--!strict
-- Dünyanı məlumatdan qurur və oyun vəziyyətini görünüşə çevirir (WorldStateService).
-- Hər sahənin üç görünüşü (baxımsız, qismən, tam bərpa) əvvəlcədən qurulur; düymə basılanda bütöv
-- səhnə yenidən qurulmur, yalnız əlaqəli obyektlər dəyişir (bölmə 5).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Constants = require(Shared.Constants)
local Layout = require(Shared.Layout)
local WorkDefs = require(Shared.Defs.WorkDefs)
local BuildDefs = require(Shared.Defs.BuildDefs)
local PlantDefs = require(Shared.Defs.PlantDefs)
local ZoneDefs = require(Shared.Defs.ZoneDefs)
local QuestDefs = require(Shared.Defs.QuestDefs)
local NpcDefs = require(Shared.Defs.NpcDefs)
local Placement = require(Shared.Core.Placement)
local Game = require(Shared.Core.Game)
local Placeholders = require(Shared.Visual.Placeholders)

type Profile = Types.Profile
type LayoutObject = Types.LayoutObject

local WorldService = {}

local root: Folder
local zoneFolders: { [string]: Folder } = {}
local objectModels: { [string]: Model } = {}
local buildModels: { [string]: Model } = {}
local plantModels: { [string]: Model } = {}
local socketModels: { [string]: Model } = {}
local groundParts: { [string]: { BasePart } } = {}
local stageFolders: { [string]: { [string]: Folder } } = {}
local zoneStage: { [string]: string } = {}
local buildsFolder: Folder

local TAG_INTERACT = "TG_Interact"
local TAG_FOLIAGE = "TG_Foliage"
local TAG_WATER = "TG_Water"

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function tween(inst: Instance, seconds: number, props: { [string]: any })
	TweenService:Create(inst, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), props):Play()
end

-- Final modellər əlavə olunanda onlar istifadə edilir (docs/ASSETS.md)
local function template(folderName: string, name: string): Model?
	local folder = ServerStorage:FindFirstChild(folderName)
	local found = folder and folder:FindFirstChild(name)
	if found and found:IsA("Model") then
		return found:Clone()
	end
	return nil
end

local function buildTemplate(name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local builds = assets and assets:FindFirstChild("Builds")
	local found = builds and builds:FindFirstChild(name)
	if found and found:IsA("Model") then
		return found:Clone()
	end
	return nil
end

local function setAttributes(m: Instance, id: string, kind: string, def: string?, zone: string?)
	m:SetAttribute("TG_Id", id)
	m:SetAttribute("TG_Kind", kind)
	if def then
		m:SetAttribute("TG_Def", def)
	end
	if zone then
		m:SetAttribute("TG_Zone", zone)
	end
end

------------------------------------------------------------------------------------------
-- Qurulma
------------------------------------------------------------------------------------------

-- Deterministik təsadüfi ədəd (ot səpələnməsi hər dəfə eyni olsun)
local function seeded(seed: number): Random
	return Random.new(seed)
end

local function buildZoneDressing(zl: Types.ZoneLayout, folder: Folder)
	local zdef = ZoneDefs.byId[zl.zone]
	local stages: { [string]: Folder } = {}
	for _, stage in { "neglected", "partial", "restored" } do
		local f = Instance.new("Folder")
		f.Name = "Stage_" .. stage
		f.Parent = folder
		stages[stage] = f
	end
	stageFolders[zl.zone] = stages
	-- Ot dəstələri: baxımsızda quru, bərpada yaşıl. Sırf dekor: collision və sorğu yoxdur.
	local rng = seeded(zdef.order * 1337)
	local ox, oz = zdef.origin[1], zdef.origin[3]
	local sx, sz = zdef.size[1], zdef.size[2]
	local y = zdef.origin[2]
	for i = 1, math.floor(sx * sz / 120) do
		local x = ox + rng:NextNumber(2, sx - 2)
		local z = oz + rng:NextNumber(2, sz - 2)
		local onPath = false
		for _, path in zl.paths do
			if x > path.x0 - 1 and x < path.x1 + 1 and z > path.z0 - 1 and z < path.z1 + 1 then
				onPath = true
			end
		end
		if not onPath then
			local h = rng:NextNumber(10, 22) * (if i % 7 == 0 then 1 else 0.45)
			for stage, f in stages do
				local color = if stage == "neglected"
					then Color3.fromRGB(170, 150, 100)
					elseif stage == "partial" then Color3.fromRGB(150, 170, 100)
					else Color3.fromRGB(111, 166, 106)
				local blade = Placeholders.part({
					name = "Grass",
					size = Vector3.new(0.8, h, 0.8),
					cframe = CFrame.new(x, y + h / 2, z)
						* CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), 0, math.rad(rng:NextNumber(-8, 8))),
					color = color,
					collide = false,
					query = false,
					parent = f,
				})
				blade.CastShadow = false
				CollectionService:AddTag(blade, TAG_FOLIAGE)
				if stage == "restored" and i % 3 == 0 then
					local flower = Placeholders.part({
						name = "Flower",
						size = Vector3.new(1.4, 1.4, 1.4),
						cframe = CFrame.new(x, y + h + 0.6, z),
						color = if i % 2 == 0 then Color3.fromRGB(250, 240, 245) else Color3.fromRGB(237, 200, 109),
						shape = Enum.PartType.Ball,
						collide = false,
						query = false,
						parent = f,
					})
					flower.CastShadow = false
				end
			end
		end
	end
end

local function buildStatic(zl: Types.ZoneLayout, folder: Folder)
	local zdef = ZoneDefs.byId[zl.zone]
	groundParts[zl.zone] = {}
	for _, g in zl.ground do
		local part = Placeholders.part({
			name = if g.kind then "Ground_" .. g.kind else "Ground",
			size = v3(g.size),
			cframe = CFrame.new(v3(g.pos)),
			color = if g.kind == "undertable" then Color3.fromRGB(120, 100, 80) else rgb(zdef.groundColor.neglected),
			material = Enum.Material.Grass,
			parent = folder,
		})
		if g.kind ~= "undertable" then
			table.insert(groundParts[zl.zone], part)
		end
	end
	for _, w in zl.walls do
		local part = Placeholders.part({
			name = "Wall",
			size = v3(w.size),
			cframe = CFrame.new(v3(w.pos)) * CFrame.Angles(0, math.rad(w.rot or 0), 0),
			color = if w.transparent then Color3.fromRGB(200, 230, 235) else Color3.fromRGB(95, 130, 85),
			material = if w.transparent then Enum.Material.Glass else Enum.Material.Grass,
			transparency = if w.transparent then 0.6 else 0,
			parent = folder,
		})
		-- Oyunçu divarın üstündən tullanıb keçməsin: görünməz hündür hissə
		Placeholders.part({
			name = "WallCap",
			size = Vector3.new(w.size[1], 30, w.size[3]),
			cframe = part.CFrame * CFrame.new(0, w.size[2] / 2 + 15, 0),
			color = Color3.new(1, 1, 1),
			transparency = 1,
			query = false,
			parent = folder,
		})
	end
	for _, wt in zl.water do
		local part = Placeholders.part({
			name = "Stream",
			size = v3(wt.size),
			cframe = CFrame.new(v3(wt.pos)),
			color = Color3.fromRGB(134, 197, 216),
			material = Enum.Material.Glass,
			transparency = 0.35,
			collide = false,
			query = false,
			parent = folder,
		})
		CollectionService:AddTag(part, TAG_WATER)
	end
	for _, prop in zl.props do
		local shape = Enum.PartType.Block
		local size = v3(prop.size)
		local cf = CFrame.new(v3(prop.pos)) * CFrame.Angles(math.rad(prop.tilt or 0), math.rad(prop.rot or 0), 0)
		if prop.shape == "ball" then
			shape = Enum.PartType.Ball
		elseif prop.shape == "cylinder" then
			shape = Enum.PartType.Cylinder
			size = Vector3.new(size.Y, size.X, size.Z)
			cf = cf * CFrame.Angles(0, 0, math.rad(90))
		elseif prop.shape == "cylinderV" then
			shape = Enum.PartType.Cylinder
			size = Vector3.new(size.Y, size.X, size.Z)
			cf = cf * CFrame.Angles(0, 0, math.rad(90))
		end
		local parent: Instance = folder
		if prop.stage and prop.stage ~= "any" then
			parent = stageFolders[zl.zone][prop.stage] or folder
		end
		local part = Placeholders.part({
			name = prop.name or "Prop",
			size = size,
			cframe = cf,
			color = rgb(prop.color),
			shape = shape,
			collide = if prop.collide == nil then true else prop.collide,
			parent = parent,
		})
		part.Material = Enum.Material.SmoothPlastic
	end
end

local function makeObject(obj: LayoutObject): Model?
	local at = CFrame.new(v3(obj.pos)) * CFrame.Angles(0, math.rad(obj.rot or 0), 0)
	local size = Layout.sizeOf(obj)
	local kind = obj.kind
	local m: Model? = template("WorldTemplates", obj.id)
	if not m and obj.def then
		m = template("WorldTemplates", obj.def)
	end
	if m then
		m:PivotTo(at)
		m.Name = obj.id
	elseif kind == "work" then
		local def = WorkDefs.workById[obj.def :: string]
		m = Placeholders.workObject(def, at, obj.id)
	elseif kind == "spot" then
		local def = WorkDefs.workById[(obj.spawns :: { string })[1]]
		m = Placeholders.workObject(def, at, obj.id)
	elseif kind == "consumer" then
		local def = WorkDefs.consumerById[obj.def :: string]
		m = Placeholders.consumer(def, at, obj.id)
	elseif kind == "source" then
		m = Placeholders.source(at, obj.id, size)
	elseif kind == "plot" then
		m = Placeholders.plot(obj.id, at, size)
	elseif kind == "npc" then
		local npc = NpcDefs.byId[obj.def :: string]
		m = Placeholders.npc(obj.id, at, rgb(npc.color))
	elseif kind == "storage" then
		m = Placeholders.simple(obj.id, at, size, Color3.fromRGB(170, 125, 85))
	elseif kind == "workbench" then
		m = Placeholders.simple(obj.id, at, size, Color3.fromRGB(142, 101, 74))
	elseif kind == "board" then
		m = Placeholders.simple(obj.id, at, size, Color3.fromRGB(244, 231, 207))
	elseif kind == "memory" then
		m = Placeholders.simple(obj.id, at, size, Color3.fromRGB(237, 200, 109), Enum.PartType.Ball, false)
	elseif kind == "cargo" then
		m = Placeholders.simple(obj.id, at, size, Color3.fromRGB(200, 121, 88), Enum.PartType.Block, false)
	elseif kind == "dropoff" then
		m = Placeholders.simple(obj.id, at, size, Color3.fromRGB(90, 60, 50), Enum.PartType.Block, false)
	elseif kind == "gate" then
		m = Placeholders.simple(obj.id, at, size, Color3.fromRGB(110, 75, 50), Enum.PartType.Block, true)
	elseif kind == "lamp" then
		m = Placeholders.simple(obj.id, at, { 0.6, 6, 0.6 }, Color3.fromRGB(142, 101, 74))
		local globe = Placeholders.part({
			name = "Globe",
			size = Vector3.new(1.6, 1.6, 1.6),
			cframe = at * CFrame.new(0, 6.6, 0),
			color = Color3.fromRGB(237, 200, 109),
			shape = Enum.PartType.Ball,
			material = Enum.Material.SmoothPlastic,
			collide = false,
			parent = m,
		})
		local light = Instance.new("PointLight")
		light.Name = "Light"
		light.Enabled = false
		light.Range = 20
		light.Brightness = 1.5
		light.Color = Color3.fromRGB(255, 220, 160)
		light.Parent = globe
	elseif kind == "socket" then
		local marker = Placeholders.simple(obj.id, at, size, Color3.fromRGB(170, 125, 85), Enum.PartType.Block, false)
		local body = marker:FindFirstChild("Body") :: BasePart
		body.Transparency = 0.5
		m = marker
	elseif kind == "tree" then
		m = Placeholders.model(obj.id, at)
		Placeholders.part({
			name = "Body",
			size = Vector3.new(size[1] + 2, 6, size[3] + 2),
			cframe = at * CFrame.new(0, 3, 0),
			color = Color3.fromRGB(120, 95, 75),
			transparency = 1,
			collide = false,
			parent = m,
		})
	elseif kind == "home" then
		m = Placeholders.model(obj.id, at)
		Placeholders.part({
			name = "Door",
			size = Vector3.new(4, 7, 1),
			cframe = at * CFrame.new(0, 3.5, -7.5),
			color = Color3.fromRGB(142, 101, 74),
			parent = m,
		})
	end
	if not m then
		return nil
	end
	local model = m :: Model
	setAttributes(model, obj.id, kind, obj.def, obj.zone)
	local extra = obj.extra
	if extra and extra.barrier then
		local b = extra.barrier :: { number }
		Placeholders.barrier(model, at, Vector3.new(b[1], b[2], b[3]))
	end
	if kind ~= "gate" and kind ~= "tree" and kind ~= "home" then
		CollectionService:AddTag(model, TAG_INTERACT)
	end
	if kind == "tree" then
		CollectionService:AddTag(model, TAG_INTERACT)
	end
	return model
end

function WorldService.build()
	root = Instance.new("Folder")
	root.Name = "World"
	for _, zl in Layout.zones do
		local folder = Instance.new("Folder")
		folder.Name = zl.zone
		folder.Parent = root
		zoneFolders[zl.zone] = folder
		buildZoneDressing(zl, folder)
		buildStatic(zl, folder)
		local objs = Instance.new("Folder")
		objs.Name = "Objects"
		objs.Parent = folder
		for _, obj in zl.objects do
			local m = makeObject(obj)
			if m then
				m.Parent = objs
				objectModels[obj.id] = m
			end
		end
	end
	buildsFolder = Instance.new("Folder")
	buildsFolder.Name = "Builds"
	buildsFolder.Parent = root
	-- Başlanğıcda bütün sahələr baxımsız görünüşdədir
	for zone, stages in stageFolders do
		for stage, f in stages do
			f.Parent = if stage == "neglected" then zoneFolders[zone] else nil
		end
		zoneStage[zone] = "neglected"
	end
	root.Parent = workspace
end

------------------------------------------------------------------------------------------
-- Vəziyyətin tətbiqi
------------------------------------------------------------------------------------------

local function fadeOut(m: Model, seconds: number)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			tween(d, seconds, { Transparency = 1 })
		elseif d:IsA("Light") then
			d.Enabled = false
		end
	end
	CollectionService:RemoveTag(m, TAG_INTERACT)
end

local function fadeIn(m: Model, seconds: number)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Base" and d.Name ~= "Barrier" then
			d.CanQuery = true
			local wantCollide = d.Name == "Body" and (m:GetAttribute("TG_Kind") == "work") and false
			d.CanCollide = wantCollide or false
			tween(d, seconds, { Transparency = d:GetAttribute("TG_BaseTransparency") or 0 })
		end
	end
	CollectionService:AddTag(m, TAG_INTERACT)
end

local function rememberTransparency(m: Model)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("TG_BaseTransparency") == nil then
			d:SetAttribute("TG_BaseTransparency", d.Transparency)
		end
	end
end

local function applyConsumer(id: string, p: Profile, animate: boolean)
	local m = objectModels[id]
	if not m then
		return
	end
	local soil = m:FindFirstChild("Soil") :: BasePart?
	local restored = p.restoredObjectIds[id] == true
	local moisture = if restored then Constants.MOISTURE_MAX else (p.moisture[id] or 0)
	local f = moisture / Constants.MOISTURE_MAX
	if soil then
		local dry = Color3.fromRGB(150, 120, 90)
		local wet = Color3.fromRGB(90, 70, 50)
		local target = dry:Lerp(wet, f)
		if animate then
			tween(soil, 1.2, { Color = target })
		else
			soil.Color = target
		end
	end
	local flowers = m:FindFirstChild("Flowers")
	if flowers then
		for _, part in flowers:GetChildren() do
			if part:IsA("BasePart") then
				local t = if restored then 0 else 1
				if animate then
					tween(part, 1.5, { Transparency = t })
				else
					part.Transparency = t
				end
			end
		end
	end
	m:SetAttribute("TG_Restored", restored)
	m:SetAttribute("TG_Moisture", moisture)
end

local function applyObject(id: string, p: Profile, animate: boolean)
	local obj = Layout.byId[id]
	local m = objectModels[id]
	if not obj or not m then
		return
	end
	rememberTransparency(m)
	local kind = obj.kind
	if kind == "work" or kind == "memory" or kind == "cargo" then
		if p.restoredObjectIds[id] then
			if m:GetAttribute("TG_Restored") ~= true then
				m:SetAttribute("TG_Restored", true)
				fadeOut(m, if animate then 1.2 else 0)
				local barrier = m:FindFirstChild("Barrier")
				if barrier then
					barrier:Destroy()
				end
			end
		end
	elseif kind == "spot" then
		local available = p.respawn[id] == nil or p.respawn[id] <= p.playSeconds
		if available and m:GetAttribute("TG_Available") ~= true then
			m:SetAttribute("TG_Available", true)
			fadeIn(m, if animate then 1 else 0)
		elseif not available and m:GetAttribute("TG_Available") ~= false then
			m:SetAttribute("TG_Available", false)
			fadeOut(m, if animate then 0.8 else 0)
		end
	elseif kind == "consumer" then
		applyConsumer(id, p, animate)
	elseif kind == "dropoff" then
		local body = m:FindFirstChild("Body") :: BasePart?
		if body and p.restoredObjectIds[id] then
			body.Color = Color3.fromRGB(200, 121, 88)
			m:SetAttribute("TG_Restored", true)
		end
	elseif kind == "source" then
		local water = m:FindFirstChild("Water") :: BasePart?
		local cap = obj.capacity or 12
		if water then
			local f = math.clamp((p.waterSources[id] or 0) / cap, 0, 1)
			water.Transparency = 0.2 + (1 - f) * 0.7
		end
	end
end

local function zoneProgress(p: Profile, zone: string): string
	for _, ch in QuestDefs.chapters do
		if ch.zone == zone then
			local done = 0
			for _, step in ch.steps do
				if p.quest.done[step.id] then
					done += 1
				end
			end
			if done >= #ch.steps then
				return "restored"
			elseif done >= math.ceil(#ch.steps / 2) then
				return "partial"
			end
			return "neglected"
		end
	end
	return "neglected"
end

local function applyZones(p: Profile, animate: boolean)
	for _, zdef in ZoneDefs.list do
		local stage = zoneProgress(p, zdef.id)
		if zoneStage[zdef.id] ~= stage then
			zoneStage[zdef.id] = stage
			for name, f in stageFolders[zdef.id] do
				f.Parent = if name == stage then zoneFolders[zdef.id] else nil
			end
			local color = rgb((zdef.groundColor :: any)[stage])
			for _, g in groundParts[zdef.id] do
				if animate then
					tween(g, 1.5, { Color = color })
				else
					g.Color = color
				end
			end
		end
	end
	-- Qapılar: sahə açılanda açılır
	for _, obj in Layout.objects do
		if obj.kind == "gate" then
			local m = objectModels[obj.id]
			local extra = obj.extra
			local zone = extra and extra.unlockZone
			if m and zone and p.zones[zone] and m:GetAttribute("TG_Open") ~= true then
				m:SetAttribute("TG_Open", true)
				fadeOut(m, if animate then 1.5 else 0)
			end
		elseif obj.kind == "lamp" then
			local m = objectModels[obj.id]
			local extra = obj.extra
			local chapter = extra and extra.chapter
			local light = m and m:FindFirstChild("Light", true) :: Light?
			if light and chapter then
				local ch = QuestDefs.chapters[chapter]
				local lit = ch ~= nil and p.quest.done[ch.steps[#ch.steps].id] == true
				light.Enabled = lit
				local globe = light.Parent :: BasePart
				globe.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
			end
		end
	end
end

function WorldService.applyPlant(slot: string, p: Profile)
	local plant = p.plants[slot]
	local existing = plantModels[slot]
	local at: CFrame? = nil
	if slot:sub(1, 1) == "B" and not Layout.byId[slot] then
		local b = p.builds[slot:sub(2)]
		if b then
			local c = Placement.worldCenter(b)
			local def = BuildDefs.byId[b.t]
			if c then
				at = CFrame.new(c[1], c[2] + def.height, c[3])
			end
		end
	else
		local obj = Layout.byId[slot]
		if obj then
			local size = Layout.sizeOf(obj)
			at = CFrame.new(obj.pos[1], obj.pos[2] + size[2], obj.pos[3])
		end
	end
	if not plant or not at then
		if existing then
			existing:Destroy()
			plantModels[slot] = nil
		end
		return
	end
	local def = PlantDefs.byId[plant.sp]
	if not def then
		return
	end
	local stage = Game.plantStage(plant.g, def.growSeconds, plant.ready)
	if existing and existing:GetAttribute("TG_Stage") == stage then
		return
	end
	-- Mərhələ dəyişməsi yumşaq 0,5 s keçidlə (bölmə 13)
	if existing then
		local old = existing
		for _, d in old:GetDescendants() do
			if d:IsA("BasePart") then
				tween(d, 0.5, { Transparency = 1 })
			end
		end
		task.delay(0.5, function()
			old:Destroy()
		end)
	end
	local m = Placeholders.plant(def, stage, at :: CFrame)
	m.Name = "Plant_" .. slot
	m:SetAttribute("TG_Stage", stage)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Base" then
			local target = d.Transparency
			d.Transparency = 1
			tween(d, 0.5, { Transparency = target })
		end
	end
	m.Parent = root
	plantModels[slot] = m
end

local function socketBuild(obj: LayoutObject): Model
	local extra: { [string]: any } = obj.extra or {}
	if obj.def == "B_BRIDGE" then
		local span = extra.span :: { number }
		local from = Vector3.new(obj.pos[1] + span[1], obj.pos[2] + span[2], obj.pos[3] + span[3])
		local to = Vector3.new(obj.pos[1] + span[4], obj.pos[2] + span[5], obj.pos[3] + span[6])
		local bridge = template("WorldTemplates", "B_BRIDGE")
		if bridge then
			-- Hazır model Z oxu boyunca, pivot mərkəzdə qurulmalıdır (docs/ASSETS.md)
			bridge:PivotTo(CFrame.new((from + to) / 2))
			return bridge
		end
		return Placeholders.bridge(from, to, extra.width or 6, "Bridge_" .. obj.id)
	end
	-- Lift: şaxta, aşağı və yuxarı platforma
	local m = template("WorldTemplates", "B_LIFT")
	if m then
		m:PivotTo(CFrame.new(v3(obj.pos)))
		return m
	end
	local at = CFrame.new(v3(obj.pos))
	local lift = Placeholders.model("Lift_" .. obj.id, at)
	local top = extra.top :: { number }
	local landing = extra.landing :: { number }
	local height = top[2] - obj.pos[2]
	Placeholders.block(
		lift,
		"Platform",
		at,
		Vector3.new(8, 0.6, 8),
		Color3.fromRGB(170, 125, 85),
		true,
		Enum.Material.Wood
	)
	for _, dx in { -4, 4 } do
		for _, dz in { -4, 4 } do
			Placeholders.block(
				lift,
				"Post",
				at * CFrame.new(dx, 0, dz),
				Vector3.new(0.6, height + 4, 0.6),
				Color3.fromRGB(142, 101, 74),
				true,
				Enum.Material.Wood
			)
		end
	end
	Placeholders.part({
		-- Divarın üzündən (Z=−39) masanın üstünə qədər; divarın görünməz qapağına girmir
		name = "TopDeck",
		size = Vector3.new(8, 0.6, 6),
		cframe = CFrame.new(landing[1], landing[2] - 0.3, landing[3] - 2),
		color = Color3.fromRGB(170, 125, 85),
		material = Enum.Material.Wood,
		parent = lift,
	})
	return lift
end

local function applySockets(p: Profile)
	for _, obj in Layout.objects do
		if obj.kind == "socket" then
			local built = false
			for _, b in p.builds do
				if b.socket == obj.id then
					built = true
				end
			end
			if built and not socketModels[obj.id] then
				local m = socketBuild(obj)
				setAttributes(m, obj.id, "socketBuild", obj.def, obj.zone)
				CollectionService:AddTag(m, TAG_INTERACT)
				m.Parent = buildsFolder
				socketModels[obj.id] = m
				-- Liftin yuxarı dayanacağı ayrıca əlaqə nöqtəsidir (hündürlük fərqi böyükdür)
				local extra = obj.extra
				local landing = extra and extra.landing
				if obj.def == "B_LIFT" and landing then
					local l = landing :: { number }
					local top = Placeholders.model("LiftTop_" .. obj.id, CFrame.new(l[1], l[2], l[3]))
					setAttributes(top, obj.id, "socketBuild", obj.def, obj.zone)
					CollectionService:AddTag(top, TAG_INTERACT)
					top.Parent = buildsFolder
				end
				local marker = objectModels[obj.id]
				if marker then
					fadeOut(marker, 0.5)
				end
			end
		end
	end
end

function WorldService.applyBuild(uid: string, p: Profile)
	local b = p.builds[uid]
	local existing = buildModels[uid]
	if existing then
		existing:Destroy()
		buildModels[uid] = nil
	end
	if not b then
		WorldService.applyPlant("B" .. uid, p)
		return
	end
	if b.socket then
		applySockets(p)
		return
	end
	local def = BuildDefs.byId[b.t]
	local c = Placement.worldCenter(b)
	if not def or not c then
		return
	end
	local center = Vector3.new(c[1], c[2], c[3])
	local m = buildTemplate(b.t)
	if m then
		m:PivotTo(CFrame.new(center) * Placeholders.rotationCFrame(b.r))
	else
		m = Placeholders.build(def, b.v, center, b.r, "B_" .. uid)
	end
	local model = m :: Model
	model.Name = "B_" .. uid
	setAttributes(model, uid, "build", b.t, nil)
	model:SetAttribute("TG_Variant", b.v or "")
	model:SetAttribute("TG_Rot", b.r)
	if b.w then
		model:SetAttribute("TG_Water", b.w)
	end
	CollectionService:AddTag(model, TAG_INTERACT)
	CollectionService:AddTag(model, "TG_Build")
	model.Parent = buildsFolder
	buildModels[uid] = model
	WorldService.applyPlant("B" .. uid, p)
end

function WorldService.applyAll(p: Profile)
	for _, obj in Layout.objects do
		applyObject(obj.id, p, false)
	end
	for slot in p.plants do
		WorldService.applyPlant(slot, p)
	end
	for _, obj in Layout.objects do
		if obj.kind == "plot" then
			WorldService.applyPlant(obj.id, p)
		end
	end
	for uid in p.builds do
		WorldService.applyBuild(uid, p)
	end
	applySockets(p)
	applyZones(p, false)
end

-- Oyun hadisələrini görünüşə çevirir
function WorldService.handleEvent(e: Game.Event, p: Profile)
	local t = e.type
	if t == "restored" or t == "spot" then
		applyObject(e.id, p, true)
	elseif t == "moisture" then
		applyConsumer(e.id, p, true)
	elseif t == "plant" then
		WorldService.applyPlant(e.slot, p)
	elseif t == "build" then
		if e.op == "water" or e.op == "state" then
			local m = buildModels[e.uid]
			local b = p.builds[e.uid]
			if m and b then
				m:SetAttribute("TG_Water", b.w or 0)
				m:SetAttribute("TG_Busy", b.c ~= nil and b.c > 0)
			end
		else
			WorldService.applyBuild(e.uid, p)
		end
	elseif t == "zone" or t == "step" or t == "chapter" or t == "final" then
		applyZones(p, true)
	elseif t == "flow" then
		local now = os.clock()
		for _, uid in e.path or {} do
			local m = buildModels[uid]
			if m then
				m:SetAttribute("TG_Flow", now)
			end
		end
	elseif t == "water" then
		if e.id and Layout.byId[e.id] then
			applyObject(e.id, p, true)
		end
	end
end

-- Mənbələrin su səviyyəsi (saniyədə bir dəfə çağırılır)
function WorldService.refreshSources(p: Profile)
	for _, obj in Layout.objects do
		if obj.kind == "source" then
			applyObject(obj.id, p, false)
		end
	end
end

function WorldService.getObjectModel(id: string): Model?
	return objectModels[id]
end

function WorldService.getRoot(): Folder
	return root
end

return WorldService
