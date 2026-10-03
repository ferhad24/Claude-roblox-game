--!strict
-- Oyun analitikası (bölmə 26): yalnız texniki və oyun hadisələri; şəxsi məlumat və dialoq mətni yoxdur.
-- AnalyticsService:LogCustomEvent istifadə olunur. Uğursuz olarsa (Studio, limit) səssiz keçilir.
local AnalyticsService = game:GetService("AnalyticsService")

local Telemetry = {}

local ALLOWED = {
	tutorial_step = true,
	work_completed = true,
	purchase = true,
	recipe_crafted = true,
	zone_restored = true,
	quest_completed = true,
	final_completed = true,
	save_error = true,
}

function Telemetry.log(player: Player, eventName: string, catalogId: string?, sessionSeconds: number?)
	if not ALLOWED[eventName] then
		return
	end
	pcall(function()
		local fields = {}
		if catalogId then
			fields[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = catalogId
		end
		AnalyticsService:LogCustomEvent(player, eventName, math.floor(sessionSeconds or 0), fields)
	end)
end

return Telemetry
