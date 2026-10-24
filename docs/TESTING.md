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

Studio runs on 24 Oct 2026: 19/19 checks passed and the game logged no errors.

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
8. **Saving** only works on a published place: File > Publish to Roblox, then Game Settings >
   Security > Enable Studio Access to API Services. Play, earn some cash, stop, Play again.
   **Check:** your cash and machines come back.

To speed up testing, temporarily change `cost` values in `src/shared/Config.luau` (for example
the trophy to 500) and rebuild; change them back afterwards.

If something fails, copy the red error lines from the Output window (View > Output) into a
message: that is enough to fix it.
