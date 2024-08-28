local TweenService = game:GetService('TweenService')

local Randomize = Random.new()

-- For the wheel model
local Wheel = workspace:WaitForChild('Map'):WaitForChild('Main'):WaitForChild('Wheel'):WaitForChild('SpinningWheel'):WaitForChild('Main')
local WheelRoot = Wheel.PrimaryPart

local WheelInformation = TweenInfo.new(1.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

task.spawn(function()
	while true do
		local Tween = TweenService:Create(WheelRoot, WheelInformation, {
			CFrame = WheelRoot.CFrame * CFrame.Angles(math.rad(180), 0, 0)
		})

		Tween:Play()
		Tween.Completed:Wait()
	end
end)

-- For the car models
local Platters = workspace:WaitForChild('Platters')

for _, Platter in pairs(Platters:GetChildren()) do
	local PlatterRoot = Platter.PrimaryPart
	
	local SecondsForHalfRevolution = Randomize:NextInteger(100, 150) / 10
	local OppositeDirection = Randomize:NextInteger(1, 2) == 1

	local PlatterInformation = TweenInfo.new(SecondsForHalfRevolution, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	
	-- Start it by a random value so it doesn't look uniformm
	PlatterRoot.CFrame = PlatterRoot.CFrame * CFrame.Angles(math.rad(Randomize:NextInteger(1, 360)), 0, 0)
	
	task.spawn(function()
		while true do
			local Tween = TweenService:Create(PlatterRoot, PlatterInformation, {
				CFrame = PlatterRoot.CFrame * CFrame.Angles(math.rad(if OppositeDirection then -180 else 180), 0, 0)
			})

			Tween:Play()
			Tween.Completed:Wait()
		end
	end)
end