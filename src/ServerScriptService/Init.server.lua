--[[
	Init.server.lua
	Main server initialization script
	Loads and initializes all core services
]]

local ServerScriptService = game:GetService("ServerScriptService")

print("======================")
print("Elland Server Starting")
print("======================")

-- Load services
local PlayerDataService = require(ServerScriptService.PlayerDataService)
local CurrencyManager = require(ServerScriptService.CurrencyManager)
local ZoneManager = require(ServerScriptService.ZoneManager)
local WordleManager = require(ServerScriptService.WordleManager)
local WorldBuilder = require(ServerScriptService.WorldBuilder)
local PolishBuilder = require(ServerScriptService.PolishBuilder)
local NatureBuilder = require(ServerScriptService.NatureBuilder)
local BuildingSandbox = require(ServerScriptService.BuildingSandbox)
local ObbyManager = require(ServerScriptService.ObbyManager)
local SoccerManager = require(ServerScriptService.SoccerManager)
local StageManager = require(ServerScriptService.StageManager)
local TalentShowManager = require(ServerScriptService.TalentShowManager)
local NutcrackerBuilder = require(ServerScriptService.NutcrackerBuilder)
local FamilyBuilder = require(ServerScriptService.FamilyBuilder)
local PetManager = require(ServerScriptService.PetManager)
local BakeryManager = require(ServerScriptService.BakeryManager)
local HuntManager = require(ServerScriptService.HuntManager)
local SeasonManager = require(ServerScriptService.SeasonManager)
local InteractionManager = require(ServerScriptService.InteractionManager)

-- Initialize services in order
print("Initializing PlayerDataService...")
PlayerDataService:Init()

print("Initializing CurrencyManager...")
CurrencyManager:Init(PlayerDataService)

-- Build the world FIRST (creates spawn locations)
print("Building World...")
WorldBuilder:BuildWorld()

-- Visual polish + nature scatter right after the base world
print("Applying lighting and polish...")
PolishBuilder:Build()

print("Scattering nature...")
NatureBuilder:Build()

-- Attractions and activities (all need the base terrain/structures)
print("Initializing BuildingSandbox...")
BuildingSandbox:Init()

print("Initializing ObbyManager...")
ObbyManager:Init(CurrencyManager)

print("Initializing SoccerManager...")
SoccerManager:Init(CurrencyManager)

print("Initializing StageManager...")
StageManager:Init(CurrencyManager)

print("Initializing TalentShowManager...")
TalentShowManager:Init(PlayerDataService, CurrencyManager)

print("Building Nutcracker Plaza...")
NutcrackerBuilder:Build()

print("Building family touches...")
FamilyBuilder:Build()

print("Initializing PetManager...")
PetManager:Init(PlayerDataService, CurrencyManager)

print("Initializing BakeryManager...")
BakeryManager:Init(PlayerDataService, CurrencyManager)

print("Initializing HuntManager...")
HuntManager:Init(PlayerDataService, CurrencyManager)

-- Seasonal overlay AFTER the world, polish, nature, and plaza exist
print("Applying seasonal decorations...")
SeasonManager:Init()

-- Initialize ZoneManager AFTER world is built (needs spawn locations)
print("Initializing ZoneManager...")
ZoneManager:Init()

print("Initializing WordleManager...")
WordleManager:Init(PlayerDataService, CurrencyManager)

print("Initializing InteractionManager...")
InteractionManager:Init(PlayerDataService, CurrencyManager)

print("======================")
print("Elland Server Ready!")
print("======================")
