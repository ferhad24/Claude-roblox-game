--!strict
-- Client görünüş effektləri (bölmə 13, 18): gün dövrəsi (24 dəq; gecə də yollar görünür),
-- yağış (ayarla söndürülür, mexaniki qazancı qalır), çarxın fırlanması, kanalda su,
-- tapşırıq markeri, bərpadan sonra dekorativ böcəklər (≤ 20, sadə dövrə, sancmır).
-- Titrəşən/yanıb-sönən işıq yoxdur. Azaldılmış hərəkətdə fırlanma və böcək hərəkəti yavaşdır.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Layout = require(Shared.Layout)
local QuestDefs = require(Shared.Defs.QuestDefs)
local Net = require(script.Parent.Parent.Net)
local Kit = require(script.Parent.Parent.UI.Kit)

local Effects = {}

local player = Players.LocalPlayer
local localDay = 0
local rainPart: Part? = nil
local rainEmitter: ParticleEmitter? = nil
local markerGui: BillboardGui
local insects: { { part: Part, center: Vector3, radius: number, speed: number, phase: number, height: number } } = {}
local insectZones: { [string]: boolean } = {}

Effects.reducedMotion = false

-- Bərpadan sonra görünən böcəklər: Z02 uğurböcəyi, Z03 kəpənək, Z05 arı
local INSECTS = {
	{ zone = "Z02", chapter = 2, color = Color3.fromRGB(220, 60, 50), size = 0.5, count = 6 },
	{ zone = "Z03", chapter = 3, color = Color3.fromRGB(169, 149, 207), size = 0.7, count = 7 },
	{ zone = "Z05", chapter = 5, color = Color3.fromRGB(237, 200, 109), size = 0.45, count = 7 },
}

-- Gün fazaları: 12 dəq gündüz (06→18), 6 dəq axşam (18→21), 6 dəq gecə (21→06)
local function clockFor(t: number): number
	if t < Constants.DAY_PHASE_DAY then
		return 6 + 12 * (t / Constants.DAY_PHASE_DAY)
	elseif t < Constants.DAY_PHASE_DAY + Constants.DAY_PHASE_EVENING then
		return 18 + 3 * ((t - Constants.DAY_PHASE_DAY) / Constants.DAY_PHASE_EVENING)
	end
	local f = (t - Constants.DAY_PHASE_DAY - Constants.DAY_PHASE_EVENING)
		/ (Constants.DAY_LENGTH - Constants.DAY_PHASE_DAY - Constants.DAY_PHASE_EVENING)
	return (21 + 9 * f) % 24
end

local function applyLighting()
	local clock = clockFor(localDay)
	Lighting.ClockTime = clock
	local night = clock >= 19.5 or clock < 5.5
	-- Gecə qara ekran yoxdur: ətraf işıq aşağı düşür, amma yollar görünür
	Lighting.Ambient = if night then Color3.fromRGB(70, 80, 100) else Color3.fromRGB(115, 115, 107)
	Lighting.OutdoorAmbient = if night then Color3.fromRGB(85, 95, 120) else Color3.fromRGB(140, 140, 128)
end

local function setRain(on: boolean)
	local s = Net.state
	local visible = on and s ~= nil and s.settings.rainFx == true
	if visible and not rainPart then
		local p = Instance.new("Part")
		p.Name = "TG_Rain"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Transparency = 1
		p.Size = Vector3.new(80, 1, 80)
		p.Parent = workspace
		local e = Instance.new("ParticleEmitter")
		e.Rate = if Effects.reducedMotion then 80 else 220
		e.Lifetime = NumberRange.new(1.2)
		e.Speed = NumberRange.new(40)
		e.EmissionDirection = Enum.NormalId.Bottom
		e.Size = NumberSequence.new(0.12)
		e.Color = ColorSequence.new(Color3.fromRGB(200, 225, 235))
		e.Transparency = NumberSequence.new(0.4)
		e.Parent = p
		rainPart = p
		rainEmitter = e
	elseif not visible and rainPart then
		rainPart:Destroy()
		rainPart = nil
		rainEmitter = nil
	end
end

local function updateInsects(s: { [string]: any })
	for _, info in INSECTS do
		local ch = QuestDefs.chapters[info.chapter]
		local restored = s.questDone[ch.steps[#ch.steps].id] == true
		if restored and not insectZones[info.zone] and #insects + info.count <= 20 then
			insectZones[info.zone] = true
			local zl = Layout.zoneLayout[info.zone]
			local base = Vector3.new(zl.safeSpawn[1], zl.safeSpawn[2], zl.safeSpawn[3])
			local rng = Random.new(info.chapter * 99)
			for i = 1, info.count do
				local p = Instance.new("Part")
				p.Name = "Insect"
				p.Anchored = true
				p.CanCollide = false
				p.CanQuery = false
				p.CastShadow = false
				p.Shape = Enum.PartType.Ball
				p.Size = Vector3.new(info.size, info.size, info.size)
				p.Color = info.color
				p.Material = Enum.Material.SmoothPlastic
				p.Parent = workspace
				table.insert(insects, {
					part = p,
					center = base + Vector3.new(rng:NextNumber(-25, 25), 0, rng:NextNumber(-25, 25)),
					radius = rng:NextNumber(2, 6),
					speed = rng:NextNumber(0.4, 0.9),
					phase = i,
					height = rng:NextNumber(2, 6),
				})
			end
		end
	end
end

local function updateMarker(s: { [string]: any })
	local id = s.quest and s.quest.marker
	local obj = id and Layout.byId[id]
	if not obj or not s.settings.markers then
		markerGui.Enabled = false
		return
	end
	local world = workspace:FindFirstChild("World")
	local model = world and world:FindFirstChild(id :: string, true)
	if model and model:IsA("Model") then
		markerGui.Adornee = model.PrimaryPart
		markerGui.Enabled = true
	else
		markerGui.Enabled = false
	end
end

function Effects.update(dt: number)
	local s = Net.state
	if s and not s.paused then
		localDay = (localDay + dt) % Constants.DAY_LENGTH
	end
	applyLighting()
	local cam = workspace.CurrentCamera
	if rainPart and cam then
		rainPart.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 30, 0))
	end
	local now = os.clock()
	-- Çarxlar və kanallar: son 1,5 s-də su keçibsə
	for _, m in CollectionService:GetTagged("TG_Build") do
		if m:IsA("Model") and m.Parent ~= nil then
			local flowT = m:GetAttribute("TG_Flow") :: number?
			local flowing = flowT ~= nil and now - (flowT :: number) < 1.5
			local water = m:FindFirstChild("Water") :: BasePart?
			if water then
				water.Transparency = if flowing then 0.25 else 0.75
			end
			local wheel = m:FindFirstChild("Wheel") :: BasePart?
			if wheel and flowing then
				local speed = if Effects.reducedMotion then 0.8 else 2.5
				wheel.CFrame = wheel.CFrame * CFrame.Angles(speed * dt, 0, 0)
			end
		end
	end
	local t = now
	for _, ins in insects do
		local speed = if Effects.reducedMotion then ins.speed * 0.4 else ins.speed
		local a = t * speed + ins.phase
		ins.part.Position = ins.center
			+ Vector3.new(math.cos(a) * ins.radius, ins.height + math.sin(a * 2) * 0.6, math.sin(a) * ins.radius)
	end
end

function Effects.init()
	markerGui = Instance.new("BillboardGui")
	markerGui.Name = "TG_Marker"
	markerGui.Size = UDim2.fromOffset(40, 40)
	markerGui.StudsOffsetWorldSpace = Vector3.new(0, 11, 0)
	markerGui.AlwaysOnTop = true
	markerGui.LightInfluence = 0
	markerGui.Enabled = false
	markerGui.Parent = player:WaitForChild("PlayerGui")
	local icon = Kit.icon(markerGui, Kit.colors.accent, "▼", 36)
	icon.Position = UDim2.fromOffset(2, 2)

	Net.StateChanged:Connect(function(s: { [string]: any })
		if math.abs(((s.dayTime or 0) - localDay)) > 5 then
			localDay = s.dayTime or 0
		end
		setRain(s.raining == true)
		updateMarker(s)
		updateInsects(s)
	end)
	Net.Event:Connect(function(e: { [string]: any })
		if e.type == "rain" then
			setRain(e.on == true)
		end
	end)
end

return Effects
