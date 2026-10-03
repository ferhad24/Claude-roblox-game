--!nocheck
-- Su qrafı: dövrə su yaratmır, əlaqəsiz çıxış su xərcləmir, nasos enerji tələb edir, çən növbə ilə bölür.
local H = require("../harness")

return function(T)
	local Game = H.require("src/shared/Core/Game")
	local Profile = H.require("src/shared/Core/Profile")
	local Water = H.require("src/shared/Core/Water")

	local function fresh()
		local p = Profile.new(0)
		p.zones.Z02 = true
		p.zones.Z05 = true
		p.zones.Z06 = true
		local g = Game.new(p)
		return g, p
	end

	local function put(p, t, area, x, z, r, v, w)
		local uid = tostring(p.nextBuildId)
		p.nextBuildId += 1
		p.builds[uid] = { t = t, area = area, x = x, z = z, r = r or 0, v = v, w = w }
		return uid
	end

	local function totalWater(p)
		local n = 0
		for _, v in p.waterSources do
			n += v
		end
		for _, b in p.builds do
			n += b.w or 0
		end
		for _, m in p.moisture do
			n += m / 25
		end
		return n
	end

	T.describe("Su qrafı", function()
		T.it("əlaqəsi olmayan çıxış su xərcləmir", function()
			local g, p = fresh()
			local before = p.waterSources["Z01_DewBowl"]
			-- Qabın çıxışına bağlanmayan tək kanal
			put(p, "B_CHANNEL", "A_Z01_LINE", 8, 2, 0)
			g:invalidateGraph()
			for _ = 1, 5 do
				g:waterTick()
			end
			T.expect(p.waterSources["Z01_DewBowl"]).toBe(before)
		end)

		T.it("kanal saniyədə ən çox 1 doza ötürür", function()
			local g, p = fresh()
			put(p, "B_CHANNEL", "A_Z01_LINE", 2, 4, 0) -- in (18,86) qabın çıxışı
			put(p, "B_CHANNEL", "A_Z01_LINE", 6, 4, 0)
			put(p, "B_CHANNEL", "A_Z01_LINE", 10, 4, 0) -- out (30,86) = yatağın girişi
			g:invalidateGraph()
			g:waterTick()
			T.expect(p.moisture["Z01_Bed_01"]).toBe(25)
			g:waterTick()
			T.expect(p.moisture["Z01_Bed_01"]).toBe(50)
		end)

		T.it("özünə dönən dövrə su yaratmır və sonsuz dövr etmir", function()
			local g, p = fresh()
			-- A_Z06 (origin −46, −36). Çən (−26, 24); şərq çıxışından başlayan halqa çənin öz girişinə qayıdır.
			local tank = put(p, "B_TANK", "A_Z06", 20, 60, 0, nil, 5)
			put(p, "B_CHANNEL", "A_Z06", 24, 60, 0, "right")
			put(p, "B_CHANNEL", "A_Z06", 24, 64, 1)
			put(p, "B_CHANNEL", "A_Z06", 24, 68, 1, "right")
			put(p, "B_CHANNEL", "A_Z06", 20, 68, 2)
			put(p, "B_CHANNEL", "A_Z06", 16, 68, 2)
			put(p, "B_CHANNEL", "A_Z06", 12, 68, 2, "right")
			put(p, "B_CHANNEL", "A_Z06", 12, 64, 3)
			put(p, "B_CHANNEL", "A_Z06", 12, 60, 3, "right")
			put(p, "B_CHANNEL", "A_Z06", 16, 60, 0)
			g:invalidateGraph()
			-- Halqa həqiqətən qapalıdır: şərq çıxışından iz çənin özünə çatır
			local t = Water.trace(p, g:getGraph(), "-24,0,24")
			T.expect(t ~= nil).toBeTruthy("halqa qapanmadı")
			T.expect(t.target.id).toBe(tank)
			T.expect(#t.path).toBe(10)
			for _ = 1, 20 do
				g:waterTick()
			end
			T.expect(p.builds[tank].w).toBe(5)
		end)

		T.it("nasos çarxsız işləmir; çarx + nasos rəfdəki yatağa su qaldırır", function()
			local g, p = fresh()
			-- Z05: nov (−64, 0), çıxışı (−66, 0). A_Z05_GH origin (−118, −18): lokal = dünya + (118, 18).
			local function at(x, z)
				return x + 118, z + 18
			end
			local wx, wz = at(-68, 0)
			local px, pz = at(-72, 0)
			-- Əvvəl yalnız nasos (çarx yoxdur)
			local pumpOnly = put(p, "B_PUMP", "A_Z05_GH", wx, wz, 2)
			g:invalidateGraph()
			T.expect(Water.trace(p, g:getGraph(), "-66,24,0")).toBe(nil)
			p.builds[pumpOnly] = nil
			-- Tam xətt: çarx → nasos → 2 kanal → sola dönüş → 9 kanal (+Z) → sola dönüş → yatağın girişi (−82, 40)
			put(p, "B_WHEEL", "A_Z05_GH", wx, wz, 2)
			put(p, "B_PUMP", "A_Z05_GH", px, pz, 2)
			local x, z = at(-76, 0)
			put(p, "B_CHANNEL", "A_Z05_GH", x, z, 2)
			x, z = at(-80, 0)
			put(p, "B_CHANNEL", "A_Z05_GH", x, z, 2)
			x, z = at(-84, 0)
			put(p, "B_CHANNEL", "A_Z05_GH", x, z, 2, "left")
			for cz = 4, 36, 4 do
				x, z = at(-84, cz)
				put(p, "B_CHANNEL", "A_Z05_GH", x, z, 1)
			end
			x, z = at(-84, 40)
			put(p, "B_CHANNEL", "A_Z05_GH", x, z, 1, "left")
			g:invalidateGraph()
			T.expect(Water.lineConnected(p, g:getGraph(), "Z05_BloomBed_02", { "B_PUMP" })).toBe(true)
			for _ = 1, 4 do
				g:waterTick()
			end
			T.expect(p.restoredObjectIds["Z05_BloomBed_02"]).toBe(true)
			T.expect(p.campaign["MAT_BLOOM"]).toBe(1)
			-- Çarxı götürəndə nasos dayanır, heç nə xarab olmur
			local g2, p2 = fresh()
			put(p2, "B_PUMP", "A_Z05_GH", px, pz, 2)
			g2:invalidateGraph()
			T.expect(Water.lineConnected(p2, g2:getGraph(), "Z05_BloomBed_02", nil)).toBe(false)
		end)

		T.it("çəndən iki xətt çıxanda su növbə ilə bölünür", function()
			local g, p = fresh()
			-- A_Z06 origin (−46, −36). T1 mərkəzi dünya (−26, −16): çıxışlar (−24,−16), (−26,−18), (−26,−14)
			local t1 = put(p, "B_TANK", "A_Z06", 20, 20, 0, nil, 0)
			-- T2 girişi (−24,−16): mərkəz (−22,−16), r=0
			local t2 = put(p, "B_TANK", "A_Z06", 24, 20, 0, nil, 0)
			-- T3 girişi (−26,−14): r=1 → giriş ofseti (0,−2), mərkəz (−26,−12)
			local t3 = put(p, "B_TANK", "A_Z06", 20, 24, 1, nil, 0)
			g:invalidateGraph()
			for _ = 1, 4 do
				p.builds[t1].w = 1
				g:waterTick()
			end
			T.expect(p.builds[t2].w).toBe(2)
			T.expect(p.builds[t3].w).toBe(2)
		end)

		T.it("struktur yoxlaması: xətt varsa, yataq dolu olsa belə 'qoşulub' sayılır", function()
			local g, p = fresh()
			put(p, "B_WHEEL", "A_Z01_LINE", 2, 4, 0)
			put(p, "B_CHANNEL", "A_Z01_LINE", 6, 4, 0)
			put(p, "B_CHANNEL", "A_Z01_LINE", 10, 4, 0)
			p.restoredObjectIds["Z01_Bed_01"] = true
			p.moisture["Z01_Bed_01"] = 100
			g:invalidateGraph()
			T.expect(Water.lineConnected(p, g:getGraph(), "Z01_Bed_01", nil)).toBe(true)
			T.expect(Water.lineConnected(p, g:getGraph(), "Z01_Bed_01", { "B_WHEEL" })).toBe(true)
			T.expect(Water.lineConnected(p, g:getGraph(), "Z01_Bed_01", { "B_PUMP" })).toBe(false)
		end)
	end)
end
