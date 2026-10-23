# Pit Lane Tycoon

Roblox incremental tycoon in Luau, synced with Rojo. See README.md and docs/LAUNCH.md.

- All tunable numbers live in `src/shared/Config.luau`; the server builds the whole map from code.
- Gate before every push: every `src/**/*.luau` passes `luau-compile`, and
  `rojo build default.project.json -o PitLaneTycoon.rbxlx` succeeds (CI runs both).
- Logic can't be run outside Roblox Studio: say so when a change is untested in Studio.
- Pass/product ids are the owner's to create on the Creator Dashboard; never invent ids.
- Keep the repository private. No real names, emails or account ids in files.
- After a gameplay change, rebuild the place file and attach it to a new GitHub release.
