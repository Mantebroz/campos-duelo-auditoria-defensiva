--!nonstrict
-- LocalScript para StarterPlayerScripts.
-- UI: "Comenzar combate".
--
-- Objetivo: probar el combate automatico del cliente contra bots/combatientes
-- del servidor sin publicar tu logica privada. El script usa los controladores
-- locales existentes del place:
--   GameManager:GetController("CharacterController")
--   GameManager:GetController("PlayerInputController")
--   GameManager:GetController("TargetLockController")
--
-- Puede elegir bots o jugadores reales si el servidor los expone como
-- CustomCharacter/LockAvailableTarget disponibles. El personaje local siempre
-- queda excluido; el servidor sigue decidiendo si la accion procede.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local localPlayer = Players.LocalPlayer
local rng = Random.new()

local CONFIG = {
	MaxTargetDistance = 95,
	RetargetSeconds = 0.35,

	PreferredDistance = 8.25,
	TooCloseDistance = 4.4,
	AttackRange = 9.2,

	ThinkInterval = 1 / 16,
	MinAttackCooldown = 0.24,
	MaxAttackCooldown = 0.82,
	DefenseCooldown = 0.42,
	BlockHoldSeconds = 0.2,

	StrafeSwitchMinSeconds = 0.45,
	StrafeSwitchMaxSeconds = 1.25,
	DodgeInputHoldSeconds = 0.18,

	AutoEquipWeapon = true,
	AllowBotTargets = true,
	AllowPlayerTargets = true,
	AllowUnmarkedServerCombatants = true,

	-- Configuracion de nivel de combate.
	-- ForceCombatLevel = nil usa tu sistema externo. Pon 11 para probar el modo superior.
	ForceCombatLevel = 11,
	DefaultCombatLevel = 11,
	MinCombatLevel = 1,
	MaxCombatLevel = 11,
	PerfectCombatLevel = 11,
	PerfectReactionDelay = 0.012,
	PerfectDefenseCooldown = 0.16,
	PerfectAttackCooldown = 0.18,
	PerfectMoveNoise = 0.005,

	CombatLevelAttributeNames = {
		"CombatLevel",
		"NivelCombate",
		"NivelDeCombate",
	},

	CombatLevelValueNames = {
		"CombatLevel",
		"NivelCombate",
		"NivelDeCombate",
	},

	BotModelAttributes = {
		"IsBot",
		"Bot",
		"NPC",
		"ClientCombatBot",
		"AvailableForClientSparring",
		"DisponibleParaCombateCliente",
		"BotDisponible",
	},

	BotTags = {
		"Bot",
		"NPC",
		"TrainingBot",
		"ClientCombatBot",
	},
}

local ATTACK_ATTRIBUTE_NAMES = {
	"IsAttacking",
	"Attacking",
	"AttackWindup",
	"SwingActive",
	"IncomingAttack",
	"QueuedAttack",
	"CurrentAttack",
	"CurrentAction",
	"ActionState",
	"CombatState",
	"LastAttackAt",
}

local ATTACK_TOKENS = {
	"attack",
	"slash",
	"swing",
	"strike",
	"jab",
	"heavy",
	"light",
	"combo",
	"hit",
	"golpe",
	"ataque",
}

local enabled = false
local controllersReady = false
local statusText = "esperando cliente"

local GameManager = nil
local CharacterController = nil
local PlayerInputController = nil
local TargetLockController = nil

local currentTargetModel = nil
local currentTargetRoot = nil
local nextRetargetAt = 0
local nextAttackAt = 0
local nextDefenseAt = 0
local nextEquipAt = 0
local nextStrafeSwitchAt = 0
local strafeSign = 1
local thinkAccumulator = 0
local defenseSerial = 0

local desiredMoveDirection = Vector3.zero
local dodgeMoveDirection = nil
local dodgeMoveUntil = 0

local screenGui = nil
local toggleButton = nil
local statusLabel = nil
local levelLabel = nil
local targetLabel = nil
local detailLabel = nil

local function clampLevel(value)
	if typeof(value) ~= "number" or value ~= value then
		return CONFIG.DefaultCombatLevel
	end

	return math.clamp(math.floor(value + 0.5), CONFIG.MinCombatLevel, CONFIG.MaxCombatLevel)
end

local function readNumberValue(container, names)
	if not container then
		return nil
	end

	for _, name in ipairs(names) do
		local child = container:FindFirstChild(name)
		if child and (child:IsA("NumberValue") or child:IsA("IntValue")) then
			return child.Value
		end
	end

	return nil
end

local function readCombatLevel()
	if CONFIG.ForceCombatLevel ~= nil then
		return clampLevel(CONFIG.ForceCombatLevel)
	end

	for _, attributeName in ipairs(CONFIG.CombatLevelAttributeNames) do
		local value = localPlayer:GetAttribute(attributeName)
		if typeof(value) == "number" then
			return clampLevel(value)
		end
	end

	local directValue = readNumberValue(localPlayer, CONFIG.CombatLevelValueNames)
	if directValue then
		return clampLevel(directValue)
	end

	local leaderstats = localPlayer:FindFirstChild("leaderstats")
	local statsValue = readNumberValue(leaderstats, CONFIG.CombatLevelValueNames)
	if statsValue then
		return clampLevel(statsValue)
	end

	return clampLevel(CONFIG.DefaultCombatLevel)
end

local function isPerfectLevel(level)
	return CONFIG.PerfectCombatLevel ~= nil and level >= CONFIG.PerfectCombatLevel
end

local function levelAlpha(level)
	if isPerfectLevel(level) then
		return 1
	end

	return (math.clamp(level, 1, 10) - 1) / 9
end

local function lerpNumber(a, b, t)
	return a + (b - a) * math.clamp(t, 0, 1)
end

local function flatUnit(vector)
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude <= 0.001 then
		return Vector3.zero
	end

	return flat.Unit
end

local function noisyDirection(direction, level)
	if direction.Magnitude <= 0 then
		return direction
	end

	local alpha = levelAlpha(level)
	local maxNoise = lerpNumber(0.42, 0.055, alpha)
	local mistakeChance = lerpNumber(0.3, 0.055, alpha)

	if isPerfectLevel(level) then
		maxNoise = CONFIG.PerfectMoveNoise
		mistakeChance = 0
	end

	if rng:NextNumber() < mistakeChance then
		maxNoise *= 2.1
	end

	local noise = Vector3.new(rng:NextNumber(-maxNoise, maxNoise), 0, rng:NextNumber(-maxNoise, maxNoise))
	local result = direction + noise
	if result.Magnitude <= 0.001 then
		return direction
	end

	return result.Unit
end

local function createLabel(parent, name, text, height, textSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, height)
	label.Font = Enum.Font.Gotham
	label.Text = text
	label.TextColor3 = Color3.fromRGB(235, 240, 245)
	label.TextSize = textSize or 13
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function createUi()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("ComenzarCombate")
	if existing then
		existing:Destroy()
	end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ComenzarCombate"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Position = UDim2.fromOffset(16, 232)
	panel.Size = UDim2.fromOffset(270, 166)
	panel.BackgroundColor3 = Color3.fromRGB(19, 24, 31)
	panel.BorderSizePixel = 0
	panel.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(72, 86, 102)
	stroke.Thickness = 1
	stroke.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = panel

	toggleButton = Instance.new("TextButton")
	toggleButton.Name = "ComenzarCombateButton"
	toggleButton.Size = UDim2.new(1, 0, 0, 36)
	toggleButton.BackgroundColor3 = Color3.fromRGB(49, 116, 82)
	toggleButton.BorderSizePixel = 0
	toggleButton.Font = Enum.Font.GothamBold
	toggleButton.Text = "Comenzar combate"
	toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggleButton.TextSize = 14
	toggleButton.LayoutOrder = 1
	toggleButton.Parent = panel

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 6)
	buttonCorner.Parent = toggleButton

	statusLabel = createLabel(panel, "Estado", "Estado: OFF", 18, 13)
	statusLabel.LayoutOrder = 2

	levelLabel = createLabel(panel, "Nivel", "Nivel combate: 5/11", 18, 13)
	levelLabel.LayoutOrder = 3

	targetLabel = createLabel(panel, "Objetivo", "Objetivo: ninguno", 18, 13)
	targetLabel.LayoutOrder = 4

	detailLabel = createLabel(panel, "Detalle", "Cliente listo para probar objetivos disponibles.", 34, 12)
	detailLabel.TextColor3 = Color3.fromRGB(178, 190, 202)
	detailLabel.LayoutOrder = 5

	toggleButton.Activated:Connect(function()
		enabled = not enabled
		currentTargetModel = nil
		currentTargetRoot = nil
		nextRetargetAt = 0
		desiredMoveDirection = Vector3.zero
		dodgeMoveDirection = nil
		defenseSerial += 1

		if not enabled and TargetLockController then
			pcall(function()
				TargetLockController:SetTarget(nil)
			end)
		end
	end)
end

local function updateUi(level)
	if not screenGui then
		return
	end

	toggleButton.Text = enabled and "Detener combate" or "Comenzar combate"
	toggleButton.BackgroundColor3 = enabled and Color3.fromRGB(145, 70, 61) or Color3.fromRGB(49, 116, 82)
	statusLabel.Text = enabled and "Estado: ON" or "Estado: OFF"
	levelLabel.Text = string.format("Nivel combate: %d/%d", level, CONFIG.MaxCombatLevel)
	if isPerfectLevel(level) then
		levelLabel.Text ..= " superior"
	end

	if enabled then
		if currentTargetModel then
			local player = Players:GetPlayerFromCharacter(currentTargetModel)
			local userId = currentTargetModel:GetAttribute("UserId")
			if not player and typeof(userId) == "number" then
				player = Players:GetPlayerByUserId(userId)
			end
			local kind = player and "Jugador" or "Bot"
			targetLabel.Text = string.format("Objetivo: %s %s", kind, currentTargetModel.Name)
		else
			targetLabel.Text = "Objetivo: buscando..."
		end
	else
		targetLabel.Text = "Objetivo: detenido"
	end

	detailLabel.Text = controllersReady and statusText or "Esperando ControllersStarted..."
end

local function waitForControllers()
	while ReplicatedStorage:GetAttribute("ControllersStarted") ~= true do
		ReplicatedStorage:GetAttributeChangedSignal("ControllersStarted"):Wait()
	end

	local ok, manager = pcall(require, ReplicatedStorage:WaitForChild("GameManager"))
	if not ok then
		statusText = "No pude requerir GameManager"
		warn("[ComenzarCombate] GameManager require fallo: " .. tostring(manager))
		return
	end

	GameManager = manager

	local okControllers, err = pcall(function()
		CharacterController = GameManager:GetController("CharacterController")
		PlayerInputController = GameManager:GetController("PlayerInputController")
		TargetLockController = GameManager:GetController("TargetLockController")
	end)

	if not okControllers then
		statusText = "No pude cargar controladores"
		warn("[ComenzarCombate] controladores no disponibles: " .. tostring(err))
		return
	end

	controllersReady = true
	statusText = "cliente listo"
end

local function getLocalHandler()
	if not CharacterController then
		return nil
	end

	local ok, handler = pcall(function()
		return CharacterController:GetLocalCharacterHandler()
	end)

	if ok then
		return handler
	end

	return nil
end

local function getRoot(model)
	if not model or not model:IsA("Model") then
		return nil
	end

	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end

	return nil
end

local function getHumanoid(model)
	if not model or not model:IsA("Model") then
		return nil
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end

	return nil
end

local function getModelPlayer(model)
	local player = Players:GetPlayerFromCharacter(model)
	if player then
		return player
	end

	local userId = model:GetAttribute("UserId")
	if typeof(userId) == "number" then
		return Players:GetPlayerByUserId(userId)
	end

	return nil
end

local function isLocalCharacterModel(model, localHandler)
	if not model then
		return true
	end

	if localHandler and (model == localHandler.OriginalModel or model == localHandler.Model) then
		return true
	end

	if localPlayer.Character and model == localPlayer.Character then
		return true
	end

	if getModelPlayer(model) == localPlayer then
		return true
	end

	return false
end

local function hasBotMarker(model)
	for _, tagName in ipairs(CONFIG.BotTags) do
		if CollectionService:HasTag(model, tagName) then
			return true
		end
	end

	for _, attributeName in ipairs(CONFIG.BotModelAttributes) do
		if model:GetAttribute(attributeName) == true then
			return true
		end
	end

	return false
end

local function isCandidateModel(model, localHandler)
	if not model or not model:IsA("Model") then
		return false
	end

	if isLocalCharacterModel(model, localHandler) then
		return false
	end

	local isPlayerTarget = getModelPlayer(model) ~= nil
	if isPlayerTarget and not CONFIG.AllowPlayerTargets then
		return false
	end

	if not isPlayerTarget and not CONFIG.AllowBotTargets then
		return false
	end

	if model:GetAttribute("IsDead") == true then
		return false
	end

	if model:GetAttribute("ClientCombatDisabled") == true then
		return false
	end

	if not getRoot(model) then
		return false
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health <= 0 then
		return false
	end

	if isPlayerTarget then
		return true
	end

	return CONFIG.AllowUnmarkedServerCombatants or hasBotMarker(model)
end

local function addCandidateFromPart(part, localHandler, seen, output)
	if not part or not part:IsA("BasePart") then
		return
	end

	local model = part:FindFirstAncestorWhichIsA("Model")
	if not model or seen[model] then
		return
	end

	if isCandidateModel(model, localHandler) then
		seen[model] = true
		table.insert(output, {
			model = model,
			root = part,
		})
	end
end

local function addCandidateFromModel(model, localHandler, seen, output)
	if not model or seen[model] then
		return
	end

	if not isCandidateModel(model, localHandler) then
		return
	end

	local root = getRoot(model)
	if root then
		seen[model] = true
		table.insert(output, {
			model = model,
			root = root,
		})
	end
end

local function collectCandidates(localHandler)
	local seen = {}
	local output = {}

	for _, targetPart in ipairs(CollectionService:GetTagged("LockAvailableTarget")) do
		addCandidateFromPart(targetPart, localHandler, seen, output)
	end

	for _, characterModel in ipairs(CollectionService:GetTagged("CustomCharacter")) do
		addCandidateFromModel(characterModel, localHandler, seen, output)
	end

	for _, tagName in ipairs(CONFIG.BotTags) do
		for _, tagged in ipairs(CollectionService:GetTagged(tagName)) do
			if tagged:IsA("BasePart") then
				addCandidateFromPart(tagged, localHandler, seen, output)
			elseif tagged:IsA("Model") then
				addCandidateFromModel(tagged, localHandler, seen, output)
			end
		end
	end

	return output
end

local function chooseTarget(localHandler)
	if not localHandler or not localHandler.Root then
		return nil, nil
	end

	local origin = localHandler.Root.Position
	local bestModel = nil
	local bestRoot = nil
	local bestDistance = math.huge

	for _, candidate in ipairs(collectCandidates(localHandler)) do
		local distance = (candidate.root.Position - origin).Magnitude
		if distance <= CONFIG.MaxTargetDistance and distance < bestDistance then
			bestModel = candidate.model
			bestRoot = candidate.root
			bestDistance = distance
		end
	end

	return bestModel, bestRoot
end

local function keepTargetLock(root)
	if not TargetLockController then
		return
	end

	if root and TargetLockController.Target ~= root then
		pcall(function()
			TargetLockController:SetTarget(root)
		end)
	elseif not root and TargetLockController.Target then
		pcall(function()
			TargetLockController:SetTarget(nil)
		end)
	end
end

local function requestEquipWeapon()
	if os.clock() < nextEquipAt then
		return
	end

	nextEquipAt = os.clock() + 1

	local requestFolder = ReplicatedStorage:FindFirstChild("Remotes")
		and ReplicatedStorage.Remotes:FindFirstChild("PlayerCharacter")
		and ReplicatedStorage.Remotes.PlayerCharacter:FindFirstChild("Request")

	local setEquippedWeapon = requestFolder and requestFolder:FindFirstChild("SetEquippedWeapon")
	if setEquippedWeapon and setEquippedWeapon:IsA("RemoteEvent") then
		setEquippedWeapon:FireServer(true)
	end
end

local function requestAttack(handler, level)
	local actionManager = handler and handler.ActionManager
	if not actionManager then
		return false
	end

	if not handler.EquippedWeapon then
		if CONFIG.AutoEquipWeapon then
			requestEquipWeapon()
			statusText = "equipando arma"
		end
		return false
	end

	local heavyChance = isPerfectLevel(level) and 0.44 or lerpNumber(0.18, 0.36, levelAlpha(level))
	local attackType = rng:NextNumber() < heavyChance and "Heavy" or "Light"
	local ok, didQueue = pcall(function()
		return actionManager:TryQueueBasicAttack(attackType)
	end)

	if ok and didQueue then
		statusText = "atacando"
		return true
	end

	return false
end

local function requestDodge(handler, direction, level)
	local actionManager = handler and handler.ActionManager
	if not actionManager or not actionManager.CanStartDodge then
		return false
	end

	local ok, canDodge = pcall(function()
		return actionManager:CanStartDodge()
	end)

	if not ok or not canDodge then
		return false
	end

	dodgeMoveDirection = noisyDirection(direction, level)
	dodgeMoveUntil = os.clock() + CONFIG.DodgeInputHoldSeconds
	handler._desiredDodge = 0.26666666666666666
	statusText = "esquivando"
	return true
end

local function releaseBlock(handler)
	if not handler then
		return
	end

	local queue = handler._blockInputQueue
	if queue then
		for i = #queue, 1, -1 do
			local item = queue[i]
			if item.clearedByAction then
				table.remove(queue, i)
			elseif item.state == true then
				item.state = 0.13333333333333333
			end
		end
	end

	local blockAction = handler.ActionManager and handler.ActionManager.BlockAction
	if blockAction then
		blockAction._wantsToRelease = true
	end
end

local function requestBlock(handler)
	local actionManager = handler and handler.ActionManager
	if not actionManager or not actionManager.CanStartBlock then
		return false
	end

	if actionManager.BlockAction then
		return false
	end

	local ok, canBlock = pcall(function()
		local allowed = actionManager:CanStartBlock()
		return allowed
	end)

	if not ok or not canBlock then
		return false
	end

	handler._blockInputQueue = handler._blockInputQueue or {}
	if #handler._blockInputQueue < 2 then
		table.insert(handler._blockInputQueue, {
			state = true,
		})
	end

	statusText = "bloqueando"

	task.delay(CONFIG.BlockHoldSeconds, function()
		releaseBlock(handler)
	end)

	return true
end

local function attributeSignalsAttack(value)
	if typeof(value) == "boolean" then
		return value
	end

	if typeof(value) == "number" then
		local age = os.clock() - value
		return value > 0 and age >= 0 and age <= 0.65
	end

	if typeof(value) == "string" then
		local lower = string.lower(value)
		for _, token in ipairs(ATTACK_TOKENS) do
			if string.find(lower, token, 1, true) then
				return true
			end
		end
	end

	return false
end

local function animationSignalsAttack(model)
	local humanoid = getHumanoid(model)
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return false
	end

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track.IsPlaying and track.WeightCurrent > 0.04 then
			local lowerName = string.lower(track.Name)
			for _, token in ipairs(ATTACK_TOKENS) do
				if string.find(lowerName, token, 1, true) then
					return true
				end
			end
		end
	end

	return false
end

local function targetSignalsAttack(targetModel, targetRoot, localRoot, distance, level)
	if not targetModel or not targetRoot or not localRoot then
		return false
	end

	local extraRange = isPerfectLevel(level) and 5 or 3
	if distance > CONFIG.AttackRange + extraRange then
		return false
	end

	for _, attributeName in ipairs(ATTACK_ATTRIBUTE_NAMES) do
		if attributeSignalsAttack(targetModel:GetAttribute(attributeName)) or attributeSignalsAttack(targetRoot:GetAttribute(attributeName)) then
			return true
		end
	end

	if animationSignalsAttack(targetModel) then
		return true
	end

	local toLocal = flatUnit(localRoot.Position - targetRoot.Position)
	if toLocal.Magnitude <= 0 then
		return false
	end

	local facingDot = flatUnit(targetRoot.CFrame.LookVector):Dot(toLocal)
	local facingThreshold = isPerfectLevel(level) and 0.22 or 0.45
	return distance <= CONFIG.AttackRange + extraRange and facingDot > facingThreshold
end

local function computeMoveDirection(localRoot, targetRoot, level)
	local now = os.clock()

	if dodgeMoveDirection and now < dodgeMoveUntil then
		return dodgeMoveDirection
	end

	if now >= nextStrafeSwitchAt then
		strafeSign = rng:NextNumber() < 0.5 and -1 or 1
		nextStrafeSwitchAt = now + rng:NextNumber(CONFIG.StrafeSwitchMinSeconds, CONFIG.StrafeSwitchMaxSeconds)
	end

	local toTarget = targetRoot.Position - localRoot.Position
	local forward = flatUnit(toTarget)
	if forward.Magnitude <= 0 then
		return Vector3.zero
	end

	local distance = Vector3.new(toTarget.X, 0, toTarget.Z).Magnitude
	local tangent = Vector3.new(-forward.Z, 0, forward.X) * strafeSign
	local direction

	if distance > CONFIG.PreferredDistance + 1.2 then
		direction = (forward * 0.92 + tangent * 0.22).Unit
	elseif distance < CONFIG.TooCloseDistance then
		direction = (-forward * 0.85 + tangent * 0.55).Unit
	else
		local radialCorrection = math.clamp((distance - CONFIG.PreferredDistance) / 3, -0.42, 0.42)
		direction = (tangent + forward * radialCorrection).Unit
	end

	return noisyDirection(direction, level)
end

local function computeDodgeDirection(localRoot, targetRoot, level)
	local away = flatUnit(localRoot.Position - targetRoot.Position)
	if away.Magnitude <= 0 then
		away = flatUnit(localRoot.CFrame.RightVector)
	end

	local side = Vector3.new(-away.Z, 0, away.X) * strafeSign
	local alpha = levelAlpha(level)
	local sideChance = isPerfectLevel(level) and 0.97 or lerpNumber(0.55, 0.86, alpha)
	local direction = rng:NextNumber() < sideChance and side or away
	return noisyDirection(direction, level)
end

local function queueDefense(handler, localRoot, targetRoot, targetModel, level)
	local now = os.clock()
	if now < nextDefenseAt then
		return
	end

	nextDefenseAt = now + (isPerfectLevel(level) and CONFIG.PerfectDefenseCooldown or CONFIG.DefenseCooldown)
	defenseSerial += 1
	local serial = defenseSerial

	local alpha = levelAlpha(level)
	local reactionDelay = lerpNumber(0.22, 0.035, alpha) + rng:NextNumber(0, lerpNumber(0.12, 0.025, alpha))
	local mistakeChance = lerpNumber(0.32, 0.055, alpha)
	if isPerfectLevel(level) then
		reactionDelay = CONFIG.PerfectReactionDelay + rng:NextNumber(0, 0.01)
		mistakeChance = 0
	end

	task.delay(reactionDelay, function()
		if serial ~= defenseSerial or not enabled then
			return
		end

		local liveHandler = getLocalHandler()
		if liveHandler ~= handler or not liveHandler or not liveHandler.Root then
			return
		end

		if not currentTargetRoot or currentTargetRoot ~= targetRoot or not currentTargetRoot:IsDescendantOf(game) then
			return
		end

		if rng:NextNumber() < mistakeChance then
			statusText = "fallo defensa"
			return
		end

		local dodgeChance = isPerfectLevel(level) and 0.99 or lerpNumber(0.54, 0.92, alpha)
		if rng:NextNumber() <= dodgeChance then
			local dodgeDirection = computeDodgeDirection(liveHandler.Root, targetRoot, level)
			requestDodge(liveHandler, dodgeDirection, level)
		else
			requestBlock(liveHandler)
		end
	end)
end

local function nextAttackCooldown(level)
	if isPerfectLevel(level) then
		return CONFIG.PerfectAttackCooldown + rng:NextNumber(0, 0.025)
	end

	return lerpNumber(CONFIG.MaxAttackCooldown, CONFIG.MinAttackCooldown, levelAlpha(level)) + rng:NextNumber(0, 0.08)
end

local function stepAi(dt)
	local level = readCombatLevel()
	updateUi(level)

	if not controllersReady then
		return
	end

	if not enabled then
		desiredMoveDirection = Vector3.zero
		return
	end

	thinkAccumulator += dt
	if thinkAccumulator < CONFIG.ThinkInterval then
		return
	end
	thinkAccumulator = 0

	local handler = getLocalHandler()
	if not handler or not handler.Root or not handler.OriginalModel or handler.OriginalModel:GetAttribute("IsDead") then
		currentTargetModel = nil
		currentTargetRoot = nil
		desiredMoveDirection = Vector3.zero
		statusText = "sin personaje local"
		return
	end

	local now = os.clock()
	if now >= nextRetargetAt or not currentTargetModel or not currentTargetRoot or not isCandidateModel(currentTargetModel, handler) then
		currentTargetModel, currentTargetRoot = chooseTarget(handler)
		nextRetargetAt = now + CONFIG.RetargetSeconds
	end

	if not currentTargetModel or not currentTargetRoot then
		desiredMoveDirection = Vector3.zero
		keepTargetLock(nil)
		statusText = "buscando objetivo disponible"
		return
	end

	keepTargetLock(currentTargetRoot)

	local localRoot = handler.Root
	local distance = (Vector3.new(currentTargetRoot.Position.X, 0, currentTargetRoot.Position.Z) - Vector3.new(localRoot.Position.X, 0, localRoot.Position.Z)).Magnitude
	desiredMoveDirection = computeMoveDirection(localRoot, currentTargetRoot, level)

	if targetSignalsAttack(currentTargetModel, currentTargetRoot, localRoot, distance, level) then
		queueDefense(handler, localRoot, currentTargetRoot, currentTargetModel, level)
	end

	if distance <= CONFIG.AttackRange and now >= nextAttackAt then
		if requestAttack(handler, level) then
			nextAttackAt = now + nextAttackCooldown(level)
		else
			nextAttackAt = now + 0.18
		end
	end
end

local function overrideMoveInput()
	if not enabled or not controllersReady or not PlayerInputController then
		return
	end

	if PlayerInputController.CurrentInput then
		PlayerInputController.CurrentInput.MoveDirection = desiredMoveDirection
	end
end

createUi()
task.spawn(waitForControllers)

RunService:BindToRenderStep("ComenzarCombateMoveOverride", Enum.RenderPriority.Input.Value + 2, overrideMoveInput)
RunService.Heartbeat:Connect(stepAi)
