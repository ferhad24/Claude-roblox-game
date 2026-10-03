--!strict
-- Serverlə əlaqə: sorğular (rid ilə), vəziyyət (snapshot), hadisələr, sessiya statusu.
-- Client heç vaxt qiymət, mükafat, XP və ya hazır nəticə göndərmir: yalnız niyyət (action + ID-lər).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(script.Parent.Signal)

local Net = {}

local remotes: Folder
local actionRemote: RemoteEvent
local resultRemote: RemoteEvent
local stateRemote: RemoteEvent
local eventRemote: RemoteEvent
local sessionRemote: RemoteEvent

local nextRid = 0
local pending: { [number]: (any) -> () } = {}

Net.state = nil :: { [string]: any }?
Net.session = { status = "loading", testMode = false, isNew = false } :: { [string]: any }
Net.StateChanged = Signal.new() :: Signal.Signal<{ [string]: any }>
Net.Event = Signal.new() :: Signal.Signal<{ [string]: any }>
Net.SessionChanged = Signal.new() :: Signal.Signal<{ [string]: any }>
Net.Result = Signal.new() :: Signal.Signal<string, { [string]: any }>

function Net.init()
	remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	actionRemote = remotes:WaitForChild("Action") :: RemoteEvent
	resultRemote = remotes:WaitForChild("Result") :: RemoteEvent
	stateRemote = remotes:WaitForChild("State") :: RemoteEvent
	eventRemote = remotes:WaitForChild("Event") :: RemoteEvent
	sessionRemote = remotes:WaitForChild("Session") :: RemoteEvent

	stateRemote.OnClientEvent:Connect(function(snapshot: any)
		if type(snapshot) == "table" then
			Net.state = snapshot
			Net.StateChanged:Fire(snapshot)
		end
	end)
	eventRemote.OnClientEvent:Connect(function(e: any)
		if type(e) == "table" then
			Net.Event:Fire(e)
		end
	end)
	sessionRemote.OnClientEvent:Connect(function(msg: any)
		if type(msg) == "table" then
			Net.session = msg
			Net.SessionChanged:Fire(msg)
		end
	end)
	resultRemote.OnClientEvent:Connect(function(rid: any, result: any)
		local cb = pending[rid]
		if cb then
			pending[rid] = nil
			cb(result)
		end
	end)
	sessionRemote:FireServer({ op = "hello" })
end

-- Sorğu göndərir; nəticə callback-ə gəlir. Uğursuz nəticə HUD-da göstərilmək üçün Result siqnalına da gedir.
function Net.request(action: string, payload: { [string]: any }?, callback: ((any) -> ())?)
	nextRid += 1
	local rid = nextRid
	local body: { [string]: any } = payload or {}
	body.rid = rid
	pending[rid] = function(result: any)
		if callback then
			callback(result)
		end
		Net.Result:Fire(action, result)
	end
	actionRemote:FireServer(action, body)
end

-- Gözləyən versiya (yield edir)
function Net.call(action: string, payload: { [string]: any }?): any
	local thread = coroutine.running()
	local done = false
	local value = nil
	Net.request(action, payload, function(result)
		done = true
		value = result
		task.spawn(thread, result)
	end)
	if not done then
		value = coroutine.yield()
	end
	return value
end

function Net.retryLoad()
	sessionRemote:FireServer({ op = "retry" })
end

return Net
