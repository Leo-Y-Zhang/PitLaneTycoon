-- Pit Lane Tycoon driving: steers the player's race car and shows the lap timer. The car's
-- VehicleSeat reads the keyboard (WASD or arrows), a gamepad or a phone's thumbstick;
-- DriveModel turns that into speed and turn rate, and this script hands them to the car's
-- LinearVelocity and AngularVelocity. Each drive opens with a start-light sequence on the
-- gantry, and the engine and tyres are heard. The server times the laps (Racing.luau).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local DriveModel = require(Shared:WaitForChild("DriveModel"))
local TrackShape = require(Shared:WaitForChild("TrackShape"))
local player = Players.LocalPlayer

local INK = Color3.fromRGB(245, 246, 248)
local PANEL = Color3.fromRGB(17, 20, 24)
local GOLD = Color3.fromRGB(255, 205, 60)
local RED = Color3.fromRGB(255, 80, 70)

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

local function lapTime(seconds: number): string
	return ("%d:%05.2f"):format(seconds // 60, seconds % 60)
end

-- the lap panel, top centre under the cash bar, shown while driving --------------------
local gui = new("ScreenGui", { Name = "PitLaneDrive", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))
local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 112), Size = UDim2.fromOffset(360, 100),
	BackgroundColor3 = PANEL, BackgroundTransparency = 0.15, Visible = false,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, panel)
local scale = new("UIScale", {}, panel)
local clock = new("TextLabel", {
	Size = UDim2.new(1, -20, 0, 38), Position = UDim2.fromOffset(10, 4), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = INK, Text = "Out lap",
}, panel)
local times = new("TextLabel", {
	Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 44), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = GOLD, Text = "",
}, panel)
local speedo = new("TextLabel", {
	Name = "Speed", Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 72), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = INK, Text = "",
}, panel)

-- sounds: the engine follows the speed, the tyres squeal in a slide, the lights beep
local effects = SoundService:WaitForChild("PitLaneEffects", 10) -- Polish.client.luau's group (the Sounds setting)
local function sound(name: string, looped: boolean, volume: number): Sound
	return new("Sound", {
		Name = "PitLane_" .. name, SoundId = "rbxassetid://" .. Config.Audio[name], Looped = looped, Volume = volume,
		SoundGroup = effects,
	}, SoundService)
end
local engine = sound("engine", true, 0.35)
local skid = sound("skid", true, 0)
local lightBeep = sound("light", false, 0.5)
local goBeep = sound("go", false, 0.6)

-- the start lights on the gantry, changed only on this player's screen
local RED_ON, RED_OFF = Color3.fromRGB(255, 40, 40), Color3.fromRGB(40, 12, 12)
local function setLights(lit: number)
	local track = workspace:FindFirstChild("Track")
	for i = 1, 5 do
		local light = track and track:FindFirstChild("StartLight" .. i) :: BasePart?
		if light then
			light.Color = i <= lit and RED_ON or RED_OFF
			light.Material = i <= lit and Enum.Material.Neon or Enum.Material.SmoothPlastic
		end
	end
end
local startedAt: number? = nil -- os.clock when this drive's lights began
local hold = 0
local shown = -1

local function rescale()
	local view = workspace.CurrentCamera.ViewportSize
	scale.Scale = math.clamp(math.min(view.X / 900, view.Y / 560), 0.65, 1)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()

local function refreshPanel(go: boolean, lit: number)
	local start = player:GetAttribute("LapStart") or 0
	if not go then
		clock.Text = string.rep("●", lit) .. string.rep("○", 5 - lit)
		clock.TextColor3 = RED
	elseif startedAt and os.clock() - startedAt < 5 * DriveModel.LightGap + hold + 1.2 then
		clock.Text = "GO!"
		clock.TextColor3 = Color3.fromRGB(46, 204, 113)
	elseif start <= 0 then
		clock.Text = "Out lap: cross the line"
		clock.TextColor3 = INK
	elseif player:GetAttribute("LapValid") == false then
		clock.Text = "Lap void: " .. tostring(player:GetAttribute("LapProblem") or "track limits")
		clock.TextColor3 = RED
	else
		clock.Text = lapTime(math.max(0, workspace:GetServerTimeNow() - start))
		clock.TextColor3 = INK
	end
	local reverse = player:GetAttribute("Layout") == "reverse"
	local last, best = player:GetAttribute("LastLap"), player:GetAttribute(reverse and "BestLapReverse" or "BestLap") or 0
	times.Text = ("%sLast %s   Best %s"):format(reverse and "Reverse GP   " or "", last and lapTime(last) or "-",
		best > 0 and lapTime(best) or "-")
end

-- driving ---------------------------------------------------------------------------
RunService.Heartbeat:Connect(function(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local driving = seat ~= nil and seat:IsA("VehicleSeat") and seat:GetAttribute("RaceCar") == true
	panel.Visible = driving
	-- below the live event's strip when one is running
	panel.Position = UDim2.new(0.5, 0, 0, (workspace:GetAttribute("EventName") or "") ~= "" and 152 or 112)
	if not driving then
		if startedAt then -- out of the car: lights back to how everyone sees them, engine off
			startedAt = nil
			setLights(5)
			engine:Stop()
			skid:Stop()
		end
		return
	end
	if not startedAt then
		startedAt = os.clock()
		hold = 0.4 + math.random() * 0.8
		shown = -1
		engine:Play()
		skid:Play()
	end
	local lit, go = DriveModel.lights(os.clock() - (startedAt :: number), hold)
	if lit ~= shown then -- a light came on, or they all went out
		shown = lit
		setLights(lit)
		if go then
			goBeep:Play()
		elseif lit > 0 then
			lightBeep:Play()
		end
	end
	refreshPanel(go, lit)
	local car = (seat :: VehicleSeat).Parent :: Model
	local chassis = car.PrimaryPart
	local drive = chassis and chassis:FindFirstChild("Drive") :: LinearVelocity?
	local steer = chassis and chassis:FindFirstChild("Steer") :: AngularVelocity?
	if not (chassis and drive and steer) then
		return
	end
	local look = chassis.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z).Unit
	local velocity = chassis.AssemblyLinearVelocity
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	local _, offset = TrackShape.nearest(Config.Track, chassis.Position.X, chassis.Position.Z)
	local offroad = math.abs(offset) > Config.Track.halfWidth + 1
	local along = flat:Dot(forward)
	local top = car:GetAttribute("TopSpeed") or Config.Drive.topSpeed
	-- held on the grid until the lights go out
	local throttle = go and (seat :: VehicleSeat).ThrottleFloat or 0
	local speed, turn = DriveModel.step(along, throttle, (seat :: VehicleSeat).SteerFloat, dt, top, offroad, Config.Drive)
	-- grip: sideways motion dies away a little behind the steering, so the car slides a
	-- touch through fast bends instead of running on rails
	local sideways = flat - forward * along
	local v = forward * speed + sideways * (1 - math.min(1, Config.Drive.grip * dt))
	drive.PlaneVelocity = Vector2.new(v.X, v.Z)
	steer.AngularVelocity = Vector3.new(0, turn, 0)
	-- a stud is taken as a metre, as most Roblox racers do
	speedo.Text = ("%d km/h"):format(math.floor(math.abs(along) * 3.6 + 0.5))
	engine.PlaybackSpeed = 0.75 + 0.85 * math.clamp(math.abs(along) / top, 0, 1)
	engine.Volume = 0.25 + 0.2 * math.abs(throttle)
	skid.Volume = math.clamp((sideways.Magnitude - 6) / 20, 0, 0.5)
end)
