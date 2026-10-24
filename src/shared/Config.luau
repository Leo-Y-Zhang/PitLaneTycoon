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
-- kind: "press" makes parts, "upgrade" multiplies a part's value as it passes,
-- "speed" speeds the conveyor, "trophy" unlocks the new-season (rebirth) button.
export type Item = {
	key: string,
	name: string,
	cost: number,
	kind: string,
	every: number?, -- press: seconds between parts
	value: number?, -- press: cash per part before multipliers
	x: number?, -- press/upgrade: position along the conveyor (studs from its centre)
	mult: number?, -- upgrade: value multiplier
	speed: number?, -- speed: conveyor studs per second
}

Config.Items = {
	{ key = "press1", name = "Bolt press", cost = 0, kind = "press", every = 2.0, value = 2, x = -16 },
	{ key = "press2", name = "Bracket press", cost = 60, kind = "press", every = 2.0, value = 5, x = -11 },
	{ key = "speed1", name = "Faster conveyor", cost = 150, kind = "speed", speed = 14 },
	{ key = "press3", name = "Wishbone press", cost = 400, kind = "press", every = 1.8, value = 12, x = -6 },
	{ key = "up1", name = "Paint shop (x2)", cost = 1200, kind = "upgrade", mult = 2, x = 6 },
	{ key = "press4", name = "Gearbox line", cost = 3500, kind = "press", every = 1.6, value = 30, x = -1 },
	{ key = "up2", name = "Wind tunnel (x1.5)", cost = 9000, kind = "upgrade", mult = 1.5, x = 11 },
	{ key = "speed2", name = "Pit-crew conveyor", cost = 15000, kind = "speed", speed = 20 },
	{ key = "press5", name = "Carbon-fibre autoclave", cost = 30000, kind = "press", every = 1.5, value = 90, x = 4 },
	{ key = "press6", name = "Power-unit bench", cost = 80000, kind = "press", every = 1.4, value = 220, x = -19 },
	{ key = "trophy", name = "Constructors' trophy", cost = 200000, kind = "trophy" },
} :: { Item }

Config.BaseConveyorSpeed = 9
Config.PartLifetime = 25 -- seconds before an uncollected part is cleared

-- New season (rebirth): wipes cash and the line, keeps a permanent multiplier.
Config.SeasonBonus = 0.5 -- each season adds +50% to all earnings
Config.SeasonCost = function(season: number): number
	return 200000 * (season + 1)
end

-- Daily reward: a streak keeps players coming back. Day n pays rewards[min(n, #rewards)]
-- multiplied by the player's season multiplier.
Config.DailyRewards = { 100, 250, 500, 1000, 2000, 4000, 8000 }
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

-- Leaderboard of factory earnings across all seasons (bought cash and rewards don't count).
Config.LeaderboardName = "PitLaneTycoon_Earned_v1"
Config.LeaderboardSize = 10
Config.LeaderboardRefreshSeconds = 120

Config.AutosaveSeconds = 60
Config.DataStoreName = "PitLaneTycoon_v1"
Config.PlotCount = 6
Config.PlotRadius = 90

return Config
