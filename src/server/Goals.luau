--!strict
-- The goals chain (Config.Goals): one goal at a time, each paying a few minutes of income
-- when it is met. Pure Luau, so tests/Goals.spec.luau checks the chain in CI.

local Goals = {}

export type Goal = { kind: string, n: number, text: string, minutes: number, floor: number }
export type Stats = {
	banks: number, -- times cash was banked at the blue pad
	purchases: number, -- machines bought this season
	laps: number, -- clean laps
	earned: number, -- factory earnings, all seasons
	bestLap: number, -- seconds, 0 = none
	season: number, -- 0 = the first
	trophy: boolean, -- the Constructors' trophy bought this season
}

Goals.Kinds = { "banks", "purchases", "laps", "earned", "lapUnder", "trophy", "season" }

-- how far along a goal is, and what it needs
function Goals.progress(goal: Goal, s: Stats): (number, number)
	if goal.kind == "banks" then
		return math.min(s.banks, goal.n), goal.n
	elseif goal.kind == "purchases" then
		return math.min(s.purchases, goal.n), goal.n
	elseif goal.kind == "laps" then
		return math.min(s.laps, goal.n), goal.n
	elseif goal.kind == "earned" then
		return math.min(s.earned, goal.n), goal.n
	elseif goal.kind == "lapUnder" then -- n = seconds
		return if s.bestLap > 0 and s.bestLap < goal.n then 1 else 0, 1
	elseif goal.kind == "trophy" then -- won it this season, or in an earlier one
		return if s.trophy or s.season > 0 then 1 else 0, 1
	elseif goal.kind == "season" then -- n = seasons started after the first
		return math.min(s.season, goal.n), goal.n
	end
	return 0, 1
end

function Goals.done(goal: Goal, s: Stats): boolean
	local have, need = Goals.progress(goal, s)
	return have >= need
end

return Goals
