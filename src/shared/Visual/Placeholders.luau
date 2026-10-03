--!strict
-- PROTOTİP PLACEHOLDER MODELLƏRİ (bölmə 18–19): yalnız primitiv hissələrdən ibarətdir.
-- Final asset deyil. Hazır model olanda eyni adla ServerStorage.WorldTemplates və ya
-- ReplicatedStorage.Assets.Builds içinə qoyulur və bu fabrik avtomatik olaraq onları istifadə edir
-- (bax: docs/ASSETS.md). Heç bir xarici asset ID istifadə edilmir.
local Shared = script.Parent.Parent
local Types = require(Shared.Types)
local Placement = require(Shared.Core.Placement)

type BuildDef = Types.BuildDef

local Placeholders = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end
Placeholders.rgb = rgb

export type PartProps = {
	name: string?,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	shape: Enum.PartType?,
	material: Enum.Material?,
	transparency: number?,
	collide: boolean?,
	query: boolean?,
	parent: Instance?,
}

function Placeholders.part(props: PartProps): Part
	local p = Instance.new("Part")
	p.Name = props.name or "Part"
	p.Anchored = true
	p.Size = props.size
	p.CFrame = props.cframe
	p.Color = props.color
	p.Shape = props.shape or Enum.PartType.Block
	p.Material = props.material or Enum.Material.SmoothPlastic
	p.Transparency = props.transparency or 0
	p.CanCollide = if props.collide == nil then true else props.collide
	p.CanQuery = if props.query == nil then true else props.query
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = true
	if props.parent then
		p.Parent = props.parent
	end
	return p
end

local function model(name: string, at: CFrame): (Model, Part)
	local m = Instance.new("Model")
	m.Name = name
	local base = Placeholders.part({
		name = "Base",
		size = Vector3.new(0.2, 0.2, 0.2),
		cframe = at,
		color = Color3.new(1, 1, 1),
		transparency = 1,
		collide = false,
		query = false,
		parent = m,
	})
	m.PrimaryPart = base
	return m, base
end
Placeholders.model = model

-- Yer səviyyəsində mərkəzi olan blok (alt səthi y-də)
local function block(
	parent: Instance,
	name: string,
	at: CFrame,
	size: Vector3,
	color: Color3,
	collide: boolean?,
	mat: Enum.Material?
): Part
	return Placeholders.part({
		name = name,
		size = size,
		cframe = at * CFrame.new(0, size.Y / 2, 0),
		color = color,
		collide = collide,
		material = mat,
		parent = parent,
	})
end
Placeholders.block = block

------------------------------------------------------------------------------------------
-- Sabit dünya obyektləri
------------------------------------------------------------------------------------------

function Placeholders.workObject(def: Types.WorkDef, at: CFrame, id: string): Model
	local m = model(id, at)
	local size = Vector3.new(def.size[1], def.size[2], def.size[3])
	local color = rgb(def.color)
	local t = def.workType
	if t == "leaf" then
		local leaf = block(m, "Body", at * CFrame.Angles(0, math.rad(25), 0), size, color, false, Enum.Material.Fabric)
		leaf.Shape = Enum.PartType.Block
		local vein = block(
			m,
			"Vein",
			at * CFrame.Angles(0, math.rad(25), 0) * CFrame.new(0, size.Y, 0),
			Vector3.new(size.X * 0.9, 0.1, 0.25),
			color:Lerp(Color3.new(0, 0, 0), 0.3),
			false
		)
		vein.CanQuery = false
	elseif t == "thread" then
		Placeholders.part({
			name = "Body",
			size = Vector3.new(size.X, size.Y, size.Z),
			cframe = at * CFrame.new(0, size.Y / 2, 0),
			color = color,
			shape = Enum.PartType.Ball,
			material = Enum.Material.Fabric,
			collide = false,
			parent = m,
		})
		for i = 1, 3 do
			Placeholders.part({
				name = "Strand",
				size = Vector3.new(0.2, size.Y * 1.2, 0.2),
				cframe = at * CFrame.new((i - 2) * 1.2, size.Y / 2, 0) * CFrame.Angles(0, 0, math.rad((i - 2) * 25)),
				color = color,
				collide = false,
				query = false,
				parent = m,
			})
		end
	elseif t == "branch" then
		Placeholders.part({
			name = "Body",
			size = Vector3.new(size.X, size.Y, size.Y),
			cframe = at * CFrame.new(0, size.Y / 2, 0) * CFrame.Angles(0, math.rad(15), 0),
			color = color,
			shape = Enum.PartType.Cylinder,
			material = Enum.Material.Wood,
			collide = false,
			parent = m,
		})
		Placeholders.part({
			name = "Twig",
			size = Vector3.new(size.X * 0.4, size.Y * 0.5, size.Y * 0.5),
			cframe = at * CFrame.new(1, size.Y, 0.8) * CFrame.Angles(0, math.rad(55), math.rad(20)),
			color = color,
			shape = Enum.PartType.Cylinder,
			material = Enum.Material.Wood,
			collide = false,
			query = false,
			parent = m,
		})
	elseif t == "stone_light" or t == "stone_heavy" then
		Placeholders.part({
			name = "Body",
			size = size,
			cframe = at * CFrame.new(0, size.Y / 2, 0),
			color = color,
			shape = Enum.PartType.Ball,
			material = Enum.Material.Slate,
			collide = t == "stone_heavy",
			parent = m,
		})
	elseif t == "glass" then
		block(m, "Body", at, size, color, false, Enum.Material.Glass).Transparency = 0.25
		block(
			m,
			"Dust",
			at * CFrame.new(0, 0, 0),
			size + Vector3.new(0.05, 0, 0.05),
			Color3.fromRGB(150, 140, 120),
			false,
			Enum.Material.Sand
		).Transparency =
			0.3
	elseif t == "root" then
		Placeholders.part({
			name = "Body",
			size = size,
			cframe = at * CFrame.new(0, size.Y / 2, 0),
			color = color,
			shape = Enum.PartType.Ball,
			material = Enum.Material.Wood,
			collide = true,
			parent = m,
		})
		for i = 1, 4 do
			Placeholders.part({
				name = "Coil",
				size = Vector3.new(size.X * 1.1, 1, 1),
				cframe = at * CFrame.new(0, i * 1.2, 0) * CFrame.Angles(0, math.rad(i * 45), 0),
				color = color:Lerp(Color3.new(0, 0, 0), 0.2),
				shape = Enum.PartType.Cylinder,
				material = Enum.Material.Wood,
				collide = false,
				query = false,
				parent = m,
			})
		end
	elseif t == "soil" then
		Placeholders.part({
			name = "Body",
			size = size,
			cframe = at * CFrame.new(0, size.Y / 2, 0),
			color = color,
			shape = Enum.PartType.Ball,
			material = Enum.Material.Ground,
			collide = false,
			parent = m,
		})
	else
		Placeholders.part({
			name = "Body",
			size = size,
			cframe = at * CFrame.new(0, size.Y / 2, 0),
			color = color,
			shape = Enum.PartType.Ball,
			material = Enum.Material.SmoothPlastic,
			collide = false,
			parent = m,
		})
	end
	return m
end

function Placeholders.barrier(parent: Instance, at: CFrame, size: Vector3): Part
	return Placeholders.part({
		name = "Barrier",
		size = size,
		cframe = at * CFrame.new(0, size.Y / 2, 0),
		color = Color3.fromRGB(200, 200, 200),
		transparency = 1,
		collide = true,
		query = false,
		parent = parent,
	})
end

function Placeholders.consumer(def: Types.ConsumerDef, at: CFrame, id: string): Model
	local m = model(id, at)
	local size = Vector3.new(def.size[1], def.size[2], def.size[3])
	local rim = block(m, "Rim", at, size, Color3.fromRGB(142, 101, 74), true, Enum.Material.Wood)
	rim.Transparency = 0
	local soil = block(
		m,
		"Soil",
		at * CFrame.new(0, size.Y - 0.1, 0),
		Vector3.new(size.X - 1, 0.3, size.Z - 1),
		Color3.fromRGB(150, 120, 90),
		false,
		Enum.Material.Ground
	)
	soil.CanQuery = true
	local flowers = Instance.new("Folder")
	flowers.Name = "Flowers"
	flowers.Parent = m
	local n = 0
	for ix = -1, 1 do
		for iz = -1, 1, 2 do
			n += 1
			local stem = Placeholders.part({
				name = "Stem",
				size = Vector3.new(0.3, 2, 0.3),
				cframe = at * CFrame.new(ix * size.X * 0.3, size.Y + 1, iz * size.Z * 0.22),
				color = Color3.fromRGB(111, 166, 106),
				collide = false,
				query = false,
				transparency = 1,
				parent = flowers,
			})
			local headColor = if def.bloom then Color3.fromRGB(255, 220, 120) else Color3.fromRGB(250, 240, 245)
			if n % 2 == 0 and not def.bloom then
				headColor = Color3.fromRGB(169, 149, 207)
			end
			Placeholders.part({
				name = "Head",
				size = Vector3.new(1.2, 1.2, 1.2),
				cframe = stem.CFrame * CFrame.new(0, 1.2, 0),
				color = headColor,
				shape = Enum.PartType.Ball,
				collide = false,
				query = false,
				transparency = 1,
				parent = flowers,
			})
		end
	end
	if def.id == "ROOT_RESERVOIR" then
		rim.Color = Color3.fromRGB(110, 75, 50)
	elseif def.id == "TREE_CROWN" then
		rim.Color = Color3.fromRGB(120, 95, 75)
	end
	return m
end

function Placeholders.source(at: CFrame, id: string, size: { number }): Model
	local m = model(id, at)
	local s = Vector3.new(size[1], size[2], size[3])
	local bowl = Placeholders.part({
		name = "Bowl",
		size = Vector3.new(s.Y, s.X, s.Z),
		cframe = at * CFrame.new(0, s.Y / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		color = Color3.fromRGB(190, 190, 200),
		shape = Enum.PartType.Cylinder,
		material = Enum.Material.Metal,
		parent = m,
	})
	bowl.CanCollide = true
	Placeholders.part({
		name = "Water",
		size = Vector3.new(0.3, s.X * 0.85, s.Z * 0.85),
		cframe = at * CFrame.new(0, s.Y + 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)),
		color = Color3.fromRGB(134, 197, 216),
		shape = Enum.PartType.Cylinder,
		material = Enum.Material.Glass,
		transparency = 0.2,
		collide = false,
		query = false,
		parent = m,
	})
	return m
end

function Placeholders.simple(
	id: string,
	at: CFrame,
	size: { number },
	color: Color3,
	shape: Enum.PartType?,
	collide: boolean?
): Model
	local m = model(id, at)
	local s = Vector3.new(size[1], size[2], size[3])
	Placeholders.part({
		name = "Body",
		size = s,
		cframe = at * CFrame.new(0, s.Y / 2, 0),
		color = color,
		shape = shape,
		collide = if collide == nil then true else collide,
		parent = m,
	})
	return m
end

function Placeholders.npc(id: string, at: CFrame, color: Color3): Model
	local m = model(id, at)
	block(m, "Legs", at, Vector3.new(1.6, 2, 1), Color3.fromRGB(142, 101, 74), true)
	block(m, "Body", at * CFrame.new(0, 2, 0), Vector3.new(2, 2, 1.2), color, true)
	Placeholders.part({
		name = "Head",
		size = Vector3.new(1.6, 1.6, 1.6),
		cframe = at * CFrame.new(0, 4.8, 0),
		color = Color3.fromRGB(244, 231, 207),
		shape = Enum.PartType.Ball,
		parent = m,
	})
	Placeholders.part({
		name = "Hat",
		size = Vector3.new(0.6, 2.4, 2.4),
		cframe = at * CFrame.new(0, 5.7, 0) * CFrame.Angles(0, 0, math.rad(90)),
		color = Color3.fromRGB(111, 166, 106),
		shape = Enum.PartType.Cylinder,
		collide = false,
		parent = m,
	})
	return m
end

function Placeholders.plot(id: string, at: CFrame, size: { number }): Model
	local m = model(id, at)
	block(
		m,
		"Soil",
		at,
		Vector3.new(size[1], size[2], size[3]),
		Color3.fromRGB(120, 90, 65),
		false,
		Enum.Material.Ground
	)
	return m
end

-- Bitki görünüşü mərhələyə görə (1 toxum, 2 cücərti, 3 yarpaq, 4 çiçək)
function Placeholders.plant(def: Types.PlantDef, stage: number, at: CFrame): Model
	local m = model("Plant", at)
	local green = Color3.fromRGB(111, 166, 106)
	if stage <= 1 then
		Placeholders.part({
			name = "Seed",
			size = Vector3.new(0.6, 0.6, 0.6),
			cframe = at * CFrame.new(0, 0.3, 0),
			color = Color3.fromRGB(142, 101, 74),
			shape = Enum.PartType.Ball,
			collide = false,
			query = false,
			parent = m,
		})
	else
		local h = if stage == 2 then 0.8 elseif stage == 3 then 1.8 else 2.4
		Placeholders.part({
			name = "Stem",
			size = Vector3.new(0.25, h, 0.25),
			cframe = at * CFrame.new(0, h / 2, 0),
			color = green,
			collide = false,
			query = false,
			parent = m,
		})
		if stage >= 3 then
			for i = 0, 2 do
				Placeholders.part({
					name = "Leaf",
					size = Vector3.new(1, 0.1, 0.5),
					cframe = at
						* CFrame.new(0, h * 0.6, 0)
						* CFrame.Angles(0, math.rad(i * 120), math.rad(15))
						* CFrame.new(0.5, 0, 0),
					color = green,
					collide = false,
					query = false,
					parent = m,
				})
			end
		end
		if stage >= 4 then
			Placeholders.part({
				name = "Flower",
				size = Vector3.new(1.2, 1.2, 1.2),
				cframe = at * CFrame.new(0, h + 0.4, 0),
				color = rgb(def.color),
				shape = Enum.PartType.Ball,
				collide = false,
				query = false,
				parent = m,
			})
		end
	end
	return m
end

------------------------------------------------------------------------------------------
-- Qurğular
------------------------------------------------------------------------------------------

-- Döndürmə: r=1 lokal +X-i dünya +Z-yə çevirir → yaw = −90° × r
function Placeholders.rotationCFrame(r: number): CFrame
	return CFrame.Angles(0, math.rad(-90 * (r % 4)), 0)
end

function Placeholders.build(def: BuildDef, variant: string?, center: Vector3, r: number, name: string?): Model
	local at = CFrame.new(center) * Placeholders.rotationCFrame(r)
	local m = model(name or def.id, at)
	local color = rgb(def.color)
	local fp = (Placement.variantOf(def, variant))
	local fx, fz = fp[1], fp[2]
	local kind = def.kind
	if kind == "channel" then
		local v = variant or "straight"
		if v == "straight" then
			block(m, "Trough", at, Vector3.new(fx, 0.6, 1.6), color, false, Enum.Material.Wood)
			block(
				m,
				"Water",
				at * CFrame.new(0, 0.6, 0),
				Vector3.new(fx, 0.1, 1.0),
				Color3.fromRGB(134, 197, 216),
				false,
				Enum.Material.Glass
			).Transparency =
				0.6
		else
			local side = if v == "left" then -1 else 1
			block(m, "TroughIn", at * CFrame.new(-1, 0, 0), Vector3.new(2, 0.6, 1.6), color, false, Enum.Material.Wood)
			block(
				m,
				"TroughOut",
				at * CFrame.new(0, 0, side * 1),
				Vector3.new(1.6, 0.6, 2),
				color,
				false,
				Enum.Material.Wood
			)
			block(
				m,
				"Water",
				at * CFrame.new(-0.5, 0.6, 0),
				Vector3.new(1.4, 0.1, 1.0),
				Color3.fromRGB(134, 197, 216),
				false,
				Enum.Material.Glass
			).Transparency =
				0.6
		end
		for _, part in m:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanCollide = false
			end
		end
	elseif kind == "wheel" then
		block(m, "Frame", at, Vector3.new(fx, 0.6, fz), color, true, Enum.Material.Wood)
		Placeholders.part({
			name = "Wheel",
			size = Vector3.new(1, 5, 5),
			cframe = at * CFrame.new(0, 3.2, 0) * CFrame.Angles(0, math.rad(90), 0),
			color = color:Lerp(Color3.new(1, 1, 1), 0.15),
			shape = Enum.PartType.Cylinder,
			material = Enum.Material.Wood,
			collide = false,
			parent = m,
		})
		block(
			m,
			"Water",
			at * CFrame.new(0, 0.6, 0),
			Vector3.new(fx, 0.1, 1.0),
			Color3.fromRGB(134, 197, 216),
			false,
			Enum.Material.Glass
		).Transparency =
			0.6
	elseif kind == "pump" then
		block(m, "Housing", at, Vector3.new(fx * 0.8, def.height, fz * 0.8), color, true, Enum.Material.Metal)
		Placeholders.part({
			name = "Pipe",
			size = Vector3.new(def.height + 2, 0.8, 0.8),
			cframe = at * CFrame.new(fx * 0.4, def.height / 2 + 1, 0) * CFrame.Angles(0, 0, math.rad(90)),
			color = Color3.fromRGB(150, 150, 160),
			shape = Enum.PartType.Cylinder,
			material = Enum.Material.Metal,
			collide = false,
			parent = m,
		})
	elseif kind == "tank" or kind == "catcher" then
		Placeholders.part({
			name = "Body",
			size = Vector3.new(def.height, fx * 0.9, fz * 0.9),
			cframe = at * CFrame.new(0, def.height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
			color = color,
			shape = Enum.PartType.Cylinder,
			material = if kind == "tank" then Enum.Material.Wood else Enum.Material.Fabric,
			parent = m,
		})
		Placeholders.part({
			name = "Water",
			size = Vector3.new(0.3, fx * 0.75, fz * 0.75),
			cframe = at * CFrame.new(0, def.height + 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
			color = Color3.fromRGB(134, 197, 216),
			shape = Enum.PartType.Cylinder,
			material = Enum.Material.Glass,
			transparency = 0.3,
			collide = false,
			query = false,
			parent = m,
		})
		if kind == "catcher" then
			Placeholders.part({
				name = "Leaf",
				size = Vector3.new(fx * 1.6, 0.2, fz * 1.6),
				cframe = at * CFrame.new(0, def.height + 1.5, 0) * CFrame.Angles(math.rad(10), 0, 0),
				color = Color3.fromRGB(111, 166, 106),
				collide = false,
				query = false,
				parent = m,
			})
		end
	elseif kind == "planter" then
		block(m, "Pot", at, Vector3.new(fx * 0.9, def.height, fz * 0.9), color, true, Enum.Material.Slate)
		block(
			m,
			"Soil",
			at * CFrame.new(0, def.height - 0.2, 0),
			Vector3.new(fx * 0.75, 0.3, fz * 0.75),
			Color3.fromRGB(90, 70, 50),
			false,
			Enum.Material.Ground
		)
	elseif kind == "compost" then
		block(m, "Bin", at, Vector3.new(fx * 0.9, def.height, fz * 0.9), color, true, Enum.Material.Wood)
	elseif kind == "lamp" then
		block(m, "Post", at, Vector3.new(0.4, def.height, 0.4), Color3.fromRGB(142, 101, 74), true, Enum.Material.Wood)
		local globe = Placeholders.part({
			name = "Globe",
			size = Vector3.new(1.4, 1.4, 1.4),
			cframe = at * CFrame.new(0, def.height + 0.5, 0),
			color = color,
			shape = Enum.PartType.Ball,
			material = Enum.Material.Neon,
			collide = false,
			parent = m,
		})
		local light = Instance.new("PointLight")
		light.Range = 16
		light.Brightness = 1.2
		light.Color = color
		light.Parent = globe
	elseif kind == "sprinkler" then
		block(
			m,
			"Stand",
			at,
			Vector3.new(0.6, def.height, 0.6),
			Color3.fromRGB(150, 150, 160),
			true,
			Enum.Material.Metal
		)
		Placeholders.part({
			name = "Head",
			size = Vector3.new(1.6, 0.4, 1.6),
			cframe = at * CFrame.new(0, def.height, 0),
			color = color,
			collide = false,
			parent = m,
		})
	elseif kind == "sorter" then
		block(m, "Shelf", at, Vector3.new(fx, def.height, fz), color, true, Enum.Material.Wood)
	else
		-- Dekor və digərləri
		block(
			m,
			"Body",
			at,
			Vector3.new(fx, math.max(0.3, def.height), fz),
			color,
			def.blocksPath,
			Enum.Material.SmoothPlastic
		)
	end
	return m
end

-- Körpü: iki dayaq arasında taxta lövhələr
function Placeholders.bridge(from: Vector3, to: Vector3, width: number, name: string): Model
	local mid = (from + to) / 2
	local length = (to - from).Magnitude
	local at = CFrame.lookAt(mid, to)
	local m = model(name, at)
	local planks = math.max(1, math.floor(length / 1.5))
	for i = 0, planks - 1 do
		local z = -length / 2 + (i + 0.5) * (length / planks)
		Placeholders.part({
			name = "Plank",
			size = Vector3.new(width, 0.4, length / planks * 0.9),
			cframe = at * CFrame.new(0, 0.2, z),
			color = Color3.fromRGB(170, 125, 85),
			material = Enum.Material.Wood,
			parent = m,
		})
	end
	for _, side in { -1, 1 } do
		Placeholders.part({
			name = "Rope",
			size = Vector3.new(0.2, 0.2, length),
			cframe = at * CFrame.new(side * width / 2, 2.5, 0),
			color = Color3.fromRGB(200, 180, 130),
			collide = false,
			query = false,
			parent = m,
		})
		Placeholders.part({
			name = "Rail",
			size = Vector3.new(0.3, 2.5, length),
			cframe = at * CFrame.new(side * width / 2, 1.25, 0),
			color = Color3.fromRGB(200, 180, 130),
			transparency = 1,
			parent = m,
		})
	end
	return m
end

return Placeholders
