--!strict
-- The pit crew (Config.Crew): crates hire members at random, and the best few work in the
-- garage for a boost. Pure Luau, so tests/Crew.spec.luau checks the odds and boosts in CI.

local Crew = {}

export type Rarity = { name: string, chance: number, colour: { number } }
export type Member = { key: string, name: string, rarity: number, income: number, rare: number?, prop: string }

-- r1, r2 = random numbers in [0, 1): r1 picks the rarity (rarest first), r2 a member of it
function Crew.roll(r1: number, r2: number, members: { Member }, rarities: { Rarity }): Member
	local tier, edge = 1, 0
	for i = #rarities, 1, -1 do
		edge += rarities[i].chance
		if r1 < edge then
			tier = i
			break
		end
	end
	local pool = {}
	for _, member in members do
		if member.rarity == tier then
			table.insert(pool, member)
		end
	end
	return pool[math.min(#pool, math.floor(r2 * #pool) + 1)]
end

-- what a member is worth as a share of income; a rare-part boost counts at rareWorth (what
-- rare parts add to income, from Rarity.expected) for each step
local function worth(member: Member, rareWorth: number): number
	return member.income + ((member.rare or 1) - 1) * rareWorth
end

-- the members who work in the garage: the best `slots` of those owned (owned = counts by key;
-- a member hired twice can fill two places). Keys no longer in Config are skipped.
function Crew.best(owned: { [string]: number }, members: { Member }, slots: number, rareWorth: number): { string }
	local ranked = {}
	for _, member in members do
		for _ = 1, math.min(owned[member.key] or 0, slots) do
			table.insert(ranked, member)
		end
	end
	table.sort(ranked, function(a, b)
		local wa, wb = worth(a, rareWorth), worth(b, rareWorth)
		if wa ~= wb then
			return wa > wb
		end
		return a.key < b.key
	end)
	local working = {}
	for i = 1, math.min(slots, #ranked) do
		working[i] = ranked[i].key
	end
	return working
end

-- the working crew's income multiplier and rare-chance multiplier (both add up: two +5%
-- members give 1.1, two 2x rare members give 3)
function Crew.boost(working: { string }, members: { Member }): (number, number)
	local income, rare = 1, 1
	for _, key in working do
		for _, member in members do
			if member.key == key then
				income += member.income
				rare += (member.rare or 1) - 1
			end
		end
	end
	return income, rare
end

-- a crate's price: `minutes` of income per minute (before crew boosts), at least floor * mult
function Crew.price(perMinute: number, mult: number, crate: { minutes: number, floor: number }): number
	return math.floor(math.max(crate.floor * mult, perMinute * crate.minutes))
end

return Crew
