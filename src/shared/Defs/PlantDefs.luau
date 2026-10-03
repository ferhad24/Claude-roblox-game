--!strict
-- Bitkilər (bölmə 13). Böyümə yalnız aktiv oyun vaxtında və rütubət ≥ 25 olanda gedir.
local Types = require(script.Parent.Parent.Types)

type PlantDef = Types.PlantDef

local list: { PlantDef } = {
	{
		id = "PL_DAISY",
		nameKey = "plant.PL_DAISY",
		seedId = "SEED_DAISY",
		seedPrice = 8,
		growSeconds = 90,
		yield = { { id = "MAT_PETAL", n = 2 } },
		zone = "Z01",
		unlock = { kind = "always" },
		color = { 250, 250, 240 },
	},
	{
		id = "PL_CLOVER",
		nameKey = "plant.PL_CLOVER",
		seedId = "SEED_CLOVER",
		seedPrice = 12,
		growSeconds = 120,
		yield = { { id = "MAT_FIBER", n = 3 } },
		zone = "Z02",
		unlock = { kind = "zone", zone = "Z02" },
		color = { 120, 180, 110 },
	},
	{
		id = "PL_MOSS",
		nameKey = "plant.PL_MOSS",
		seedId = "SEED_MOSS",
		seedPrice = 16,
		growSeconds = 150,
		yield = { { id = "MAT_FIBER", n = 2 }, { id = "MAT_PETAL", n = 1 } },
		zone = "Z03",
		unlock = { kind = "zone", zone = "Z03" },
		color = { 100, 150, 100 },
	},
	{
		id = "PL_MARIGOLD",
		nameKey = "plant.PL_MARIGOLD",
		seedId = "SEED_MARIGOLD",
		seedPrice = 20,
		growSeconds = 180,
		yield = { { id = "MAT_PETAL", n = 4 } },
		zone = "Z04",
		unlock = { kind = "zone", zone = "Z04" },
		color = { 240, 150, 50 },
	},
	{
		id = "PL_LAVENDER",
		nameKey = "plant.PL_LAVENDER",
		seedId = "SEED_LAVENDER",
		seedPrice = 24,
		growSeconds = 210,
		yield = { { id = "MAT_PETAL", n = 5 } },
		zone = "Z05",
		unlock = { kind = "zone", zone = "Z05" },
		color = { 169, 149, 207 },
	},
	{
		id = "PL_STAR",
		nameKey = "plant.PL_STAR",
		seedId = "SEED_STAR",
		seedPrice = 30,
		growSeconds = 240,
		yield = { { id = "MAT_PETAL", n = 6 } },
		zone = "Z06",
		unlock = { kind = "final" },
		color = { 255, 240, 160 },
	},
}

local byId: { [string]: PlantDef } = {}
local bySeed: { [string]: PlantDef } = {}
for _, def in list do
	byId[def.id] = def
	bySeed[def.seedId] = def
end

return {
	list = list,
	byId = byId,
	bySeed = bySeed,
}
