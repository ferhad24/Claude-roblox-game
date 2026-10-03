--!nocheck
-- Tam kampaniya botu: yalnız server API-si ilə (oyunçunun edə biləcəyi əməliyyatlarla) oynayır.
-- Məqsəd: softlock yoxlaması və balans ölçümü (təkrar iş, sifariş, gözləmə vaxtı).
-- Bütün vaxtlar SİMULYASİYA TƏXMİNİDİR (bax: Bot.luau).
local Campaign = {}

function Campaign.run(H, Bot, opts)
	local Layout = H.require("src/shared/Layout")
	local WorkDefs = H.require("src/shared/Defs/WorkDefs")
	local RecipeDefs = H.require("src/shared/Defs/RecipeDefs")
	local QuestDefs = H.require("src/shared/Defs/QuestDefs")
	local Inventory = H.require("src/shared/Core/Inventory")
	local Progression = H.require("src/shared/Core/Progression")

	local bot = Bot.new(H, { lenient = true })
	local g = bot.game
	local p = bot:profile()
	local metrics = {
		repeatWorks = 0, -- yenilənən yuvalarda iş
		orders = 0,
		waitSeconds = 0, -- resurs/su/bitki gözləməsi
		chapterTimes = {},
		coinsGrind = 0,
		xpGrind = 0,
		log = bot.log,
	}

	local function check(r, what)
		if not r.ok then
			error(("%s uğursuz: %s [addım %s]"):format(what, tostring(r.err), bot:step()), 2)
		end
		return r
	end

	local function waitSim(seconds)
		metrics.waitSeconds += seconds
		bot:wait(seconds)
	end

	-- Material mənbələri: hansı iş tərifləri bu materialı verir
	local yields = {}
	for _, w in WorkDefs.work do
		for _, a in w.mats do
			yields[a.id] = yields[a.id] or {}
			table.insert(yields[a.id], w.id)
		end
	end

	local function dist(pos)
		local dx, dz = pos[1] - bot.pos[1], pos[3] - bot.pos[3]
		return math.sqrt(dx * dx + dz * dz)
	end

	local function canWork(def)
		if bot:power() < def.minPower then
			return false
		end
		local tool = g:bestTool(def.workType)
		return tool ~= nil
	end

	-- Uzaq səfər: əvvəl evə qayıt (pulsuz), sonra yeri
	local function travel(id)
		local obj = Layout.byId[id]
		if obj and dist(obj.pos) > 90 then
			bot:try("GoHome", {})
			local spawn = Layout.zoneLayout.Z01.safeSpawn
			bot.pos = { spawn[1], spawn[2], spawn[3] }
			g:setPosition(spawn[1], spawn[2], spawn[3])
		end
		bot:goTo(id)
	end

	local function deposit()
		travel("Z01_Storage")
		bot:act("Interact", { target = "Z01_Storage" })
	end

	-- Bir iş obyektini tamamla (çanta doludursa boşalt)
	local function doWork(id)
		local obj = Layout.byId[id]
		travel(id)
		local r = bot:try("StartWork", { target = id })
		if not r.ok and r.err == "msg.bagFull" then
			deposit()
			travel(id)
			r = bot:try("StartWork", { target = id })
		end
		if not r.ok then
			return false, r.err
		end
		for _ = 1, 4000 do
			g:tick(0.25)
			if not g.work then
				break
			end
		end
		g:drainEvents()
		if obj.kind == "spot" then
			metrics.repeatWorks += 1
		end
		return true
	end

	-- Birdəfəlik obyektlər (açıq sahə, hələ bərpa olunmayıb, güc/alət çatır)
	local function openOneTime(defFilter)
		local list = {}
		for _, obj in Layout.objects do
			if obj.kind == "work" and p.zones[obj.zone] and not p.restoredObjectIds[obj.id] then
				local def = WorkDefs.workById[obj.def]
				if def and canWork(def) and (not defFilter or defFilter(def)) then
					table.insert(list, obj)
				end
			end
		end
		table.sort(list, function(a, b)
			return dist(a.pos) < dist(b.pos)
		end)
		return list
	end

	local function availableSpots(defFilter)
		local list = {}
		for _, obj in Layout.objects do
			if obj.kind == "spot" and p.zones[obj.zone] and g:spotAvailable(obj.id) then
				local def = WorkDefs.workById[obj.spawns[1]]
				if def and canWork(def) and (not defFilter or defFilter(def)) then
					table.insert(list, obj)
				end
			end
		end
		table.sort(list, function(a, b)
			return dist(a.pos) < dist(b.pos)
		end)
		return list
	end

	local function nextRespawn(defFilter)
		local best = math.huge
		for _, obj in Layout.objects do
			if obj.kind == "spot" and p.zones[obj.zone] then
				local def = WorkDefs.workById[obj.spawns[1]]
				if def and canWork(def) and (not defFilter or defFilter(def)) then
					local t = p.respawn[obj.id]
					if t then
						best = math.min(best, t - p.playSeconds)
					end
				end
			end
		end
		return best
	end

	local function yieldsItem(item)
		return function(def)
			for _, a in def.mats do
				if a.id == item then
					return true
				end
			end
			return false
		end
	end

	-- Material yığ: birdəfəlik obyektlərdən, sonra yenilənən yuvalardan
	local function gather(item, n)
		for _ = 1, 500 do
			if Inventory.count(p, item) + (p.pending[item] or 0) >= n then
				if (p.pending[item] or 0) > 0 then
					deposit()
				end
				return
			end
			local filter = yieldsItem(item)
			local one = openOneTime(filter)
			if #one > 0 then
				doWork(one[1].id)
			else
				local spots = availableSpots(filter)
				if #spots > 0 then
					doWork(spots[1].id)
				else
					local t = nextRespawn(filter)
					if t == math.huge then
						error(("'%s' üçün mənbə yoxdur (softlock?) [addım %s]"):format(item, bot:step()))
					end
					waitSim(math.max(1, t))
				end
			end
		end
		error("gather sonsuz dövr: " .. item)
	end

	-- Bitki məhsulu ilə ləçək/lif: Z01 sahəsində toxum ək və yığ
	local function growPetals(n)
		for _ = 1, 50 do
			if Inventory.count(p, "MAT_PETAL") >= n then
				return
			end
			local slot = "Z01_Plot_01"
			local plant = p.plants[slot]
			travel(slot)
			if not plant then
				if (p.seeds["SEED_DAISY"] or 0) == 0 then
					travel("Z01_Shop")
					check(bot:act("BuyItem", { id = "SEED_DAISY" }), "toxum")
					travel(slot)
				end
				check(bot:act("PlantSeed", { slot = slot, seed = "SEED_DAISY" }), "ək")
				plant = p.plants[slot]
			end
			if plant.ready then
				check(bot:act("Harvest", { slot = slot }), "yığ")
			else
				if plant.m < 25 then
					if p.cup <= 0 then
						travel("Z01_DewBowl")
						bot:fillFull("Z01_DewBowl")
						travel(slot)
					end
					check(bot:act("WaterPlant", { target = slot }), "sula")
				end
				local def = H.require("src/shared/Defs/PlantDefs").byId[plant.sp]
				waitSim(math.max(1, def.growSeconds - plant.g + 0.5))
			end
		end
		error("ləçək yetişmədi")
	end

	local function craft(recipeId, count)
		travel("Z01_Workbench")
		check(bot:act("Craft", { recipe = recipeId, count = count }), "craft " .. recipeId)
	end

	local recipeFor = {}
	for _, r in RecipeDefs.list do
		recipeFor[r.output.id] = r
	end

	-- Məhsulu (material və ya qurğu) təmin et: lazım olsa xammal yığ və hazırla
	local ensure
	function ensure(item, n)
		local have
		local isBuild = H.require("src/shared/Defs/BuildDefs").byId[item] ~= nil
		if isBuild then
			have = p.buildInv[item] or 0
		else
			have = Inventory.count(p, item)
		end
		if have >= n then
			return
		end
		local missing = n - have
		local r = recipeFor[item]
		if r and p.groups[r.group] then
			local times = math.ceil(missing / r.output.n)
			for _, a in r.inputs do
				ensure(a.id, a.n * times + (if isBuild then 0 else 0))
			end
			-- inputs ola bilər ki, digər ensure-lar tərəfindən xərclənib: yenidən yoxla
			for _, a in r.inputs do
				ensure(a.id, a.n * times)
			end
			craft(r.id, times)
			return
		end
		if item == "MAT_PETAL" then
			growPetals(n)
			return
		end
		if item == "MAT_COMPOST" then
			error("kompost üçün ayrıca addım lazımdır")
		end
		gather(item, n)
	end

	-- Damğa qazan: sifarişlər və yenilənən iş
	local function earnCoins(target)
		local start = p.coins
		for _ = 1, 2000 do
			if p.coins >= target then
				metrics.coinsGrind += math.max(0, p.coins - start)
				return
			end
			-- Əvvəl birdəfəlik obyektlər (təbii kəşf)
			local one = openOneTime(function(def)
				return def.coins > 0 and #def.mats >= 0
			end)
			local didOrder = false
			if #one == 0 then
				-- Sifariş: təklif olunan materialı yığa biliriksə
				local offers = p.orders.offers
				for _, id in offers do
					local def = QuestDefs.orderById[id]
					local w = def.wants
					local sourceOk = yields[w.id] ~= nil
					if sourceOk then
						travel("Z01_Board")
						bot:act("AcceptOrder", { order = id })
						ensure(w.id, w.n)
						travel("Z01_Board")
						local r = bot:try("DeliverOrder", { order = id })
						if r.ok then
							metrics.orders += 1
							didOrder = true
						end
						break
					end
				end
				if not didOrder then
					local spots = availableSpots(nil)
					if #spots > 0 then
						doWork(spots[1].id)
					else
						waitSim(math.max(1, nextRespawn(nil)))
					end
				end
			else
				doWork(one[1].id)
			end
		end
		error("damğa toplanmadı: " .. target)
	end

	local function earnPower(level)
		local before = p.workXP
		for _ = 1, 3000 do
			if bot:power() >= level then
				metrics.xpGrind += p.workXP - before
				return
			end
			local one = openOneTime(nil)
			if #one > 0 then
				doWork(one[1].id)
			else
				local offers = p.orders.offers
				local done = false
				for _, id in offers do
					local def = QuestDefs.orderById[id]
					if yields[def.wants.id] then
						travel("Z01_Board")
						bot:act("AcceptOrder", { order = id })
						ensure(def.wants.id, def.wants.n)
						travel("Z01_Board")
						if bot:try("DeliverOrder", { order = id }).ok then
							metrics.orders += 1
							done = true
						end
						break
					end
				end
				if not done then
					local spots = availableSpots(nil)
					if #spots > 0 then
						doWork(spots[1].id)
					else
						waitSim(math.max(1, nextRespawn(nil)))
					end
				end
			end
		end
		error("güc çatmadı: " .. level)
	end

	local function buy(id, price)
		if price and p.coins < price then
			earnCoins(price)
		end
		travel("Z01_Shop")
		check(bot:act("BuyItem", { id = id }), "al " .. id)
	end

	local function buyKey(group, price)
		if p.coins < price then
			earnCoins(price)
		end
		travel("Z01_Workbench")
		check(bot:act("BuyItem", { id = group }), "açar " .. group)
	end

	local function talk(id)
		travel(id)
		check(bot:act("Interact", { target = id }), "danış " .. id)
	end

	local function place(build, area, x, z, r, v)
		local a = Layout.areaById[area]
		bot:goToPos(a.origin[1] + x, a.origin[2], a.origin[3] + z)
		g:setPosition(a.origin[1] + x, a.origin[2], a.origin[3] + z)
		return check(
			bot:act("Place", { build = build, area = area, x = x, z = z, r = r or 0, v = v }),
			"yerləşdir " .. build
		)
	end

	local function move(uid, area, x, z, r, v)
		local a = Layout.areaById[area]
		bot:goToPos(a.origin[1] + x, a.origin[2], a.origin[3] + z)
		g:setPosition(a.origin[1] + x, a.origin[2], a.origin[3] + z)
		return check(
			bot:act("MoveBuild", { uid = uid, area = area, x = x, z = z, r = r or 0, v = v }),
			"köçür " .. uid
		)
	end

	local function findBuild(t, pred)
		for uid, b in p.builds do
			if b.t == t and (not pred or pred(b)) then
				return uid
			end
		end
		return nil
	end

	local function waterBed(id, source)
		for _ = 1, 40 do
			if p.restoredObjectIds[id] then
				return
			end
			if p.cup <= 0 then
				travel(source)
				bot:fillFull(source)
			end
			travel(id)
			check(bot:act("WaterPlant", { target = id }), "sula " .. id)
		end
		error("yataq dirçəlmədi " .. id)
	end

	local function waitUntil(pred, maxSeconds, what)
		local t = 0
		while not pred() do
			waitSim(1)
			t += 1
			if t > maxSeconds then
				error(("gözləmə bitmədi: %s [addım %s]"):format(what, bot:step()))
			end
		end
	end

	-- Sahənin əlavə işləri: xatirə, bütün birdəfəlik obyektlər, sahə bitkisini ək (yığım sonra)
	local zonePlant = {
		Z01 = { plot = "Z01_Plot_02", seed = "SEED_DAISY" },
		Z02 = { plot = "Z02_Plot_01", seed = "SEED_CLOVER" },
		Z03 = { plot = "Z03_Plot_01", seed = "SEED_MOSS" },
		Z04 = { plot = "Z04_Plot_01", seed = "SEED_MARIGOLD" },
		Z05 = { plot = "Z05_Plot_01", seed = "SEED_LAVENDER" },
	}
	local function harvestReady()
		for _, info in zonePlant do
			local plant = p.plants[info.plot]
			if plant and plant.ready and p.zones[Layout.byId[info.plot].zone] then
				travel(info.plot)
				bot:try("Harvest", { slot = info.plot })
			end
		end
	end
	local function doExtras(zone)
		if opts and opts.skipExtras then
			return
		end
		for _, obj in Layout.objects do
			if obj.zone == zone and obj.kind == "memory" and not p.restoredObjectIds[obj.id] then
				travel(obj.id)
				bot:try("Interact", { target = obj.id })
			end
		end
		for _, obj in Layout.objects do
			if obj.zone == zone and obj.kind == "work" and not p.restoredObjectIds[obj.id] then
				local def = WorkDefs.workById[obj.def]
				if canWork(def) then
					doWork(obj.id)
				end
			end
		end
		local info = zonePlant[zone]
		if info and not p.plants[info.plot] then
			buy(info.seed, 30)
			travel(info.plot)
			bot:try("PlantSeed", { slot = info.plot, seed = info.seed })
			for _ = 1, 2 do
				if p.cup <= 0 then
					local src = if zone == "Z05" then "Z05_Gutter" else "Z01_DewBowl"
					travel(src)
					bot:fillFull(src)
				end
				travel(info.plot)
				bot:try("WaterPlant", { target = info.plot })
			end
		end
		harvestReady()
	end

	-- Save/load dövrəsi: profil serializasiya edilir (JSON), miqrasiyadan keçir və yeni sessiya yaradılır
	local function saveLoadCycle()
		local serde = require("@lune/serde")
		local Profile = H.require("src/shared/Core/Profile")
		local Game = H.require("src/shared/Core/Game")
		local json = serde.encode("json", p)
		local data = serde.decode("json", json)
		local loaded, why = Profile.migrate(data, 0)
		assert(loaded, "profil yüklənmədi: " .. tostring(why))
		local newGame = Game.new(loaded)
		newGame:setPosition(bot.pos[1], bot.pos[2], bot.pos[3])
		newGame:drainEvents()
		bot.game = newGame
		g = newGame
		p = loaded
		metrics.saveLoads = (metrics.saveLoads or 0) + 1
	end

	local function chapterDone(n)
		if opts and opts.saveLoadEachChapter then
			saveLoadCycle()
		end
		metrics.chapterTimes[n] = bot:totalSeconds()
		bot:note("Fəsil %d bitdi: damğa=%d güc=%d XP=%d", n, p.coins, bot:power(), p.workXP)
		local ch = QuestDefs.chapters[n]
		if n <= 5 then
			doExtras(ch.zone)
			bot:note("  əlavə işlərdən sonra: damğa=%d güc=%d XP=%d", p.coins, bot:power(), p.workXP)
		end
	end

	------------------------------------------------------------------------------------
	-- FƏSİL 1 (ilk 20 dəqiqə spesifikasiyası ilə eyni axın)
	------------------------------------------------------------------------------------
	for i = 1, 3 do
		doWork(("Z01_Leaf_%02d"):format(i))
	end
	travel("Z01_DewBowl")
	bot:fillFull("Z01_DewBowl")
	travel("Z01_Plot_01")
	check(bot:act("WaterPlant", { target = "Z01_Plot_01" }), "toxum")
	buy("TOOL_SHEARS_1", 15)
	deposit()
	for i = 1, 3 do
		doWork(("Z01_Thread_%02d"):format(i))
	end
	talk("Z01_Workbench")
	craft("C_ROPE", 1)
	earnCoins(60)
	buy("TOOL_SAW_1", 60)
	ensure("MAT_PLANK", 4)
	ensure("B_WHEEL", 1)
	place("B_WHEEL", "A_Z01_LINE", 2, 4, 0)
	place("B_CHANNEL", "A_Z01_LINE", 6, 4, 0)
	place("B_CHANNEL", "A_Z01_LINE", 10, 4, 0)
	waitUntil(function()
		return p.restoredObjectIds["Z01_Bed_01"] == true
	end, 60, "Bed_01")
	waterBed("Z01_Bed_02", "Z01_DewBowl")
	waterBed("Z01_Bed_03", "Z01_DewBowl")
	assert(p.quest.chapter == 2, "fəsil 1 bitmədi: " .. bot:step())
	chapterDone(1)

	------------------------------------------------------------------------------------
	-- FƏSİL 2: Şeh çəmənliyi
	------------------------------------------------------------------------------------
	talk("NPC_CIRT_Z02")
	buyKey("G_Z02", 150)
	ensure("B_CATCHER", 1)
	-- Toplayıcı (84,40) → çarx (88,40) → xüsusi yatağın girişi (90,40). A_Z02_LINE origin (70,32)
	place("B_CATCHER", "A_Z02_LINE", 14, 8, 0)
	local z01Wheel = findBuild("B_WHEEL")
	move(z01Wheel, "A_Z02_LINE", 18, 8, 0)
	assert(bot:step() ~= "Q2_WHEEL_LINE", "çarx xətti qoşulmadı")
	waterBed("Z02_Bed_01", "Z01_DewBowl")
	waterBed("Z02_Bed_02", "Z01_DewBowl")
	waterBed("Z02_Bed_03", "Z01_DewBowl")
	waitUntil(function()
		return p.restoredObjectIds["Z02_BloomBed_01"] == true
	end, 200, "Z02 xüsusi yatağı (toplayıcı + çarx)")
	ensure("B_BRIDGE", 1)
	bot:goTo("Z02_BridgeSocket")
	check(bot:act("Place", { build = "B_BRIDGE", socket = "Z02_BridgeSocket" }), "körpü")
	assert(p.quest.chapter == 3, "fəsil 2 bitmədi: " .. bot:step())
	chapterDone(2)

	------------------------------------------------------------------------------------
	-- FƏSİL 3: Köhnə dibçək
	------------------------------------------------------------------------------------
	if bot:power() < 5 then
		earnPower(5)
	end
	buy("TOOL_SHOVEL_1", 180)
	for i = 1, 3 do
		assert(doWork(("Z03_Soil_%02d"):format(i)))
	end
	buy("TOOL_CART_1", 220)
	for i = 1, 3 do
		travel(("Z03_Shard_%02d"):format(i))
		check(bot:act("Interact", { target = ("Z03_Shard_%02d"):format(i) }), "yük")
	end
	travel("Z03_PotCrack")
	check(bot:act("Interact", { target = "Z03_PotCrack" }), "çat")
	talk("NPC_NARGIZ_Z03")
	buyKey("G_Z03", 200)
	-- Kompost: Nərgizdən 2; qalan 4 üçün kompost qabı (6 lif + 2 ləçək → 3 kompost, 60 s)
	ensure("B_COMPOST", 1)
	place("B_COMPOST", "A_Z03_YARD", 4, 18, 0)
	local bin = findBuild("B_COMPOST")
	for _ = 1, 2 do
		ensure("MAT_FIBER", 6)
		ensure("MAT_PETAL", 2)
		bot:goTo(bin)
		check(bot:act("Interact", { target = bin }), "kompost yüklə")
		waitSim(61)
		bot:goTo(bin)
		check(bot:act("Interact", { target = bin }), "kompost götür")
	end
	ensure("MAT_CLAY", 12)
	for i = 1, 3 do
		ensure("B_PLANTER", 1)
		local r = place("B_PLANTER", "A_Z03_YARD", 10 + i * 6, 6, 0)
		local uid = r.data.uid
		if (p.seeds["SEED_DAISY"] or 0) == 0 and (p.seeds["SEED_MOSS"] or 0) == 0 then
			buy("SEED_DAISY", 8)
		end
		local seed = if (p.seeds["SEED_MOSS"] or 0) > 0 then "SEED_MOSS" else "SEED_DAISY"
		bot:goTo(uid)
		check(bot:act("PlantSeed", { slot = uid, seed = seed }), "ək")
		-- İki doza (50): bir doza 30 s-dən sonra 25-dən aşağı düşür
		for _ = 1, 2 do
			if p.cup <= 0 then
				travel("Z01_DewBowl")
				bot:fillFull("Z01_DewBowl")
			end
			bot:goTo(uid)
			check(bot:act("WaterPlant", { target = uid }), "qabı sula")
		end
	end
	assert(bot:step() == "Q3_POTLINE", "əkin qabları sayılmadı: " .. bot:step())
	-- Dibçək xətti: toplayıcını dibçəyin içinə köçür (82,−66) → hövzənin girişi (84,−66)
	local catcher = findBuild("B_CATCHER")
	move(catcher, "A_Z03_POT", 10, 10, 0)
	waterBed("Z03_BloomBed_01", "Z01_DewBowl")
	waitUntil(function()
		return p.restoredObjectIds["Z03_PotBasin"] == true
	end, 200, "dibçək hövzəsi")
	assert(p.quest.chapter == 4, "fəsil 3 bitmədi: " .. bot:step())
	chapterDone(3)

	------------------------------------------------------------------------------------
	-- FƏSİL 4: Düyünlü köklər
	------------------------------------------------------------------------------------
	if bot:power() < 7 then
		earnPower(7)
	end
	buy("TOOL_LEVER_1", 280)
	for i = 1, 4 do
		assert(doWork(("Z04_Heavy_%02d"):format(i)))
	end
	talk("NPC_CIRT_Z04")
	buyKey("G_Z04", 300)
	ensure("MAT_GEAR", 2)
	waterBed("Z04_BloomBed_01", "Z01_DewBowl")
	ensure("MAT_GEAR", 2)
	ensure("B_LIFT", 1)
	bot:goTo("Z04_LiftSocket")
	check(bot:act("Place", { build = "B_LIFT", socket = "Z04_LiftSocket" }), "lift")
	assert(p.quest.chapter == 5, "fəsil 4 bitmədi: " .. bot:step())
	chapterDone(4)

	------------------------------------------------------------------------------------
	-- FƏSİL 5: Şüşə istixana
	------------------------------------------------------------------------------------
	buy("TOOL_BRUSH_1", 250)
	if bot:power() < 8 then
		earnPower(8)
	end
	for i = 1, 4 do
		assert(doWork(("Z05_Panel_%02d"):format(i)))
	end
	talk("NPC_CIRT_Z05")
	buyKey("G_Z05", 415)
	ensure("B_PUMP", 1)
	-- Toplayıcı (−92,40) → çarx (−88,40) → nasos (−84,40) → rəfdəki yatağın girişi (−82,40)
	-- A_Z05_GH origin (−118, −18): lokal = dünya + (118, 18)
	move(findBuild("B_CATCHER"), "A_Z05_GH", 26, 58, 0)
	move(findBuild("B_WHEEL"), "A_Z05_GH", 30, 58, 0)
	place("B_PUMP", "A_Z05_GH", 34, 58, 0)
	assert(bot:step() ~= "Q5_PUMP", "nasos xətti qoşulmadı: " .. bot:step())
	-- 3 əkin qabını istixanaya köçür (bitkilər qalır), rütubəti təmin et
	local i = 0
	for uid, b in p.builds do
		if b.t == "B_PLANTER" then
			i += 1
			-- Dünya (−112, 0/6/12): şüşə qutularından və yollardan uzaq
			move(uid, "A_Z05_GH", 6, 12 + i * 6, 0)
			local plant = p.plants["B" .. uid]
			while plant and plant.m < 50 do
				if p.cup <= 0 then
					travel("Z05_Gutter")
					bot:fillFull("Z05_Gutter")
				end
				bot:goTo(uid)
				check(bot:act("WaterPlant", { target = uid }), "sula qab")
			end
		end
	end
	waterBed("Z05_BloomBed_01", "Z05_Gutter")
	waitUntil(function()
		return p.restoredObjectIds["Z05_BloomBed_02"] == true
	end, 300, "rəfdəki yataq (nasos)")
	assert(p.quest.chapter == 6, "fəsil 5 bitmədi: " .. bot:step())
	chapterDone(5)

	------------------------------------------------------------------------------------
	-- FƏSİL 6: Ürək ağacı
	------------------------------------------------------------------------------------
	-- Qalan bitki yığımları (əlavə işlər)
	for _ = 1, 8 do
		local pendingPlant = false
		for _, info in zonePlant do
			local plant = p.plants[info.plot]
			if plant and not plant.ready then
				pendingPlant = true
			end
		end
		harvestReady()
		if not pendingPlant or (opts and opts.skipExtras) then
			break
		end
		waitSim(30)
	end
	metrics.xpBefore15 = p.workXP
	local xpBefore15 = p.workXP
	if bot:power() < 15 then
		bot:note(
			"Güc 15 üçün əlavə iş lazımdır: güc=%d XP=%d (lazım %d)",
			bot:power(),
			p.workXP,
			Progression.totalXpFor(15)
		)
		earnPower(15)
	end
	metrics.xpGapTo15 = p.workXP - xpBefore15
	buy("TOOL_SHEARS_2", 600)
	for k = 1, 5 do
		assert(doWork(("Z06_Knot_%02d"):format(k)))
	end
	-- Kök rezervuarları: R3 kranından bir kanalla; qalanlar toplayıcılarla (növbə ilə köçürülür)
	ensure("B_CHANNEL", 1)
	-- A_Z06 origin (−46, −36): lokal = dünya + (46, 36). Kanal mərkəzi (6, 28), r=3 (axın −Z)
	place("B_CHANNEL", "A_Z06", 52, 64, 3)
	local reservoirs = {
		{ id = "Z06_Root_01", port = { 28, 8 } },
		{ id = "Z06_Root_02", port = { 20, 22 } },
		{ id = "Z06_Root_04", port = { -8, 22 } },
		{ id = "Z06_Root_05", port = { -16, 8 } },
	}
	-- Toplayıcı sayı 4: lazım olan qədər hazırla
	while
		#(function()
				local l = {}
				for _, b in p.builds do
					if b.t == "B_CATCHER" then
						table.insert(l, b)
					end
				end
				return l
			end)()
			+ (p.buildInv["B_CATCHER"] or 0)
		< 4
	do
		ensure("B_CATCHER", (p.buildInv["B_CATCHER"] or 0) + 1)
	end
	local catchers = {}
	for uid, b in p.builds do
		if b.t == "B_CATCHER" then
			table.insert(catchers, uid)
		end
	end
	for idx, res in reservoirs do
		local uid = catchers[idx]
		local lx, lz = res.port[1] + 46, res.port[2] + 2 + 36
		if uid then
			move(uid, "A_Z06", lx, lz, 3)
		else
			local r = place("B_CATCHER", "A_Z06", lx, lz, 3)
			catchers[idx] = r.data.uid
		end
	end
	waitUntil(function()
		for k = 1, 5 do
			if not p.restoredObjectIds[("Z06_Root_%02d"):format(k)] then
				return false
			end
		end
		return true
	end, 600, "kök rezervuarları")
	assert(bot:step() == "Q6_CROWN", "addım gözlənilən deyil: " .. bot:step())
	-- Tac: toplayıcı (6,−24) r=1 → çarx (6,−20) → nasos (6,−16) → tacın girişi (6,−14)
	move(catchers[1], "A_Z06", 52, 12, 1)
	move(findBuild("B_WHEEL"), "A_Z06", 52, 16, 1)
	move(findBuild("B_PUMP"), "A_Z06", 52, 20, 1)
	waitUntil(function()
		return p.restoredObjectIds["Z06_Crown"] == true
	end, 300, "tac")
	assert(bot:step() == "Q6_WAKE", "oyanış addımı deyil: " .. bot:step())
	travel("Z06_Tree")
	check(bot:act("Interact", { target = "Z06_Tree" }), "ağacı oyat")
	assert(p.finalCompleted, "final tamamlanmadı")
	chapterDone(6)
	metrics.final = true
	metrics.profile = p
	metrics.game = g
	metrics.coins = p.coins
	metrics.power = bot:power()
	metrics.totalSeconds = bot:totalSeconds()
	metrics.activeSeconds = p.playSeconds
	metrics.walkSeconds = bot.walkSeconds
	metrics.bot = bot
	return metrics
end

return Campaign
