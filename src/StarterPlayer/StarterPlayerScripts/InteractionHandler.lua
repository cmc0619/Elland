--[[
	InteractionHandler
	Handles server-initiated UI interactions on the client
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for WordleUI to be available
task.wait(2)

local WordleUI = _G.WordleUI

if not WordleUI then
	warn("WordleUI not found!")
	return
end

-- Listen for OpenWordleUI event
local function setupWordleListener()
	local openWordle = ReplicatedStorage:WaitForChild("OpenWordleUI")

	openWordle.OnClientEvent:Connect(function()
		print("Opening Wordle UI from interaction")
		WordleUI:Open()
	end)

	print("InteractionHandler: Listening for Wordle prompts")
end

setupWordleListener()
