--!strict
-- Lokal mətnlər: Locales.t(lang, key, params). Parametrlər "{ad}" yerinə qoyulur.
local AZ = require(script.AZ) :: { [string]: string }
local EN = require(script.EN) :: { [string]: string }

local Locales = {}

Locales.languages = { "az", "en" }
Locales.maps = { az = AZ, en = EN } :: { [string]: { [string]: string } }
Locales.default = "az"

function Locales.t(lang: string?, key: string, params: { [string]: any }?): string
	local map = Locales.maps[lang or Locales.default] or AZ
	local text = map[key] or AZ[key] or key
	if params then
		text = (
			text:gsub("{(%w+)}", function(name: string): string
				local v = params[name]
				if v == nil then
					return "{" .. name .. "}"
				end
				return tostring(v)
			end)
		)
	end
	return text
end

return Locales
