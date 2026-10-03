--!nocheck
-- DOM tüstü testi: yığılmış .rbxl faylını Lune-un Roblox DOM-una yükləyir və server dünya qurulmasını işlədir.
-- Bu Roblox engine-i DEYİL: fizika, render, şəbəkə, siqnallar yoxdur. Yalnız instance/property xətalarını tutur.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

-- Lune DOM-da olmayan metodlar
roblox.implementMethod("Instance", "WaitForChild", function(inst, name)
	local found = inst:FindFirstChild(name)
	assert(found, "WaitForChild: tapılmadı " .. inst:GetFullName() .. "." .. tostring(name))
	return found
end)

local placePath = process.args[1] or "build/TinyGrove.rbxl"
local game = roblox.deserializePlace(fs.readFile(placePath))
local workspace = game:GetService("Workspace")

-- Engine xidmətləri üçün minimal əvəzedicilər
local tags = {}
local CollectionServiceShim = {
	AddTag = function(_, inst, tag)
		tags[tag] = tags[tag] or {}
		tags[tag][inst] = true
	end,
	RemoveTag = function(_, inst, tag)
		if tags[tag] then
			tags[tag][inst] = nil
		end
	end,
	GetTagged = function(_, tag)
		local out = {}
		for inst in tags[tag] or {} do
			table.insert(out, inst)
		end
		return out
	end,
}
local TweenServiceShim = {
	Create = function(_, inst, _info, props)
		return {
			Play = function()
				for k, v in props do
					inst[k] = v
				end
			end,
		}
	end,
}
local shims = { CollectionService = CollectionServiceShim, TweenService = TweenServiceShim }

local gameProxy = setmetatable({}, {
	__index = function(_, key)
		if key == "GetService" then
			return function(_, name)
				return shims[name] or game:GetService(name)
			end
		end
		local v = game[key]
		if type(v) == "function" then
			return function(_, ...)
				return v(game, ...)
			end
		end
		return v
	end,
})

-- Lune-da Random tipi yoxdur: deterministik əvəzedici
local RandomShim = {
	new = function(seed)
		local state = (seed or 1) % 2147483647
		if state <= 0 then
			state += 2147483646
		end
		local r = {}
		local function nextFloat()
			state = (state * 16807) % 2147483647
			return state / 2147483647
		end
		function r:NextNumber(a, b)
			a = a or 0
			b = b or 1
			return a + (b - a) * nextFloat()
		end
		function r:NextInteger(a, b)
			return math.floor(a + (b - a + 1) * nextFloat())
		end
		return r
	end,
}

local function TweenInfoNew(...)
	return { ... }
end

local cache = {}
local function requireModule(module)
	if cache[module] ~= nil then
		return cache[module]
	end
	assert(module.ClassName == "ModuleScript", "ModuleScript deyil: " .. module:GetFullName())
	local env = {
		script = module,
		game = gameProxy,
		workspace = workspace,
		require = requireModule,
		Instance = roblox.Instance,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		UDim2 = roblox.UDim2,
		UDim = roblox.UDim,
		Enum = roblox.Enum,
		Random = RandomShim,
		NumberRange = roblox.NumberRange,
		NumberSequence = roblox.NumberSequence,
		ColorSequence = roblox.ColorSequence,
		TweenInfo = { new = TweenInfoNew },
		task = {
			wait = function() end,
			spawn = function(f, ...)
				f(...)
			end,
			defer = function(f, ...)
				f(...)
			end,
			delay = function() end,
		},
	}
	local fn = luau.load(module.Source, { debugName = module:GetFullName(), environment = env })
	local result = fn()
	cache[module] = result
	return result
end

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:FindFirstChild("Shared")

-- Kataloq yoxlaması (server başlanğıcındakı kimi)
local Catalog = requireModule(Shared.Core.Catalog)
local Locales = requireModule(Shared.Locales)
local errs = Catalog.validate(Locales.maps)
assert(#errs == 0, "kataloq xətaları: " .. #errs)

local WorldService = requireModule(ServerScriptService.Server.Services.WorldService)
local Profile = requireModule(Shared.Core.Profile)
local Game = requireModule(Shared.Core.Game)

WorldService.build()
local world = workspace:FindFirstChild("World")
assert(world, "World qovluğu yaradılmadı")
local parts = 0
for _, d in world:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
end
print(
	("Dünya quruldu: %d hissə, %d interaktiv obyekt"):format(parts, #CollectionServiceShim:GetTagged("TG_Interact"))
)

-- Vəziyyətin tətbiqi və bir neçə hadisə
local p = Profile.new(0)
WorldService.applyAll(p)
local g = Game.new(p)
g:setPosition(0, 0, 80)
g:handle("StartWork", { target = "Z01_Leaf_01" }, 1)
for _ = 1, 30 do
	g:tick(0.1)
end
for _, e in g:drainEvents() do
	WorldService.handleEvent(e, p)
end
-- Qurğu yerləşdirmə görünüşü (bütün qurğu növləri)
local Layout = requireModule(Shared.Layout)
local BuildDefs = requireModule(Shared.Defs.BuildDefs)
local uid = 100
for _, def in BuildDefs.list do
	if not def.socketOnly then
		uid += 1
		local variants = def.variants or { { id = nil } }
		for _, v in variants do
			uid += 1
			p.builds[tostring(uid)] = {
				t = def.id,
				area = "A_Z06",
				x = 10 + (uid % 10) * 7,
				z = 10 + math.floor(uid / 10) % 8 * 7,
				r = uid % 4,
				v = v.id ~= "straight" and v.id or nil,
			}
			WorldService.applyBuild(tostring(uid), p)
		end
	end
end
-- Yuvalar: körpü və lift
p.builds["900"] = { t = "B_BRIDGE", socket = "Z02_BridgeSocket", x = 0, z = 0, r = 0 }
p.builds["901"] = { t = "B_LIFT", socket = "Z04_LiftSocket", x = 0, z = 0, r = 0 }
WorldService.applyBuild("900", p)
WorldService.applyBuild("901", p)
-- Bitki mərhələləri
p.plants["Z01_Plot_02"] = { sp = "PL_DAISY", g = 90, m = 50, ready = true }
WorldService.applyPlant("Z01_Plot_02", p)
-- Bütün sahələr açıq və bərpa olunmuş görünüş
for _, z in { "Z02", "Z03", "Z04", "Z05", "Z06" } do
	p.zones[z] = true
end
for id in pairs(Layout.byId) do
	p.restoredObjectIds[id] = true
end
for _, ch in requireModule(Shared.Defs.QuestDefs).chapters do
	for _, s in ch.steps do
		p.quest.done[s.id] = true
	end
end
WorldService.applyAll(p)
WorldService.handleEvent({ type = "chapter", n = 6 }, p)
-- Personaj görünüşü (R15 və R6 hissə adları)
local CharacterLook = requireModule(ServerScriptService.Server.Services.CharacterLook)
for _, names in { { "Head", "LeftHand", "RightHand", "UpperTorso" }, { "Head", "Left Arm", "Right Arm", "Torso" } } do
	local char = roblox.Instance.new("Model")
	for _, n in names do
		local part = roblox.Instance.new("Part")
		part.Name = n
		part.Size = roblox.Vector3.new(1, 1, 1)
		part.CFrame = roblox.CFrame.new(0, 5, 0)
		part.Parent = char
	end
	char.Parent = workspace
	CharacterLook.apply(char, { skin = 3, outfit = 2 }, 20)
	CharacterLook.apply(char, { skin = 1, outfit = 4 }, 5)
	assert(char:FindFirstChild("TG_LeafHat"), "papaq yaradılmadı")
	assert(char:FindFirstChildOfClass("BodyColors"), "BodyColors yoxdur")
end
print("Personaj görünüşü: xətasız")
print("Vəziyyət tətbiqi və hadisələr: xətasız")
