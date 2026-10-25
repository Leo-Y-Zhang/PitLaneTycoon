-- Pit Lane Tycoon smoke test: a Studio plugin that plays the game the way TESTING.md describes
-- and reports PASS or FAIL for each step. run.py installs it, opens the place, reads the result
-- from Studio's log and removes it again; it never ships with the game.
--
-- The plugin loads in every Studio DataModel. In the editor it starts a play test through
-- StudioTestService; inside that test the server copy walks the player through the game, and
-- the client copy reports the HUD and any client errors.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local StudioTestService = game:GetService("StudioTestService")
local ServerScriptService = game:GetService("ServerScriptService")

local TAG = "[PLT-TEST]"
local SCENARIO = "smoke" -- run.py --photos swaps in "photo"

local function isPitLane(): boolean
	if RunService:IsClient() and RunService:IsRunning() then
		-- server scripts never reach the client; the shared Config module does
		local shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared", 20)
		return shared ~= nil and shared:FindFirstChild("Config") ~= nil
	end
	local server = ServerScriptService:FindFirstChild("Server")
	return server ~= nil and server:FindFirstChild("Tycoon") ~= nil
end

local function waitFor(fn: () -> any, timeout: number): any
	local t0 = os.clock()
	repeat
		local v = fn()
		if v then
			return v
		end
		task.wait(0.2)
	until os.clock() - t0 > timeout
	return nil
end

if not isPitLane() then
	return
end

-- editor, run.py --audio: check every sound id the game uses comes from a Roblox-licensed
-- library (so any experience may play it), and list candidates for new sounds -------------
-- the accounts Roblox's licensed libraries are published under
local LICENSED = { Roblox = true, APMOfficial = true, ProSoundEffects = true }
local function auditAudio()
	local MarketplaceService = game:GetService("MarketplaceService")
	local AssetService = game:GetService("AssetService")
	local function say(text: string)
		print(TAG, "AUDIO " .. string.sub(text, 1, 380))
	end
	local okConfig, config = pcall(function()
		return require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config")) :: any
	end)
	local bad = 0
	local ids = {}
	for name, id in (okConfig and config.Audio or {}) do
		if type(id) == "table" then
			for i, track in id do
				table.insert(ids, { name .. i, track })
			end
		else
			table.insert(ids, { name, id })
		end
	end
	for _, entry in ids do
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(entry[2], Enum.InfoType.Asset)
		end)
		local licensed = ok and info.Creator and LICENSED[info.Creator.Name] == true and info.AssetTypeId == 3
		bad += licensed and 0 or 1
		say(("%s %s %d %s by %s"):format(licensed and "OK" or "BAD", entry[1], entry[2], ok and tostring(info.Name) or "?",
			ok and info.Creator and tostring(info.Creator.Name) or tostring(info)))
	end
	if #ids == 0 then
		bad += 1
		say("BAD no Config.Audio")
	end
	local SEARCH = {} -- run.py --search fills this
	local queries = #SEARCH > 0 and SEARCH or { { "Music", "racing" }, { "Music", "upbeat electronic" },
		{ "Sound", "button click" }, { "Sound", "cash register" }, { "Sound", "whoosh" }, { "Sound", "race car engine" } }
	for _, query in queries do
		local ok, result = pcall(function()
			local params = Instance.new("AudioSearchParams")
			params.SearchKeyword = query[2]
			params.AudioSubType = query[1] == "Music" and Enum.AudioSubType.Music or Enum.AudioSubType.SoundEffect
			return AssetService:SearchAudio(params):GetCurrentPage()
		end)
		if not ok then
			say("SEARCH-FAILED " .. query[2] .. " " .. tostring(result))
			continue
		end
		for i, item in result do
			if i == 1 then
				say("KEYS " .. query[2] .. " " .. HttpService:JSONEncode(item))
			end
			local creator = item.Creator or item.creator or {}
			local name = creator.Name or creator.name or item.CreatorName or "?"
			if not LICENSED[name] then
				continue -- only what any experience may play
			end
			say(("FOUND %s | %s | %s | %s | %ss | by %s"):format(query[2], tostring(item.Id), tostring(item.Title),
				tostring(item.Artist), tostring(item.Duration), tostring(name)))
		end
	end
	print(TAG, "RESULT " .. HttpService:JSONEncode({ ok = true, result = { passed = bad == 0 and 1 or 0, total = 1, errors = bad } }))
end

-- editor: start the play test and print what it returns --------------------------------
if RunService:IsEdit() then
	if SCENARIO == "audio" then
		task.delay(6, auditAudio)
		return
	end
	task.delay(8, function()
		print(TAG, "START")
		if SCENARIO == "photo" then
			workspace:SetAttribute("PhotoMode", true) -- never saved: run.py closes Studio unsaved
		end
		local ok, result = pcall(function()
			return StudioTestService:ExecutePlayModeAsync({ scenario = SCENARIO })
		end)
		-- Studio's log cuts long lines, so the details go one per line before the summary
		if ok and type(result) == "table" then
			for _, message in result.errors or {} do
				print(TAG, "ERROR " .. string.sub(message, 1, 400))
			end
			for _, message in result.warnings or {} do
				print(TAG, "WARNING " .. string.sub(message, 1, 400))
			end
			result = { passed = result.passed, total = result.total, errors = #(result.errors or {}) }
		end
		print(TAG, "RESULT " .. HttpService:JSONEncode({ ok = ok, result = result }))
	end)
	return
end

-- client, photo mode: hide the HUD and the avatar, then frame four thumbnail shots --------
local function photoShoot()
	local player = Players.LocalPlayer
	pcall(function()
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	end)
	waitFor(function()
		return player.PlayerGui:FindFirstChild("PitLaneHud") and player.PlayerGui:FindFirstChild("PitLaneSettings")
	end, 30)
	local function hideGuis()
		for _, gui in player.PlayerGui:GetChildren() do
			if gui:IsA("ScreenGui") then
				gui.Enabled = false
			end
		end
	end
	hideGuis()
	local plot = waitFor(function()
		for _, model in workspace:WaitForChild("Plots"):GetChildren() do
			local board = model:FindFirstChild("Sign") and model.Sign:FindFirstChildOfClass("BillboardGui")
			local text = board and board:FindFirstChildOfClass("TextLabel")
			if text and text.Text == "Your garage" then
				return model
			end
		end
		return nil
	end, 30)
	if not plot then
		print(TAG, "PHOTO no garage found")
		return
	end
	task.wait(6) -- let every press drop parts onto the line
	local character = player.Character
	if character then
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				d.LocalTransparencyModifier = 1
			end
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end
	for _, gui in workspace:GetDescendants() do -- floating labels clutter a thumbnail
		if gui:IsA("BillboardGui") then
			gui.Enabled = false
		end
	end
	for _, model in workspace.Plots:GetChildren() do -- name boards are blank blocks without their labels
		local sign = model:FindFirstChild("Sign")
		if sign and sign:IsA("BasePart") then
			sign.LocalTransparencyModifier = 1
		end
	end
	local base = (plot:FindFirstChild("Base") :: BasePart).CFrame
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = 55
	local shots = {
		{ "hero", base * CFrame.new(-22, 15, -38), base * CFrame.new(2, 3, 8) },
		{ "car", base * CFrame.new(-12, 6, 4), base * CFrame.new(2.5, 1.4, 15) },
		{ "line", base * CFrame.new(-22, 6, -12), base * CFrame.new(12, 2.5, 2) },
		{ "paddock", base * CFrame.new(0, 48, -100), base * CFrame.new(0, 2, -10) },
	}
	for _, shot in shots do
		cam.CFrame = CFrame.lookAt(shot[2].Position, shot[3].Position)
		task.wait(1.5)
		print(TAG, "SHOT " .. shot[1])
		task.wait(2.5)
	end
	-- the car on the track, just past the gantry
	game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Drive"):FireServer(true)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and waitFor(function()
		return humanoid.SeatPart
	end, 8)
	if seat then
		local shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		local TrackShape = require(shared:WaitForChild("TrackShape")) :: any
		local track = (require(shared:WaitForChild("Config")) :: any).Track
		local car = seat.Parent :: Model
		local x, z = TrackShape.point(track, 0.06)
		local tx, tz = TrackShape.tangent(track, 0.06)
		local at = Vector3.new(x, 1.1, z)
		-- sitting down hands the camera to the car; take it back every frame
		local hold = RunService.Heartbeat:Connect(function()
			car:PivotTo(CFrame.lookAt(at, at + Vector3.new(tx, 0, tz)))
			cam.CameraType = Enum.CameraType.Scriptable
		end)
		task.wait(1)
		hideGuis()
		for _, d in (character :: Model):GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				d.LocalTransparencyModifier = 1
			end
		end
		local side = Vector3.new(tz, 0, -tx) -- outwards
		cam.CFrame = CFrame.lookAt(at + Vector3.new(tx, 0, tz) * 16 + side * 7 + Vector3.new(0, 3, 0), at - Vector3.new(tx, 0, tz) * 6)
		task.wait(1.5)
		print(TAG, "SHOT race")
		task.wait(2.5)
		cam.CFrame = CFrame.lookAt(at + side * 60 + Vector3.new(0, 30, 0), at + Vector3.new(0, 2, 0))
		task.wait(1.5)
		print(TAG, "SHOT track")
		task.wait(2.5)
		hold:Disconnect()
	end
	for _, model in workspace.Plots:GetChildren() do -- the night look, built next door in photo mode
		if model:GetAttribute("Theme") == "night" then
			local nb = (model:FindFirstChild("Base") :: BasePart).CFrame
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = CFrame.lookAt((nb * CFrame.new(-24, 20, -54)).Position, (nb * CFrame.new(0, 7, 8)).Position)
			task.wait(1.5)
			print(TAG, "SHOT night")
			task.wait(2.5)
			break
		end
	end
	print(TAG, "PHOTOS-DONE")
end

-- client: check the HUD and report client-side errors ----------------------------------
-- run.py counts every CLIENT-FAIL line as a failed check
local function clientCheck(name: string, pass: any, detail: any?)
	print(TAG, (pass and "CLIENT-PASS " or "CLIENT-FAIL ") .. name .. (detail ~= nil and (" (" .. tostring(detail) .. ")") or ""))
end

if RunService:IsClient() then
	if workspace:GetAttribute("PhotoMode") then
		task.spawn(photoShoot)
		return
	end
	LogService.MessageOut:Connect(function(message, kind)
		if kind == Enum.MessageType.MessageError then
			print(TAG, "CLIENT-ERROR " .. message)
		end
	end)
	task.spawn(function()
		local player = Players.LocalPlayer
		local hud = waitFor(function()
			return player and player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("PitLaneHud")
		end, 30)
		if not hud then
			clientCheck("the HUD appears", false)
			return
		end
		local popUps = 0
		task.spawn(function()
			local character = player.Character or player.CharacterAdded:Wait()
			character:WaitForChild("HumanoidRootPart").ChildAdded:Connect(function(child)
				local label = child:IsA("BillboardGui") and child:FindFirstChildOfClass("TextLabel")
				if label and string.sub(label.Text, 1, 2) == "+$" then
					popUps += 1
				end
			end)
		end)

		task.wait(3)
		local guide = workspace:FindFirstChild("PitLaneGuide")
		local to = guide and guide:IsA("Beam") and guide.Enabled and guide.Attachment1
		local target = to and to.Parent and to.Parent.Name or "none"
		clientCheck("a guide line leads to the pad to step on next",
			string.sub(target, 1, 4) == "Buy_" or target == "CollectPad", target)
		local shop, nextText = nil, nil
		for _, d in hud:GetDescendants() do
			if d:IsA("TextButton") and d.Text == "Shop" then
				shop = d
			elseif d:IsA("TextLabel") and string.sub(d.Text, 1, 5) == "Next:" then
				nextText = d.Text
			end
		end
		clientCheck("the next purchase and its price are on show", nextText, nextText)
		local view = workspace.CurrentCamera.ViewportSize
		local bottom = shop and shop.AbsolutePosition.Y + shop.AbsoluteSize.Y
		clientCheck("the buttons sit clear of a phone's thumbstick corner", bottom and bottom <= view.Y * 0.62,
			bottom and ("%d of %d px"):format(bottom, view.Y))
		local goalShown, giftText = false, nil
		for _, d in hud:GetDescendants() do
			if d:IsA("TextLabel") and d.Text ~= "" and d.Text == player:GetAttribute("GoalText") then
				goalShown = true
			elseif d:IsA("TextButton") and string.match(d.Text, "^Gift in %d+:%d%d$") then
				giftText = d.Text
			end
		end
		clientCheck("the goal panel shows the current goal", goalShown, player:GetAttribute("GoalText"))
		local card = hud:FindFirstChild("Welcome") :: Frame?
		clientCheck("the welcome card shows on a first visit", card and (card.Visible or player:GetAttribute("Welcome") == false))
		clientCheck("the gift counts down", giftText, giftText)
		game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("ClaimGift"):FireServer()
		clientCheck("a gift claimed early is refused", waitFor(function()
			for _, d in hud:GetDescendants() do
				if d:IsA("TextLabel") and string.sub(d.Text, 1, 21) == "Your gift is ready in" then
					return true
				end
			end
			return false
		end, 4))
		-- sound: every effect and track loads, the music plays, and the setting turns it off
		local SoundService = game:GetService("SoundService")
		local sounds = {}
		for _, d in SoundService:GetChildren() do
			if d:IsA("Sound") and string.sub(d.Name, 1, 8) == "PitLane_" then
				table.insert(sounds, d)
			end
		end
		local unloaded = waitFor(function()
			for _, sound in sounds do
				if not sound.IsLoaded then
					return nil
				end
			end
			return "none"
		end, 20)
		local missing = {}
		for _, sound in sounds do
			if not sound.IsLoaded then
				table.insert(missing, sound.Name)
			end
		end
		clientCheck("every sound and music track loads", #sounds >= 8 and unloaded,
			("%d sounds%s"):format(#sounds, #missing > 0 and (", not loaded: " .. table.concat(missing, " ")) or ""))
		local function playing(): string?
			for _, sound in sounds do
				if string.find(sound.Name, "Music") and sound.IsPlaying then
					return sound.Name
				end
			end
			return nil
		end
		clientCheck("music plays", waitFor(playing, 8), playing())
		local settingsRemote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Settings")
		settingsRemote:FireServer("music", false)
		clientCheck("the music setting turns it off", waitFor(function()
			return player:GetAttribute("MusicOn") == false and not playing()
		end, 5))
		settingsRemote:FireServer("music", true)
		clientCheck("and on again", waitFor(playing, 5))
		local settingsGui = player.PlayerGui:FindFirstChild("PitLaneSettings")
		clientCheck("a settings button sits top left",
			settingsGui and settingsGui:FindFirstChild("SettingsButton") and settingsGui.SettingsButton.AbsolutePosition.X < 80)
		local felt = shop and shop:FindFirstChild("Feel")
		clientCheck("buttons respond to the pointer", felt ~= nil)
		local topBar = hud:FindFirstChild("TopBar") :: Frame?
		local phone = game:GetService("UserInputService").TouchEnabled and not game:GetService("UserInputService").KeyboardEnabled
		clientCheck("the top bar stays clear of the player list", topBar and (phone
			or topBar.AbsolutePosition.X + topBar.AbsoluteSize.X <= view.X - 320), -- the list is about 315 px wide
			topBar and ("right edge %d of %d"):format(topBar.AbsolutePosition.X + topBar.AbsoluteSize.X, view.X))

		for _, delay in { 4, 10, 15 } do -- the server half finishes in about a minute
			task.wait(delay)
			local texts = {}
			for _, d in hud:GetDescendants() do
				if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and d.Visible then
					table.insert(texts, d.Text)
				end
			end
			print(TAG, "CLIENT-HUD " .. table.concat(texts, " | "))
		end
		clientCheck("banking cash shows a +$ pop-up", popUps > 0, popUps)
	end)

	-- the time trial: when the server half says so, take the car, reverse it under throttle,
	-- lap the track along the centre line at 50 studs/s (the server times what it sees), cut
	-- across the infield, then jump out
	task.spawn(function()
		local player = Players.LocalPlayer
		while workspace:GetAttribute("PLT_Drive") ~= true do
			workspace:GetAttributeChangedSignal("PLT_Drive"):Wait()
		end
		local shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		local Config = require(shared:WaitForChild("Config")) :: any
		local TrackShape = require(shared:WaitForChild("TrackShape")) :: any
		game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Drive"):FireServer(true)
		local humanoid = (player.Character :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid
		local seat = waitFor(function()
			local s = humanoid.SeatPart
			return s and s:IsA("VehicleSeat") and s
		end, 8) :: VehicleSeat?
		if not seat then
			clientCheck("the car takes the player", false)
			return
		end
		local car = seat.Parent :: Model
		task.wait(0.5)
		local hud = player.PlayerGui:FindFirstChild("PitLaneHud")
		local leave = false
		for _, d in (hud and hud:GetDescendants() or {}) do
			leave = leave or (d:IsA("TextButton") and d.Text == "Leave car")
		end
		clientCheck("the Race button becomes Leave car", leave)
		local panel = player.PlayerGui:FindFirstChild("PitLaneDrive")
		local frame = panel and panel:FindFirstChildOfClass("Frame")
		clientCheck("the lap panel shows while driving", frame and frame.Visible)

		-- the start: the lights count up on the panel, then GO
		local clockLabel = frame and frame:FindFirstChildOfClass("TextLabel")
		local sawLights = waitFor(function()
			return clockLabel and string.find(clockLabel.Text, "●", 1, true) ~= nil
		end, 3)
		clientCheck("the start lights count down", sawLights, clockLabel and clockLabel.Text)
		clientCheck("then the lights go out: GO", waitFor(function()
			return clockLabel and clockLabel.Text == "GO!"
		end, 6), clockLabel and clockLabel.Text)
		local engineSound = game:GetService("SoundService"):FindFirstChild("PitLane_engine") :: Sound?
		clientCheck("the engine runs", engineSound and engineSound.IsLoaded and engineSound.IsPlaying)

		-- hold the brake (it reverses) for three seconds, after the controls have written theirs
		local hold = RunService.Stepped:Connect(function()
			seat.ThrottleFloat = -1
		end)
		task.wait(2.5)
		local speedLabel = frame and frame:FindFirstChild("Speed") :: TextLabel?
		local reading = speedLabel and tonumber(string.match(speedLabel.Text, "^(%d+) km/h$"))
		clientCheck("the speed shows in km/h", reading and reading > 10, speedLabel and speedLabel.Text)
		task.wait(0.5)
		hold:Disconnect()

		local function place(a: number, off: number)
			local x, z = TrackShape.point(Config.Track, a)
			local tx, tz = TrackShape.tangent(Config.Track, a)
			local at = Vector3.new(x + tz * off, 1.1, z - tx * off)
			car:PivotTo(CFrame.lookAt(at, at + Vector3.new(tx, 0, tz)))
		end
		local a, clockSeen = -0.04, nil
		local function run(to: number, off: number)
			while a < to do
				local dt = RunService.Heartbeat:Wait()
				local x1, z1 = TrackShape.point(Config.Track, a)
				local x2, z2 = TrackShape.point(Config.Track, a + 0.001)
				a += 50 * dt / (math.sqrt((x2 - x1) ^ 2 + (z2 - z1) ^ 2) / 0.001)
				place(a, off)
				local clock = frame and frame:FindFirstChildOfClass("TextLabel")
				if clock and string.match(clock.Text, "^%d:%d%d%.%d%d$") then
					clockSeen = clock.Text
				end
			end
		end
		run(2 * math.pi + 0.5, 0)
		clientCheck("the lap clock runs on screen", clockSeen, clockSeen)
		run(2 * math.pi + 1.2, -30) -- through the infield
		while workspace:GetAttribute("PLT_Drive") ~= false do
			workspace:GetAttributeChangedSignal("PLT_Drive"):Wait()
		end
		humanoid.Sit = false
		humanoid.Jump = true

		-- redeem codes, once the server half has finished checking cash
		task.wait(1)
		local redeem = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Redeem")
		local first = redeem:InvokeServer(" pitlane ")
		clientCheck("a code works in any case and pays", string.match(tostring(first), "^Code PITLANE: %+%$"), first)
		task.wait(1.6)
		local again = redeem:InvokeServer("PitLane")
		clientCheck("a code pays only once", again == "You've already used PITLANE", again)
		task.wait(1.6)
		local wrong = redeem:InvokeServer("NOPE")
		clientCheck("a wrong code is turned down", wrong == "That code doesn't work", wrong)
		clientCheck("players can't read the codes",
			game:GetService("ReplicatedStorage"):FindFirstChild("Codes", true) == nil and (Config :: any).Codes == nil)
	end)
	return
end

-- server: play the game -----------------------------------------------------------------
local okArgs, args = pcall(function()
	return StudioTestService:GetTestArgs()
end)
if not okArgs or type(args) ~= "table" or args.scenario ~= SCENARIO then
	return
end

local checks, errors, warnings = {}, {}, {}
LogService.MessageOut:Connect(function(message, kind)
	if kind == Enum.MessageType.MessageError then
		table.insert(errors, message)
	elseif kind == Enum.MessageType.MessageWarning then
		table.insert(warnings, message)
	end
end)

if SCENARIO == "photo" then
	-- the client takes the pictures; the server keeps the session open long enough, checks
	-- that a garage with every machine earns what the HUD says it earns, and reports any
	-- error from building every machine at once
	local ratio = 0
	-- how hard the server works with every machine running (the photo garage)
	local perf = { step = 0, worst = 0, fps = 0, parts = 0, drops = 0 }
	task.delay(20, function()
		local total, n = 0, 0
		local conn = RunService.Heartbeat:Connect(function(dt)
			total += dt
			n += 1
			perf.worst = math.max(perf.worst, dt)
		end)
		task.wait(10)
		conn:Disconnect()
		perf.step = total / math.max(n, 1)
		perf.fps = workspace:GetRealPhysicsFPS()
		for _, d in workspace:GetDescendants() do
			if d:IsA("BasePart") then
				perf.parts += 1
			end
		end
		for _, model in workspace:WaitForChild("Plots"):GetChildren() do
			perf.drops += #model:WaitForChild("Drops"):GetChildren()
		end
	end)
	task.spawn(function()
		local player = waitFor(function()
			return Players:GetPlayers()[1]
		end, 30)
		task.wait(12)
		local before = player and player:GetAttribute("Pending") or 0
		task.wait(20)
		local perMin = player and player:GetAttribute("IncomePerMin") or 0
		ratio = ((player and player:GetAttribute("Pending") or 0) - before) * 3 / math.max(perMin, 1)
	end)
	task.delay(45, function()
		local ok = ratio > 0.85 and ratio < 1.15
		print(TAG, (ok and "PASS " or "FAIL ") .. ("a full garage earns what the HUD says (%.2f of it)"):format(ratio))
		print(TAG, ("PERF one full garage: server step %.1f ms (worst %.1f), physics %.0f fps, %d parts in the world, %d on the line"):format(
			perf.step * 1000, perf.worst * 1000, perf.fps, perf.parts, perf.drops))
		StudioTestService:EndTest({ passed = ok and 1 or 0, total = 1, errors = errors, warnings = warnings })
	end)
	return
end

local function check(name: string, pass: any, detail: any?)
	local ok = pass and true or false
	table.insert(checks, { name = name, pass = ok, detail = detail and tostring(detail) or nil })
	print(TAG, (ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local function finish()
	local passed = 0
	for _, c in checks do
		if c.pass then
			passed += 1
		end
	end
	StudioTestService:EndTest({
		passed = passed,
		total = #checks,
		checks = checks,
		errors = errors,
		warnings = warnings,
	})
end

local function run()
	local player = waitFor(function()
		return Players:GetPlayers()[1]
	end, 30)
	check("a player joins", player)
	if not player then
		return
	end

	local plotsFolder = workspace:FindFirstChild("Plots")
	check("six garages around the spawn", plotsFolder and #plotsFolder:GetChildren() == 6,
		plotsFolder and #plotsFolder:GetChildren())

	local plot = waitFor(function()
		for _, model in (plotsFolder and plotsFolder:GetChildren() or {}) do
			local sign = model:FindFirstChild("Sign")
			local board = sign and sign:FindFirstChildOfClass("BillboardGui")
			local text = board and board:FindFirstChildOfClass("TextLabel")
			if text and text.Text == player.DisplayName .. "'s garage" then
				return model
			end
		end
		return nil
	end, 15)
	check("a garage with the player's name", plot)
	if not plot then
		return
	end
	-- the garage builds itself: free plots are building sites, the player's grows with purchases
	local function has(model: Instance, name: string): boolean
		local garage = model:FindFirstChild("Garage")
		return garage ~= nil and garage:FindFirstChild(name) ~= nil
	end
	local free = nil
	for _, model in plotsFolder:GetChildren() do
		if model ~= plot then
			free = model
		end
	end
	check("a free plot is a building site", free and has(free, "Scaffold") and has(free, "Fence") and has(free, "Cones")
		and has(free, "SiteSign") and not has(free, "BackWall"))
	check("a new team starts on a building site too", has(plot, "Cones") and not has(plot, "Floor"))
	check("a first-season garage has the day look", plot:GetAttribute("Theme") == "day", plot:GetAttribute("Theme"))

	local ls = waitFor(function()
		return player:FindFirstChild("leaderstats")
	end, 5)
	local cash = ls and ls:FindFirstChild("Cash")
	check("leaderstats show Cash", cash)
	if not cash then
		return
	end
	-- weekend happy hour doubles income; the test can land in it
	local happy = workspace:GetAttribute("HappyHour")
	local x = happy and 2 or 1
	check("the happy-hour flag is set", typeof(happy) == "boolean", happy)
	check("income starts at $60/min", player:GetAttribute("IncomePerMin") == 60 * x, player:GetAttribute("IncomePerMin"))
	check("no friends boost when playing alone", player:GetAttribute("FriendBoost") == 0, player:GetAttribute("FriendBoost"))
	local board = workspace:FindFirstChild("Leaderboard")
	local boardGui = board and board:FindFirstChildOfClass("SurfaceGui")
	check("the leaderboard explains it needs publishing", boardGui and waitFor(function()
		for _, label in boardGui:GetChildren() do
			if label:IsA("TextLabel") and string.find(label.Text, "published") then
				return true
			end
		end
		return false
	end, 10))
	check("first press is built", plot.Items:FindFirstChild("press1"))
	check("it is a stamping press with a die", plot.Items:FindFirstChild("Die"))
	check("and makes bolts, not plain cubes", waitFor(function()
		for _, drop in plot.Drops:GetChildren() do
			if math.abs((drop :: BasePart).Size.X - 0.9) < 0.01 then
				return true
			end
		end
		return false
	end, 6))
	check("the next purchase is published", player:GetAttribute("NextKey") == "press2"
		and player:GetAttribute("NextCost") == 60, player:GetAttribute("NextKey"))
	check("the analytics funnel logs the join", player:GetAttribute("FunnelStep") == 1, player:GetAttribute("FunnelStep"))
	check("a new player gets the welcome card", player:GetAttribute("Welcome") == true, player:GetAttribute("Welcome"))
	check("the first goal is to bank cash", player:GetAttribute("GoalText") == "Bank your first cash",
		player:GetAttribute("GoalText"))
	local giftIn = (player:GetAttribute("GiftAt") or 0) - workspace:GetServerTimeNow()
	check("the first gift is ten minutes away", giftIn > 540 and giftIn <= 600, math.floor(giftIn))

	local character = waitFor(function()
		local c = player.Character
		return c and c:FindFirstChild("HumanoidRootPart") and c
	end, 30)
	check("character spawns", character)
	if not character then
		return
	end
	task.wait(2)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
	local base = plot:FindFirstChild("Base") :: BasePart
	local distance = (root.Position - base.Position).Magnitude
	check("character lands on its own garage", distance < 40, math.floor(distance))

	local function standOn(partName: string): BasePart?
		local target = plot:FindFirstChild(partName) :: BasePart?
		if not target then
			return nil
		end
		character:PivotTo(base.CFrame * CFrame.new(0, 4, -22)) -- step off first
		task.wait(0.6)
		character:PivotTo(target.CFrame * CFrame.new(0, 3, 0))
		task.wait(1.2)
		return target
	end

	check("a part drops within 4 seconds", waitFor(function()
		return #plot.Drops:GetChildren() > 0
	end, 4))
	check("parts reach scrutineering", waitFor(function()
		return (player:GetAttribute("Pending") or 0) > 0
	end, 15), player:GetAttribute("Pending"))
	-- left to Roblox, a part near a player is simulated on that player's computer
	local clientOwned = 0
	for _ = 1, 10 do
		for _, d in plot.Drops:GetChildren() do
			if d:IsA("BasePart") and d:GetNetworkOwner() ~= nil then
				clientOwned += 1
			end
		end
		task.wait(0.3)
	end
	check("the server moves every part on the line", clientOwned == 0, clientOwned)

	-- a new part can land while we walk, so only the bank balance is checked
	local before = cash.Value
	local pending = player:GetAttribute("Pending") or 0
	standOn("CollectPad")
	check("the blue pad banks the cash", cash.Value >= before + pending,
		("cash %d -> %d, pending %d"):format(before, cash.Value, pending))

	check("banking meets the first goal and shows the next", waitFor(function()
		return player:GetAttribute("GoalText") == "Buy 2 machines"
	end, 3), player:GetAttribute("GoalText"))

	local function earn(amount: number)
		local t0 = os.clock()
		while cash.Value < amount and os.clock() - t0 < 120 do
			task.wait(4)
			standOn("CollectPad")
		end
	end
	-- earn enough for the second press if the daily reward did not cover it
	earn(60)
	check("$60 earned for the Bracket press", cash.Value >= 60, cash.Value)

	local pad2 = plot:FindFirstChild("Buy_press2") :: BasePart
	check("the Bracket press pad is lit", pad2 and pad2.Transparency == 0 and pad2.CanTouch)
	local cashBefore = cash.Value
	standOn("Buy_press2")
	check("stepping on the red pad buys it", waitFor(function()
		return plot.Items:FindFirstChild("press2")
	end, 3))
	check("it cost $60", cash.Value <= cashBefore - 60 + 15, ("%d -> %d"):format(cashBefore, cash.Value))
	check("income rises to $210/min", player:GetAttribute("IncomePerMin") == 210 * x, player:GetAttribute("IncomePerMin"))
	check("the funnel logs the first purchase", player:GetAttribute("FunnelStep") == 2, player:GetAttribute("FunnelStep"))
	check("buying a machine puts the welcome card away", waitFor(function()
		return player:GetAttribute("Welcome") == false
	end, 3))
	check("the first purchase lays the garage floor and clears the cones", waitFor(function()
		return has(plot, "Floor") and not has(plot, "Cones")
	end, 3))
	local pad3 = plot:FindFirstChild("Buy_speed1") :: BasePart
	check("the next pad lights up", pad3 and pad3.Transparency == 0 and pad3.CanTouch)
	check("the bought pad goes dark", pad2.Transparency == 1 and not pad2.CanTouch)
	check("the next purchase moves on", player:GetAttribute("NextKey") == "speed1", player:GetAttribute("NextKey"))

	if cash.Value < 150 then
		standOn("Buy_speed1")
		task.wait(1)
		check("a pad you cannot afford does not sell", player:GetAttribute("NextKey") == "speed1"
			and pad3.Transparency == 0, cash.Value)
	end

	earn(150)
	standOn("Buy_speed1")
	check("the faster conveyor is bought", waitFor(function()
		return player:GetAttribute("NextKey") == "press3"
	end, 3), player:GetAttribute("NextKey"))
	check("two machines meet that goal; next, drive a lap", waitFor(function()
		return player:GetAttribute("GoalText") == "Drive a clean lap"
	end, 3), player:GetAttribute("GoalText"))
	check("the second raises the back wall and takes the scaffolding down", waitFor(function()
		return has(plot, "BackWall") and not has(plot, "Scaffold")
	end, 3))
	-- 9 -> 14 studs/s runs both presses 14/9 as fast: $210/min becomes $326/min
	check("a faster conveyor speeds every press up", player:GetAttribute("IncomePerMin") == math.floor(210 * 14 / 9 * x),
		player:GetAttribute("IncomePerMin"))

	-- the time trial: the client half takes the car, reverses, laps and jumps out
	local track = workspace:FindFirstChild("Track")
	check("a time-trial track rings the paddock", track and #track:GetChildren() > 300, track and #track:GetChildren())
	local showCar = plot.Items:FindFirstChild("ShowCar")
	check("the show car offers a drive", showCar and showCar:FindFirstChildWhichIsA("ProximityPrompt", true))
	check("a fastest-laps board stands at the spawn", workspace:FindFirstChild("LapBoard"))
	local shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local trackModule = shared:FindFirstChild("TrackShape")
	if not (trackModule and track) then
		return -- a build without the time trial: the checks above have failed it
	end
	local TrackShape = require(trackModule) :: any
	local trackShape = (require(shared:WaitForChild("Config")) :: any).Track
	local cashBeforeLap = cash.Value
	workspace:SetAttribute("PLT_Drive", true)
	local car = waitFor(function()
		local cars = workspace:FindFirstChild("RaceCars")
		return cars and cars:FindFirstChild("Car_" .. player.UserId)
	end, 10)
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	check("Race puts the player in their own car on the grid", car and waitFor(function()
		return humanoid.SeatPart and humanoid.SeatPart:IsDescendantOf(car)
	end, 6))
	local chassis = car and car.PrimaryPart
	check("the player's computer drives it", chassis and chassis:GetNetworkOwner() == player)
	if chassis then
		local from = chassis.Position
		task.wait(9) -- the start lights hold the car about four seconds first
		local moved = (chassis.Position - from).Magnitude
		check("the pedals move the car (it reverses under the brake)", moved > 15, math.floor(moved))
	end
	check("crossing the line starts the clock", waitFor(function()
		return (player:GetAttribute("LapStart") or 0) > 0
	end, 15))
	local lap = waitFor(function()
		return player:GetAttribute("LastLap")
	end, 45)
	local expect = TrackShape.length(trackShape) / 50
	check("a clean lap is timed by the server", lap and math.abs(lap - expect) / expect < 0.05,
		lap and ("%.2f s, expected %.2f"):format(lap, expect))
	check("a clean lap pays", cash.Value > cashBeforeLap, ("%d -> %d"):format(cashBeforeLap, cash.Value))
	check("and becomes the best lap", lap and player:GetAttribute("BestLap") == lap, player:GetAttribute("BestLap"))
	check("a clean lap meets the lap goal", waitFor(function()
		return player:GetAttribute("GoalText") == "Buy 5 machines"
	end, 3), player:GetAttribute("GoalText"))
	check("cutting across the infield voids the lap", waitFor(function()
		return player:GetAttribute("LapValid") == false
	end, 20), player:GetAttribute("LapProblem"))
	workspace:SetAttribute("PLT_Drive", false)
	check("jumping out puts the player back at their garage", waitFor(function()
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		return car and not car.Parent and root and (root.Position - base.Position).Magnitude < 40
	end, 10))
	local cashBeforeCode = cash.Value
	check("redeeming a code pays", waitFor(function()
		return cash.Value >= cashBeforeCode + 250
	end, 10), ("%d -> %d"):format(cashBeforeCode, cash.Value))

	-- the game's own warnings: a failing analytics call or save warns once
	local own = {}
	for _, message in warnings do
		if string.find(message, "[PitLane]", 1, true) then
			table.insert(own, message)
		end
	end
	check("the game logged no warnings of its own", #own == 0, own[1])

	-- leave the character somewhere visible for a screenshot
	character:PivotTo(base.CFrame * CFrame.new(-8, 4, -14) * CFrame.Angles(0, math.rad(200), 0))
	print(TAG, "SHOT")
	task.wait(6)
end

task.spawn(function()
	local ok, err = pcall(run)
	if not ok then
		check("the test itself ran without crashing", false, err)
	end
	finish()
end)
