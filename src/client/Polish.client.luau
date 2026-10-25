-- Pit Lane Tycoon polish: music, sound effects, the settings panel (music and sounds on or
-- off, kept with the player's save) and how buttons feel: they grow under the pointer, dip
-- when pressed and click. Every sound comes from a Roblox-licensed library (Config.Audio).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local INK = Color3.fromRGB(245, 246, 248)
local PANEL = Color3.fromRGB(17, 20, 24)
local GREEN = Color3.fromRGB(46, 204, 113)
local GREY = Color3.fromRGB(60, 64, 70)
local MUSIC_VOLUME, EFFECTS_VOLUME = 0.3, 0.7

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

-- sounds ----------------------------------------------------------------------------
local musicGroup = new("SoundGroup", { Name = "PitLaneMusic", Volume = MUSIC_VOLUME }, SoundService)
local effectsGroup = new("SoundGroup", { Name = "PitLaneEffects", Volume = EFFECTS_VOLUME }, SoundService)
local function effect(name: string, volume: number): Sound
	return new("Sound", {
		Name = "PitLane_" .. name, SoundId = "rbxassetid://" .. Config.Audio[name], Volume = volume, SoundGroup = effectsGroup,
	}, SoundService)
end
local click = effect("click", 0.4)
local cash = effect("cash", 0.5)
local buy = effect("buy", 0.6)
local build = effect("build", 0.5)

-- music: the playlist in a shuffled order, one track after another
local tracks: { Sound } = {}
for i, id in Config.Audio.music do
	tracks[i] = new("Sound", { Name = "PitLane_Music" .. i, SoundId = "rbxassetid://" .. id, SoundGroup = musicGroup }, SoundService)
end
for i = #tracks, 2, -1 do
	local j = math.random(i)
	tracks[i], tracks[j] = tracks[j], tracks[i]
end
local current = 0
local function playNext()
	current = current % #tracks + 1
	tracks[current]:Play()
end
for _, track in tracks do
	track.Ended:Connect(playNext)
end

local function musicOn(): boolean
	return player:GetAttribute("MusicOn") ~= false
end
local function soundsOn(): boolean
	return player:GetAttribute("SfxOn") ~= false
end
local function apply()
	effectsGroup.Volume = soundsOn() and EFFECTS_VOLUME or 0
	local track = tracks[current]
	if musicOn() then
		musicGroup.Volume = MUSIC_VOLUME
		if not track then
			playNext()
		elseif track.IsPaused then
			track:Resume()
		end
	elseif track and track.IsPlaying then
		track:Pause()
	end
end
player:GetAttributeChangedSignal("MusicOn"):Connect(apply)
player:GetAttributeChangedSignal("SfxOn"):Connect(apply)

remotes:WaitForChild("Effect").OnClientEvent:Connect(function(kind: string)
	if kind == "banked" then
		cash:Play()
	elseif kind == "bought" then
		buy:Play()
	elseif kind == "built" then
		build:Play()
	end
end)

-- buttons: grow under the pointer, dip when pressed, click ---------------------------
local function feel(b: GuiButton)
	if b:FindFirstChild("Feel") then return end
	local s = new("UIScale", { Name = "Feel" }, b)
	local function to(size: number)
		TweenService:Create(s, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = size }):Play()
	end
	b.MouseEnter:Connect(function()
		to(1.05)
	end)
	b.MouseLeave:Connect(function()
		to(1)
	end)
	b.MouseButton1Down:Connect(function()
		to(0.94)
	end)
	b.MouseButton1Up:Connect(function()
		to(1)
	end)
	b.Activated:Connect(function()
		click:Play()
	end)
end
local function hook(gui: Instance)
	for _, d in gui:GetDescendants() do
		if d:IsA("GuiButton") then
			feel(d)
		end
	end
	gui.DescendantAdded:Connect(function(d)
		if d:IsA("GuiButton") then
			feel(d)
		end
	end)
end
local playerGui = player:WaitForChild("PlayerGui")
for _, name in { "PitLaneHud", "PitLaneDrive", "PitLaneSettings" } do
	task.spawn(function()
		local found = playerGui:WaitForChild(name, 30)
		if found then
			hook(found)
		end
	end)
end

-- settings: a button top left with a sliders icon, and a small panel ------------------
local gui = new("ScreenGui", { Name = "PitLaneSettings", ResetOnSpawn = false }, playerGui)
local open = new("TextButton", {
	Name = "SettingsButton", Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(44, 44),
	BackgroundColor3 = PANEL, BackgroundTransparency = 0.1, Text = "", AutoButtonColor = true,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 10) }, open)
for i, knob in { 0.3, 0.7, 0.45 } do -- three sliders
	local y = 10 + (i - 1) * 11
	new("Frame", { Position = UDim2.fromOffset(10, y + 1), Size = UDim2.fromOffset(24, 2), BackgroundColor3 = INK,
		BorderSizePixel = 0 }, open)
	local dot = new("Frame", { Position = UDim2.fromOffset(10 + knob * 24 - 3, y - 2), Size = UDim2.fromOffset(7, 7),
		BackgroundColor3 = Color3.fromRGB(255, 205, 60), BorderSizePixel = 0 }, open)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
end
local panel = new("Frame", {
	Name = "SettingsPanel", Position = UDim2.fromOffset(12, 62), Size = UDim2.fromOffset(200, 120),
	BackgroundColor3 = PANEL, BackgroundTransparency = 0.05, Visible = false,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, panel)
local function toggle(y: number, label: string, setting: string, isOn: () -> boolean)
	new("TextLabel", {
		Position = UDim2.fromOffset(14, y), Size = UDim2.fromOffset(90, 40), BackgroundTransparency = 1, Text = label,
		Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = INK, TextXAlignment = Enum.TextXAlignment.Left,
	}, panel)
	local b = new("TextButton", {
		Name = setting, Position = UDim2.fromOffset(110, y + 4), Size = UDim2.fromOffset(76, 32), Font = Enum.Font.GothamBold,
		TextSize = 15, TextColor3 = INK, AutoButtonColor = true,
	}, panel)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, b)
	local function show()
		b.Text = isOn() and "On" or "Off"
		b.BackgroundColor3 = isOn() and GREEN or GREY
	end
	b.Activated:Connect(function()
		remotes:WaitForChild("Settings"):FireServer(setting, not isOn())
	end)
	player:GetAttributeChangedSignal(setting == "music" and "MusicOn" or "SfxOn"):Connect(show)
	show()
end
toggle(14, "Music", "music", musicOn)
toggle(64, "Sounds", "sfx", soundsOn)
open.Activated:Connect(function()
	panel.Visible = not panel.Visible
end)

-- start the music once the save has said whether the player wants it
task.delay(2, apply)
