--!strict
-- Cari dil və mətn tərcüməsi. Parametr dəyəri lokal açar kimi tanınırsa (məs. "item.MAT_FIBER") tərcümə olunur.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Locales = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Locales"))
local Signal = require(script.Parent.Signal)

local Lang = {}

Lang.current = "az"
Lang.Changed = Signal.new() :: Signal.Signal<string>

function Lang.set(lang: string)
	if lang ~= Lang.current and Locales.maps[lang] then
		Lang.current = lang
		Lang.Changed:Fire(lang)
	end
end

function Lang.has(key: string): boolean
	return Locales.maps[Lang.current][key] ~= nil or Locales.maps.az[key] ~= nil
end

function Lang.t(key: string, params: { [string]: any }?): string
	local resolved: { [string]: any }? = nil
	if params then
		resolved = {}
		for k, v in params do
			if type(v) == "string" and Lang.has(v) then
				(resolved :: any)[k] = Locales.t(Lang.current, v)
			else
				(resolved :: any)[k] = v
			end
		end
	end
	return Locales.t(Lang.current, key, resolved)
end

return Lang
