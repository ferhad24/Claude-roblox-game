--!strict
-- Bir oyunçunun oyun sessiyası: bütün mexanika burada, server tərəfdə işləyir.
-- Roblox API-dən asılı deyil: adapter (ServerScriptService) mövqeyi, vaxtı və sorğuları ötürür,
-- hadisələri (events) dünyaya və UI-yə çevirir. Client heç vaxt qiymət, mükafat, XP, rütubət
-- və ya hazır iş nəticəsi göndərmir; hamısı kataloqdan burada hesablanır.
local Shared = script.Parent.Parent
local Types = require(Shared.Types)
local Constants = require(Shared.Constants)
local ItemDefs = require(Shared.Defs.ItemDefs)
local ToolDefs = require(Shared.Defs.ToolDefs)
local WorkDefs = require(Shared.Defs.WorkDefs)
local BuildDefs = require(Shared.Defs.BuildDefs)
local RecipeDefs = require(Shared.Defs.RecipeDefs)
local PlantDefs = require(Shared.Defs.PlantDefs)
local ShopDefs = require(Shared.Defs.ShopDefs)
local ZoneDefs = require(Shared.Defs.ZoneDefs)
local QuestDefs = require(Shared.Defs.QuestDefs)
local NpcDefs = require(Shared.Defs.NpcDefs)
local Layout = require(Shared.Layout)
local Progression = require(script.Parent.Progression)
local Conditions = require(script.Parent.Conditions)
local Inventory = require(script.Parent.Inventory)
local Placement = require(script.Parent.Placement)
local Water = require(script.Parent.Water)

type Profile = Types.Profile
type WorkDef = Types.WorkDef
type ToolDef = Types.ToolDef
type Objective = Types.Objective
type PlacedBuild = Types.PlacedBuild
type LayoutObject = Types.LayoutObject

export type Event = { type: string, [string]: any }
export type Result = { ok: boolean, err: string?, params: { [string]: any }?, data: any?, dup: boolean? }

type WorkSession = {
	id: string,
	def: WorkDef,
	tool: string,
	rate: number,
	progress: number,
	spot: boolean,
}

local Game = {}
Game.__index = Game

export type Session = typeof(setmetatable(
	{} :: {
		profile: Profile,
		paused: boolean,
		work: WorkSession?,
		events: { Event },
		graph: Water.Graph?,
		pos: { number }?,
		waterAcc: number,
		decayAcc: number,
		ridCache: { [string]: Result },
		ridOrder: { string },
		rate: { [string]: { number } },
		dirty: boolean,
		raining: boolean,
	},
	Game
))

local function ok(data: any?): Result
	return { ok = true, data = data }
end

local function fail(err: string, params: { [string]: any }?): Result
	return { ok = false, err = err, params = params }
end

local function isFinite(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function isId(v: any): boolean
	return type(v) == "string" and #v > 0 and #v <= 64
end

------------------------------------------------------------------------------------------
-- Yaradılma
------------------------------------------------------------------------------------------

function Game.new(profile: Profile): Session
	local self = setmetatable({
		profile = profile,
		paused = false,
		work = nil,
		events = {},
		graph = nil,
		pos = nil,
		waterAcc = 0,
		decayAcc = 0,
		ridCache = {},
		ridOrder = {},
		rate = {},
		dirty = true,
		raining = profile.rain.untilT > profile.playSeconds,
	}, Game)
	self:afterChange()
	return self
end

function Game.emit(self: Session, kind: string, data: { [string]: any }?)
	local e: Event = { type = kind }
	if data then
		for k, v in data do
			e[k] = v
		end
	end
	table.insert(self.events, e)
end

function Game.toast(self: Session, key: string, params: { [string]: any }?)
	self:emit("toast", { key = key, params = params })
end

function Game.drainEvents(self: Session): { Event }
	local list = self.events
	self.events = {}
	return list
end

function Game.setPosition(self: Session, x: number, y: number, z: number)
	if isFinite(x) and isFinite(y) and isFinite(z) then
		self.pos = { x, y, z }
	end
end

function Game.power(self: Session): number
	return Progression.levelFor(self.profile.workXP)
end

function Game.getGraph(self: Session): Water.Graph
	local g = self.graph
	if not g then
		g = Water.build(self.profile)
		self.graph = g
	end
	return g :: Water.Graph
end

function Game.invalidateGraph(self: Session)
	self.graph = nil
end

------------------------------------------------------------------------------------------
-- Köməkçilər
------------------------------------------------------------------------------------------

-- Obyektin footprint-inə üfüqi məsafə (böyük obyektlərdə mərkəzə yox, kənara ölçülür)
function Game.distanceToObject(self: Session, obj: LayoutObject): number
	local pos = self.pos
	if not pos then
		return math.huge
	end
	if math.abs(pos[2] - obj.pos[2]) > 14 then
		return math.huge
	end
	local size = Layout.sizeOf(obj)
	local hx, hz = size[1] / 2, size[3] / 2
	local dx = math.max(0, math.abs(pos[1] - obj.pos[1]) - hx)
	local dz = math.max(0, math.abs(pos[3] - obj.pos[3]) - hz)
	return math.sqrt(dx * dx + dz * dz)
end

function Game.distanceToBuild(self: Session, b: PlacedBuild): number
	local pos = self.pos
	local c = Placement.worldCenter(b)
	if not pos or not c then
		return math.huge
	end
	if math.abs(pos[2] - c[2]) > 14 then
		return math.huge
	end
	local def = BuildDefs.byId[b.t]
	local rect = Placement.footprintRect(def, c, b.r, b.v)
	local dx = math.max(0, rect.x0 - pos[1], pos[1] - rect.x1)
	local dz = math.max(0, rect.z0 - pos[3], pos[3] - rect.z1)
	return math.sqrt(dx * dx + dz * dz)
end

function Game.zoneOpen(self: Session, zone: string): boolean
	return self.profile.zones[zone] == true
end

function Game.bestTool(self: Session, workType: string): (ToolDef?, number)
	local best: ToolDef? = nil
	local bestRate = 0
	for id in self.profile.tools do
		local t = ToolDefs.byId[id]
		local r = t and (t.rates :: any)[workType]
		if t and r and r > bestRate then
			best, bestRate = t, r
		end
	end
	return best, bestRate
end

function Game.ownsToolOrBetter(self: Session, toolId: string): boolean
	local def = ToolDefs.byId[toolId]
	if not def then
		return false
	end
	for id in self.profile.tools do
		local t = ToolDefs.byId[id]
		if t and t.family == def.family and t.tier >= def.tier then
			return true
		end
	end
	return false
end

function Game.cupSpec(self: Session): Types.CupSpec
	local best: Types.CupSpec = { capacity = 0, spread = 1, spreadRadius = 0 }
	for id in self.profile.tools do
		local t = ToolDefs.byId[id]
		if t and t.cup and t.cup.capacity > best.capacity then
			best = t.cup
		end
	end
	return best
end

function Game.addCoins(self: Session, n: number)
	self.profile.coins += n
end

function Game.addXp(self: Session, n: number)
	local before = self:power()
	self.profile.workXP += n
	local after = self:power()
	if after > before then
		self:emit("level", { n = after })
		self:toast("msg.powerUp", { n = after })
	end
end

function Game.addMark(self: Session, branch: string)
	local m = (self.profile.mastery :: any)[branch]
	if not m then
		return
	end
	local before = Progression.masteryLevel(m.marks)
	m.marks += 1
	m.level = Progression.masteryLevel(m.marks)
	if m.level > before then
		local nameKey = branch == "hand" and "ui.masteryHand"
			or branch == "botany" and "ui.masteryBotany"
			or "ui.masteryMech"
		self:toast("msg.masteryUp", { name = nameKey, n = m.level })
	end
end

function Game.masteryLevel(self: Session, branch: string): number
	local m = (self.profile.mastery :: any)[branch]
	return m and Progression.masteryLevel(m.marks) or 0
end

function Game.giveItems(self: Session, list: { Types.Amount })
	local overflow = false
	for _, a in list do
		local item = ItemDefs.byId[a.id]
		if item and item.category == "material" then
			local _, rest = Inventory.addToBag(self.profile, a.id, a.n)
			if rest > 0 then
				overflow = true
			end
		elseif item and (item.category == "campaign" or item.category == "memory") then
			self.profile.campaign[a.id] = (self.profile.campaign[a.id] or 0) + a.n
		elseif item and item.category == "seed" then
			self.profile.seeds[a.id] = math.min(Constants.SEED_STACK_MAX, (self.profile.seeds[a.id] or 0) + a.n)
		elseif BuildDefs.byId[a.id] then
			self.profile.buildInv[a.id] = (self.profile.buildInv[a.id] or 0) + a.n
		end
		self:toast("msg.got", {
			n = a.n,
			name = (item and item.nameKey) or (BuildDefs.byId[a.id] and BuildDefs.byId[a.id].nameKey) or a.id,
		})
	end
	if overflow then
		self:toast("msg.bagFull")
	end
end

------------------------------------------------------------------------------------------
-- Sahələr, qruplar, tapşırıqlar, nailiyyətlər
------------------------------------------------------------------------------------------

function Game.refreshZones(self: Session)
	local p = self.profile
	for _, z in ZoneDefs.list do
		if not p.zones[z.id] and Conditions.check(p, z.unlock) then
			p.zones[z.id] = true
			self:invalidateGraph()
			self:emit("zone", { id = z.id })
			self:toast("msg.zoneOpen", { name = z.nameKey })
		end
	end
end

function Game.refreshGroups(self: Session)
	local p = self.profile
	for _, g in RecipeDefs.groups do
		if g.free and not p.groups[g.id] and Conditions.check(p, g.unlock) then
			p.groups[g.id] = true
		end
	end
end

function Game.objectiveProgress(self: Session, o: Objective): (number, number)
	local p = self.profile
	if o.type == "restore" then
		local n = 0
		for _, id in o.ids do
			if p.restoredObjectIds[id] then
				n += 1
			end
		end
		return n, #o.ids
	elseif o.type == "fillCup" then
		return (p.interacted["fill"] and 1 or 0), 1
	elseif o.type == "water" then
		return (p.interacted["w:" .. o.id] and 1 or 0), 1
	elseif o.type == "ownTool" then
		return (self:ownsToolOrBetter(o.tool) and 1 or 0), 1
	elseif o.type == "interact" then
		return (p.interacted[o.id] and 1 or 0), 1
	elseif o.type == "crafted" then
		return math.min(o.count, p.stats.crafted[o.item] or 0), o.count
	elseif o.type == "buildAtPort" then
		return (Water.buildAtPort(p, self:getGraph(), o.build, o.node) and 1 or 0), 1
	elseif o.type == "lineConnected" then
		return (Water.lineConnected(p, self:getGraph(), o.target, o.via) and 1 or 0), 1
	elseif o.type == "placed" then
		local n = 0
		for _, b in p.builds do
			if b.t == o.build then
				local area = b.area and Layout.areaById[b.area]
				if not o.zone or (area and area.zone == o.zone) then
					n += 1
				end
			end
		end
		return math.min(n, o.count), o.count
	elseif o.type == "socket" then
		for _, b in p.builds do
			if b.socket == o.id then
				return 1, 1
			end
		end
		return 0, 1
	elseif o.type == "key" then
		return (p.groups[o.group] and 1 or 0), 1
	elseif o.type == "cargo" then
		return math.min(o.count, p.stats.cargoDelivered[o.target] or 0), o.count
	elseif o.type == "planted" then
		return math.min(o.count, p.stats.planted), o.count
	elseif o.type == "harvested" then
		local n = 0
		if o.species then
			n = p.stats.harvested[o.species] or 0
		else
			for _, v in p.stats.harvested do
				n += v
			end
		end
		return math.min(n, o.count), o.count
	elseif o.type == "workingPlanters" then
		local n = 0
		for uid, b in p.builds do
			if b.t == "B_PLANTER" then
				local area = b.area and Layout.areaById[b.area]
				local plant = p.plants["B" .. uid]
				if
					plant
					and plant.m >= Constants.PLANT_MIN_MOISTURE
					and (not o.zone or (area and area.zone == o.zone))
				then
					n += 1
				end
			end
		end
		return math.min(n, o.count), o.count
	elseif o.type == "essences" then
		return math.min(o.count, p.campaign["MAT_BLOOM"] or 0), o.count
	elseif o.type == "wake" then
		return (p.finalCompleted and 1 or 0), 1
	elseif o.type == "power" then
		return math.min(o.value, self:power()), o.value
	elseif o.type == "memory" then
		return (p.memories[o.id] and 1 or 0), 1
	end
	return 0, 1
end

function Game.objectiveDone(self: Session, o: Objective): boolean
	local done, total = self:objectiveProgress(o)
	return done >= total
end

function Game.currentStep(self: Session): Types.QuestStep?
	local q = self.profile.quest
	local ch = QuestDefs.chapters[q.chapter]
	if not ch then
		return nil
	end
	return ch.steps[q.step]
end

function Game.grantBonus(self: Session, bonus: any)
	if not bonus then
		return
	end
	if bonus.coins then
		self:addCoins(bonus.coins)
	end
	if bonus.xp then
		self:addXp(bonus.xp)
	end
	if bonus.builds then
		self:giveItems(bonus.builds)
	end
	if bonus.items then
		self:giveItems(bonus.items)
	end
	if bonus.seeds then
		self:giveItems(bonus.seeds)
	end
	if bonus.coins or bonus.xp then
		self:toast("msg.reward", { coins = bonus.coins or 0, xp = bonus.xp or 0 })
	end
end

function Game.advanceQuests(self: Session)
	local p = self.profile
	for _ = 1, 100 do
		local ch = QuestDefs.chapters[p.quest.chapter]
		if not ch then
			break
		end
		local step = ch.steps[p.quest.step]
		if not step then
			break
		end
		if p.quest.done[step.id] then
			-- Köhnə save uyğunluğu: artıq bitmiş addımı keç
			p.quest.step += 1
		elseif self:objectiveDone(step.objective) then
			p.quest.done[step.id] = true
			local key = "step:" .. step.id
			if not p.oneTimeRewards[key] then
				p.oneTimeRewards[key] = true
				self:grantBonus(step.bonus)
			end
			if step.unlockGroup then
				p.groups[step.unlockGroup] = true
			end
			self:emit("step", { id = step.id })
			self:toast("msg.stepDone")
			p.quest.step += 1
		else
			break
		end
		if p.quest.step > #ch.steps then
			local key = "chapter:" .. ch.chapter
			if not p.oneTimeRewards[key] then
				p.oneTimeRewards[key] = true
				self:addCoins(ch.reward.coins)
				self:addXp(ch.reward.xp)
				if ch.reward.badge then
					p.campaign[ch.reward.badge] = 1
				end
				self:toast("msg.chapterDone", { name = ch.titleKey })
				self:toast("msg.reward", { coins = ch.reward.coins, xp = ch.reward.xp })
				if ch.chapter == 6 then
					self:grantFinalRewards()
				end
			end
			self:emit("chapter", { n = ch.chapter })
			p.quest.chapter += 1
			p.quest.step = 1
		end
		self:refreshZones()
		self:refreshGroups()
	end
	-- Əlavə işlər
	for _, side in QuestDefs.sideTasks do
		if not p.quest.side[side.id] and self:zoneOpen(side.zone) and self:objectiveDone(side.objective) then
			p.quest.side[side.id] = true
			self:addCoins(side.reward.coins)
			self:addXp(side.reward.xp)
			self:emit("side", { id = side.id })
			self:toast("msg.reward", { coins = side.reward.coins, xp = side.reward.xp })
		end
	end
end

function Game.grantFinalRewards(self: Session)
	local p = self.profile
	if p.oneTimeRewards["final"] then
		return
	end
	p.oneTimeRewards["final"] = true
	p.buildInv[ShopDefs.finalRewardDecor] = (p.buildInv[ShopDefs.finalRewardDecor] or 0) + 1
	p.seeds["SEED_STAR"] = math.min(Constants.SEED_STACK_MAX, (p.seeds["SEED_STAR"] or 0) + 1)
	self:refreshGroups()
end

function Game.unlockAchievement(self: Session, id: string)
	local p = self.profile
	if p.achievements[id] then
		return
	end
	local def = QuestDefs.achievementById[id]
	if not def then
		return
	end
	p.achievements[id] = true
	if def.coins > 0 then
		self:addCoins(def.coins)
	end
	self:emit("achievement", { id = id })
	self:toast("msg.achievement", { name = def.nameKey })
end

function Game.checkAchievements(self: Session)
	local p = self.profile
	if p.quest.done["Q1_LINE"] or p.stats.dosesByLine > 0 then
		self:unlockAchievement("ACH_FIRST_LINE")
	end
	if
		Conditions.chapterDone(p, 1)
		and p.quest.side["S1_MEMORY"]
		and p.quest.side["S1_SHORTCUT"]
		and p.quest.side["S1_DAISY"]
	then
		self:unlockAchievement("ACH_NUT_HOUSE")
	end
	if p.quest.done["Q2_BRIDGE"] then
		self:unlockAchievement("ACH_BRIDGE")
	end
	if p.quest.done["Q5_PANELS"] then
		self:unlockAchievement("ACH_GREENHOUSE")
	end
	local badges = 0
	for i = 1, 5 do
		if (p.campaign["BADGE_TREE_" .. i] or 0) > 0 then
			badges += 1
		end
	end
	if badges >= 5 then
		self:unlockAchievement("ACH_FIVE_BADGES")
	end
	if p.finalCompleted then
		self:unlockAchievement("ACH_TREE_AWAKE")
	end
	local mems = 0
	for _ in p.memories do
		mems += 1
	end
	if mems >= 6 then
		self:unlockAchievement("ACH_SIX_MEMORIES")
	end
	if self:power() >= Constants.POWER_MAX then
		self:unlockAchievement("ACH_GARDEN_MASTER")
	end
end

-- Hər hansı əməliyyatdan sonra çağırılır
function Game.afterChange(self: Session)
	self:refreshZones()
	self:refreshGroups()
	self:advanceQuests()
	self:checkAchievements()
	self:refreshOrders()
	self.dirty = true
end

------------------------------------------------------------------------------------------
-- Sifarişlər (əlavə iş lövhəsi)
------------------------------------------------------------------------------------------

function Game.availableOrders(self: Session): { string }
	local list = {}
	for _, o in QuestDefs.orders do
		if Conditions.check(self.profile, o.unlock) then
			table.insert(list, o.id)
		end
	end
	return list
end

function Game.nextRandom(self: Session, n: number): number
	-- Deterministik LCG (oyunçu profilində saxlanılır)
	local s = self.profile.orders.seed
	s = (s * 1103515245 + 12345) % 2147483648
	self.profile.orders.seed = s
	return (s % n) + 1
end

function Game.pickOrder(self: Session, exclude: { string }): string?
	local pool = {}
	for _, id in self:availableOrders() do
		if not table.find(exclude, id) then
			table.insert(pool, id)
		end
	end
	if #pool == 0 then
		return nil
	end
	return pool[self:nextRandom(#pool)]
end

function Game.refreshOrders(self: Session)
	local o = self.profile.orders
	-- Artıq mövcud olmayanları təmizlə
	for i = #o.offers, 1, -1 do
		if not QuestDefs.orderById[o.offers[i]] then
			table.remove(o.offers, i)
		end
	end
	while #o.offers < 3 do
		local id = self:pickOrder(o.offers)
		if not id then
			break
		end
		table.insert(o.offers, id)
	end
	if o.active and not table.find(o.offers, o.active) then
		o.active = nil
	end
end

------------------------------------------------------------------------------------------
-- Əməliyyatlar
------------------------------------------------------------------------------------------

local Actions: { [string]: { group: string, fn: (Session, any) -> Result } } = {}

-- İŞ ---------------------------------------------------------------------------------

function Game.resolveWorkTarget(self: Session, targetId: string): (LayoutObject?, WorkDef?, boolean)
	local obj = Layout.byId[targetId]
	if not obj then
		return nil, nil, false
	end
	if obj.kind == "work" then
		local def = obj.def and WorkDefs.workById[obj.def]
		return obj, def, false
	elseif obj.kind == "spot" and obj.spawns then
		local def = WorkDefs.workById[obj.spawns[1]]
		return obj, def, true
	end
	return nil, nil, false
end

function Game.spotAvailable(self: Session, spotId: string): boolean
	local t = self.profile.respawn[spotId]
	return t == nil or t <= self.profile.playSeconds
end

function Game.startWork(self: Session, targetId: string, toolId: string?): Result
	if self.paused then
		return fail("msg.paused")
	end
	local obj, def, isSpot = self:resolveWorkTarget(targetId)
	if not obj or not def then
		return fail("msg.badRequest")
	end
	if not self:zoneOpen(obj.zone) then
		return fail("msg.locked")
	end
	if isSpot then
		if not self:spotAvailable(targetId) then
			return fail("msg.notReady")
		end
	elseif self.profile.restoredObjectIds[targetId] then
		return fail("hint.done")
	end
	if self:distanceToObject(obj) > Constants.WORK_RANGE then
		return fail("msg.tooFar")
	end
	if self:power() < def.minPower then
		return fail("msg.needPower", { n = def.minPower })
	end
	local tool: ToolDef? = nil
	local rate = 0
	if toolId and self.profile.tools[toolId] then
		local t = ToolDefs.byId[toolId]
		local r = t and (t.rates :: any)[def.workType]
		if t and r then
			tool, rate = t, r
		end
	end
	if not tool then
		tool, rate = self:bestTool(def.workType)
	end
	if not tool then
		return fail("msg.wrongTool")
	end
	-- "Toplama dayanır": çanta doludursa və gözləyən material varsa yeni material işi başlamır
	if #def.mats > 0 and Inventory.bagFree(self.profile) <= 0 and Inventory.hasPending(self.profile) then
		return fail("msg.bagFull")
	end
	local current = self.work
	if current and current.id == targetId then
		return ok()
	end
	if current then
		self:stopWork()
	end
	local finalTool = tool :: ToolDef
	self.profile.equipped = finalTool.id
	local speed = rate
		* Progression.powerMultiplier(self:power())
		* Progression.masteryMultiplier(self:masteryLevel(def.mastery))
	self.work = {
		id = targetId,
		def = def,
		tool = finalTool.id,
		rate = speed,
		progress = self.profile.workProgress[targetId] or 0,
		spot = isSpot,
	}
	self:emit("work", {
		id = targetId,
		progress = (self.profile.workProgress[targetId] or 0) / def.work,
		active = true,
		tool = finalTool.id,
	})
	self.dirty = true
	return ok()
end

function Game.stopWork(self: Session): Result
	local w = self.work
	if not w then
		return ok()
	end
	self.work = nil
	if w.progress > 0 then
		self.profile.workProgress[w.id] = w.progress
	end
	self:emit("work", { id = w.id, progress = w.progress / w.def.work, active = false })
	self.dirty = true
	return ok()
end

function Game.completeWork(self: Session, w: WorkSession)
	local p = self.profile
	local def = w.def
	self.work = nil
	p.workProgress[w.id] = nil
	if w.spot then
		p.respawn[w.id] = p.playSeconds + Constants.RESPAWN_SECONDS
		self:emit("spot", { id = w.id, available = false })
	else
		if p.restoredObjectIds[w.id] then
			return -- təkrar mükafat yoxdur
		end
		p.restoredObjectIds[w.id] = true
		self:emit("restored", { id = w.id })
		self:invalidateGraph()
	end
	self:addCoins(def.coins)
	self:addXp(def.xp)
	self:addMark(def.mastery)
	p.stats.works += 1
	self:emit("work", { id = w.id, progress = 1, active = false, done = true })
	self:toast("msg.reward", { coins = def.coins, xp = def.xp })
	if #def.mats > 0 then
		self:giveItems(def.mats)
	end
	self:afterChange()
end

Actions.StartWork = {
	group = "work",
	fn = function(self, payload)
		if not isId(payload.target) or (payload.tool ~= nil and not isId(payload.tool)) then
			return fail("msg.badRequest")
		end
		return self:startWork(payload.target, payload.tool)
	end,
}

Actions.StopWork = {
	group = "work",
	fn = function(self, _payload)
		return self:stopWork()
	end,
}

Actions.EquipTool = {
	group = "misc",
	fn = function(self, payload)
		if not isId(payload.tool) or not self.profile.tools[payload.tool] then
			return fail("msg.badRequest")
		end
		self.profile.equipped = payload.tool
		self.dirty = true
		return ok()
	end,
}

Actions.SetHotbar = {
	group = "misc",
	fn = function(self, payload)
		local slot = payload.slot
		if not isFinite(slot) or slot % 1 ~= 0 or slot < 1 or slot > 4 then
			return fail("msg.badRequest")
		end
		if not isId(payload.tool) or not self.profile.tools[payload.tool] then
			return fail("msg.badRequest")
		end
		local hb = self.profile.hotbar
		local existing = table.find(hb, payload.tool)
		if existing then
			table.remove(hb, existing)
		end
		if slot > #hb + 1 then
			slot = #hb + 1
		end
		table.insert(hb, slot, payload.tool)
		while #hb > 4 do
			table.remove(hb)
		end
		self.dirty = true
		return ok()
	end,
}

-- DÜKAN -------------------------------------------------------------------------------

function Game.buy(self: Session, id: string): Result
	local p = self.profile
	local tool = ToolDefs.byId[id]
	if tool then
		if tool.price <= 0 then
			return fail("msg.alreadyOwned")
		end
		if self:ownsToolOrBetter(id) then
			return fail("msg.alreadyOwned")
		end
		if not Conditions.check(p, tool.unlock) then
			return fail("msg.locked")
		end
		if self:power() < tool.minPower then
			return fail("msg.needPower", { n = tool.minPower })
		end
		if p.coins < tool.price then
			return fail("msg.notEnoughCoins")
		end
		p.coins -= tool.price
		p.tools[id] = true
		-- Yüksək dərəcə aşağını əvəz edir: hotbar-da yerini tutur
		local replaced = false
		for i, hid in p.hotbar do
			local h = ToolDefs.byId[hid]
			if h and h.family == tool.family then
				p.hotbar[i] = id
				replaced = true
			end
		end
		if not replaced and #p.hotbar < 4 then
			table.insert(p.hotbar, id)
		end
		local eq = p.equipped and ToolDefs.byId[p.equipped]
		if not eq or eq.family == tool.family then
			p.equipped = id
		end
		self:emit("bought", { id = id })
		self:afterChange()
		return ok()
	end
	local bag = ShopDefs.bagById[id]
	if bag then
		if p.bagCapacity >= bag.capacity then
			return fail("msg.alreadyOwned")
		end
		if p.bagCapacity ~= bag.requires then
			return fail("msg.locked")
		end
		if not Conditions.check(p, bag.unlock) then
			return fail("msg.locked")
		end
		if p.coins < bag.price then
			return fail("msg.notEnoughCoins")
		end
		p.coins -= bag.price
		p.bagCapacity = bag.capacity
		Inventory.flushPending(p)
		self:emit("bought", { id = id })
		self:afterChange()
		return ok()
	end
	local plant = PlantDefs.bySeed[id]
	if plant then
		if not Conditions.check(p, plant.unlock) then
			return fail("msg.locked")
		end
		if (p.seeds[id] or 0) >= Constants.SEED_STACK_MAX then
			return fail("msg.limit")
		end
		if p.coins < plant.seedPrice then
			return fail("msg.notEnoughCoins")
		end
		p.coins -= plant.seedPrice
		p.seeds[id] = (p.seeds[id] or 0) + 1
		self:emit("bought", { id = id })
		self:afterChange()
		return ok()
	end
	local decor = ShopDefs.decorById[id]
	if decor then
		if id == ShopDefs.finalRewardDecor then
			return fail("msg.locked")
		end
		if not Conditions.check(p, decor.unlock) then
			return fail("msg.locked")
		end
		local bdef = BuildDefs.byId[id]
		if bdef and Placement.countOwned(p, id) >= bdef.limit then
			return fail("msg.limit")
		end
		if p.coins < decor.price then
			return fail("msg.notEnoughCoins")
		end
		p.coins -= decor.price
		p.buildInv[id] = (p.buildInv[id] or 0) + 1
		self:emit("bought", { id = id })
		self:afterChange()
		return ok()
	end
	local group = RecipeDefs.groupById[id]
	if group then
		if p.groups[id] then
			return fail("msg.alreadyOwned")
		end
		if group.free or not Conditions.check(p, group.unlock) then
			return fail("msg.locked")
		end
		if p.coins < group.keyPrice then
			return fail("msg.notEnoughCoins")
		end
		p.coins -= group.keyPrice
		p.groups[id] = true
		self:emit("bought", { id = id })
		self:afterChange()
		return ok()
	end
	return fail("msg.badRequest")
end

Actions.BuyItem = {
	group = "trade",
	fn = function(self, payload)
		if not isId(payload.id) then
			return fail("msg.badRequest")
		end
		return self:buy(payload.id)
	end,
}

-- EMALATXANA -----------------------------------------------------------------------------

function Game.craft(self: Session, recipeId: string, count: number): Result
	local p = self.profile
	local recipe = RecipeDefs.byId[recipeId]
	if not recipe then
		return fail("msg.badRequest")
	end
	if not p.groups[recipe.group] then
		return fail("msg.locked")
	end
	local bdef = BuildDefs.byId[recipe.output.id]
	if bdef then
		if Placement.countOwned(p, recipe.output.id) + recipe.output.n * count > bdef.limit then
			return fail("msg.limit")
		end
	end
	if not Inventory.take(p, recipe.inputs, count) then
		return fail("msg.notEnoughMats")
	end
	local total = recipe.output.n * count
	if bdef then
		p.buildInv[recipe.output.id] = (p.buildInv[recipe.output.id] or 0) + total
	else
		Inventory.addCrafted(p, recipe.output.id, total)
	end
	p.stats.crafted[recipe.output.id] = (p.stats.crafted[recipe.output.id] or 0) + total
	self:emit("crafted", { id = recipe.output.id, n = total })
	self:toast("msg.got", { n = total, name = bdef and bdef.nameKey or ItemDefs.byId[recipe.output.id].nameKey })
	self:afterChange()
	return ok()
end

Actions.Craft = {
	group = "trade",
	fn = function(self, payload)
		local count = payload.count
		if
			not isId(payload.recipe)
			or not isFinite(count)
			or count % 1 ~= 0
			or count < 1
			or count > Constants.MAX_CRAFT_COUNT
		then
			return fail("msg.badRequest")
		end
		return self:craft(payload.recipe, count)
	end,
}

-- TİKİNTİ --------------------------------------------------------------------------------

local function placeRequest(payload: any): Placement.PlaceRequest?
	local req: Placement.PlaceRequest = {}
	if payload.socket ~= nil then
		if not isId(payload.socket) then
			return nil
		end
		req.socket = payload.socket
		return req
	end
	if not isId(payload.area) then
		return nil
	end
	if not (isFinite(payload.x) and isFinite(payload.z) and isFinite(payload.r)) then
		return nil
	end
	if math.abs(payload.x) > 512 or math.abs(payload.z) > 512 then
		return nil
	end
	if payload.v ~= nil and not isId(payload.v) then
		return nil
	end
	req.area = payload.area
	req.x = payload.x
	req.z = payload.z
	req.r = payload.r
	req.v = payload.v
	return req
end

function Game.place(self: Session, buildId: string, req: Placement.PlaceRequest): Result
	local p = self.profile
	if (p.buildInv[buildId] or 0) <= 0 then
		return fail("msg.notEnoughMats")
	end
	if Placement.totalLimitReached(p) then
		return fail("msg.limit")
	end
	local valid, err, candidate = Placement.validate(p, buildId, req, nil)
	if not valid or not candidate then
		return fail(err or "msg.cantPlace")
	end
	local def = BuildDefs.byId[buildId]
	local c = Placement.worldCenter(candidate)
	if c and self.pos then
		local dx, dz = c[1] - self.pos[1], c[3] - self.pos[3]
		if math.sqrt(dx * dx + dz * dz) > 40 then
			return fail("msg.tooFar")
		end
	end
	p.buildInv[buildId] -= 1
	if p.buildInv[buildId] <= 0 then
		p.buildInv[buildId] = nil
	end
	local uid = tostring(p.nextBuildId)
	p.nextBuildId += 1
	if def.kind == "tank" or def.kind == "catcher" then
		candidate.w = 0
	end
	p.builds[uid] = candidate
	self:invalidateGraph()
	self:emit("build", { uid = uid, op = "add" })
	self:afterChange()
	return ok({ uid = uid })
end

Actions.Place = {
	group = "place",
	fn = function(self, payload)
		if not isId(payload.build) then
			return fail("msg.badRequest")
		end
		local req = placeRequest(payload)
		if not req then
			return fail("msg.badRequest")
		end
		return self:place(payload.build, req)
	end,
}

function Game.moveBuild(self: Session, uid: string, req: Placement.PlaceRequest): Result
	local p = self.profile
	local b = p.builds[uid]
	if not b then
		return fail("msg.badRequest")
	end
	local def = BuildDefs.byId[b.t]
	if not def or def.socketOnly then
		return fail("msg.cantPlace")
	end
	local valid, err, candidate = Placement.validate(p, b.t, req, uid)
	if not valid or not candidate then
		return fail(err or "msg.cantPlace")
	end
	b.area = candidate.area
	b.x = candidate.x
	b.z = candidate.z
	b.r = candidate.r
	b.v = candidate.v
	self:invalidateGraph()
	self:emit("build", { uid = uid, op = "move" })
	self:afterChange()
	return ok()
end

Actions.MoveBuild = {
	group = "place",
	fn = function(self, payload)
		if not isId(payload.uid) then
			return fail("msg.badRequest")
		end
		local req = placeRequest(payload)
		if not req or req.socket then
			return fail("msg.badRequest")
		end
		return self:moveBuild(payload.uid, req)
	end,
}

function Game.storeBuild(self: Session, uid: string): Result
	local p = self.profile
	local b = p.builds[uid]
	if not b then
		return fail("msg.badRequest")
	end
	local def = BuildDefs.byId[b.t]
	if not def or def.socketOnly then
		-- Körpü və lift yığılmır: sahəyə giriş itməsin
		return fail("msg.cantPlace")
	end
	-- Su saxlayan qurğu: su ev rezervuarına keçir, sığmırsa əvvəl boşaltma lazımdır
	local water = b.w or 0
	if def.kind == "tank" or def.kind == "catcher" then
		if water > Constants.HOME_WATER_CAPACITY - p.homeWater then
			return fail("msg.drainFirst")
		end
		p.homeWater += water
	end
	if def.kind == "planter" then
		local plant = p.plants["B" .. uid]
		if plant then
			if plant.ready then
				-- Hazır məhsulu əvvəl yığmaq lazımdır (bölmə 13)
				return fail("msg.harvestFirst")
			end
			-- Bitkinin növü toxum kimi qaytarılır (layihə qərarı, docs/DESIGN_DECISIONS.md)
			local pdef = PlantDefs.byId[plant.sp]
			if pdef then
				p.seeds[pdef.seedId] = math.min(Constants.SEED_STACK_MAX, (p.seeds[pdef.seedId] or 0) + 1)
			end
			p.plants["B" .. uid] = nil
		end
	end
	if def.kind == "compost" and (b.w or 0) > 0 then
		Inventory.addCrafted(p, "MAT_COMPOST", b.w or 0)
	end
	p.builds[uid] = nil
	p.buildInv[b.t] = (p.buildInv[b.t] or 0) + 1
	self:invalidateGraph()
	self:emit("build", { uid = uid, op = "remove" })
	self:afterChange()
	return ok()
end

Actions.StoreBuild = {
	group = "place",
	fn = function(self, payload)
		if not isId(payload.uid) then
			return fail("msg.badRequest")
		end
		return self:storeBuild(payload.uid)
	end,
}

Actions.DrainBuild = {
	group = "place",
	fn = function(self, payload)
		if not isId(payload.uid) then
			return fail("msg.badRequest")
		end
		local b = self.profile.builds[payload.uid]
		if not b or b.w == nil then
			return fail("msg.badRequest")
		end
		b.w = 0
		self:emit("build", { uid = payload.uid, op = "water" })
		self.dirty = true
		return ok()
	end,
}

-- SU ---------------------------------------------------------------------------------

function Game.fillWater(self: Session, sourceId: string): Result
	local p = self.profile
	local spec = self:cupSpec()
	local space = spec.capacity - p.cup
	if space <= 0 then
		return fail("msg.cupFull")
	end
	local available = 0
	local takeFrom: (number) -> ()
	local obj = Layout.byId[sourceId]
	if obj and obj.kind == "source" then
		if not self:zoneOpen(obj.zone) then
			return fail("msg.locked")
		end
		if self:distanceToObject(obj) > Constants.INTERACT_RANGE then
			return fail("msg.tooFar")
		end
		available = p.waterSources[sourceId] or 0
		takeFrom = function(n)
			p.waterSources[sourceId] = available - n
		end
	elseif obj and obj.kind == "storage" then
		if self:distanceToObject(obj) > Constants.INTERACT_RANGE then
			return fail("msg.tooFar")
		end
		available = p.homeWater
		takeFrom = function(n)
			p.homeWater -= n
		end
	else
		local b = p.builds[sourceId]
		local def = b and BuildDefs.byId[b.t]
		if not b or not def or (def.kind ~= "tank" and def.kind ~= "catcher") then
			return fail("msg.badRequest")
		end
		if self:distanceToBuild(b) > Constants.INTERACT_RANGE then
			return fail("msg.tooFar")
		end
		available = b.w or 0
		takeFrom = function(n)
			b.w = available - n
		end
	end
	if available <= 0 then
		return fail("msg.sourceEmpty")
	end
	local n = math.min(space, available)
	takeFrom(n)
	p.cup += n
	p.interacted["fill"] = true
	self:emit("water", { op = "fill", id = sourceId, n = n })
	self:afterChange()
	return ok({ n = n })
end

Actions.FillWater = {
	group = "misc",
	fn = function(self, payload)
		if not isId(payload.source) then
			return fail("msg.badRequest")
		end
		return self:fillWater(payload.source)
	end,
}

-- Hədəf su qəbul edirmi (qabla). Qaytarır: qəbul, xəta açarı
function Game.cupAccepts(self: Session, targetId: string): (boolean, string?)
	local p = self.profile
	local obj = Layout.byId[targetId]
	if obj then
		if not self:zoneOpen(obj.zone) then
			return false, "msg.locked"
		end
		if obj.kind == "consumer" then
			local def, locked = Water.consumerState(p, targetId)
			if not def then
				return false, "msg.badRequest"
			end
			if locked then
				local extra = obj.extra
				local lockId = extra and extra.lockedBy
				local lockObj = lockId and Layout.byId[lockId]
				return false, (lockObj and lockObj.kind == "dropoff") and "hint.needPatch" or "hint.needKnot"
			end
			if not def.cupAllowed then
				return false, def.requiresPump and "hint.needPump" or "hint.networkOnly"
			end
			if p.restoredObjectIds[targetId] or (p.moisture[targetId] or 0) >= Constants.MOISTURE_MAX then
				return false, "msg.bedFull"
			end
			return true, nil
		elseif obj.kind == "plot" then
			local plant = p.plants[targetId]
			if not plant then
				return false, "msg.noSeed"
			end
			if plant.m >= Constants.MOISTURE_MAX then
				return false, "msg.bedFull"
			end
			return true, nil
		end
		return false, "msg.badRequest"
	end
	local b = p.builds[targetId]
	if b then
		local def = BuildDefs.byId[b.t]
		if def.kind == "planter" then
			local plant = p.plants["B" .. targetId]
			if not plant then
				return false, "msg.noSeed"
			end
			if plant.m >= Constants.MOISTURE_MAX then
				return false, "msg.bedFull"
			end
			return true, nil
		elseif def.kind == "tank" then
			if (b.w or 0) >= (def.capacity or 0) then
				return false, "msg.bedFull"
			end
			return true, nil
		end
	end
	return false, "msg.badRequest"
end

function Game.applyCupDose(self: Session, targetId: string)
	local p = self.profile
	local obj = Layout.byId[targetId]
	if obj and obj.kind == "consumer" then
		p.moisture[targetId] = math.min(Constants.MOISTURE_MAX, (p.moisture[targetId] or 0) + Constants.DOSE_MOISTURE)
		self:emit("moisture", { id = targetId })
		self:checkConsumer(targetId)
	elseif obj and obj.kind == "plot" then
		local plant = p.plants[targetId]
		plant.m = math.min(Constants.MOISTURE_MAX, plant.m + Constants.DOSE_MOISTURE)
		self:emit("plant", { slot = targetId })
	else
		local b = p.builds[targetId]
		local def = BuildDefs.byId[b.t]
		if def.kind == "planter" then
			local plant = p.plants["B" .. targetId]
			plant.m = math.min(Constants.MOISTURE_MAX, plant.m + Constants.DOSE_MOISTURE)
			self:emit("plant", { slot = "B" .. targetId })
		elseif def.kind == "tank" then
			b.w = (b.w or 0) + 1
			self:emit("build", { uid = targetId, op = "water" })
		end
	end
end

function Game.targetCenter(self: Session, targetId: string): { number }?
	local obj = Layout.byId[targetId]
	if obj then
		return obj.pos
	end
	local b = self.profile.builds[targetId]
	return b and Placement.worldCenter(b) or nil
end

function Game.waterTarget(self: Session, targetId: string): Result
	local p = self.profile
	if p.cup <= 0 then
		return fail("hint.emptyCup")
	end
	local obj = Layout.byId[targetId]
	local dist = math.huge
	if obj then
		dist = self:distanceToObject(obj)
	elseif p.builds[targetId] then
		dist = self:distanceToBuild(p.builds[targetId])
	end
	if dist > Constants.INTERACT_RANGE then
		return fail("msg.tooFar")
	end
	local accepted, err = self:cupAccepts(targetId)
	if not accepted then
		return fail(err or "msg.badRequest")
	end
	local spec = self:cupSpec()
	local targets = { targetId }
	-- Şeh çiləyicisi: suyu yaxın 3 hədəfə bölür, əlavə su yaratmır
	if spec.spread > 1 then
		local center = self:targetCenter(targetId) :: { number }
		local candidates = {}
		local function consider(id: string, c: { number }?)
			if id ~= targetId and c and math.abs(c[2] - center[2]) < 2 then
				local d = math.sqrt((c[1] - center[1]) ^ 2 + (c[3] - center[3]) ^ 2)
				if d <= spec.spreadRadius and self:cupAccepts(id) then
					table.insert(candidates, { id = id, d = d })
				end
			end
		end
		for _, o in Layout.objects do
			if o.kind == "consumer" or o.kind == "plot" then
				consider(o.id, o.pos)
			end
		end
		for uid, b in p.builds do
			if b.t == "B_PLANTER" then
				consider(uid, Placement.worldCenter(b))
			end
		end
		table.sort(candidates, function(a, b)
			if a.d == b.d then
				return a.id < b.id
			end
			return a.d < b.d
		end)
		for _, c in candidates do
			if #targets >= spec.spread then
				break
			end
			table.insert(targets, c.id)
		end
	end
	local used = 0
	for _, id in targets do
		if p.cup <= 0 then
			break
		end
		p.cup -= 1
		used += 1
		self:applyCupDose(id)
	end
	p.interacted["w:" .. targetId] = true
	self:emit("water", { op = "pour", id = targetId, n = used })
	self:afterChange()
	return ok({ n = used })
end

Actions.WaterPlant = {
	group = "misc",
	fn = function(self, payload)
		if not isId(payload.target) then
			return fail("msg.badRequest")
		end
		return self:waterTarget(payload.target)
	end,
}

-- Yataq bərpa həddinə çatdımı
function Game.checkConsumer(self: Session, id: string)
	local p = self.profile
	if p.restoredObjectIds[id] then
		return
	end
	local obj = Layout.byId[id]
	local def = obj and obj.def and WorkDefs.consumerById[obj.def]
	if not def then
		return
	end
	local threshold = math.min(Constants.MOISTURE_MAX, def.doses * Constants.DOSE_MOISTURE)
	if (p.moisture[id] or 0) >= threshold then
		p.restoredObjectIds[id] = true
		p.moisture[id] = Constants.MOISTURE_MAX
		self:invalidateGraph()
		if def.coins > 0 or def.xp > 0 then
			self:addCoins(def.coins)
			self:addXp(def.xp)
			self:toast("msg.reward", { coins = def.coins, xp = def.xp })
		end
		self:addMark(def.mastery)
		if def.bloom and not p.oneTimeRewards["bloom:" .. id] then
			p.oneTimeRewards["bloom:" .. id] = true
			p.campaign["MAT_BLOOM"] = (p.campaign["MAT_BLOOM"] or 0) + 1
			self:toast("msg.got", { n = 1, name = "item.MAT_BLOOM" })
		end
		self:emit("restored", { id = id })
		self:toast("msg.restored", { name = def.nameKey })
	end
end

-- BİTKİLƏR ---------------------------------------------------------------------------

function Game.slotKey(self: Session, slotId: string): (string?, string?)
	-- Qaytarır: plants açarı, zona (və ya nil)
	local obj = Layout.byId[slotId]
	if obj and obj.kind == "plot" then
		return slotId, obj.zone
	end
	local b = self.profile.builds[slotId]
	if b and b.t == "B_PLANTER" then
		local area = b.area and Layout.areaById[b.area]
		return "B" .. slotId, area and area.zone or nil
	end
	return nil, nil
end

function Game.slotDistance(self: Session, slotId: string): number
	local obj = Layout.byId[slotId]
	if obj then
		return self:distanceToObject(obj)
	end
	local b = self.profile.builds[slotId]
	return b and self:distanceToBuild(b) or math.huge
end

function Game.plantSeed(self: Session, slotId: string, seedId: string): Result
	local p = self.profile
	local key, zone = self:slotKey(slotId)
	if not key then
		return fail("msg.badRequest")
	end
	if zone and not self:zoneOpen(zone) then
		return fail("msg.locked")
	end
	if self:slotDistance(slotId) > Constants.INTERACT_RANGE then
		return fail("msg.tooFar")
	end
	if p.plants[key] then
		return fail("msg.slotBusy")
	end
	local pdef = PlantDefs.bySeed[seedId]
	if not pdef or (p.seeds[seedId] or 0) <= 0 then
		return fail("msg.noSeed")
	end
	p.seeds[seedId] -= 1
	if p.seeds[seedId] <= 0 then
		p.seeds[seedId] = nil
	end
	p.plants[key] = { sp = pdef.id, g = 0, m = 0, ready = false }
	p.stats.planted += 1
	self:emit("plant", { slot = key })
	self:afterChange()
	return ok()
end

Actions.PlantSeed = {
	group = "misc",
	fn = function(self, payload)
		if not isId(payload.slot) or not isId(payload.seed) then
			return fail("msg.badRequest")
		end
		return self:plantSeed(payload.slot, payload.seed)
	end,
}

function Game.harvest(self: Session, slotId: string): Result
	local p = self.profile
	local key = self:slotKey(slotId)
	if not key then
		return fail("msg.badRequest")
	end
	if self:slotDistance(slotId) > Constants.INTERACT_RANGE then
		return fail("msg.tooFar")
	end
	local plant = p.plants[key]
	if not plant or not plant.ready then
		return fail("msg.notReady")
	end
	local pdef = PlantDefs.byId[plant.sp]
	plant.ready = false
	plant.g = 0
	p.stats.harvested[plant.sp] = (p.stats.harvested[plant.sp] or 0) + 1
	self:addMark("botany")
	if pdef then
		self:giveItems(pdef.yield)
	end
	self:emit("plant", { slot = key })
	self:afterChange()
	return ok()
end

Actions.Harvest = {
	group = "trade",
	fn = function(self, payload)
		if not isId(payload.slot) then
			return fail("msg.badRequest")
		end
		return self:harvest(payload.slot)
	end,
}

-- ƏLAQƏ (NPC, iş masası, anbar, xatirə, yük, final) ----------------------------------------

function Game.interact(self: Session, targetId: string): Result
	local p = self.profile
	local obj = Layout.byId[targetId]
	if not obj then
		local b = p.builds[targetId]
		if b then
			return self:interactBuild(targetId, b)
		end
		return fail("msg.badRequest")
	end
	if not self:zoneOpen(obj.zone) then
		return fail("msg.locked")
	end
	if self:distanceToObject(obj) > Constants.INTERACT_RANGE then
		return fail("msg.tooFar")
	end
	local kind = obj.kind
	if kind == "npc" then
		p.interacted[targetId] = true
		local npc = obj.def and NpcDefs.byId[obj.def]
		self:emit("dialog", { npc = obj.def, opens = npc and npc.opens or nil })
		self:afterChange()
		return ok()
	elseif kind == "workbench" then
		p.interacted[targetId] = true
		self:emit("open", { panel = "workshop" })
		self:afterChange()
		return ok()
	elseif kind == "board" then
		p.interacted[targetId] = true
		self:emit("open", { panel = "board" })
		self:afterChange()
		return ok()
	elseif kind == "storage" then
		p.interacted[targetId] = true
		local moved = Inventory.deposit(p)
		if Inventory.hasPending(p) then
			self:toast("msg.storageFull")
		end
		self:emit("open", { panel = "inventory", moved = moved })
		self:afterChange()
		return ok({ moved = moved })
	elseif kind == "memory" then
		if p.restoredObjectIds[targetId] then
			return fail("hint.done")
		end
		p.restoredObjectIds[targetId] = true
		local memId = obj.def :: string
		p.memories[memId] = true
		self:emit("restored", { id = targetId })
		self:toast("msg.memoryFound", { name = ItemDefs.byId[memId].nameKey })
		self:afterChange()
		return ok()
	elseif kind == "cargo" then
		if p.restoredObjectIds[targetId] then
			return fail("hint.done")
		end
		local cart = nil
		for id in p.tools do
			local t = ToolDefs.byId[id]
			if t and t.cartCapacity then
				cart = t
			end
		end
		if not cart then
			return fail("hint.needCart")
		end
		local carried = Inventory.sum(p.cargo)
		if carried >= (cart.cartCapacity :: number) then
			return fail("msg.cartFull")
		end
		local itemId = obj.def :: string
		p.cargo[itemId] = (p.cargo[itemId] or 0) + 1
		p.restoredObjectIds[targetId] = true
		p.equipped = cart.id
		self:emit("restored", { id = targetId })
		self:emit("cargo", { n = carried + 1 })
		if carried + 1 >= 3 then
			self:unlockAchievement("ACH_HEAVY_LOAD")
		end
		self:afterChange()
		return ok()
	elseif kind == "dropoff" then
		if p.restoredObjectIds[targetId] then
			return fail("hint.done")
		end
		local itemId = obj.def :: string
		local carried = p.cargo[itemId] or 0
		if carried <= 0 then
			return fail("hint.needCart")
		end
		local need = (obj.count or 1) - (p.stats.cargoDelivered[targetId] or 0)
		local n = math.min(carried, need)
		p.cargo[itemId] = carried - n
		if p.cargo[itemId] <= 0 then
			p.cargo[itemId] = nil
		end
		p.stats.cargoDelivered[targetId] = (p.stats.cargoDelivered[targetId] or 0) + n
		if p.stats.cargoDelivered[targetId] >= (obj.count or 1) then
			p.restoredObjectIds[targetId] = true
			self:invalidateGraph()
			self:emit("restored", { id = targetId })
		end
		self:emit("cargo", { n = Inventory.sum(p.cargo) })
		self:afterChange()
		return ok({ n = n })
	elseif kind == "tree" then
		return self:wakeTree()
	elseif kind == "home" then
		self:emit("open", { panel = "home" })
		return ok()
	end
	return fail("msg.badRequest")
end

function Game.interactBuild(self: Session, uid: string, b: PlacedBuild): Result
	local p = self.profile
	if self:distanceToBuild(b) > Constants.INTERACT_RANGE then
		return fail("msg.tooFar")
	end
	local def = BuildDefs.byId[b.t]
	if def.kind == "compost" then
		if (b.w or 0) > 0 then
			Inventory.addCrafted(p, "MAT_COMPOST", b.w :: number)
			self:toast("msg.got", { n = b.w, name = "item.MAT_COMPOST" })
			b.w = 0
			self:emit("build", { uid = uid, op = "state" })
			self:afterChange()
			return ok()
		end
		if b.c and b.c > 0 then
			return fail("msg.notReady")
		end
		local recipe = { { id = "MAT_FIBER", n = 6 }, { id = "MAT_PETAL", n = 2 } }
		if not Inventory.take(p, recipe, 1) then
			return fail("msg.notEnoughMats")
		end
		b.c = 60
		self:emit("build", { uid = uid, op = "state" })
		self:afterChange()
		return ok()
	elseif def.kind == "sorter" then
		local moved = Inventory.deposit(p)
		self:emit("open", { panel = "inventory", moved = moved })
		self:afterChange()
		return ok({ moved = moved })
	end
	return fail("msg.badRequest")
end

function Game.finalReady(self: Session): boolean
	local p = self.profile
	for i = 1, 5 do
		if (p.campaign["BADGE_TREE_" .. i] or 0) < 1 then
			return false
		end
	end
	if (p.campaign["MAT_BLOOM"] or 0) < 5 then
		return false
	end
	for i = 1, 5 do
		if
			not p.restoredObjectIds[("Z06_Knot_%02d"):format(i)] or not p.restoredObjectIds[("Z06_Root_%02d"):format(i)]
		then
			return false
		end
	end
	return p.restoredObjectIds["Z06_Crown"] == true
end

function Game.wakeTree(self: Session): Result
	local p = self.profile
	if p.finalCompleted then
		-- Finaldan sonra: xatirə kitabından təkrar izləmə
		self:emit("final", { replay = true })
		return ok()
	end
	local step = self:currentStep()
	if not step or step.id ~= "Q6_WAKE" or not self:finalReady() then
		return fail("msg.locked")
	end
	p.finalCompleted = true
	self:emit("final", { replay = false })
	self:afterChange()
	return ok()
end

Actions.Interact = {
	group = "misc",
	fn = function(self, payload)
		if not isId(payload.target) then
			return fail("msg.badRequest")
		end
		return self:interact(payload.target)
	end,
}

Actions.Deposit = {
	group = "misc",
	fn = function(self, _payload)
		return self:interact("Z01_Storage")
	end,
}

Actions.GoHome = {
	group = "misc",
	fn = function(self, _payload)
		self:stopWork()
		local spawn = Layout.zoneLayout["Z01"].safeSpawn
		self:emit("teleport", { pos = spawn })
		self:toast("msg.homeTeleport")
		return ok({ pos = spawn })
	end,
}

-- Lift: aşağı və yuxarı dayanacaq arasında (prototipdə qısa keçid kimi)
Actions.UseLift = {
	group = "misc",
	fn = function(self, payload)
		if not isId(payload.socket) then
			return fail("msg.badRequest")
		end
		local obj = Layout.byId[payload.socket]
		if not obj or obj.kind ~= "socket" or obj.def ~= "B_LIFT" then
			return fail("msg.badRequest")
		end
		local built = false
		for _, b in self.profile.builds do
			if b.socket == payload.socket then
				built = true
			end
		end
		if not built then
			return fail("msg.locked")
		end
		local extra: { [string]: any } = obj.extra or {}
		local top = extra.landing or extra.top
		local pos = self.pos
		if not pos or not top then
			return fail("msg.badRequest")
		end
		local function near(p: { number }): boolean
			local dx, dy, dz = pos[1] - p[1], pos[2] - p[2], pos[3] - p[3]
			return math.sqrt(dx * dx + dz * dz) <= 12 and math.abs(dy) <= 8
		end
		local target
		if near(obj.pos) then
			target = top
		elseif near(top) then
			target = { obj.pos[1], obj.pos[2], obj.pos[3] - 6 }
		else
			return fail("msg.tooFar")
		end
		self:stopWork()
		self:emit("teleport", { pos = target })
		return ok({ pos = target })
	end,
}

-- Finaldan sonra: yalnız ziyarət olunmuş (açıq) sahələrə rahat keçid (bölmə 5)
Actions.FastTravel = {
	group = "misc",
	fn = function(self, payload)
		if not self.profile.finalCompleted then
			return fail("msg.locked")
		end
		local zone = payload.zone
		if type(zone) ~= "string" or not self.profile.zones[zone] then
			return fail("msg.locked")
		end
		local zl = Layout.zoneLayout[zone]
		if not zl then
			return fail("msg.badRequest")
		end
		self:stopWork()
		self:emit("teleport", { pos = zl.safeSpawn })
		return ok({ pos = zl.safeSpawn })
	end,
}

Actions.WatchedFinal = {
	group = "misc",
	fn = function(self, _payload)
		if not self.profile.finalCompleted then
			return fail("msg.locked")
		end
		self.profile.finalWatched += 1
		self.dirty = true
		return ok()
	end,
}

-- SİFARİŞLƏR -------------------------------------------------------------------------

Actions.AcceptOrder = {
	group = "trade",
	fn = function(self, payload)
		local o = self.profile.orders
		if not isId(payload.order) or not table.find(o.offers, payload.order) then
			return fail("msg.badRequest")
		end
		o.active = payload.order
		self.dirty = true
		return ok()
	end,
}

Actions.DeliverOrder = {
	group = "trade",
	fn = function(self, payload)
		local p = self.profile
		local o = p.orders
		local id = payload.order
		if not isId(id) or o.active ~= id then
			return fail("msg.badRequest")
		end
		local def = QuestDefs.orderById[id]
		if not def then
			return fail("msg.badRequest")
		end
		if not Inventory.take(p, { def.wants }, 1) then
			return fail("msg.notEnoughMats")
		end
		self:addCoins(def.coins)
		self:addXp(def.xp)
		self:toast("msg.reward", { coins = def.coins, xp = def.xp })
		o.completed += 1
		local idx = table.find(o.offers, id)
		if idx then
			table.remove(o.offers, idx)
		end
		o.active = nil
		-- Yeni təklif: indicə bitən iş dərhal geri gəlməsin
		local excluded = table.clone(o.offers)
		table.insert(excluded, id)
		local nxt = self:pickOrder(excluded) or self:pickOrder(o.offers)
		if nxt then
			table.insert(o.offers, idx or (#o.offers + 1), nxt)
		end
		self:emit("order", { id = id })
		self:afterChange()
		return ok()
	end,
}

Actions.RerollOrder = {
	group = "trade",
	fn = function(self, payload)
		local o = self.profile.orders
		local slot = payload.slot
		if not isFinite(slot) or slot % 1 ~= 0 or slot < 1 or slot > #o.offers then
			return fail("msg.badRequest")
		end
		if o.offers[slot] == o.active then
			return fail("msg.badRequest")
		end
		local excluded = table.clone(o.offers)
		local nxt = self:pickOrder(excluded)
		if nxt then
			o.offers[slot] = nxt
		end
		self.dirty = true
		return ok()
	end,
}

-- AYARLAR və PAUZA ---------------------------------------------------------------------

local SETTINGS: { [string]: (any) -> boolean } = {
	lang = function(v)
		return v == "az" or v == "en"
	end,
	music = function(v)
		return isFinite(v) and v >= 0 and v <= 1
	end,
	sfx = function(v)
		return isFinite(v) and v >= 0 and v <= 1
	end,
	camSens = function(v)
		return isFinite(v) and v >= 0.2 and v <= 3
	end,
	reducedMotion = function(v)
		return type(v) == "boolean"
	end,
	cameraShake = function(v)
		return type(v) == "boolean"
	end,
	quality = function(v)
		return v == "auto" or v == "low" or v == "high"
	end,
	textSize = function(v)
		return isFinite(v) and v >= 0.8 and v <= 1.5
	end,
	markers = function(v)
		return type(v) == "boolean"
	end,
	rainFx = function(v)
		return type(v) == "boolean"
	end,
	skin = function(v)
		return isFinite(v) and v % 1 == 0 and v >= 1 and v <= 6
	end,
	outfit = function(v)
		return isFinite(v) and v % 1 == 0 and v >= 1 and v <= 4
	end,
}

Actions.SetPreference = {
	group = "misc",
	fn = function(self, payload)
		local key = payload.key
		if type(key) ~= "string" or not SETTINGS[key] or not SETTINGS[key](payload.value) then
			return fail("msg.badRequest")
		end
		self.profile.settings[key] = payload.value
		self:emit("pref", { key = key, value = payload.value })
		self.dirty = true
		return ok()
	end,
}

function Game.setPaused(self: Session, paused: boolean)
	if paused and not self.paused then
		self:stopWork()
	end
	self.paused = paused
	self:emit("paused", { paused = paused })
	self.dirty = true
end

Actions.SetPaused = {
	group = "misc",
	fn = function(self, payload)
		if type(payload.paused) ~= "boolean" then
			return fail("msg.badRequest")
		end
		self:setPaused(payload.paused)
		return ok()
	end,
}

------------------------------------------------------------------------------------------
-- Sorğu ötürücüsü: tip, sürət limiti və təkrar sorğu yoxlaması
------------------------------------------------------------------------------------------

Game.Actions = Actions

function Game.rateAllowed(self: Session, group: string, clock: number): boolean
	local lim = (Constants.RATE_LIMITS :: any)[group]
	if not lim then
		return true
	end
	local list = self.rate[group]
	if not list then
		list = {}
		self.rate[group] = list
	end
	local cutoff = clock - lim.window
	local i = 1
	while i <= #list do
		if list[i] <= cutoff then
			table.remove(list, i)
		else
			i += 1
		end
	end
	if #list >= lim.count then
		return false
	end
	table.insert(list, clock)
	return true
end

function Game.handle(self: Session, action: any, payload: any, clock: number): Result
	if type(action) ~= "string" or type(payload) ~= "table" then
		return fail("msg.badRequest")
	end
	local spec = Actions[action]
	if not spec then
		return fail("msg.badRequest")
	end
	local rid = payload.rid
	local ridKey: string? = nil
	if rid ~= nil then
		if not ((type(rid) == "number" and isFinite(rid)) or (type(rid) == "string" and #rid <= 32)) then
			return fail("msg.badRequest")
		end
		ridKey = action .. ":" .. tostring(rid)
		local cached = self.ridCache[ridKey :: string]
		if cached then
			-- Eyni sorğunun təkrarı ikinci mükafat yaratmır
			return { ok = cached.ok, err = cached.err, params = cached.params, data = cached.data, dup = true }
		end
	end
	if not self:rateAllowed(spec.group, clock) then
		return fail("msg.rateLimited")
	end
	local okCall, result = pcall(spec.fn, self, payload)
	if not okCall then
		warn("[TinyGrove] əməliyyat xətası " .. action .. ": " .. tostring(result))
		return fail("msg.badRequest")
	end
	if ridKey then
		self.ridCache[ridKey] = result
		table.insert(self.ridOrder, ridKey)
		while #self.ridOrder > Constants.RID_CACHE_SIZE do
			local old = table.remove(self.ridOrder, 1)
			if old then
				self.ridCache[old] = nil
			end
		end
	end
	if not result.ok then
		self.dirty = true
	end
	return result
end

------------------------------------------------------------------------------------------
-- Zaman: yalnız aktiv oyunda (pauza və oflayn vaxt hesablanmır)
------------------------------------------------------------------------------------------

local function plantStage(g: number, grow: number, ready: boolean): number
	if ready then
		return 4
	end
	local f = g / grow
	if f < 0.25 then
		return 1
	elseif f < 0.6 then
		return 2
	end
	return 3
end
Game.plantStage = plantStage

function Game.tick(self: Session, dt: number)
	if self.paused or not isFinite(dt) or dt <= 0 then
		return
	end
	dt = math.min(dt, 1) -- böyük sıçrayışlar olmasın
	local p = self.profile
	p.playSeconds += dt

	-- İş
	local w = self.work
	if w then
		local obj = Layout.byId[w.id]
		if not obj or self:distanceToObject(obj) > Constants.WORK_RANGE then
			self:stopWork()
			self:toast("msg.tooFar")
		else
			w.progress += w.rate * dt
			if w.progress >= w.def.work then
				self:completeWork(w)
			else
				self:emit("work", { id = w.id, progress = w.progress / w.def.work, active = true })
			end
		end
	end

	-- Resurs yuvalarının yenilənməsi
	for id, t in p.respawn do
		if t <= p.playSeconds then
			p.respawn[id] = nil
			self:emit("spot", { id = id, available = true })
			self.dirty = true
		end
	end

	-- Mənbələrin dolması
	for _, obj in Layout.objects do
		if obj.kind == "source" and p.zones[obj.zone] then
			local cap = obj.capacity or 12
			local cur = p.waterSources[obj.id] or 0
			if cur < cap then
				local acc = (p.waterRegen[obj.id] or 0) + dt
				local interval = obj.regenSeconds or 5
				while acc >= interval and cur < cap do
					acc -= interval
					cur += 1
				end
				p.waterSources[obj.id] = cur
				p.waterRegen[obj.id] = if cur >= cap then 0 else acc
			end
		end
	end

	-- Yağış (2–3 dövrədən bir, 2 dəqiqə). Mexaniki qazancı: toplayıcılar sürətlə dolur.
	local raining = p.playSeconds < p.rain.untilT
	if not raining and p.playSeconds >= p.rain.next then
		p.rain.untilT = p.playSeconds + Constants.RAIN_DURATION
		local cycles = (p.orders.seed % 2 == 0) and Constants.RAIN_MIN_CYCLES or Constants.RAIN_MAX_CYCLES
		p.rain.next = p.playSeconds + cycles * Constants.DAY_LENGTH
		raining = true
	end
	if raining ~= self.raining then
		self.raining = raining
		self:emit("rain", { on = raining })
		self.dirty = true
	end
	p.dayTime = (p.dayTime + dt) % Constants.DAY_LENGTH

	-- Qurğuların daxili vəziyyəti: toplayıcı və kompost
	for uid, b in p.builds do
		local def = BuildDefs.byId[b.t]
		if def and def.kind == "catcher" then
			local cap = def.capacity or 20
			if (b.w or 0) < cap then
				local interval = raining and Constants.RAIN_CATCHER_INTERVAL or (def.regenSeconds or 20)
				local acc = (b.rt or 0) + dt
				local cur = b.w or 0
				while acc >= interval and cur < cap do
					acc -= interval
					cur += 1
				end
				b.w = cur
				b.rt = acc
			end
		elseif def and def.kind == "compost" and b.c and b.c > 0 then
			b.c -= dt
			if b.c <= 0 then
				b.c = nil
				b.w = (b.w or 0) + 3
				self:emit("build", { uid = uid, op = "state" })
				self.dirty = true
			end
		end
	end

	-- Bitkilər: rütubət ≥ 25 olanda böyüyür, ölmür
	for slot, plant in p.plants do
		local pdef = PlantDefs.byId[plant.sp]
		if pdef and not plant.ready and plant.m >= Constants.PLANT_MIN_MOISTURE then
			local before = plantStage(plant.g, pdef.growSeconds, false)
			plant.g = math.min(pdef.growSeconds, plant.g + dt)
			if plant.g >= pdef.growSeconds then
				plant.ready = true
			end
			local after = plantStage(plant.g, pdef.growSeconds, plant.ready)
			if after ~= before then
				self:emit("plant", { slot = slot })
				self.dirty = true
				if after >= 2 then
					self:unlockAchievement("ACH_FIRST_SPROUT")
				end
			end
		end
	end

	-- Rütubətin azalması: hər 30 s aktiv oyunda −2 (bərpa olunmuş kampaniya yataqları istisna)
	self.decayAcc += dt
	while self.decayAcc >= Constants.MOISTURE_DECAY_INTERVAL do
		self.decayAcc -= Constants.MOISTURE_DECAY_INTERVAL
		for id, m in p.moisture do
			if not p.restoredObjectIds[id] and m > 0 then
				p.moisture[id] = math.max(0, m - Constants.MOISTURE_DECAY)
				self:emit("moisture", { id = id })
			end
		end
		for slot, plant in p.plants do
			if plant.m > 0 then
				plant.m = math.max(0, plant.m - Constants.MOISTURE_DECAY)
				self:emit("plant", { slot = slot })
			end
		end
		self.dirty = true
	end

	-- Su axını: saniyədə bir dəfə
	self.waterAcc += dt
	if self.waterAcc >= Constants.WATER_TICK then
		self.waterAcc -= Constants.WATER_TICK
		self:waterTick()
	end
end

function Game.waterTick(self: Session)
	local p = self.profile
	local g = self:getGraph()
	local deliveries = Water.tick(p, g)
	if #deliveries == 0 then
		return
	end
	local changed = false
	for _, d in deliveries do
		p.stats.dosesByLine += 1
		local target = d.target
		if target.kind == "consumer" then
			p.stats.lineDelivered[target.id] = (p.stats.lineDelivered[target.id] or 0) + 1
			self:emit("moisture", { id = target.id })
			self:checkConsumer(target.id)
		elseif d.planter then
			self:emit("plant", { slot = "B" .. d.planter })
		elseif target.kind == "tank" then
			self:emit("build", { uid = target.id, op = "water" })
		end
		if d.wheels > 0 then
			local zone = d.zone or target.zone
			if zone then
				p.stats.wheelZones[zone] = true
			end
		end
		self:emit("flow", { target = target.key, path = d.path })
		changed = true
	end
	if changed then
		self:afterChange()
	end
end

------------------------------------------------------------------------------------------
-- Client üçün vəziyyət (yalnız göstəriş; client heç nəyi buradan serverə qaytarmır)
------------------------------------------------------------------------------------------

function Game.snapshot(self: Session): { [string]: any }
	local p = self.profile
	local level = self:power()
	local inLevel, need = Progression.progress(p.workXP)
	local step = self:currentStep()
	local questView = nil
	if step then
		local done, total = self:objectiveProgress(step.objective)
		questView = {
			chapter = p.quest.chapter,
			stepId = step.id,
			textKey = step.textKey,
			done = done,
			total = total,
			marker = step.marker,
		}
	end
	local sides = {}
	for _, side in QuestDefs.sideTasks do
		if self:zoneOpen(side.zone) then
			local done, total = self:objectiveProgress(side.objective)
			table.insert(sides, {
				id = side.id,
				textKey = side.textKey,
				done = done,
				total = total,
				finished = p.quest.side[side.id] == true,
				marker = side.marker,
			})
		end
	end
	local w = self.work
	local spec = self:cupSpec()
	return {
		coins = p.coins,
		xp = p.workXP,
		power = level,
		xpInLevel = inLevel,
		xpNeed = need,
		mastery = {
			hand = { marks = p.mastery.hand.marks, level = Progression.masteryLevel(p.mastery.hand.marks) },
			botany = { marks = p.mastery.botany.marks, level = Progression.masteryLevel(p.mastery.botany.marks) },
			mech = { marks = p.mastery.mech.marks, level = Progression.masteryLevel(p.mastery.mech.marks) },
		},
		tools = p.tools,
		equipped = p.equipped,
		hotbar = p.hotbar,
		bag = p.bag,
		bagCapacity = p.bagCapacity,
		bagUsed = Inventory.bagUsed(p),
		pending = p.pending,
		storage = p.storage,
		storageUsed = Inventory.sum(p.storage),
		storageCapacity = Constants.STORAGE_CAPACITY,
		campaign = p.campaign,
		seeds = p.seeds,
		buildInv = p.buildInv,
		cup = p.cup,
		cupCapacity = spec.capacity,
		homeWater = p.homeWater,
		cargo = p.cargo,
		groups = p.groups,
		quest = questView,
		questDone = p.quest.done,
		sides = sides,
		zones = p.zones,
		restored = p.restoredObjectIds,
		respawn = p.respawn,
		memories = p.memories,
		achievements = p.achievements,
		orders = p.orders,
		settings = p.settings,
		paused = self.paused,
		playSeconds = p.playSeconds,
		dayTime = p.dayTime,
		raining = self.raining,
		finalCompleted = p.finalCompleted,
		builds = p.builds,
		plants = p.plants,
		moisture = p.moisture,
		waterSources = p.waterSources,
		workProgress = p.workProgress,
		work = w and { id = w.id, progress = w.progress / w.def.work, tool = w.tool } or nil,
		interacted = p.interacted,
		stats = { crafted = p.stats.crafted, harvested = p.stats.harvested, cargoDelivered = p.stats.cargoDelivered },
	}
end

return Game
