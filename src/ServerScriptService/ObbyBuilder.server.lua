--!strict

local Workspace = game:GetService("Workspace")

local OBBY_FOLDER = Instance.new("Folder")
OBBY_FOLDER.Name = "ObbyCourse"
OBBY_FOLDER.Parent = Workspace

local OBSTACLE_FOLDER = Instance.new("Folder")
OBSTACLE_FOLDER.Name = "Obstacles"
OBSTACLE_FOLDER.Parent = OBBY_FOLDER

local CHECKPOINT_FOLDER = Instance.new("Folder")
CHECKPOINT_FOLDER.Name = "Checkpoints"
CHECKPOINT_FOLDER.Parent = OBBY_FOLDER

-- ── Color theme ──────────────────────────────────────────────────────────────

local COLORS = {
	Primary = Color3.fromRGB(175, 50, 255),
	Secondary = Color3.fromRGB(0, 200, 255),
	Accent = Color3.fromRGB(255, 50, 100),
	Finish = Color3.fromRGB(255, 215, 0),
	Checkpoint = Color3.fromRGB(0, 255, 100),
	Platform1 = Color3.fromRGB(100, 50, 200),
	Platform2 = Color3.fromRGB(50, 150, 255),
	Platform3 = Color3.fromRGB(200, 50, 150),
	Beam = Color3.fromRGB(255, 100, 50),
	Danger = Color3.fromRGB(200, 30, 30),
	Start = Color3.fromRGB(50, 200, 100),
}

-- ── Part helpers ─────────────────────────────────────────────────────────────

local function createPart(
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material?,
	canCollide: boolean?,
	parent: Instance?
): Part
	local part = Instance.new("Part")
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = if canCollide == nil then true else canCollide
	part.Parent = parent or OBSTACLE_FOLDER
	return part
end

local function createWedge(
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material?,
	parent: Instance?
): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Size = size
	wedge.Position = position
	wedge.Color = color
	wedge.Material = material or Enum.Material.SmoothPlastic
	wedge.Anchored = true
	wedge.CanCollide = true
	wedge.Parent = parent or OBSTACLE_FOLDER
	return wedge
end

local function createCheckpoint(index: number, position: Vector3): Part
	local part = Instance.new("Part")
	part.Size = Vector3.new(10, 0.5, 10)
	part.Position = position
	part.Color = COLORS.Checkpoint
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 0.7
	part.Name = "Checkpoint_" .. tostring(index)
	part.Parent = CHECKPOINT_FOLDER

	-- Add a checkmark decal
	local decal = Instance.new("Decal")
	decal.Face = Enum.NormalId.Top
	decal.Texture = "rbxasset://textures/face/checkmark.png"
	decal.Parent = part

	return part
end

local function createFinishPart(position: Vector3): Part
	local part = Instance.new("Part")
	part.Size = Vector3.new(20, 0.5, 20)
	part.Position = position
	part.Color = COLORS.Finish
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = true
	part.Transparency = 0.3
	part.Name = "FinishTrigger"
	part.Parent = OBBY_FOLDER

	-- Glow effect via particle emitter
	local attachment = Instance.new("Attachment")
	attachment.Parent = part

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 20
	emitter.Lifetime = NumberRange.new(1, 2)
	emitter.Speed = NumberRange.new(2, 5)
	emitter.Color = ColorSequence.new(COLORS.Finish)
	emitter.Enabled = true
	emitter.Parent = attachment

	return part
end

-- ── Section 1: Start Platform ───────────────────────────────────────────────

local function buildStartPlatform(): Vector3
	local startPos = Vector3.new(-70, 0, 0)

	-- Main start platform
	createPart(Vector3.new(20, 1, 20), startPos, COLORS.Start, Enum.Material.Grass)

	-- Decorative edge glow
	createPart(Vector3.new(22, 0.2, 22), Vector3.new(-70, 0.6, 0), COLORS.Secondary, Enum.Material.Neon, true, OBBY_FOLDER)

	-- Directional arrows on the ground (using cylinder parts)
	for i = -8, 8, 4 do
		local arrowHead = Instance.new("Part")
		arrowHead.Size = Vector3.new(2, 0.1, 2)
		arrowHead.Position = Vector3.new(-70 + i, 0.55, 0)
		arrowHead.Color = COLORS.Secondary
		arrowHead.Material = Enum.Material.Neon
		arrowHead.Anchored = true
		arrowHead.CanCollide = false
		arrowHead.Shape = Enum.PartType.Cylinder
		arrowHead.Parent = OBBY_FOLDER
	end

	return startPos
end

-- ── Section 2: Simple Jumps ─────────────────────────────────────────────────

local function buildSimpleJumps()
	local startX = -58
	local numPlatforms = 5

	for i = 1, numPlatforms do
		local width = math.max(8 - (i * 0.8), 3)
		local depth = math.max(4 - (i * 0.3), 2)
		local yOffset = (i - 1) * 2.5
		local xPos = startX + (i - 1) * 7
		local color = if i % 2 == 0 then COLORS.Platform1 else COLORS.Platform2

		createPart(Vector3.new(width, 0.5, depth), Vector3.new(xPos, 1 + yOffset, 0), color)

		-- Neon edge glow
		createPart(Vector3.new(width + 1, 0.1, depth + 1), Vector3.new(xPos, 1.25 + yOffset, 0), COLORS.Secondary, Enum.Material.Neon, false)

		-- Checkpoint at platform 3 (middle)
		if i == 3 then
			createCheckpoint(1, Vector3.new(xPos, 1 + yOffset + 2, 0))
		end
	end
end

-- ── Section 3: Moving Platforms ─────────────────────────────────────────────

local function buildMovingPlatforms()
	local movingData: { { Platform: Part, BodyPosition: BodyPosition, Direction: number, Speed: number, Range: number, StartZ: number } } = {}
	local startX = -20

	for i = 1, 3 do
		local platform = Instance.new("Part")
		platform.Size = Vector3.new(6, 0.5, 4)
		platform.Position = Vector3.new(startX + (i - 1) * 10, 9, 0)
		platform.Color = COLORS.Accent
		platform.Material = Enum.Material.Neon
		platform.Anchored = false
		platform.CanCollide = true
		platform.Name = "MovingPlatform_" .. tostring(i)
		platform.Parent = OBSTACLE_FOLDER

		-- BodyPosition to move it back and forth
		local bodyPos = Instance.new("BodyPosition")
		bodyPos.MaxForce = Vector3.new(0, 0, 4000)
		bodyPos.P = 2000
		bodyPos.D = 100
		bodyPos.Position = platform.Position
		bodyPos.Parent = platform

		local data = {
			Platform = platform,
			BodyPosition = bodyPos,
			Direction = 1,
			Speed = 3 + i * 0.5,
			Range = 8 + i * 2,
			StartZ = platform.Position.Z,
		}

		table.insert(movingData, data)
	end

	-- Move platforms each frame
	local function movePlatforms(dt: number)
		for _, data in movingData do
			local newZ = data.BodyPosition.Position.Z + data.Direction * data.Speed * dt
			if math.abs(newZ - data.StartZ) > data.Range then
				data.Direction *= -1
				newZ = data.StartZ + data.Direction * data.Range
			end
			data.BodyPosition.Position = Vector3.new(data.Platform.Position.X, data.Platform.Position.Y, newZ)
		end
	end

	return movePlatforms
end

-- ── Section 4: Tricky Section ───────────────────────────────────────────────

local function buildTrickySection()
	-- Thin beam walk
	for i = 0, 4 do
		createPart(Vector3.new(8, 0.3, 1), Vector3.new(5 + i * 5, 13, 0), COLORS.Beam, Enum.Material.Wood)
	end

	-- Checkpoint after beams
	createCheckpoint(2, Vector3.new(27, 13, 0))

	-- Rising wall jumps (wedges going up)
	for i = 0, 4 do
		local yPos = 14 + i * 2.5
		createWedge(Vector3.new(4, 3, 3), Vector3.new(32 + i * 5, yPos, 0), COLORS.Platform3)
		-- Small platform beside each wedge
		createPart(Vector3.new(3, 0.5, 3), Vector3.new(34 + i * 5, yPos + 1.5, 4), COLORS.Platform1)
	end

	-- Checkpoint after wall jumps
	createCheckpoint(3, Vector3.new(52, 26, 0))
end

-- ── Section 5: Crumbling Platform Run ──────────────────────────────────────

local function buildCrumblingRun()
	for i = 0, 9 do
		local platform = Instance.new("Part")
		platform.Size = Vector3.new(3, 0.5, 4)
		platform.Position = Vector3.new(35 + i * 3, 28, 0)
		platform.Color = COLORS.Danger
		platform.Material = Enum.Material.SmoothPlastic
		platform.Anchored = true
		platform.CanCollide = true
		platform.Name = "CrumblingPlatform_" .. tostring(i)
		platform.Parent = OBSTACLE_FOLDER

		-- Add a slight zigzag offset for visual variety
		local zOffset = (i % 3 - 1) * 2
		platform.Position = Vector3.new(35 + i * 3, 28, zOffset)
	end
end

-- ── Section 6: Finish Area ─────────────────────────────────────────────────

local function buildFinishArea()
	local finishPos = Vector3.new(70, 28, 0)

	-- Main finish platform
	createPart(Vector3.new(20, 1, 20), finishPos, COLORS.Finish, Enum.Material.Neon)

	-- Finish trigger
	createFinishPart(Vector3.new(70, 29, 0))

	-- Outer glow ring
	local glowRing = Instance.new("Part")
	glowRing.Size = Vector3.new(24, 0.2, 24)
	glowRing.Position = Vector3.new(70, 28.5, 0)
	glowRing.Color = COLORS.Secondary
	glowRing.Material = Enum.Material.Neon
	glowRing.Anchored = true
	glowRing.CanCollide = false
	glowRing.Shape = Enum.PartType.Cylinder
	glowRing.Parent = OBBY_FOLDER

	-- "FRANK THE TANK" BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "FrankTheTank"
	billboard.Size = UDim2.fromOffset(400, 100)
	billboard.StudsOffset = Vector3.new(0, 10, 0)
	billboard.AlwaysOnTop = true
	billboard.Enabled = true
	billboard.ClipsDescendants = false
	billboard.Parent = OBBY_FOLDER

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "FRANK THE TANK"
	textLabel.TextColor3 = COLORS.Finish
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextStrokeTransparency = 0.3
	textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	textLabel.Parent = billboard

	-- Subtitle label
	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, 0, 0, 40)
	subtitle.Position = UDim2.fromScale(0, 1)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "OBBY CHAMPION"
	subtitle.TextColor3 = COLORS.Secondary
	subtitle.TextScaled = true
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextStrokeTransparency = 0.5
	subtitle.Parent = billboard

	-- Firework cannons (particle emitters around the finish)
	for angle = 0, 360, 60 do
		local rad = math.rad(angle)
		local x = 70 + 12 * math.cos(rad)
		local z = 12 * math.sin(rad)

		local cannon = Instance.new("Part")
		cannon.Size = Vector3.new(1, 1, 1)
		cannon.Position = Vector3.new(x, 28, z)
		cannon.Color = COLORS.Secondary
		cannon.Material = Enum.Material.Neon
		cannon.Anchored = true
		cannon.CanCollide = false
		cannon.Shape = Enum.PartType.Cylinder
		cannon.Name = "FireworkCannon"
		cannon.Parent = OBBY_FOLDER

		local attachment = Instance.new("Attachment")
		attachment.Parent = cannon

		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Rate = 5
		emitter.Lifetime = NumberRange.new(2, 4)
		emitter.Speed = NumberRange.new(5, 15)
		emitter.SpreadAngle = Vector2.new(30, 30)
		emitter.Color = ColorSequence.new(COLORS.Finish)
		emitter.Enabled = true
		emitter.Parent = attachment
	end
end

-- ── Death Zone ──────────────────────────────────────────────────────────────

local function buildDeathZone()
	-- Create a large invisible part below the course
	local deathPart = Instance.new("Part")
	deathPart.Size = Vector3.new(500, 1, 200)
	deathPart.Position = Vector3.new(0, -15, 0)
	deathPart.Transparency = 1
	deathPart.Anchored = true
	deathPart.CanCollide = false
	deathPart.Name = "DeathZone"
	deathPart.Parent = OBBY_FOLDER
end

-- ── Build everything ─────────────────────────────────────────────────────────

export type MovePlatformFn = (dt: number) -> ()

local function build(): MovePlatformFn
	buildStartPlatform()
	buildSimpleJumps()
	local movePlatforms = buildMovingPlatforms()
	buildTrickySection()
	buildCrumblingRun()
	buildFinishArea()
	buildDeathZone()

	return movePlatforms
end

return {
	build = build,
	Folder = OBBY_FOLDER,
	CheckpointFolder = CHECKPOINT_FOLDER,
	Colors = COLORS,
}
