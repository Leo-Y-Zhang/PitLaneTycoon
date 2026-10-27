# Studio test

## Automatic

With Roblox Studio installed and signed in (Windows):

    python tools/studio-test/run.py PitLaneTycoon.rbxlx --shots shots

It installs a test plugin, opens the place, and plays it through StudioTestService: the
player joins, gets a named garage, parts drop and reach scrutineering (moved by the server, not
the player's computer), the blue pad banks the cash, the Bracket press is bought for $60,
income rises to $210/min, the next pad lights up, a pad you cannot afford refuses to sell, and
the Faster conveyor lifts income to $326/min. On the player's side it checks the guide line
to the next pad, the Next bar, that the buttons sit clear of a phone's thumbstick, that the
sound loads and that banking shows a +$ pop-up. It prints PASS or FAIL for each step and any
errors the game logged, then removes the plugin. It never publishes anything. The latest place
file is a CI artifact (`PitLaneTycoon-place`) on every run.

With `--shots DIR`, the smoke run saves `tracker.png` as well as the existing
`studio-play.png`. After the server checks the welcome card and gift countdown, it creates
`PLT_TrackerShot` and waits. The client closes the welcome card and fires `Welcomed` without
dismissing the tutorial, waits for the visible `FirstSteps` card to say `FIRST STEPS  1 / 5`,
and checks its bounds against the goal panel, bottom-left thumbstick area and desktop player
list. It prints `[PLT-TEST] SHOT tracker` and holds that state for six seconds before signalling
the server to continue. `run.py` reads the named marker and captures the Studio window to
`DIR/tracker.png`; the later bare `SHOT` still saves `DIR/studio-play.png` with the crew panel
open. The server cannot buy a machine or start the drive/crew stages during the tracker shot.

A new player gets the welcome card, and buying a machine puts it away. A collected Gold part
goes into the team's collection case, and the sign carries a Like prompt (likes between two
players can't be played in a one-player Studio test; `tests/Likes.spec.luau` checks the rules). A live event started by
the test (a short Safety car) doubles income, shows on its strip and ends on time; a forced Gold
part glows and is worth five times a normal one. The pit crew stays closed after one purchase;
the test opens it (`PLT_Crew`, which also pays for ten crates) and the player's side hires four:
each crate costs the same however good the crew, a fifth crate straight after is refused, the
best three stand by the car, income rises by exactly their boost, and the panel shows every
member and the odds. Scout's pick is on offer with its end time; the test makes it a Mechanic
(`PLT_Pick`), the strip shows it with a countdown, it costs two crates and hires once. (The speed readout check failed twice in four
runs on 25 Oct 2026 while the car demonstrably reversed in the others: the test's brake input
is flaky, not the game.)

Sound: every effect and music track loads, music plays, the music setting turns it off and on
again, the settings button sits top left, buttons respond to the pointer, and (screen unlocked)
the top bar stays clear of the player list. `run.py --audio` checks every id in `Config.Audio`
belongs to a Roblox-licensed library (it failed on a build without `Config.Audio`).

Goals: the first goal is to bank cash, banking meets it and shows "Buy 2 machines", two
machines show "Drive a clean lap", and the lap shows "Buy 5 machines"; the panel shows the
current goal. The first gift is ten minutes away, its button counts down, and claiming early
is refused. After the drive, a code typed as " pitlane " pays, pays only once, a wrong code is
turned down, and the code list is nowhere players can read it.

The garage: a first-season garage has the day look; the first press is a stamping press with a
die and makes bolts (each press makes its own part). A free plot is a building site and so is a
new team's; the first purchase lays
the floor and clears the cones, the second raises the back wall and takes the scaffolding down.

Then the time trial: the track, the show car's Drive prompt and the Fastest laps board are
there; Race seats the player in their own car, which their computer drives; holding the brake
reverses it (the driving script and the car's motors work); the test then laps the car along
the centre line at 50 studs/s and checks the server timed it (length / 50 to within 5%), paid
for it and made it the best lap, that cutting across the infield voids the next lap, and that
jumping out returns the player to their garage. On screen: the Race button becomes Leave car,
the lap panel shows, the start lights count down and go out for GO, the engine runs, the speed
shows in km/h while reversing, and the lap clock runs.

It also checks that the onboarding funnel logs the join and the first purchase, and that the
game logged no warnings of its own (a failing save or analytics call warns). Lock the screen
and Studio draws its viewport 1 px tall: the server checks still hold, but the client layout
check fails and screenshots come out empty, so run.py says when the screen is locked.

Studio runs on 24 Oct 2026: 19/19 checks passed and the game logged no errors.

`run.py PLACE --photos --shots DIR` builds every machine and garage piece, checks a full garage
earns what the HUD says, takes six pictures (four of the garage, the race car at the start
gantry, the track) and prints a PERF line: the server's step time, physics rate and part counts.
It ends with a Reverse GP lap (the photo garage is in season 2) and checks the server timed it
and kept it apart from the Grand Prix best, then a picture of the car on the Endurance grid
(`endurance`; the photo run opens every layout) and an Endurance lap, also timed by the server. On 25 Oct 2026 with one full garage: 60 physics steps a second (worst step 20 ms), 1,492 parts.

Saving across servers can't be played in Studio (an unpublished place has no DataStore), so the
lock is tested on its own: `luau tests/SaveLock.spec.luau` (CI runs it) plays a server hop, a
crashed server, a server that comes back after losing its lock, a late save after leaving, a
failing store and a player who leaves while waiting. `luau tests/Racing.spec.luau` checks that
the track clears every garage and has no bend under 40 studs, that the car reaches top speed,
brakes, reverses, slows on grass and steers the right way, and that lap timing is accurate
(also with uneven samples), voids cut and teleported laps and does not count reversing over the
line. Five deliberate bugs (no teleport check, laps counted backwards, no nearest-point search,
steering reversed, a track through the garages) each failed it on 25 Oct 2026.
`luau tests/Garage.spec.luau` checks the garage plan: a free plot is all building site, the
pieces go up in order and all before the trophy, each site prop is cleared by one piece, and
a new season keeps the shell. `luau tests/Layout.spec.luau` checks the top bar stays clear of
the player list and the settings button in every computer window from 640 px wide, stays
centred on phones, and that the left buttons end above the thumbstick. `luau tests/Goals.spec.luau` checks every goal can be met where
it stands in the chain (purchase goals within a season's line, lap times within reach of that
season's car), how progress is counted, and that codes are well formed and not in the shared
Config.

## By hand

Do this in Roblox Studio after a big change, and note anything that fails.

1. Open `PitLaneTycoon.rbxlx` from the latest release and press **Play**.
2. You should land on your garage, facing a red pad, with a yellow line leading to it.
   **Check:** six garages around the spawn; a sign with your name on yours; the top bar shows
   `$100` (the first daily reward), `+$60/min` and `Next: Bracket press - ready`.
3. **Within 3 seconds** a grey part drops from the Bolt press and rides the conveyor to the green
   scrutineering block. **Check:** "Collect $..." rises on the blue pad.
4. Walk onto the **blue pad**. **Check:** the top bar's cash goes up, a green `+$...` rises
   above you, and the pad resets to $0.
5. Collect $60 and step on the **red pad** (Bracket press). **Check:** a second press appears
   with a burst of sparks, the next red pad lights up, and a "Bought Bracket press" message
   shows.
6. **Phone layout:** in Studio's Test tab, open Device and pick a phone in landscape. **Check:**
   the top bar, Shop button and shop window fit on screen and the Shop button is not in the
   bottom-left corner where the thumbstick goes.
7. Open **Shop**. **Check:** it says the shop opens soon (no pass ids are set yet).
8. Press **Race**. **Check:** you sit in your team's car on the grid behind the chequered line,
   and a lap panel says "Out lap". Drive with WASD: the car accelerates, steers, slows on the
   grass, and the clock starts at the line. Finish a lap on the road: a "Lap 0:.." message and a
   +$ pop-up. Press Space: you are back at your garage. On a phone layout (step 6), drive with
   the thumbstick.
9. **Saving** only works on a published place: File > Publish to Roblox, then Game Settings >
   Security > Enable Studio Access to API Services. Play, earn some cash, stop, Play again.
   **Check:** your cash and machines come back.

To speed up testing, temporarily change `cost` values in `src/shared/Config.luau` (for example
the trophy to 500) and rebuild; change them back afterwards.

If something fails, copy the red error lines from the Output window (View > Output) into a
message: that is enough to fix it.
