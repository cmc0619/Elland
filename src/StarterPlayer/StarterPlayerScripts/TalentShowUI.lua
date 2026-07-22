--[[
	TalentShowUI
	Audience voting panel for the Talent Show at Ella's Stage. When the
	server opens the voting window (last 30 seconds of a show), every
	player except the performer gets two big buttons - Applause and Star -
	they can tap repeatedly (client debounce + server rate limit). The
	panel hides itself when the show ends.

	Follows the FashionUI module pattern: CreateUI/Open/Close/Init,
	initialized by ClientController.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local TalentShowUI = {}
TalentShowUI.ScreenGui = nil
TalentShowUI.TimerLabel = nil
TalentShowUI.CountLabel = nil

local TalentShowEvent
local TalentShowVote

local VOTE_DEBOUNCE = 1 -- Matches the server-side rate limit
local lastVoteSent = 0
local sessionToken = 0 -- Guards the countdown loop against overlaps

function TalentShowUI:CreateUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TalentShowUI"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "VotingPanel"
	frame.Size = UDim2.new(0, 360, 0, 190)
	frame.Position = UDim2.new(0.5, 0, 1, -230)
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.BackgroundColor3 = Color3.fromRGB(47, 49, 54)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 12)
	frameCorner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -20, 0, 28)
	title.Position = UDim2.new(0, 10, 0, 10)
	title.BackgroundTransparency = 1
	title.Text = "Cheer for the performer!"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 20
	title.Font = Enum.Font.GothamBold
	title.Parent = frame

	local timer = Instance.new("TextLabel")
	timer.Name = "Timer"
	timer.Size = UDim2.new(1, -20, 0, 20)
	timer.Position = UDim2.new(0, 10, 0, 38)
	timer.BackgroundTransparency = 1
	timer.Text = "30s left to vote"
	timer.TextColor3 = Color3.fromRGB(255, 215, 0)
	timer.TextSize = 14
	timer.Font = Enum.Font.Gotham
	timer.Parent = frame

	local applause = Instance.new("TextButton")
	applause.Name = "ApplauseButton"
	applause.Size = UDim2.new(0, 150, 0, 70)
	applause.Position = UDim2.new(0, 20, 0, 68)
	applause.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	applause.Text = "\240\159\145\143 Applause"
	applause.TextColor3 = Color3.fromRGB(60, 45, 10)
	applause.TextSize = 20
	applause.Font = Enum.Font.GothamBold
	applause.Parent = frame

	local applauseCorner = Instance.new("UICorner")
	applauseCorner.CornerRadius = UDim.new(0, 10)
	applauseCorner.Parent = applause

	local star = Instance.new("TextButton")
	star.Name = "StarButton"
	star.Size = UDim2.new(0, 150, 0, 70)
	star.Position = UDim2.new(1, -170, 0, 68)
	star.BackgroundColor3 = Color3.fromRGB(255, 130, 180)
	star.Text = "\226\173\144 Star"
	star.TextColor3 = Color3.fromRGB(80, 20, 45)
	star.TextSize = 20
	star.Font = Enum.Font.GothamBold
	star.Parent = frame

	local starCorner = Instance.new("UICorner")
	starCorner.CornerRadius = UDim.new(0, 10)
	starCorner.Parent = star

	local counts = Instance.new("TextLabel")
	counts.Name = "Counts"
	counts.Size = UDim2.new(1, -20, 0, 24)
	counts.Position = UDim2.new(0, 10, 1, -34)
	counts.BackgroundTransparency = 1
	counts.Text = "You sent: 0 applause, 0 stars"
	counts.TextColor3 = Color3.fromRGB(200, 200, 200)
	counts.TextSize = 14
	counts.Font = Enum.Font.Gotham
	counts.Parent = frame

	self.ScreenGui = gui
	self.TimerLabel = timer
	self.CountLabel = counts

	local sentApplause = 0
	local sentStars = 0

	local function sendVote(voteType)
		local now = os.clock()
		if now - lastVoteSent < VOTE_DEBOUNCE then
			return
		end
		lastVoteSent = now

		if voteType == "applause" then
			sentApplause = sentApplause + 1
		else
			sentStars = sentStars + 1
		end
		counts.Text = "You sent: " .. sentApplause .. " applause, " .. sentStars .. " stars"

		if TalentShowVote then
			TalentShowVote:FireServer(voteType)
		end
	end

	applause.MouseButton1Click:Connect(function()
		sendVote("applause")
	end)
	star.MouseButton1Click:Connect(function()
		sendVote("star")
	end)

	-- Expose a reset so each voting window starts at zero
	self.ResetCounts = function()
		sentApplause = 0
		sentStars = 0
		lastVoteSent = 0
		counts.Text = "You sent: 0 applause, 0 stars"
	end
end

function TalentShowUI:ShowVoting(hostName, duration)
	if not self.ScreenGui then
		return
	end

	sessionToken = sessionToken + 1
	local token = sessionToken

	if self.ResetCounts then
		self.ResetCounts()
	end
	self.ScreenGui.Enabled = true

	local title = self.ScreenGui.VotingPanel:FindFirstChild("Title")
	if title then
		title.Text = "Cheer for " .. hostName .. "!"
	end

	task.spawn(function()
		for remaining = duration, 1, -1 do
			if token ~= sessionToken then
				return
			end
			self.TimerLabel.Text = remaining .. "s left to vote"
			task.wait(1)
		end
		if token == sessionToken then
			self:Close()
		end
	end)
end

function TalentShowUI:Close()
	sessionToken = sessionToken + 1
	if self.ScreenGui then
		self.ScreenGui.Enabled = false
	end
end

function TalentShowUI:Init()
	TalentShowEvent = ReplicatedStorage:WaitForChild("TalentShowEvent", 10)
	TalentShowVote = ReplicatedStorage:WaitForChild("TalentShowVote", 10)

	if not TalentShowEvent or not TalentShowVote then
		warn("TalentShowUI: remotes not found - server may still be starting")
		return
	end

	self:CreateUI()

	TalentShowEvent.OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then
			return
		end
		if data.phase == "voting" then
			-- The performer performs; everyone else votes
			if data.hostUserId ~= player.UserId then
				self:ShowVoting(data.hostName or "the performer", data.duration or 30)
			end
		elseif data.phase == "end" or data.phase == "start" then
			self:Close()
		end
	end)
end

return TalentShowUI
