--!strict
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
local GuiService = game:GetService("GuiService")

local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Feedback = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HudFeedback"))
local Icons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Icons"))
local Layout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Layout"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local INK = Color3.fromRGB(245, 246, 248)
local PANEL = Color3.fromRGB(17, 20, 24)
local RED = Color3.fromRGB(225, 38, 28) -- pit-lane red
local GREEN = Color3.fromRGB(46, 204, 113)

local money = Feedback.money

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

-- One active tween per target; toggling motion off also settles in-flight effects.
local animations: { [Instance]: { tween: Tween, goals: { [string]: any } } } = {}
local function reduceMotion(): boolean
	return player:GetAttribute("ReduceMotion") == true
end
local function animate(target: Instance, info: TweenInfo, goals: { [string]: any })
	local previous = animations[target]
	if previous then previous.tween:Cancel() end
	if reduceMotion() then
		for key, value in goals do (target :: any)[key] = value end
		animations[target] = nil
		return
	end
	local tween = TweenService:Create(target, info, goals)
	animations[target] = { tween = tween, goals = goals }
	tween.Completed:Once(function()
		if animations[target] and animations[target].tween == tween then animations[target] = nil end
	end)
	tween:Play()
end
player:GetAttributeChangedSignal("ReduceMotion"):Connect(function()
	if not reduceMotion() then return end
	for target, animation in animations do
		animation.tween:Cancel()
		for key, value in animation.goals do (target :: any)[key] = value end
		animations[target] = nil
	end
end)

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

local gui = new("ScreenGui", { Name = "PitLaneHud", ResetOnSpawn = false, IgnoreGuiInset = false,
	DisplayOrder = 10, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

-- every panel is laid out for a laptop and shrinks on a phone held sideways
local scales: { UIScale } = {}
local function scaled(o: GuiObject)
	table.insert(scales, new("UIScale", {}, o))
end
-- the panels that open in the middle: on a computer they keep clear of the player list
local panels: { { frame: GuiObject, width: number, scale: UIScale } } = {}
local renderToasts: () -> () = function() end
local modalFrames: { GuiObject } = {}
local function watchModal(o: GuiObject)
	table.insert(modalFrames, o)
	-- Respond to harness toggles and geometry changes as well as button clicks.
	for _, property in { "Visible", "AbsolutePosition", "AbsoluteSize" } do
		o:GetPropertyChangedSignal(property):Connect(function() renderToasts() end)
	end
end
local function centred(o: GuiObject)
	table.insert(panels, { frame = o, width = o.Size.X.Offset, scale = new("UIScale", {}, o) })
	watchModal(o)
end
local topScale: UIScale? = nil
local topFrame: Frame? = nil
local eventVisible = false
local function rescale()
	local view = workspace.CurrentCamera.ViewportSize
	local s = Layout.scale(view.X, view.Y)
	for _, u in scales do
		u.Scale = s
	end
	-- the top bar and the middle panels keep clear of the player list a computer shows top right (Layout)
	local phone = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	for _, p in panels do
		local centre, panelScale = Layout.panel(view.X, view.Y, p.width, phone)
		p.frame.Position = UDim2.new(0, centre, 0.5, 0)
		p.scale.Scale = panelScale
	end
	if topScale and topFrame then
		local centre, barScale = Layout.topBar(view.X, view.Y, phone)
		topFrame.Position = UDim2.fromOffset(centre, 10)
		topScale.Scale = barScale
	end
	renderToasts()
end

-- top bar: cash, income, waiting at the pad, and the next purchase -------------------
local top = new("Frame", {
	Name = "TopBar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(360, Layout.TopBarHeight),
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
	if eventVisible ~= eventBar.Visible then
		eventVisible = eventBar.Visible
		rescale()
	end
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
Icons.draw(cashLabel, "cash", GREEN)
local cashScale = new("UIScale", {}, cashLabel)
local displayedCash = new("NumberValue", { Name = "DisplayedCash" }, gui)
local targetCash: number? = nil
local cashTweenInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
displayedCash.Changed:Connect(function(value: number)
	cashLabel.Text = money(value)
end)
local function updateCash(cash: number)
	if cash == targetCash then return end
	local previous = targetCash
	targetCash = cash
	if previous == nil then
		displayedCash.Value = cash
	else
		animate(displayedCash, cashTweenInfo, { Value = cash })
		if cash > previous and not reduceMotion() then
			cashScale.Scale = 1.08
			animate(cashScale, TweenInfo.new(0.22, Enum.EasingStyle.Quad), { Scale = 1 })
		end
	end
end
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

-- The line must be complete AND the season fee banked; the server still decides eligibility.
local seasonBar = new("Frame", {
	Name = "SeasonProgress", Position = UDim2.fromOffset(10, 92), Size = UDim2.new(1, -20, 0, 22),
	BackgroundColor3 = Color3.fromRGB(40, 44, 50),
}, top)
round(seasonBar, 6)
local seasonFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(145, 103, 20) }, seasonBar)
round(seasonFill, 6)
local seasonLabel = new("TextLabel", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
	TextScaled = true, TextColor3 = INK, Text = "",
}, seasonBar)
new("UITextSizeConstraint", { MaxTextSize = 13 }, seasonLabel)

local function cashNow(): number
	local ls = player:FindFirstChild("leaderstats")
	local cash = ls and ls:FindFirstChild("Cash")
	return cash and (cash :: NumberValue).Value or 0
end

local seasonItems: { Feedback.ProgressItem } = {}
for _, item in Config.Items do
	table.insert(seasonItems, { key = item.key, season = item.season })
end

local function refreshTop()
	local cash = cashNow()
	updateCash(cash)
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
	local season = player:GetAttribute("Season") or 0
	local trophy = player:GetAttribute("HasTrophy") == true
	local fee = player:GetAttribute("SeasonCost") or Config.SeasonCost(season)
	local progress, built, total = Feedback.seasonProgress(seasonItems, season,
		player:GetAttribute("NextKey") or "", trophy, cash, fee)
	local size = UDim2.fromScale(progress, 1)
	if seasonFill:GetAttribute("Progress") ~= progress then
		seasonFill:SetAttribute("Progress", progress)
		animate(seasonFill, TweenInfo.new(0.3), { Size = size })
	end
	if not trophy then
		seasonLabel.Text = ("Season %d: build the line  %d / %d"):format(season + 2, built, total)
	elseif cash < fee then
		seasonLabel.Text = ("Season %d: %s / %s"):format(season + 2, money(cash), money(fee))
	else
		seasonLabel.Text = ("Season %d ready!  +%d%% earnings"):format(season + 2, Config.SeasonBonus * 100)
	end
end

-- toasts ----------------------------------------------------------------------------
-- Three reusable cards, with a bounded FIFO waiting behind them.
local toastQueue = Feedback.newQueue()
local host = new("Frame", {
	Name = "Toasts", AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.fromOffset(Layout.ToastWidth, Layout.ToastStackHeight),
	BackgroundTransparency = 1, Visible = false, ZIndex = 100,
}, gui)
local toastScale = new("UIScale", {}, host)
new("UIListLayout", {
	Padding = UDim.new(0, Layout.ToastGap), SortOrder = Enum.SortOrder.LayoutOrder,
}, host)
local toastCards: { { label: TextLabel, id: number } } = {}
for _ = 1, Feedback.ToastLimit do
	local label = new("TextLabel", {
		Size = UDim2.fromOffset(Layout.ToastWidth, Layout.ToastHeight), BackgroundColor3 = PANEL, BackgroundTransparency = 0,
		TextColor3 = INK, Font = Enum.Font.GothamBold, TextScaled = true, Text = "", Visible = false, ZIndex = 101,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, host)
	round(label, 16)
	new("UIStroke", { Color = GREEN, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, label)
	new("UITextSizeConstraint", { MaxTextSize = 16 }, label)
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
	}, label)
	table.insert(toastCards, { label = label, id = 0 })
end
local function placeToasts(): boolean
	local view = workspace.CurrentCamera.ViewportSize
	local insetTop, insetBottom = GuiService:GetGuiInset()
	local modalTops: { number } = {}
	for _, frame in modalFrames do
		if frame.Visible then
			table.insert(modalTops, frame.AbsolutePosition.Y)
		end
	end
	local centre, scale, y, allowed = Layout.toasts(view.X, view.Y, insetTop.Y, insetBottom.Y, modalTops)
	if not allowed then
		-- no room above an open panel: never hide feedback, draw over its top edge instead
		-- (the pills are opaque and layered above every panel)
		centre, scale, y, allowed = Layout.toasts(view.X, view.Y, insetTop.Y, insetBottom.Y, {})
	end
	host.Position = UDim2.fromOffset(centre, y)
	toastScale.Scale = scale
	host.Visible = allowed
	return not allowed
end
renderToasts = function()
	Feedback.advance(toastQueue, os.clock(), placeToasts())
	if topFrame then
		topFrame.Position = UDim2.new(topFrame.Position.X,
			UDim.new(0, Layout.toastHudTop(toastScale.Scale, host.Visible and #toastQueue.visible or 0)))
	end
	for _, card in toastCards do
		local alive = false
		for _, entry in toastQueue.visible do
			if entry.id == card.id then alive = true end
		end
		if not alive then
			card.id = 0
			card.label.Visible = false
		end
	end
	for row, entry in toastQueue.visible do
		local card = nil
		for _, candidate in toastCards do
			if candidate.id == entry.id then card = candidate; break end
		end
		if not card then
			for _, candidate in toastCards do
				if candidate.id == 0 then card = candidate; break end
			end
			if card then
				card.id = entry.id
				card.label.Text = entry.text
				card.label.TextTransparency = 1
				animate(card.label, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { TextTransparency = 0 })
				card.label.Visible = true
			end
		end
		if card then
			-- List slots settle immediately: sliding could cross another pill.
			card.label.LayoutOrder = row
		end
	end
end
local function showToast(text: string)
	Feedback.enqueue(toastQueue, text, os.clock(), placeToasts())
	renderToasts()
end
remotes:WaitForChild("Notify").OnClientEvent:Connect(showToast)
task.spawn(function()
	while true do
		renderToasts()
		task.wait(0.1)
	end
end)

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
Icons.button(shopButton, "cash", INK)
Icons.button(raceButton, "race", INK)
local crewButton = button("Crew", Color3.fromRGB(120, 60, 200), bar)
crewButton.Name = "CrewButton"
crewButton.LayoutOrder = 3
Icons.button(crewButton, "crew", INK)
crewButton.Visible = false -- until the crew unlocks
local seasonButton = button("New season", Color3.fromRGB(200, 150, 20), bar)
seasonButton.LayoutOrder = 4
Icons.button(seasonButton, "goal", INK)
seasonButton.Visible = false
-- the time trial: into your car on the grid, or back out to the garage. Once the Reverse GP
-- is open, Race asks which layout first (the Endurance circuit joins them in season 3).
local chooser = new("Frame", {
	Name = "LayoutChooser", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 172, 0.42, 0),
	Size = UDim2.fromOffset(150, 152), BackgroundTransparency = 1, Visible = false,
}, gui)
new("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 10) }, chooser)
scaled(chooser)
watchModal(chooser)
for _, choice in {
	{ label = "Grand Prix", key = "gp", colour = Color3.fromRGB(28, 86, 214) },
	{ label = "Reverse GP", key = "reverse", colour = Color3.fromRGB(120, 60, 200) },
	{ label = "Endurance", key = "long", colour = Color3.fromRGB(214, 110, 20) },
} do
	local b = button(choice.label, choice.colour, chooser)
	b.Name = choice.key
	if choice.key == "long" then
		local function show()
			b.Visible = player:GetAttribute("LongUnlocked") == true
		end
		player:GetAttributeChangedSignal("LongUnlocked"):Connect(show)
		show()
	end
	b.Activated:Connect(function()
		chooser.Visible = false
		remotes:WaitForChild("Drive"):FireServer(true, choice.key)
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
centred(shop)
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
	local passName = tostring(name)
	if id ~= 0 then
		row(PASS_TEXT[name] or name, function()
			if not player:GetAttribute("Owns" .. passName) then
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
centred(crewPanel)
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

local function rarityColour(member: typeof(Config.Crew.members[1])): Color3
	local c = Config.Crew.rarities[member.rarity].colour
	return Color3.fromRGB(c[1], c[2], c[3])
end
local function boostText(member: typeof(Config.Crew.members[1])): string
	local parts = {}
	if member.income > 0 then
		table.insert(parts, ("+%d%% income"):format(math.floor(member.income * 100 + 0.5)))
	end
	if (member.rare or 1) > 1 then
		table.insert(parts, ("rare parts x%g"):format(member.rare or 1))
	end
	return table.concat(parts, ", ")
end
local function memberOf(key: string?): typeof(Config.Crew.members[1])?
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
		if reduceMotion() then break end
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
	revealScale.Scale = reduceMotion() and 1 or 0.6
	animate(revealScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
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
centred(confirm)
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
	local sign = plot and plot:FindFirstChild("Sign")
	local prompt = sign and sign:FindFirstChild("Like")
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
	local target: Instance? = nil
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
	if reduceMotion() then return end
	local holder = new("Attachment", { Position = Vector3.new(0, at.Size.Y / 2, 0) }, at)
	local burst = new("ParticleEmitter", {
		Rate = 0, Speed = NumberRange.new(8, 14), Lifetime = NumberRange.new(0.5, 0.9), SpreadAngle = Vector2.new(70, 70),
		LightEmission = 1, Color = ColorSequence.new(Color3.fromRGB(255, 205, 60)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
	}, holder)
	burst:Emit(30)
	Debris:AddItem(holder, 1.5)
end

-- Fixed pool: bursts and auto-collect never allocate more than six billboards.
type CashPopup = { board: BillboardGui, label: TextLabel, token: number }
local popupPool: { CashPopup } = {}
for _ = 1, 6 do
	local board = new("BillboardGui", {
		Size = UDim2.fromOffset(160, 40), AlwaysOnTop = true, Enabled = false, MaxDistance = 120,
	})
	local label = new("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true,
		TextColor3 = GREEN, TextStrokeTransparency = 0.3, Text = "",
	}, board)
	table.insert(popupPool, { board = board, label = label, token = 0 })
end
local function resetPopup(entry: CashPopup)
	entry.token += 1
	for _, target in { entry.board :: Instance, entry.label :: Instance } do
		local active = animations[target]
		if active then active.tween:Cancel(); animations[target] = nil end
	end
	entry.board.Enabled = false
	entry.board.Parent = nil
end
-- Detach pooled instances before Roblox destroys the old character on respawn.
player.CharacterRemoving:Connect(function()
	for _, entry in popupPool do resetPopup(entry) end
end)
local popupCursor = 0
local function popUp(text: string)
	local plot = myPlot()
	local collector = plot and plot:FindFirstChild("CollectPad")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not collector or not collector:IsA("BasePart") then return end
	popupCursor = popupCursor % #popupPool + 1
	local entry = popupPool[popupCursor]
	-- A reused slot cancels both old tweens before restoring opacity and position.
	resetPopup(entry)
	local token = entry.token
	entry.board.Adornee = collector
	entry.board.StudsOffsetWorldSpace = Vector3.new((popupCursor % 3 - 1) * 1.2, 2 + (popupCursor % 2) * 0.6, 0)
	entry.label.Text = text
	entry.label.TextTransparency = 0
	entry.label.TextStrokeTransparency = 0.3
	-- Keep the existing character-root path used by the smoke test; Adornee anchors it to the collector.
	entry.board.Parent = root
	entry.board.Enabled = true
	if not reduceMotion() then
		animate(entry.board, TweenInfo.new(1.1), { StudsOffsetWorldSpace = entry.board.StudsOffsetWorldSpace + Vector3.new(0, 3, 0) })
		animate(entry.label, TweenInfo.new(1.1), { TextTransparency = 1, TextStrokeTransparency = 1 })
	end
	task.delay(1.2, function()
		if entry.token ~= token then return end
		resetPopup(entry)
	end)
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
centred(welcome)
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
Icons.button(giftButton, "gift", INK)
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
		-- the next pad can reach this computer after the attribute that names it, with
		-- nothing changing afterwards to redraw the guide line
		refreshGuide()
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
-- Settings live in the polish script; they use the same obstruction rule.
task.spawn(function()
	local settingsGui = player:WaitForChild("PlayerGui"):WaitForChild("PitLaneSettings")
	local settings = settingsGui:WaitForChild("SettingsPanel")
	if settings:IsA("GuiObject") then
		watchModal(settings)
		renderToasts()
	end
end)
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
task.spawn(function()
	local ls = player:WaitForChild("leaderstats")
	ls:WaitForChild("Cash").Changed:Connect(refreshAll)
	refreshAll()
end)
rescale()
refreshAll()
