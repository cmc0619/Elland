--[[
	FamilyBuilder
	Small family touches:
	  - A picnic area beside Ella's House (checkered blanket, basket,
	    sit-able seats).
	  - A photo spot arch with an "ELLAND" sign on the way to the Lookout.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)

local FamilyBuilder = {}

local GROUND_LEVEL = Constants.WORLD.GROUND_LEVEL

local function createPart(parent, name, size, cframe, color, material, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.BrickColor = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CanCollide = canCollide ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function buildPicnic(parent)
	local center = Constants.FAMILY.PICNIC_CENTER

	-- Red blanket with a simple white checkered pattern
	createPart(
		parent, "PicnicBlanket", Vector3.new(9, 0.15, 9),
		CFrame.new(center.X, GROUND_LEVEL + 0.1, center.Z),
		BrickColor.new("Bright red"), Enum.Material.Fabric, false
	)
	for _, offset in ipairs({
		Vector3.new(-2.2, 0, -2.2),
		Vector3.new(2.2, 0, -2.2),
		Vector3.new(-2.2, 0, 2.2),
		Vector3.new(2.2, 0, 2.2),
	}) do
		createPart(
			parent, "BlanketCheck", Vector3.new(2, 0.18, 2),
			CFrame.new(center.X + offset.X, GROUND_LEVEL + 0.1, center.Z + offset.Z),
			BrickColor.new("White"), Enum.Material.Fabric, false
		)
	end

	-- Picnic basket with a little handle
	local basket = createPart(
		parent, "PicnicBasket", Vector3.new(2.2, 1.4, 1.6),
		CFrame.new(center.X, GROUND_LEVEL + 0.9, center.Z),
		BrickColor.new("Reddish brown"), Enum.Material.Wood
	)
	createPart(
		parent, "BasketHandle", Vector3.new(0.3, 1, 1.4),
		CFrame.new(center.X, GROUND_LEVEL + 2.1, center.Z),
		BrickColor.new("Brown"), Enum.Material.Wood, false
	)

	-- A couple of seats on the blanket corners
	for _, offset in ipairs({ Vector3.new(-3.5, 0, 3.5), Vector3.new(3.5, 0, -3.5) }) do
		local seat = Instance.new("Seat")
		seat.Name = "PicnicSeat"
		seat.Size = Vector3.new(2, 1, 2)
		seat.Position = Vector3.new(center.X + offset.X, GROUND_LEVEL + 0.5, center.Z + offset.Z)
		seat.Anchored = true
		seat.BrickColor = BrickColor.new("Bright blue")
		seat.Material = Enum.Material.Fabric
		seat.TopSurface = Enum.SurfaceType.Smooth
		seat.Parent = parent
	end

	return basket
end

local function buildPhotoSpot(parent)
	local center = Constants.FAMILY.PHOTO_SPOT

	-- Simple arch frame: two posts + top beam
	local postColor = BrickColor.new("Bright yellow")
	for _, xSign in ipairs({ -1, 1 }) do
		createPart(
			parent, "PhotoPost", Vector3.new(1, 12, 1),
			CFrame.new(center.X + xSign * 5, GROUND_LEVEL + 6, center.Z),
			postColor, Enum.Material.SmoothPlastic
		)
	end
	createPart(
		parent, "PhotoBeam", Vector3.new(12, 1.5, 1.5),
		CFrame.new(center.X, GROUND_LEVEL + 12, center.Z),
		postColor, Enum.Material.SmoothPlastic
	)

	-- "ELLAND" sign hanging from the beam
	local sign = createPart(
		parent, "PhotoSign", Vector3.new(9, 3, 0.5),
		CFrame.new(center.X, GROUND_LEVEL + 9.8, center.Z),
		BrickColor.new("White")
	)
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.Parent = sign
	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.new(1, 0, 1, 0)
	signLabel.BackgroundTransparency = 1
	signLabel.Text = "ELLAND"
	signLabel.TextColor3 = Color3.fromRGB(100, 150, 255)
	signLabel.TextScaled = true
	signLabel.Font = Enum.Font.GothamBold
	signLabel.Parent = signGui

	-- Marker on the ground where the photographer's subject stands
	createPart(
		parent, "PhotoMark", Vector3.new(3, 0.1, 3),
		CFrame.new(center.X, GROUND_LEVEL + 0.08, center.Z - 4),
		BrickColor.new("Bright violet"), Enum.Material.Neon, false
	)
end

function FamilyBuilder:Build()
	local old = Workspace:FindFirstChild("FamilyTouches")
	if old then
		old:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "FamilyTouches"
	folder.Parent = Workspace

	buildPicnic(folder)
	buildPhotoSpot(folder)

	print("FamilyBuilder finished: picnic area and photo spot")
end

return FamilyBuilder
