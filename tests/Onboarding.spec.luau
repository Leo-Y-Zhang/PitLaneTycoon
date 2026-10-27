--!strict
local Onboarding = require("../src/shared/Onboarding")
local Layout = require("../src/shared/Layout")

local passed, failed = 0, 0
local function check(name: string, ok: boolean)
	if ok then passed += 1 else failed += 1 end
	print((if ok then "PASS " else "FAIL ") .. name)
end

local function save()
	return { welcomed = false, funnel = 0, goal = 1, season = 0, banks = 0, laps = 0,
		earned = 0, lastSeen = 0, bought = {} :: { [string]: boolean }, crew = {} :: { [string]: number } }
end
check("only an untouched save starts the tracker", Onboarding.isNewSave(save()))
for _, field in { "funnel", "season", "banks", "laps", "earned", "lastSeen" } do
	local s = save()
	;(s :: any)[field] = 1
	check("returning progress excludes " .. field, not Onboarding.isNewSave(s))
end
do
	local s = save()
	s.welcomed = true
	check("a welcomed save never restarts", not Onboarding.isNewSave(s))
	s = save()
	s.goal = 2
	check("old goal progress never restarts", not Onboarding.isNewSave(s))
	s = save()
	s.bought.press1 = true
	check("the free starter on an old save is not a new save", not Onboarding.isNewSave(s))
	s = save()
	s.crew.mechanic = 1
	check("existing crew excludes a save", not Onboarding.isNewSave(s))
end

local stats = { purchases = 0, banks = 0, crew = 0, laps = 0, gifts = 0 }
local expected = { "Buy your first machine", "Collect your cash", "Hire your first crew member", "Drive a lap", "Claim your gift" }
for step, field in { "purchases", "banks", "crew", "laps", "gifts" } do
	check("ordered step " .. step, Onboarding.step(stats) == step and Onboarding.Steps[step] == expected[step])
	check("step " .. step .. " needs a confirmed event", not Onboarding.completed(stats)[step])
	;(stats :: any)[field] = 1
	check("confirmed event completes step " .. step, Onboarding.completed(stats)[step])
end
check("all five events finish the tracker", Onboarding.step(stats) == nil)
do
	local early = { purchases = 0, banks = 1, crew = 0, laps = 1, gifts = 0 }
	check("out of order events do not skip an unmet step", Onboarding.step(early) == 1)
	early.purchases = 1
	check("earlier real events stay complete", Onboarding.step(early) == 3)
	early.crew = 1
	check("a lap taken early does not need repeating", Onboarding.step(early) == 5)
end
check("tracker stays active before ten minutes", Onboarding.active(true, false, 599.99, 1))
check("tracker expires at ten minutes", not Onboarding.active(true, false, 600, 1))
check("skip hides it immediately", not Onboarding.active(true, true, 1, 1))
check("returning saves never show it", not Onboarding.active(false, false, 1, 1))
check("completion hides it", not Onboarding.active(true, false, 1, nil))
check("first buy targets an affordable pad", Onboarding.target(1, true, 0, false, false) == "pad")
check("first buy can guide banking to afford the pad", Onboarding.target(1, false, 5, false, false) == "collector")
check("collect step waits for pending cash", Onboarding.target(2, true, 0, false, false) == nil)
check("collect step points at any waiting cash", Onboarding.target(2, true, 1, false, false) == "collector")
check("crew points at its button once unlocked", Onboarding.target(3, true, 0, true, false) == "crew")
check("locked crew guides continued building", Onboarding.target(3, true, 0, false, false) == "pad")
check("lap points at Race", Onboarding.target(4, true, 0, true, false) == "race")
check("gift is not targeted early", Onboarding.target(5, true, 0, true, false) == nil)
check("ready gift points at its button", Onboarding.target(5, true, 0, true, true) == "gift")
check("pulse strength is available", type(Onboarding.pulse) == "function")
if Onboarding.pulse then
	check("reduce motion is steady across time", Onboarding.pulse(true, 0) == 0 and Onboarding.pulse(true, 0.4) == 0)
	check("normal motion pulses", Onboarding.pulse(false, 0) ~= Onboarding.pulse(false, 0.4))
	check("turning reduce motion on settles the pulse", Onboarding.pulse(true, 0.4) == 0)
end

for _, size in { { 320, 568 }, { 640, 360 }, { 667, 375 }, { 844, 390 }, { 1024, 768 }, { 1920, 1080 } } do
	for _, touch in { true, false } do
		local w, h = size[1], size[2]
		local tag = ("%dx%d %s"):format(w, h, tostring(touch))
		local p = Layout.tracker(w, h, 60, 12, touch, h * 0.52, {}, false)
		local left, bottom = p.x - Layout.GoalWidth * p.scale, 60 + p.y + Layout.TrackerStackHeight * p.scale
		check(tag .. " stays in safe area or hides", not p.visible or (left >= 8 and bottom <= h - 12))
		check(tag .. " clears touch corners or hides", not p.visible or not touch or bottom <= h * 0.62)
		check(tag .. " clears player list or hides", not p.visible or touch or 60 + p.y >= 60 + Layout.PlayerListHeight + 8)
		local modal = Layout.tracker(w, h, 60, 12, touch, 100, {}, true)
		check(tag .. " hides with any panel open", not modal.visible)
		local covered = Layout.tracker(w, h, 60, 12, touch, 100, { { left = 0, top = 0, right = w, bottom = h } }, false)
		check(tag .. " hides when no unobstructed space remains", not covered.visible)
	end
end
do
	local p = Layout.tracker(844, 390, 60, 0, true, 150, {}, false)
	check("landscape phone has room for both cards", p.visible)
	local p2 = Layout.tracker(1920, 1080, 60, 0, false, 100, { { left = 1700, right = 1920, top = 0, bottom = 350 } }, false)
	check("cards can move below an obstruction", p2.visible and p2.y >= 298)
end
do -- Include actual HUD lanes, rather than testing an otherwise empty screen.
	for _, size in { { 667, 375 }, { 844, 390 }, { 1024, 768 }, { 1920, 1080 } } do
		for _, touch in { true, false } do
			local w, h = size[1], size[2]
			local cx, ts = Layout.topBar(w, h, touch)
			local s = Layout.scale(w, h)
			local obstacles = {
				{ left = cx - 180 * ts, right = cx + 180 * ts, top = 70, bottom = 70 + Layout.TopBarHeight * ts },
				{ left = 12, right = 12 + 150 * s, top = 60 + (h - 60) * 0.42 - 103 * s,
					bottom = 60 + (h - 60) * 0.42 + 103 * s },
			}
			local p = Layout.tracker(w, h, 60, 0, touch, h * 0.52, obstacles, false)
			local clear = true
			for _, r in obstacles do
				local overlap = p.x - 230 * s < r.right + 8 and p.x > r.left - 8
					and 60 + p.y < r.bottom + 8 and 60 + p.y + Layout.TrackerStackHeight * s > r.top - 8
				clear = clear and (not p.visible or not overlap)
			end
			check(("%dx%d %s clears real HUD lanes"):format(w, h, tostring(touch)), clear)
			if touch then check(("%dx%d touch shows both cards beside HUD"):format(w, h), p.visible) end
		end
	end
end
print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then error("onboarding tests failed") end
