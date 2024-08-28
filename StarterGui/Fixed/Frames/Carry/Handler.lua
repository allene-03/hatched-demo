-- Services
local Replicated = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')

-- Mainstream
local LocalPlayer = Players.LocalPlayer

local AnimationModule = require(Replicated:WaitForChild('Modules'):WaitForChild('Animation'):WaitForChild('Core'))
local Interact = require(Replicated:WaitForChild('Modules'):WaitForChild('Interface'):WaitForChild('Interact'):WaitForChild('Core'))

local CarryingRemote = Replicated:WaitForChild('Remotes'):WaitForChild('Pets'):WaitForChild('Carrying')

local ClientCarrying = nil
local NonclientCarrying = {}
local PlayingCarriedAnimation = {}

-- Interface
local Frame = script.Parent
local Button = Frame.Parent.Parent:WaitForChild('Buttons'):WaitForChild('Drop')

-- Functions
local function HandleServerEvent(Mode, Arguments)
	if Mode == 'Carry' then
		local AnimationController = Arguments.Pet:FindFirstChild('AnimationController')

		if not AnimationController or not Arguments or not Arguments.Id then
			return
		else
			HandleServerEvent('Drop', Arguments)
		end
				
		local Configurations = require(Arguments.Information.Configuration)
		local Animation = Arguments.Information.Animations:FindFirstChild('Held')
		
		local LoadedAnimation
		
		if Animation then
			local AnimationSpeed = Configurations.CarryAnimationSpeed or 1
			
			LoadedAnimation = AnimationController:LoadAnimation(Animation)
			LoadedAnimation.Looped = true
			LoadedAnimation:Play(nil, nil, AnimationSpeed)
		end
		
		if Arguments.Id == LocalPlayer.UserId then
			ClientCarrying = LoadedAnimation
			
			-- Play animation from character
			AnimationModule:PlayAnimation(LocalPlayer.Character, 'Carrying', {Looped = true, Weight = 2})
			
			-- Turn off interact
			local InteractConnections = Interact:Retrieve(Arguments.Pet.PrimaryPart)

			for _, InteractConnection in pairs(InteractConnections) do
				Interact:Pause(InteractConnection, 'CarryingPet', true)
			end

			Button.Visible = true
		else
			NonclientCarrying[Arguments.Id] = LoadedAnimation
		end
	elseif Mode == 'Drop' then
		if not Arguments or not Arguments.Id then
			return
		end
	
		if Arguments.Id == LocalPlayer.UserId then
			-- Turn off interact
			if Arguments.Pet then
				local InteractConnections = Interact:Retrieve(Arguments.Pet.PrimaryPart)

				for _, InteractConnection in pairs(InteractConnections) do
					Interact:Resume(InteractConnection, 'CarryingPet', true)
				end
			end
			
			-- Stop the animations playing
			if ClientCarrying then
				ClientCarrying:Stop()
			end
			
			ClientCarrying = nil
			
			-- Stop the carrying animation for the player
			AnimationModule:StopAnimation('Carrying')
			
			-- Set it to visible
			Button.Visible = false
		else
			if NonclientCarrying[Arguments.Id] then
				NonclientCarrying[Arguments.Id]:Stop()
			end

			NonclientCarrying[Arguments.Id] = nil
		end
	end
end

-- Events
CarryingRemote.OnClientEvent:Connect(HandleServerEvent)

Button.MouseButton1Down:Connect(function()
	CarryingRemote:FireServer('Drop')
end)

-- Main sequence
Button.Visible = false