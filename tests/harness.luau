--!nocheck
-- Lune üçün yükləyici: Roblox-un `script.Parent.X` üslublu require-larını fayl sisteminə xəritələyir.
-- Yalnız Roblox API-dən asılı olmayan modullar (src/shared) burada işlədilə bilər.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Harness = {}

local moduleCache: { [string]: any } = {}
local proxyCache: { [string]: any } = {}
local loading: { [string]: boolean } = {}

local function dirname(path: string): string
	return path:match("^(.*)/[^/]+$") or "."
end

local function basename(path: string): string
	return (path:match("([^/]+)$") or path):gsub("%.luau$", "")
end

local makeProxy

-- fs funksiyaları yield edir, metametodda çağırıla bilməz: ağacı əvvəlcədən indeksləyirik.
local dirs: { [string]: boolean } = {}
local files: { [string]: boolean } = {}
local function index(path: string)
	dirs[path] = true
	for _, name in fs.readDir(path) do
		local full = path .. "/" .. name
		if fs.isDir(full) then
			index(full)
		else
			files[full] = true
		end
	end
end
index("src")
index("tests")

local function childPath(path: string, name: string): string?
	if dirs[path] then
		local dirChild = path .. "/" .. name
		if dirs[dirChild] then
			return dirChild
		end
		if files[dirChild .. ".luau"] then
			return dirChild .. ".luau"
		end
	end
	return nil
end

function makeProxy(path: string)
	if proxyCache[path] then
		return proxyCache[path]
	end
	local proxy = setmetatable({ __path = path }, {
		__index = function(self, key)
			if key == "Parent" then
				return makeProxy(dirname(path))
			elseif key == "Name" then
				return basename(path)
			elseif key == "FindFirstChild" then
				return function(_, name)
					local p = childPath(path, name)
					return p and makeProxy(p) or nil
				end
			elseif key == "WaitForChild" then
				return function(_, name)
					local p = childPath(path, name)
					assert(p, "WaitForChild: tapılmadı " .. path .. "/" .. tostring(name))
					return makeProxy(p)
				end
			end
			local p = childPath(path, key)
			if not p then
				error(("harness: '%s' içində '%s' tapılmadı"):format(path, tostring(key)), 2)
			end
			return makeProxy(p)
		end,
		__tostring = function()
			return "Proxy(" .. path .. ")"
		end,
	})
	proxyCache[path] = proxy
	return proxy
end

local function fileFor(path: string): string
	if dirs[path] then
		return path .. "/init.luau"
	end
	return path
end

local customRequire

function customRequire(target: any): any
	if type(target) ~= "table" or not rawget(target, "__path") then
		error("harness: require yalnız script proxy qəbul edir, gələn: " .. tostring(target), 2)
	end
	local path = rawget(target, "__path")
	local file = fileFor(path)
	if moduleCache[file] ~= nil then
		return moduleCache[file]
	end
	if loading[file] then
		error("harness: dövri require: " .. file)
	end
	loading[file] = true
	local source = fs.readFile(file)
	local chunk = luau.load(source, {
		debugName = file,
		environment = {
			script = makeProxy(path),
			require = customRequire,
		},
	})
	local result = chunk()
	loading[file] = nil
	moduleCache[file] = result
	return result
end

function Harness.root(path: string)
	return makeProxy(path)
end

function Harness.require(path: string)
	if not dirs[path] and files[path .. ".luau"] then
		path ..= ".luau"
	end
	return customRequire(makeProxy(path))
end

function Harness.reset()
	table.clear(moduleCache)
end

return Harness
