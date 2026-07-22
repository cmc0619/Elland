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

-- Building sandbox needs the build platform from WorldBuilder
print("Initializing BuildingSandbox...")
BuildingSandbox:Init()

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
