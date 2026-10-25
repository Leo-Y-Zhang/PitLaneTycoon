-- Pit Lane Tycoon racing: the time-trial track round the paddock, each team's race car, and
-- lap timing. The player's computer drives its own car (Drive.client.luau) so it responds
-- at once; the server samples where the car is and times every lap itself (LapTimer), so a
-- lap time can't be made up. Money and saving stay in Tycoon.server.luau, through `host`.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local TrackShape = require(Shared:WaitForChild("TrackShape"))
local LapTimer = require(script.Parent:WaitForChild("LapTimer"))
local Scenery = require(script.Parent:WaitForChild("Scenery"))

local Racing = {}

export type Host = {
	season: (Player) -> number?, -- nil until the player has a garage
	colour: (Player) -> Color3,
	slot: (Player) -> number, -- the player's garage number, for a place on the grid
	garage: (Player) -> CFrame?, -- where a player goes back to after driving
	lap: (Player, number, string) -> (), -- a clean lap of this many seconds on a layout ("gp", "reverse", "long")
	tell: (Player, string) -> (), -- a message on the player's screen
	photo: boolean?, -- Studio's photo run, which drives every layout
}

type Car = { model: Model, chassis: BasePart, seat: VehicleSeat, timer: LapTimer.Timer, layout: string }
local cars: { [Player]: Car } = {}
local host: Host
local folder: Folder

-- cars pass through each other and through people on foot, so nobody can be rammed
PhysicsService:RegisterCollisionGroup("RaceCars")
PhysicsService:RegisterCollisionGroup("OnFoot")
PhysicsService:CollisionGroupSetCollidable("RaceCars", "RaceCars", false)
PhysicsService:CollisionGroupSetCollidable("RaceCars", "OnFoot", false)

function Racing.topSpeed(season: number): number
	return math.min(Config.Drive.maxTopSpeed, Config.Drive.topSpeed + Config.Drive.perSeason * season)
end

-- the circuit a layout runs on: the Grand Prix track (either way round) or the Endurance circuit
local function shapeOf(layout: string): any
	return if layout == "long" then Config.LongTrack else Config.Track
end

-- a place on the grid just behind the start line, nose along the track (the other side of
-- the line and the other way round for the Reverse GP); rows are as far apart on every circuit
local function gridSpot(slot: number, layout: string): CFrame
	local shape = shapeOf(layout)
	local way = layout == "reverse" and -1 or 1
	local a = way * (-0.035 - 0.014 * ((slot - 1) // 2)) * Config.Track.radius / shape.radius
	local x, z = TrackShape.point(shape, a)
	local dx, dz = TrackShape.tangent(shape, a)
	local side = (slot % 2 == 0 and 1 or -1) * 3.5
	local at = Vector3.new(x - dz * side, 0.2, z + dx * side)
	return CFrame.lookAt(at, at + Vector3.new(dx, 0, dz) * way)
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = a, b
	w.Parent = b
end

-- the show car's body on an invisible chassis that glides on four ball skids (they slide
-- over the joins between road pieces); a LinearVelocity and an AngularVelocity, set by the
-- driver's computer, do the driving and keep the car level
local function buildCar(player: Player, pose: CFrame, season: number, layout: string): Car
	local model = Scenery.car(folder, pose, host.colour(player), season)
	model.Name = "Car_" .. player.UserId
	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(3.2, 0.6, 10)
	chassis.CFrame = pose * CFrame.new(0, 0.9, 0)
	chassis.Transparency = 1
	chassis.CanCollide = false
	chassis.Parent = model
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p ~= chassis then
			p.Anchored = false
			p.Massless = true
			p.CanCollide = false
			p.CanTouch = false
			weld(chassis, p)
		end
	end
	for _, at in { Vector3.new(-1.6, 0.8, -3.3), Vector3.new(1.6, 0.8, -3.3), Vector3.new(-1.6, 0.8, 3.4), Vector3.new(1.6, 0.8, 3.4) } do
		local skid = Instance.new("Part")
		skid.Name = "Skid"
		skid.Shape = Enum.PartType.Ball
		skid.Size = Vector3.new(1.6, 1.6, 1.6)
		skid.CFrame = pose * CFrame.new(at)
		skid.Transparency = 1
		skid.CustomPhysicalProperties = PhysicalProperties.new(2, 0, 0, 100, 100)
		skid.Parent = model
		weld(chassis, skid)
	end
	local seat = Instance.new("VehicleSeat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(1.4, 0.3, 1.6)
	seat.CFrame = pose * CFrame.new(0, 1.3, 0.4)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.Massless = true
	seat.HeadsUpDisplay = false
	seat:SetAttribute("RaceCar", true)
	seat.Parent = model
	weld(chassis, seat)

	local root = Instance.new("Attachment")
	root.Name = "Root"
	root.Parent = chassis
	local drive = Instance.new("LinearVelocity")
	drive.Name = "Drive"
	drive.Attachment0 = root
	drive.RelativeTo = Enum.ActuatorRelativeTo.World
	drive.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	drive.PrimaryTangentAxis = Vector3.xAxis
	drive.SecondaryTangentAxis = Vector3.zAxis
	drive.PlaneVelocity = Vector2.zero
	drive.MaxForce = 4e5
	drive.Parent = chassis
	local steer = Instance.new("AngularVelocity")
	steer.Name = "Steer"
	steer.Attachment0 = root
	steer.RelativeTo = Enum.ActuatorRelativeTo.World
	steer.AngularVelocity = Vector3.zero
	steer.MaxTorque = 4e6
	steer.Parent = chassis

	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CollisionGroup = "RaceCars"
		end
	end
	model.PrimaryPart = chassis
	local top = Racing.topSpeed(season)
	model:SetAttribute("TopSpeed", top)
	local shape = shapeOf(layout)
	local timer = LapTimer.new({
		nearest = function(x: number, z: number)
			return TrackShape.nearest(shape, x, z)
		end,
		limit = shape.limit,
		maxSpeed = top,
		reverse = layout == "reverse",
	})
	return { model = model, chassis = chassis, seat = seat, timer = timer, layout = layout }
end

local function setLap(player: Player, start: number, valid: boolean)
	player:SetAttribute("LapStart", start)
	player:SetAttribute("LapValid", valid)
	player:SetAttribute("LapProblem", nil)
end

-- out of the car and back to the garage
function Racing.leave(player: Player)
	local car = cars[player]
	if not car then return end
	cars[player] = nil
	car.model:Destroy()
	player:SetAttribute("Driving", false)
	setLap(player, 0, true)
	local character = player.Character
	local home = host.garage(player)
	if character and home then
		task.defer(function()
			character:PivotTo(home)
		end)
	end
end

-- layout: "gp" (the default), "reverse" (opens in Config.Track.reverseFromSeason) or "long",
-- the Endurance circuit (opens in Config.LongTrack.fromSeason)
function Racing.drive(player: Player, layout: string?)
	if cars[player] then return end
	local season = host.season(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if season == nil or not humanoid or humanoid.Health <= 0 or humanoid.SeatPart then return end
	local chosen = if layout == "reverse" or layout == "long" then layout else "gp"
	if chosen == "reverse" and season < Config.Track.reverseFromSeason then
		host.tell(player, ("The Reverse GP opens in season %d"):format(Config.Track.reverseFromSeason + 1))
		return
	end
	if chosen == "long" and season < Config.LongTrack.fromSeason and not host.photo then
		host.tell(player, ("The Endurance circuit opens in season %d"):format(Config.LongTrack.fromSeason + 1))
		return
	end
	local pose = gridSpot(host.slot(player), chosen)
	local car = buildCar(player, pose, season, chosen)
	cars[player] = car
	player:SetAttribute("Driving", true)
	player:SetAttribute("Layout", chosen)
	setLap(player, 0, true)
	character:PivotTo(pose * CFrame.new(0, 4, 0))
	car.seat:Sit(humanoid)
	car.chassis:SetNetworkOwner(player)
	car.seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if car.seat.Occupant == nil then
			Racing.leave(player)
		end
	end)
	task.delay(2, function()
		if cars[player] == car and car.seat.Occupant ~= humanoid then
			Racing.leave(player) -- the seat never took them
		end
	end)
end

-- the drive prompt on a team's show car (only its owner can use it)
function Racing.prompt(showCar: Model, owner: Player)
	local body = showCar:FindFirstChildWhichIsA("BasePart")
	if not body then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Drive"
	prompt.ObjectText = "Time trial"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	prompt.Triggered:Connect(function(who)
		if who == owner then
			Racing.drive(who)
		end
	end)
end

-- sample every car ten times a second and time its laps
local function tick()
	local now = workspace:GetServerTimeNow()
	for player, car in cars do
		local pos = car.chassis.Position
		if pos.Y < -40 then -- off the edge of the world
			Racing.leave(player)
			continue
		end
		local event = LapTimer.sample(car.timer, now, pos.X, pos.Z)
		if event and event.kind == "lap" then
			player:SetAttribute("LastLap", event.time)
			if event.valid then
				host.lap(player, event.time :: number, car.layout)
			end
		end
		if event then
			setLap(player, car.timer.lapStart :: number, true)
		elseif player:GetAttribute("LapValid") ~= car.timer.valid then
			player:SetAttribute("LapValid", car.timer.valid)
			player:SetAttribute("LapProblem", car.timer.reason)
		end
	end
end

local function onFoot(character: Model)
	for _, p in character:GetDescendants() do
		if p:IsA("BasePart") then
			p.CollisionGroup = "OnFoot"
		end
	end
	character.DescendantAdded:Connect(function(p)
		if p:IsA("BasePart") then
			p.CollisionGroup = "OnFoot"
		end
	end)
end

function Racing.start(h: Host, remotes: Folder)
	host = h
	local _, outer = TrackShape.extent(Config.LongTrack)
	Scenery.track(Config.Track, "Track", "TIME TRIAL", outer) -- the grass reaches past both circuits
	Scenery.track(Config.LongTrack, "LongTrack", "ENDURANCE")
	folder = Instance.new("Folder")
	folder.Name = "RaceCars"
	folder.Parent = workspace
	local drive = Instance.new("RemoteEvent")
	drive.Name = "Drive" -- true = take me to my car, false = let me out
	drive.Parent = remotes
	drive.OnServerEvent:Connect(function(player, want, layout)
		if want == true then
			Racing.drive(player, if type(layout) == "string" then layout else nil)
		elseif want == false then
			Racing.leave(player)
		end
	end)
	local function joined(player: Player)
		player.CharacterAdded:Connect(function(character)
			Racing.leave(player) -- a new character (reset, death) leaves the car behind
			onFoot(character)
		end)
		if player.Character then
			onFoot(player.Character)
		end
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		joined(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local car = cars[player]
		cars[player] = nil
		if car then
			car.model:Destroy()
		end
	end)
	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since >= 0.1 then
			since = 0
			tick()
		end
	end)
end

return Racing
