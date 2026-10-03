--!nocheck
-- M3: bütün kampaniya başdan sona (məntiq simulyasiyası). Softlock və balans ölçümü.
local H = require("../harness")
local Bot = require("../sim/Bot")
local Campaign = require("../sim/Campaign")

return function(T)
	T.describe("Tam kampaniya (bot simulyasiyası)", function()
		local metrics
		T.it("bot 6 fəsli və finalı yalnız oyun qaydaları ilə bitirir", function()
			local ok, result = pcall(Campaign.run, H, Bot)
			if not ok then
				error(result, 0)
			end
			metrics = result
			T.expect(metrics.final).toBe(true)
		end)
		T.it("bütün əlavə işlərlə güc 15 təkrar işsiz əldə olunur (bölmə 15 qaydası)", function()
			assert(metrics, "kampaniya işləmədi")
			T.expect(metrics.xpGapTo15 or 0).toBe(0)
		end)
		T.it("finaldan sonra: sərbəst rejim, mükafatlar, yenidən baxış, rahat keçid", function()
			assert(metrics, "kampaniya işləmədi")
			local p, g = metrics.profile, metrics.game
			T.expect(p.finalCompleted).toBe(true)
			T.expect(p.groups["G_FINAL"]).toBe(true)
			T.expect(p.buildInv["D_MASTER_BADGE"]).toBe(1)
			T.expect((p.seeds["SEED_STAR"] or 0) >= 1).toBeTruthy()
			T.expect(p.achievements["ACH_TREE_AWAKE"]).toBe(true)
			T.expect(p.achievements["ACH_FIVE_BADGES"]).toBe(true)
			-- Finala yenidən baxış (ağacla əlaqə) yeni mükafat yaratmır
			local coins = p.coins
			g:setPosition(6, 0, 10)
			local r = g:handle("Interact", { target = "Z06_Tree" }, 99001)
			T.ok(r)
			local sawReplay = false
			for _, e in g:drainEvents() do
				if e.type == "final" and e.replay then
					sawReplay = true
				end
			end
			T.expect(sawReplay).toBe(true)
			T.expect(p.coins).toBe(coins)
			T.ok(g:handle("WatchedFinal", {}, 99002))
			-- Rahat keçid yalnız açıq sahələrə
			T.ok(g:handle("FastTravel", { zone = "Z03" }, 99003))
			T.fails(g:handle("FastTravel", { zone = "Z99" }, 99004), "msg.locked")
			-- Sərbəst rejim: final dekor reseptləri hazırlana bilir
			p.bag["MAT_PLANK"] = 3
			p.bag["MAT_FIBER"] = 2
			g:setPosition(36, 0, 62)
			T.ok(g:handle("Craft", { recipe = "R_BENCH", count = 1 }, 99005))
			T.expect(p.buildInv["B_BENCH"]).toBe(1)
		end)

		T.it("hər fəsildən sonra save/load (JSON) ilə də kampaniya bitir (save uyğunluğu)", function()
			local ok, result = pcall(Campaign.run, H, Bot, { saveLoadEachChapter = true })
			if not ok then
				error(result, 0)
			end
			T.expect(result.final).toBe(true)
			T.expect(result.saveLoads).toBe(6)
		end)

		T.it("ölçülən göstəricilər (təxmini, simulyasiya)", function()
			assert(metrics, "kampaniya işləmədi")
			print(
				("      Ümumi təxmini vaxt: %.1f dəq (aktiv %.1f, yeriş %.1f, gözləmə %.1f)"):format(
					metrics.totalSeconds / 60,
					metrics.activeSeconds / 60,
					metrics.walkSeconds / 60,
					metrics.waitSeconds / 60
				)
			)
			print(
				("      Yenilənən yuva işi: %d, sifariş: %d, son güc: %d, son damğa: %d"):format(
					metrics.repeatWorks,
					metrics.orders,
					metrics.power,
					metrics.coins
				)
			)
			print(
				("      Fəsil 6 əvvəli XP: %d; güc 15 üçün təkrar işlə qazanılan XP: %d"):format(
					metrics.xpBefore15 or 0,
					metrics.xpGapTo15 or 0
				)
			)
			for n = 1, 6 do
				print(("      Fəsil %d bitdi: %.1f dəq"):format(n, (metrics.chapterTimes[n] or 0) / 60))
			end
			for _, line in metrics.log do
				print("      " .. line)
			end
		end)
	end)
end
