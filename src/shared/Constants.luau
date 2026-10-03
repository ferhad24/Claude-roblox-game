--!strict
-- Vahid ölçülər və balans sabitləri. Bütün rəqəmlər dizayn sənədinin (v1.0) ilkin hədəfləridir.

local Constants = {}

-- Hərəkət və kamera (bölmə 2)
Constants.WALK_SPEED = 14
Constants.RUN_SPEED = 18
Constants.CARRY_WALK_SPEED = 12 -- yük daşıyanda 11-dən aşağı salınmır
Constants.CARRY_RUN_SPEED = 15
Constants.JUMP_HEIGHT = 3.2
Constants.CAMERA_START_DISTANCE = 12
Constants.CAMERA_MIN_DISTANCE = 8
Constants.CAMERA_MAX_DISTANCE = 22
Constants.CAMERA_FOV = 70

-- İş (bölmə 6–7)
Constants.WORK_RANGE = 8 -- obyektdən 8 stud-dan uzaqlaşanda iş dayanır
Constants.INTERACT_RANGE = 10
Constants.POWER_MAX = 20
Constants.POWER_SPEED_BONUS = 0.025 -- baza × [1 + 0.025 × (L−1)]
Constants.MASTERY_MAX = 5
Constants.MASTERY_COSTS = { 5, 10, 15, 20, 25 }
Constants.MASTERY_STEP = 0.02 -- hər səviyyə iş vaxtını 2% azaldır
Constants.MASTERY_CAP = 0.10

-- İnventar (bölmə 8–10)
Constants.STACK_MAX = 99
Constants.SEED_STACK_MAX = 20
Constants.BAG_START = 12
Constants.STORAGE_CAPACITY = 300
Constants.HOME_WATER_CAPACITY = 120

-- Resurs yuvaları (bölmə 9)
Constants.RESPAWN_SECONDS = 60

-- Su (bölmə 12)
Constants.WATER_TICK = 1
Constants.CHANNEL_RATE = 1 -- doza/s
Constants.DOSE_MOISTURE = 25
Constants.MOISTURE_MAX = 100
Constants.MOISTURE_DECAY = 2
Constants.MOISTURE_DECAY_INTERVAL = 30
Constants.PLANT_MIN_MOISTURE = 25
Constants.MAX_LINE_LENGTH = 80 -- bir xəttin izlənməsində maksimum düyün sayı

-- Tikinti (bölmə 11, 21)
Constants.MAX_PLAYER_BUILDS = 120
Constants.GRID = 1

-- Gün dövrəsi (bölmə 18)
Constants.DAY_LENGTH = 24 * 60
Constants.DAY_PHASE_DAY = 12 * 60
Constants.DAY_PHASE_EVENING = 6 * 60
Constants.RAIN_DURATION = 120
Constants.RAIN_MIN_CYCLES = 2
Constants.RAIN_MAX_CYCLES = 3
Constants.RAIN_CATCHER_INTERVAL = 5 -- yağış zamanı toplayıcı hər 5 s-də 1 doza

-- Şəbəkə və təhlükəsizlik (bölmə 20)
Constants.RATE_LIMITS = {
	work = { count = 4, window = 1 },
	trade = { count = 2, window = 1 },
	place = { count = 4, window = 1 },
	misc = { count = 8, window = 1 },
}
Constants.MAX_CRAFT_COUNT = 20
Constants.RID_CACHE_SIZE = 64

-- Yaddaş (bölmə 20)
Constants.SCHEMA_VERSION = 1
Constants.AUTOSAVE_SECONDS = 150
Constants.SESSION_LOCK_SECONDS = 1800
Constants.DATASTORE_NAME = "TinyGrove_Profiles_v1"

-- UI
Constants.MIN_TOUCH = 48
Constants.TOAST_SECONDS = 1.5
Constants.EXPENSIVE_DECOR = 50 -- bu qiymətdən baha dekor üçün bir dəfə təsdiq

return Constants
