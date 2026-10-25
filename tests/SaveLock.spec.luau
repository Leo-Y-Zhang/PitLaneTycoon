-- Tests for src/server/SaveLock.luau. CI runs them with the Luau command line:
--     luau tests/SaveLock.spec.luau
-- The store is a fake with the one DataStore call the module uses (UpdateAsync), and the
-- clock is a number the tests move by hand, so two servers can be played out in order.

local SaveLock = require("../src/server/SaveLock")

local failed, passed = 0, 0
local function check(name: string, ok: any, detail: any?)
	if ok then
		passed += 1
		print("PASS " .. name)
	else
		failed += 1
		print("FAIL " .. name .. (if detail ~= nil then " (" .. tostring(detail) .. ")" else ""))
	end
end

local function copy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = copy(x)
	end
	return out
end

-- UpdateAsync: the transform sees a copy; nil cancels the write
local function fakeStore(initial: { [string]: any }?)
	local store = { values = initial or {}, broken = false, calls = 0 }
	function store:UpdateAsync(key: string, transform: (any) -> any): any
		self.calls += 1
		if self.broken then
			error("DataStore request failed")
		end
		local out = transform(copy(self.values[key]))
		if out ~= nil then
			self.values[key] = copy(out)
		end
		return copy(out)
	end
	return store
end

local clock = 0
local function opts(overrides: { [string]: any }?)
	local o: any = {
		now = function()
			return clock
		end,
		wait = function(s: number)
			clock += s
		end,
		gone = function()
			return false
		end,
		stale = 150,
		retry = 6,
		giveUp = 300,
	}
	for k, v in overrides or {} do
		o[k] = v
	end
	return o
end

do -- a new player
	clock = 0
	local store = fakeStore()
	local data, status = SaveLock.open(store, "u_1", "A", opts())
	check("a new player loads with no save", data == nil and status == "ok", status)
	local lock = store.values.u_1 and store.values.u_1.lock
	check("loading takes the lock", lock and lock.job == "A" and lock.at == 0)
end

do -- a save from before locking existed
	clock = 0
	local store = fakeStore({ u_1 = { cash = 500, season = 2 } })
	local data, status = SaveLock.open(store, "u_1", "A", opts())
	check("a save from v0.3 (no lock) loads", status == "ok" and data and data.cash == 500 and data.season == 2, status)
	check("the lock is not handed to the game as data", data and data.lock == nil)
end

do -- a server hop: B loads while A is still saving
	clock = 0
	local store = fakeStore({ u_1 = { cash = 100 } })
	SaveLock.open(store, "u_1", "A", opts())
	local waits = 0
	local data, status = SaveLock.open(store, "u_1", "B", opts({
		wait = function(s: number)
			waits += 1
			clock += s
			if waits == 1 then
				-- A's leaving save lands while B waits
				SaveLock.save(store, "u_1", { cash = 250 }, "A", clock, true)
			end
		end,
	}))
	check("a second server waits while the first holds the save", waits >= 1, waits)
	check("then loads what the first server saved on leaving", status == "ok" and data and data.cash == 250,
		data and data.cash)
	check("and holds the lock itself", store.values.u_1.lock and store.values.u_1.lock.job == "B")
end

do -- a crashed server never lets go
	clock = 0
	local store = fakeStore({ u_1 = { cash = 100 } })
	SaveLock.open(store, "u_1", "A", opts())
	clock = 10
	local data, status = SaveLock.open(store, "u_1", "B", opts())
	check("a lock left by a crashed server is taken over once stale", status == "ok" and data and data.cash == 100, status)
	check("but not before it is stale", clock >= 150, clock)
end

do -- a live server keeps its lock fresh by saving
	clock = 0
	local store = fakeStore({ u_1 = { cash = 100 } })
	SaveLock.open(store, "u_1", "A", opts())
	local refreshed = 0
	local _, status = SaveLock.open(store, "u_1", "B", opts({
		wait = function(s: number)
			clock += s
			if clock - refreshed >= 60 then -- A's autosave
				refreshed = clock
				SaveLock.save(store, "u_1", { cash = 100 + clock }, "A", clock)
			end
		end,
	}))
	check("a server that keeps saving keeps the save", status == "locked", status)
	check("and the waiting server gives up after giveUp", clock >= 300 and clock < 320, clock)
end

do -- the old server comes back after its lock was taken over
	clock = 0
	local store = fakeStore({ u_1 = { cash = 100 } })
	SaveLock.open(store, "u_1", "A", opts())
	clock = 200
	SaveLock.open(store, "u_1", "B", opts())
	SaveLock.save(store, "u_1", { cash = 900 }, "B", clock)
	local written, lost = SaveLock.save(store, "u_1", { cash = 120 }, "A", clock)
	check("a server that lost the lock does not overwrite the newer save", not written and store.values.u_1.cash == 900,
		store.values.u_1.cash)
	check("and is told it lost the lock", lost)
end

do -- leaving lets go
	clock = 0
	local store = fakeStore({ u_1 = { cash = 100 } })
	SaveLock.open(store, "u_1", "A", opts())
	local written = SaveLock.save(store, "u_1", { cash = 300 }, "A", 5, true)
	check("the leaving save is written", written and store.values.u_1.cash == 300)
	check("and lets go of the lock", store.values.u_1.lock == nil)
	local late, lost = SaveLock.save(store, "u_1", { cash = 1 }, "A", 6)
	check("a late save after letting go is refused", not late and lost and store.values.u_1.cash == 300,
		store.values.u_1.cash)
	clock = 7
	local data, status = SaveLock.open(store, "u_1", "B", opts())
	check("another server loads at once after the leaving save", status == "ok" and clock == 7 and data and data.cash == 300,
		clock)
end

do -- the store is down
	clock = 0
	local store = fakeStore({ u_1 = { cash = 100 } })
	store.broken = true
	local data, status = SaveLock.open(store, "u_1", "A", opts())
	check("a store that keeps failing is reported, not played as a new save", data == nil and status == "error", status)
	check("after three tries", store.calls == 3, store.calls)
	local written, lost, err = SaveLock.save(store, "u_1", { cash = 1 }, "A", 0)
	check("a failed save is not mistaken for a lost lock", not written and not lost and err ~= nil)
end

do -- the player leaves while we wait
	clock = 0
	local store = fakeStore({ u_1 = { cash = 100 } })
	SaveLock.open(store, "u_1", "A", opts())
	local _, status = SaveLock.open(store, "u_1", "B", opts({
		gone = function()
			return true
		end,
	}))
	check("a player who leaves while waiting stops the wait", status == "gone", status)
	check("and the other server's lock is untouched", store.values.u_1.lock.job == "A")
end

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then
	error("SaveLock tests failed")
end
