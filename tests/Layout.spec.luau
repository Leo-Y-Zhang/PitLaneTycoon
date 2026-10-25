-- Tests for the HUD layout (src/shared/Layout.luau) across phones and computer windows.
-- CI runs them with the Luau command line: luau tests/Layout.spec.luau

local Layout = require("../src/shared/Layout")

local failed, passed = 0, 0
local function check(name: string, ok: any, detail: any?)
	if ok then
		passed += 1
		print("PASS " .. name)
	else
		failed += 1
		print("FAIL " .. name .. (if detail ~= nil then " (" .. tostring(detail) .. ")" else ""))
	end
end

do -- computer windows, from a narrow one beside other windows to a wide monitor
	local clear, onScreen, readable, worst = true, true, true, nil
	for width = 640, 2560, 40 do
		for _, height in { 480, 720, 1080 } do
			local centre, s = Layout.topBar(width, height, false)
			local half = Layout.TopBarWidth / 2 * s
			if centre + half > width - Layout.PlayerListWidth + 0.01 then
				clear, worst = false, ("%dx%d right edge %.0f"):format(width, height, centre + half)
			end
			if centre - half < Layout.SettingsWidth then
				onScreen, worst = false, ("%dx%d left edge %.0f"):format(width, height, centre - half)
			end
			readable = readable and s >= 0.5
		end
	end
	check("on a computer the top bar stays clear of the player list", clear, worst)
	check("and of the settings button", onScreen, worst)
	check("and never shrinks below half size", readable)
	local centre = Layout.topBar(1920, 1080, false)
	check("on a wide screen it stays centred", centre == 960, centre)
end

do -- phones and tablets held sideways
	local centred, clearOfThumb, worst = true, true, nil
	for _, size in { { 667, 375 }, { 740, 360 }, { 844, 390 }, { 926, 428 }, { 1024, 768 }, { 1180, 820 } } do
		local width, height = size[1], size[2]
		local centre = Layout.topBar(width, height, true)
		centred = centred and centre == width / 2
		-- the thumbstick sits in the bottom-left third of the screen
		local bottom = Layout.buttonsBottom(width, height)
		if bottom > height * 0.62 then
			clearOfThumb, worst = false, ("%dx%d buttons end at %.0f of %d"):format(width, height, bottom, height)
		end
	end
	check("on a phone the top bar is centred (the player list is hidden)", centred)
	check("the left-edge buttons end above the thumbstick", clearOfThumb, worst)
	check("panels shrink on a phone but stay readable", Layout.scale(640, 360) == 0.65 and Layout.scale(1366, 768) == 1)
end

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then
	error("layout tests failed")
end
