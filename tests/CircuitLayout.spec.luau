--!strict
-- CI runs these geometry/budget checks without Roblox: luau tests/CircuitLayout.spec.luau

local Config = require("../src/shared/Config")
local TrackShape = require("../src/shared/TrackShape")
local CircuitLayout = require("../src/shared/CircuitLayout")

local failed, passed = 0, 0
local function check(name: string, ok: any, detail: any?)
	if ok then
		passed += 1
		print("PASS " .. name)
	else
		failed += 1
		print("FAIL " .. name .. (if detail ~= nil then " (" .. tostring(detail) .. ")" else ""))
	end
end

local shapes: { TrackShape.Shape } = { Config.Track, Config.LongTrack }
local plan = CircuitLayout.generate(shapes, Config.PlotCount, Config.PlotRadius, 1977)
local TAU = 2 * math.pi

-- Reconstruct Scenery.track's bend measure independently, using TrackShape, not the planner.
local function bendAt(shape: TrackShape.Shape, a: number): (number, number)
	local px, pz = TrackShape.point(shape, a - TAU / 200)
	local x, z = TrackShape.point(shape, a)
	local qx, qz = TrackShape.point(shape, a + TAU / 200)
	local ax, az, bx, bz = x - px, z - pz, qx - x, qz - z
	local lengths = math.sqrt((ax * ax + az * az) * (bx * bx + bz * bz))
	return math.acos(math.clamp((ax * bx + az * bz) / lengths, -1, 1)), ax * bz - az * bx
end

local function clearance(layout: CircuitLayout.Layout, tracks: { TrackShape.Shape }, plotRadius: number): (boolean, boolean, string)
	local roads, paddock, worst = true, true, ""
	for _, p in layout.placements do
		if math.sqrt(p.x * p.x + p.z * p.z) - p.radius < plotRadius + 40 then
			paddock, worst = false, p.kind .. " in paddock"
		end
	end
	for index, shape in tracks do
		-- Five times denser than generation; check the entire footprint against both roads.
		local samples = TrackShape.samples(shape, 4000)
		for _, p in layout.placements do
			local limit = shape.halfWidth + 6 + p.radius
			for _, q in samples do
				if (p.x - q.x) ^ 2 + (p.z - q.z) ^ 2 < limit * limit then
					roads, worst = false, p.kind .. " overlaps circuit " .. tostring(index)
					break
				end
			end
		end
	end
	return roads, paddock, worst
end

-- Check full footprints with independent, denser TrackShape samples. Landscape trees must
-- clear both tracks too, regardless of a placement's track/angle metadata. Hills are low.
local function startClearance(layout: CircuitLayout.Layout, shape: TrackShape.Shape): (number, number, string, string)
	local starts, approaches = 0, 0
	local startDetail, approachDetail = "", ""
	local x, z = TrackShape.point(shape, 0)
	local samples = TrackShape.samples(shape, 4000)
	for _, p in layout.placements do
		if p.kind == "floodlight" or p.kind == "grandstand" or p.kind == "billboard"
			or p.kind == "marshalPost" or p.kind == "treeCluster" then
			if (p.x - x) ^ 2 + (p.z - z) ^ 2 < (35 + p.radius) ^ 2 then
				starts += 1
				startDetail = p.kind .. " inside start clearance"
			end
			for _, q in samples do
				if (q.a <= 0.1 * TAU or q.a >= 0.9 * TAU)
					and (p.x - q.x) ^ 2 + (p.z - q.z) ^ 2 < (25 + p.radius) ^ 2 then
					approaches += 1
					approachDetail = p.kind .. " inside approach clearance"
					break
				end
			end
		end
	end
	return starts, approaches, startDetail, approachDetail
end

do
	for index, shape in shapes do
		local starts, approaches, startDetail, approachDetail = startClearance(plan, shape)
		check("tall footprints stay 35 studs from circuit " .. index .. " start/finish", starts == 0, startDetail)
		check("tall footprints stay 25 studs from circuit " .. index .. " first/last 10%", approaches == 0, approachDetail)
	end
end

do
	local roads, paddock, worst = clearance(plan, shapes, Config.PlotRadius)
	check("every footprint clears BOTH centrelines by halfWidth + 6", roads, worst)
	check("every footprint stays outside PlotRadius + 40", paddock, worst)
	local grass, separate = true, true
	for i, p in plan.placements do
		if p.kind ~= "hill" then
			grass = grass and math.max(math.abs(p.x), math.abs(p.z)) + p.radius <= plan.grassHalfSize
			for j = i + 1, #plan.placements do
				local q = plan.placements[j]
				if q.kind ~= "hill" and (p.x - q.x) ^ 2 + (p.z - q.z) ^ 2 < (p.radius + q.radius) ^ 2 then
					separate = false
				end
			end
		end
	end
	check("all trackside props and trees sit on the grass slab", grass)
	check("decorations do not overlap each other", separate)
	local _, outer = TrackShape.extent(Config.LongTrack)
	check("landscape uses the actual grass slab extent", math.abs(plan.grassHalfSize - (outer + 40)) < 0.0001)
end

do
	local counts: { [string]: number } = {}
	local perTrack: { { [string]: number } } = { {}, {} }
	local total, known = 0, true
	for _, p in plan.placements do
		counts[p.kind] = (counts[p.kind] or 0) + 1
		local cost = CircuitLayout.PartCost[p.kind]
		known = known and cost ~= nil and cost >= 1 and p.radius > 0
		total += cost or 0
		if p.track > 0 then
			perTrack[p.track][p.kind] = (perTrack[p.track][p.kind] or 0) + 1
		end
	end
	check("all placements have a known renderer cost and footprint", known)
	check("exposed count includes every prop, crowd and hill", total == plan.partCount, total)
	check("the whole Venue uses at most 1800 Parts", total <= 1800 and CircuitLayout.Budget == 1800, total)
	for _, kind in { "grandstand", "tyreWall", "armco", "billboard", "marshalPost", "floodlight" } do
		check("both circuits have " .. kind, (perTrack[1][kind] or 0) > 0 and (perTrack[2][kind] or 0) > 0)
	end
	check("four grandstands and twelve towers are planned", counts.grandstand == 4 and counts.floodlight == 12)
	check("landscaping includes twenty-two tree clusters and all sixty hills", counts.treeCluster == 22 and counts.hill == 60)
end

do
	local bends, outside, attached = true, true, true
	local straights, sustained, facing, nearby = true, true, true, true
	for _, p in plan.placements do
		if p.kind == "tyreWall" or p.kind == "grandstand" then
			local shape = shapes[p.track]
			local bend, turn = bendAt(shape, p.angle)
			local x, z = TrackShape.point(shape, p.angle)
			local tx, tz = TrackShape.tangent(shape, p.angle)
			local dx, dz = p.x - x, p.z - z
			attached = attached and math.abs(p.bend - bend) < 0.000001 and math.abs(dx * tx + dz * tz) < 0.000001
			if p.kind == "tyreWall" then
				bends = bends and bend > 0.07
				outside = outside and (dx * tz - dz * tx) * turn > 0 and p.side == (if turn > 0 then 1 else -1)
			else
				straights = straights and bend < 0.025
				local before = bendAt(shape, p.angle - 0.06)
				local after = bendAt(shape, p.angle + 0.06)
				sustained = sustained and bend + before + after < 0.09
				local distance = math.sqrt(dx * dx + dz * dz)
				-- A Roblox yaw's local -Z is (-sin(yaw), -cos(yaw)) in the ground plane.
				facing = facing and (math.sin(p.yaw) * dx + math.cos(p.yaw) * dz) / distance > 0.9999
				local _, nearest = TrackShape.nearest(shape, p.x, p.z)
				nearby = nearby and math.abs(nearest) <= 70
			end
		end
	end
	check("tyre walls only mark bends using the existing 0.07 threshold", bends)
	check("tyre walls are on the outside of the turn, including concave bends", outside)
	check("trackside bend metadata and normal offsets match TrackShape", attached)
	check("grandstands sit beside the main straights", straights)
	check("the grandstand straight extends beyond a single inflection point", sustained)
	check("grandstand fronts face their circuit", facing)
	check("grandstands are close enough to watch the race", nearby)
end

local function same(a: CircuitLayout.Layout, b: CircuitLayout.Layout): boolean
	if a.partCount ~= b.partCount or a.grassHalfSize ~= b.grassHalfSize or #a.placements ~= #b.placements then
		return false
	end
	for i, p in a.placements do
		local q = b.placements[i]
		for key, value in p :: any do
			if (q :: any)[key] ~= value then return false end
		end
		for key, value in q :: any do
			if (p :: any)[key] ~= value then return false end
		end
	end
	return true
end

do
	local other = CircuitLayout.generate(shapes, Config.PlotCount, Config.PlotRadius, 42)
	local repeated = CircuitLayout.generate(shapes, Config.PlotCount, Config.PlotRadius, 1977)
	local default = CircuitLayout.generate(shapes, Config.PlotCount, Config.PlotRadius)
	check("same seed reproduces every field and placement order after another build", same(plan, repeated))
	check("the default seed also reproduces the plan", same(plan, default))
	check("different seeds change the landscaping", not same(plan, other))
	local trees: { CircuitLayout.Placement } = {}
	for _, p in plan.placements do
		if p.kind == "treeCluster" then table.insert(trees, p) end
	end
	local varied, grid = false, false
	for i = 2, #trees do
		varied = varied or math.abs(trees[i].scale - trees[1].scale) > 0.1
		for j = 1, i - 1 do
			grid = grid or math.abs(trees[i].x - trees[j].x) < 0.001 or math.abs(trees[i].z - trees[j].z) < 0.001
		end
	end
	check("tree cluster centres have no shared grid rows or columns", not grid)
	check("tree clusters vary in size", varied)
end

do
	local safe, budget, allHills = true, true, true
	local startsClear, approachesClear = true, true
	for _, seed in { 1, 42, 2026, 2147483646 } do
		local alternate = CircuitLayout.generate(shapes, Config.PlotCount, Config.PlotRadius, seed)
		local roads, paddock = clearance(alternate, shapes, Config.PlotRadius)
		safe = safe and roads and paddock
		for _, shape in shapes do
			local starts, approaches = startClearance(alternate, shape)
			startsClear = startsClear and starts == 0
			approachesClear = approachesClear and approaches == 0
		end
		budget = budget and alternate.partCount <= 1800
		local hills = 0
		for _, p in alternate.placements do
			if p.kind == "hill" then hills += 1 end
		end
		allHills = allHills and hills == 60
	end
	check("clearance holds across four additional seeds", safe)
	check("start circles stay clear across four additional seeds", startsClear)
	check("start approaches stay clear across four additional seeds", approachesClear)
	check("the budget holds across four additional seeds", budget)
	check("every seed covers all four slab edges with hills", allHills)
	local wider: { TrackShape.Shape } = {
		{ radius = Config.Track.radius, waves = Config.Track.waves, halfWidth = 12 },
		{ radius = Config.LongTrack.radius, waves = Config.LongTrack.waves, halfWidth = 15 },
	}
	local alternate = CircuitLayout.generate(wider, 12, 110, 2026)
	local roads, paddock = clearance(alternate, wider, 110)
	check("wider roads and a larger plot ring also preserve clearance", roads and paddock)
	check("a changed plot ring and road widths preserve the budget", alternate.partCount <= 1800)
	startsClear, approachesClear = true, true
	for _, shape in wider do
		local starts, approaches = startClearance(alternate, shape)
		startsClear = startsClear and starts == 0
		approachesClear = approachesClear and approaches == 0
	end
	check("wider roads and a larger plot ring keep start circles clear", startsClear)
	check("wider roads and a larger plot ring keep start approaches clear", approachesClear)
end

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then
	error("circuit layout tests failed")
end
