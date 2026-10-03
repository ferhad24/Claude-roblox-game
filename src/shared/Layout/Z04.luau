--!strict
-- Z04 Düyünlü köklər: X −130..50, Z −110..−40. Kök tuneli, 4 ağır daş maneəsi (ling),
-- mexanika, yük lifti (Z05-ə giriş). Qısa yol: masa altından evə (Z04_Heavy_05).
local Types = require(script.Parent.Parent.Types)

local layout: Types.ZoneLayout = {
	zone = "Z04",
	safeSpawn = { 44, 3, -75 },
	objects = {
		{
			id = "Z04_Heavy_01",
			kind = "work",
			def = "W_STONE_HEAVY",
			zone = "Z04",
			pos = { 30, 0, -75 },
			blocksPath = true,
			extra = { barrier = { 4, 10, 14 } },
		},
		{
			id = "Z04_Heavy_02",
			kind = "work",
			def = "W_STONE_HEAVY",
			zone = "Z04",
			pos = { 2, 0, -75 },
			blocksPath = true,
			extra = { barrier = { 4, 10, 14 } },
		},
		{
			id = "Z04_Heavy_03",
			kind = "work",
			def = "W_STONE_HEAVY",
			zone = "Z04",
			pos = { -26, 0, -75 },
			blocksPath = true,
			extra = { barrier = { 4, 10, 14 } },
		},
		{
			id = "Z04_Heavy_04",
			kind = "work",
			def = "W_STONE_HEAVY",
			zone = "Z04",
			pos = { -54, 0, -75 },
			blocksPath = true,
			extra = { barrier = { 4, 10, 14 } },
		},
		{
			id = "Z04_Heavy_05",
			kind = "work",
			def = "W_STONE_HEAVY",
			zone = "Z04",
			pos = { -78, 0, -40 },
			blocksPath = true,
			extra = { barrier = { 12, 10, 4 } },
		},
		{
			id = "NPC_CIRT_Z04",
			kind = "npc",
			def = "NPC_CIRT_Z04",
			zone = "Z04",
			pos = { -82, 0, -62 },
			extra = { size = { 3, 5, 3 } },
		},
		{
			id = "Z04_BloomBed_01",
			kind = "consumer",
			def = "BED_BLOOM",
			zone = "Z04",
			pos = { -111, 0, -96 },
			ports = { { x = 5, z = 0, dir = "in" } },
		},
		{ id = "Z04_Plot_01", kind = "plot", zone = "Z04", pos = { -120, 0, -60 }, extra = { size = { 4, 1, 4 } } },
		{ id = "Z04_Branch_01", kind = "work", def = "W_BRANCH", zone = "Z04", pos = { -92, 0, -102 } },
		{ id = "Z04_Branch_02", kind = "work", def = "W_BRANCH", zone = "Z04", pos = { -74, 0, -94 } },
		{ id = "Z04_Stone_01", kind = "work", def = "W_STONE_LIGHT", zone = "Z04", pos = { -118, 0, -48 } },
		{ id = "Z04_Spot_Branch_01", kind = "spot", zone = "Z04", pos = { -124, 0, -106 }, spawns = { "W_BRANCH" } },
		{
			id = "Z04_Spot_Pebble_01",
			kind = "spot",
			zone = "Z04",
			pos = { -70, 0, -104 },
			spawns = { "W_STONE_LIGHT" },
		},
		{ id = "Z04_Spot_Leaf_01", kind = "spot", zone = "Z04", pos = { -126, 0, -80 }, spawns = { "W_LEAF" } },
		{ id = "Z04_Mem", kind = "memory", def = "MEM_CHINA", zone = "Z04", pos = { -127, 0, -108 } },
		-- Yük lifti: aşağı platforma Z04-də, yuxarı enmə yeri Z05 masasının kənarında (Y=24)
		{
			id = "Z04_LiftSocket",
			kind = "socket",
			def = "B_LIFT",
			zone = "Z04",
			pos = { -100, 0, -46 },
			opens = "Z05",
			extra = { top = { -100, 24, -46 }, landing = { -100, 24, -39 }, size = { 8, 1, 8 } },
		},
	},
	areas = {
		{ id = "A_Z04_HALL", zone = "Z04", origin = { -128, 0, -108 }, size = { 30, 24 } },
	},
	paths = {
		{ x0 = -66, z0 = -81, x1 = 50, z1 = -69 },
		{ x0 = -100, z0 = -81, x1 = -66, z1 = -69 },
		{ x0 = -104, z0 = -69, x1 = -96, z1 = -50 },
		{ x0 = -84, z0 = -46, x1 = -72, z1 = -34 },
	},
	ground = {
		{ pos = { -40, -1, -75 }, size = { 180, 2, 70 } },
	},
	walls = {
		{ pos = { -40, 6, -110 }, size = { 180, 12, 2 } },
		{ pos = { -130, 6, -75 }, size = { 2, 12, 70 } },
		-- Kök tunelinin divarları (X −66..50)
		{ pos = { -8, 6, -82 }, size = { 116, 12, 2 } },
		{ pos = { -8, 6, -68 }, size = { 116, 12, 2 } },
		-- Qərb zalının şərq kənarı (tunelin şimal və cənubunda)
		{ pos = { -66, 6, -96 }, size = { 2, 12, 28 } },
		{ pos = { -66, 6, -54 }, size = { 2, 12, 28 } },
		-- Masa altı ilə sərhəd (Z=−40), X −130..−84 və −72..−50; ağır daş keçidi X −84..−72
		{ pos = { -107, 6, -40 }, size = { 46, 12, 2 } },
		{ pos = { -61, 6, -40 }, size = { 22, 12, 2 } },
	},
	props = {
		{ name = "Mushroom1", pos = { -112, 3, -70 }, size = { 6, 6, 6 }, shape = "ball", color = { 230, 130, 60 } },
		{ name = "Mushroom2", pos = { -88, 2, -106 }, size = { 4, 4, 4 }, shape = "ball", color = { 230, 130, 60 } },
		{ name = "RootArch", pos = { 16, 10, -75 }, size = { 4, 4, 16 }, shape = "block", color = { 110, 75, 50 } },
	},
	water = {},
}

return layout
