--!strict
-- Güc və ustalıq (bölmə 6).
-- Güc səviyyəsi L üçün ümumi İş XP-si: 20 × (L−1) × L. Növbəti səviyyəyə əlavə: 40 × L.
local Constants = require(script.Parent.Parent.Constants)

local Progression = {}

function Progression.totalXpFor(level: number): number
	return 20 * (level - 1) * level
end

function Progression.levelFor(xp: number): number
	local level = 1
	while level < Constants.POWER_MAX and xp >= Progression.totalXpFor(level + 1) do
		level += 1
	end
	return level
end

-- Cari səviyyədə irəliləyiş: (səviyyədə toplanan, növbəti üçün lazım olan)
function Progression.progress(xp: number): (number, number)
	local level = Progression.levelFor(xp)
	if level >= Constants.POWER_MAX then
		return 0, 0
	end
	local base = Progression.totalXpFor(level)
	return xp - base, 40 * level
end

-- Güc iş sürətinə kiçik əlavə verir: 1 + 0.025 × (L−1)
function Progression.powerMultiplier(level: number): number
	return 1 + Constants.POWER_SPEED_BONUS * (level - 1)
end

-- Ustalıq: işarə sayından səviyyə (0–5); xərclər 5, 10, 15, 20, 25 (ardıcıl)
function Progression.masteryLevel(marks: number): number
	local level = 0
	local spent = 0
	for i, cost in Constants.MASTERY_COSTS do
		spent += cost
		if marks >= spent then
			level = i
		else
			break
		end
	end
	return level
end

-- Ustalıq iş vaxtını hər səviyyədə 2% azaldır, cəmi 10%-dən çox deyil.
-- İş vaxtı = iş / (sürət × güc × ustalıq), ona görə ustalıq vuruğu 1 / (1 − azalma) olur.
function Progression.masteryMultiplier(level: number): number
	local reduction = math.min(Constants.MASTERY_STEP * level, Constants.MASTERY_CAP)
	return 1 / (1 - reduction)
end

function Progression.workSeconds(work: number, toolRate: number, power: number, masteryLvl: number): number
	return work / (toolRate * Progression.powerMultiplier(power) * Progression.masteryMultiplier(masteryLvl))
end

return Progression
