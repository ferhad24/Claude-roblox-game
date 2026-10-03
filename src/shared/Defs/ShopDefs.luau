--!strict
-- Dükan: çanta yüksəlişləri və dekorlar (bölmə 10, 14, 16).
-- Alətlər ToolDefs-dən, toxumlar PlantDefs-dən, resept açarları RecipeDefs-dən gəlir.
local Types = require(script.Parent.Parent.Types)

type Condition = Types.Condition
type DecorDef = Types.DecorDef

export type BagUpgrade = {
	id: string,
	nameKey: string,
	price: number,
	capacity: number,
	requires: number,
	unlock: Condition,
	mandatory: boolean,
}

local bagUpgrades: { BagUpgrade } = {
	{
		id = "BAG_24",
		nameKey = "shop.BAG_24",
		price = 80,
		capacity = 24,
		requires = 12,
		unlock = { kind = "step", step = "Q1_WORKSHOP" },
		mandatory = true,
	},
	{
		id = "BAG_36",
		nameKey = "shop.BAG_36",
		price = 240,
		capacity = 36,
		requires = 24,
		unlock = { kind = "zone", zone = "Z03" },
		mandatory = true,
	},
}

-- Dekorların qiymətləri sənəddə verilmiş sıradadır: 25, 30, 45, 35, 60, 50, 40, 80, 0.
-- Bağ ustası nişanı satılmır — final mükafatıdır.
local decor: { DecorDef } = {
	{
		id = "D_LEAF_RUG",
		nameKey = "build.D_LEAF_RUG",
		price = 25,
		unlock = { kind = "chapter", chapter = 1 },
		footprint = { 6, 4 },
		color = { 111, 166, 106 },
	},
	{
		id = "D_PEBBLE_PATH",
		nameKey = "build.D_PEBBLE_PATH",
		price = 30,
		unlock = { kind = "chapter", chapter = 1 },
		footprint = { 4, 4 },
		color = { 170, 170, 160 },
	},
	{
		id = "D_MUSHROOM_SEAT",
		nameKey = "build.D_MUSHROOM_SEAT",
		price = 45,
		unlock = { kind = "chapter", chapter = 1 },
		footprint = { 2, 2 },
		color = { 220, 120, 80 },
	},
	{
		id = "D_THREAD_FLAGS",
		nameKey = "build.D_THREAD_FLAGS",
		price = 35,
		unlock = { kind = "chapter", chapter = 1 },
		footprint = { 6, 2 },
		color = { 244, 231, 207 },
	},
	{
		id = "D_NUT_TABLE",
		nameKey = "build.D_NUT_TABLE",
		price = 60,
		unlock = { kind = "chapter", chapter = 1 },
		footprint = { 4, 4 },
		color = { 142, 101, 74 },
	},
	{
		id = "D_MAILBOX",
		nameKey = "build.D_MAILBOX",
		price = 50,
		unlock = { kind = "chapter", chapter = 1 },
		footprint = { 2, 2 },
		color = { 200, 80, 70 },
	},
	{
		id = "D_SEED_BOARD",
		nameKey = "build.D_SEED_BOARD",
		price = 40,
		unlock = { kind = "chapter", chapter = 1 },
		footprint = { 4, 2 },
		color = { 170, 125, 85 },
	},
	{
		id = "D_BUTTERFLY_BOARD",
		nameKey = "build.D_BUTTERFLY_BOARD",
		price = 80,
		unlock = { kind = "chapter", chapter = 3 },
		footprint = { 4, 2 },
		color = { 169, 149, 207 },
	},
	{
		id = "D_MASTER_BADGE",
		nameKey = "build.D_MASTER_BADGE",
		price = 0,
		unlock = { kind = "final" },
		footprint = { 2, 2 },
		color = { 237, 200, 109 },
	},
}

local decorById: { [string]: DecorDef } = {}
for _, def in decor do
	decorById[def.id] = def
end
local bagById: { [string]: BagUpgrade } = {}
for _, def in bagUpgrades do
	bagById[def.id] = def
end

return {
	bagUpgrades = bagUpgrades,
	bagById = bagById,
	decor = decor,
	decorById = decorById,
	-- Final mükafatı: satılmır, finalda bir dəfə verilir
	finalRewardDecor = "D_MASTER_BADGE",
}
