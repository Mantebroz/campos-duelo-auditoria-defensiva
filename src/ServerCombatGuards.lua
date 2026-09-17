--!strict
-- ModuleScript defensivo para validar acciones de combate en servidor.

local ServerCombatGuards = {}

type Bucket = {
	windowStart: number,
	count: number,
}

local buckets: {[string]: Bucket} = {}
local cooldowns: {[string]: number} = {}

local function now(): number
	return os.clock()
end

local function keyFor(player: Player, action: string): string
	return tostring(player.UserId) .. ":" .. action
end

function ServerCombatGuards.allowRate(player: Player, action: string, windowSeconds: number, maxEvents: number): (boolean, string?)
	if windowSeconds <= 0 or maxEvents <= 0 then
		return false, "bad-rate-config"
	end

	local key = keyFor(player, action)
	local t = now()
	local bucket = buckets[key]

	if bucket == nil or t - bucket.windowStart >= windowSeconds then
		buckets[key] = {
			windowStart = t,
			count = 1,
		}
		return true, nil
	end

	bucket.count += 1
	if bucket.count > maxEvents then
		return false, "rate-limited"
	end

	return true, nil
end

function ServerCombatGuards.allowCooldown(player: Player, action: string, cooldownSeconds: number): (boolean, string?)
	if cooldownSeconds < 0 then
		return false, "bad-cooldown-config"
	end

	local key = keyFor(player, action)
	local t = now()
	local readyAt = cooldowns[key] or 0

	if t < readyAt then
		return false, "cooldown"
	end

	cooldowns[key] = t + cooldownSeconds
	return true, nil
end

function ServerCombatGuards.getRoot(model: Instance?): BasePart?
	if model == nil or not model:IsA("Model") then
		return nil
	end

	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	return nil
end

function ServerCombatGuards.getHumanoid(model: Instance?): Humanoid?
	if model == nil or not model:IsA("Model") then
		return nil
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end

	return nil
end

function ServerCombatGuards.withinDistance(a: BasePart, b: BasePart, maxDistance: number): boolean
	if maxDistance <= 0 then
		return false
	end

	return (a.Position - b.Position).Magnitude <= maxDistance
end

function ServerCombatGuards.facingTarget(attackerRoot: BasePart, targetRoot: BasePart, minDot: number): boolean
	local offset = targetRoot.Position - attackerRoot.Position
	if offset.Magnitude <= 0.001 then
		return true
	end

	local direction = offset.Unit
	return attackerRoot.CFrame.LookVector:Dot(direction) >= minDot
end

function ServerCombatGuards.validateTarget(attacker: Player, targetModel: Instance?, maxDistance: number, minFacingDot: number?): (boolean, string?, Humanoid?)
	local attackerCharacter = attacker.Character
	local attackerRoot = ServerCombatGuards.getRoot(attackerCharacter)
	local targetRoot = ServerCombatGuards.getRoot(targetModel)
	local targetHumanoid = ServerCombatGuards.getHumanoid(targetModel)

	if attackerRoot == nil then
		return false, "attacker-no-root", nil
	end

	if targetRoot == nil or targetHumanoid == nil then
		return false, "bad-target", nil
	end

	if not ServerCombatGuards.withinDistance(attackerRoot, targetRoot, maxDistance) then
		return false, "out-of-range", nil
	end

	if minFacingDot ~= nil and not ServerCombatGuards.facingTarget(attackerRoot, targetRoot, minFacingDot) then
		return false, "bad-facing", nil
	end

	return true, nil, targetHumanoid
end

function ServerCombatGuards.safeNumber(value: any, fallback: number, minValue: number, maxValue: number): number
	if typeof(value) ~= "number" or value ~= value then
		return fallback
	end

	return math.clamp(value, minValue, maxValue)
end

return ServerCombatGuards

