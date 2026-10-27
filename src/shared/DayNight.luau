--!strict
-- Pure clock policy, shared with plain-Luau tests. Hours use Roblox's 24-hour clock.
local DayNight = {}
DayNight.SecondsPerDay = 20 * 60
DayNight.Dusk = 18
DayNight.Dawn = 6

function DayNight.advance(clock: number, elapsed: number, frozen: boolean): number
	return (clock + (if frozen then 0 else math.max(0, elapsed) * 24 / DayNight.SecondsPerDay)) % 24
end

function DayNight.isNight(clock: number): boolean
	local hour = clock % 24
	return hour >= DayNight.Dusk or hour < DayNight.Dawn
end

function DayNight.frozen(configured: boolean, studio: boolean, photo: boolean): boolean
	return configured or (studio and photo)
end

return DayNight
