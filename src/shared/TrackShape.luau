--!strict
-- The time-trial track: a loop round the paddock, described in polar coordinates about the
-- spawn as r(a) = radius + the sum of amplitude * sin(frequency * a + phase). Pure maths with
-- no Roblox APIs, so the server (lap timing), the client (on or off the road) and
-- tests/Racing.spec.luau all agree on where the track is. Angles grow from +X towards +Z,
-- which is the way round the cars drive; the start line is at angle 0.

local TrackShape = {}

export type Shape = {
	radius: number,
	waves: { { number } }, -- { amplitude, frequency, phase }
	halfWidth: number,
}

local TAU = 2 * math.pi

function TrackShape.radiusAt(shape: Shape, a: number): number
	local r = shape.radius
	for _, w in shape.waves do
		r += w[1] * math.sin(w[2] * a + w[3])
	end
	return r
end

-- the centre line at angle a
function TrackShape.point(shape: Shape, a: number): (number, number)
	local r = TrackShape.radiusAt(shape, a)
	return r * math.cos(a), r * math.sin(a)
end

-- the direction of travel at angle a, as a unit vector
function TrackShape.tangent(shape: Shape, a: number): (number, number)
	local x1, z1 = TrackShape.point(shape, a - 0.001)
	local x2, z2 = TrackShape.point(shape, a + 0.001)
	local dx, dz = x2 - x1, z2 - z1
	local len = math.sqrt(dx * dx + dz * dz)
	return dx / len, dz / len
end

-- the angle round the paddock, from 0 to 2 pi
function TrackShape.angleOf(x: number, z: number): number
	local a = math.atan2(z, x)
	return if a < 0 then a + TAU else a
end

-- the nearest point of the centre line to (x, z): its angle, and the distance to it,
-- positive outside the line and negative inside it. Starts from the point's own angle and
-- narrows in, since on the bends the nearest point can sit at a slightly different angle.
function TrackShape.nearest(shape: Shape, x: number, z: number): (number, number)
	local function dist2(a: number): number
		local px, pz = TrackShape.point(shape, a)
		return (px - x) ^ 2 + (pz - z) ^ 2
	end
	local lo, hi = TrackShape.angleOf(x, z) - 0.2, TrackShape.angleOf(x, z) + 0.2
	for _ = 1, 30 do
		local m1, m2 = lo + (hi - lo) / 3, hi - (hi - lo) / 3
		if dist2(m1) < dist2(m2) then
			hi = m2
		else
			lo = m1
		end
	end
	local a = (lo + hi) / 2
	local d = math.sqrt(dist2(a))
	if math.sqrt(x * x + z * z) < TrackShape.radiusAt(shape, a) then
		d = -d
	end
	return a % TAU, d
end

-- n points evenly spaced in angle, from the start line round
function TrackShape.samples(shape: Shape, n: number): { { x: number, z: number, a: number } }
	local out = {}
	for i = 0, n - 1 do
		local a = i / n * TAU
		local x, z = TrackShape.point(shape, a)
		table.insert(out, { x = x, z = z, a = a })
	end
	return out
end

-- how near to and how far from the spawn the road's edges come
function TrackShape.extent(shape: Shape): (number, number)
	local inner, outer = math.huge, 0
	for _, p in TrackShape.samples(shape, 2000) do
		local r = math.sqrt(p.x * p.x + p.z * p.z)
		inner, outer = math.min(inner, r), math.max(outer, r)
	end
	return inner - shape.halfWidth, outer + shape.halfWidth
end

function TrackShape.length(shape: Shape): number
	local points = TrackShape.samples(shape, 2000)
	local total = 0
	for i, p in points do
		local q = points[i % #points + 1]
		total += math.sqrt((q.x - p.x) ^ 2 + (q.z - p.z) ^ 2)
	end
	return total
end

return TrackShape
