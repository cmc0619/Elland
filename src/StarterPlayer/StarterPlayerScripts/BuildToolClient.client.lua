--[[
	BuildToolClient.client.lua
	Client-side behavior for the Build Tool handed out in the Building Area.

	Click (tool activated): ask the server to place a block at the mouse hit
	position. R or right-click (while equipped): ask the server to delete
	the block under the mouse. The server re-validates everything - this
	script only reports what the player aimed at.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local BuildPlaceRequest = ReplicatedStorage:WaitForChild("BuildPlaceRequest", 10)
local BuildDeleteRequest = ReplicatedStorage:WaitForChild("BuildDeleteRequest", 10)

if not BuildPlaceRequest or not BuildDeleteRequest then
	warn("Build tool remotes not found - server may still be starting")
	return
end

local toolEquipped = false

local function hookTool(tool)
	if tool.Name ~= "BuildTool" then
		return
	end

	tool.Equipped:Connect(function()
		toolEquipped = true
	end)

	tool.Unequipped:Connect(function()
		toolEquipped = false
	end)

	tool.Activated:Connect(function()
		-- mouse.Hit is valid while the tool is equipped
		BuildPlaceRequest:FireServer(mouse.Hit.Position)
	end)
end

-- Watch backpack and character for the tool
local function watchContainer(container)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Tool") then
			hookTool(child)
		end
	end
	container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			hookTool(child)
		end
	end)
end

local backpack = player:WaitForChild("Backpack", 10)
if backpack then
	watchContainer(backpack)
end

player.CharacterAdded:Connect(function(character)
	watchContainer(character)
end)
if player.Character then
	watchContainer(player.Character)
end

-- Delete: R key or right-click while the tool is equipped
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not toolEquipped then
		return
	end

	if input.KeyCode == Enum.KeyCode.R or input.UserInputType == Enum.UserInputType.MouseButton2 then
		local target = mouse.Target
		if target then
			BuildDeleteRequest:FireServer(target)
		end
	end
end)
