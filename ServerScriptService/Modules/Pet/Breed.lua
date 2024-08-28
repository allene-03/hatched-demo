-- Breeding algorithm

-- Services
local Replicated = game:GetService('ReplicatedStorage')
local Storage = game:GetService('ServerStorage')

local PetBreedModule = {
	Purebreed = (1 / 10), -- Chance of getting your parent's skintone
	Puresize = (1 / 8), -- Chance of getting your parent's size
	
	-- Out of 100, If an epic has a 30 % base chance, a legendary would have a (30 - ChanceDecreaseBetweenRarities) base
	ChanceDecreaseBetweenRarities = 15, 
	
	-- Out of 100, Since legendary has the lowest chance, when you bred a legend with an epic, 
	-- you would have MinimumBaseRarityChance (this of course changes when you breed a legendary with a lower rank)
	MinimumBaseRarityChance = 20,
	
	-- Out of 1, The decrease in chances of getting other pet based on difference between rarities
	-- legendary bred with epic yields MinimumBaseRarityChance of getting, legendary bred with ultra-rare
	-- would yield (MinimumBaseRarityChance * (RarityOffsetChancePercentageDrop)), and legendary bred with
	-- rare would yield (MinimumBaseRarityChance * (RarityOffsetChancePercentageDrop ^ 2))
	RarityOffsetChancePercentageDrop = (1 / 2),
	
	-- Out of 100, This is the chance of getting the other player's pet assuming the rarities are equivalent
	ChanceOfNewSpeciesWithSameRarity = 45,
	
	-- The chance to receive a complimentary color instead of the actual color
	ChanceOfColorMutating = (1 / 8),
	
	-- This is how frequently you want recessed shades to show up to be chosen after they've
	-- already been picked
	ChanceOfGettingSameRareShade = (1 / 3), -- Consider decreasing this to (1/2)?
	
	-- This is how frequently you would acquire a duplicated instance - quadruplets, triplets, and twins
	DuplicationOptions = {
		Quadruplets = {
			Chance = (1 / 300),
			Multiplier = 4
		},
		
		Triplets = {
			Chance = (1 / 200),
			Multiplier = 3
		},
		
		Twins = {
			Chance = (1 / 100),
			Multiplier = 2
		},
	},
	
	-- This is the distribution in chance between a fraternal and identical duplication
	DuplicationTypes = {
		Fraternal = (2 / 3),
		Identical = (1 / 3)
	},
	
	-- This is what's added to the min and the max so +/- PotentialVariabilty is added to both ends of
	-- the potential spectrum
	PotentialVariability = 2,
	
	-- Standard bounds represent the actual range that's going to be outputted, 0 - 100. Adjusted
	-- bounds represents the values within that range of the standard bounds. For instance, if
	-- the standard range is {Start = 0, End = 10} and adjusted range is {Start = 0, End = 80}
	-- then I would get something like {8, 16, 24, 32, 40, 48, 56, 64, 72, 80} essentially clamping
	-- the range of 0 - 80 (adjusted) in the bounds of 0 - 10 (standard)
	PotentialDistributionBounds = {
		{
			Standard = {Start = 0, End = 20},
			Adjusted = {Start = 0, End = 27.5}
		},
		
		{
			Standard = {Start = 20, End = 80},
			Adjusted = {Start = 27.5, End = 72.5}
		},
		
		{
			Standard = {Start = 80, End = 100},
			Adjusted = {Start = 72.5, End = 100}
		},
	},
	
	ShadingDistributionBounds = {
		-- 15% chance of getting a color lerped between 0 and 0.325
		{
			Standard = {Start = 0, End = 15},
			Adjusted = {Start = 0, End = 32.5}
		},
		-- 70% chance of getting a color lerped between 0.325 and 0.675
		{
			Standard = {Start = 15, End = 85},
			Adjusted = {Start = 32.5, End = 67.5}
		},
		-- 15% chance of getting a color lerped between 0.675 and 1 (which would be the other player's pet)
		{
			Standard = {Start = 85, End = 100},
			Adjusted = {Start = 67.5, End = 100}
		},
	},
}

-- Repositories
local Settings = require(Replicated.Modules.Utility.Settings)
local Core = require(script.Parent.Core)

-- Templates
local PetTemplate = Core['Template']()
local RarityTemplate = Replicated.Assets.Rarity
local PotentialTemplate = PetTemplate.Data.Potential

-- Variables
local Randomize = Random.new()
local MaximumRank

-- Functions
local function FormatPets(Profiles)
	local FormattedPet = {}

	for _, Profile in pairs(Profiles) do
		table.insert(FormattedPet, {
			Pet = Profile.Pet,
			Player = Profile.Player,
			Reference = Profile.Pet.Reference,
			Equipped = Profile.Equipped,
			Type = ''
		})
	end

	return FormattedPet
end

local function GetPetFromPlayer(Pets, Player)
	for _, Pet in pairs(Pets) do
		if Pet.Player == Player then
			print('Found pet')
			return Pet
		end
	end
end

local function FetchMaximumRank(Maximum)
	Maximum = -1

	for _, Rarity in pairs(RarityTemplate:GetChildren()) do
		Maximum = Rarity.Rank.Value > Maximum and Rarity.Rank.Value or Maximum
	end

	return Maximum
end

local function GetMax(Table, ExcludingKeys)
	ExcludingKeys = ExcludingKeys or {}
	local MaxIndex, Max

	for Index, Value in pairs(Table) do
		if Settings:Index(ExcludingKeys, Index) then
			continue
		end
		
		if Max then
			if Value > Max then
				Max = Value; MaxIndex = Index;
			end
		else
			Max = Value; MaxIndex = Index;
		end
	end

	return MaxIndex, Max
end

local function GetMin(Table, ExcludingKeys)
	ExcludingKeys = ExcludingKeys or {}
	local MinIndex, Min

	for Index, Value in pairs(Table) do
		if Settings:Index(ExcludingKeys, Index) then
			continue
		end
		
		if Min then
			if Value < Min then
				Min = Value; MinIndex = Index;
			end
		else
			Min = Value; MinIndex = Index;
		end
	end

	return MinIndex, Min
end

local function GetRelationship(Pets)
	local Relationship = {}
	
	for _, Pet in pairs(Pets) do
		Relationship.Dominant = Relationship.Dominant or (Pet.Type == 'Dominant' and Pet)
		Relationship.Recessive = Relationship.Recessive or (Pet.Type == 'Recessive' and Pet)
	end
	
	return Relationship
end

local function ConvertRarityToNumber(Pets)
	local ConvertedRarities = {}
	
	for Pet, Rarity in pairs(Pets) do
		for _, RarityType in pairs(RarityTemplate:GetChildren()) do
			if RarityType.Name == Rarity then
				ConvertedRarities[Pet] = RarityType.Rank.Value
			end
		end
	end
	
	return ConvertedRarities
end

local function GetComplimentaryColor(Color)
	local H, S, V = Color:ToHSV()
	H = (H + 0.5) % 1
	
	return Color3.fromHSV(H, S, V)
end

local function CollectAttributes(Objects, Attribute, Ordered)
	if not Attribute then
		return
	elseif type(Attribute) ~= 'table' then
		Attribute = {Attribute}
	end

	local Attributes = {}

	for _, Object in pairs(Objects) do
		local ObjectReference = Object.Reference

		if ObjectReference then
			local ObjectAttribute
			
			for _, AttributeDescent in pairs(Attribute) do
				if ObjectAttribute then
					ObjectAttribute = ObjectAttribute[AttributeDescent]
				else
					ObjectAttribute = ObjectReference[AttributeDescent]
				end
			end

			if ObjectAttribute then
				if Ordered then
					Attributes[Object] = ObjectAttribute
				else
					table.insert(Attributes, ObjectAttribute)
				end
			end
		end
	end

	return Attributes
end

-- Refer to potentialDistributionBounds in properties above
local function Distribution(Bounds)
	if Bounds[#Bounds]['Adjusted']['End'] ~= 100 or Bounds[#Bounds]['Standard']['End'] ~= 100 then
		warn('Both standard and adjusted bounds should end at 100.')
	end

	if Bounds[1]['Adjusted']['Start'] ~= 0 or Bounds[1]['Standard']['Start'] ~= 0 then
		warn('Both standard and adjusted bounds should start at 0.')
	end

	for Index, Bound in pairs(Bounds) do
		local NextBound = Bounds[Index + 1]

		if NextBound then
			if NextBound['Standard']['Start'] ~= Bound['Standard']['End'] then
				warn('Standard bound starts and ends should be equivalent.')
			end

			if NextBound['Adjusted']['Start'] ~= Bound['Adjusted']['End'] then
				warn('Adjusted bound starts and ends should be equivalent.')
			end
		end
	end

	local Distributed = {}

	for _, Bound in pairs(Bounds) do
		local AdjustedStartBound, AdjustedEndBound = Bound.Adjusted.Start, Bound.Adjusted.End

		for Iterate = Bound.Standard.Start + 1, Bound.Standard.End do
			local Adjusted = (AdjustedEndBound - AdjustedStartBound) * ((Iterate - Bound.Standard.Start) / (Bound.Standard.End - Bound.Standard.Start)) + AdjustedStartBound
			table.insert(Distributed, Adjusted)
		end
	end

	return Distributed
end

-- Breeding specific functions
local function SelectSpecies(Pets, Player)
	local CollectedRarity = CollectAttributes(Pets, 'Rarity', true)
	local ConvertedRarity = ConvertRarityToNumber(CollectedRarity)
	
	local RarerPet, ConvertedRarerPetRarity = GetMax(ConvertedRarity) -- This entire function is all done relative to this 'rarer' pet
	local LessRarerPet, ConvertedLessRarerPetRarity = GetMin(ConvertedRarity, {RarerPet})
	
	local BaseChanceOfGettingSpecies = ((MaximumRank - ConvertedRarerPetRarity) * PetBreedModule.ChanceDecreaseBetweenRarities) + PetBreedModule.MinimumBaseRarityChance
	local IsTheSameRarity = (ConvertedLessRarerPetRarity == ConvertedRarerPetRarity)
	
	local ChanceOfReceivingRarerSpecies 
		
	if IsTheSameRarity then
		-- If they are both your pets then same chance of getting them
		if (RarerPet.Player == LessRarerPet.Player) and (RarerPet.Player == Player) then
			ChanceOfReceivingRarerSpecies = 50
		-- If the rarer one is yours, then you have a 100 - ChanceOfNew, ie. if ChanceOfNew was 30, you'd have 70
		elseif RarerPet.Player == Player then
			ChanceOfReceivingRarerSpecies = (100 - PetBreedModule.ChanceOfNewSpeciesWithSameRarity)
		-- If the rarer one is the players, then you have a ChanceOfNew, ie. if ChanceOfNew was 30, you'd have 30
		elseif LessRarerPet.Player == Player then
			ChanceOfReceivingRarerSpecies = PetBreedModule.ChanceOfNewSpeciesWithSameRarity
		else
		-- If none of these apply, then same chance of getting either
			ChanceOfReceivingRarerSpecies = 50
		end
	else
		-- Get player to reference their equipped pet (session type does not matter)
		local PlayerPet = GetPetFromPlayer(Pets, Player)
		ChanceOfReceivingRarerSpecies = BaseChanceOfGettingSpecies * ((PetBreedModule.RarityOffsetChancePercentageDrop) ^ (ConvertedRarerPetRarity - ConvertedLessRarerPetRarity - 1))
		
		if PlayerPet and PlayerPet.Equipped then
			-- With max stat, you get 15% off final price
			local Golden = (PlayerPet.Equipped.Data.Potential.Golden or 0)
			ChanceOfReceivingRarerSpecies += ((Golden / 100) * (0.15 * ChanceOfReceivingRarerSpecies))
		end
	end
		
	-- The reason it's multiplied/divided here is to make it possible for decimals (up to the thousandth)
	local RandomizedChance = Randomize:NextInteger(1 * 1000, 100 * 1000) / 1000
	
	-- The chances you got the rarer species
	local GotRarerSpecies = (RandomizedChance >= (100 - ChanceOfReceivingRarerSpecies))
	
	-- Set the 'dominant' / 'recessive' to the pets now for future use
	if GotRarerSpecies then
		RarerPet.Type = 'Dominant'; LessRarerPet.Type = 'Recessive';
		return RarerPet.Reference.Species, RarerPet.Reference.Rarity
	else
		RarerPet.Type = 'Recessive'; LessRarerPet.Type = 'Dominant';
		return LessRarerPet.Reference.Species, LessRarerPet.Reference.Rarity
	end
end

local function SelectPotential(Pets, Player, IsSoloSession)
	local FetchDistribution = Distribution(PetBreedModule.PotentialDistributionBounds)
	local Potential = {}
	
	-- Get player to reference their equipped pet (session type does not matter)
	local PlayerPet = GetPetFromPlayer(Pets, Player)
	local Chemistry
	
	if PlayerPet and PlayerPet.Equipped then
		if IsSoloSession then
			Chemistry = PlayerPet.Equipped.Data.Potential['Self-Chemistry'] or 0
		else
			Chemistry = PlayerPet.Equipped.Data.Potential['Multi-Chemistry'] or 0
		end
	else
		Chemistry = 0
	end
	
	-- With max stat, you get +1 variability
	Chemistry = Chemistry / 100
	
	-- Start the process
	for Attribute, _ in pairs(PotentialTemplate) do
		local CollectedPotentialAttribute = CollectAttributes(Pets, {'Potential', Attribute})
		local MinimumPotentialAttribute, MaximumPotentialAttribute = Settings:Min(CollectedPotentialAttribute), Settings:Max(CollectedPotentialAttribute)

		-- Add some variability
		local MinimumCap, MaximumCap = 0, Core.MaxPotential

		if not ((MinimumPotentialAttribute == MaximumPotentialAttribute) and (MinimumPotentialAttribute <= MinimumCap or MaximumPotentialAttribute >= MaximumCap)) then
			MinimumPotentialAttribute = math.clamp(MinimumPotentialAttribute + Randomize:NextInteger(-PetBreedModule.PotentialVariability, PetBreedModule.PotentialVariability) + Chemistry, MinimumCap, MaximumCap)
			MaximumPotentialAttribute = math.clamp(MaximumPotentialAttribute + Randomize:NextInteger(-PetBreedModule.PotentialVariability, PetBreedModule.PotentialVariability) + Chemistry, MinimumCap, MaximumCap)
		end

		-- Now actually choose the addition
		local ChosenDistributionAmount = FetchDistribution[Randomize:NextInteger(1, #FetchDistribution)]
		Potential[Attribute] = math.round((ChosenDistributionAmount * (1 / 100) * (MaximumPotentialAttribute - MinimumPotentialAttribute)) + MinimumPotentialAttribute)
	end

	return Potential
end

local function SelectSize(Pets)
	local CollectedSize = CollectAttributes(Pets, 'Size', false)
	local RandomizedChance = Randomize:NextInteger(1 * 1000, 100 * 1000) / 1000
	
	if RandomizedChance >= (100 - (PetBreedModule.Puresize * 100)) then
		return CollectedSize[Randomize:NextInteger(1, #CollectedSize)]
	else
		local MaximumSize, MinimumSize = Settings:Max(CollectedSize), Settings:Min(CollectedSize)
		return math.round(((MaximumSize - MinimumSize) * (Randomize:NextInteger(1, 100) / 100)) + MinimumSize)
	end
end

local function SelectShading(Pets)
	local Relationship = GetRelationship(Pets)
	local ChosenShading = {}

	if Relationship.Dominant and Relationship.Recessive then
		local FetchDistribution = Distribution(PetBreedModule.ShadingDistributionBounds)
		local DominantShading, RecessiveShading = Relationship.Dominant.Reference.Shading, Relationship.Recessive.Reference.Shading
		local ShadesInteractedWith = {}

		for _, DominantShadeTable in pairs(DominantShading) do
			local PossibleShading = {}
			
			-- For each dominant shade, it will create a pair of possible combos
			-- with recessive shades and choose one randomly at the end
			for _, RecessiveShadeTable in pairs(RecessiveShading) do
				local RandomizedChance = Randomize:NextInteger(1 * 1000, 100 * 1000) / 1000
				local NewPossibleShade
				
				if RandomizedChance >= (100 - (PetBreedModule.Purebreed * 100)) then
					local PurebreedOptions = {DominantShadeTable.New, RecessiveShadeTable.New}
					NewPossibleShade = PurebreedOptions[Randomize:NextInteger(1, #PurebreedOptions)]
				else
					local ChosenDistributionAmount = FetchDistribution[Randomize:NextInteger(1, #FetchDistribution)]
					local PossibleShade = Settings:ToColor(RecessiveShadeTable.New):Lerp(Settings:ToColor(DominantShadeTable.New), ChosenDistributionAmount * (1 / 100))
					NewPossibleShade = Settings:FromColor(PossibleShade)	
				end
				
				local NewPossibleShadeTable = {Color = {Old = DominantShadeTable.Old, New = NewPossibleShade}, Reference = Settings:ToColor(RecessiveShadeTable.New)}
				
				-- If the color has already been interacted with in another iteration then lower chances of
				-- getting it again in the future
				if Settings:IndexColor(ShadesInteractedWith, NewPossibleShadeTable.Reference) then
					table.insert(PossibleShading, NewPossibleShadeTable)
				else
					for Index = 1, (1 / (PetBreedModule.ChanceOfGettingSameRareShade)) do
						table.insert(PossibleShading, NewPossibleShadeTable)
					end
				end
			end
			
			-- If you've already got that shade make it less likely to get that shade again
			local ChosenShade = PossibleShading[Randomize:NextInteger(1, #PossibleShading)]
			
			table.insert(ShadesInteractedWith, ChosenShade.Reference)
			table.insert(ChosenShading, ChosenShade.Color)
		end
		
		-- To make sure it only occurs one time per breed this is done at the end, the 
		-- purpose of this is to introduce a chance of getting a 'complimentary' color shade
		local RandomizedMutationChance = Randomize:NextInteger(1 * 1000, 100 * 1000) / 1000

		if RandomizedMutationChance >= (100 - (PetBreedModule.ChanceOfColorMutating * 100)) then
			local IndexToMutate = Randomize:NextInteger(1, #ChosenShading)
			local ColorToMutate = Settings:ToColor(ChosenShading[IndexToMutate]['New'])
			ChosenShading[IndexToMutate]['New'] = Settings:FromColor(GetComplimentaryColor(ColorToMutate))
		end
	else
		warn('Did not find dominant/recessive pet, please allocate these pets.')
	end
	
	return ChosenShading
end

local function UpdateGeneration(Pets, Player, IsSoloSession)
	-- If the player is solo, then it's their highest, else it's their current pet generation + 1
	if IsSoloSession then
		local _, MaxGeneration = GetMax(CollectAttributes(Pets, 'Generation', false))
		return MaxGeneration and MaxGeneration + 1 or PetTemplate.Reference.Generation
	else
		for _, Pet in pairs(Pets) do
			if Pet.Player == Player then
				local Generation = Pet.Reference.Generation
				return Generation and Generation + 1 or PetTemplate.Reference.Generation
			end
		end
	end
	
	-- If all fails then they get the default generation in pet template
	return PetTemplate.Reference.Generation
end

local function UpdateBreedability(Pets)
	local CollectedNonbreedability = CollectAttributes(Pets, 'Nonbreedable', false) or {}
	local NonbreedableWithOthers, NonbreedableWithAll
	
	for _, BreedableStatus in pairs(CollectedNonbreedability) do
		if BreedableStatus == 'All' then
			NonbreedableWithAll = true
			break
		elseif BreedableStatus == 'Others' then
			NonbreedableWithOthers = true
			break
		end
	end
	
	return (NonbreedableWithAll and 'All') or (NonbreedableWithOthers and 'Others')
end

-- Primary functions
local function Fuse(Pets, Player, IsSoloSession)
	local Attributes = {}
	Attributes.Gender = Core['Genders'][Randomize:NextInteger(1, #Core['Genders'])]
	
	-- This needs to go before everything else (setting species and rarities) because it also establishes
	-- dominance type for the next couple of actions
	Attributes.Species, Attributes.Rarity = SelectSpecies(Pets, Player)
	Attributes.Potential = SelectPotential(Pets, Player, IsSoloSession)
	Attributes.Shading = SelectShading(Pets)
	Attributes.Size = SelectSize(Pets)
	Attributes.Egg = GetRelationship(Pets)['Dominant']['Reference']['Egg']
	
	Attributes.Nonbreedable = UpdateBreedability(Pets)
	Attributes.Generation = UpdateGeneration(Pets, Player, IsSoloSession)
	Attributes.Bred = true
	
	return Attributes
end

local function Process(Profiles, Player, IsSoloSession)
	local Pets = FormatPets(Profiles)
	local PlayerPet = GetPetFromPlayer(Pets, Player) -- Get player to reference their equipped pet (session type does not matter)

	local ChanceOfQuadruplets, ChanceOfTriplets, ChanceOfTwins = PetBreedModule.DuplicationOptions.Quadruplets.Chance, PetBreedModule.DuplicationOptions.Triplets.Chance, PetBreedModule.DuplicationOptions.Twins.Chance
	local MultiplicationFactor = 1
	
	local DuplicationType
	
	if PlayerPet and PlayerPet.Equipped then
		-- With max stat, you get a 3X chance of these duplications
		local Bountiful = (PlayerPet.Equipped.Data.Potential.Bountiful or 0)
		
		ChanceOfQuadruplets += ((Bountiful / 100) * (3 * ChanceOfQuadruplets))
		ChanceOfTriplets += ((Bountiful / 100) * (3 * ChanceOfTriplets))
		ChanceOfTwins += ((Bountiful / 100) * (3 * ChanceOfTwins))
	end
	
	-- Generate the random chance
	local RandomizedChance = Randomize:NextInteger(1 * 1000, 100 * 1000) / 1000

	-- Chances of getting twins to quadruplets
	if (RandomizedChance >= (100 - (ChanceOfQuadruplets * 100))) then
		MultiplicationFactor = PetBreedModule.DuplicationOptions.Quadruplets.Multiplier
	elseif (RandomizedChance >= (100 - ((ChanceOfQuadruplets * 100) + (ChanceOfTriplets * 100)))) then
		MultiplicationFactor = PetBreedModule.DuplicationOptions.Triplets.Multiplier
	elseif (RandomizedChance >= (100 - ((ChanceOfQuadruplets * 100) + (ChanceOfTriplets * 100) + (ChanceOfTwins * 100)))) then
		MultiplicationFactor = PetBreedModule.DuplicationOptions.Twins.Multiplier
	end
	
	local BredPets = {}
	
	-- Chances of getting fraternal versus identical twins
	if MultiplicationFactor > 1 then
		RandomizedChance = Randomize:NextInteger(1 * 1000, 100 * 1000) / 1000
		
		if (RandomizedChance >= (100 - (PetBreedModule.DuplicationTypes.Identical * 100))) then
			local FusedPet = Fuse(Pets, Player, IsSoloSession)
			DuplicationType = 'Identical'
			
			for Index = 1, MultiplicationFactor do
				table.insert(BredPets, Settings:DeepCopy(FusedPet))
			end
		else
			DuplicationType = 'Non-identical'
			
			for Index =  1, MultiplicationFactor do
				table.insert(BredPets, Fuse(Pets, Player, IsSoloSession))
			end
		end
	else
		table.insert(BredPets, Fuse(Pets, Player, IsSoloSession))
	end
	
	return BredPets, DuplicationType
end

-- Module functions
function PetBreedModule:GetBreedPrice(InformationSet)
	local Count, Price, Economic = 0, 0, 0
	
	for _, Information in pairs(InformationSet) do
		local Pet, Equipped = Information.Pet, Information.Equipped
		
		if Pet then
			local Rarity = RarityTemplate:FindFirstChild(Pet.Reference.Rarity)
			
			if Rarity then
				Price += (Rarity.Price.Value) + (3 * Core:GetOverall(Pet.Reference.Potential))
				Economic += Equipped and Equipped.Data.Potential.Economic or 0
				Count += 1
			end
		end
	end
	
	-- With both players at max stats, you get 15% off final price
	local ScaledPrice = math.round(Price - ((Economic / (Count * 100)) * (0.15 * Price)))
	
	if Count >= 2 then
		return ScaledPrice
	end
end

function PetBreedModule:CheckRequirements(Pets, IsSoloPlayer)
	-- Whenever a requirement is added wrap all if statements with a 'return false' given a requirement is violated
	if #(Pets) ~= 2 then
		return false, 'You need at least two pets to proceed.'
	end
	
	-- Making sure nonbreedable trait is in rotation
	for _, Pet in pairs(Pets) do
		if Pet.Reference.Nonbreedable == 'All' then
			return false, 'One or more of these pets cannot be bred.'
		elseif Pet.Reference.Nonbreedable == 'Others' and not IsSoloPlayer then
			return false, "One or more of these pets cannot be bred with other players' pets."
		end
	end
	
	if Core.GenderSpecificEnabled then
		local Male, Female

		for _, Pet in pairs(Pets) do
			Male = (Pet.Reference.Gender == 'Male') and true or Male
			Female = (Pet.Reference.Gender == 'Female') and true or Female
		end

		if not (Male and Female) then
			return false, 'You need a male and female pet to proceed.'
		end
	end
	
	if Core.BreedableStageEnabled then
		for _, Pet in pairs(Pets) do
			local Stage = Pet.Data.Stage
			local StageData = Core['Stages'][Stage]

			if StageData then
				if StageData.Stage ~= Core.BreedableStage then
					return false, 'Both pets need to be at least ' .. Core.BreedableStage ..' before they can breed.'
				end
			else
				return false, 'Aging error. Please try again later.'
			end
		end
	end

	return true
end

function PetBreedModule:Form(InformationSet, IsSoloSession)
	-- Temporary folder to check pet requirements
	local ReferenceToPets = {}
	
	for _, Information in pairs(InformationSet) do
		table.insert(ReferenceToPets, Information.Pet)
	end
	
	local Success, Error = PetBreedModule:CheckRequirements(ReferenceToPets, IsSoloSession)

	if not Success then
		return Success, Error
	end
	
	local ReturnData = {}
	
	for _, Information in pairs(InformationSet) do
		local BredPets, DuplicationType = Process(InformationSet, Information.Player, IsSoloSession)
		local ProcessedPets = {}
		
		for _, BredPet in pairs(BredPets) do
			local ProcessedPet = Core:Create(BredPet.Species, BredPet)
			table.insert(ProcessedPets, ProcessedPet)
		end
		
		local PlayerReturnData = {Player = Information.Player, Data = Information.Data, Pets = ProcessedPets, DuplicationType = DuplicationType}
		table.insert(ReturnData, PlayerReturnData)
		
		if IsSoloSession then
			break
		end
	end
	
	return ReturnData
end

-- Main sequence
MaximumRank = FetchMaximumRank(MaximumRank)

return PetBreedModule