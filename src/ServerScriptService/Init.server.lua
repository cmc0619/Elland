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

-- Initialize services in order
print("Initializing PlayerDataService...")
PlayerDataService:Init()

print("Initializing CurrencyManager...")
CurrencyManager:Init(PlayerDataService)

print("Initializing ZoneManager...")
ZoneManager:Init()

print("======================")
print("Elland Server Ready!")
print("======================")
