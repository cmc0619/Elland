--[[
	HuntManager
	Music Note Hunt: 10 glowing eighth-note pickups hidden around the
	whole map (hilltop, riverbank, boutique, stage, obby finish, plaza,
	library, house, picnic, building area). Each note is a gold neon
	model (note head + stem + flag) with sparkles, a point light, and a
	server Heartbeat spin/bob loop.

	Collection is server-side and once per player: touched notes are
	recorded in player data (HuntNotes, persisted by PlayerDataService),
	pay a small Coin reward, and toast progress ("Note 4/10 found!").
	Collecting all 10 pays a big reward, bursts confetti at the player,
	sends a special toast, and sets HuntCompleted = true.

	Notes never respawn for a player who already collected them: on join
	(and after each pickup) the server fires HuntNoteUpdate with that
	player's collected indexes, and HuntClient hides those notes locally.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)

local HuntManager = {}
HuntManager.PlayerDataService = nil
HuntManager.CurrencyManager = nil

-- RemoteEvent (created at module load so clients can WaitForChild it)
local HuntNoteUpdate = Instance.new("RemoteEvent")
HuntNoteUpdate.Name = "HuntNoteUpdate"
HuntNoteUpdate.Parent = ReplicatedStorage

-- Shared one-line notification channel (ClientController shows the toast)
local NotifyPlayer = ReplicatedStorage:FindFirstChild("NotifyPlayer")
if not NotifyPlayer then
	NotifyPlayer = Instance.new("RemoteEvent")
	NotifyPlayer.Name = "NotifyPlayer"
	NotifyPlayer.Parent = ReplicatedStorage
end

local HUNT = Constants.HUNT
local TOTAL_NOTES = #HUNT.NOTES

-- Spin/bob animation state: { model, baseCFrame, phase }
local animatedNotes = {}
-- player.UserId -> { [noteIndex] = os.clock() } touch debounce
local touchDebounce = {}

-- One glowing eighth note: head ball + stem + flag, gold neon
local function buildNote(parent, index, position)
	local model = Instance.new("Model")
	model.Name = "Note" .. index
	model:SetAttribute("NoteIndex", index)

	local gold = Color3.fromRGB(255, 205, 60)

	local function part(name, shape, size, offset)
		local p = Instance.new("Part")
		p.Name = name
		if shape then
			p.Shape = shape
		end
		p.Size = size
		p.CFrame = CFrame.new(position + offset)
		p.Anchored = true
		p.CanCollide = false
		p.Color = gold
		p.Material = Enum.Material.Neon
		p.Parent = model
		return p
	end

	-- Note head (slightly flattened ball), stem rising from its right side
	local head = part("NoteHead", Enum.PartType.Ball, Vector3.new(1.8, 1.4, 1.8), Vector3.new(0, 0, 0))
	part("Stem", nil, Vector3.new(0.35, 3.4, 0.35), Vector3.new(0.85, 1.7, 0))
	part("Flag", nil, Vector3.new(1.1, 0.7, 0.3), Vector3.new(0.55, 3.3, 0))

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.Rate = 6
	sparkles.Lifetime = NumberRange.new(0.5, 1)
	sparkles.Speed = NumberRange.new(1, 2)
	sparkles.Size = NumberSequence.new(0.3)
	sparkles.LightEmission = 0.8
	sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 225, 140))
	sparkles.Parent = head

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 215, 100)
	light.Brightness = 1.2
	light.Range = 12
	light.Parent = head

	model.PrimaryPart = head
	model.Parent = parent
	return model, head
end

local function playerFromHit(hit)
	local character = hit and hit.Parent
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

function HuntManager:GetCollected(player)
	local data = self.PlayerDataService and self.PlayerDataService:GetData(player)
	if data and data.HuntNotes then
		return data.HuntNotes
	end
	return {}
end

-- Tell the client which notes to hide + the running count for the HUD
function HuntManager:SendProgress(player)
	local data = self.PlayerDataService and self.PlayerDataService:GetData(player)
	if not data then
		return
	end
	HuntNoteUpdate:FireClient(player, data.HuntNotes or {}, data.HuntCompleted == true, TOTAL_NOTES)
end

-- Confetti burst at the player for the big completion moment
local function burstConfetti(player)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	local confetti = Instance.new("ParticleEmitter")
	confetti.Rate = 0
	confetti.Lifetime = NumberRange.new(1, 2)
	confetti.Speed = NumberRange.new(12, 20)
	confetti.SpreadAngle = Vector2.new(180, 180)
	confetti.Size = NumberSequence.new(0.4)
	confetti.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 105, 180)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(135, 206, 250)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 215, 0)),
	})
	confetti.Parent = rootPart
	confetti:Emit(100)
	task.delay(3, function()
		confetti:Destroy()
	end)
end

function HuntManager:HandleNoteTouched(player, noteIndex)
	local data = self.PlayerDataService and self.PlayerDataService:GetData(player)
	if not data then
		return
	end

	local collected = data.HuntNotes or {}
	if table.find(collected, noteIndex) then
		return -- Already found by this player
	end

	table.insert(collected, noteIndex)
	self.PlayerDataService:UpdateData(player, "HuntNotes", collected)

	local found = #collected

	if found >= TOTAL_NOTES and not data.HuntCompleted then
		-- The full set: big reward, confetti, special toast
		self.PlayerDataService:UpdateData(player, "HuntCompleted", true)
		if self.CurrencyManager then
			self.CurrencyManager:AddCurrency(player, HUNT.COMPLETE_REWARD, "Music Note Hunt complete")
		end
		burstConfetti(player)
		NotifyPlayer:FireClient(player, "You found every music note! Elland sings for you!")
	elseif self.CurrencyManager then
		self.CurrencyManager:AddCurrency(player, HUNT.NOTE_REWARD, "Music note " .. found .. "/" .. TOTAL_NOTES)
		NotifyPlayer:FireClient(player, "Note " .. found .. "/" .. TOTAL_NOTES .. " found!")
	end

	self:SendProgress(player)
end

function HuntManager:BuildNotes()
	local old = Workspace:FindFirstChild("MusicNotes")
	if old then
		old:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "MusicNotes"
	folder.Parent = Workspace

	table.clear(animatedNotes)

	for index, position in ipairs(HUNT.NOTES) do
		local model, head = buildNote(folder, index, position)

		table.insert(animatedNotes, {
			model = model,
			base = CFrame.new(position),
			phase = index * 0.9, -- Stagger so they don't bob in sync
		})

		head.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			if not player then
				return
			end
			local now = os.clock()
			local playerTouches = touchDebounce[player.UserId]
			if playerTouches and playerTouches[index] and now - playerTouches[index] < 2 then
				return
			end
			if not playerTouches then
				playerTouches = {}
				touchDebounce[player.UserId] = playerTouches
			end
			playerTouches[index] = now

			self:HandleNoteTouched(player, index)
		end)
	end
end

-- Slow spin + gentle bob for every note (like the obby moving platforms)
function HuntManager:StartAnimationLoop()
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for _, note in ipairs(animatedNotes) do
			if note.model.Parent then
				local bob = math.sin(t * 1.6 + note.phase) * HUNT.BOB_AMPLITUDE
				local spin = CFrame.Angles(0, t * HUNT.SPIN_SPEED + note.phase, 0)
				note.model:PivotTo(note.base * spin + Vector3.new(0, bob, 0))
			end
		end
	end)
end

function HuntManager:Init(playerDataService, currencyManager)
	self.PlayerDataService = playerDataService
	self.CurrencyManager = currencyManager

	self:BuildNotes()
	self:StartAnimationLoop()

	-- Send returning players their progress so collected notes stay hidden
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			-- Wait for PlayerDataService to finish loading
			while not self.PlayerDataService:GetData(player) and player.Parent do
				task.wait(0.5)
			end
			if player.Parent then
				self:SendProgress(player)
			end
		end)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			task.wait(1)
			self:SendProgress(player)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		touchDebounce[player.UserId] = nil
	end)

	print("HuntManager initialized: " .. TOTAL_NOTES .. " music notes hidden around Elland")
end

return HuntManager
