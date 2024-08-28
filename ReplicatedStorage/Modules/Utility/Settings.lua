local UserInputService = game:GetService('UserInputService')
local Randomize = Random.new()

local Settings = {	
	['DebounceTable'] = {
		['PurchaseEgg'] = {},
		['PurchaseVehicle'] = {},
		['EquipVehicle'] = {},
		['PurchaseHome'] = {},
		['SpawnHome'] = {},
		['LockHome'] = {},
		['ColorHome'] = {},
		['SellHome'] = {},
		['RenameHome'] = {},
		['TeleportPlayer'] = {},
		['FetchPetInfo'] = {},
		['CachePetInfo'] = {},
		['RobSafe'] = {},
	};
}

local function GetPower(n)
	return math.floor(math.log(n+1) / (math.log(2) + math.log(5)))
end

local function GetBoundingBoxMin(BoundingBoxCFrame, BoundingBoxSize, Axis)
	return BoundingBoxCFrame.Position[Axis] - BoundingBoxSize[Axis] / 2
end

local function GetBoundingBoxMax(BoundingBoxCFrame, BoundingBoxSize, Axis)
	return BoundingBoxCFrame.Position[Axis] + BoundingBoxSize[Axis] / 2
end

function Settings:Compress(n)
	local Power = math.floor(GetPower(math.abs(n))/3)
	local S = tostring(n / 10 ^ (Power * 3))
	local Compressed = S:match('%.') and S:sub(1, 4) or S:sub(1, 3)
	return Compressed:gsub('%.?0+$', '') .. (Settings['Suffixes'][Power] or '')
end

-- Convert {{['A'] = 1, ['B'] = 2}, {['A'] = 3, ['B'] = 4}} to {['A'] = {1, 3}, ['B'] = {2, 4}}
function Settings:Transform(List)
	local Converted = {}

	for _, D1 in pairs(List) do
		for Name, D2 in pairs(D1) do
			if not Converted[Name] then
				Converted[Name] = {}
			end

			table.insert(Converted[Name], D2)
		end
	end

	return Converted
end

-- This is so you can use it as a table rather than tuple (math.max(a, b, c, d))
function Settings:Max(Table)
	local Max

	for _, Value in pairs(Table) do
		Max = (Max and (Value > Max and Value or Max) or Value)
	end

	return Max
end

-- This is so you can use it as a table rather than tuple (math.min(a, b, c, d))
function Settings:Min(Table)
	local Min

	for _, Value in pairs(Table) do
		Min = (Min and (Value < Min and Value or Min) or Value)
	end

	return Min
end

function Settings:iMax(Table)
	local Max

	for Value, _ in pairs(Table) do
		Max = (Max and (Value > Max and Value or Max) or Value)
	end

	return Max
end

function Settings:iMin(Table)
	local Min

	for Value, _ in pairs(Table) do
		Min = (Min and (Value < Min and Value or Min) or Value)
	end

	return Min
end

function Settings:ScaleToOffset(Scale)
	local ViewPortSize = workspace.Camera.ViewportSize
	return ({ViewPortSize.X * Scale[1], ViewPortSize.Y * Scale[2]})
end

function Settings:OffsetToScale(Offset)
	local ViewPortSize = workspace.Camera.ViewportSize
	return ({Offset.X / ViewPortSize.X, Offset.Y / ViewPortSize.Y})
end

function Settings:FromColor(Color)
	return ("%02x%02x%02x"):format(Color.R * 255, Color.G * 255, Color.B * 255)
end

function Settings:ToColor(Serial)
	local R, G, B = Serial:match("(..)(..)(..)")
	R, G, B = tonumber(R, 16), tonumber(G, 16), tonumber(B, 16)
	
	return Color3.fromRGB(R, G, B)
end

function Settings:Create(Class, Name, Parent)
	if Class then
		local Object = Instance.new(Class)
		
		if Name then
			Object.Name = Name
		end
		
		if Parent then
			Object.Parent = Parent
		end
		
		return Object
	end
end

function Settings:Index(Table, Value)
	for Indice, Item in pairs(Table) do
		if Item == Value then
			return Indice, Item
		end
	end
end

function Settings:IndexColor(Table, Color)
	for Indice, ColorValue in pairs(Table) do
		if Settings:equalsColor(Color, ColorValue) then
			return Indice, ColorValue
		end
	end
end

function Settings:KIndex(Table, Value)
	for Indice, Item in pairs(Table) do
		if Indice == Value then
			return Indice, Item
		end
	end
end

-- Unsure if this works here
function Settings:tableDescendantOf(Table, Value)
	for Indice, Item in pairs(Table) do
		if Item == Value then
			return true
		elseif type(Item) == 'table' then			
			if Settings:tableDescendantOf(Item, Value) then
				return true
			end
		end
	end
end

function Settings:SetDebounce(Player, Type, Time)
	local ReferenceTable = Settings['DebounceTable'][Type]

	if ReferenceTable and not ReferenceTable[Player.Name] then
		task.spawn(function(...)
			ReferenceTable[Player.Name] = true
			task.wait(Time)
			ReferenceTable[Player.Name] = nil
		end)

		return true
	end
end

function Settings:equalsColor(colorA, colorB, epsilon)
	local epsilon = epsilon or 0.001

	if math.abs(colorA.R - colorB.R) > epsilon then
		return false
	end

	if math.abs(colorA.G - colorB.G) > epsilon then
		return false
	end

	if math.abs(colorA.B - colorB.B) > epsilon then
		return false
	end

	return true
end

-- Instance functions
function Settings:ConvertFolderToTable(Adding)
	local Table = {}

	for _, Child in pairs(Adding:GetChildren()) do
		if Child:IsA('ValueBase') then
			Table[Child.Name] = Child.Value
		elseif Child:IsA('Folder') then
			Table[Child.Name] = Settings:ConvertFolderToTable(Child)
		else
			warn('Unknown type present.')
		end
	end

	return Table
end

-- Most of the time you can use OverlapParams in place of CheckPoint/PartCollision instead. 
-- Use these when needing to check bounding boxes intersection of MODELS over baseparts
function Settings:CheckPointCollision(PointPosition, BoundingBoxCFrame, BoundingBoxSize) -- Point vs AABB
	return
		(PointPosition.X >= GetBoundingBoxMin(BoundingBoxCFrame, BoundingBoxSize, 'X') and PointPosition.X <= GetBoundingBoxMax(BoundingBoxCFrame, BoundingBoxSize, 'X')) and
		(PointPosition.Y >= GetBoundingBoxMin(BoundingBoxCFrame, BoundingBoxSize, 'Y') and PointPosition.Y <= GetBoundingBoxMax(BoundingBoxCFrame, BoundingBoxSize, 'Y')) and
		(PointPosition.Z >= GetBoundingBoxMin(BoundingBoxCFrame, BoundingBoxSize, 'Z') and PointPosition.Z <= GetBoundingBoxMax(BoundingBoxCFrame, BoundingBoxSize, 'Z'))
end

function Settings:CheckPartCollision(BoundingBoxCFrame, BoundingBoxSize, OtherBoundingBoxCFrame, OtherBoundingBoxSize) -- AABB vs AABB
	return
		(GetBoundingBoxMin(BoundingBoxCFrame, BoundingBoxSize, 'X') <= GetBoundingBoxMax(OtherBoundingBoxCFrame, OtherBoundingBoxSize, 'X') and GetBoundingBoxMax(BoundingBoxCFrame, BoundingBoxSize, 'X') >= GetBoundingBoxMin(OtherBoundingBoxCFrame, OtherBoundingBoxSize, 'X')) and
		(GetBoundingBoxMin(BoundingBoxCFrame, BoundingBoxSize, 'Y') <= GetBoundingBoxMax(OtherBoundingBoxCFrame, OtherBoundingBoxSize, 'Y') and GetBoundingBoxMax(BoundingBoxCFrame, BoundingBoxSize, 'Y') >= GetBoundingBoxMin(OtherBoundingBoxCFrame, OtherBoundingBoxSize, 'Y')) and
		(GetBoundingBoxMin(BoundingBoxCFrame, BoundingBoxSize, 'Z') <= GetBoundingBoxMax(OtherBoundingBoxCFrame, OtherBoundingBoxSize, 'Z') and GetBoundingBoxMax(BoundingBoxCFrame, BoundingBoxSize, 'Z') >= GetBoundingBoxMin(OtherBoundingBoxCFrame, OtherBoundingBoxSize, 'Z'))
end

-- Table functions
function Settings:Length(Table)
	local Counter = 0 

	for _, _ in pairs(Table) do
		Counter += 1	
	end

	return Counter
end

function Settings:ShallowCopy(Table)
	return {table.unpack(Table)}
end

function Settings:DeepCopy(Table)
	local New = {}
	
	for Indice, Value in pairs(Table) do
		if type(Value) == 'table' then
			Value = Settings:DeepCopy(Value)
		end
		
		New[Indice] = Value
	end
	
	return New
end

function Settings:Shuffle(Table)
	local Item

	for i = #Table, 1, -1 do
		Item = table.remove(Table, Randomize:NextInteger(1, i))
		table.insert(Table, Item)
	end

	return Table
end

function Settings:Sort(Table)
	local Gap = math.floor(#Table / 2)

	while Gap > 0 do 
		for Iteration = Gap, #Table do
			local Temp = Table[Iteration]
			local Switch = Iteration

			while (Switch > Gap and Table[Switch - Gap] > Temp) do
				Table[Switch] = Table[Switch - Gap]
				Switch -= Gap
			end

			Table[Switch] = Temp
		end

		Gap = math.floor(Gap / 2)
	end

	return Table
end

function Settings:Reverse(Table)
	local Length = #Table
	local Iterate = 1
	
	while Iterate < Length do
		Table[Iterate], Table[Length] = Table[Length], Table[Iterate]

		Iterate += 1
		Length -= 1
	end
	
	return Table
end

--
function Settings:Round(Value, Decimal)
	Decimal = Decimal or 1
	return math.floor((Value * Decimal) + 0.5) / Decimal
end

function Settings:GetMouseHit(Ignoring)
	local Location = UserInputService:GetMouseLocation()
	local ViewpointRay = workspace.CurrentCamera:ViewportPointToRay(Location.X, Location.Y)
	local ExtendedRay = Ray.new(ViewpointRay.Origin, ViewpointRay.Direction * 1000)

	return workspace:FindPartOnRayWithIgnoreList(ExtendedRay, Ignoring or {})
end

return Settings