--!strict
-- Server Script para Studio: inventaria remotes sin invocarlos.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function pathOf(instance: Instance): string
	local parts = {}
	local current: Instance? = instance

	while current and current ~= game do
		table.insert(parts, 1, current.Name)
		current = current.Parent
	end

	return "game." .. table.concat(parts, ".")
end

local rows = {}

for _, descendant in ReplicatedStorage:GetDescendants() do
	if descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") or descendant:IsA("UnreliableRemoteEvent") then
		table.insert(rows, {
			className = descendant.ClassName,
			path = pathOf(descendant),
		})
	end
end

table.sort(rows, function(a, b)
	return a.path < b.path
end)

print("== Remote inventory ==")
for _, row in rows do
	print(string.format("%s | %s", row.className, row.path))
end
print(string.format("Total remotes: %d", #rows))

