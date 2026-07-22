--[[
	PetFollow.client.lua
	Smooth client-side follow loop for pets.

	The server (PetManager) spawns one anchored, non-collidable pet model
	per player in Workspace/Pets, tagged with an OwnerUserId attribute and
	positioned once. This script pivots every pet model on each Heartbeat
	toward a point just behind its owner's character with a gentle bob, so
	pets trail smoothly with zero per-frame network traffic. Every client
	animates every pet (each uses the owner's replicated character), which
	keeps the view consistent for all players.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local PETS = Constants.PETS

local petsFolder = Workspace:WaitForChild("Pets", 30)
if not petsFolder then
	-- PetManager always creates the folder on Init; if it never appears
	-- the server is not running the pet feature, so just idle.
	return
end

RunService.Heartbeat:Connect(function(dt)
	local t = os.clock()
	local bob = math.sin(t * (2 * math.pi / PETS.BOB_PERIOD)) * PETS.BOB_AMPLITUDE
	local alpha = math.min(1, dt * PETS.FOLLOW_SPEED)

	for _, model in ipairs(petsFolder:GetChildren()) do
		local ownerId = model:GetAttribute("OwnerUserId")
		local owner = ownerId and Players:GetPlayerByUserId(ownerId)
		local character = owner and owner.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local targetPos = (rootPart.CFrame * CFrame.new(
				PETS.FOLLOW_OFFSET + Vector3.new(0, PETS.FOLLOW_HEIGHT + bob, 0)
			)).Position
			-- Hover while facing the owner
			local target = CFrame.lookAt(targetPos, Vector3.new(
				rootPart.Position.X, targetPos.Y, rootPart.Position.Z
			))
			model:PivotTo(model:GetPivot():Lerp(target, alpha))
		end
	end
end)
