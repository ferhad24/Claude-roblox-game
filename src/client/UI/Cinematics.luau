--!strict
-- Açılış (8 s, keçilə bilən) və final səhnəsi (25–35 s, keçilə bilən; bölmə 4 və 15).
-- Azaldılmış hərəkət ayarında kamera uçuşları əvəzinə sabit kadrlar göstərilir.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Layout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Layout"))
local Kit = require(script.Parent.Kit)

local Cinematics = {}

local overlay: Frame
local caption: TextLabel
local skipButton: TextButton
local running = false
local skipRequested = false

Cinematics.reducedMotion = false

local function camera(): Camera
	return workspace.CurrentCamera :: Camera
end

-- Bir kadr: kamera A-dan B-yə (və ya sabit B), altyazı ilə. Keçilə bilər.
local function shot(fromCF: CFrame, toCF: CFrame, seconds: number, captionKey: string?)
	if skipRequested then
		return
	end
	local cam = camera()
	if captionKey then
		Kit.setText(caption, captionKey)
		caption.Visible = true
	else
		caption.Visible = false
	end
	if Cinematics.reducedMotion then
		cam.CFrame = toCF
	else
		cam.CFrame = fromCF
		TweenService
			:Create(cam, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = toCF })
			:Play()
	end
	local t = 0
	while t < seconds and not skipRequested do
		t += task.wait(0.1)
	end
end

local function begin()
	running = true
	skipRequested = false
	overlay.Visible = true
	camera().CameraType = Enum.CameraType.Scriptable
end

local function finish()
	local cam = camera()
	cam.CameraType = Enum.CameraType.Custom
	overlay.Visible = false
	caption.Visible = false
	running = false
end

function Cinematics.isRunning(): boolean
	return running
end

function Cinematics.skip()
	skipRequested = true
end

-- 8 saniyəlik açılış: qoz evindən bağa baxış və idarəetmə göstərişi
function Cinematics.opening(onDone: () -> ())
	begin()
	local home = Layout.byId["Z01_Home"]
	local tree = Layout.byId["Z06_Tree"]
	local hp = Vector3.new(home.pos[1], home.pos[2], home.pos[3])
	local tp = Vector3.new(tree.pos[1], tree.pos[2] + 60, tree.pos[3])
	shot(
		CFrame.lookAt(hp + Vector3.new(0, 14, -22), tp),
		CFrame.lookAt(hp + Vector3.new(10, 30, -50), tp),
		4,
		"cine.opening1"
	)
	shot(
		CFrame.lookAt(hp + Vector3.new(-8, 8, -18), hp + Vector3.new(0, 2, -30)),
		CFrame.lookAt(hp + Vector3.new(-4, 6, -14), hp + Vector3.new(0, 2, -30)),
		4,
		"cine.controls"
	)
	finish()
	onDone()
end

-- Final: su köklərə yayılır, rəng gövdə boyunca qalxır, yarpaqlar açılır, çiçəklər görünür (~30 s)
function Cinematics.final(onDone: () -> ())
	begin()
	local tree = Layout.byId["Z06_Tree"]
	local base = Vector3.new(tree.pos[1], tree.pos[2], tree.pos[3])
	shot(
		CFrame.lookAt(base + Vector3.new(0, 6, 40), base + Vector3.new(0, 1, 18)),
		CFrame.lookAt(base + Vector3.new(20, 8, 34), base + Vector3.new(0, 1, 10)),
		7,
		"cine.final1"
	)
	shot(
		CFrame.lookAt(base + Vector3.new(24, 4, 0), base + Vector3.new(0, 10, 0)),
		CFrame.lookAt(base + Vector3.new(24, 40, 0), base + Vector3.new(0, 60, 0)),
		8,
		"cine.final2"
	)
	shot(
		CFrame.lookAt(base + Vector3.new(0, 70, 70), base + Vector3.new(0, 100, 0)),
		CFrame.lookAt(base + Vector3.new(-50, 90, 50), base + Vector3.new(0, 100, 0)),
		8,
		"cine.final3"
	)
	shot(
		CFrame.lookAt(base + Vector3.new(-30, 20, 60), base + Vector3.new(0, 20, 0)),
		CFrame.lookAt(base + Vector3.new(30, 26, 70), base + Vector3.new(0, 30, 0)),
		7,
		"cine.final4"
	)
	finish()
	onDone()
end

function Cinematics.init(gui: ScreenGui)
	overlay = Kit.frame(gui, { name = "Cinematic", transparency = 1, radius = 0 })
	overlay.ZIndex = 25
	local barTop = Kit.frame(overlay, { size = UDim2.new(1, 0, 0, 60), color = Color3.new(0, 0, 0), radius = 0 })
	barTop.ZIndex = 25
	local barBottom = Kit.frame(overlay, {
		size = UDim2.new(1, 0, 0, 60),
		pos = UDim2.fromScale(0, 1),
		anchor = Vector2.new(0, 1),
		color = Color3.new(0, 0, 0),
		radius = 0,
	})
	barBottom.ZIndex = 25
	caption = Kit.label(overlay, "", {
		raw = true,
		textSize = 22,
		bold = true,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, -40, 0, 0),
		pos = UDim2.new(0.5, 0, 1, -70),
		anchor = Vector2.new(0.5, 1),
		auto = Enum.AutomaticSize.Y,
	})
	caption.ZIndex = 26
	skipButton = Kit.button(
		overlay,
		"ui.skip",
		function()
			Cinematics.skip()
		end,
		{ size = UDim2.fromOffset(120, 48), pos = UDim2.new(1, -16, 0, 70), anchor = Vector2.new(1, 0), style = "soft" }
	)
	skipButton.ZIndex = 26
	overlay.Visible = false
end

return Cinematics
