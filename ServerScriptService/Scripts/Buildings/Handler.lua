local Replicated = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')

local Settings = require(Replicated.Modules.Utility.Settings)
local TouchedRemote = Replicated.Remotes.Buildings.Touched

-- For tutorial
local TutorialModule = require(Replicated.Modules.Tutorial.Core)

local Received = Replicated.Remotes.Tutorial.Received
local Communication = Replicated.Remotes.Tutorial.Communication

-- Others
local BuildingAssets = workspace.Buildings
local RequiredDistanceFromDoor = 37.5 -- Should not go lower, because player's can walk away while the fade is playing and end up not teleporting

local function Teleport(Object, Door, Character)
	local Player = Character and Players:GetPlayerFromCharacter(Character)
	
	if not Object.Value then
		return
	end
	
	-- Ensuring locked doors stay locked
	local TeleportType = Door.Parent
	
	if TeleportType then
		local TeleportBuildingRoot = TeleportType.Parent
		
		if TeleportBuildingRoot then
			local Locked = TeleportBuildingRoot:FindFirstChild('Locked')
			local Owner = TeleportBuildingRoot:FindFirstChild('Owner')
			
			if (Locked and Locked.Value == true and TeleportType.Name == 'Exterior') and (not Owner or Owner.Value ~= Player.Name) then
				return
			end
		end
	end
	
	-- Main teleportation sequence
	local NewLocation = Object.Value
	
	if (Character:FindFirstChild('Humanoid') and Character.Humanoid.Health > 0) then
		local Player = Players:GetPlayerFromCharacter(Character)
		local CharacterRoot = Character.HumanoidRootPart
					
		if (CharacterRoot and (CharacterRoot.Position - Door.Position).Magnitude <= RequiredDistanceFromDoor) and Player and Settings:SetDebounce(Player, 'TeleportPlayer', 2) then
			local _, CharacterSize = Character:GetBoundingBox()
			local ObjectAngle = NewLocation.CFrame:toEulerAnglesXYZ()

			local TeleportTo = CFrame.new(Vector3.new(NewLocation.Position.X, NewLocation.Position.Y + (CharacterSize.Y / 2) + (NewLocation.Size.Y / 2), NewLocation.Position.Z, Vector3.new(ObjectAngle)))
			Character.PrimaryPart.CFrame = TeleportTo
		end
	end
end

TouchedRemote.OnServerInvoke = function(Player, Door)
	local Object = Door:FindFirstChild('Teleportation')

	if Object then
		Teleport(Object, Door, Player.Character)
	end
end

-- Set all buildings with teleport things
for _, Buliding in pairs(BuildingAssets:GetChildren()) do
	local Interior, Exterior = Buliding:FindFirstChild('Interior'), Buliding:FindFirstChild('Exterior')

	if Interior and Exterior then
		local InteriorComponents = {
			Door = Interior:FindFirstChild('Door'),
			Pad = Interior:FindFirstChild('Pad'),
		}

		local ExteriorComponents = {
			Door = Exterior:FindFirstChild('Door'),
			Pad = Exterior:FindFirstChild('Pad'),
		}

		if InteriorComponents.Door and InteriorComponents.Pad and ExteriorComponents.Door and ExteriorComponents.Pad then
			-- Set them to teleport to one another
			local InteriorTeleportation = Settings:Create('ObjectValue', 'Teleportation', InteriorComponents.Door)
			InteriorTeleportation.Value = ExteriorComponents.Pad

			local ExteriorTeleportation = Settings:Create('ObjectValue', 'Teleportation', ExteriorComponents.Door)
			ExteriorTeleportation.Value = InteriorComponents.Pad
		end
	end
end
