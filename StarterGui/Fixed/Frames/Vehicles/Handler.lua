-- Services
local Replicated = game:GetService('ReplicatedStorage')
local MarketplaceService = game:GetService('MarketplaceService')
local TweenService = game:GetService('TweenService')
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')

-- Instances
local Primary = script.Parent
local Customize = Primary.Parent:WaitForChild('Customize')
local MainMusic = Primary.Parent:WaitForChild('Music')

local OpenButton = Primary:WaitForChild('Open')
local OpenButtonArrowLabel = OpenButton:WaitForChild('Arrow')

local ContainterButtons = Primary:WaitForChild('Main'):WaitForChild('Container')

-- Remotes
local Handling = Replicated:WaitForChild('Remotes'):WaitForChild('Vehicles'):WaitForChild('Handling')
local Informing = Replicated:WaitForChild('Remotes'):WaitForChild('Vehicles'):WaitForChild('Informing')
local Retrieving = Replicated:WaitForChild('Remotes'):WaitForChild('Vehicles'):WaitForChild('Retrieving')
local Exchanging = Replicated:WaitForChild('Remotes'):WaitForChild('Vehicles'):WaitForChild('Exchanging')

-- ModuleScripts
local VehicleClient = require(Replicated:WaitForChild('Modules'):WaitForChild('Vehicles'):WaitForChild('Client'))
local VehicleCore = require(Replicated:WaitForChild('Modules'):WaitForChild('Vehicles'):WaitForChild('Core'))
local DataModule = require(Replicated:WaitForChild('Modules'):WaitForChild('Data'):WaitForChild('Core'))

-- Objects
local LocalPlayer = Players.LocalPlayer

-- Wait for the Inventory tab before the vehicle inventory
DataModule:Wait(DataModule, 'PlayerData', 'Inventory')
local VehiclesInventory = DataModule:Wait(DataModule.PlayerData, 'Inventory', 'Vehicles')

-- Horn instance
local HornSoundObject = script:WaitForChild('Horn')

-- Music instances
local MusicObject = MainMusic:WaitForChild('Sound')
local MusicPlayButton = MainMusic:WaitForChild('Play')
local MusicExitButton = MainMusic:WaitForChild('Exit')
local MusicIdentificationBox = MainMusic:WaitForChild('Identification'):WaitForChild('Box')
local MusicGoButton = MainMusic:WaitForChild('Go')
local MusicCurrentlyPlaying = MainMusic:WaitForChild('Playing'):WaitForChild('Song')

-- Customize instances
local CustomizeEvents = {}

local CustomizeColor = Customize:WaitForChild('Color')
local CustomizeFooter = Customize:WaitForChild('Footer')
local CustomizeMain = Customize:WaitForChild('Main')
local CustomizeVehicle = Customize:WaitForChild('Vehicle')
local CustomizeTemplate = script:WaitForChild('Customize')

local CustomizeColorSelect = CustomizeColor:WaitForChild('Body'):WaitForChild('Select')
local CustomizeColorExit = CustomizeColor:WaitForChild('Exit')

-- Speedometer data
local Speedometer = ContainterButtons:WaitForChild('Speedometer')
local SpeedInformation = {Position = Vector3.new(), Time = tick()}

-- Configuration
local Configurations = {
	OpenedPosition = Primary.Position,
	ClosedPosition = UDim2.fromScale(Primary.Position.X.Scale - 0.16, Primary.Position.Y.Scale),
	
	TweenToOpenPosition = TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
	TweenToClosePosition = TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
	
	PlayMusicButtonColor = Color3.fromRGB(31, 241, 134),
	PauseMusicButtonColor = Color3.fromRGB(233, 0, 39),
	
	CarHornId = 'rbxassetid://7877364363',
}

-- Variables
local ReferencingVehicle, ReferencingIdentifier
local IsOpened, CanTween = true, true

-- Customize functions
local function AdjustModelGlow(NeonGroup, ToNeon)
	for _, Part in pairs(NeonGroup) do
		if Part:IsA('BasePart') then
			Part.Material = ToNeon and Enum.Material.Neon or Enum.Material.SmoothPlastic
		end
	end
end

local function ChangeModelColor(ColorGroup, Color)
	for _, Part in pairs(ColorGroup:GetChildren()) do
		if Part:IsA('BasePart') then
			Part.Color = Color
		end
	end
end

local function GetFirstColor(ColorGroup)
	for _, Part in pairs(ColorGroup:GetChildren()) do
		if Part:IsA('BasePart') then
			return Part.Color
		end
	end
end

local function ClearImage(ImageHolder)
	for _, Child in pairs(ImageHolder:GetChildren()) do
		Child:Destroy()
	end

	ImageHolder.CurrentCamera = nil
end

-- Utility functions
function CommonTween(Button)
	local Playing = TweenService:Create(
		Button.Main,
		TweenInfo.new(0.125, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false),
		{Position = Button.Shadow.Position})

	Playing:Play()
	Playing.Completed:Wait()

	Playing = TweenService:Create(
		Button.Main,
		TweenInfo.new(0.125, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false),
		{Position = UDim2.fromScale(0.5, 0)})

	Playing:Play()
	Playing.Completed:Wait()
end

-- Functions
local function PlayMusic(Mode, Id)
	if Mode == 'Play' then
		if not Id or Id == '' then
			return
		end
		
		local Success, IdDetails = pcall(MarketplaceService.GetProductInfo, MarketplaceService, Id)
		
		if Success then
			if IdDetails and IdDetails.AssetTypeId == 3 then
				MusicIdentificationBox.Text = ''
				MusicCurrentlyPlaying.Text = IdDetails.Name
				
				MusicPlayButton.Text = 'PAUSE'
				MusicPlayButton.BackgroundColor3 = Configurations.PauseMusicButtonColor
				
				MusicObject.SoundId = "rbxassetid://" .. Id
				MusicObject:Play()
			end
		end
	elseif Mode == 'Default' then
		MusicCurrentlyPlaying.Text = 'N/A'

		MusicPlayButton.Text = 'Play'
		MusicPlayButton.BackgroundColor3 = Configurations.PlayMusicButtonColor
	end
end

local function ToggleSongPlaying(Mode)
	if not MusicObject.SoundId or MusicObject.SoundId == '' then
		return
	end
	
	if Mode == 'Pause' or (not Mode and MusicObject.Playing) then
		MusicObject:Pause()

		MusicPlayButton.Text = 'PLAY'
		MusicPlayButton.BackgroundColor3 = Configurations.PlayMusicButtonColor
	elseif Mode == 'Resume' or (not Mode) then
		MusicObject:Resume()

		MusicPlayButton.Text = 'PAUSE'
		MusicPlayButton.BackgroundColor3 = Configurations.PauseMusicButtonColor
	end
end

local function ClearCustomize(...)
	-- Clear out ViewportFrames
	ClearImage(CustomizeVehicle.Background.Picture)
	
	-- Default the price
	CustomizeFooter.Price.Label.Text = '0'
	
	-- Turn off the color stuff
	CustomizeColor.Visible = false
	
	-- Delete the old options
	for _, Option in pairs(CustomizeMain:GetChildren()) do
		if Option.ClassName == 'Frame' then
			Option:Destroy()
		end
	end
	
	-- Clear out the events
	for _, Event in pairs(CustomizeEvents) do
		Event:Disconnect()
	end
	
	CustomizeEvents = {}
	
	-- Set it to invisible
	Customize.Visible = false
end

local function HandleCustomize(Identifier)
	-- Clear out the old stuff, don't remove this
	ClearCustomize()
	
	-- Check for main folder/identifier
	if not Identifier then
		return
	end
		
	-- Establish the object and set up the image 
	local VehicleFolder = VehiclesInventory[Identifier]
	local VehicleType = VehicleFolder.Type
	local _, Object, _ = VehicleClient:ReturnCamera(CustomizeVehicle, VehicleClient:GetData(VehicleFolder))

	-- Initialize the price and change table variables
	local Changes = {Color = {}, Glow = nil}
	local ColorSelectEvent, ColorExitEvent
	local Price = 0
	
	-- Set up the next customize templates and events
	for _, ColorGroup in pairs(Object['Body']['Main']:GetChildren()) do
		local Coloring = CustomizeTemplate:WaitForChild('Coloring'):Clone()
		local OriginalColor = GetFirstColor(ColorGroup)
		
		local AddedPrice = 0
		
		Coloring.Type.Text = ColorGroup.Name
		Coloring.Selection.Color.BackgroundColor3 = OriginalColor
		
		table.insert(CustomizeEvents, Coloring.Selection.Choose.MouseButton1Down:Connect(function()
			if ColorSelectEvent then
				ColorSelectEvent:Disconnect()
			end
			
			if ColorExitEvent then
				ColorExitEvent:Disconnect()
			end
			
			-- Make it visible
			CustomizeColor.Visible = true
			
			-- Set events
			ColorSelectEvent = CustomizeColorSelect.MouseButton1Down:Connect(function()
				local Color = Retrieving:Invoke()
				local UpgradePrice = math.round(VehicleCore.Customize.ColorCostPercentage * VehicleCore['Vehicles'][VehicleType]['Price'])
				
				CustomizeColor.Visible = false
				Changes['Color'][ColorGroup.Name] = Color
				
				Price -= AddedPrice; AddedPrice = UpgradePrice; Price += AddedPrice
				CustomizeFooter.Price.Label.Text = tostring(Price)

				Coloring.Selection.Color.BackgroundColor3 = Color
				ChangeModelColor(ColorGroup, Color)
			end)
			
			table.insert(CustomizeEvents, ColorSelectEvent)

			ColorExitEvent = CustomizeColorExit.MouseButton1Down:Connect(function()
				CustomizeColor.Visible = false
			end)
			
			table.insert(CustomizeEvents, ColorExitEvent)
		end))
		
		table.insert(CustomizeEvents, Coloring.Selection.Cancel.MouseButton1Down:Connect(function()
			Changes['Color'][ColorGroup.Name] = nil
			
			Price -= AddedPrice; AddedPrice = 0; Price += AddedPrice
			CustomizeFooter.Price.Label.Text = tostring(Price)
			
			Coloring.Selection.Color.BackgroundColor3 = OriginalColor
			ChangeModelColor(ColorGroup, OriginalColor)
		end))
		
		-- Parent it
		Coloring.Parent = CustomizeMain
	end
	
	-- Finding out if neon addition is applicable or not
	local GlowingParts = {}
	
	for _, Object in pairs(Object['Body']:GetDescendants()) do
		if Object.ClassName == 'BoolValue' and Object.Name == 'NeonInclusion' then
			table.insert(GlowingParts, Object.Parent)
		end
	end
	
	-- Set up the glow customize template and event
	if #GlowingParts >= 1 then
		local Glow = CustomizeTemplate:WaitForChild('Glow'):Clone()
		local OriginalNeon = VehicleFolder.Customized and VehicleFolder.Customized.Glow
		
		local AddedPrice = 0
		
		if OriginalNeon then
			Changes.Glow = true
			Glow.Selection.Yes.BackgroundTransparency = 0
			Glow.Selection.No.BackgroundTransparency = 1
		else
			Changes.Glow = nil
			Glow.Selection.Yes.BackgroundTransparency = 1
			Glow.Selection.No.BackgroundTransparency = 0
		end
		
		table.insert(CustomizeEvents, Glow.Selection.Yes.MouseButton1Down:Connect(function()
			local UpgradePrice
			
			if OriginalNeon then
				UpgradePrice = 0
			else
				UpgradePrice = math.round(VehicleCore.Customize.GlowCostPercentage * VehicleCore['Vehicles'][VehicleType]['Price'])
			end
			
			Changes.Glow = true
			
			Price -= AddedPrice; AddedPrice = UpgradePrice; Price += AddedPrice
			CustomizeFooter.Price.Label.Text = tostring(Price)
			
			Glow.Selection.Yes.BackgroundTransparency = 0
			Glow.Selection.No.BackgroundTransparency = 1
			
			AdjustModelGlow(GlowingParts, true)
		end))
		
		table.insert(CustomizeEvents, Glow.Selection.No.MouseButton1Down:Connect(function()
			Changes.Glow = nil

			Price -= AddedPrice; AddedPrice = 0; Price += AddedPrice
			CustomizeFooter.Price.Label.Text = tostring(Price)

			Glow.Selection.Yes.BackgroundTransparency = 1
			Glow.Selection.No.BackgroundTransparency = 0

			AdjustModelGlow(GlowingParts)
		end))
		
		-- Finally parent this to customize
		Glow.Parent = CustomizeMain
	end
			
	-- Finally handle the footer events
	table.insert(CustomizeEvents, CustomizeFooter.Purchase.MouseButton1Down:Connect(function()
		CommonTween(CustomizeFooter.Purchase)
		Exchanging:InvokeServer('Customizing', {Identifier = Identifier, Vehicle = ReferencingVehicle, Customize = Changes})
		ClearCustomize()
	end))
	
	table.insert(CustomizeEvents, CustomizeFooter.Cancel.MouseButton1Down:Connect(function()
		CommonTween(CustomizeFooter.Cancel)
		ClearCustomize()
	end))
		
	-- Finally make it visible
	Customize.Visible = true
end

-- Since we want network usage optimized, we receive a bindable instead of receiving a Handling event on both the core vehicle
-- script and here
Informing.Event:Connect(function(Mode, Arguments)
	if Mode == 'Driving' then
		if Arguments.Active == true then
			ReferencingVehicle, ReferencingIdentifier = Arguments.Vehicle, Arguments.Identifier
			SpeedInformation.Position, SpeedInformation.Time = ReferencingVehicle.PrimaryPart.Position, tick()
			Primary.Parent.Visible = true
		else
			MainMusic.Visible = false
			ToggleSongPlaying('Pause')
			ClearCustomize()
			
			ReferencingVehicle, ReferencingIdentifier = nil, nil
			Primary.Parent.Visible = false
		end
	elseif Mode == 'Ludicrous' then
		MarketplaceService:PromptGamePassPurchase(LocalPlayer, Arguments.Id)
	end
end)

-- Events
OpenButton.MouseButton1Down:Connect(function()
	if CanTween then
		CanTween = false
		local Tween
		
		if IsOpened then
			IsOpened = false
			OpenButtonArrowLabel.Text = '>'
			Tween = TweenService:Create(Primary, Configurations.TweenToClosePosition, {Position = Configurations.ClosedPosition})
		else
			IsOpened = true
			OpenButtonArrowLabel.Text = '<'
			Tween = TweenService:Create(Primary, Configurations.TweenToOpenPosition, {Position = Configurations.OpenedPosition})
		end
		
		Tween:Play()
		Tween.Completed:Wait()
		
		CanTween = true
	end
end)

-- Container button events
ContainterButtons:WaitForChild('Lock').MouseButton1Down:Connect(function()
	if ReferencingVehicle then
		Handling:FireServer('Locking', {Vehicle = ReferencingVehicle})
	end
end)

ContainterButtons:WaitForChild('Ludicrous').MouseButton1Down:Connect(function()
	if ReferencingVehicle then
		Handling:FireServer('Ludicrous', {Vehicle = ReferencingVehicle})
	end
end)

ContainterButtons:WaitForChild('Lights').MouseButton1Down:Connect(function()
	if ReferencingVehicle then
		Handling:FireServer('Headlights', {Vehicle = ReferencingVehicle})
	end
end)

ContainterButtons:WaitForChild('Stuck').MouseButton1Down:Connect(function()
	if ReferencingVehicle then
		Handling:FireServer('Flipping', {Vehicle = ReferencingVehicle})
	end
end)

ContainterButtons:WaitForChild('Music').MouseButton1Down:Connect(function()
	if ReferencingVehicle then
		MainMusic.Visible = not MainMusic.Visible
	end
end)

ContainterButtons:WaitForChild('Customize').MouseButton1Down:Connect(function()
	if not Customize.Visible then
		HandleCustomize(ReferencingIdentifier)
	else
		ClearCustomize()
	end
end)

ContainterButtons:WaitForChild('Horn').MouseButton1Down:Connect(function()
	if ReferencingVehicle and not Primary:FindFirstChildOfClass('Sound') then
		local Horn = HornSoundObject:Clone()
		Horn.SoundId = Configurations.CarHornId
		Horn.Parent = Primary
		
		Horn:Play()
		
		Horn.Ended:Connect(function()
			Horn:Destroy()
			Horn = nil
		end)
	end
end)

-- Music button events
MusicPlayButton.MouseButton1Down:Connect(ToggleSongPlaying)

MusicExitButton.MouseButton1Down:Connect(function()
	MainMusic.Visible = false
end)

MusicGoButton.MouseButton1Down:Connect(function()
	PlayMusic('Play', MusicIdentificationBox.Text)
end)

-- Speedometer event
task.spawn(function()
	while true do
		if ReferencingVehicle then
			local CurrentPosition, CurrentTime = ReferencingVehicle.PrimaryPart and ReferencingVehicle.PrimaryPart.Position, tick()
			local Speed = tostring(math.round((CurrentPosition - SpeedInformation.Position).Magnitude / (CurrentTime - SpeedInformation.Time)))
			
			SpeedInformation.Position, SpeedInformation.Time = CurrentPosition, CurrentTime
			Speedometer.Text = Speed .. ' MPH'
		end
		
		task.wait(0.1)
	end
end)

-- Main sequence
Primary.Parent.Visible = false
MainMusic.Visible = false
Customize.Visible = false

-- Simulating starting open value
IsOpened = true
OpenButtonArrowLabel.Text = '<'
Primary.Position = Configurations.OpenedPosition

-- Set playing to default values
PlayMusic('Default')