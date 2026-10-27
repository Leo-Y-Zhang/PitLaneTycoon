--!strict
-- Pit Lane Tycoon polish: world bursts, music, sound effects, the settings panel (music and sounds on or
-- off, kept with the player's save) and how buttons feel: they grow under the pointer, dip
-- when pressed and click. Every sound comes from a Roblox-licensed library (Config.Audio).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Layout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Layout"))
local Icons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Icons"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Bursts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BurstPool"))
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
	elseif kind == "bought" or kind == "hired" then
		buy:Play()
	elseif kind == "built" then
		build:Play()
	end
end)

-- World feedback: six reusable emitters/highlights, attached to Terrain so plot rebuilds
-- cannot destroy the pool. No extra Parts, asset textures, or particle queues.
type Burst = { holder: Attachment, emitter: ParticleEmitter, glow: Highlight, tween: Tween? }
local leases = Bursts.new()
local bursts: { Burst } = {}
local feedback = Instance.new("Folder")
feedback.Name = "PitLaneFeedback"
feedback.Parent = workspace
for _ = 1, Bursts.SlotLimit do
	local holder = Instance.new("Attachment")
	holder.Name = "FeedbackBurst"
	holder.Parent = workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Rate = 0
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.LockedToPart = false
	emitter.Parent = holder -- keep the built-in default texture
	local glow = Instance.new("Highlight")
	glow.Enabled = false
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Parent = feedback
	table.insert(bursts, { holder = holder, emitter = emitter, glow = glow })
end
local function resetBurst(entry: Burst)
	entry.emitter:Clear()
	if entry.tween then entry.tween:Cancel(); entry.tween = nil end
	entry.glow.Enabled = false
	entry.glow.Adornee = nil
end
local function clearBursts()
	Bursts.clear(leases)
	for _, entry in bursts do resetBurst(entry) end
end
player:GetAttributeChangedSignal("ReduceMotion"):Connect(function()
	if player:GetAttribute("ReduceMotion") == true then clearBursts() end
end)
player.CharacterRemoving:Connect(clearBursts)

local rainbow = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 75, 90)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 50)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(75, 235, 120)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(65, 175, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(170, 90, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 215)),
})
local gold = Color3.fromRGB(255, 205, 60)

local function glowSlot(index: number, token: number, tier: string, count: number, attempt: number)
	if leases.slots[index].token ~= token or leases.slots[index].expiresAt <= os.clock() then return end
	local plots = workspace:FindFirstChild("Plots")
	local plot = plots and plots:FindFirstChild("Plot" .. tostring(player:GetAttribute("Plot") or 0))
	local items = plot and plot:FindFirstChild("Items")
	local shelf = items and items:FindFirstChild("Shelf")
	local slot = shelf and shelf:FindFirstChild(tier .. "Slot" .. count)
	-- The effect remote can arrive before the replacement cabinet replicates.
	if not shelf or (shelf:GetAttribute(tier) or 0) < count or not slot then
		if attempt < 12 then task.delay(0.05, glowSlot, index, token, tier, count, attempt + 1) end
		return
	end
	local entry = bursts[index]
	entry.glow.Adornee = slot
	entry.glow.FillColor = if tier == "Gold" then gold else Color3.fromRGB(225, 100, 255)
	entry.glow.OutlineColor = entry.glow.FillColor
	entry.glow.FillTransparency, entry.glow.OutlineTransparency = 0.15, 0
	entry.glow.Enabled = true
	local tween = TweenService:Create(entry.glow, TweenInfo.new(0.65), { FillTransparency = 1, OutlineTransparency = 1 })
	entry.tween = tween
	tween:Play()
end

remotes:WaitForChild("Effect").OnClientEvent:Connect(function(kind: string, arg: any, position: Vector3?, colour: Color3?)
	local profileKind: string
	if kind == "bought" or kind == "built" then profileKind = "purchase"
	elseif kind == "season" then profileKind = "season"
	elseif kind == "rare" and type(arg) == "table" and (arg.tier == "Gold" or arg.tier == "Rainbow") then
		profileKind = if arg.tier == "Gold" then "gold" else "rainbow"
	else return end
	if typeof(position) ~= "Vector3" or typeof(colour) ~= "Color3" then return end
	local index, token = Bursts.acquire(leases, profileKind, os.clock(), player:GetAttribute("ReduceMotion") == true)
	if not index or not token then return end
	local profile = Bursts.Profiles[profileKind]
	local entry = bursts[index]
	resetBurst(entry)
	entry.holder.WorldCFrame = CFrame.new(position)
	local emitter = entry.emitter
	local confetti = profileKind == "season"
	local rare = profileKind == "gold" or profileKind == "rainbow"
	emitter.Color = if confetti or profileKind == "rainbow" then rainbow
		elseif profileKind == "gold" then ColorSequence.new(gold) else ColorSequence.new(colour)
	emitter.Lifetime = NumberRange.new(profile.duration * 0.65, profile.duration)
	emitter.Speed = if confetti then NumberRange.new(12, 22) elseif rare then NumberRange.new(3, 8) else NumberRange.new(8, 14)
	emitter.SpreadAngle = if confetti then Vector2.new(100, 100) else Vector2.new(70, 70)
	emitter.Acceleration = Vector3.new(0, if confetti then -18 else -8, 0)
	emitter.Drag = if confetti then 1.5 else 0
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-150, 150)
	emitter.Squash = NumberSequence.new(if confetti then 1.4 else 0)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if confetti then 0.5 elseif rare then 0.35 else 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter:Emit(profile.count)
	if kind == "rare" and type(arg.count) == "number" and arg.count >= 1 and arg.count <= 6 then
		glowSlot(index, token, arg.tier, arg.count, 0)
	end
	task.delay(profile.duration, function()
		if Bursts.release(leases, index, token) then resetBurst(entry) end
	end)
end)

-- buttons: grow under the pointer, dip when pressed, click ---------------------------
local function feel(b: GuiButton)
	if b:FindFirstChild("Feel") then return end
	local s = new("UIScale", { Name = "Feel" }, b)
	local active: Tween? = nil
	local function to(size: number)
		if active then active:Cancel() end
		if player:GetAttribute("ReduceMotion") == true then
			s.Scale = 1
			return
		end
		local tween = TweenService:Create(s, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = size })
		active = tween
		tween:Play()
	end
	local motionConnection = player:GetAttributeChangedSignal("ReduceMotion"):Connect(function()
		if player:GetAttribute("ReduceMotion") == true then to(1) end
	end)
	b.Destroying:Connect(function()
		motionConnection:Disconnect()
		if active then active:Cancel() end
	end)
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
Icons.draw(open, "settings", INK)
local panel = new("Frame", {
	Name = "SettingsPanel", Position = UDim2.fromOffset(12, Layout.SettingsPanelTop), Size = UDim2.fromOffset(244, Layout.SettingsPanelHeight),
	BackgroundColor3 = PANEL, BackgroundTransparency = 0.05, Visible = false,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, panel)
local settingsScale = new("UIScale", {}, panel)
local function rescaleSettings()
	local view = workspace.CurrentCamera.ViewportSize
	settingsScale.Scale = Layout.scale(view.X, view.Y)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescaleSettings)
rescaleSettings()
local function toggle(y: number, label: string, setting: string, attribute: string, isOn: () -> boolean)
	new("TextLabel", {
		Position = UDim2.fromOffset(14, y), Size = UDim2.fromOffset(136, 40), BackgroundTransparency = 1, Text = label,
		Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = INK, TextXAlignment = Enum.TextXAlignment.Left,
	}, panel)
	local b = new("TextButton", {
		Name = setting, Position = UDim2.fromOffset(154, y + 4), Size = UDim2.fromOffset(76, 32), Font = Enum.Font.GothamBold,
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
	player:GetAttributeChangedSignal(attribute):Connect(show)
	show()
end
toggle(14, "Music", "music", "MusicOn", musicOn)
toggle(59, "Sounds", "sfx", "SfxOn", soundsOn)
toggle(104, "Reduce motion", "reduceMotion", "ReduceMotion", function()
	return player:GetAttribute("ReduceMotion") == true
end)
open.Activated:Connect(function()
	panel.Visible = not panel.Visible
end)

-- start the music once the save has said whether the player wants it
task.delay(2, apply)
