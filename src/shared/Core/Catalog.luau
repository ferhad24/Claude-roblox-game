--!strict
-- Bütün kataloqları bir yerdə toplayır və startup yoxlamasını aparır:
-- ID unikallığı, istinadlar, tapşırıq asılılıqlarının dövrəsizliyi/ardıcıllığı, lokal mətn açarları.
local Shared = script.Parent.Parent
local Types = require(Shared.Types)
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

type Condition = Types.Condition
type Objective = Types.Objective

local Catalog = {
	Items = ItemDefs,
	Tools = ToolDefs,
	Work = WorkDefs,
	Builds = BuildDefs,
	Recipes = RecipeDefs,
	Plants = PlantDefs,
	Shop = ShopDefs,
	Zones = ZoneDefs,
	Quests = QuestDefs,
	Npcs = NpcDefs,
	Layout = Layout,
}

-- Qlobal sıra: hər tapşırıq addımına kampaniya boyu sıra nömrəsi.
local stepOrder: { [string]: number } = {}
local orderedSteps: { Types.QuestStep } = {}
do
	local n = 0
	for _, ch in QuestDefs.chapters do
		for _, step in ch.steps do
			n += 1
			stepOrder[step.id] = n
			table.insert(orderedSteps, step)
		end
	end
end
Catalog.stepOrder = stepOrder
Catalog.orderedSteps = orderedSteps

-- Fəslin son addımının sıra nömrəsi (fəsil bitməsi bu addımla bərabərdir).
local function chapterEndOrder(chapter: number): number
	local ch = QuestDefs.chapters[chapter]
	if not ch then
		return math.huge
	end
	return stepOrder[ch.steps[#ch.steps].id]
end
Catalog.chapterEndOrder = chapterEndOrder

-- Şərtin ən tez ödənə biləcəyi kampaniya sırası (0 = başlanğıcdan).
local function conditionOrder(cond: Condition): number
	if cond.kind == "always" then
		return 0
	elseif cond.kind == "step" then
		return stepOrder[cond.step] or math.huge
	elseif cond.kind == "chapter" then
		return chapterEndOrder(cond.chapter)
	elseif cond.kind == "zone" then
		local z = ZoneDefs.byId[cond.zone]
		if not z then
			return math.huge
		end
		return conditionOrder(z.unlock)
	elseif cond.kind == "final" then
		return chapterEndOrder(6)
	elseif cond.kind == "power" then
		return 0 -- güc ayrıca balans testində yoxlanılır
	elseif cond.kind == "all" then
		local m = 0
		for _, c in cond.list do
			m = math.max(m, conditionOrder(c))
		end
		return m
	end
	return math.huge
end
Catalog.conditionOrder = conditionOrder

-- Hər hansı əşya/qurğu/material ID-si üçün ad açarı.
function Catalog.nameKey(id: string): string
	local item = ItemDefs.byId[id]
	if item then
		return item.nameKey
	end
	local build = BuildDefs.byId[id]
	if build then
		return build.nameKey
	end
	local tool = ToolDefs.byId[id]
	if tool then
		return tool.nameKey
	end
	local plant = PlantDefs.byId[id]
	if plant then
		return plant.nameKey
	end
	return id
end

function Catalog.isMaterial(id: string): boolean
	local item = ItemDefs.byId[id]
	return item ~= nil and item.category == "material"
end

function Catalog.validate(locales: { [string]: { [string]: string } }?): { string }
	local errors: { string } = {}
	local function err(msg: string)
		table.insert(errors, msg)
	end

	-- 1. Qlobal ID unikallığı
	local seen: { [string]: string } = {}
	local function claim(id: string, where: string)
		if seen[id] then
			err(("Təkrarlanan ID '%s' (%s və %s)"):format(id, seen[id], where))
		else
			seen[id] = where
		end
	end
	for _, d in ItemDefs.list do
		claim(d.id, "item")
	end
	for _, d in ToolDefs.list do
		claim(d.id, "tool")
	end
	for _, d in WorkDefs.work do
		claim(d.id, "work")
	end
	for _, d in WorkDefs.consumers do
		claim(d.id, "consumer")
	end
	for _, d in BuildDefs.list do
		claim(d.id, "build")
		local portLists: { { Types.Port } } = { d.ports }
		if d.variants then
			for _, v in d.variants do
				table.insert(portLists, v.ports)
			end
		end
		for _, list in portLists do
			for _, port in list do
				if port.dir ~= "in" and port.dir ~= "out" then
					err(("Qurğu %s: port istiqaməti yanlışdır"):format(d.id))
				end
			end
		end
	end
	for _, d in RecipeDefs.list do
		claim(d.id, "recipe")
	end
	for _, d in RecipeDefs.groups do
		claim(d.id, "group")
	end
	for _, d in PlantDefs.list do
		claim(d.id, "plant")
	end
	for _, d in ZoneDefs.list do
		claim(d.id, "zone")
	end
	for _, step in orderedSteps do
		claim(step.id, "step")
	end
	for _, d in QuestDefs.sideTasks do
		claim(d.id, "side")
	end
	for _, d in QuestDefs.orders do
		claim(d.id, "order")
	end
	for _, d in QuestDefs.achievements do
		claim(d.id, "achievement")
	end
	for _, d in ShopDefs.bagUpgrades do
		claim(d.id, "bag")
	end
	for _, d in NpcDefs.list do
		claim(d.id, "npc")
	end
	for _, obj in Layout.objects do
		if not (obj.kind == "npc" and obj.def == obj.id) then
			claim(obj.id, "layout")
		end
	end
	for _, a in Layout.areas do
		claim(a.id, "area")
	end

	-- 2. Kataloq istinadları
	local function isItem(id: string): boolean
		return ItemDefs.byId[id] ~= nil
	end
	for _, r in RecipeDefs.list do
		local g = RecipeDefs.groupById[r.group]
		if not g then
			err(("Resept %s: naməlum qrup %s"):format(r.id, r.group))
		elseif not table.find(g.recipes, r.id) then
			err(("Resept %s qrupun (%s) siyahısında yoxdur"):format(r.id, r.group))
		end
		for _, a in r.inputs do
			if not Catalog.isMaterial(a.id) then
				err(("Resept %s: giriş material deyil: %s"):format(r.id, a.id))
			end
			if a.n <= 0 or a.n % 1 ~= 0 then
				err(("Resept %s: yanlış miqdar"):format(r.id))
			end
		end
		if not (isItem(r.output.id) or BuildDefs.byId[r.output.id]) then
			err(("Resept %s: naməlum çıxış %s"):format(r.id, r.output.id))
		end
		for _, a in r.inputs do
			if a.id == "MAT_BLOOM" then
				err(("Resept %s kampaniya materialı xərcləyir"):format(r.id))
			end
		end
	end
	for _, g in RecipeDefs.groups do
		for _, rid in g.recipes do
			local r = RecipeDefs.byId[rid]
			if not r then
				err(("Qrup %s: naməlum resept %s"):format(g.id, rid))
			elseif r.group ~= g.id then
				err(("Qrup %s: resept %s başqa qrupa aiddir"):format(g.id, rid))
			end
		end
	end
	for _, w in WorkDefs.work do
		for _, a in w.mats do
			if not Catalog.isMaterial(a.id) then
				err(("İş %s: naməlum material %s"):format(w.id, a.id))
			end
		end
		if w.minPower < 1 or w.minPower > 20 then
			err(("İş %s: minimum güc 1–20 aralığında deyil"):format(w.id))
		end
		local hasTool = false
		for _, t in ToolDefs.list do
			if (t.rates :: any)[w.workType] then
				hasTool = true
			end
		end
		if not hasTool then
			err(("İş %s: bu iş növünü görən alət yoxdur (%s)"):format(w.id, w.workType))
		end
	end
	for _, p in PlantDefs.list do
		if not isItem(p.seedId) then
			err(("Bitki %s: toxum yoxdur"):format(p.id))
		end
		for _, a in p.yield do
			if not Catalog.isMaterial(a.id) then
				err(("Bitki %s: məhsul material deyil %s"):format(p.id, a.id))
			end
		end
	end
	for _, d in ShopDefs.decor do
		if not BuildDefs.byId[d.id] then
			err(("Dekor %s qurğu kataloqunda yoxdur"):format(d.id))
		end
	end
	for _, o in QuestDefs.orders do
		if not Catalog.isMaterial(o.wants.id) then
			err(("Sifariş %s: material deyil %s"):format(o.id, o.wants.id))
		end
		if o.wants.id == "MAT_BLOOM" then
			err(("Sifariş %s kampaniya materialı istəyir"):format(o.id))
		end
	end

	-- 3. Şərt istinadları
	local function checkCondition(cond: Condition, where: string)
		if cond.kind == "step" then
			if not stepOrder[cond.step] then
				err(("%s: naməlum addım %s"):format(where, cond.step))
			end
		elseif cond.kind == "zone" then
			if not ZoneDefs.byId[cond.zone] then
				err(("%s: naməlum sahə %s"):format(where, cond.zone))
			end
		elseif cond.kind == "chapter" then
			if not QuestDefs.chapters[cond.chapter] then
				err(("%s: naməlum fəsil %d"):format(where, cond.chapter))
			end
		elseif cond.kind == "all" then
			for _, c in cond.list do
				checkCondition(c, where)
			end
		end
	end
	for _, t in ToolDefs.list do
		checkCondition(t.unlock, "Alət " .. t.id)
	end
	for _, g in RecipeDefs.groups do
		checkCondition(g.unlock, "Qrup " .. g.id)
	end
	for _, z in ZoneDefs.list do
		checkCondition(z.unlock, "Sahə " .. z.id)
	end
	for _, p in PlantDefs.list do
		checkCondition(p.unlock, "Bitki " .. p.id)
	end
	for _, d in ShopDefs.decor do
		checkCondition(d.unlock, "Dekor " .. d.id)
	end
	for _, b in ShopDefs.bagUpgrades do
		checkCondition(b.unlock, "Çanta " .. b.id)
	end
	for _, o in QuestDefs.orders do
		checkCondition(o.unlock, "Sifariş " .. o.id)
	end

	-- 4. Layout istinadları
	for _, obj in Layout.objects do
		local where = "Layout " .. obj.id
		if not ZoneDefs.byId[obj.zone] then
			err(where .. ": naməlum sahə")
		end
		if obj.kind == "work" then
			if not (obj.def and WorkDefs.workById[obj.def]) then
				err(where .. ": naməlum iş tərifi")
			end
		elseif obj.kind == "consumer" then
			local c = obj.def and WorkDefs.consumerById[obj.def]
			if not c then
				err(where .. ": naməlum yataq tərifi")
			end
			if not obj.ports or #obj.ports == 0 then
				err(where .. ": portu yoxdur")
			end
			local extra = obj.extra
			if extra and extra.lockedBy and not Layout.byId[extra.lockedBy] then
				err(where .. ": lockedBy obyekti yoxdur")
			end
		elseif obj.kind == "source" then
			if not obj.ports or #obj.ports == 0 then
				err(where .. ": mənbənin portu yoxdur")
			end
		elseif obj.kind == "spot" then
			if not obj.spawns or #obj.spawns == 0 then
				err(where .. ": yuva heç nə yaratmır")
			else
				for _, s in obj.spawns do
					if not WorkDefs.workById[s] then
						err(where .. ": naməlum resurs " .. s)
					end
				end
			end
		elseif obj.kind == "socket" then
			local b = obj.def and BuildDefs.byId[obj.def]
			if not (b and b.socketOnly) then
				err(where .. ": yuva qurğusu socketOnly deyil")
			end
			if obj.opens and not ZoneDefs.byId[obj.opens] then
				err(where .. ": naməlum açılan sahə")
			end
		elseif obj.kind == "npc" then
			if not (obj.def and NpcDefs.byId[obj.def]) then
				err(where .. ": naməlum NPC")
			end
		elseif obj.kind == "memory" or obj.kind == "cargo" then
			if not (obj.def and isItem(obj.def)) then
				err(where .. ": naməlum əşya")
			end
		elseif obj.kind == "dropoff" then
			if not obj.count or obj.count < 1 then
				err(where .. ": təhvil sayı yoxdur")
			end
		elseif obj.kind == "plot" then
			local extra = obj.extra
			if extra and extra.preplant and not PlantDefs.byId[extra.preplant] then
				err(where .. ": naməlum ilkin bitki")
			end
		elseif obj.kind == "gate" then
			local extra = obj.extra
			if not (extra and extra.unlockZone and ZoneDefs.byId[extra.unlockZone]) then
				err(where .. ": qapının açılma sahəsi yoxdur")
			end
		end
		-- Portlar tam ədəd koordinatda olmalıdır (1 stud şəbəkə), istiqamət "in" və ya "out"
		for _, p in Layout.worldPorts(obj) do
			if p.dir ~= "in" and p.dir ~= "out" then
				err(where .. ": port istiqaməti yanlışdır")
			end
			-- Kanal hissələri 4 stud-dur və portun cütlüyünü dəyişmir: sabit portlar cüt koordinatda olmalıdır,
			-- əks halda təbii mənbədən gələn xətt heç vaxt çata bilməz (gizli softlock)
			if p.x % 2 ~= 0 or p.z % 2 ~= 0 then
				err(where .. (": port cüt şəbəkədə deyil (%g, %g)"):format(p.x, p.z))
			end
		end
	end
	for _, area in Layout.areas do
		if area.origin[1] % 1 ~= 0 or area.origin[3] % 1 ~= 0 or area.size[1] % 1 ~= 0 or area.size[2] % 1 ~= 0 then
			err("Sahə " .. area.id .. ": tam ədəd olmayan ölçü")
		end
		if not ZoneDefs.byId[area.zone] then
			err("Sahə " .. area.id .. ": naməlum zona")
		end
	end

	-- Yalnız şəbəkə ilə sulanan obyektlərin portu tikinti sahəsinin içində və ya sərhədində olmalıdır
	for _, obj in Layout.objects do
		if obj.kind == "consumer" and obj.def then
			local c = WorkDefs.consumerById[obj.def]
			if c and not c.cupAllowed then
				for _, p in Layout.worldPorts(obj) do
					local ok = false
					for _, area in Layout.areas do
						local x0, z0 = area.origin[1], area.origin[3]
						if
							p.y == area.origin[2]
							and p.x >= x0
							and p.x <= x0 + area.size[1]
							and p.z >= z0
							and p.z <= z0 + area.size[2]
						then
							ok = true
						end
					end
					if not ok then
						err(("Layout %s: şəbəkə portu heç bir tikinti sahəsinə çatmır"):format(obj.id))
					end
				end
			end
		end
	end

	-- 5. Tapşırıq obyektivləri və ardıcıllıq (dövrəsizlik)
	local function objZoneOrder(id: string): number
		local obj = Layout.byId[id]
		if not obj then
			return math.huge
		end
		local z = ZoneDefs.byId[obj.zone]
		return z and conditionOrder(z.unlock) or math.huge
	end
	local function checkObjective(o: Objective, where: string, order: number)
		local function needObj(id: string, kinds: { string }?)
			local obj = Layout.byId[id]
			if not obj then
				err(("%s: naməlum obyekt %s"):format(where, id))
				return
			end
			if kinds and not table.find(kinds, obj.kind) then
				err(("%s: %s növü uyğun deyil (%s)"):format(where, id, obj.kind))
			end
			if objZoneOrder(id) >= order then
				err(("%s: %s sahəsi bu addımdan əvvəl açılmır"):format(where, id))
			end
		end
		if o.type == "restore" then
			for _, id in o.ids do
				needObj(id, { "work", "consumer" })
			end
		elseif o.type == "water" then
			needObj(o.id, { "plot", "consumer" })
		elseif o.type == "ownTool" then
			local t = ToolDefs.byId[o.tool]
			if not t then
				err(where .. ": naməlum alət " .. o.tool)
			elseif conditionOrder(t.unlock) >= order then
				err(("%s: %s aləti bu addımdan əvvəl açılmır"):format(where, o.tool))
			end
		elseif o.type == "interact" then
			needObj(o.id, { "npc", "workbench", "storage", "board" })
		elseif o.type == "crafted" then
			local found = false
			for _, r in RecipeDefs.list do
				if r.output.id == o.item then
					found = true
					local g = RecipeDefs.groupById[r.group]
					if g and conditionOrder(g.unlock) >= order then
						err(("%s: %s resepti bu addımdan əvvəl açılmır"):format(where, o.item))
					end
				end
			end
			if not found then
				err(where .. ": bu əşyanı verən resept yoxdur " .. o.item)
			end
		elseif o.type == "buildAtPort" then
			if not BuildDefs.byId[o.build] then
				err(where .. ": naməlum qurğu " .. o.build)
			end
			needObj(o.node, { "source", "consumer" })
		elseif o.type == "lineConnected" then
			needObj(o.target, { "consumer" })
			if o.via then
				for _, b in o.via do
					if not BuildDefs.byId[b] then
						err(where .. ": naməlum qurğu " .. b)
					end
				end
			end
		elseif o.type == "placed" then
			if not BuildDefs.byId[o.build] then
				err(where .. ": naməlum qurğu " .. o.build)
			end
		elseif o.type == "socket" then
			needObj(o.id, { "socket" })
		elseif o.type == "key" then
			local g = RecipeDefs.groupById[o.group]
			if not g then
				err(where .. ": naməlum qrup " .. o.group)
			elseif conditionOrder(g.unlock) >= order then
				err(("%s: %s açarı bu addımdan əvvəl açılmır"):format(where, o.group))
			end
		elseif o.type == "cargo" then
			needObj(o.target, { "dropoff" })
		elseif o.type == "harvested" then
			if o.species and not PlantDefs.byId[o.species] then
				err(where .. ": naməlum bitki " .. o.species)
			end
		elseif o.type == "memory" then
			if not isItem(o.id) then
				err(where .. ": naməlum xatirə " .. o.id)
			end
		end
	end
	for _, step in orderedSteps do
		local order = stepOrder[step.id]
		checkObjective(step.objective, "Addım " .. step.id, order)
		if step.marker and not Layout.byId[step.marker] then
			err(("Addım %s: marker obyekti yoxdur %s"):format(step.id, step.marker))
		end
		if step.unlockGroup and not RecipeDefs.groupById[step.unlockGroup] then
			err(("Addım %s: naməlum qrup %s"):format(step.id, step.unlockGroup))
		end
		local bonus = step.bonus
		if bonus then
			local lists: { { Types.Amount } } = { bonus.builds or {}, bonus.items or {}, bonus.seeds or {} }
			for _, list in lists do
				for _, a in list do
					if not (isItem(a.id) or BuildDefs.byId[a.id]) then
						err(("Addım %s: bonus əşyası yoxdur %s"):format(step.id, a.id))
					end
				end
			end
		end
	end
	for _, side in QuestDefs.sideTasks do
		checkObjective(side.objective, "Əlavə iş " .. side.id, math.huge)
	end
	for _, ch in QuestDefs.chapters do
		if ch.reward.badge and not isItem(ch.reward.badge) then
			err(("Fəsil %d: nişan yoxdur"):format(ch.chapter))
		end
	end
	-- Resept qruplarının açılması fəsil sırasına uyğun olmalıdır
	for _, g in RecipeDefs.groups do
		if conditionOrder(g.unlock) == math.huge then
			err(("Qrup %s heç vaxt açılmır"):format(g.id))
		end
	end

	-- 6. Mahiyyət mənbələri
	if #QuestDefs.bloomSources ~= 5 then
		err("Mahiyyət mənbəyi sayı 5 deyil")
	end
	for _, id in QuestDefs.bloomSources do
		local obj = Layout.byId[id]
		local c = obj and obj.def and WorkDefs.consumerById[obj.def]
		if not (c and c.bloom) then
			err(("Mahiyyət mənbəyi %s xüsusi yataq deyil"):format(id))
		end
	end
	for _, obj in Layout.objects do
		if obj.kind == "consumer" and obj.def then
			local c = WorkDefs.consumerById[obj.def]
			if c and c.bloom and not table.find(QuestDefs.bloomSources, obj.id) then
				err(("Xüsusi yataq %s mahiyyət siyahısında yoxdur"):format(obj.id))
			end
		end
	end

	-- 7. Lokal mətn açarları
	if locales then
		local keys: { string } = {}
		local function key(k: string)
			table.insert(keys, k)
		end
		for _, d in ItemDefs.list do
			key(d.nameKey)
		end
		for _, d in ToolDefs.list do
			key(d.nameKey)
		end
		for _, d in WorkDefs.work do
			key(d.nameKey)
		end
		for _, d in WorkDefs.consumers do
			key(d.nameKey)
		end
		for _, d in BuildDefs.list do
			key(d.nameKey)
		end
		for _, d in RecipeDefs.list do
			key(d.nameKey)
		end
		for _, d in RecipeDefs.groups do
			key(d.nameKey)
		end
		for _, d in PlantDefs.list do
			key(d.nameKey)
		end
		for _, d in ZoneDefs.list do
			key(d.nameKey)
		end
		for _, ch in QuestDefs.chapters do
			key(ch.titleKey)
			for _, s in ch.steps do
				key(s.textKey)
			end
		end
		for _, s in QuestDefs.sideTasks do
			key(s.textKey)
		end
		for _, a in QuestDefs.achievements do
			key(a.nameKey)
		end
		for _, b in ShopDefs.bagUpgrades do
			key(b.nameKey)
		end
		for _, n in NpcDefs.list do
			key(n.nameKey)
			for _, l in n.lines do
				key(l)
			end
		end
		for lang, map in locales do
			for _, k in keys do
				if map[k] == nil then
					err(("Lokal mətn yoxdur [%s] %s"):format(lang, k))
				end
			end
		end
	end

	return errors
end

return Catalog
