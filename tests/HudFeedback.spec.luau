--!strict
-- Run with plain Luau: luau tests/HudFeedback.spec.luau
local Feedback = require("../src/shared/HudFeedback")
local Config = require("../src/shared/Config")

local passed, failed = 0, 0
local function check(name: string, ok: boolean)
	if ok then
		passed += 1
		print("PASS " .. name)
	else
		failed += 1
		print("FAIL " .. name)
	end
end
local function near(a: number, b: number): boolean
	return math.abs(a - b) < 0.000001
end

for _, case in {
	{ value = 0, expected = "$0" },
	{ value = 999.99, expected = "$999" },
	{ value = 1000, expected = "$1.0K" },
	{ value = 12500, expected = "$12.5K" },
	{ value = 1000000, expected = "$1.0M" },
	{ value = 2500000000, expected = "$2.5B" },
	{ value = 1000000000000, expected = "$1.0T" },
	{ value = 1000000000000000, expected = "$1.0Qa" },
	{ value = 1e18, expected = "$1000.0Qa" },
	{ value = -15.5, expected = "$-16" },
	{ value = -1250, expected = "$-1.2K" },
} do
	check("existing cash format for " .. tostring(case.value), Feedback.money(case.value) == case.expected)
end

do
	local q = Feedback.newQueue()
	Feedback.enqueue(q, "", 0)
	check("empty toasts are ignored", #q.visible == 0 and #q.pending == 0)
	for i = 1, 5 do Feedback.enqueue(q, tostring(i), 0) end
	check("three messages are visible during a burst", #q.visible == 3 and #q.pending == 2)
	check("visible messages keep arrival order", q.visible[1].text == "1" and q.visible[3].text == "3")
	check("pending messages keep arrival order", q.pending[1].text == "4" and q.pending[2].text == "5")
	Feedback.advance(q, 2.99)
	check("messages keep their full display lifetime", #q.visible == 3 and q.visible[1].text == "1")
	Feedback.advance(q, 3)
	check("expired messages promote the pending queue", #q.visible == 2 and #q.pending == 0 and q.visible[1].text == "4")
	check("waiting messages get a fresh lifetime when shown", q.visible[1].expiresAt == 6)
	Feedback.advance(q, 6)
	check("the queue drains after its last lifetime", #q.visible == 0 and #q.pending == 0)
	Feedback.enqueue(q, "next", 6)
	check("entry ids stay unique after draining", q.visible[1].id == 6)
end

do
	local q = Feedback.newQueue()
	Feedback.enqueue(q, "first", 0)
	Feedback.enqueue(q, "second", 1)
	Feedback.enqueue(q, "third", 2)
	Feedback.enqueue(q, "fourth", 2)
	Feedback.advance(q, 3)
	check("staggered expiry preserves other visible messages", #q.visible == 3 and q.visible[1].text == "second")
	check("one freed slot promotes just one message", q.visible[3].text == "fourth" and q.visible[3].expiresAt == 6)
	Feedback.advance(q, 100)
	check("a long time jump removes all expired cards", #q.visible == 0)
end

do
	local q = Feedback.newQueue()
	for i = 1, 100 do Feedback.enqueue(q, tostring(i), 0) end
	check("a notification storm has bounded memory", #q.visible == 3 and #q.pending == 12)
	check("overflow leaves visible cards undisturbed", q.visible[1].text == "1" and q.visible[3].text == "3")
	check("overflow retains the latest waiting messages", q.pending[1].text == "89" and q.pending[12].text == "100")
	local bounded = true
	for t = 3, 20 do
		Feedback.advance(q, t)
		bounded = bounded and #q.visible <= 3 and #q.pending <= 12
	end
	check("the queue stays bounded while draining", bounded and #q.visible == 0 and #q.pending == 0)
end

local items: { Feedback.ProgressItem } = {}
for _, item in Config.Items do table.insert(items, { key = item.key, season = item.season }) end
do
	local progress, built, total = Feedback.seasonProgress(items, 0, "press2", false, 0, Config.SeasonCost(0))
	check("the free press earns no purchase progress", progress == 0 and built == 0)
	check("season one excludes later-season machines and the free press", total == 19)
	local _, _, seasonTwoTotal = Feedback.seasonProgress(items, 1, "press2", false, 0, Config.SeasonCost(1))
	local _, _, seasonThreeTotal = Feedback.seasonProgress(items, 2, "press2", false, 0, Config.SeasonCost(2))
	check("season two includes its extra machines", seasonTwoTotal == 21)
	check("season three includes all machines", seasonThreeTotal == 23)
	local afterPurchase = Feedback.seasonProgress(items, 0, "speed1", false, 0, 9000000)
	check("the next key tracks sequential purchases", near(afterPurchase, 0.8 / 19))
	local beforeTrophy = Feedback.seasonProgress(items, 0, "trophy", false, 1e12, 9000000)
	check("cash cannot finish a season without the trophy", near(beforeTrophy, 0.8 * 18 / 19) and beforeTrophy < 1)
	check("missing next key during replication does not imply completion", Feedback.seasonProgress(items, 0, "", false, 0, 9000000) == 0)
	check("unknown next key does not imply completion", Feedback.seasonProgress(items, 0, "unknown", false, 0, 9000000) == 0)
	check("the trophy completes the build stage", near(Feedback.seasonProgress(items, 0, "", true, 0, 9000000), 0.8))
	check("half the season fee adds half the cash stage", near(Feedback.seasonProgress(items, 0, "", true, 4500000, 9000000), 0.9))
	check("the full fee and trophy finish the bar", Feedback.seasonProgress(items, 0, "", true, 9000000, 9000000) == 1)
	check("excess cash is clamped", Feedback.seasonProgress(items, 0, "", true, 1e12, 9000000) == 1)
	check("negative cash cannot reverse build progress", near(Feedback.seasonProgress(items, 0, "", true, -1, 9000000), 0.8))
	check("a season reset resets progress", Feedback.seasonProgress(items, 1, "press2", false, 0, 18000000) == 0)
	check("zero fee never divides by zero", Feedback.seasonProgress(items, 0, "", true, 0, 0) == 0.8)
	check("an empty catalogue is safe", Feedback.seasonProgress({}, 0, "", false, 0, 1) == 0)
end

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then error("HUD feedback tests failed") end
