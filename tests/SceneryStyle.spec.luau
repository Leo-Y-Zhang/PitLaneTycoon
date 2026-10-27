--!strict
-- Pure visual recipes: the renderer consumes exactly these part descriptors.
local Style = require("../src/shared/SceneryStyle")

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

local expected = { "frontWing", "haloNumber", "livery", "drs", "ventsCarbon", "gold" }
for season = 0, 6 do
	local upgrades = Style.upgrades(season)
	local ordered = #upgrades == season
	for i, id in upgrades do ordered = ordered and id == expected[i] end
	check("season " .. season .. " has exactly its cumulative upgrades", ordered)
end
check("negative seasons have no upgrades", #Style.upgrades(-4) == 0)
check("fractional seasons round down", #Style.upgrades(2.9) == 2)
check("upgrades cap at six", #Style.upgrades(600) == 6)
check("there are six teams", #Style.Teams == 6)

local emblems: { [string]: boolean } = {}
local facades: { [string]: boolean } = {}
local numbers: { [number]: boolean } = {}
local expectedEmblems = { 2, 5, 3, 5, 6, 8 }
local expectedNumbers = { 2, 5, 5, 4, 5, 6 }
local expectedGarage = { 25, 49, 35, 49, 47, 61 }
local garagePieces = { "Floor", "BackWall", "SideWalls", "Livery", "Awning", "Lights", "PitWall", "Kit", "UpperDeck" }
for index, team in Style.Teams do
	local label = "team " .. index
	local primary = { team.primary.r, team.primary.g, team.primary.b }
	local secondary = { team.secondary.r, team.secondary.g, team.secondary.b }
	local validPalette = false
	for i, channel in primary do validPalette = validPalette or channel ~= secondary[i] end
	for _, rgb in { primary, secondary } do
		for _, channel in rgb do validPalette = validPalette and channel >= 0 and channel <= 255 and channel % 1 == 0 end
	end
	check(label .. " has a distinct valid second colour", validPalette)
	check(label .. " has a unique emblem, facade and number",
		not emblems[team.emblem] and not facades[team.facade] and not numbers[team.number])
	emblems[team.emblem], facades[team.facade], numbers[team.number] = true, true, true
	check(label .. " emblem is made of the expected strokes", #Style.Emblems[team.emblem] == expectedEmblems[index])
	local previous: { Style.Detail } = {}
	for season = 0, 6 do
		local parts = Style.carParts(team, season)
		local counts = Style.carCounts(team, season)
		local numberParts = if season >= 2 then expectedNumbers[index] * 3 else 0
		local expectedCount = expectedEmblems[index] + numberParts
		for stage = 1, season do expectedCount += ({ 4, 4, 4, 5, 8, 8 })[stage] end
		check(label .. " season " .. season .. " part sums match the recipe",
			counts.total == #parts and counts.total == expectedCount and counts.total <= Style.CarPartBudget and counts.total <= 60, counts.total)
		local cumulative = true
		for i, old in previous do
			local current = parts[i]
			cumulative = cumulative and current.x == old.x and current.y == old.y and current.z == old.z
				and current.sx == old.sx and current.sy == old.sy and current.sz == old.sz
				and current.rx == old.rx and current.ry == old.ry and current.rz == old.rz
				and current.colour == old.colour and current.group == old.group and current.cylinder == old.cylinder
		end
		check(label .. " season " .. season .. " retains every earlier detail", cumulative)
		local safe, inside, roles = true, true, {} :: { [string]: number }
		for _, part in parts do
			safe = safe and part.sx > 0 and part.sy > 0 and part.sz > 0
			-- Conservative oriented-box X/Z bounds, independent of the generator.
			local cx, sx = math.cos(part.rx), math.sin(part.rx)
			local cy, sy = math.cos(part.ry), math.sin(part.ry)
			local cz, sz = math.cos(part.rz), math.sin(part.rz)
			local halfX = (math.abs(cy * cz) * part.sx + math.abs(cy * sz) * part.sy + math.abs(sy) * part.sz) / 2
			local halfZ = (math.abs(sx * sz - cx * sy * cz) * part.sx
				+ math.abs(sx * cz + cx * sy * sz) * part.sy + math.abs(cx * cy) * part.sz) / 2
			inside = inside and math.abs(part.x) + halfX <= 2.63 + 0.00001
				and part.z - halfZ >= -6.35 - 0.00001 and part.z + halfZ <= 5.75 + 0.00001
			roles[part.group] = (roles[part.group] or 0) + 1
		end
		check(label .. " season " .. season .. " has positive dimensions within the original footprint", safe and inside)
		check(label .. " season " .. season .. " race number appears on nose and both sidepods",
			(roles.number or 0) == numberParts)
		local sums = 0
		for group, count in counts.groups do sums += count; safe = safe and roles[group] == count end
		check(label .. " season " .. season .. " group counts sum to the total", safe and sums == counts.total)
		previous = parts
	end
	check(label .. " car geometry caps at six", #Style.carParts(team, 99) == #previous)
	local goldBefore, goldAtSix, stripes = 0, 0, 0
	for _, detail in Style.carParts(team, 5) do
		goldBefore += if detail.colour == "gold" then 1 else 0
		stripes += if detail.group == "livery" and detail.colour == "secondary" then 1 else 0
	end
	for _, detail in Style.carParts(team, 6) do goldAtSix += if detail.colour == "gold" then 1 else 0 end
	check(label .. " gold accents appear only at six", goldBefore == 0 and goldAtSix == 8)
	check(label .. " livery keeps four stripes in the second colour", stripes == 4)
	local counts = Style.garageCounts(team)
	local total, facade, pit = 0, false, false
	for _, piece in garagePieces do
		local parts = Style.garageParts(team, piece)
		check(label .. " " .. piece .. " count matches its recipe", #parts == (counts.groups[piece] or 0))
		total += #parts
		for _, part in parts do
			facade = facade or (piece == "Livery" and part.group == "emblem")
			pit = pit or (piece == "PitWall" and part.group == "emblem")
		end
	end
	check(label .. " has facade and pit-wall emblems", facade and pit)
	check(label .. " has a team-specific facade pattern", #Style.garageParts(team, "Awning") >= 4)
	check(label .. " garage sums fit the budget", total == counts.total and total == expectedGarage[index] and total <= Style.GaragePartBudget and total <= 80, total)
	check(label .. " unrecognised garage pieces add nothing", #Style.garageParts(team, "unknown") == 0)
	print(("COUNTS team %d car seasons 0..6: %s; garage +%d"):format(index,
		table.concat((function(): { string }
			local result: { string } = {}
			for season = 0, 6 do table.insert(result, tostring(Style.carCounts(team, season).total)) end
			return result
		end)(), ", "), total))
end

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then error("scenery style tests failed") end
