local Replicated = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local Players = game:GetService('Players')

local LocalPlayer = Players.LocalPlayer

local Utility = require(Replicated:WaitForChild('Modules'):WaitForChild('Vehicles'):WaitForChild('Utility'))
local Interact = require(Replicated:WaitForChild('Modules'):WaitForChild('Interface'):WaitForChild('Interact'):WaitForChild('Core'))
local Settings = require(Replicated:WaitForChild('Modules'):WaitForChild('Utility'):WaitForChild('Settings'))

local Handling = Replicated:WaitForChild('Remotes'):WaitForChild('Vehicles'):WaitForChild('Handling')
local Informing = Replicated:WaitForChild('Remotes'):WaitForChild('Vehicles'):WaitForChild('Informing')

local Controller = script:WaitForChild('Controller')
local Repository = workspace:WaitForChild('Vehicles')

local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

-- Variables
local MagnitudeOfDisplayingRearlightChanges = 150

-- References
local SettingUpConnections = {}
local AvailableSeats = {}

-- Longer-termed driving instances
local SpawnedVehicles = {}

-- References specifically to short-term driving instances
local ControllerObjects = {}
local DrivingEvent, LudicrousActive

-- Functions
local function ClearConnections(Vehicle)
	if not AvailableSeats[Vehicle] then
		return
	end
	
	for _, Connection in pairs(AvailableSeats[Vehicle]) do
		if typeof(Connection) == 'RBXScriptConnection' then
			print('Recycled seat change event.')
			Connection:Disconnect()
		else
			print('Recycled on click event.')
			Interact:Ignore(Connection)
		end
	end
end

local function Clean(ControllerObjects)
	if DrivingEvent then
		DrivingEvent:Disconnect()
	end
	
	for _, ControllerObject in pairs(ControllerObjects) do
		ControllerObject:Destroy()
	end
	
	LudicrousActive = nil
end

local function Control(Vehicle, Configuration)
	local Controllers, ControllerObjects = {}, {}
	
	if Vehicle:FindFirstChild('Mechs') then
		for MechIndex, MechModel in pairs(Vehicle.Mechs:GetChildren()) do
			local ControllerObject = Controller:Clone()
			local Controller = require(ControllerObject)
			
			Controller:SetConstraints(MechModel.Mech.Steer_Axl.HingeConstraint, MechModel.Mech.Drive_Axl.CylindricalConstraint)
			
			table.insert(ControllerObjects, ControllerObject)
			Controllers[MechIndex] = Controller
			
			Utility.FormatControl(Controllers[MechIndex], Configuration)
		end
	end
	
	return Controllers, ControllerObjects
end

local function Steer(Configuration, Controllers, Direction)
	for Index, Wheel in pairs(Configuration.Layout.FrontMechs) do
		local Mech = Controllers[Index]
		
		if not Mech then
			warn('Mech was not found, returning.')
		end
		
		Mech:SetSteerAngle(Configuration.SteerAngle * Direction)
		Mech:TurnWheel(Configuration.SteerSpeed)
	end
end

local function Drive(Configuration, Controllers, Direction)
	local DriveType = Configuration.Layout.DriveType
	local FrontMechs = Configuration.Layout.FrontMechs
	local RearMechs = Configuration.Layout.RearMechs
	
	local AppliedBoosts = (LudicrousActive and 1.55) or 1
	
	if DriveType == 'AWD' or DriveType == 'FWD' then
		Utility.ApplyWheelSpin(Direction, Configuration.VehicleSpeed * AppliedBoosts, FrontMechs, Controllers)
	end
	
	if DriveType == 'AWD' or DriveType == 'FWD' then
		Utility.ApplyWheelSpin(Direction, Configuration.VehicleSpeed * AppliedBoosts, RearMechs, Controllers)
	end
end

local function ChangeRearlightsColor(Car, ToNeon)
	if not Car:FindFirstChild('Body') or not Car.Body:FindFirstChild('Rearlights') then
		return
	end
	
	for _, Part in pairs(Car.Body.Rearlights:GetChildren()) do
		if ToNeon and Part.Material ~= Enum.Material.Neon then
			Part.Material = Enum.Material.Neon
		elseif Part.Material ~= Enum.Material.SmoothPlastic then
			Part.Material = Enum.Material.SmoothPlastic
		end
	end
end

local function SetupRearlights(Car)
	local Seat = Car:WaitForChild('Seat', 10)
	
	if Seat then
		Seat:GetPropertyChangedSignal('Throttle'):Connect(function()
			local Seat = Car:FindFirstChild('Seat')

			if (Seat and Seat.Occupant) and (Character and Character.PrimaryPart) and (Seat.Position - Character.PrimaryPart.Position).Magnitude <= MagnitudeOfDisplayingRearlightChanges then
				if Seat.Throttle < 0 then
					ChangeRearlightsColor(Car, true)
				else
					ChangeRearlightsColor(Car)
				end
			end
		end)
	end
end

local function CheckIfSeatAvailable(Connection, Vehicle, Seat)
	if not AvailableSeats[Vehicle] then
		return
	end
	
	local Occupant = Seat.Occupant

	if not Occupant then
		Interact:Resume(Connection, 'SeatOccupied')
	else
		Interact:Pause(Connection, 'SeatOccupied')
	end
end

local function SetupSeatInterface(Vehicle, Seat, Driving)
	local Connection = Interact:Listen(Seat, 'Click', Driving and 'Drive' or 'Sit', function()
		if Driving then
			Handling:FireServer('Driving', {Vehicle = Vehicle})
		else
			Handling:FireServer('Sitting', {Seat = Seat})
		end
	end)

	table.insert(AvailableSeats[Vehicle], Connection)
	
	-- Normally we would let the object just garbage collect when the instance is destroyed, but incase a new thread
	-- starts with different information when SetupSeating is called again, we need to recycle this
	table.insert(AvailableSeats[Vehicle], Seat:GetPropertyChangedSignal('Occupant'):Connect(function()
		CheckIfSeatAvailable(Connection, Vehicle, Seat)
	end))

	CheckIfSeatAvailable(Connection, Vehicle, Seat)
end

local function SetupSeating(Vehicle)
	-- Complete overkill but this (the whole repeat nonsense) is necessary to get the most up-to-date information
	-- on the seating, basically without that and the SettingUpConnections[Vehicle] debounce, the processes would
	-- race alongside and end up running simultaneously (both passengers and driver for the owner)
	local TimeStarted = tick()
	
	repeat
		task.wait()
	until (not SettingUpConnections[Vehicle]) or (not Vehicle.Parent) or (tick() - TimeStarted > 10)
	
	if not Vehicle.Parent or SettingUpConnections[Vehicle] then
		return
	end
	
	-- Checks if a connection setup is in lieu
	if not SettingUpConnections[Vehicle] then
		SettingUpConnections[Vehicle] = true
		
		-- If ran twice, we clear out the old connections
		ClearConnections(Vehicle)
		
		-- Passenger / driver relationship
		if SpawnedVehicles[Vehicle] then	
			local Seat = Vehicle:WaitForChild('Seat', 10)

			if Seat then
				AvailableSeats[Vehicle] = {}
				SetupSeatInterface(Vehicle, Seat, true)
			end
		else
			local Passengers = Vehicle:WaitForChild('Passengers', 10)
			
			if Passengers then
				AvailableSeats[Vehicle] = {}
				
				for _, Seat in pairs(Passengers:GetChildren()) do
					SetupSeatInterface(Vehicle, Seat)
				end
			end
		end
		
		SettingUpConnections[Vehicle] = nil
	end
end

-- Events
LocalPlayer.CharacterAdded:Connect(function(SpawnedCharacter)
	Character = SpawnedCharacter
end)

Handling.OnClientEvent:Connect(function(Mode, Arguments)	
	Arguments = Arguments or {}
	
	if Mode == 'Driving' then
		Clean(ControllerObjects)
				
		if Arguments.Configuration and Arguments.Vehicle then
			local Configuration, Vehicle = require(Arguments.Configuration), Arguments.Vehicle
			
			local Seat = Vehicle:WaitForChild('Seat')
			local Controllers; Controllers, ControllerObjects = Control(Vehicle, Configuration)
			
			DrivingEvent = RunService.Heartbeat:Connect(function()
				Steer(Configuration, Controllers, Seat.Steer)
				Drive(Configuration, Controllers, Seat.Throttle)
			end)
			
			Interact:AddAction('VehicleEquipped')
			Informing:Fire('Driving', {Active = true, Vehicle = Vehicle, Identifier = Arguments.Identifier})
		else
			Interact:RemoveAction('VehicleEquipped')
			Informing:Fire('Driving', {Active = false})
		end
	elseif Mode == 'Sitting' then
		if Arguments.Vehicle then
			Interact:AddAction('VehiclePassengerSitting')
		else
			Interact:RemoveAction('VehiclePassengerSitting')
		end
	elseif Mode == 'Ludicrous' then
		if Arguments.Action == 'Purchase' then
			Informing:Fire(Mode, Arguments) -- We pass it to the other place to handle firing prompt
		elseif Arguments.Action == 'Activate' then
			LudicrousActive = Arguments.Ludicrous
		end
	elseif Mode == 'Spawned' then
		if Arguments.Vehicle then
			SpawnedVehicles[Arguments.Vehicle] = true
			SetupSeating(Arguments.Vehicle) -- Set up the seating with you as driver AFTER we set SpawnedVehicles
		end
	elseif Mode == 'Despawned' then
		if Arguments.Vehicle then
			SpawnedVehicles[Arguments.Vehicle] = nil
		end
	end
end)

Repository.ChildAdded:Connect(function(Vehicle)
	SetupSeating(Vehicle)
	SetupRearlights(Vehicle)
end)

Repository.ChildRemoved:Connect(function(Vehicle)
	ClearConnections(Vehicle)
	AvailableSeats[Vehicle] = nil
end)

-- Main sequence
for _, Vehicle in pairs(Repository:GetChildren()) do
	SetupRearlights(Vehicle)
end