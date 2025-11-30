--[[
	InteractionHandler
	Handles server-initiated UI interactions on the client
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for WordleUI to be available
task.wait(2)

local WordleUI = _G.WordleUI

if not WordleUI then
	warn("InteractionHandler: WordleUI not found in _G!")
	return
end

print("InteractionHandler: WordleUI found, setting up listener")

-- Listen for OpenWordleUI event
local function setupWordleListener()
	local openWordle = ReplicatedStorage:WaitForChild("OpenWordleUI", 30)
	
	if not openWordle then
		warn("InteractionHandler: OpenWordleUI event not found after 30 seconds!")
		return
	end

	openWordle.OnClientEvent:Connect(function()
		print("InteractionHandler: Received OpenWordleUI event!")
		if WordleUI and WordleUI.Open then
			WordleUI:Open()
		else
			warn("InteractionHandler: WordleUI:Open() not available!")
		end
	end)

	print("InteractionHandler: Listening for Wordle prompts")
end

setupWordleListener()
