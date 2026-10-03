--!strict
-- TINY GROVE server başlanğıcı: kataloq yoxlaması → dünya → yaddaş → sessiyalar.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.Core.Catalog)
local Locales = require(Shared.Locales)

local errors = Catalog.validate(Locales.maps)
if #errors > 0 then
	for _, e in errors do
		warn("[TinyGrove] Kataloq xətası: " .. e)
	end
	error(("[TinyGrove] Kataloq yoxlaması %d xəta tapdı; oyun başladılmır."):format(#errors))
end

local WorldService = require(script.Services.WorldService)
local PlayerDataService = require(script.Services.PlayerDataService)
local SessionService = require(script.Services.SessionService)

WorldService.build()
PlayerDataService.init()
SessionService.init()
print("[TinyGrove] server hazırdır")
