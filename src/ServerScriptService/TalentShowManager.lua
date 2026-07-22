--[[
	TalentShowManager
	Talent Show at Ella's Stage: a voting minigame for family and friends
	in the server. The "Host a Talent Show!" prompt on the stage starts a
	60-second server-managed event (one at a time, 10-minute server-wide
	cooldown). The host is the performer; during the last 30 seconds every
	OTHER player gets the TalentShowUI voting panel with Applause / Star
	buttons (server rate-limits votes to 1/second per player, performers
	can't vote for themselves).

	When the show ends the server tallies the votes, awards the performer
	Coins (1 Coin per 2 votes, capped at 25), bursts confetti over the
	stage, and toasts the results to everyone. TalentShowsHosted and
	BestApplause persist in player data (migration-safe defaults).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)

local TalentShowManager = {}
TalentShowManager.PlayerDataService = nil
TalentShowManager.CurrencyManager = nil

-- RemoteEvents (created at module load so clients can WaitForChild them)
local TalentShowEvent = Instance.new("RemoteEvent")
TalentShowEvent.Name = "TalentShowEvent"
TalentShowEvent.Parent = ReplicatedStorage

local TalentShowVote = Instance.new("RemoteEvent")
TalentShowVote.Name = "TalentShowVote"
TalentShowVote.Parent = ReplicatedStorage

-- Shared one-line notification channel (ClientController shows the toast)
local NotifyPlayer = ReplicatedStorage:FindFirstChild("NotifyPlayer")
if not NotifyPlayer then
	NotifyPlayer = Instance.new("RemoteEvent")
	NotifyPlayer.Name = "NotifyPlayer"
	NotifyPlayer.Parent = ReplicatedStorage
end

local SHOW = Constants.TALENT_SHOW
local STAGE = Constants.STAGE
local GROUND_LEVEL = Constants.WORLD.GROUND_LEVEL

-- Server-managed show state. Only one show at a time.
-- { host = Player, hostName = string, applause = n, stars = n, voting = bool }
local activeShow = nil
local lastShowEndTime = 0 -- os.time() of the last show's end (server-wide cooldown)
local lastVoteTime = {} -- [UserId] = os.clock() (vote rate limit)
local confettiEmitter = nil

local function notifyAll(text)
	for _, p in ipairs(Players:GetPlayers()) do
		NotifyPlayer:FireClient(p, text)
	end
end

-- The host spotlight on the stage + a confetti cannon above it
local function buildHostSpot()
	local stage = Workspace:FindFirstChild("EllasStage")
	if not stage then
		warn("TalentShowManager: EllasStage not found - is StageManager initialized first?")
		return
	end

	local center = STAGE.CENTER
	local topY = GROUND_LEVEL + STAGE.PLATFORM_SIZE.Y

	local spot = Instance.new("Part")
	spot.Name = "TalentShowSpot"
	spot.Size = Vector3.new(3, 3, 3)
	spot.Shape = Enum.PartType.Ball
	spot.Position = Vector3.new(center.X + 8, topY + 2, center.Z - 3)
	spot.Anchored = true
	spot.CanCollide = false
	spot.Transparency = 0.5
	spot.Color = Color3.fromRGB(255, 215, 0)
	spot.Material = Enum.Material.Neon
	spot.Parent = stage

	local light = Instance.new("PointLight")
	light.Brightness = 1.5
	light.Range = 14
	light.Color = Color3.fromRGB(255, 215, 120)
	light.Parent = spot

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Host a Talent Show!"
	prompt.ObjectText = "Ella's Stage"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 12
	prompt.Parent = spot

	prompt.Triggered:Connect(function(player)
		TalentShowManager:HandleHostRequest(player)
	end)

	-- Confetti cannon high above the stage center (Rate 0, burst with :Emit)
	local cannon = Instance.new("Part")
	cannon.Name = "ConfettiCannon"
	cannon.Size = Vector3.new(1, 1, 1)
	cannon.Position = Vector3.new(center.X, topY + 16, center.Z)
	cannon.Anchored = true
	cannon.CanCollide = false
	cannon.Transparency = 1
	cannon.Parent = stage

	confettiEmitter = Instance.new("ParticleEmitter")
	confettiEmitter.Rate = 0
	confettiEmitter.Lifetime = NumberRange.new(1.5, 2.5)
	confettiEmitter.Speed = NumberRange.new(10, 18)
	confettiEmitter.SpreadAngle = Vector2.new(50, 50)
	confettiEmitter.Size = NumberSequence.new(0.4)
	confettiEmitter.LightEmission = 0.4
	confettiEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 215, 0)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 105, 180)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(135, 206, 250)),
	})
	confettiEmitter.Rotation = NumberRange.new(0, 360)
	confettiEmitter.Parent = cannon
end

function TalentShowManager:HandleHostRequest(player)
	if activeShow then
		NotifyPlayer:FireClient(player, "A talent show is already happening - cheer them on!")
		return
	end

	local now = os.time()
	local remaining = SHOW.COOLDOWN - (now - lastShowEndTime)
	if lastShowEndTime > 0 and remaining > 0 then
		local minutes = math.ceil(remaining / 60)
		NotifyPlayer:FireClient(player, "The stage needs a rest! Next show in about " .. minutes .. " minute(s).")
		return
	end

	if not (self.PlayerDataService and self.PlayerDataService:GetData(player)) then
		return
	end

	self:StartShow(player)
end

function TalentShowManager:StartShow(player)
	activeShow = {
		host = player,
		hostName = player.Name,
		applause = 0,
		stars = 0,
		voting = false,
	}

	notifyAll("Talent show starting at Ella's Stage! " .. player.Name .. " is performing!")
	TalentShowEvent:FireAllClients({
		phase = "start",
		hostUserId = player.UserId,
		hostName = player.Name,
		duration = SHOW.DURATION,
	})

	-- Open the voting window for the final stretch
	task.delay(SHOW.DURATION - SHOW.VOTING_WINDOW, function()
		if not activeShow or activeShow.host ~= player then
			return
		end
		activeShow.voting = true
		TalentShowEvent:FireAllClients({
			phase = "voting",
			hostUserId = player.UserId,
			hostName = player.Name,
			duration = SHOW.VOTING_WINDOW,
		})
	end)

	-- End the show on schedule
	task.delay(SHOW.DURATION, function()
		if activeShow and activeShow.host == player then
			self:EndShow()
		end
	end)
end

function TalentShowManager:EndShow()
	local show = activeShow
	if not show then
		return
	end
	activeShow = nil
	lastShowEndTime = os.time()

	local total = show.applause + show.stars

	TalentShowEvent:FireAllClients({ phase = "end" })

	if confettiEmitter then
		confettiEmitter:Emit(80)
	end

	notifyAll(show.hostName .. " got " .. show.applause .. " applause and " .. show.stars .. " stars!")

	local host = show.host
	if host and host.Parent then
		-- Coins scale with votes, capped so a big server can't break the economy
		local coins = math.min(math.floor(total / SHOW.VOTES_PER_COIN), SHOW.MAX_COINS)
		if coins > 0 and self.CurrencyManager then
			self.CurrencyManager:AddCurrency(host, coins, "Talent show applause")
		end

		-- Persist stats (fields exist via migration-safe defaults)
		local data = self.PlayerDataService and self.PlayerDataService:GetData(host)
		if data then
			self.PlayerDataService:UpdateData(host, "TalentShowsHosted", (data.TalentShowsHosted or 0) + 1)
			self.PlayerDataService:UpdateData(host, "BestApplause", math.max(data.BestApplause or 0, total))
		end
	end
end

-- Audience vote: rate-limited, voting window only, never the performer
function TalentShowManager:HandleVote(player, voteType)
	local show = activeShow
	if not show or not show.voting then
		return
	end
	if show.host == player then
		return -- Performers can't vote for themselves
	end
	if voteType ~= "applause" and voteType ~= "star" then
		return
	end

	local now = os.clock()
	if lastVoteTime[player.UserId] and now - lastVoteTime[player.UserId] < SHOW.VOTE_RATE_LIMIT then
		return
	end
	lastVoteTime[player.UserId] = now

	if voteType == "applause" then
		show.applause = show.applause + 1
	else
		show.stars = show.stars + 1
	end
end

function TalentShowManager:Init(playerDataService, currencyManager)
	self.PlayerDataService = playerDataService
	self.CurrencyManager = currencyManager

	buildHostSpot()

	TalentShowVote.OnServerEvent:Connect(function(player, voteType)
		self:HandleVote(player, voteType)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastVoteTime[player.UserId] = nil
		-- If the host leaves mid-show, wrap up gracefully
		if activeShow and activeShow.host == player then
			self:EndShow()
		end
	end)

	print("TalentShowManager initialized: talent shows ready at Ella's Stage")
end

return TalentShowManager
