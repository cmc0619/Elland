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
local InteractionManager = require(ServerScriptService.InteractionManager)

-- Initialize services in order
print("Initializing PlayerDataService...")
PlayerDataService:Init()

print("Initializing CurrencyManager...")
CurrencyManager:Init(PlayerDataService)

-- Build the world FIRST (creates spawn locations)
print("Building World...")
WorldBuilder:BuildWorld()

-- Initialize ZoneManager AFTER world is built (needs spawn locations)
print("Initializing ZoneManager...")
ZoneManager:Init()

print("Initializing WordleManager...")
WordleManager:Init(PlayerDataService, CurrencyManager)

print("Initializing InteractionManager...")
InteractionManager:Init()

print("======================")
print("Elland Server Ready!")
print("======================")
