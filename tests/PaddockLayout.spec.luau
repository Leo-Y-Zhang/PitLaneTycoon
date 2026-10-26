--!strict
-- CI runs these pure placement tests with: luau tests/PaddockLayout.spec.luau
local PaddockLayout = require("../src/shared/PaddockLayout")
local Config = require("../src/shared/Config")

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

local tau = math.pi * 2
local epsilon = 0.000001
local cases = {
	{ count = Config.PlotCount, radius = Config.PlotRadius, gap = 26 },
	{ count = 2, radius = 90, gap = 26 },
	{ count = 3, radius = 90, gap = 26 },
	{ count = 4, radius = 90, gap = 26 },
	{ count = 5, radius = 90, gap = 26 },
	{ count = 8, radius = 90, gap = 26 },
	{ count = 6, radius = 76, gap = 18 },
	{ count = 8, radius = 120, gap = 32 },
	{ count = 10, radius = 110, gap = 30 },
	{ count = 12, radius = 120, gap = 26 },
}

for _, case in cases do
	local props = PaddockLayout.generate(case.count, case.radius, case.gap)
	local again = PaddockLayout.generate(case.count, case.radius, case.gap)
	local laneClear, spawnClear, plotClear, onAsphalt, separated, deterministic = true, true, true, true, true, #props == #again
	local parts, towers = 0, 0
	local wedges: { [number]: number } = {}
	for i, prop in props do
		local radius = PaddockLayout.Specs[prop.kind].radius
		parts += PaddockLayout.Specs[prop.kind].parts
		towers += if prop.kind == "tower" then 1 else 0
		local distance = math.sqrt(prop.x ^ 2 + prop.z ^ 2)
		spawnClear = spawnClear and distance - radius >= 18 - epsilon
		onAsphalt = onAsphalt and distance + radius <= case.radius - case.gap + epsilon
		local wedge = math.floor((math.atan2(prop.z, prop.x) % tau) / tau * case.count)
		wedges[wedge] = (wedges[wedge] or 0) + 1
		for lane = 0, case.count - 1 do
			local a = lane / case.count * tau
			local dx, dz = math.cos(a), math.sin(a)
			-- Independently measure the actual painted lane segment (17 to the plot front).
			local along = math.clamp(prop.x * dx + prop.z * dz, 17, case.radius - case.gap)
			local lx, lz = prop.x - dx * along, prop.z - dz * along
			laneClear = laneClear and math.sqrt(lx ^ 2 + lz ^ 2) - radius >= 9 - epsilon
			local px, pz = prop.x - dx * case.radius, prop.z - dz * case.radius
			plotClear = plotClear and math.sqrt(px ^ 2 + pz ^ 2) - radius >= 30 - epsilon
		end
		for j = 1, i - 1 do
			local other = props[j]
			local dx, dz = prop.x - other.x, prop.z - other.z
			separated = separated and math.sqrt(dx ^ 2 + dz ^ 2) >= radius + PaddockLayout.Specs[other.kind].radius - epsilon
		end
		local repeatProp = again[i]
		deterministic = deterministic and repeatProp ~= nil and prop.x == repeatProp.x and prop.z == repeatProp.z
			and prop.yaw == repeatProp.yaw and prop.kind == repeatProp.kind
	end
	local covered = true
	for wedge = 0, case.count - 1 do
		covered = covered and (wedges[wedge] or 0) > 0
	end
	local label = (" (%d plots, radius %d, gap %d)"):format(case.count, case.radius, case.gap)
	check("whole props clear every lane by 9 studs" .. label, laneClear)
	check("whole props clear the spawn by 18 studs" .. label, spawnClear)
	check("whole props clear every plot centre by 30 studs" .. label, plotClear)
	check("props stay on the inner paddock asphalt" .. label, onAsphalt)
	check("props do not intersect one another" .. label, separated)
	check("every wedge receives props" .. label, covered)
	check("four to six towers surround the spawn" .. label, towers >= 4 and towers <= 6, towers)
	check("prop part allowances fit the 700-part budget" .. label, #props > 0 and parts <= 700, parts)
	check("placement and order are deterministic" .. label, deterministic)
end

do -- The shipped layout gets a complete paddock scene in each team's wedge.
	local props = PaddockLayout.generate(Config.PlotCount, Config.PlotRadius, 26)
	local kindsByWedge: { [number]: { [string]: number } } = {}
	local parts = 0
	for _, prop in props do
		local wedge = math.floor((math.atan2(prop.z, prop.x) % tau) / tau * Config.PlotCount)
		local kinds: { [string]: number } = kindsByWedge[wedge] or {}
		kindsByWedge[wedge] = kinds
		kinds[prop.kind] = (kinds[prop.kind] or 0) + 1
		parts += PaddockLayout.Specs[prop.kind].parts
	end
	for wedge = 0, Config.PlotCount - 1 do
		local kinds: { [string]: number } = kindsByWedge[wedge] or {}
		local complete = true
		for kind in PaddockLayout.Specs do
			complete = complete and (kinds[kind] or 0) > 0
		end
		check("the shipped wedge has every prop kind " .. wedge, complete)
		check("the shipped wedge has paired barriers and planters " .. wedge,
			kinds.barrier == 2 and kinds.planter == 2)
	end
	check("the shipped paddock has 54 props using 618 Parts", #props == 54 and parts == 618, parts)
	-- A fresh call must not share mutable placement records with an earlier call.
	local firstX = props[1].x
	props[1].x = 10000
	check("calls return independent records", PaddockLayout.generate(Config.PlotCount, Config.PlotRadius, 26)[1].x == firstX)
	check("a changed front gap changes the usable layout", #PaddockLayout.generate(Config.PlotCount, Config.PlotRadius, 44) < #props)
end

check("no plots produce no props", #PaddockLayout.generate(0, 90, 26) == 0)
check("an impossible paddock produces no props", #PaddockLayout.generate(6, 25, 26) == 0)
check("fractional plot counts produce no props", #PaddockLayout.generate(6.5, 90, 26) == 0)

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then
	error("paddock layout tests failed")
end
