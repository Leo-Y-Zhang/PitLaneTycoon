-- Pit Lane Tycoon HUD: cash and income, the next purchase, the shop (and redeem codes), the
-- race and new-season buttons, the current goal and the gift for staying, toasts, and the
-- guide line, sparks and "+$" pop-ups that show where to go next.

local Players = game:GetService("Players")
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
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.42, 0), Size = UDim2.fromOffset(150, 152),
	BackgroundTransparency = 1,
}, gui)
new("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 10) }, bar)
scaled(bar)
local shopButton = button("Shop", RED, bar)
local raceButton = button("Race", Color3.fromRGB(28, 86, 214), bar)
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
local seasonButton = button("New season", Color3.fromRGB(200, 150, 20), bar)
seasonButton.Visible = false
-- the time trial: into your car on the grid, or back out to the garage
raceButton.Activated:Connect(function()
	remotes:WaitForChild("Drive"):FireServer(player:GetAttribute("Driving") ~= true)
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
new("Frame", { Position = UDim2.new(0, -8, 0.5, -7), Size = UDim2.fromOffset(16, 14), BorderSizePixel = 0,
	BackgroundColor3 = Color3.fromRGB(225, 38, 28) }, giftButton)
new("Frame", { Position = UDim2.new(0, -2, 0.5, -7), Size = UDim2.fromOffset(4, 14), BorderSizePixel = 0,
	BackgroundColor3 = Color3.fromRGB(255, 205, 60) }, giftButton)
new("Frame", { Position = UDim2.new(0, -10, 0.5, -10), Size = UDim2.fromOffset(20, 4), BorderSizePixel = 0,
	BackgroundColor3 = Color3.fromRGB(255, 205, 60) }, giftButton)
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
	welcome.Visible = player:GetAttribute("Welcome") == true
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
