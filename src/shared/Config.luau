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

-- The garage builds itself (src/server/GaragePlan.luau): a free plot is a building site, and
-- each piece goes up once the team has made `at` purchases this season, clearing away the
-- site prop it replaces. `keep` pieces stand from the start of later seasons, so a new season
-- opens in the finished shell and builds the extras again.
export type GaragePiece = { name: string, label: string, at: number, keep: boolean?, clears: string? }
Config.GaragePieces = {
	{ name = "Floor", label = "Epoxy floor", at = 1, keep = true, clears = "Cones" },
	{ name = "BackWall", label = "Back wall", at = 2, keep = true, clears = "Scaffold" },
	{ name = "SideWalls", label = "Side walls", at = 4, keep = true, clears = "Fence" },
	{ name = "Livery", label = "Team colours", at = 6, keep = true, clears = "SiteSign" },
	{ name = "Awning", label = "Awning", at = 8, keep = true },
	{ name = "Lights", label = "Floodlights", at = 10 },
	{ name = "PitWall", label = "Pit wall", at = 12 },
	{ name = "Kit", label = "Tyres and tools", at = 14 },
	{ name = "UpperDeck", label = "Upper deck", at = 16 },
} :: { GaragePiece }
-- from this season (0 = the first) the garage takes its night look: graphite and neon
Config.NightGarageSeason = 2

-- Sounds and music, from Roblox-licensed libraries only (APM Music, Pro Sound Effects), so
-- any experience may play them. `python tools/studio-test/run.py PLACE --audio` checks every
-- id here belongs to one of those libraries, and lists more to choose from.
Config.Audio = {
	click = 9119717523, -- Pro Sound Effects: Switch Click On Or Off Toggle Button 2
	cash = 9113728625, -- Pro Sound Effects: Cash Register 1
	buy = 9113728756, -- Pro Sound Effects: Cash Register 5
	build = 9120716440, -- Pro Sound Effects: Whoosh Fast Swish By 4
	engine = 9113002130, -- Pro Sound Effects: 1992 Pontiac Grand Prix Race Car 1 (looped, pitched by speed)
	skid = 9120399077, -- Pro Sound Effects: Vehicle Skids Long Heavy Tire Squeal 3
	light = 9117060347, -- Pro Sound Effects: Nasa Transmission Beep 1 (each start light)
	go = 9117060368, -- Pro Sound Effects: Nasa Transmission Beep 3 (lights out)
	-- APM Music: Windows Down (Kosinus), Racing Mind (Thomas Balmforth), Big League (c)
	-- (Sacha Collisson), Rock Driver (Richard Myhill)
	music = { 9044706933, 1836950435, 1837768143, 1840321341 },
}

-- Rare parts, the way the biggest Roblox games use rarities and mutations: now and then a
-- press stamps a Gold or Rainbow part worth many times more, glowing on the line (a Rainbow is
-- announced to the whole server). Together they add about 11% to income (tests/Rarity.spec.luau).
Config.RareParts = {
	{ name = "Gold", chance = 1 / 60, mult = 5 },
	{ name = "Rainbow", chance = 1 / 600, mult = 25 },
} :: { { name: string, chance: number, mult: number } }

-- Live events: every few minutes the whole server gets one at the same time, so there is
-- always something about to happen. incomeMult multiplies earnings, rareMult the rare chances.
Config.Events = {
	everyMinutes = 12,
	list = {
		{ name = "Safety car", seconds = 90, incomeMult = 2, rareMult = 1, text = "every part pays double" },
		{ name = "Gold rush", seconds = 120, incomeMult = 1, rareMult = 5, text = "rare parts five times as likely" },
	},
}

-- Pit crew (src/server/Crew.luau), the way the biggest Roblox games use pets: after
-- `unlockPurchases` machines a team can open crew crates for cash. Each crate hires one member
-- (rarity first, then a member of that rarity); the best `slots` members work in the garage,
-- stand by the car and add their boosts. They stay through new seasons. A crate costs
-- `minutes` of the factory's income before crew boosts (at least `floor` times the season
-- multiplier), so it is worth the same at every stage. income = +share of income; rare =
-- multiplies the rare-part chances. tests/Crew.spec.luau checks the odds and the boosts.
Config.Crew = {
	slots = 3,
	unlockPurchases = 5,
	crate = { minutes = 5, floor = 300 },
	-- Scout's pick: one member on offer at a fixed price (`crates` times the crate price, by
	-- rarity), the same pick in every server, changing every `minutes`; each team may hire it
	-- once. `weights` = how often each rarity is the pick. A pick costs fewer crates than
	-- hunting that member with crates would (tests/Crew.spec.luau).
	pick = { minutes = 10, weights = { 0.35, 0.35, 0.22, 0.08 }, crates = { 2, 5, 14, 35 } },
	rarities = { -- commonest first; colours as RGB
		{ name = "Common", chance = 0.62, colour = { 190, 196, 204 } },
		{ name = "Rare", chance = 0.27, colour = { 60, 150, 255 } },
		{ name = "Epic", chance = 0.09, colour = { 180, 90, 255 } },
		{ name = "Legendary", chance = 0.02, colour = { 255, 196, 40 } },
	} :: { { name: string, chance: number, colour: { number } } },
	members = {
		{ key = "fitter", name = "Tyre fitter", rarity = 1, income = 0.05, prop = "tyre" },
		{ key = "mechanic", name = "Mechanic", rarity = 1, income = 0.05, prop = "wrench" },
		{ key = "lollipop", name = "Lollipop marshal", rarity = 1, income = 0.05, prop = "lollipop" },
		{ key = "engineer", name = "Race engineer", rarity = 2, income = 0.12, prop = "headset" },
		{ key = "strategist", name = "Strategist", rarity = 2, income = 0.12, prop = "clipboard" },
		{ key = "aero", name = "Aero designer", rarity = 3, income = 0.25, prop = "wing" },
		{ key = "analyst", name = "Data analyst", rarity = 3, income = 0.1, rare = 2, prop = "laptop" },
		{ key = "principal", name = "Team principal", rarity = 4, income = 0.6, prop = "headset" },
	} :: { { key: string, name: string, rarity: number, income: number, rare: number?, prop: string } },
}

-- Garage likes (src/server/Likes.luau): once a day each player may like another team's garage
-- at its sign; the liked team gets `minutes` of its income (at least `floor` times its multiplier).
Config.Likes = { minutes = 1, floor = 50 }

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
-- Goals, one at a time in this order (src/server/Goals.luau); each pays `minutes` of income
-- (at least `floor` times the season multiplier) when met. Kinds: banks, purchases (this
-- season), laps (clean), earned (factory, all seasons), lapUnder (n = seconds), trophy,
-- season (n = new seasons started), crew (n = members hired). tests/Goals.spec.luau checks
-- they can all be met.
Config.Goals = {
	{ kind = "banks", n = 1, text = "Bank your first cash", minutes = 1, floor = 30 },
	{ kind = "purchases", n = 2, text = "Buy 2 machines", minutes = 2, floor = 60 },
	{ kind = "laps", n = 1, text = "Drive a clean lap", minutes = 2, floor = 100 },
	{ kind = "purchases", n = 5, text = "Buy 5 machines", minutes = 3, floor = 200 },
	{ kind = "crew", n = 1, text = "Hire your first crew member", minutes = 3, floor = 300 },
	{ kind = "earned", n = 10000, text = "Earn $10K", minutes = 3, floor = 300 },
	{ kind = "lapUnder", n = 25, text = "Lap in under 0:25", minutes = 4, floor = 400 },
	{ kind = "purchases", n = 10, text = "Buy 10 machines", minutes = 4, floor = 500 },
	{ kind = "laps", n = 10, text = "Drive 10 clean laps", minutes = 5, floor = 500 },
	{ kind = "earned", n = 1000000, text = "Earn $1M", minutes = 5, floor = 500 },
	{ kind = "trophy", n = 1, text = "Win the Constructors' trophy", minutes = 6, floor = 1000 },
	{ kind = "season", n = 1, text = "Start season 2", minutes = 6, floor = 1000 },
	{ kind = "lapUnder", n = 21, text = "Lap in under 0:21", minutes = 8, floor = 1000 },
	{ kind = "earned", n = 50000000, text = "Earn $50M", minutes = 8, floor = 1000 },
	{ kind = "season", n = 2, text = "Start season 3", minutes = 10, floor = 2000 },
	{ kind = "lapUnder", n = 18, text = "Lap in under 0:18", minutes = 10, floor = 2000 },
	{ kind = "season", n = 3, text = "Start season 4", minutes = 12, floor = 2000 },
} :: { { kind: string, n: number, text: string, minutes: number, floor: number } }

-- A gift for staying: every `everyMinutes` played this visit, one claimable gift of
-- `minutes` of income (at least `floor` times the season multiplier). They don't pile up.
Config.Gift = { everyMinutes = 10, minutes = 3, floor = 150 }

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
	reverseFromSeason = 1, -- the Reverse GP (the same circuit the other way) opens in season 2
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
Config.LapBoardReverseName = "PitLaneTycoon_BestLapReverse_v1"

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
