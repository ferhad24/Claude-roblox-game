--!strict
-- TINY GROVE client başlanğıcı: şəbəkə → UI → kontrollerlər.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Net = require(script.Net)
local Lang = require(script.Lang)
local Kit = require(script.UI.Kit)
local Hud = require(script.UI.Hud)
local Panels = require(script.UI.Panels)
local Dialog = require(script.UI.Dialog)
local StartScreen = require(script.UI.StartScreen)
local Cinematics = require(script.UI.Cinematics)
local Interaction = require(script.Controllers.Interaction)
local Build = require(script.Controllers.Build)
local CameraMovement = require(script.Controllers.CameraMovement)
local Effects = require(script.Controllers.Effects)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

Net.init()
local gui = Kit.init(playerGui)
Hud.init(gui)
Panels.init(gui)
Dialog.init(gui)
Cinematics.init(gui)
Interaction.init(gui)
Build.init(gui)
CameraMovement.init(gui)
Effects.init()
StartScreen.init(gui)
Hud.setVisible(false)

local playing = false
local menuPaused = false

local function setPaused(paused: boolean)
	Net.request("SetPaused", { paused = paused })
end

local function refreshControls()
	local blocked = not playing or Panels.isOpen() or Dialog.isOpen() or Cinematics.isRunning() or Build.isActive()
	Interaction.setEnabled(not blocked)
	Hud.setVisible(playing and not Cinematics.isRunning())
end

Interaction.isBlocked = function(): boolean
	return not playing or Panels.isOpen() or Dialog.isOpen() or Cinematics.isRunning() or Build.isActive()
end

local function playFinal(replay: boolean)
	Panels.close()
	refreshControls()
	task.spawn(function()
		Cinematics.final(function()
			refreshControls()
			if not replay then
				Hud.toast("ui.final.title")
				Hud.toast("ui.final.msg")
			end
			Net.request("WatchedFinal", {})
		end)
		refreshControls()
	end)
end

-- Başla / Davam et: pauza açılır, yeni profil üçün 8 s keçilə bilən açılış
StartScreen.onStart = function(isNew: boolean)
	playing = true
	setPaused(false)
	if isNew then
		task.spawn(function()
			Cinematics.opening(function()
				refreshControls()
			end)
		end)
		task.defer(refreshControls)
	end
	refreshControls()
end

Hud.onMenu = function(name: string)
	if name == "home" then
		Net.request("GoHome", {})
	else
		Panels.toggle(name)
	end
	refreshControls()
end

Hud.onSlot = function(i: number)
	local s = Net.state
	local tool = s and s.hotbar[i]
	if tool then
		Net.request("EquipTool", { tool = tool })
	end
end

Panels.onPlaceBuild = function(id: string)
	Build.start(id, nil)
	refreshControls()
end
Panels.onReplayFinal = function()
	playFinal(true)
end
Panels.onPauseChanged = function(paused: boolean)
	setPaused(paused)
end
Panels.onClosed = function(_name: string)
	refreshControls()
end
Panels.onSettingsChanged = function(key: string, value: any)
	if key == "lang" then
		Lang.set(value)
	elseif key == "textSize" then
		Kit.setTextScale(value)
	elseif key == "reducedMotion" then
		Effects.reducedMotion = value
		Cinematics.reducedMotion = value
	end
end

Build.onFinished = function()
	refreshControls()
end

Interaction.onOpenPanel = function(panel: string, tab: string?)
	if panel == "inventory" or panel == "workshop" or panel == "board" or panel == "shop" then
		Panels.open(panel, tab)
		refreshControls()
	end
end
Interaction.onDialog = function(npcId: string, opens: string?)
	Dialog.open(npcId, function()
		if opens == "shop" then
			Panels.open("shop")
		end
		refreshControls()
	end)
	refreshControls()
end
Interaction.onBuildMove = function(uid: string)
	local s = Net.state
	local b = s and s.builds[uid]
	if b then
		Build.start(b.t, uid)
		refreshControls()
	end
end
Interaction.onReplayFinal = function()
	playFinal(true)
end

-- Server hadisələri
Net.Event:Connect(function(e: { [string]: any })
	local t = e.type
	if t == "toast" then
		Hud.toast(e.key, e.params, e.error == true)
	elseif t == "final" then
		playFinal(e.replay == true)
	elseif t == "work" then
		Hud.setWorkProgress(e.progress, e.active == true)
	elseif t == "water" then
		Hud.showWater(4)
	elseif t == "crafted" then
		Hud.showCrafted(e.id, e.n)
	end
end)
Net.Result:Connect(function(_action: string, result: { [string]: any })
	if result and not result.ok and result.err then
		Hud.toast(result.err, result.params, true)
	end
end)
Net.SessionChanged:Connect(function(msg: { [string]: any })
	Hud.setTestMode(msg.testMode == true)
end)

-- Ayarların ilkin tətbiqi
local appliedOnce = false
Net.StateChanged:Connect(function(s: { [string]: any })
	if not appliedOnce then
		appliedOnce = true
		Lang.set(s.settings.lang or "az")
		Kit.setTextScale(s.settings.textSize or 1)
		Effects.reducedMotion = s.settings.reducedMotion == true
		Cinematics.reducedMotion = s.settings.reducedMotion == true
	end
end)

-- Klaviatura qısayolları (bölmə 17): Tab inventar, M xəritə, J tapşırıqlar, B tikinti, P pauza, 1–4 alətlər
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed or not playing then
		return
	end
	local k = input.KeyCode
	if Dialog.isOpen() then
		if k == Enum.KeyCode.E or k == Enum.KeyCode.Space or k == Enum.KeyCode.Return or k == Enum.KeyCode.ButtonA then
			Dialog.advance()
		end
		return
	end
	if Cinematics.isRunning() then
		if k == Enum.KeyCode.Space or k == Enum.KeyCode.ButtonB then
			Cinematics.skip()
		end
		return
	end
	if k == Enum.KeyCode.Tab then
		Panels.toggle("inventory")
	elseif k == Enum.KeyCode.M then
		Panels.toggle("map")
	elseif k == Enum.KeyCode.J then
		Panels.toggle("quests")
	elseif k == Enum.KeyCode.P then
		Panels.toggle("pause")
	elseif k == Enum.KeyCode.B and not Build.isActive() then
		Panels.open("inventory", "builds")
	elseif k == Enum.KeyCode.ButtonB and Panels.isOpen() then
		Panels.close()
	elseif k == Enum.KeyCode.One or k == Enum.KeyCode.Two or k == Enum.KeyCode.Three or k == Enum.KeyCode.Four then
		local idx = ({
			[Enum.KeyCode.One] = 1,
			[Enum.KeyCode.Two] = 2,
			[Enum.KeyCode.Three] = 3,
			[Enum.KeyCode.Four] = 4,
		})[k]
		if Hud.onSlot and idx then
			Hud.onSlot(idx)
		end
	end
	refreshControls()
end)

-- Esc: Roblox-un standart menyusu açılanda oyun vəziyyəti pauzaya düşür
GuiService.MenuOpened:Connect(function()
	if playing and not menuPaused then
		menuPaused = true
		Interaction.stopWork()
		setPaused(true)
	end
end)
GuiService.MenuClosed:Connect(function()
	if menuPaused then
		menuPaused = false
		if not Panels.isOpen() or Panels.current() ~= "pause" then
			setPaused(false)
		end
	end
end)

local foliageAcc = 0
RunService.RenderStepped:Connect(function(dt: number)
	Hud.update(dt)
	Effects.update(dt)
	Interaction.update()
	foliageAcc += dt
	if foliageAcc >= 0.1 then
		foliageAcc = 0
		CameraMovement.updateFoliage()
	end
end)
