--!strict
-- Pure placement data. Radii enclose the whole prop, including roofs, feet and flags.
local PaddockLayout = {}

export type Kind = "tent" | "flag" | "tyres" | "fuel" | "barrier" | "planter" | "tower"
export type Placement = { x: number, z: number, yaw: number, kind: Kind }
export type PropSpec = { radius: number, parts: number }

PaddockLayout.PartBudget = 700
PaddockLayout.Specs = {
	tent = { radius = 8.2, parts = 22 },
	flag = { radius = 3, parts = 6 },
	tyres = { radius = 2.6, parts = 17 },
	fuel = { radius = 3, parts = 15 },
	barrier = { radius = 3.3, parts = 11 },
	planter = { radius = 2.2, parts = 5 },
	tower = { radius = 3.2, parts = 11 },
} :: { [string]: PropSpec }

function PaddockLayout.generate(plotCount: number, plotRadius: number, frontGap: number): { Placement }
	local result: { Placement } = {}
	if plotCount < 2 or plotCount % 1 ~= 0 or plotRadius <= 0 or frontGap < 0 then
		return result
	end
	local edge = plotRadius - frontGap
	local usedParts = 0
	local function add(kind: Kind, angle: number, radial: number, tangent: number): boolean
		local spec = PaddockLayout.Specs[kind]
		local c, s = math.cos(angle), math.sin(angle)
		local x, z = c * radial + s * tangent, s * radial - c * tangent
		local distance = math.sqrt(x * x + z * z)
		if distance - spec.radius < 18 or distance + spec.radius > edge
			or usedParts + spec.parts > PaddockLayout.PartBudget then
			return false
		end
		for i = 0, plotCount - 1 do
			local a = i / plotCount * math.pi * 2
			local dx, dz = math.cos(a), math.sin(a)
			-- Distance to the outward lane ray, also protecting the approach to its end.
			local along = math.max(0, x * dx + z * dz)
			local lx, lz = x - dx * along, z - dz * along
			if math.sqrt(lx * lx + lz * lz) - spec.radius < 9 then
				return false
			end
			local px, pz = x - dx * plotRadius, z - dz * plotRadius
			if math.sqrt(px * px + pz * pz) - spec.radius < 30 then
				return false
			end
		end
		for _, other in result do
			local dx, dz = x - other.x, z - other.z
			if math.sqrt(dx * dx + dz * dz) < spec.radius + PaddockLayout.Specs[other.kind].radius + 0.5 then
				return false
			end
		end
		table.insert(result, { x = x, z = z, yaw = math.pi / 2 - angle, kind = kind })
		usedParts += spec.parts
		return true
	end

	-- Four to six towers, spread over the wedges. Search outwards if a wedge is narrow.
	local towerCount = math.clamp(plotCount, 4, 6)
	for i = 0, towerCount - 1 do
		local wedge = math.floor(i * plotCount / towerCount)
		local fraction = if plotCount < 4 then (if i % 2 == 0 then 0.35 else 0.65) else 0.5
		local a = (wedge + fraction) / plotCount * math.pi * 2
		for radial = 29, math.min(60, edge - PaddockLayout.Specs.tower.radius), 2 do
			if add("tower", a, radial, 0) then
				break
			end
		end
	end

	-- Add each layer to all wedges before the next: a tight budget still dresses every team.
	local templates: { { kind: Kind, radial: number, tangent: number } } = {
		{ kind = "tent", radial = 50, tangent = 0 },
		{ kind = "flag", radial = 58, tangent = -14 },
		{ kind = "tyres", radial = 41, tangent = -9 },
		{ kind = "fuel", radial = 41, tangent = 9 },
		{ kind = "barrier", radial = 35, tangent = -5 },
		{ kind = "barrier", radial = 35, tangent = 5 },
		{ kind = "planter", radial = 59.5, tangent = -6 },
		{ kind = "planter", radial = 59.5, tangent = 6 },
		{ kind = "planter", radial = 59.5, tangent = 0 },
	}
	local scale = math.min(1.4, edge / 64)
	for _, template in templates do
		for wedge = 0, plotCount - 1 do
			local a = (wedge + 0.5) / plotCount * math.pi * 2
			add(template.kind, a, template.radial * scale, template.tangent * scale)
		end
	end
	return result
end

return PaddockLayout
