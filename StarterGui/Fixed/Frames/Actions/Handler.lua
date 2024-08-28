local Replicated = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local UserInputService = game:GetService('UserInputService')
local Players = game:GetService('Players')

local Interact = require(Replicated:WaitForChild('Modules'):WaitForChild('Interface'):WaitForChild('Interact'):WaitForChild('Core'))
local Action = require(Replicated:WaitForChild('Modules'):WaitForChild('Interface'):WaitForChild('Action'):WaitForChild('Core'))
local Settings = require(Replicated:WaitForChild('Modules'):WaitForChild('Utility'):WaitForChild('Settings'))
local PetModule = require(Replicated.Modules:WaitForChild('Pet'):WaitForChild('Core'))
local DataModule = require(Replicated:WaitForChild('Modules'):WaitForChild('Data'):WaitForChild('Core'))

local UpdatePetRemote = Replicated:WaitForChild('Remotes'):WaitForChild('Pets'):WaitForChild('Updating')
local RequestPetRemote = Replicated:WaitForChild('Remotes'):WaitForChild('Pets'):WaitForChild('Requesting')
local PetMovementBindable = Replicated:WaitForChild('Remotes'):WaitForChild('Other'):WaitForChild('GetPetState')

local LocalPlayer = Players.LocalPlayer

-- Local variables
local InterfaceInUse = false
local ConnectionInformation = {} -- Used for everything except client character

-- Configurations
local Configurations = {
	ActionInTweenInformation = TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out, 0, false),
	ActionOutTweenInformation = TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.In, 0, false),
	
	ActionInHoverTweenInformation = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, 0, false),
	ActionOutHoverTweenInformation = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In, 0, false),
	
	-- How big you want the actions to grow after hovering
	InterfaceGrowth = 1.085,	
	CloseInterfaceGrowth = 1.275
}

-- Main functions
local function OnActionCompleted(Player, ObjectInteractingWith, Interface, InteractConnection, Callback)
	-- We yield a little bit before making interfaces visible again
	task.spawn(function()
		task.wait(0.25)
		Interact:RemoveAction('PlayerPetAction')
	end)
	
	local Tween = TweenService:Create(Interface, Configurations.ActionOutTweenInformation, {Size = UDim2.fromScale(0, 0)})
	Tween:Play()
	
	-- If there is a callback and the connection reference is still valid
	if Callback and ((ConnectionInformation[ObjectInteractingWith] == InteractConnection) or (LocalPlayer.Character and ObjectInteractingWith:IsDescendantOf(LocalPlayer.Character))) then
		Callback()
	end

	Tween.Completed:Connect(function()
		Interface:Destroy()

		-- Once again cheking if the interactConnection reference is still valid
		if InteractConnection and (InteractConnection == ConnectionInformation[ObjectInteractingWith]) then
			Interact:Resume(InteractConnection, 'ObjectSelected')
		end

		Interface, InterfaceInUse = nil, false
	end)
end

local function OnActionSetup(Player, ObjectInteractingWith, Type, Subtype, Data, InteractConnection)
	-- Check if object present
	if not ObjectInteractingWith then
		return
	end
	
	-- Check if the interface can be used
	if InterfaceInUse or Interact.ReferencingActionInterface then
		return
	end
	
	-- Set the player to be a part of the data group
	Data = Data or {}
	Data.Player = Player

	-- Load the data group (main thread this then test)
	local Interface, Callbacks = Action:LoadActionGroup(Type, Subtype, Data)

	if Interface and Callbacks then
		-- Start the sequence now that all conditions are checked off
		InterfaceInUse = true
				
		-- Pause the interact thread and give it some time to render
		if InteractConnection then
			Interact:Pause(InteractConnection, 'ObjectSelected')
			task.wait(1)
		end
		
		-- Initialize tween factors
		local InterfaceSize = Interface.Size
		Interface.Size = UDim2.fromScale(0, 0)
		Interface.Parent = script.Parent
		
		-- Starting tween
		local Tween = TweenService:Create(Interface, Configurations.ActionInTweenInformation, {Size = InterfaceSize})
		Tween:Play()
		Tween.Completed:Wait()
		
		-- Add the action so that other interfaces can't be clicked
		Interact:AddAction('PlayerPetAction')
		
		-- Initialize action options and paradigms
		local SelectedIndice = false
		local ActionConnections = {}

		for _, Indice in pairs(Interface['Indices']:GetChildren()) do
			local IndiceSize = Indice.Size
			local Callback = Callbacks[Indice]

			-- We don't need to disconnect the next range of events as the action will eventually be destroyed
			-- Also, we need to add renderStepped to mouseEnter/mouseLeave events so they fire reliably
			Indice.Button.MouseEnter:Connect(function()
				RunService.RenderStepped:Wait()

				local Tween = TweenService:Create(Indice, Configurations.ActionInHoverTweenInformation, {Size = UDim2.fromScale(IndiceSize.X.Scale * Configurations.InterfaceGrowth, IndiceSize.Y.Scale * Configurations.InterfaceGrowth)})
				Tween:Play()	
			end)

			Indice.Button.MouseLeave:Connect(function()
				RunService.RenderStepped:Wait()

				local Tween = TweenService:Create(Indice, Configurations.ActionInHoverTweenInformation, {Size = IndiceSize})
				Tween:Play()	
			end)

			Indice.Button.MouseButton1Down:Connect(function()
				if not SelectedIndice then
					SelectedIndice = true
					OnActionCompleted(Player, ObjectInteractingWith, Interface, InteractConnection, Callback)
				end
			end)
		end

		-- Set up close button events
		local CloseButtonSize = Interface.Close.Size

		Interface.Close.MouseEnter:Connect(function()
			RunService.RenderStepped:Wait()

			local Tween = TweenService:Create(Interface.Close, Configurations.ActionInHoverTweenInformation, {Size = UDim2.fromScale(CloseButtonSize.X.Scale * Configurations.CloseInterfaceGrowth, CloseButtonSize.Y.Scale * Configurations.CloseInterfaceGrowth)})
			Tween:Play()	
		end)

		Interface.Close.MouseLeave:Connect(function()
			RunService.RenderStepped:Wait()

			local Tween = TweenService:Create(Interface.Close, Configurations.ActionInHoverTweenInformation, {Size = CloseButtonSize})
			Tween:Play()	
		end)

		Interface.Close.MouseButton1Down:Connect(function()
			OnActionCompleted(Player, ObjectInteractingWith, Interface, InteractConnection)
		end)
	end
end

local function OnActionInvoke(Type, Subtype, Player, Data)
	if Type == 'Client' then
		if Subtype == 'Pet' or Subtype == 'Egg' then
			local InteractConnection; InteractConnection = Interact:Listen(Data.Model.PrimaryPart, 'Click', 'Interact', function()
				OnActionSetup(Player, Data.Model.PrimaryPart, Type, Subtype, Data, InteractConnection)
			end)

			ConnectionInformation[Data.Model.PrimaryPart] = InteractConnection
		elseif Subtype == 'Player' then
			local Character = Player.Character
			local HumanoidRootPart = Character:WaitForChild('HumanoidRootPart')
			
			OnActionSetup(Player, HumanoidRootPart, Type, Subtype)
		end
	else
		if Subtype == 'Pet' or Subtype == 'Egg' then
			local InteractConnection; InteractConnection = Interact:Listen(Data.Model.PrimaryPart, 'Click', 'Interact', function()
				OnActionSetup(Player, Data.Model.PrimaryPart, Type, Subtype, Data, InteractConnection)
			end)

			ConnectionInformation[Data.Model.PrimaryPart] = InteractConnection
		elseif Subtype == 'Player' then
			local Character = Player.Character
			local HumanoidRootPart = Character:WaitForChild('HumanoidRootPart')
			
			local InteractConnection; InteractConnection = Interact:Listen(HumanoidRootPart, 'Click', 'Interact', function()
				OnActionSetup(Player, HumanoidRootPart, Type, Subtype, nil, InteractConnection)
			end)

			ConnectionInformation[HumanoidRootPart] = InteractConnection
		end
	end
end

local function OnActionDisconnect(Object)
	if Object and ConnectionInformation[Object] then
		print('Object garbage collected successfully.')
		
		Interact:Ignore(ConnectionInformation[Object])
		ConnectionInformation[Object] = nil
	end
end

-- Added / removing functions
local function CharacterAdded(Player)
	if not Player then
		return
	end
		
	-- Wait for character object to load
	repeat
		task.wait()
	until (Player.Character)
	
	-- Initialize
	OnActionInvoke('Nonclient', 'Player', Player)
end

local function CharacterRemoving(Character)
	if Character then
		local CharacterRoot = Character:FindFirstChild('HumanoidRootPart')
		
		if CharacterRoot then
			OnActionDisconnect(CharacterRoot)
		end
	end
end

local function PlayerAdded(Player)
	if Player ~= LocalPlayer then
		-- This needs to go first
		CharacterAdded(Player)
		
		Player.CharacterAdded:Connect(function()
			CharacterAdded(Player)
		end)
		
		Player.CharacterRemoving:Connect(CharacterRemoving)
	end
end

local function PlayerRemoving(Player)
	if Player ~= LocalPlayer then
		local Character = Player.Character
		
		if Character then
			local CharacterRoot = Character:FindFirstChild('HumanoidRootPart')
			
			if CharacterRoot then
				OnActionDisconnect(CharacterRoot)
			end
		end
	end
end

local function PetAdded(Information)
	local Data = {
		Model = Information.Pet,
		Folder = Information.Folder,
		Pet = Information.Key
	}
	
	local Subtype = 'Pet'
	
	if PetModule['Settings']['Stages'][Information.Folder.Data.Stage]['Stage'] == 'Egg' then
		Subtype = 'Egg'
	end
	
	if Information.Player == LocalPlayer then
		OnActionInvoke('Client', Subtype, Information.Player, Data)
	else
		OnActionInvoke('Nonclient', Subtype, Information.Player, Data)
	end
end

local function PetRemoving(Information)
	local Pet = Information.Pet
	
	if Pet then
		local PetPrimaryPart = Pet.PrimaryPart
		
		if PetPrimaryPart then
			OnActionDisconnect(PetPrimaryPart)
		end
	end
end

-- Events
Players.PlayerAdded:Connect(PlayerAdded)
Players.PlayerRemoving:Connect(PlayerRemoving)

UpdatePetRemote.OnClientEvent:Connect(function(Mode, Information)	
	if Mode == 'Equipped' and Information.Type == 'New' then
		PetAdded(Information)
	elseif Mode == 'Unequipped' then
		PetRemoving(Information)
	end
end)

PetMovementBindable.Event:Connect(function(Pet, NewState)
	local InteractConnections = Interact:Retrieve(Pet.PrimaryPart)
	
	if NewState ~= 'Idle' then
		for _, InteractConnection in pairs(InteractConnections) do
			Interact:Pause(InteractConnection, 'PetMovement')
		end
	else
		for _, InteractConnection in pairs(InteractConnections) do
			Interact:Resume(InteractConnection, 'PetMovement')
		end
	end
end)

UserInputService.InputBegan:Connect(function(Key, Typing)
	if not Typing then
		if Key.UserInputType == Enum.UserInputType.MouseButton1 or Key.UserInputType == Enum.UserInputType.Touch then
			local RayHit = Settings:GetMouseHit()
			
			if RayHit and LocalPlayer.Character and RayHit:IsDescendantOf(LocalPlayer.Character) then
				OnActionInvoke('Client', 'Player', LocalPlayer)
			end
		end
	end	
end)

-- Main sequence
for _, Player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		PlayerAdded(Player)
	end)
end

local CurrentPets = RequestPetRemote:InvokeServer(true)

for _, Information in ipairs(CurrentPets) do
	PetAdded(Information)
end