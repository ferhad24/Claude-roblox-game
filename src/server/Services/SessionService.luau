--!strict
-- Oyunçu sessiyası: Remote sorğuları, oyun vaxtı, hadisələrin dünyaya və UI-yə ötürülməsi,
-- yaddaş (avtomatik save, çıxışda save, BindToClose), təhlükəsiz nöqtəyə qaytarma.
-- Oyun təknəfərlikdir (MaxPlayers=1 platformada ayrıca qurulur); ikinci oyunçu qəbul edilmir.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Layout = require(Shared.Layout)
local QuestDefs = require(Shared.Defs.QuestDefs)
local Game = require(Shared.Core.Game)
local PlayerDataService = require(script.Parent.PlayerDataService)
local WorldService = require(script.Parent.WorldService)
local Telemetry = require(script.Parent.Telemetry)
local ProfileStore = require(script.Parent.Parent.ProfileStore)
local CharacterLook = require(script.Parent.CharacterLook)

local SessionService = {}

type Active = {
	player: Player,
	game: Game.Session,
	store: ProfileStore.Session,
	tickAcc: number,
	snapshotAcc: number,
	sourceAcc: number,
	safeAcc: number,
	saveAcc: number,
	saveSoonAt: number?,
	lastSafe: Vector3?,
	saving: boolean,
	closed: boolean,
}

local remotes: Folder
local actionRemote: RemoteEvent
local resultRemote: RemoteEvent
local stateRemote: RemoteEvent
local eventRemote: RemoteEvent
local sessionRemote: RemoteEvent
local active: Active? = nil
local loadingPlayer: Player? = nil

local TICK = 0.1
local SNAPSHOT_INTERVAL = 0.25
local CRITICAL_SAVE_DELAY = 8
-- Buraxılış save-i gedən save-i ən çox bu qədər gözləyir; BindToClose isə bütün yazıları
-- (Roblox ~30 s verir) ehtiyatla 25 s-ə qədər gözləyir
local SAVE_QUEUE_WAIT = 20
local CLOSE_WAIT = 25
local RESPAWN_DELAY = 2

-- Hazırda gedən DataStore yazıları (save və kilid buraxılması). BindToClose bunlar bitənə qədər
-- qayıtmır, yoxsa server bağlanar və son save/kilid buraxılması itər.
local pendingWrites = 0

-- Client-ə göndərilən hadisələr (qalanları yalnız serverdə dünyanı dəyişir)
local CLIENT_EVENTS = {
	toast = true,
	dialog = true,
	open = true,
	final = true,
	level = true,
	zone = true,
	chapter = true,
	step = true,
	side = true,
	achievement = true,
	paused = true,
	rain = true,
	cargo = true,
	work = true,
	teleport = true,
	bought = true,
	crafted = true,
	water = true,
}

local function makeRemote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end

local function root(player: Player): BasePart?
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end
	return nil
end

local function teleport(player: Player, pos: { number })
	local char = player.Character
	if char then
		char:PivotTo(CFrame.new(pos[1], pos[2] + 3, pos[3]))
	end
end

local function inWater(position: Vector3): boolean
	for _, part in CollectionService:GetTagged("TG_Water") do
		if part:IsA("BasePart") then
			local localPos = part.CFrame:PointToObjectSpace(position)
			local half = part.Size / 2
			if
				math.abs(localPos.X) <= half.X
				and math.abs(localPos.Y) <= half.Y + 2
				and math.abs(localPos.Z) <= half.Z
			then
				return true
			end
		end
	end
	return false
end

-- Ayaq altında bərk, su olmayan səth varmı (server özü yoxlayır; client-in FloorMaterial-ına güvənmir)
local function onSolidGround(char: Model, pos: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	params.RespectCanCollide = true
	local hit = workspace:Raycast(pos, Vector3.new(0, -6, 0), params)
	return hit ~= nil and not CollectionService:HasTag(hit.Instance, "TG_Water")
end

local function requestSave(a: Active, delay: number)
	local at = os.clock() + delay
	if not a.saveSoonAt or at < a.saveSoonAt then
		a.saveSoonAt = at
	end
end

local function doSave(a: Active, release: boolean)
	if a.saving and not release then
		return
	end
	pendingWrites += 1
	-- Save-lər ardıcıldır: eyni revision ilə iki paralel yazı birini "revision" xətası ilə rədd etdirərdi
	-- (buraxılış save-i itər və kilid 'SESSION_LOCK_SECONDS' qədər qalardı)
	local deadline = os.clock() + SAVE_QUEUE_WAIT
	while a.saving and os.clock() < deadline do
		task.wait(0.1)
	end
	a.saving = true
	local called, result, reason = pcall(PlayerDataService.save, a.store, release)
	a.saving = false
	pendingWrites -= 1
	local ok = called and result == true
	local why = if called then reason else tostring(result)
	if not ok then
		warn(("[TinyGrove] save alınmadı (%s)"):format(tostring(why)))
		Telemetry.log(a.player, "save_error", tostring(why), a.game.profile.playSeconds)
		if a.player.Parent then
			eventRemote:FireClient(a.player, { type = "toast", key = "msg.saveError" })
		end
	end
end

local function applyLook(a: Active)
	local char = a.player.Character
	if char then
		CharacterLook.apply(char, a.game.profile.settings, a.game:power())
	end
end

local function processEvents(a: Active)
	local events = a.game:drainEvents()
	local p = a.game.profile
	for _, e in events do
		WorldService.handleEvent(e, p)
		local t = e.type
		if t == "teleport" then
			teleport(a.player, e.pos)
		elseif t == "step" then
			Telemetry.log(a.player, "quest_completed", e.id, p.playSeconds)
			if QuestDefs.stepChapter[e.id] == 1 then
				Telemetry.log(a.player, "tutorial_step", e.id, p.playSeconds)
			end
		elseif t == "chapter" then
			local ch = QuestDefs.chapters[e.n]
			Telemetry.log(a.player, "zone_restored", ch and ch.zone or nil, p.playSeconds)
			requestSave(a, CRITICAL_SAVE_DELAY)
		elseif t == "bought" then
			Telemetry.log(a.player, "purchase", e.id, p.playSeconds)
			requestSave(a, CRITICAL_SAVE_DELAY * 2)
		elseif t == "crafted" then
			Telemetry.log(a.player, "recipe_crafted", e.id, p.playSeconds)
		elseif t == "work" and e.done then
			local obj = Layout.byId[e.id]
			Telemetry.log(a.player, "work_completed", obj and (obj.def or obj.id) or e.id, p.playSeconds)
		elseif t == "pref" and (e.key == "skin" or e.key == "outfit") then
			applyLook(a)
		elseif t == "level" and e.n >= Constants.POWER_MAX then
			applyLook(a)
		elseif t == "final" and not e.replay then
			Telemetry.log(a.player, "final_completed", nil, p.playSeconds)
			requestSave(a, 1)
		end
		if CLIENT_EVENTS[t] then
			eventRemote:FireClient(a.player, e)
		end
	end
end

local function pushSnapshot(a: Active)
	if a.game.dirty then
		a.game.dirty = false
		stateRemote:FireClient(a.player, a.game:snapshot())
	end
end

local function onAction(player: Player, action: any, payload: any)
	local a = active
	if not a or a.player ~= player or a.closed then
		return
	end
	if type(payload) ~= "table" then
		return
	end
	local rid = payload.rid
	local result = a.game:handle(action, payload, os.clock())
	if rid ~= nil and (type(rid) == "number" or type(rid) == "string") then
		resultRemote:FireClient(
			player,
			rid,
			{ ok = result.ok, err = result.err, params = result.params, data = result.data }
		)
	elseif not result.ok and result.err then
		eventRemote:FireClient(player, { type = "toast", key = result.err, params = result.params, error = true })
	end
	processEvents(a)
	pushSnapshot(a)
end

local function spawnCharacter(player: Player)
	player:LoadCharacter()
	local spawn = Layout.zoneLayout["Z01"].safeSpawn
	teleport(player, spawn)
end

local function startSession(player: Player)
	loadingPlayer = player
	sessionRemote:FireClient(player, { status = "loading" })
	local storeSession, why = PlayerDataService.load(player)
	loadingPlayer = nil
	if not player.Parent then
		if storeSession then
			pendingWrites += 1
			pcall(PlayerDataService.release, storeSession)
			pendingWrites -= 1
		end
		return
	end
	if not storeSession then
		warn("[TinyGrove] profil yüklənmədi: " .. tostring(why))
		Telemetry.log(player, "save_error", "load:" .. tostring(why), 0)
		sessionRemote:FireClient(player, { status = "failed", reason = why })
		return
	end
	local session = Game.new(storeSession.profile)
	-- Başlanğıc ekranında vaxt keçmir: oyunçu "Başla/Davam et" basanda pauza açılır
	session:setPaused(true)
	session:drainEvents()
	local a: Active = {
		player = player,
		game = session,
		store = storeSession,
		tickAcc = 0,
		snapshotAcc = 0,
		sourceAcc = 0,
		safeAcc = 0,
		saveAcc = 0,
		saveSoonAt = nil,
		lastSafe = nil,
		saving = false,
		closed = false,
	}
	active = a
	WorldService.applyAll(session.profile)
	player.CharacterAdded:Connect(function(char: Model)
		-- CharacterAutoLoads=false: personaj ölərsə (məs. Esc → Reset) özümüz yenidən yaradırıq
		local humanoid = char:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				task.delay(RESPAWN_DELAY, function()
					if active == a and not a.closed and player.Parent and player.Character == char then
						player:LoadCharacter()
					end
				end)
			end)
		end
		char:WaitForChild("Head", 10)
		applyLook(a)
		task.defer(function()
			local target = a.lastSafe
			if target then
				teleport(player, { target.X, target.Y, target.Z })
			end
		end)
	end)
	spawnCharacter(player)
	sessionRemote:FireClient(player, {
		status = "ready",
		testMode = PlayerDataService.isTestMode(),
		isNew = session.profile.playSeconds < 1,
	})
	session.dirty = true
	pushSnapshot(a)
end

local function endSession(player: Player)
	local a = active
	if not a or a.player ~= player then
		return
	end
	a.closed = true
	a.game:stopWork()
	active = nil
	doSave(a, true)
end

local function heartbeat(dt: number)
	local a = active
	if not a or a.closed then
		return
	end
	local hrp = root(a.player)
	if hrp then
		local pos = hrp.Position
		a.game:setPosition(pos.X, pos.Y, pos.Z)
		-- Suya düşəndə və ya xəritədən çıxanda son təhlükəsiz nöqtəyə itkisiz qaytarma
		a.safeAcc += dt
		if a.safeAcc >= 0.25 then
			a.safeAcc = 0
			local char = a.player.Character
			local wet = inWater(pos)
			if wet or pos.Y < -30 then
				local target = a.lastSafe or Vector3.new(table.unpack(Layout.zoneLayout["Z01"].safeSpawn))
				teleport(a.player, { target.X, target.Y, target.Z })
			elseif char and onSolidGround(char, pos) then
				a.lastSafe = pos
			end
		end
	end
	a.tickAcc += dt
	while a.tickAcc >= TICK do
		a.tickAcc -= TICK
		a.game:tick(TICK)
	end
	processEvents(a)
	a.sourceAcc += dt
	if a.sourceAcc >= 1 then
		a.sourceAcc = 0
		WorldService.refreshSources(a.game.profile)
	end
	a.snapshotAcc += dt
	if a.snapshotAcc >= SNAPSHOT_INTERVAL then
		a.snapshotAcc = 0
		pushSnapshot(a)
	end
	-- Avtomatik save (request budget-ə uyğun)
	a.saveAcc += dt
	local due = a.saveAcc >= Constants.AUTOSAVE_SECONDS
		or (a.saveSoonAt ~= nil and os.clock() >= (a.saveSoonAt :: number))
	if due and not a.saving and PlayerDataService.budgetOk() then
		a.saveAcc = 0
		a.saveSoonAt = nil
		task.spawn(doSave, a, false)
	end
end

function SessionService.init()
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	actionRemote = makeRemote("Action")
	resultRemote = makeRemote("Result")
	stateRemote = makeRemote("State")
	eventRemote = makeRemote("Event")
	sessionRemote = makeRemote("Session")
	remotes.Parent = ReplicatedStorage

	actionRemote.OnServerEvent:Connect(onAction)
	sessionRemote.OnServerEvent:Connect(function(player: Player, msg: any)
		if type(msg) ~= "table" then
			return
		end
		if msg.op == "retry" and active == nil and loadingPlayer == nil then
			startSession(player)
		elseif msg.op == "hello" then
			-- Client hazırdır: cari vəziyyəti yenidən göndər
			local a = active
			if a and a.player == player then
				sessionRemote:FireClient(player, {
					status = "ready",
					testMode = PlayerDataService.isTestMode(),
					isNew = a.game.profile.playSeconds < 1,
				})
				a.game.dirty = true
				pushSnapshot(a)
			elseif loadingPlayer == player then
				sessionRemote:FireClient(player, { status = "loading" })
			end
		end
	end)

	Players.PlayerAdded:Connect(function(player: Player)
		if active ~= nil or loadingPlayer ~= nil then
			player:Kick("TINY GROVE təknəfərlik oyundur.")
			return
		end
		task.spawn(startSession, player)
	end)
	for _, player in Players:GetPlayers() do
		if active == nil and loadingPlayer == nil then
			task.spawn(startSession, player)
		end
	end
	Players.PlayerRemoving:Connect(endSession)
	RunService.Heartbeat:Connect(heartbeat)
	game:BindToClose(function()
		local a = active
		if a then
			a.closed = true
			a.game:stopWork()
			active = nil
			doSave(a, true)
		end
		-- PlayerRemoving-də başlamış save/kilid buraxılması hələ gedə bilər: bitməsini gözlə
		local deadline = os.clock() + CLOSE_WAIT
		while pendingWrites > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return SessionService
