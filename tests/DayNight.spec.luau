--!strict
-- Run with plain Luau: luau tests/DayNight.spec.luau
local Cycle = require("../src/shared/DayNight")
local passed, failed = 0, 0
local function check(name: string, ok: boolean)
	if ok then passed += 1; print("PASS " .. name)
	else failed += 1; print("FAIL " .. name) end
end
local function near(a: number, b: number): boolean
	return math.abs(a - b) < 0.000001
end

check("a full day takes twenty minutes", Cycle.SecondsPerDay == 1200)
check("a minute advances 1.2 hours", near(Cycle.advance(14.5, 60, false), 15.7))
check("a full cycle returns to the starting hour", near(Cycle.advance(14.5, 1200, false), 14.5))
check("midnight wraps smoothly", near(Cycle.advance(23.5, 50, false), 0.5))
check("long stalls preserve elapsed time across days", near(Cycle.advance(6, 3000, false), 18))
check("negative elapsed time cannot reverse the clock", Cycle.advance(12, -1, false) == 12)
check("frozen time does not advance", Cycle.advance(14.5, 600, true) == 14.5)
check("freeze does not force daytime", Cycle.advance(23, 600, true) == 23)
check("just before dusk is day", not Cycle.isNight(17.999))
check("dusk switches lights on", Cycle.isNight(18))
check("midnight is night", Cycle.isNight(0))
check("just before dawn is night", Cycle.isNight(5.999))
check("dawn switches lights off", not Cycle.isNight(6))
check("noon is day", not Cycle.isNight(12))
check("thresholds accept wrapped hours", Cycle.isNight(42) and not Cycle.isNight(30))
check("server config freezes live servers", Cycle.frozen(true, false, false))
check("Studio photos freeze the clock", Cycle.frozen(false, true, true))
check("normal Studio play still cycles", not Cycle.frozen(false, true, false))
check("photo flag cannot freeze a live server", not Cycle.frozen(false, false, true))

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then error("day/night tests failed") end
