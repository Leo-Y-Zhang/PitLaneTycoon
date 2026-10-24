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

-- editor: start the play test and print what it returns --------------------------------
if RunService:IsEdit() then
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
	local hud = waitFor(function()
		return player.PlayerGui:FindFirstChild("PitLaneHud")
	end, 30)
	if hud then
		hud.Enabled = false
	end
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
	local base = (plot:FindFirstChild("Base") :: BasePart).CFrame
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = 55
	local shots = {
		{ "hero", base * CFrame.new(-36, 22, -44), base * CFrame.new(4, 2, 6) },
		{ "car", base * CFrame.new(-9, 4.5, 6), base * CFrame.new(2, 1.5, 15) },
		{ "line", base * CFrame.new(-28, 5, -9), base * CFrame.new(14, 2.5, 1) },
		{ "paddock", base * CFrame.new(0, 42, -86), base * CFrame.new(0, 3, 0) },
	}
	for _, shot in shots do
		cam.CFrame = CFrame.lookAt(shot[2].Position, shot[3].Position)
		task.wait(1.5)
		print(TAG, "SHOT " .. shot[1])
		task.wait(2.5)
	end
	print(TAG, "PHOTOS-DONE")
end

-- client: report the HUD and client-side errors -----------------------------------------
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
			print(TAG, "CLIENT-HUD missing")
			return
		end
		for _, delay in { 3, 7, 10 } do -- the server half finishes in about 30 s
			task.wait(delay)
			local texts = {}
			for _, d in hud:GetDescendants() do
				if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and d.Visible then
					table.insert(texts, d.Text)
				end
			end
			print(TAG, "CLIENT-HUD " .. table.concat(texts, " | "))
		end
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
if SCENARIO == "photo" then
	-- the client takes the pictures; the server only keeps the session open long enough
	task.delay(45, function()
		StudioTestService:EndTest({ passed = 0, total = 0, errors = {}, warnings = {} })
	end)
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

	-- a new part can land while we walk, so only the bank balance is checked
	local before = cash.Value
	local pending = player:GetAttribute("Pending") or 0
	standOn("CollectPad")
	check("the blue pad banks the cash", cash.Value >= before + pending,
		("cash %d -> %d, pending %d"):format(before, cash.Value, pending))

	-- earn enough for the second press if the daily reward did not cover it
	local t0 = os.clock()
	while cash.Value < 60 and os.clock() - t0 < 120 do
		task.wait(4)
		standOn("CollectPad")
	end
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
	local pad3 = plot:FindFirstChild("Buy_speed1") :: BasePart
	check("the next pad lights up", pad3 and pad3.Transparency == 0 and pad3.CanTouch)
	check("the bought pad goes dark", pad2.Transparency == 1 and not pad2.CanTouch)

	if cash.Value < 150 then
		standOn("Buy_speed1")
		task.wait(1)
		check("a pad you cannot afford does not sell", not plot.Items:FindFirstChild("speed1")
			and pad3.Transparency == 0, cash.Value)
	end

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
