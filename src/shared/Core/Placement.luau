--!strict
-- Qurğuların yerləşdirilməsi (bölmə 11): 1 stud şəbəkə, 90° döndürmə, sahə və maneə yoxlaması.
-- Transform sahənin lokal koordinatında saxlanılır: {area, x, z, r, v}. x/z qurğunun mərkəzidir.
-- Döndürmə qaydası: r=1 lokal +X istiqamətini dünya +Z-yə çevirir (Roblox yaw = −90° × r).
local Shared = script.Parent.Parent
local Types = require(Shared.Types)
local Constants = require(Shared.Constants)
local BuildDefs = require(Shared.Defs.BuildDefs)
local Layout = require(Shared.Layout)

type Profile = Types.Profile
type PlacedBuild = Types.PlacedBuild
type Rect = Types.Rect
type Port = Types.Port
type BuildDef = Types.BuildDef

local Placement = {}

export type WorldPort = { x: number, y: number, z: number, dir: string }

function Placement.rotate(x: number, z: number, r: number): (number, number)
	r = r % 4
	if r == 0 then
		return x, z
	elseif r == 1 then
		return -z, x
	elseif r == 2 then
		return -x, -z
	else
		return z, -x
	end
end

function Placement.variantOf(def: BuildDef, v: string?): ({ number }, { Port })
	if def.variants then
		for _, variant in def.variants do
			if variant.id == (v or "straight") then
				return variant.footprint, variant.ports
			end
		end
		local first = def.variants[1]
		return first.footprint, first.ports
	end
	return def.footprint, def.ports
end

function Placement.validVariant(def: BuildDef, v: string?): boolean
	if not def.variants then
		return v == nil
	end
	if v == nil then
		return true
	end
	for _, variant in def.variants do
		if variant.id == v then
			return true
		end
	end
	return false
end

-- Qurğunun dünya mərkəzi {x, y, z}
function Placement.worldCenter(b: PlacedBuild): { number }?
	if b.area then
		local area = Layout.areaById[b.area]
		if not area then
			return nil
		end
		return { area.origin[1] + b.x, area.origin[2], area.origin[3] + b.z }
	elseif b.socket then
		local obj = Layout.byId[b.socket]
		if not obj then
			return nil
		end
		return { obj.pos[1], obj.pos[2], obj.pos[3] }
	end
	return nil
end

function Placement.footprintRect(def: BuildDef, center: { number }, r: number, v: string?): Rect
	local fp = Placement.variantOf(def, v)
	local fx, fz = fp[1], fp[2]
	if r % 2 == 1 then
		fx, fz = fz, fx
	end
	-- Künc formaları üçün footprint simmetrikdir (kvadrat), ona görə mərkəzə nisbətən yetərlidir
	return { x0 = center[1] - fx / 2, z0 = center[3] - fz / 2, x1 = center[1] + fx / 2, z1 = center[3] + fz / 2 }
end

-- Nöqtədən qurğunun footprint-inə üfüqi məsafə (server və client eyni funksiyanı işlədir)
function Placement.distanceToBuild(b: PlacedBuild, x: number, y: number, z: number): number
	local def = BuildDefs.byId[b.t]
	local c = Placement.worldCenter(b)
	if not def or not c then
		return math.huge
	end
	if math.abs(y - c[2]) > 14 then
		return math.huge
	end
	local rect = Placement.footprintRect(def, c, b.r, b.v)
	local dx = math.max(0, rect.x0 - x, x - rect.x1)
	local dz = math.max(0, rect.z0 - z, z - rect.z1)
	return math.sqrt(dx * dx + dz * dz)
end

function Placement.worldPorts(b: PlacedBuild): { WorldPort }
	local def = BuildDefs.byId[b.t]
	local center = Placement.worldCenter(b)
	local out: { WorldPort } = {}
	if not def or not center then
		return out
	end
	local _, ports = Placement.variantOf(def, b.v)
	for _, p in ports do
		local rx, rz = Placement.rotate(p.x, p.z, b.r)
		table.insert(out, { x = center[1] + rx, y = center[2], z = center[3] + rz, dir = p.dir })
	end
	return out
end

local function overlaps(a: Rect, b: Rect): boolean
	local eps = 1e-6
	return a.x0 < b.x1 - eps and b.x0 < a.x1 - eps and a.z0 < b.z1 - eps and b.z0 < a.z1 - eps
end
Placement.overlaps = overlaps

local function sameLevel(y1: number, y2: number): boolean
	return math.abs(y1 - y2) < 2
end

export type PlaceRequest = { area: string?, socket: string?, x: number?, z: number?, r: number?, v: string? }

-- Qurğu sayı (yerləşdirilmiş + inventarda)
function Placement.countOwned(p: Profile, buildId: string): number
	local n = p.buildInv[buildId] or 0
	for _, b in p.builds do
		if b.t == buildId then
			n += 1
		end
	end
	return n
end

function Placement.countPlaced(p: Profile, buildId: string?): number
	local n = 0
	for _, b in p.builds do
		if buildId == nil or b.t == buildId then
			n += 1
		end
	end
	return n
end

-- Yerləşdirmənin yoxlanması. ignoreUid: köçürmə zamanı qurğunun özü.
function Placement.validate(
	p: Profile,
	buildId: string,
	req: PlaceRequest,
	ignoreUid: string?
): (boolean, string?, PlacedBuild?)
	local def = BuildDefs.byId[buildId]
	if not def then
		return false, "msg.badRequest", nil
	end
	if def.socketOnly then
		local socketId = req.socket
		if type(socketId) ~= "string" then
			return false, "msg.cantPlace", nil
		end
		local obj = Layout.byId[socketId]
		if not obj or obj.kind ~= "socket" or obj.def ~= buildId then
			return false, "msg.cantPlace", nil
		end
		if not p.zones[obj.zone] then
			return false, "msg.locked", nil
		end
		for uid, b in p.builds do
			if b.socket == socketId and uid ~= ignoreUid then
				return false, "msg.slotBusy", nil
			end
		end
		return true, nil, { t = buildId, socket = socketId, x = 0, z = 0, r = 0 }
	end

	local areaId = req.area
	if type(areaId) ~= "string" then
		return false, "msg.cantPlace", nil
	end
	local area = Layout.areaById[areaId]
	if not area then
		return false, "msg.cantPlace", nil
	end
	if not p.zones[area.zone] then
		return false, "msg.locked", nil
	end
	local x, z, r = req.x, req.z, req.r
	if type(x) ~= "number" or type(z) ~= "number" or type(r) ~= "number" then
		return false, "msg.badRequest", nil
	end
	if x ~= x or z ~= z or r ~= r or x % 1 ~= 0 or z % 1 ~= 0 or r % 1 ~= 0 or r < 0 or r > 3 then
		return false, "msg.badRequest", nil
	end
	if not Placement.validVariant(def, req.v) then
		return false, "msg.badRequest", nil
	end
	local candidate: PlacedBuild = { t = buildId, area = areaId, x = x, z = z, r = r, v = req.v }
	local center = Placement.worldCenter(candidate) :: { number }
	local rect = Placement.footprintRect(def, center, r, req.v)
	-- Sahənin içində
	local ax0, az0 = area.origin[1], area.origin[3]
	local ax1, az1 = ax0 + area.size[1], az0 + area.size[2]
	if rect.x0 < ax0 or rect.z0 < az0 or rect.x1 > ax1 or rect.z1 > az1 then
		return false, "msg.cantPlace", nil
	end
	-- Sabit obyektlər və divarlar
	for _, blk in Layout.blocked do
		if sameLevel(blk.y, center[2]) and overlaps(rect, blk.rect) then
			-- Bərpa olunmuş maneənin bariyeri artıq yoxdur, amma obyektin özü yerində qalır: yenə bloklayırıq
			return false, "msg.cantPlace", nil
		end
	end
	-- Yollar (kanal kimi alçaq qurğular istisna)
	if def.blocksPath then
		for _, path in Layout.paths do
			if sameLevel(path.y, center[2]) and overlaps(rect, path.rect) then
				return false, "msg.cantPlace", nil
			end
		end
	end
	-- Digər qurğular
	for uid, b in p.builds do
		if uid ~= ignoreUid and b.area then
			local odef = BuildDefs.byId[b.t]
			local oc = Placement.worldCenter(b)
			if odef and oc and sameLevel(oc[2], center[2]) then
				if overlaps(rect, Placement.footprintRect(odef, oc, b.r, b.v)) then
					return false, "msg.cantPlace", nil
				end
			end
		end
	end
	return true, nil, candidate
end

function Placement.totalLimitReached(p: Profile): boolean
	return Placement.countPlaced(p, nil) >= Constants.MAX_PLAYER_BUILDS
end

return Placement
