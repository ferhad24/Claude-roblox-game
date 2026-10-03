--!strict
-- Oyunçu profilinin sxemi, yeni profil, miqrasiya və təmizləmə (bölmə 20 "Yaddaş sxemi").
-- Instance-lər, event connection-lar və render effektləri yaddaşa yazılmır.
local Shared = script.Parent.Parent
local Types = require(Shared.Types)
local Constants = require(Shared.Constants)
local ToolDefs = require(Shared.Defs.ToolDefs)
local Layout = require(Shared.Layout)

type Profile = Types.Profile

local Profile = {}

local function defaultSettings(): { [string]: any }
	return {
		lang = "az",
		music = 0.6,
		sfx = 0.8,
		camSens = 1,
		reducedMotion = false,
		cameraShake = false,
		quality = "auto",
		textSize = 1,
		markers = true,
		rainFx = true,
		skin = 2,
		outfit = 1,
	}
end

function Profile.new(now: number): Profile
	local tools: { [string]: boolean } = {}
	for _, id in ToolDefs.starting do
		tools[id] = true
	end
	local p: Profile = {
		schemaVersion = Constants.SCHEMA_VERSION,
		createdAt = now,
		coins = 0,
		workXP = 0,
		mastery = {
			hand = { marks = 0, level = 0 },
			botany = { marks = 0, level = 0 },
			mech = { marks = 0, level = 0 },
		},
		tools = tools,
		equipped = "TOOL_GLOVES_1",
		hotbar = { "TOOL_GLOVES_1", "TOOL_CUP_1" },
		bagCapacity = Constants.BAG_START,
		bag = {},
		pending = {},
		storage = {},
		campaign = {},
		seeds = {},
		buildInv = {},
		cup = 0,
		homeWater = 0,
		cargo = {},
		groups = {},
		quest = { chapter = 1, step = 1, done = {}, side = {} },
		oneTimeRewards = {},
		zones = { Z01 = true },
		restoredObjectIds = {},
		workProgress = {},
		interacted = {},
		builds = {},
		nextBuildId = 1,
		waterSources = {},
		waterRegen = {},
		moisture = {},
		plants = {},
		respawn = {},
		memories = {},
		achievements = {},
		stats = {
			crafted = {},
			harvested = {},
			planted = 0,
			lineDelivered = {},
			cargoDelivered = {},
			wheelZones = {},
			dosesByLine = 0,
			works = 0,
		},
		orders = { offers = {}, active = nil, seed = 12345, completed = 0 },
		settings = defaultSettings(),
		playSeconds = 0,
		dayTime = 6 * 60, -- səhər
		rain = { next = Constants.DAY_LENGTH * 2, untilT = 0 },
		finalCompleted = false,
		finalWatched = 0,
	}
	-- İlk toxum əvvəlcədən əkilib (bölmə 4: "ilk toxumu sulayır")
	for _, obj in Layout.objects do
		local extra = obj.extra
		if obj.kind == "plot" and extra and extra.preplant then
			p.plants[obj.id] = { sp = extra.preplant :: string, g = 0, m = 0, ready = false }
		end
	end
	-- Mənbələr dolu başlayır
	for _, obj in Layout.objects do
		if obj.kind == "source" then
			p.waterSources[obj.id] = obj.capacity or 12
		end
	end
	return p
end

-- Miqrasiyalar: versiya N → N+1. v0 yalnız test üçün nümunə formatıdır (bax: tests/profile.spec.luau).
local MIGRATIONS: { [number]: (any) -> any } = {
	[0] = function(old: any): any
		-- v0: "stamps" → coins, "inv" → bag, "xp" → workXP
		old.coins = old.coins or old.stamps or 0
		old.stamps = nil
		old.bag = old.bag or old.inv or {}
		old.inv = nil
		old.workXP = old.workXP or old.xp or 0
		old.xp = nil
		old.schemaVersion = 1
		return old
	end,
}
Profile.MIGRATIONS = MIGRATIONS

local function isFiniteNumber(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function sanitizeCountMap(map: any, allowed: ((string) -> boolean)?): { [string]: number }
	local out: { [string]: number } = {}
	if type(map) ~= "table" then
		return out
	end
	for k, v in map do
		if type(k) == "string" and isFiniteNumber(v) and v > 0 and (not allowed or allowed(k)) then
			out[k] = math.floor(v)
		end
	end
	return out
end

local function sanitizeFlagMap(map: any): { [string]: boolean }
	local out: { [string]: boolean } = {}
	if type(map) ~= "table" then
		return out
	end
	for k, v in map do
		if type(k) == "string" and v == true then
			out[k] = true
		end
	end
	return out
end

-- Köhnə və ya natamam profili cari sxemə gətirir. Uyğun gəlməyən save üçün nil + səbəb qaytarır.
function Profile.migrate(data: any, now: number): (Profile?, string?)
	if type(data) ~= "table" then
		return nil, "not_a_table"
	end
	local version = data.schemaVersion
	if version == nil then
		version = 0
	end
	if not isFiniteNumber(version) or version % 1 ~= 0 or version < 0 then
		return nil, "bad_version"
	end
	if version > Constants.SCHEMA_VERSION then
		-- Gələcək versiyada yazılmış save: üzərinə yazmamaq üçün rədd edilir
		return nil, "future_version"
	end
	while version < Constants.SCHEMA_VERSION do
		local step = MIGRATIONS[version]
		if not step then
			return nil, "no_migration_" .. tostring(version)
		end
		local ok, result = pcall(step, data)
		if not ok or type(result) ~= "table" then
			return nil, "migration_failed_" .. tostring(version)
		end
		data = result
		version = data.schemaVersion
		if type(version) ~= "number" then
			return nil, "migration_no_version"
		end
	end

	-- Çatışmayan sahələri doldur, tipləri yoxla
	local base = Profile.new(isFiniteNumber(data.createdAt) and data.createdAt or now)
	local p = base
	if isFiniteNumber(data.coins) and data.coins >= 0 then
		p.coins = math.floor(data.coins)
	end
	if isFiniteNumber(data.workXP) and data.workXP >= 0 then
		p.workXP = math.floor(data.workXP)
	end
	if type(data.mastery) == "table" then
		for _, branch in { "hand", "botany", "mech" } do
			local m = data.mastery[branch]
			if type(m) == "table" and isFiniteNumber(m.marks) and m.marks >= 0 then
				(p.mastery :: any)[branch].marks = math.floor(m.marks)
			end
		end
	end
	if type(data.tools) == "table" then
		for id, v in data.tools do
			if v == true and ToolDefs.byId[id] then
				p.tools[id] = true
			end
		end
	end
	if type(data.equipped) == "string" and p.tools[data.equipped] then
		p.equipped = data.equipped
	end
	if type(data.hotbar) == "table" then
		local hb = {}
		for _, id in data.hotbar do
			if type(id) == "string" and p.tools[id] and #hb < 4 then
				table.insert(hb, id)
			end
		end
		p.hotbar = hb
	end
	if isFiniteNumber(data.bagCapacity) then
		p.bagCapacity = math.clamp(math.floor(data.bagCapacity), Constants.BAG_START, 36)
	end
	p.bag = sanitizeCountMap(data.bag)
	p.pending = sanitizeCountMap(data.pending)
	p.storage = sanitizeCountMap(data.storage)
	p.campaign = sanitizeCountMap(data.campaign)
	p.seeds = sanitizeCountMap(data.seeds)
	p.buildInv = sanitizeCountMap(data.buildInv)
	p.cargo = sanitizeCountMap(data.cargo)
	if isFiniteNumber(data.cup) and data.cup >= 0 then
		p.cup = math.floor(data.cup)
	end
	if isFiniteNumber(data.homeWater) and data.homeWater >= 0 then
		p.homeWater = math.min(math.floor(data.homeWater), Constants.HOME_WATER_CAPACITY)
	end
	p.groups = sanitizeFlagMap(data.groups)
	if type(data.quest) == "table" then
		local q = data.quest
		if isFiniteNumber(q.chapter) and isFiniteNumber(q.step) then
			p.quest.chapter = math.clamp(math.floor(q.chapter), 1, 7)
			p.quest.step = math.max(1, math.floor(q.step))
		end
		p.quest.done = sanitizeFlagMap(q.done)
		p.quest.side = sanitizeFlagMap(q.side)
	end
	p.oneTimeRewards = sanitizeFlagMap(data.oneTimeRewards)
	local zones = sanitizeFlagMap(data.zones)
	zones.Z01 = true
	p.zones = zones
	p.restoredObjectIds = sanitizeFlagMap(data.restoredObjectIds)
	if type(data.workProgress) == "table" then
		for id, v in data.workProgress do
			if type(id) == "string" and isFiniteNumber(v) and v > 0 then
				p.workProgress[id] = v
			end
		end
	end
	p.interacted = sanitizeFlagMap(data.interacted)
	if type(data.builds) == "table" then
		for uid, b in data.builds do
			if
				type(uid) == "string"
				and type(b) == "table"
				and type(b.t) == "string"
				and isFiniteNumber(b.x)
				and isFiniteNumber(b.z)
			then
				p.builds[uid] = {
					t = b.t,
					area = type(b.area) == "string" and b.area or nil,
					socket = type(b.socket) == "string" and b.socket or nil,
					x = math.floor(b.x),
					z = math.floor(b.z),
					r = isFiniteNumber(b.r) and (math.floor(b.r) % 4) or 0,
					v = type(b.v) == "string" and b.v or nil,
					w = isFiniteNumber(b.w) and math.max(0, math.floor(b.w)) or nil,
					c = isFiniteNumber(b.c) and b.c or nil,
					rt = isFiniteNumber(b.rt) and b.rt or nil,
				}
			end
		end
	end
	if isFiniteNumber(data.nextBuildId) and data.nextBuildId >= 1 then
		p.nextBuildId = math.floor(data.nextBuildId)
	end
	if type(data.waterSources) == "table" then
		for id, v in data.waterSources do
			if type(id) == "string" and isFiniteNumber(v) and v >= 0 then
				p.waterSources[id] = math.floor(v)
			end
		end
	end
	if type(data.waterRegen) == "table" then
		for id, v in data.waterRegen do
			if type(id) == "string" and isFiniteNumber(v) then
				p.waterRegen[id] = v
			end
		end
	end
	if type(data.moisture) == "table" then
		for id, v in data.moisture do
			if type(id) == "string" and isFiniteNumber(v) then
				p.moisture[id] = math.clamp(v, 0, Constants.MOISTURE_MAX)
			end
		end
	end
	if type(data.plants) == "table" then
		p.plants = {}
		for slot, st in data.plants do
			if type(slot) == "string" and type(st) == "table" and type(st.sp) == "string" then
				p.plants[slot] = {
					sp = st.sp,
					g = isFiniteNumber(st.g) and math.max(0, st.g) or 0,
					m = isFiniteNumber(st.m) and math.clamp(st.m, 0, Constants.MOISTURE_MAX) or 0,
					ready = st.ready == true,
					md = isFiniteNumber(st.md) and st.md or nil,
				}
			end
		end
	end
	if type(data.respawn) == "table" then
		for id, v in data.respawn do
			if type(id) == "string" and isFiniteNumber(v) then
				p.respawn[id] = v
			end
		end
	end
	p.memories = sanitizeFlagMap(data.memories)
	p.achievements = sanitizeFlagMap(data.achievements)
	if type(data.stats) == "table" then
		local s = data.stats
		p.stats.crafted = sanitizeCountMap(s.crafted)
		p.stats.harvested = sanitizeCountMap(s.harvested)
		p.stats.lineDelivered = sanitizeCountMap(s.lineDelivered)
		p.stats.cargoDelivered = sanitizeCountMap(s.cargoDelivered)
		p.stats.wheelZones = sanitizeFlagMap(s.wheelZones)
		if isFiniteNumber(s.planted) then
			p.stats.planted = math.floor(s.planted)
		end
		if isFiniteNumber(s.dosesByLine) then
			p.stats.dosesByLine = math.floor(s.dosesByLine)
		end
		if isFiniteNumber(s.works) then
			p.stats.works = math.floor(s.works)
		end
	end
	if type(data.orders) == "table" then
		local o = data.orders
		local offers = {}
		if type(o.offers) == "table" then
			for _, id in o.offers do
				if type(id) == "string" and #offers < 3 then
					table.insert(offers, id)
				end
			end
		end
		p.orders.offers = offers
		p.orders.active = type(o.active) == "string" and o.active or nil
		if isFiniteNumber(o.seed) then
			p.orders.seed = math.floor(o.seed)
		end
		if isFiniteNumber(o.completed) then
			p.orders.completed = math.floor(o.completed)
		end
	end
	if type(data.settings) == "table" then
		for k, v in data.settings do
			if p.settings[k] ~= nil and type(v) == type(p.settings[k]) then
				p.settings[k] = v
			end
		end
	end
	if isFiniteNumber(data.playSeconds) and data.playSeconds >= 0 then
		p.playSeconds = data.playSeconds
	end
	if isFiniteNumber(data.dayTime) then
		p.dayTime = data.dayTime % Constants.DAY_LENGTH
	end
	if type(data.rain) == "table" and isFiniteNumber(data.rain.next) and isFiniteNumber(data.rain.untilT) then
		p.rain = { next = data.rain.next, untilT = data.rain.untilT }
	end
	p.finalCompleted = data.finalCompleted == true
	if isFiniteNumber(data.finalWatched) then
		p.finalWatched = math.floor(data.finalWatched)
	end
	p.schemaVersion = Constants.SCHEMA_VERSION
	return p, nil
end

-- Dərin surət (save üçün snapshot və testlər)
function Profile.clone<T>(v: T): T
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v :: any do
		out[k] = Profile.clone(x)
	end
	return out :: any
end

return Profile
