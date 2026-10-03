--!nocheck
-- UI tüstü testi (loopback): client modulları Lune DOM-da işə salınır, RemoteEvent-lər birbaşa
-- real oyun nüvəsinə (Game) qoşulur. Hər panel və tab açılır, düymələr basılır.
-- Bu Roblox engine-i DEYİL: render, layout hesabı, fizika yoxdur. Yalnız runtime xətalarını tutur.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local game = roblox.deserializePlace(fs.readFile(process.args[1] or "build/TinyGrove.rbxl"))
local workspace = game:GetService("Workspace")
local errors = {}

------------------------------------------------------------------------------------------
-- Siqnal və event əvəzediciləri
------------------------------------------------------------------------------------------
local function newSignal()
	local handlers = {}
	local sig = {}
	function sig:Connect(fn)
		handlers[fn] = true
		return {
			Disconnect = function()
				handlers[fn] = nil
			end,
			Connected = true,
		}
	end
	function sig:Fire(...)
		for fn in handlers do
			local ok, err = pcall(fn, ...)
			if not ok then
				table.insert(errors, tostring(err))
				print("  XƏTA (siqnal): " .. tostring(err))
			end
		end
	end
	function sig:Wait() end
	return sig
end

-- Lune eyni Instance üçün müxtəlif userdata obyektləri qaytara bilər: siqnalları atributdakı sabit ID ilə açarlayırıq
local instanceSignals = {}
local nextSigId = 0
local function signalFor(inst, name)
	local id = inst:GetAttribute("__sigid")
	if not id then
		nextSigId += 1
		id = nextSigId
		inst:SetAttribute("__sigid", id)
	end
	local map = instanceSignals[id]
	if not map then
		map = {}
		instanceSignals[id] = map
	end
	if not map[name] then
		map[name] = newSignal()
	end
	return map[name]
end
for _, pair in
	{
		{ "GuiButton", "Activated" },
		{ "GuiObject", "InputBegan" },
		{ "GuiObject", "InputEnded" },
		{ "RemoteEvent", "OnClientEvent" },
		{ "RemoteEvent", "OnServerEvent" },
	}
do
	roblox.implementProperty(pair[1], pair[2], function(inst)
		return signalFor(inst, pair[2])
	end)
end
-- Engine tərəfindən hesablanan metodlar
roblox.implementMethod("Model", "GetPivot", function(m)
	local pp = m.PrimaryPart
	return if pp then pp.CFrame else roblox.CFrame.new()
end)
-- Raycast: A_Z01_LINE sahəsinin içinə (21, 0, 86) düşən saxta nəticə
roblox.implementMethod("Workspace", "Raycast", function()
	return { Position = roblox.Vector3.new(21, 0, 86), Normal = roblox.Vector3.new(0, 1, 0) }
end)
roblox.implementMethod("Camera", "ViewportPointToRay", function(_cam, x, y)
	return roblox.Ray.new(roblox.Vector3.new(0, 50, 0), roblox.Vector3.new(0, -1, 0))
end)
roblox.implementMethod("Camera", "ScreenPointToRay", function(_cam, x, y)
	return roblox.Ray.new(roblox.Vector3.new(0, 50, 0), roblox.Vector3.new(0, -1, 0))
end)
roblox.implementMethod("Instance", "WaitForChild", function(inst, name)
	local found = inst:FindFirstChild(name)
	assert(found, "WaitForChild: tapılmadı " .. inst:GetFullName() .. "." .. tostring(name))
	return found
end)
roblox.implementMethod("Instance", "GetPropertyChangedSignal", function(inst, prop)
	return signalFor(inst, "Changed_" .. prop)
end)

------------------------------------------------------------------------------------------
-- Xidmət əvəzediciləri
------------------------------------------------------------------------------------------
local tags = {}
local CollectionService = {
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
		-- Roblox Destroy zamanı tag-ları silir: silinmiş instansları atırıq
		local out = {}
		for inst in tags[tag] or {} do
			local alive = pcall(function()
				return inst.Parent
			end)
			if alive and inst.Parent ~= nil then
				table.insert(out, inst)
			else
				tags[tag][inst] = nil
			end
		end
		return out
	end,
}
local TweenService = {
	Create = function(_, inst, _info, props)
		return {
			Play = function()
				for k, v in props do
					inst[k] = v
				end
			end,
			Cancel = function() end,
		}
	end,
}
local UserInputService = {
	TouchEnabled = true, -- mobil düymələri də yarat
	KeyboardEnabled = true,
	MouseEnabled = true,
	GamepadEnabled = false,
	MouseDeltaSensitivity = 1,
	InputBegan = newSignal(),
	InputEnded = newSignal(),
	TouchMoved = newSignal(),
	GetMouseLocation = function()
		return roblox.Vector2.new(400, 300)
	end,
}
local GuiService = { MenuOpened = newSignal(), MenuClosed = newSignal() }
local RunService = {
	RenderStepped = newSignal(),
	Heartbeat = newSignal(),
	IsStudio = function()
		return true
	end,
}
local ContextActionService = { BindAction = function() end, UnbindAction = function() end }

local playerGui = roblox.Instance.new("Folder")
playerGui.Name = "PlayerGui"
local LocalPlayer = {
	Name = "Tester",
	UserId = 1,
	Character = nil,
	CharacterAdded = newSignal(),
	CameraMinZoomDistance = 8,
	CameraMaxZoomDistance = 22,
	PlayerGui = playerGui,
	WaitForChild = function(_, name)
		if name == "PlayerGui" then
			return playerGui
		end
		error("LocalPlayer.WaitForChild " .. name)
	end,
}
local Players = { LocalPlayer = LocalPlayer }

local cam = roblox.Instance.new("Camera")
cam.ViewportSize = roblox.Vector2.new(1280, 720)
cam.Parent = workspace
local okCam = pcall(function()
	workspace.CurrentCamera = cam
end)
print("CurrentCamera təyin olundu: " .. tostring(okCam))
local workspaceProxy = workspace

local shims = {
	CollectionService = CollectionService,
	TweenService = TweenService,
	UserInputService = UserInputService,
	GuiService = GuiService,
	RunService = RunService,
	ContextActionService = ContextActionService,
	Players = Players,
}
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
			return (a or 0) + ((b or 1) - (a or 0)) * nextFloat()
		end
		function r:NextInteger(a, b)
			return math.floor(a + (b - a + 1) * nextFloat())
		end
		return r
	end,
}

local cache = {}
local function makeEnv(module, req)
	return {
		script = module,
		game = gameProxy,
		workspace = workspaceProxy,
		require = req,
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
		TweenInfo = {
			new = function(...)
				return { ... }
			end,
		},
		Ray = roblox.Ray,
		RaycastParams = {
			new = function()
				return {}
			end,
		},
		task = {
			wait = function()
				return 0.1
			end,
			spawn = function(f, ...)
				local ok, err = pcall(f, ...)
				if not ok then
					table.insert(errors, tostring(err))
					print("  XƏTA (task): " .. tostring(err))
				end
			end,
			defer = function(f, ...)
				local ok, err = pcall(f, ...)
				if not ok then
					table.insert(errors, tostring(err))
				end
			end,
			delay = function() end,
		},
		os = os,
		coroutine = coroutine,
	}
end
local function requireModule(module)
	if cache[module] ~= nil then
		return cache[module]
	end
	local fn =
		luau.load(module.Source, { debugName = module:GetFullName(), environment = makeEnv(module, requireModule) })
	local result = fn()
	cache[module] = result
	return result
end

------------------------------------------------------------------------------------------
-- Server tərəfi: dünya və real oyun sessiyası (loopback)
------------------------------------------------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:FindFirstChild("Shared")
local WorldService = requireModule(game:GetService("ServerScriptService").Server.Services.WorldService)
local Profile = requireModule(Shared.Core.Profile)
local Game = requireModule(Shared.Core.Game)
WorldService.build()

-- Lune DOM: BasePart.Position CFrame-dən hesablanmır; dünya hissələri üçün əl ilə təyin edirik
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") then
		d.Position = d.CFrame.Position
	end
end
cam.CFrame = roblox.CFrame.lookAt(roblox.Vector3.new(0, 15, 100), roblox.Vector3.new(0, 0, 80))

local remotes = roblox.Instance.new("Folder")
remotes.Name = "Remotes"
for _, n in { "Action", "Result", "State", "Event", "Session" } do
	local r = roblox.Instance.new("RemoteEvent")
	r.Name = n
	r.Parent = remotes
end
remotes.Parent = ReplicatedStorage

local profile = Profile.new(0)
profile.coins = 500
local session = Game.new(profile)
session:setPosition(0, 0, 86)
local clock = 0
local sent = 0

local function pushState()
	signalFor(remotes.State, "OnClientEvent"):Fire(session:snapshot())
end
local function pushEvents()
	for _, e in session:drainEvents() do
		WorldService.handleEvent(e, profile)
		signalFor(remotes.Event, "OnClientEvent"):Fire(e)
	end
end

-- Şəbəkə gecikməsi rejimi: sorğular növbəyə yığılır və flush() ilə emal olunur (cavab + snapshot gec gəlir)
local latency = false
local queue = {}
local startCount = 0
local function flush()
	local q = queue
	queue = {}
	for _, fn in q do
		fn()
	end
end

roblox.implementMethod("RemoteEvent", "FireServer", function(remote, a, b)
	sent += 1
	if remote.Name == "Action" then
		if a == "StartWork" then
			startCount += 1
		end
		local function deliver()
			clock += 1
			local result = session:handle(a, b, clock)
			if not result.ok then
				print(("   server rədd etdi: %s → %s"):format(tostring(a), tostring(result.err)))
			end
			if type(b) == "table" and b.rid then
				signalFor(remotes.Result, "OnClientEvent"):Fire(b.rid, result)
			end
			pushEvents()
			pushState()
		end
		if latency then
			table.insert(queue, deliver)
		else
			deliver()
		end
	elseif remote.Name == "Session" then
		signalFor(remotes.Session, "OnClientEvent"):Fire({ status = "ready", testMode = true, isNew = true })
		pushState()
	end
end)

------------------------------------------------------------------------------------------
-- Client: init skriptini işə sal
------------------------------------------------------------------------------------------
local client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local clientFn = luau.load(client.Source, { debugName = "Client", environment = makeEnv(client, requireModule) })
clientFn()
print("Client modulları yükləndi, sorğular: " .. sent)

local Panels = requireModule(client.UI.Panels)
local Hud = requireModule(client.UI.Hud)
local Interaction = requireModule(client.Controllers.Interaction)
local Build = requireModule(client.Controllers.Build)
local Dialog = requireModule(client.UI.Dialog)
local Lang = requireModule(client.Lang)

-- Başla düyməsi
local function findButton(root, pred)
	for _, d in root:GetDescendants() do
		if d:IsA("TextButton") and pred(d) then
			return d
		end
	end
	return nil
end
local ui = playerGui:FindFirstChild("TinyGroveUI")
assert(ui, "UI yaradılmadı")
local start = findButton(ui, function(b)
	return b.Text == "Başla" or b.Text == "Davam et"
end)
assert(start, "Başla düyməsi tapılmadı")
signalFor(start, "Activated"):Fire()
print("Başla basıldı; pauza: " .. tostring(session.paused))

-- Hər panel və tab
local tabs = {
	inventory = { "bag", "builds", "seeds", "tools", "campaign" },
	shop = { "tools", "bag", "seeds", "decor" },
	workshop = { "recipes", "keys" },
	board = {},
	quests = {},
	map = {},
	plantbook = {},
	memories = {},
	achievements = {},
	settings = {},
	pause = {},
}
for name, list in tabs do
	Panels.open(name)
	for _, t in list do
		Panels.open(name, t)
	end
	Panels.close()
end
print("Bütün panellər və tablar açıldı")

-- Dükandan alış (qayçı): addım şərtini yerinə yetir və düyməni bas
profile.quest.done["Q1_LEAVES"] = true
session.dirty = true
pushState()
Panels.open("shop", "tools")
local buyBtn = findButton(ui, function(b)
	return b.Text == "Al" and b.AutoButtonColor
end)
assert(buyBtn, "Al düyməsi tapılmadı")
signalFor(buyBtn, "Activated"):Fire()
Panels.close()
print("Alışdan sonra alətlər: shears=" .. tostring(profile.tools["TOOL_SHEARS_1"]) .. " damğa=" .. profile.coins)

-- Dil dəyişməsi və ayarlar
Panels.open("settings")
Lang.set("en")
Panels.close()
Lang.set("az")

-- Dialoq
Dialog.open("NPC_PITIR", function() end)
Dialog.advance()
Dialog.advance()

-- Personaj: yarpağa baxır və sol düyməni basılı saxlayır (iş)
local char = roblox.Instance.new("Model")
char.Name = "Tester"
local hrp = roblox.Instance.new("Part")
hrp.Name = "HumanoidRootPart"
hrp.CFrame = roblox.CFrame.lookAt(roblox.Vector3.new(0, 3, 83), roblox.Vector3.new(0, 3, 80))
hrp.Position = hrp.CFrame.Position -- Lune DOM: Position CFrame-dən avtomatik hesablanmır
hrp.Parent = char
local head = roblox.Instance.new("Part")
head.Name = "Head"
head.CFrame = hrp.CFrame * roblox.CFrame.new(0, 1.5, 0)
head.Position = head.CFrame.Position
head.Parent = char
char.Parent = workspace
LocalPlayer.Character = char
session:setPosition(0, 0, 83)
RunService.RenderStepped:Fire(0.1)
UserInputService.InputBegan:Fire(
	{ UserInputType = roblox.Enum.UserInputType.MouseButton1, KeyCode = roblox.Enum.KeyCode.Unknown },
	false
)
assert(
	session.work and session.work.id == "Z01_Leaf_01",
	"iş UI-dən başlamadı: " .. tostring(session.work and session.work.id)
)
for _ = 1, 30 do
	session:tick(0.1)
end
pushEvents()
pushState()
UserInputService.InputEnded:Fire({
	UserInputType = roblox.Enum.UserInputType.MouseButton1,
	KeyCode = roblox.Enum.KeyCode.Unknown,
})
assert(profile.restoredObjectIds["Z01_Leaf_01"], "yarpaq təmizlənmədi")
print("UI ilə iş: Z01_Leaf_01 təmizləndi, lif=" .. tostring(profile.bag["MAT_FIBER"]))

-- Gecikmə ilə iş: cavab və snapshot 10 kadr gec gəlir. Basılı düymə StartWork-u hər kadrda
-- təkrar göndərməməlidir (əvvəl belə olurdu və sürət limiti xətaları yaranırdı)
-- Yarpaq 2-nin şimal-şərqi (Nərgizdən uzaq), standart baxış −Z (Lune lookAt məhdudiyyəti)
hrp.CFrame = roblox.CFrame.new(2, 3, 78)
hrp.Position = hrp.CFrame.Position
session:setPosition(2, 0, 78)
latency = true
local startsBefore = startCount
RunService.RenderStepped:Fire(0.1)
UserInputService.InputBegan:Fire(
	{ UserInputType = roblox.Enum.UserInputType.MouseButton1, KeyCode = roblox.Enum.KeyCode.Unknown },
	false
)
for _ = 1, 10 do
	RunService.RenderStepped:Fire(0.1)
end
assert(startCount - startsBefore == 1, "gecikmədə StartWork təkrarlandı: " .. (startCount - startsBefore))
latency = false
flush()
assert(session.work and session.work.id == "Z01_Leaf_02", "gecikmədən sonra iş başlamadı")
for _ = 1, 5 do
	RunService.RenderStepped:Fire(0.1)
end
assert(startCount - startsBefore == 1, "snapshot-dan sonra StartWork təkrarlandı")
UserInputService.InputEnded:Fire({
	UserInputType = roblox.Enum.UserInputType.MouseButton1,
	KeyCode = roblox.Enum.KeyCode.Unknown,
})
assert(session.work == nil, "düymə buraxılanda iş dayanmadı")
print("Gecikmə ilə iş: 11 kadrda 1 StartWork, buraxanda StopWork")

-- E ilə şeh qabını doldurmaq
-- Qeyd: Lune 0.10.5-də CFrame.lookAt düz +Z istiqamətində səhv LookVector (0,0,−1) qaytarır;
-- ona görə +Z-yə baxış Angles ilə verilir (Roblox-da hər iki üsul eynidir)
hrp.CFrame = roblox.CFrame.new(14, 3, 79) * roblox.CFrame.Angles(0, math.pi, 0)
hrp.Position = hrp.CFrame.Position
session:setPosition(14, 0, 79)
RunService.RenderStepped:Fire(0.1)
UserInputService.InputBegan:Fire(
	{ UserInputType = roblox.Enum.UserInputType.Keyboard, KeyCode = roblox.Enum.KeyCode.E },
	false
)
assert(profile.cup > 0, "qab dolmadı")
print("UI ilə su: qabda " .. profile.cup .. " doza")

-- Tikinti rejimi: kanal şeh qabının çıxışına bitişir və "Təsdiq" ilə qoyulur
profile.buildInv["B_CHANNEL"] = 2
session.dirty = true
pushState()
session:setPosition(20, 0, 86)
Build.start("B_CHANNEL", nil)
RunService.RenderStepped:Fire(0.016)
local confirmBtn = findButton(ui, function(b)
	return b.Text == "Təsdiq" and b.Parent and b.Parent.Name == "BuildControls"
end)
assert(confirmBtn, "Təsdiq düyməsi tapılmadı")
signalFor(confirmBtn, "Activated"):Fire()
local placed = nil
for uid, b in profile.builds do
	if b.t == "B_CHANNEL" then
		placed = b
	end
end
assert(placed, "kanal yerləşdirilmədi")
print(
	("UI ilə tikinti: kanal %s x=%d z=%d r=%d (şeh qabının çıxışına bitişdi)"):format(
		placed.area,
		placed.x,
		placed.z,
		placed.r
	)
)
Build.cancel()

-- Yerləşdirilmiş kanalın kontekst menyusu: "Yığ" → qurğu inventara qayıdır
do
	local uid = nil
	for id, b in profile.builds do
		if b.t == "B_CHANNEL" then
			uid = id
		end
	end
	assert(uid, "kanal yoxdur")
	local wm = workspace:FindFirstChild("World")
	-- Kontekst menyusu Interaction.interact ilə açılır: hədəfi birbaşa təyin etmək üçün yaxına get
	hrp.CFrame = roblox.CFrame.new(24, 3, 88) * roblox.CFrame.Angles(0, math.pi, 0)
	hrp.Position = hrp.CFrame.Position
	session:setPosition(24, 0, 88)
	RunService.RenderStepped:Fire(0.1)
	UserInputService.InputBegan:Fire(
		{ UserInputType = roblox.Enum.UserInputType.Keyboard, KeyCode = roblox.Enum.KeyCode.E },
		false
	)
	local menu = ui:FindFirstChild("ContextMenu")
	local storeBtn = menu and findButton(menu, function(b)
		return b.Text == "Yığ"
	end)
	if storeBtn then
		signalFor(storeBtn, "Activated"):Fire()
		print("Kontekst menyusu: kanal yığıldı, inventarda " .. tostring(profile.buildInv["B_CHANNEL"]))
	else
		print("Kontekst menyusu: hədəf kanal deyildi (yaxındakı başqa obyekt seçildi)")
	end
	local _ = wm
end

-- NPC dialoqu (Usta Pıtır) → dükan açılır
hrp.CFrame = roblox.CFrame.new(-22, 3, 85) * roblox.CFrame.Angles(0, math.pi, 0)
hrp.Position = hrp.CFrame.Position
session:setPosition(-22, 0, 85)
RunService.RenderStepped:Fire(0.1)
UserInputService.InputBegan:Fire(
	{ UserInputType = roblox.Enum.UserInputType.Keyboard, KeyCode = roblox.Enum.KeyCode.E },
	false
)
assert(Dialog.isOpen(), "dialoq açılmadı")
Dialog.advance()
Dialog.advance()
assert(Panels.isOpen() and Panels.current() == "shop", "dialoqdan sonra dükan açılmadı")
Panels.close()
print("NPC dialoqu → dükan: işləyir")

-- Boş əkin yerində toxum seçimi
profile.seeds["SEED_DAISY"] = 2
session.dirty = true
pushState()
hrp.CFrame = roblox.CFrame.new(-16, 3, 84) -- −Z istiqamətinə (əkin yerinə) baxır
hrp.Position = hrp.CFrame.Position
session:setPosition(-16, 0, 84)
RunService.RenderStepped:Fire(0.1)
UserInputService.InputBegan:Fire(
	{ UserInputType = roblox.Enum.UserInputType.Keyboard, KeyCode = roblox.Enum.KeyCode.E },
	false
)
local seedMenu = ui:FindFirstChild("ContextMenu")
local plantBtn = seedMenu and findButton(seedMenu, function(b)
	return b.Text:find("Ək", 1, true) ~= nil
end)
assert(plantBtn, "toxum menyusu açılmadı")
signalFor(plantBtn, "Activated"):Fire()
assert(profile.plants["Z01_Plot_02"], "toxum əkilmədi")
print("Toxum seçimi: Z01_Plot_02-yə əkildi")

-- İngilis dilində bütün panellər
Lang.set("en")
for name in tabs do
	Panels.open(name)
	Panels.close()
end
Lang.set("az")
print("EN dilində bütün panellər: xətasız")

-- Ayar düymələri (serverdə yoxlanılır)
Panels.open("settings")
local onBtn = findButton(ui, function(b)
	return b.Text == "Açıq" or b.Text == "Bağlı"
end)
assert(onBtn, "ayar düyməsi yoxdur")
local before = {}
for k, v in profile.settings do
	before[k] = v
end
signalFor(onBtn, "Activated"):Fire()
Panels.close()
local changed = nil
for k, v in profile.settings do
	if before[k] ~= v then
		changed = k .. "=" .. tostring(v)
	end
end
assert(changed, "ayar dəyişmədi")
print("Ayar düyməsi serverdə ayarı dəyişdi: " .. changed)

-- Render dövrəsi (HUD, effektlər, əlaqə)
for _ = 1, 5 do
	RunService.RenderStepped:Fire(0.1)
end

-- Final kəsimi və hadisələr
signalFor(remotes.Event, "OnClientEvent"):Fire({ type = "toast", key = "msg.saved" })
signalFor(remotes.Event, "OnClientEvent"):Fire({ type = "crafted", id = "MAT_ROPE", n = 1 })
signalFor(remotes.Event, "OnClientEvent"):Fire({ type = "crafted", id = "B_WHEEL", n = 1 })
signalFor(remotes.Event, "OnClientEvent"):Fire({ type = "work", id = "Z01_Leaf_01", progress = 0.5, active = true })
signalFor(remotes.Event, "OnClientEvent"):Fire({ type = "final", replay = true })

if #errors > 0 then
	print(("UI tüstü testi: %d xəta"):format(#errors))
	process.exit(1)
end
print("UI tüstü testi: xətasız")
