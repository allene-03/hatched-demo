-- Refer to documentation for settings and brief explanation

local Replicated = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local Players = game:GetService('Players')

local LocalPlayer = Players.LocalPlayer

local Serverfinding = Replicated:WaitForChild('Remotes'):WaitForChild('Pets'):WaitForChild('Pathfinding')
local Clientfinding = Replicated:WaitForChild('Remotes'):WaitForChild('Pets'):WaitForChild('Clientfinding')

-- For the PetAction menu
local ClientMovement = Replicated:WaitForChild('Remotes'):WaitForChild('Other'):WaitForChild('GetPetState')

local ClientPetWrapper = require(Replicated:WaitForChild('Modules'):WaitForChild('Pet'):WaitForChild('Pathfinding'):WaitForChild('Client'))
local NonclientPetWrapper = require(Replicated:WaitForChild('Modules'):WaitForChild('Pet'):WaitForChild('Pathfinding'):WaitForChild('Nonclient'))

local Settings = require(Replicated:WaitForChild('Modules'):WaitForChild('Utility'):WaitForChild('Settings'))

-- Variables
local ClientPet
local NonclientPets = {}

-- Connections
local Connections = {}

--- Functions
local function Disconnect(Connections)
	for _, Connection in pairs(Connections) do
		Connection:Disconnect()
	end
	
	return {}
end

-- Store events to notify other clients
local function Hook()
	Connections = Disconnect(Connections)

	if ClientPet then	
		-- Send the initial client movement bindable for interact
		ClientMovement:Fire(ClientPet.Model, ClientPet.State)

		-- Set up the events
		table.insert(Connections, ClientPet.StateChanged:Connect(function()
			local Data = {Pet = ClientPet.Model, State = ClientPet.State, Jump = false}
			
			Serverfinding:FireServer(Data)
			ClientMovement:Fire(Data.Pet, Data.State)
		end))
		
		table.insert(Connections, ClientPet.Jumped:Connect(function()
			local Data = {Pet = ClientPet.Model, State = ClientPet.State, Jump = true}
			Serverfinding:FireServer(Data)
		end))
	end
end

local function OnUpdate(Mode, Data)
	if Mode == 'Add' then
		if not Data.Pet then
			return
		end
		
		if Data.Id == LocalPlayer.UserId then
			if ClientPet then
				ClientPet:Unbind()
			end
			
			-- Start it off in the right position
			local Location; ClientPet = ClientPetWrapper.new(Data.Pet, Data.Information)
			
			repeat
				Location = ClientPet.GetDesiredLocation()
				task.wait()
			until (Location)
			
			-- Make sure the client pet hasn't been switched while it was getting location
			if (not ClientPet or ClientPet.Model ~= Data.Pet) then
				return
			end
			
			ClientPet:Update('Teleporting', Location, false)
			Hook()
		else
			if NonclientPets[Data.Id] then
				NonclientPets[Data.Id]:Unbind()
			end
			
			NonclientPets[Data.Id] = NonclientPetWrapper.new(Data.Pet, Data.Information)
		end
	elseif Mode == 'Remove' then
		if Data.Id == LocalPlayer.UserId then
			if ClientPet then
				ClientPet:Unbind()
			end
			
			ClientPet = nil
			Hook()
		else
			if NonclientPets[Data.Id] then
				NonclientPets[Data.Id]:Unbind()
			end
			
			NonclientPets[Data.Id] = nil
		end
	elseif Mode == 'Edit' then
		if Data.Pet and Data.Id == LocalPlayer.UserId then
			ClientPet:Edit(Data.Pet)
		end
	elseif Mode == 'Update' then
		if not Data then
			return
		end
		
		if Data.Id ~= LocalPlayer.UserId then
			if not NonclientPets[Data.Id] then
				OnUpdate('Add', Data)
			end

			NonclientPets[Data.Id]:Update(Data.State, Data.JumpValue)
		end
	end
end

local function OnClientUpdate(Mode, Data)
	if not ClientPet or ClientPet.Model ~= Data.Pet then
		return
	end
	
	if Mode == 'Size' then
		ClientPet:Edit(Data.Pet)
	elseif Mode == 'Position' then
		ClientPet:Update('Teleporting', Vector3.new(Data.Location.X, Data.Location.Y + 1, Data.Location.Z), false)
	end
end

-- Main loop that handles the pet movement
RunService.Heartbeat:Connect(function()
	if ClientPet then
		ClientPet:UpdateVisualisation()
	end
end)

Serverfinding.OnClientEvent:Connect(OnUpdate)
Clientfinding.Event:Connect(OnClientUpdate)