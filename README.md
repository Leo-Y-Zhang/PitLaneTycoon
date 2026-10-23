# Pit Lane Tycoon

A Roblox incremental tycoon. You run a racing team's factory: presses stamp out car parts, the
conveyor carries them through the paint shop and wind tunnel to scrutineering, and every part
that passes earns cash for the next machine. Win the Constructors' trophy, then start a new
season: the garage resets, but every season adds +50% to all earnings for good.

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
| The map, the production line, money, saving, purchases | `src/server/Tycoon.server.luau` |
| The on-screen HUD and shop | `src/client/Hud.client.luau` |

Build the place file: `rojo build default.project.json -o PitLaneTycoon.rbxlx`.
Live-sync while editing: `rojo serve`, with the Rojo plugin connected in Studio.

CI checks that every Luau file compiles and that the place file builds.
