local Replicated = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')
local StarterGui = game:GetService('StarterGui')

local LocalPlayer = Players.LocalPlayer

local ActionInterfaceFolder = Replicated:WaitForChild('Assets'):WaitForChild('Interface'):WaitForChild('Action')
local Notify = Replicated.Remotes:WaitForChild('Systems'):WaitForChild('Notify')

-- The functions, remotes, modules required for actions
local BreedRemoteHandler = Replicated:WaitForChild('Remotes'):WaitForChild('Breed'):WaitForChild('Handle')
local GoHomeBindable = Replicated:WaitForChild('Remotes'):WaitForChild('Other'):WaitForChild('InvokeDeath')
local UpgradingBindable = Replicated:WaitForChild('Remotes'):WaitForChild('Other'):WaitForChild('InvokeUpgrade')
local RenamingBindable = Replicated:WaitForChild('Remotes'):WaitForChild('Other'):WaitForChild('InvokeRename')
local CarryingRemote = Replicated:WaitForChild('Remotes'):WaitForChild('Pets'):WaitForChild('Carrying')

local EffectsModule = require(Replicated:WaitForChild('Modules'):WaitForChild('Pet'):WaitForChild('Effects'))

-- Option types
local ActionInterfaces = {
	One = ActionInterfaceFolder:WaitForChild('One-Menu'),
	Two = ActionInterfaceFolder:WaitForChild('Two-Menu'),
	Four = ActionInterfaceFolder:WaitForChild('Four-Menu')
}

-- Selection parameters
local CoreActionModule = {
	Selection = {
		Client = {
			Player = {
				Actions = {'Breed', 'Home'}
			},
			
			Pet = {
				Actions = {'Breed', 'Carry', 'Rename', 'Upgrade'}
			},
			
			Egg = {
				Actions = {'Breed', 'Carry', 'Rename', 'Hatch'}
			}
		},
		
		Nonclient = {
			Player = {
				Actions = {'Breed', 'Friend'}
			},
			
			Pet = {
				Actions = {'Breed'}
			},
			
			Egg = {
				Actions = {'Back'}
			}
		}
	},
}

-- Configuration data
local ActionConfigurations = {
	['Breed'] = {
		Color = Color3.fromRGB(31, 241, 95),
		Name = 'Breed'
	},

	['Home'] = {
		Color = Color3.fromRGB(232, 29, 17),
		Name = 'Go Home'
	},

	['Carry'] = {
		Color = Color3.fromRGB(234, 152, 39),
		Name = 'Carry'
	},

	['Rename'] = {
		Color = Color3.fromRGB(100, 156, 236),
		Name = 'Rename'
	},

	['Upgrade'] = {
		Color = Color3.fromRGB(234, 255, 251),
		Name = 'Upgrade'
	},

	['Hatch'] = {
		Color = Color3.fromRGB(73, 241, 175),
		Name = 'Hatch Now'
	},

	['Friend'] = {
		Color = Color3.fromRGB(193, 241, 78),
		Name = 'Add Friend'
	},
	
	['Back'] = {
		Color = Color3.fromRGB(235, 205, 28),
		Name = 'Back'
	},
	
	['__Default'] = {
		Color = Color3.fromRGB(255, 255, 255),
		Name = ''
	},
}

-- Module functions
function CoreActionModule:LoadActionGroup(Type, Subtype, Data)
	local GroupType = CoreActionModule['Selection'][Type]
	
	if GroupType then
		local GroupSubtype = GroupType[Subtype]
		
		if GroupSubtype then
			local Interface
			local Callbacks = {}
			
			-- Choose the menu going to be used
			if #GroupSubtype.Actions == 1 then
				Interface = ActionInterfaces['One']:Clone()
			elseif #GroupSubtype.Actions == 2 then
				Interface = ActionInterfaces['Two']:Clone()
			else
				Interface = ActionInterfaces['Four']:Clone()
			end
			
			-- Set the reference text
			Interface.Reference.Text = '@' .. Data.Player.Name
			
			for Indice, Action in pairs(GroupSubtype.Actions) do
				local InterfaceIndice = Interface['Indices']['_' .. Indice]
				local ActionData = ActionConfigurations[Action]
				
				if not ActionData then
					ActionData = ActionConfigurations['__Default']
				end
				
				-- Recolor the interface
				InterfaceIndice.ImageColor3 = Color3.fromRGB(255, 255, 255) -- Old: ActionData.Color:Lerp(Color3.new(0, 0, 0), 0.25)
				InterfaceIndice.Background.ImageColor3 = ActionData.Color:Lerp(Color3.new(1, 1, 1), 0.15)
				InterfaceIndice.Title.TextColor3 = ActionData.Color:Lerp(Color3.new(0, 0, 0), 0.35)
				
				-- Naming the interface and giving text
				InterfaceIndice.Title.Text = string.upper(ActionData.Name)
				InterfaceIndice.Name = Action
				
				-- Set the callback to be used later
				local Callback = function() end
				
				if Action == 'Breed' then
					Callback = function()
						BreedRemoteHandler:FireServer('Initiate', {Other = Data.Player.Name})

						if LocalPlayer ~= Data.Player then
							Notify:Fire("You sent a breed request to " .. Data.Player.Name .. ".")
						end
					end
				elseif Action == 'Friend' then
					Callback = function()
						StarterGui:SetCore("PromptSendFriendRequest", Data.Player)
					end
				elseif Action == 'Home' then
					Callback = function()
						GoHomeBindable:Fire()
					end
				elseif Action == 'Upgrade' then
					Callback = function()
						UpgradingBindable:Fire(Data.Pet)
					end
				elseif Action == 'Rename' then
					Callback = function()
						RenamingBindable:Fire(Data.Pet)
					end
				elseif Action == 'Carry' then
					Callback = function()
						if not EffectsModule:IsPlaying(Data.Model, true) then
							CarryingRemote:FireServer('Carry')
						end
					end
				elseif Action == 'Back' then
					Callback = function()
						-- Don't need to do anything additional here 
					end
				end
				
				Callbacks[InterfaceIndice] = Callback
			end
			
			-- Rename the asset
			Interface.Name = 'Menu'
			
			return Interface, Callbacks
		end
	end
end

return CoreActionModule