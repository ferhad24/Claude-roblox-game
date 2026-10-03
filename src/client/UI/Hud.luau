--!strict
-- HUD (bölmə 17): yuxarı solda damğa, güc və XP; yuxarı sağda əsas tapşırıq; aşağıda 4 alət yuvası;
-- çanta və su yalnız əlaqəli olanda görünür; mükafat bildirişi 1,5 s, eyni işdə birləşdirilir.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local ToolDefs = require(Shared.Defs.ToolDefs)
local QuestDefs = require(Shared.Defs.QuestDefs)
local Catalog = require(Shared.Core.Catalog)
local Net = require(script.Parent.Parent.Net)
local Lang = require(script.Parent.Parent.Lang)
local Kit = require(script.Parent.Kit)

local Hud = {}

local frame: Frame
local coinsLabel: TextLabel
local powerLabel: TextLabel
local xpFill: Frame
local questTitle: TextLabel
local questText: TextLabel
local sideList: Frame
local hotbar: Frame
local slotButtons: { TextButton } = {}
local bagBox: Frame
local bagLabel: TextLabel
local cupLabel: TextLabel
local pendingLabel: TextLabel
local toastBox: Frame
local workBar: Frame
local workFill: Frame
local testBanner: TextLabel
local menuBar: Frame

local showWaterUntil = 0
local toasts: { { key: string, text: string, label: TextLabel, expires: number, count: number } } = {}

Hud.onMenu = nil :: ((string) -> ())?
Hud.onSlot = nil :: ((number) -> ())?

local function fmtCoins(n: number): string
	return "◆ " .. tostring(n)
end

function Hud.toast(key: string, params: { [string]: any }?, isError: boolean?)
	local text = Lang.t(key, params)
	local now = os.clock()
	-- Eyni bildirişi birləşdir
	for _, t in toasts do
		if t.text == text and t.expires > now then
			t.count += 1
			t.expires = now + Constants.TOAST_SECONDS
			t.label.Text = if t.count > 1 then (text .. "  ×" .. t.count) else text
			return
		end
	end
	local label = Kit.label(
		toastBox,
		text,
		{ raw = true, textSize = 18, bold = true, align = Enum.TextXAlignment.Center, auto = Enum.AutomaticSize.Y }
	)
	label.BackgroundTransparency = 0.2
	label.BackgroundColor3 = if isError then Kit.colors.terracotta else Kit.colors.bg
	label.Size = UDim2.new(1, 0, 0, 30)
	Kit.corner(label, 8)
	Kit.padding(label, 4)
	table.insert(toasts, { key = key, text = text, label = label, expires = now + Constants.TOAST_SECONDS, count = 1 })
	while #toasts > 4 do
		local old = table.remove(toasts, 1)
		if old then
			old.label:Destroy()
		end
	end
end

function Hud.update(dt: number)
	local now = os.clock()
	for i = #toasts, 1, -1 do
		local t = toasts[i]
		if t.expires <= now then
			t.label:Destroy()
			table.remove(toasts, i)
		end
	end
	local _ = dt
end

function Hud.showWater(seconds: number)
	showWaterUntil = os.clock() + seconds
end

local function render(s: { [string]: any })
	coinsLabel.Text = fmtCoins(s.coins)
	powerLabel.Text = Lang.t("ui.power") .. " " .. tostring(s.power)
	local need = s.xpNeed
	xpFill.Size = UDim2.fromScale(if need > 0 then math.clamp(s.xpInLevel / need, 0, 1) else 1, 1)

	-- Tapşırıq izləyicisi
	local q = s.quest
	if q then
		local ch = QuestDefs.chapters[q.chapter]
		questTitle.Text = Lang.t("ui.chapter", { n = q.chapter }) .. " · " .. Lang.t(ch and ch.titleKey or "")
		questText.Text = Lang.t(q.textKey, { done = q.done, total = q.total })
	elseif s.finalCompleted then
		questTitle.Text = Lang.t("ui.final.title")
		questText.Text = Lang.t("ui.final.msg")
	end
	Kit.clear(sideList)
	local shown = 0
	for _, side in s.sides or {} do
		if not side.finished and shown < 2 and side.done < side.total then
			shown += 1
			Kit.label(
				sideList,
				"• " .. Lang.t(side.textKey),
				{ raw = true, textSize = 15, color = Kit.colors.moss, auto = Enum.AutomaticSize.Y, order = shown }
			)
		end
	end

	-- Alət yuvaları
	for i, btn in slotButtons do
		local toolId = s.hotbar[i]
		local def = toolId and ToolDefs.byId[toolId]
		if def then
			btn.Text = tostring(i) .. "  " .. Lang.t(def.nameKey)
			btn.BackgroundColor3 = if s.equipped == toolId then Kit.colors.leaf else Kit.colors.bgSoft
			btn.Visible = true
		else
			btn.Text = tostring(i)
			btn.BackgroundColor3 = Kit.colors.bgSoft
			btn.Visible = true
		end
	end

	-- Çanta və su: yalnız lazım olanda
	local bagFull = s.bagUsed >= s.bagCapacity
	local hasPending = next(s.pending) ~= nil
	local equippedDef = s.equipped and ToolDefs.byId[s.equipped]
	local holdingCup = equippedDef ~= nil and equippedDef.cup ~= nil
	local showBag = bagFull or hasPending or s.bagUsed >= s.bagCapacity * 0.75 or s.work ~= nil
	local showCup = holdingCup or os.clock() < showWaterUntil
	bagBox.Visible = showBag or showCup
	bagLabel.Visible = showBag
	bagLabel.Text = Lang.t("ui.bag") .. " " .. Lang.t("ui.capacity", { n = s.bagUsed, max = s.bagCapacity })
	bagLabel.TextColor3 = if bagFull then Kit.colors.accent else Kit.colors.text
	cupLabel.Visible = showCup
	cupLabel.Text = Lang.t("ui.water") .. " " .. Lang.t("ui.capacity", { n = s.cup, max = s.cupCapacity })
	if hasPending then
		local parts = {}
		for id, n in s.pending do
			table.insert(parts, tostring(n) .. " " .. Lang.t(Catalog.nameKey(id)))
		end
		pendingLabel.Visible = true
		pendingLabel.Text = Lang.t("msg.bagFull") .. "\n" .. Lang.t("ui.pending", { list = table.concat(parts, ", ") })
	else
		pendingLabel.Visible = false
	end

	-- İş irəliləyişi
	if s.work then
		workBar.Visible = true
		workFill.Size = UDim2.fromScale(math.clamp(s.work.progress, 0, 1), 1)
	else
		workBar.Visible = false
	end
end

function Hud.setWorkProgress(progress: number?, active: boolean)
	if active and progress then
		workBar.Visible = true
		workFill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
	else
		workBar.Visible = false
	end
end

function Hud.setTestMode(on: boolean)
	testBanner.Visible = on
end

function Hud.setVisible(on: boolean)
	frame.Visible = on
end

function Hud.init(rootGui: ScreenGui)
	frame = Kit.frame(rootGui, { name = "HUD", transparency = 1, radius = 0 })

	-- Yuxarı sol: damğa, güc, XP
	local stats = Kit.frame(
		frame,
		{ name = "Stats", size = UDim2.fromOffset(220, 74), pos = UDim2.fromOffset(12, 12), transparency = 0.25 }
	)
	Kit.padding(stats, 8)
	coinsLabel = Kit.label(
		stats,
		fmtCoins(0),
		{ raw = true, textSize = 22, bold = true, color = Kit.colors.accent, size = UDim2.new(1, 0, 0, 26) }
	)
	powerLabel = Kit.label(
		stats,
		"",
		{ raw = true, textSize = 16, size = UDim2.new(1, 0, 0, 20), pos = UDim2.fromOffset(0, 28) }
	)
	local xpBar = Kit.frame(
		stats,
		{ size = UDim2.new(1, 0, 0, 8), pos = UDim2.fromOffset(0, 50), color = Kit.colors.bgSoft, radius = 4 }
	)
	xpFill = Kit.frame(xpBar, { size = UDim2.fromScale(0, 1), color = Kit.colors.moss, radius = 4 })

	-- Yuxarı sağ: əsas tapşırıq
	local quest = Kit.frame(frame, {
		name = "Quest",
		size = UDim2.fromOffset(340, 0),
		pos = UDim2.new(1, -12, 0, 12),
		anchor = Vector2.new(1, 0),
		transparency = 0.25,
		auto = Enum.AutomaticSize.Y,
	})
	Kit.padding(quest, 10)
	Kit.list(quest, false, 4)
	questTitle = Kit.label(
		quest,
		"",
		{ raw = true, textSize = 15, color = Kit.colors.moss, bold = true, order = 1, auto = Enum.AutomaticSize.Y }
	)
	questText = Kit.label(quest, "", { raw = true, textSize = 19, bold = true, order = 2, auto = Enum.AutomaticSize.Y })
	sideList = Kit.frame(quest, {
		name = "Sides",
		size = UDim2.new(1, 0, 0, 0),
		transparency = 1,
		auto = Enum.AutomaticSize.Y,
		order = 3,
		radius = 0,
	})
	Kit.list(sideList, false, 2)

	-- Menyu düymələri (sağda, tapşırığın altında)
	menuBar = Kit.frame(frame, {
		name = "Menu",
		size = UDim2.fromOffset(0, 48),
		pos = UDim2.new(1, -12, 0, 150),
		anchor = Vector2.new(1, 0),
		transparency = 1,
		auto = Enum.AutomaticSize.X,
		radius = 0,
	})
	Kit.list(menuBar, true, 6)
	local menus = {
		{ "inventory", "ui.inventory" },
		{ "map", "ui.map" },
		{ "quests", "ui.quests" },
		{ "settings", "ui.settings" },
		{ "pause", "ui.pause" },
		{ "home", "ui.home" },
	}
	for i, m in menus do
		Kit.button(menuBar, m[2], function()
			if Hud.onMenu then
				Hud.onMenu(m[1])
			end
		end, { style = "soft", size = UDim2.fromOffset(0, 48), auto = Enum.AutomaticSize.X, textSize = 15, order = i })
	end
	for _, b in menuBar:GetChildren() do
		if b:IsA("TextButton") then
			Kit.padding(b, 8)
		end
	end

	-- Aşağı: 4 alət yuvası
	hotbar = Kit.frame(frame, {
		name = "Hotbar",
		size = UDim2.fromOffset(0, 56),
		pos = UDim2.new(0.5, 0, 1, -12),
		anchor = Vector2.new(0.5, 1),
		transparency = 1,
		auto = Enum.AutomaticSize.X,
		radius = 0,
	})
	Kit.list(hotbar, true, 6)
	for i = 1, 4 do
		local b = Kit.button(hotbar, tostring(i), function()
			if Hud.onSlot then
				Hud.onSlot(i)
			end
		end, { raw = true, style = "soft", size = UDim2.fromOffset(150, 52), textSize = 14, order = i })
		table.insert(slotButtons, b)
	end

	-- İş irəliləyişi
	workBar = Kit.frame(frame, {
		name = "WorkBar",
		size = UDim2.fromOffset(240, 12),
		pos = UDim2.new(0.5, 0, 1, -82),
		anchor = Vector2.new(0.5, 1),
		color = Kit.colors.bgSoft,
		radius = 6,
	})
	workFill = Kit.frame(workBar, { size = UDim2.fromScale(0, 1), color = Kit.colors.accent, radius = 6 })
	workBar.Visible = false

	-- Çanta və su (kontekstual)
	bagBox = Kit.frame(frame, {
		name = "Bag",
		size = UDim2.fromOffset(200, 0),
		pos = UDim2.new(0, 12, 1, -12),
		anchor = Vector2.new(0, 1),
		transparency = 0.25,
		auto = Enum.AutomaticSize.Y,
	})
	Kit.padding(bagBox, 8)
	Kit.list(bagBox, false, 2)
	bagLabel = Kit.label(bagBox, "", { raw = true, textSize = 16, order = 1, auto = Enum.AutomaticSize.Y })
	cupLabel = Kit.label(
		bagBox,
		"",
		{ raw = true, textSize = 16, order = 2, color = Kit.colors.dew, auto = Enum.AutomaticSize.Y }
	)
	bagBox.Visible = false

	pendingLabel = Kit.label(frame, "", {
		raw = true,
		textSize = 16,
		bold = true,
		color = Kit.colors.accent,
		size = UDim2.fromOffset(360, 0),
		pos = UDim2.new(0.5, 0, 0, 12),
		anchor = Vector2.new(0.5, 0),
		auto = Enum.AutomaticSize.Y,
		align = Enum.TextXAlignment.Center,
	})
	pendingLabel.BackgroundTransparency = 0.25
	pendingLabel.BackgroundColor3 = Kit.colors.bg
	Kit.corner(pendingLabel, 8)
	Kit.padding(pendingLabel, 6)
	pendingLabel.Visible = false

	-- Bildirişlər
	toastBox = Kit.frame(frame, {
		name = "Toasts",
		size = UDim2.fromOffset(380, 0),
		pos = UDim2.new(0.5, 0, 0, 80),
		anchor = Vector2.new(0.5, 0),
		transparency = 1,
		auto = Enum.AutomaticSize.Y,
		radius = 0,
	})
	Kit.list(toastBox, false, 4, Enum.HorizontalAlignment.Center)

	testBanner = Kit.label(frame, "ui.testMode", {
		textSize = 13,
		color = Kit.colors.accent,
		size = UDim2.fromOffset(420, 18),
		pos = UDim2.new(0.5, 0, 1, -76),
		anchor = Vector2.new(0.5, 1),
		align = Enum.TextXAlignment.Center,
	})
	testBanner.Visible = false

	Net.StateChanged:Connect(render)
	Lang.Changed:Connect(function()
		if Net.state then
			render(Net.state)
		end
	end)
	if Net.state then
		render(Net.state)
	end
end

return Hud
