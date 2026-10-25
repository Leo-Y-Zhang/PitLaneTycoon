--!strict
-- Which pieces of a team's garage are up, from the plan in Config.GaragePieces: a piece goes
-- up once the team has made `at` purchases this season and clears away the building-site prop
-- it replaces. Pure Luau, so tests/Garage.spec.luau checks the plan in CI; Scenery builds the
-- pieces and props by name.

local GaragePlan = {}

export type Piece = { name: string, label: string, at: number, keep: boolean?, clears: string? }

-- the building-site props Scenery.siteProp can build
GaragePlan.SiteProps = { "Cones", "Scaffold", "Fence", "SiteSign" }

-- purchases = machines bought this season (the free first press does not count). From the
-- second season on, the `keep` pieces stand from the start.
function GaragePlan.built(pieces: { Piece }, purchases: number, season: number): { [string]: boolean }
	local up = {}
	for _, piece in pieces do
		up[piece.name] = purchases >= piece.at or (season > 0 and piece.keep == true)
	end
	return up
end

-- the site props still standing: each one until the piece that clears it is up
function GaragePlan.site(pieces: { Piece }, up: { [string]: boolean }): { [string]: boolean }
	local props = {}
	for _, name in GaragePlan.SiteProps do
		props[name] = false
	end
	for _, piece in pieces do
		if piece.clears then
			props[piece.clears] = not up[piece.name]
		end
	end
	return props
end

-- the piece this purchase puts up, if any (for the "garage grows" message)
function GaragePlan.newPiece(pieces: { Piece }, purchases: number, season: number): Piece?
	for _, piece in pieces do
		if piece.at == purchases and not (season > 0 and piece.keep) then
			return piece
		end
	end
	return nil
end

return GaragePlan
