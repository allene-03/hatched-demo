local Replicated = game:GetService('ReplicatedStorage')
local ServerScriptService = game:GetService('ServerScriptService')

local Settings = require(Replicated.Modules.Utility.Settings)
local Pathfinder = require(ServerScriptService.Modules.Pet.Pathfinder)

local Carrying = Replicated.Remotes.Pets.Carrying
local CarryModule = {}

local function GetRelativeScale(Biggest, Actual)
	return (Actual.X + Actual.Y + Actual.Z) / (Biggest.X + Biggest.Y + Biggest.Z)
end

function CarryModule:Carry(Player, Pet, PetInfo)
	local RootPart = Pet:FindFirstChild('RootPart')
	local Torso = Player.Character and Player.Character:FindFirstChild('UpperTorso')
	
	if RootPart and Torso then
		CarryModule:Drop(Player) -- Drop it before you can pick up another
		
		local Configurations = require(PetInfo.Configuration)
		local Model = PetInfo.Models.Main
		
		local _, Biggest = Model:GetBoundingBox()
		local _, Actual = Pet:GetBoundingBox()
		
		local CarryOffset = (Configurations.CarryOffset or Vector3.new(0, 0, 0)) * (GetRelativeScale(Biggest, Actual))	
		RootPart.CFrame = (Torso.CFrame * CFrame.new(0, -1.5, -1.5) * CFrame.Angles(0, math.rad(90), 0)) + CarryOffset
		
		local Weld = Settings:Create('WeldConstraint', '_CarryConstraint')
		Weld.Part0, Weld.Part1 = Torso, RootPart -- Don't change order, it's used in :Drop to allocate the pet
		Weld.Parent = Torso
		
		-- Disable PFing temporarily
		Pathfinder:Disable(Player, Pet, 'CarryingPet')
		
		-- Inform them of this now
		Carrying:FireAllClients('Carry', {Pet = Pet, Information = PetInfo, Id = Player.UserId})
	end
end

function CarryModule:Drop(Player)
	local Torso = Player.Character and Player.Character:FindFirstChild('UpperTorso')
	local PetModel = nil
	
	if Torso then
		local Weld = Torso:FindFirstChild('_CarryConstraint')
		
		if Weld then
			PetModel = Weld.Part1 and Weld.Part1:FindFirstAncestorWhichIsA('Model')
			Weld:Destroy()
		end
	end
	
	-- Notify the player
	Carrying:FireAllClients('Drop', {Pet = PetModel, Id = Player.UserId})
	
	-- Enable PFing
	Pathfinder:Enable(Player, PetModel, 'CarryingPet')
end

return CarryModule