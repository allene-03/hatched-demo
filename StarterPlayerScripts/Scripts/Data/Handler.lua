local Replicated = game:GetService('ReplicatedStorage')
local Remotes = Replicated:WaitForChild('Remotes'):WaitForChild('Data')

local Update = Remotes:WaitForChild('Update')
local Ready = Remotes:WaitForChild('Ready')
local Changed = Remotes:WaitForChild('Changed')
local ChildAdded = Remotes:WaitForChild('ChildAdded')
local ChildRemoved = Remotes:WaitForChild('ChildRemoved')

local Settings = require(Replicated:WaitForChild('Modules'):WaitForChild('Utility'):WaitForChild('Settings'))
local DataModule = require(Replicated:WaitForChild('Modules'):WaitForChild('Data'):WaitForChild('Core'))

Update.OnClientEvent:Connect(function(Mode, Arguments)
	local Events = DataModule:Update(Mode, Arguments)
		
	if Events then
		for EventType, Firing in pairs(Events) do
			if EventType == 'Changed' then
				Changed:Fire(Firing.Shared, Firing.Path, Firing.Key, Firing.Shared)
			elseif EventType == 'ChildAdded' then
				ChildAdded:Fire(Firing.Shared, Firing.Path, Firing.Key, Firing.InsertKey)
			elseif EventType == 'ChildRemoved' then
				ChildRemoved:Fire(Firing.Shared, Firing.Path, Firing.Key, Firing.Forked)
			end
		end
	end
end)

while true do	
	if DataModule.Loaded == true then
		break
	end
	
	Ready:FireServer()
	task.wait(DataModule.Settings.RequestDataYield)
end