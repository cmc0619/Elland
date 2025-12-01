--[[
	WordleManager
	Manages Wordle game logic, daily words, and player attempts
	Server-authoritative word checking and scoring
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WordleManager = {}
WordleManager.PlayerDataService = nil
WordleManager.CurrencyManager = nil

local Constants = require(ReplicatedStorage.Shared.Constants)

-- Remote Events
local WordleGuess = Instance.new("RemoteEvent")
WordleGuess.Name = "WordleGuess"
WordleGuess.Parent = ReplicatedStorage

local WordleResult = Instance.new("RemoteEvent")
WordleResult.Name = "WordleResult"
WordleResult.Parent = ReplicatedStorage

local WordleNewGame = Instance.new("RemoteEvent")
WordleNewGame.Name = "WordleNewGame"
WordleNewGame.Parent = ReplicatedStorage

-- Daily word selection (resets at midnight)
local currentDailyWord = nil
local lastWordDate = nil

-- Get today's date string
local function getTodayDate()
	local now = os.time()
	local date = os.date("*t", now)
	return string.format("%04d-%02d-%02d", date.year, date.month, date.day)
end

-- Select daily word
local function selectDailyWord()
	local today = getTodayDate()

	if today ~= lastWordDate then
		-- New day, select new word
		local words = Constants.WORDLE.WORDS
		local seed = 0

		-- Create deterministic seed from date
		for i = 1, #today do
			seed = seed + string.byte(today, i)
		end

		math.randomseed(seed)
		currentDailyWord = words[math.random(1, #words)]
		lastWordDate = today

		print("Daily Wordle word selected for", today)
	end

	return currentDailyWord
end

-- Check if a guess is valid (is it a real word?)
local function isValidWord(word)
	-- Accept any 5-letter alphabetic word for now
	-- This makes the game more fun and less frustrating
	word = word:upper()
	
	-- Check it's the right length
	if #word ~= Constants.WORDLE.WORD_LENGTH then
		return false
	end
	
	-- Check all characters are letters A-Z
	for i = 1, #word do
		local char = word:sub(i, i)
		if char < "A" or char > "Z" then
			return false
		end
	end
	
	return true
end

-- Check guess against target word
-- Returns array of results: "correct", "present", "absent"
local function checkGuess(guess, target)
	guess = guess:upper()
	target = target:upper()

	local result = {}
	local targetLetters = {}

	-- Count letters in target
	for i = 1, #target do
		local letter = target:sub(i, i)
		targetLetters[letter] = (targetLetters[letter] or 0) + 1
	end

	-- First pass: mark correct positions
	for i = 1, #guess do
		local guessLetter = guess:sub(i, i)
		local targetLetter = target:sub(i, i)

		if guessLetter == targetLetter then
			result[i] = {
				letter = guessLetter,
				status = "correct"
			}
			targetLetters[guessLetter] = targetLetters[guessLetter] - 1
		end
	end

	-- Second pass: mark present/absent
	for i = 1, #guess do
		if not result[i] then
			local guessLetter = guess:sub(i, i)

			if targetLetters[guessLetter] and targetLetters[guessLetter] > 0 then
				result[i] = {
					letter = guessLetter,
					status = "present"
				}
				targetLetters[guessLetter] = targetLetters[guessLetter] - 1
			else
				result[i] = {
					letter = guessLetter,
					status = "absent"
				}
			end
		end
	end

	return result
end

-- Get player's Wordle progress
function WordleManager:GetPlayerProgress(player)
	if not self.PlayerDataService then
		return nil
	end

	local data = self.PlayerDataService:GetData(player)
	if not data then
		return nil
	end

	-- Initialize Wordle data if it doesn't exist
	if not data.Wordle then
		data.Wordle = {
			LastPlayedDate = "",
			TodayAttempts = 0,
			TodayGuesses = {},
			TodayComplete = false,
			TodayWon = false,
			TotalGamesPlayed = 0,
			TotalWins = 0,
			CurrentStreak = 0,
			MaxStreak = 0,
		}
		self.PlayerDataService:UpdateData(player, "Wordle", data.Wordle)
	end

	return data.Wordle
end

-- Handle player guess
function WordleManager:HandleGuess(player, guess)
	print("WordleManager: Received guess from", player.Name, "-", guess)
	
	if #guess ~= Constants.WORDLE.WORD_LENGTH then
		print("WordleManager: Wrong length -", #guess, "vs", Constants.WORDLE.WORD_LENGTH)
		WordleResult:FireClient(player, {
			success = false,
			error = "Word must be " .. Constants.WORDLE.WORD_LENGTH .. " letters"
		})
		return
	end

	-- Check if valid word
	if not isValidWord(guess) then
		print("WordleManager: Invalid word -", guess)
		WordleResult:FireClient(player, {
			success = false,
			error = "Not a valid word"
		})
		return
	end
	
	print("WordleManager: Valid guess, processing...")

	local progress = self:GetPlayerProgress(player)
	local today = getTodayDate()

	-- Check if starting new day
	if progress.LastPlayedDate ~= today then
		progress.LastPlayedDate = today
		progress.TodayAttempts = 0
		progress.TodayGuesses = {}
		progress.TodayComplete = false
		progress.TodayWon = false
	end

	-- Check if already complete
	if progress.TodayComplete then
		WordleResult:FireClient(player, {
			success = false,
			error = "You've already completed today's Wordle!"
		})
		return
	end

	-- Check if max attempts reached
	if progress.TodayAttempts >= Constants.WORDLE.MAX_ATTEMPTS then
		WordleResult:FireClient(player, {
			success = false,
			error = "No more attempts left!"
		})
		return
	end

	-- Check the guess
	local dailyWord = selectDailyWord()
	local result = checkGuess(guess, dailyWord)

	progress.TodayAttempts = progress.TodayAttempts + 1
	table.insert(progress.TodayGuesses, {
		word = guess:upper(),
		result = result
	})

	-- Check if won
	local isCorrect = true
	for _, letterResult in ipairs(result) do
		if letterResult.status ~= "correct" then
			isCorrect = false
			break
		end
	end

	if isCorrect then
		progress.TodayComplete = true
		progress.TodayWon = true
		progress.TotalGamesPlayed = progress.TotalGamesPlayed + 1
		progress.TotalWins = progress.TotalWins + 1
		progress.CurrentStreak = progress.CurrentStreak + 1
		progress.MaxStreak = math.max(progress.MaxStreak, progress.CurrentStreak)

		-- Award currency
		if self.CurrencyManager then
			self.CurrencyManager:AddCurrency(player, Constants.WORDLE.DAILY_REWARD, "Wordle Daily Complete")
		end

		WordleResult:FireClient(player, {
			success = true,
			result = result,
			complete = true,
			won = true,
			attempts = progress.TodayAttempts,
			message = "Congratulations! You solved today's Wordle!",
			reward = Constants.WORDLE.DAILY_REWARD
		})
	elseif progress.TodayAttempts >= Constants.WORDLE.MAX_ATTEMPTS then
		-- Out of attempts
		progress.TodayComplete = true
		progress.TodayWon = false
		progress.TotalGamesPlayed = progress.TotalGamesPlayed + 1
		progress.CurrentStreak = 0

		WordleResult:FireClient(player, {
			success = true,
			result = result,
			complete = true,
			won = false,
			attempts = progress.TodayAttempts,
			message = "Out of attempts! The word was: " .. dailyWord
		})
	else
		-- Continue playing
		WordleResult:FireClient(player, {
			success = true,
			result = result,
			complete = false,
			attempts = progress.TodayAttempts,
			remaining = Constants.WORDLE.MAX_ATTEMPTS - progress.TodayAttempts
		})
	end

	-- Save progress
	self.PlayerDataService:UpdateData(player, "Wordle", progress)
end

-- Send current game state to player
function WordleManager:SendGameState(player)
	local progress = self:GetPlayerProgress(player)
	local today = getTodayDate()

	-- Reset if new day
	if progress.LastPlayedDate ~= today then
		progress.LastPlayedDate = today
		progress.TodayAttempts = 0
		progress.TodayGuesses = {}
		progress.TodayComplete = false
		progress.TodayWon = false
		self.PlayerDataService:UpdateData(player, "Wordle", progress)
	end

	WordleNewGame:FireClient(player, {
		attempts = progress.TodayAttempts,
		maxAttempts = Constants.WORDLE.MAX_ATTEMPTS,
		guesses = progress.TodayGuesses,
		complete = progress.TodayComplete,
		won = progress.TodayWon,
		stats = {
			totalGames = progress.TotalGamesPlayed,
			totalWins = progress.TotalWins,
			currentStreak = progress.CurrentStreak,
			maxStreak = progress.MaxStreak,
		}
	})
end

-- Initialize the manager
function WordleManager:Init(playerDataService, currencyManager)
	self.PlayerDataService = playerDataService
	self.CurrencyManager = currencyManager

	-- Select initial daily word
	selectDailyWord()

	-- Handle guess requests
	WordleGuess.OnServerEvent:Connect(function(player, guess)
		self:HandleGuess(player, guess)
	end)

	-- Handle new game requests
	WordleNewGame.OnServerEvent:Connect(function(player)
		self:SendGameState(player)
	end)

	print("WordleManager initialized")
end

return WordleManager
