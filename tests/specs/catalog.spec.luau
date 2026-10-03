--!nocheck
-- Kataloq yoxlaması: ID unikallığı, istinadlar, ardıcıllıq, lokal mətnlər.
local H = require("../harness")

return function(T)
	local Catalog = H.require("src/shared/Core/Catalog")
	local Locales = H.require("src/shared/Locales")

	T.describe("Kataloq", function()
		T.it("startup yoxlaması xətasız keçir", function()
			local errs = Catalog.validate(Locales.maps)
			for _, e in errs do
				print("      " .. e)
			end
			T.expect(#errs).toBe(0)
		end)

		T.it("yoxlama həqiqətən xətaları tutur (mutasiya testi)", function()
			local R = Catalog.Recipes
			local W = Catalog.Work
			local Q = Catalog.Quests
			-- 1) Təkrarlanan ID
			table.insert(
				R.list,
				{
					id = "C_ROPE",
					nameKey = "recipe.C_ROPE",
					group = "G_Z01",
					inputs = {},
					output = { id = "MAT_ROPE", n = 1 },
				}
			)
			local errs = Catalog.validate(Locales.maps)
			table.remove(R.list)
			T.expect(#errs > 0).toBeTruthy("təkrarlanan ID tutulmadı")
			-- 2) Naməlum material
			local leaf = W.workById["W_LEAF"]
			local saved = leaf.mats
			leaf.mats = { { id = "MAT_UNKNOWN", n = 1 } }
			errs = Catalog.validate(Locales.maps)
			leaf.mats = saved
			T.expect(#errs > 0).toBeTruthy("naməlum material tutulmadı")
			-- 3) Ardıcıllıq: addım öz açılmasından əvvəl alət tələb edir
			local step = Q.stepById["Q1_SHEARS"]
			local savedObj = step.objective
			step.objective = { type = "ownTool", tool = "TOOL_SHEARS_2" }
			errs = Catalog.validate(Locales.maps)
			step.objective = savedObj
			T.expect(#errs > 0).toBeTruthy("ardıcıllıq pozuntusu tutulmadı")
			-- 4) Lokal mətn çatışmır
			local en = Locales.maps.en
			local savedText = en["item.MAT_FIBER"]
			en["item.MAT_FIBER"] = nil
			errs = Catalog.validate(Locales.maps)
			en["item.MAT_FIBER"] = savedText
			T.expect(#errs > 0).toBeTruthy("çatışmayan mətn tutulmadı")
			-- Bərpadan sonra yenə təmiz
			T.expect(#Catalog.validate(Locales.maps)).toBe(0)
		end)

		T.it("beş mahiyyət mənbəyinin ID-ləri sənəddəkilərdir", function()
			local expected =
				{ "Z02_BloomBed_01", "Z03_BloomBed_01", "Z04_BloomBed_01", "Z05_BloomBed_01", "Z05_BloomBed_02" }
			for i, id in expected do
				T.expect(Catalog.Quests.bloomSources[i]).toBe(id)
			end
		end)

		T.it("fəsil mükafatları cəmi 2 450 damğadır", function()
			local sum = 0
			for _, ch in Catalog.Quests.chapters do
				sum += ch.reward.coins
			end
			T.expect(sum).toBe(2450)
		end)

		T.it("məcburi alış büdcəsi konfiqurasiyadan 3 650 damğa çıxır", function()
			local sum = 0
			for _, t in Catalog.Tools.list do
				if t.mandatory then
					sum += t.price
				end
			end
			for _, b in Catalog.Shop.bagUpgrades do
				if b.mandatory then
					sum += b.price
				end
			end
			for _, g in Catalog.Recipes.groups do
				if not g.free then
					sum += g.keyPrice
				end
			end
			T.expect(sum).toBe(3650)
		end)
	end)
end
