--!strict
-- Ekranlar (bölmə 17): İnventar, Emalatxana, Dükan, Bağ xəritəsi, Tapşırıqlar, Bitki kitabı,
-- Xatirələr, Nailiyyətlər, Əlavə iş lövhəsi, Ayarlar, Pauza. Eyni anda bir panel açıq olur.
-- Bütün alış/craft sorğuları serverə yalnız ID ilə gedir; nəticəni server hesablayır.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local ItemDefs = require(Shared.Defs.ItemDefs)
local ToolDefs = require(Shared.Defs.ToolDefs)
local BuildDefs = require(Shared.Defs.BuildDefs)
local RecipeDefs = require(Shared.Defs.RecipeDefs)
local PlantDefs = require(Shared.Defs.PlantDefs)
local ShopDefs = require(Shared.Defs.ShopDefs)
local ZoneDefs = require(Shared.Defs.ZoneDefs)
local QuestDefs = require(Shared.Defs.QuestDefs)
local Layout = require(Shared.Layout)
local Catalog = require(Shared.Core.Catalog)
local Conditions = require(Shared.Core.Conditions)
local Net = require(script.Parent.Parent.Net)
local Lang = require(script.Parent.Parent.Lang)
local Kit = require(script.Parent.Kit)

local Panels = {}

type State = { [string]: any }

local rootGui: ScreenGui
local window: Frame
local titleLabel: TextLabel
local tabsBar: Frame
local body: ScrollingFrame
local current: string? = nil
local currentTab: { [string]: string } = {}
local confirmedDecor: { [string]: boolean } = {}
local modal: Frame? = nil
local pausedByPanel = false

Panels.onPlaceBuild = nil :: ((string) -> ())?
Panels.onReplayFinal = nil :: (() -> ())?
Panels.onPauseChanged = nil :: ((boolean) -> ())?
Panels.onSettingsChanged = nil :: ((string, any) -> ())?
Panels.onClosed = nil :: ((string) -> ())?

local renderers: { [string]: (State) -> () } = {}
local openPanel: (string, string?) -> () -- Panels.open sonradan təyin olunur
local tabsFor: { [string]: { { string } } } = {}

------------------------------------------------------------------------------------------
-- Köməkçilər
------------------------------------------------------------------------------------------

local function nameOf(id: string): string
	return Lang.t(Catalog.nameKey(id))
end

local function colorOf(id: string): Color3
	local item = ItemDefs.byId[id]
	if item then
		return Color3.fromRGB(item.color[1], item.color[2], item.color[3])
	end
	local tool = ToolDefs.byId[id]
	if tool then
		return Color3.fromRGB(tool.color[1], tool.color[2], tool.color[3])
	end
	local b = BuildDefs.byId[id]
	if b then
		return Color3.fromRGB(b.color[1], b.color[2], b.color[3])
	end
	return Kit.colors.moss
end

local function condText(s: State, cond: any): string
	-- Snapshot profil kimi istifadə olunur (eyni sahə adları)
	local unmet = Conditions.firstUnmet(s :: any, cond)
	if not unmet then
		return ""
	end
	if unmet.kind == "step" then
		local step = QuestDefs.stepById[unmet.step]
		return Lang.t("cond.step", { step = step and Lang.t(step.textKey, { done = "", total = "" }) or unmet.step })
	elseif unmet.kind == "chapter" then
		return Lang.t("cond.chapter", { n = unmet.chapter })
	elseif unmet.kind == "power" then
		return Lang.t("cond.power", { n = unmet.value })
	elseif unmet.kind == "zone" then
		return Lang.t("cond.zone", { zone = "zone." .. unmet.zone })
	elseif unmet.kind == "final" then
		return Lang.t("cond.final")
	end
	return ""
end

-- Snapshot Conditions modulu üçün profil kimi işləyir: quest.done və zones lazımdır
local function asProfile(s: State): any
	return {
		quest = { done = s.questDone or {}, chapter = s.quest and s.quest.chapter or 7 },
		zones = s.zones or {},
		workXP = s.xp or 0,
		finalCompleted = s.finalCompleted,
	}
end

local function row(parent: Instance, order: number, height: number?): Frame
	local r = Kit.frame(parent, {
		size = UDim2.new(1, -8, 0, height or 56),
		color = Kit.colors.bgSoft,
		order = order,
		auto = Enum.AutomaticSize.Y,
	})
	Kit.padding(r, 6)
	return r
end

local function rowText(r: Frame, title: string, sub: string?, iconColor: Color3?, symbol: string?)
	local x = 0
	if iconColor then
		local icon = Kit.icon(r, iconColor, symbol or "•", 36)
		icon.Position = UDim2.fromOffset(0, 4)
		x = 44
	end
	local holder = Kit.frame(r, {
		size = UDim2.new(1, -(x + 160), 0, 0),
		pos = UDim2.fromOffset(x, 0),
		transparency = 1,
		auto = Enum.AutomaticSize.Y,
		radius = 0,
	})
	Kit.list(holder, false, 2)
	Kit.label(holder, title, { raw = true, bold = true, textSize = 17, auto = Enum.AutomaticSize.Y, order = 1 })
	if sub and sub ~= "" then
		Kit.label(
			holder,
			sub,
			{ raw = true, textSize = 14, color = Kit.colors.moss, auto = Enum.AutomaticSize.Y, order = 2 }
		)
	end
end

local function rowButton(
	r: Frame,
	text: string,
	onClick: () -> (),
	style: string?,
	disabled: boolean?,
	params: { [string]: any }?
): TextButton
	return Kit.button(r, text, onClick, {
		style = style,
		disabled = disabled,
		params = params,
		size = UDim2.fromOffset(150, 48),
		pos = UDim2.new(1, 0, 0, 0),
		anchor = Vector2.new(1, 0),
		textSize = 15,
	})
end

local function section(title: string, order: number)
	local l = Kit.label(
		body,
		title,
		{ bold = true, textSize = 18, color = Kit.colors.accent, order = order, auto = Enum.AutomaticSize.Y }
	)
	l.Size = UDim2.new(1, -8, 0, 26)
end

local function feedback(result: any)
	-- Xətalar HUD-a Net.Result vasitəsilə gedir
	local _ = result
end

local function showConfirm(text: string, onYes: () -> ())
	if modal then
		modal:Destroy()
	end
	local m = Kit.frame(rootGui, {
		name = "Confirm",
		size = UDim2.fromOffset(360, 0),
		pos = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		auto = Enum.AutomaticSize.Y,
	})
	m.ZIndex = 20
	Kit.padding(m, 14)
	Kit.list(m, false, 10, Enum.HorizontalAlignment.Center)
	Kit.label(
		m,
		text,
		{ raw = true, textSize = 18, align = Enum.TextXAlignment.Center, auto = Enum.AutomaticSize.Y, order = 1 }
	)
	local buttons = Kit.frame(m, { size = UDim2.new(1, 0, 0, 48), transparency = 1, order = 2, radius = 0 })
	Kit.list(buttons, true, 10, Enum.HorizontalAlignment.Center)
	Kit.button(buttons, "ui.confirm", function()
		m:Destroy()
		modal = nil
		onYes()
	end, { order = 1 })
	Kit.button(buttons, "ui.cancel", function()
		m:Destroy()
		modal = nil
	end, { style = "soft", order = 2 })
	modal = m
end
Panels.showConfirm = showConfirm

------------------------------------------------------------------------------------------
-- İnventar
------------------------------------------------------------------------------------------

tabsFor.inventory = {
	{ "bag", "ui.bag" },
	{ "builds", "ui.builds" },
	{ "seeds", "ui.seeds" },
	{ "tools", "ui.tools" },
	{ "campaign", "ui.campaign" },
}

renderers.inventory = function(s)
	local tab = currentTab.inventory or "bag"
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	if tab == "bag" then
		section(Lang.t("ui.bag") .. " " .. Lang.t("ui.capacity", { n = s.bagUsed, max = s.bagCapacity }), nextOrder())
		local any = false
		for _, item in ItemDefs.list do
			local n = s.bag[item.id]
			if n then
				any = true
				local r = row(body, nextOrder())
				rowText(r, nameOf(item.id), "×" .. tostring(n), colorOf(item.id), Kit.symbolFor(item.id))
			end
		end
		if not any then
			Kit.label(body, "ui.empty", { textSize = 15, color = Kit.colors.muted, order = nextOrder() })
		end
		if next(s.pending) ~= nil then
			section(Lang.t("ui.pendingTitle"), nextOrder())
			for id, n in s.pending do
				local r = row(body, nextOrder())
				rowText(r, nameOf(id), "×" .. tostring(n), colorOf(id), Kit.symbolFor(id))
			end
		end
		section(
			Lang.t("ui.storage") .. " " .. Lang.t("ui.capacity", { n = s.storageUsed, max = s.storageCapacity }),
			nextOrder()
		)
		for _, item in ItemDefs.list do
			local n = s.storage[item.id]
			if n then
				local r = row(body, nextOrder())
				rowText(r, nameOf(item.id), "×" .. tostring(n), colorOf(item.id), Kit.symbolFor(item.id))
			end
		end
		section(Lang.t("ui.homeWater", { n = s.homeWater, max = Constants.HOME_WATER_CAPACITY }), nextOrder())
	elseif tab == "builds" then
		local any = false
		for _, def in BuildDefs.list do
			local n = s.buildInv[def.id]
			if n and n > 0 then
				any = true
				local r = row(body, nextOrder())
				rowText(r, Lang.t(def.nameKey), "×" .. tostring(n), colorOf(def.id), Kit.symbolFor(def.id))
				if not def.socketOnly then
					rowButton(r, "ui.place", function()
						Panels.close()
						if Panels.onPlaceBuild then
							Panels.onPlaceBuild(def.id)
						end
					end)
				else
					Kit.label(r, "ui.socketHint", {
						textSize = 13,
						color = Kit.colors.moss,
						size = UDim2.fromOffset(150, 48),
						pos = UDim2.new(1, 0, 0, 0),
						anchor = Vector2.new(1, 0),
					})
				end
			end
		end
		if not any then
			Kit.label(body, "ui.empty", { textSize = 15, color = Kit.colors.muted, order = nextOrder() })
		end
	elseif tab == "seeds" then
		local any = false
		for _, plant in PlantDefs.list do
			local n = s.seeds[plant.seedId]
			if n and n > 0 then
				any = true
				local r = row(body, nextOrder())
				rowText(
					r,
					nameOf(plant.seedId),
					"×" .. tostring(n) .. " · " .. Lang.t("ui.plantHint"),
					colorOf(plant.seedId),
					Kit.symbolFor(plant.seedId)
				)
			end
		end
		if not any then
			Kit.label(body, "ui.empty", { textSize = 15, color = Kit.colors.muted, order = nextOrder() })
		end
	elseif tab == "tools" then
		for _, def in ToolDefs.list do
			if s.tools[def.id] then
				local r = row(body, nextOrder())
				local rates = {}
				for wt, rate in def.rates :: any do
					table.insert(rates, ("%s %.1f/s"):format(Lang.t("worktype." .. wt), rate))
				end
				local extra = table.concat(rates, ", ")
				if def.cup then
					extra = Lang.t("ui.cupSpec", { n = def.cup.capacity })
				elseif def.cartCapacity then
					extra = Lang.t("ui.cartSpec", { n = def.cartCapacity })
				end
				rowText(r, Lang.t(def.nameKey), extra, colorOf(def.id), Kit.symbolFor(def.id))
				local slot = table.find(s.hotbar, def.id)
				rowButton(r, if slot then "ui.slotN" else "ui.assignSlot", function()
					local target = slot or math.min(#s.hotbar + 1, 4)
					Net.request("SetHotbar", { slot = target, tool = def.id }, feedback)
				end, "soft", false, { n = slot or "" })
			end
		end
	elseif tab == "campaign" then
		section(Lang.t("ui.badges"), nextOrder())
		for i = 1, 5 do
			local id = "BADGE_TREE_" .. i
			local r = row(body, nextOrder())
			local have = (s.campaign[id] or 0) > 0
			rowText(
				r,
				nameOf(id),
				if have then "✓" else Lang.t("ui.notFound"),
				if have then colorOf(id) else Kit.colors.bgSoft,
				tostring(i)
			)
		end
		local blooms = s.campaign["MAT_BLOOM"] or 0
		section(nameOf("MAT_BLOOM") .. " " .. tostring(blooms) .. "/5", nextOrder())
		if next(s.cargo) ~= nil then
			for id, n in s.cargo do
				local r = row(body, nextOrder())
				rowText(r, nameOf(id), "×" .. tostring(n), colorOf(id), Kit.symbolFor(id))
			end
		end
	end
end

------------------------------------------------------------------------------------------
-- Dükan (Usta Pıtır)
------------------------------------------------------------------------------------------

tabsFor.shop = { { "tools", "ui.tools" }, { "bag", "ui.bag" }, { "seeds", "ui.seeds" }, { "decor", "ui.decor" } }

local function buy(id: string, price: number, nameText: string, needsConfirm: boolean)
	if needsConfirm and not confirmedDecor[id] then
		showConfirm(Lang.t("ui.confirmBuy", { name = nameText, n = price }), function()
			confirmedDecor[id] = true
			Net.request("BuyItem", { id = id }, feedback)
		end)
		return
	end
	Net.request("BuyItem", { id = id }, feedback)
end

renderers.shop = function(s)
	local tab = currentTab.shop or "tools"
	local p = asProfile(s)
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	if tab == "tools" then
		for _, def in ToolDefs.list do
			if def.price > 0 then
				local r = row(body, nextOrder())
				local owned = false
				for id in s.tools do
					local t = ToolDefs.byId[id]
					if t and t.family == def.family and t.tier >= def.tier then
						owned = true
					end
				end
				local unlocked = Conditions.check(p, def.unlock)
				local sub = Lang.t("ui.price", { n = def.price })
				if not unlocked then
					sub = Lang.t("ui.unlockAt", { what = condText(p, def.unlock) })
				elseif s.power < def.minPower then
					sub = Lang.t("hint.needPower", { n = def.minPower }) .. " · " .. sub
				end
				rowText(r, Lang.t(def.nameKey), sub, colorOf(def.id), Kit.symbolFor(def.id))
				if owned then
					rowButton(r, "ui.owned", function() end, "soft", true)
				else
					local can = unlocked and s.coins >= def.price and s.power >= def.minPower
					rowButton(r, "ui.buy", function()
						buy(def.id, def.price, Lang.t(def.nameKey), false)
					end, "primary", not can)
				end
			end
		end
	elseif tab == "bag" then
		for _, bag in ShopDefs.bagUpgrades do
			local r = row(body, nextOrder())
			local unlocked = Conditions.check(p, bag.unlock)
			local owned = s.bagCapacity >= bag.capacity
			local sub = Lang.t("ui.price", { n = bag.price })
			if not unlocked then
				sub = Lang.t("ui.unlockAt", { what = condText(p, bag.unlock) })
			end
			rowText(r, Lang.t(bag.nameKey), sub, Kit.colors.earth, "B")
			if owned then
				rowButton(r, "ui.owned", function() end, "soft", true)
			else
				local can = unlocked and s.coins >= bag.price and s.bagCapacity == bag.requires
				rowButton(r, "ui.buy", function()
					buy(bag.id, bag.price, Lang.t(bag.nameKey), false)
				end, "primary", not can)
			end
		end
	elseif tab == "seeds" then
		for _, plant in PlantDefs.list do
			local r = row(body, nextOrder())
			local unlocked = Conditions.check(p, plant.unlock)
			local sub = Lang.t("ui.price", { n = plant.seedPrice }) .. " · ×" .. tostring(s.seeds[plant.seedId] or 0)
			if not unlocked then
				sub = Lang.t("ui.unlockAt", { what = condText(p, plant.unlock) })
			end
			rowText(r, nameOf(plant.seedId), sub, colorOf(plant.seedId), Kit.symbolFor(plant.seedId))
			local can = unlocked
				and s.coins >= plant.seedPrice
				and (s.seeds[plant.seedId] or 0) < Constants.SEED_STACK_MAX
			rowButton(r, "ui.buy", function()
				buy(plant.seedId, plant.seedPrice, nameOf(plant.seedId), false)
			end, "primary", not can)
		end
	elseif tab == "decor" then
		for _, d in ShopDefs.decor do
			if d.id ~= ShopDefs.finalRewardDecor then
				local r = row(body, nextOrder())
				local unlocked = Conditions.check(p, d.unlock)
				local sub = Lang.t("ui.price", { n = d.price })
				if not unlocked then
					sub = Lang.t("ui.unlockAt", { what = condText(p, d.unlock) })
				end
				rowText(r, Lang.t(d.nameKey), sub, colorOf(d.id), Kit.symbolFor(d.id))
				rowButton(r, "ui.buy", function()
					buy(d.id, d.price, Lang.t(d.nameKey), d.price >= Constants.EXPENSIVE_DECOR)
				end, "primary", not (unlocked and s.coins >= d.price))
			end
		end
	end
end

------------------------------------------------------------------------------------------
-- Emalatxana
------------------------------------------------------------------------------------------

tabsFor.workshop = { { "recipes", "ui.recipes" }, { "keys", "ui.keys" } }

local function amountsText(s: State, list: { any }, mult: number): (string, boolean)
	local parts = {}
	local all = true
	for _, a in list do
		local have = (s.bag[a.id] or 0) + (s.storage[a.id] or 0)
		local need = a.n * mult
		if have < need then
			all = false
		end
		table.insert(parts, ("%s %d/%d"):format(nameOf(a.id), have, need))
	end
	return table.concat(parts, " · "), all
end

renderers.workshop = function(s)
	local tab = currentTab.workshop or "recipes"
	local p = asProfile(s)
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	if tab == "recipes" then
		local anyGroup = false
		for _, g in RecipeDefs.groups do
			if s.groups[g.id] then
				anyGroup = true
				section(Lang.t(g.nameKey), nextOrder())
				for _, rid in g.recipes do
					local recipe = RecipeDefs.byId[rid]
					local r = row(body, nextOrder())
					local text, can = amountsText(s, recipe.inputs, 1)
					local outName = nameOf(recipe.output.id)
					rowText(r, outName, text, colorOf(recipe.output.id), Kit.symbolFor(recipe.output.id))
					local btns = Kit.frame(r, {
						size = UDim2.fromOffset(150, 48),
						pos = UDim2.new(1, 0, 0, 0),
						anchor = Vector2.new(1, 0),
						transparency = 1,
						radius = 0,
					})
					Kit.list(btns, true, 4)
					Kit.button(btns, "ui.craft", function()
						Net.request("Craft", { recipe = rid, count = 1 }, feedback)
					end, { disabled = not can, size = UDim2.fromOffset(90, 48), textSize = 14, order = 1 })
					local _, can5 = amountsText(s, recipe.inputs, 5)
					if not BuildDefs.byId[recipe.output.id] then
						Kit.button(btns, "×5", function()
							Net.request("Craft", { recipe = rid, count = 5 }, feedback)
						end, {
							raw = true,
							style = "soft",
							disabled = not can5,
							size = UDim2.fromOffset(56, 48),
							textSize = 14,
							order = 2,
						})
					end
				end
			end
		end
		if not anyGroup then
			Kit.label(
				body,
				"ui.workshopLocked",
				{ textSize = 16, color = Kit.colors.muted, order = nextOrder(), auto = Enum.AutomaticSize.Y }
			)
		end
	else
		for _, g in RecipeDefs.groups do
			if not g.free then
				local r = row(body, nextOrder())
				local unlocked = Conditions.check(p, g.unlock)
				local owned = s.groups[g.id] == true
				local sub = Lang.t("ui.price", { n = g.keyPrice })
				if not unlocked then
					sub = Lang.t("ui.unlockAt", { what = condText(p, g.unlock) })
				end
				rowText(r, Lang.t(g.nameKey), sub, Kit.colors.accent, "K")
				if owned then
					rowButton(r, "ui.owned", function() end, "soft", true)
				else
					rowButton(r, "ui.buy", function()
						Net.request("BuyItem", { id = g.id }, feedback)
					end, "primary", not (unlocked and s.coins >= g.keyPrice))
				end
			end
		end
	end
end

------------------------------------------------------------------------------------------
-- Əlavə iş lövhəsi
------------------------------------------------------------------------------------------

renderers.board = function(s)
	local o = s.orders
	if #o.offers == 0 then
		Kit.label(
			body,
			"ui.noOrders",
			{ textSize = 16, color = Kit.colors.muted, order = 1, auto = Enum.AutomaticSize.Y }
		)
		return
	end
	for i, id in o.offers do
		local def = QuestDefs.orderById[id]
		if def then
			local r = row(body, i)
			local have = (s.bag[def.wants.id] or 0) + (s.storage[def.wants.id] or 0)
			local title = ("%d %s"):format(def.wants.n, nameOf(def.wants.id))
			local sub = Lang.t("msg.reward", { coins = def.coins, xp = def.xp })
				.. (" · %d/%d"):format(have, def.wants.n)
			if o.active == id then
				sub = Lang.t("ui.active") .. " · " .. sub
			end
			rowText(r, title, sub, colorOf(def.wants.id), Kit.symbolFor(def.wants.id))
			local btns = Kit.frame(r, {
				size = UDim2.fromOffset(200, 48),
				pos = UDim2.new(1, 0, 0, 0),
				anchor = Vector2.new(1, 0),
				transparency = 1,
				radius = 0,
			})
			Kit.list(btns, true, 4)
			if o.active == id then
				Kit.button(btns, "ui.deliver", function()
					Net.request("DeliverOrder", { order = id }, feedback)
				end, { disabled = have < def.wants.n, size = UDim2.fromOffset(120, 48), textSize = 14, order = 1 })
			else
				Kit.button(btns, "ui.accept", function()
					Net.request("AcceptOrder", { order = id }, feedback)
				end, { size = UDim2.fromOffset(120, 48), textSize = 14, order = 1 })
				Kit.button(btns, "ui.reroll", function()
					Net.request("RerollOrder", { slot = i }, feedback)
				end, { style = "soft", size = UDim2.fromOffset(72, 48), textSize = 14, order = 2 })
			end
		end
	end
end

------------------------------------------------------------------------------------------
-- Tapşırıqlar
------------------------------------------------------------------------------------------

renderers.quests = function(s)
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local currentChapter = if s.quest then s.quest.chapter else 7
	for _, ch in QuestDefs.chapters do
		if ch.chapter <= currentChapter then
			section(Lang.t("ui.chapter", { n = ch.chapter }) .. " · " .. Lang.t(ch.titleKey), nextOrder())
			for _, step in ch.steps do
				local done = s.questDone[step.id] == true
				local isCurrent = s.quest and s.quest.stepId == step.id
				if done or isCurrent then
					local text = Lang.t(step.textKey, {
						done = if isCurrent then s.quest.done else "✓",
						total = if isCurrent then s.quest.total else "✓",
					})
					Kit.label(body, (if done then "✓ " else "▶ ") .. text, {
						raw = true,
						textSize = 15,
						color = if done then Kit.colors.moss else Kit.colors.text,
						order = nextOrder(),
						auto = Enum.AutomaticSize.Y,
					})
				end
			end
		end
	end
	section(Lang.t("ui.side"), nextOrder())
	for _, side in s.sides or {} do
		local text = Lang.t(side.textKey)
		Kit.label(body, (if side.finished then "✓ " else "• ") .. text, {
			raw = true,
			textSize = 15,
			color = if side.finished then Kit.colors.moss else Kit.colors.text,
			order = nextOrder(),
			auto = Enum.AutomaticSize.Y,
		})
	end
end

------------------------------------------------------------------------------------------
-- Bağ xəritəsi
------------------------------------------------------------------------------------------

renderers.map = function(s)
	local mapFrame =
		Kit.frame(body, { name = "MapCanvas", size = UDim2.new(1, -8, 0, 300), color = Kit.colors.bgSoft, order = 1 })
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 260 / 220
	aspect.Parent = mapFrame
	local function toMap(x: number, z: number): UDim2
		return UDim2.fromScale((x + 130) / 260, (z + 110) / 220)
	end
	for _, z in ZoneDefs.list do
		local open = s.zones[z.id] == true
		local zf = Kit.frame(mapFrame, {
			size = UDim2.fromScale(z.size[1] / 260, z.size[2] / 220),
			pos = toMap(z.origin[1], z.origin[3]),
			color = if open then Kit.colors.leaf else Kit.colors.bg,
			transparency = if open then 0.2 else 0.5,
			radius = 4,
		})
		local stroke = Instance.new("UIStroke")
		stroke.Color = Kit.colors.cream
		stroke.Transparency = 0.6
		stroke.Parent = zf
		Kit.label(
			zf,
			if open then Lang.t(z.nameKey) else "?",
			{ raw = true, textSize = 13, bold = true, align = Enum.TextXAlignment.Center, size = UDim2.fromScale(1, 1) }
		)
	end
	local function dot(x: number, z: number, color: Color3, size: number)
		local d = Kit.frame(mapFrame, {
			size = UDim2.fromOffset(size, size),
			pos = toMap(x, z),
			anchor = Vector2.new(0.5, 0.5),
			color = color,
			radius = math.floor(size / 2),
		})
		d.ZIndex = 3
	end
	-- Ev, hədəf və oyunçu
	local home = Layout.byId["Z01_Home"]
	if home then
		dot(home.pos[1], home.pos[3], Kit.colors.earth, 12)
	end
	local markerId = s.quest and s.quest.marker
	local marker = markerId and Layout.byId[markerId]
	if marker and s.settings.markers then
		dot(marker.pos[1], marker.pos[3], Kit.colors.accent, 14)
	end
	local player = game:GetService("Players").LocalPlayer
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then
		dot(hrp.Position.X, hrp.Position.Z, Kit.colors.dew, 12)
	end
	-- Finaldan sonra rahat keçid (yalnız açılmış sahələr)
	if s.finalCompleted then
		section(Lang.t("ui.travel"), 2)
		local bar = Kit.frame(
			body,
			{ size = UDim2.new(1, -8, 0, 0), transparency = 1, auto = Enum.AutomaticSize.Y, order = 3, radius = 0 }
		)
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(150, 48)
		grid.CellPadding = UDim2.fromOffset(6, 6)
		grid.Parent = bar
		for _, z in ZoneDefs.list do
			if s.zones[z.id] then
				Kit.button(bar, z.nameKey, function()
					Panels.close()
					Net.request("FastTravel", { zone = z.id }, feedback)
				end, { style = "soft", textSize = 14 })
			end
		end
	end
end

------------------------------------------------------------------------------------------
-- Bitki kitabı, xatirələr, nailiyyətlər
------------------------------------------------------------------------------------------

renderers.plantbook = function(s)
	for i, plant in PlantDefs.list do
		local r = row(body, i)
		local known = (s.stats.harvested[plant.id] or 0) > 0 or Conditions.check(asProfile(s), plant.unlock)
		local yields = {}
		for _, a in plant.yield do
			table.insert(yields, ("%d %s"):format(a.n, nameOf(a.id)))
		end
		if known then
			rowText(
				r,
				Lang.t(plant.nameKey),
				Lang.t(
					"ui.growInfo",
					{ n = plant.growSeconds, list = table.concat(yields, ", "), h = s.stats.harvested[plant.id] or 0 }
				),
				colorOf(plant.seedId),
				Kit.symbolFor(plant.seedId)
			)
		else
			rowText(r, "???", Lang.t("ui.notFound"), Kit.colors.bg, "?")
		end
	end
end

renderers.memories = function(s)
	local order = 0
	for _, item in ItemDefs.list do
		if item.category == "memory" then
			order += 1
			local r = row(body, order)
			local found = s.memories[item.id] == true
			if found then
				rowText(
					r,
					nameOf(item.id),
					Lang.t("ui.foundIn", { zone = "zone." .. item.zone }),
					colorOf(item.id),
					Kit.symbolFor(item.id)
				)
			else
				-- Siluet: ilk oyunda bütün yerlər açıq işarələnmir
				rowText(r, "· · ·", Lang.t("ui.notFound"), Kit.colors.bg, "?")
			end
		end
	end
	if s.finalCompleted then
		order += 1
		Kit.button(body, "ui.replayFinal", function()
			Panels.close()
			if Panels.onReplayFinal then
				Panels.onReplayFinal()
			end
		end, { order = order, size = UDim2.fromOffset(240, 48) })
	end
end

renderers.achievements = function(s)
	for i, a in QuestDefs.achievements do
		local r = row(body, i)
		local got = s.achievements[a.id] == true
		rowText(
			r,
			Lang.t(a.nameKey),
			if got then "✓" else Lang.t("ui.notFound"),
			if got then Kit.colors.accent else Kit.colors.bg,
			if got then "★" else "?"
		)
	end
end

------------------------------------------------------------------------------------------
-- Ayarlar və pauza
------------------------------------------------------------------------------------------

local function setPref(key: string, value: any)
	Net.request("SetPreference", { key = key, value = value }, feedback)
	if Panels.onSettingsChanged then
		Panels.onSettingsChanged(key, value)
	end
end

renderers.settings = function(s)
	local st = s.settings
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local function toggle(key: string, labelKey: string)
		local r = row(body, nextOrder())
		rowText(r, Lang.t(labelKey), nil)
		rowButton(r, if st[key] then "ui.on" else "ui.off", function()
			setPref(key, not st[key])
		end, if st[key] then "primary" else "soft")
	end
	local function choice(key: string, labelKey: string, options: { any }, labels: { string })
		local r = row(body, nextOrder())
		rowText(r, Lang.t(labelKey), nil)
		local idx = table.find(options, st[key]) or 1
		rowButton(r, labels[idx], function()
			local nxt = options[(idx % #options) + 1]
			setPref(key, nxt)
		end, "soft", false)
	end
	choice("lang", "ui.language", { "az", "en" }, { "lang.az", "lang.en" })
	choice("music", "ui.music", { 0, 0.3, 0.6, 1 }, { "ui.off", "vol.low", "vol.mid", "vol.high" })
	choice("sfx", "ui.sfx", { 0, 0.4, 0.8, 1 }, { "ui.off", "vol.low", "vol.mid", "vol.high" })
	choice("camSens", "ui.camSens", { 0.5, 0.75, 1, 1.5, 2 }, { "sens.1", "sens.2", "sens.3", "sens.4", "sens.5" })
	toggle("reducedMotion", "ui.reducedMotion")
	toggle("cameraShake", "ui.cameraShake")
	choice("quality", "ui.quality", { "auto", "low", "high" }, { "q.auto", "q.low", "q.high" })
	choice("textSize", "ui.textSize", { 0.9, 1, 1.2, 1.4 }, { "ts.s", "ts.m", "ts.l", "ts.xl" })
	toggle("markers", "ui.markers")
	toggle("rainFx", "ui.rainFx")
	choice("skin", "ui.skin", { 1, 2, 3, 4, 5, 6 }, { "skin.1", "skin.2", "skin.3", "skin.4", "skin.5", "skin.6" })
	choice("outfit", "ui.outfit", { 1, 2, 3, 4 }, { "outfit.1", "outfit.2", "outfit.3", "outfit.4" })
	section(Lang.t("ui.audioNote"), nextOrder())
end

renderers.pause = function(_s)
	Kit.label(
		body,
		"ui.paused",
		{ textSize = 22, bold = true, align = Enum.TextXAlignment.Center, order = 1, auto = Enum.AutomaticSize.Y }
	)
	local list = {
		{ "ui.resume", "resume" },
		{ "ui.settings", "settings" },
		{ "ui.memoryBook", "memories" },
		{ "ui.plantbook", "plantbook" },
		{ "ui.achievements", "achievements" },
	}
	for i, item in list do
		Kit.button(body, item[1], function()
			if item[2] == "resume" then
				Panels.close()
			else
				openPanel(item[2])
			end
		end, { order = i + 1, size = UDim2.new(1, -8, 0, 52), style = if i == 1 then "primary" else "soft" })
	end
end

------------------------------------------------------------------------------------------
-- Panel idarəsi
------------------------------------------------------------------------------------------

local TITLES = {
	inventory = "ui.inventory",
	shop = "ui.shop",
	workshop = "ui.workshop",
	board = "ui.orders",
	quests = "ui.quests",
	map = "ui.map",
	plantbook = "ui.plantbook",
	memories = "ui.memoryBook",
	achievements = "ui.achievements",
	settings = "ui.settings",
	pause = "ui.pause",
}

local function renderCurrent()
	local name = current
	local s = Net.state
	if not name or not s then
		return
	end
	local scroll = body.CanvasPosition
	Kit.clear(body)
	Kit.clear(tabsBar)
	local tabs = tabsFor[name]
	tabsBar.Visible = tabs ~= nil
	if tabs then
		for i, t in tabs do
			local active = (currentTab[name] or tabs[1][1]) == t[1]
			Kit.button(tabsBar, t[2], function()
				currentTab[name] = t[1]
				body.CanvasPosition = Vector2.zero
				renderCurrent()
			end, {
				style = if active then "accent" else "soft",
				size = UDim2.fromOffset(0, 44),
				auto = Enum.AutomaticSize.X,
				textSize = 14,
				order = i,
			})
		end
		for _, b in tabsBar:GetChildren() do
			if b:IsA("TextButton") then
				Kit.padding(b, 8)
			end
		end
	end
	local fn = renderers[name]
	if fn then
		fn(s)
	end
	body.CanvasPosition = scroll
end

function Panels.open(name: string, tab: string?)
	if not renderers[name] then
		return
	end
	-- Yalnız Pauza ekranı oyunu pauzaya alır; ondan açılan alt ekranlar pauzanı saxlayır
	if name == "pause" and not pausedByPanel then
		pausedByPanel = true
		if Panels.onPauseChanged then
			Panels.onPauseChanged(true)
		end
	end
	current = name
	if tab then
		currentTab[name] = tab
	end
	Kit.setText(titleLabel, TITLES[name] or name)
	window.Visible = true
	body.CanvasPosition = Vector2.zero
	renderCurrent()
end

openPanel = Panels.open

function Panels.close()
	local was = current
	current = nil
	window.Visible = false
	if modal then
		modal:Destroy()
		modal = nil
	end
	if pausedByPanel then
		pausedByPanel = false
		if Panels.onPauseChanged then
			Panels.onPauseChanged(false)
		end
	end
	if was and Panels.onClosed then
		Panels.onClosed(was)
	end
end

function Panels.isOpen(): boolean
	return current ~= nil
end

function Panels.current(): string?
	return current
end

function Panels.toggle(name: string)
	if current == name then
		Panels.close()
	else
		Panels.open(name)
	end
end

function Panels.init(gui: ScreenGui)
	rootGui = gui
	window = Kit.frame(gui, {
		name = "Window",
		size = UDim2.new(1, -32, 1, -120),
		pos = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		transparency = 0.04,
	})
	local sc = Instance.new("UISizeConstraint")
	sc.MaxSize = Vector2.new(680, 560)
	sc.Parent = window
	window.ZIndex = 10
	Kit.padding(window, 12)
	titleLabel = Kit.label(window, "", { raw = true, textSize = 22, bold = true, size = UDim2.new(1, -60, 0, 32) })
	Kit.button(window, "✕", function()
		Panels.close()
	end, {
		raw = true,
		style = "soft",
		size = UDim2.fromOffset(48, 48),
		pos = UDim2.new(1, 0, 0, -6),
		anchor = Vector2.new(1, 0),
		textSize = 20,
	})
	tabsBar = Kit.frame(
		window,
		{ name = "Tabs", size = UDim2.new(1, 0, 0, 44), pos = UDim2.fromOffset(0, 44), transparency = 1, radius = 0 }
	)
	Kit.list(tabsBar, true, 6)
	body = Kit.scroll(window, { size = UDim2.new(1, 0, 1, -100), pos = UDim2.fromOffset(0, 96) })
	Kit.list(body, false, 6)
	window.Visible = false
	Net.StateChanged:Connect(function()
		if current then
			renderCurrent()
		end
	end)
	Lang.Changed:Connect(function()
		if current then
			Kit.setText(titleLabel, TITLES[current] or current)
			renderCurrent()
		end
	end)
end

return Panels
