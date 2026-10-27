--!strict
-- Pure part recipes shared by show cars, race cars and both garage themes.
local Style = {}

export type RGB = { r: number, g: number, b: number }
export type Team = { name: string, primary: RGB, secondary: RGB, emblem: string, facade: string, number: number }
export type Stroke = { x1: number, y1: number, x2: number, y2: number }
export type Colour = "primary" | "secondary" | "carbon" | "gold"
export type Detail = {
	x: number, y: number, z: number, sx: number, sy: number, sz: number,
	rx: number, ry: number, rz: number, colour: Colour, group: string, cylinder: boolean,
}
export type Counts = { total: number, groups: { [string]: number } }

Style.CarPartBudget = 60
Style.GaragePartBudget = 80
Style.Teams = {
	{ name = "Scarlet", primary = { r = 214, g = 32, b = 32 }, secondary = { r = 255, g = 236, b = 185 }, emblem = "chevron", facade = "chevrons", number = 1 },
	{ name = "Cobalt", primary = { r = 28, g = 86, b = 214 }, secondary = { r = 92, g = 235, b = 255 }, emblem = "star", facade = "grid", number = 2 },
	{ name = "Papaya", primary = { r = 255, g = 128, b = 0 }, secondary = { r = 27, g = 38, b = 61 }, emblem = "bolt", facade = "slashes", number = 3 },
	{ name = "Racing Green", primary = { r = 0, g = 120, b = 72 }, secondary = { r = 220, g = 245, b = 130 }, emblem = "shield", facade = "diamonds", number = 4 },
	{ name = "Violet", primary = { r = 120, g = 60, b = 200 }, secondary = { r = 148, g = 255, b = 207 }, emblem = "wing", facade = "rays", number = 5 },
	{ name = "Teal", primary = { r = 0, g = 160, b = 170 }, secondary = { r = 255, g = 195, b = 202 }, emblem = "ring", facade = "waves", number = 6 },
} :: { Team }

local function stroke(x1: number, y1: number, x2: number, y2: number): Stroke
	return { x1 = x1, y1 = y1, x2 = x2, y2 = y2 }
end
Style.Emblems = {
	chevron = { stroke(-0.45, 0.3, 0, -0.3), stroke(0, -0.3, 0.45, 0.3) },
	star = {},
	bolt = { stroke(0.25, 0.45, -0.2, 0), stroke(-0.2, 0, 0.2, 0), stroke(0.2, 0, -0.25, -0.45) },
	shield = { stroke(-0.4, 0.4, 0.4, 0.4), stroke(-0.4, 0.4, -0.35, -0.15), stroke(0.4, 0.4, 0.35, -0.15),
		stroke(-0.35, -0.15, 0, -0.45), stroke(0.35, -0.15, 0, -0.45) },
	wing = { stroke(-0.45, -0.3, 0.45, -0.3), stroke(-0.45, -0.3, -0.3, 0.4), stroke(-0.3, 0.4, 0.45, -0.3),
		stroke(-0.35, 0.15, 0.2, 0.15), stroke(-0.4, -0.05, 0.1, -0.05), stroke(-0.4, -0.05, -0.35, 0.15) },
	ring = {},
} :: { [string]: { Stroke } }
for i = 0, 4 do
	local a, b = math.pi / 2 + i * math.pi * 4 / 5, math.pi / 2 + (i + 1) * math.pi * 4 / 5
	table.insert(Style.Emblems.star, stroke(math.cos(a) * 0.45, math.sin(a) * 0.45, math.cos(b) * 0.45, math.sin(b) * 0.45))
end
for i = 0, 7 do
	local a, b = i * math.pi / 4, (i + 1) * math.pi / 4
	table.insert(Style.Emblems.ring, stroke(math.cos(a) * 0.4, math.sin(a) * 0.4, math.cos(b) * 0.4, math.sin(b) * 0.4))
end

-- Strokes repeat across the front edge of the existing awning without covering its opening.
Style.Facades = {
	chevrons = Style.Emblems.chevron,
	grid = { stroke(-0.4, -0.4, -0.4, 0.4), stroke(0.4, -0.4, 0.4, 0.4), stroke(-0.4, -0.2, 0.4, -0.2), stroke(-0.4, 0.2, 0.4, 0.2) },
	slashes = { stroke(-0.45, -0.4, -0.25, 0.4), stroke(-0.1, -0.4, 0.1, 0.4), stroke(0.25, -0.4, 0.45, 0.4) },
	diamonds = { stroke(-0.45, 0, 0, 0.4), stroke(0, 0.4, 0.45, 0), stroke(0.45, 0, 0, -0.4), stroke(0, -0.4, -0.45, 0) },
	rays = { stroke(-0.45, -0.35, 0.45, -0.35), stroke(-0.45, -0.35, 0.45, 0), stroke(-0.45, -0.35, 0.45, 0.35) },
	waves = { stroke(-0.45, 0, -0.2, 0.3), stroke(-0.2, 0.3, 0, 0), stroke(0, 0, 0.2, -0.3), stroke(0.2, -0.3, 0.45, 0) },
} :: { [string]: { Stroke } }

local upgradeOrder = { "frontWing", "haloNumber", "livery", "drs", "ventsCarbon", "gold" }
function Style.upgrades(season: number): { string }
	local result: { string } = {}
	for i = 1, math.clamp(math.floor(season), 0, 6) do table.insert(result, upgradeOrder[i]) end
	return result
end

local function part(out: { Detail }, group: string, colour: Colour, x: number, y: number, z: number,
	sx: number, sy: number, sz: number, rx: number?, ry: number?, rz: number?, cylinder: boolean?)
	table.insert(out, { x = x, y = y, z = z, sx = sx, sy = sy, sz = sz,
		rx = rx or 0, ry = ry or 0, rz = rz or 0, colour = colour, group = group, cylinder = cylinder or false })
end

-- A flat XY drawing may face the paddock, lie along the sloped nose, or face either sidepod.
local function drawing(out: { Detail }, strokes: { Stroke }, group: string, x: number, y: number, z: number,
	scaleX: number, scaleY: number, thickness: number, rx: number, ry: number)
	for _, s in strokes do
		local dx, dy = (s.x2 - s.x1) * scaleX, (s.y2 - s.y1) * scaleY
		local mx, my = (s.x1 + s.x2) * scaleX / 2, (s.y1 + s.y2) * scaleY / 2
		-- Match CFrame.Angles(rx, ry, rz): rotation about Z, then Y, then X.
		part(out, group, "secondary", x + math.cos(ry) * mx, y + math.cos(rx) * my + math.sin(rx) * math.sin(ry) * mx,
			z + math.sin(rx) * my - math.cos(rx) * math.sin(ry) * mx,
			math.sqrt(dx * dx + dy * dy), thickness, 0.035, rx, ry, math.atan2(dy, dx))
	end
end

local segments = {
	stroke(-0.28, 0.45, 0.28, 0.45), stroke(0.28, 0.42, 0.28, 0.03), stroke(0.28, -0.03, 0.28, -0.42),
	stroke(-0.28, -0.45, 0.28, -0.45), stroke(-0.28, -0.42, -0.28, -0.03), stroke(-0.28, 0.03, -0.28, 0.42),
	stroke(-0.28, 0, 0.28, 0),
}
local digits = { { 2, 3 }, { 1, 2, 7, 5, 4 }, { 1, 2, 7, 3, 4 }, { 6, 7, 2, 3 }, { 1, 6, 7, 3, 4 }, { 1, 6, 7, 5, 3, 4 } }

function Style.carParts(team: Team, season: number): { Detail }
	local out: { Detail } = {}
	local slope = math.atan2(3.6, 0.75)
	drawing(out, Style.Emblems[team.emblem], "emblem", 0, 1.3, -3.1, 0.85, 0.85, 0.07, slope, 0)
	for _, upgrade in Style.upgrades(season) do
		if upgrade == "frontWing" then
			part(out, upgrade, "carbon", 0, 0.55, -5.85, 4.8, 0.1, 0.7)
			part(out, upgrade, "primary", 0, 0.72, -5.55, 4.5, 0.1, 0.45)
			part(out, upgrade, "carbon", 0, 0.9, -5.3, 4.1, 0.1, 0.35)
			part(out, upgrade, "primary", 0, 0.62, -6.12, 4.8, 0.1, 0.3)
		elseif upgrade == "haloNumber" then
			part(out, upgrade, "carbon", 0, 2.3, -1.55, 0.95, 0.14, 0.14)
			part(out, upgrade, "carbon", 0, 1.95, -1.55, 0.14, 0.75, 0.14)
			for _, side in { -1, 1 } do
				part(out, upgrade, "carbon", side * 0.43, 2.05, -0.7, 0.13, 0.13, math.sqrt(1.7 ^ 2 + 0.5 ^ 2), math.atan2(0.5, 1.7))
			end
			local number: { Stroke } = {}
			for _, index in digits[team.number] do table.insert(number, segments[index]) end
			drawing(out, number, "number", 0, 1.0, -4.55, 1, 1, 0.075, slope, 0)
			for _, side in { -1, 1 } do
				drawing(out, number, "number", side * 1.925, 1, 1.05, 0.72, 0.72, 0.06, 0, side * math.pi / 2)
			end
		elseif upgrade == "livery" then
			for _, side in { -1, 1 } do
				part(out, upgrade, "secondary", side * 1.45, 1.44, 1.1, 0.35, 0.025, 3.1)
				part(out, upgrade, "secondary", side * 0.65, 1.715, 1.15, 0.22, 0.025, 3.7)
			end
		elseif upgrade == "drs" then
			part(out, upgrade, "carbon", 0, 3.42, 4.65, 3.5, 0.12, 0.55, -0.15)
			for _, side in { -1, 1 } do
				part(out, upgrade, "primary", side * 1.8, 2.85, 4.7, 0.12, 1.5, 1.5)
			end
			part(out, upgrade, "carbon", 0, 3.23, 4.65, 0.14, 0.36, 0.16)
			part(out, upgrade, "secondary", 0, 3.48, 4.34, 0.5, 0.12, 0.12)
		elseif upgrade == "ventsCarbon" then
			for _, side in { -1, 1 } do
				for i = 0, 2 do
					part(out, upgrade, "carbon", side * 1.45, 1.47, 1.55 + i * 0.42, 0.65, 0.06, 0.16, 0, side * 0.2)
				end
				part(out, upgrade, "carbon", side * 1.82, 0.67, 1.1, 0.12, 0.14, 3.1)
			end
		elseif upgrade == "gold" then
			for _, wheel in { { z = -3.3, diameter = 1.7, width = 1 }, { z = 3.4, diameter = 1.85, width = 1.3 } } do
				for _, side in { -1, 1 } do
					-- Entirely within the original rim discs' bounds. A smaller gold hub leaves a carbon lip.
					part(out, upgrade, "gold", side * 1.95, wheel.diameter / 2, wheel.z,
						wheel.width + 0.06, wheel.diameter * 0.46, wheel.diameter * 0.46, 0, 0, 0, true)
				end
			end
			for _, side in { -1, 1 } do
				part(out, upgrade, "gold", side * 2.34, 0.63, -5.85, 0.1, 0.06, 0.65)
				part(out, upgrade, "gold", side * 1.8, 3.63, 4.7, 0.14, 0.06, 1.5)
			end
		end
	end
	return out
end

function Style.garageParts(team: Team, piece: string): { Detail }
	local out: { Detail } = {}
	if piece == "Livery" then
		for _, side in { -1, 1 } do
			part(out, "badge", "primary", side * 18.5, 7, 24.7, 3.2, 3.2, 0.12)
			drawing(out, Style.Emblems[team.emblem], "emblem", side * 18.5, 7, 24.6, 2.7, 2.7, 0.22, 0, 0)
		end
	elseif piece == "PitWall" then
		for _, side in { -1, 1 } do
			part(out, "badge", "primary", side * 29, 0.85, -25.04, 1.8, 1.4, 0.06)
			drawing(out, Style.Emblems[team.emblem], "emblem", side * 29, 0.85, -25.1, 1.25, 1.25, 0.1, 0, 0)
		end
	elseif piece == "Awning" then
		part(out, "fascia", "primary", 0, 12.5, 17.69, 64, 1, 0.1)
		for _, x in { -25, -15, -5, 5, 15, 25 } do
			drawing(out, Style.Facades[team.facade], "pattern", x, 12.5, 17.6, 6, 0.9, 0.09, 0, 0)
		end
	end
	return out
end

local function count(parts: { Detail }): Counts
	local result: Counts = { total = #parts, groups = {} }
	for _, detail in parts do result.groups[detail.group] = (result.groups[detail.group] or 0) + 1 end
	return result
end
function Style.carCounts(team: Team, season: number): Counts
	return count(Style.carParts(team, season))
end
function Style.garageCounts(team: Team): Counts
	local result: Counts = { total = 0, groups = {} }
	for _, piece in { "Livery", "PitWall", "Awning" } do
		local n = #Style.garageParts(team, piece)
		result.groups[piece] = n
		result.total += n
	end
	return result
end

return Style
