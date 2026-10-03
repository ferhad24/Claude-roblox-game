--!nocheck
-- Balans auditi (bölmə 8, 26): rəqəmlər birbaşa konfiqurasiyadan hesablanır, sənəddəki təxminlərdən deyil.
-- İşlətmək: lune run tools/balance_report.luau [docs/BALANCE.md]
local fs = require("@lune/fs")
local process = require("@lune/process")
local H = require("../tests/harness")

local Catalog = H.require("src/shared/Core/Catalog")
local Progression = H.require("src/shared/Core/Progression")
local Layout = Catalog.Layout
local Q = Catalog.Quests

local out = {}
local function line(s)
	table.insert(out, s or "")
end

-- Hər fəslin sonuna qədər açıq olan zonalar: fəsil N bitəndə Z(N+1) açılır
local chapterZone = { "Z01", "Z02", "Z03", "Z04", "Z05", "Z06" }

-- Birdəfəlik mükafatlar zona üzrə
local zoneCoins, zoneXp, zoneObjs = {}, {}, {}
for _, z in chapterZone do
	zoneCoins[z], zoneXp[z], zoneObjs[z] = 0, 0, 0
end
for _, obj in Layout.objects do
	if obj.kind == "work" then
		local def = Catalog.Work.workById[obj.def]
		zoneCoins[obj.zone] += def.coins
		zoneXp[obj.zone] += def.xp
		zoneObjs[obj.zone] += 1
	elseif obj.kind == "consumer" then
		local def = Catalog.Work.consumerById[obj.def]
		zoneCoins[obj.zone] += def.coins
		zoneXp[obj.zone] += def.xp
		zoneObjs[obj.zone] += 1
	end
end
local sideCoins, sideXp = {}, {}
for _, z in chapterZone do
	sideCoins[z], sideXp[z] = 0, 0
end
for _, s in Q.sideTasks do
	-- Z06 əlavə işlərindən yalnız xatirə finaldan əvvəl mümkündür
	-- Z06: finaldan əvvəl yalnız xatirə və qısa yol mümkündür (ulduz çiçəyi finaldan sonra açılır)
	if not (s.zone == "Z06" and s.id == "S6_STAR") then
		sideCoins[s.zone] += s.reward.coins
		sideXp[s.zone] += s.reward.xp
	end
end

-- Məcburi alışlar: hansı fəsildə ilk dəfə alına bilər / lazım olur.
-- Şərt fəsil N-in sonunda ödənirsə (məs. növbəti zona açılır), alış fəsil N+1-də baş verir.
local purchases = {}
local function addPurchase(ch, id, price, gate)
	table.insert(purchases, { ch = ch, id = id, price = price, gate = gate })
end
local stepCh = Q.stepChapter
local function firstChapterFor(order: number): number
	for _, chap in Q.chapters do
		if Catalog.chapterEndOrder(chap.chapter) > order then
			-- Şərt bu fəslin daxilində (və ya əvvəlki fəslin sonunda) ödənir
			return chap.chapter
		end
	end
	return 6
end
for _, t in Catalog.Tools.list do
	if t.mandatory then
		local gateCh = nil
		for _, chap in Q.chapters do
			for _, step in chap.steps do
				if step.objective.type == "ownTool" and step.objective.tool == t.id then
					gateCh = chap.chapter
				end
			end
		end
		-- Alət addım kimi tələb olunmasa da, məcburi addımdakı obyekti yalnız bu ailə işləyə bilirsə keçiddir
		for _, chap in Q.chapters do
			for _, step in chap.steps do
				if step.objective.type == "restore" then
					for _, id in step.objective.ids do
						local obj = Layout.byId[id]
						local wdef = obj and obj.kind == "work" and Catalog.Work.workById[obj.def]
						if wdef and (t.rates :: any)[wdef.workType] and t.tier == 1 then
							local others = false
							for _, o in Catalog.Tools.list do
								if o.family ~= t.family and (o.rates :: any)[wdef.workType] then
									others = true
								end
							end
							if not others and (gateCh == nil or chap.chapter < gateCh) then
								gateCh = chap.chapter
							end
						end
					end
				end
			end
		end
		-- Mişar: Q1_PLANKS üçün budaq işi (lövhə → çarx) yalnız mişarla mümkündür
		if t.id == "TOOL_SAW_1" and gateCh == nil then
			gateCh = 1
		end
		addPurchase(gateCh or firstChapterFor(Catalog.conditionOrder(t.unlock)), t.id, t.price, gateCh ~= nil)
	end
end
for _, b in Catalog.Shop.bagUpgrades do
	addPurchase(firstChapterFor(Catalog.conditionOrder(b.unlock)), b.id, b.price, false)
end
for _, g in Catalog.Recipes.groups do
	if not g.free then
		addPurchase(stepCh[g.unlock.step], g.id, g.keyPrice, true)
	end
end
table.sort(purchases, function(a, b)
	if a.ch == b.ch then
		return a.id < b.id
	end
	return a.ch < b.ch
end)

local total, gateTotal = 0, 0
for _, pch in purchases do
	total += pch.price
	if pch.gate then
		gateTotal += pch.price
	end
end

line("# Balans hesabatı (avtomatik)")
line("")
line("Bu fayl `lune run tools/balance_report.luau docs/BALANCE.md` ilə konfiqurasiyadan yaradılır.")
line("Rəqəmlər dizayn məlumatlarının hesabıdır, ölçülmüş oyun vaxtı deyil.")
line("")
line("## Məcburi alışlar")
line("")
line("“Keçid” sütunu: alış olmadan kampaniya irəliləmir (addım və ya iş tələbi). Qalanları sənədin")
line("məcburi büdcəsinə (3 650) daxildir, amma oyun onları tələb etmir (rahatlıq alətləri, çanta).")
line("")
line("| Fəsil | ID | Qiymət | Keçid |")
line("|---:|---|---:|:---:|")
for _, pch in purchases do
	line(("| %d | %s | %d | %s |"):format(pch.ch, pch.id, pch.price, if pch.gate then "✓" else "—"))
end
line(("| | **Cəmi (sənəd büdcəsi)** | **%d** | |"):format(total))
line(("| | **Cəmi (yalnız keçid üçün)** | **%d** | |"):format(gateTotal))
line("")

line("## Zəmanətli gəlir və XP (təkrar iş və sifarişsiz)")
line("")
line(
	"Fərz: oyunçu açıq sahələrdəki bütün birdəfəlik obyektləri və əlavə işləri bitirir (Z06 əlavə işlərindən yalnız xatirə)."
)
line("")
line(
	"| Fəsil | Fəsil mükafatı | Obyektlər (damğa/XP) | Əlavə işlər (damğa/XP) | Məcburi alışlar | Damğa balansı (kumulyativ) | XP (kumulyativ) | Güc |"
)
line("|---:|---:|---:|---:|---:|---:|---:|---:|")
local cumCoins, cumXp, cumSpend, cumGate = 0, 100, 0, 0 -- 100 XP tutorial bonusu
local powerAt = {}
local shortfalls = {}
local gateShortfalls = {}
for _, chap in Q.chapters do
	local z = chap.zone
	local spend, gateSpend = 0, 0
	for _, pch in purchases do
		if pch.ch == chap.chapter then
			spend += pch.price
			if pch.gate then
				gateSpend += pch.price
			end
		end
	end
	cumCoins += zoneCoins[z] + sideCoins[z]
	cumXp += zoneXp[z] + sideXp[z]
	cumSpend += spend
	cumGate += gateSpend
	local balanceBeforeReward = cumCoins - cumSpend
	if balanceBeforeReward < 0 then
		shortfalls[chap.chapter] = -balanceBeforeReward
	end
	if cumCoins - cumGate < 0 then
		gateShortfalls[chap.chapter] = -(cumCoins - cumGate)
	end
	cumCoins += chap.reward.coins
	cumXp += chap.reward.xp
	local power = Progression.levelFor(cumXp)
	powerAt[chap.chapter] = { xp = cumXp, power = power }
	line(
		("| %d | %d / %d | %d / %d | %d / %d | %d | %d | %d | %d |"):format(
			chap.chapter,
			chap.reward.coins,
			chap.reward.xp,
			zoneCoins[z],
			zoneXp[z],
			sideCoins[z],
			sideXp[z],
			spend,
			cumCoins - cumSpend,
			cumXp,
			power
		)
	)
end
line("")
line(
	"Damğa balansı sütunu fəsil mükafatı alındıqdan sonrakı vəziyyətdir (sənəd büdcəsinin hamısı alınırsa)."
)
line("Fəsil daxilində, fəsil mükafatından əvvəl təkrar iş/sifarişlə qazanılmalı olan məbləğ:")
line("")
line("| Fəsil | Bütün sənəd büdcəsi alınırsa | Yalnız keçid alışları |")
line("|---:|---:|---:|")
for ch = 1, 6 do
	line(("| %d | %d | %d |"):format(ch, shortfalls[ch] or 0, gateShortfalls[ch] or 0))
end
line("")

-- Güc tələbləri
line("## Güc tələbləri")
line("")
line("| Tələb | Güc | Lazım XP | Zəmanətli XP (əvvəlki fəslin sonu) | Fərq |")
line("|---|---:|---:|---:|---:|")
local reqs = {
	{ "Yüngül daş (Z01, çarx üçün çınqıl)", 4, 1 },
	{ "Torpaq tıxacı (Z03)", 5, 2 },
	{ "Ling (Z04)", 7, 3 },
	{ "Şüşə panel (Z05)", 8, 4 },
	{ "Kök qayçısı (Z06)", 15, 5 },
}
local gapTo15 = 0
for _, r in reqs do
	local need = Progression.totalXpFor(r[2])
	local have = if r[3] == 1 then 100 + zoneXp.Z01 else powerAt[r[3]].xp
	local gap = need - have
	if r[2] == 15 then
		gapTo15 = gap
	end
	line(
		("| %s | %d | %d | %d | %s |"):format(
			r[1],
			r[2],
			need,
			have,
			if gap > 0 then ("**−%d**"):format(gap) else "✓"
		)
	)
end
line("")
line("Qeyd: Z01 sətrində XP fəsil 1 daxilindədir (tutorial + Z01 obyektləri), fəsil mükafatı daxil deyil.")
line("")

-- Təkrar iş sürəti (sifarişlər və yuvalar)
line("## Təkrar iş nümunələri (bölmə 14)")
line("")
line("| Sifariş | İstək | Damğa | XP |")
line("|---|---|---:|---:|")
for _, o in Q.orders do
	line(("| %s | %d %s | %d | %d |"):format(o.id, o.wants.n, o.wants.id, o.coins, o.xp))
end
line("")
line(
	("Yenilənən yuva: hər yuva %d s aktiv oyundan sonra yenidən resurs verir."):format(
		H.require("src/shared/Constants").RESPAWN_SECONDS
	)
)
line("")

local text = table.concat(out, "\n") .. "\n"
local target = process.args[1]
if target then
	fs.writeFile(target, text)
	print("Yazıldı: " .. target)
end
print(text)
return {
	gapTo15 = gapTo15,
	total = total,
	gateTotal = gateTotal,
	powerAt = powerAt,
	shortfalls = shortfalls,
	gateShortfalls = gateShortfalls,
}
