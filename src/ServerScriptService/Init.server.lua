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

-- Initialize services in order
print("Initializing PlayerDataService...")
PlayerDataService:Init()

print("Initializing CurrencyManager...")
CurrencyManager:Init(PlayerDataService)

print("Initializing ZoneManager...")
ZoneManager:Init()

print("Initializing WordleManager...")
WordleManager:Init(PlayerDataService, CurrencyManager)

-- Optional: Build the world (comment out after first run)
-- Uncomment the lines below and run once in Studio to build the world
-- Then comment them out again to prevent rebuilding every time
--[[
print("Building World...")
WorldBuilder:BuildWorld()
print("World building complete! Comment out WorldBuilder in Init.server.lua")
--]]

print("======================")
print("Elland Server Ready!")
print("======================")
