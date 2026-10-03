--!nocheck
-- Oyun sessiyasını server API-si ilə idarə edən test botu.
-- Vaxt hesabı TƏXMİNDİR: iş/gözləmə vaxtı simulyasiya olunur, yeriş vaxtı düz xətt məsafəsi × 1.3 / 14 stud/s,
-- hər UI əməliyyatı üçün sabit əlavə saniyə götürülür. Real oyunçu ilə ölçülmüş vaxt deyil.
local Bot = {}
Bot.__index = Bot

local WALK = 14
local PATH_FACTOR = 1.3
local UI_SECONDS = 2

function Bot.new(H, opts)
	local Game = H.require("src/shared/Core/Game")
	local Profile = H.require("src/shared/Core/Profile")
	local Layout = H.require("src/shared/Layout")
	local Placement = H.require("src/shared/Core/Placement")
	local profile = (opts and opts.profile) or Profile.new(0)
	local self = setmetatable({
		H = H,
		Layout = Layout,
		Placement = Placement,
		game = Game.new(profile),
		clock = 0,
		walkSeconds = 0,
		uiSeconds = 0,
		pos = { 0, 0, 86 },
		log = {},
		strict = not (opts and opts.lenient),
	}, Bot)
	self.game:setPosition(0, 0, 86)
	return self
end

function Bot:profile()
	return self.game.profile
end

function Bot:activeSeconds()
	return self.game.profile.playSeconds
end

-- Yeriş vaxtı tick edildiyi üçün playSeconds-ə daxildir; UI vaxtı ayrıca əlavə olunur
function Bot:totalSeconds()
	return self.game.profile.playSeconds + self.uiSeconds
end

function Bot:note(fmt, ...)
	table.insert(self.log, string.format("[%6.1f dəq] ", self:totalSeconds() / 60) .. string.format(fmt, ...))
end

-- Mövqeyə get (yeriş vaxtı yeriş zamanı da oyun vaxtı keçir: tick edilir)
function Bot:goToPos(x, y, z)
	local dx, dy, dz = x - self.pos[1], y - self.pos[2], z - self.pos[3]
	local dist = math.sqrt(dx * dx + dz * dz) * PATH_FACTOR + math.abs(dy) * 2
	local seconds = dist / WALK
	self.walkSeconds += seconds
	-- Yeriş zamanı da aktiv oyun vaxtı keçir (bitkilər böyüyür, su axır)
	local remaining = seconds
	while remaining > 0 do
		local step = math.min(0.5, remaining)
		self.game:tick(step)
		remaining -= step
	end
	self.pos = { x, y, z }
	self.game:setPosition(x, y, z)
end

function Bot:goTo(id)
	local obj = self.Layout.byId[id]
	if obj then
		self:goToPos(obj.pos[1], obj.pos[2], obj.pos[3])
		return
	end
	local b = self.game.profile.builds[id]
	assert(b, "naməlum hədəf " .. tostring(id))
	local c = self.Placement.worldCenter(b)
	self:goToPos(c[1], c[2], c[3])
end

function Bot:act(action, payload)
	self.clock += 1
	local result = self.game:handle(action, payload or {}, self.clock)
	self.game:drainEvents()
	if self.strict and not result.ok then
		error(("%s uğursuz: %s (%s)"):format(action, tostring(result.err), self.H and "" or ""), 2)
	end
	return result
end

function Bot:try(action, payload)
	self.clock += 1
	local result = self.game:handle(action, payload or {}, self.clock)
	self.game:drainEvents()
	return result
end

function Bot:wait(seconds)
	local remaining = seconds
	while remaining > 0 do
		local step = math.min(0.5, remaining)
		self.game:tick(step)
		remaining -= step
	end
	self.game:drainEvents()
end

function Bot:ui()
	self.uiSeconds += UI_SECONDS
end

-- İşi tamamla. Qaytarır: iş saniyəsi
function Bot:work(id)
	self:goTo(id)
	local p = self.game.profile
	local isSpot = self.Layout.byId[id].kind == "spot"
	local result = self:try("StartWork", { target = id })
	if not result.ok then
		if result.err == "msg.bagFull" then
			self:deposit()
			self:goTo(id)
			result = self:try("StartWork", { target = id })
		end
		if not result.ok then
			error(("StartWork %s uğursuz: %s"):format(id, tostring(result.err)), 2)
		end
	end
	local t0 = p.playSeconds
	for _ = 1, 2000 do
		self.game:tick(0.25)
		if not self.game.work then
			break
		end
	end
	self.game:drainEvents()
	if isSpot then
		assert(p.respawn[id] ~= nil, "yuva işi bitmədi: " .. id)
	else
		assert(p.restoredObjectIds[id], "iş bitmədi: " .. id)
	end
	return p.playSeconds - t0
end

function Bot:deposit()
	self:goTo("Z01_Storage")
	self:act("Interact", { target = "Z01_Storage" })
	self:ui()
end

function Bot:fill(sourceId)
	self:goTo(sourceId)
	return self:act("FillWater", { source = sourceId })
end

function Bot:pour(targetId)
	self:goTo(targetId)
	return self:act("WaterPlant", { target = targetId })
end

function Bot:buy(id)
	self:goTo("Z01_Shop")
	self:ui()
	return self:act("BuyItem", { id = id })
end

function Bot:craft(recipe, n)
	self:goTo("Z01_Workbench")
	self:ui()
	return self:act("Craft", { recipe = recipe, count = n or 1 })
end

function Bot:interact(id)
	self:goTo(id)
	self:ui()
	return self:act("Interact", { target = id })
end

function Bot:place(build, area, x, z, r, v)
	local a = self.Layout.areaById[area]
	self:goToPos(a.origin[1] + x, a.origin[2], a.origin[3] + z)
	self:ui()
	return self:act("Place", { build = build, area = area, x = x, z = z, r = r or 0, v = v })
end

function Bot:placeSocket(build, socket)
	self:goTo(socket)
	self:ui()
	return self:act("Place", { build = build, socket = socket })
end

function Bot:step()
	local s = self.game:currentStep()
	return s and s.id or "DONE"
end

function Bot:power()
	return self.game:power()
end

-- Mənbəyə kifayət qədər su yığılana qədər gözlə və qabı doldur
function Bot:fillFull(sourceId)
	local spec = self.game:cupSpec()
	self:goTo(sourceId)
	for _ = 1, 400 do
		local p = self.game.profile
		if p.cup >= spec.capacity then
			break
		end
		local r = self:try("FillWater", { source = sourceId })
		if not r.ok and r.err ~= "msg.sourceEmpty" then
			break
		end
		if p.cup < spec.capacity then
			self:wait(1)
		end
	end
end

-- Hədəfi qabla tam bərpa et (lazım olsa mənbəyə qayıdaraq)
function Bot:waterUntilRestored(targetId, sourceId)
	local p = self.game.profile
	for _ = 1, 50 do
		if p.restoredObjectIds[targetId] then
			return
		end
		if p.cup <= 0 then
			self:fillFull(sourceId)
		end
		self:pour(targetId)
	end
	error("yataq bərpa olunmadı: " .. targetId)
end

return Bot
