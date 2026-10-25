--!strict
-- Pit Lane Tycoon: every number a designer would tune lives here.

local Config = {}

-- Game pass and developer product ids. Create them on the Creator Dashboard
-- (Monetization) after publishing, paste the ids here, and rebuild. 0 = not set up yet:
-- the shop hides that item and the server treats nobody as owning it.
Config.Passes = {
	DoubleCash = 0, -- 2x everything the factory earns
	AutoCollect = 0, -- earnings go straight to the bank, no walking to the pad
	VIP = 0, -- 1.25x earnings, gold car, VIP tag
}
Config.Products = {
	-- id = 0 hides the product. Each pack gives `minutes` of the player's current income
	-- (floored at `floor`), so the packs stay worth buying at every stage of the game.
	{ id = 0, name = "Sponsor bonus", minutes = 10, floor = 500 },
	{ id = 0, name = "Title sponsor", minutes = 60, floor = 5000 },
}

-- Production line, bought in order. Each pad appears once the one before it is bought.
-- kind: "press" makes parts, "tune" multiplies one press's parts, "upgrade" multiplies a
-- part's value as it passes, "speed" runs the conveyor and every press faster, "trophy"
-- unlocks the new-season (rebirth) button. `season` = the first season (0-based) an item
-- appears in, so later seasons have machines the first one never had.
-- Pacing: `python tools/balance.py` prints the minutes each purchase takes (CI checks it).
export type Item = {
	key: string,
	name: string,
	cost: number,
	kind: string,
	every: number?, -- press: seconds between parts at the base conveyor speed
	value: number?, -- press: cash per part before multipliers
	x: number?, -- press/upgrade: position along the conveyor (studs from its centre)
	mult: number?, -- tune/upgrade: value multiplier
	speed: number?, -- speed: conveyor studs per second
	target: string?, -- tune: the press it improves
	season: number?, -- first season it appears in (default 0)
}

Config.Items = {
	{ key = "press1", name = "Bolt press", cost = 0, kind = "press", every = 2.0, value = 2, x = -16 },
	{ key = "press2", name = "Bracket press", cost = 60, kind = "press", every = 2.0, value = 5, x = -11 },
	{ key = "speed1", name = "Faster conveyor", cost = 150, kind = "speed", speed = 14 },
	{ key = "press3", name = "Wishbone press", cost = 400, kind = "press", every = 1.8, value = 12, x = -6 },
	{ key = "tune1", name = "Bolt press Mk II", cost = 1900, kind = "tune", target = "press1", mult = 3 },
	{ key = "up1", name = "Paint shop (x2)", cost = 2500, kind = "upgrade", mult = 2, x = 6 },
	{ key = "press4", name = "Gearbox line", cost = 5500, kind = "press", every = 1.6, value = 30, x = -1 },
	{ key = "tune2", name = "Bracket press Mk II", cost = 15000, kind = "tune", target = "press2", mult = 3 },
	{ key = "up2", name = "Wind tunnel (x1.5)", cost = 19000, kind = "upgrade", mult = 1.5, x = 11 },
	{ key = "speed2", name = "Pit-crew conveyor", cost = 30000, kind = "speed", speed = 20 },
	{ key = "press5", name = "Carbon-fibre autoclave", cost = 46000, kind = "press", every = 1.5, value = 90, x = 4 },
	{ key = "tune3", name = "Wishbone press Mk II", cost = 130000, kind = "tune", target = "press3", mult = 3 },
	{ key = "up3", name = "Brake dyno (x2)", cost = 160000, kind = "upgrade", mult = 2, x = 16 },
	{ key = "press6", name = "Power-unit bench", cost = 330000, kind = "press", every = 1.4, value = 220, x = -19 },
	{ key = "tune4", name = "Gearbox line Mk II", cost = 850000, kind = "tune", target = "press4", mult = 3 },
	{ key = "speed3", name = "Race-spec conveyor", cost = 1000000, kind = "speed", speed = 26 },
	{ key = "tune5", name = "Autoclave Mk II", cost = 1400000, kind = "tune", target = "press5", mult = 3 },
	{ key = "up4", name = "Simulator (x2)", cost = 2000000, kind = "upgrade", mult = 2, x = 20.5 },
	{ key = "tune6", name = "Power-unit bench Mk II", cost = 4200000, kind = "tune", target = "press6", mult = 3 },
	{ key = "up5", name = "Telemetry (x2)", cost = 6500000, kind = "upgrade", mult = 2, x = 13.5, season = 1 },
	{ key = "tune7", name = "Autoclave Mk III", cost = 12000000, kind = "tune", target = "press5", mult = 2, season = 1 },
	{ key = "up6", name = "Hybrid power (x2)", cost = 20000000, kind = "upgrade", mult = 2, x = 8.5, season = 2 },
	{ key = "tune8", name = "Power-unit bench Mk III", cost = 40000000, kind = "tune", target = "press6", mult = 2, season = 2 },
	{ key = "trophy", name = "Constructors' trophy", cost = 9200000, kind = "trophy" },
} :: { Item }

Config.BaseConveyorSpeed = 9
Config.PartLifetime = 25 -- seconds before an uncollected part is cleared

-- New season (rebirth): wipes cash and the line, keeps a permanent multiplier.
Config.SeasonBonus = 0.5 -- each season adds +50% to all earnings
Config.SeasonCostBase = 9000000
Config.SeasonCost = function(season: number): number
	return Config.SeasonCostBase * (season + 1)
end

-- Daily reward: a streak keeps players coming back. Day n pays the larger of cash[n] times
-- the season multiplier and minutes[n] of the player's income (n capped at the last day).
Config.DailyRewards = {
	cash = { 100, 250, 500, 1000, 2000, 4000, 8000 },
	minutes = { 1, 2, 3, 5, 8, 12, 20 },
}
Config.DailyCooldownHours = 20
Config.StreakBreakHours = 48

-- Friends boost: each friend in the same server adds +10% (up to 5), so players bring friends.
Config.FriendBoost = 0.1
Config.FriendBoostMax = 5

-- Offline earnings: a share of the income rate at the last save, for up to capHours away.
Config.Offline = { share = 0.25, capHours = 8, minMinutes = 5 }

-- Happy hour: 2x earnings at the same time every weekend, so players gather (UTC; os.date
-- wday 1 = Sunday, 7 = Saturday). 18:00 UTC is 19:00 in UK summer time.
Config.HappyHour = { days = { 7, 1 }, startHourUtc = 18, hours = 1, mult = 2 }

-- Time trial: a track round the paddock (src/shared/TrackShape.luau). In polar coordinates
-- about the spawn the centre line is radius + amplitude * sin(frequency * angle + phase) for
-- each wave; it must clear the garages (tests/Racing.spec.luau checks it). limit = how far
-- from the centre line a car may stray before the lap stops counting.
Config.Track = {
	radius = 175,
	waves = { { 22, 3, 0.3 }, { 10, 5, 1.0 }, { 4, 8, 0.2 } },
	halfWidth = 8,
	limit = 13,
}
-- The race car (src/shared/DriveModel.luau). Speeds in studs per second; it gets faster
-- every season. A clean lap pays lapRewardMinutes of income, a new best lap bestLapMinutes
-- more, so driving pays a little while the factory keeps earning.
Config.Drive = {
	topSpeed = 65, perSeason = 5, maxTopSpeed = 95,
	accel = 24, brake = 70, drag = 10, reverse = 16, turnRate = 1.2, grip = 6, offroadShare = 0.45,
	lapRewardMinutes = 0.25, lapRewardFloor = 20, bestLapMinutes = 2,
}
Config.LapBoardName = "PitLaneTycoon_BestLap_v1"

-- Leaderboard of factory earnings across all seasons (bought cash and rewards don't count).
Config.LeaderboardName = "PitLaneTycoon_Earned_v1"
Config.LeaderboardSize = 10
Config.LeaderboardRefreshSeconds = 120

Config.AutosaveSeconds = 60
-- Session locking (src/server/SaveLock.luau): a server holding a save refreshes its lock at
-- every autosave, so a lock older than staleSeconds belongs to a server that crashed. A
-- server hop normally waits one retry; stale must stay well above AutosaveSeconds.
Config.SaveLock = { staleSeconds = 150, retrySeconds = 6, giveUpSeconds = 300 }
Config.DataStoreName = "PitLaneTycoon_v1"
Config.PlotCount = 6
Config.PlotRadius = 90

return Config
