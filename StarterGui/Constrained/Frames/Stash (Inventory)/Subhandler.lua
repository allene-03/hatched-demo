local Run = game:GetService('RunService')
local Replicated = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')
local UserInputService = game:GetService('UserInputService')
local GUIService = game:GetService('GuiService')

local Frame = script.Parent

local DataModule = require(Replicated:WaitForChild('Modules'):WaitForChild('Data'):WaitForChild('Core'))

local Assets = Replicated:WaitForChild('Assets')
local Remotes = Replicated:WaitForChild('Remotes')
local Rarity = Assets:WaitForChild('Rarity')

local Settings = require(Replicated:WaitForChild('Modules'):WaitForChild('Utility'):WaitForChild('Settings'))
local Mouseover = require(Replicated.Modules.Utility:WaitForChild('Mouseover'))

local Pet = require(Replicated.Modules:WaitForChild('Pet'):WaitForChild('Core'))
local Vehicles = require(Replicated.Modules:WaitForChild('Vehicles'):WaitForChild('Client'))

local Inventory = DataModule:Wait(DataModule, 'PlayerData', 'Inventory')

local Primary = Frame.Primary
local Interfacing = script.Interfacing

local Templates = script:WaitForChild('Templates')

local FrameTemplate = Templates:WaitForChild('Frame')
local ButtonTemplate = Templates:WaitForChild('Button')

local MainBar = Primary:WaitForChild('Main')
local SideBar = Primary:WaitForChild('Sidebar'):WaitForChild('Main')

local Default = SideBar.Pets
local TextWhenNoItems = MainBar:WaitForChild('Background'):WaitForChild('Standard')

local Pet_Handling = Remotes:WaitForChild('Pets'):WaitForChild('Handling')
local Pet_Breeding = Remotes:WaitForChild('Breed'):WaitForChild('Request')
local Pet_BreedingReturn = Remotes:WaitForChild('Breed'):WaitForChild('Return')
local Pet_DisplayingUpgrade = Replicated:WaitForChild('Remotes'):WaitForChild('Other'):WaitForChild('InvokeUpgrade')

local Vehicle_Handling = Remotes:WaitForChild('Vehicles'):WaitForChild('Handling')
local Vehicle_Exchanging = Remotes:WaitForChild('Vehicles'):WaitForChild('Exchanging')

-- Establish the data
local EventData = {
	Hovered = {
		Folder = script:WaitForChild('Hover'),
		Repository = Frame:WaitForChild('Events'):WaitForChild('Hover'),
		Types = {},
		Events = {}
	},
	
	Highlighted = {
		Folder = script:WaitForChild('Highlight'),
		Repository = Frame:WaitForChild('Events'):WaitForChild('Highlight'),
		Types = {},
		Events = {}
	},
	
	PetProfile = {
		Repository = Frame:WaitForChild('Profile'),
		Events = {}
	}
}

-- Configurations
local Configurations = {
	PrimaryButton = {
		EquippedColor = Color3.fromRGB(27, 211, 115),
		StandardColor = Color3.fromRGB(255, 255, 255)
	},
	
	HighlightedButton = {
		Pets = {
			EquippedColor = EventData.Highlighted.Folder.Pets.Selection.Equip.Main.ImageColor3,
			EquippedShadowColor = EventData.Highlighted.Folder.Pets.Selection.Equip.Shadow.ImageColor3,
			EquippedTextColor = EventData.Highlighted.Folder.Pets.Selection.Equip.Main.Label.TextColor3,
		},
		
		Vehicles = {
			EquippedColor = EventData.Highlighted.Folder.Vehicles.Selection.Equip.Main.ImageColor3,
			EquippedShadowColor = EventData.Highlighted.Folder.Vehicles.Selection.Equip.Shadow.ImageColor3,
			EquippedTextColor = EventData.Highlighted.Folder.Vehicles.Selection.Equip.Main.Label.TextColor3,
		}
	},
	
	Tab = {
		EquippedColor = Color3.fromRGB(255, 236, 208),
		EquippedTextColor = Color3.fromRGB(254, 160, 90),
		EquippedShadowColor = Color3.fromRGB(229, 211, 187),
		
		StandardColor = Color3.fromRGB(254, 160, 90),
		StandardTextColor = Color3.fromRGB(255, 255, 255),
		StandardShadowColor = Color3.fromRGB(220, 138, 76),
	},
	
	Bar = {
		SmallInitialSizeX = 0.15,
		BigInitialSizeX = 0.105,
	},
}

local Inset = GUIService:GetGuiInset()
local YInset = Inset.Y

-- Matrixes
local EquippedMatrix = {}
local ButtonMatrix = {}
local GridMatrix = {}

-- Variables
local DefaultMultiplierValue, MaximumMultiplierValue = 1, 50
local IsBreeding = false

-- Functions
local function Clear(Events)
	for _, Event in pairs(Events) do
		if typeof(Event) == 'Instance' then
			DataModule:Disconnect(Event)
		else
			Event:Disconnect()
		end
	end
	
	return {}
end

-- Call this before attempting to reference any specific hovered/highlighted instances
local function HandleEventData(Type)
	local EventType = EventData[Type]
	
	if EventType.Folder then
		for _, EventSubtype in pairs(EventType.Repository:GetChildren()) do
			EventSubtype.Parent = EventType.Folder
		end
	else
		EventType.Repository.Visible = false
	end
	
	EventType.Events = Clear(EventType.Events)
end

-- Sees if object in scrolling frame is being clipped or not
local function Bound(Object, Frame)
	local Position = {
		Top = Settings:Round(Object.AbsolutePosition.Y - Frame.AbsolutePosition.Y),
		Bottom = Settings:Round(Object.AbsolutePosition.Y + Object.AbsoluteSize.Y - Frame.AbsolutePosition.Y)
	}
	
	if Position.Bottom >= 0 and Position.Top <= Frame.AbsoluteSize.Y then
		return true
	end
end

local function Clamp(Mouse, Frame)
	return (Mouse.Y - YInset) >= Frame.AbsolutePosition.Y and (Mouse.Y - YInset) <= (Frame.AbsolutePosition.Y + Frame.AbsoluteSize.Y)
end

local function Tween(Object, Info, Properties)
	local Tween = TweenService:Create(Object, Info, Properties)
	Tween:Play()

	return Tween
end

local function CommonTween(Button)
	local Playing = Tween(
		Button.Main,
		TweenInfo.new(0.125, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false),
		{Position = Button.Shadow.Position})

	Playing.Completed:Wait()

	Playing = Tween(
		Button.Main,
		TweenInfo.new(0.125, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false),
		{Position = UDim2.fromScale(0.5, 0)})

	Playing.Completed:Wait()
end

local function Equip(Typed, Item)
	for Button, _ in pairs(ButtonMatrix[Typed]) do
		if Button:IsA('GuiButton') and not Button:FindFirstChild('Different') then
			Button.BackgroundColor3 = Configurations.PrimaryButton.StandardColor
		end
	end
	
	if Item then
		Item.BackgroundColor3 = Configurations.PrimaryButton.EquippedColor
	end
end

-- This essentially sets the frame to text when it has no children, so the frame doesn't look so empty
local function SetBackgroundText(Frame)
	-- We need to ensure that the frame we're referencing is visible, so we're not setting or removing the 
	-- background text from occurrences on different frames
	if not Frame or not Frame.Visible then
		return
	end
	 
	for _, Child in pairs(Frame:GetChildren()) do
		if Child:IsA('GuiButton') then
			TextWhenNoItems.Visible = false
			return
		end
	end
	
	TextWhenNoItems.Visible = true
end

local function Remove(Tab, Typed, Button)
	local Matrix = ButtonMatrix[Typed]
	local Removing = {}
	
	-- Looking for a specific instance vs performing routine check
	if Button then
		table.insert(Removing, Button)
	else
		for Button, _ in pairs(Matrix) do
			if Button:IsA('GuiButton') then
				local Found = Matrix[Button]

				if (not Found or not (Found.Key and Found.Location) or (not Found['Location'][Found['Key']])) then
					table.insert(Removing, Button)
				end
			end
		end
	end
	
	-- Do the actual removing
	for _, Button in pairs(Removing) do
		Button:Destroy()

		-- Clear out the events
		Clear(Matrix[Button]['Events'])

		-- Set it to be garbage collected
		Matrix[Button] = nil
	end

	-- Check for background changes
	SetBackgroundText(Tab)
end

local function Switch(NewTab)
	-- If they are the same tabs then return
	if NewTab == Interfacing.Value then
		return
	end
	
	-- Removes all the tabs colors and frames in preperation for new tab
	for _, Tab in pairs(SideBar:GetChildren()) do
		if Tab.ClassName == 'ImageButton' then
			Tab.Main.ImageColor3 = Configurations.Tab.StandardColor
			Tab.Main.Label.TextColor3 = Configurations.Tab.StandardTextColor
			Tab.Shadow.ImageColor3 = Configurations.Tab.StandardShadowColor

			local TabHasFrame = MainBar:FindFirstChild(Tab.Name)

			if TabHasFrame then
				TabHasFrame.Visible = false
			end
		end
	end
	
	-- Sets the reference value to the new tab
	Interfacing.Value = NewTab
	
	-- Handles the visuals / colors for new tab
	NewTab.Main.ImageColor3 = Configurations.Tab.EquippedColor
	NewTab.Main.Label.TextColor3 = Configurations.Tab.EquippedTextColor
	NewTab.Shadow.ImageColor3 = Configurations.Tab.EquippedShadowColor
	
	-- Finds the new tab
	local MainTab = MainBar:FindFirstChild(NewTab.Name)

	if MainTab then
		MainTab.Visible = true
	end
	
	-- Do this LAST because this function requires the most updated object visibility to function correctly
	SetBackgroundText(MainTab)
end

-- Upgrade functions
local function OnUpgradeSetAge(Added, AgeLabel)
	local Data = Added.Data
	local Current, After = Pet:GetAge(Data.Stage)
	
	AgeLabel.Current.Text = string.upper(Current)
	AgeLabel.After.Text = string.upper(After)
	
	local AgePercentage
	
	if After == 'MAX' then
		AgePercentage = 1
	else
		AgePercentage = (Data.Experience / ((Pet.Settings.Stages[Data.Stage].Experience / 100) * Pet.Settings.Experience[Pet:GetAttribute(Added, 'Rarity', true)]))
	end
	
	AgeLabel.Holder.Progress.Size = UDim2.fromScale(Configurations.Bar.BigInitialSizeX + ((1 - Configurations.Bar.BigInitialSizeX) * AgePercentage), 1)
end

local function OnUpgradeButtonClick(Arguments)
	HandleEventData('PetProfile') -- Clears out the old profile
	
	if Arguments.Highlighted then
		EventData.Highlighted.Events = Clear(EventData.Highlighted.Events)
		CommonTween(Arguments.Highlighted.Selection.Upgrade)
	end
	
	HandleEventData('Highlighted')
	
	-- Initializing the variables
	local Profile = EventData['PetProfile']['Repository']
	
	local Page, Main = Profile.Page, Profile.Main
	local Statistics, Additional, Age = Main.Stats, Main.Additional, Main.Age
	local Multiplier = Statistics.Multiplier.Holder.Adding
	
	local Added = Arguments.Added
	local Variables = Added.Variables
	local Data = Added.Data
	
	local ButtonRarity = Pet:GetAttribute(Added, 'Rarity')
	local ButtonRarityColor
	
	if Rarity:FindFirstChild(ButtonRarity) then
		ButtonRarityColor = Rarity[ButtonRarity]['Color']['Value']
	else
		ButtonRarityColor = Color3.fromRGB(255, 255, 255)
	end
	
	-- Multiplier value that will be toggled
	local MultiplierValue = DefaultMultiplierValue
	
	-- Turn off help page
	Profile.Help.Visible = false

	-- Setting the values
	Page.Nickname.Text = string.upper(Variables.Nickname)
	Page.Nickname.Shadow.Text = string.upper(Variables.Nickname)
	
	Additional.Rarity.Value.Text = string.upper(ButtonRarity)
	Additional.Rarity.Value.TextColor3 = ButtonRarityColor

	Additional.Gender.Text = 'GENDER: ' .. string.upper(Pet:GetAttribute(Added, 'Gender'))
	Additional.Species.Text = 'SPECIES: ' .. string.upper(Pet:GetAttribute(Added, 'Species'))
	
	local PetSizing = Pet:GetAttribute(Added, 'Size')
	
	if PetSizing and type(PetSizing) == 'number' then
		Additional.PetSize.Text = 'SIZE: ' .. string.upper(Pet:GetSize(PetSizing))
	else
		Additional.PetSize.Text = 'SIZE: ' .. string.upper(PetSizing)
	end

	
	Statistics.Points.Text = 'AVAILABLE POINTS: ' .. Added.Data.Points.Current
	Multiplier.Text = MultiplierValue
	
	OnUpgradeSetAge(Added, Age)
	
	for _, Statistic in pairs(Statistics:GetChildren()) do
		if Statistic.ClassName == 'Frame' then
			local AddedStatistic = Added['Data']['Potential'][Statistic.Name]
			
			-- This is so we can hide numbers but have the math still function
			local VisualAddedMaxStatistic = Pet:GetPotential(Added, Statistic.Name)
			local AddedMaxStatistic = Pet:GetPotential(Added, Statistic.Name, true)
			
			if AddedStatistic and (VisualAddedMaxStatistic and AddedMaxStatistic) then
				local Size = Statistic.Add.Size
				
				Statistic.Holder.Current.Text = AddedStatistic
				Statistic.After.Text = VisualAddedMaxStatistic
				
				Statistic.Holder.Progress.Size = UDim2.fromScale(Configurations.Bar.SmallInitialSizeX + ((1 - Configurations.Bar.SmallInitialSizeX) * (AddedStatistic / AddedMaxStatistic)), 1)
				
				table.insert(EventData.PetProfile.Events, Statistic.Add.InputBegan:Connect(function(Input)
					if Input.UserInputType == Enum.UserInputType.MouseMovement then
						Tween(Statistic.Add, TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {Size = UDim2.fromScale(Size.X.Scale * 1.25, Size.Y.Scale * 1.25)})
					end
				end))

				table.insert(EventData.PetProfile.Events, Statistic.Add.InputEnded:Connect(function(Input)
					if Input.UserInputType == Enum.UserInputType.MouseMovement then
						Tween(Statistic.Add, TweenInfo.new(0.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.In), {Size = Size})
					end
				end))

				table.insert(EventData.PetProfile.Events, Statistic.Add.MouseButton1Down:Connect(function()
					local Status, Return = Pet_Handling:InvokeServer('Upgrading', {Pet = Arguments.Identifier, Statistic = Statistic.Name, Multiplier = tonumber(Multiplier.Text)})

					-- Tween progress bar at beginning and each upgrade
					if Status == true then
						Statistic.Holder.Current.Text = Return
						Statistic.Holder.Progress.Size = UDim2.fromScale(Configurations.Bar.SmallInitialSizeX + ((1 - Configurations.Bar.SmallInitialSizeX) * (Return / AddedMaxStatistic )), 1)
					end
				end))
			end
		end
	end
	
	-- Setting up the other events
	local NicknameChanged = DataModule:Changed(Variables, 'Nickname')

	table.insert(EventData.PetProfile.Events, NicknameChanged)

	table.insert(EventData.PetProfile.Events, NicknameChanged.Event:Connect(function()
		Page.Nickname.Text = string.upper(Variables.Nickname)
		Page.Nickname.Shadow.Text = string.upper(Variables.Nickname)
	end))
	
	local CurrentPointsChanged = DataModule:Changed(Added.Data.Points, 'Current')

	table.insert(EventData.PetProfile.Events, CurrentPointsChanged)

	table.insert(EventData.PetProfile.Events, CurrentPointsChanged.Event:Connect(function()
		Statistics.Points.Text = 'AVAILABLE POINTS: ' .. Added.Data.Points.Current
	end))
	
	local ExperienceChanged = DataModule:Changed(Added.Data, 'Experience')
	local StageChanged = DataModule:Changed(Added.Data, 'Stage')

	table.insert(EventData.PetProfile.Events, ExperienceChanged)
	table.insert(EventData.PetProfile.Events, StageChanged)

	table.insert(EventData.PetProfile.Events, ExperienceChanged.Event:Connect(function()
		OnUpgradeSetAge(Added, Age)
	end))

	table.insert(EventData.PetProfile.Events, StageChanged.Event:Connect(function()
		OnUpgradeSetAge(Added, Age)
	end))
	
	table.insert(EventData.PetProfile.Events, Multiplier.FocusLost:Connect(function()
		if not tonumber(Multiplier.Text) then
			Multiplier.Text = MultiplierValue
		elseif tonumber(Multiplier.Text) > MaximumMultiplierValue then
			Multiplier.Text = MaximumMultiplierValue
		end

		MultiplierValue = Multiplier.Text
	end))
	
	table.insert(EventData.PetProfile.Events, Profile.Main.Stats.Help.MouseButton1Down:Connect(function()
		Profile.Help.Visible = true
	end))
	
	table.insert(EventData.PetProfile.Events, Profile.Help._Exit.MouseButton1Down:Connect(function()
		Profile.Help.Visible = false
	end))
	
	table.insert(EventData.PetProfile.Events, Profile._Exit.MouseButton1Down:Connect(function()
		HandleEventData('PetProfile')
	end))
	
	-- Handle the final stuff with camera, object, picture, etc.
	local Picture = Main.ImageHolder.Background.Picture
	
	-- Parent to nil so that we can use them later
	for _, Object in pairs(Picture:GetChildren()) do
		Object.Parent = nil
	end

	local ProfileObject, ProfileCam = Arguments.ObjectMatrix.Profile, Instance.new('Camera')
	ProfileObject.Parent, ProfileCam.Parent = Picture, Picture

	ProfileCam.CFrame = Arguments.CameraCFrame

	Picture.BackgroundColor3 = Arguments.BackgroundColor
	Picture.CurrentCamera = ProfileCam

	-- Finally we make it visible
	Profile.Visible = true
end

-- Button clicking events
local function OnButtonClicked(Typed, Arguments)
	local Highlighted = EventData['Highlighted']['Types'][Typed]
	
	-- Get the pertaining local data needed
	local Added = Arguments.Added
	local Button = Arguments.Button
	
	-- Clean out old event data
	HandleEventData('Hovered')
	HandleEventData('Highlighted')
	
	-- Remove the tag if visilbe
	if Button.Tag.Visible then
		local Tween = TweenService:Create(
			Button.Tag,
			TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{BackgroundTransparency = 1}
		)
		
		Tween:Play()

		Tween.Completed:Connect(function()
			if Button and Button:FindFirstChild('Tag') then
				Button.Tag.Visible = false
			end
		end)
	end
	
	-- Handle the local data placement
	local EquippedCallback, UnequippedCallback, SellingCallback, UpgradeCallback
	
	if Typed == 'Pets' then
		local Potential = Pet:GetAttribute(Added, 'Potential')
		local Overall
			
		if Potential and type(Potential) == 'table' then
			Overall = Pet:GetOverall(Potential)
		else
			Overall = Potential
		end
		
		local ButtonRarity = Pet:GetAttribute(Added, 'Rarity')
		local ButtonRarityColor

		if Rarity:FindFirstChild(ButtonRarity) then
			ButtonRarityColor = Rarity[ButtonRarity]['Color']['Value']
		else
			ButtonRarityColor = Color3.fromRGB(255, 255, 255)
		end

		Highlighted.Rarity.Text = string.upper(ButtonRarity)
		Highlighted.Rarity.TextColor3 = ButtonRarityColor
		
		Highlighted.Nickname.Text = string.upper(Added.Variables.Nickname)
		Highlighted.Overall.Text = tostring(Overall) .. ' OVR'
		
		EquippedCallback = function()
			Pet_Handling:InvokeServer('Equipping', {Pet = Arguments.Identifier})
		end
		
		UnequippedCallback = function()
			Pet_Handling:InvokeServer('Equipping')
		end
		
		SellingCallback = function()
			local Success = Pet_Handling:InvokeServer('Selling', {Pet = Arguments.Identifier})

			if Success == 'Complete' then
				HandleEventData('Hovered')
				HandleEventData('Highlighted')
			elseif Success == 'Only' then
				print("You can't sell your only pet.")

				HandleEventData('Hovered')
				HandleEventData('Highlighted')
			end
		end
		
		UpgradeCallback = function()
			OnUpgradeButtonClick({
				Highlighted = Highlighted,
				Added = Added,
				Identifier = Arguments.Identifier,
				ObjectMatrix = Arguments.ObjectMatrix,
				CameraCFrame = Arguments.CameraCFrame,
				BackgroundColor = Arguments.BackgroundColor
			})
		end
	elseif Typed == 'Vehicles' then
		local ButtonRarity = Added.Rarity

		Highlighted.Rarity.Text = string.upper(ButtonRarity)
		Highlighted.Rarity.TextColor3 = Rarity[ButtonRarity]['Color']['Value']
		
		Highlighted.Nickname.Text = string.upper(Added.Type)
		
		EquippedCallback = function()
			Vehicle_Handling:FireServer('Equipping', {Vehicle = Arguments.Identifier})
		end
		
		UnequippedCallback = function()
			Vehicle_Handling:FireServer('Unequipping')
		end
		
		SellingCallback = function()
			local Success = Vehicle_Exchanging:InvokeServer('Selling', {Vehicle = Arguments.Identifier})
			
			if Success == true then
				HandleEventData('Hovered')
				HandleEventData('Highlighted')
			end
		end
	end
	
	-- Now handle the camera, objects, picture
	local Picture = Highlighted.Image.Background.Picture
	
	-- Parent to nil so that we can use them later
	for _, Object in pairs(Picture:GetChildren()) do
		Object.Parent = nil
	end
	
	local HighlightedObject, HighlightedCam = Arguments.ObjectMatrix.Highlighted, Instance.new('Camera')
	HighlightedObject.Parent, HighlightedCam.Parent = Picture, Picture

	HighlightedCam.CFrame = Arguments.CameraCFrame

	Picture.BackgroundColor3 = Arguments.BackgroundColor
	Picture.CurrentCamera = HighlightedCam
	
	-- Set UI's position
	local Position = UserInputService:GetMouseLocation()				
	Highlighted.Position = UDim2.new(0, Position.X + Settings:ScaleToOffset({0.02, 0})[1], 0, Position.Y)
	
	-- Handle for only the highlighted with equips
	local EquipButton = Highlighted.Selection:FindFirstChild('Equip')
	
	if EquipButton then
		table.insert(EventData.Highlighted.Events, EquipButton.MouseButton1Down:Connect(function()
			EventData.Highlighted.Events = Clear(EventData.Highlighted.Events)

			CommonTween(Highlighted.Selection.Equip)
			HandleEventData('Highlighted')

			if EquippedMatrix[Typed] == Button then
				EquippedMatrix[Typed] = nil
				Equip(Typed)
				UnequippedCallback()
			else
				EquippedMatrix[Typed] = Button
				Equip(Typed, Button)
				EquippedCallback()
			end
		end))
		
		-- Handle how the equipped button looks
		if EquippedMatrix[Typed] == Button then				
			EquipButton.Main.ImageColor3 = Configurations.Tab.StandardColor
			EquipButton.Shadow.ImageColor3 = Configurations.Tab.StandardShadowColor
			EquipButton.Main.Label.TextColor3 = Configurations.Tab.StandardTextColor
			EquipButton.Main.Label.Text = 'UNEQUIP'
		else
			EquipButton.Main.ImageColor3 = Configurations.HighlightedButton[Typed]['EquippedColor']
			EquipButton.Shadow.ImageColor3 = Configurations.HighlightedButton[Typed]['EquippedShadowColor']
			EquipButton.Main.Label.TextColor3 = Configurations.HighlightedButton[Typed]['EquippedTextColor']
			EquipButton.Main.Label.Text = 'EQUIP'
		end
	end
	
	-- Handle for only the highlighted with sells
	local SellButton = Highlighted.Selection:FindFirstChild('Sell')
	
	if SellButton then
		table.insert(EventData.Highlighted.Events, SellButton.MouseButton1Down:Connect(function()
			EventData.Highlighted.Events = Clear(EventData.Highlighted.Events)

			CommonTween(Highlighted.Selection.Sell)
			SellingCallback()
		end))
	end

	-- Handle for only the highlighted with upgraded
	local PetProfile = Highlighted.Selection:FindFirstChild('Upgrade')
	
	if PetProfile then
		table.insert(EventData.Highlighted.Events, PetProfile.MouseButton1Down:Connect(function()
			UpgradeCallback()
		end))
	end
	
	-- All highlighted have the leave event
	table.insert(EventData.Highlighted.Events, Highlighted._Exit.MouseButton1Down:Connect(function()
		HandleEventData('Highlighted')
	end))

	-- Finally parent it to the repository
	Highlighted.Parent = EventData.Highlighted.Repository
end

-- Button hovering events
local function OnButtonEntered(Typed, Arguments)	
	local Hovered = EventData['Hovered']['Types'][Typed]
	local Added = Arguments.Added

	if Typed == 'Pets' then	
		local ButtonRarity = Pet:GetAttribute(Added, 'Rarity')
		local ButtonRarityColor

		if Rarity:FindFirstChild(ButtonRarity) then
			ButtonRarityColor = Rarity[ButtonRarity]['Color']['Value']
		else
			ButtonRarityColor = Color3.fromRGB(255, 255, 255)
		end
		
		local Potential = Pet:GetAttribute(Added, 'Potential')
		local Overall

		if Potential and type(Potential) == 'table' then
			Overall = Pet:GetOverall(Potential)
		else
			Overall = Potential
		end

		Hovered.Rarity.Text = string.upper(ButtonRarity)
		Hovered.Rarity.TextColor3 = ButtonRarityColor

		Hovered.Nickname.Text = string.upper(Added.Variables.Nickname)
		Hovered.Overall.Text = tostring(Overall) .. ' OVR'
	elseif Typed == 'Vehicles' then
		local ButtonRarity = Added.Rarity

		Hovered.Rarity.Text = string.upper(ButtonRarity)
		Hovered.Rarity.TextColor3 = Rarity[ButtonRarity]['Color']['Value']

		Hovered.Nickname.Text = string.upper(Added.Type)
	end

	local Picture = Hovered.Image.Background.Picture

	-- Parent to nil so that we can use them later
	for _, Object in pairs(Picture:GetChildren()) do
		Object.Parent = nil
	end

	local HoverObject, HoverCam = Arguments.ObjectMatrix.Hover, Instance.new('Camera')
	HoverObject.Parent, HoverCam.Parent = Picture, Picture

	HoverCam.CFrame = Arguments.CameraCFrame

	Picture.BackgroundColor3 = Arguments.BackgroundColor
	Picture.CurrentCamera = HoverCam
	
	local Parented = false
	local Position = UserInputService:GetMouseLocation()		

	if Clamp(Position, Arguments.Tab) then
		Parented = true

		Hovered.Position = UDim2.new(0, Position.X + Settings:ScaleToOffset({0.02, 0})[1], 0, Position.Y)
		Hovered.Parent = EventData.Hovered.Repository
	end

	table.insert(EventData.Hovered.Events, Run.Heartbeat:Connect(function()
		local Position = UserInputService:GetMouseLocation()

		if Clamp(Position, Arguments.Tab) then
			Hovered.Position = UDim2.new(0, Position.X + Settings:ScaleToOffset({0.02, 0})[1], 0, Position.Y)

			if Parented == false then
				Parented = true
				Hovered.Parent = EventData.Hovered.Repository
			end
		else
			if Parented == true then
				Parented = false
				Hovered.Parent = EventData.Hovered.Folder
			end
		end
	end))
end

local function Add(Added, Identifier, Type, Typed, IsNew)	
	local Details
	local Camera, Object, BackgroundColor
	local Events = {}

	local Button = ButtonTemplate:Clone()
	Button.LayoutOrder = -Added.InventoryId or 0
	
	local Tab = MainBar:FindFirstChild(Typed)

	if Typed == 'Pets' then
		if Pet['Settings']['Stages'][Added.Data.Stage]['Stage'] == 'Egg' then
			Tab = MainBar:FindFirstChild('Eggs')
			Details = Pet:GetData(Added, true)
		else
			Details = Pet:GetData(Added)
		end
		
		Camera, Object, BackgroundColor = Pet:ReturnCamera(Button, Details)
	elseif Typed == 'Vehicles' then
		Details = Vehicles:GetData(Added)
		Camera, Object, BackgroundColor = Vehicles:ReturnCamera(Button, Details)
	end
	
	if not Tab then
		return
	end
	
	Button.Name = Details and Details.Folder.Name or 'Button'
	Button.Tag.Visible = IsNew

	-- Create the objects for Hover, Highlight, and the main button	
	local ObjectMatrix = {
		Hover = Object:Clone(),
		Highlighted = Object:Clone(),
		Profile = (Typed == 'Pets' and Object:Clone())
	}

	-- Add it to the matrix so it can be tracked and also removed later
	-- It's important to used 'Typed' instead of Tab.Name here as Egg's Tab.Name = 'Eggs' and it's typed is 'Pets'
	ButtonMatrix[Typed][Button] = {
		Location = Type,
		Key = Identifier,
		
		Events = Events,
		Upgrade = (Typed == 'Pets') and function()
			OnUpgradeButtonClick({
				Added = Added,
				Identifier = Identifier,
				ObjectMatrix = ObjectMatrix,
				CameraCFrame = Camera.CFrame,
				BackgroundColor = BackgroundColor
			})
		end
	}

	-- Set up the events to be used
	local MouseEnter, MouseLeave = Mouseover.MouseEnterLeaveEvent(Button)

	table.insert(Events, MouseEnter:Connect(function()
		if (Frame.Visible and Tab.Visible and Bound(Button, Tab)) and (not EventData.PetProfile.Repository.Visible) and (EventData.Highlighted.Folder:FindFirstChild(Typed)) then
			OnButtonEntered(Typed, {
				Added = Added,
				ObjectMatrix = ObjectMatrix,
				CameraCFrame = Camera.CFrame,
				BackgroundColor = BackgroundColor,
				Tab = Tab
			})
		end
	end))

	-- It will only send if it's a pet, we make sure that other stuff cant be sent by not chaining the if statements (Typed and IsBreeding) together
	table.insert(Events, Button.MouseButton1Down:Connect(function()
		if IsBreeding == true then
			-- Make sure we aren't accidentally submitting eggs
			if (Typed == 'Pets' and Tab.Name == 'Pets') then
				Pet_BreedingReturn:Fire(Identifier)
			end
		elseif (Frame.Visible) and (not EventData.PetProfile.Repository.Visible) then
			OnButtonClicked(Typed, {
				Added = Added,
				Button = Button,
				ObjectMatrix = ObjectMatrix,
				BackgroundColor = BackgroundColor,
				CameraCFrame = Camera.CFrame,
				Identifier = Identifier
			})
		end
	end))

	table.insert(Events, MouseLeave:Connect(function()
		if Frame.Visible and Bound(Button, Tab) then
			HandleEventData('Hovered')
		end
	end))
	
	-- Set event monitors - transitioning from egg to pet
	if Typed == 'Pets' and Tab.Name == 'Eggs' then
		local StageChanged = DataModule:Changed(Added.Data, 'Stage')
		table.insert(Events, StageChanged)

		table.insert(Events, StageChanged.Event:Connect(function()
			if Pet['Settings']['Stages'][Added.Data.Stage]['Stage'] ~= 'Egg' then
				Remove(Tab, Typed, Button) -- Event connections are removed in this thread
				Add(Added, Identifier, Type, Typed, true)
			end
		end))
	end
	
	-- Finally parent it to the tab
	Button.Parent = Tab

	-- After parenting, adjust the background text visibility
	SetBackgroundText(Tab)
end

local function Adjust(Frame, Padding, Size)
	local AbsoluteSize = Frame.AbsoluteSize

	local NewPadding = Padding * AbsoluteSize
	NewPadding = UDim2.new(0, NewPadding.X, 0, NewPadding.Y)
	
	local NewSize = Size * AbsoluteSize
	NewSize = UDim2.new(0, NewSize.X, 0, NewSize.Y)

	Frame.Grid.CellPadding = NewPadding
	Frame.Grid.CellSize = NewSize
	
	Frame.CanvasSize = UDim2.new(0, 0, 0, Frame.Grid.AbsoluteContentSize.Y)
end

-- Start main sequence

-- Set up the types to be referenced for hovered and highlighted
for _, Type in pairs(EventData.Highlighted.Folder:GetChildren()) do
	EventData['Highlighted']['Types'][Type.Name] = Type
end

for _, Type in pairs(EventData.Hovered.Folder:GetChildren()) do
	EventData['Hovered']['Types'][Type.Name] = Type
end

HandleEventData('PetProfile')

-- Creating tabs for all of them
for _, SideTab in pairs(SideBar:GetChildren()) do
	if SideTab.ClassName == 'ImageButton' then
		local Name = SideTab.Name
		
		local MainTab = FrameTemplate:Clone()
		MainTab.Name = Name
		MainTab.Visible = false
		MainTab.Parent = MainBar
		
		local Padding = Vector2.new(MainTab.Grid.CellPadding.X.Scale, MainTab.Grid.CellPadding.Y.Scale)
		local Size = Vector2.new(MainTab.Grid.CellSize.X.Scale, MainTab.Grid.CellSize.Y.Scale)
		
		ButtonMatrix[Name] = {}
		
		GridMatrix[Name] = {
			Padding = Padding,
			Size = Size
		}

		Adjust(MainTab, Padding, Size)

		SideTab.MouseButton1Down:Connect(function()
			local Frame = MainBar:FindFirstChild(Name)
			
			if Frame and Frame.ClassName == 'ScrollingFrame' then
				print('Adjusting... ', Frame.Name)
				
				HandleEventData('Hovered')
				HandleEventData('Highlighted')

				Adjust(Frame, GridMatrix[Frame.Name]['Padding'], GridMatrix[Frame.Name]['Size'])
			end
			
			Switch(SideTab)
			CommonTween(SideTab)
		end)
		
		MainTab:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()
			if Frame.Visible and (Interfacing.Value and Interfacing.Value.Name == MainTab.Name) then
				print(MainTab.Name)
				Adjust(MainTab, Padding, Size)
			end
		end)

		MainTab.Grid:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()			
			Adjust(MainTab, Padding, Size)
		end)

		MainTab:GetPropertyChangedSignal('CanvasPosition'):Connect(function()
			HandleEventData('Highlighted')
		end)
	end
end

for Name, Type in pairs(Inventory) do
	local Tab = MainBar:FindFirstChild(Name)

	if Tab then
		task.spawn(function()
			for Key, Item in pairs(Type) do
				Add(Item, Key, Type, Name)
			end
		end)
				
		DataModule:ChildAdded(Inventory, Name).Event:Connect(function(Key, Item)
			local Found = Inventory[Name][Key] -- References the pointer, not the passed item
			Add(Found, Key, Type, Name, true)
		end)

		DataModule:ChildRemoved(Inventory, Name).Event:Connect(function(Key, Item)
			local Typed
			
			if Tab.Name == 'Eggs' then
				Typed = 'Pets'
			else
				Typed = Tab.Name
			end
			
			Remove(Tab, Typed)
		end)
	end
end

Frame:GetPropertyChangedSignal('Visible'):Connect(function()
	HandleEventData('PetProfile')
	
	for _, Frame in pairs(MainBar:GetChildren()) do
		if Frame.ClassName == 'ScrollingFrame' then
			Adjust(Frame, GridMatrix[Frame.Name]['Padding'], GridMatrix[Frame.Name]['Size'])
		end
	end
	
	HandleEventData('Highlighted')
	HandleEventData('Hovered')
end)

Pet_Breeding.Event:Connect(function(Mode)
	if Mode == 'Start' or Mode == 'Resume' then
		Switch(SideBar.Pets)
		IsBreeding = true
	elseif Mode == 'End' or Mode == 'Pause' then
		IsBreeding = false
	end
end)

Pet_DisplayingUpgrade.Event:Connect(function(Key)
	local Referencing = 'Pets'
	
	if not Key then
		return
	end
	
	for Button, Information in pairs(ButtonMatrix[Referencing]) do
		if Key == Information.Key then
			task.wait(0.25) -- This task wait offset is required so that when visibility is turned on for the ui again it doesn't force close upgrades
			
			Switch(SideBar[Referencing])
			Information['Upgrade']()
			
			break
		end
	end
end)

-- Set default value
Switch(Default)