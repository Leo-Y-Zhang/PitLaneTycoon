-- Pit Lane Tycoon HUD: cash and income, the shop, the new-season button and toasts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
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

-- top bar: cash, income, waiting at the pad ----------------------------------------
local top = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(360, 62),
	BackgroundColor3 = PANEL, BackgroundTransparency = 0.1,
}, gui)
round(top, 12)
new("UIStroke", { Color = RED, Thickness = 2 }, top)
local cashLabel = new("TextLabel", {
	Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 4), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack, TextSize = 28, TextColor3 = GREEN, Text = "$0",
}, top)
local subLabel = new("TextLabel", {
	Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 38), BackgroundTransparency = 1,
	Font = Enum.Font.Gotham, TextSize = 15, TextColor3 = INK, Text = "",
}, top)

local function refreshTop()
	local ls = player:FindFirstChild("leaderstats")
	local cash = ls and ls:FindFirstChild("Cash")
	cashLabel.Text = money(cash and cash.Value or 0)
	local parts = { "+" .. money(player:GetAttribute("IncomePerMin") or 0) .. "/min" }
	local pending = player:GetAttribute("Pending") or 0
	if pending > 0 then
		table.insert(parts, money(pending) .. " waiting at the blue pad")
	end
	table.insert(parts, "Season " .. ((player:GetAttribute("Season") or 0) + 1))
	subLabel.Text = table.concat(parts, "   ")
end

-- toasts ----------------------------------------------------------------------------
local toast = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.fromOffset(420, 40),
	BackgroundColor3 = PANEL, BackgroundTransparency = 1, TextTransparency = 1, TextColor3 = INK,
	Font = Enum.Font.GothamBold, TextSize = 17, Text = "",
}, gui)
round(toast, 10)
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
local bar = new("Frame", { Position = UDim2.new(0, 12, 1, -60), Size = UDim2.fromOffset(320, 48), BackgroundTransparency = 1 }, gui)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10) }, bar)
local shopButton = button("Shop", RED, bar)
local seasonButton = button("New season", Color3.fromRGB(200, 150, 20), bar)
seasonButton.Visible = false

-- shop ------------------------------------------------------------------------------
local shop = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(380, 360),
	BackgroundColor3 = PANEL, Visible = false,
}, gui)
round(shop, 14)
new("UIStroke", { Color = RED, Thickness = 2 }, shop)
new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 22,
	TextColor3 = INK, Text = "Team shop",
}, shop)
local list = new("ScrollingFrame", {
	Position = UDim2.fromOffset(14, 50), Size = UDim2.new(1, -28, 1, -110), BackgroundTransparency = 1,
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
shopButton.Activated:Connect(function()
	shop.Visible = not shop.Visible
end)
close.Activated:Connect(function()
	shop.Visible = false
end)

-- new season ------------------------------------------------------------------------
local confirm = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(380, 190),
	BackgroundColor3 = PANEL, Visible = false,
}, gui)
round(confirm, 14)
new("UIStroke", { Color = Color3.fromRGB(200, 150, 20), Thickness = 2 }, confirm)
local confirmText = new("TextLabel", {
	Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 100), BackgroundTransparency = 1,
	Font = Enum.Font.GothamMedium, TextSize = 17, TextColor3 = INK, TextWrapped = true, Text = "",
}, confirm)
local go = button("Start season", Color3.fromRGB(200, 150, 20), confirm)
go.Position = UDim2.new(0, 24, 1, -60)
local cancel = button("Not yet", Color3.fromRGB(60, 64, 70), confirm)
cancel.Position = UDim2.new(1, -174, 1, -60)

seasonButton.Activated:Connect(function()
	local season = (player:GetAttribute("Season") or 0) + 1
	confirmText.Text = ("Start season %d? It costs %s and resets your garage, but every season adds +%d%% to all earnings for good.")
		:format(season + 1, money(player:GetAttribute("SeasonCost") or 0), math.floor(Config.SeasonBonus * 100))
	confirm.Visible = true
end)
go.Activated:Connect(function()
	confirm.Visible = false
	remotes:WaitForChild("NewSeason"):FireServer()
end)
cancel.Activated:Connect(function()
	confirm.Visible = false
end)

-- keep it current -------------------------------------------------------------------
local function refreshAll()
	refreshTop()
	seasonButton.Visible = player:GetAttribute("HasTrophy") == true
end
player.AttributeChanged:Connect(refreshAll)
task.spawn(function()
	local ls = player:WaitForChild("leaderstats")
	ls:WaitForChild("Cash").Changed:Connect(refreshTop)
	refreshAll()
end)
refreshAll()
