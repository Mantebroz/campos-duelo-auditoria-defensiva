--!strict
-- Tabla de politicas defensivas para envolver handlers remotos del servidor.
-- No invoca remotes; documenta que debe validar cada familia.

local RemotePolicyMatrix = {}

export type Policy = {
	risk: "low" | "medium" | "high" | "critical",
	direction: "client_to_server" | "server_to_client" | "mixed",
	rateWindowSeconds: number,
	maxCallsPerWindow: number,
	requiredChecks: {string},
}

RemotePolicyMatrix.Groups = {
	PlayerCharacterCombat = {
		risk = "critical",
		direction = "client_to_server",
		rateWindowSeconds = 1,
		maxCallsPerWindow = 20,
		requiredChecks = {
			"type-check",
			"alive-and-in-match",
			"server-cooldown",
			"server-stamina",
			"weapon-ownership",
			"distance-angle-line-of-sight",
			"server-impact-ledger",
			"reject-telemetry",
		},
	} :: Policy,

	PlayerCharacterMovement = {
		risk = "high",
		direction = "client_to_server",
		rateWindowSeconds = 1,
		maxCallsPerWindow = 90,
		requiredChecks = {
			"type-check",
			"cframe-delta-clamp",
			"speed-acceleration-clamp",
			"ping-tolerance",
			"resync-on-anomaly",
			"reject-telemetry",
		},
	} :: Policy,

	MatchAndParty = {
		risk = "medium",
		direction = "mixed",
		rateWindowSeconds = 3,
		maxCallsPerWindow = 10,
		requiredChecks = {
			"type-check",
			"membership",
			"phase-check",
			"host-permission",
			"idempotency",
			"reject-telemetry",
		},
	} :: Policy,

	EconomyInventoryRewards = {
		risk = "critical",
		direction = "client_to_server",
		rateWindowSeconds = 10,
		maxCallsPerWindow = 12,
		requiredChecks = {
			"type-check",
			"server-balance",
			"ownership",
			"receipt-verification",
			"idempotency",
			"atomic-save",
			"reject-telemetry",
		},
	} :: Policy,

	SettingsAndLayout = {
		risk = "low",
		direction = "client_to_server",
		rateWindowSeconds = 10,
		maxCallsPerWindow = 20,
		requiredChecks = {
			"type-check",
			"allowlist-key",
			"value-range",
			"payload-size-limit",
		},
	} :: Policy,

	DebugCommands = {
		risk = "critical",
		direction = "client_to_server",
		rateWindowSeconds = 60,
		maxCallsPerWindow = 1,
		requiredChecks = {
			"disabled-in-production",
			"userid-allowlist",
			"audit-log",
			"no-economy-mutation-without-server-proof",
		},
	} :: Policy,
}

function RemotePolicyMatrix.getPolicy(groupName: string): Policy?
	return RemotePolicyMatrix.Groups[groupName]
end

return RemotePolicyMatrix

