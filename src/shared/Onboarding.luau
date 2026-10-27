--!strict
-- Presentation only. Progress comes from server-owned counters; this never awards cash.
local Onboarding = {}

export type Save = {
	welcomed: boolean, funnel: number, goal: number, season: number, banks: number,
	laps: number, earned: number, lastSeen: number,
	bought: { [string]: boolean }, crew: { [string]: number },
}
export type Stats = { purchases: number, banks: number, crew: number, laps: number, gifts: number }
Onboarding.Steps = { "Buy your first machine", "Collect your cash", "Hire your first crew member", "Drive a lap", "Claim your gift" }

-- Evaluate before granting the free starter or logging Joined. An abandoned first
-- visit is still a returning save, even if its welcome card was never dismissed.
function Onboarding.isNewSave(save: Save): boolean
	return not save.welcomed and save.funnel == 0 and save.goal == 1 and save.season == 0
		and save.banks == 0 and save.laps == 0 and save.earned == 0 and save.lastSeen == 0
		and next(save.bought) == nil and next(save.crew) == nil
end

function Onboarding.completed(stats: Stats): { boolean }
	return { stats.purchases > 0, stats.banks > 0, stats.crew > 0, stats.laps > 0, stats.gifts > 0 }
end

-- Remember events performed early, without asking players to repeat them.
function Onboarding.step(stats: Stats): number?
	for i, done in Onboarding.completed(stats) do
		if not done then return i end
	end
	return nil
end

function Onboarding.active(firstSession: boolean, dismissed: boolean, elapsed: number, step: number?): boolean
	return firstSession and not dismissed and elapsed < 600 and step ~= nil
end

function Onboarding.pulse(reduced: boolean, time: number): number
	return if reduced then 0 else (math.sin(time * 4) + 1) / 2
end

function Onboarding.target(step: number, affordable: boolean, pending: number, crewUnlocked: boolean, giftReady: boolean): string?
	if step == 1 or (step == 3 and not crewUnlocked) then
		if affordable then return "pad" end
		if pending > 0 then return "collector" end
	elseif step == 2 then
		if pending > 0 then return "collector" end
	elseif step == 3 then
		return "crew"
	elseif step == 4 then
		return "race"
	elseif step == 5 and giftReady then
		return "gift"
	end
	return nil
end

return Onboarding
