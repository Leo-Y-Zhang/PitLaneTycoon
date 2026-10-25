-- Tests for goals and redeem codes (src/server/Goals.luau, Config.Goals, src/server/Codes.luau).
-- CI runs them with the Luau command line: luau tests/Goals.spec.luau

local Config = require("../src/shared/Config")
local Goals = require("../src/server/Goals")
local Codes = require("../src/server/Codes")
local TrackShape = require("../src/shared/TrackShape")

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

local known = {}
for _, kind in Goals.Kinds do
	known[kind] = true
end

-- season 1 has every season-0 item but the free first press to buy
local seasonOnePurchases = -1
for _, item in Config.Items do
	if (item.season or 0) == 0 then
		seasonOnePurchases += 1
	end
end

do
	local wellFormed, bad = true, nil
	for i, goal in Config.Goals do
		local ok = known[goal.kind] and goal.text ~= "" and goal.minutes > 0 and goal.floor > 0 and goal.n > 0
		if not ok then
			wellFormed, bad = false, i
		end
	end
	check("every goal has a known kind, a text and a reward", wellFormed, bad)

	-- each goal must be possible at the point of the chain where it stands: purchase goals
	-- within a season's line, lap goals within reach of that season's car
	local length = TrackShape.length(Config.Track)
	local season, reachable, why = 0, true, nil
	local lastEarned, lastSeason = 0, 0
	for _, goal in Config.Goals do
		if goal.kind == "purchases" and goal.n > seasonOnePurchases then
			reachable, why = false, goal.text
		elseif goal.kind == "lapUnder" then
			local top = math.min(Config.Drive.maxTopSpeed, Config.Drive.topSpeed + Config.Drive.perSeason * season)
			if goal.n < length / top * 1.1 then -- a flat-out lap plus some room for the bends
				reachable, why = false, ("%s needs %.1f s at %d studs/s"):format(goal.text, length / top * 1.1, top)
			end
		elseif goal.kind == "earned" then
			reachable = reachable and goal.n > lastEarned
			lastEarned = goal.n
		elseif goal.kind == "season" then
			reachable = reachable and goal.n > lastSeason
			lastSeason = goal.n
			season = goal.n
		end
	end
	check("every goal can be met where it stands in the chain", reachable, why)
end

do
	local s = { banks = 0, purchases = 3, laps = 0, earned = 0, bestLap = 0, season = 0, trophy = false }
	local function goal(kind: string, n: number)
		return { kind = kind, n = n, text = "", minutes = 1, floor = 1 }
	end
	local have, need = Goals.progress(goal("purchases", 5), s)
	check("progress counts towards the goal", have == 3 and need == 5)
	check("and caps at it", (Goals.progress(goal("purchases", 2), s)) == 2)
	check("a lap goal needs a lap under the time", not Goals.done(goal("lapUnder", 25), s))
	s.bestLap = 24.5
	check("and is met by one", Goals.done(goal("lapUnder", 25), s))
	check("but not by a lap over it", not Goals.done(goal("lapUnder", 24), s))
	check("the trophy goal is met once bought", not Goals.done(goal("trophy", 1), s))
	s.season = 1
	check("and stays met in later seasons, when the trophy is gone", Goals.done(goal("trophy", 1), s))
end

do
	local ok, bad, count = true, nil, 0
	for code, prize in Codes do
		count += 1
		if code ~= string.upper(code) or string.find(code, "[^%w]") or prize.minutes <= 0 or prize.floor <= 0 then
			ok, bad = false, code
		end
	end
	check("codes are upper-case letters and digits with a reward", ok and count > 0, bad)
	check("the codes are not in the shared Config, which players can read", (Config :: any).Codes == nil)
end

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then
	error("goal tests failed")
end
