--!strict
-- Sakinlər (bölmə 14): Usta Pıtır, Bağban Nərgiz, Mexanik Çırt.
-- Dialoqlar 1–3 cümlədir; mətnlər Locales-dədir.

export type NpcDef = {
	id: string,
	who: "pitir" | "nargiz" | "cirt",
	nameKey: string,
	lines: { string }, -- lokal mətn açarları
	opens: string?, -- "shop" | "workshop" | "board"
	color: { number },
}

local list: { NpcDef } = {
	{
		id = "NPC_PITIR",
		who = "pitir",
		nameKey = "npc.pitir",
		lines = { "dlg.pitir.1", "dlg.pitir.2" },
		opens = "shop",
		color = { 170, 125, 85 },
	},
	{
		id = "NPC_NARGIZ_Z01",
		who = "nargiz",
		nameKey = "npc.nargiz",
		lines = { "dlg.nargiz.z01.1", "dlg.nargiz.z01.2" },
		color = { 169, 149, 207 },
	},
	{
		id = "NPC_CIRT_Z02",
		who = "cirt",
		nameKey = "npc.cirt",
		lines = { "dlg.cirt.z02.1", "dlg.cirt.z02.2", "dlg.cirt.z02.3" },
		color = { 120, 130, 140 },
	},
	{
		id = "NPC_NARGIZ_Z03",
		who = "nargiz",
		nameKey = "npc.nargiz",
		lines = { "dlg.nargiz.z03.1", "dlg.nargiz.z03.2", "dlg.nargiz.z03.3" },
		color = { 169, 149, 207 },
	},
	{
		id = "NPC_CIRT_Z04",
		who = "cirt",
		nameKey = "npc.cirt",
		lines = { "dlg.cirt.z04.1", "dlg.cirt.z04.2" },
		color = { 120, 130, 140 },
	},
	{
		id = "NPC_CIRT_Z05",
		who = "cirt",
		nameKey = "npc.cirt",
		lines = { "dlg.cirt.z05.1", "dlg.cirt.z05.2", "dlg.cirt.z05.3" },
		color = { 120, 130, 140 },
	},
}

local byId: { [string]: NpcDef } = {}
for _, def in list do
	byId[def.id] = def
end

return {
	list = list,
	byId = byId,
}
