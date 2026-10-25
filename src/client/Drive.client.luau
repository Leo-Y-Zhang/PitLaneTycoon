-- Pit Lane Tycoon driving: steers the player's race car and shows the lap timer. The car's
-- VehicleSeat reads the keyboard (WASD or arrows), a gamepad or a phone's thumbstick;
-- DriveModel turns that into speed and turn rate, and this script hands them to the car's
-- LinearVelocity and AngularVelocity. The server times the laps (Racing.luau).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 112), Size = UDim2.fromOffset(360, 74),
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

local function rescale()
	local view = workspace.CurrentCamera.ViewportSize
	scale.Scale = math.clamp(math.min(view.X / 900, view.Y / 560), 0.65, 1)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()

local function refreshPanel()
	local start = player:GetAttribute("LapStart") or 0
	if start <= 0 then
		clock.Text = "Out lap: cross the line"
		clock.TextColor3 = INK
	elseif player:GetAttribute("LapValid") == false then
		clock.Text = "Lap void: " .. tostring(player:GetAttribute("LapProblem") or "track limits")
		clock.TextColor3 = RED
	else
		clock.Text = lapTime(math.max(0, workspace:GetServerTimeNow() - start))
		clock.TextColor3 = INK
	end
	local last, best = player:GetAttribute("LastLap"), player:GetAttribute("BestLap") or 0
	times.Text = ("Last %s   Best %s"):format(last and lapTime(last) or "-", best > 0 and lapTime(best) or "-")
end

-- driving ---------------------------------------------------------------------------
RunService.Heartbeat:Connect(function(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local driving = seat ~= nil and seat:IsA("VehicleSeat") and seat:GetAttribute("RaceCar") == true
	panel.Visible = driving
	if not driving then
		return
	end
	refreshPanel()
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
	local speed, turn = DriveModel.step(along, (seat :: VehicleSeat).ThrottleFloat,
		(seat :: VehicleSeat).SteerFloat, dt, car:GetAttribute("TopSpeed") or Config.Drive.topSpeed, offroad, Config.Drive)
	-- grip: sideways motion dies away a little behind the steering, so the car slides a
	-- touch through fast bends instead of running on rails
	local sideways = flat - forward * along
	local v = forward * speed + sideways * (1 - math.min(1, Config.Drive.grip * dt))
	drive.PlaneVelocity = Vector2.new(v.X, v.Z)
	steer.AngularVelocity = Vector3.new(0, turn, 0)
end)
