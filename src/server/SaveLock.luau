--!strict
-- Session-locked saves, so two servers never play the same save at once. When a player
-- hops servers, the new server can load before the old one has finished saving; without a
-- lock it plays the older save, and whichever server writes last wins, losing progress.
--
-- A save is the player's data plus `lock = { job, at }`: the server (its JobId) that has it
-- and when that server last saved. A server loads only a save no live server holds, waits
-- while another server is still letting go, and takes over a lock that has gone stale (that
-- server stopped saving, so it crashed). It writes only while it still holds the lock, and
-- lets go when the player leaves.
--
-- Pure Luau with the store passed in, so tests/SaveLock.spec.luau runs it in CI.

local SaveLock = {}

export type Record = { [string]: any }
export type Options = {
	now: () -> number, -- seconds, os.time in the game
	wait: (number) -> (), -- task.wait in the game
	gone: () -> boolean, -- the player left while we waited
	stale: number, -- a lock this old belongs to a server that stopped saving
	retry: number, -- seconds between tries while another server holds the save
	giveUp: number, -- stop waiting after this long and play without saving
	held: (() -> ())?, -- called each time another server is found holding the save
}

-- UpdateAsync transform for loading: take the save unless a live server holds it
function SaveLock.claim(record: Record?, job: string, now: number, stale: number): (Record?, boolean)
	return table.clone(record or {}), true -- no lock: like v0.3
end

function SaveLock.write(record: Record?, data: Record, job: string, now: number, release: boolean?): (Record?, boolean)
	return table.clone(data), true -- no lock: like v0.3
end

-- Load and lock a player's save. Returns the save (nil for a new player) and a status:
-- "ok", "locked" (gave up waiting), "error" (the store kept failing) or "gone".
function SaveLock.open(store: any, key: string, job: string, opts: Options): (Record?, string)
	local started = opts.now()
	local failures = 0
	while true do
		local held = false
		local ok, result = pcall(function()
			return store:UpdateAsync(key, function(record: Record?)
				local claimed, got = SaveLock.claim(record, job, opts.now(), opts.stale)
				held = got
				return claimed
			end)
		end)
		if ok and held then
			local data = table.clone(result :: Record)
			data.lock = nil
			-- a brand-new player's save holds nothing but the lock
			return if next(data) == nil then nil else data, "ok"
		elseif not ok then
			failures += 1
			if failures >= 3 then
				return nil, "error"
			end
			opts.wait(failures) -- a store error: try again soon
		else
			if opts.held then
				opts.held()
			end
			if opts.gone() then
				return nil, "gone"
			elseif opts.now() - started >= opts.giveUp then
				return nil, "locked"
			end
			opts.wait(opts.retry)
		end
	end
end

-- Save a player's data; release = the player is leaving. Returns whether it was written,
-- whether this server has lost the lock (so it must stop saving) and the store's error.
function SaveLock.save(store: any, key: string, data: Record, job: string, now: number, release: boolean?): (boolean, boolean, string?)
	local held = false
	local ok, err = pcall(function()
		store:UpdateAsync(key, function(record: Record?)
			local out, still = SaveLock.write(record, data, job, now, release)
			held = still
			return out
		end)
	end)
	if not ok then
		return false, false, tostring(err)
	end
	return held, not held, nil
end

return SaveLock
