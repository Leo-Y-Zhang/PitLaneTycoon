--!strict
-- Times laps from a car's position, which the server samples ten times a second; the
-- player's computer drives the car, so the server never takes its word for a lap time.
--
-- Progress is the angle round the paddock, counted on without wrapping: crossing the start
-- line (angle 0) forwards ends a lap and starts the next, and the crossing time is taken
-- between the two samples either side of it. Driving back over the line and forwards again
-- does not count twice. A lap counts only if the car stayed within the track limits and
-- never moved further between two samples than its top speed allows (a teleport).
--
-- Pure Luau: the track comes in as a function, so tests/Racing.spec.luau runs it in CI.

local LapTimer = {}

local TAU = 2 * math.pi

export type Options = {
	nearest: (number, number) -> (number, number), -- (x, z) -> angle of the nearest centre-line point, distance from it
	limit: number, -- furthest a car may be from the centre line (half the width plus some kerb)
	maxSpeed: number, -- the car's top speed, studs per second
}
export type Event = { kind: string, time: number?, valid: boolean?, reason: string? }
export type Timer = {
	opts: Options,
	u: number?, -- the angle travelled, unwrapped
	line: number, -- the last start line passed, as a count of whole turns
	t: number, x: number, z: number, -- the previous sample
	lapStart: number?, -- when the lap under way began (nil until the car first crosses the line)
	valid: boolean,
	reason: string?,
}

function LapTimer.new(opts: Options): Timer
	return { opts = opts, u = nil, line = 0, t = 0, x = 0, z = 0, lapStart = nil, valid = true, reason = nil }
end

local function spoil(timer: Timer, reason: string)
	if timer.lapStart and timer.valid then
		timer.valid = false
		timer.reason = reason
	end
end

-- Feed one sample (time in seconds, position). Returns nil, or { kind = "start" } the first
-- time the car crosses the line, or { kind = "lap", time, valid, reason } for each lap after.
function LapTimer.sample(timer: Timer, t: number, x: number, z: number): Event?
	local a, dist = timer.opts.nearest(x, z)
	local prev = timer.u
	if prev == nil then
		-- the cars start just behind the line, so read the angle as -pi..pi
		timer.u = if a > math.pi then a - TAU else a
		timer.line = math.floor((timer.u :: number) / TAU)
		timer.t, timer.x, timer.z = t, x, z
		return nil
	end
	local d = (a - prev) % TAU
	if d > math.pi then
		d -= TAU
	end
	local u = prev + d

	if math.abs(dist) > timer.opts.limit then
		spoil(timer, "track limits")
	end
	local moved = math.sqrt((x - timer.x) ^ 2 + (z - timer.z) ^ 2)
	if moved > timer.opts.maxSpeed * 1.5 * (t - timer.t) + 12 then
		spoil(timer, "teleport")
	end

	local event: Event? = nil
	local line = math.floor(u / TAU)
	if line > timer.line then
		local f = (line * TAU - prev) / (u - prev)
		local crossed = timer.t + f * (t - timer.t)
		if timer.lapStart then
			event = { kind = "lap", time = crossed - (timer.lapStart :: number), valid = timer.valid, reason = timer.reason }
		else
			event = { kind = "start" }
		end
		timer.lapStart = crossed
		timer.valid = true
		timer.reason = nil
		timer.line = line
	end
	timer.u, timer.t, timer.x, timer.z = u, t, x, z
	return event
end

return LapTimer
