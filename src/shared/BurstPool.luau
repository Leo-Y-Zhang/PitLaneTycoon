--!strict
-- Presentation-only leases: no Roblox instances, unbounded queues, or busy-slot stealing.
local BurstPool = {}
BurstPool.SlotLimit = 6
BurstPool.ParticleLimit = 240
export type Profile = { count: number, duration: number }
BurstPool.Profiles = {
	purchase = { count = 24, duration = 0.9 },
	gold = { count = 36, duration = 1.1 },
	rainbow = { count = 48, duration = 1.3 },
	season = { count = 80, duration = 2.4 },
} :: { [string]: Profile }
export type Slot = { token: number, expiresAt: number, count: number }
export type Pool = { slots: { Slot } }

function BurstPool.new(): Pool
	local slots: { Slot } = {}
	for _ = 1, BurstPool.SlotLimit do
		table.insert(slots, { token = 0, expiresAt = -math.huge, count = 0 })
	end
	return { slots = slots }
end

function BurstPool.acquire(pool: Pool, kind: string, now: number, reduceMotion: boolean): (number?, number?)
	local profile = BurstPool.Profiles[kind]
	if reduceMotion or not profile then return nil, nil end
	local free: number? = nil
	local particles = 0
	for i, slot in pool.slots do
		if slot.expiresAt <= now then
			if not free then free = i end
		else
			particles += slot.count
		end
	end
	if not free or particles + profile.count > BurstPool.ParticleLimit then return nil, nil end
	local slot = pool.slots[free]
	slot.token += 1
	slot.expiresAt = now + profile.duration
	slot.count = profile.count
	return free, slot.token
end

function BurstPool.release(pool: Pool, index: number, token: number): boolean
	local slot = pool.slots[index]
	if not slot or slot.token ~= token then return false end
	slot.expiresAt, slot.count = -math.huge, 0
	return true
end

function BurstPool.clear(pool: Pool)
	for _, slot in pool.slots do
		slot.token += 1
		slot.expiresAt, slot.count = -math.huge, 0
	end
end

return BurstPool
