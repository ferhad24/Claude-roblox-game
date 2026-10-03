--!strict
-- Kataloq şərtlərinin profil üzərində yoxlanması.
local Shared = script.Parent.Parent
local Types = require(Shared.Types)
local QuestDefs = require(Shared.Defs.QuestDefs)
local Progression = require(script.Parent.Progression)

type Condition = Types.Condition
type Profile = Types.Profile

local Conditions = {}

function Conditions.chapterDone(p: Profile, chapter: number): boolean
	local ch = QuestDefs.chapters[chapter]
	if not ch then
		return false
	end
	return p.quest.done[ch.steps[#ch.steps].id] == true
end

function Conditions.check(p: Profile, cond: Condition): boolean
	if cond.kind == "always" then
		return true
	elseif cond.kind == "step" then
		return p.quest.done[cond.step] == true
	elseif cond.kind == "chapter" then
		return Conditions.chapterDone(p, cond.chapter)
	elseif cond.kind == "power" then
		return Progression.levelFor(p.workXP) >= cond.value
	elseif cond.kind == "zone" then
		return p.zones[cond.zone] == true
	elseif cond.kind == "final" then
		return p.finalCompleted
	elseif cond.kind == "all" then
		for _, c in cond.list do
			if not Conditions.check(p, c) then
				return false
			end
		end
		return true
	end
	return false
end

-- UI üçün: şərtin oxunaqlı izahı üçün açar və parametrlər.
function Conditions.describe(cond: Condition): (string, { [string]: any })
	if cond.kind == "step" then
		local step = QuestDefs.stepById[cond.step]
		return "cond.step", { step = step and step.textKey or cond.step }
	elseif cond.kind == "chapter" then
		return "cond.chapter", { n = cond.chapter }
	elseif cond.kind == "power" then
		return "cond.power", { n = cond.value }
	elseif cond.kind == "zone" then
		return "cond.zone", { zone = "zone." .. cond.zone }
	elseif cond.kind == "final" then
		return "cond.final", {}
	elseif cond.kind == "all" then
		-- İlk ödənməyən hissəni göstərmək üçün çağıran tərəf Conditions.firstUnmet istifadə edir
		return Conditions.describe(cond.list[1])
	end
	return "cond.always", {}
end

function Conditions.firstUnmet(p: Profile, cond: Condition): Condition?
	if cond.kind == "all" then
		for _, c in cond.list do
			local u = Conditions.firstUnmet(p, c)
			if u then
				return u
			end
		end
		return nil
	end
	if Conditions.check(p, cond) then
		return nil
	end
	return cond
end

return Conditions
