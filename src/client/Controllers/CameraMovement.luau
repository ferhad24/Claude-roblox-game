--!strict
-- Kamera (bölmə 2): üçüncü şəxs, ilkin məsafə 12, diapazon 8–22, FOV 70, divarlara daxil olmur
-- (DevCameraOcclusionMode = Zoom), yaxın otlar görüntünü örtəndə lokal şəffaflaşır.
-- Hərəkət: yeriş 14, qaçış 18 (limitsiz), yük daşıyanda 12/15 (11-dən aşağı deyil).
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local Net = require(script.Parent.Parent.Net)
local Kit = require(script.Parent.Parent.UI.Kit)

local CameraMovement = {}

local player = Players.LocalPlayer
local running = false
local runToggle = false
local faded: { [BasePart]: boolean } = {}
local runButton: TextButton? = nil

local function humanoid(): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid") or nil
end

local function carrying(): boolean
	local s = Net.state
	return s ~= nil and next(s.cargo) ~= nil
end

function CameraMovement.applySpeed()
	local h = humanoid()
	if not h then
		return
	end
	local run = running or runToggle
	if carrying() then
		h.WalkSpeed = if run then Constants.CARRY_RUN_SPEED else Constants.CARRY_WALK_SPEED
	else
		h.WalkSpeed = if run then Constants.RUN_SPEED else Constants.WALK_SPEED
	end
end

function CameraMovement.setSensitivity(v: number)
	UserInputService.MouseDeltaSensitivity = math.clamp(v, 0.2, 3)
end

-- Kamera ilə xarakter arasında qalan otları şəffaflaşdır (yalnız lokal görünüş)
function CameraMovement.updateFoliage()
	local cam = workspace.CurrentCamera
	local char = player.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	if not cam or not head then
		return
	end
	local a = cam.CFrame.Position
	local b = head.Position
	local ab = b - a
	local len = ab.Magnitude
	if len < 0.1 then
		return
	end
	local dir = ab / len
	local nowFaded: { [BasePart]: boolean } = {}
	for _, inst in CollectionService:GetTagged("TG_Foliage") do
		if inst:IsA("BasePart") and inst:IsDescendantOf(workspace) then
			local p = inst.Position
			local t = math.clamp((p - a):Dot(dir), 0, len)
			local closest = a + dir * t
			local radius = math.max(inst.Size.X, inst.Size.Z) / 2 + 1.5
			local dy = math.abs(p.Y - closest.Y) - inst.Size.Y / 2
			local dxz = Vector3.new(p.X - closest.X, 0, p.Z - closest.Z).Magnitude
			if dxz < radius and dy < 1.5 and t < len - 1 then
				nowFaded[inst] = true
			end
		end
	end
	for part in faded do
		if not nowFaded[part] and part.Parent then
			part.LocalTransparencyModifier = 0
		end
	end
	for part in nowFaded do
		part.LocalTransparencyModifier = 0.75
	end
	faded = nowFaded
end

local function setupCharacter(char: Model)
	local h = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if not h then
		return
	end
	CameraMovement.applySpeed()
	local cam = workspace.CurrentCamera
	if cam then
		cam.FieldOfView = Constants.CAMERA_FOV
	end
	-- İlkin məsafə 12: bir anlıq min=max=12, sonra 8–22 diapazonu
	player.CameraMinZoomDistance = Constants.CAMERA_START_DISTANCE
	player.CameraMaxZoomDistance = Constants.CAMERA_START_DISTANCE
	task.delay(0.3, function()
		player.CameraMinZoomDistance = Constants.CAMERA_MIN_DISTANCE
		player.CameraMaxZoomDistance = Constants.CAMERA_MAX_DISTANCE
	end)
end

function CameraMovement.init(gui: ScreenGui)
	if player.Character then
		task.spawn(setupCharacter, player.Character)
	end
	player.CharacterAdded:Connect(setupCharacter)
	ContextActionService:BindAction(
		"TG_Run",
		function(_name: string, inputState: Enum.UserInputState): Enum.ContextActionResult
			running = inputState == Enum.UserInputState.Begin
			CameraMovement.applySpeed()
			return Enum.ContextActionResult.Pass
		end,
		false,
		Enum.KeyCode.LeftShift,
		Enum.KeyCode.ButtonL3
	)
	if UserInputService.TouchEnabled then
		runButton = Kit.button(gui, "ui.run", function()
			runToggle = not runToggle
			if runButton then
				runButton.BackgroundColor3 = if runToggle then Kit.colors.leaf else Kit.colors.bgSoft
			end
			CameraMovement.applySpeed()
		end, {
			style = "soft",
			size = UDim2.fromOffset(80, 52),
			pos = UDim2.new(1, -180, 1, -96),
			anchor = Vector2.new(1, 1),
			textSize = 15,
		})
	end
	Net.StateChanged:Connect(function(s: { [string]: any })
		CameraMovement.applySpeed()
		CameraMovement.setSensitivity(s.settings.camSens or 1)
	end)
end

return CameraMovement
