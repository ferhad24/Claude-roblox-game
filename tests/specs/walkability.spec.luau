--!nocheck
-- Gedişə yararlılıq testi: xəritə 1 stud-luq şəbəkəyə çevrilir (divarlar, bariyerlər, bağlı qapılar,
-- bərk obyektlər, çay, iki səviyyə: yer Y=0 və masa Y=24; lift və rampa bağlantıları). Flood fill ilə:
--  1) başlanğıcda bağlı sahələrə sızma yoxdur;
--  2) hər fəslin tapşırıq obyektlərinə (və bütün interaktiv obyektlərə) yaxınlaşmaq mümkündür.
-- Bu, Roblox fizikasının DƏQİQ modeli deyil (pillə, tullanma, sürüşmə yoxdur); layout xətalarını tutmaq üçündür.
local H = require("../harness")

return function(T)
	local Layout = H.require("src/shared/Layout")
	local QuestDefs = H.require("src/shared/Defs/QuestDefs")
	local WorkDefs = H.require("src/shared/Defs/WorkDefs")
	local ZoneDefs = H.require("src/shared/Defs/ZoneDefs")

	local X0, Z0, X1, Z1 = -130, -110, 130, 110
	local W, D = X1 - X0, Z1 - Z0
	local LEVELS = { 0, 24 }
	local RADIUS = 1 -- personajın yarım eni (təxmini)

	local function idx(x, z)
		return (z - Z0) * W + (x - X0)
	end

	-- Fırlanmış düzbucaqlının içindədirmi (Roblox yaw: lokal X → (cos, −sin))
	local function inRect(px, pz, cx, cz, sx, sz, rotDeg, pad)
		local a = math.rad(rotDeg or 0)
		local dx, dz = px - cx, pz - cz
		local lx = dx * math.cos(a) - dz * math.sin(a)
		local lz = dx * math.sin(a) + dz * math.cos(a)
		return math.abs(lx) <= sx / 2 + pad and math.abs(lz) <= sz / 2 + pad
	end

	local function rasterize(level, state)
		local blocked = {}
		local ground = {}
		local river = {}
		local function fillRect(target, cx, cz, sx, sz, rot, pad)
			local r = math.sqrt(sx * sx + sz * sz) / 2 + pad + 1
			for x = math.floor(cx - r), math.ceil(cx + r) do
				for z = math.floor(cz - r), math.ceil(cz + r) do
					if x >= X0 and x < X1 and z >= Z0 and z < Z1 then
						if inRect(x + 0.5, z + 0.5, cx, cz, sx, sz, rot, pad) then
							target[idx(x, z)] = true
						end
					end
				end
			end
		end
		local function spans(y0, y1)
			return y1 > level + 0.5 and y0 < level + 5
		end
		for _, zl in Layout.zones do
			for _, g in zl.ground do
				local top = g.pos[2] + g.size[2] / 2
				if math.abs(top - level) < 0.5 then
					fillRect(ground, g.pos[1], g.pos[3], g.size[1], g.size[3], 0, 0)
				end
			end
			for _, w in zl.walls do
				if spans(w.pos[2] - w.size[2] / 2, w.pos[2] + w.size[2] / 2) then
					fillRect(blocked, w.pos[1], w.pos[3], w.size[1], w.size[3], w.rot, RADIUS)
				end
			end
			for _, wt in zl.water do
				fillRect(river, wt.pos[1], wt.pos[3], wt.size[1], wt.size[3], 0, RADIUS)
			end
			for _, pr in zl.props do
				local collide = pr.collide ~= false and pr.name ~= "Ramp"
				if collide and spans(pr.pos[2] - pr.size[2] / 2, pr.pos[2] + pr.size[2] / 2) then
					fillRect(blocked, pr.pos[1], pr.pos[3], pr.size[1], pr.size[3], pr.rot, RADIUS)
				end
			end
		end
		for _, obj in Layout.objects do
			local y = obj.pos[2]
			if math.abs(y - level) < 1 then
				local extra = obj.extra or {}
				local restored = state.restored[obj.id]
				if extra.barrier and not restored then
					local b = extra.barrier
					fillRect(blocked, obj.pos[1], obj.pos[3], b[1], b[3], obj.rot, RADIUS)
				end
				if obj.kind == "gate" and not state.zones[extra.unlockZone] then
					local sz = extra.size
					fillRect(blocked, obj.pos[1], obj.pos[3], sz[1], sz[3], obj.rot, RADIUS)
				end
				-- Bərk obyektlər (görünüşdə CanCollide=true olanlar)
				local solid = false
				if
					obj.kind == "source"
					or obj.kind == "npc"
					or obj.kind == "storage"
					or obj.kind == "workbench"
					or obj.kind == "board"
				then
					solid = true
				elseif obj.kind == "work" and not restored then
					local def = WorkDefs.workById[obj.def]
					solid = def.workType == "stone_heavy" or def.workType == "root"
				end
				if solid then
					local size = Layout.sizeOf(obj)
					fillRect(blocked, obj.pos[1], obj.pos[3], size[1], size[3], obj.rot, RADIUS)
				end
			end
		end
		-- Körpü: yalnız çay xanalarını açır (digər maneələr qalır); görünməz məhəccərlər (Placeholders.bridge)
		-- körpünün iki kənarında bərk divar kimidir
		if level == 0 and state.bridge then
			local s = Layout.byId["Z02_BridgeSocket"]
			local span = s.extra.span
			local width = s.extra.width
			local z0, z1 = s.pos[3] + span[3], s.pos[3] + span[6]
			local deck = {}
			fillRect(deck, s.pos[1], (z0 + z1) / 2, width, z1 - z0, 0, 0)
			for i in deck do
				river[i] = nil
				ground[i] = true
			end
			for _, side in { -1, 1 } do
				fillRect(blocked, s.pos[1] + side * width / 2, (z0 + z1) / 2, 0.3, z1 - z0, 0, RADIUS)
			end
		end
		for i in river do
			blocked[i] = true
		end
		return blocked, ground
	end

	local function flood(state, start)
		local grids = {}
		for _, level in LEVELS do
			local b, g = rasterize(level, state)
			grids[level] = { blocked = b, ground = g, seen = {} }
		end
		local queue = {}
		local function push(level, x, z)
			if x < X0 or x >= X1 or z < Z0 or z >= Z1 then
				return
			end
			local grid = grids[level]
			local i = idx(x, z)
			if grid.seen[i] or grid.blocked[i] or not grid.ground[i] then
				return
			end
			grid.seen[i] = true
			table.insert(queue, { level, x, z })
		end
		push(start[1], start[2], start[3])
		-- Səviyyələr arası bağlantılar
		local links = {}
		if state.lift then
			local s = Layout.byId["Z04_LiftSocket"]
			local l = s.extra.landing
			table.insert(links, { { 0, s.pos[1], s.pos[3] }, { 24, l[1], l[3] } })
		end
		if state.zones.Z05 then
			table.insert(links, { { 24, -60, 57 }, { 0, -60, 102 } })
		end
		local head = 1
		while head <= #queue do
			local cur = queue[head]
			head += 1
			local level, x, z = cur[1], cur[2], cur[3]
			push(level, x + 1, z)
			push(level, x - 1, z)
			push(level, x, z + 1)
			push(level, x, z - 1)
			for _, link in links do
				for k = 1, 2 do
					local a, b = link[k], link[3 - k]
					if a[1] == level and math.abs(a[2] - x) <= 3 and math.abs(a[3] - z) <= 3 then
						push(b[1], math.floor(b[2]), math.floor(b[3]))
					end
				end
			end
		end
		return grids
	end

	-- Obyektin footprint-inə `range` stud yaxınlıqda keçilə bilən hüceyrə varmı
	local function reachable(grids, obj, range)
		local level = if obj.pos[2] > 12 then 24 else 0
		local grid = grids[level]
		local size = Layout.sizeOf(obj)
		local hx, hz = size[1] / 2 + range, size[3] / 2 + range
		for x = math.floor(obj.pos[1] - hx), math.ceil(obj.pos[1] + hx) do
			for z = math.floor(obj.pos[3] - hz), math.ceil(obj.pos[3] + hz) do
				if x >= X0 and x < X1 and z >= Z0 and z < Z1 and grid.seen[idx(x, z)] then
					return true
				end
			end
		end
		return false
	end

	local spawn = Layout.zoneLayout.Z01.safeSpawn
	local START = { 0, math.floor(spawn[1]), math.floor(spawn[3]) }

	local function zoneInterior(zone)
		local z = ZoneDefs.byId[zone]
		return z.origin[1] + 4, z.origin[3] + 4, z.origin[1] + z.size[1] - 4, z.origin[3] + z.size[2] - 4
	end

	T.describe("Gedişə yararlılıq (layout)", function()
		T.it("başlanğıcda bağlı sahələrə (Z02–Z06) sızma yoxdur", function()
			local state = { restored = {}, zones = { Z01 = true } }
			local grids = flood(state, START)
			local leaks = {}
			for _, zone in { "Z02", "Z03", "Z04", "Z05", "Z06" } do
				local level = if zone == "Z05" then 24 else 0
				local x0, z0, x1, z1 = zoneInterior(zone)
				local count = 0
				for x = math.floor(x0), math.floor(x1) do
					for z = math.floor(z0), math.floor(z1) do
						if grids[level].seen[idx(x, z)] then
							count += 1
						end
					end
				end
				if count > 0 then
					table.insert(leaks, zone .. "=" .. count)
				end
			end
			T.expect(#leaks).toBe(0, table.concat(leaks, ", "))
		end)

		T.it(
			"fəsil 1 obyektlərinə başlanğıc vəziyyətdə yaxınlaşmaq olur (saplar kəsilənə qədər emalatxana bağlı)",
			function()
				local state = { restored = {}, zones = { Z01 = true } }
				local grids = flood(state, START)
				for _, id in
					{
						"Z01_Leaf_01",
						"Z01_Leaf_02",
						"Z01_Leaf_03",
						"Z01_DewBowl",
						"Z01_Plot_01",
						"Z01_Shop",
						"Z01_Thread_01",
						"Z01_Storage",
					}
				do
					T.expect(reachable(grids, Layout.byId[id], 2)).toBe(true, id)
				end
				-- İş masası saplar kəsilməmiş əlçatan olmamalıdır (yalnız qısa yol daşı da bağlıdır)
				T.expect(reachable(grids, Layout.byId["Z01_Workbench"], 2)).toBe(false, "emalatxana tez açılır")
				state.restored["Z01_Thread_01"] = true
				state.restored["Z01_Thread_02"] = true
				state.restored["Z01_Thread_03"] = true
				grids = flood(state, START)
				T.expect(reachable(grids, Layout.byId["Z01_Workbench"], 2)).toBe(true, "emalatxanaya yol açılmadı")
			end
		)

		T.it("hər fəslin başlanğıcında onun tapşırıq obyektlərinə çatmaq olur", function()
			local Catalog = H.require("src/shared/Core/Catalog")
			local Conditions = H.require("src/shared/Core/Conditions")
			local problems = {}
			for _, ch in QuestDefs.chapters do
				-- Fəslin əvvəlki addımları bitib; sahələr şərtlərə görə açıqdır; əvvəlki fəsillərin obyektləri bərpa olunub
				local done = {}
				for _, prev in QuestDefs.chapters do
					if prev.chapter < ch.chapter then
						for _, s in prev.steps do
							done[s.id] = true
						end
					end
				end
				local fakeProfile = { quest = { done = done }, zones = {}, workXP = 7600, finalCompleted = false }
				for _, z in ZoneDefs.list do
					if Conditions.check(fakeProfile, z.unlock) then
						fakeProfile.zones[z.id] = true
					end
				end
				local restored = {}
				for _, obj in Layout.objects do
					if obj.kind == "work" or obj.kind == "cargo" or obj.kind == "dropoff" then
						local z = ZoneDefs.byId[obj.zone]
						if z.chapter < ch.chapter then
							restored[obj.id] = true
						end
					end
				end
				local state = {
					restored = restored,
					zones = fakeProfile.zones,
					bridge = done["Q2_BRIDGE"] == true,
					lift = done["Q4_LIFT"] == true,
				}
				-- Fəsil daxilində addım-addım: hər addımın obyektləri əvvəlkilər bitəndə əlçatan olmalıdır
				for _, step in ch.steps do
					local grids = flood(state, START)
					local ids = {}
					local o = step.objective
					if o.type == "restore" then
						ids = o.ids
					elseif o.type == "interact" or o.type == "water" then
						ids = { o.id }
					elseif o.type == "socket" then
						ids = { o.id }
					elseif o.type == "cargo" then
						ids = { o.target }
					end
					if step.marker then
						table.insert(ids, step.marker)
					end
					-- Ardıcıl maneələr (məs. dəhlizdəki saplar): əlçatan olanlar bərpa edilir, yenidən yoxlanılır
					local pending = {}
					for _, id in ids do
						pending[id] = true
					end
					local progress = true
					while progress do
						progress = false
						for id in pending do
							local obj = Layout.byId[id]
							-- Yuvalar (körpü, lift) çayın/şaxtanın içindədir: 10 stud-luq əlaqə məsafəsindən istifadə olunur
							local range = if obj and obj.kind == "socket" then 8 else 3
							if obj and reachable(grids, obj, range) then
								pending[id] = nil
								if o.type == "restore" then
									state.restored[id] = true
									grids = flood(state, START)
								end
								progress = true
							end
						end
					end
					for id in pending do
						table.insert(problems, ("fəsil %d, %s: %s əlçatan deyil"):format(ch.chapter, step.id, id))
					end
					-- Addım bitdi: onun obyektləri bərpa olunur
					if o.type == "restore" then
						for _, id in o.ids do
							state.restored[id] = true
						end
					elseif o.type == "cargo" then
						state.restored[o.target] = true
						for i = 1, 3 do
							state.restored[("Z03_Shard_%02d"):format(i)] = true
						end
					elseif o.type == "socket" and o.id == "Z02_BridgeSocket" then
						state.bridge = true
						state.zones.Z03 = true
					elseif o.type == "socket" and o.id == "Z04_LiftSocket" then
						state.lift = true
					end
				end
				local _ = Catalog
			end
			for _, pr in problems do
				print("      " .. pr)
			end
			T.expect(#problems).toBe(0)
		end)

		T.it("hər şey açıq olanda bütün interaktiv obyektlərə çatmaq olur", function()
			local zones = {}
			for _, z in ZoneDefs.list do
				zones[z.id] = true
			end
			local restored = {}
			for _, obj in Layout.objects do
				restored[obj.id] = true
			end
			local grids = flood({ restored = restored, zones = zones, bridge = true, lift = true }, START)
			local missing = {}
			for _, obj in Layout.objects do
				if
					obj.kind ~= "gate"
					and obj.kind ~= "home"
					and obj.kind ~= "lamp"
					and not reachable(grids, obj, 3)
				then
					table.insert(missing, obj.id)
				end
			end
			for _, m in missing do
				print("      əlçatmaz: " .. m)
			end
			T.expect(#missing).toBe(0)
			-- Sahələrin təhlükəsiz nöqtələri (rahat keçid, suya düşəndə qaytarma) keçilə bilən hüceyrədədir
			for _, zl in Layout.zones do
				local sp = zl.safeSpawn
				local level = if sp[2] > 12 then 24 else 0
				local ok = false
				for dx = -1, 1 do
					for dz = -1, 1 do
						if grids[level].seen[idx(math.floor(sp[1]) + dx, math.floor(sp[3]) + dz)] then
							ok = true
						end
					end
				end
				T.expect(ok).toBe(true, "təhlükəsiz nöqtə əlçatmazdır: " .. zl.zone)
			end
		end)
	end)
end
