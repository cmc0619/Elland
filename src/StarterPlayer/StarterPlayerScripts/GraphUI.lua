--[[
	GraphUI
	The Graphing Easel at the Algebra Academy. The "Graph an equation"
	prompt (server) fires OpenGraphUI; the player types an equation and
	the client parses it with the SHARED EquationParser module, then draws
	the graph on the easel's graph-paper SurfaceGui:

	  - Grid lines, highlighted axes, integer labels -10..10
	  - Linear / horizontal / vertical: one thin rotated Frame segment,
	    clipped to the visible range
	  - Quadratic: a polyline of 40 small segments sampling the curve over
	    x in [-10, 10], clipped to the visible y range

	Rendering is fully client-side and local-only, so every interacting
	player gets their own view of the easel. On the first successful graph
	per session the client also fires GraphBonusRequest; the server
	re-parses with the same shared module before paying +2 Coins.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local EquationParser = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EquationParser"))

local GraphUI = {}
GraphUI.ScreenGui = nil

local OpenGraphUI
local GraphBonusRequest

local inputBox
local errorLabel
local bonusSentThisSession = false

local RANGE = 10 -- Graph window is [-10, 10] on both axes
local GRID_COLOR = Color3.fromRGB(200, 212, 228)
local AXIS_COLOR = Color3.fromRGB(60, 70, 90)
local GRAPH_COLOR = Color3.fromRGB(220, 60, 90)
local LABEL_COLOR = Color3.fromRGB(90, 100, 120)

--------------------------------------------------------------------------------
-- Easel graph paper (workspace SurfaceGui, edited locally per player)
--------------------------------------------------------------------------------

local function getGraphArea()
	local academy = Workspace:FindFirstChild("AlgebraAcademy")
	local board = academy and academy:FindFirstChild("GraphBoard")
	local gui = board and board:FindFirstChild("GraphPaperGui")
	return gui and gui:FindFirstChild("GraphArea")
end

-- Map graph coordinates to pixels inside the area
local function toPixel(x, y, width, height)
	return (x + RANGE) / (2 * RANGE) * width, (RANGE - y) / (2 * RANGE) * height
end

local function drawSegment(layer, x1, y1, x2, y2, width, height, color, thickness)
	local ax, ay = toPixel(x1, y1, width, height)
	local bx, by = toPixel(x2, y2, width, height)
	local dx, dy = bx - ax, by - ay
	local length = math.sqrt(dx * dx + dy * dy)
	if length < 0.5 then
		return
	end

	local line = Instance.new("Frame")
	line.Name = "Segment"
	line.BorderSizePixel = 0
	line.BackgroundColor3 = color
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Size = UDim2.new(0, length, 0, thickness or 3)
	line.Position = UDim2.new(0, (ax + bx) / 2, 0, (ay + by) / 2)
	line.Rotation = math.deg(math.atan2(dy, dx))
	line.Parent = layer
end

-- One-time grid: lines at every integer, bold axes, labels -10..10
local function ensureGrid(area)
	if area:FindFirstChild("GridLayer") then
		return
	end

	local grid = Instance.new("Frame")
	grid.Name = "GridLayer"
	grid.Size = UDim2.new(1, 0, 1, 0)
	grid.BackgroundTransparency = 1
	grid.Parent = area

	local width, height = area.AbsoluteSize.X, area.AbsoluteSize.Y

	for i = -RANGE, RANGE do
		local isAxis = (i == 0)
		-- Vertical grid line at x = i
		drawSegment(grid, i, -RANGE, i, RANGE, width, height, isAxis and AXIS_COLOR or GRID_COLOR, isAxis and 3 or 1)
		-- Horizontal grid line at y = i
		drawSegment(grid, -RANGE, i, RANGE, i, width, height, isAxis and AXIS_COLOR or GRID_COLOR, isAxis and 3 or 1)

		-- Axis labels: x along the bottom, y along the left
		local px, pyBottom = toPixel(i, -RANGE, width, height)
		local xLabel = Instance.new("TextLabel")
		xLabel.Size = UDim2.new(0, 24, 0, 12)
		xLabel.Position = UDim2.new(0, px - 12, 0, pyBottom - 12)
		xLabel.BackgroundTransparency = 1
		xLabel.Text = tostring(i)
		xLabel.TextColor3 = LABEL_COLOR
		xLabel.TextSize = 9
		xLabel.Font = Enum.Font.Gotham
		xLabel.Parent = grid

		local pxLeft, py = toPixel(-RANGE, i, width, height)
		local yLabel = Instance.new("TextLabel")
		yLabel.Size = UDim2.new(0, 24, 0, 12)
		yLabel.Position = UDim2.new(0, pxLeft + 2, 0, py - 6)
		yLabel.BackgroundTransparency = 1
		yLabel.Text = tostring(i)
		yLabel.TextColor3 = LABEL_COLOR
		yLabel.TextSize = 9
		yLabel.Font = Enum.Font.Gotham
		yLabel.Parent = grid
	end
end

-- Clip a linear segment (from x=-10 to x=10) against the visible y range
local function clipLinear(m, b)
	local function yAt(x)
		return m * x + b
	end
	local x1, y1 = -RANGE, yAt(-RANGE)
	local x2, y2 = RANGE, yAt(RANGE)

	if (y1 > RANGE and y2 > RANGE) or (y1 < -RANGE and y2 < -RANGE) then
		return nil -- Entirely off the page
	end

	local function clip(xa, ya, xb, yb)
		if ya > RANGE then
			local t = (RANGE - ya) / (yb - ya)
			xa, ya = xa + t * (xb - xa), RANGE
		elseif ya < -RANGE then
			local t = (-RANGE - ya) / (yb - ya)
			xa, ya = xa + t * (xb - xa), -RANGE
		end
		return xa, ya
	end

	if m ~= 0 then
		x1, y1 = clip(x1, y1, x2, y2)
		x2, y2 = clip(x2, y2, x1, y1)
	end
	return x1, y1, x2, y2
end

local function renderEquation(parsed)
	local area = getGraphArea()
	if not area then
		return false
	end

	ensureGrid(area)

	-- Replace the previous graph (per-player, local only)
	local old = area:FindFirstChild("GraphLayer")
	if old then
		old:Destroy()
	end
	local layer = Instance.new("Frame")
	layer.Name = "GraphLayer"
	layer.Size = UDim2.new(1, 0, 1, 0)
	layer.BackgroundTransparency = 1
	layer.Parent = area

	local width, height = area.AbsoluteSize.X, area.AbsoluteSize.Y

	if parsed.kind == "linear" then
		local x1, y1, x2, y2 = clipLinear(parsed.m, parsed.b)
		if x1 then
			drawSegment(layer, x1, y1, x2, y2, width, height, GRAPH_COLOR, 3)
		end
	elseif parsed.kind == "horizontal" then
		if math.abs(parsed.y) <= RANGE then
			drawSegment(layer, -RANGE, parsed.y, RANGE, parsed.y, width, height, GRAPH_COLOR, 3)
		end
	elseif parsed.kind == "vertical" then
		if math.abs(parsed.x) <= RANGE then
			drawSegment(layer, parsed.x, -RANGE, parsed.x, RANGE, width, height, GRAPH_COLOR, 3)
		end
	elseif parsed.kind == "quadratic" then
		local segments = 40
		local prevX, prevY, prevOut
		for i = 0, segments do
			local x = -RANGE + i * (2 * RANGE / segments)
			local y = parsed.a * x * x + parsed.b * x + parsed.c
			local out = (y > RANGE) and 1 or (y < -RANGE) and -1 or 0
			if i > 0 and not (out ~= 0 and out == prevOut) then
				drawSegment(
					layer,
					prevX, math.clamp(prevY, -RANGE, RANGE),
					x, math.clamp(y, -RANGE, RANGE),
					width, height, GRAPH_COLOR, 3
				)
			end
			prevX, prevY, prevOut = x, y, out
		end
	end

	return true
end

--------------------------------------------------------------------------------
-- Input panel
--------------------------------------------------------------------------------

function GraphUI:CreateUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "GraphUI"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.Size = UDim2.new(0, 380, 0, 170)
	frame.Position = UDim2.new(0.5, 0, 1, -210)
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.BackgroundColor3 = Color3.fromRGB(47, 49, 54)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 12)
	frameCorner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -70, 0, 28)
	title.Position = UDim2.new(0, 14, 0, 10)
	title.BackgroundTransparency = 1
	title.Text = "Graph an equation"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamBold
	title.Parent = frame

	local close = Instance.new("TextButton")
	close.Size = UDim2.new(0, 36, 0, 28)
	close.Position = UDim2.new(1, -48, 0, 10)
	close.BackgroundColor3 = Color3.fromRGB(237, 66, 69)
	close.Text = "X"
	close.TextColor3 = Color3.fromRGB(255, 255, 255)
	close.TextSize = 16
	close.Font = Enum.Font.GothamBold
	close.Parent = frame
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = close
	close.MouseButton1Click:Connect(function()
		self:Close()
	end)

	inputBox = Instance.new("TextBox")
	inputBox.Size = UDim2.new(0, 220, 0, 44)
	inputBox.Position = UDim2.new(0, 14, 0, 50)
	inputBox.BackgroundColor3 = Color3.fromRGB(32, 34, 37)
	inputBox.Text = ""
	inputBox.PlaceholderText = "y=2x+1"
	inputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
	inputBox.TextSize = 20
	inputBox.ClearTextOnFocus = false
	inputBox.Font = Enum.Font.GothamBold
	inputBox.Parent = frame
	local inputCorner = Instance.new("UICorner")
	inputCorner.CornerRadius = UDim.new(0, 10)
	inputCorner.Parent = inputBox

	local graphButton = Instance.new("TextButton")
	graphButton.Size = UDim2.new(0, 120, 0, 44)
	graphButton.Position = UDim2.new(0, 246, 0, 50)
	graphButton.BackgroundColor3 = Color3.fromRGB(67, 181, 129)
	graphButton.Text = "Graph it!"
	graphButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	graphButton.TextSize = 18
	graphButton.Font = Enum.Font.GothamBold
	graphButton.Parent = frame
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 10)
	buttonCorner.Parent = graphButton

	errorLabel = Instance.new("TextLabel")
	errorLabel.Size = UDim2.new(1, -28, 0, 50)
	errorLabel.Position = UDim2.new(0, 14, 0, 106)
	errorLabel.BackgroundTransparency = 1
	errorLabel.Text = ""
	errorLabel.TextColor3 = Color3.fromRGB(250, 166, 26)
	errorLabel.TextSize = 14
	errorLabel.TextWrapped = true
	errorLabel.TextXAlignment = Enum.TextXAlignment.Left
	errorLabel.Font = Enum.Font.Gotham
	errorLabel.Parent = frame

	graphButton.MouseButton1Click:Connect(function()
		self:Graph(inputBox.Text)
	end)

	self.ScreenGui = gui
end

function GraphUI:Graph(text)
	local parsed, err = EquationParser.Parse(text)
	if not parsed then
		errorLabel.Text = err or "Hmm, I can't read that one."
		return
	end

	if not renderEquation(parsed) then
		errorLabel.Text = "The easel isn't ready yet - try again in a moment."
		return
	end

	errorLabel.Text = ""

	-- First successful graph per session: ask the server for the bonus
	-- (the server re-parses with the same module before paying out)
	if not bonusSentThisSession and GraphBonusRequest then
		bonusSentThisSession = true
		GraphBonusRequest:FireServer(text)
	end
end

function GraphUI:Open()
	if self.ScreenGui then
		self.ScreenGui.Enabled = true
	end
end

function GraphUI:Close()
	if self.ScreenGui then
		self.ScreenGui.Enabled = false
	end
end

function GraphUI:Init()
	OpenGraphUI = ReplicatedStorage:WaitForChild("OpenGraphUI", 10)
	GraphBonusRequest = ReplicatedStorage:WaitForChild("GraphBonusRequest", 10)

	if not OpenGraphUI then
		warn("GraphUI: remotes not found - server may still be starting")
		return
	end

	self:CreateUI()

	OpenGraphUI.OnClientEvent:Connect(function()
		self:Open()
	end)
end

return GraphUI
