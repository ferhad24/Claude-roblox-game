--!nocheck
-- Mənbə kodunda istifadə olunan bütün lokal mətn açarları AZ və EN-də mövcuddur.
local fs = require("@lune/fs")
local H = require("../harness")

return function(T)
	local Locales = H.require("src/shared/Locales")
	local Catalog = H.require("src/shared/Core/Catalog")

	local function walk(dir, out)
		for _, name in fs.readDir(dir) do
			local full = dir .. "/" .. name
			if fs.isDir(full) then
				walk(full, out)
			elseif name:match("%.luau$") then
				table.insert(out, full)
			end
		end
		return out
	end

	T.describe("Lokal mətnlər", function()
		T.it("koddakı bütün açar literalları hər iki dildə var", function()
			local missing = {}
			local prefixes = {
				"ui",
				"hint",
				"msg",
				"cond",
				"cine",
				"key",
				"lang",
				"vol",
				"sens",
				"q",
				"ts",
				"worktype",
				"skin",
				"outfit",
			}
			for _, file in walk("src", {}) do
				local src = fs.readFile(file)
				for key in src:gmatch('"([%w_]+%.[%w_.]+)"') do
					local prefix = key:match("^([%w_]+)%.")
					if table.find(prefixes, prefix) then
						for lang, map in Locales.maps do
							if map[key] == nil then
								table.insert(missing, ("[%s] %s (%s)"):format(lang, key, file))
							end
						end
					end
				end
			end
			for _, m in missing do
				print("      " .. m)
			end
			T.expect(#missing).toBe(0)
		end)

		T.it("hər iş növü üçün ad var", function()
			for _, w in Catalog.Work.work do
				for lang, map in Locales.maps do
					T.expect(map["worktype." .. w.workType] ~= nil).toBeTruthy(lang .. " worktype." .. w.workType)
				end
			end
		end)

		T.it("AZ və EN eyni açar dəstinə malikdir", function()
			for k in Locales.maps.az do
				T.expect(Locales.maps.en[k] ~= nil).toBeTruthy("EN-də yoxdur: " .. k)
			end
			for k in Locales.maps.en do
				T.expect(Locales.maps.az[k] ~= nil).toBeTruthy("AZ-də yoxdur: " .. k)
			end
		end)
	end)
end
