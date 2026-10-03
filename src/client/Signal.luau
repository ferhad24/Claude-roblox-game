--!strict
-- Sadə siqnal (client daxili hadisələr üçün).
local Signal = {}
Signal.__index = Signal

export type Connection = { Disconnect: (Connection) -> () }
export type Signal<T...> = {
	Connect: (Signal<T...>, (T...) -> ()) -> Connection,
	Fire: (Signal<T...>, T...) -> (),
}

function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({ handlers = {} :: { [number]: (T...) -> () }, nextId = 0 }, Signal)
	return self :: any
end

function Signal.Connect(self: any, fn: (...any) -> ()): Connection
	self.nextId += 1
	local id = self.nextId
	self.handlers[id] = fn
	return {
		Disconnect = function(_c: any)
			self.handlers[id] = nil
		end,
	} :: any
end

function Signal.Fire(self: any, ...: any)
	for _, fn in self.handlers do
		task.spawn(fn, ...)
	end
end

return Signal
