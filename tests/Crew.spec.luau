-- Tests for the pit crew (src/server/Crew.luau, Config.Crew).
-- CI runs them with the Luau command line: luau tests/Crew.spec.luau

local Config = require("../src/shared/Config")
local Crew = require("../src/server/Crew")
local Rarity = require("../src/server/Rarity")

local crew = Config.Crew
local members, rarities = crew.members, crew.rarities
local rareWorth = Rarity.expected(1, Config.RareParts) - 1
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

do -- the odds
	local total = 0
	for _, r in rarities do
		total += r.chance
	end
	check("the rarity chances add up to 1", math.abs(total - 1) < 1e-9, total)
	local everyTierHired, everyMemberValid = true, true
	for tier in rarities do
		local any = false
		for _, m in members do
			any = any or m.rarity == tier
		end
		everyTierHired = everyTierHired and any
	end
	for _, m in members do
		everyMemberValid = everyMemberValid and rarities[m.rarity] ~= nil and m.income >= 0
	end
	check("every rarity has someone to hire", everyTierHired)
	check("every member has a known rarity", everyMemberValid)

	local counts, steps = {}, 20000
	for i = 0, steps - 1 do
		local m = Crew.roll((i + 0.5) / steps, 0.5, members, rarities)
		counts[m.rarity] = (counts[m.rarity] or 0) + 1
	end
	local fair = true
	for tier, r in rarities do
		fair = fair and math.abs((counts[tier] or 0) / steps - r.chance) < 0.001
	end
	check("each rarity comes up as often as its chance", fair)
	check("the lowest roll is the rarest member", Crew.roll(0, 0, members, rarities).rarity == #rarities)
	check("the highest roll is a common one", Crew.roll(0.9999, 0.9999, members, rarities).rarity == 1)
	local seen = {}
	for i = 0, 99 do
		seen[Crew.roll(0.99, i / 100, members, rarities).key] = true
	end
	local commons, allSeen = 0, true
	for _, m in members do
		if m.rarity == 1 then
			commons += 1
			allSeen = allSeen and seen[m.key] == true
		end
	end
	check("every member of a rarity can be hired", commons >= 2 and allSeen)
	local legendary = rarities[#rarities].chance
	check("a Legendary takes about 50 crates", 1 / legendary >= 30 and 1 / legendary <= 80, 1 / legendary)
end

do -- who works in the garage
	check("nobody works before anyone is hired", #Crew.best({}, members, crew.slots, rareWorth) == 0)
	local two = Crew.best({ fitter = 2, engineer = 1 }, members, 3, rareWorth)
	check("the best come first, and one hired twice fills two places",
		two[1] == "engineer" and two[2] == "fitter" and two[3] == "fitter", table.concat(two, ","))
	local full = Crew.best({ fitter = 5, principal = 1, aero = 1, engineer = 1 }, members, 3, rareWorth)
	check("only `slots` of them work", #full == 3 and full[1] == "principal" and full[2] == "aero" and full[3] == "engineer",
		table.concat(full, ","))
	local analyst = Crew.best({ analyst = 1, engineer = 1 }, members, 1, rareWorth)
	check("a rare-part boost counts for what rare parts earn", analyst[1] == "analyst", analyst[1])
	local gone = Crew.best({ someoneRetired = 3, fitter = 1 }, members, 3, rareWorth)
	check("members no longer in the game are skipped", #gone == 1 and gone[1] == "fitter", table.concat(gone, ","))
end

do -- what they add
	local income, rare = Crew.boost({}, members)
	check("no crew, no boost", income == 1 and rare == 1)
	income, rare = Crew.boost({ "principal", "aero", "fitter" }, members)
	check("income boosts add up", math.abs(income - 1.9) < 1e-9 and rare == 1, income)
	income, rare = Crew.boost({ "analyst", "analyst" }, members)
	check("rare boosts add up", rare == 3 and math.abs(income - 1.2) < 1e-9, rare)
	local best = 0
	for _, m in members do
		best = math.max(best, m.income + ((m.rare or 1) - 1) * rareWorth)
	end
	check("a full crew of the best at most triples income", 1 + best * crew.slots <= 3, 1 + best * crew.slots)
end

do -- the crate's price
	check("a crate costs minutes of income", Crew.price(1000, 1, crew.crate) == 1000 * crew.crate.minutes)
	check("and at least the floor", Crew.price(0, 1, crew.crate) == crew.crate.floor)
	check("the floor grows with the season multiplier", Crew.price(0, 2.5, crew.crate) == math.floor(crew.crate.floor * 2.5))
	check("crew unlocks after a few machines, before the trophy", crew.unlockPurchases >= 2 and crew.unlockPurchases <= 10)
end

do -- Scout's pick
	local pick = crew.pick
	local total = 0
	for _, w in pick.weights do
		total += w
	end
	check("the pick's rarity weights add up to 1", math.abs(total - 1) < 1e-9, total)
	local start = math.floor(1793000000 / (pick.minutes * 60)) -- windows around October 2026
	local counts, seen, changes, last = {}, {}, 0, nil
	local n = 20000
	for w = start, start + n - 1 do
		local m = Crew.pick(w, members, pick.weights)
		counts[m.rarity] = (counts[m.rarity] or 0) + 1
		seen[m.key] = true
		changes += (last and last ~= m.key) and 1 or 0
		last = m.key
	end
	local fair = true
	for tier, weight in pick.weights do
		fair = fair and math.abs((counts[tier] or 0) / n - weight) < 0.01
	end
	check("each rarity is the pick as often as its weight", fair)
	local everyone = true
	for _, m in members do
		everyone = everyone and seen[m.key] == true
	end
	check("everyone gets to be the pick", everyone)
	check("the pick usually changes each time", changes / n > 0.6, changes / n)
	check("the same window gives the same pick everywhere",
		Crew.pick(start + 7, members, pick.weights).key == Crew.pick(start + 7, members, pick.weights).key)
	-- hunting one member with crates takes 1 / (its rarity's chance / members of that rarity)
	local bargain, worst = true, nil
	for tier, r in rarities do
		local size = 0
		for _, m in members do
			size += m.rarity == tier and 1 or 0
		end
		local hunt = size / r.chance
		if pick.crates[tier] >= hunt then
			bargain, worst = false, ("%s: %d crates vs %.1f"):format(r.name, pick.crates[tier], hunt)
		end
	end
	check("a pick costs fewer crates than hunting that member", bargain, worst)
	check("a Legendary pick is the rarest", pick.weights[#pick.weights] < pick.weights[1])
end

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then
	error("crew tests failed")
end
