local Replicated = game:GetService('ReplicatedStorage')
local Settings = require(Replicated:WaitForChild('Modules'):WaitForChild('Utility'):WaitForChild('Settings'))

local Remotes = Replicated:WaitForChild('Remotes'):WaitForChild('Data')

local Changed = Remotes:WaitForChild('Changed')
local ChildAdded = Remotes:WaitForChild('ChildAdded')
local ChildRemoved = Remotes:WaitForChild('ChildRemoved')

local Data = {
	PlayerData = {
		-- Stores consolidate data
	},
	
	SharedData = {
		-- Stores shared data for other players, including yourself
	},
	
	EventsTracked = {
		-- Keeps track of all the remote events present to prevent memory leaks
	},
	
	Settings = {
		WaitIndice = 0.03,
		YieldWarning = 5,
		
		DisplayTime = 60,
		DisplaySharedTime = 90,

		RequestDataYield = 3,
		
		PathSeperator = '/',
		
		-- Whether you want to be notified of updates to either
		Notification = {
			Self = false,
			Shared = false,
		}
	},
	
	Loaded = false,
	SharedLoaded = false
}

function Data:Trace(Path, Shared, Event)
	local Traced = (Shared and Data.SharedData) or Data.PlayerData
	local Path = Path or {}
	local Success = true
	
	for _, Branch in pairs(Path) do
		if Traced[Branch] then
			Traced = Traced[Branch]
		else
			-- No point in informing if they haven't even received original initialize data
			if Data.Loaded then
				if #Path >= 1 then
					warn('Error tracing branch for given path: ' .. table.concat(Path, Data.Settings.PathSeperator))
				else
					warn('Error tracing branch for root path.')
				end
			end
			
			Success = false
		end
	end
	
	if Success and not Event then
		if Shared and Data.Settings.Notification.Shared then
			if #Path >= 1 then
				print('[+] Update to shared client in path: ' .. table.concat(Path, Data.Settings.PathSeperator))
			else
				print('[+] Update to shared client in root path.')
			end
		elseif not Shared and Data.Settings.Notification.Self then
			if #Path >= 1 then
				print('[+] Update to own client in path: ' .. table.concat(Path, Data.Settings.PathSeperator))
			else
				print('[+] Update to own client in root path.')
			end
		end
	end
	
	return Traced, Success
end

function Data:Update(Mode, Arguments)	
	local Traced
	local Events = {}
		
	if Mode ~= 'Initialize' then
		local Success
		
		if Arguments.Shared and Data.SharedLoaded then
			Traced, Success = Data:Trace(Arguments.Path, true)
		elseif not Arguments.Shared and Data.Loaded then
			Traced, Success = Data:Trace(Arguments.Path)
		end
		
		if not Success then
			return
		end
	end
		
	if Mode == 'Initialize' then
		if Arguments.Shared then
			print('[+] Shared data attached successfully.')
			
			Traced, Arguments.Key = Data, "SharedData"
			Traced[Arguments.Key] = Arguments.Value
			Data.SharedLoaded = true
		else
			print('[+] Client data loaded successfully.')

			Traced, Arguments.Key = Data, "PlayerData"
			Traced[Arguments.Key] = Arguments.Value
			Data.Loaded = true
		end
	elseif Mode == 'Remove' then
		if type(Traced) == 'table' then
			local Forked = Traced[Arguments.Key]
			
			Events.ChildRemoved = {
				Shared = Arguments.Shared,
				Path = Arguments.Path,
				Key = Arguments.Key,
				Forked = Forked,
			}
		end
		
		Traced[Arguments.Key] = nil
	elseif Mode == 'Insert' then
		Traced[Arguments.Key][Arguments.InsertKey] = Arguments.Value
		
		Events.ChildAdded = {
			Shared = Arguments.Shared,
			Path = Arguments.Path,
			Key = Arguments.Key,
			InsertKey = Arguments.InsertKey
		}
	elseif Mode == 'Set' then
		Traced[Arguments.Key] = Arguments.Value
	else
		return
	end
		
	Events.Changed = {
		Shared = Arguments.Shared,
		Path = Arguments.Path,
		Key = Arguments.Key
	}
	
	return Events
end

function Data:Wait(Directory, Key, Child, Yield)
	local Found = false
	
	if type(Child) ~= 'string' then
		warn('Child name should be a string.')
		return
	elseif Yield and type(Yield) ~= 'number' then
		warn('Yield should be a number.')
		return
	end
	
	if Directory[Key][Child] then
		return Directory[Key][Child]
	end
	
	local Changing
	
	Changing = Changed.Event:Connect(function()
		if Directory[Key] then
			if Directory[Key][Child] then
				Found = true
				Changing:Disconnect()
			end
		else
			warn('Table removed while locating.')
			Changing:Disconnect()
			return
		end
	end)
	
	local Yielded, Warned = 0, false
	
	repeat
		task.wait(Data.Settings.WaitIndice)
		Yielded += Data.Settings.WaitIndice
		
		if Found then
			return Directory[Key][Child]
		end
		
		if not Yield and Yielded >= Data.Settings.YieldWarning and not Warned then
			Warned = true
			warn('Infinite yield possible for child: ' .. Child)
		end
	until (Yield and (Yielded >= Yield))
	
	Changing:Disconnect()
end

function Data:Disconnect(Event)
	local Found = Data['EventsTracked'][Event]
	
	if Found then
		Data['EventsTracked'][Event] = nil
		Event:Destroy()
	end
end

function Data:Changed(Directory, Key)
	local Event = Instance.new('BindableEvent')
	Data['EventsTracked'][Event] = true
	
	local Changing
	
	Changing = Changed.Event:Connect(function(Shared, Path, PathKey)
		local Change = (Shared and Data:Trace(Path, true, true)) or Data:Trace(Path, nil, true)
		
		if not Directory or not Directory[Key] then
			Changing:Disconnect()
			Event:Destroy()
		elseif not Data['EventsTracked'][Event] then
			Changing:Disconnect()
		end
		
		if Change[PathKey] == Directory[Key] then
			Event:Fire(Change[PathKey])
		end
	end)
	
	return Event
end

function Data:ChildAdded(Directory, Key)
	local Event = Instance.new('BindableEvent')
	Data['EventsTracked'][Event] = true

	local Adding
	
	Adding = ChildAdded.Event:Connect(function(Shared, Path, PathKey, PathInsertKey)
		local Added = (Shared and Data:Trace(Path, true, true)) or Data:Trace(Path, nil, true)
		
		if not Directory or not Directory[Key] then
			Adding:Disconnect()
			Event:Destroy()
		elseif not Data['EventsTracked'][Event] then
			Adding:Disconnect()
		end

		if Added[PathKey] == Directory[Key] then
			Event:Fire(PathInsertKey, Added[PathKey][PathInsertKey])
		end
	end)
	
	return Event
end

function Data:ChildRemoved(Directory, Key)
	local Event = Instance.new('BindableEvent')
	Data['EventsTracked'][Event] = true

	local Removing

	Removing = ChildRemoved.Event:Connect(function(Shared, Path, PathKey, Forked)
		local Removed = (Shared and Data:Trace(Path, true, true)) or Data:Trace(Path, nil, true)
		
		if not Directory or not Directory[Key] then
			Removing:Disconnect()
			Event:Destroy()
		elseif not Data['EventsTracked'][Event] then
			Removing:Disconnect()
		end

		if Removed == Directory[Key] then
			Event:Fire(PathKey, Forked)
		end
	end)
	
	return Event
end

task.spawn(function()
	while true do
		task.wait(Data.Settings.DisplayTime)
		print(Data.PlayerData)
	end
end)

task.spawn(function()
	while true do
		task.wait(Data.Settings.DisplaySharedTime)
		print(Data.SharedData)
	end
end)

-- :Loaded() should be a core function in client data module similar to :Wait() using events to wait till loaded
-- Needs to add them to a 'list' and globally check and inform all scripts at once

return Data