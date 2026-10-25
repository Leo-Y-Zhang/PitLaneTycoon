-- Tests for the garage that builds itself (src/server/GaragePlan.luau, Config.GaragePieces).
-- CI runs them with the Luau command line: luau tests/Garage.spec.luau

local Config = require("../src/shared/Config")
local GaragePlan = require("../src/server/GaragePlan")

local pieces = Config.GaragePieces
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

local function count(set: { [string]: boolean }): number
	local n = 0
	for _, v in set do
		n += v and 1 or 0
	end
	return n
end

do
	local up = GaragePlan.built(pieces, 0, 0)
	local site = GaragePlan.site(pieces, up)
	check("an empty plot has no garage yet", count(up) == 0, count(up))
	check("and is a building site: every prop standing", count(site) == #GaragePlan.SiteProps, count(site))
end

do
	local up = GaragePlan.built(pieces, 1, 0)
	local site = GaragePlan.site(pieces, up)
	check("the first purchase lays the floor", up.Floor == true)
	check("and clears the cones", site.Cones == false and site.Scaffold == true)
end

do
	local ordered, last = true, 0
	for _, piece in pieces do
		ordered = ordered and piece.at > last
		last = piece.at
	end
	check("pieces go up one purchase-step at a time, in order", ordered)
	-- season 1's purchases: every item that appears in it except the free first press; the
	-- trophy is the last of them
	local purchases = -1
	for _, item in Config.Items do
		if (item.season or 0) == 0 then
			purchases += 1
		end
	end
	check("the whole garage is up before the trophy", last <= purchases - 1, ("last piece at %d of %d"):format(last, purchases))
	local grows = true
	for p = 1, purchases do
		grows = grows and count(GaragePlan.built(pieces, p, 0)) >= count(GaragePlan.built(pieces, p - 1, 0))
	end
	check("a purchase never takes a piece down", grows)
end

do
	local known = {}
	for _, name in GaragePlan.SiteProps do
		known[name] = true
	end
	local ok, cleared = true, {}
	for _, piece in pieces do
		if piece.clears then
			ok = ok and known[piece.clears] == true and not cleared[piece.clears]
			cleared[piece.clears] = true
		end
	end
	check("each site prop is cleared by exactly one piece", ok and count(cleared) == #GaragePlan.SiteProps)
	local done = GaragePlan.site(pieces, GaragePlan.built(pieces, 99, 0))
	check("a finished garage has no building site left", count(done) == 0, count(done))
end

do
	local up = GaragePlan.built(pieces, 0, 1)
	local keptAll, extrasDown = true, true
	for _, piece in pieces do
		if piece.keep then
			keptAll = keptAll and up[piece.name]
		else
			extrasDown = extrasDown and not up[piece.name]
		end
	end
	check("a new season starts in the finished shell", keptAll)
	check("and builds the extras again", extrasDown)
	local again = nil
	for p = 1, 20 do
		local piece = GaragePlan.newPiece(pieces, p, 1)
		if piece and piece.keep then
			again = piece.name
		end
	end
	check("without announcing the shell again", again == nil, again)
	local first = GaragePlan.newPiece(pieces, 1, 0)
	check("the first purchase announces the floor", first and first.name == "Floor", first and first.name)
end

do
	local from = Config.NightGarageSeason
	check("the garage keeps its day look before the night season", GaragePlan.theme(from - 1, from) == "day")
	check("and takes the night look from it on", GaragePlan.theme(from, from) == "night" and GaragePlan.theme(from + 3, from) == "night")
	check("the night look comes in a later season, not the first", from >= 1, from)
end

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then
	error("garage tests failed")
end
