# Pit Lane Tycoon

A Roblox incremental tycoon. You run a racing team's factory: presses stamp out car parts, the
conveyor carries them through the paint shop, wind tunnel and the rest to scrutineering, and
every part that passes earns cash for the next machine. Twenty-four purchases later (about an
hour) you win the Constructors' trophy and can start a new season: the garage resets, every
season adds +50% to all earnings for good, and seasons 2 and 3 bring machines the first one
never had.

The garage builds itself as you go: a free plot is a building site, and every few purchases
another piece rises out of the floor, from the epoxy floor and walls to floodlights, a pit wall
and an upper deck with a glass front. From the third season it takes a night look: graphite
walls and team colours that glow.

After five machines the pit crew opens: crates bought with cash hire crew members by rarity
(Common to Legendary, odds on the panel), and the best three stand round the car adding income
or rare-part luck, kept through every season. Scout's pick offers one member at a fixed price,
the same in every server, new every 10 minutes.

A goal panel always shows the next thing to aim for (bank, buy, hire, lap, earn, beat a lap
time, win the trophy, start a season) and pays when it is met; a gift waits every 10 minutes played;
codes typed in the shop pay once each. Rare Gold and Rainbow parts turn up on the line, and every
12 minutes the whole server gets a live event (Safety car, Gold rush).

Between purchases, take your team's car out on the time-trial track round the paddock (the
Race button, or Drive at the show car). The server times every lap, a clean lap pays, and the
fastest laps go on a board at the spawn. The car gets faster every season, and from season 2
the Reverse GP runs the circuit the other way round.

All of it is code (Luau, synced with [Rojo](https://rojo.space)). The map is built by the
server at start-up, so the place file needs nothing made by hand.

## Open it in Roblox Studio

1. Download `PitLaneTycoon.rbxlx` from this repository's latest release (or build it: see below).
2. Double-click it to open in Roblox Studio, then press Play to try it.
3. To publish: File, Publish to Roblox, then in Game Settings > Security turn on
   "Enable Studio Access to API Services" so progress saves.

## Make money from it

After publishing, create the passes and products on the Creator Dashboard (your experience >
Monetization), paste their ids into `src/shared/Config.luau`, and rebuild. Items with id 0 stay
hidden, so the game is safe to publish before the shop is set up. Prices and the launch plan are
in [docs/LAUNCH.md](docs/LAUNCH.md).

## Change it

| What | Where |
|---|---|
| Prices, machines, multipliers, season cost, daily rewards, pass ids | `src/shared/Config.luau` |
| How long each purchase and season takes | `python tools/balance.py` (reads the config) |
| The map, the production line, money, saving, purchases | `src/server/Tycoon.server.luau` |
| Session-locked saves (no lost progress on a server hop) | `src/server/SaveLock.luau` |
| Goals (chain in `Config.Goals`) / redeem codes (server only) | `src/server/Goals.luau` / `src/server/Codes.luau` |
| The pit crew: crate odds, who works, boosts, Scout's pick (members in `Config.Crew`) | `src/server/Crew.luau` |
| Which garage pieces are up / how each piece looks | `src/server/GaragePlan.luau` (plan in `Config.GaragePieces`) / `src/server/Scenery.luau` |
| The track's shape, the car's handling, lap timing | `src/shared/TrackShape.luau`, `src/shared/DriveModel.luau`, `src/server/LapTimer.luau` |
| Cars, the prompt, sampling laps / steering the car | `src/server/Racing.luau` / `src/client/Drive.client.luau` |
| Funnel and economy events for the Creator Dashboard | `src/server/Analytics.luau` |
| The on-screen HUD and shop | `src/client/Hud.client.luau` |
| Music, sounds, settings, button feel / where panels go on each screen | `src/client/Polish.client.luau` / `src/shared/Layout.luau` |

Build the place file: `rojo build default.project.json -o PitLaneTycoon.rbxlx`.
Live-sync while editing: `rojo serve`, with the Rojo plugin connected in Studio.

CI checks that every Luau file compiles and type-checks against the Roblox API, that the place
file builds, that the pacing holds (the first season takes 45-90 minutes and no purchase
more than 8, `tools/balance.py`), and runs the Luau tests in `tests/` (save locking; the
track, the car's handling and lap timing; the garage plan; goals and codes; rare parts and
live events; garage likes; the pit crew; the HUD layout on phones and computer windows).

Sounds and music come only from Roblox-licensed libraries (APM Music, Pro Sound Effects), listed
in `Config.Audio`. `python tools/studio-test/run.py PitLaneTycoon.rbxlx --audio` checks every id
belongs to one of them; add `--search "Sound:tire squeal;Music:rock"` to find more.
