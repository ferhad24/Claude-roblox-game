--!strict
-- Çanta, ev anbarı və gözləyən materiallar (bölmə 8–10).
-- Çanta dolu olduqda material itmir: sığmayan hissə "gözləyən"ə yazılır və boşaltmadan sonra çantaya keçir.
local Shared = script.Parent.Parent
local Types = require(Shared.Types)
local Constants = require(Shared.Constants)

type Profile = Types.Profile
type Amount = Types.Amount

local Inventory = {}

local function sum(map: { [string]: number }): number
	local n = 0
	for _, v in map do
		n += v
	end
	return n
end
Inventory.sum = sum

function Inventory.bagUsed(p: Profile): number
	return sum(p.bag)
end

function Inventory.bagFree(p: Profile): number
	return math.max(0, p.bagCapacity - sum(p.bag))
end

function Inventory.storageFree(p: Profile): number
	return math.max(0, Constants.STORAGE_CAPACITY - sum(p.storage))
end

function Inventory.hasPending(p: Profile): boolean
	return next(p.pending) ~= nil
end

-- Material sayı (çanta + anbar)
function Inventory.count(p: Profile, id: string): number
	return (p.bag[id] or 0) + (p.storage[id] or 0)
end

-- Çantaya əlavə edir; sığmayan hissə gözləyənə gedir. Qaytarır: (çantaya düşən, gözləyənə düşən)
function Inventory.addToBag(p: Profile, id: string, n: number): (number, number)
	local fit = math.min(n, Inventory.bagFree(p), Constants.STACK_MAX - (p.bag[id] or 0))
	fit = math.max(0, fit)
	if fit > 0 then
		p.bag[id] = (p.bag[id] or 0) + fit
	end
	local rest = n - fit
	if rest > 0 then
		p.pending[id] = (p.pending[id] or 0) + rest
	end
	return fit, rest
end

-- Hazırlanmış materiallar: əvvəl çanta, sonra anbar, sonra gözləyən (heç vaxt itmir)
function Inventory.addCrafted(p: Profile, id: string, n: number)
	local fit = math.max(0, math.min(n, Inventory.bagFree(p), Constants.STACK_MAX - (p.bag[id] or 0)))
	if fit > 0 then
		p.bag[id] = (p.bag[id] or 0) + fit
	end
	local rest = n - fit
	if rest > 0 then
		local toStorage = math.min(rest, Inventory.storageFree(p))
		if toStorage > 0 then
			p.storage[id] = (p.storage[id] or 0) + toStorage
			rest -= toStorage
		end
	end
	if rest > 0 then
		p.pending[id] = (p.pending[id] or 0) + rest
	end
end

function Inventory.hasAll(p: Profile, list: { Amount }, mult: number): boolean
	local need: { [string]: number } = {}
	for _, a in list do
		need[a.id] = (need[a.id] or 0) + a.n * mult
	end
	for id, n in need do
		if Inventory.count(p, id) < n then
			return false
		end
	end
	return true
end

-- Atomik çıxılma: əvvəl yoxlanılır, sonra əvvəl çantadan, sonra anbardan götürülür.
function Inventory.take(p: Profile, list: { Amount }, mult: number): boolean
	if not Inventory.hasAll(p, list, mult) then
		return false
	end
	for _, a in list do
		local n = a.n * mult
		local fromBag = math.min(n, p.bag[a.id] or 0)
		if fromBag > 0 then
			p.bag[a.id] -= fromBag
			if p.bag[a.id] <= 0 then
				p.bag[a.id] = nil
			end
		end
		local rest = n - fromBag
		if rest > 0 then
			p.storage[a.id] -= rest
			if p.storage[a.id] <= 0 then
				p.storage[a.id] = nil
			end
		end
	end
	return true
end

-- Çantanı ev anbarına boşaldır, sonra gözləyənləri çantaya keçirir. Qaytarır: köçürülən say.
function Inventory.deposit(p: Profile): number
	local moved = 0
	for id, n in p.bag do
		local free = Inventory.storageFree(p)
		local m = math.min(n, free)
		if m > 0 then
			p.storage[id] = (p.storage[id] or 0) + m
			p.bag[id] = n - m
			if p.bag[id] <= 0 then
				p.bag[id] = nil
			end
			moved += m
		end
	end
	Inventory.flushPending(p)
	return moved
end

-- Gözləyən materialları çantaya (yer varsa) və sonra anbara keçirir.
function Inventory.flushPending(p: Profile)
	for id, n in p.pending do
		local fit = math.max(0, math.min(n, Inventory.bagFree(p), Constants.STACK_MAX - (p.bag[id] or 0)))
		if fit > 0 then
			p.bag[id] = (p.bag[id] or 0) + fit
		end
		local rest = n - fit
		if rest > 0 then
			local s = math.min(rest, Inventory.storageFree(p))
			if s > 0 then
				p.storage[id] = (p.storage[id] or 0) + s
				rest -= s
			end
		end
		if rest > 0 then
			p.pending[id] = rest
		else
			p.pending[id] = nil
		end
	end
end

return Inventory
