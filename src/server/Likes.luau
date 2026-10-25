--!strict
-- Garage likes: a player may like another team's garage once a day, never their own. Pure
-- Luau, so tests/Likes.spec.luau checks the rules in CI.

local Likes = {}

-- the day number a time falls on (UTC)
function Likes.day(now: number): number
	return now // 86400
end

-- likedOn = the liker's record of { [owner's UserId as a string] = the day they last liked them }
function Likes.can(likerId: number, ownerId: number, likedOn: { [string]: number }, today: number): boolean
	return likerId ~= ownerId and likedOn[tostring(ownerId)] ~= today
end

-- record a like, dropping records from earlier days so the save stays small
function Likes.record(ownerId: number, likedOn: { [string]: number }, today: number)
	for key, day in likedOn do
		if day ~= today then
			likedOn[key] = nil
		end
	end
	likedOn[tostring(ownerId)] = today
end

return Likes
