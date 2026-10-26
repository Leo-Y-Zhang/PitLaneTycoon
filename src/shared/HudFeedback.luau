--!strict
-- Presentation only: no rewards or eligibility decisions are made here.
local HudFeedback = {}

-- The HUD's existing abbreviated cash format, shared by counters and pop-ups.
function HudFeedback.money(n: number): string
	local units = { "", "K", "M", "B", "T", "Qa" }
	local i = 1
	while math.abs(n) >= 1000 and i < #units do
		n /= 1000
		i += 1
	end
	if i == 1 then
		return "$" .. tostring(math.floor(n))
	end
	return string.format("$%.1f%s", n, units[i])
end

export type ProgressItem = { key: string, season: number? }

-- Purchases are sequential; NextKey describes the first unowned eligible item.
-- Building the line earns 80%; banking the season fee earns the remaining 20%.
function HudFeedback.seasonProgress(items: { ProgressItem }, season: number, nextKey: string,
	hasTrophy: boolean, cash: number, cost: number): (number, number, number)
	local total, built = 0, 0
	local reachedNext = false
	for i, item in items do
		if (item.season or 0) <= season then
			if item.key == nextKey then reachedNext = true end
			if i > 1 then -- the first press is free
				total += 1
				if not reachedNext then built += 1 end
			end
		end
	end
	-- Empty/unknown NextKey can occur before replication; only the trophy confirms completion.
	if hasTrophy then
		return 0.8 + 0.2 * math.clamp(cash / math.max(cost, 1), 0, 1), total, total
	end
	if not reachedNext then built = 0 end
	return 0.8 * built / math.max(total, 1), built, total
end

HudFeedback.ToastLimit = 3
HudFeedback.PendingLimit = 12
HudFeedback.ToastLifetime = 3
export type Toast = { id: number, text: string, expiresAt: number }
export type Queue = { visible: { Toast }, pending: { Toast }, serial: number }

function HudFeedback.newQueue(): Queue
	return { visible = {}, pending = {}, serial = 0 }
end

function HudFeedback.advance(queue: Queue, now: number)
	for i = #queue.visible, 1, -1 do
		if queue.visible[i].expiresAt <= now then table.remove(queue.visible, i) end
	end
	while #queue.visible < HudFeedback.ToastLimit and #queue.pending > 0 do
		local entry = table.remove(queue.pending, 1)
		if not entry then break end
		entry.expiresAt = now + HudFeedback.ToastLifetime
		table.insert(queue.visible, entry)
	end
end

function HudFeedback.enqueue(queue: Queue, text: string, now: number)
	HudFeedback.advance(queue, now)
	if text == "" then return end
	queue.serial += 1
	if #queue.pending == HudFeedback.PendingLimit then table.remove(queue.pending, 1) end
	table.insert(queue.pending, { id = queue.serial, text = text, expiresAt = 0 })
	HudFeedback.advance(queue, now)
end

return HudFeedback
