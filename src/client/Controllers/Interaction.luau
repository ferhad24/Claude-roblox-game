--!strict
-- Əlaqə (bölmə 7, 17): ən yaxın obyekti seçir, 3 vəziyyətli göstəriş göstərir
-- (işləyə bilərsən / uyğun alət yoxdur / şərt çatmır — rənglə yanaşı ikon və mətn),
-- iş basılı saxlamaqla edilir, əlaqə E / gamepad X / mobil düymə ilə.
-- Client yalnız niyyəti göndərir; bütün yoxlamalar serverdə təkrarlanır.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Layout = require(Shared.Layout)
local ToolDefs = require(Shared.Defs.ToolDefs)
local WorkDefs = require(Shared.Defs.WorkDefs)
local BuildDefs = require(Shared.Defs.BuildDefs)
local PlantDefs = require(Shared.Defs.PlantDefs)
local NpcDefs = require(Shared.Defs.NpcDefs)
local Net = require(script.Parent.Parent.Net)
local Lang = require(script.Parent.Parent.Lang)
local Kit = require(script.Parent.Parent.UI.Kit)

local Interaction = {}

local player = Players.LocalPlayer

export type Hint = {
	state: string, -- "can" | "noTool" | "locked" | "done" | "info"
	text: string,
	action: string?, -- əlaqə əməliyyatı (E)
	work: boolean?, -- basılı saxlayaraq iş
}

local target: Model? = nil
local targetHint: Hint? = nil
local billboard: BillboardGui
local hintIcon: Frame
local hintText: TextLabel
local mobileBar: Frame
local workButton: TextButton
local actButton: TextButton
local menu: Frame
local workingTarget: string? = nil
local workHeld = false
local enabled = false
local gui: ScreenGui

Interaction.onOpenPanel = nil :: ((string, string?) -> ())?
Interaction.onDialog = nil :: ((string, string?) -> ())?
Interaction.onBuildMove = nil :: ((string) -> ())?
Interaction.onReplayFinal = nil :: (() -> ())?
Interaction.isBlocked = nil :: (() -> boolean)?

local STATE_COLOR = {
	can = Color3.fromHex("#6FA66A"),
	noTool = Color3.fromRGB(150, 150, 150),
	locked = Color3.fromHex("#C87958"),
	done = Color3.fromHex("#A8C78D"),
	info = Color3.fromHex("#86C5D8"),
}
local STATE_SYMBOL = { can = "✓", noTool = "✕", locked = "!", done = "✓", info = "i" }

local function rootPart(): BasePart?
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	return if hrp and hrp:IsA("BasePart") then hrp else nil
end

local function state(): { [string]: any }?
	return Net.state
end

local function ownsRate(s: { [string]: any }, workType: string): boolean
	for id in s.tools do
		local t = ToolDefs.byId[id]
		if t and (t.rates :: any)[workType] then
			return true
		end
	end
	return false
end

local function cheapestToolFor(workType: string): string?
	local bestKey: string? = nil
	local bestPrice = math.huge
	for _, t in ToolDefs.list do
		if (t.rates :: any)[workType] and t.price < bestPrice then
			bestPrice = t.price
			bestKey = t.nameKey
		end
	end
	return bestKey
end

local function hint(stateName: string, key: string, params: { [string]: any }?, action: string?, work: boolean?): Hint
	return { state = stateName, text = Lang.t(key, params), action = action, work = work }
end

local function power(s: { [string]: any }): number
	return s.power or 1
end

-- Obyekt üçün göstəriş (server yoxlamalarının UI güzgüsü)
local function describe(m: Model, s: { [string]: any }): Hint?
	local id = m:GetAttribute("TG_Id") :: string?
	local kind = m:GetAttribute("TG_Kind") :: string?
	if not id or not kind then
		return nil
	end
	if kind == "build" then
		local def = BuildDefs.byId[m:GetAttribute("TG_Def") :: string]
		return hint("can", "hint.can", { action = "ui.interact", name = def and def.nameKey or "" }, "buildMenu")
	elseif kind == "socketBuild" then
		if m:GetAttribute("TG_Def") == "B_LIFT" then
			return hint("can", "hint.can", { action = "ui.useLift", name = "build.B_LIFT" }, "lift")
		end
		return nil
	end
	local obj = Layout.byId[id]
	if not obj then
		return nil
	end
	if not s.zones[obj.zone] then
		return hint("locked", "ui.zoneLocked")
	end
	if kind == "work" or kind == "spot" then
		if kind == "work" and s.restored[id] then
			return nil
		end
		if kind == "spot" and m:GetAttribute("TG_Available") == false then
			return nil
		end
		local defId = if kind == "work" then obj.def else (obj.spawns :: { string })[1]
		local def = WorkDefs.workById[defId :: string]
		if not def then
			return nil
		end
		if power(s) < def.minPower then
			return hint("locked", "hint.needPower", { n = def.minPower })
		end
		if not ownsRate(s, def.workType) then
			return hint("noTool", "hint.noTool", { tool = cheapestToolFor(def.workType) or "" })
		end
		return hint("can", "hint.can", { action = "ui.work", name = def.nameKey }, nil, true)
	elseif kind == "consumer" then
		local def = WorkDefs.consumerById[obj.def :: string]
		if s.restored[id] then
			return hint("done", "hint.done")
		end
		local extra = obj.extra
		local lockId = extra and extra.lockedBy
		if lockId and not s.restored[lockId] then
			local lockObj = Layout.byId[lockId]
			return hint("locked", if lockObj and lockObj.kind == "dropoff" then "hint.needPatch" else "hint.needKnot")
		end
		if not def.cupAllowed then
			return hint("info", if def.requiresPump then "hint.needPump" else "hint.networkOnly")
		end
		if s.cup <= 0 then
			return hint("noTool", "hint.emptyCup")
		end
		return hint("can", "hint.can", { action = "ui.pour", name = def.nameKey }, "pour")
	elseif kind == "source" then
		if s.cup >= s.cupCapacity then
			return hint("done", "msg.cupFull")
		end
		return hint("can", "hint.can", { action = "ui.fill", name = "item.MAT_DEW" }, "fill")
	elseif kind == "plot" then
		local plant = s.plants[id]
		if not plant then
			if next(s.seeds) ~= nil then
				return hint("can", "ui.plant", nil, "plant")
			end
			return hint("noTool", "msg.noSeed")
		end
		if plant.ready then
			return hint(
				"can",
				"hint.can",
				{ action = "ui.harvest", name = PlantDefs.byId[plant.sp].nameKey },
				"harvest"
			)
		end
		if s.cup > 0 and plant.m < Constants.MOISTURE_MAX then
			return hint("can", "hint.can", { action = "ui.pour", name = PlantDefs.byId[plant.sp].nameKey }, "pour")
		end
		local def = PlantDefs.byId[plant.sp]
		return hint(
			"info",
			"ui.plantStatus",
			{ g = math.floor(plant.g / def.growSeconds * 100), m = math.floor(plant.m) }
		)
	elseif kind == "npc" then
		local npc = NpcDefs.byId[obj.def :: string]
		return hint("can", "hint.can", { action = "ui.talk", name = npc and npc.nameKey or "" }, "talk")
	elseif kind == "workbench" then
		return hint("can", "hint.can", { action = "ui.open", name = "ui.workshop" }, "workbench")
	elseif kind == "storage" then
		return hint("can", "hint.can", { action = "ui.deposit", name = "ui.storage" }, "storage")
	elseif kind == "board" then
		return hint("can", "hint.can", { action = "ui.open", name = "ui.orders" }, "board")
	elseif kind == "memory" then
		if s.restored[id] then
			return nil
		end
		return hint("can", "ui.look", nil, "memory")
	elseif kind == "cargo" then
		if s.restored[id] then
			return nil
		end
		if not s.tools["TOOL_CART_1"] then
			return hint("noTool", "hint.needCart")
		end
		return hint("can", "hint.can", { action = "ui.pickup", name = "item.CARGO_SHARD" }, "cargo")
	elseif kind == "dropoff" then
		if s.restored[id] then
			return hint("done", "hint.done")
		end
		local carried = s.cargo[obj.def :: string] or 0
		if carried <= 0 then
			return hint("noTool", "hint.needCart")
		end
		return hint("can", "hint.can", { action = "ui.dropoff", name = "item.CARGO_SHARD" }, "dropoff")
	elseif kind == "tree" then
		if s.finalCompleted then
			return hint("can", "ui.replayFinal", nil, "replay")
		end
		if s.quest and s.quest.stepId == "Q6_WAKE" then
			return hint("can", "ui.wake", nil, "wake")
		end
		return hint("locked", "hint.treeSleeps")
	elseif kind == "socket" then
		local hasItem = (s.buildInv[obj.def :: string] or 0) > 0
		if hasItem then
			return hint(
				"can",
				"hint.can",
				{ action = "ui.place", name = BuildDefs.byId[obj.def :: string].nameKey },
				"socket"
			)
		end
		return hint("locked", "hint.needBuild", { name = BuildDefs.byId[obj.def :: string].nameKey })
	end
	return nil
end
Interaction.describe = describe

local function modelPosition(m: Model): Vector3
	return m:GetPivot().Position
end

-- Hədəf seçimi: məsafə (obyektin ölçüsü nəzərə alınaraq) və baxış istiqaməti
local function pickTarget(): Model?
	local hrp = rootPart()
	local s = state()
	if not hrp or not s then
		return nil
	end
	local pos = hrp.Position
	local look = hrp.CFrame.LookVector
	local best: Model? = nil
	local bestScore = math.huge
	for _, inst in CollectionService:GetTagged("TG_Interact") do
		if inst:IsA("Model") and inst.Parent then
			local mp = modelPosition(inst)
			local id = inst:GetAttribute("TG_Id") :: string?
			local obj = id and Layout.byId[id]
			local radius = 2
			if obj then
				local size = Layout.sizeOf(obj)
				radius = math.max(size[1], size[3]) / 2
			elseif inst:GetAttribute("TG_Kind") == "build" then
				radius = 2
			end
			local delta = Vector3.new(mp.X - pos.X, 0, mp.Z - pos.Z)
			local dist = math.max(0, delta.Magnitude - radius)
			if dist <= Constants.INTERACT_RANGE - 1 and math.abs(mp.Y - pos.Y) < 14 then
				local facing = if delta.Magnitude > 0.01 then delta.Unit:Dot(look) else 1
				local score = dist - facing * 2
				if score < bestScore then
					bestScore = score
					best = inst
				end
			end
		end
	end
	return best
end

local function setBillboard(m: Model?, h: Hint?)
	if not m or not h then
		billboard.Enabled = false
		return
	end
	local adornee: Instance? = m.PrimaryPart
	if not adornee then
		adornee = m:FindFirstChildWhichIsA("BasePart")
	end
	(billboard :: any).Adornee = adornee
	hintIcon.BackgroundColor3 = STATE_COLOR[h.state] or STATE_COLOR.info
	local sym = hintIcon:FindFirstChildOfClass("TextLabel")
	if sym then
		sym.Text = STATE_SYMBOL[h.state] or "i"
	end
	local keyHint = ""
	if UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled then
		if h.work then
			keyHint = "  [" .. Lang.t("key.hold") .. "]"
		elseif h.action then
			keyHint = "  [E]"
		end
	end
	hintText.Text = h.text .. keyHint
	billboard.Enabled = true
end

local function updateMobile(h: Hint?)
	if not UserInputService.TouchEnabled then
		mobileBar.Visible = false
		return
	end
	mobileBar.Visible = enabled
	workButton.Visible = h ~= nil and h.work == true
	actButton.Visible = h ~= nil and h.action ~= nil and h.state == "can"
	if h and h.action then
		actButton.Text = h.text
	end
end

------------------------------------------------------------------------------------------
-- Əməliyyatlar
------------------------------------------------------------------------------------------

local function closeMenu()
	menu.Visible = false
	Kit.clear(menu)
end

local function openMenu(items: { { key: string, fn: () -> (), params: { [string]: any }? } })
	Kit.clear(menu)
	for i, item in items do
		Kit.button(menu, item.key, function()
			closeMenu()
			item.fn()
		end, {
			order = i,
			size = UDim2.new(1, 0, 0, 48),
			style = if i == 1 then "primary" else "soft",
			params = item.params,
			textSize = 15,
		})
	end
	Kit.button(
		menu,
		"ui.cancel",
		closeMenu,
		{ order = #items + 1, size = UDim2.new(1, 0, 0, 48), style = "soft", textSize = 15 }
	)
	menu.Visible = true
end

local function seedMenu(slot: string)
	local s = state()
	if not s then
		return
	end
	local items = {}
	for _, plant in PlantDefs.list do
		local n = s.seeds[plant.seedId]
		if n and n > 0 then
			table.insert(items, {
				key = "ui.plantSeed",
				params = { name = plant.nameKey, n = n },
				fn = function()
					Net.request("PlantSeed", { slot = slot, seed = plant.seedId })
				end,
			})
		end
	end
	if #items > 0 then
		openMenu(items)
	end
end

local function buildMenu(uid: string)
	local s = state()
	if not s then
		return
	end
	local b = s.builds[uid]
	if not b then
		return
	end
	local def = BuildDefs.byId[b.t]
	local items = {}
	if def.kind == "planter" then
		local plant = s.plants["B" .. uid]
		if not plant then
			if next(s.seeds) ~= nil then
				table.insert(items, {
					key = "ui.plant",
					fn = function()
						seedMenu(uid)
					end,
				})
			end
		elseif plant.ready then
			table.insert(items, {
				key = "ui.harvest",
				fn = function()
					Net.request("Harvest", { slot = uid })
				end,
			})
		elseif s.cup > 0 then
			table.insert(items, {
				key = "ui.pour",
				fn = function()
					Net.request("WaterPlant", { target = uid })
				end,
			})
		end
	elseif def.kind == "tank" or def.kind == "catcher" then
		if (b.w or 0) > 0 and s.cup < s.cupCapacity then
			table.insert(items, {
				key = "ui.fill",
				fn = function()
					Net.request("FillWater", { source = uid })
				end,
			})
		end
		if def.kind == "tank" and s.cup > 0 then
			table.insert(items, {
				key = "ui.pour",
				fn = function()
					Net.request("WaterPlant", { target = uid })
				end,
			})
		end
		if (b.w or 0) > 0 then
			table.insert(items, {
				key = "ui.drain",
				fn = function()
					Net.request("DrainBuild", { uid = uid })
				end,
			})
		end
	elseif def.kind == "compost" or def.kind == "sorter" then
		table.insert(items, {
			key = "ui.use",
			fn = function()
				Net.request("Interact", { target = uid })
			end,
		})
	end
	table.insert(items, {
		key = "ui.move",
		fn = function()
			if Interaction.onBuildMove then
				Interaction.onBuildMove(uid)
			end
		end,
	})
	table.insert(items, {
		key = "ui.store",
		fn = function()
			Net.request("StoreBuild", { uid = uid })
		end,
	})
	openMenu(items)
end

local function interact()
	if not enabled or (Interaction.isBlocked and Interaction.isBlocked()) then
		return
	end
	local m = target
	local h = targetHint
	if not m or not h or not h.action then
		return
	end
	local id = m:GetAttribute("TG_Id") :: string
	local a = h.action
	if a == "pour" then
		Net.request("WaterPlant", { target = id })
	elseif a == "fill" then
		Net.request("FillWater", { source = id })
	elseif a == "plant" then
		seedMenu(id)
	elseif a == "harvest" then
		Net.request("Harvest", { slot = id })
	elseif
		a == "talk"
		or a == "workbench"
		or a == "storage"
		or a == "board"
		or a == "memory"
		or a == "cargo"
		or a == "dropoff"
		or a == "wake"
	then
		Net.request("Interact", { target = id })
	elseif a == "replay" then
		if Interaction.onReplayFinal then
			Interaction.onReplayFinal()
		end
	elseif a == "socket" then
		local obj = Layout.byId[id]
		Net.request("Place", { build = obj.def, socket = id })
	elseif a == "lift" then
		Net.request("UseLift", { socket = id })
	elseif a == "buildMenu" then
		buildMenu(id)
	end
end
Interaction.interact = interact

local function startWork()
	if not enabled or (Interaction.isBlocked and Interaction.isBlocked()) then
		return
	end
	workHeld = true
	local m = target
	local h = targetHint
	if m and h and h.work and h.state == "can" then
		local id = m:GetAttribute("TG_Id") :: string
		workingTarget = id
		Net.request("StartWork", { target = id })
	end
end

local function stopWork()
	workHeld = false
	if workingTarget then
		workingTarget = nil
		Net.request("StopWork", {})
	end
end
Interaction.stopWork = stopWork

function Interaction.setEnabled(on: boolean)
	enabled = on
	if not on then
		stopWork()
		closeMenu()
		setBillboard(nil, nil)
	end
	updateMobile(if on then targetHint else nil)
end

function Interaction.update()
	if not enabled then
		return
	end
	local s = state()
	if not s then
		return
	end
	-- İş zamanı hədəfi dəyişmirik
	if workingTarget and s.work and s.work.id == workingTarget then
		return
	end
	if workingTarget and not s.work then
		workingTarget = nil
	end
	local m = pickTarget()
	local h = if m then describe(m, s) else nil
	target = if h then m else nil
	targetHint = h
	setBillboard(target, h)
	updateMobile(h)
	-- Düymə hələ basılıdırsa yeni işlənə bilən hədəfə keç
	if workHeld and not workingTarget and h and h.work and h.state == "can" then
		startWork()
	end
end

function Interaction.init(rootGui: ScreenGui)
	gui = rootGui
	billboard = Instance.new("BillboardGui")
	billboard.Name = "TG_Hint"
	billboard.Size = UDim2.fromOffset(280, 44)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 40
	billboard.Enabled = false
	billboard.Parent = player:WaitForChild("PlayerGui")
	local bg = Kit.frame(billboard, { size = UDim2.fromScale(1, 1), transparency = 0.15 })
	hintIcon = Kit.icon(bg, STATE_COLOR.can, "✓", 32)
	hintIcon.Position = UDim2.fromOffset(6, 6)
	hintText = Kit.label(
		bg,
		"",
		{ raw = true, textSize = 16, bold = true, size = UDim2.new(1, -48, 1, 0), pos = UDim2.fromOffset(44, 0) }
	)
	hintText.TextYAlignment = Enum.TextYAlignment.Center

	-- Mobil: böyük iş düyməsi, kontekst əlaqə düyməsi
	mobileBar = Kit.frame(gui, {
		name = "Mobile",
		size = UDim2.fromOffset(150, 0),
		pos = UDim2.new(1, -16, 1, -96),
		anchor = Vector2.new(1, 1),
		transparency = 1,
		auto = Enum.AutomaticSize.Y,
		radius = 0,
	})
	Kit.list(mobileBar, false, 10, Enum.HorizontalAlignment.Right)
	actButton = Kit.button(mobileBar, "ui.interact", function()
		interact()
	end, { size = UDim2.fromOffset(150, 56), style = "accent", order = 1, textSize = 15 })
	workButton = Kit.button(
		mobileBar,
		"ui.work",
		function() end,
		{ size = UDim2.fromOffset(110, 110), order = 2, textSize = 22 }
	)
	workButton.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			startWork()
		end
	end)
	workButton.InputEnded:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			stopWork()
		end
	end)
	mobileBar.Visible = false

	menu = Kit.frame(gui, {
		name = "ContextMenu",
		size = UDim2.fromOffset(240, 0),
		pos = UDim2.fromScale(0.5, 0.55),
		anchor = Vector2.new(0.5, 0),
		auto = Enum.AutomaticSize.Y,
		transparency = 0.05,
	})
	menu.ZIndex = 12
	Kit.padding(menu, 8)
	Kit.list(menu, false, 6)
	menu.Visible = false

	-- PC və gamepad girişləri
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
			startWork()
		elseif input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX then
			interact()
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
			stopWork()
		end
	end)
	Net.Event:Connect(function(e: { [string]: any })
		if e.type == "work" and e.done and e.id == workingTarget then
			workingTarget = nil
		elseif e.type == "dialog" then
			if Interaction.onDialog then
				Interaction.onDialog(e.npc, e.opens)
			end
		elseif e.type == "open" then
			if Interaction.onOpenPanel then
				Interaction.onOpenPanel(e.panel, nil)
			end
		end
	end)
end

return Interaction
