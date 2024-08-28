local TweenService = game:GetService('TweenService')
local Replicated = game:GetService('ReplicatedStorage')

local Settings = require(Replicated:WaitForChild('Modules'):WaitForChild('Utility'):WaitForChild('Settings'))
local Scaling = require(Replicated:WaitForChild('Modules'):WaitForChild('Utility'):WaitForChild('Scaling'))
local Interact = require(Replicated:WaitForChild('Modules'):WaitForChild('Interface'):WaitForChild('Interact'):WaitForChild('Core'))
local Lightning = require(Replicated:WaitForChild('Modules'):WaitForChild('Utility'):WaitForChild('Lightning'))

local PetsFolder = Replicated:WaitForChild('Assets'):WaitForChild('Pets')
local ParticlesFolder = Replicated:WaitForChild('Assets'):WaitForChild('Particles'):WaitForChild('Pet')
local CarryingRemote = Replicated:WaitForChild('Remotes'):WaitForChild('Pets'):WaitForChild('Carrying')

local Clientfinding = Replicated:WaitForChild('Remotes'):WaitForChild('Pets'):WaitForChild('Clientfinding')

local PetEffectsModule = {
	Repository = Settings:Create('Folder', 'PetsEffects', workspace),
	
	Effects = {
		Glow = {
			InTween = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			OutTween = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
			Default = Color3.fromRGB(254, 205, 19)
		},
		
		Lightning = {
			Default = Color3.fromRGB(254, 205, 19),
			Part = nil -- Will be set later
		}
	},
	
	-- If wrapping is true, then priority likely should be yield
	Types = {
		Leveling = {
			Sequence = {
				{Function = 'ParticleEffect', Parameters = {Particle = ParticlesFolder:WaitForChild('Leveling')}},
				{Function = 'GlowEffect'},
				{Function = 'ChangeProperties'}
			},
			
			Priority = 'Yield',
			Wrapping = true,
		},
		
		HighRankTransitioning = {
			Sequence = {
				{Function = 'LightningEffect'},
				{Function = 'GlowEffect'},
				{Function = 'Wait', Parameters = {Time = 1}},
			},

			Priority = 'Yield',
			Wrapping = true,
		},
		
		Transitioning = {
			Sequence = {
				{Function = 'GlowEffect'},
				{Function = 'Wait', Parameters = {Time = 0.5}},
			},

			Priority = 'Yield',
			Wrapping = true,
		},
		
		Breeding = {
			Sequence = {
				{Function = 'ParticleEffect', Parameters = {Particle = ParticlesFolder:WaitForChild('Breeding')}},
				{Function = 'Wait', Parameters = {Time = 1}},
			},
			
			Priority = 'Ignore',
			Wrapping = false,
		},
		
		Equipping = {
			Sequence = {
				{Function = 'ParticleEffect', Parameters = {Particle = ParticlesFolder:WaitForChild('Equipping')}},
				{Function = 'Wait', Parameters = {Time = 0.35}},
			},

			Priority = 'Ignore',
			Wrapping = false,
		},
	},
	
	HandlingPets = {
		-- Where you store the pets that VFXs are being done on
	}
}

-- Delta functions
function PetEffectsModule:ChangeProperties(Pet, Properties, Nonvisual)
	Properties = type(Properties) == 'table' and Properties or {}
	
	for Type, Value in pairs(Properties) do
		if Type == 'Size' then
			if Nonvisual then
				Scaling:Resize(Pet, Value)
			else
				-- You might have to go to Scaling module and increase the WaitTime some if the usage is too high
				Scaling:TweenSize(Pet, 1.5, Value, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			end
		end
	end
end

-- Effect functions
function ParticleEffect(RenderingPet, ParticlePart)
	local Particles = {}
	ParticlePart = ParticlePart:Clone()

	local PetCFrame, PetSize = RenderingPet:GetBoundingBox()
	local DominantAxis, ScaleFactor

	if PetSize.X > PetSize.Z then
		DominantAxis = PetSize.X
		ScaleFactor = DominantAxis / ParticlePart.Size.X
	else
		DominantAxis = PetSize.Z
		ScaleFactor = DominantAxis / ParticlePart.Size.Z
	end

	for _, Particle in pairs(ParticlePart:GetDescendants()) do
		if Particle.ClassName == 'ParticleEmitter' then
			local NumberSequenceKeypoints = {}

			for _, Keypoint in pairs(Particle.Size.Keypoints) do
				table.insert(NumberSequenceKeypoints, NumberSequenceKeypoint.new(Keypoint.Time, Keypoint.Value * ScaleFactor, Keypoint.Envelope * ScaleFactor))
			end

			Particle.Size = NumberSequence.new(NumberSequenceKeypoints)
			table.insert(Particles, Particle)
		end
	end

	ParticlePart.Size = Vector3.new(DominantAxis, ParticlePart.Size.Y, DominantAxis)
	ParticlePart.Position = Vector3.new(PetCFrame.Position.X, PetCFrame.Position.Y - (PetSize.Y / 2) + (ParticlePart.Size.Y) + 0.1, PetCFrame.Position.Z)

	-- Create weld so they move together
	local Weld = Instance.new('WeldConstraint')
	Weld.Part0 = RenderingPet.PrimaryPart
	Weld.Part1 = ParticlePart
	Weld.Parent = ParticlePart

	ParticlePart.CanCollide = false
	ParticlePart.Anchored = false

	-- Finally parent it and set up the callback function
	ParticlePart.Parent = RenderingPet.PrimaryPart

	return function()
		local Lifetimes = {}

		for _, Particle in pairs(Particles) do
			table.insert(Lifetimes, Particle.Lifetime.Max)
			Particle.Enabled = false
		end

		task.wait(Settings:Max(Lifetimes))
		ParticlePart:Destroy()
	end
end

function LightningEffect(RenderingPet, LightningBaseColor)
	local PetCFrame = RenderingPet:GetBoundingBox()
	LightningBaseColor = LightningBaseColor or PetEffectsModule.Effects.Lightning.Default
	
	local _StartPart, _EndPart = PetEffectsModule.Effects.Lightning.Part:Clone(), PetEffectsModule.Effects.Lightning.Part:Clone()
	local _StartPartAttachment, _EndPartAttachment = _StartPart.LightningAttachment, _EndPart.LightningAttachment
	_StartPart.CFrame, _EndPart.CFrame = PetCFrame + Vector3.new(0, 20, 0), PetCFrame
	_StartPart.Parent, _EndPart.Parent = workspace.Terrain, workspace.Terrain
	
	local LightningActive = true
	local Time = 0.5
	
	-- The main sequence handling the lightning
	task.spawn(function()
		while (LightningActive == true) do
			local Bolt = Lightning.new(_StartPartAttachment, _EndPartAttachment, 100)
			Bolt.AnimationSpeed = 1
			Bolt.Frequency = 1.5
			Bolt.Thickness = 0.75
			
			Bolt.PulseSpeed = 1
			Bolt.PulseLength = Time
			
			local Color_R = math.clamp((LightningBaseColor.R * 255) + math.random(-150, 150), 0, 255)
			local Color_G = math.clamp((LightningBaseColor.G * 255) + math.random(-150, 150), 0, 255)
			local Color_B = math.clamp((LightningBaseColor.B * 255) + math.random(-150, 150), 0, 255)
			
			Bolt.Color = Color3.fromRGB(Color_R, Color_G, Color_B)
			
			task.wait(0.1)
		end
	end)
	
	return function()
		LightningActive = false
		task.wait(Time) -- Let it finish current animations
		
		_StartPart:Destroy()
		_EndPart:Destroy()
	end
end

local function RemoveGlowEffect(Properties)
	local Tweens, TweensCompleted = {}, {}
	
	for Part, PropertyTable in pairs(Properties) do
		local NewTransparency = 0.4 + (PropertyTable.Transparency * (1 - 0.4))
		local NewColor = PropertyTable.Color:Lerp(Color3.new(0, 0, 0), 0.33)
		
		table.insert(Tweens, TweenService:Create(Part, PetEffectsModule.Effects.Glow.OutTween, {Color = NewColor, Transparency = NewTransparency}))
	end
	
	for _, Tween in pairs(Tweens) do
		task.spawn(function()
			Tween:Play()
			Tween.Completed:Wait()

			table.insert(TweensCompleted, Tween)
		end)
	end
	
	repeat
		task.wait()
	until (#Tweens == #TweensCompleted)
	
	for Part, PropertyTable in pairs(Properties) do
		Part.Color = PropertyTable.Color
		Part.Material = PropertyTable.Material
		Part.Transparency = PropertyTable.Transparency
	end
end

function GlowEffect(RenderingPet, GlowColor)
	local Tweens, TweensCompleted, PropertyTable = {}, {}, {}
	GlowColor = GlowColor or PetEffectsModule.Effects.Glow.Default
	
	for _, Part in pairs(RenderingPet:GetDescendants()) do
		if Part:IsA('BasePart') and Part.Transparency < 1 then
			PropertyTable[Part] = {Transparency = Part.Transparency, Material = Part.Material, Color = Part.Color}
			
			Part.Transparency = 0.4 + (Part.Transparency * (1 - 0.4))
			Part.Color = Part.Color:Lerp(Color3.new(0, 0, 0), 0.33)
			Part.Material = Enum.Material.Neon
			
			table.insert(Tweens, TweenService:Create(Part, PetEffectsModule.Effects.Glow.InTween, {Color = GlowColor, Transparency = 0}))
		end
	end
	
	for _, Tween in pairs(Tweens) do
		task.spawn(function()
			Tween:Play()
			Tween.Completed:Wait()
			
			table.insert(TweensCompleted, Tween)
		end)
	end
	
	repeat
		task.wait()
	until (#Tweens == #TweensCompleted)
	
	task.wait(0.25)
	
	return function()
		RemoveGlowEffect(PropertyTable)
	end
end

-- Wrapper functions
local function EndSequence(Pet, RenderingPet, Properties, OldPropertyTable, InteractConnections)	
	-- Destroy old pet and set the old properties back, we check if the pet has a parent in case it was destroyed
	-- Also inform the pathfinder to teleport the pet to it's old location and resize
	if Pet.Parent ~= nil then
		PetEffectsModule:ChangeProperties(Pet, Properties, true)
	
		Clientfinding:Fire('Size', {Pet = Pet})
		Clientfinding:Fire('Position', {Pet = Pet, Location = RenderingPet.PrimaryPart.Position})
	end

	RenderingPet:Destroy()
	
	if Pet.Parent ~= nil then
		for _, InteractConnection in pairs(InteractConnections) do
			Interact:Resume(InteractConnection, 'PetEffects')
		end
		
		for Object, OldPropertySubtable in pairs(OldPropertyTable) do
			for PropertyName, PropertyValue in pairs(OldPropertySubtable) do
				Object[PropertyName] = PropertyValue
			end
		end
	end
end

function BeginningSequence(Pet, Properties)
	local RenderingPet = Pet:Clone()
	local PropertyTable = {}
	
	-- The pet is cloned and anchored, if it has a primarypart that is anchored else everything is
	local HasPrimaryPart = RenderingPet.PrimaryPart
	
	if HasPrimaryPart then
		RenderingPet.PrimaryPart.Anchored = true
	end
	
	for _, Object in pairs(RenderingPet:GetDescendants()) do
		if Object:IsA('BasePart') then
			Object.CanCollide = false
			
			if not HasPrimaryPart then
				Object.Anchored = true
			end
		elseif Object:IsA('GuiObject') then
			Object.Visible = false
		elseif Object:IsA('ParticleEmitter') then
			Object.Enabled = false
		end
	end
		
	-- Remove the interact ui
	local InteractConnections = Interact:Retrieve(Pet.PrimaryPart)
	
	for _, InteractConnection in pairs(InteractConnections) do
		Interact:Pause(InteractConnection, 'PetEffects', true)
	end
	
	-- Drop the pet
	CarryingRemote:FireServer('Drop')
	
	-- Save the pet / properties and anchor it / also remove the interact ui
	for _, Object in pairs(Pet:GetDescendants()) do
		if Object:IsA('BasePart') then
			PropertyTable[Object] = {Transparency = Object.Transparency}
			Object.Transparency = 1
		elseif Object:IsA('GuiObject') then
			PropertyTable[Object] = {Visible = Object.Visible}
			Object.Visible = false
		elseif Object:IsA('ParticleEmitter') then
			PropertyTable[Object] = {Enabled = Object.Enabled}
			Object.Enabled = false
		end
	end
	
	RenderingPet.Parent = PetEffectsModule.Repository
	
	-- If there is an animation then it should play it, this has to occur after parenting
	local PetData = Properties.Species and PetsFolder:FindFirstChild(Properties.Species)

	if PetData then
		local IdleAnimation = PetData.Animations:FindFirstChild('Idle')

		if IdleAnimation then
			local Controller = RenderingPet.AnimationController
			local Animator = Controller:FindFirstChild('Animator')
			local LoadedAnimation

			if Animator then
				LoadedAnimation = Animator:LoadAnimation(IdleAnimation)
			else
				LoadedAnimation = Controller:LoadAnimation(IdleAnimation)
			end

			LoadedAnimation.Looped = true
			LoadedAnimation:Play()
		end
	end
	
	-- Return the callback
	return RenderingPet, function() 
		EndSequence(Pet, RenderingPet, Properties, PropertyTable, InteractConnections)
	end
end

-- Primary functions
function PetEffectsModule:PlayEffect(Pet, EffectType, Properties)
	local HandlingPets = PetEffectsModule.HandlingPets
	
	-- If the priority is yield it will wait, otherwise it will ignore it. This is so stuff can't be played
	-- on the main pet if it's invisible
	if EffectType.Priority == 'Yield' then
		repeat
			task.wait()
		until (not HandlingPets[Pet])
	end

	if not HandlingPets[Pet] then
		HandlingPets[Pet] = {
			Type = EffectType,
			Doing = true
		}
		
		local CompletionSequence = {}
		local RenderingPet = Pet

		if EffectType.Wrapping then
			local ReturnedPet, Unwrap = BeginningSequence(Pet, Properties)
			RenderingPet = ReturnedPet
			table.insert(CompletionSequence, 1, Unwrap)
		end

		for _, EffectSubtype in pairs(EffectType.Sequence) do
			if EffectSubtype.Function == 'Wait' then
				task.wait(EffectSubtype.Parameters.Time)

				table.insert(CompletionSequence, 1, function()
					task.wait(EffectSubtype.Parameters.Time)
				end)
			elseif EffectSubtype.Function == 'ChangeProperties' then
				PetEffectsModule:ChangeProperties(RenderingPet, Properties)
			elseif EffectSubtype.Function == 'ParticleEffect' then
				local Callback = ParticleEffect(RenderingPet, EffectSubtype.Parameters.Particle)
				table.insert(CompletionSequence, 1, Callback)
			elseif EffectSubtype.Function == 'LightningEffect' then
				local Parameter = EffectSubtype.Parameters and EffectSubtype.Parameters.Color
				local Callback = LightningEffect(RenderingPet, Parameter)
				table.insert(CompletionSequence, 1, Callback)
			elseif EffectSubtype.Function == 'GlowEffect' then
				local Parameter = EffectSubtype.Parameters and EffectSubtype.Parameters.Color
				local Callback = GlowEffect(RenderingPet, Parameter)
				table.insert(CompletionSequence, 1, Callback)
			end
		end
			
		for _, CallbackFunction in pairs(CompletionSequence) do
			CallbackFunction()
		end
		
		HandlingPets[Pet] = nil
	end
end

function PetEffectsModule:IsPlaying(Pet, OnlyWrapping)
	if not Pet then
		return
	end
	
	local PetIsPlaying = PetEffectsModule['HandlingPets'][Pet]

	if PetIsPlaying then
		if OnlyWrapping then
			if PetIsPlaying.Type and PetIsPlaying.Type.Wrapping then
				return true
			end
		else
			return true
		end
	end
end

-- Main sequence
local Part = Settings:Create('Part', 'LightningPart')
local Attachment = Settings:Create('Attachment', 'LightningAttachment', Part)

Part.CastShadow = false
Part.Transparency = 1
Part.Size = Vector3.new(1, 1, 1)
Part.Anchored = true
Part.Anchored, Part.CanCollide, Part.CanTouch = true, false, false

-- Set it to the lightning part
PetEffectsModule.Effects.Lightning.Part = Part

return PetEffectsModule