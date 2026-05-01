--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local ObbyGameLogic = {}

-- ── Types ───────────────────────────────────────────────────────────────────

export type PlayerData = {
	Timer: number?,
	TimerActive: boolean,
	LastCheckpoint: Vector3?,
	Finished: boolean,
	BestTime: number?,
	TimerGui: BillboardGui?,
	StartTime: number?,
}

-- ── State ───────────────────────────────────────────────────────────────────

local playerDataMap: { [Player]: PlayerData } = {}
local checkpointParts: { Part } = {}
local finishPart: Part? = nil
local fallThreshold: number = -10

-- ── Timer BillboardGui ──────────────────────────────────────────────────────

local function createTimerGui(): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 50)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = true
	gui.Enabled = false
	gui.ClipsDescendants = false

	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.new(0, 0, 0)
	background.BackgroundTransparency = 0.5
	background.BorderSizePixel = 0
	background.Parent = gui

	local timerLabel = Instance.new("TextLabel")
	timerLabel.Size = UDim2.fromScale(1, 1)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Text = "0.00s"
	timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	timerLabel.TextScaled = true
	timerLabel.Font = Enum.Font.GothamBold
	timerLabel.Parent = background

	return gui
end

-- ── Checkpoint system ───────────────────────────────────────────────────────

local function findCheckpoints()
	checkpointParts = {}
	local obbyFolder = Workspace:FindFirstChild("ObbyCourse")
	if not obbyFolder then
		warn("ObbyGameLogic: ObbyCourse folder not found")
		return
	end

	local cpFolder = obbyFolder:FindFirstChild("Checkpoints")
	if not cpFolder then
		warn("ObbyGameLogic: Checkpoints folder not found")
		return
	end

	for _, child in cpFolder:GetChildren() do
		if child:IsA("Part") and string.match(child.Name, "^Checkpoint_") then
			table.insert(checkpointParts, child :: Part)
			local numberStr = string.gsub(child.Name, "Checkpoint_", "")
			local number = tonumber(numberStr)
			if number then
				child.Transparency = 0.5
				print(
					("ObbyGameLogic: Registered checkpoint %d at (%.1f, %.1f, %.1f)"):format(
						number,
						child.Position.X,
						child.Position.Y,
						child.Position.Z
					)
				)
			end
		end
	end

	-- Sort by name (index)
	table.sort(checkpointParts, function(a: Part, b: Part): boolean
		local numA = tonumber(string.gsub(a.Name, "Checkpoint_", "")) or 0
		local numB = tonumber(string.gsub(b.Name, "Checkpoint_", "")) or 0
		return numA < numB
	end)

	print(("ObbyGameLogic: Found %d checkpoints"):format(#checkpointParts))
end

local function findFinishPart(): Part?
	local obbyFolder = Workspace:FindFirstChild("ObbyCourse")
	if not obbyFolder then
		return nil
	end
	return obbyFolder:FindFirstChild("FinishTrigger") :: Part?
end

-- ── Player data ─────────────────────────────────────────────────────────────

local function getPlayerData(player: Player): PlayerData
	local data = playerDataMap[player]
	if not data then
		data = {
			Timer = 0,
			TimerActive = false,
			LastCheckpoint = nil,
			Finished = false,
			BestTime = nil,
			TimerGui = nil,
			StartTime = nil,
		}
		playerDataMap[player] = data
	end
	return data
end

-- ── Timer ────────────────────────────────────────────────────────────────────

local function startTimer(player: Player, data: PlayerData)
	if data.Finished then
		return
	end

	data.TimerActive = true
	data.StartTime = os.clock()
	data.Timer = 0

	-- Create and attach timer GUI
	local gui = createTimerGui()
	gui.Parent = player:FindFirstChildOfClass("Model")
	gui.Enabled = true
	data.TimerGui = gui

	print(("Timer started for %s"):format(player.Name))
end

local function stopTimer(player: Player, data: PlayerData): number
	data.TimerActive = false
	local finalTime = 0

	if data.StartTime then
		finalTime = os.clock() - data.StartTime
	end

	data.Timer = finalTime

	-- Update best time
	if not data.BestTime or finalTime < data.BestTime then
		data.BestTime = finalTime
	end

	-- Remove timer GUI
	if data.TimerGui then
		data.TimerGui.Enabled = false
		Debris:AddItem(data.TimerGui, 0.5)
		data.TimerGui = nil
	end

	print(("Timer stopped for %s: %.2fs"):format(player.Name, finalTime))
	return finalTime
end

-- ── Fall handling ───────────────────────────────────────────────────────────

local function onPlayerFall(player: Player, data: PlayerData)
	if data.Finished then
		return
	end

	print(("%s fell off the course!"):format(player.Name))

	-- Respawn at last checkpoint or spawn
	local spawnPosition = data.LastCheckpoint or Vector3.new(-70, 3, 0)
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if humanoid and rootPart then
			humanoid:TakeDamage(humanoid.Health) -- kill to respawn
		elseif rootPart then
			rootPart.Position = spawnPosition
		end
	end
end

local function setupFallDetection()
	RunService.Heartbeat:Connect(function(_dt: number)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if not character then
				continue
			end

			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
			if not humanoidRootPart then
				continue
			end

			local pos = humanoidRootPart.Position
			if pos.Y < fallThreshold then
				local data = getPlayerData(player)
				onPlayerFall(player, data)
			end
		end
	end)
end

-- ── Fireworks ───────────────────────────────────────────────────────────────

local function spawnFireworks(position: Vector3)
	-- Create a burst of colored parts that fly up and fade
	for _ = 1, 10 do
		local firework = Instance.new("Part")
		firework.Size = Vector3.new(0.5, 0.5, 0.5)
		firework.Shape = Enum.PartType.Ball
		firework.Anchored = false
		firework.CanCollide = false
		firework.Color = Color3.fromHSV(math.random(), 0.8, 1)
		firework.Material = Enum.Material.Neon
		firework.Position = position + Vector3.new((math.random() - 0.5) * 5, 0, (math.random() - 0.5) * 5)
		firework.Parent = workspace

		-- Apply upward velocity
		local bv = Instance.new("BodyVelocity")
		bv.MaxForce = Vector3.new(0, 4000, 0)
		bv.Velocity = Vector3.new((math.random() - 0.5) * 30, 40 + math.random() * 20, (math.random() - 0.5) * 30)
		bv.Parent = firework

		-- Fade and destroy
		task.delay(3, function()
			firework:Destroy()
		end)
	end
end

-- ── Finish ────────────────────────────────────────────────────────────────────

local function onPlayerFinish(player: Player, data: PlayerData)
	if data.Finished then
		return
	end

	data.Finished = true
	local finalTime = stopTimer(player, data)

	-- Broadcast finish message
	local message = ("%s finished the course in %.2f seconds!"):format(player.Name, finalTime)
	if data.BestTime then
		message ..= (" (Best: %.2fs)"):format(data.BestTime)
	end

	print(message)

	-- Flash the FRANK THE TANK text
	local obbyFolder = Workspace:FindFirstChild("ObbyCourse")
	if obbyFolder then
		local billboard = obbyFolder:FindFirstChild("FrankTheTank") :: BillboardGui?
		if billboard then
			local textLabel = billboard:FindFirstChildOfClass("TextLabel")
			if textLabel then
				textLabel.Text = ("FRANK THE TANK \\n%.2fs!"):format(finalTime)
				textLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
			end
		end
	end

	-- Spawn celebration fireworks
	local finishPos = Vector3.new(90, 29, 0)
	spawnFireworks(finishPos)

	-- Respawn player at start for another go
	task.delay(3, function()
		data.Finished = false
		data.TimerActive = false
		data.LastCheckpoint = nil
		data.StartTime = nil

		local character = player.Character
		if character then
			character:MoveTo(Vector3.new(-70, 3, 0))
		end
	end)
end

-- ── Touch connections ───────────────────────────────────────────────────────

local function setupTouchConnections()
	-- Checkpoint touches
	for _, checkpoint in checkpointParts do
		checkpoint.Touched:Connect(function(hit: BasePart)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player then
				return
			end

			local data = getPlayerData(player)
			if data.Finished then
				return
			end

			-- Update last checkpoint
			local cpPosition = checkpoint.Position + Vector3.new(0, 3, 0)
			data.LastCheckpoint = cpPosition

			-- Start timer on first checkpoint touch (player has left start)
			if not data.TimerActive then
				startTimer(player, data)
			end

			print(
				("%s reached checkpoint at (%.1f, %.1f, %.1f)"):format(
					player.Name,
					cpPosition.X,
					cpPosition.Y,
					cpPosition.Z
				)
			)
		end)
	end

	-- Finish trigger
	if finishPart then
		finishPart.Touched:Connect(function(hit: BasePart)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player then
				return
			end

			local data = getPlayerData(player)
			onPlayerFinish(player, data)
		end)
	end
end

-- ── Main entry point ────────────────────────────────────────────────────────

function ObbyGameLogic.setup()
	-- Find all game elements
	findCheckpoints()
	finishPart = findFinishPart()

	-- Setup player connections
	setupTouchConnections()
	setupFallDetection()

	-- Handle new players
	Players.PlayerAdded:Connect(function(player: Player)
		getPlayerData(player)
		print(("ObbyGameLogic: Player %s joined"):format(player.Name))
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		playerDataMap[player] = nil
	end)

	-- Handle character added (for respawning)
	Players.CharacterAdded:Connect(function(character: Model)
		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		local data = getPlayerData(player)

		-- If player was in progress but not finished, respawn at checkpoint
		if data.TimerActive and not data.Finished then
			local spawnPos = data.LastCheckpoint or Vector3.new(-70, 3, 0)
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if rootPart then
				rootPart.Position = spawnPos
			end
		end

		-- Re-attach timer GUI
		if data.TimerGui then
			data.TimerGui.Parent = character
		end
	end)

	print("ObbyGameLogic: Setup complete")
end

return ObbyGameLogic
