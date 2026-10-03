--!strict
-- Əsas tapşırıq zənciri (bölmə 15), sahə əlavə işləri (bölmə 5), təkrar sifarişlər (bölmə 14)
-- və nailiyyətlər (bölmə 16).
local Types = require(script.Parent.Parent.Types)

type ChapterDef = Types.ChapterDef
type SideTaskDef = Types.SideTaskDef
type OrderDef = Types.OrderDef
type AchievementDef = Types.AchievementDef

local chapters: { ChapterDef } = {
	{
		chapter = 1,
		zone = "Z01",
		titleKey = "chapter.1",
		reward = { coins = 150, xp = 100, badge = "BADGE_TREE_1" },
		steps = {
			{
				id = "Q1_LEAVES",
				textKey = "step.Q1_LEAVES",
				objective = { type = "restore", ids = { "Z01_Leaf_01", "Z01_Leaf_02", "Z01_Leaf_03" } },
				marker = "Z01_Leaf_01",
			},
			{ id = "Q1_FILL", textKey = "step.Q1_FILL", objective = { type = "fillCup" }, marker = "Z01_DewBowl" },
			{
				id = "Q1_SEED",
				textKey = "step.Q1_SEED",
				objective = { type = "water", id = "Z01_Plot_01" },
				marker = "Z01_Plot_01",
				-- "İlk çiçəyin suvarılması ayrıca tutorial bonusu olaraq 100 XP verir" (bölmə 4)
				bonus = { xp = 100 },
			},
			{
				id = "Q1_SHEARS",
				textKey = "step.Q1_SHEARS",
				objective = { type = "ownTool", tool = "TOOL_SHEARS_1" },
				marker = "Z01_Shop",
			},
			{
				id = "Q1_THREADS",
				textKey = "step.Q1_THREADS",
				objective = { type = "restore", ids = { "Z01_Thread_01", "Z01_Thread_02", "Z01_Thread_03" } },
				marker = "Z01_Thread_01",
			},
			{
				id = "Q1_WORKSHOP",
				textKey = "step.Q1_WORKSHOP",
				objective = { type = "interact", id = "Z01_Workbench" },
				marker = "Z01_Workbench",
				-- "Emalatxana təlimi pulsuz 2 hazır kanal hissəsi verir" (bölmə 4)
				bonus = { builds = { { id = "B_CHANNEL", n = 2 } } },
				unlockGroup = "G_Z01",
			},
			{
				id = "Q1_ROPE",
				textKey = "step.Q1_ROPE",
				objective = { type = "crafted", item = "MAT_ROPE", count = 1 },
				marker = "Z01_Workbench",
			},
			{
				id = "Q1_SAW",
				textKey = "step.Q1_SAW",
				objective = { type = "ownTool", tool = "TOOL_SAW_1" },
				marker = "Z01_Shop",
			},
			{
				id = "Q1_PLANKS",
				textKey = "step.Q1_PLANKS",
				objective = { type = "crafted", item = "MAT_PLANK", count = 4 },
				marker = "Z01_Branch_01",
			},
			{
				id = "Q1_WHEEL",
				textKey = "step.Q1_WHEEL",
				objective = { type = "crafted", item = "B_WHEEL", count = 1 },
				marker = "Z01_Stone_01",
			},
			{
				id = "Q1_PLACE_WHEEL",
				textKey = "step.Q1_PLACE_WHEEL",
				objective = { type = "buildAtPort", build = "B_WHEEL", node = "Z01_DewBowl" },
				marker = "Z01_DewBowl",
			},
			{
				id = "Q1_LINE",
				textKey = "step.Q1_LINE",
				objective = { type = "lineConnected", target = "Z01_Bed_01" },
				marker = "Z01_Bed_01",
			},
			{
				id = "Q1_BEDS",
				textKey = "step.Q1_BEDS",
				objective = { type = "restore", ids = { "Z01_Bed_01", "Z01_Bed_02", "Z01_Bed_03" } },
				marker = "Z01_Bed_02",
			},
		},
	},
	{
		chapter = 2,
		zone = "Z02",
		titleKey = "chapter.2",
		reward = { coins = 250, xp = 180, badge = "BADGE_TREE_2" },
		steps = {
			{
				id = "Q2_MASTER",
				textKey = "step.Q2_MASTER",
				objective = { type = "interact", id = "NPC_CIRT_Z02" },
				marker = "NPC_CIRT_Z02",
			},
			{
				id = "Q2_KEY",
				textKey = "step.Q2_KEY",
				objective = { type = "key", group = "G_Z02" },
				marker = "Z01_Workbench",
			},
			{
				id = "Q2_CATCHER",
				textKey = "step.Q2_CATCHER",
				objective = { type = "placed", build = "B_CATCHER", count = 1, zone = "Z02" },
				marker = "Z02_Spot_Resin_01",
			},
			{
				id = "Q2_WHEEL_LINE",
				textKey = "step.Q2_WHEEL_LINE",
				objective = { type = "lineConnected", target = "Z02_BloomBed_01", via = { "B_WHEEL" } },
				marker = "Z02_BloomBed_01",
			},
			{
				id = "Q2_BEDS",
				textKey = "step.Q2_BEDS",
				objective = { type = "restore", ids = { "Z02_Bed_01", "Z02_Bed_02", "Z02_Bed_03", "Z02_BloomBed_01" } },
				marker = "Z02_Bed_01",
			},
			{
				id = "Q2_BRIDGE",
				textKey = "step.Q2_BRIDGE",
				objective = { type = "socket", id = "Z02_BridgeSocket" },
				marker = "Z02_BridgeSocket",
			},
		},
	},
	{
		chapter = 3,
		zone = "Z03",
		titleKey = "chapter.3",
		reward = { coins = 350, xp = 250, badge = "BADGE_TREE_3" },
		steps = {
			{
				id = "Q3_PASSAGES",
				textKey = "step.Q3_PASSAGES",
				objective = { type = "restore", ids = { "Z03_Soil_01", "Z03_Soil_02", "Z03_Soil_03" } },
				marker = "Z03_Soil_01",
			},
			{
				id = "Q3_CART",
				textKey = "step.Q3_CART",
				objective = { type = "ownTool", tool = "TOOL_CART_1" },
				marker = "Z01_Shop",
			},
			{
				id = "Q3_CARGO",
				textKey = "step.Q3_CARGO",
				objective = { type = "cargo", target = "Z03_PotCrack", count = 3 },
				marker = "Z03_Shard_01",
			},
			{
				id = "Q3_NARGIZ",
				textKey = "step.Q3_NARGIZ",
				objective = { type = "interact", id = "NPC_NARGIZ_Z03" },
				marker = "NPC_NARGIZ_Z03",
				-- "Nərgiz 2 kompost verir" (bölmə 11)
				bonus = { items = { { id = "MAT_COMPOST", n = 2 } }, seeds = { { id = "SEED_MOSS", n = 1 } } },
			},
			{
				id = "Q3_KEY",
				textKey = "step.Q3_KEY",
				objective = { type = "key", group = "G_Z03" },
				marker = "Z01_Workbench",
			},
			{
				id = "Q3_PLANTERS",
				textKey = "step.Q3_PLANTERS",
				objective = { type = "workingPlanters", count = 3 },
				marker = "NPC_NARGIZ_Z03",
			},
			{
				id = "Q3_POTLINE",
				textKey = "step.Q3_POTLINE",
				objective = { type = "restore", ids = { "Z03_PotBasin", "Z03_BloomBed_01" } },
				marker = "Z03_PotBasin",
			},
		},
	},
	{
		chapter = 4,
		zone = "Z04",
		titleKey = "chapter.4",
		reward = { coins = 450, xp = 350, badge = "BADGE_TREE_4" },
		steps = {
			{
				id = "Q4_LEVER",
				textKey = "step.Q4_LEVER",
				objective = { type = "ownTool", tool = "TOOL_LEVER_1" },
				marker = "Z01_Shop",
			},
			{
				id = "Q4_STONES",
				textKey = "step.Q4_STONES",
				objective = {
					type = "restore",
					ids = { "Z04_Heavy_01", "Z04_Heavy_02", "Z04_Heavy_03", "Z04_Heavy_04" },
				},
				marker = "Z04_Heavy_01",
			},
			{
				id = "Q4_MECH",
				textKey = "step.Q4_MECH",
				objective = { type = "interact", id = "NPC_CIRT_Z04" },
				marker = "NPC_CIRT_Z04",
			},
			{
				id = "Q4_KEY",
				textKey = "step.Q4_KEY",
				objective = { type = "key", group = "G_Z04" },
				marker = "Z01_Workbench",
			},
			{
				id = "Q4_GEARS",
				textKey = "step.Q4_GEARS",
				objective = { type = "crafted", item = "MAT_GEAR", count = 2 },
				marker = "Z01_Workbench",
			},
			{
				id = "Q4_BLOOM",
				textKey = "step.Q4_BLOOM",
				objective = { type = "restore", ids = { "Z04_BloomBed_01" } },
				marker = "Z04_BloomBed_01",
			},
			{
				id = "Q4_LIFT",
				textKey = "step.Q4_LIFT",
				objective = { type = "socket", id = "Z04_LiftSocket" },
				marker = "Z04_LiftSocket",
			},
		},
	},
	{
		chapter = 5,
		zone = "Z05",
		titleKey = "chapter.5",
		reward = { coins = 550, xp = 450, badge = "BADGE_TREE_5" },
		steps = {
			{
				id = "Q5_BRUSH",
				textKey = "step.Q5_BRUSH",
				objective = { type = "ownTool", tool = "TOOL_BRUSH_1" },
				marker = "Z01_Shop",
			},
			{
				id = "Q5_PANELS",
				textKey = "step.Q5_PANELS",
				objective = {
					type = "restore",
					ids = { "Z05_Panel_01", "Z05_Panel_02", "Z05_Panel_03", "Z05_Panel_04" },
				},
				marker = "Z05_Panel_01",
			},
			{
				id = "Q5_PUMPTALK",
				textKey = "step.Q5_PUMPTALK",
				objective = { type = "interact", id = "NPC_CIRT_Z05" },
				marker = "NPC_CIRT_Z05",
			},
			{
				id = "Q5_KEY",
				textKey = "step.Q5_KEY",
				objective = { type = "key", group = "G_Z05" },
				marker = "Z01_Workbench",
			},
			{
				id = "Q5_PUMP",
				textKey = "step.Q5_PUMP",
				objective = { type = "lineConnected", target = "Z05_BloomBed_02", via = { "B_PUMP" } },
				marker = "Z05_BloomBed_02",
			},
			{
				id = "Q5_PLANTERS",
				textKey = "step.Q5_PLANTERS",
				objective = { type = "workingPlanters", count = 3, zone = "Z05" },
				marker = "Z05_Gutter",
			},
			{
				id = "Q5_FLOWER",
				textKey = "step.Q5_FLOWER",
				objective = { type = "restore", ids = { "Z05_BloomBed_01", "Z05_BloomBed_02" } },
				marker = "Z05_BloomBed_01",
			},
		},
	},
	{
		chapter = 6,
		zone = "Z06",
		titleKey = "chapter.6",
		reward = { coins = 700, xp = 650 },
		steps = {
			{
				id = "Q6_SHEARS",
				textKey = "step.Q6_SHEARS",
				objective = { type = "ownTool", tool = "TOOL_SHEARS_2" },
				marker = "Z01_Shop",
			},
			{
				id = "Q6_KNOTS",
				textKey = "step.Q6_KNOTS",
				objective = {
					type = "restore",
					ids = { "Z06_Knot_01", "Z06_Knot_02", "Z06_Knot_03", "Z06_Knot_04", "Z06_Knot_05" },
				},
				marker = "Z06_Knot_01",
			},
			{
				id = "Q6_ROOTS",
				textKey = "step.Q6_ROOTS",
				objective = {
					type = "restore",
					ids = { "Z06_Root_01", "Z06_Root_02", "Z06_Root_03", "Z06_Root_04", "Z06_Root_05" },
				},
				marker = "Z06_Root_01",
			},
			{
				id = "Q6_ESSENCE",
				textKey = "step.Q6_ESSENCE",
				objective = { type = "essences", count = 5 },
				marker = "Z06_Tree",
			},
			{
				id = "Q6_CROWN",
				textKey = "step.Q6_CROWN",
				objective = { type = "restore", ids = { "Z06_Crown" } },
				marker = "Z06_Crown",
			},
			{ id = "Q6_WAKE", textKey = "step.Q6_WAKE", objective = { type = "wake" }, marker = "Z06_Tree" },
		},
	},
}

local sideTasks: { SideTaskDef } = {
	{
		id = "S1_MEMORY",
		zone = "Z01",
		textKey = "side.S1_MEMORY",
		objective = { type = "memory", id = "MEM_BUTTON" },
		reward = { coins = 25, xp = 30 },
	},
	{
		id = "S1_SHORTCUT",
		zone = "Z01",
		textKey = "side.S1_SHORTCUT",
		objective = { type = "restore", ids = { "Z01_Stone_02" } },
		reward = { coins = 25, xp = 30 },
		marker = "Z01_Stone_02",
	},
	{
		id = "S1_DAISY",
		zone = "Z01",
		textKey = "side.S1_DAISY",
		objective = { type = "harvested", species = "PL_DAISY", count = 1 },
		reward = { coins = 25, xp = 30 },
		marker = "Z01_Plot_01",
	},
	{
		id = "S2_MEMORY",
		zone = "Z02",
		textKey = "side.S2_MEMORY",
		objective = { type = "memory", id = "MEM_BEAD" },
		reward = { coins = 40, xp = 60 },
	},
	{
		id = "S2_SHORTCUT",
		zone = "Z02",
		textKey = "side.S2_SHORTCUT",
		objective = { type = "restore", ids = { "Z02_Branch_05" } },
		reward = { coins = 40, xp = 60 },
		marker = "Z02_Branch_05",
	},
	{
		id = "S2_CLOVER",
		zone = "Z02",
		textKey = "side.S2_CLOVER",
		objective = { type = "harvested", species = "PL_CLOVER", count = 1 },
		reward = { coins = 40, xp = 60 },
		marker = "Z02_Plot_01",
	},
	{
		id = "S3_MEMORY",
		zone = "Z03",
		textKey = "side.S3_MEMORY",
		objective = { type = "memory", id = "MEM_KEY" },
		reward = { coins = 50, xp = 80 },
	},
	{
		id = "S3_SHORTCUT",
		zone = "Z03",
		textKey = "side.S3_SHORTCUT",
		objective = { type = "restore", ids = { "Z03_Soil_04" } },
		reward = { coins = 50, xp = 80 },
		marker = "Z03_Soil_04",
	},
	{
		id = "S3_MOSS",
		zone = "Z03",
		textKey = "side.S3_MOSS",
		objective = { type = "harvested", species = "PL_MOSS", count = 1 },
		reward = { coins = 50, xp = 80 },
	},
	{
		id = "S4_MEMORY",
		zone = "Z04",
		textKey = "side.S4_MEMORY",
		objective = { type = "memory", id = "MEM_CHINA" },
		reward = { coins = 60, xp = 100 },
	},
	{
		id = "S4_SHORTCUT",
		zone = "Z04",
		textKey = "side.S4_SHORTCUT",
		objective = { type = "restore", ids = { "Z04_Heavy_05" } },
		reward = { coins = 60, xp = 100 },
		marker = "Z04_Heavy_05",
	},
	{
		id = "S4_MARIGOLD",
		zone = "Z04",
		textKey = "side.S4_MARIGOLD",
		objective = { type = "harvested", species = "PL_MARIGOLD", count = 1 },
		reward = { coins = 60, xp = 100 },
		marker = "Z04_Plot_01",
	},
	{
		id = "S5_MEMORY",
		zone = "Z05",
		textKey = "side.S5_MEMORY",
		objective = { type = "memory", id = "MEM_ORB" },
		reward = { coins = 70, xp = 120 },
	},
	{
		id = "S5_LAMP",
		zone = "Z05",
		textKey = "side.S5_LAMP",
		objective = { type = "placed", build = "B_LAMP", count = 1, zone = "Z05" },
		reward = { coins = 70, xp = 120 },
	},
	{
		id = "S5_LAVENDER",
		zone = "Z05",
		textKey = "side.S5_LAVENDER",
		objective = { type = "harvested", species = "PL_LAVENDER", count = 1 },
		reward = { coins = 70, xp = 120 },
	},
	{
		id = "S6_MEMORY",
		zone = "Z06",
		textKey = "side.S6_MEMORY",
		objective = { type = "memory", id = "MEM_HEART" },
		reward = { coins = 80, xp = 150 },
	},
	{
		id = "S6_STAR",
		zone = "Z06",
		textKey = "side.S6_STAR",
		objective = { type = "harvested", species = "PL_STAR", count = 1 },
		reward = { coins = 80, xp = 150 },
	},
	{
		id = "S6_ARCH",
		zone = "Z06",
		textKey = "side.S6_ARCH",
		objective = { type = "placed", build = "B_FLOWERARCH", count = 1 },
		reward = { coins = 80, xp = 150 },
	},
}

-- Nümunələr sənəddəndir: 8 lif → 16/20, 4 budaq → 20/25, 6 ləçək → 24/30. Qalanları eyni nisbətlə əlavə edilib.
local orders: { OrderDef } = {
	{
		id = "O_FIBER8",
		wants = { id = "MAT_FIBER", n = 8 },
		coins = 16,
		xp = 20,
		unlock = { kind = "step", step = "Q1_WORKSHOP" },
	},
	{
		id = "O_TWIG4",
		wants = { id = "MAT_TWIG", n = 4 },
		coins = 20,
		xp = 25,
		unlock = { kind = "step", step = "Q1_SAW" },
	},
	{
		id = "O_PETAL6",
		wants = { id = "MAT_PETAL", n = 6 },
		coins = 24,
		xp = 30,
		unlock = { kind = "step", step = "Q1_WORKSHOP" },
	},
	{
		id = "O_PEBBLE4",
		wants = { id = "MAT_PEBBLE", n = 4 },
		coins = 22,
		xp = 28,
		unlock = { kind = "zone", zone = "Z02" },
	},
	{
		id = "O_RESIN3",
		wants = { id = "MAT_RESIN", n = 3 },
		coins = 18,
		xp = 24,
		unlock = { kind = "zone", zone = "Z02" },
	},
	{
		id = "O_PLANK3",
		wants = { id = "MAT_PLANK", n = 3 },
		coins = 26,
		xp = 32,
		unlock = { kind = "zone", zone = "Z02" },
	},
	{
		id = "O_CLAY4",
		wants = { id = "MAT_CLAY", n = 4 },
		coins = 24,
		xp = 30,
		unlock = { kind = "zone", zone = "Z03" },
	},
	{
		id = "O_ROPE2",
		wants = { id = "MAT_ROPE", n = 2 },
		coins = 26,
		xp = 34,
		unlock = { kind = "zone", zone = "Z03" },
	},
	{
		id = "O_METAL3",
		wants = { id = "MAT_METAL", n = 3 },
		coins = 26,
		xp = 34,
		unlock = { kind = "zone", zone = "Z03" },
	},
	{
		id = "O_COMPOST2",
		wants = { id = "MAT_COMPOST", n = 2 },
		coins = 28,
		xp = 36,
		unlock = { kind = "zone", zone = "Z04" },
	},
	{
		id = "O_GLASS3",
		wants = { id = "MAT_GLASS", n = 3 },
		coins = 28,
		xp = 36,
		unlock = { kind = "zone", zone = "Z05" },
	},
	{
		id = "O_SEAL2",
		wants = { id = "MAT_SEAL", n = 2 },
		coins = 30,
		xp = 40,
		unlock = { kind = "zone", zone = "Z05" },
	},
}

local achievements: { AchievementDef } = {
	{ id = "ACH_FIRST_SPROUT", nameKey = "ach.ACH_FIRST_SPROUT", coins = 10 },
	{ id = "ACH_FIRST_LINE", nameKey = "ach.ACH_FIRST_LINE", coins = 10 },
	{ id = "ACH_NUT_HOUSE", nameKey = "ach.ACH_NUT_HOUSE", coins = 15 },
	{ id = "ACH_BRIDGE", nameKey = "ach.ACH_BRIDGE", coins = 15 },
	{ id = "ACH_HEAVY_LOAD", nameKey = "ach.ACH_HEAVY_LOAD", coins = 15 },
	{ id = "ACH_GREENHOUSE", nameKey = "ach.ACH_GREENHOUSE", coins = 20 },
	{ id = "ACH_FIVE_BADGES", nameKey = "ach.ACH_FIVE_BADGES", coins = 20 },
	{ id = "ACH_TREE_AWAKE", nameKey = "ach.ACH_TREE_AWAKE", coins = 0 },
	{ id = "ACH_SIX_MEMORIES", nameKey = "ach.ACH_SIX_MEMORIES", coins = 25 },
	{ id = "ACH_GARDEN_MASTER", nameKey = "ach.ACH_GARDEN_MASTER", coins = 0 },
}

local stepById: { [string]: Types.QuestStep } = {}
local stepChapter: { [string]: number } = {}
local stepIndex: { [string]: number } = {}
for _, ch in chapters do
	for i, step in ch.steps do
		stepById[step.id] = step
		stepChapter[step.id] = ch.chapter
		stepIndex[step.id] = i
	end
end
local sideById: { [string]: SideTaskDef } = {}
for _, s in sideTasks do
	sideById[s.id] = s
end
local orderById: { [string]: OrderDef } = {}
for _, o in orders do
	orderById[o.id] = o
end
local achievementById: { [string]: AchievementDef } = {}
for _, a in achievements do
	achievementById[a.id] = a
end

return {
	chapters = chapters,
	stepById = stepById,
	stepChapter = stepChapter,
	stepIndex = stepIndex,
	sideTasks = sideTasks,
	sideById = sideById,
	orders = orders,
	orderById = orderById,
	achievements = achievements,
	achievementById = achievementById,
	-- Hər bir xüsusi yataqdan bir dəfə MAT_BLOOM alınır (bölmə 9)
	bloomSources = { "Z02_BloomBed_01", "Z03_BloomBed_01", "Z04_BloomBed_01", "Z05_BloomBed_01", "Z05_BloomBed_02" },
}
