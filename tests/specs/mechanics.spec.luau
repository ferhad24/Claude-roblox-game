--!nocheck
-- Əlavə mexanikalar: çiləyici, şeh çiləyicisi (CUP_3), kompost, rəf, sifarişlər, araba/yük,
-- xatirə və əlavə iş mükafatı, nailiyyətlər, finalın vaxtından əvvəl açılmaması.
local H = require("../harness")
local Bot = require("../sim/Bot")

return function(T)
	local Layout = H.require("src/shared/Layout")
	local Water = H.require("src/shared/Core/Water")

	local function rich()
		local bot = Bot.new(H)
		local p = bot:profile()
		p.coins = 2000
		p.workXP = 7600
		for _, z in { "Z02", "Z03", "Z04", "Z05", "Z06" } do
			p.zones[z] = true
		end
		return bot, p
	end

	local function put(p, t, area, x, z, r, v, w)
		local uid = tostring(p.nextBuildId)
		p.nextBuildId += 1
		p.builds[uid] = { t = t, area = area, x = x, z = z, r = r or 0, v = v, w = w }
		return uid
	end

	T.describe("Çiləyici və şeh çiləyicisi", function()
		T.it("çiləyici 1 dozanı 6 stud içində ən quru əkin qabına verir (əlavə su yaratmır)", function()
			local bot, p = rich()
			local g = bot.game
			-- A_Z06 (origin −46,−36). Toplayıcı → çiləyici; çiləyicinin yanında 2 əkin qabı
			local catcher = put(p, "B_CATCHER", "A_Z06", 10, 10, 0, nil, 5) -- mərkəz (−36,−26), çıxış (−34,−26)
			put(p, "B_SPRINKLER", "A_Z06", 13, 10, 0) -- mərkəz (−33,−26), giriş (−34,−26)
			local a = put(p, "B_PLANTER", "A_Z06", 17, 10, 0) -- (−29,−26): məsafə 4
			local b = put(p, "B_PLANTER", "A_Z06", 13, 14, 0) -- (−33,−22): məsafə 4
			p.plants["B" .. a] = { sp = "PL_DAISY", g = 0, m = 50, ready = false }
			p.plants["B" .. b] = { sp = "PL_DAISY", g = 0, m = 0, ready = false }
			g:invalidateGraph()
			g:waterTick()
			T.expect(p.plants["B" .. b].m).toBe(25)
			T.expect(p.plants["B" .. a].m).toBe(50)
			T.expect(p.builds[catcher].w).toBe(4)
		end)

		T.it("şeh çiləyicisi suyu yaxın 3 hədəfə bölür, hər hədəf 1 doza alır", function()
			local bot, p = rich()
			p.tools["TOOL_CUP_3"] = true
			p.cup = 20
			-- Z01 əkin yerləri yan-yanadır (−10,80) və (−16,80); üçüncü hədəf: Bed_03 (−15,50) uzaqdır
			p.plants["Z01_Plot_02"] = { sp = "PL_DAISY", g = 0, m = 0, ready = false }
			p.plants["Z01_Plot_01"].m = 0
			bot:goTo("Z01_Plot_01")
			local r = T.ok(bot:act("WaterPlant", { target = "Z01_Plot_01" }))
			T.expect(r.data.n).toBe(2)
			T.expect(p.cup).toBe(18)
			T.expect(p.plants["Z01_Plot_01"].m).toBe(25)
			T.expect(p.plants["Z01_Plot_02"].m).toBe(25)
		end)
	end)

	T.describe("Kompost və rəf", function()
		T.it("kompost qabı 6 lif + 2 ləçək → 60 s aktiv vaxtda 3 kompost", function()
			local bot, p = rich()
			p.bag["MAT_FIBER"] = 6
			p.bag["MAT_PETAL"] = 2
			local uid = put(p, "B_COMPOST", "A_Z03_YARD", 4, 18, 0)
			bot:goTo(uid)
			T.ok(bot:act("Interact", { target = uid }))
			T.expect(p.bag["MAT_FIBER"]).toBe(nil)
			T.fails(bot:try("Interact", { target = uid }), "msg.notReady")
			bot:wait(59)
			T.expect(p.builds[uid].w).toBe(nil)
			bot:wait(2)
			T.expect(p.builds[uid].w).toBe(3)
			T.ok(bot:act("Interact", { target = uid }))
			T.expect(p.bag["MAT_COMPOST"]).toBe(3)
		end)

		T.it("toxum rəfi çantanı ev anbarına boşaldır", function()
			local bot, p = rich()
			p.bag["MAT_TWIG"] = 5
			local uid = put(p, "B_SORTER", "A_Z01_GARDEN", 18, 6, 0)
			bot:goTo(uid)
			T.ok(bot:act("Interact", { target = uid }))
			T.expect(p.storage["MAT_TWIG"]).toBe(5)
			T.expect(p.bag["MAT_TWIG"]).toBe(nil)
		end)
	end)

	T.describe("Əkin qabının yığılması", function()
		T.it("hazır məhsul varsa qab yığılmır; yığımdan sonra bitki toxum kimi qayıdır", function()
			local bot, p = rich()
			local uid = put(p, "B_PLANTER", "A_Z03_YARD", 10, 6, 0)
			p.plants["B" .. uid] = { sp = "PL_MOSS", g = 150, m = 50, ready = true }
			bot:goTo(uid)
			T.fails(bot:try("StoreBuild", { uid = uid }), "msg.harvestFirst")
			T.ok(bot:act("Harvest", { slot = uid }))
			T.ok(bot:act("StoreBuild", { uid = uid }))
			T.expect(p.buildInv["B_PLANTER"]).toBe(1)
			T.expect(p.seeds["SEED_MOSS"]).toBe(1)
			T.expect(p.plants["B" .. uid]).toBe(nil)
		end)
	end)

	T.describe("Sifariş lövhəsi", function()
		T.it("təklif qəbul olunur, material təhvil verilir, yeni təklif gəlir", function()
			local bot, p = rich()
			p.quest.done["Q1_WORKSHOP"] = true
			p.quest.done["Q1_SAW"] = true
			bot.game:refreshOrders()
			T.expect(#p.orders.offers).toBe(3)
			local id = p.orders.offers[1]
			local def = H.require("src/shared/Defs/QuestDefs").orderById[id]
			bot:goTo("Z01_Board")
			T.fails(bot:try("DeliverOrder", { order = id }), "msg.badRequest")
			T.ok(bot:act("AcceptOrder", { order = id }))
			T.fails(bot:try("DeliverOrder", { order = id }), "msg.notEnoughMats")
			p.storage[def.wants.id] = def.wants.n
			local coins = p.coins
			T.ok(bot:act("DeliverOrder", { order = id }))
			T.expect(p.coins).toBe(coins + def.coins)
			T.expect(p.orders.completed).toBe(1)
			T.expect(#p.orders.offers).toBe(3)
			T.expect(p.orders.active).toBe(nil)
			-- Pulsuz dəyişmə; təkliflər təkrarlanmır
			T.ok(bot:act("RerollOrder", { slot = 2 }))
			local seen = {}
			for _, o in p.orders.offers do
				T.expect(seen[o]).toBe(nil)
				seen[o] = true
			end
		end)
	end)

	T.describe("Araba və yük", function()
		T.it("araba olmadan yük götürülmür; tutum 3; çat 3 parça ilə yamanır və hövzə açılır", function()
			local bot, p = rich()
			bot:goTo("Z03_Shard_01")
			T.fails(bot:try("Interact", { target = "Z03_Shard_01" }), "hint.needCart")
			p.tools["TOOL_CART_1"] = true
			for i = 1, 3 do
				local id = ("Z03_Shard_%02d"):format(i)
				bot:goTo(id)
				T.ok(bot:act("Interact", { target = id }))
			end
			T.expect(p.cargo["CARGO_SHARD"]).toBe(3)
			T.expect(p.achievements["ACH_HEAVY_LOAD"]).toBe(true)
			-- Hövzə hələ kilidlidir
			bot.game:invalidateGraph()
			local _, locked = Water.consumerState(p, "Z03_PotBasin")
			T.expect(locked).toBe(true)
			bot:goTo("Z03_PotCrack")
			T.ok(bot:act("Interact", { target = "Z03_PotCrack" }))
			T.expect(p.restoredObjectIds["Z03_PotCrack"]).toBe(true)
			T.expect(p.cargo["CARGO_SHARD"]).toBe(nil)
			_, locked = Water.consumerState(p, "Z03_PotBasin")
			T.expect(locked).toBe(false)
		end)
	end)

	T.describe("Xatirə, əlavə iş, nailiyyət", function()
		T.it("xatirə tapılır, əlavə iş mükafatı bir dəfə verilir", function()
			local bot, p = rich()
			local coins = p.coins
			bot:goTo("Z01_Mem")
			T.ok(bot:act("Interact", { target = "Z01_Mem" }))
			T.expect(p.memories["MEM_BUTTON"]).toBe(true)
			T.expect(p.quest.side["S1_MEMORY"]).toBe(true)
			T.expect(p.coins).toBe(coins + 25)
			T.fails(bot:try("Interact", { target = "Z01_Mem" }), "hint.done")
			bot.game:afterChange()
			T.expect(p.coins).toBe(coins + 25)
		end)

		T.it("ilk cücərti nailiyyəti bitki 2-ci mərhələyə çatanda açılır", function()
			local bot, p = rich()
			local plant = p.plants["Z01_Plot_01"]
			plant.m = 100
			bot:wait(30)
			T.expect(p.achievements["ACH_FIRST_SPROUT"]).toBe(true)
		end)
	end)

	T.describe("Final", function()
		T.it("şərtlər tamamlanmadan ağac oyanmır", function()
			local bot, p = rich()
			bot:goTo("Z06_Tree")
			T.fails(bot:try("Interact", { target = "Z06_Tree" }), "msg.locked")
			T.expect(p.finalCompleted).toBe(false)
		end)

		T.it("kilidli kök rezervuarı (düyün açılmayıb) şəbəkədən su qəbul etmir", function()
			local bot, p = rich()
			local g = bot.game
			-- Kran (6,32) çıxışı (6,30) → kanal (6,28) → R3 girişi (6,26); R3 düyünü açılmayıb
			put(p, "B_CHANNEL", "A_Z06", 52, 64, 3)
			g:invalidateGraph()
			for _ = 1, 5 do
				g:waterTick()
			end
			T.expect(p.moisture["Z06_Root_03"]).toBe(nil)
			p.restoredObjectIds["Z06_Knot_03"] = true
			g:invalidateGraph()
			for _ = 1, 5 do
				g:waterTick()
			end
			T.expect(p.restoredObjectIds["Z06_Root_03"]).toBe(true)
		end)
	end)

	T.describe("Sahə qapıları", function()
		T.it("fəsil 1 bitəndə Z02, körpü ilə Z03 açılır; Z06 4 və 5-ci nişandan sonra", function()
			local bot = Bot.new(H)
			local p = bot:profile()
			local Quest = H.require("src/shared/Defs/QuestDefs")
			for _, s in Quest.chapters[1].steps do
				p.quest.done[s.id] = true
			end
			bot.game:afterChange()
			T.expect(p.zones.Z02).toBe(true)
			T.expect(p.zones.Z03).toBe(nil)
			p.quest.done["Q2_BRIDGE"] = true
			bot.game:afterChange()
			T.expect(p.zones.Z03).toBe(true)
			T.expect(p.zones.Z06).toBe(nil)
		end)
	end)

	local _ = Layout
end
