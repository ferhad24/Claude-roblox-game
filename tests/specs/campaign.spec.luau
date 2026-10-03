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
