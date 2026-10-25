-- Tests for garage likes (src/server/Likes.luau). CI runs them with the Luau command line:
--     luau tests/Likes.spec.luau

local Likes = require("../src/server/Likes")

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

local today = Likes.day(1793000000)
local likedOn = {}
check("a player can't like their own garage", not Likes.can(7, 7, likedOn, today))
check("but can like another team's", Likes.can(7, 9, likedOn, today))
Likes.record(9, likedOn, today)
check("once a day", not Likes.can(7, 9, likedOn, today))
check("other garages still can be liked that day", Likes.can(7, 11, likedOn, today))
check("and the same garage again the next day", Likes.can(7, 9, likedOn, today + 1))
Likes.record(11, likedOn, today + 1)
check("old days are dropped from the record", likedOn["9"] == nil and likedOn["11"] == today + 1)
check("a day is a UTC calendar day", Likes.day(86400 * 3 + 5) == 3 and Likes.day(86400 * 3 - 1) == 2)

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then
	error("likes tests failed")
end
