--!strict
-- Run with plain Luau: luau tests/BurstPool.spec.luau
local Bursts = require("../src/shared/BurstPool")
local passed, failed = 0, 0
local function check(name: string, ok: boolean)
	if ok then passed += 1; print("PASS " .. name)
	else failed += 1; print("FAIL " .. name) end
end

local pool = Bursts.new()
check("the pool has a fixed number of slots", #pool.slots == Bursts.SlotLimit)
check("reduce motion suppresses particles", Bursts.acquire(pool, "purchase", 0, true) == nil)
check("suppressed bursts leave slots free", pool.slots[1].token == 0)
check("unknown effects do not allocate", Bursts.acquire(pool, "unknown", 0, false) == nil)
local index, token = Bursts.acquire(pool, "purchase", 0, false)
check("a purchase leases the first free slot", index == 1 and token == 1)
check("a lease lasts until all particles expire", pool.slots[1].expiresAt == Bursts.Profiles.purchase.duration)
local second = Bursts.acquire(pool, "gold", 0, false)
check("simultaneous bursts use separate slots", second == 2)
for _ = 3, Bursts.SlotLimit do Bursts.acquire(pool, "purchase", 0, false) end
check("a full pool drops additional bursts", Bursts.acquire(pool, "purchase", 0, false) == nil)
check("bursts never grow the pool", #pool.slots == Bursts.SlotLimit)
local reused, nextToken = Bursts.acquire(pool, "purchase", Bursts.Profiles.purchase.duration, false)
check("expired slots are reused at the boundary", reused == 1 and nextToken == 2)
check("stale cleanup cannot release a reused slot", not Bursts.release(pool, 1, 1))
check("current cleanup releases its lease", Bursts.release(pool, 1, 2))
check("release makes a slot available immediately", Bursts.acquire(pool, "purchase", 1, false) == 1)

pool = Bursts.new()
local admitted = 0
for _ = 1, 1000 do
	if Bursts.acquire(pool, "season", 0, false) then admitted += 1 end
end
check("confetti respects the total particle budget", admitted * Bursts.Profiles.season.count <= Bursts.ParticleLimit)
check("particle budget caps confetti before slots run out", admitted > 0 and admitted < Bursts.SlotLimit)
check("expired confetti frees its particle budget", Bursts.acquire(pool, "season", Bursts.Profiles.season.duration, false) == 1)
Bursts.clear(pool)
check("motion changes invalidate outstanding callbacks", not Bursts.release(pool, 1, 2))
check("motion changes release all slots", Bursts.acquire(pool, "season", 0, false) == 1)
for _, kind in { "purchase", "gold", "rainbow", "season" } do
	local profile = Bursts.Profiles[kind]
	check(kind .. " has bounded positive count and lifetime", profile.count > 0 and profile.count <= Bursts.ParticleLimit
		and profile.duration > 0 and profile.duration <= 3)
end
check("rare tiers have distinct bursts", Bursts.Profiles.gold.count ~= Bursts.Profiles.rainbow.count)

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then error("burst pool tests failed") end
