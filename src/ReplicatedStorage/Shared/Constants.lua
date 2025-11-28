--[[
	Constants
	Shared constants accessible by both client and server
	Central configuration for game-wide settings
]]

local Constants = {}

-- Game Info
Constants.GAME_NAME = "Elland"
Constants.VERSION = "0.1.0"

-- Currency
Constants.CURRENCY_NAME = "Coins"
Constants.STARTING_CURRENCY = 100

-- Experience and Leveling
Constants.XP_PER_LEVEL = 100
Constants.XP_MULTIPLIER = 1.5 -- Each level requires 1.5x more XP

-- Zones
Constants.ZONES = {
	Hub = {
		Name = "Central Hub",
		Color = Color3.fromRGB(200, 200, 200),
		Icon = "rbxassetid://0", -- Replace with actual asset IDs
	},
	WordGarden = {
		Name = "Word Garden",
		Color = Color3.fromRGB(100, 200, 100),
		Icon = "rbxassetid://0",
	},
	FashionDistrict = {
		Name = "Fashion District",
		Color = Color3.fromRGB(255, 150, 200),
		Icon = "rbxassetid://0",
	},
	MathAcademy = {
		Name = "Math Academy",
		Color = Color3.fromRGB(100, 150, 255),
		Icon = "rbxassetid://0",
	},
	CreativeCommons = {
		Name = "Creative Commons",
		Color = Color3.fromRGB(255, 200, 100),
		Icon = "rbxassetid://0",
	},
}

-- UI Settings
Constants.UI = {
	ANIMATION_SPEED = 0.3,
	CURRENCY_DISPLAY_DURATION = 2,
	NOTIFICATION_DURATION = 3,
}

-- Word Garden Settings
Constants.WORD_GARDEN = {
	MIN_WORD_LENGTH = 3,
	MAX_WORD_LENGTH = 10,
	TIME_PER_PUZZLE = 60,
	BONUS_TIME = 10,
}

-- Fashion District Settings
Constants.FASHION_DISTRICT = {
	MAX_OUTFIT_SLOTS = 10,
	MAX_ITEMS_PER_OUTFIT = 8,
	SHOWCASE_DURATION = 30,
}

-- Math Academy Settings
Constants.MATH_ACADEMY = {
	PROBLEMS_PER_QUIZ = 10,
	TIME_PER_PROBLEM = 30,
	DIFFICULTY_LEVELS = {"Easy", "Medium", "Hard"},
}

-- Creative Commons Settings
Constants.CREATIVE_COMMONS = {
	MAX_BUILDS = 20,
	MAX_PARTS_PER_BUILD = 500,
	SAVE_COOLDOWN = 5,
}

-- Color Palette
Constants.COLORS = {
	PRIMARY = Color3.fromRGB(88, 101, 242),
	SECONDARY = Color3.fromRGB(67, 181, 129),
	SUCCESS = Color3.fromRGB(67, 181, 129),
	WARNING = Color3.fromRGB(250, 166, 26),
	ERROR = Color3.fromRGB(237, 66, 69),
	TEXT_PRIMARY = Color3.fromRGB(255, 255, 255),
	TEXT_SECONDARY = Color3.fromRGB(200, 200, 200),
	BACKGROUND = Color3.fromRGB(32, 34, 37),
	BACKGROUND_SECONDARY = Color3.fromRGB(47, 49, 54),
}

-- Sound Settings
Constants.SOUNDS = {
	MUSIC_VOLUME = 0.7,
	SFX_VOLUME = 0.8,
	UI_VOLUME = 0.5,
}

-- Remote Events/Functions Names
Constants.REMOTES = {
	CURRENCY_CHANGED = "CurrencyChanged",
	PURCHASE_REQUEST = "PurchaseRequest",
	TELEPORT_REQUEST = "TeleportRequest",
	DATA_LOADED = "DataLoaded",
}

-- Utility Functions
function Constants.GetLevelFromXP(xp)
	local level = 1
	local xpRequired = Constants.XP_PER_LEVEL

	while xp >= xpRequired do
		xp = xp - xpRequired
		level = level + 1
		xpRequired = math.floor(xpRequired * Constants.XP_MULTIPLIER)
	end

	return level, xp, xpRequired
end

function Constants.GetXPForLevel(level)
	local totalXP = 0
	local xpRequired = Constants.XP_PER_LEVEL

	for i = 1, level - 1 do
		totalXP = totalXP + xpRequired
		xpRequired = math.floor(xpRequired * Constants.XP_MULTIPLIER)
	end

	return totalXP
end

return Constants
