--!strict
-- ModuleScript ejemplo: validaciones defensivas para remotes PlayerCharacter.
-- Este modulo no explota remotes; muestra como tratarlos como intenciones no confiables.

local PlayerCharacterRequestValidator = {}

export type CombatState = {
	matchId: string?,
	isAlive: boolean,
	isStunned: boolean,
	equippedWeapon: string?,
	ultimateEnergy: number,
	stamina: number,
	lastCFrame: CFrame?,
	lastCFrameAt: number?,
	activeImpacts: {[string]: {
		attacker: Player,
		defender: Player,
		actionId: string,
		expiresAt: number,
		used: boolean,
	}},
	cooldowns: {[string]: number},
}

local MAX_CFRAME_DELTA_PER_SECOND = 55
local MAX_CFRAME_SINGLE_DELTA = 18
local IMPACT_GRACE_SECONDS = 0.2

local function now(): number
	return os.clock()
end

local function reject(reason: string): (boolean, string)
	return false, reason
end

function PlayerCharacterRequestValidator.requireAlive(state: CombatState): (boolean, string?)
	if not state.isAlive then
		return reject("not-alive")
	end

	if state.isStunned then
		return reject("stunned")
	end

	return true, nil
end

function PlayerCharacterRequestValidator.checkCooldown(state: CombatState, action: string, cooldownSeconds: number): (boolean, string?)
	local t = now()
	local readyAt = state.cooldowns[action] or 0

	if t < readyAt then
		return reject("cooldown")
	end

	state.cooldowns[action] = t + cooldownSeconds
	return true, nil
end

function PlayerCharacterRequestValidator.validateAttackRequest(state: CombatState, requestedAttack: any): (boolean, string?)
	local ok, reason = PlayerCharacterRequestValidator.requireAlive(state)
	if not ok then
		return false, reason
	end

	if typeof(requestedAttack) ~= "string" then
		return reject("bad-attack-type")
	end

	if state.equippedWeapon == nil then
		return reject("no-equipped-weapon")
	end

	if requestedAttack == "Ultimate" and state.ultimateEnergy < 100 then
		return reject("no-ultimate-energy")
	end

	return PlayerCharacterRequestValidator.checkCooldown(state, "attack", 0.12)
end

function PlayerCharacterRequestValidator.validateDefenseIntent(state: CombatState, action: "block" | "dodge", direction: any?): (boolean, string?, Vector3?)
	local ok, reason = PlayerCharacterRequestValidator.requireAlive(state)
	if not ok then
		return false, reason, nil
	end

	if action == "dodge" and state.stamina < 1 then
		return reject("no-dodge-stamina")
	end

	if direction ~= nil then
		if typeof(direction) ~= "Vector3" then
			return reject("bad-direction")
		end

		if direction.Magnitude > 1.05 then
			direction = direction.Unit
		end
	end

	return true, nil, direction
end

function PlayerCharacterRequestValidator.validateCFrameReport(state: CombatState, reportedCFrame: any, receivedAt: number?): (boolean, string?)
	if typeof(reportedCFrame) ~= "CFrame" then
		return reject("bad-cframe")
	end

	local t = receivedAt or now()
	local lastCFrame = state.lastCFrame
	local lastAt = state.lastCFrameAt

	if lastCFrame and lastAt then
		local dt = math.max(t - lastAt, 1 / 60)
		local delta = (reportedCFrame.Position - lastCFrame.Position).Magnitude
		local maxDelta = math.min(MAX_CFRAME_SINGLE_DELTA, MAX_CFRAME_DELTA_PER_SECOND * dt)

		if delta > maxDelta then
			return reject("cframe-delta-too-large")
		end
	end

	state.lastCFrame = reportedCFrame
	state.lastCFrameAt = t
	return true, nil
end

function PlayerCharacterRequestValidator.validateImpactResolution(state: CombatState, player: Player, impactId: any): (boolean, string?, string?)
	if typeof(impactId) ~= "string" then
		return reject("bad-impact-id")
	end

	local impact = state.activeImpacts[impactId]
	if impact == nil then
		return reject("unknown-impact-id")
	end

	if impact.used then
		return reject("impact-already-used")
	end

	if impact.defender ~= player then
		return reject("wrong-defender")
	end

	if now() > impact.expiresAt + IMPACT_GRACE_SECONDS then
		return reject("impact-expired")
	end

	impact.used = true
	return true, nil, impact.actionId
end

return PlayerCharacterRequestValidator

