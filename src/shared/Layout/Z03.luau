--!strict
-- Z03 Köhnə dibçək: X 50..130, Z −110..−8. Nəhəng çatlamış terrakota dibçək (mərkəz 90, −66),
-- 3 kök keçidi (kürək), araba ilə çat yamağı, əkin qabları, dibçəyə su xətti.
local Types = require(script.Parent.Parent.Types)

local CX, CZ = 90, -66
local R_OUT = 26
local THICK = 3
local WALL_H = 14

local function ring(angleDeg: number, radius: number): { number }
	local a = math.rad(angleDeg)
	return { CX + radius * math.cos(a), 0, CZ + radius * math.sin(a) }
end

-- Kök keçidləri (boşluqlar): 60°, 180°, 300° əsas; 240° qısa yol
local GAPS = { [60] = true, [180] = true, [240] = true, [300] = true }

local walls: { { pos: { number }, size: { number }, rot: number?, transparent: boolean? } } = {
	{ pos = { 90, 5, -110 }, size = { 80, 10, 2 } },
	{ pos = { 130, 5, -59 }, size = { 2, 10, 102 } },
	{ pos = { 50, 5, -95.5 }, size = { 2, 10, 29 } }, -- qərb (Z −110..−81)
	{ pos = { 50, 5, -54.5 }, size = { 2, 10, 29 } }, -- qərb (Z −69..−40)
	-- Çayın şimal sahili, körpü yeri X 106..112 açıqdır
	{ pos = { 78, 1.5, -9 }, size = { 56, 3, 1 } },
	{ pos = { 121, 1.5, -9 }, size = { 18, 3, 1 } },
}
local midR = R_OUT - THICK / 2
local segLen = 2 * math.pi * midR / 24 + 0.4
for k = 0, 23 do
	local deg = k * 15
	if not GAPS[deg] then
		local p = ring(deg, midR)
		table.insert(walls, { pos = { p[1], WALL_H / 2, p[3] }, size = { segLen, WALL_H, THICK }, rot = -(deg + 90) })
	end
end

local function at(angleDeg: number, radius: number): { number }
	local p = ring(angleDeg, radius)
	return { math.floor(p[1] * 100 + 0.5) / 100, 0, math.floor(p[3] * 100 + 0.5) / 100 }
end

local layout: Types.ZoneLayout = {
	zone = "Z03",
	safeSpawn = { 109, 3, -14 },
	objects = {
		{
			id = "NPC_NARGIZ_Z03",
			kind = "npc",
			def = "NPC_NARGIZ_Z03",
			zone = "Z03",
			pos = { 100, 0, -22 },
			extra = { size = { 3, 5, 3 } },
		},
		-- Kök keçidləri: dibçək divarındakı torpaqla tıxanmış çatlar
		{
			id = "Z03_Soil_01",
			kind = "work",
			def = "W_SOIL_CLOG",
			zone = "Z03",
			pos = at(60, midR),
			blocksPath = true,
			extra = { barrier = { 7, 10, 7 } },
		},
		{
			id = "Z03_Soil_02",
			kind = "work",
			def = "W_SOIL_CLOG",
			zone = "Z03",
			pos = at(180, midR),
			blocksPath = true,
			extra = { barrier = { 7, 10, 7 } },
		},
		{
			id = "Z03_Soil_03",
			kind = "work",
			def = "W_SOIL_CLOG",
			zone = "Z03",
			pos = at(300, midR),
			blocksPath = true,
			extra = { barrier = { 7, 10, 7 } },
		},
		{
			id = "Z03_Soil_04",
			kind = "work",
			def = "W_SOIL_CLOG",
			zone = "Z03",
			pos = at(240, midR),
			blocksPath = true,
			extra = { barrier = { 7, 10, 7 } },
		},
		-- Araba ilə daşınan terrakota parçaları və çat
		{ id = "Z03_Shard_01", kind = "cargo", def = "CARGO_SHARD", zone = "Z03", pos = { 58, 0, -100 } },
		{ id = "Z03_Shard_02", kind = "cargo", def = "CARGO_SHARD", zone = "Z03", pos = { 124, 0, -30 } },
		{ id = "Z03_Shard_03", kind = "cargo", def = "CARGO_SHARD", zone = "Z03", pos = { 126, 0, -96 } },
		{
			id = "Z03_PotCrack",
			kind = "dropoff",
			def = "CARGO_SHARD",
			zone = "Z03",
			pos = at(120, 28),
			count = 3,
			extra = { size = { 6, 10, 3 } },
		},
		-- Dibçəyin içindəki quru torpaq çuxuru: çat yamanmayınca su saxlamır
		{
			id = "Z03_PotBasin",
			kind = "consumer",
			def = "POT_BASIN",
			zone = "Z03",
			pos = { 90, 0, -66 },
			ports = { { x = -6, z = 0, dir = "in" } },
			extra = { lockedBy = "Z03_PotCrack" },
		},
		{
			id = "Z03_BloomBed_01",
			kind = "consumer",
			def = "BED_BLOOM",
			zone = "Z03",
			pos = { 124, 0, -65 },
			ports = { { x = 0, z = -5, dir = "in" } },
		},
		{ id = "Z03_Plot_01", kind = "plot", zone = "Z03", pos = { 88, 0, -18 }, extra = { size = { 4, 1, 4 } } },
		{ id = "Z03_Clay_01", kind = "work", def = "W_CLAY", zone = "Z03", pos = { 116, 0, -30 } },
		{ id = "Z03_Metal_01", kind = "work", def = "W_METAL", zone = "Z03", pos = { 68, 0, -104 } },
		{ id = "Z03_Spot_Clay_01", kind = "spot", zone = "Z03", pos = { 58, 0, -104 }, spawns = { "W_CLAY" } },
		{ id = "Z03_Spot_Clay_02", kind = "spot", zone = "Z03", pos = { 124, 0, -48 }, spawns = { "W_CLAY" } },
		{ id = "Z03_Spot_Metal_01", kind = "spot", zone = "Z03", pos = { 60, 0, -52 }, spawns = { "W_METAL" } },
		{ id = "Z03_Spot_Metal_02", kind = "spot", zone = "Z03", pos = { 126, 0, -104 }, spawns = { "W_METAL" } },
		{ id = "Z03_Mem", kind = "memory", def = "MEM_KEY", zone = "Z03", pos = { 100, 0, -76 } },
		{
			id = "GATE_Z04",
			kind = "gate",
			zone = "Z03",
			pos = { 50, 0, -75 },
			extra = { unlockZone = "Z04", size = { 2, 10, 12 } },
		},
	},
	areas = {
		{ id = "A_Z03_POT", zone = "Z03", origin = { 72, 0, -76 }, size = { 12, 20 } },
		{ id = "A_Z03_YARD", zone = "Z03", origin = { 56, 0, -36 }, size = { 40, 22 } },
	},
	paths = {
		{ x0 = 106, z0 = -40, x1 = 112, z1 = -8 },
		{ x0 = 50, z0 = -14, x1 = 112, z1 = -8 },
		{ x0 = 50, z0 = -81, x1 = 56, z1 = -8 },
	},
	ground = {
		{ pos = { 90, -1, -59 }, size = { 80, 2, 102 } },
	},
	walls = walls,
	props = {
		{
			name = "PotRimShadow",
			pos = { 90, 0.2, -66 },
			size = { 46, 0.4, 46 },
			shape = "cylinder",
			color = { 120, 90, 70 },
			collide = false,
		},
	},
	water = {},
}

return layout
