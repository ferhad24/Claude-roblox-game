--!nocheck
-- M2: davametmə, sessiya kilidi, miqrasiya. Yaddaşdaxili adapterlə (canlı DataStore DEYİL).
local H = require("../harness")

return function(T)
	local ProfileStore = H.require("src/server/ProfileStore")
	local Profile = H.require("src/shared/Core/Profile")
	local Game = H.require("src/shared/Core/Game")
	local Constants = H.require("src/shared/Constants")

	local clock = 1000
	local function makeStore(adapter, jobId)
		return ProfileStore.new({
			adapter = adapter,
			jobId = jobId,
			now = function()
				return clock
			end,
			wait = function(s)
				clock += s
			end,
			lockTimeout = Constants.SESSION_LOCK_SECONDS,
			retries = 4,
			migrate = Profile.migrate,
			newProfile = Profile.new,
			clone = Profile.clone,
		})
	end

	T.describe("Yaddaş və sessiya kilidi", function()
		T.it("yeni profil yaradılır, saxlanılır və yenidən yüklənir", function()
			local adapter = ProfileStore.memoryAdapter(Profile.clone)
			local store = makeStore(adapter, "jobA")
			local s, err = store:load("p_1")
			T.expect(err).toBe(nil)
			s.profile.coins = 42
			T.expect((store:save(s, true))).toBe(true)
			local s2 = store:load("p_1")
			T.expect(s2.profile.coins).toBe(42)
			T.expect(s2.revision).toBe(1)
		end)

		T.it("iki sessiya eyni profilə paralel yazmır", function()
			local adapter = ProfileStore.memoryAdapter(Profile.clone)
			local a = makeStore(adapter, "jobA")
			local b = makeStore(adapter, "jobB")
			local sa = a:load("p_2")
			T.expect(sa ~= nil).toBeTruthy()
			local sb, err = b:load("p_2")
			T.expect(sb).toBe(nil)
			T.expect(err).toBe("locked")
			sa.profile.coins = 7
			T.expect((a:save(sa, false))).toBe(true)
		end)

		T.it(
			"kilid bərpası: köhnəlmiş kilid (çökmüş server) götürülür, köhnə sessiya artıq yaza bilmir",
			function()
				local adapter = ProfileStore.memoryAdapter(Profile.clone)
				local a = makeStore(adapter, "jobA")
				local b = makeStore(adapter, "jobB")
				local sa = a:load("p_3")
				sa.profile.coins = 5
				a:save(sa, false)
				clock += Constants.SESSION_LOCK_SECONDS + 1
				local sb = b:load("p_3")
				T.expect(sb ~= nil).toBeTruthy("köhnəlmiş kilid götürülmədi")
				T.expect(sb.profile.coins).toBe(5)
				sa.profile.coins = 999
				local ok, why = a:save(sa, false)
				T.expect(ok).toBe(false)
				T.expect(why).toBe("lockLost")
				T.expect(sa.readOnly).toBe(true)
				local check = makeStore(adapter, "jobB")
				sb.profile.coins = 6
				T.expect((check:save(sb, true))).toBe(true)
				local again = makeStore(adapter, "jobC"):load("p_3")
				T.expect(again.profile.coins).toBe(6)
			end
		)

		T.it("yükləmə xətasında əvvəlki profil əvəzlənmir", function()
			local adapter = ProfileStore.memoryAdapter(Profile.clone)
			local a = makeStore(adapter, "jobA")
			local s = a:load("p_4")
			s.profile.coins = 321
			a:save(s, true)
			adapter.failNext = 10 -- bütün cəhdlər uğursuz
			local b = makeStore(adapter, "jobB")
			local sb, err = b:load("p_4")
			T.expect(sb).toBe(nil)
			T.expect(err).toBe("error")
			adapter.failNext = 0
			local sc = makeStore(adapter, "jobC"):load("p_4")
			T.expect(sc.profile.coins).toBe(321)
		end)

		T.it("müvəqqəti xətadan sonra retry/backoff ilə yüklənir", function()
			local adapter = ProfileStore.memoryAdapter(Profile.clone)
			adapter.failNext = 2
			local before = clock
			local s = makeStore(adapter, "jobA"):load("p_5")
			T.expect(s ~= nil).toBeTruthy()
			T.expect(clock - before).toBe(2 + 4)
		end)

		T.it("yeni schemaVersion əvvəlki (v0) save-i miqrasiya edir", function()
			local adapter = ProfileStore.memoryAdapter(Profile.clone)
			adapter.data["p_6"] = { v = 1, revision = 3, data = { stamps = 50, inv = { MAT_FIBER = 4 }, xp = 130 } }
			local s, err = makeStore(adapter, "jobA"):load("p_6")
			T.expect(err).toBe(nil)
			T.expect(s.profile.coins).toBe(50)
			T.expect(s.profile.bag["MAT_FIBER"]).toBe(4)
			T.expect(s.profile.workXP).toBe(130)
			T.expect(s.profile.schemaVersion).toBe(Constants.SCHEMA_VERSION)
			T.expect(s.revision).toBe(3)
		end)

		T.it("uyğun olmayan (gələcək versiya) save təhlükəsiz rədd olunur və üzərinə yazılmır", function()
			local adapter = ProfileStore.memoryAdapter(Profile.clone)
			local future = { schemaVersion = 99, coins = 1 }
			adapter.data["p_7"] = { v = 1, revision = 5, data = future }
			local s, err = makeStore(adapter, "jobA"):load("p_7")
			T.expect(s).toBe(nil)
			T.expect(err).toBe("migrate:future_version")
			T.expect(adapter.data["p_7"].data.schemaVersion).toBe(99)
			T.expect(adapter.data["p_7"].revision).toBe(5)
			T.expect(adapter.data["p_7"].lock).toBe(nil)
		end)

		T.it("zədəli profil sahələri təmizlənir (NaN, mənfi, naməlum alət)", function()
			local p = Profile.migrate({
				schemaVersion = 1,
				coins = 0 / 0,
				workXP = -5,
				tools = { TOOL_GLOVES_1 = true, TOOL_FAKE = true },
				bag = { MAT_FIBER = math.huge, MAT_TWIG = 3 },
			}, 0)
			T.expect(p.coins).toBe(0)
			T.expect(p.workXP).toBe(0)
			T.expect(p.tools["TOOL_FAKE"]).toBe(nil)
			T.expect(p.bag["MAT_FIBER"]).toBe(nil)
			T.expect(p.bag["MAT_TWIG"]).toBe(3)
		end)

		T.it("oyun vəziyyəti save/load dövrəsindən sonra eyni qalır", function()
			local adapter = ProfileStore.memoryAdapter(Profile.clone)
			local store = makeStore(adapter, "jobA")
			local s = store:load("p_8")
			local g = Game.new(s.profile)
			g:setPosition(0, 0, 80)
			g:handle("StartWork", { target = "Z01_Leaf_01" }, 1)
			for _ = 1, 20 do
				g:tick(0.25)
			end
			s.profile.builds["1"] = { t = "B_CHANNEL", area = "A_Z01_LINE", x = 2, z = 4, r = 0 }
			store:save(s, true)
			local s2 = makeStore(adapter, "jobB"):load("p_8")
			T.expect(s2.profile.restoredObjectIds["Z01_Leaf_01"]).toBe(true)
			T.expect(s2.profile.coins).toBe(5)
			T.expect(s2.profile.builds["1"].t).toBe("B_CHANNEL")
			T.expect(s2.profile.quest.step).toBe(1)
		end)
	end)
end
