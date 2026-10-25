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
end

-- the fittings every plot has from the start: hazard stripes at the conveyor ends and its
-- side rails (plot-local frame: -Z faces the spawn)
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
end

local ORANGE = Color3.fromRGB(255, 120, 20)
local STEEL = Color3.fromRGB(150, 155, 162)
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
	elseif name == "SideWalls" then
		for _, x in { -31.5, 31.5 } do
			p(x, 6, 10, 1, 12, 32, wall, wallMat).CanCollide = true
		end
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
function Scenery.press(parent: Instance, cf: CFrame, name: string, colour: Color3): (Part, Part)
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
	return head, die
end

-- the collection case at the back of the garage: a gold bar for each Gold part stamped and a
-- gem for each Rainbow (up to six of each on show), with the totals on the plinth
function Scenery.shelf(parent: Instance, cf: CFrame, gold: number, rainbow: number): Model
	local m = Instance.new("Model")
	m.Name = "Shelf"
	local plinth = block(m, cf * CFrame.new(0, 0.5, 0), Vector3.new(9, 1, 1.8), CARBON, Enum.Material.Metal)
	local case = block(m, cf * CFrame.new(0, 2.5, 0), Vector3.new(9, 3, 1.8), Color3.fromRGB(190, 220, 240), Enum.Material.Glass)
	case.Transparency = 0.7
	for i = 1, math.min(gold, 6) do
		block(m, cf * CFrame.new(-3.75 + (i - 1) * 1.5, 1.35, 0), Vector3.new(1, 0.45, 0.6), Color3.fromRGB(255, 196, 40), Enum.Material.Neon)
	end
	for i = 1, math.min(rainbow, 6) do
		local gem = block(m, cf * CFrame.new(-3.75 + (i - 1) * 1.5, 2.6, 0), Vector3.new(0.75, 0.75, 0.75),
			Color3.fromRGB(255, 70, 210), Enum.Material.Neon)
		gem.Shape = Enum.PartType.Ball
	end
	sign(plinth, Enum.NormalId.Front, ("RARE PARTS  %d GOLD  %d RAINBOW"):format(gold, rainbow), Color3.fromRGB(255, 205, 60))
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
