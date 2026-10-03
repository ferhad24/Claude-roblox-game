--!strict
-- Z05 Şüşə istixana: köhnə masanın üstü (X −130..−50, Z −36..60, Y=24).
-- 4 tozlu panel (fırça), nasos, 3 işlək əkin qabı, istixana çiçəkləri.
local Types = require(script.Parent.Parent.Types)

local Y = 24

local layout: Types.ZoneLayout = {
	zone = "Z05",
	safeSpawn = { -100, Y + 3, -32 },
	objects = {
		{
			id = "NPC_CIRT_Z05",
			kind = "npc",
			def = "NPC_CIRT_Z05",
			zone = "Z05",
			pos = { -108, Y, -28 },
			extra = { size = { 3, 5, 3 } },
		},
		-- Paneller: 01 istixananın tozlu şüşə qapısıdır
		{
			id = "Z05_Panel_01",
			kind = "work",
			def = "W_GLASS_PANEL",
			zone = "Z05",
			pos = { -90, Y, -20 },
			blocksPath = true,
			extra = { barrier = { 8, 14, 1 }, size = { 8, 14, 1 } },
		},
		{
			id = "Z05_Panel_02",
			kind = "work",
			def = "W_GLASS_PANEL",
			zone = "Z05",
			pos = { -119, Y, 15 },
			extra = { size = { 1, 12, 10 } },
		},
		{
			id = "Z05_Panel_03",
			kind = "work",
			def = "W_GLASS_PANEL",
			zone = "Z05",
			pos = { -90, Y, 49 },
			extra = { size = { 10, 12, 1 } },
		},
		{
			id = "Z05_Panel_04",
			kind = "work",
			def = "W_GLASS_PANEL",
			zone = "Z05",
			pos = { -61, Y, 22 },
			extra = { size = { 1, 12, 10 } },
		},
		-- Yağış novu: sonsuz, yavaş dolan mənbə (layihə qərarı, docs/DESIGN_DECISIONS.md)
		{
			id = "Z05_Gutter",
			kind = "source",
			zone = "Z05",
			pos = { -64, Y, 0 },
			ports = { { x = -2, z = 0, dir = "out" } },
			capacity = 12,
			regenSeconds = 5,
			infinite = true,
			extra = { size = { 4, 6, 4 } },
		},
		{
			id = "Z05_BloomBed_01",
			kind = "consumer",
			def = "BED_BLOOM",
			zone = "Z05",
			pos = { -111, Y, 36 },
			ports = { { x = 5, z = 0, dir = "in" } },
		},
		{
			id = "Z05_BloomBed_02",
			kind = "consumer",
			def = "BED_BLOOM_HIGH",
			zone = "Z05",
			pos = { -77, Y, 40 },
			ports = { { x = -5, z = 0, dir = "in" } },
		},
		{ id = "Z05_Plot_01", kind = "plot", zone = "Z05", pos = { -104, Y, 16 }, extra = { size = { 4, 1, 4 } } },
		{ id = "Z05_Glass_01", kind = "work", def = "W_GLASS_SHARD", zone = "Z05", pos = { -100, Y, -10 } },
		{ id = "Z05_Glass_02", kind = "work", def = "W_GLASS_SHARD", zone = "Z05", pos = { -72, Y, -10 } },
		{ id = "Z05_Spot_Glass_01", kind = "spot", zone = "Z05", pos = { -114, Y, -12 }, spawns = { "W_GLASS_SHARD" } },
		{ id = "Z05_Spot_Glass_02", kind = "spot", zone = "Z05", pos = { -114, Y, 44 }, spawns = { "W_GLASS_SHARD" } },
		{ id = "Z05_Spot_Metal_01", kind = "spot", zone = "Z05", pos = { -68, Y, 44 }, spawns = { "W_METAL" } },
		{ id = "Z05_Mem", kind = "memory", def = "MEM_ORB", zone = "Z05", pos = { -126, Y, 56 } },
		-- Masadan aşağı enən rampanın üst qapısı (Z05 açılanda açılır)
		{
			id = "GATE_Z05R",
			kind = "gate",
			zone = "Z05",
			pos = { -60, Y, 60 },
			extra = { unlockZone = "Z05", size = { 8, 8, 2 } },
		},
	},
	areas = {
		{ id = "A_Z05_GH", zone = "Z05", origin = { -118, Y, -18 }, size = { 56, 66 } },
	},
	paths = {
		{ x0 = -104, z0 = -36, x1 = -96, z1 = -20 },
		{ x0 = -94, z0 = -20, x1 = -86, z1 = 30 },
	},
	ground = {
		{ pos = { -90, Y - 1, 12 }, size = { 80, 2, 96 } },
	},
	walls = {
		-- Masanın kənar qoruyucuları
		{ pos = { -117, Y + 1.5, -36 }, size = { 26, 3, 1 } }, -- X −130..−104
		{ pos = { -73, Y + 1.5, -36 }, size = { 46, 3, 1 } }, -- X −96..−50
		{ pos = { -130, Y + 1.5, 12 }, size = { 1, 3, 96 } },
		{ pos = { -50, Y + 1.5, 12 }, size = { 1, 3, 96 } },
		{ pos = { -97, Y + 1.5, 60 }, size = { 66, 3, 1 } }, -- X −130..−64
		{ pos = { -53, Y + 1.5, 60 }, size = { 6, 3, 1 } }, -- X −56..−50
		-- İstixananın şüşə divarları (X −120..−60, Z −20..50), qapı X −94..−86
		{ pos = { -107, Y + 10, -20 }, size = { 26, 20, 1 }, transparent = true },
		{ pos = { -73, Y + 10, -20 }, size = { 26, 20, 1 }, transparent = true },
		{ pos = { -120, Y + 10, 15 }, size = { 1, 20, 70 }, transparent = true },
		{ pos = { -60, Y + 10, 15 }, size = { 1, 20, 70 }, transparent = true },
		{ pos = { -90, Y + 10, 50 }, size = { 60, 20, 1 }, transparent = true },
	},
	props = {
		{
			name = "Shelf",
			pos = { -77, Y + 2, 40 },
			size = { 14, 4, 12 },
			shape = "block",
			color = { 170, 125, 85 },
			collide = false,
		},
		{
			name = "ColorJar1",
			pos = { -116, Y + 3, -16 },
			size = { 3, 6, 3 },
			shape = "cylinder",
			color = { 169, 149, 207 },
		},
		{
			name = "ColorJar2",
			pos = { -64, Y + 3, 46 },
			size = { 3, 6, 3 },
			shape = "cylinder",
			color = { 237, 200, 109 },
		},
		-- Masadan cənuba enən rampa (Z 60 → 100)
		{
			name = "Ramp",
			pos = { -60, 12, 80 },
			size = { 8, 1, 46.6 },
			shape = "block",
			color = { 170, 125, 85 },
			tilt = 31,
		},
	},
	water = {},
}

return layout
