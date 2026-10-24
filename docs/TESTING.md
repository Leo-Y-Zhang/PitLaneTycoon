# Five-minute Studio test

The code compiles, the place file builds and every script type-checks against the Roblox API in
CI, but nothing has been played yet. Do this once in Roblox Studio (download it from
roblox.com/create and sign in), and note anything that fails.

1. Open `PitLaneTycoon.rbxlx` from the latest release and press **Play**.
2. You should land on your garage, facing a red pad. **Check:** six garages around the spawn; a
   sign with your name on yours; the top bar shows `$0` and `+$.../min`.
3. **Within 3 seconds** a grey part drops from the Bolt press and rides the conveyor to the green
   scrutineering block. **Check:** "Collect $..." rises on the blue pad.
4. Walk onto the **blue pad**. **Check:** the top bar's cash goes up and the pad resets to $0.
5. Collect $60 and step on the **red pad** (Bracket press). **Check:** a second press appears,
   the next red pad lights up, and a "Bought Bracket press" message shows.
6. Open **Shop**. **Check:** it says the shop opens soon (no pass ids are set yet).
7. **Saving** only works on a published place: File > Publish to Roblox, then Game Settings >
   Security > Enable Studio Access to API Services. Play, earn some cash, stop, Play again.
   **Check:** your cash and machines come back.

To speed up testing, temporarily change `cost` values in `src/shared/Config.luau` (for example
the trophy to 500) and rebuild; change them back afterwards.

If something fails, copy the red error lines from the Output window (View > Output) into a
message: that is enough to fix it.
