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

do -- toasts start at the top of the inset-safe area, never at the panel/HUD centre
	for _, size in { { 810, 512 }, { 844, 390 }, { 1920, 1080 } } do
		local width, height = size[1], size[2]
		for _, inset in { 36, 60 } do
			local tag = ("%dx%d inset %d"):format(width, height, inset)
			local centre, s, y, allowed = Layout.toasts(width, height, inset, 0)
			local bottom = inset + y + 104 * s -- three 32 px pills with two 4 px gaps
			check(tag .. " closed: top centred just below inset", centre == width / 2 and y == 8)
			check(tag .. " closed: the full stack fits", allowed == true and bottom <= height - 8)
			check(tag .. " closed: pills stay on screen", centre - 180 * s >= 8 and centre + 180 * s <= width - 8)
			for _, panel in { { name = "crew", width = 440, height = 500 }, { name = "shop", width = 380, height = 410 },
				{ name = "season", width = 380, height = 230 }, { name = "welcome", width = 440, height = 250 } } do
				for _, touch in { false, true } do
					local _, panelScale = Layout.panel(width, height, panel.width, touch)
					local modalTop = inset + (height - inset - panel.height * panelScale) / 2
					local x, scale, top, show = Layout.toasts(width, height, inset, 0, { modalTop })
					local fits = bottom + 8 <= modalTop
					local name = tag .. " " .. panel.name .. (touch and " touch" or " computer")
					check(name .. ": stays at top centre", x == centre and top == 8 and scale == s)
					check(name .. ": show above panel or hold", show == fits)
					check(name .. ": never covers modal", show == false or inset + top + 104 * scale + 8 <= modalTop)
				end
			end
		end
	end
	local _, s, y = Layout.toasts(810, 512, 60, 0)
	local boundary = 60 + y + 104 * s + 8
	local _, _, _, atBoundary = Layout.toasts(810, 512, 60, 0, { boundary })
	local _, _, _, belowBoundary = Layout.toasts(810, 512, 60, 0, { boundary - 0.01 })
	check("an exact fit above a modal is allowed", atBoundary == true)
	check("a stack cannot cross the modal clearance by even a pixel", belowBoundary == false)
	local _, _, _, covered = Layout.toasts(844, 390, 60, 0, { 40 })
	check("a modal crossing the top safe area holds notifications", covered == false)
	local _, _, _, bottomInset = Layout.toasts(844, 390, 60, 300)
	check("the bottom safe inset is reserved too", bottomInset == false)
	local centre, smallScale, _, narrow = Layout.toasts(320, 568, 60, 0)
	check("portrait pills fit within safe horizontal margins", narrow == true and centre - 180 * smallScale >= 8)
	check("the HUD returns to its usual top when the queue drains", Layout.toastHudTop ~= nil and Layout.toastHudTop(1, 0) == 10)
	for _, size in { { 810, 512 }, { 844, 390 }, { 1920, 1080 } } do
		local _, scale, y = Layout.toasts(size[1], size[2], 60, 0)
		for count = 1, 3 do
			local bottom = y + (count * 32 + (count - 1) * 4) * scale
			check(("%dx%d: HUD clears %d toast pills"):format(size[1], size[2], count),
				Layout.toastHudTop ~= nil and Layout.toastHudTop(scale, count) >= bottom + 8)
		end
	end
	local _, _, _, multipleBlocked = Layout.toasts(810, 512, 60, 0, { 300, 80 })
	local _, _, _, multipleClear = Layout.toasts(1920, 1080, 60, 0, { 400, 300 })
	check("every open modal must clear the toast stack", multipleBlocked == false)
	check("several modals with enough space allow the stack", multipleClear == true)
	local clearOfControls, onScreen = true, true
	for _, size in { { 320, 568 }, { 360, 640 }, { 640, 360 }, { 667, 375 }, { 740, 360 }, { 844, 390 }, { 926, 428 }, { 1024, 768 }, { 1180, 820 } } do
		local width, height = size[1], size[2]
		local centre, s, y = Layout.toasts(width, height, 60, 0)
		local left, right, bottom = centre - 180 * s, centre + 180 * s, 60 + y + 104 * s
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
