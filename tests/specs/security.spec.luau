--!nocheck
-- Bölmə 25 məcburi sınaq ssenariləri (məntiq səviyyəsi).
local H = require("../harness")
local Bot = require("../sim/Bot")

return function(T)
	local Profile = H.require("src/shared/Core/Profile")
	local Game = H.require("src/shared/Core/Game")
	local Layout = H.require("src/shared/Layout")

	local function richBot()
		local bot = Bot.new(H)
		local p = bot:profile()
		p.coins = 1000
		p.workXP = 2000
		return bot, p
	end

	T.describe("Təkrar sorğular (duplikasiya)", function()
		T.it("eyni Buy sorğusu (eyni rid) iki dəfə ödəniş/əşya yaratmır", function()
			local bot, p = richBot()
			p.quest.done["Q1_LEAVES"] = true
			bot:goTo("Z01_Shop")
			local r1 = bot.game:handle("BuyItem", { id = "SEED_DAISY", rid = 77 }, 1)
			local r2 = bot.game:handle("BuyItem", { id = "SEED_DAISY", rid = 77 }, 2)
			T.ok(r1)
			T.expect(r2.dup).toBe(true)
			T.expect(p.seeds["SEED_DAISY"]).toBe(1)
			T.expect(p.coins).toBe(1000 - 8)
		end)

		T.it("eyni Craft sorğusu (eyni rid) bir dəfə işləyir", function()
			local bot, p = richBot()
			p.groups["G_Z01"] = true
			p.bag["MAT_TWIG"] = 4
			bot.game:handle("Craft", { recipe = "C_PLANK", count = 1, rid = "a1" }, 1)
			bot.game:handle("Craft", { recipe = "C_PLANK", count = 1, rid = "a1" }, 2)
			T.expect(p.bag["MAT_PLANK"]).toBe(1)
			T.expect(p.bag["MAT_TWIG"]).toBe(2)
		end)

		T.it("Harvest təkrarı ikinci məhsul vermir", function()
			local bot, p = richBot()
			p.plants["Z01_Plot_01"] = { sp = "PL_DAISY", g = 90, m = 50, ready = true }
			bot:goTo("Z01_Plot_01")
			T.ok(bot.game:handle("Harvest", { slot = "Z01_Plot_01" }, 1))
			T.fails(bot.game:handle("Harvest", { slot = "Z01_Plot_01" }, 2), "msg.notReady")
			T.expect(p.bag["MAT_PETAL"]).toBe(2)
		end)

		T.it("bir obyektin bitirmə mükafatı bir dəfə yazılır", function()
			local bot, p = richBot()
			bot:work("Z01_Leaf_01")
			local coins = p.coins
			T.fails(bot:try("StartWork", { target = "Z01_Leaf_01" }), "hint.done")
			T.expect(p.coins).toBe(coins)
		end)
	end)

	T.describe("İş doğrulaması", function()
		T.it("uyğun olmayan alət və ya güc yoxdursa iş başlamır", function()
			local bot = Bot.new(H)
			bot:goTo("Z01_Thread_01")
			T.fails(bot:try("StartWork", { target = "Z01_Thread_01" }), "msg.wrongTool")
			bot:goTo("Z01_Branch_01")
			T.fails(bot:try("StartWork", { target = "Z01_Branch_01" }), "msg.needPower")
		end)

		T.it("uzaq obyektdə iş başlamır; 8 stud-dan uzaqlaşanda iş dayanır", function()
			local bot, p = richBot()
			bot:goTo("Z01_Leaf_05")
			T.fails(bot:try("StartWork", { target = "Z01_Leaf_01" }), "msg.tooFar")
			bot:goTo("Z01_Leaf_01")
			T.ok(bot:try("StartWork", { target = "Z01_Leaf_01" }))
			bot.game:tick(0.5)
			local obj = Layout.byId["Z01_Leaf_01"]
			bot.game:setPosition(obj.pos[1] + 20, 0, obj.pos[3])
			bot.game:tick(0.5)
			T.expect(bot.game.work).toBe(nil)
			T.expect(p.restoredObjectIds["Z01_Leaf_01"]).toBe(nil)
			T.expect(p.workProgress["Z01_Leaf_01"] > 0).toBeTruthy()
		end)

		T.it("iş yarıda dayanıb davam edəndə irəliləyiş və mükafat doğru qalır", function()
			local bot, p = richBot()
			p.workXP = 0
			bot:goTo("Z01_Leaf_01")
			T.ok(bot:try("StartWork", { target = "Z01_Leaf_01" }))
			bot.game:tick(1) -- 2 iş vahidindən 1-i
			T.ok(bot:try("StopWork", {}))
			local saved = p.workProgress["Z01_Leaf_01"]
			T.expect(saved).toBeNear(1, 0.01)
			bot.game:tick(5) -- iş dayanıb: irəliləyiş dəyişmir
			T.expect(p.workProgress["Z01_Leaf_01"]).toBe(saved)
			T.ok(bot:try("StartWork", { target = "Z01_Leaf_01" }))
			bot.game:tick(1.1)
			T.expect(p.restoredObjectIds["Z01_Leaf_01"]).toBe(true)
			T.expect(p.coins).toBe(1005)
			T.expect(p.workXP).toBe(8)
			T.expect(p.bag["MAT_FIBER"]).toBe(4)
		end)
	end)

	T.describe("Qurğular və su", function()
		T.it("qurğunu yığıb yenidən qoymaq material və su çoxaltmır", function()
			local bot, p = richBot()
			p.zones.Z06 = true
			p.buildInv["B_TANK"] = 1
			bot.game:setPosition(-26, 0, -16)
			local r = T.ok(bot:act("Place", { build = "B_TANK", area = "A_Z06", x = 20, z = 20, r = 0 }))
			local uid = r.data.uid
			p.builds[uid].w = 10
			T.ok(bot:act("StoreBuild", { uid = uid }))
			T.expect(p.buildInv["B_TANK"]).toBe(1)
			T.expect(p.homeWater).toBe(10)
			T.expect(p.storage["MAT_CLAY"]).toBe(nil)
			T.ok(bot:act("Place", { build = "B_TANK", area = "A_Z06", x = 20, z = 20, r = 0 }))
			local placedUid
			for id, b in p.builds do
				if b.t == "B_TANK" then
					placedUid = id
				end
			end
			T.expect(p.builds[placedUid].w).toBe(0)
			T.expect(p.buildInv["B_TANK"]).toBe(nil)
		end)

		T.it("ev rezervuarı doludursa çəni yığmaq üçün əvvəl boşaltma lazımdır", function()
			local bot, p = richBot()
			p.zones.Z06 = true
			p.buildInv["B_TANK"] = 1
			p.homeWater = 110
			bot.game:setPosition(-26, 0, -16)
			local r = T.ok(bot:act("Place", { build = "B_TANK", area = "A_Z06", x = 20, z = 20, r = 0 }))
			p.builds[r.data.uid].w = 20
			T.fails(bot:try("StoreBuild", { uid = r.data.uid }), "msg.drainFirst")
			T.ok(bot:act("DrainBuild", { uid = r.data.uid }))
			T.ok(bot:act("StoreBuild", { uid = r.data.uid }))
			T.expect(p.homeWater).toBe(110)
		end)

		T.it("yollara və əsas obyektlərin üstünə qurğu qoymaq olmur", function()
			local bot, p = richBot()
			p.buildInv["B_WHEEL"] = 1
			bot.game:setPosition(20, 0, 86)
			-- Yatağın üstü (A_Z01_EAST sahəsində deyil, ona görə sahədən kənar) və sahədən çıxan footprint
			T.fails(bot:try("Place", { build = "B_WHEEL", area = "A_Z01_LINE", x = 11, z = 4, r = 0 }), "msg.cantPlace")
			-- Masa altına çıxan cığır A_Z01_GARDEN sahəsindən keçir: çarx yolu bağlaya bilməz, kanal (alçaq) qoyula bilər
			bot.game:setPosition(-44, 0, 100)
			T.fails(
				bot:try("Place", { build = "B_WHEEL", area = "A_Z01_GARDEN", x = 4, z = 4, r = 0 }),
				"msg.cantPlace"
			)
			p.buildInv["B_CHANNEL"] = 1
			T.ok(bot:act("Place", { build = "B_CHANNEL", area = "A_Z01_GARDEN", x = 4, z = 4, r = 0 }))
		end)

		T.it("limitdən artıq qurğu hazırlanmır", function()
			local bot, p = richBot()
			p.groups["G_Z01"] = true
			p.buildInv["B_WHEEL"] = 4
			p.bag["MAT_PLANK"] = 4
			p.bag["MAT_PEBBLE"] = 2
			p.bag["MAT_ROPE"] = 1
			bot:goTo("Z01_Workbench")
			T.fails(bot:try("Craft", { recipe = "R_WHEEL", count = 1 }), "msg.limit")
			T.expect(p.bag["MAT_PLANK"]).toBe(4)
		end)
	end)

	T.describe("Bitkilər, pauza, oflayn", function()
		T.it("bitki susuz dayanır, ölmür", function()
			local bot, p = richBot()
			local plant = p.plants["Z01_Plot_01"]
			plant.m = 0
			bot:wait(300)
			T.expect(p.plants["Z01_Plot_01"]).toBeTruthy()
			T.expect(plant.g).toBe(0)
			plant.m = 50
			bot:wait(30)
			T.expect(plant.g > 0).toBeTruthy()
		end)

		T.it("pauza bitki, su və iş vaxtını dayandırır", function()
			local bot, p = richBot()
			local plant = p.plants["Z01_Plot_01"]
			plant.m = 100
			bot:goTo("Z01_Leaf_01")
			T.ok(bot:try("StartWork", { target = "Z01_Leaf_01" }))
			T.ok(bot:try("SetPaused", { paused = true }))
			local g0, play0 = plant.g, p.playSeconds
			bot.game:tick(10)
			T.expect(plant.g).toBe(g0)
			T.expect(p.playSeconds).toBe(play0)
			T.expect(bot.game.work).toBe(nil)
			T.fails(bot:try("StartWork", { target = "Z01_Leaf_01" }), "msg.paused")
			T.ok(bot:try("SetPaused", { paused = false }))
			bot.game:tick(1)
			T.expect(plant.g > g0).toBeTruthy()
		end)

		T.it("oflayn müddətdə heç nə dəyişmir (yeni sessiya eyni profildən başlayır)", function()
			local bot, p = richBot()
			local plant = p.plants["Z01_Plot_01"]
			plant.m = 80
			plant.g = 10
			local saved = Profile.clone(p)
			-- Oflayn vaxt: sessiya yoxdur, heç bir tick yoxdur. Sonra yenidən yükləmə:
			local loaded = Profile.migrate(saved, 99999)
			local g2 = Game.new(loaded)
			T.expect(g2.profile.plants["Z01_Plot_01"].g).toBe(10)
			T.expect(g2.profile.plants["Z01_Plot_01"].m).toBe(80)
			T.expect(g2.profile.playSeconds).toBe(p.playSeconds)
		end)

		T.it("pauzadan qayıtmaq təkrar mükafat vermir", function()
			local bot, p = richBot()
			bot:work("Z01_Leaf_01")
			local coins = p.coins
			bot:act("SetPaused", { paused = true })
			bot:act("SetPaused", { paused = false })
			bot.game:afterChange()
			T.expect(p.coins).toBe(coins)
		end)
	end)

	T.describe("Lift", function()
		T.it("lift həm aşağıdan, həm yuxarıdan işləyir; qurulmayıbsa işləmir", function()
			local bot, p = richBot()
			p.zones.Z04 = true
			p.zones.Z05 = true
			bot.game:setPosition(-100, 0, -46)
			T.fails(bot:try("UseLift", { socket = "Z04_LiftSocket" }), "msg.locked")
			p.builds["50"] = { t = "B_LIFT", socket = "Z04_LiftSocket", x = 0, z = 0, r = 0 }
			local up = T.ok(bot:act("UseLift", { socket = "Z04_LiftSocket" }))
			T.expect(up.data.pos[2]).toBe(24)
			bot.game:setPosition(-100, 24, -39)
			local down = T.ok(bot:act("UseLift", { socket = "Z04_LiftSocket" }))
			T.expect(down.data.pos[2]).toBe(0)
			bot.game:setPosition(0, 0, 80)
			T.fails(bot:try("UseLift", { socket = "Z04_LiftSocket" }), "msg.tooFar")
		end)
	end)

	T.describe("Yanlış sorğular", function()
		T.it("NaN, sonsuz, hədsiz count və naməlum ID rədd olunur", function()
			local bot, p = richBot()
			p.groups["G_Z01"] = true
			p.bag["MAT_TWIG"] = 99
			bot:goTo("Z01_Workbench")
			T.fails(bot:try("Craft", { recipe = "C_PLANK", count = 0 / 0 }), "msg.badRequest")
			T.fails(bot:try("Craft", { recipe = "C_PLANK", count = math.huge }), "msg.badRequest")
			T.fails(bot:try("Craft", { recipe = "C_PLANK", count = 1000 }), "msg.badRequest")
			T.fails(bot:try("Craft", { recipe = "C_PLANK", count = 1.5 }), "msg.badRequest")
			T.fails(bot:try("Craft", { recipe = "NOPE", count = 1 }), "msg.badRequest")
			T.fails(
				bot:try("Place", { build = "B_CHANNEL", area = "A_Z01_LINE", x = 0 / 0, z = 1, r = 0 }),
				"msg.badRequest"
			)
			T.fails(bot:try("StartWork", { target = string.rep("x", 200) }), "msg.badRequest")
			T.fails(bot:try("MoveBuild", { uid = "999", area = "A_Z01_LINE", x = 2, z = 2, r = 0 }), "msg.badRequest")
			T.fails(bot.game:handle("Nope", {}, 1000), "msg.badRequest")
			T.fails(bot.game:handle("BuyItem", "notatable", 1001), "msg.badRequest")
			T.expect(p.bag["MAT_TWIG"]).toBe(99)
		end)

		T.it("client mükafat/qiymət göndərsə nəzərə alınmır", function()
			local bot, p = richBot()
			p.quest.done["Q1_LEAVES"] = true
			bot:goTo("Z01_Shop")
			T.ok(bot:act("BuyItem", { id = "TOOL_SHEARS_1", price = 0, coins = 99999 }))
			T.expect(p.coins).toBe(1000 - 15)
		end)

		T.it("sürət limiti: alış/craft saniyədə 2", function()
			local bot, p = richBot()
			p.zones.Z02 = true
			bot:goTo("Z01_Shop")
			local okCount = 0
			for i = 1, 5 do
				local r = bot.game:handle("BuyItem", { id = "SEED_DAISY" }, 100 + i * 0.01)
				if r.ok then
					okCount += 1
				end
			end
			T.expect(okCount).toBe(2)
		end)

		T.it("kilidli sahənin obyekti işlənmir, kilidli alət alınmır", function()
			local bot, p = richBot()
			bot:goTo("Z02_Branch_01")
			T.fails(bot:try("StartWork", { target = "Z02_Branch_01" }), "msg.locked")
			bot:goTo("Z01_Shop")
			T.fails(bot:try("BuyItem", { id = "TOOL_CART_1" }), "msg.locked")
			T.fails(bot:try("BuyItem", { id = "D_MASTER_BADGE" }), "msg.locked")
		end)
	end)
end
