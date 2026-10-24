--!strict
-- Pit Lane Tycoon scenery: lighting, the paddock, garage walls and each team's show car.
-- Pure decoration, built from code like everything else; nothing here touches money.

local Lighting = game:GetService("Lighting")

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

-- walls, roof and a team-colour band around a plot (plot-local frame: -Z faces the spawn)
function Scenery.garage(model: Instance, cf: CFrame, team: { name: string, colour: Color3 })
	local g = Instance.new("Folder")
	g.Name = "Garage"
	g.Parent = model
	local back = block(g, cf * CFrame.new(0, 6, 25.5), Vector3.new(64, 12, 1), WALL, Enum.Material.Concrete)
	back.CanCollide = true
	for _, x in { -31.5, 31.5 } do
		local side = block(g, cf * CFrame.new(x, 6, 10), Vector3.new(1, 12, 32), WALL, Enum.Material.Concrete)
		side.CanCollide = true
		block(g, cf * CFrame.new(x, 10.5, 10), Vector3.new(1.15, 1.2, 32.1), team.colour)
	end
	block(g, cf * CFrame.new(0, 10.5, 24.9), Vector3.new(62, 1.2, 0.3), team.colour)
	block(g, cf * CFrame.new(0, 12.5, 22), Vector3.new(65, 1, 8.5), CARBON, Enum.Material.Metal) -- awning, leaves the car in the sun
	local name = block(g, cf * CFrame.new(0, 7, 24.9), Vector3.new(30, 4.5, 0.2), WALL)
	name.Transparency = 1
	sign(name, Enum.NormalId.Front, string.upper(team.name), team.colour)
	-- coloured trim round the floor and hazard stripes at the conveyor ends
	block(g, cf * CFrame.new(0, 0.05, -25.8), Vector3.new(64, 0.12, 0.4), team.colour)
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

-- a show car built from parts; gold trim from season 2, a gold livery from season 4
function Scenery.car(parent: Instance, cf: CFrame, colour: Color3, season: number): Model
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
	for _, w in { { -3.3, 1.7, 1.0 }, { 3.4, 1.85, 1.3 } } do
		for _, x in { -1.95, 1.95 } do
			local wheel = p(x, w[2] / 2, w[1], w[3], w[2], w[2], CARBON)
			wheel.Shape = Enum.PartType.Cylinder
			local rim = p(x + (x > 0 and 0.04 or -0.04), w[2] / 2, w[1], w[3] - 0.05, w[2] * 0.55, w[2] * 0.55, trim, Enum.Material.Metal)
			rim.Shape = Enum.PartType.Cylinder
		end
	end
	car.Parent = parent
	return car
end

return Scenery
