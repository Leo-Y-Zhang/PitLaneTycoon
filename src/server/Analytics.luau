--!strict
-- Funnel and economy events for the Creator Dashboard (Analytics > Funnels and Economy):
-- how far new players get, and where the cash comes from and goes. Every call is guarded,
-- so a failing analytics call never stops the game.

local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

-- the onboarding funnel, in the order a player reaches it. A first season has 19
-- purchases with the trophy last, so the steps always arrive in this order.
Analytics.Steps = { "Joined", "First purchase", "5 purchases", "10 purchases", "15 purchases", "Constructors' trophy", "New season" }
Analytics.Step = { joined = 1, firstPurchase = 2, trophy = 6, newSeason = 7 }

local warned = false
local function try(fn: () -> ())
	local ok, err = pcall(fn)
	if not ok and not warned then
		warned = true -- once per server, not once per call
		warn("[PitLane] analytics call failed: " .. tostring(err))
	end
end

-- the funnel step a purchase count reaches (first purchase, then every fifth)
function Analytics.purchaseStep(purchases: number): number
	if purchases >= 15 then return 5 end
	if purchases >= 10 then return 4 end
	if purchases >= 5 then return 3 end
	if purchases >= 1 then return 2 end
	return 0
end

-- log every funnel step after `reached` up to `step`; returns the new furthest step, which
-- the caller keeps in the save so each step is sent once per player
function Analytics.funnel(player: Player, reached: number, step: number): number
	for s = reached + 1, math.min(step, #Analytics.Steps) do
		try(function()
			AnalyticsService:LogOnboardingFunnelStepEvent(player, s, Analytics.Steps[s])
		end)
	end
	if step > reached then
		player:SetAttribute("FunnelStep", step)
		return step
	end
	return reached
end

local function economy(player: Player, flow: Enum.AnalyticsEconomyFlowType, amount: number, balance: number,
	transaction: Enum.AnalyticsEconomyTransactionType, sku: string)
	amount = math.floor(amount)
	if amount < 1 then return end
	try(function()
		AnalyticsService:LogEconomyEvent(player, flow, "Cash", amount, math.floor(balance), transaction.Name, sku)
	end)
end

-- cash in: the factory, rewards and Robux packs
function Analytics.earned(player: Player, amount: number, balance: number, transaction: Enum.AnalyticsEconomyTransactionType, sku: string)
	economy(player, Enum.AnalyticsEconomyFlowType.Source, amount, balance, transaction, sku)
end

-- cash out: machines and new seasons
function Analytics.spent(player: Player, amount: number, balance: number, transaction: Enum.AnalyticsEconomyTransactionType, sku: string)
	economy(player, Enum.AnalyticsEconomyFlowType.Sink, amount, balance, transaction, sku)
end

return Analytics
