local Lighting = game:GetService('Lighting')
local RunService = game:GetService("RunService")
local TweenService = game:GetService('TweenService')
local ReplicatedFirst = game:GetService('ReplicatedFirst')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local StarterGui = game:GetService('StarterGui')
local ContentProvider = game:GetService('ContentProvider')

local Player = game.Players.LocalPlayer
local PlayerGui = Player:WaitForChild('PlayerGui')

local Camera = workspace:WaitForChild('Camera')
local CameraPoint = workspace:WaitForChild('Map'):WaitForChild('Components'):WaitForChild('Camera')

local Loading = script:WaitForChild('Loading')
local Main, Menu, Fade = Loading:WaitForChild('Main'):WaitForChild('Holder'), Loading:WaitForChild('Menu'), Loading:WaitForChild('Fade')
local Progress, Caption = Main:WaitForChild('Bar'):WaitForChild('Progress'), Main:WaitForChild('Caption')
local Gradient = Main.Parent:WaitForChild('Gradient')
local Play = Menu:WaitForChild('Play')

local Disable = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Other"):WaitForChild('Disable')

local Data = require(ReplicatedStorage:WaitForChild('Modules'):WaitForChild('Data'):WaitForChild('Core'))
local Mouseover = require(ReplicatedStorage:WaitForChild('Modules'):WaitForChild('Utility'):WaitForChild('Mouseover'))

-- Performance measurement
local SuccessfullyStackedItems, TimeToStack, CheckRate = false, 7.5, 0.5

task.spawn(function()
	local Waited = 0
	
	repeat
		if SuccessfullyStackedItems == true then
			return
		end
		
		task.wait(CheckRate)
		Waited += CheckRate
	until (Waited >= TimeToStack)
	
	warn('Load content failed to stack content in expected time.')
end)

-- Read below:
local LoadingContent = {
	StarterGui:WaitForChild('Fixed'):WaitForChild('Buttons'),
	StarterGui:WaitForChild('Fixed'):WaitForChild('Frames'):WaitForChild('Clothing'),
	StarterGui:WaitForChild('Fixed'):WaitForChild('Frames'):WaitForChild('Home'),
	StarterGui:WaitForChild('Fixed'):WaitForChild('Frames'):WaitForChild('Time'),
	StarterGui:WaitForChild('Standard'):WaitForChild('Buttons'),
	StarterGui:WaitForChild('Constrained'):WaitForChild('Buttons'),
	StarterGui:WaitForChild('Constrained'):WaitForChild('Frames'),
	ReplicatedStorage:WaitForChild('Assets'):WaitForChild('Interface'),
	ReplicatedStorage:WaitForChild('Assets'):WaitForChild('Homes'),
	ReplicatedStorage:WaitForChild('Assets'):WaitForChild('Particles'),
	Loading,
}

-- Keep this part here as some variables require it
local LoadingContentBin = {}

for _, Content in pairs(LoadingContent) do
	table.insert(LoadingContentBin, {Content})
end

SuccessfullyStackedItems = true

-- More variables
local GuisThatResetOnSpawn = {}

local AssetsLoaded = 0
local TotalTweenTime = 0.75 -- The total time it should take to tween entire bar with or without content

local StandardTweenInformation = TweenInfo.new(TotalTweenTime / #LoadingContentBin, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local StartingTweenInformation = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local FadingGradientTweenInformation = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local FadingScreenTweenInformation = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local FadingScreenOutTweenInformation = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
local BounceInTweenInformation = TweenInfo.new(1.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)

-- Remaining variables
local OffsetStartingBarPercentage = 5.5 -- The first bar percentage you see
local StartingBarPercentage = 10 -- Offset tweens to this immediately
StartingBarPercentage /= 100; OffsetStartingBarPercentage /= 100;

local OriginalMainSize = Main.Size

local PlayColor = {
	Original = Play:WaitForChild('Main').BackgroundColor3,
	Hovered = Color3.fromRGB(34, 255, 146)
}

-- Core functions
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
		{Position = UDim2.fromScale(0.5, 0.5)})

	Playing:Play()
	Playing.Completed:Wait()
end

function Tween(Object, Info, Properties)
	local Tween = TweenService:Create(Object, Info, Properties)
	Tween:Play()
	
	Tween.Completed:Wait()
end

function DisableAllGuis(GuiFolder)
	local PropertyTable = {}
	
	local RemoveAddedUIConnection = GuiFolder.ChildAdded:Connect(function(Interface)
		if Interface:IsA('ScreenGui') and Interface ~= Loading then
			PropertyTable[Interface] = {Enabled = Interface.Enabled, ResetOnSpawn = Interface.ResetOnSpawn}
			Interface.Enabled, Interface.ResetOnSpawn = false	, false
		end
	end)
	
	for _, Interface in pairs(GuiFolder:GetChildren()) do
		task.spawn(function()
			if Interface:IsA('ScreenGui') and Interface ~= Loading then
				PropertyTable[Interface] = {Enabled = Interface.Enabled, ResetOnSpawn = Interface.ResetOnSpawn}
				Interface.Enabled, Interface.ResetOnSpawn = false	, false
			end
		end)
	end
	
	return PropertyTable, RemoveAddedUIConnection
end

function EnableAllGuis(PropertyTable, RemovingConnection)
	RemovingConnection:Disconnect()
	
	for Interface, PropertySubtable in pairs(PropertyTable) do
		for PropertyName, Property in pairs(PropertySubtable) do
			Interface[PropertyName] = Property
		end
	end
end

local function BeginningTween(Fade)
	local FadeInTween = TweenService:Create(Fade, FadingScreenTweenInformation, {Transparency = 0}) -- BC3

	Fade.Visible = true
	Fade.Transparency = 1
	Fade.Size = UDim2.fromScale(1, 1)
	
	FadeInTween:Play()
	FadeInTween.Completed:Wait()
	
	return Fade
end

local function FinishingTween(Fade)
	local ZoomingOutTween = TweenService:Create(Fade, FadingScreenOutTweenInformation, {Transparency = 1})
	ZoomingOutTween:Play()
	ZoomingOutTween.Completed:Wait()
end

-- Main sequencing
if Camera.CameraSubject == nil then
	repeat RunService.RenderStepped:Wait() until Camera.CameraSubject ~= nil
end

Camera.CameraType = Enum.CameraType.Scriptable
Camera.CFrame = CameraPoint.CFrame

Disable:Fire(true)

-- Setup the interface
Loading.Parent = PlayerGui
ReplicatedFirst:RemoveDefaultLoadingScreen()

-- Set up the loading assets
Progress.Size = UDim2.fromScale(OffsetStartingBarPercentage, 1)
Main.Size = UDim2.fromScale(0, 0)

Tween(Main, BounceInTweenInformation, {Size = OriginalMainSize})
Tween(Progress, StartingTweenInformation, {Size = UDim2.fromScale(StartingBarPercentage, 1)})

local TimeStarted = tick()

for Index, Content in pairs(LoadingContentBin) do
	ContentProvider:PreloadAsync(Content)
	AssetsLoaded += 1
	Tween(Progress, StandardTweenInformation, {Size = UDim2.fromScale((AssetsLoaded / #LoadingContentBin) * (1 - StartingBarPercentage) + StartingBarPercentage, 1)})
end

print('Loaded in: ~' .. tick() - (StandardTweenInformation.Time * #LoadingContentBin) - TimeStarted)

Tween(Progress, StartingTweenInformation, {Size = UDim2.fromScale(1, 1)})

Caption.Text = 'Waiting for data'
repeat task.wait() until (Data.Loaded and Data.SharedLoaded)

task.wait(0.1)

Caption.Text = 'Waiting for game'
repeat task.wait() until (game:IsLoaded())

task.wait(0.5)

-- Some quick aesthetics
for _, Object in pairs(Main:GetChildren()) do
	if Object:IsA('GuiObject') then
		Object.Visible = false 
	end
end

Tween(Gradient, FadingGradientTweenInformation, {Offset = Vector2.new(1, 0)})

-- Now introduce the main menu
local Blur = Instance.new('BlurEffect')
Blur.Size = 12
Blur.Parent = Lighting

local PlayMouseEnterBindable, PlayMouseLeftBindable = Mouseover.MouseEnterLeaveEvent(Play)
local PlayMouseButtonEvent, PlayMouseEnterEvent, PlayMouseLeftEvent

local PropertiesOfDisabled, RemovingConnection = DisableAllGuis(PlayerGui)

PlayMouseButtonEvent = Play.MouseButton1Down:Connect(function()
	PlayMouseButtonEvent:Disconnect()
	CommonTween(Play)
	
	Menu.Visible = false
	
	-- Consider using a normal fade for this and FinishingTween()
	local Fader = BeginningTween(Fade)
	
	Menu.Visible = false
	Blur:Destroy()
	
	EnableAllGuis(PropertiesOfDisabled, RemovingConnection)
	
	local Character = Player.Character or Player.CharacterAdded:Wait()
	local Humanoid = Character:WaitForChild('Humanoid')
	
	Camera.CameraType = Enum.CameraType.Custom
	Camera.CameraSubject = Humanoid
		
	task.wait(0.5)
	Disable:Fire()
	
	FinishingTween(Fader)
	
	Loading:Destroy()
	script:Destroy()
end)

PlayMouseEnterEvent = PlayMouseEnterBindable:Connect(function()
	Play.Main.BackgroundColor3 = PlayColor.Hovered
end)

PlayMouseLeftEvent = PlayMouseLeftBindable:Connect(function()
	Play.Main.BackgroundColor3 = PlayColor.Original
end)

Menu.Visible = true

Tween(Main.Parent, FadingScreenTweenInformation, {BackgroundTransparency = 1})
Main.Parent.Visible = false