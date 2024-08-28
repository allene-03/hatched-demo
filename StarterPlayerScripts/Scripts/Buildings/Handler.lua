local Replicated = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')

local Remotes = Replicated:WaitForChild('Remotes'):WaitForChild('Buildings')
local Notify = Replicated:WaitForChild('Remotes'):WaitForChild('Systems'):WaitForChild('Notify')

local BuildingAdded = Remotes:WaitForChild('Added')
local BuildingTouched = Remotes:WaitForChild('Touched')

local FadeEffect = require(Replicated:WaitForChild('Modules'):WaitForChild('Fade'):WaitForChild('Core'))

local LocalPlayer = Players.LocalPlayer
local Teleporting = false

local function CheckIfDoorIsLocked(Door)
	local TeleportType = Door.Parent

	if TeleportType then
		local TeleportBuildingRoot = TeleportType.Parent

		if TeleportBuildingRoot then
			local Locked = TeleportBuildingRoot:FindFirstChild('Locked')
			local Owner = TeleportBuildingRoot:FindFirstChild('Owner')

			if (Locked and Locked.Value == true and TeleportType.Name == 'Exterior') and (not Owner or Owner.Value ~= LocalPlayer.Name) then
				return true
			end
		end
	end
end

local function HandleTouchedEvent(Door, Part)	
	if not Teleporting then	
		Teleporting = true
		
		-- Start the sequence
		local Character = LocalPlayer.Character
		
		if (Character and Part.Parent == Character) then
			if (Character:FindFirstChild('Humanoid') and Character.Humanoid.Health > 0) then
				if CheckIfDoorIsLocked(Door) then
					Notify:Fire("This player's home is locked.")
					task.wait(2)
				else
					local Callback = FadeEffect:StartTween()
					BuildingTouched:InvokeServer(Door)

					if Callback then
						task.wait(0.5)
						Callback()
					end
					
					task.wait(0.5)
				end
			end
		end
		
		-- Toggle the value back off
		Teleporting = false
	end
end

for _, Object in pairs(workspace:GetDescendants()) do
	if Object.Name == 'Teleportation' and Object.ClassName == 'ObjectValue' then
		local Door = Object.Parent

		Door.Touched:Connect(function(Part)
			HandleTouchedEvent(Door, Part)
		end)
	end
end

BuildingAdded.OnClientEvent:Connect(function(Door)
	local Object = Door:FindFirstChild('Teleportation')

	if Object then
		Door.Touched:Connect(function(Part)
			HandleTouchedEvent(Door, Part)
		end)
	end
end)