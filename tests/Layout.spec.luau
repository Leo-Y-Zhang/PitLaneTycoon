--!strict
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
	local clear, onScreen, readable = true, true, true
	local worst: string? = nil
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

do -- the centred panels (shop and new season 380 px wide, crew and welcome 440) on a computer
	local clear, onScreen, readable = true, true, true
	local worst: string? = nil
	for width = 640, 2560, 40 do
		for _, height in { 480, 720, 1080 } do
			for _, panelWidth in { 380, 440 } do
				local centre, s = Layout.panel(width, height, panelWidth, false)
				local half = panelWidth / 2 * s
				if centre + half > width - Layout.PlayerListWidth + 0.01 then
					clear, worst = false, ("%dx%d, %d wide: right edge %.0f"):format(width, height, panelWidth, centre + half)
				end
				if centre - half < 0 then
					onScreen, worst = false, ("%dx%d, %d wide: left edge %.0f"):format(width, height, panelWidth, centre - half)
				end
				readable = readable and s >= 0.5
			end
		end
	end
	check("on a computer the shop and crew panels stay clear of the player list", clear, worst)
	check("and on the screen", onScreen, worst)
	check("and never shrink below half size", readable)
	local centre, s = Layout.panel(1920, 1080, 440, false)
	check("on a wide screen they stay centred at full size", centre == 960 and s == 1, ("%g at %g"):format(centre, s))
	local phone = Layout.panel(844, 390, 440, true)
	check("on a phone they stay centred (the list is hidden there)", phone == 422, phone)
end

do -- phones and tablets held sideways
	local centred, clearOfThumb = true, true
	local worst: string? = nil
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

do -- notification stack: same horizontal safe area as the HUD, below it and the event
	local clearOfList, belowHud = true, true
	for width = 640, 2560, 40 do
		for _, event in { false, true } do
			local centre, s, y = Layout.toasts(width, 480, false, event)
			clearOfList = clearOfList and centre + 180 * s <= width - Layout.PlayerListWidth + 0.01
				and centre - 180 * s >= Layout.SettingsWidth
			belowHud = belowHud and y >= 10 + (Layout.TopBarHeight + (event and 40 or 0)) * s
		end
	end
	check("toasts respect the player list and settings safe areas", clearOfList)
	check("toasts sit below the HUD including a live event", belowHud)
	local clearOfControls, onScreen = true, true
	for _, size in { { 320, 568 }, { 360, 640 }, { 640, 360 }, { 667, 375 }, { 740, 360 }, { 844, 390 }, { 926, 428 }, { 1024, 768 }, { 1180, 820 } } do
		local width, height = size[1], size[2]
		local centre, s, y = Layout.toasts(width, height, true, true)
		local left, right, bottom = centre - 180 * s, centre + 180 * s, y + 108 * s + 60
		-- Conservative corner control regions, with 60 px reserved for Roblox's top inset.
		clearOfControls = clearOfControls and (bottom < height * 0.62 or (left > width * 0.3 and right < width * 0.7))
		onScreen = onScreen and left >= 0 and right <= width and bottom < height
	end
	check("three toasts stay clear of phone thumbstick and jump corners", clearOfControls)
	check("the full toast stack fits portrait and landscape phones", onScreen)
	local settingsClear = true
	for _, size in { { 640, 360 }, { 667, 375 }, { 740, 360 }, { 844, 390 }, { 926, 428 }, { 1024, 768 } } do
		local width, height = size[1], size[2]
		local bottom = Layout.SettingsPanelTop + Layout.SettingsPanelHeight * Layout.scale(width, height) + 60
		settingsClear = settingsClear and bottom < height * 0.62
	end
	check("the expanded settings including Reduce motion stay above the thumbstick", settingsClear)
end

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then
	error("layout tests failed")
end
