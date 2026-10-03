--!strict
-- Profilin yüklənməsi və saxlanılması (bölmə 20, M2).
-- Canlı DataStore əlçatan deyilsə (Studio-da API girişi bağlı, yayımlanmamış yer) yaddaşdaxili
-- TEST adapteri işə düşür və oyunçuya "test rejimi — yaddaş saxlanmır" göstərilir.
-- Test adapteri canlı DataStore sayılmır (bölmə 24, M2).
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Profile = require(Shared.Core.Profile)
local ProfileStore = require(script.Parent.Parent.ProfileStore)

local PlayerDataService = {}

local store: ProfileStore.Store
local testMode = false
local jobId = if game.JobId ~= "" then game.JobId else ("studio-" .. HttpService:GenerateGUID(false))

local function makeAdapter(): ProfileStore.Adapter
	local ok, dsOrErr = pcall(function()
		return DataStoreService:GetDataStore(Constants.DATASTORE_NAME)
	end)
	if ok then
		local ds = dsOrErr :: DataStore
		-- Studio-da API girişi bağlı olanda ilk sorğu xəta verir: bunu əvvəlcədən yoxlayırıq
		local probeOk, probeErr = pcall(function()
			ds:GetAsync("__probe")
		end)
		if probeOk then
			return {
				UpdateAsync = function(_self: any, key: string, fn: (any) -> any): any
					return ds:UpdateAsync(key, function(old: any): any
						return fn(old)
					end)
				end,
				isTest = false,
			}
		end
		warn("[TinyGrove] DataStore əlçatan deyil, test adapteri istifadə olunur: " .. tostring(probeErr))
	else
		warn("[TinyGrove] DataStore açılmadı, test adapteri istifadə olunur: " .. tostring(dsOrErr))
	end
	testMode = true
	return ProfileStore.memoryAdapter(Profile.clone)
end

function PlayerDataService.init()
	local adapter = makeAdapter()
	store = ProfileStore.new({
		adapter = adapter,
		jobId = jobId,
		now = os.time,
		wait = function(s: number)
			task.wait(s)
		end,
		lockTimeout = Constants.SESSION_LOCK_SECONDS,
		retries = 4,
		migrate = Profile.migrate,
		newProfile = Profile.new,
		clone = Profile.clone,
	})
end

function PlayerDataService.isTestMode(): boolean
	return testMode
end

function PlayerDataService.keyFor(player: Player): string
	-- Studio-da test oyunçularının mənfi ID-ləri ola bilər; açar ayrı prefikslə saxlanılır
	if player.UserId <= 0 then
		return "test_" .. tostring(player.UserId)
	end
	return "p_" .. tostring(player.UserId)
end

function PlayerDataService.load(player: Player): (ProfileStore.Session?, string?)
	return store:load(PlayerDataService.keyFor(player))
end

-- Request budget-ə hörmət: büdcə azdırsa avtomatik save bir az gözləyir
function PlayerDataService.budgetOk(): boolean
	if testMode then
		return true
	end
	local ok, budget = pcall(function()
		return DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
	end)
	return not ok or (budget :: number) > 2
end

function PlayerDataService.save(session: ProfileStore.Session, release: boolean): (boolean, string?)
	return store:save(session, release)
end

function PlayerDataService.release(session: ProfileStore.Session)
	store:releaseLock(session.key)
end

function PlayerDataService.isStudio(): boolean
	return RunService:IsStudio()
end

return PlayerDataService
