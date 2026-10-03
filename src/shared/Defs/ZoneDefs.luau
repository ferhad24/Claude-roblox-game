--!strict
-- Altı sahə (bölmə 5). Xəritə ölçüsü 260 × 220 stud: X −130..130, Z −110..110.
-- Şimal −Z istiqamətidir. Z05 masa üstündə, Y=24 hündürlükdədir və liftlə açılır.
local Types = require(script.Parent.Parent.Types)

type ZoneDef = Types.ZoneDef

local list: { ZoneDef } = {
	{
		id = "Z01",
		nameKey = "zone.Z01",
		order = 1,
		unlock = { kind = "always" },
		chapter = 1,
		origin = { -50, 0, 40 },
		size = { 100, 70 },
		groundColor = { neglected = { 150, 130, 95 }, partial = { 140, 160, 100 }, restored = { 111, 166, 106 } },
	},
	{
		id = "Z02",
		nameKey = "zone.Z02",
		order = 2,
		unlock = { kind = "chapter", chapter = 1 },
		chapter = 2,
		origin = { 50, 0, 8 },
		size = { 80, 102 },
		groundColor = { neglected = { 160, 150, 110 }, partial = { 150, 175, 120 }, restored = { 168, 199, 141 } },
	},
	{
		id = "Z03",
		nameKey = "zone.Z03",
		order = 3,
		unlock = { kind = "step", step = "Q2_BRIDGE" },
		chapter = 3,
		origin = { 50, 0, -110 },
		size = { 80, 102 },
		groundColor = { neglected = { 150, 115, 90 }, partial = { 140, 140, 100 }, restored = { 120, 160, 100 } },
	},
	{
		id = "Z04",
		nameKey = "zone.Z04",
		order = 4,
		unlock = { kind = "chapter", chapter = 3 },
		chapter = 4,
		origin = { -130, 0, -110 },
		size = { 180, 70 },
		groundColor = { neglected = { 120, 95, 75 }, partial = { 120, 125, 85 }, restored = { 100, 150, 90 } },
	},
	{
		id = "Z05",
		nameKey = "zone.Z05",
		order = 5,
		unlock = { kind = "chapter", chapter = 4 },
		chapter = 5,
		origin = { -130, 24, -36 },
		size = { 80, 96 },
		groundColor = { neglected = { 170, 160, 140 }, partial = { 170, 185, 150 }, restored = { 190, 215, 170 } },
	},
	{
		id = "Z06",
		nameKey = "zone.Z06",
		order = 6,
		unlock = {
			kind = "all",
			list = { { kind = "chapter", chapter = 4 }, { kind = "chapter", chapter = 5 } },
		},
		chapter = 6,
		origin = { -40, 0, -40 },
		size = { 90, 80 },
		groundColor = { neglected = { 140, 110, 85 }, partial = { 130, 140, 95 }, restored = { 111, 166, 106 } },
	},
}

local byId: { [string]: ZoneDef } = {}
for _, def in list do
	byId[def.id] = def
end

return {
	list = list,
	byId = byId,
}
