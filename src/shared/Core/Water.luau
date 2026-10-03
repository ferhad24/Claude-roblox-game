--!strict
-- Su sistemi (bölmə 12): fiziki maye simulyasiyası yoxdur, yönlü əlaqə qrafıdır.
-- Mənbə → (çən) → kanal → yataq. Bir çıxış portu saniyədə ən çox 1 doza ötürür.
-- Əlaqəsi olmayan çıxış su xərcləmir. Dövrə su yaratmır (hər izləmədə ziyarət edilən düyün təkrarlanmır).
-- Çarx su keçəndə xəttə 1 enerji verir; nasos 1 enerji istəyir. Enerji yığılmır.
local Shared = script.Parent.Parent
local Types = require(Shared.Types)
local Constants = require(Shared.Constants)
local BuildDefs = require(Shared.Defs.BuildDefs)
local WorkDefs = require(Shared.Defs.WorkDefs)
local Layout = require(Shared.Layout)
local Placement = require(script.Parent.Placement)

type Profile = Types.Profile

local Water = {}

export type Node = {
	key: string,
	kind: string, -- source | consumer | channel | wheel | pump | tank | catcher | planter | sprinkler
	id: string, -- layout id və ya build uid
	zone: string?,
	ins: { string },
	outs: { string },
	center: { number },
	buildType: string?,
}

export type Graph = {
	nodes: { [string]: Node },
	order: { string },
	inIndex: { [string]: Node }, -- port açarı → həmin portda girişi olan düyün
	emitters: { Node },
	rotation: { [string]: number },
}

local function portKey(x: number, y: number, z: number): string
	return string.format("%d,%d,%d", math.floor(x + 0.5), math.floor(y + 0.5), math.floor(z + 0.5))
end
Water.portKey = portKey

local BUILD_KIND: { [string]: string } = {
	channel = "channel",
	wheel = "wheel",
	pump = "pump",
	tank = "tank",
	catcher = "catcher",
	planter = "planter",
	sprinkler = "sprinkler",
}

function Water.build(p: Profile): Graph
	local g: Graph = { nodes = {}, order = {}, inIndex = {}, emitters = {}, rotation = {} }
	local function add(node: Node)
		g.nodes[node.key] = node
		table.insert(g.order, node.key)
		for _, k in node.ins do
			-- Eyni nöqtədə iki giriş ola bilməz (yerləşdirmə üst-üstə düşməni bloklayır)
			if not g.inIndex[k] then
				g.inIndex[k] = node
			end
		end
	end
	for _, obj in Layout.objects do
		if (obj.kind == "source" or obj.kind == "consumer") and p.zones[obj.zone] then
			local ins, outs = {}, {}
			for _, wp in Layout.worldPorts(obj) do
				if wp.dir == "in" then
					table.insert(ins, portKey(wp.x, wp.y, wp.z))
				else
					table.insert(outs, portKey(wp.x, wp.y, wp.z))
				end
			end
			add({
				key = "L:" .. obj.id,
				kind = obj.kind,
				id = obj.id,
				zone = obj.zone,
				ins = ins,
				outs = outs,
				center = obj.pos,
			})
		end
	end
	local uids = {}
	for uid in p.builds do
		table.insert(uids, uid)
	end
	table.sort(uids)
	for _, uid in uids do
		local b = p.builds[uid]
		local def = BuildDefs.byId[b.t]
		local kind = def and BUILD_KIND[def.kind]
		local center = Placement.worldCenter(b)
		if kind and center then
			local ins, outs = {}, {}
			for _, wp in Placement.worldPorts(b) do
				if wp.dir == "in" then
					table.insert(ins, portKey(wp.x, wp.y, wp.z))
				else
					table.insert(outs, portKey(wp.x, wp.y, wp.z))
				end
			end
			local area = b.area and Layout.areaById[b.area]
			add({
				key = "B:" .. uid,
				kind = kind,
				id = uid,
				zone = area and area.zone or nil,
				ins = ins,
				outs = outs,
				center = center,
				buildType = b.t,
			})
		end
	end
	for _, key in g.order do
		local node = g.nodes[key]
		if node.kind == "source" or node.kind == "catcher" or node.kind == "tank" then
			table.insert(g.emitters, node)
		end
	end
	return g
end

local function consumerState(p: Profile, id: string): (Types.ConsumerDef?, boolean)
	local obj = Layout.byId[id]
	local def = obj and obj.def and WorkDefs.consumerById[obj.def]
	if not obj or not def then
		return nil, false
	end
	local extra = obj.extra
	local locked = extra ~= nil and extra.lockedBy ~= nil and not p.restoredObjectIds[extra.lockedBy :: string]
	return def, locked
end
Water.consumerState = consumerState

local function planterAccepts(p: Profile, uid: string): boolean
	local plant = p.plants["B" .. uid]
	return plant ~= nil and plant.m < Constants.MOISTURE_MAX
end

-- Çiləyicinin 6 stud radiusunda ən çox 3 əkin qabı (ən yaxından)
function Water.sprinklerTargets(p: Profile, node: Node): { string }
	local list = {}
	for uid, b in p.builds do
		if b.t == "B_PLANTER" then
			local c = Placement.worldCenter(b)
			if c and math.abs(c[2] - node.center[2]) < 2 then
				local d = math.sqrt((c[1] - node.center[1]) ^ 2 + (c[3] - node.center[3]) ^ 2)
				if d <= 6 then
					table.insert(list, { uid = uid, d = d })
				end
			end
		end
	end
	table.sort(list, function(a, b)
		if a.d == b.d then
			return a.uid < b.uid
		end
		return a.d < b.d
	end)
	local out = {}
	for i = 1, math.min(3, #list) do
		table.insert(out, list[i].uid)
	end
	return out
end

-- Terminal düyün suyu qəbul edirmi (dolğunluq nəzərə alınır)
local function accepts(p: Profile, node: Node, pumped: boolean): boolean
	if node.kind == "consumer" then
		local def, locked = consumerState(p, node.id)
		if not def or locked or p.restoredObjectIds[node.id] then
			return false
		end
		if def.requiresPump and not pumped then
			return false
		end
		return (p.moisture[node.id] or 0) < Constants.MOISTURE_MAX
	elseif node.kind == "planter" then
		return planterAccepts(p, node.id)
	elseif node.kind == "sprinkler" then
		for _, uid in Water.sprinklerTargets(p, node) do
			if planterAccepts(p, uid) then
				return true
			end
		end
		return false
	elseif node.kind == "tank" then
		local b = p.builds[node.id]
		local def = b and BuildDefs.byId[b.t]
		return b ~= nil and def ~= nil and (b.w or 0) < (def.capacity or 0)
	end
	return false
end

-- Strukturca qəbul edə bilərmi (dolğunluq nəzərə alınmır; yalnız kilid və nasos qaydası)
local function structurallyAccepts(p: Profile, node: Node, pumped: boolean): boolean
	if node.kind == "consumer" then
		local def, locked = consumerState(p, node.id)
		if not def or locked then
			return false
		end
		return not def.requiresPump or pumped
	end
	return node.kind == "planter" or node.kind == "sprinkler" or node.kind == "tank"
end

export type Trace = { target: Node, path: { Node }, wheels: number }

-- Bir çıxış portundan axını izləyir; suyu qəbul edən terminal düyünə çatırsa onu qaytarır.
function Water.trace(p: Profile, g: Graph, outKey: string): Trace?
	local visited: { [Node]: boolean } = {}
	local energy = 0
	local wheels = 0
	local pumped = false
	local path: { Node } = {}
	local key: string? = outKey
	for _ = 1, Constants.MAX_LINE_LENGTH do
		if not key then
			return nil
		end
		local node = g.inIndex[key]
		if not node or visited[node] then
			return nil
		end
		visited[node] = true
		table.insert(path, node)
		if node.kind == "channel" then
			key = node.outs[1]
		elseif node.kind == "wheel" then
			energy += 1
			wheels += 1
			key = node.outs[1]
		elseif node.kind == "pump" then
			if energy <= 0 then
				return nil
			end
			energy -= 1
			pumped = true
			key = node.outs[1]
		else
			if accepts(p, node, pumped) then
				return { target = node, path = path, wheels = wheels }
			end
			return nil
		end
	end
	return nil
end

local function emitterWater(p: Profile, node: Node): number
	if node.kind == "source" then
		return p.waterSources[node.id] or 0
	end
	local b = p.builds[node.id]
	return b and (b.w or 0) or 0
end

local function takeWater(p: Profile, node: Node)
	if node.kind == "source" then
		p.waterSources[node.id] = math.max(0, (p.waterSources[node.id] or 0) - 1)
	else
		local b = p.builds[node.id]
		if b then
			b.w = math.max(0, (b.w or 0) - 1)
		end
	end
end

export type Delivery = { target: Node, planter: string?, viaLine: boolean, wheels: number, zone: string? }

-- Bir su tiki (1 s). Dəyişən hədəflərin siyahısını qaytarır.
function Water.tick(p: Profile, g: Graph): { Delivery }
	local deliveries: { Delivery } = {}
	for _, em in g.emitters do
		local outs = em.outs
		local n = #outs
		if n > 0 then
			local start = g.rotation[em.key] or 0
			for i = 0, n - 1 do
				if emitterWater(p, em) <= 0 then
					break
				end
				local idx = ((start + i) % n) + 1
				local t = Water.trace(p, g, outs[idx])
				-- Öz girişinə qayıdan halqa: heç nə dəyişmir, çatdırılma sayılmır
				if t and t.target ~= em then
					local target = t.target
					local planterUid: string? = nil
					if target.kind == "consumer" then
						p.moisture[target.id] =
							math.min(Constants.MOISTURE_MAX, (p.moisture[target.id] or 0) + Constants.DOSE_MOISTURE)
					elseif target.kind == "planter" then
						local plant = p.plants["B" .. target.id]
						plant.m = math.min(Constants.MOISTURE_MAX, plant.m + Constants.DOSE_MOISTURE)
						planterUid = target.id
					elseif target.kind == "sprinkler" then
						-- Ən quru əkin qabını seç (əlavə su yaratmır: 1 doza → 1 qab)
						local best: string? = nil
						local bestM = math.huge
						for _, uid in Water.sprinklerTargets(p, target) do
							local plant = p.plants["B" .. uid]
							if plant and plant.m < Constants.MOISTURE_MAX and plant.m < bestM then
								best, bestM = uid, plant.m
							end
						end
						if best then
							local plant = p.plants["B" .. best]
							plant.m = math.min(Constants.MOISTURE_MAX, plant.m + Constants.DOSE_MOISTURE)
							planterUid = best
						end
					elseif target.kind == "tank" then
						local b = p.builds[target.id]
						b.w = (b.w or 0) + 1
					end
					takeWater(p, em)
					local zone = em.zone
					table.insert(
						deliveries,
						{
							target = target,
							planter = planterUid,
							viaLine = #t.path > 1 or target.kind ~= "tank",
							wheels = t.wheels,
							zone = zone,
						}
					)
				end
			end
			g.rotation[em.key] = (start + 1) % n
		end
	end
	return deliveries
end

-- Struktur yoxlaması: hər hansı mənbədən hədəfə (lazım olsa "via" qurğuları ilə) xətt varmı.
function Water.lineConnected(p: Profile, g: Graph, targetId: string, via: { string }?): boolean
	local target = g.nodes["L:" .. targetId]
	if not target then
		return false
	end
	local needed: { string } = via or {}
	local found = false

	local function dfs(
		outKey: string,
		energy: number,
		pumped: boolean,
		seen: { [string]: boolean },
		onPath: { [Node]: boolean },
		depth: number
	)
		if found or depth > Constants.MAX_LINE_LENGTH then
			return
		end
		local node = g.inIndex[outKey]
		if not node or onPath[node] then
			return
		end
		onPath[node] = true
		local newSeen = seen
		if node.buildType and table.find(needed, node.buildType) and not seen[node.buildType] then
			newSeen = table.clone(seen)
			newSeen[node.buildType] = true
		end
		if node.kind == "channel" or node.kind == "wheel" or node.kind == "pump" then
			local e, pm = energy, pumped
			local ok = true
			if node.kind == "wheel" then
				e += 1
			elseif node.kind == "pump" then
				if e <= 0 then
					ok = false
				else
					e -= 1
					pm = true
				end
			end
			if ok and node.outs[1] then
				dfs(node.outs[1], e, pm, newSeen, onPath, depth + 1)
			end
		elseif node == target then
			if structurallyAccepts(p, node, pumped) then
				local all = true
				for _, b in needed do
					if not newSeen[b] then
						all = false
					end
				end
				if all then
					found = true
				end
			end
		elseif node.kind == "tank" then
			-- Çən ötürücüdür: yenidən çıxır (enerji çəndə sıfırlanır)
			for _, o in node.outs do
				dfs(o, 0, false, newSeen, onPath, depth + 1)
			end
		end
		onPath[node] = nil
	end

	for _, em in g.emitters do
		for _, o in em.outs do
			dfs(o, 0, false, {}, { [em] = true }, 0)
			if found then
				return true
			end
		end
	end
	return found
end

-- Verilmiş tipdə qurğunun giriş portu sabit düyünün çıxış portuna bağlıdırmı
function Water.buildAtPort(p: Profile, g: Graph, buildType: string, nodeId: string): boolean
	local node = g.nodes["L:" .. nodeId]
	if not node then
		return false
	end
	for _, o in node.outs do
		local nxt = g.inIndex[o]
		if nxt and nxt.buildType == buildType then
			return true
		end
	end
	return false
end

-- Hər hansı xətt (ən azı bir kanal/çarx/nasos və ya qurğu vasitəsilə) bu hədəfə qoşulubmu
function Water.anyLine(p: Profile, g: Graph): boolean
	for _, em in g.emitters do
		for _, o in em.outs do
			if g.inIndex[o] then
				return true
			end
		end
	end
	return false
end

return Water
