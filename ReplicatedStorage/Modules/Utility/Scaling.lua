local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local Replicated = game:GetService('ReplicatedStorage')

local Settings = require(Replicated:WaitForChild('Modules'):WaitForChild('Utility'):WaitForChild('Settings'))

local Scaling = {}

function scaleRecursive(part, instance, scaleFactor)
	if instance:isA("Bone") then
		local bone = instance
		-- move bone local translation to part space, scale, then move back to bone parent space
		local parentCFrame = bone.Parent.CFrame
		local boneParentToPartCFrame = part.CFrame:Inverse() * parentCFrame
		boneParentToPartCFrame = boneParentToPartCFrame - boneParentToPartCFrame.Position
		local pivotOffsetInPartSpace = (boneParentToPartCFrame * bone.Position) * scaleFactor
		bone.Position = boneParentToPartCFrame:inverse() * pivotOffsetInPartSpace
	end

	local children = instance:GetChildren()

	for i = 1, #children do
		local child = children[i]
		scaleRecursive(part, child, scaleFactor)
	end
end

function Scaling:CalculateScale(Original, New)
	if not Original.PrimaryPart or not New.PrimaryPart then
		warn('Model needs primary part.')
		return
	end

	return ((New.PrimaryPart.Size.X + New.PrimaryPart.Size.Y + New.PrimaryPart.Size.Z) / (Original.PrimaryPart.Size.X + Original.PrimaryPart.Size.Y + Original.PrimaryPart.Size.Z))
end

function Scaling:ScaleAnimation(Animations, Original, New)
	local Folder = Instance.new('Folder')
	local ScaleFactor = Scaling:CalculateScale(Original, New)

	if not ScaleFactor then
		warn('Scale factor not present.')
		return
	elseif ScaleFactor <= 0 then
		warn('Scale factor too low.')
		return
	end

	for _, Animation in pairs(Animations) do
		if not Animation.ClassName == 'KeyframeSequence' then
			warn('Keyframe sequence not attributed.')
			continue
		end

		local NewAnimation = Animation:Clone()

		for _, Pose in pairs(NewAnimation:GetDescendants()) do
			if Pose:IsA('Pose') then
				Pose.CFrame = Pose.CFrame + Pose.CFrame.p  * (ScaleFactor - 1)
				NewAnimation.Parent = Folder
			end
		end
	end

	return Folder
end

function Scaling:Resize(Model, Factor)
	for _, Part in pairs(Model:GetChildren()) do
		if Part:IsA("BasePart") then
			Part.Size *= Factor
			scaleRecursive(Part, Part, Factor)

			for _, child in pairs(Part:GetChildren()) do
				if child:IsA("JointInstance") then
					-- Set the Offset CFrames to itself adding (or subtracting) a scaled position of itself.
					child.C0 = child.C0 + child.C0.Position * (Factor - 1)
					child.C1 = child.C1 + child.C1.Position * (Factor - 1)
				end
			end
		end
	end
end

function Scaling:TweenSize(Model, Duration, Factor, easingStyle, easingDirection)
	local S, I, oldAlpha = Factor - 1, 0, 0

	while I < 1 do
		local WaitTime = task.wait(0.029) -- We want it low enough so it's smooth, but not so high that it lags
		I = math.min(I + (WaitTime / Duration), 1)
		
		local Alpha = TweenService:GetValue(I, easingStyle, easingDirection)
		Scaling:Resize(Model, (Alpha * S + 1) / (oldAlpha * S + 1))
		
		oldAlpha = Alpha
	end

	task.wait()
end

return Scaling