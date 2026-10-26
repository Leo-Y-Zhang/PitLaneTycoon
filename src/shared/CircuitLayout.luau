--!strict
-- A deterministic, CFrame-free venue plan. Footprint discs include every overhang, not just
-- the prop's origin. No services, globals or environment-dependent requires are needed.

local CircuitLayout = {}

export type Shape = { radius: number, waves: { { number } }, halfWidth: number }
export type Placement = {
	kind: string,
	x: number,
	z: number,
	yaw: number, -- radians about Y; local -Z faces the track
	radius: number, -- conservative horizontal footprint, including flags/canopies
	scale: number,
	variant: number,
	track: number, -- 1 or 2 for trackside props; 0 for landscape
	angle: number,
	bend: number,
	side: number, -- +1 is right of travel, -1 is left
}
export type Layout = { placements: { Placement }, partCount: number, grassHalfSize: number }
type Point = { x: number, z: number }
type Candidate = { angle: number, bend: number, turn: number, score: number }

local TAU = 2 * math.pi
CircuitLayout.Budget = 1800
CircuitLayout.SampleCount = 800
CircuitLayout.BendThreshold = 0.07
CircuitLayout.StraightThreshold = 0.025

-- These are exact renderer costs, including crowds, flags and hills. Circuit.build checks
-- each completed prop against this contract so renderer changes cannot silently exceed it.
CircuitLayout.PartCost = table.freeze({
	grandstand = 106,
	treeCluster = 16,
	tyreWall = 16,
	armco = 5,
	billboard = 7,
	marshalPost = 9,
	floodlight = 18,
	hill = 1,
} :: { [string]: number })

local footprints: { [string]: number } = {
	grandstand = 27, treeCluster = 18, tyreWall = 8.5, armco = 10,
	billboard = 13, marshalPost = 7, floodlight = 7, hill = 68,
}

-- The same polar equation as TrackShape.point, kept local so this module also runs in the
-- plain Luau CLI. The specs check the plan against TrackShape's independent geometry.
local function point(shape: Shape, a: number): (number, number)
	local r = shape.radius
	for _, w in shape.waves do
		r += w[1] * math.sin(w[2] * a + w[3])
	end
	return r * math.cos(a), r * math.sin(a)
end

local function tangent(shape: Shape, a: number): (number, number)
	local x1, z1 = point(shape, a - 0.001)
	local x2, z2 = point(shape, a + 0.001)
	local length = math.sqrt((x2 - x1) ^ 2 + (z2 - z1) ^ 2)
	return (x2 - x1) / length, (z2 - z1) / length
end

local function bendAt(shape: Shape, a: number): (number, number)
	-- Exactly Scenery.track's heading change, at its 200-segment resolution. The signed
	-- cross product tells us which side is outside, including concave bends in these loops.
	local step = TAU / 200
	local px, pz = point(shape, a - step)
	local x, z = point(shape, a)
	local qx, qz = point(shape, a + step)
	local ax, az, bx, bz = x - px, z - pz, qx - x, qz - z
	local length = math.sqrt((ax * ax + az * az) * (bx * bx + bz * bz))
	return math.acos(math.clamp((ax * bx + az * bz) / length, -1, 1)), ax * bz - az * bx
end

local function segmentDistance2(x: number, z: number, a: Point, b: Point): number
	local dx, dz = b.x - a.x, b.z - a.z
	local t = math.clamp(((x - a.x) * dx + (z - a.z) * dz) / (dx * dx + dz * dz), 0, 1)
	return (x - a.x - t * dx) ^ 2 + (z - a.z - t * dz) ^ 2
end

function CircuitLayout.generate(shapes: { Shape }, plotCount: number, plotRadius: number, seed: number?): Layout
	assert(#shapes == 2, "the venue needs both circuits")
	assert(plotCount >= 1 and plotRadius >= 0, "invalid plot ring")
	local state = math.floor(seed or 1977) % 2147483647
	if state <= 0 then
		state = 1
	end
	local function random(): number
		-- Park-Miller: products fit in a double's integer precision; never touches math.random.
		state = state * 48271 % 2147483647
		return state / 2147483647
	end

	local lines: { { Point } } = {}
	local outer = 0
	for _, shape in shapes do
		local samples: { Point } = {}
		for i = 0, CircuitLayout.SampleCount - 1 do
			local x, z = point(shape, i / CircuitLayout.SampleCount * TAU)
			table.insert(samples, { x = x, z = z })
		end
		table.insert(lines, samples)
		-- Match the grass extent used by Racing.start/TrackShape.extent.
		for i = 0, 1999 do
			local x, z = point(shape, i / 2000 * TAU)
			outer = math.max(outer, math.sqrt(x * x + z * z) + shape.halfWidth)
		end
	end
	local layout: Layout = { placements = {}, partCount = 0, grassHalfSize = outer + 40 }

	local function add(p: Placement): boolean
		local cost = CircuitLayout.PartCost[p.kind]
		if layout.partCount + cost > CircuitLayout.Budget then
			return false
		end
		if math.sqrt(p.x * p.x + p.z * p.z) < plotRadius + 40 + p.radius + 1 then
			return false
		end
		if p.kind ~= "hill" and math.max(math.abs(p.x), math.abs(p.z)) + p.radius > layout.grassHalfSize - 3 then
			return false
		end
		local tall = p.kind == "grandstand" or p.kind == "treeCluster" or p.kind == "billboard"
			or p.kind == "marshalPost" or p.kind == "floodlight"
		for index, line in lines do
			-- Keep the full footprint out of both start areas, including landscape trees.
			local start = line[1]
			if tall and (p.x - start.x) ^ 2 + (p.z - start.z) ^ 2 < (35 + p.radius) ^ 2 then
				return false
			end
			-- A stud of extra margin covers the tiny error between chords and the true curve.
			local clearance = shapes[index].halfWidth + 6 + p.radius + 1
			for i, a in line do
				-- Segment i starts at (i - 1) / #line; include both ends of the lap.
				local approach = i <= #line * 0.1 or i > #line * 0.9
				local limit = if tall and approach then math.max(clearance, 25 + p.radius + 1) else clearance
				if segmentDistance2(p.x, p.z, a, line[i % #line + 1]) < limit * limit then
					return false
				end
			end
		end
		if p.kind ~= "hill" then
			for _, other in layout.placements do
				if (p.x - other.x) ^ 2 + (p.z - other.z) ^ 2 < (p.radius + other.radius + 3) ^ 2 then
					return false
				end
			end
		end
		table.insert(layout.placements, p)
		layout.partCount += cost
		return true
	end

	local function placement(kind: string, x: number, z: number, yaw: number, scale: number): Placement
		return {
			kind = kind, x = x, z = z, yaw = yaw, radius = footprints[kind] * scale,
			scale = scale, variant = math.floor(random() * 100000), track = 0, angle = 0, bend = 0, side = 0,
		}
	end

	local function trackside(kind: string, index: number, a: number, side: number): boolean
		local shape = shapes[index]
		local x, z = point(shape, a)
		local tx, tz = tangent(shape, a)
		local bend = bendAt(shape, a)
		for extra = 0, 16, 8 do
			local offset = shape.halfWidth + 6 + footprints[kind] + 4 + extra
			local px, pz = x + tz * side * offset, z - tx * side * offset
			local p = placement(kind, px, pz, math.atan2(px - x, pz - z), 1)
			p.track, p.angle, p.bend, p.side = index, a, bend, side
			if add(p) then
				return true
			end
		end
		return false
	end

	-- Reserve the best viewing areas first, using the straightest sustained stretches rather
	-- than a single inflection point. Disjoint footprints separate stands along the straight.
	for index, shape in shapes do
		local candidates: { Candidate } = {}
		for i = 0, 199 do
			local a = i / 200 * TAU
			local bend, turn = bendAt(shape, a)
			local before = bendAt(shape, a - 0.06)
			local after = bendAt(shape, a + 0.06)
			table.insert(candidates, { angle = a, bend = bend, turn = turn, score = bend + before + after })
		end
		table.sort(candidates, function(a: Candidate, b: Candidate)
			return if a.score == b.score then a.angle < b.angle else a.score < b.score
		end)
		local stands = 0
		for _, c in candidates do
			if stands >= 2 then break end
			if c.bend < CircuitLayout.StraightThreshold and c.score < 0.09 then
				for _, side in { 1, -1 } do
					if trackside("grandstand", index, c.angle, side) then
						stands += 1
						break
					end
				end
			end
		end
	end

	for index, shape in shapes do
		local bends: { Candidate } = {}
		for i = 0, 199 do
			local a = i / 200 * TAU
			local bend, turn = bendAt(shape, a)
			if bend > CircuitLayout.BendThreshold then
				table.insert(bends, { angle = a, bend = bend, turn = turn, score = bend })
			end
		end
		table.sort(bends, function(a: Candidate, b: Candidate)
			return if a.bend == b.bend then a.angle < b.angle else a.bend > b.bend
		end)
		local walls = 0
		for _, c in bends do
			if walls >= 8 then break end
			if trackside("tyreWall", index, c.angle, if c.turn > 0 then 1 else -1) then
				walls += 1
			end
		end
	end

	-- Try sectors around each circuit, filling gaps without overlapping the reserved props.
	local amenities = {
		{ kind = "armco", count = 12 }, { kind = "billboard", count = 5 },
		{ kind = "marshalPost", count = 4 }, { kind = "floodlight", count = 6 },
	}
	for _, amenity in amenities do
		for index, shape in shapes do
			local placed = 0
			for i = 0, 199 do
				if placed >= amenity.count then break end
				-- Coprime stride spreads successful placements around the whole loop.
				local a = ((i * 37 + index * 11 + plotCount) % 200) / 200 * TAU
				local bend = bendAt(shape, a)
				if amenity.kind ~= "armco" or bend <= CircuitLayout.BendThreshold then
					for _, side in { 1, -1 } do
						if trackside(amenity.kind, index, a, side) then
							placed += 1
							break
						end
					end
				end
			end
		end
	end

	local clusters = 0
	for _ = 1, 1200 do
		if clusters >= 22 then break end
		local x = (random() * 2 - 1) * (layout.grassHalfSize - 20)
		local z = (random() * 2 - 1) * (layout.grassHalfSize - 20)
		local p = placement("treeCluster", x, z, random() * TAU, 0.8 + random() * 0.35)
		if add(p) then
			clusters += 1
		end
	end

	-- Overlapping, tilted grass blocks skirt all four sides of the square grass slab. Their
	-- bottoms dip below the slab and their inner slopes cover its edge, including the corners.
	local half = layout.grassHalfSize
	local steps = math.ceil(2 * half / 58)
	for side = 0, 3 do
		local a = side * math.pi / 2
		for i = 0, steps do
			local along = -half + i / steps * 2 * half
			local outward = half + 40
			local x = along * math.cos(a) + outward * math.sin(a)
			local z = -along * math.sin(a) + outward * math.cos(a)
			add(placement("hill", x, z, a, 1))
		end
	end
	return layout
end

return CircuitLayout
