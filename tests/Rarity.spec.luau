-- Tests for rare parts and live events (src/server/Rarity.luau, Config.RareParts, Config.Events).
-- CI runs them with the Luau command line: luau tests/Rarity.spec.luau

local Config = require("../src/shared/Config")
local Rarity = require("../src/server/Rarity")

local tiers = Config.RareParts
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

local rainbow, gold = tiers[#tiers], tiers[1]
do
	local name = Rarity.roll(rainbow.chance * 0.5, 1, tiers)
	check("the rarest tier is rolled first", name == rainbow.name, name)
	local name2, mult2 = Rarity.roll(rainbow.chance + gold.chance * 0.5, 1, tiers)
	check("then the next", name2 == gold.name and mult2 == gold.mult, name2)
	local name3, mult3 = Rarity.roll(rainbow.chance + gold.chance + 0.001, 1, tiers)
	check("and most parts are ordinary", name3 == nil and mult3 == 1, name3)
	local boosted = Rarity.roll((rainbow.chance + gold.chance) * 3, 5, tiers)
	check("an event that raises the odds widens every tier", boosted ~= nil, boosted)
end

do -- a fixed sequence of rolls lands near the expected value
	local seed, total, n = 12345, 0, 200000
	for _ = 1, n do
		seed = (seed * 1103515245 + 12345) % 2147483648
		local _, mult = Rarity.roll(seed / 2147483648, 1, tiers)
		total += mult
	end
	local expected = Rarity.expected(1, tiers)
	check("rolled parts average out to the expected value", math.abs(total / n - expected) < 0.02,
		("%.3f vs %.3f"):format(total / n, expected))
	-- the pacing tool (tools/balance.py) times the line without rare parts, so they must stay a
	-- bonus and not reshape the season
	check("rare parts add 5-15% to income, not more", expected > 1.05 and expected < 1.15, expected)
end

do
	local ok, why = true, nil
	for _, event in Config.Events.list do
		if event.seconds <= 0 or event.seconds >= Config.Events.everyMinutes * 60 / 2 then
			ok, why = false, event.name .. " runs too long"
		elseif event.incomeMult < 1 or event.rareMult < 1 then
			ok, why = false, event.name .. " takes something away"
		elseif event.text == "" then
			ok, why = false, event.name .. " has no text"
		end
	end
	check("every live event is short, only gives, and says what it does", ok and #Config.Events.list > 0, why)
end

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then
	error("rarity tests failed")
end
