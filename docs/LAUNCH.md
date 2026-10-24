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
   (`icon.png` 512x512, `thumbnail-1..3.png` 1280x720); upload all three thumbnails so Roblox
   rotates them. They contain no avatar or username. To remake them after a visual change:
   `python tools/studio-test/run.py PitLaneTycoon.rbxlx --photos --shots shots` then
   `python tools/studio-test/thumbnails.py shots marketing`.
4. **Create the passes and products**, paste the ids into `Config.luau`, rebuild, republish.
5. **First traffic:** share with friends for the first concurrent players; then a small Sponsored
   Experience campaign (Ads Manager) once Day-1 retention looks healthy. Do not spend on ads
   before the game keeps players.
6. **Update weekly:** new machines, a new upgrade, a limited-time event. Update logs in the
   game description bring returning players.

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

## Next features (in order of expected impact)

1. A second plot theme unlocked in season 3 (keeps rebirthing fresh).
2. Session locking, so a player who hops servers within seconds can't load a save that the old
   server has not finished writing (rare; matters once there is real traffic).

Done 24 Oct 2026: a longer first season (11 purchases became 24), machines that only appear in
later seasons, and a HUD built for phones.
