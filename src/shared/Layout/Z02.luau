--!strict
-- Z02 Şeh çəmənliyi: X 50..130, Z 8..110. Su toplayıcı, çarx, 4 çiçək qrupu, ip körpü.
local Types = require(script.Parent.Parent.Types)

local layout: Types.ZoneLayout = {
	zone = "Z02",
	safeSpawn = { 56, 3, 77 },
	objects = {
		{
			id = "NPC_CIRT_Z02",
			kind = "npc",
			def = "NPC_CIRT_Z02",
			zone = "Z02",
			pos = { 60, 0, 68 },
			extra = { size = { 3, 5, 3 } },
		},
		{
			id = "Z02_Bed_01",
			kind = "consumer",
			def = "BED_DRY",
			zone = "Z02",
			pos = { 71, 0, 96 },
			ports = { { x = 5, z = 0, dir = "in" } },
		},
		{
			id = "Z02_Bed_02",
			kind = "consumer",
			def = "BED_DRY",
			zone = "Z02",
			pos = { 121, 0, 96 },
			ports = { { x = -5, z = 0, dir = "in" } },
		},
		{
			id = "Z02_Bed_03",
			kind = "consumer",
			def = "BED_DRY",
			zone = "Z02",
			pos = { 123, 0, 60 },
			ports = { { x = -5, z = 0, dir = "in" } },
		},
		{
			id = "Z02_BloomBed_01",
			kind = "consumer",
			def = "BED_BLOOM",
			zone = "Z02",
			pos = { 95, 0, 40 },
			ports = { { x = -5, z = 0, dir = "in" } },
		},
		{ id = "Z02_Plot_01", kind = "plot", zone = "Z02", pos = { 80, 0, 64 }, extra = { size = { 4, 1, 4 } } },
		{ id = "Z02_Plot_02", kind = "plot", zone = "Z02", pos = { 86, 0, 64 }, extra = { size = { 4, 1, 4 } } },
		-- Birdəfəlik maneələr
		{ id = "Z02_Branch_01", kind = "work", def = "W_BRANCH", zone = "Z02", pos = { 80, 0, 77 } },
		{ id = "Z02_Branch_02", kind = "work", def = "W_BRANCH", zone = "Z02", pos = { 100, 0, 88 } },
		{ id = "Z02_Branch_03", kind = "work", def = "W_BRANCH", zone = "Z02", pos = { 109, 0, 30 } },
		{ id = "Z02_Branch_04", kind = "work", def = "W_BRANCH", zone = "Z02", pos = { 64, 0, 104 } },
		-- Qısa yol: çəmənliyi bölən hasar keçidi (əlavə iş S2_SHORTCUT)
		{
			id = "Z02_Branch_05",
			kind = "work",
			def = "W_BRANCH",
			zone = "Z02",
			pos = { 63, 0, 56 },
			blocksPath = true,
			extra = { barrier = { 6, 6, 2 } },
		},
		{ id = "Z02_Stone_01", kind = "work", def = "W_STONE_LIGHT", zone = "Z02", pos = { 90, 0, 104 } },
		{ id = "Z02_Stone_02", kind = "work", def = "W_STONE_LIGHT", zone = "Z02", pos = { 126, 0, 30 } },
		{ id = "Z02_Leaf_01", kind = "work", def = "W_LEAF", zone = "Z02", pos = { 74, 0, 86 } },
		{ id = "Z02_Leaf_02", kind = "work", def = "W_LEAF", zone = "Z02", pos = { 92, 0, 70 } },
		{ id = "Z02_Leaf_03", kind = "work", def = "W_LEAF", zone = "Z02", pos = { 118, 0, 44 } },
		-- Yenilənən yuvalar: budaq, qatran, çınqıl (bölmə 9)
		{ id = "Z02_Spot_Branch_01", kind = "spot", zone = "Z02", pos = { 56, 0, 96 }, spawns = { "W_BRANCH" } },
		{ id = "Z02_Spot_Branch_02", kind = "spot", zone = "Z02", pos = { 124, 0, 106 }, spawns = { "W_BRANCH" } },
		{ id = "Z02_Spot_Resin_01", kind = "spot", zone = "Z02", pos = { 60, 0, 22 }, spawns = { "W_RESIN" } },
		{ id = "Z02_Spot_Resin_02", kind = "spot", zone = "Z02", pos = { 76, 0, 14 }, spawns = { "W_RESIN" } },
		{ id = "Z02_Spot_Resin_03", kind = "spot", zone = "Z02", pos = { 124, 0, 74 }, spawns = { "W_RESIN" } },
		{ id = "Z02_Spot_Pebble_01", kind = "spot", zone = "Z02", pos = { 126, 0, 16 }, spawns = { "W_STONE_LIGHT" } },
		{ id = "Z02_Mem", kind = "memory", def = "MEM_BEAD", zone = "Z02", pos = { 54, 0, 12 } },
		{
			id = "Z02_BridgeSocket",
			kind = "socket",
			def = "B_BRIDGE",
			zone = "Z02",
			pos = { 109, 0, 0 },
			opens = "Z03",
			extra = { span = { 0, 0, -10, 0, 0, 10 }, width = 6 },
		},
	},
	areas = {
		{ id = "A_Z02_LINE", zone = "Z02", origin = { 70, 0, 32 }, size = { 20, 16 } },
		{ id = "A_Z02_FIELD", zone = "Z02", origin = { 52, 0, 58 }, size = { 40, 12 } },
		{ id = "A_Z02_NORTH", zone = "Z02", origin = { 78, 0, 90 }, size = { 30, 18 } },
	},
	paths = {
		{ x0 = 50, z0 = 74, x1 = 112, z1 = 80 },
		{ x0 = 106, z0 = 8, x1 = 112, z1 = 110 },
		{ x0 = 60, z0 = 50, x1 = 66, z1 = 62 },
	},
	ground = {
		{ pos = { 90, -1, 59 }, size = { 80, 2, 102 } },
	},
	walls = {
		{ pos = { 90, 5, 110 }, size = { 80, 10, 2 } },
		{ pos = { 130, 5, 59 }, size = { 2, 10, 102 } },
		-- Çəmənliyi bölən hasar (Z=56), X 50..104, keçid X 60..66
		{ pos = { 55, 3, 56 }, size = { 10, 6, 1 } },
		{ pos = { 85, 3, 56 }, size = { 38, 6, 1 } },
		-- Çayın sahili (aşağı hasar), körpü yeri X 106..112 açıqdır
		{ pos = { 78, 1.5, 9 }, size = { 56, 3, 1 } },
		{ pos = { 121, 1.5, 9 }, size = { 18, 3, 1 } },
	},
	props = {
		{
			name = "OldShoe",
			pos = { 116, 6, 20 },
			size = { 10, 12, 25 },
			shape = "block",
			color = { 90, 70, 60 },
			rot = 15,
		},
		{
			name = "GrassBlade1",
			pos = { 58, 9, 40 },
			size = { 2, 18, 2 },
			shape = "block",
			color = { 120, 160, 90 },
			stage = "any",
		},
		{
			name = "GrassBlade2",
			pos = { 128, 11, 90 },
			size = { 2, 22, 2 },
			shape = "block",
			color = { 120, 160, 90 },
			stage = "any",
		},
		{ name = "FlatStone", pos = { 100, 0.5, 60 }, size = { 12, 1, 9 }, shape = "block", color = { 160, 160, 150 } },
	},
	water = {
		{ pos = { 90, -3, 0 }, size = { 80, 6, 16 } }, -- çay: düşən oyunçu son təhlükəsiz nöqtəyə qaytarılır
	},
}

return layout
