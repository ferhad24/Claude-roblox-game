--!strict
-- Reseptlər və resept qrupları (bölmə 11).
-- Məcburi açar qiymətləri: Z02 150, Z03 200, Z04 300, Z05 415. Z01 qrupu pulsuz açılır.
local Types = require(script.Parent.Parent.Types)

type RecipeDef = Types.RecipeDef
type RecipeGroupDef = Types.RecipeGroupDef

local recipes: { RecipeDef } = {
	-- Ara materiallar
	{
		id = "C_ROPE",
		nameKey = "recipe.C_ROPE",
		group = "G_Z01",
		inputs = { { id = "MAT_FIBER", n = 4 }, { id = "MAT_THREAD", n = 1 } },
		output = { id = "MAT_ROPE", n = 1 },
	},
	{
		id = "C_PLANK",
		nameKey = "recipe.C_PLANK",
		group = "G_Z01",
		inputs = { { id = "MAT_TWIG", n = 2 } },
		output = { id = "MAT_PLANK", n = 1 },
	},
	{
		id = "C_SEAL",
		nameKey = "recipe.C_SEAL",
		group = "G_Z02",
		inputs = { { id = "MAT_RESIN", n = 2 }, { id = "MAT_FIBER", n = 1 } },
		output = { id = "MAT_SEAL", n = 1 },
	},
	{
		id = "C_GEAR",
		nameKey = "recipe.C_GEAR",
		group = "G_Z04",
		inputs = { { id = "MAT_METAL", n = 2 }, { id = "MAT_PEBBLE", n = 1 } },
		output = { id = "MAT_GEAR", n = 1 },
	},
	-- Qurğular
	{
		id = "R_CHANNEL",
		nameKey = "build.B_CHANNEL",
		group = "G_Z02",
		inputs = { { id = "MAT_PLANK", n = 2 }, { id = "MAT_SEAL", n = 1 } },
		output = { id = "B_CHANNEL", n = 1 },
	},
	{
		id = "R_WHEEL",
		nameKey = "build.B_WHEEL",
		group = "G_Z01",
		inputs = { { id = "MAT_PLANK", n = 4 }, { id = "MAT_PEBBLE", n = 2 }, { id = "MAT_ROPE", n = 1 } },
		output = { id = "B_WHEEL", n = 1 },
	},
	{
		id = "R_CATCHER",
		nameKey = "build.B_CATCHER",
		group = "G_Z02",
		inputs = { { id = "MAT_PLANK", n = 3 }, { id = "MAT_FIBER", n = 2 }, { id = "MAT_SEAL", n = 1 } },
		output = { id = "B_CATCHER", n = 1 },
	},
	{
		id = "R_BRIDGE",
		nameKey = "build.B_BRIDGE",
		group = "G_Z02",
		inputs = { { id = "MAT_PLANK", n = 6 }, { id = "MAT_ROPE", n = 3 } },
		output = { id = "B_BRIDGE", n = 1 },
	},
	{
		id = "R_LIFT",
		nameKey = "build.B_LIFT",
		group = "G_Z04",
		inputs = { { id = "MAT_PLANK", n = 8 }, { id = "MAT_ROPE", n = 4 }, { id = "MAT_GEAR", n = 2 } },
		output = { id = "B_LIFT", n = 1 },
	},
	{
		id = "R_PUMP",
		nameKey = "build.B_PUMP",
		group = "G_Z05",
		inputs = { { id = "MAT_METAL", n = 4 }, { id = "MAT_GEAR", n = 2 }, { id = "MAT_SEAL", n = 2 } },
		output = { id = "B_PUMP", n = 1 },
	},
	{
		id = "R_TANK",
		nameKey = "build.B_TANK",
		group = "G_Z05",
		inputs = { { id = "MAT_CLAY", n = 4 }, { id = "MAT_SEAL", n = 3 } },
		output = { id = "B_TANK", n = 1 },
	},
	{
		id = "R_PLANTER",
		nameKey = "build.B_PLANTER",
		group = "G_Z03",
		inputs = { { id = "MAT_CLAY", n = 4 }, { id = "MAT_COMPOST", n = 2 } },
		output = { id = "B_PLANTER", n = 1 },
	},
	{
		id = "R_COMPOST",
		nameKey = "build.B_COMPOST",
		group = "G_Z03",
		inputs = { { id = "MAT_PLANK", n = 4 }, { id = "MAT_FIBER", n = 2 } },
		output = { id = "B_COMPOST", n = 1 },
	},
	{
		id = "R_LAMP",
		nameKey = "build.B_LAMP",
		group = "G_Z05",
		inputs = { { id = "MAT_GLASS", n = 2 }, { id = "MAT_RESIN", n = 1 }, { id = "MAT_FIBER", n = 2 } },
		output = { id = "B_LAMP", n = 1 },
	},
	{
		id = "R_SORTER",
		nameKey = "build.B_SORTER",
		group = "G_Z05",
		inputs = { { id = "MAT_PLANK", n = 5 }, { id = "MAT_GEAR", n = 1 } },
		output = { id = "B_SORTER", n = 1 },
	},
	{
		id = "R_SPRINKLER",
		nameKey = "build.B_SPRINKLER",
		group = "G_Z05",
		inputs = { { id = "MAT_METAL", n = 2 }, { id = "MAT_SEAL", n = 2 }, { id = "MAT_GEAR", n = 1 } },
		output = { id = "B_SPRINKLER", n = 1 },
	},
	{
		id = "R_BENCH",
		nameKey = "build.B_BENCH",
		group = "G_FINAL",
		inputs = { { id = "MAT_PLANK", n = 3 }, { id = "MAT_FIBER", n = 2 } },
		output = { id = "B_BENCH", n = 1 },
	},
	{
		id = "R_FLOWERARCH",
		nameKey = "build.B_FLOWERARCH",
		group = "G_FINAL",
		inputs = { { id = "MAT_PLANK", n = 6 }, { id = "MAT_ROPE", n = 4 }, { id = "MAT_PETAL", n = 8 } },
		output = { id = "B_FLOWERARCH", n = 1 },
	},
}

local groups: { RecipeGroupDef } = {
	{
		id = "G_Z01",
		nameKey = "group.G_Z01",
		zone = "Z01",
		keyPrice = 0,
		unlock = { kind = "step", step = "Q1_WORKSHOP" },
		free = true,
		recipes = { "C_ROPE", "C_PLANK", "R_WHEEL" },
	},
	{
		id = "G_Z02",
		nameKey = "group.G_Z02",
		zone = "Z02",
		keyPrice = 150,
		unlock = { kind = "step", step = "Q2_MASTER" },
		free = false,
		recipes = { "C_SEAL", "R_CHANNEL", "R_CATCHER", "R_BRIDGE" },
	},
	{
		id = "G_Z03",
		nameKey = "group.G_Z03",
		zone = "Z03",
		keyPrice = 200,
		unlock = { kind = "step", step = "Q3_NARGIZ" },
		free = false,
		recipes = { "R_COMPOST", "R_PLANTER" },
	},
	{
		id = "G_Z04",
		nameKey = "group.G_Z04",
		zone = "Z04",
		keyPrice = 300,
		unlock = { kind = "step", step = "Q4_MECH" },
		free = false,
		recipes = { "C_GEAR", "R_LIFT" },
	},
	{
		id = "G_Z05",
		nameKey = "group.G_Z05",
		zone = "Z05",
		keyPrice = 415,
		unlock = { kind = "step", step = "Q5_PUMPTALK" },
		free = false,
		recipes = { "R_PUMP", "R_TANK", "R_LAMP", "R_SORTER", "R_SPRINKLER" },
	},
	{
		id = "G_FINAL",
		nameKey = "group.G_FINAL",
		zone = "Z06",
		keyPrice = 0,
		unlock = { kind = "final" },
		free = true,
		recipes = { "R_BENCH", "R_FLOWERARCH" },
	},
}

local byId: { [string]: RecipeDef } = {}
for _, def in recipes do
	byId[def.id] = def
end
local groupById: { [string]: RecipeGroupDef } = {}
for _, def in groups do
	groupById[def.id] = def
end

return {
	list = recipes,
	byId = byId,
	groups = groups,
	groupById = groupById,
}
