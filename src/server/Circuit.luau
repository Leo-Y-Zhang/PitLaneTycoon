--!strict
-- The whole venue is static, non-interactive decoration; no assets or per-frame work.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local CircuitLayout = require(Shared:WaitForChild("CircuitLayout"))
local Scenery = require(script.Parent:WaitForChild("Scenery"))

local Circuit = {}
type Placement = CircuitLayout.Placement

local CARBON = Color3.fromRGB(25, 29, 35)
local STEEL = Color3.fromRGB(155, 169, 179)
local CONCRETE = Color3.fromRGB(164, 172, 180)
local WHITE = Color3.fromRGB(238, 242, 245)
local ORANGE = Color3.fromRGB(255, 133, 34)
local greens = {
	Color3.fromRGB(50, 105, 55), Color3.fromRGB(66, 122, 59),
	Color3.fromRGB(78, 134, 65), Color3.fromRGB(43, 94, 62),
}
local shirts = {
	Color3.fromRGB(243, 205, 60), Color3.fromRGB(233, 237, 240),
	Color3.fromRGB(78, 141, 184), Color3.fromRGB(210, 100, 143),
}
local skin = {
	Color3.fromRGB(239, 193, 148), Color3.fromRGB(183, 126, 87), Color3.fromRGB(111, 73, 52),
}
local sponsors = { "TURBO OIL", "APEX TYRES", "GRIDLINE" }

function Circuit.build(): Folder
	local shapes: { CircuitLayout.Shape } = { Config.Track, Config.LongTrack }
	local layout = CircuitLayout.generate(shapes, Config.PlotCount, Config.PlotRadius)
	local previous = workspace:FindFirstChild("Venue")
	if previous then previous:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "Venue"
	local count = 0
	local towers = 0

	local function part(cf: CFrame, size: Vector3, colour: Color3, material: Enum.Material?): Part
		local p = Scenery.block(folder, cf, size, colour, material)
		p.CanQuery = false
		p.CastShadow = math.min(size.X, size.Y, size.Z) >= 2
		count += 1
		return p
	end

	local function strut(cf: CFrame, a: Vector3, b: Vector3)
		part(cf * CFrame.lookAt((a + b) / 2, b), Vector3.new(0.22, 0.22, (b - a).Magnitude), STEEL, Enum.Material.Metal)
	end

	local function grandstand(p: Placement, cf: CFrame)
		local team = Scenery.Teams[p.variant % #Scenery.Teams + 1].colour
		part(cf * CFrame.new(0, 0.1, 0), Vector3.new(44, 0.6, 18), CONCRETE, Enum.Material.Concrete)
		for row = 0, 4 do
			local z, height = -6.4 + row * 2.6, 1.2 + row * 1.45
			part(cf * CFrame.new(0, height / 2 - 0.2, z), Vector3.new(42, height, 2.6), CONCRETE, Enum.Material.Concrete)
			part(cf * CFrame.new(0, height + 0.05, z), Vector3.new(40, 0.4, 1.7), team)
			for seat = 0, 7 do
				local n = p.variant + row * 13 + seat * 7
				local x = -17.5 + seat * 5
				local shirt = if n % 3 == 0 then Scenery.Teams[n % #Scenery.Teams + 1].colour else shirts[n % #shirts + 1]
				part(cf * CFrame.new(x, height + 0.95, z), Vector3.new(1.55, 1.5, 1.3), shirt)
				part(cf * CFrame.new(x, height + 2.1, z - 0.05), Vector3.new(0.85, 0.85, 0.85), skin[n % #skin + 1])
			end
		end
		part(cf * CFrame.new(0, 13.8, 0), Vector3.new(46, 0.65, 20), CARBON, Enum.Material.Metal)
		for _, x in { -21, 21 } do
			for _, z in { -8, 8 } do
				part(cf * CFrame.new(x, 6.8, z), Vector3.new(0.7, 14, 0.7), STEEL, Enum.Material.Metal)
			end
		end
		for _, z in { -8, 8 } do
			part(cf * CFrame.new(0, 13.2, z), Vector3.new(44, 0.7, 0.8), STEEL, Enum.Material.Metal)
		end
		local fascia = part(cf * CFrame.new(0, 13.3, -10.1), Vector3.new(46, 1.6, 0.35), team)
		Scenery.sign(fascia, Enum.NormalId.Front, if p.track == 1 then "TIME TRIAL  /  CIRCUIT CLUB" else "ENDURANCE  /  CIRCUIT CLUB", WHITE)
		part(cf * CFrame.new(0, 1.4, -9), Vector3.new(44, 0.5, 0.35), STEEL, Enum.Material.Metal)
		for _, x in { -22, 22 } do
			part(cf * CFrame.new(x, 7.4, 0), Vector3.new(0.35, 0.6, 18), STEEL, Enum.Material.Metal)
		end
		for _, x in { -20, 20 } do
			part(cf * CFrame.new(x, 16, 7), Vector3.new(0.16, 6, 0.16), STEEL, Enum.Material.Metal)
			part(cf * CFrame.new(x + 1.5, 18.1, 7), Vector3.new(3.3, 1.8, 0.15), team)
		end
	end

	local function treeCluster(p: Placement, cf: CFrame)
		for i = 0, 3 do
			local angle = p.variant * 0.01 + i * 2.39996
			local distance = (4 + i * 1.7) * p.scale
			local tree = cf * CFrame.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
			local s = p.scale * (0.85 + (p.variant + i * 7) % 13 / 30)
			part(tree * CFrame.new(0, 3.3 * s, 0), Vector3.new(0.95, 7, 0.95) * s,
				Color3.fromRGB(103, 78, 55), Enum.Material.Wood)
			for layer = 0, 2 do
				local diameter = 8.5 - layer * 1.8
				local canopy = part(tree * CFrame.new(0, (7 + layer * 2.8) * s, 0),
					Vector3.new(diameter, 6 - layer * 0.6, diameter) * s,
					greens[(p.variant + i + layer) % #greens + 1], Enum.Material.Grass)
				canopy.Shape = Enum.PartType.Ball
			end
		end
	end

	local function tyreWall(p: Placement, cf: CFrame)
		for column = 0, 4 do
			for row = 0, 2 do
				local tyre = part(cf * CFrame.new(-6 + column * 3, 0.4 + row, 0) * CFrame.Angles(0, 0, math.pi / 2),
					Vector3.new(0.95, 2.8, 2.8), CARBON)
				tyre.Shape = Enum.PartType.Cylinder
			end
		end
		part(cf * CFrame.new(0, 1.5, -1.43), Vector3.new(15, 0.5, 0.18),
			if p.variant % 2 == 0 then WHITE else Scenery.Teams[p.variant % #Scenery.Teams + 1].colour)
	end

	local function armco(_p: Placement, cf: CFrame)
		for _, x in { -8, 0, 8 } do
			part(cf * CFrame.new(x, 1.3, 0.3), Vector3.new(0.5, 3, 0.6), STEEL, Enum.Material.Metal)
		end
		for _, y in { 1, 2.2 } do
			part(cf * CFrame.new(0, y, 0), Vector3.new(18, 0.45, 0.35), STEEL, Enum.Material.Metal)
		end
	end

	local function billboard(p: Placement, cf: CFrame)
		local accent = Scenery.Teams[p.variant % #Scenery.Teams + 1].colour
		for _, x in { -8, 8 } do
			part(cf * CFrame.new(x, 3.3, 0), Vector3.new(0.8, 7, 0.8), STEEL, Enum.Material.Metal)
		end
		local board = part(cf * CFrame.new(0, 10, 0), Vector3.new(24, 7, 0.6), CARBON)
		local text = sponsors[p.variant % #sponsors + 1]
		Scenery.sign(board, Enum.NormalId.Front, text, WHITE)
		Scenery.sign(board, Enum.NormalId.Back, text, WHITE)
		for _, y in { 6.4, 13.6 } do
			part(cf * CFrame.new(0, y, 0), Vector3.new(25, 0.5, 0.9), accent, Enum.Material.Metal)
		end
		for _, x in { -12.25, 12.25 } do
			part(cf * CFrame.new(x, 10, 0), Vector3.new(0.5, 7.2, 0.9), accent, Enum.Material.Metal)
		end
	end

	local function marshalPost(p: Placement, cf: CFrame)
		part(cf * CFrame.new(0, 0, 0), Vector3.new(10, 0.4, 8), CONCRETE, Enum.Material.Concrete)
		part(cf * CFrame.new(0, 3, 2.5), Vector3.new(8, 5.5, 0.5), WHITE)
		for _, x in { -3.8, 3.8 } do
			part(cf * CFrame.new(x, 3, 0), Vector3.new(0.45, 5.5, 5.5), WHITE)
		end
		part(cf * CFrame.new(0, 6.3, 0), Vector3.new(10, 0.5, 8), CARBON, Enum.Material.Metal)
		local window = part(cf * CFrame.new(0, 4, -2.8), Vector3.new(7, 2.5, 0.2), Color3.fromRGB(147, 201, 212), Enum.Material.Glass)
		window.Transparency = 0.4
		part(cf * CFrame.new(4.5, 6, 0), Vector3.new(0.15, 12, 0.15), STEEL, Enum.Material.Metal)
		part(cf * CFrame.new(5.4, 11.5, 0), Vector3.new(2, 0.9, 0.1), ORANGE)
		local board = part(cf * CFrame.new(0, 1.2, -2.9), Vector3.new(7, 1.6, 0.25), ORANGE)
		Scenery.sign(board, Enum.NormalId.Front, "MARSHAL " .. tostring(p.variant % 20 + 1), CARBON)
	end

	local function floodlight(_p: Placement, cf: CFrame)
		towers += 1
		part(cf * CFrame.new(0, 0.2, 0), Vector3.new(4, 0.8, 4), CONCRETE, Enum.Material.Concrete)
		for _, x in { -1.2, 1.2 } do
			for _, z in { -1.2, 1.2 } do
				part(cf * CFrame.new(x, 14, z), Vector3.new(0.3, 28, 0.3), STEEL, Enum.Material.Metal)
			end
		end
		for _, z in { -1.2, 1.2 } do
			for level = 0, 3 do
				local x = if level % 2 == 0 then -1.2 else 1.2
				strut(cf, Vector3.new(x, 1 + level * 6.3, z), Vector3.new(-x, 7.3 + level * 6.3, z))
			end
		end
		part(cf * CFrame.new(0, 28, 0), Vector3.new(8, 0.6, 2), CARBON, Enum.Material.Metal)
		for lamp = 0, 3 do
			local bank = part(cf * CFrame.new(-3 + lamp * 2, 29, -0.8) * CFrame.Angles(math.rad(-30), 0, 0),
				Vector3.new(1.6, 1.2, 0.5), Color3.fromRGB(255, 244, 212), Enum.Material.Neon)
			if towers % 4 == 0 and lamp == 1 then
				local light = Instance.new("SpotLight")
				light.Face = Enum.NormalId.Front
				light.Angle = 65
				light.Range = 80
				light.Brightness = 2
				light.Color = bank.Color
				light.Shadows = false
				light.Parent = bank
			end
		end
	end

	local function hill(p: Placement, cf: CFrame)
		local size = Vector3.new(64 + p.variant % 13, 28 + p.variant % 13, 86 + math.floor(p.variant / 13) % 11)
		part(cf * CFrame.new(0, -4, 0) * CFrame.Angles(0.18 + p.variant % 5 * 0.015, 0, if p.variant % 2 == 0 then 0.08 else -0.08),
			size, Color3.fromRGB(74 + p.variant % 9, 124 + p.variant % 9, 61 + p.variant % 7), Enum.Material.Grass)
	end

	local builders: { [string]: (Placement, CFrame) -> () } = {
		grandstand = grandstand, treeCluster = treeCluster, tyreWall = tyreWall, armco = armco,
		billboard = billboard, marshalPost = marshalPost, floodlight = floodlight, hill = hill,
	}
	for _, p in layout.placements do
		local before = count
		builders[p.kind](p, CFrame.new(p.x, 0, p.z) * CFrame.Angles(0, p.yaw, 0))
		assert(count - before == CircuitLayout.PartCost[p.kind], "venue part cost changed: " .. p.kind)
	end
	assert(count == layout.partCount and count <= CircuitLayout.Budget, "venue part budget exceeded")
	folder:SetAttribute("PartCount", count)
	folder.Parent = workspace
	return folder
end

return Circuit
