--!strict
-- Z01 Qoz məhəlləsi: X −50..50, Z 40..110. Ev, dükan, emalatxana, ilk su xətti.
-- Bütün koordinatlar dünya koordinatıdır (stud). Portlar obyektin mərkəzinə nisbətəndir.
local Types = require(script.Parent.Parent.Types)

local layout: Types.ZoneLayout = {
	zone = "Z01",
	safeSpawn = { 0, 3, 86 },
	objects = {
		-- Ev və mərkəz
		{ id = "Z01_Home", kind = "home", zone = "Z01", pos = { 0, 0, 100 }, extra = { size = { 16, 14, 14 } } },
		{ id = "Z01_Storage", kind = "storage", zone = "Z01", pos = { 11, 0, 95 }, extra = { size = { 5, 4, 4 } } },
		{
			id = "Z01_Shop",
			kind = "npc",
			def = "NPC_PITIR",
			zone = "Z01",
			pos = { -22, 0, 92 },
			extra = { size = { 8, 6, 6 } },
		},
		{ id = "Z01_Board", kind = "board", zone = "Z01", pos = { -12, 0, 86 }, extra = { size = { 4, 6, 1 } } },
		{
			id = "Z01_Nargiz",
			kind = "npc",
			def = "NPC_NARGIZ_Z01",
			zone = "Z01",
			pos = { -6, 0, 78 },
			extra = { size = { 3, 5, 3 } },
		},
		{
			id = "Z01_DewBowl",
			kind = "source",
			zone = "Z01",
			pos = { 14, 0, 86 },
			ports = { { x = 4, z = 0, dir = "out" } },
			capacity = 12,
			regenSeconds = 4,
			infinite = true,
			extra = { size = { 8, 3, 8 } },
		},
		{
			id = "Z01_Plot_01",
			kind = "plot",
			zone = "Z01",
			pos = { -10, 0, 80 },
			extra = { size = { 4, 1, 4 }, preplant = "PL_DAISY" },
		},
		{ id = "Z01_Plot_02", kind = "plot", zone = "Z01", pos = { -16, 0, 80 }, extra = { size = { 4, 1, 4 } } },
		-- Yolun üstündəki ilk 3 yarpaq (bölmə 4)
		{ id = "Z01_Leaf_01", kind = "work", def = "W_LEAF", zone = "Z01", pos = { 0, 0, 80 } },
		{ id = "Z01_Leaf_02", kind = "work", def = "W_LEAF", zone = "Z01", pos = { -1, 0, 74 } },
		{ id = "Z01_Leaf_03", kind = "work", def = "W_LEAF", zone = "Z01", pos = { 1, 0, 68 } },
		{ id = "Z01_Leaf_04", kind = "work", def = "W_LEAF", zone = "Z01", pos = { -30, 0, 84 } },
		{ id = "Z01_Leaf_05", kind = "work", def = "W_LEAF", zone = "Z01", pos = { 20, 0, 77 } },
		{ id = "Z01_Leaf_06", kind = "work", def = "W_LEAF", zone = "Z01", pos = { -24, 0, 56 } },
		{ id = "Z01_Leaf_07", kind = "work", def = "W_LEAF", zone = "Z01", pos = { 10, 0, 46 } },
		-- Emalatxana dəhlizini bağlayan saplar
		{
			id = "Z01_Thread_01",
			kind = "work",
			def = "W_THREAD",
			zone = "Z01",
			pos = { 8, 0, 61 },
			blocksPath = true,
			extra = { barrier = { 2, 6, 8 } },
		},
		{
			id = "Z01_Thread_02",
			kind = "work",
			def = "W_THREAD",
			zone = "Z01",
			pos = { 14, 0, 61 },
			blocksPath = true,
			extra = { barrier = { 2, 6, 8 } },
		},
		{
			id = "Z01_Thread_03",
			kind = "work",
			def = "W_THREAD",
			zone = "Z01",
			pos = { 20, 0, 61 },
			blocksPath = true,
			extra = { barrier = { 2, 6, 8 } },
		},
		{ id = "Z01_Thread_04", kind = "work", def = "W_THREAD", zone = "Z01", pos = { -36, 0, 46 } },
		{ id = "Z01_Thread_05", kind = "work", def = "W_THREAD", zone = "Z01", pos = { 30, 0, 102 } },
		{ id = "Z01_Workbench", kind = "workbench", zone = "Z01", pos = { 36, 0, 62 }, extra = { size = { 8, 4, 5 } } },
		-- Budaqlar və daşlar
		{ id = "Z01_Branch_01", kind = "work", def = "W_BRANCH", zone = "Z01", pos = { -34, 0, 64 } },
		{ id = "Z01_Branch_02", kind = "work", def = "W_BRANCH", zone = "Z01", pos = { -20, 0, 70 } },
		{ id = "Z01_Branch_03", kind = "work", def = "W_BRANCH", zone = "Z01", pos = { 14, 0, 50 } },
		{ id = "Z01_Branch_04", kind = "work", def = "W_BRANCH", zone = "Z01", pos = { -40, 0, 92 } },
		{ id = "Z01_Stone_01", kind = "work", def = "W_STONE_LIGHT", zone = "Z01", pos = { -40, 0, 74 } },
		-- Qısa yol: emalatxana həyətinin cənub divarındakı keçid (əlavə iş S1_SHORTCUT)
		{
			id = "Z01_Stone_02",
			kind = "work",
			def = "W_STONE_LIGHT",
			zone = "Z01",
			pos = { 36, 0, 72 },
			blocksPath = true,
			extra = { barrier = { 4, 6, 2 } },
		},
		-- Quru çiçək yataqları (fəsil 1)
		{
			id = "Z01_Bed_01",
			kind = "consumer",
			def = "BED_DRY",
			zone = "Z01",
			pos = { 35, 0, 86 },
			ports = { { x = -5, z = 0, dir = "in" } },
		},
		{
			id = "Z01_Bed_02",
			kind = "consumer",
			def = "BED_DRY",
			zone = "Z01",
			pos = { -27, 0, 66 },
			ports = { { x = 5, z = 0, dir = "in" } },
		},
		{
			id = "Z01_Bed_03",
			kind = "consumer",
			def = "BED_DRY",
			zone = "Z01",
			pos = { -15, 0, 50 },
			ports = { { x = 5, z = 0, dir = "in" } },
		},
		-- Yenilənən mənbə yuvaları (bölmə 9): Z01-də yarpaq və nazik sap
		{ id = "Z01_Spot_Leaf_01", kind = "spot", zone = "Z01", pos = { -42, 0, 104 }, spawns = { "W_LEAF" } },
		{ id = "Z01_Spot_Leaf_02", kind = "spot", zone = "Z01", pos = { -44, 0, 58 }, spawns = { "W_LEAF" } },
		{ id = "Z01_Spot_Thread_01", kind = "spot", zone = "Z01", pos = { 42, 0, 104 }, spawns = { "W_THREAD" } },
		{ id = "Z01_Spot_Thread_02", kind = "spot", zone = "Z01", pos = { 24, 0, 46 }, spawns = { "W_THREAD" } },
		{ id = "Z01_Mem", kind = "memory", def = "MEM_BUTTON", zone = "Z01", pos = { -46, 0, 46 } },
		{ id = "Z01_Lamp_01", kind = "lamp", zone = "Z01", pos = { 6, 0, 70 }, extra = { chapter = 1 } },
		-- Qapılar
		{
			id = "GATE_Z02",
			kind = "gate",
			zone = "Z01",
			pos = { 50, 0, 77 },
			extra = { unlockZone = "Z02", size = { 2, 10, 12 } },
		},
		{
			id = "GATE_Z06",
			kind = "gate",
			zone = "Z01",
			pos = { 0, 0, 40 },
			extra = { unlockZone = "Z06", size = { 12, 12, 2 } },
		},
	},
	areas = {
		{ id = "A_Z01_LINE", zone = "Z01", origin = { 18, 0, 82 }, size = { 12, 8 } },
		{ id = "A_Z01_GARDEN", zone = "Z01", origin = { -48, 0, 96 }, size = { 22, 12 } },
		{ id = "A_Z01_EAST", zone = "Z01", origin = { 26, 0, 88 }, size = { 22, 18 } },
	},
	paths = {
		{ x0 = -3, z0 = 40, x1 = 3, z1 = 92 }, -- əsas cığır
		{ x0 = -24, z0 = 82, x1 = 10, z1 = 92 }, -- evin qabağı
		{ x0 = 3, z0 = 57, x1 = 24, z1 = 65 }, -- emalatxana dəhlizi
		{ x0 = 3, z0 = 74, x1 = 50, z1 = 80 }, -- Z02 qapısına cığır
		{ x0 = -50, z0 = 96, x1 = -26, z1 = 104 }, -- masa altı qısa yola çıxış
	},
	ground = {
		{ pos = { 0, -1, 75 }, size = { 100, 2, 70 } },
		-- Masa altı (zona deyil): X −130..−50, Z −40..110. Z01-dən qərb keçidi ilə açıqdır.
		{ pos = { -90, -1, 35 }, size = { 80, 2, 150 }, kind = "undertable" },
	},
	walls = {
		-- Xarici sərhədlər
		{ pos = { 0, 5, 110 }, size = { 100, 10, 2 } },
		{ pos = { -50, 5, 57 }, size = { 2, 10, 34 } }, -- qərb (Z 40..74)
		{ pos = { -50, 5, 85 }, size = { 2, 10, 22 } }, -- qərb (Z 74..96)
		{ pos = { -50, 5, 107 }, size = { 2, 10, 6 } }, -- qərb (Z 104..110)
		{ pos = { 50, 5, 55.5 }, size = { 2, 10, 31 } }, -- şərq (Z 40..71)
		{ pos = { 50, 5, 96.5 }, size = { 2, 10, 27 } }, -- şərq (Z 83..110)
		{ pos = { -28, 6, 40 }, size = { 44, 12, 2 } }, -- şimal (X −50..−6)
		{ pos = { 28, 6, 40 }, size = { 44, 12, 2 } }, -- şimal (X 6..50)
		-- Emalatxana dəhlizi və həyəti
		{ pos = { 13.5, 3, 57 }, size = { 21, 6, 1 } },
		{ pos = { 13.5, 3, 65 }, size = { 21, 6, 1 } },
		{ pos = { 24, 3, 53.5 }, size = { 1, 6, 7 } }, -- həyətin qərb divarı (Z 50..57)
		{ pos = { 24, 3, 68.5 }, size = { 1, 6, 7 } }, -- həyətin qərb divarı (Z 65..72)
		{ pos = { 35, 3, 50 }, size = { 22, 6, 1 } },
		{ pos = { 46, 3, 61 }, size = { 1, 6, 22 } },
		{ pos = { 29, 3, 72 }, size = { 10, 6, 1 } }, -- cənub (X 24..34)
		{ pos = { 42, 3, 72 }, size = { 8, 6, 1 } }, -- cənub (X 38..46)
		-- Masa altının xarici sərhədləri
		{ pos = { -130, 5, 35 }, size = { 2, 10, 150 } },
		{ pos = { -90, 5, 110 }, size = { 80, 10, 2 } },
	},
	props = {
		{ name = "NutHouse", pos = { 0, 7, 102 }, size = { 18, 14, 16 }, shape = "ball", color = { 142, 101, 74 } },
		{
			name = "Teaspoon",
			pos = { -36, 0.8, 76 },
			size = { 30, 1.5, 6 },
			shape = "block",
			color = { 190, 190, 200 },
			rot = 25,
		},
		{ name = "WorkshopShell", pos = { 36, 4, 56 }, size = { 18, 8, 10 }, shape = "ball", color = { 160, 115, 80 } },
		{ name = "ShopCrate", pos = { -22, 2.5, 96 }, size = { 10, 5, 6 }, shape = "block", color = { 170, 125, 85 } },
		-- Köhnə masanın ayaqları (Z05 masanın üstündədir)
		{ name = "TableLeg1", pos = { -126, 11, -32 }, size = { 4, 22, 4 }, shape = "block", color = { 120, 85, 60 } },
		{ name = "TableLeg2", pos = { -54, 11, -32 }, size = { 4, 22, 4 }, shape = "block", color = { 120, 85, 60 } },
		{ name = "TableLeg3", pos = { -126, 11, 56 }, size = { 4, 22, 4 }, shape = "block", color = { 120, 85, 60 } },
		{ name = "TableLeg4", pos = { -54, 11, 56 }, size = { 4, 22, 4 }, shape = "block", color = { 120, 85, 60 } },
	},
	water = {},
}

return layout
