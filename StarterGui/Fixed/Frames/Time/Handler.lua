local Main = script.Parent

local Lighting = game:GetService('Lighting')
local Replicated = game:GetService('ReplicatedStorage')

local Hide = Replicated:WaitForChild('Remotes'):WaitForChild('Interface'):WaitForChild('Hide')
local Settings = require(Replicated:WaitForChild('Modules'):WaitForChild('Utility'):WaitForChild('Settings'))

local Timer = Main:WaitForChild('Timer')
local Shift = Main:WaitForChild('Inside'):WaitForChild('Gradient')

-- 12PM to 9PM Afternoon.. 12 to 20
-- 9PM to 6AM Night.. 21 to 5
-- 6AM to 12 Morning.. 6 to 11

-- Fix the shift offset, shouldn't be red at night
local KeystoneTimes = {
	['Morning'] = {
		['Start'] = Color3.fromRGB(217, 0, 0),
		['End'] = Color3.fromRGB(255, 218, 0),
	};
	
	['Afternoon'] = {
		['Start'] = Color3.fromRGB(0, 125, 242),
		['End'] = Color3.fromRGB(173, 153, 255),
	};
	
	['Night'] = {
		['Start'] = Color3.fromRGB(8, 47, 87),
		['End'] = Color3.fromRGB(62, 108, 255),
	};
}

function Gradient(Hours)
	if Hours > 11 and Hours < 21 then
		local Dividend = (Hours - 11) / (21 - 11)
		
		Shift.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, KeystoneTimes['Afternoon']['Start']:Lerp(KeystoneTimes['Night']['Start'], Dividend)),
			ColorSequenceKeypoint.new(1, KeystoneTimes['Afternoon']['End']:Lerp(KeystoneTimes['Night']['End'], Dividend)),
		}
	elseif Hours > 20 or Hours < 6 then
		local Dividend = Hours < 20 and ((Hours + 24) - 20) / (30 - 20) or (Hours - 20) / (30 - 20)

		Shift.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, KeystoneTimes['Night']['Start']:Lerp(KeystoneTimes['Morning']['Start'], Dividend)),
			ColorSequenceKeypoint.new(1, KeystoneTimes['Night']['End']:Lerp(KeystoneTimes['Morning']['End'], Dividend)),
		}
	elseif Hours > 5 and Hours < 12 then
		local Dividend = (Hours - 5) / (12 - 5)

		Shift.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, KeystoneTimes['Morning']['Start']:Lerp(KeystoneTimes['Afternoon']['Start'], Dividend)),
			ColorSequenceKeypoint.new(1, KeystoneTimes['Morning']['End']:Lerp(KeystoneTimes['Afternoon']['End'], Dividend)),
		}
	end
end

function Format(Hours, Minutes)
	local Status = 'AM'
	
	if Hours < 1 then
		Hours = '12'
	elseif Hours > 11 then
		Status = 'PM'
		
		if Hours > 12 then
			Hours -= 12
		end	
	end

	if Minutes < 10 then
		Minutes = '0' .. Minutes
	end
	
	Minutes = tostring(Minutes)
	Hours = tostring(Hours)
	
	return Hours .. ':' .. Minutes .. ' ' .. Status
end

function Convert(Lighting)
	local Time = Lighting:GetMinutesAfterMidnight() 
	local Hours, Minutes = math.floor(Time / 60), math.floor((Time % 60) + 0.5)
	
	Gradient(Hours)
	return Format(Hours, Minutes)
end

-- Enact color shift depending on time... use loop/lerp
Lighting:GetPropertyChangedSignal('TimeOfDay'):Connect(function()
	Timer.Text = Convert(Lighting)
end)

Hide.Event:Connect(function(Status, Type, List)
	local Mention = Settings:Index(List, Main)

	if Type == 'Except' then
		if Status == 'Hide' then
			if not Mention then
				Main.Visible = false
			end
		else
			if not Mention then
				Main.Visible = true
			end
		end
	elseif Type == 'Including' then
		if Status == 'Hide' then
			if Mention then
				Main.Visible = false
			end
		else
			if Mention then
				Main.Visible = true
			end
		end
	end
end)