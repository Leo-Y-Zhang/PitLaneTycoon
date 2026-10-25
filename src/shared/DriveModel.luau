--!strict
-- How the race car responds to the pedals and the wheel: arcade handling, worked out one
-- frame at a time. Pure maths, so tests/Racing.spec.luau checks it in CI; the client
-- (Drive.client.luau) turns the result into the car's velocity and turn rate.

local DriveModel = {}

DriveModel.Standstill = 0.1 -- studs per second; slower than this is stopped

export type Handling = {
	accel: number, -- studs/s gained per second at full throttle
	brake: number, -- studs/s lost per second braking
	drag: number, -- studs/s lost per second coasting
	reverse: number, -- top speed backwards
	turnRate: number, -- radians per second at full lock, once moving
	offroadShare: number, -- off the road the car tops out at this share of its top speed
}

-- speed is along the car's nose (negative = reversing); throttle and steer run from -1 to 1
-- as a VehicleSeat reports them. Returns the new speed and the turn rate (radians per
-- second about the vertical; positive turns left).
function DriveModel.step(speed: number, throttle: number, steer: number, dt: number, top: number, offroad: boolean,
	h: Handling): (number, number)
	local cap = if offroad then top * h.offroadShare else top
	-- the physics never measures a car at rest as exactly 0: below a crawl it counts as
	-- stopped, or a held brake would 'brake' a creep of +0.004 back to 0 every frame
	if math.abs(speed) < DriveModel.Standstill then
		speed = 0
	end
	if throttle > 0 then
		if speed < 0 then
			speed = math.min(0, speed + h.brake * throttle * dt)
		elseif speed < cap then
			speed = math.min(cap, speed + h.accel * throttle * dt)
		end
	elseif throttle < 0 then
		if speed > 0 then
			speed = math.max(0, speed + h.brake * throttle * dt)
		else
			speed = math.max(-h.reverse, speed + h.accel * 0.5 * throttle * dt)
		end
	elseif speed > 0 then
		speed = math.max(0, speed - h.drag * dt)
	else
		speed = math.min(0, speed + h.drag * dt)
	end
	if speed > cap then -- ran wide onto the grass: scrub off speed
		speed = math.max(cap, speed - h.brake * 0.6 * dt)
	end
	-- no turning on the spot, and reversing steers the other way round
	local grip = math.min(1, math.abs(speed) / 12)
	local turn = -steer * h.turnRate * grip * (if speed < 0 then -1 else 1)
	return speed, turn
end

-- The start: five red lights come on one a second apart, then after a short hold they all
-- go out and the car may go. Returns how many are lit and whether it is GO.
DriveModel.LightGap = 0.7
function DriveModel.lights(elapsed: number, hold: number): (number, boolean)
	local lit = math.clamp(math.floor(elapsed / DriveModel.LightGap), 0, 5)
	if elapsed >= 5 * DriveModel.LightGap + hold then
		return 0, true
	end
	return lit, false
end

return DriveModel
