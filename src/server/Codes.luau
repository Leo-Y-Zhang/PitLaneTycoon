--!strict
-- Redeem codes. They live here on the server, not in the shared Config, so players can't read
-- the list. Typed in any case; each pays once per player: `minutes` of their income, at least
-- `floor` times their season multiplier. Announce new codes in the game's description or
-- group wall (one for the launch, one for each milestone or update) and remove old ones.

return {
	PITLANE = { minutes = 5, floor = 250 },
	GREENFLAG = { minutes = 10, floor = 500 },
} :: { [string]: { minutes: number, floor: number } }
