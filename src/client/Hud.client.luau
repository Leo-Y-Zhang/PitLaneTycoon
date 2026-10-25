-- Pit Lane Tycoon HUD: cash and income, the next purchase, the shop (and redeem codes), the
-- race, crew and new-season buttons, the pit crew and its crates, the current goal and the
-- gift for staying, toasts, and the guide line, sparks and "+$" pop-ups that show where to go
-- next.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Layout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Layout"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local INK = Color3.fromRGB(245, 246, 248)
local PANEL = Color3.fromRGB(17, 20, 24)
local RED = Color3.fromRGB(225, 38, 28) -- pit-lane red
local GREEN = Color3.fromRGB(46, 204, 113)

local function money(n: number): string
	local units = { "", "K", "M", "B", "T", "Qa" }
	local i = 1
	while math.abs(n) >= 1000 and i < #units do
		n /= 1000
		i += 1
	end
	if i == 1 then
		return "$" .. tostring(math.floor(n))
	end
	return string.format("$%.1f%s", n, units[i])
end

local function new(class: string, props: { [string]: any }, parent: Instance?): any
	local o = Instance.new(class)
	for k, v in props do
		(o :: any)[k] = v
	end
	if parent then
		o.Parent = parent
	end
	return o
end

local function round(o: GuiObject, r: number)
	new("UICorner", { CornerRadius = UDim.new(0, r) }, o)
end

local function button(text: string, color: Color3, parent: Instance): TextButton
	local b = new("TextButton", {
		Size = UDim2.fromOffset(150, 44), BackgroundColor3 = color, Text = text, TextColor3 = INK,
		Font = Enum.Font.GothamBold, TextSize = 18, AutoButtonColor = true,
	}, parent)
	round(b, 10)
	return b
end

local gui = new("ScreenGui", { Name = "PitLaneHud", ResetOnSpawn = false, IgnoreGuiInset = false }, player:WaitForChild("PlayerGui"))

-- every panel is laid out for a laptop and shrinks on a phone held sideways
local scales: { UIScale } = {}
local function scaled(o: GuiObject)
	table.insert(scales, new("UIScale", {}, o))
end
local topScale: UIScale? = nil
local topFrame: Frame? = nil
local function rescale()
	local view = workspace.CurrentCamera.ViewportSize
	local s = Layout.scale(view.X, view.Y)
	for _, u in scales do
		u.Scale = s
	end
	-- the top bar keeps clear of the player list a computer shows top right (Layout)
	if topScale and topFrame then
		local phone = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		local centre, barScale = Layout.topBar(view.X, view.Y, phone)
		topFrame.Position = UDim2.fromOffset(centre, 10)
		topScale.Scale = barScale
	end
end

-- top bar: cash, income, waiting at the pad, and the next purchase -------------------
local top = new("Frame", {
	Name = "TopBar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(360, 92),
	BackgroundColor3 = PANEL, BackgroundTransparency = 0.1,
}, gui)
round(top, 12)
topFrame = top
topScale = new("UIScale", {}, top)
new("UIStroke", { Color = RED, Thickness = 2 }, top)
-- the live event, on a chequered strip under the top bar
local eventBar = new("Frame", {
	Name = "EventBar", Position = UDim2.new(0, 0, 1, 6), Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Color3.fromRGB(255, 205, 60),
	Visible = false,
}, top)
round(eventBar, 8)
local eventLabel = new("TextLabel", {
	Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack,
	TextScaled = true, TextColor3 = Color3.fromRGB(17, 20, 24), Text = "",
}, eventBar)
new("UITextSizeConstraint", { MaxTextSize = 17 }, eventLabel)
local function refreshEvent()
	local name = workspace:GetAttribute("EventName") or ""
	local left = (workspace:GetAttribute("EventEnds") or 0) - workspace:GetServerTimeNow()
	eventBar.Visible = name ~= "" and left > 0
	if eventBar.Visible then
		local s = math.ceil(left)
		eventLabel.Text = ("%s  %d:%02d  %s"):format(string.upper(name), s // 60, s % 60, workspace:GetAttribute("EventText") or "")
	end
end
task.spawn(function()
	while true do
		refreshEvent()
		task.wait(0.5)
	end
end)
local cashLabel = new("TextLabel", {
	Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 4), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack, TextSize = 28, TextColor3 = GREEN, Text = "$0",
}, top)
local subLabel = new("TextLabel", {
	Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 38), BackgroundTransparency = 1,
	Font = Enum.Font.Gotham, TextScaled = true, TextColor3 = INK, Text = "",
}, top)
-- shrink a long line ("$11 waiting at the blue pad") to fit the bar instead of spilling out
new("UITextSizeConstraint", { MaxTextSize = 15 }, subLabel)
local nextBar = new("Frame", {
	Position = UDim2.fromOffset(10, 64), Size = UDim2.new(1, -20, 0, 20), BackgroundColor3 = Color3.fromRGB(40, 44, 50),
}, top)
round(nextBar, 6)
local nextFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(30, 130, 76) }, nextBar)
round(nextFill, 6)
local nextLabel = new("TextLabel", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextScaled = true,
	TextColor3 = INK, Text = "",
}, nextBar)
new("UITextSizeConstraint", { MaxTextSize = 14 }, nextLabel)
new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, nextLabel)

local function cashNow(): number
	local ls = player:FindFirstChild("leaderstats")
	local cash = ls and ls:FindFirstChild("Cash")
	return cash and (cash :: NumberValue).Value or 0
end

local function refreshTop()
	local cash = cashNow()
	cashLabel.Text = money(cash)
	local parts = { "+" .. money(player:GetAttribute("IncomePerMin") or 0) .. "/min" }
	local pending = player:GetAttribute("Pending") or 0
	if pending > 0 then
		table.insert(parts, money(pending) .. " waiting at the blue pad")
	end
	local boost = player:GetAttribute("FriendBoost") or 0
	if boost > 0 then
		table.insert(parts, ("Friends +%d%%"):format(boost))
	end
	if workspace:GetAttribute("HappyHour") then
		table.insert(parts, "2x happy hour")
	end
	table.insert(parts, "Season " .. ((player:GetAttribute("Season") or 0) + 1))
	subLabel.Text = table.concat(parts, "   ")

	local name, cost = player:GetAttribute("NextName") or "", player:GetAttribute("NextCost") or 0
	if name == "" then
		nextLabel.Text = player:GetAttribute("HasTrophy") and "Line complete: start a new season" or ""
		nextFill.Size = UDim2.fromScale(1, 1)
	elseif cash >= cost then
		nextLabel.Text = "Next: " .. name .. " - ready, step on the red pad"
		nextFill.Size = UDim2.fromScale(1, 1)
	else
		nextLabel.Text = ("Next: %s  %s / %s"):format(name, money(cash), money(cost))
		nextFill.Size = UDim2.fromScale(math.clamp(cash / math.max(cost, 1), 0, 1), 1)
	end
end

-- toasts ----------------------------------------------------------------------------
local toast = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.fromOffset(420, 40),
	BackgroundColor3 = PANEL, BackgroundTransparency = 1, TextTransparency = 1, TextColor3 = INK,
	Font = Enum.Font.GothamBold, TextSize = 17, Text = "",
}, gui)
round(toast, 10)
scaled(toast)
local toastToken = 0
local function showToast(text: string)
	toastToken += 1
	local mine = toastToken
	toast.Text = text
	toast.BackgroundTransparency = 0.15
	toast.TextTransparency = 0
	task.delay(2.6, function()
		if mine == toastToken then
			TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		end
	end)
end
remotes:WaitForChild("Notify").OnClientEvent:Connect(showToast)

-- buttons ---------------------------------------------------------------------------
-- left edge, above the middle: clear of a phone's thumbstick (bottom left) and jump button
local bar = new("Frame", {
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.42, 0), Size = UDim2.fromOffset(150, Layout.ButtonBarHeight),
	BackgroundTransparency = 1,
}, gui)
new("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, bar)
scaled(bar)
local shopButton = button("Shop", RED, bar)
shopButton.LayoutOrder = 1
local raceButton = button("Race", Color3.fromRGB(28, 86, 214), bar)
raceButton.LayoutOrder = 2
-- a chequered flag before the word
new("UIPadding", { PaddingLeft = UDim.new(0, 22) }, raceButton)
for col = 0, 2 do
	for row = 0, 1 do
		new("Frame", {
			Position = UDim2.new(0, -6 + col * 6, 0.5, -6 + row * 6), Size = UDim2.fromOffset(6, 6), BorderSizePixel = 0,
			BackgroundColor3 = (col + row) % 2 == 0 and INK or Color3.fromRGB(17, 20, 24),
		}, raceButton)
	end
end
local crewButton = button("Crew", Color3.fromRGB(120, 60, 200), bar)
crewButton.Name = "CrewButton"
crewButton.LayoutOrder = 3
crewButton.Visible = false -- until the crew unlocks
local seasonButton = button("New season", Color3.fromRGB(200, 150, 20), bar)
seasonButton.LayoutOrder = 4
seasonButton.Visible = false
-- the time trial: into your car on the grid, or back out to the garage. Once the Reverse GP
-- is open, Race asks which layout first (the Endurance circuit joins them in season 3).
local chooser = new("Frame", {
	Name = "LayoutChooser", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 172, 0.42, 0),
	Size = UDim2.fromOffset(150, 152), BackgroundTransparency = 1, Visible = false,
}, gui)
new("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 10) }, chooser)
scaled(chooser)
for _, choice in {
	{ "Grand Prix", "gp", Color3.fromRGB(28, 86, 214) },
	{ "Reverse GP", "reverse", Color3.fromRGB(120, 60, 200) },
	{ "Endurance", "long", Color3.fromRGB(214, 110, 20) },
} do
	local b = button(choice[1], choice[3], chooser)
	b.Name = choice[2]
	if choice[2] == "long" then
		local function show()
			b.Visible = player:GetAttribute("LongUnlocked") == true
		end
		player:GetAttributeChangedSignal("LongUnlocked"):Connect(show)
		show()
	end
	b.Activated:Connect(function()
		chooser.Visible = false
		remotes:WaitForChild("Drive"):FireServer(true, choice[2])
	end)
end
raceButton.Activated:Connect(function()
	if player:GetAttribute("Driving") == true then
		remotes:WaitForChild("Drive"):FireServer(false)
	elseif player:GetAttribute("ReverseUnlocked") == true then
		chooser.Visible = not chooser.Visible
	else
		remotes:WaitForChild("Drive"):FireServer(true, "gp")
	end
end)

-- shop ------------------------------------------------------------------------------
local shop = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(380, 410),
	BackgroundColor3 = PANEL, Visible = false,
}, gui)
round(shop, 14)
scaled(shop)
new("UIStroke", { Color = RED, Thickness = 2 }, shop)
new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 22,
	TextColor3 = INK, Text = "Team shop",
}, shop)
local list = new("ScrollingFrame", {
	Position = UDim2.fromOffset(14, 50), Size = UDim2.new(1, -28, 1, -164), BackgroundTransparency = 1,
	ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
}, shop)
new("UIListLayout", { Padding = UDim.new(0, 8) }, list)
local close = button("Close", Color3.fromRGB(60, 64, 70), shop)
close.AnchorPoint = Vector2.new(0.5, 1)
close.Position = UDim2.new(0.5, 0, 1, -12)

local PASS_TEXT = {
	DoubleCash = "2x Cash: double everything your factory earns",
	AutoCollect = "Auto-collect: earnings go straight to the bank",
	VIP = "VIP: 1.25x earnings and the VIP tag",
}
local rows = 0
local function row(text: string, onBuy: () -> ())
	rows += 1
	local r = new("TextButton", {
		Size = UDim2.new(1, -8, 0, 52), BackgroundColor3 = Color3.fromRGB(32, 36, 42), Text = text,
		TextColor3 = INK, Font = Enum.Font.GothamMedium, TextSize = 15, TextWrapped = true, AutoButtonColor = true,
	}, list)
	round(r, 10)
	r.Activated:Connect(onBuy)
end
for name, id in Config.Passes do
	if id ~= 0 then
		row(PASS_TEXT[name] or name, function()
			if not player:GetAttribute("Owns" .. name) then
				MarketplaceService:PromptGamePassPurchase(player, id)
			else
				showToast("You already own this pass")
			end
		end)
	end
end
for _, product in Config.Products do
	if product.id ~= 0 then
		row(("%s: %d minutes of income"):format(product.name, product.minutes), function()
			MarketplaceService:PromptProductPurchase(player, product.id)
		end)
	end
end
if rows == 0 then
	new("TextLabel", {
		Size = UDim2.new(1, -8, 0, 60), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 16,
		TextColor3 = INK, TextWrapped = true, Text = "The shop opens soon. Keep building!",
	}, list)
end
-- redeem codes: typed here, checked on the server (the list never reaches the player)
local codeBox = new("TextBox", {
	Position = UDim2.new(0, 14, 1, -106), Size = UDim2.new(1, -150, 0, 40), BackgroundColor3 = Color3.fromRGB(32, 36, 42),
	PlaceholderText = "Have a code?", PlaceholderColor3 = Color3.fromRGB(140, 146, 156), Text = "", TextColor3 = INK,
	Font = Enum.Font.GothamBold, TextSize = 16, ClearTextOnFocus = false,
}, shop)
round(codeBox, 8)
local redeemButton = button("Redeem", GREEN, shop)
redeemButton.Size = UDim2.fromOffset(112, 40)
redeemButton.Position = UDim2.new(1, -126, 1, -106)
local redeeming = false
redeemButton.Activated:Connect(function()
	if redeeming or codeBox.Text == "" then return end
	redeeming = true
	local ok, message = pcall(function()
		return remotes:WaitForChild("Redeem"):InvokeServer(codeBox.Text)
	end)
	showToast(ok and tostring(message) or "Try again in a moment")
	if ok and string.find(tostring(message), "+$", 1, true) then
		codeBox.Text = ""
	end
	redeeming = false
end)

shopButton.Activated:Connect(function()
	shop.Visible = not shop.Visible
end)
close.Activated:Connect(function()
	shop.Visible = false
end)

-- pit crew: every member as a card (the ones not hired yet greyed out), the odds, and crates
local PURPLE = Color3.fromRGB(120, 60, 200)
local crewPanel = new("Frame", {
	Name = "CrewPanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(440, 500), BackgroundColor3 = PANEL, Visible = false,
}, gui)
round(crewPanel, 14)
scaled(crewPanel)
new("UIStroke", { Color = PURPLE, Thickness = 2 }, crewPanel)
new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 22,
	TextColor3 = INK, Text = "Pit crew",
}, crewPanel)
local crewSummary = new("TextLabel", {
	Name = "Summary", Position = UDim2.fromOffset(14, 40), Size = UDim2.new(1, -28, 0, 20), BackgroundTransparency = 1,
	Font = Enum.Font.GothamMedium, TextScaled = true, TextColor3 = Color3.fromRGB(200, 204, 212),
}, crewPanel)
new("UITextSizeConstraint", { MaxTextSize = 14 }, crewSummary)
local cards = new("ScrollingFrame", {
	Name = "Cards", Position = UDim2.fromOffset(14, 128), Size = UDim2.new(1, -28, 1, -230), BackgroundTransparency = 1,
	ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
}, crewPanel)
new("UIGridLayout", { CellSize = UDim2.fromOffset(128, 84), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, cards)
local oddsParts = {}
for _, r in Config.Crew.rarities do
	table.insert(oddsParts, ("%s %g%%"):format(r.name, r.chance * 100))
end
new("TextLabel", {
	Name = "Odds", Position = UDim2.new(0, 14, 1, -98), Size = UDim2.new(1, -28, 0, 18), BackgroundTransparency = 1,
	Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = Color3.fromRGB(150, 156, 166),
	Text = "Crate odds: " .. table.concat(oddsParts, "  ·  "),
}, crewPanel)
local hire = button("Open crate", GREEN, crewPanel)
hire.Name = "OpenCrate"
hire.Size = UDim2.new(1, -182, 0, 48)
hire.Position = UDim2.new(0, 14, 1, -66)
local crewClose = button("Close", Color3.fromRGB(60, 64, 70), crewPanel)
crewClose.Size = UDim2.fromOffset(140, 48)
crewClose.Position = UDim2.new(1, -154, 1, -66)

local function rarityColour(member): Color3
	local c = Config.Crew.rarities[member.rarity].colour
	return Color3.fromRGB(c[1], c[2], c[3])
end
local function boostText(member): string
	local parts = {}
	if member.income > 0 then
		table.insert(parts, ("+%d%% income"):format(math.floor(member.income * 100 + 0.5)))
	end
	if (member.rare or 1) > 1 then
		table.insert(parts, ("rare parts x%g"):format(member.rare))
	end
	return table.concat(parts, ", ")
end
local function memberOf(key: string?)
	for _, member in Config.Crew.members do
		if member.key == key then
			return member
		end
	end
	return nil
end

-- Scout's pick: one member at a fixed price, the same in every server, changing on a timer
local pickStrip = new("Frame", {
	Name = "Pick", Position = UDim2.fromOffset(14, 66), Size = UDim2.new(1, -28, 0, 54),
	BackgroundColor3 = Color3.fromRGB(32, 36, 42),
}, crewPanel)
round(pickStrip, 10)
local pickStroke = new("UIStroke", { Color = PURPLE, Thickness = 2 }, pickStrip)
local pickTimer = new("TextLabel", {
	Name = "Timer", Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -150, 0, 16), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.fromRGB(255, 205, 60),
	TextXAlignment = Enum.TextXAlignment.Left,
}, pickStrip)
local pickName = new("TextLabel", {
	Name = "Member", Position = UDim2.fromOffset(12, 24), Size = UDim2.new(1, -150, 0, 22), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = INK, TextXAlignment = Enum.TextXAlignment.Left,
}, pickStrip)
new("UITextSizeConstraint", { MaxTextSize = 16 }, pickName)
local pickButton = button("Hire", GREEN, pickStrip)
pickButton.Name = "HirePick"
pickButton.AnchorPoint = Vector2.new(1, 0.5)
pickButton.Position = UDim2.new(1, -8, 0.5, 0)
pickButton.Size = UDim2.fromOffset(128, 40)
pickButton.TextSize = 15
local function refreshPick()
	local member = memberOf(workspace:GetAttribute("PickKey"))
	pickStrip.Visible = member ~= nil
	if not member then return end
	local left = math.max(0, math.floor((workspace:GetAttribute("PickEnds") or 0) - workspace:GetServerTimeNow()))
	pickTimer.Text = ("SCOUT'S PICK  ·  a new one in %d:%02d"):format(left // 60, left % 60)
	pickName.Text = ("%s  ·  %s  ·  %s"):format(member.name, Config.Crew.rarities[member.rarity].name, boostText(member))
	pickName.TextColor3 = rarityColour(member)
	pickStroke.Color = rarityColour(member)
	local hired = player:GetAttribute("PickHired") == true
	pickButton.Text = hired and "Hired" or ("Hire  " .. money(player:GetAttribute("PickPrice") or 0))
	pickButton.BackgroundColor3 = hired and Color3.fromRGB(60, 64, 70) or GREEN
end
local cardOf = {}
for i, member in Config.Crew.members do
	local card = new("Frame", { Name = member.key, LayoutOrder = i, BackgroundColor3 = Color3.fromRGB(32, 36, 42) }, cards)
	round(card, 10)
	new("Frame", { Size = UDim2.new(1, 0, 0, 6), BorderSizePixel = 0, BackgroundColor3 = rarityColour(member) }, card)
	local name = new("TextLabel", {
		Name = "Name", Position = UDim2.fromOffset(8, 10), Size = UDim2.new(1, -16, 0, 20), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = INK, TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false, Text = member.name,
	}, card)
	new("TextLabel", {
		Position = UDim2.fromOffset(8, 30), Size = UDim2.new(1, -16, 0, 16), BackgroundTransparency = 1, Font = Enum.Font.Gotham,
		TextSize = 12, TextColor3 = rarityColour(member), TextXAlignment = Enum.TextXAlignment.Left,
		Text = Config.Crew.rarities[member.rarity].name,
	}, card)
	local boost = new("TextLabel", {
		Position = UDim2.fromOffset(8, 46), Size = UDim2.new(1, -16, 0, 14), BackgroundTransparency = 1, Font = Enum.Font.Gotham,
		TextScaled = true, TextColor3 = Color3.fromRGB(200, 204, 212), TextXAlignment = Enum.TextXAlignment.Left,
		Text = boostText(member),
	}, card)
	new("UITextSizeConstraint", { MaxTextSize = 12 }, boost) -- a two-part boost shrinks to fit
	local count = new("TextLabel", {
		Name = "Count", Position = UDim2.fromOffset(8, 62), Size = UDim2.new(1, -16, 0, 16), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = GREEN, TextXAlignment = Enum.TextXAlignment.Left,
	}, card)
	cardOf[member.key] = { card = card, name = name, count = count }
end

-- the crate opens: names flick past, then the one hired lands in its rarity's colour
local reveal = new("Frame", {
	Name = "Reveal", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -20), Size = UDim2.fromOffset(300, 132),
	BackgroundColor3 = Color3.fromRGB(24, 27, 32), Visible = false, ZIndex = 5,
}, crewPanel)
round(reveal, 14)
local revealStroke = new("UIStroke", { Color = PURPLE, Thickness = 3 }, reveal)
local revealScale = new("UIScale", {}, reveal)
local revealTier = new("TextLabel", {
	Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack,
	TextSize = 18, TextColor3 = INK, ZIndex = 6,
}, reveal)
local revealName = new("TextLabel", {
	Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack,
	TextSize = 28, TextColor3 = INK, ZIndex = 6,
}, reveal)
local revealBoost = new("TextLabel", {
	Position = UDim2.fromOffset(0, 88), Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium,
	TextSize = 16, TextColor3 = Color3.fromRGB(200, 204, 212), ZIndex = 6,
}, reveal)
local revealToken = 0
local function showReveal(key: string)
	revealToken += 1
	local token = revealToken
	local members = Config.Crew.members
	reveal.Visible = true
	revealBoost.Text = ""
	revealTier.Text = "Hiring..."
	revealTier.TextColor3 = INK
	revealStroke.Color = PURPLE
	for i = 1, 10 do
		local m = members[math.random(1, #members)]
		revealName.Text = m.name
		revealName.TextColor3 = rarityColour(m)
		task.wait(0.04 + i * 0.012)
		if token ~= revealToken then return end
	end
	for _, m in members do
		if m.key == key then
			local colour = rarityColour(m)
			revealTier.Text = string.upper(Config.Crew.rarities[m.rarity].name)
			revealTier.TextColor3 = colour
			revealName.Text = m.name
			revealName.TextColor3 = colour
			revealBoost.Text = boostText(m)
			revealStroke.Color = colour
		end
	end
	revealScale.Scale = 0.6
	TweenService:Create(revealScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.wait(1.8)
	if token == revealToken then
		reveal.Visible = false
	end
end

local function refreshCrew()
	crewButton.Visible = player:GetAttribute("CrewUnlocked") == true
	hire.Text = "Open crate  " .. money(player:GetAttribute("CratePrice") or 0)
	local ok, owned = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("CrewOwned") or "{}")
	end)
	owned = ok and type(owned) == "table" and owned or {}
	local working = {}
	for _, key in string.split(player:GetAttribute("CrewWorking") or "", ",") do
		if key ~= "" then
			working[key] = (working[key] or 0) + 1
		end
	end
	for key, c in cardOf do
		local n = owned[key] or 0
		c.card.BackgroundTransparency = n > 0 and 0 or 0.55
		c.name.TextColor3 = n > 0 and INK or Color3.fromRGB(130, 136, 146)
		if n == 0 then
			c.count.Text = "Not hired yet"
			c.count.TextColor3 = Color3.fromRGB(130, 136, 146)
		else
			c.count.Text = ("x%d%s"):format(n, working[key] and ("  ·  %d in the garage"):format(working[key]) or "")
			c.count.TextColor3 = working[key] and GREEN or Color3.fromRGB(200, 204, 212)
		end
	end
	local income, rare = player:GetAttribute("CrewIncome") or 0, player:GetAttribute("CrewRare") or 1
	refreshPick()
	crewSummary.Text = ("Best %d at work in the garage: +%d%% income%s"):format(Config.Crew.slots, income,
		rare > 1 and (", rare parts x%g"):format(rare) or "")
end

local hiring = false
hire.Activated:Connect(function()
	if hiring then return end
	hiring = true
	local ok, key, why = pcall(function()
		return remotes:WaitForChild("OpenCrate"):InvokeServer()
	end)
	hiring = false
	if ok and key then
		showReveal(key) -- a quicker crate cuts this one's reveal short
	else
		showToast(ok and tostring(why) or "Try again in a moment")
	end
end)
pickButton.Activated:Connect(function()
	if hiring or player:GetAttribute("PickHired") == true then return end
	hiring = true
	local ok, key, why = pcall(function()
		return remotes:WaitForChild("HirePick"):InvokeServer()
	end)
	hiring = false
	if ok and key then
		showReveal(key)
	else
		showToast(ok and tostring(why) or "Try again in a moment")
	end
end)
workspace:GetAttributeChangedSignal("PickKey"):Connect(refreshPick)
task.spawn(function()
	while true do -- the countdown
		if crewPanel.Visible then
			refreshPick()
		end
		task.wait(1)
	end
end)
crewButton.Activated:Connect(function()
	crewPanel.Visible = not crewPanel.Visible
	shop.Visible = false
end)
shopButton.Activated:Connect(function()
	crewPanel.Visible = false
end)
crewClose.Activated:Connect(function()
	crewPanel.Visible = false
end)

-- new season ------------------------------------------------------------------------
local confirm = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(380, 230),
	BackgroundColor3 = PANEL, Visible = false,
}, gui)
round(confirm, 14)
scaled(confirm)
new("UIStroke", { Color = Color3.fromRGB(200, 150, 20), Thickness = 2 }, confirm)
local confirmText = new("TextLabel", {
	Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 140), BackgroundTransparency = 1,
	Font = Enum.Font.GothamMedium, TextSize = 17, TextColor3 = INK, TextWrapped = true, Text = "",
}, confirm)
local go = button("Start season", Color3.fromRGB(200, 150, 20), confirm)
go.Position = UDim2.new(0, 24, 1, -60)
local cancel = button("Not yet", Color3.fromRGB(60, 64, 70), confirm)
cancel.Position = UDim2.new(1, -174, 1, -60)

seasonButton.Activated:Connect(function()
	local season = (player:GetAttribute("Season") or 0) + 1
	local text = ("Start season %d? It costs %s and resets your garage, but every season adds +%d%% to all earnings for good.")
		:format(season + 1, money(player:GetAttribute("SeasonCost") or 0), math.floor(Config.SeasonBonus * 100))
	local unlocks = {}
	for _, item in Config.Items do
		if item.season == season then
			table.insert(unlocks, item.name)
		end
	end
	if #unlocks > 0 then
		text ..= "\nNew machines: " .. table.concat(unlocks, ", ") .. "."
	end
	confirmText.Text = text
	confirm.Visible = true
end)
go.Activated:Connect(function()
	confirm.Visible = false
	remotes:WaitForChild("NewSeason"):FireServer()
end)
cancel.Activated:Connect(function()
	confirm.Visible = false
end)

-- where to go next: a guide line, sparks and "+$" (Polish.client.luau plays the sounds) --
local guide = new("Beam", {
	Name = "PitLaneGuide", Enabled = false, FaceCamera = true, Segments = 1, Width0 = 0.3, Width1 = 0.3,
	LightEmission = 1, Color = ColorSequence.new(Color3.fromRGB(255, 205, 60)), Transparency = NumberSequence.new(0.35),
}, workspace)
local guideFrom: Attachment?, guideTo: Attachment? = nil, nil

local function myPlot(): Instance?
	local index = player:GetAttribute("Plot") or 0
	local plots = workspace:FindFirstChild("Plots")
	return index > 0 and plots and plots:FindFirstChild("Plot" .. index) or nil
end

-- to the red pad when the next item is affordable, to the blue pad when the cash waiting
-- there would cover it, and nowhere while the factory is still earning
-- the like prompt on your own garage's sign is for other players
local function hideOwnLike()
	local plot = myPlot()
	local prompt = plot and plot:FindFirstChild("Sign") and plot.Sign:FindFirstChild("Like")
	if prompt then
		(prompt :: ProximityPrompt).Enabled = false
	end
end

local function refreshGuide()
	local plot = myPlot()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local key, cost = player:GetAttribute("NextKey") or "", player:GetAttribute("NextCost") or 0
	local cash, pending = cashNow(), player:GetAttribute("Pending") or 0
	local target = nil
	if plot and root and key ~= "" then
		if cash >= cost then
			target = plot:FindFirstChild("Buy_" .. key)
		elseif cash + pending >= cost then
			target = plot:FindFirstChild("CollectPad")
		end
	end
	if not (target and root) then
		guide.Enabled = false
		return
	end
	if not guideFrom or guideFrom.Parent ~= root then
		if guideFrom then guideFrom:Destroy() end
		guideFrom = new("Attachment", { Name = "GuideFrom" }, root)
	end
	if not guideTo or guideTo.Parent ~= target then
		if guideTo then guideTo:Destroy() end
		guideTo = new("Attachment", { Name = "GuideTo", Position = Vector3.new(0, 0.4, 0) }, target)
	end
	guide.Attachment0, guide.Attachment1 = guideFrom, guideTo
	guide.Enabled = true
end

local function sparks(at: BasePart)
	local holder = new("Attachment", { Position = Vector3.new(0, at.Size.Y / 2, 0) }, at)
	local burst = new("ParticleEmitter", {
		Rate = 0, Speed = NumberRange.new(8, 14), Lifetime = NumberRange.new(0.5, 0.9), SpreadAngle = Vector2.new(70, 70),
		LightEmission = 1, Color = ColorSequence.new(Color3.fromRGB(255, 205, 60)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
	}, holder)
	burst:Emit(30)
	Debris:AddItem(holder, 1.5)
end

local function popUp(text: string)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	-- built whole before it goes on the character, so it appears with its text
	local board = new("BillboardGui", { Size = UDim2.fromOffset(160, 40), StudsOffset = Vector3.new(0, 3, 0), AlwaysOnTop = true })
	local label = new("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true,
		TextColor3 = GREEN, TextStrokeTransparency = 0.3, Text = text,
	}, board)
	board.Parent = root
	TweenService:Create(board, TweenInfo.new(1.1), { StudsOffset = Vector3.new(0, 6, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(1.1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(board, 1.2)
end

remotes:WaitForChild("Effect").OnClientEvent:Connect(function(kind: string, arg: any)
	local plot = myPlot()
	if kind == "banked" then
		popUp("+" .. money(arg))
	elseif kind == "bought" and plot then
		local items = plot:FindFirstChild("Items")
		local spot = items and items:FindFirstChild(arg) or plot:FindFirstChild("Buy_" .. arg)
		if spot and spot:IsA("BasePart") then
			sparks(spot)
		end
	end
end)

-- the first visit: three lines on how the game works, until "Let's go" or the first buy --
local welcome = new("Frame", {
	Name = "Welcome", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(440, 250),
	BackgroundColor3 = PANEL, BackgroundTransparency = 0.05, Visible = false,
}, gui)
round(welcome, 14)
scaled(welcome)
new("UIStroke", { Color = Color3.fromRGB(255, 205, 60), Thickness = 2 }, welcome)
new("TextLabel", {
	Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -36, 0, 34), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack,
	TextSize = 22, TextColor3 = INK, Text = "Welcome to your garage",
}, welcome)
for i, line in {
	"Your presses make car parts. They ride the conveyor to scrutineering and earn cash.",
	"Bank the cash on the blue pad, then step on the red pad to buy the next machine.",
	"Press Race any time to drive your team's car round the track.",
} do
	new("TextLabel", {
		Position = UDim2.fromOffset(18, 52 + (i - 1) * 44), Size = UDim2.new(1, -36, 0, 40), BackgroundTransparency = 1,
		Font = Enum.Font.Gotham, TextSize = 15, TextWrapped = true, TextColor3 = INK, TextXAlignment = Enum.TextXAlignment.Left,
		Text = i .. ".  " .. line,
	}, welcome)
end
local letsGo = button("Let's go", GREEN, welcome)
letsGo.AnchorPoint = Vector2.new(0.5, 1)
letsGo.Position = UDim2.new(0.5, 0, 1, -14)
letsGo.Activated:Connect(function()
	welcome.Visible = false
	remotes:WaitForChild("Welcomed"):FireServer()
end)

-- the current goal and the gift for staying, right edge (clear of the jump button) -----
local goals = new("Frame", {
	Name = "GoalPanel", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.52, 0), Size = UDim2.fromOffset(230, 150),
	BackgroundColor3 = PANEL, BackgroundTransparency = 0.15,
}, gui)
round(goals, 12)
scaled(goals)
new("TextLabel", {
	Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 14), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack, TextSize = 12, TextColor3 = Color3.fromRGB(255, 205, 60),
	TextXAlignment = Enum.TextXAlignment.Left, Text = "GOAL",
}, goals)
local goalReward = new("TextLabel", {
	Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 14), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = GREEN, TextXAlignment = Enum.TextXAlignment.Right, Text = "",
}, goals)
local goalText = new("TextLabel", {
	Position = UDim2.fromOffset(12, 26), Size = UDim2.new(1, -24, 0, 22), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = INK, TextXAlignment = Enum.TextXAlignment.Left, Text = "",
}, goals)
new("UITextSizeConstraint", { MaxTextSize = 17 }, goalText)
local goalBar = new("Frame", {
	Position = UDim2.fromOffset(12, 54), Size = UDim2.new(1, -24, 0, 16), BackgroundColor3 = Color3.fromRGB(40, 44, 50),
}, goals)
round(goalBar, 8)
local goalFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(255, 205, 60) }, goalBar)
round(goalFill, 8)
local goalCount = new("TextLabel", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 12,
	TextColor3 = INK, TextStrokeTransparency = 0.5, Text = "", ZIndex = 2,
}, goalBar)
local giftButton = button("Gift", Color3.fromRGB(60, 64, 70), goals)
giftButton.Position = UDim2.fromOffset(12, 88)
giftButton.Size = UDim2.new(1, -24, 0, 48)
giftButton.TextSize = 16
-- a little gift box before the words
new("UIPadding", { PaddingLeft = UDim.new(0, 24) }, giftButton)
for _, piece in { -- lid, box, ribbon, two bow loops
	{ -10, -7, 20, 5, Color3.fromRGB(225, 38, 28) }, { -8, -2, 16, 11, Color3.fromRGB(225, 38, 28) },
	{ -2, -7, 4, 16, Color3.fromRGB(255, 205, 60) }, { -7, -11, 5, 4, Color3.fromRGB(255, 205, 60) },
	{ 2, -11, 5, 4, Color3.fromRGB(255, 205, 60) },
} do
	new("Frame", { Position = UDim2.new(0, piece[1], 0.5, piece[2]), Size = UDim2.fromOffset(piece[3], piece[4]),
		BorderSizePixel = 0, BackgroundColor3 = piece[5] }, giftButton)
end
giftButton.Activated:Connect(function()
	remotes:WaitForChild("ClaimGift"):FireServer()
end)

local function lapText(seconds: number): string
	return ("%d:%05.2f"):format(seconds // 60, seconds % 60)
end

local function refreshGoal()
	local text = player:GetAttribute("GoalText") or ""
	if text == "" then
		goalText.Text = "Every goal done!"
		goalReward.Text = ""
		goalFill.Size = UDim2.fromScale(1, 1)
		goalCount.Text = ""
		return
	end
	goalText.Text = text
	goalReward.Text = "+" .. money(player:GetAttribute("GoalReward") or 0)
	local kind = player:GetAttribute("GoalKind")
	local have, need = player:GetAttribute("GoalHave") or 0, math.max(player:GetAttribute("GoalNeed") or 1, 1)
	goalFill.Size = UDim2.fromScale(math.clamp(have / need, 0, 1), 1)
	if kind == "earned" then
		goalCount.Text = money(have) .. " / " .. money(need)
	elseif kind == "lapUnder" then
		local best = player:GetAttribute("BestLap") or 0
		goalCount.Text = best > 0 and ("Best lap " .. lapText(best)) or "Press Race to drive"
	elseif kind == "trophy" or kind == "season" then
		goalCount.Text = ""
	else
		goalCount.Text = ("%d / %d"):format(have, need)
	end
end

-- the gift counts down here; the server decides when it is ready
local function refreshGift()
	local left = (player:GetAttribute("GiftAt") or math.huge) - workspace:GetServerTimeNow()
	if left <= 0 then
		giftButton.Text = "Claim your gift!"
		giftButton.BackgroundColor3 = GREEN
	else
		local s = math.ceil(left)
		giftButton.Text = ("Gift in %d:%02d"):format(s // 60, s % 60)
		giftButton.BackgroundColor3 = Color3.fromRGB(60, 64, 70)
	end
end
task.spawn(function()
	while true do
		refreshGift()
		task.wait(1)
	end
end)

-- keep it current -------------------------------------------------------------------
local function refreshAll()
	refreshTop()
	refreshGuide()
	seasonButton.Visible = player:GetAttribute("HasTrophy") == true
	raceButton.Text = player:GetAttribute("Driving") == true and "Leave car" or "Race"
	refreshGoal()
	refreshGift()
	refreshCrew()
	welcome.Visible = player:GetAttribute("Welcome") == true
	hideOwnLike()
end
player.AttributeChanged:Connect(refreshAll)
workspace:GetAttributeChangedSignal("HappyHour"):Connect(refreshTop)
player.CharacterAdded:Connect(function(character)
	character:WaitForChild("HumanoidRootPart", 10)
	refreshGuide()
end)
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
task.spawn(function()
	local ls = player:WaitForChild("leaderstats")
	ls:WaitForChild("Cash").Changed:Connect(refreshAll)
	refreshAll()
end)
rescale()
refreshAll()
