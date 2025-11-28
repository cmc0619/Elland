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

-- World Layout Positions
Constants.WORLD = {
	RIVER_START = Vector3.new(-300, 11, -100),  -- Raised above ground (Y=10)
	RIVER_END = Vector3.new(300, 11, 100),
	TERRAIN_SIZE = Vector3.new(600, 10, 600),
}

-- Zones with world positions (terrain is Y=0 to Y=10, spawns at Y=12)
Constants.ZONES = {
	Hub = {
		Name = "By the River",
		Description = "The peaceful center of Elland",
		Position = Vector3.new(0, 12, 0),
		Color = Color3.fromRGB(100, 150, 255),
		Icon = "rbxassetid://0",
	},
	EllasLookout = {
		Name = "Ella's Lookout",
		Description = "A big hill with a tree and swing - perfect for thinking",
		Position = Vector3.new(200, 70, -200),
		Color = Color3.fromRGB(100, 200, 100),
		Icon = "rbxassetid://0",
	},
	EllasHouse = {
		Name = "Ella's House",
		Description = "Home sweet home",
		Position = Vector3.new(150, 12, -100),  -- On ground level
		Color = Color3.fromRGB(255, 200, 150),
		Icon = "rbxassetid://0",
	},
	WordleLibrary = {
		Name = "Wordle Library",
		Description = "Solve daily word puzzles and challenges",
		Position = Vector3.new(-200, 12, 200),
		Color = Color3.fromRGB(200, 150, 255),
		Icon = "rbxassetid://0",
	},
	FashionBoutique = {
		Name = "Fashion Boutique",
		Description = "Express yourself through style and design",
		Position = Vector3.new(200, 12, 200),
		Color = Color3.fromRGB(255, 150, 200),
		Icon = "rbxassetid://0",
	},
	BuildingArea = {
		Name = "Building Area",
		Description = "Create and build your own structures",
		Position = Vector3.new(-200, 12, -200),
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

-- Wordle Library Settings
Constants.WORDLE = {
	WORD_LENGTH = 5,
	MAX_ATTEMPTS = 6,
	DAILY_REWARD = 50,
	WORDS = {
		-- 5-letter words appropriate for 11-13 year olds
		"APPLE", "BEACH", "BRAVE", "CREEK", "DANCE", "DREAM", "FAIRY",
		"FLAME", "GLOBE", "GRACE", "HEART", "HORSE", "HOUSE", "LAUGH",
		"LIGHT", "MAGIC", "MUSIC", "OCEAN", "PEACE", "PLANT", "RIVER",
		"SHINE", "SMILE", "SPARK", "STORY", "SWEET", "SWIFT", "THINK",
		"TRAIL", "TRUST", "VOICE", "WATER", "WORLD", "WRITE", "YOUTH",
	},
}

-- Fashion Boutique Settings
Constants.FASHION = {
	MAX_OUTFIT_SLOTS = 10,
	MAX_ITEMS_PER_OUTFIT = 8,
	SHOWCASE_DURATION = 30,
	CLOTHING_CATEGORIES = {"Tops", "Bottoms", "Shoes", "Accessories", "Hair"},
}

-- Building Area Settings
Constants.BUILDING = {
	MAX_BUILDS = 20,
	MAX_PARTS_PER_BUILD = 500,
	SAVE_COOLDOWN = 5,
	ALLOWED_PARTS = {"Part", "Wedge", "Sphere", "Cylinder", "TrussPart"},
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
