--!strict
-- ModuleScript para un NPC de entrenamiento justo y configurable.

export type Settings = {
	PreferredRange: number,
	AttackRange: number,
	RetreatHealthRatio: number,
	ReactionTime: number,
	BlockChance: number,
}

export type Snapshot = {
	Distance: number,
	CanAttack: boolean,
	IncomingAttack: boolean,
	HealthRatio: number,
	StaminaRatio: number,
}

local NpcCombatBrain = {}
NpcCombatBrain.DefaultSettings = {
	PreferredRange = 8,
	AttackRange = 5,
	RetreatHealthRatio = 0.25,
	ReactionTime = 0.25,
	BlockChance = 0.35,
}

local lastDecisionAt = 0
local lastAction = "idle"

local function chance(probability: number): boolean
	return math.random() < math.clamp(probability, 0, 1)
end

local function mergeSettings(settings: Settings?): Settings
	local defaults = NpcCombatBrain.DefaultSettings
	settings = settings or defaults

	return {
		PreferredRange = settings.PreferredRange or defaults.PreferredRange,
		AttackRange = settings.AttackRange or defaults.AttackRange,
		RetreatHealthRatio = settings.RetreatHealthRatio or defaults.RetreatHealthRatio,
		ReactionTime = math.max(settings.ReactionTime or defaults.ReactionTime, 0.18),
		BlockChance = settings.BlockChance or defaults.BlockChance,
	}
end

function NpcCombatBrain.decide(snapshot: Snapshot, settings: Settings?): string
	local config = mergeSettings(settings)
	local t = os.clock()

	if t - lastDecisionAt < config.ReactionTime then
		return lastAction
	end

	lastDecisionAt = t

	if snapshot.HealthRatio <= config.RetreatHealthRatio and snapshot.Distance < config.PreferredRange then
		lastAction = "retreat"
	elseif snapshot.IncomingAttack and chance(config.BlockChance) and snapshot.StaminaRatio > 0.2 then
		lastAction = "block"
	elseif snapshot.Distance > config.PreferredRange then
		lastAction = "approach"
	elseif snapshot.Distance <= config.AttackRange and snapshot.CanAttack and snapshot.StaminaRatio > 0.15 then
		if snapshot.StaminaRatio > 0.55 and chance(0.3) then
			lastAction = "heavy"
		else
			lastAction = "jab"
		end
	else
		lastAction = "strafe"
	end

	return lastAction
end

return NpcCombatBrain

