--[[
	WordleManager
	Manages Wordle game logic, daily words, and player attempts
	Server-authoritative word checking and scoring
	
	Uses external API for words: https://random-words-api.kushcreates.com/
	NOTE: You must enable HttpService in Game Settings > Security > Allow HTTP Requests
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

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

-- Cache of valid words fetched from API
local validWordsCache = {}
local apiAvailable = false

-- API Configuration
local WORD_API_BASE = "https://random-words-api.kushcreates.com/api"

-- Fetch words from API
local function fetchWordsFromAPI(count)
	local url = WORD_API_BASE .. "?category=wordle&length=5&type=uppercase&words=" .. tostring(count or 100)
	
	local success, result = pcall(function()
		local response = HttpService:GetAsync(url)
		return HttpService:JSONDecode(response)
	end)
	
	if success and type(result) == "table" then
		print("WordleManager: Fetched", #result, "words from API")
		return result
	else
		warn("WordleManager: API fetch failed -", result)
		return nil
	end
end

-- Initialize word cache from API
local function initializeWordCache()
	print("WordleManager: Initializing word cache from API...")
	
	local words = fetchWordsFromAPI(500) -- Get a good selection of valid words
	
	if words and #words > 0 then
		for _, word in ipairs(words) do
			if type(word) == "string" then
				validWordsCache[word:upper()] = true
			end
		end
		apiAvailable = true
		print("WordleManager: Loaded", #words, "words into validation cache")
	else
		-- Fall back to hardcoded list
		warn("WordleManager: API unavailable, using fallback word list")
		for _, word in ipairs(Constants.WORDLE.WORDS) do
			validWordsCache[word:upper()] = true
		end
		apiAvailable = false
	end
end

-- Get today's date string
local function getTodayDate()
	local now = os.time()
	local date = os.date("*t", now)
	return string.format("%04d-%02d-%02d", date.year, date.month, date.day)
end

-- Select daily word (from API if available, otherwise fallback)
local function selectDailyWord()
	local today = getTodayDate()

	if today ~= lastWordDate then
		-- New day, select new word
		lastWordDate = today
		
		if apiAvailable then
			-- Try to get a fresh word from API
			local words = fetchWordsFromAPI(1)
			if words and #words > 0 and type(words[1]) == "string" then
				currentDailyWord = words[1]:upper()
				-- Also add to our valid words cache
				validWordsCache[currentDailyWord] = true
				print("Daily Wordle word fetched from API for", today)
				return currentDailyWord
			end
		end
		
		-- Fallback: pick from our cache or Constants
		local wordList = {}
		for word, _ in pairs(validWordsCache) do
			table.insert(wordList, word)
		end
		
		if #wordList == 0 then
			wordList = Constants.WORDLE.WORDS
		end
		
		-- Create deterministic seed from date
		local seed = 0
		for i = 1, #today do
			seed = seed + string.byte(today, i)
		end
		math.randomseed(seed)
		
		currentDailyWord = wordList[math.random(1, #wordList)]:upper()
		print("Daily Wordle word selected (fallback) for", today)
	end

	return currentDailyWord
end

-- Check if a guess is valid (is it a real word?)
-- Check if a guess is valid (is it a real word?)
local function isValidWord(word)
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
	
	-- If API is available, validate against our cache
	if apiAvailable and next(validWordsCache) then
		return validWordsCache[word] == true
	end
	
	-- If API unavailable, accept any alphabetic 5-letter word
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
		local errorMsg = "Not in word list"
		if not apiAvailable then
			errorMsg = "Not a valid word"
		end
		WordleResult:FireClient(player, {
			success = false,
			error = errorMsg
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
		print("WordleManager: Player won! Awarding", Constants.WORDLE.DAILY_REWARD, "coins")
		if self.CurrencyManager then
			local success = self.CurrencyManager:AddCurrency(player, Constants.WORDLE.DAILY_REWARD, "Wordle Daily Complete")
			print("WordleManager: Currency award success:", success)
		else
			warn("WordleManager: CurrencyManager is nil! Cannot award coins!")
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

	-- Initialize word cache from API (do this first!)
	initializeWordCache()
	
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
	if apiAvailable then
		print("WordleManager: Using Random Words API for word generation")
	else
		print("WordleManager: Using fallback word list (enable HttpService for API access)")
	end
end

return WordleManager
