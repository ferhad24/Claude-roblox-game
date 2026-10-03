--!nocheck
-- Test işlədicisi: `lune run tests/run.luau [filtr]`
-- Yalnız Roblox API-dən asılı olmayan məntiq yoxlanılır. Studio/oyun daxili davranış burada test edilmir.
local fs = require("@lune/fs")
local process = require("@lune/process")
local Lib = require("./lib")

local filter = process.args[1]

local specs = {}
for _, name in fs.readDir("tests/specs") do
	if name:match("%.spec%.luau$") and (not filter or name:find(filter, 1, true)) then
		table.insert(specs, name)
	end
end
table.sort(specs)

for _, name in specs do
	print("\n▶ " .. name)
	local spec = require("./specs/" .. name:gsub("%.luau$", ""))
	local ok, err = pcall(spec, Lib)
	if not ok then
		Lib.results.failed += 1
		table.insert(Lib.results.failures, { name = name, err = err })
		print("  ✗ yüklənmə xətası: " .. tostring(err))
	end
end

local r = Lib.results
print(("\nNəticə: %d keçdi, %d uğursuz"):format(r.passed, r.failed))
if r.failed > 0 then
	print("\nUğursuz testlər:")
	for _, f in r.failures do
		print("  - " .. f.name)
	end
	process.exit(1)
end
