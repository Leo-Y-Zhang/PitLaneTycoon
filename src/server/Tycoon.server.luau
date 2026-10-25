-- Pit Lane Tycoon server: plots, the production line, money, saving and purchases.
-- The whole map is built here from code, so the place file needs nothing made by hand.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Scenery = require(script.Parent:WaitForChild("Scenery"))
local SaveLock = require(script.Parent:WaitForChild("SaveLock"))
local Analytics = require(script.Parent:WaitForChild("Analytics"))
-- this server's name on a save lock (Studio has no JobId)
local JOB = game.JobId ~= "" and game.JobId or ("studio-" .. HttpService:GenerateGUID(false))
-- Studio only: a finished garage with no username on show, for thumbnails (tools/studio-test)
local PHOTO_MODE = RunService:IsStudio() and workspace:GetAttribute("PhotoMode") == true
Scenery.lighting()

local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[PitLane] DataStore unavailable (publish the place and enable Studio API access): " .. tostring(result))
	end
end
local board = nil -- the earnings leaderboard
do
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.LeaderboardName)
	end)
	if ok then
		board = result
	end
end

-- remotes ---------------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
local function remote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local notify = remote("Notify")
local newSeason = remote("NewSeason")
local effect = remote("Effect") -- purchase sparks and "+$" pop-ups, drawn by the owner's HUD

local ITEM_BY_KEY = {}
for i, item in Config.Items do
	ITEM_BY_KEY[item.key] = i
end

-- machines take turns at two label heights in the order they stand along the conveyor, so
-- neighbours' names never overlap
local LABEL_HIGH: { [string]: boolean } = {}
for _, kind in { "press", "upgrade" } do
	local line = {}
	for _, item in Config.Items do
		if item.kind == kind then
			table.insert(line, item)
		end
	end
	table.sort(line, function(a, b)
		return (a.x :: number) < (b.x :: number)
	end)
	for rank, item in line do
		LABEL_HIGH[item.key] = rank % 2 == 0
	end
end

-- small helpers ---------------------------------------------------------------------
local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

-- studs = a size in the world, so close machines' labels shrink with distance instead of
-- piling on top of each other; without it the label stays readable from across the garage
local function label(parent: Instance, text: string, height: number, studs: Vector2?): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = studs and UDim2.fromScale(studs.X, studs.Y) or UDim2.fromOffset(220, 60)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 90
	gui.Parent = parent
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.4
	t.Text = text
	t.Parent = gui
	return t
end

local function money(n: number): string
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

-- player state ----------------------------------------------------------------------
type Data = {
	cash: number, bought: { [string]: boolean }, season: number, lastDaily: number, streak: number,
	receipts: { [string]: boolean }, earned: number, lastSeen: number, offlineRate: number,
	funnel: number, -- the furthest onboarding-funnel step logged (Analytics)
}
type State = {
	data: Data, plot: any?, pending: number, canSave: boolean, passes: { [string]: boolean }, dirty: boolean, friends: number,
	leaving: boolean, released: boolean, -- the leaving save is under way / has let go of the lock
	unlogged: number, -- factory income not yet sent to analytics (sent once a minute)
}
local states: { [Player]: State } = {}

local function freshData(): Data
	return {
		cash = 0, bought = {}, season = 0, lastDaily = 0, streak = 0, receipts = {},
		earned = 0, lastSeen = 0, offlineRate = 0, funnel = 0,
	}
end

local function isHappyHour(): boolean
	local t = os.date("!*t")
	local h = Config.HappyHour
	return table.find(h.days, t.wday) ~= nil and t.hour >= h.startHourUtc and t.hour < h.startHourUtc + h.hours
end
local happyHour = isHappyHour()
workspace:SetAttribute("HappyHour", happyHour)

-- seasons and passes: the lasting part of the multiplier (offline earnings use only this)
local function baseMultiplier(st: State): number
	local m = 1 + st.data.season * Config.SeasonBonus
	if st.passes.DoubleCash then m *= 2 end
	if st.passes.VIP then m *= 1.25 end
	return m
end

local function friendBoost(st: State): number
	return math.min(st.friends, Config.FriendBoostMax) * Config.FriendBoost
end

local function multiplier(st: State): number
	return baseMultiplier(st) * (1 + friendBoost(st)) * (happyHour and Config.HappyHour.mult or 1)
end

local function conveyorSpeed(st: State): number
	local speed = Config.BaseConveyorSpeed
	for _, item in Config.Items do
		if item.kind == "speed" and st.data.bought[item.key] then
			speed = math.max(speed, item.speed :: number)
		end
	end
	return speed
end

-- a faster conveyor runs the presses faster too, so the parts stay the same distance apart
local function pressInterval(st: State, item: Config.Item): number
	return (item.every :: number) * Config.BaseConveyorSpeed / conveyorSpeed(st)
end

local function pressValue(st: State, item: Config.Item): number
	local value = item.value :: number
	for _, tune in Config.Items do
		if tune.kind == "tune" and tune.target == item.key and st.data.bought[tune.key] then
			value *= tune.mult :: number
		end
	end
	return value
end

-- every gate stands downstream of every press (tools/balance.py checks it), so every part
-- reaching scrutineering has passed every bought gate
local function gateMultiplier(st: State): number
	local m = 1
	for _, item in Config.Items do
		if item.kind == "upgrade" and st.data.bought[item.key] then
			m *= item.mult :: number
		end
	end
	return m
end

local function incomePerMinute(st: State, lastingOnly: boolean?): number
	local perMin = 0
	for _, item in Config.Items do
		if item.kind == "press" and st.data.bought[item.key] then
			perMin += pressValue(st, item) / pressInterval(st, item) * 60
		end
	end
	return perMin * gateMultiplier(st) * (lastingOnly and baseMultiplier(st) or multiplier(st))
end

local function nextItemIndex(st: State): number?
	for i, item in Config.Items do
		if not st.data.bought[item.key] and (item.season or 0) <= st.data.season then
			return i
		end
	end
	return nil
end

local function publish(player: Player)
	local st = states[player]
	if not st then return end
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		(ls:FindFirstChild("Cash") :: NumberValue).Value = math.floor(st.data.cash);
		(ls:FindFirstChild("Seasons") :: IntValue).Value = st.data.season
	end
	player:SetAttribute("Pending", math.floor(st.pending))
	player:SetAttribute("IncomePerMin", math.floor(incomePerMinute(st)))
	player:SetAttribute("Season", st.data.season)
	player:SetAttribute("SeasonCost", Config.SeasonCost(st.data.season))
	player:SetAttribute("HasTrophy", st.data.bought.trophy == true)
	player:SetAttribute("FriendBoost", math.floor(friendBoost(st) * 100 + 0.5))
	local nextIndex = nextItemIndex(st)
	local nextItem = nextIndex and Config.Items[nextIndex]
	player:SetAttribute("NextKey", nextItem and nextItem.key or "")
	player:SetAttribute("NextName", nextItem and nextItem.name or "")
	player:SetAttribute("NextCost", nextItem and nextItem.cost or 0)
	player:SetAttribute("Plot", st.plot and st.plot.index or 0)
	for name in Config.Passes do
		player:SetAttribute("Owns" .. name, st.passes[name] == true)
	end
	if st.plot then
		st.plot.pendingLabel.Text = st.passes.AutoCollect and "Auto-collect on" or ("Collect " .. money(st.pending))
	end
end

local function addCash(player: Player, amount: number, fromFactory: boolean?)
	local st = states[player]
	if not st then return end
	st.data.cash += amount
	if fromFactory then
		st.data.earned += amount -- only factory income counts for the leaderboard
		st.unlogged += amount
	end
	st.dirty = true
	publish(player)
end

-- plots -----------------------------------------------------------------------------
local plots = {}
local plotsFolder = Instance.new("Folder")
plotsFolder.Name = "Plots"
plotsFolder.Parent = workspace

local function at(plot, x: number, y: number, z: number): CFrame
	return plot.cf * CFrame.new(x, y, z)
end

local function refreshPads(player: Player)
	local st = states[player]
	if not st or not st.plot then return end
	local nextIndex = nextItemIndex(st)
	for i, pad in st.plot.pads do
		local show = i == nextIndex
		pad.Transparency = show and 0 or 1
		pad.CanTouch = show
		pad:FindFirstChildOfClass("BillboardGui").Enabled = show
	end
end

local function spawnPress(player: Player, item)
	local st = states[player]
	local plot = st.plot
	local body = part({
		Name = item.key, Size = Vector3.new(3, 3, 3), Color = Color3.fromRGB(70, 74, 82),
		Material = Enum.Material.Metal, CFrame = at(plot, item.x, 7, 0), Parent = plot.items,
	})
	part({ Name = "Cap", Size = Vector3.new(3.2, 0.3, 3.2), Color = plot.team.colour,
		Material = Enum.Material.SmoothPlastic, CFrame = at(plot, item.x, 8.65, 0), Parent = plot.items })
	plot.pressLabels[item.key] = label(body, item.name, LABEL_HIGH[item.key] and 4 or 2.6, Vector2.new(4.6, 1.2))
	task.spawn(function()
		while body.Parent and states[player] == st and st.plot == plot do
			local drop = Instance.new("Part")
			drop.Size = Vector3.new(1.2, 1.2, 1.2)
			drop.Color = Color3.fromRGB(196, 202, 210)
			drop.Material = Enum.Material.SmoothPlastic
			drop.CFrame = at(plot, item.x, 4.6, 0)
			drop:SetAttribute("Value", pressValue(st, item))
			drop.Parent = plot.drops
			-- the server moves every part, so a player's client can't steer them
			drop:SetNetworkOwner(nil)
			Debris:AddItem(drop, Config.PartLifetime)
			task.wait(pressInterval(st, item))
		end
	end)
end

-- an arch the parts ride through: dark posts, a team-colour beam and a faint curtain (the
-- part that counts), so six gates in a row read as six gates rather than one glowing wall
local function spawnUpgrade(player: Player, item)
	local plot = states[player].plot
	for _, z in { -3.9, 3.9 } do
		part({ Name = item.key .. "_post", Size = Vector3.new(0.6, 6.6, 0.6), Color = Color3.fromRGB(40, 44, 50),
			Material = Enum.Material.Metal, CanCollide = false, CanTouch = false, CFrame = at(plot, item.x, 4.3, z),
			Parent = plot.items })
	end
	part({ Name = item.key .. "_beam", Size = Vector3.new(0.9, 0.6, 8.4), Color = plot.team.colour,
		Material = Enum.Material.SmoothPlastic, CanCollide = false, CanTouch = false, CFrame = at(plot, item.x, 7.9, 0),
		Parent = plot.items })
	local gate = part({
		Name = item.key, Size = Vector3.new(1, 5.6, 7.2), Color = Color3.fromRGB(255, 170, 0),
		Material = Enum.Material.Neon, Transparency = 0.78, CanCollide = false,
		CFrame = at(plot, item.x, 4.3, 0), Parent = plot.items,
	})
	label(gate, item.name, LABEL_HIGH[item.key] and 5.6 or 4, Vector2.new(4.4, 1.3))
	local tag = "U_" .. item.key
	-- only the paint: a fast part can pass a gate between two physics steps without touching
	-- it, so the gates' multipliers are paid at scrutineering instead (gateMultiplier)
	gate.Touched:Connect(function(hit)
		if hit.Parent == plot.drops and not hit:GetAttribute(tag) then
			hit:SetAttribute(tag, true)
			hit.Color = Color3.fromRGB(255, 120, 40)
		end
	end)
end

-- a tune-up: a gold band round its press (one more per Mk) and the press's new name; metal,
-- not neon, so the bands don't bloom into one streak along the line
local function spawnTune(player: Player, item)
	local st = states[player]
	local plot = st.plot
	local press = Config.Items[ITEM_BY_KEY[item.target]]
	local tier = 0
	for _, other in Config.Items do
		if other.kind == "tune" and other.target == item.target and st.data.bought[other.key] then
			tier += 1
		end
		if other == item then break end
	end
	part({ Name = item.key, Size = Vector3.new(3.25, 0.3, 3.25), Color = Color3.fromRGB(212, 175, 55),
		Material = Enum.Material.Metal, CanCollide = false, CFrame = at(plot, press.x :: number, 5.6 + tier * 0.7, 0),
		Parent = plot.items })
	local name = plot.pressLabels[item.target]
	if name then name.Text = item.name end
end

local function build(player: Player, item)
	local st = states[player]
	if item.kind == "press" then
		spawnPress(player, item)
	elseif item.kind == "upgrade" then
		spawnUpgrade(player, item)
	elseif item.kind == "tune" then
		spawnTune(player, item)
	elseif item.kind == "speed" then
		st.plot.conveyor.AssemblyLinearVelocity = st.plot.cf.RightVector * conveyorSpeed(st)
	elseif item.kind == "trophy" then
		local cup = part({
			Name = "Trophy", Size = Vector3.new(3, 5, 3), Color = Color3.fromRGB(255, 205, 60),
			Material = Enum.Material.Foil, CFrame = at(st.plot, -27, 3, 16), Parent = st.plot.items,
		})
		label(cup, "New season ready", 4)
	end
end

local function rebuildPlot(player: Player)
	local st = states[player]
	local plot = st.plot
	plot.items:ClearAllChildren()
	plot.drops:ClearAllChildren()
	plot.pressLabels = {}
	Scenery.car(plot.items, at(plot, 2, 0, 15) * CFrame.Angles(0, math.rad(90), 0), plot.team.colour, st.data.season)
	plot.conveyor.AssemblyLinearVelocity = plot.cf.RightVector * conveyorSpeed(st)
	for _, item in Config.Items do
		if st.data.bought[item.key] then
			build(player, item)
		end
	end
	refreshPads(player)
end

local function tryBuy(player: Player, index: number)
	local st = states[player]
	if not st or nextItemIndex(st) ~= index then return end
	local item = Config.Items[index]
	if st.data.cash < item.cost then
		notify:FireClient(player, "Need " .. money(item.cost - st.data.cash) .. " more for " .. item.name)
		return
	end
	st.data.cash -= item.cost
	st.data.bought[item.key] = true
	st.dirty = true
	build(player, item)
	refreshPads(player)
	publish(player)
	notify:FireClient(player, "Bought " .. item.name)
	effect:FireClient(player, "bought", item.key)
	Analytics.spent(player, item.cost, st.data.cash, Enum.AnalyticsEconomyTransactionType.Shop, item.key)
	local purchases = -1 -- the first press is free
	for _ in st.data.bought do
		purchases += 1
	end
	local step = item.kind == "trophy" and Analytics.Step.trophy or Analytics.purchaseStep(purchases)
	st.data.funnel = Analytics.funnel(player, st.data.funnel, step)
end

local function bankPending(player: Player)
	local st = states[player]
	if st and st.pending > 0 then
		local amount = st.pending
		st.pending = 0
		addCash(player, amount, true)
		effect:FireClient(player, "banked", amount)
	end
end

local function makePlot(index: number)
	local angle = (index - 1) / Config.PlotCount * math.pi * 2
	local centre = Vector3.new(math.cos(angle), 0, math.sin(angle)) * Config.PlotRadius
	local plot = { index = index, owner = nil :: Player?, pads = {}, pressLabels = {}, team = Scenery.Teams[(index - 1) % #Scenery.Teams + 1] }
	plot.cf = CFrame.lookAt(centre, Vector3.new(0, 0, 0)) -- local -Z faces the spawn
	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model.Parent = plotsFolder
	plot.model = model
	part({ Name = "Base", Size = Vector3.new(64, 1, 52), CFrame = at(plot, 0, -0.5, 0),
		Color = Color3.fromRGB(46, 52, 58), Material = Enum.Material.Concrete, Parent = model })
	local sign = part({ Name = "Sign", Size = Vector3.new(14, 4, 1), CFrame = at(plot, 0, 3, -25.5),
		Color = plot.team.colour, Parent = model })
	Scenery.garage(model, plot.cf, plot.team)
	plot.signLabel = label(sign, "Free garage", 3)
	plot.conveyor = part({ Name = "Conveyor", Size = Vector3.new(48, 1, 6), CFrame = at(plot, 0, 1, 0),
		Color = Color3.fromRGB(30, 30, 30), Material = Enum.Material.DiamondPlate, Parent = model })
	local collector = part({ Name = "Scrutineering", Size = Vector3.new(4, 3, 8), CFrame = at(plot, 26, 1.5, 0),
		Color = Color3.fromRGB(0, 170, 110), Material = Enum.Material.Neon, Parent = model })
	label(collector, "Scrutineering", 3, Vector2.new(5.5, 1.4))
	local collectPad = part({ Name = "CollectPad", Size = Vector3.new(6, 0.4, 6), CFrame = at(plot, 26, 0.2, 12),
		Color = Color3.fromRGB(0, 120, 255), Material = Enum.Material.Neon, Parent = model })
	plot.pendingLabel = label(collectPad, "Collect $0", 3)
	plot.items = Instance.new("Folder")
	plot.items.Name = "Items"
	plot.items.Parent = model
	plot.drops = Instance.new("Folder")
	plot.drops.Name = "Drops"
	plot.drops.Parent = model

	collector.Touched:Connect(function(hit)
		if hit.Parent ~= plot.drops or not plot.owner then return end
		local st = states[plot.owner]
		local value = (hit:GetAttribute("Value") or 0) * (st and gateMultiplier(st) * multiplier(st) or 1)
		hit:Destroy()
		if not st then return end
		if st.passes.AutoCollect then
			addCash(plot.owner, value, true)
		else
			st.pending += value
			publish(plot.owner)
		end
	end)
	local function ownerOf(hit: BasePart): Player?
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and player == plot.owner then return player end
		return nil
	end
	collectPad.Touched:Connect(function(hit)
		local player = ownerOf(hit)
		if player then bankPending(player) end
	end)
	for i, item in Config.Items do
		-- two rows of twelve in front of the line; only the next pad is ever lit
		local col, row = (i - 1) % 12, (i - 1) // 12
		local pad = part({ Name = "Buy_" .. item.key, Size = Vector3.new(4, 0.4, 4),
			CFrame = at(plot, -27 + col * 4.9, 0.2, -18 + row * 5), Color = Color3.fromRGB(255, 70, 70),
			Material = Enum.Material.Neon, Transparency = 1, CanTouch = false, Parent = model })
		local text = label(pad, item.name .. "\n" .. (item.cost == 0 and "Free" or money(item.cost)), 3)
		local board = text.Parent :: BillboardGui
		board.Enabled = false
		local busy = false
		pad.Touched:Connect(function(hit)
			local player = ownerOf(hit)
			if player and not busy then
				busy = true
				tryBuy(player, i)
				task.wait(0.4)
				busy = false
			end
		end)
		plot.pads[i] = pad
	end
	return plot
end

for i = 1, Config.PlotCount do
	plots[i] = makePlot(i)
end
local spawnPad = Instance.new("SpawnLocation")
spawnPad.Size = Vector3.new(12, 1, 12)
spawnPad.Anchored = true
spawnPad.Neutral = true
spawnPad.Duration = 0 -- no fighting here, so no spawn-protection bubble on arrival
spawnPad.Color = Color3.fromRGB(230, 230, 235)
spawnPad.CFrame = CFrame.new(0, 0.5, 0)
spawnPad.Parent = workspace
-- the paddock: one ground plane under the spawn and every garage
part({ Name = "Paddock", Size = Vector3.new(2 * Config.PlotRadius + 140, 1, 2 * Config.PlotRadius + 140),
	CFrame = CFrame.new(0, -0.6, 0), Color = Color3.fromRGB(84, 92, 98), Material = Enum.Material.Asphalt, Parent = workspace })
Scenery.paddock(Config.PlotCount, Config.PlotRadius, 26)

-- saving ----------------------------------------------------------------------------
-- Saves are session-locked (SaveLock): a server writes a player's save only while it holds
-- that save's lock, so a server hop can't load an old save or overwrite a newer one.
local savesInFlight = 0

-- release = the player is leaving: let go of the lock so their next server loads at once
local function save(player: Player, release: boolean?): boolean
	local st = states[player]
	if not st or not st.canSave or st.released or not store then return false end
	st.data.lastSeen = os.time()
	st.data.offlineRate = incomePerMinute(st, true)
	local wasDirty = st.dirty
	savesInFlight += 1
	local written, lost, err = SaveLock.save(store, "u_" .. player.UserId, table.clone(st.data), JOB, os.time(), release)
	savesInFlight -= 1
	if written then
		st.dirty = false
		st.released = release == true
	elseif lost then
		-- another server took this save over after this one stopped saving for too long;
		-- its copy is the newer one, so this server must not write again
		st.canSave = false
		warn("[PitLane] " .. player.Name .. "'s save is held by another server; no longer saving here")
	else
		warn("[PitLane] save failed for " .. player.Name .. ": " .. tostring(err))
	end
	-- the game's owner never appears on the public board
	local isOwner = game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
	if written and wasDirty and board and st.data.earned >= 1 and not isOwner then
		pcall(function()
			board:SetAsync("u_" .. player.UserId, math.floor(st.data.earned))
		end)
	end
	return written
end

local function load(player: Player): (Data, boolean)
	if not store then
		return freshData(), false
	end
	local told = false
	local result, status = SaveLock.open(store, "u_" .. player.UserId, JOB, {
		now = function()
			return os.time()
		end,
		wait = function(seconds: number)
			task.wait(seconds)
		end,
		held = function()
			if not told then
				told = true
				notify:FireClient(player, "Fetching your garage from your last server...")
			end
		end,
		gone = function()
			return player.Parent == nil
		end,
		stale = Config.SaveLock.staleSeconds,
		retry = Config.SaveLock.retrySeconds,
		giveUp = Config.SaveLock.giveUpSeconds,
	})
	if status ~= "ok" then
		-- never overwrite a save we could not read, or one another server still holds
		return freshData(), false
	end
	local data = freshData()
	for k, v in result or {} do
		(data :: any)[k] = v
	end
	return data, true
end

local function flushAnalytics(player: Player, st: State)
	if st.unlogged >= 1 then
		Analytics.earned(player, st.unlogged, st.data.cash, Enum.AnalyticsEconomyTransactionType.Gameplay, "Factory")
		st.unlogged = 0
	end
end

-- passes ----------------------------------------------------------------------------
local function checkPasses(player: Player, st: State)
	for name, id in Config.Passes do
		if id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
			end)
			st.passes[name] = ok and owns or false
		end
	end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	local st = states[player]
	if not (purchased and st) then return end
	for name, id in Config.Passes do
		if id == passId then
			st.passes[name] = true
			if name == "AutoCollect" then bankPending(player) end
			notify:FireClient(player, "Thanks! Pass active.")
		end
	end
	publish(player)
end)

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local st = player and states[player]
	if not (player and st) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if st.data.receipts[receipt.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	for _, product in Config.Products do
		if product.id ~= 0 and product.id == receipt.ProductId then
			-- report a purchase granted only once it is saved; otherwise Roblox offers it
			-- again on the player's next visit, instead of the Robux buying nothing
			if not (store and st.canSave) then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			local amount = math.max(product.floor, incomePerMinute(st) * product.minutes)
			st.data.receipts[receipt.PurchaseId] = true
			addCash(player, amount)
			if not save(player) then
				st.data.receipts[receipt.PurchaseId] = nil
				st.data.cash = math.max(0, st.data.cash - amount)
				publish(player)
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			notify:FireClient(player, product.name .. ": +" .. money(amount))
			Analytics.earned(player, amount, st.data.cash, Enum.AnalyticsEconomyTransactionType.IAP, product.name)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- seasons and daily rewards ---------------------------------------------------------
newSeason.OnServerEvent:Connect(function(player)
	local st = states[player]
	if not st or not st.data.bought.trophy then return end
	local cost = Config.SeasonCost(st.data.season)
	if st.data.cash < cost then
		notify:FireClient(player, "A new season needs " .. money(cost))
		return
	end
	Analytics.spent(player, st.data.cash, 0, Enum.AnalyticsEconomyTransactionType.Gameplay, "NewSeason")
	st.data.season += 1
	st.data.cash = 0
	st.data.bought = { [Config.Items[1].key] = true }
	st.pending = 0
	st.dirty = true
	rebuildPlot(player)
	publish(player)
	save(player)
	notify:FireClient(player, ("Season %d! Earnings now x%.1f"):format(st.data.season + 1, multiplier(st)))
	st.data.funnel = Analytics.funnel(player, st.data.funnel, Analytics.Step.newSeason)
end)

local function dailyReward(player: Player, st: State)
	local now = os.time()
	local since = (now - st.data.lastDaily) / 3600
	if since < Config.DailyCooldownHours then return end
	st.data.streak = (since <= Config.StreakBreakHours) and st.data.streak + 1 or 1
	st.data.lastDaily = now
	local day = math.min(st.data.streak, #Config.DailyRewards.cash)
	local reward = math.max(Config.DailyRewards.cash[day] * multiplier(st), incomePerMinute(st) * Config.DailyRewards.minutes[day])
	addCash(player, reward)
	notify:FireClient(player, ("Day %d streak: +%s"):format(st.data.streak, money(reward)))
	Analytics.earned(player, reward, st.data.cash, Enum.AnalyticsEconomyTransactionType.TimedReward, "DailyStreak")
end

local function offlineEarnings(player: Player, st: State)
	local away = os.time() - st.data.lastSeen
	if st.data.lastSeen <= 0 or away < Config.Offline.minMinutes * 60 then return end
	local minutes = math.min(away / 60, Config.Offline.capHours * 60)
	local amount = math.floor(st.data.offlineRate * minutes * Config.Offline.share)
	if amount <= 0 then return end
	addCash(player, amount)
	Analytics.earned(player, amount, st.data.cash, Enum.AnalyticsEconomyTransactionType.TimedReward, "Offline")
	task.delay(3, function() -- after the daily-reward message
		notify:FireClient(player, "Your factory made " .. money(amount) .. " while you were away")
	end)
end

-- friends boost ---------------------------------------------------------------------
local friendCache: { [string]: boolean } = {}
local function areFriends(a: Player, b: Player): boolean
	local lo, hi = math.min(a.UserId, b.UserId), math.max(a.UserId, b.UserId)
	local key = lo .. ":" .. hi
	if friendCache[key] == nil then
		local ok, result = pcall(function()
			return a:IsFriendsWith(b.UserId)
		end)
		if not ok then return false end -- ask again next time
		friendCache[key] = result
	end
	return friendCache[key]
end

local function refreshFriends()
	for player, st in states do
		task.spawn(function()
			local count = 0
			for _, other in Players:GetPlayers() do
				if other ~= player and areFriends(player, other) then
					count += 1
				end
			end
			if states[player] == st and st.friends ~= count then
				st.friends = count
				publish(player)
			end
		end)
	end
end

-- leaderboard -----------------------------------------------------------------------
local boardRows: { TextLabel } = {}
do
	local boardPart = part({ Name = "Leaderboard", Size = Vector3.new(18, 12, 1), CFrame = CFrame.new(0, 6.5, -14),
		Color = Color3.fromRGB(17, 20, 24), Material = Enum.Material.SmoothPlastic, Parent = workspace })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- faces the spawn
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = boardPart
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 80)
	title.BackgroundColor3 = Color3.fromRGB(225, 38, 28)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = "Top constructors"
	title.Parent = gui
	for i = 1, Config.LeaderboardSize do
		local row = Instance.new("TextLabel")
		row.Position = UDim2.new(0, 24, 0, 80 + (i - 1) * 38)
		row.Size = UDim2.new(1, -48, 0, 36)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Color3.fromRGB(245, 246, 248)
		row.Text = ""
		row.Parent = gui
		boardRows[i] = row
	end
end

local nameCache: { [number]: string } = {}
local function refreshBoard()
	local ok, page = false, nil
	if board then
		ok, page = pcall(function()
			return board:GetSortedAsync(false, Config.LeaderboardSize):GetCurrentPage()
		end)
	end
	if not ok then
		boardRows[1].Text = "Appears once the game is published"
		return
	end
	for i, row in boardRows do
		local entry = page[i]
		if entry then
			local userId = tonumber(string.sub(entry.key, 3)) or 0
			if not nameCache[userId] then
				local okName, name = pcall(function()
					return Players:GetNameFromUserIdAsync(userId)
				end)
				nameCache[userId] = okName and name or "Racer"
			end
			row.Text = ("%d. %s   %s"):format(i, nameCache[userId], money(entry.value))
		else
			row.Text = ""
		end
	end
end

-- joining and leaving ---------------------------------------------------------------
local function assignPlot(player: Player)
	for _, plot in plots do
		if not plot.owner then
			plot.owner = player
			plot.signLabel.Text = player.DisplayName .. "'s garage"
			return plot
		end
	end
	return nil
end

local function onPlayerAdded(player: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local cash = Instance.new("NumberValue")
	cash.Name = "Cash"
	cash.Parent = ls
	local seasons = Instance.new("IntValue")
	seasons.Name = "Seasons"
	seasons.Parent = ls
	ls.Parent = player

	local data, canSave = load(player)
	if not player.Parent then
		-- left while loading: let go of the save, unchanged, so their next server needn't wait
		if canSave then
			SaveLock.save(store, "u_" .. player.UserId, data, JOB, os.time(), true)
		end
		return
	end
	local st: State = {
		data = data, plot = nil, pending = 0, canSave = canSave, passes = {}, dirty = false, friends = 0,
		leaving = false, released = false, unlogged = 0,
	}
	states[player] = st
	checkPasses(player, st)
	st.data.bought[Config.Items[1].key] = true -- the first press is free
	if PHOTO_MODE then
		for _, item in Config.Items do
			st.data.bought[item.key] = true
		end
		st.data.season = 1
	end
	st.plot = assignPlot(player)
	if not st.plot then
		notify:FireClient(player, "This server is full of teams. Try another server.")
		return
	end
	if PHOTO_MODE then
		st.plot.signLabel.Text = "Your garage"
	end
	rebuildPlot(player)
	publish(player)
	st.data.funnel = Analytics.funnel(player, st.data.funnel, Analytics.Step.joined)
	if not canSave and store then
		notify:FireClient(player, "Saving is unavailable right now; progress this visit may not save.")
	end
	dailyReward(player, st)
	offlineEarnings(player, st)
	refreshFriends()

	local function toPlot(character: Model)
		task.defer(function()
			if st.plot then
				character:PivotTo(at(st.plot, 0, 4, -22))
			end
		end)
	end
	player.CharacterAdded:Connect(toPlot)
	if player.Character then toPlot(player.Character) end
end
Players.PlayerAdded:Connect(onPlayerAdded)
-- anyone who joined while this script was still building the map
for _, player in Players:GetPlayers() do
	if not states[player] then
		task.spawn(onPlayerAdded, player)
	end
end

Players.PlayerRemoving:Connect(function(player)
	local st = states[player]
	if not st then return end
	st.leaving = true
	flushAnalytics(player, st)
	save(player, true)
	if st.plot then
		st.plot.owner = nil
		st.plot.signLabel.Text = "Free garage"
		st.plot.pendingLabel.Text = "Collect $0"
		st.plot.items:ClearAllChildren()
		st.plot.drops:ClearAllChildren()
		for _, pad in st.plot.pads do
			pad.Transparency = 1
			pad.CanTouch = false
			pad:FindFirstChildOfClass("BillboardGui").Enabled = false
		end
	end
	states[player] = nil
	refreshFriends()
end)

game:BindToClose(function()
	if RunService:IsStudio() and not store then return end
	for player, st in states do
		if not st.leaving then -- otherwise PlayerRemoving is already saving them
			st.leaving = true
			task.spawn(save, player, true)
		end
	end
	local started = os.clock()
	while savesInFlight > 0 and os.clock() - started < 25 do -- Roblox allows 30 s here
		task.wait(0.2)
	end
end)

task.spawn(function()
	while true do
		refreshBoard()
		task.wait(Config.LeaderboardRefreshSeconds)
	end
end)

task.spawn(function()
	while true do
		task.wait(30)
		local now = isHappyHour()
		if now ~= happyHour then
			happyHour = now
			workspace:SetAttribute("HappyHour", now)
			for player in states do
				publish(player)
				if now then
					notify:FireClient(player, "Happy hour! Everything earns 2x for the next hour")
				end
			end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(Config.AutosaveSeconds)
		-- everyone, changed or not: each save also tells other servers this lock is alive
		for player, st in states do
			if not st.leaving then
				flushAnalytics(player, st)
				task.spawn(save, player)
			end
		end
	end
end)
