--[[
	HuntClient.client.lua
	Client side of the Music Note Hunt.

	The server (HuntManager) owns collection state; this script:
	  - Hides notes the local player already collected (the server fires
	    HuntNoteUpdate with the collected indexes on join and after every
	    pickup; hiding is local-only so other players still see them).
	  - Shows a small HUD counter with hunt progress ("Notes 3/10").
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local HuntNoteUpdate = ReplicatedStorage:WaitForChild("HuntNoteUpdate", 15)
if not HuntNoteUpdate then
	return -- Server is not running the hunt
end

-- Small progress HUD (bottom-right, out of the way of the currency HUD)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HuntHUD"
screenGui.ResetOnSpawn = false

local counter = Instance.new("TextLabel")
counter.Name = "HuntCounter"
counter.Size = UDim2.new(0, 150, 0, 34)
counter.Position = UDim2.new(1, -20, 1, -20)
counter.AnchorPoint = Vector2.new(1, 1)
counter.BackgroundColor3 = Color3.fromRGB(255, 205, 60)
counter.BorderSizePixel = 0
counter.Text = "Notes 0/?"
counter.TextSize = 16
counter.TextColor3 = Color3.fromRGB(90, 70, 20)
counter.Font = Enum.Font.GothamBold
counter.Parent = screenGui

local counterCorner = Instance.new("UICorner")
counterCorner.CornerRadius = UDim.new(0, 10)
counterCorner.Parent = counter

screenGui.Parent = playerGui

-- Hide one collected note locally (parts, light, sparkles)
local function hideNote(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
		elseif descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
		elseif descendant:IsA("PointLight") then
			descendant.Enabled = false
		end
	end
end

HuntNoteUpdate.OnClientEvent:Connect(function(collectedNotes, huntCompleted, totalNotes)
	local folder = Workspace:FindFirstChild("MusicNotes")
	if folder and type(collectedNotes) == "table" then
		for _, noteIndex in ipairs(collectedNotes) do
			local model = folder:FindFirstChild("Note" .. noteIndex)
			if model then
				hideNote(model)
			end
		end
	end

	local found = type(collectedNotes) == "table" and #collectedNotes or 0
	totalNotes = type(totalNotes) == "number" and totalNotes or 0

	if huntCompleted then
		counter.Text = "Notes " .. totalNotes .. "/" .. totalNotes .. "!"
		counter.BackgroundColor3 = Color3.fromRGB(140, 200, 140)
	else
		counter.Text = "Notes " .. found .. "/" .. totalNotes
	end
end)
