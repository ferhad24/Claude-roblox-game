--!strict
-- Profil yaddaşı: UpdateAsync ilə sessiya kilidi, revision, retry/backoff (bölmə 20).
-- Roblox API-dən birbaşa asılı deyil: DataStore "adapter" kimi ötürülür (testdə yaddaşdaxili adapter).
--
-- Qeyd formatı: { v = 1, revision = n, lock = { job = jobId, t = os.time() } | nil, data = profile | nil }
-- Qaydalar:
--   * Yükləmə uğursuzdursa boş yeni profil köhnə profilin üzərinə yazılmır.
--   * Başqa server kilidi saxlayırsa (və kilid köhnəlməyibsə) yükləmə gözləyir/rədd edilir.
--   * Save yalnız kilid bu serverdə və revision uyğun olanda yazılır; əks halda yazmadan imtina edilir.
export type Adapter = {
	UpdateAsync: (self: any, key: string, fn: (any) -> any) -> any,
	isTest: boolean?,
}

export type Deps = {
	adapter: Adapter,
	jobId: string,
	now: () -> number,
	wait: (number) -> (),
	lockTimeout: number,
	retries: number,
	migrate: (any, number) -> (any?, string?),
	newProfile: (number) -> any,
	clone: (any) -> any,
}

export type Session = {
	key: string,
	revision: number,
	profile: any,
	readOnly: boolean,
	released: boolean,
}

local ProfileStore = {}
ProfileStore.__index = ProfileStore

export type Store = typeof(setmetatable({} :: { deps: Deps }, ProfileStore))

function ProfileStore.new(deps: Deps): Store
	return setmetatable({ deps = deps }, ProfileStore)
end

local function backoff(attempt: number): number
	return math.min(16, 2 ^ attempt) -- 2, 4, 8, 16 s
end

-- Qaytarır: sessiya və ya nil + səbəb ("locked" | "error" | "corrupt" | "migrate:<səbəb>")
function ProfileStore.load(self: Store, key: string): (Session?, string?)
	local d = self.deps
	local lastErr = "error"
	for attempt = 1, d.retries do
		local status = "error"
		local okCall, result = pcall(function()
			return d.adapter:UpdateAsync(key, function(old: any): any
				local now = d.now()
				if old == nil then
					status = "new"
					return { v = 1, revision = 0, lock = { job = d.jobId, t = now }, data = nil }
				end
				if type(old) ~= "table" or type(old.revision) ~= "number" then
					status = "corrupt"
					return nil
				end
				local lock = old.lock
				if
					type(lock) == "table"
					and lock.job ~= d.jobId
					and type(lock.t) == "number"
					and now - lock.t < d.lockTimeout
				then
					status = "locked"
					return nil
				end
				status = "ok"
				old.lock = { job = d.jobId, t = now }
				return old
			end)
		end)
		if okCall and (status == "ok" or status == "new") then
			local record = result
			if type(record) ~= "table" then
				return nil, "error"
			end
			local now = d.now()
			local profile, why
			if record.data == nil then
				profile = d.newProfile(now)
			else
				profile, why = d.migrate(record.data, now)
			end
			if not profile then
				-- Uyğun olmayan save: üzərinə yazmırıq, kilidi buraxırıq
				self:releaseLock(key)
				return nil, "migrate:" .. tostring(why)
			end
			return { key = key, revision = record.revision, profile = profile, readOnly = false, released = false }, nil
		end
		if okCall and status == "corrupt" then
			return nil, "corrupt"
		end
		lastErr = okCall and status or "error"
		if attempt < d.retries then
			d.wait(backoff(attempt))
		end
	end
	return nil, lastErr
end

-- Yalnız kilidi buraxır (məlumata toxunmur)
function ProfileStore.releaseLock(self: Store, key: string)
	local d = self.deps
	pcall(function()
		d.adapter:UpdateAsync(key, function(old: any): any
			if type(old) ~= "table" or type(old.lock) ~= "table" or old.lock.job ~= d.jobId then
				return nil
			end
			old.lock = nil
			return old
		end)
	end)
end

-- Qaytarır: uğur, səbəb ("lockLost" | "revision" | "missing" | "error" | "readOnly")
function ProfileStore.save(self: Store, session: Session, release: boolean): (boolean, string?)
	local d = self.deps
	if session.readOnly then
		return false, "readOnly"
	end
	if session.released then
		return false, "released"
	end
	local snapshot = d.clone(session.profile)
	local lastErr = "error"
	for attempt = 1, d.retries do
		local status = "error"
		local okCall = pcall(function()
			d.adapter:UpdateAsync(session.key, function(old: any): any
				if type(old) ~= "table" then
					status = "missing"
					return nil
				end
				if type(old.lock) ~= "table" or old.lock.job ~= d.jobId then
					status = "lockLost"
					return nil
				end
				if old.revision ~= session.revision then
					status = "revision"
					return nil
				end
				status = "ok"
				local lock = nil
				if not release then
					lock = { job = d.jobId, t = d.now() }
				end
				return { v = 1, revision = session.revision + 1, lock = lock, data = snapshot }
			end)
		end)
		if okCall and status == "ok" then
			session.revision += 1
			if release then
				session.released = true
			end
			return true, nil
		end
		if okCall and (status == "lockLost" or status == "revision" or status == "missing") then
			-- Başqa sessiya yazıb: bu sessiya artıq yazmamalıdır
			session.readOnly = true
			return false, status
		end
		lastErr = status
		if attempt < d.retries then
			d.wait(backoff(attempt))
		end
	end
	return false, lastErr
end

-- Yaddaşdaxili adapter: Studio-da API girişi olmayanda və testlərdə istifadə olunur.
-- Dəyərlər serializasiyanı yamsılamaq üçün dərin surətlə saxlanılır. Oyun bağlananda itir.
function ProfileStore.memoryAdapter(clone: (any) -> any): Adapter
	local data: { [string]: any } = {}
	local adapter = {
		isTest = true,
		failNext = 0,
		data = data,
	}
	function adapter.UpdateAsync(self: any, key: string, fn: (any) -> any): any
		if self.failNext > 0 then
			self.failNext -= 1
			error("simulated DataStore error")
		end
		local current = data[key]
		local result = fn(current ~= nil and clone(current) or nil)
		if result ~= nil then
			data[key] = clone(result)
			return clone(result)
		end
		return current ~= nil and clone(current) or nil
	end
	return adapter :: any
end

return ProfileStore
