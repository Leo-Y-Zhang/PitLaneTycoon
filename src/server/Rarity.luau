--!strict
-- Rare parts (Config.RareParts): now and then a press stamps a Gold or Rainbow part worth
-- many times more. Pure Luau, so tests/Rarity.spec.luau checks the odds and what they add to
-- income in CI.

local Rarity = {}

export type Tier = { name: string, chance: number, mult: number }

-- r = a random number in [0, 1); chanceMult scales every chance (a live event can raise them).
-- Returns the tier's name (nil for an ordinary part) and its value multiplier.
function Rarity.roll(r: number, chanceMult: number, tiers: { Tier }): (string?, number)
	local edge = 0
	for i = #tiers, 1, -1 do -- rarest first
		edge += tiers[i].chance * chanceMult
		if r < edge then
			return tiers[i].name, tiers[i].mult
		end
	end
	return nil, 1
end

-- what rare parts add to the average part's value, as a multiplier (1.1 = +10%)
function Rarity.expected(chanceMult: number, tiers: { Tier }): number
	local extra = 0
	for _, tier in tiers do
		extra += tier.chance * chanceMult * (tier.mult - 1)
	end
	return 1 + extra
end

return Rarity
