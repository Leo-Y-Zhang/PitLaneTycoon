--!strict
-- Where the HUD's panels go for a given screen, worked out without Roblox APIs so
-- tests/Layout.spec.luau can check phones and laptops in CI.

local Layout = {}

Layout.TopBarWidth = 360
Layout.TopBarHeight = 122
-- Roblox's player list, top right on a computer: about 315 px with Seasons and Cash
-- (measured in Studio on 25 Oct 2026)
Layout.PlayerListWidth = 330
-- Reserve 200 px below the top safe inset for the desktop list and its rows.
Layout.PlayerListHeight = 200
Layout.SettingsPanelTop = 62
Layout.SettingsPanelHeight = 154
Layout.SettingsWidth = 56 -- the settings button, top left
Layout.PanelMargin = 8 -- the least gap between a panel and the left edge of the screen
Layout.ButtonBarHeight = 206 -- Shop, Race, Crew and New season, left edge
Layout.ButtonBarCentre = 0.42 -- of the screen's height

-- every panel is laid out for a laptop and shrinks on a phone held sideways
function Layout.scale(width: number, height: number): number
	return math.clamp(math.min(width / 900, height / 560), 0.65, 1)
end

-- the top bar's centre, in pixels from the left, and its scale. A computer shows the player
-- list in the top-right corner, so in a narrow window the bar moves left (and shrinks if it
-- must) to stay clear of it and of the settings button. Phones hide the list behind a button,
-- so there the bar stays centred.
function Layout.topBar(width: number, height: number, touch: boolean): (number, number)
	local s = Layout.scale(width, height)
	if touch then
		return width / 2, s
	end
	local left, right = Layout.SettingsWidth + 8, width - Layout.PlayerListWidth
	local half = Layout.TopBarWidth / 2
	if right - left < Layout.TopBarWidth * s then
		s = math.max(0.5, (right - left) / Layout.TopBarWidth)
	end
	local centre = math.clamp(width / 2, left + half * s, math.max(left + half * s, right - half * s))
	return centre, s
end

-- a panel that opens in the middle of the screen (the shop, the crew), `panelWidth` px wide
-- on a laptop: its centre in pixels from the left, and its scale. Like the top bar, on a
-- computer it slides left in a narrow window (and shrinks if it must) to keep clear of the
-- player list; phones hide the list, so there it stays centred.
function Layout.panel(width: number, height: number, panelWidth: number, touch: boolean): (number, number)
	local s = Layout.scale(width, height)
	if touch then
		return width / 2, s
	end
	local left, right = Layout.PanelMargin, width - Layout.PlayerListWidth
	if right - left < panelWidth * s then
		s = math.max(0.5, (right - left) / panelWidth)
	end
	local half = panelWidth / 2 * s
	return math.clamp(width / 2, left + half, math.max(left + half, right - half)), s
end

-- the bottom of the left-edge buttons, in pixels from the top
function Layout.buttonsBottom(width: number, height: number): number
	return height * Layout.ButtonBarCentre + Layout.ButtonBarHeight / 2 * Layout.scale(width, height)
end

Layout.ToastWidth = 360
Layout.ToastHeight = 32
Layout.ToastGap = 4
Layout.ToastMargin = 8
Layout.ToastStackHeight = 3 * Layout.ToastHeight + 2 * Layout.ToastGap

-- IgnoreGuiInset = false: positions are relative to Roblox's safe area, not the
-- viewport centre. Insets and modal tops are viewport pixels from GetGuiInset and
-- AbsolutePosition. Reserve the full three-pill stack, including stroke clearance,
-- so promoting a waiting message cannot push the stack across an open modal.
function Layout.toasts(width: number, height: number, insetTop: number, insetBottom: number,
	modalTops: { number }?): (number, number, number, boolean)
	local s = math.min(Layout.scale(width, height), (width - 2 * Layout.ToastMargin) / Layout.ToastWidth)
	local y = Layout.ToastMargin
	local bottom = insetTop + y + Layout.ToastStackHeight * s + Layout.ToastMargin
	local limit = height - insetBottom
	if modalTops then
		for _, modalTop in modalTops do limit = math.min(limit, modalTop) end
	end
	local allowed = bottom <= limit
	return width / 2, s, y, allowed
end

-- Give notifications their own lane instead of drawing over the HUD's cash text.
function Layout.toastHudTop(scale: number, count: number): number
	if count == 0 then return 10 end
	return Layout.ToastMargin * 2 + (count * Layout.ToastHeight + (count - 1) * Layout.ToastGap) * scale
end

-- A single first-session card below the goal panel. The pair moves as one so
-- landscape phones can keep both above the thumbstick/jump corners. If the HUD
-- or an open panel leaves no safe space, hold the tracker until there is room.
Layout.GoalWidth = 230
Layout.GoalHeight = 150
Layout.TrackerHeight = 72
Layout.TrackerGap = 8
Layout.TrackerStackHeight = Layout.GoalHeight + Layout.TrackerGap + Layout.TrackerHeight
export type Rect = { left: number, top: number, right: number, bottom: number }
export type TrackerPlacement = { x: number, y: number, scale: number, visible: boolean }
function Layout.tracker(width: number, height: number, insetTop: number, insetBottom: number,
	touch: boolean, preferredTop: number, obstacles: { Rect }, panelOpen: boolean): TrackerPlacement
	local s = Layout.scale(width, height)
	local right = width - 12
	local left = right - Layout.GoalWidth * s
	local limit = math.min(height - insetBottom, if touch then height * 0.62 else height)
	local maxY = limit - insetTop - Layout.TrackerStackHeight * s - 8
	local y = math.max(8, math.min(preferredTop, maxY))
	local blockers = table.clone(obstacles)
	if not touch then
		table.insert(blockers, { left = width - Layout.PlayerListWidth, right = width,
			top = insetTop, bottom = insetTop + Layout.PlayerListHeight })
	end
	for _ = 1, #blockers + 1 do
		local moved = false
		for _, rect in blockers do
			if left < rect.right + 8 and right > rect.left - 8
				and insetTop + y < rect.bottom + 8 and insetTop + y + Layout.TrackerStackHeight * s > rect.top - 8 then
				y = rect.bottom - insetTop + 8
				moved = true
			end
		end
		if not moved then break end
	end
	return { x = right, y = y, scale = s, visible = not panelOpen and left >= 8 and y <= maxY }
end

return Layout
