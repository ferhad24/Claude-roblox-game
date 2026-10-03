--!nocheck
-- M1 qəbul şərti (məntiq səviyyəsində): Z01 ilk 15–20 dəqiqə başdan sona tamamlanır.
-- Bu, Studio-da oynama testi DEYİL: server məntiqi bot tərəfindən idarə olunur.
local H = require("../harness")
local Bot = require("../sim/Bot")

return function(T)
	T.describe("Z01 — ilk 20 dəqiqə (məntiq simulyasiyası)", function()
		local bot = Bot.new(H)
		local p = bot:profile()

		T.it("başlanğıc: pulsuz əlcək, damcı qabı, 12 tutumlu çanta, güc 1", function()
			T.expect(p.tools["TOOL_GLOVES_1"]).toBe(true)
			T.expect(p.tools["TOOL_CUP_1"]).toBe(true)
			T.expect(p.bagCapacity).toBe(12)
			T.expect(bot:power()).toBe(1)
			T.expect(bot:step()).toBe("Q1_LEAVES")
		end)

		T.it("ilk 3 yarpaq: hər biri 4 lif, 5 damğa, 8 XP → dəqiq 15 damğa", function()
			for i = 1, 3 do
				bot:work(("Z01_Leaf_%02d"):format(i))
			end
			T.expect(p.coins).toBe(15)
			T.expect(p.workXP).toBe(24)
			T.expect(p.bag["MAT_FIBER"]).toBe(12)
			T.expect(bot:step()).toBe("Q1_FILL")
			bot:note("3 yarpaq təmizləndi, damğa=%d", p.coins)
		end)

		T.it("qabı doldurub ilk toxumu sulamaq 100 XP verir və güc 3 olur", function()
			bot:fill("Z01_DewBowl")
			T.expect(p.cup).toBe(6)
			T.expect(bot:step()).toBe("Q1_SEED")
			bot:pour("Z01_Plot_01")
			T.expect(p.workXP).toBe(124)
			T.expect(bot:power()).toBe(3)
			T.expect(bot:step()).toBe("Q1_SHEARS")
			bot:note("toxum suvarıldı, güc=%d", bot:power())
		end)

		T.it("mis qayçı 15 damğaya alınır, eyni aləti iki dəfə almaq olmur", function()
			bot:buy("TOOL_SHEARS_1")
			T.expect(p.coins).toBe(0)
			local again = bot:try("BuyItem", { id = "TOOL_SHEARS_1" })
			T.fails(again, "msg.alreadyOwned")
			T.expect(bot:step()).toBe("Q1_THREADS")
		end)

		T.it("çanta dolu: material itmir, damğa yenə verilir, yeni toplama dayanır", function()
			T.expect(p.bag["MAT_FIBER"]).toBe(12)
			bot:goTo("Z01_Thread_01")
			T.ok(bot:act("StartWork", { target = "Z01_Thread_01" }))
			for _ = 1, 100 do
				bot.game:tick(0.25)
				if not bot.game.work then
					break
				end
			end
			T.expect(p.restoredObjectIds["Z01_Thread_01"]).toBe(true)
			T.expect(p.coins).toBe(8)
			T.expect(p.pending["MAT_FIBER"]).toBe(3)
			T.expect(p.pending["MAT_THREAD"]).toBe(1)
			bot:goTo("Z01_Thread_02")
			T.fails(bot:try("StartWork", { target = "Z01_Thread_02" }), "msg.bagFull")
			bot:deposit()
			T.expect(p.storage["MAT_FIBER"]).toBe(12)
			T.expect(p.bag["MAT_FIBER"]).toBe(3)
			T.expect(p.bag["MAT_THREAD"]).toBe(1)
			T.expect(next(p.pending)).toBe(nil)
		end)

		T.it("saplar kəsilir, emalatxana 2 pulsuz kanal və Z01 reseptlərini verir", function()
			bot:work("Z01_Thread_02")
			bot:work("Z01_Thread_03")
			T.expect(bot:step()).toBe("Q1_WORKSHOP")
			bot:interact("Z01_Workbench")
			T.expect(p.buildInv["B_CHANNEL"]).toBe(2)
			T.expect(p.groups["G_Z01"]).toBe(true)
			T.expect(bot:step()).toBe("Q1_ROPE")
			bot:craft("C_ROPE", 1)
			T.expect(bot:step()).toBe("Q1_SAW")
			bot:note("emalatxana açıldı, ip hazır")
		end)

		T.it("mişar üçün damğa ətraf işlərdən yığılır", function()
			for i = 4, 7 do
				bot:work(("Z01_Leaf_%02d"):format(i))
			end
			bot:work("Z01_Thread_04")
			bot:work("Z01_Thread_05")
			T.expect(p.coins).toBeAtLeast(60)
			bot:buy("TOOL_SAW_1")
			T.expect(bot:step()).toBe("Q1_PLANKS")
			bot:note("mişar alındı, damğa=%d güc=%d", p.coins, bot:power())
		end)

		T.it("güc 3-də budaq işi mümkündür; 4 lövhə və çarx hazırlanır", function()
			bot:work("Z01_Branch_01")
			bot:work("Z01_Branch_02")
			bot:work("Z01_Branch_03")
			bot:craft("C_PLANK", 4)
			T.expect(bot:step()).toBe("Q1_WHEEL")
			T.expect(bot:power()).toBeAtLeast(4)
			bot:work("Z01_Stone_01")
			bot:craft("R_WHEEL", 1)
			T.expect(p.buildInv["B_WHEEL"]).toBe(1)
			T.expect(bot:step()).toBe("Q1_PLACE_WHEEL")
		end)

		T.it("çarx şeh qabının çıxışına, iki kanal birinci yatağa qoşulur", function()
			-- A_Z01_LINE: origin (18, 82). Çarx mərkəzi (20, 86) → lokal (2, 4)
			bot:place("B_WHEEL", "A_Z01_LINE", 2, 4, 0)
			T.expect(bot:step()).toBe("Q1_LINE")
			bot:place("B_CHANNEL", "A_Z01_LINE", 6, 4, 0)
			T.expect(bot:step()).toBe("Q1_LINE")
			bot:place("B_CHANNEL", "A_Z01_LINE", 10, 4, 0)
			T.expect(bot:step()).toBe("Q1_BEDS")
			-- Su axır: 3 doza → yataq dirçəlir
			bot:wait(5)
			T.expect(p.restoredObjectIds["Z01_Bed_01"]).toBe(true)
			T.expect(p.stats.lineDelivered["Z01_Bed_01"]).toBeAtLeast(3)
			T.expect(p.stats.wheelZones["Z01"]).toBe(true)
			bot:note("ilk su xətti işlədi")
		end)

		T.it("qalan iki yataq qabla sulanır və fəsil 1 bitir", function()
			bot:waterUntilRestored("Z01_Bed_02", "Z01_DewBowl")
			bot:waterUntilRestored("Z01_Bed_03", "Z01_DewBowl")
			T.expect(p.quest.chapter).toBe(2)
			T.expect(p.campaign["BADGE_TREE_1"]).toBe(1)
			T.expect(p.zones["Z02"]).toBe(true)
			T.expect(p.achievements["ACH_FIRST_LINE"]).toBe(true)
			bot:note("fəsil 1 bitdi: damğa=%d güc=%d", p.coins, bot:power())
		end)

		T.it("fəsil 1 təxmini müddəti 25 dəqiqədən azdır (simulyasiya təxmini)", function()
			local minutes = bot:totalSeconds() / 60
			print(
				("      Təxmini müddət: %.1f dəq (aktiv %.1f, yeriş %.1f, UI %.1f)"):format(
					minutes,
					bot:activeSeconds() / 60,
					bot.walkSeconds / 60,
					bot.uiSeconds / 60
				)
			)
			for _, line in bot.log do
				print("      " .. line)
			end
			T.expect(minutes).toBeAtMost(25)
		end)
	end)
end
