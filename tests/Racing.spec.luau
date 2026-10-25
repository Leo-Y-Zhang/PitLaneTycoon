-- Tests for the time trial: the track's shape (src/shared/TrackShape.luau), the car's
-- handling (src/shared/DriveModel.luau) and lap timing (src/server/LapTimer.luau).
-- CI runs them with the Luau command line: luau tests/Racing.spec.luau

local Config = require("../src/shared/Config")
local TrackShape = require("../src/shared/TrackShape")
local DriveModel = require("../src/shared/DriveModel")
local LapTimer = require("../src/server/LapTimer")

local shape = Config.Track
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

-- the track -----------------------------------------------------------------------------
do
	local points = TrackShape.samples(shape, 2000)
	local inner, tightest = math.huge, math.huge
	for i, p in points do
		inner = math.min(inner, math.sqrt(p.x * p.x + p.z * p.z) - shape.halfWidth)
		-- the radius of the circle through three neighbouring points
		local a, c = points[(i - 2) % #points + 1], points[i % #points + 1]
		local ab = math.sqrt((p.x - a.x) ^ 2 + (p.z - a.z) ^ 2)
		local bc = math.sqrt((c.x - p.x) ^ 2 + (c.z - p.z) ^ 2)
		local ca = math.sqrt((a.x - c.x) ^ 2 + (a.z - c.z) ^ 2)
		local area = math.abs((p.x - a.x) * (c.z - a.z) - (p.z - a.z) * (c.x - a.x)) / 2
		if area > 1e-9 then
			tightest = math.min(tightest, ab * bc * ca / (4 * area))
		end
	end
	-- a garage reaches out to its back corners: 26 studs behind its centre, 32 to each side
	local garage = math.sqrt((Config.PlotRadius + 26) ^ 2 + 32 ^ 2)
	check("the track clears every garage, with grass between", inner - 3 > garage + 3,
		("inner edge %.0f, garages reach %.0f"):format(inner, garage))
	check("no bend is tighter than 40 studs", tightest >= 40, tightest)
	local length = TrackShape.length(shape)
	check("a lap is 900 to 1500 studs", length >= 900 and length <= 1500, length)

	local worst = 0
	for i = 0, 59 do
		local a = i / 60 * 2 * math.pi
		local x, z = TrackShape.point(shape, a)
		local tx, tz = TrackShape.tangent(shape, a)
		for _, off in { -6, 0, 6 } do
			local got, dist = TrackShape.nearest(shape, x + tz * off, z - tx * off) -- (tz, -tx) points outwards
			local da = math.abs((got - a + math.pi) % (2 * math.pi) - math.pi)
			worst = math.max(worst, da * 100, math.abs(dist - off))
		end
	end
	check("nearest finds the centre line and how far off it a car is (outside +)", worst < 0.05, worst)
end

-- the car -----------------------------------------------------------------------------
do
	local h, top = Config.Drive, 65
	local speed, t = 0, 0
	while speed < top and t < 30 do
		speed = DriveModel.step(speed, 1, 0, 1 / 60, top, false, h)
		t += 1 / 60
	end
	check("full throttle reaches top speed in top / accel seconds", math.abs(t - top / h.accel) < 0.1, t)
	for _ = 1, 120 do
		speed = DriveModel.step(speed, 1, 0, 1 / 60, top, false, h)
	end
	check("and never passes it", speed <= top, speed)
	local grass = speed
	for _ = 1, 240 do
		grass = DriveModel.step(grass, 1, 0, 1 / 60, top, true, h)
	end
	check("running onto the grass scrubs speed down to its share", math.abs(grass - top * h.offroadShare) < 0.01, grass)
	local stopped, braking = speed, 0
	while stopped > 0 and braking < 10 do
		stopped = DriveModel.step(stopped, -1, 0, 1 / 60, top, false, h)
		braking += 1 / 60
	end
	check("braking stops it in top / brake seconds", math.abs(braking - top / h.brake) < 0.1, braking)
	local back = 0
	for _ = 1, 600 do
		back = DriveModel.step(back, -1, 0, 1 / 60, top, false, h)
	end
	check("held brake then reverses, up to the reverse limit", back == -h.reverse, back)
	local coast = top
	for _ = 1, 60 * 10 do
		coast = DriveModel.step(coast, 0, 0, 1 / 60, top, false, h)
	end
	check("off the pedals it rolls to a stop", coast == 0, coast)
	local _, still = DriveModel.step(0, 0, 1, 1 / 60, top, false, h)
	local _, right = DriveModel.step(40, 1, 1, 1 / 60, top, false, h)
	local _, backRight = DriveModel.step(-10, -1, 1, 1 / 60, top, false, h)
	check("no turning on the spot", still == 0, still)
	check("steering right turns right (negative about the vertical)", right == -h.turnRate, right)
	check("reversing steers the other way", backRight > 0, backRight)
	-- a car at rest never measures exactly 0: a held pedal must pull away whichever way it creeps
	local backAway = DriveModel.step(0.004, -1, 0, 1 / 60, top, false, h)
	local pullAway = DriveModel.step(-0.004, 1, 0, 1 / 60, top, false, h)
	check("creeping forward at a standstill, the brake still reverses", backAway < 0, backAway)
	check("creeping back at a standstill, the throttle still pulls away", pullAway > 0, pullAway)
end

do -- the start lights
	local lit0, go0 = DriveModel.lights(0, 0.5)
	local lit3 = DriveModel.lights(DriveModel.LightGap * 3 + 0.01, 0.5)
	local lit5, go5 = DriveModel.lights(DriveModel.LightGap * 5 + 0.2, 0.5)
	local out, go = DriveModel.lights(DriveModel.LightGap * 5 + 0.51, 0.5)
	check("the lights start dark and the car is held", lit0 == 0 and not go0)
	check("they come on one at a time", lit3 == 3, lit3)
	check("all five stay lit through the hold", lit5 == 5 and not go5, lit5)
	check("then all go out: GO", out == 0 and go)
end

-- lap timing --------------------------------------------------------------------------
local function timer()
	return LapTimer.new({
		nearest = function(x: number, z: number)
			return TrackShape.nearest(shape, x, z)
		end,
		limit = shape.limit,
		maxSpeed = 65,
	})
end

-- drive along the centre line from angle a0 to a1 at `speed`, sampling every `every`
-- seconds (a function for uneven gaps); returns the events and the time it ended at.
-- `bend(a)` moves the car off the centre line (studs outwards) at angle a.
local function drive(t: any, a0: number, a1: number, speed: number, every: any, start: number,
	bend: ((number) -> number)?): ({ any }, number)
	local events, now, a = {}, start, a0
	local dir = if a1 >= a0 then 1 else -1
	while (a1 - a) * dir > 0 do
		local gap = if type(every) == "function" then every() else every
		-- step the angle so the car covers speed * gap studs along the line
		local x1, z1 = TrackShape.point(shape, a)
		local x2, z2 = TrackShape.point(shape, a + 0.001)
		local perAngle = math.sqrt((x2 - x1) ^ 2 + (z2 - z1) ^ 2) / 0.001
		a += dir * speed * gap / perAngle
		now += gap
		local x, z = TrackShape.point(shape, a)
		local tx, tz = TrackShape.tangent(shape, a)
		local off = bend and bend(a) or 0
		local event = LapTimer.sample(t, now, x + tz * off, z - tx * off)
		if event then
			table.insert(events, event)
		end
	end
	return events, now
end

local TAU = 2 * math.pi
local length = TrackShape.length(shape)
do
	local t = timer()
	local events = drive(t, -0.04, TAU + 0.3, 40, 0.1, 100)
	check("crossing the line starts the clock", events[1] and events[1].kind == "start")
	local lap = events[2]
	check("the next crossing is a lap", lap and lap.kind == "lap" and lap.valid == true, lap and lap.kind)
	local expect = length / 40
	check("timed to within 1% of its length / speed", lap and math.abs(lap.time - expect) / expect < 0.01,
		lap and ("%.2f vs %.2f"):format(lap.time, expect))
	check("one lap, not more", #events == 2, #events)
end

do -- uneven sampling (a busy server)
	local t = timer()
	local seed = 7
	local function gap()
		seed = (seed * 1103515245 + 12345) % 2147483648
		return 0.05 + (seed / 2147483648) * 0.2
	end
	local events = drive(t, -0.04, TAU + 0.3, 40, gap, 0)
	local lap = events[2]
	local expect = length / 40
	check("uneven samples still time to within 1%", lap and math.abs(lap.time - expect) / expect < 0.01,
		lap and ("%.2f vs %.2f"):format(lap.time, expect))
end

do -- cutting across the infield
	local t = timer()
	local events = drive(t, -0.04, TAU + 0.3, 40, 0.1, 0, function(a)
		return if a > 2 and a < 2.4 then -30 else 0
	end)
	local lap = events[2]
	check("a lap that leaves the track limits is void", lap and lap.valid == false and lap.reason == "track limits",
		lap and lap.reason)
	local more = drive(t, TAU + 0.3, 2 * TAU + 0.3, 40, 0.1, 100)
	check("and the next clean lap counts again", more[1] and more[1].valid == true, more[1] and more[1].reason)
end

do -- a teleport
	local t = timer()
	local _, now = drive(t, -0.04, 1, 40, 0.1, 0)
	-- jump half a lap round in one sample
	local x, z = TrackShape.point(shape, 1 + math.pi * 0.9)
	LapTimer.sample(t, now + 0.1, x, z)
	local events = drive(t, 1 + math.pi * 0.9, TAU + 0.3, 40, 0.1, now + 0.1)
	local lap = events[#events]
	check("a car that jumps along the track is void", lap and lap.kind == "lap" and lap.valid == false and lap.reason == "teleport",
		lap and lap.reason)
end

do -- the Reverse GP: the same circuit the other way round
	local rt = LapTimer.new({
		nearest = function(x: number, z: number)
			return TrackShape.nearest(shape, x, z)
		end,
		limit = shape.limit,
		maxSpeed = 65,
		reverse = true,
	})
	local events = drive(rt, 0.04, -TAU - 0.3, 40, 0.1, 0)
	local expect = length / 40
	check("a Reverse GP lap starts at the line and is timed", events[1] and events[1].kind == "start" and events[2]
		and events[2].kind == "lap" and math.abs(events[2].time - expect) / expect < 0.01, events[2] and events[2].time)
	local wrongWay = LapTimer.new({
		nearest = function(x: number, z: number)
			return TrackShape.nearest(shape, x, z)
		end,
		limit = shape.limit,
		maxSpeed = 65,
		reverse = true,
	})
	local forwards = drive(wrongWay, 0.04, TAU + 0.3, 40, 0.1, 0)
	check("driving the GP way round in the Reverse GP never counts a lap", #forwards == 0, #forwards)
end

do -- reversing over the line and going again
	local t = timer()
	local _, now = drive(t, -0.04, 0.5, 40, 0.1, 0) -- started
	local back, now2 = drive(t, 0.5, -0.3, 10, 0.1, now)
	local again, now3 = drive(t, -0.3, 0.5, 40, 0.1, now2)
	check("driving back over the line and forwards again is not a lap", #back == 0 and #again == 0, #back + #again)
	local lap = drive(t, 0.5, TAU + 0.2, 40, 0.1, now3)
	check("the lap still ends at the line", lap[1] and lap[1].kind == "lap", lap[1] and lap[1].kind)
end

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then
	error("racing tests failed")
end
