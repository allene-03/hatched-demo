local Replicated = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')
local UserInputService = game:GetService('UserInputService')
local RunService = game:GetService('RunService')
local Players = game:GetService('Players')

local Settings = require(Replicated:WaitForChild('Modules'):WaitForChild('Utility'):WaitForChild('Settings'))

local LocalPlayer = Players.LocalPlayer
local LocalCharacter = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

local PlayerGui = LocalPlayer:WaitForChild('PlayerGui')

-- Variables
local TemplateInterface = Replicated:WaitForChild('Assets'):WaitForChild('Interface'):WaitForChild('Interact'):WaitForChild('Main')

local Configurations = {
	TemplateInterfaceButtonSize = TemplateInterface:WaitForChild('Button')['Size'],
	TemplateInterfaceButtonEnableInfo = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false),
	TemplateInterfaceButtonDisableInfo = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In, 0, false),
	TemplateInterfaceButtonSpinInfo = TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false),
	TemplateInterfaceButtonSpinHoldInfo = TweenInfo.new(120, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false),
}

-- For CoreInteractModule.ReferencingActionInterface
local ActionInterfaceVisibilityList = {}

local CoreInteractModule = {
	-- This is the main repository for the interfaces
	Repository = Settings:Create('ScreenGui', 'Interact', PlayerGui),

	-- This is where all the connections will be stored
	StoredInterfaceConnections = {},

	-- Settings
	Settings = {
		DistanceFromObject = 25,
	},
	
	-- Whether or not an action interface is open or not, this should never be set directly without methods
	ReferencingActionInterface = false
}

-- Functions
-- We use transparency instead of visibility to not interfere with the Hide/Show functions
local function SetButtonVisibility(Button, On)
	if Button:FindFirstChild('Action') then
		Button.Action.TextTransparency = On and 0 or 1

		if Button.Action:FindFirstChild('Gradient') then
			Button.Action.Gradient.Transparency = On and 0 or 1
		end
	end
end

local function Index(Table, Object)
	for ValueIndex, Value in pairs(Table) do
		if Value == Object then
			return ValueIndex
		end
	end
end

local function ConnectEvents(Button, InterfaceConnection)
	local Events = {}
	local MouseHolding = false
	local MouseEnteredThread = 0
	
	local SpinningTween
	
	-- We add RenderStepped because MouseEntered and MouseLeave won't work reliably without them before processes
	local MouseEnteredEvent; MouseEnteredEvent = Button.MouseEnter:Connect(function()
		RunService.RenderStepped:Wait()
		SetButtonVisibility(Button, true)
		
		local CurrentMouseEnteredThread = MouseEnteredThread
		
		-- We index the connections to make sure that another thread hasn't started which would cause two while loops to be playing
		while (CurrentMouseEnteredThread == MouseEnteredThread) and (InterfaceConnection and Settings:Index(InterfaceConnection.Connections, MouseEnteredEvent)) do
			if Button:FindFirstChild('Spin') then
				Button.Spin.Rotation = 0

				SpinningTween = TweenService:Create(
					Button.Spin,
					MouseHolding and Configurations.TemplateInterfaceButtonSpinHoldInfo or Configurations.TemplateInterfaceButtonSpinInfo,
					{Rotation = MouseHolding and (360 * 16) or 360}
				)
				
				SpinningTween:Play()
				
				SpinningTween.Completed:Wait()
			else
				break
			end
		end
		
		SpinningTween = nil
	end)
	
	table.insert(Events, MouseEnteredEvent)
	
	table.insert(Events, Button.MouseLeave:Connect(function()
		RunService.RenderStepped:Wait()
		SetButtonVisibility(Button, false)

		MouseEnteredThread += 1
	end))
	
	if InterfaceConnection.Mode == 'Click' then
		table.insert(Events, Button.MouseButton1Down:Connect(function()
			MouseEnteredThread += 1
			InterfaceConnection['Callback']()
		end))
	elseif InterfaceConnection.Mode == 'Hold' then
		local TimeToHold = InterfaceConnection.Time or 2.5
		
		table.insert(Events, Button.MouseButton1Down:Connect(function()
			if MouseHolding then
				return
			end

			MouseHolding = true

			local MouseHeldEntireTime = false
			local TimeHeld = 0

			while UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do			
				if TimeHeld >= (TimeToHold) then
					MouseHeldEntireTime = true
					break
				else
					TimeHeld += task.wait()
				end
			end

			if MouseHeldEntireTime and InterfaceConnection then
				InterfaceConnection['Callback']()
			end

			MouseHolding = false

			if SpinningTween then
				SpinningTween:Cancel()
			end
		end))
	else
		warn('No applicable interact modes identified for given button object.')
	end
	
	return Events
end

local function DisconnectEvents(InterfaceConnection)	
	for _, Event in pairs(InterfaceConnection.Connections) do
		Event:Disconnect()
	end

	return {}
end

local function Enable(InterfaceConnection)
	if not InterfaceConnection.Action then
		InterfaceConnection.Action = 'Enabling'
		InterfaceConnection.Active = true

		local Interface = InterfaceConnection['Interface']

		local InterfaceButton = Interface:WaitForChild('Button')
		InterfaceButton.Size = UDim2.fromScale(0, 0)
		InterfaceButton:WaitForChild('Action')['TextTransparency'] = 1
		InterfaceButton:WaitForChild('Action'):WaitForChild('Gradient')['Transparency'] = 1

		Interface.Enabled = true

		-- We attach events
		InterfaceConnection.Connections = ConnectEvents(InterfaceButton, InterfaceConnection)

		local Tween = TweenService:Create(InterfaceButton, Configurations.TemplateInterfaceButtonEnableInfo, {Size = Configurations.TemplateInterfaceButtonSize})
		Tween:Play()

		-- We let the main thread resume while blocking off future actions until completed
		task.spawn(function()
			Tween.Completed:Wait()
			InterfaceConnection.Action = nil
		end)
	end
end

local function Disable(InterfaceConnection)
	if not InterfaceConnection.Action then
		InterfaceConnection.Action = 'Disabling'
		InterfaceConnection.Active = false

		-- We disconnect the events
		InterfaceConnection.Connections = DisconnectEvents(InterfaceConnection)

		local Interface = InterfaceConnection['Interface']
		local InterfaceButton = Interface:WaitForChild('Button')

		local Tween = TweenService:Create(InterfaceButton, Configurations.TemplateInterfaceButtonDisableInfo, {Size = UDim2.fromScale(0, 0)})
		Tween:Play()

		-- We let the main thread resume while blocking off future actions until completed
		task.spawn(function()
			Tween.Completed:Wait()

			Interface.Enabled = false
			InterfaceButton.Size = Configurations.TemplateInterfaceButtonSize

			InterfaceConnection.Action = nil
		end)
	end
end

-- Module functions
local function HandleIgnore(InterfaceConnection)
	local StoredConnections = CoreInteractModule.StoredInterfaceConnections
	local Index = Settings:Index(StoredConnections, InterfaceConnection)
	
	if Index then
		DisconnectEvents(InterfaceConnection)
		
		InterfaceConnection.Interface:Destroy()
		StoredConnections[Index] = nil
	end
end

-- Set object to be garbage collected
function CoreInteractModule:Ignore(InterfaceConnection)
	local StoredConnections = CoreInteractModule.StoredInterfaceConnections
	
	if InterfaceConnection and Settings:Index(StoredConnections, InterfaceConnection) then
		InterfaceConnection.Breaking = true
	end
end

-- Pause the ability to view the object, the force parameter should be used VERY sparingly
function CoreInteractModule:Pause(InterfaceConnection, ActionName, Force)
	local StoredConnections = CoreInteractModule.StoredInterfaceConnections

	if InterfaceConnection and Settings:Index(StoredConnections, InterfaceConnection) then
		InterfaceConnection.VisibilityList[ActionName] = true
		
		-- This may be causing visual glitches on pet effects, you can remove if needed
		if Force then
			InterfaceConnection.Interface.Button.Visible = false
		end
		
		InterfaceConnection.Pausing = true
	end
end

-- Resume the ability to view the object
function CoreInteractModule:Resume(InterfaceConnection, ActionName)
	local StoredConnections = CoreInteractModule.StoredInterfaceConnections

	if InterfaceConnection and Settings:Index(StoredConnections, InterfaceConnection) then	
		InterfaceConnection.VisibilityList[ActionName] = nil
		
		if Settings:Length(InterfaceConnection.VisibilityList) <= 0 then
			InterfaceConnection.Pausing = false
			InterfaceConnection.Interface.Button.Visible = true
		end
	end
end

-- Toggle on/off ReferencingActionInterface
function CoreInteractModule:AddAction(ActionName)
	ActionInterfaceVisibilityList[ActionName] = true
	
	if not CoreInteractModule.ReferencingActionInterface then
		CoreInteractModule.ReferencingActionInterface = true
	end
end

function CoreInteractModule:RemoveAction(ActionName)
	ActionInterfaceVisibilityList[ActionName] = nil

	if Settings:Length(ActionInterfaceVisibilityList) <= 0 and CoreInteractModule.ReferencingActionInterface then
		CoreInteractModule.ReferencingActionInterface = false
	end
end

-- Returns all the interface connections for a given object
function CoreInteractModule:Retrieve(Object)
	local RetrievedConnections = {}
	
	for _, InterfaceConnection in pairs(CoreInteractModule.StoredInterfaceConnections) do
		if InterfaceConnection.Object == Object then
			table.insert(RetrievedConnections, InterfaceConnection)
		end 
	end
	
	return RetrievedConnections
end

-- Sets listening event
function CoreInteractModule:Listen(Object, Mode, Action, Callback, OptionalParameters)
	local Interface = TemplateInterface:Clone()
	Interface.Adornee = Object
	Interface.Enabled = false
	Interface.Parent = CoreInteractModule.Repository
	
	local Button = Interface:WaitForChild('Button')
	
	-- Set the mode/action to the caption
	Button.Label.Text = string.upper(Mode)
	Button.Action.Text = Action

	-- Set the connection
	local InterfaceConnection = {
		Object = Object,
		Interface = Interface,
		Mode = Mode,
		Callback = Callback,
		Connections = {},
		VisibilityList = {},
		Active = false,
		Breaking = false,
		Pausing = nil,
		Action = nil,
		Time = OptionalParameters and OptionalParameters.HoldTime,
	}
		
	table.insert(CoreInteractModule.StoredInterfaceConnections, InterfaceConnection)
	return InterfaceConnection
end

-- Connections
LocalPlayer.CharacterAdded:Connect(function(AddedCharacter)
	LocalCharacter = AddedCharacter
end)

-- Main sequence
CoreInteractModule.Repository.ResetOnSpawn = false
CoreInteractModule.Repository.ZIndexBehavior = Enum.ZIndexBehavior.Global

-- Spawn the main handler
task.spawn(function()
	while true do
		local StoredConnections = CoreInteractModule.StoredInterfaceConnections

		if not LocalCharacter or not LocalCharacter.PrimaryPart then
			RunService.Heartbeat:Wait()
			continue
		end

		for _, InterfaceConnection in pairs(StoredConnections) do
			local Object = InterfaceConnection.Object
			
			if (Object and Object.Parent) and (not InterfaceConnection.Breaking) then
				if (not InterfaceConnection.Pausing) and (not CoreInteractModule.ReferencingActionInterface) and (Object.Position - LocalCharacter.PrimaryPart.Position).Magnitude <= CoreInteractModule.Settings.DistanceFromObject then
					if not InterfaceConnection.Active then
						Enable(InterfaceConnection)
					end
				else
					if InterfaceConnection.Active then
						Disable(InterfaceConnection)
					end
				end
			else
				HandleIgnore(InterfaceConnection)
			end
		end

		task.wait(0.5)
	end
end)

return CoreInteractModule

-- Test for extreme reliability (especially with the risk of the AttachEvent functions)
-- E Key for the closest key or at MINIMUM closest text label around
-- Consider range being smaller and Action labels visible on all the time