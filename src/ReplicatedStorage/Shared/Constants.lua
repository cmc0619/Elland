--[[
	Constants
	Shared constants accessible by both client and server
	Central configuration for game-wide settings
]]

local Constants = {}

-- Game Info
Constants.GAME_NAME = "Elland"
Constants.VERSION = "0.2.0"

-- Currency
Constants.CURRENCY_NAME = "Coins"
Constants.STARTING_CURRENCY = 100

-- Experience and Leveling
Constants.XP_PER_LEVEL = 100
Constants.XP_MULTIPLIER = 1.5 -- Each level requires 1.5x more XP

-- World Layout Positions
Constants.WORLD = {
	GROUND_LEVEL = 10, -- Top surface of the base terrain (Y=0 to Y=10)
	RIVER_START = Vector3.new(-300, 8, -100), -- Slightly below ground for river bed
	RIVER_END = Vector3.new(300, 8, 100),
	TERRAIN_SIZE = Vector3.new(600, 10, 600),
}

-- Zones with world positions (terrain is Y=0 to Y=10, spawns at Y=12)
-- SpawnName matches the SpawnLocation created by WorldBuilder.
-- TODO: Icon assets still need to be created/uploaded; add rbxassetid here.
Constants.ZONES = {
	Hub = {
		Name = "By the River",
		Description = "The peaceful center of Elland",
		Position = Vector3.new(0, 12, 0),
		Color = Color3.fromRGB(100, 150, 255),
		SpawnName = "HubSpawn",
	},
	EllasLookout = {
		Name = "Ella's Lookout",
		Description = "A big hill with a tree and swing - perfect for thinking",
		Position = Vector3.new(200, 70, -200),
		Color = Color3.fromRGB(100, 200, 100),
		SpawnName = "LookoutSpawn",
	},
	EllasHouse = {
		Name = "Ella's House",
		Description = "Home sweet home",
		Position = Vector3.new(150, 12, -100), -- On ground level
		Color = Color3.fromRGB(255, 200, 150),
		SpawnName = "HouseSpawn",
	},
	WordleLibrary = {
		Name = "Wordle Library",
		Description = "Solve daily word puzzles and challenges",
		Position = Vector3.new(-200, 12, 200),
		Color = Color3.fromRGB(200, 150, 255),
		SpawnName = "LibrarySpawn",
	},
	FashionBoutique = {
		Name = "Fashion Boutique",
		Description = "Express yourself through style and design",
		Position = Vector3.new(200, 12, 200),
		Color = Color3.fromRGB(255, 150, 200),
		SpawnName = "BoutiqueSpawn",
	},
	BuildingArea = {
		Name = "Building Area",
		Description = "Create and build your own structures",
		Position = Vector3.new(-200, 12, -200),
		Color = Color3.fromRGB(255, 200, 100),
		SpawnName = "BuildingSpawn",
	},
}

-- UI Settings
Constants.UI = {
	ANIMATION_SPEED = 0.3,
	CURRENCY_DISPLAY_DURATION = 2,
	NOTIFICATION_DURATION = 3,
}

-- Golden-hour lighting settings (applied by PolishBuilder)
Constants.LIGHTING = {
	CLOCK_TIME = 17.2,
	GEOGRAPHIC_LATITUDE = 35,
	AMBIENT = Color3.fromRGB(95, 82, 78),
	OUTDOOR_AMBIENT = Color3.fromRGB(125, 112, 100),
	ATMOSPHERE_COLOR = Color3.fromRGB(255, 232, 205),
	ATMOSPHERE_DECAY = Color3.fromRGB(125, 105, 92),
	TINT = Color3.fromRGB(255, 245, 230),
}

-- Nature scatter settings (used by NatureBuilder)
Constants.NATURE = {
	TREE_COUNT = 24,
	TREE_SEED = 1123, -- Deterministic layout every server start
	FLOWER_PATCH_COUNT = 14,
	FLOWERS_PER_PATCH_MIN = 5,
	FLOWERS_PER_PATCH_MAX = 9,
	RIVER_CLEARANCE = 22, -- Keep trees/flowers away from the river channel
	PATH_CLEARANCE = 6, -- Keep trees off the walking paths
	MAP_EDGE = 285, -- Scatter bounds (map is 600x600 centered at origin)
	FLOWER_COLORS = {
		Color3.fromRGB(255, 105, 180), -- Pink
		Color3.fromRGB(255, 215, 0), -- Gold
		Color3.fromRGB(186, 85, 211), -- Purple
		Color3.fromRGB(255, 99, 71), -- Coral
		Color3.fromRGB(135, 206, 250), -- Sky blue
	},
}

-- Hub extras
Constants.HUB = {
	FOUNTAIN_OFFSET = Vector3.new(-16, 0, 24), -- Relative to Hub position, on land
}

-- Cobble paths connecting the Hub to each zone (built by PolishBuilder)
Constants.PATHS = {
	WIDTH = 6,
	SEGMENT_LENGTH = 8,
	LAMPPOST_INTERVAL = 5, -- One lamppost every N path segments
}

-- Wordle Library Settings
Constants.WORDLE = {
	WORD_LENGTH = 5,
	MAX_ATTEMPTS = 6,
	DAILY_REWARD = 50,
	-- Vendored word list: used as the offline fallback for the daily word
	-- (when the Random Words API is unreachable) and as the set of accepted
	-- guesses. 5-letter words appropriate for 11-13 year olds.
	WORDS = {
		"ABOUT", "APPLE", "BEACH", "BRAVE", "BREAD", "BRICK", "BRING",
		"CANDY", "CHAIR", "CHARM", "CLOUD", "CREEK", "DANCE", "DREAM",
		"EARTH", "FAIRY", "FLAME", "FLOUR", "FOUND", "FROGS", "GLOBE",
		"GRACE", "GRAPE", "GREEN", "HAPPY", "HEART", "HONEY", "HORSE",
		"HOUSE", "JUICE", "KNIFE", "LAUGH", "LEMON", "LIGHT", "MAGIC",
		"MANGO", "MELON", "MUSIC", "NIGHT", "OCEAN", "PAINT", "PEACE",
		"PEACH", "PIZZA", "PLANT", "QUEEN", "RIVER", "ROBOT", "SHINE",
		"SMILE", "SNAKE", "SPARK", "STARS", "STORY", "SUNNY", "SWEET",
		"SWIFT", "TABLE", "THINK", "TIGER", "TRAIL", "TRAIN", "TRUST",
		"VOICE", "WATER", "WHALE", "WHEEL", "WINGS", "WORLD", "WRITE",
		"YOUTH", "ZEBRA",
	},
}

-- Fashion Boutique Settings
Constants.FASHION = {
	-- Purchasable cosmetic items. This table is the single source of truth:
	-- CurrencyManager builds its server-side price catalog from it and the
	-- client FashionUI renders the shop from it. Buying records ownership in
	-- the player's saved data (Zones.FashionBoutique.OwnedItems).
	ITEMS = {
		{ Id = "FreshSneakers", Name = "Fresh Sneakers", Cost = 40, Description = "Comfy kicks for exploring Elland" },
		{ Id = "SparkleHat", Name = "Sparkle Hat", Cost = 50, Description = "A hat that catches the sunlight" },
		{ Id = "StarGlasses", Name = "Star Glasses", Cost = 60, Description = "See the world like a star" },
		{ Id = "DenimJacket", Name = "Denim Jacket", Cost = 75, Description = "Classic and cool" },
		{ Id = "FlowerCrown", Name = "Flower Crown", Cost = 80, Description = "Picked fresh from the meadow" },
		{ Id = "RainbowCape", Name = "Rainbow Cape", Cost = 100, Description = "For the hero of Elland" },
	},
}

-- Building Area Settings (legacy saved-build config; kept for future persistence)
Constants.BUILDING = {
	MAX_BUILDS = 20,
	MAX_PARTS_PER_BUILD = 500,
	SAVE_COOLDOWN = 5,
	ALLOWED_PARTS = {"Part", "Wedge", "Sphere", "Cylinder", "TrussPart"},
}

-- Building Area sandbox (live block-placing, handled by BuildingSandbox)
-- The plot is the BuildingPlatform built by WorldBuilder (80x80 at the zone).
Constants.BUILDING_SANDBOX = {
	GRID_SIZE = 2, -- Placement snaps to a 2-stud grid
	BLOCK_SIZE = Vector3.new(4, 2, 4),
	MAX_BLOCKS_PER_PLAYER = 200,
	PLACE_COOLDOWN = 0.15, -- Seconds between placements (rate limit)
	PLOT_HALF_SIZE = 38, -- Platform is 80 wide; keep blocks 2 studs from the edge
	MAX_BUILD_HEIGHT = 40, -- Blocks can stack up to 40 studs above the platform
	PASTEL_COLORS = {
		Color3.fromRGB(255, 179, 186), -- Pastel pink
		Color3.fromRGB(255, 223, 186), -- Pastel peach
		Color3.fromRGB(255, 255, 186), -- Pastel yellow
		Color3.fromRGB(186, 255, 201), -- Pastel green
		Color3.fromRGB(186, 225, 255), -- Pastel blue
		Color3.fromRGB(221, 196, 255), -- Pastel purple
	},
}

-- Ella's Obby (workout obstacle course near the Hub)
Constants.OBBY = {
	START = Vector3.new(-100, 10, 100), -- Start pad, well clear of the river
	SPACING = 14, -- Distance between platforms along +X
	LATERAL_ZIGZAG = 6, -- Side-to-side offset for jump variety
	RISE_PER_PLATFORM = 1.5, -- Course gently climbs
	PLATFORM_COUNT = 12,
	PLATFORM_SIZE = Vector3.new(6, 1, 6),
	CHECKPOINT_STAGES = { 0, 4, 8 }, -- Platforms with respawn checkpoints
	MOVING_STAGES = { [3] = true, [7] = true }, -- Platforms that slide side to side
	BLINKING_STAGES = { [5] = true, [6] = true, [9] = true }, -- Platforms that disappear
	MOVE_AMPLITUDE = 8,
	MOVE_PERIOD = 4, -- Seconds for a full back-and-forth
	BLINK_VISIBLE_TIME = 2.2,
	BLINK_HIDDEN_TIME = 0.9,
	WIN_REWARD = 25,
	WIN_COOLDOWN = 300, -- 5 minutes between winner-pad payouts
}

-- Soccer pitch near the Hub
Constants.SOCCER = {
	CENTER = Vector3.new(80, 10, 140), -- Well clear of the river
	FIELD_SIZE = Vector3.new(60, 1, 40), -- X = length (goal to goal), Z = width
	GOAL_WIDTH = 12,
	GOAL_HEIGHT = 6,
	GOAL_DEPTH = 6,
	BALL_SIZE = 4,
	KICK_POWER = 55,
	KICK_LIFT = 15, -- Upward pop so the ball bounces nicely
	KICK_DEBOUNCE = 0.75, -- Seconds between kicks per player
	GOAL_REWARD = 10,
	GOAL_COOLDOWN = 60, -- Seconds between coin payouts per player
	OUT_OF_BOUNDS_MARGIN = 15, -- Ball resets if it leaves field + margin
}

-- Concert stage (Philadelphia Girls Choir nod)
Constants.STAGE = {
	CENTER = Vector3.new(-40, 10, -140), -- Well clear of the river
	PLATFORM_SIZE = Vector3.new(30, 2, 20),
	PERFORM_REWARD = 15,
	PERFORM_COOLDOWN = 120, -- 2 minutes between payouts per player
	BILLBOARD_DURATION = 30, -- Seconds the performer's name stays up
	-- Song audio IDs for Perform! -- the owner must upload/license the audio
	-- in Roblox and paste the asset IDs here, e.g.:
	--   "rbxassetid://1234567890",
	-- Left empty on purpose: no audio plays until real IDs are added.
	CHOIR_SONGS = {},
}

-- Nutcracker Plaza (festive corner)
Constants.NUTCRACKER = {
	CENTER = Vector3.new(60, 10, -140), -- Well clear of the river
	PLAZA_SIZE = Vector3.new(34, 1, 34),
	TREE_TOUCH_COOLDOWN = 30, -- Seconds between tree twinkle messages per player
	TREE_MESSAGE = "Break a leg, Ella!",
}

-- Family touches
Constants.FAMILY = {
	PICNIC_CENTER = Vector3.new(128, 10, -132), -- Beside Ella's House
	PHOTO_SPOT = Vector3.new(118, 10, -150), -- Overlooking the path to the Lookout
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
