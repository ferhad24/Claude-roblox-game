--!strict
-- Bütün sahə tərtibatlarının indeksi: obyektlər, tikinti sahələri, bloklanmış düzbucaqlılar.
local Types = require(script.Parent.Types)
local WorkDefs = require(script.Parent.Defs.WorkDefs)

type LayoutObject = Types.LayoutObject
type ZoneLayout = Types.ZoneLayout
type Rect = Types.Rect
type BuildArea = Types.BuildArea

local zones: { ZoneLayout } = {
	require(script.Z01) :: ZoneLayout,
	require(script.Z02) :: ZoneLayout,
	require(script.Z03) :: ZoneLayout,
	require(script.Z04) :: ZoneLayout,
	require(script.Z05) :: ZoneLayout,
	require(script.Z06) :: ZoneLayout,
}

local DEFAULT_SIZE: { [string]: { number } } = {
	work = { 4, 4, 4 },
	consumer = { 10, 1.2, 8 },
	source = { 6, 3, 6 },
	plot = { 4, 1, 4 },
	spot = { 4, 2, 4 },
	socket = { 6, 1, 6 },
	npc = { 3, 5, 3 },
	storage = { 5, 4, 4 },
	workbench = { 6, 4, 4 },
	shop = { 6, 5, 6 },
	board = { 4, 6, 1 },
	memory = { 2, 2, 2 },
	cargo = { 3, 2, 3 },
	dropoff = { 4, 4, 4 },
	gate = { 4, 10, 4 },
	lamp = { 2, 6, 2 },
	tree = { 16, 100, 16 },
	home = { 12, 10, 12 },
}

local function sizeOf(obj: LayoutObject): { number }
	local extra = obj.extra
	if extra and extra.size then
		return extra.size :: { number }
	end
	if obj.kind == "work" and obj.def then
		local w = WorkDefs.workById[obj.def]
		if w then
			return w.size
		end
	end
	if obj.kind == "consumer" and obj.def then
		local c = WorkDefs.consumerById[obj.def]
		if c then
			return c.size
		end
	end
	return DEFAULT_SIZE[obj.kind] or { 4, 4, 4 }
end

local function rectAround(x: number, z: number, sx: number, sz: number, rotDeg: number?): Rect
	local hx, hz = sx / 2, sz / 2
	if rotDeg and rotDeg % 180 ~= 0 then
		local a = math.rad(rotDeg)
		local c, s = math.abs(math.cos(a)), math.abs(math.sin(a))
		hx, hz = c * sx / 2 + s * sz / 2, s * sx / 2 + c * sz / 2
	end
	return { x0 = x - hx, z0 = z - hz, x1 = x + hx, z1 = z + hz }
end

local objects: { LayoutObject } = {}
local byId: { [string]: LayoutObject } = {}
local byZone: { [string]: { LayoutObject } } = {}
local areas: { BuildArea } = {}
local areaById: { [string]: BuildArea } = {}
local blocked: { { rect: Rect, y: number, id: string? } } = {}
local paths: { { rect: Rect, y: number } } = {}
local zoneLayout: { [string]: ZoneLayout } = {}

for _, zl in zones do
	zoneLayout[zl.zone] = zl
	byZone[zl.zone] = {}
	for _, obj in zl.objects do
		table.insert(objects, obj)
		byId[obj.id] = obj
		table.insert(byZone[zl.zone], obj)
		local size = sizeOf(obj)
		if obj.kind ~= "gate" then
			table.insert(
				blocked,
				{ rect = rectAround(obj.pos[1], obj.pos[3], size[1], size[3], obj.rot), y = obj.pos[2], id = obj.id }
			)
		end
		local extra = obj.extra
		if extra and extra.barrier then
			local b = extra.barrier :: { number }
			table.insert(
				blocked,
				{ rect = rectAround(obj.pos[1], obj.pos[3], b[1], b[3], obj.rot), y = obj.pos[2], id = obj.id }
			)
		end
	end
	for _, area in zl.areas do
		table.insert(areas, area)
		areaById[area.id] = area
	end
	for _, wall in zl.walls do
		local baseY = wall.pos[2] - wall.size[2] / 2
		table.insert(
			blocked,
			{ rect = rectAround(wall.pos[1], wall.pos[3], wall.size[1], wall.size[3], wall.rot), y = baseY }
		)
	end
	for _, p in zl.paths do
		local y = 0
		if zl.zone == "Z05" then
			y = 24
		end
		table.insert(paths, { rect = p, y = y })
	end
end

-- Obyektin portlarını dünya koordinatında qaytarır.
local function worldPorts(obj: LayoutObject): { { x: number, y: number, z: number, dir: string } }
	local out = {}
	if obj.ports then
		for _, p in obj.ports do
			table.insert(out, { x = obj.pos[1] + p.x, y = obj.pos[2], z = obj.pos[3] + p.z, dir = p.dir })
		end
	end
	return out
end

-- Nöqtədən obyektin footprint-inə üfüqi məsafə (fırlanma nəzərə alınır). Server iş/əlaqə
-- məsafəsini bununla yoxlayır; client ipuclarını eyni funksiya ilə göstərir ki, uyğunsuzluq olmasın.
local function distanceTo(obj: LayoutObject, x: number, y: number, z: number): number
	if math.abs(y - obj.pos[2]) > 14 then
		return math.huge
	end
	local size = sizeOf(obj)
	local r = rectAround(obj.pos[1], obj.pos[3], size[1], size[3], obj.rot)
	local dx = math.max(0, r.x0 - x, x - r.x1)
	local dz = math.max(0, r.z0 - z, z - r.z1)
	return math.sqrt(dx * dx + dz * dz)
end

return {
	zones = zones,
	zoneLayout = zoneLayout,
	objects = objects,
	byId = byId,
	byZone = byZone,
	areas = areas,
	areaById = areaById,
	blocked = blocked,
	paths = paths,
	sizeOf = sizeOf,
	rectAround = rectAround,
	worldPorts = worldPorts,
	distanceTo = distanceTo,
}
