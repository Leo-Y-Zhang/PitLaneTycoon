--!strict
-- Where the HUD's panels go for a given screen, worked out without Roblox APIs so
-- tests/Layout.spec.luau can check phones and laptops in CI.

local Layout = {}

Layout.TopBarWidth = 360
-- Roblox's player list, top right on a computer: about 315 px with Seasons and Cash
-- (measured in Studio on 25 Oct 2026)
Layout.PlayerListWidth = 330
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

return Layout
