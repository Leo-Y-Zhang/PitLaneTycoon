# Launch and monetisation plan

Research of 23 October 2026, from public creator guides and earnings trackers (estimates, not
guarantees): simulators and tycoons lead Roblox's revenue charts, and incremental tycoons suit a
solo developer because they need little art and earn through progression passes. Most new games
earn nothing until they are discovered, so the plan below is about retention first, then traffic.

## Why this design

- **The core loop pays every few seconds** (presses → conveyor → cash), and the next purchase pad
  is always the one glowing, so players never wonder what to do.
- **A first season of about an hour** (24 purchases, none longer than 8 minutes; check with
  `python tools/balance.py`), then shorter seasons that each add machines.
- **Retention:** new seasons (rebirth) with a permanent multiplier, and a daily streak (day 7
  pays $8,000 times the season multiplier or 20 minutes of income, whichever is more). These
  are the levers that bring players back, which is what Roblox's recommendations reward.
- **Phones first:** most Roblox players are on phones, so the HUD shrinks to fit a phone held
  sideways and keeps its buttons clear of the thumbstick.
- **Monetisation that does not block free players:** passes speed things up; nothing is locked.

## Prices to start with (Robux)

| Item | Type | Price | Why |
|---|---|---|---|
| Auto-collect | Game pass | 99 | The cheapest impulse buy; removes the walk to the blue pad |
| 2x Cash | Game pass | 199 | The standard best-seller in tycoons |
| VIP | Game pass | 299 | 1.25x on top of everything, plus status |
| Sponsor bonus (10 min of income) | Developer product | 25 | Repeatable, scales with progress |
| Title sponsor (60 min of income) | Developer product | 99 | The bigger repeatable |

Roblox keeps 30% of each sale. Change prices after a week of data, not before.

## Only you can do these

Everything else is built and tested; these need your account, your ears or other people.

- **Play it yourself in Studio** with a keyboard: drive a few laps (does the handling feel
  right?), listen to the four music tracks and the sounds (none of them has been heard yet),
  and turn on Studio's phone emulator (Test > Device) to try the thumbstick.
- **Publish** under a group (step 2 below), with Max Players 6 and Studio API access on, then
  play the published game once to check saving across a leave and rejoin.
- **A full server:** invite five friends into one server for ten minutes. The server held 60
  physics fps with one full garage in Studio (5,423 parts), with a worst server step of
  20.6 ms; six full garages and six cars have only been estimated, not seen.
- **Passes, products and the group** (step 4) and the **Maturity questionnaire**.
- **Announce the launch code** `PITLANE` in the game description.

## Launch steps

1. **Before publishing:** play it solo in Studio for a full season; check that saving works
   once API access is on (leave and rejoin).
2. **Publish under a group, not your own account.** Create a group (Roblox > Groups > Create, 100
   Robux) with a game-style name, never your real name, and publish the place to the group. The
   game page then shows the group as the creator instead of your username (the group page still
   lists its owner). Earnings land in group funds; pay them to yourself from the group's Revenue
   page before DevEx. Fill in the Maturity & Compliance questionnaire (needed before it can be
   public) and set the genre to Simulation/Tycoon. Set the place's **Max Players to 6**: there
   are six garages, and a seventh player would have none.
3. **Icon and thumbnails** matter more than anything else for clicks: a bright car on a
   conveyor, big readable title, no small text. Ready-made ones are in `marketing/`
   (`icon.png` 512x512, `thumbnail-1..5.png` 1280x720); upload all five thumbnails so Roblox
   rotates them. They contain no avatar or username. To remake them after a visual change:
   `python tools/studio-test/run.py PitLaneTycoon.rbxlx --photos --shots shots` then
   `python tools/studio-test/thumbnails.py shots marketing`.
4. **Create the passes and products**, paste the ids into `Config.luau`, rebuild, republish.
5. **First traffic:** share with friends for the first concurrent players; then a small Sponsored
   Experience campaign (Ads Manager) once Day-1 retention looks healthy. Do not spend on ads
   before the game keeps players.
6. **Update weekly:** new machines, a new upgrade, a limited-time event. Update logs in the
   game description bring returning players.
7. **Read the numbers** on the Creator Dashboard under Analytics, a day or two after the first
   players. *Funnels > Onboarding* shows how many players reach each step: Joined, First
   purchase, 5, 10 and 15 purchases, Constructors' trophy, New season. The biggest drop
   between two steps is the next thing to fix. *Economy* shows cash in (factory, daily streak,
   offline pay, Robux packs) and out (each machine by its key, new seasons).

## Getting paid (DevEx)

Earned Robux can be cashed out through the Developer Exchange once you have at least 30,000
earned Robux (about USD 114 at the standard rate), are 13 or older with ID verified on your
Roblox account, and have the DevEx portal and tax form set up. Under 18, a parent or guardian
handles the tax and payment setup with you. Check the current rules on create.roblox.com
before applying.

## Built to bring players back (24 Oct 2026)

- **Friends boost:** +10% earnings for each friend in the same server, up to +50%, shown in the
  top bar. Players invite friends, which is how new games get found.
- **Offline earnings:** coming back after 5 minutes or more pays 25% of the income rate at the
  last save, for up to 8 hours away.
- **Leaderboard** at the spawn: top 10 by factory earnings across all seasons (bought cash and
  rewards don't count, so it can't be bought). The game's owner is never shown on it.
- **Happy hour:** 2x earnings every Saturday and Sunday at 18:00 UTC (19:00 UK summer time,
  18:00 in winter), so players gather at the same time. Mention it in the description.
- **Rare parts and live events (25 Oct 2026),** after what the biggest Roblox games do
  (Grow a Garden's mutations, Steal a Brainrot's rare finds, frequent server-wide events). Now
  and then a press stamps a Gold (5x, 1 in 60) or Rainbow (25x, 1 in 600) part that glows down
  the line; a Rainbow is announced to the whole server. Every 12 minutes the server gets a live
  event for everyone at once: Safety car (every part pays double for 90 s) or Gold rush (rare
  parts five times as likely for 2 min), on a chequered strip under the top bar. Rare parts add
  about 11% to income on average; `tests/Rarity.spec.luau` keeps it between 5 and 15%.
- **A collection case and garage likes (25 Oct 2026):** every Gold and Rainbow part a team
  collects goes into a glass case at the back of its garage (kept across seasons), so rare luck
  stays on show. Other players can like a garage at its sign once a day; the team gets a minute
  of income and a heart count on its sign, which gives players a reason to visit each other.
- **A pit crew (25 Oct 2026),** the Pit Lane take on the pets in Grow a Garden and Pet
  Simulator: after 5 machines a team can open crew crates for cash. Each hires one member by
  rarity (Common 62%, Rare 27%, Epic 9%, Legendary 2%, odds on the panel): tyre fitters,
  mechanics and lollipop marshals (+5% income), race engineers and strategists (+12%), an aero
  designer (+25%), a data analyst (rare parts twice as likely) and the team principal (+60%).
  The best three stand round the show car with the kit of their job and stay through new
  seasons; a Legendary is announced to the whole server. A crate costs 5 minutes of income
  before crew boosts, so it never gets dearer as the crew improves. Three principals, the
  ceiling, make 2.8x income (`tests/Crew.spec.luau` keeps it under 3x).
- **Scout's pick (25 Oct 2026),** the restocking shop of Grow a Garden for the crew: one
  member on offer at a fixed price at the top of the crew panel, the same in every server and
  new every 10 minutes, with a countdown. It costs 2, 5, 14 or 35 crates by rarity, fewer than
  hunting that member with crates would take, and each team may hire it once per pick. A
  Legendary is the pick about one time in twelve, which is worth a line in the description.
- **A welcome card (25 Oct 2026):** a first visit opens with three lines on how the game works
  (the conveyor earns, bank on the blue pad and buy on the red, Race any time) until the player
  presses Let's go or buys their first machine. The guide line, the Next bar and the first goal
  then take over.
- **Sound and feel (25 Oct 2026):** four APM Music tracks in a shuffled loop; Pro Sound Effects
  clicks, cash registers and a swish as each garage piece rises (all Roblox-licensed, checked
  with `run.py --audio`). A settings button (top left) turns music and sounds on or off, kept
  with the save. Buttons grow under the pointer and dip when pressed. On a computer the top
  bar moves left in a narrow window, so Roblox's player list no longer covers it.
- **Goals, gifts and codes (25 Oct 2026):** a goal panel shows one goal at a time from a chain
  of 17 (bank your first cash, buy 2 machines, drive a clean lap, ... start season 4); each
  pays a few minutes of income, so there is always a next step. A gift can be claimed every 10
  minutes played (they don't pile up, so players come back to the panel). Codes are typed in
  the shop and pay once per player; they live in `src/server/Codes.luau`, on the server, so
  players can't read them. Start with `PITLANE` for the launch and put it in the description;
  add a new code for each update or milestone (1K likes, 100K visits) and remove old ones.
- **The garage builds itself (25 Oct 2026):** a free plot is a building site (cones,
  scaffolding, orange fencing, an under-construction sign). Purchases 1, 2, 4, 6, 8, 10, 12, 14
  and 16 each raise a piece: epoxy floor, back wall, side walls, team livery, awning,
  floodlights, pit wall, tyres and tools, upper deck. The whole garage is up before the trophy;
  a new season opens in the finished shell and builds the extras again. Visible progress is
  what makes a tycoon satisfying, and a full garage is what other players see when they walk
  past.
- **Time trial (25 Oct 2026):** a 1,165-stud track round the paddock. The Race button (or Drive
  at the show car) puts the player in their team's car on the grid; WASD or arrows, a gamepad
  or a phone's thumbstick drive it, jump gets out. The server times every lap itself (track
  limits and teleports void a lap), so the Fastest laps board can't be faked. A clean lap pays
  15 seconds of income, a new best lap 2 minutes more, and the car is 5 studs/s faster each
  season (65 up to 95), so every season's car has a lap record to beat. Every drive opens with
  an F1 start: five red lights on the gantry, a beep each, then lights out and GO. The engine
  (a licensed race-car recording, pitched by speed) and squealing tyres are heard, and the lap
  panel shows km/h. From season 2 the **Reverse GP** opens: the same circuit the other way
  round (Race asks which), with its own best laps and its own board at the spawn. From season 3
  the **Endurance** circuit joins them: a 2 km loop round the outside of the Grand Prix track,
  with its own gantry, best laps and board. Put "drive your own F1
  car" in the description and a car on the track in a thumbnail.

## Saving across servers

Saves are session-locked (`src/server/SaveLock.luau`). A server loads a player's save only when
no live server holds it, and writes it only while it still holds it. A player who hops servers
waits a few seconds ("Fetching your garage from your last server...") while the old server
finishes its leaving save, instead of loading an older save that then overwrites the newer
one. If a server crashes, its lock goes stale after 150 seconds (the server saves every 60)
and the next server takes the save over. `tests/SaveLock.spec.luau` plays these cases through
with a fake store; CI runs it on every push.

## Next features (in order of expected impact)

1. A second track layout, or a reversed direction, unlocked in a later season.
2. Proper 3D models (meshes) for the car and machines; everything is still built from parts.

Done 25 Oct 2026: the night garage from season 3 (graphite walls, team colours that glow),
stamping presses with a moving die, a different part from each press, a fuller car with a
helmeted driver in the show car, F1 start lights, engine and tyre sounds, a speed readout.

Done 24 Oct 2026: a longer first season (11 purchases became 24), machines that only appear in
later seasons, and a HUD built for phones.
