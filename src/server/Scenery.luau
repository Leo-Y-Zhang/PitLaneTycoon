--!strict
-- Pit Lane Tycoon scenery: lighting, the paddock, garage walls, each team's show car and the
-- time-trial track.
-- Pure decoration, built from code like everything else; nothing here touches money.

local Lighting = game:GetService("Lighting")
local TrackShape = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("TrackShape"))

local Scenery = {}

Scenery.Teams = {
	{ name = "Scarlet", colour = Color3.fromRGB(214, 32, 32) },
	{ name = "Cobalt", colour = Color3.fromRGB(28, 86, 214) },
	{ name = "Papaya", colour = Color3.fromRGB(255, 128, 0) },
	{ name = "Racing Green", colour = Color3.fromRGB(0, 120, 72) },
	{ name = "Violet", colour = Color3.fromRGB(120, 60, 200) },
	{ name = "Teal", colour = Color3.fromRGB(0, 160, 170) },
}

local CARBON = Color3.fromRGB(22, 24, 28)
local WALL = Color3.fromRGB(214, 218, 224)
local WHITE = Color3.fromRGB(240, 240, 240)
local STEEL = Color3.fromRGB(150, 155, 162)
local DARK_STEEL = Color3.fromRGB(40, 44, 50)

local function block(parent: Instance, cf: CFrame, size: Vector3, colour: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

local function sign(part: BasePart, face: Enum.NormalId, text: string, colour: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = part
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = colour
	t.Text = text
	t.Parent = gui
end

Scenery.block = block
Scenery.sign = sign

function Scenery.lighting()
	Lighting.Ambient = Color3.fromRGB(70, 74, 82)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 132, 140)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Haze = 1.2
	atmosphere.Color = Color3.fromRGB(199, 214, 230)
	atmosphere.Decay = Color3.fromRGB(106, 124, 145)
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 24
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Saturation = 0.12
	grade.Contrast = 0.06
	grade.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.04
	rays.Parent = Lighting
end

-- the spawn: a red-and-white kerb ring, pit-lane lines to every garage, a title gantry
function Scenery.paddock(plotCount: number, plotRadius: number, frontGap: number)
	local folder = Instance.new("Folder")
	folder.Name = "Paddock"
	folder.Parent = workspace
	local segments = 28
	for i = 0, segments - 1 do
		local a = i / segments * math.pi * 2
		local cf = CFrame.new(math.cos(a) * 15, 0.15, math.sin(a) * 15) * CFrame.Angles(0, -a, 0)
		block(folder, cf, Vector3.new(1.4, 0.3, 3.5), i % 2 == 0 and Color3.fromRGB(214, 32, 32) or WHITE)
	end
	for i = 1, plotCount do
		local a = (i - 1) / plotCount * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local from, to = 17, plotRadius - frontGap
		local mid = dir * ((from + to) / 2)
		local look = CFrame.lookAt(mid, mid + dir)
		for _, side in { -7, 7 } do
			block(folder, look * CFrame.new(side, 0.02, 0), Vector3.new(0.5, 0.06, to - from), WHITE, Enum.Material.SmoothPlastic)
		end
		for d = 0, to - from - 4, 8 do -- dashed centre line
			block(folder, look * CFrame.new(0, 0.02, -(to - from) / 2 + d + 2), Vector3.new(0.4, 0.06, 4), Color3.fromRGB(250, 205, 40))
		end
	end
	-- title gantry above the leaderboard
	for _, x in { -14, 14 } do
		block(folder, CFrame.new(x, 8.5, -14), Vector3.new(1.2, 17, 1.2), CARBON, Enum.Material.Metal)
	end
	local title = block(folder, CFrame.new(0, 16, -14), Vector3.new(30, 4, 1.2), CARBON, Enum.Material.Metal)
	sign(title, Enum.NormalId.Back, "PIT LANE TYCOON", Color3.fromRGB(255, 205, 60))
	sign(title, Enum.NormalId.Front, "PIT LANE TYCOON", Color3.fromRGB(255, 205, 60))
	-- Props live in the wedges, with clearance measured to their whole footprint.
	local PaddockLayout = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("PaddockLayout"))
	local props = Instance.new("Folder")
	props.Name = "Props"
	props.Parent = folder
	for _, placement in PaddockLayout.generate(plotCount, plotRadius, frontGap) do
		local m = Instance.new("Model")
		m.Name = placement.kind
		local cf = CFrame.new(placement.x, 0, placement.z) * CFrame.Angles(0, placement.yaw, 0)
		local angle = math.atan2(placement.z, placement.x) % (math.pi * 2)
		local team = Scenery.Teams[math.floor(angle / (math.pi * 2) * plotCount) % #Scenery.Teams + 1]
		local partCount = 0
		local function p(x: number, y: number, z: number, sx: number, sy: number, sz: number, c: Color3, mat: Enum.Material?): Part
			local part = block(m, cf * CFrame.new(x, y, z), Vector3.new(sx, sy, sz), c, mat)
			part.CastShadow = math.max(sx, sy, sz) >= 2
			partCount += 1
			return part
		end
		local function cylinder(x: number, y: number, z: number, height: number, diameter: number, c: Color3, mat: Enum.Material?): Part
			local part = p(x, y, z, height, diameter, diameter, c, mat)
			part.Shape = Enum.PartType.Cylinder
			part.CFrame *= CFrame.Angles(0, 0, math.pi / 2)
			return part
		end
		if placement.kind == "tent" then
			for _, side in { -1, 1 } do
				local roof = p(side * 3.05, 8.05, 0, 6.4, 0.22, 9.4,
					if side == -1 then team.colour else WHITE, Enum.Material.Fabric)
				roof.CFrame *= CFrame.Angles(0, 0, -side * 0.22)
				for _, z in { -4.2, 4.2 } do
					p(side * 5.6, 3.65, z, 0.18, 7.3, 0.18, STEEL, Enum.Material.Metal)
					p(side * 5.6, 0.1, z, 0.7, 0.2, 0.7, DARK_STEEL, Enum.Material.Metal)
				end
			end
			for _, z in { -4.6, 4.6 } do
				local valance = p(0, 7.25, z, 12.4, 0.65, 0.15, team.colour, Enum.Material.Fabric)
				sign(valance, if z < 0 then Enum.NormalId.Front else Enum.NormalId.Back, "PADDOCK CLUB", WHITE)
			end
			p(0, 8.72, 0, 0.16, 0.16, 9.4, STEEL, Enum.Material.Metal)
			for _, x in { -3.5, 0, 3.5 } do
				cylinder(x, 2.45, 0.5, 0.18, 2.5, WHITE, Enum.Material.SmoothPlastic)
				cylinder(x, 1.2, 0.5, 2.4, 0.16, STEEL, Enum.Material.Metal)
				cylinder(x, 0.12, 0.5, 0.2, 1.2, DARK_STEEL, Enum.Material.Metal)
			end
		elseif placement.kind == "flag" then
			p(0, 0.15, 0, 1.8, 0.3, 1.8, DARK_STEEL, Enum.Material.Metal)
			cylinder(0, 0.6, 0, 0.9, 0.4, STEEL, Enum.Material.Metal)
			cylinder(0, 5.8, 0, 11, 0.14, STEEL, Enum.Material.Metal)
			p(1.25, 10.8, 0, 2.6, 0.1, 0.1, STEEL, Enum.Material.Metal)
			local flag = p(1.25, 9.6, 0, 2.5, 2.3, 0.06, team.colour, Enum.Material.Fabric)
			sign(flag, Enum.NormalId.Front, string.upper(team.name), WHITE)
			cylinder(0, 11.4, 0, 0.16, 0.3, WHITE, Enum.Material.Metal)
		elseif placement.kind == "tyres" then
			p(0, 0.55, 0, 2.6, 0.2, 3.3, team.colour, Enum.Material.Metal)
			for _, x in { -1.25, 1.25 } do
				for _, z in { -1.25, 1.25 } do
					local wheel = p(x, 0.28, z, 0.25, 0.55, 0.55, CARBON, Enum.Material.Rubber)
					wheel.Shape = Enum.PartType.Cylinder
				end
				p(x, 1.4, 1.45, 0.12, 1.8, 0.12, STEEL, Enum.Material.Metal)
			end
			p(0, 2.3, 1.45, 2.6, 0.14, 0.14, CARBON, Enum.Material.Metal)
			for level = 0, 2 do
				local y = 1.03 + level * 0.78
				cylinder(0, y, -0.2, 0.74, 2.25, CARBON, Enum.Material.Rubber)
				cylinder(0, y + 0.38, -0.2, 0.035, 1.35, DARK_STEEL, Enum.Material.Metal)
				p(0, y, -1.325, 0.45, 0.12, 0.025, Color3.fromRGB(245, 204, 55))
			end
		elseif placement.kind == "fuel" then
			p(0, 0.16, 0, 3.6, 0.32, 3.4, DARK_STEEL, Enum.Material.Metal)
			cylinder(-0.65, 2.1, 0.25, 3.5, 1.7, STEEL, Enum.Material.Metal)
			for _, y in { 0.9, 3.25 } do
				cylinder(-0.65, y, 0.25, 0.16, 1.78, team.colour, Enum.Material.Metal)
			end
			cylinder(-0.65, 3.95, 0.25, 0.24, 0.6, DARK_STEEL, Enum.Material.Metal)
			p(1.25, 2.9, 0.9, 0.14, 5.4, 0.14, STEEL, Enum.Material.Metal)
			p(0.15, 5.55, 0.9, 2.3, 0.16, 0.16, STEEL, Enum.Material.Metal)
			p(-0.95, 4.95, 0.9, 0.15, 1.2, 0.15, CARBON, Enum.Material.Rubber)
			p(-0.95, 4.4, 0.25, 0.15, 0.15, 1.4, CARBON, Enum.Material.Rubber)
			p(-0.95, 3.65, -0.4, 0.15, 1.5, 0.15, CARBON, Enum.Material.Rubber)
			p(-0.65, 2.95, -0.4, 0.7, 0.2, 0.2, team.colour, Enum.Material.Metal)
			local controls = p(0.7, 2.35, -0.3, 1.05, 1.4, 0.65, team.colour, Enum.Material.Metal)
			sign(controls, Enum.NormalId.Front, "FUEL", WHITE)
			p(0.7, 2.65, -0.64, 0.65, 0.32, 0.035, Color3.fromRGB(124, 224, 184), Enum.Material.Neon)
			p(0.7, 2.12, -0.65, 0.16, 0.16, 0.06, Color3.fromRGB(220, 54, 47))
			p(0.7, 1.15, -0.3, 0.25, 1.8, 0.25, STEEL, Enum.Material.Metal)
		elseif placement.kind == "barrier" then
			for _, x in { -2.6, 2.6 } do
				p(x, 0.12, 0, 1.1, 0.24, 1.5, DARK_STEEL, Enum.Material.Metal)
				p(x, 1.4, 0, 0.14, 2.6, 0.14, STEEL, Enum.Material.Metal)
			end
			for _, y in { 0.65, 2.65 } do
				p(0, y, 0, 5.4, 0.14, 0.14, STEEL, Enum.Material.Metal)
			end
			for x = -2, 2 do
				p(x, 1.65, 0, 0.09, 1.9, 0.09, STEEL, Enum.Material.Metal)
			end
		elseif placement.kind == "planter" then
			p(0, 0.65, 0, 3, 1.3, 2, DARK_STEEL, Enum.Material.Metal)
			p(0, 1.3, 0, 3.2, 0.16, 2.2, team.colour, Enum.Material.Metal)
			for k = -1, 1 do
				local leaf = p(k * 0.75, 1.85, 0, 1.35, 1.6, 1.35,
					Color3.fromRGB(48 + (k + 1) * 8, 116 + (k + 1) * 12, 64), Enum.Material.Grass)
				leaf.Shape = Enum.PartType.Ball
			end
		elseif placement.kind == "tower" then
			p(0, 0.2, 0, 3, 0.4, 3, DARK_STEEL, Enum.Material.Metal)
			p(0, 7.5, 0, 0.45, 15, 0.45, STEEL, Enum.Material.Metal)
			p(0, 14.6, 0, 6, 0.24, 0.24, DARK_STEEL, Enum.Material.Metal)
			for _, side in { -1, 1 } do
				local brace = p(side * 0.75, 1.1, 0, 0.12, 2.3, 0.12, STEEL, Enum.Material.Metal)
				brace.CFrame *= CFrame.Angles(0, 0, -side * 0.65)
			end
			for _, x in { -2.2, 0, 2.2 } do
				p(x, 14.4, -0.15, 1.5, 0.65, 0.9, CARBON, Enum.Material.Metal)
				local lamp = p(x, 14.06, -0.15, 1.25, 0.06, 0.7, Color3.fromRGB(255, 237, 201), Enum.Material.Neon)
				if x == 0 then
					local light = Instance.new("SurfaceLight")
					light.Face = Enum.NormalId.Bottom
					light.Color = lamp.Color
					light.Brightness, light.Range, light.Angle = 1.5, 32, 110
					light.Parent = lamp
				end
			end
		end
		assert(partCount <= PaddockLayout.Specs[placement.kind].parts, "Paddock prop exceeded its part allowance")
		m.Parent = props
	end
end

-- the conveyor fittings every plot has from the start (plot-local frame: -Z faces the spawn)
function Scenery.garage(model: Instance, cf: CFrame)
	local g = Instance.new("Folder")
	g.Name = "Fittings"
	g.Parent = model
	for _, x in { -23.5, 23.5 } do
		for k = 0, 2 do
			block(g, cf * CFrame.new(x, 1.55, -2 + k * 2), Vector3.new(1, 0.08, 1),
				k % 2 == 0 and Color3.fromRGB(250, 205, 40) or CARBON)
		end
	end
	for _, z in { -3.2, 3.2 } do -- conveyor side rails
		block(g, cf * CFrame.new(0, 1.9, z), Vector3.new(48, 0.4, 0.4), Color3.fromRGB(150, 155, 162), Enum.Material.Metal)
	end
	-- skirts and roller ends sit below the belt surface
	for _, side in { -1, 1 } do
		block(g, cf * CFrame.new(0, 0.75, side * 3.06), Vector3.new(48, 1.4, 0.12), DARK_STEEL, Enum.Material.Metal)
		for x = -22.5, 22.5, 3 do
			local roller = block(g, cf * CFrame.new(x, 1.05, side * 3.13) * CFrame.Angles(0, math.rad(90), 0),
				Vector3.new(0.14, 0.7, 0.7), Color3.fromRGB(190, 195, 205), Enum.Material.Metal)
			roller.Shape = Enum.PartType.Cylinder
			roller.CastShadow = false
		end
		for x = -21, 21, 6 do
			local post = block(g, cf * CFrame.new(x, 1.7, side * 3.2), Vector3.new(0.14, 0.4, 0.14), STEEL, Enum.Material.Metal)
			post.CastShadow = false
		end
	end
	for _, x in { -24.1, 24.1 } do
		local roller = block(g, cf * CFrame.new(x, 1, 0) * CFrame.Angles(0, math.rad(90), 0),
			Vector3.new(6.1, 1, 1), DARK_STEEL, Enum.Material.Metal)
		roller.Shape = Enum.PartType.Cylinder
	end
end

-- a lit upgrade arch; the touch curtain is made by the tycoon
function Scenery.gateArch(parent: Instance, cf: CFrame, colour: Color3, key: string)
	for _, z in { -3.9, 3.9 } do
		local post = block(parent, cf * CFrame.new(0, 4.3, z), Vector3.new(0.6, 6.6, 0.6), DARK_STEEL, Enum.Material.Metal)
		post.Name = key .. "_post"
		block(parent, cf * CFrame.new(0, 0.15, z), Vector3.new(0.9, 0.3, 0.9), DARK_STEEL, Enum.Material.Metal)
		for _, band in {
			{ y = 1.2, colour = Color3.fromRGB(250, 205, 40) },
			{ y = 1.55, colour = CARBON },
		} do
			block(parent, cf * CFrame.new(0, band.y, z), Vector3.new(0.68, 0.3, 0.68), band.colour, Enum.Material.Metal)
		end
		local scanner = block(parent, cf * CFrame.new(0, 5.6, math.sign(z) * 3.475),
			Vector3.new(0.25, 0.4, 0.25), colour, Enum.Material.Neon)
		scanner.CastShadow = false
	end
	local beam = block(parent, cf * CFrame.new(0, 7.9, 0), Vector3.new(0.9, 0.6, 8.4), colour)
	beam.Name = key .. "_beam"
	local strip = block(parent, cf * CFrame.new(0, 7.55, 0), Vector3.new(0.3, 0.12, 7.4), colour, Enum.Material.Neon)
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Brightness, light.Range, light.Angle = 1.2, 10, 70
	light.Color = colour
	light.Parent = strip
end

-- walls and a sign frame around the scanner, clear of the intake and collection pad
function Scenery.collectorBin(model: Instance, cf: CFrame, colour: Color3)
	local g = Instance.new("Folder")
	g.Name = "CollectorBin"
	g.Parent = model
	block(g, cf * CFrame.new(2.15, 1.8, 0), Vector3.new(0.3, 3.6, 8.6), DARK_STEEL, Enum.Material.Metal)
	block(g, cf * CFrame.new(2.15, 3.7, 0), Vector3.new(0.3, 0.2, 8.6), colour, Enum.Material.Metal)
	for _, z in { -4.15, 4.15 } do
		block(g, cf * CFrame.new(0.15, 1.8, z), Vector3.new(4.3, 3.6, 0.3), DARK_STEEL, Enum.Material.Metal)
		block(g, cf * CFrame.new(0.15, 3.7, z), Vector3.new(4.3, 0.2, 0.3), colour, Enum.Material.Metal)
	end
	for _, z in { -4.6, 4.6 } do
		for _, x in { -1.4, 1.8 } do
			block(g, cf * CFrame.new(x, 3.25, z), Vector3.new(0.4, 6.5, 0.4), DARK_STEEL, Enum.Material.Metal)
		end
		block(g, cf * CFrame.new(0.2, 6.6, z), Vector3.new(3.8, 0.4, 0.4), DARK_STEEL, Enum.Material.Metal)
	end
	local board = block(g, cf * CFrame.new(0, 7.4, -4.6), Vector3.new(3.8, 1.2, 0.3), CARBON, Enum.Material.Metal)
	sign(board, Enum.NormalId.Front, "SCRUTINEERING", WHITE)
	sign(board, Enum.NormalId.Back, "SCRUTINEERING", WHITE)
	for _, x in { -1.4, 1.8 } do
		local lamp = block(g, cf * CFrame.new(x, 5.8, -4.85), Vector3.new(0.25, 0.4, 0.1),
			Color3.fromRGB(0, 255, 110), Enum.Material.Neon)
		lamp.CastShadow = false
	end
end

local ORANGE = Color3.fromRGB(255, 120, 20)
local CONCRETE = Color3.fromRGB(196, 200, 206)
local GRAPHITE = Color3.fromRGB(44, 48, 56)

-- one piece of a team's garage, which goes up as the team buys machines (Config.GaragePieces)
function Scenery.garagePiece(name: string, parent: Instance, cf: CFrame, team: { name: string, colour: Color3 },
	theme: string?): Model
	local m = Instance.new("Model")
	m.Name = name
	-- the night look (from a later season): graphite walls, team colours that glow
	local night = theme == "night"
	local wall = night and GRAPHITE or WALL
	local concrete = night and GRAPHITE or CONCRETE
	local wallMat = night and Enum.Material.Metal or Enum.Material.Concrete
	local glow = night and Enum.Material.Neon or nil
	local function p(x: number, y: number, z: number, sx: number, sy: number, sz: number, c: Color3, mat: Enum.Material?): Part
		return block(m, cf * CFrame.new(x, y, z), Vector3.new(sx, sy, sz), c, mat)
	end
	if name == "Floor" then
		p(0, 0.05, 0, 64, 0.1, 52, night and Color3.fromRGB(30, 32, 38) or Color3.fromRGB(60, 63, 68)) -- matt: a shine mirrored the sky like water
		for _, z in { -6.5, 6.5 } do
			p(0, 0.11, z, 60, 0.02, 0.5, team.colour, glow) -- painted lane lines
		end
		p(0, 0.06, -25.8, 64, 0.12, 0.4, team.colour, glow)
	elseif name == "BackWall" then
		p(0, 6, 25.5, 64, 12, 1, wall, wallMat).CanCollide = true
		-- panel seams stop short of the nameplate
		for _, x in { -28, -20, 20, 28 } do
			p(x, 5, 24.97, 0.15, 9.6, 0.06, wall:Lerp(Color3.new(0, 0, 0), 0.12), wallMat).CastShadow = false
		end
		-- a metal kick plate protects the bottom of the wall
		p(0, 0.6, 24.96, 64, 1.2, 0.08, STEEL, Enum.Material.Metal).CastShadow = false
		-- high louvres let the garage breathe
		for _, x in { -24, 24 } do
			p(x, 8.2, 24.88, 3, 1.6, 0.24, CARBON, Enum.Material.Metal).CastShadow = false
			for k = 0, 3 do
				p(x, 7.66 + k * 0.36, 24.73, 2.7, 0.12, 0.06, STEEL, Enum.Material.Metal).CastShadow = false
			end
		end
	elseif name == "SideWalls" then
		for _, x in { -31.5, 31.5 } do
			p(x, 6, 10, 1, 12, 32, wall, wallMat).CanCollide = true
		end
		-- side panel seams leave the collect pad's standing space clear
		for _, side in { -1, 1 } do
			for _, z in { -2, 6, 14, 22 } do
				local bottom = if side == 1 and z == 14 then 4.05 else 0.2
				p(side * 30.97, (bottom + 9.8) / 2, z, 0.06, 9.8 - bottom, 0.15,
					wall:Lerp(Color3.new(0, 0, 0), 0.12), wallMat).CastShadow = false
			end
		end
		-- kick plates have a gap beside the collect pad
		p(-30.96, 0.6, 10, 0.08, 1.2, 32, STEEL, Enum.Material.Metal).CastShadow = false
		for _, plate in { { z = 0.95, length = 13.9 }, { z = 21.05, length = 9.9 } } do
			p(30.96, 0.6, plate.z, 0.08, 1.2, plate.length, STEEL, Enum.Material.Metal).CastShadow = false
		end
		-- a red extinguisher hangs beside the open front
		local extinguisher = p(-30.5, 2.1, -2.5, 1.8, 0.7, 0.7, Color3.fromRGB(200, 32, 32), Enum.Material.Metal)
		extinguisher.Shape = Enum.PartType.Cylinder
		extinguisher.CFrame = cf * CFrame.new(-30.5, 2.1, -2.5) * CFrame.Angles(0, 0, math.rad(90))
		extinguisher.CastShadow = false
		p(-30.45, 3.13, -2.5, 0.45, 0.26, 0.35, CARBON).CastShadow = false
		p(-30.9, 2.1, -2.5, 0.2, 0.25, 0.9, STEEL, Enum.Material.Metal).CastShadow = false
	elseif name == "Livery" then
		for _, x in { -31.5, 31.5 } do
			p(x, 10.5, 10, 1.15, 1.2, 32.1, team.colour, glow)
		end
		p(0, 10.5, 24.9, 62, 1.2, 0.3, team.colour, glow)
		local nameplate = p(0, 7, 24.9, 30, 4.5, 0.2, WALL)
		nameplate.Transparency = 1
		sign(nameplate, Enum.NormalId.Front, string.upper(team.name), team.colour)
	elseif name == "Awning" then
		p(0, 12.5, 22, 65, 1, 8.5, CARBON, Enum.Material.Metal) -- leaves the car in the sun
		for _, x in { -20, 0, 20 } do
			p(x, 11.6, 18.2, 0.4, 0.8, 0.4, STEEL, Enum.Material.Metal)
		end
		-- Warren trusses leave gaps for the flag and rear team band
		local function diagonal(a: Vector3, b: Vector3)
			local mid = (a + b) / 2
			local member = p(mid.X, mid.Y, mid.Z, 0.15, 0.15, (b - a).Magnitude, STEEL, Enum.Material.Metal)
			member.CFrame = cf * CFrame.lookAt(mid, b)
			member.CastShadow = false
		end
		for _, x in { -10, 10, -28, 28 } do
			if x == -28 then
				p(x, 10.9, 21, 0.25, 0.25, 5.6, STEEL, Enum.Material.Metal).CastShadow = false
				p(x, 10.9, 24.45, 0.25, 0.25, 0.5, STEEL, Enum.Material.Metal).CastShadow = false
			else
				p(x, 10.9, 21.45, 0.25, 0.25, 6.5, STEEL, Enum.Material.Metal).CastShadow = false
			end
			for k = 0, 4 do
				local z1, z2 = 18.2 + k * 1.4, math.min(18.2 + (k + 1) * 1.4, 25)
				local y1 = if k % 2 == 0 then 11.025 else 11.925
				local y2 = if k % 2 == 0 then 11.925 else 11.025
				if x == -28 and k == 4 then
					y1 += (y2 - y1) * (24.2 - z1) / (z2 - z1)
					z1 = 24.2
				end
				diagonal(Vector3.new(x, y1, z1), Vector3.new(x, y2, z2))
			end
			p(x, 11.45, 18.2, 0.25, 1.1, 0.25, STEEL, Enum.Material.Metal).CastShadow = false
			p(x, 11.6, 25, 0.25, 0.8, 0.25, STEEL, Enum.Material.Metal).CastShadow = false
		end
	elseif name == "Lights" then
		for _, x in { -20, 0, 20 } do -- strip lights under the awning
			local strip = p(x, 11.9, 21, 8, 0.25, 0.8, Color3.fromRGB(240, 246, 255), Enum.Material.Neon)
			local light = Instance.new("SpotLight")
			light.Face = Enum.NormalId.Bottom
			light.Range, light.Angle, light.Brightness = 26, 110, 1.6
			light.Parent = strip
		end
		for _, x in { -30, 30 } do -- floodlight masts at the front corners
			p(x, 8, -24, 0.6, 16, 0.6, CARBON, Enum.Material.Metal)
			local head = p(x - math.sign(x) * 0.8, 16, -23.4, 2.4, 1.2, 0.8, Color3.fromRGB(240, 246, 255), Enum.Material.Neon)
			local light = Instance.new("SpotLight")
			light.Face = Enum.NormalId.Back
			light.Range, light.Angle, light.Brightness = 40, 70, 1.2
			light.Parent = head
		end
	elseif name == "PitWall" then
		for _, x in { -22, 22 } do -- either side of the way in
			local wall = p(x, 0.8, -24.6, 20, 1.6, 0.8, concrete, wallMat)
			wall.CanCollide = true
			p(x, 1.7, -24.6, 20.1, 0.2, 0.9, team.colour, glow)
			for _, dx in { -2.6, 2.6 } do
				p(x + dx, 2.6, -24.6, 0.2, 2, 0.2, CARBON, Enum.Material.Metal)
			end
			local screen = p(x, 4.3, -24.6, 7, 2.4, 0.3, CARBON)
			sign(screen, Enum.NormalId.Front, "PIT WALL", Color3.fromRGB(60, 230, 120))
			sign(screen, Enum.NormalId.Back, "PIT WALL", Color3.fromRGB(60, 230, 120))
		end
	elseif name == "Kit" then
		for _, at in { Vector3.new(27, 0, 21), Vector3.new(24, 0, 21), Vector3.new(-23, 0, 22) } do
			for k = 0, 3 do -- a stack of tyres
				local tyre = p(at.X, 0.5 + k * 0.95, at.Z, 0.9, 2.2, 2.2, CARBON)
				tyre.Shape = Enum.PartType.Cylinder
				tyre.CFrame = cf * CFrame.new(at.X, 0.5 + k * 0.95, at.Z) * CFrame.Angles(0, 0, math.rad(90))
			end
		end
		p(-27.5, 1.3, 4, 2.4, 2.6, 4, team.colour, Enum.Material.Metal) -- tool chest, clear of the blue pad
		for k = 0, 3 do
			p(-26.25, 0.6 + k * 0.55, 4, 0.05, 0.08, 3.6, STEEL, Enum.Material.Metal) -- its drawers
		end
		p(-29.5, 6, 24, 0.3, 12, 0.3, STEEL, Enum.Material.Metal) -- flagpole
		p(-27.8, 10.6, 24, 3.2, 2, 0.1, team.colour, Enum.Material.Fabric)
		-- a pegboard keeps the hand tools above the back of the garage
		p(22, 4.6, 24.88, 8, 4, 0.12, concrete:Lerp(Color3.fromRGB(156, 145, 129), 0.55), wallMat).CastShadow = false
		for _, x in { 18.6, 20.6, 22.6, 24.6 } do
			for _, y in { 3, 6.2 } do
				p(x, y, 24.81, 0.08, 0.08, 0.02, CARBON).CastShadow = false
			end
		end
		for _, tool in {
			{ x = 18.9, y = 4.4, length = 1.5, jaw = 0.4 },
			{ x = 20.2, y = 4.2, length = 1.1, jaw = 0.35 },
		} do
			p(tool.x, tool.y, 24.78, 0.14, tool.length, 0.08, STEEL, Enum.Material.Metal).CastShadow = false
			for _, dx in { -0.16, 0.16 } do
				p(tool.x + dx, tool.y + tool.length / 2 + tool.jaw / 2 - 0.05, 24.78,
					0.14, tool.jaw, 0.08, STEEL, Enum.Material.Metal).CastShadow = false
			end
		end
		p(21.6, 4.3, 24.78, 0.18, 1.4, 0.08, team.colour, glow).CastShadow = false
		p(21.6, 5.05, 24.78, 0.85, 0.3, 0.08, STEEL, Enum.Material.Metal).CastShadow = false
		p(23, 3.9, 24.78, 0.26, 0.65, 0.08, team.colour, glow).CastShadow = false
		p(23, 4.65, 24.78, 0.08, 0.85, 0.08, STEEL, Enum.Material.Metal).CastShadow = false
		p(24.8, 4.65, 24.78, 0.14, 1.6, 0.08, STEEL, Enum.Material.Metal).CastShadow = false
		p(24.8, 3.6, 24.78, 0.24, 0.5, 0.08, team.colour, glow).CastShadow = false
		local wrenchHead = p(24.8, 5.5, 24.78, 0.08, 0.45, 0.45, STEEL, Enum.Material.Metal)
		wrenchHead.Shape = Enum.PartType.Cylinder
		wrenchHead.CFrame = cf * CFrame.new(24.8, 5.5, 24.78) * CFrame.Angles(0, math.rad(90), 0)
		wrenchHead.CastShadow = false
		-- compound colours sit on the top sidewalls of the tyre stacks
		for _, tyre in {
			{ x = 27, z = 21, colour = Color3.fromRGB(220, 40, 40) },
			{ x = 24, z = 21, colour = Color3.fromRGB(245, 210, 40) },
			{ x = -23, z = 22, colour = WHITE },
		} do
			local ring = p(tyre.x, 3.83, tyre.z, 0.06, 2.24, 2.24, tyre.colour)
			ring.Shape = Enum.PartType.Cylinder
			ring.CFrame = cf * CFrame.new(tyre.x, 3.83, tyre.z) * CFrame.Angles(0, 0, math.rad(90))
			ring.CastShadow = false
			local hub = p(tyre.x, 3.88, tyre.z, 0.04, 1.85, 1.85, CARBON, Enum.Material.Metal)
			hub.Shape = Enum.PartType.Cylinder
			hub.CFrame = cf * CFrame.new(tyre.x, 3.88, tyre.z) * CFrame.Angles(0, 0, math.rad(90))
			hub.CastShadow = false
		end
		-- a two-rail wall rack holds four upright spare tyres
		for _, rail in { { x = -29.7, y = 1 }, { x = -30.4, y = 2.4 } } do
			p(rail.x, rail.y, 14, 0.2, 0.2, 8, STEEL, Enum.Material.Metal).CastShadow = false
			for _, z in { 10.1, 17.9 } do
				p(-30.2, rail.y, z, 1.4, 0.16, 0.2, STEEL, Enum.Material.Metal).CastShadow = false
			end
		end
		for _, z in { 11, 13.2, 15.4, 17.6 } do
			local tyre = p(-29.7, 2.2, z, 0.9, 2.2, 2.2, CARBON)
			tyre.Shape = Enum.PartType.Cylinder
			tyre.CastShadow = false
			local hub = p(-29.21, 2.2, z, 0.08, 1.1, 1.1, team.colour, glow)
			hub.Shape = Enum.PartType.Cylinder
			hub.CastShadow = false
		end
	elseif name == "UpperDeck" then
		-- a second storey over the back of the garage: glass front, team band, roof sign
		p(0, 16.5, 25.5, 64, 7, 1, wall, wallMat)
		for _, x in { -31.5, 31.5 } do
			p(x, 16.5, 21.5, 1, 7, 9, wall, wallMat)
		end
		local glass = p(0, 16.2, 17.3, 62, 6.4, 0.3, night and Color3.fromRGB(70, 110, 170) or Color3.fromRGB(150, 200, 235),
			Enum.Material.Glass)
		glass.Transparency = 0.45
		for _, x in { -15.5, 0, 15.5 } do
			p(x, 16.2, 17.2, 0.4, 6.4, 0.4, CARBON, Enum.Material.Metal) -- mullions
		end
		p(0, 20.3, 21.5, 65, 0.8, 9.6, CARBON, Enum.Material.Metal)
		p(0, 19.6, 17, 65, 0.6, 0.3, team.colour, glow)
		local roofSign = p(0, 22.6, 24, 24, 3.6, 0.4, CARBON, Enum.Material.Metal)
		sign(roofSign, Enum.NormalId.Front, string.upper(team.name) .. " RACING", team.colour)
	end
	m.Parent = parent
	return m
end

-- building-site clutter on a plot whose garage is not up yet; each kind is cleared away by
-- the piece that replaces it (Config.GaragePieces `clears`)
function Scenery.siteProp(name: string, parent: Instance, cf: CFrame): Model
	local m = Instance.new("Model")
	m.Name = name
	local function p(x: number, y: number, z: number, sx: number, sy: number, sz: number, c: Color3, mat: Enum.Material?): Part
		return block(m, cf * CFrame.new(x, y, z), Vector3.new(sx, sy, sz), c, mat)
	end
	if name == "Cones" then
		for _, at in { Vector2.new(-20, -20), Vector2.new(14, -21), Vector2.new(-28, 4), Vector2.new(28, -6),
			Vector2.new(-10, 20), Vector2.new(20, 8) } do
			p(at.X, 0.08, at.Y, 1.2, 0.16, 1.2, ORANGE)
			local cone = p(at.X, 0.6, at.Y, 0.9, 0.7, 0.7, ORANGE)
			cone.Shape = Enum.PartType.Cylinder
			cone.CFrame = cf * CFrame.new(at.X, 0.6, at.Y) * CFrame.Angles(0, 0, math.rad(90))
			local band = p(at.X, 0.65, at.Y, 0.2, 0.74, 0.74, WHITE)
			band.Shape = Enum.PartType.Cylinder
			band.CFrame = cf * CFrame.new(at.X, 0.65, at.Y) * CFrame.Angles(0, 0, math.rad(90))
		end
	elseif name == "Scaffold" then
		for x = -30, 30, 10 do
			for _, z in { 24.4, 26.2 } do
				p(x, 6, z, 0.3, 12, 0.3, STEEL, Enum.Material.Metal)
			end
		end
		for _, y in { 4, 8, 12 } do
			p(0, y, 25.3, 61, 0.25, 1.9, Color3.fromRGB(176, 132, 84), Enum.Material.WoodPlanks)
			p(0, y + 1, 24.4, 60.6, 0.15, 0.15, STEEL, Enum.Material.Metal)
		end
	elseif name == "Fence" then
		for _, x in { -31.5, 31.5 } do
			for z = -4, 24, 4 do
				p(x, 1.2, z, 0.12, 2.2, 3.9, ORANGE, Enum.Material.Fabric).Transparency = 0.25
				p(x, 1.25, z - 1.95, 0.25, 2.5, 0.25, STEEL, Enum.Material.Metal)
			end
		end
	elseif name == "SiteSign" then
		for _, x in { -5, 5 } do
			p(x, 2.5, 23.5, 0.3, 5, 0.3, STEEL, Enum.Material.Metal)
		end
		local board = p(0, 4.2, 23.4, 12, 3, 0.25, Color3.fromRGB(250, 205, 40))
		sign(board, Enum.NormalId.Front, "UNDER CONSTRUCTION", CARBON)
	end
	m.Parent = parent
	return m
end

-- a stamping press over the conveyor: a C-frame (two posts behind the belt, open to the
-- front, where players stand), a crosshead in team colours, a hydraulic cylinder and the die
-- that comes down on each part. cf = the crosshead's centre. Returns the
-- crosshead (named, the label's anchor) and the die (moved by the stamp).
-- detailed with a bolted base, post bands, hydraulic lines, controls, braces and a gauge.
function Scenery.press(parent: Instance, cf: CFrame, name: string, colour: Color3): (Part, Part)
	local HAZARD = Color3.fromRGB(250, 205, 40)
	for _, x in { -0.8, 0.8 } do
		block(parent, cf * CFrame.new(x, -4.3, 3.8), Vector3.new(0.4, 9.2, 0.6), STEEL, Enum.Material.Metal)
	end
	local head = block(parent, cf * CFrame.new(0, 0, 1.2), Vector3.new(2.6, 1, 5.6), Color3.fromRGB(70, 74, 82), Enum.Material.Metal)
	head.Name = name
	block(parent, cf * CFrame.new(0, 0.62, 1.2), Vector3.new(2.8, 0.25, 5.9), colour)
	local cylinder = block(parent, cf * CFrame.new(0, -1.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(2, 1.4, 1.4),
		Color3.fromRGB(176, 182, 190), Enum.Material.Metal)
	cylinder.Shape = Enum.PartType.Cylinder
	local die = block(parent, cf * CFrame.new(0, -2.9, 0), Vector3.new(2.2, 0.7, 2.2), Color3.fromRGB(60, 64, 72), Enum.Material.Metal)
	die.Name = "Die"
	for k, z in { -0.75, 0, 0.75 } do -- hazard stripes on the die's face
		block(parent, cf * CFrame.new(-1.11, -2.9, z), Vector3.new(0.02, 0.5, 0.5), k % 2 == 1 and Color3.fromRGB(250, 205, 40) or CARBON)
	end
	-- a floor plate and four bolts behind the belt
	block(parent, cf * CFrame.new(0, -8.5, 3.8), Vector3.new(2.6, 0.2, 1.05), STEEL:Lerp(CARBON, 0.55), Enum.Material.Metal)
	for _, x in { -1.08, 1.08 } do
		for _, z in { 3.45, 4.15 } do
			local bolt = block(parent, cf * CFrame.new(x, -8.34, z) * CFrame.Angles(0, 0, math.rad(90)),
				Vector3.new(0.12, 0.18, 0.18), STEEL, Enum.Material.Metal)
			bolt.Shape = Enum.PartType.Cylinder
			bolt.CastShadow = false
		end
	end
	-- hazard bands wrap the lower posts
	for _, x in { -0.8, 0.8 } do
		for k = 0, 2 do
			block(parent, cf * CFrame.new(x, -7.58 + k * 0.83, 3.8), Vector3.new(0.46, 0.82, 0.66),
				k % 2 == 0 and HAZARD or CARBON, Enum.Material.Metal)
		end
	end
	-- hydraulic lines rise behind the posts and turn into the cylinder's top
	local pipeSteel = STEEL:Lerp(CARBON, 0.25)
	for _, x in { -0.65, 0.65 } do
		local riser = block(parent, cf * CFrame.new(x, -4.4, 4.18) * CFrame.Angles(0, 0, math.rad(90)),
			Vector3.new(7.5, 0.18, 0.18), pipeSteel, Enum.Material.Metal)
		riser.Shape = Enum.PartType.Cylinder
		local elbow = block(parent, cf * CFrame.new(x, -0.65, 4.18), Vector3.new(0.24, 0.24, 0.24), pipeSteel, Enum.Material.Metal)
		elbow.CastShadow = false
		local feed = block(parent, cf * CFrame.new(x, -0.65, 2.09) * CFrame.Angles(0, math.rad(90), 0),
			Vector3.new(4.18, 0.18, 0.18), pipeSteel, Enum.Material.Metal)
		feed.Shape = Enum.PartType.Cylinder
	end
	-- front-facing controls and a thin hazard frame on the right post
	block(parent, cf * CFrame.new(0.82, -4.1, 3.38), Vector3.new(0.72, 0.85, 0.32), CARBON, Enum.Material.Metal)
	for _, button in {
		{ x = 0.65, colour = Color3.fromRGB(40, 230, 90) },
		{ x = 0.99, colour = Color3.fromRGB(235, 40, 40) },
	} do
		local p = block(parent, cf * CFrame.new(button.x, -4.1, 3.16), Vector3.new(0.18, 0.18, 0.12), button.colour, Enum.Material.Neon)
		p.CastShadow = false
	end
	for _, y in { -4.54, -3.66 } do
		block(parent, cf * CFrame.new(0.82, y, 3.2), Vector3.new(0.8, 0.04, 0.06), HAZARD, Enum.Material.Metal).CastShadow = false
	end
	for _, x in { 0.44, 1.2 } do
		block(parent, cf * CFrame.new(x, -4.1, 3.2), Vector3.new(0.04, 0.88, 0.06), HAZARD, Enum.Material.Metal).CastShadow = false
	end
	-- diagonal braces support the head at each post
	for _, x in { -0.8, 0.8 } do
		block(parent, cf * CFrame.new(x, -0.9, 3.15) * CFrame.Angles(math.rad(45), 0, 0),
			Vector3.new(0.32, 0.32, 1.6), STEEL, Enum.Material.Metal)
	end
	-- three bolt heads on the head's front face
	for _, x in { -0.85, 0, 0.85 } do
		local bolt = block(parent, cf * CFrame.new(x, 0, -1.65) * CFrame.Angles(0, math.rad(90), 0),
			Vector3.new(0.12, 0.2, 0.2), STEEL, Enum.Material.Metal)
		bolt.Shape = Enum.PartType.Cylinder
		bolt.CastShadow = false
	end
	-- a white pressure dial and red needle on the cylinder's front
	local gauge = block(parent, cf * CFrame.new(0, -1.35, -0.73) * CFrame.Angles(0, math.rad(90), 0),
		Vector3.new(0.08, 0.45, 0.45), WHITE, Enum.Material.Metal)
	gauge.Shape = Enum.PartType.Cylinder
	gauge.CastShadow = false
	local needle = block(parent, cf * CFrame.new(0.035, -1.3, -0.79) * CFrame.Angles(0, 0, math.rad(-35)),
		Vector3.new(0.035, 0.22, 0.025), Color3.fromRGB(235, 40, 40), Enum.Material.Metal)
	needle.CastShadow = false
	return head, die
end

-- the collection case at the back of the garage: a gold bar for each Gold part stamped and a
-- gem for each Rainbow (up to six of each on show), with the totals on the plinth
function Scenery.shelf(parent: Instance, cf: CFrame, gold: number, rainbow: number): Model
	local m = Instance.new("Model")
	m.Name = "Shelf"
	local warm = Color3.fromRGB(255, 218, 150)
	local goldColour = Color3.fromRGB(232, 180, 54)
	local function p(x: number, y: number, z: number, sx: number, sy: number, sz: number, c: Color3, mat: Enum.Material?): Part
		local part = block(m, cf * CFrame.new(x, y, z), Vector3.new(sx, sy, sz), c, mat)
		part.CastShadow = false
		return part
	end
	local base = p(0, 0.4, 0, 9, 0.8, 1.8, CARBON, Enum.Material.Metal)
	sign(base, Enum.NormalId.Front, ("%d GOLD  %d RAINBOW"):format(gold, rainbow), warm)
	local header = p(0, 5.05, 0, 9, 0.7, 1.8, CARBON, Enum.Material.Metal)
	sign(header, Enum.NormalId.Front, "RARE PARTS", warm)
	p(0, 2.75, 0.82, 8.6, 3.9, 0.12, DARK_STEEL, Enum.Material.Metal)
	for _, x in { -4.35, 4.35 } do
		for _, z in { -0.76, 0.76 } do
			p(x, 2.75, z, 0.3, 3.9, 0.28, DARK_STEEL, Enum.Material.Metal)
		end
	end
	for _, y in { 1, 2.95 } do
		p(0, y, 0, 8.5, 0.12, 1.5, STEEL, Enum.Material.Metal)
	end
	for _, y in { 2.83, 4.64 } do
		local strip = p(0, y, -0.48, 8.1, 0.06, 0.12, warm, Enum.Material.Neon)
		if y > 4 then
			local light = Instance.new("PointLight")
			light.Color = warm
			light.Brightness, light.Range = 0.7, 7
			light.Shadows = false
			light.Parent = strip
		end
	end
	local glass = p(0, 2.75, -0.84, 8.4, 3.9, 0.06, Color3.fromRGB(205, 226, 235), Enum.Material.Glass)
	glass.Transparency = 0.86
	glass.Reflectance = 0.04
	local colours = {
		Color3.fromRGB(240, 65, 70), Color3.fromRGB(255, 149, 48), Color3.fromRGB(255, 218, 65),
		Color3.fromRGB(65, 206, 123), Color3.fromRGB(55, 155, 242), Color3.fromRGB(168, 91, 235),
	}
	for level = 1, 2 do
		local deck = if level == 1 then 1.06 else 3.01
		local count = if level == 1 then rainbow else gold
		for slot = 1, 6 do
			local x = -3.5 + (slot - 1) * 1.4
			if slot > math.clamp(math.floor(count), 0, 6) then
				-- Four faint edges mark an unfilled slot without pretending it holds a trophy.
				for _, side in { -1, 1 } do
					p(x + side * 0.57, deck + 0.035, 0, 0.035, 0.04, 0.9, STEEL, Enum.Material.Metal).Transparency = 0.65
					p(x, deck + 0.035, side * 0.43, 1.14, 0.04, 0.035, STEEL, Enum.Material.Metal).Transparency = 0.65
				end
			else
				p(x, deck + 0.07, 0, 1.18, 0.14, 1, CARBON, Enum.Material.Metal)
				p(x, deck + 0.22, 0.12, 0.2, 0.2, 0.35, STEEL, Enum.Material.Metal)
				if level == 2 then
					local y = deck + 0.88
					local rim = p(x, y, 0.05, 0.22, 1.08, 1.08, goldColour, Enum.Material.Metal)
					rim.Shape = Enum.PartType.Cylinder
					rim.CFrame *= CFrame.Angles(0, math.pi / 2, 0)
					local recess = p(x, y, -0.01, 0.24, 0.82, 0.82, CARBON, Enum.Material.Metal)
					recess.Shape = Enum.PartType.Cylinder
					recess.CFrame *= CFrame.Angles(0, math.pi / 2, 0)
					for spoke = 0, 3 do
						local a = spoke / 4 * math.pi * 2 + math.pi / 4
						local bar = p(x + math.cos(a) * 0.24, y + math.sin(a) * 0.24, -0.17,
							0.45, 0.1, 0.07, goldColour, Enum.Material.Metal)
						bar.CFrame *= CFrame.Angles(0, 0, a)
					end
					local hub = p(x, y, -0.2, 0.12, 0.24, 0.24, goldColour, Enum.Material.Foil)
					hub.Shape = Enum.PartType.Cylinder
					hub.CFrame *= CFrame.Angles(0, math.pi / 2, 0)
				else
					-- Six staggered aero elements with upright endplates make a miniature front wing.
					for layer, colour in colours do
						p(x, deck + 0.37 + (layer - 1) * 0.1, 0.18 - (layer - 1) * 0.065,
							1.06, 0.065, 0.45, colour, Enum.Material.Metal)
					end
					for _, side in { -1, 1 } do
						p(x + side * 0.56, deck + 0.6, 0.02, 0.06, 0.7, 0.82,
							if side == -1 then colours[1] else colours[6], Enum.Material.Metal)
					end
				end
			end
		end
	end
	-- Full case: 126 Parts; empty positions use fewer Parts than an occupied plinth.
	m.Parent = parent
	return m
end

local SKIN = { Color3.fromRGB(255, 220, 190), Color3.fromRGB(234, 184, 146), Color3.fromRGB(196, 140, 98),
	Color3.fromRGB(141, 92, 62), Color3.fromRGB(92, 58, 40) }

-- a crew member standing at cf (feet on the floor, facing cf's look direction) in a race suit
-- of the team's colour, a chest band of their rarity's colour, a team cap and the kit of their
-- job. Returns the head, for a name tag.
function Scenery.crewMember(parent: Instance, cf: CFrame, suit: Color3, band: Color3, prop: string, look: number): Part
	local m = Instance.new("Model")
	m.Name = "CrewMember"
	local function p(x: number, y: number, z: number, sx: number, sy: number, sz: number, c: Color3, mat: Enum.Material?): Part
		return block(m, cf * CFrame.new(x, y, z), Vector3.new(sx, sy, sz), c, mat)
	end
	for _, x in { -0.5, 0.5 } do
		p(x, 1.3, 0, 0.9, 2.2, 0.9, suit) -- legs
		p(x, 0.2, -0.1, 0.95, 0.4, 1.15, CARBON) -- boots
	end
	p(0, 3.5, 0, 2, 2.2, 1, suit) -- body
	p(0, 4.1, 0, 2.04, 0.35, 1.04, band, Enum.Material.Neon) -- rarity band
	p(0, 2.5, 0, 2.04, 0.25, 1.04, CARBON) -- belt
	for _, x in { -1.4, 1.4 } do
		p(x, 3.4, 0, 0.75, 2.1, 0.75, suit) -- arms
		p(x, 2.15, 0, 0.7, 0.45, 0.7, CARBON) -- gloves
	end
	local head = p(0, 5.25, 0, 1.25, 1.3, 1.25, SKIN[(look % #SKIN) + 1])
	p(0, 5.95, 0, 1.35, 0.35, 1.35, suit) -- cap
	p(0, 5.82, -0.85, 1.1, 0.1, 0.6, suit) -- its peak
	for _, x in { -0.25, 0.25 } do
		p(x, 5.35, -0.63, 0.18, 0.18, 0.05, CARBON) -- eyes
	end
	if prop == "tyre" then
		local tyre = p(2.25, 2.4, 0, 0.9, 2.3, 2.3, CARBON)
		tyre.Shape = Enum.PartType.Cylinder
		local rim = p(2.3, 2.4, 0, 0.92, 1.2, 1.2, STEEL, Enum.Material.Metal)
		rim.Shape = Enum.PartType.Cylinder
	elseif prop == "wrench" then
		p(1.4, 1.4, -0.3, 0.2, 1.6, 0.4, STEEL, Enum.Material.Metal)
		p(1.4, 0.55, -0.3, 0.2, 0.4, 0.8, STEEL, Enum.Material.Metal)
	elseif prop == "lollipop" then
		p(1.4, 3.6, -0.5, 0.15, 3.4, 0.15, CARBON) -- the pole
		local board = p(1.4, 5.9, -0.5, 0.15, 1.9, 1.9, Color3.fromRGB(250, 205, 40)) -- yellow: it shows against any suit
		board.Shape = Enum.PartType.Cylinder
		board.CFrame = cf * CFrame.new(1.4, 5.9, -0.5) * CFrame.Angles(0, math.rad(90), 0)
	elseif prop == "headset" then
		for _, x in { -0.72, 0.72 } do
			p(x, 5.3, 0, 0.25, 0.6, 0.6, CARBON) -- ear cups
		end
		p(0, 6.18, 0, 1.5, 0.12, 0.25, CARBON) -- band over the cap
		p(-0.55, 5.0, -0.5, 0.08, 0.08, 0.6, CARBON) -- microphone
	elseif prop == "clipboard" then
		p(0.6, 3.2, -0.75, 1.0, 1.3, 0.08, Color3.fromRGB(120, 86, 50))
		p(0.6, 3.15, -0.8, 0.85, 1.05, 0.02, WHITE)
	elseif prop == "wing" then
		p(0, 2.6, -1.0, 3.2, 0.18, 0.9, CARBON) -- a front wing, carried in both hands
		for _, x in { -1.55, 1.55 } do
			p(x, 2.85, -1.0, 0.1, 0.5, 0.95, band)
		end
	elseif prop == "laptop" then
		p(0, 2.6, -0.95, 1.4, 0.08, 1.0, Color3.fromRGB(70, 74, 82), Enum.Material.Metal)
		-- the screen stands at the far edge, lit on the side facing its user
		local screen = p(0, 3.05, -1.4, 1.4, 0.9, 0.06, Color3.fromRGB(70, 74, 82), Enum.Material.Metal)
		screen.CFrame = cf * CFrame.new(0, 3.05, -1.4) * CFrame.Angles(math.rad(-15), 0, 0)
		local glow = p(0, 3.05, -1.36, 1.25, 0.75, 0.02, Color3.fromRGB(60, 230, 120), Enum.Material.Neon)
		glow.CFrame = cf * CFrame.new(0, 3.05, -1.36) * CFrame.Angles(math.rad(-15), 0, 0)
	end
	m.Parent = parent
	return head
end

-- a show car built from parts; gold trim from season 2, a gold livery from season 4
function Scenery.car(parent: Instance, cf: CFrame, colour: Color3, season: number, driver: boolean?): Model
	local car = Instance.new("Model")
	car.Name = "ShowCar"
	local body = season >= 3 and Color3.fromRGB(212, 175, 55) or colour
	local trim = season >= 1 and Color3.fromRGB(255, 205, 60) or CARBON
	local function p(x: number, y: number, z: number, sx: number, sy: number, sz: number, c: Color3, m: Enum.Material?): Part
		return block(car, cf * CFrame.new(x, y, z), Vector3.new(sx, sy, sz), c, m)
	end
	p(0, 0.55, 0, 3.0, 0.25, 11, CARBON) -- floor
	p(0, 1.15, 0.6, 2.0, 1.1, 6.2, body) -- tub
	local nose = Instance.new("WedgePart")
	nose.Anchored, nose.CanCollide, nose.CanTouch = true, false, false
	nose.Size = Vector3.new(1.1, 0.75, 3.6)
	nose.CFrame = cf * CFrame.new(0, 1.0, -4.3)
	nose.Color = body
	nose.Material = Enum.Material.SmoothPlastic
	nose.Parent = car
	for _, x in { -1.45, 1.45 } do
		p(x, 1.0, 1.0, 0.9, 0.85, 3.4, body) -- sidepods
	end
	p(0, 1.75, -0.7, 0.85, 0.12, 1.5, CARBON) -- cockpit
	p(0, 2.3, -0.8, 0.14, 0.14, 1.6, CARBON, Enum.Material.Metal) -- halo
	p(0, 1.95, -1.55, 0.14, 0.75, 0.14, CARBON, Enum.Material.Metal)
	p(0, 2.05, 2.0, 0.9, 1.2, 2.6, body) -- engine cover
	p(0, 2.55, 0.8, 0.6, 0.5, 0.4, CARBON) -- airbox
	p(0, 0.45, -5.8, 4.2, 0.14, 1.0, trim) -- front wing
	for _, x in { -2.1, 2.1 } do
		p(x, 0.65, -5.8, 0.12, 0.5, 1.1, body)
	end
	p(0, 2.95, 4.7, 3.3, 0.2, 0.9, trim) -- rear wing
	for _, x in { -1.65, 1.65 } do
		p(x, 2.3, 4.7, 0.12, 1.5, 1.2, body)
	end
	p(0, 2.2, 4.4, 0.25, 1.2, 0.25, CARBON, Enum.Material.Metal)
	p(0, 0.62, -5.45, 3.9, 0.12, 0.45, body) -- front wing flap
	p(0, 3.2, 4.95, 3.3, 0.14, 0.45, body) -- rear wing flap
	local function wedge(x: number, y: number, z: number, sx: number, sy: number, sz: number, c: Color3, turn: number)
		local w = Instance.new("WedgePart")
		w.Anchored, w.CanCollide, w.CanTouch = true, false, false
		w.Size = Vector3.new(sx, sy, sz)
		w.CFrame = cf * CFrame.new(x, y, z) * CFrame.Angles(0, turn, 0)
		w.Color = c
		w.Material = Enum.Material.SmoothPlastic
		w.Parent = car
	end
	for _, x in { -1.45, 1.45 } do
		wedge(x, 1.0, -1.1, 0.9, 0.85, 0.8, body, 0) -- sidepod noses, sloping into the air
		p(x * 0.72, 1.0, -0.72, 0.5, 0.55, 0.06, CARBON) -- intakes
	end
	wedge(0, 2.05, 4.0, 0.9, 1.2, 1.6, body, math.pi) -- engine cover sloping to the rear
	-- a thin carbon bar from a to b (suspension arms, the halo's sides, mirror stalks)
	local function bar(a: Vector3, b: Vector3, thick: number, c: Color3?)
		local piece = block(car, cf * CFrame.lookAt((a + b) / 2, b), Vector3.new(thick, thick, (b - a).Magnitude),
			c or CARBON, Enum.Material.Metal)
		return piece
	end
	for _, side in { -1, 1 } do
		-- double wishbones out to each wheel, front and rear
		bar(Vector3.new(side * 0.55, 1.35, -3.0), Vector3.new(side * 1.5, 1.05, -3.3), 0.1)
		bar(Vector3.new(side * 0.55, 0.75, -2.8), Vector3.new(side * 1.5, 0.7, -3.3), 0.1)
		bar(Vector3.new(side * 0.45, 1.6, 3.2), Vector3.new(side * 1.35, 1.4, 3.4), 0.1)
		bar(Vector3.new(side * 0.45, 0.8, 3.0), Vector3.new(side * 1.35, 0.75, 3.4), 0.1)
		-- the halo's arms from the cockpit sides up to its top bar
		bar(Vector3.new(side * 0.45, 1.8, 0.15), Vector3.new(side * 0.12, 2.3, -0.25), 0.13)
		-- mirrors on stalks
		bar(Vector3.new(side * 0.95, 1.6, -1.7), Vector3.new(side * 1.3, 1.85, -1.75), 0.07)
		p(side * 1.4, 1.88, -1.75, 0.35, 0.18, 0.14, body)
	end
	p(0, 0.78, -5.25, 3.7, 0.1, 0.4, trim) -- the front wing's second element
	p(0, 1.6, 5.0, 2.5, 0.12, 0.4, CARBON) -- beam wing
	for _, x in { -0.9, -0.3, 0.3, 0.9 } do
		p(x, 0.8, 5.3, 0.08, 0.45, 0.9, CARBON) -- diffuser strakes
	end
	p(0, 2.86, 0.8, 0.55, 0.1, 0.2, Color3.fromRGB(255, 205, 60)) -- the T-cam on the airbox
	if driver then
		local helmet = p(0, 2.05, -0.75, 0.85, 0.85, 0.85, trim == CARBON and WHITE or trim)
		helmet.Shape = Enum.PartType.Ball
		p(0, 2.1, -1.15, 0.6, 0.22, 0.1, CARBON) -- visor
	end
	for _, w in { { -3.3, 1.7, 1.0 }, { 3.4, 1.85, 1.3 } } do
		for _, x in { -1.95, 1.95 } do
			local wheel = p(x, w[2] / 2, w[1], w[3], w[2], w[2], CARBON)
			wheel.Shape = Enum.PartType.Cylinder
			-- a thin white band round each sidewall: discs stacked a hair proud of each other,
			-- band, then black sidewall inside it, then the rim on top
			local discs = {
				{ proud = 0.02, size = 0.86, colour = WHITE, metal = false },
				{ proud = 0.04, size = 0.76, colour = CARBON, metal = false },
				{ proud = 0.06, size = 0.55, colour = trim, metal = true },
			}
			for _, disc in discs do
				local d = p(x, w[2] / 2, w[1], w[3] + disc.proud, w[2] * disc.size, w[2] * disc.size, disc.colour,
					if disc.metal then Enum.Material.Metal else nil)
				d.Shape = Enum.PartType.Cylinder
			end
		end
	end
	car.Parent = parent
	return car
end

-- a time-trial circuit: the road with white edge lines and red and white kerbs on the bends,
-- a chequered start line and a gantry over it titled `title`. Given `grassTo`, it also lays
-- the ground: grass out past that radius, and the paddock's asphalt inside this circuit.
function Scenery.track(shape: TrackShape.Shape, name: string, title: string, grassTo: number?)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = workspace
	local n = 200
	local points = TrackShape.samples(shape, n)
	local inner, outer = math.huge, 0
	for _, p in points do
		local r = math.sqrt(p.x * p.x + p.z * p.z)
		inner, outer = math.min(inner, r), math.max(outer, r)
	end
	inner -= shape.halfWidth
	outer += shape.halfWidth
	if grassTo then
		local size = 2 * math.max(outer, grassTo) + 80
		local grass = block(folder, CFrame.new(0, -0.7, 0), Vector3.new(size, 1, size), Color3.fromRGB(78, 128, 64),
			Enum.Material.Grass)
		grass.CanCollide = true
		-- the paddock's asphalt stops just inside the track, so the infield between is grass
		local floor = block(folder, CFrame.new(0, -0.6, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Vector3.new(1, 2 * (inner - 3), 2 * (inner - 3)), Color3.fromRGB(84, 92, 98), Enum.Material.Asphalt)
		floor.Name = "PaddockFloor"
		floor.Shape = Enum.PartType.Cylinder
		floor.CanCollide = true
	end
	for i, p in points do
		local q = points[i % n + 1]
		local prev = points[(i - 2) % n + 1]
		local a, b = Vector3.new(p.x, 0, p.z), Vector3.new(q.x, 0, q.z)
		-- alternate pieces sit a hair apart in height, so their overlaps don't flicker
		local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, 0.05 + (i % 2) * 0.02, 0)
		local len = (b - a).Magnitude
		local road = block(folder, cf, Vector3.new(2 * shape.halfWidth, 0.3, len + 1.4), Color3.fromRGB(52, 54, 58),
			Enum.Material.Asphalt)
		road.Name = "Road"
		road.CanCollide = true
		local before = (a - Vector3.new(prev.x, 0, prev.z)).Unit
		local bend = math.acos(math.clamp(before:Dot((b - a).Unit), -1, 1))
		for _, side in { -1, 1 } do
			if bend > 0.07 then
				block(folder, cf * CFrame.new(side * (shape.halfWidth + 0.6), 0.03, 0), Vector3.new(1.2, 0.36, len + 0.2),
					i % 2 == 0 and Color3.fromRGB(214, 32, 32) or WHITE)
			else
				block(folder, cf * CFrame.new(side * (shape.halfWidth - 0.6), 0.04, 0), Vector3.new(0.4, 0.3, len + 1.4), WHITE)
			end
		end
	end
	local sx, sz = TrackShape.point(shape, 0)
	local tx, tz = TrackShape.tangent(shape, 0)
	local start = CFrame.lookAt(Vector3.new(sx, 0, sz), Vector3.new(sx + tx, 0, sz + tz))
	for col = 0, 7 do
		for row = 0, 1 do
			block(folder, start * CFrame.new(-shape.halfWidth + 1 + col * 2, 0.24, (row - 0.5) * 1.2),
				Vector3.new(2, 0.06, 1.2), (col + row) % 2 == 0 and WHITE or CARBON)
		end
	end
	for _, x in { -1, 1 } do
		local post = block(folder, start * CFrame.new(x * (shape.halfWidth + 2.5), 8, 0), Vector3.new(1.4, 16, 1.4), CARBON,
			Enum.Material.Metal)
		post.CanCollide = true
	end
	local beam = block(folder, start * CFrame.new(0, 15, 0), Vector3.new(2 * shape.halfWidth + 6.4, 3, 1.4), CARBON,
		Enum.Material.Metal)
	sign(beam, Enum.NormalId.Front, title, Color3.fromRGB(255, 205, 60))
	sign(beam, Enum.NormalId.Back, title, Color3.fromRGB(255, 205, 60))
	for k = -2, 2 do -- the start lights (Drive.client.luau runs each driver's start on them)
		local light = block(folder, start * CFrame.new(k * 2.2, 13, -0.4), Vector3.new(1, 1, 0.6), Color3.fromRGB(255, 40, 40),
			Enum.Material.Neon)
		light.Name = "StartLight" .. (k + 3)
	end
end

return Scenery
