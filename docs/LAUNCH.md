# Launch and monetisation plan

Research of 23 October 2026, from public creator guides and earnings trackers (estimates, not
guarantees): simulators and tycoons lead Roblox's revenue charts, and incremental tycoons suit a
solo developer because they need little art and earn through progression passes. Most new games
earn nothing until they are discovered, so the plan below is about retention first, then traffic.

## Why this design

- **The core loop pays every few seconds** (presses → conveyor → cash), and the next purchase pad
  is always the one glowing, so players never wonder what to do.
- **Retention:** new seasons (rebirth) with a permanent multiplier, and a daily streak (day 7
  pays 80x day 1). These are the levers that bring players back, which is what Roblox's
  recommendations reward.
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
2. **Publish**, fill in the Maturity & Compliance questionnaire (needed before it can be public),
   and set the genre to Simulation/Tycoon.
3. **Icon and thumbnails** matter more than anything else for clicks: a bright car on a
   conveyor, big readable title, no small text. Make 3 thumbnails and rotate them.
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

## Next features (in order of expected impact)

1. Leaderboard of seasons in the lobby (social proof).
2. A second plot theme unlocked in season 3 (keeps rebirthing fresh).
3. Friends boost: +10% for each friend in the server (brings players' friends in).
4. Limited-time weekend event with a 2x hour.
