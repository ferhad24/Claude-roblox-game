--!strict
-- Yerləşdirmə önizləməsi (bölmə 11): 1 stud şəbəkə, 90° döndürmə, yaşıl/qırmızı xəyal model, ləğv.
-- Kanal və digər portlu qurğular yaxındakı boş çıxışa avtomatik bitişir.
-- Yoxlama client-də yalnız göstəriş üçündür; yekun qərarı server verir (eyni Placement modulu).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Layout)
local BuildDefs = require(Shared.Defs.BuildDefs)
local Placement = require(Shared.Core.Placement)
local Water = require(Shared.Core.Water)
local Placeholders = require(Shared.Visual.Placeholders)
local Net = require(script.Parent.Parent.Net)
local Kit = require(script.Parent.Parent.UI.Kit)

local Build = {}

local player = Players.LocalPlayer
local active = false
local buildId: string? = nil
local moveUid: string? = nil
local rot = 0
local variant: string? = nil
local ghost: Model? = nil
local ghostKey = ""
local candidate: Placement.PlaceRequest? = nil
local valid = false
local controls: Frame
local renderConn: RBXScriptConnection? = nil
local lastPointer: Vector2? = nil

Build.onFinished = nil :: (() -> ())?

local function camera(): Camera
	return workspace.CurrentCamera :: Camera
end

local function asProfile(s: { [string]: any }): any
	return {
		zones = s.zones,
		builds = s.builds,
		buildInv = s.buildInv,
		plants = s.plants,
		restoredObjectIds = s.restored,
		waterSources = s.waterSources,
		moisture = s.moisture,
	}
end

local function areaAt(x: number, y: number, z: number): Layout_Area?
	for _, area in Layout.areas do
		local o = area.origin
		if
			math.abs(o[2] - y) < 3
			and x >= o[1]
			and x <= o[1] + area.size[1]
			and z >= o[3]
			and z <= o[3] + area.size[2]
		then
			return area :: any
		end
	end
	return nil
end
type Layout_Area = { id: string, origin: { number }, size: { number }, zone: string }

local function setGhostColor(ok: boolean)
	local g = ghost
	if not g then
		return
	end
	local color = if ok then Color3.fromRGB(111, 220, 120) else Color3.fromRGB(230, 90, 80)
	for _, d in g:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Base" then
			d.Color = color
			d.Transparency = 0.45
			d.CanCollide = false
			d.CanQuery = false
			d.CastShadow = false
		end
	end
end

local function rebuildGhost(center: Vector3)
	local def = BuildDefs.byId[buildId :: string]
	local key = ("%s|%s|%d"):format(def.id, variant or "", rot)
	if ghost and ghostKey == key then
		(ghost :: Model):PivotTo(CFrame.new(center) * Placeholders.rotationCFrame(rot))
		return
	end
	if ghost then
		ghost:Destroy()
	end
	local g = Placeholders.build(def, variant, center, rot, "TG_Ghost")
	g.Parent = workspace
	ghost = g
	ghostKey = key
	setGhostColor(valid)
end

-- Yaxındakı boş çıxış portuna bitişmə: qurğunun giriş portu həmin nöqtəyə düşür və axın istiqamətini davam etdirir
local function snapToPort(s: { [string]: any }, hit: Vector3): (Placement.PlaceRequest?, number?)
	local def = BuildDefs.byId[buildId :: string]
	local _, ports = Placement.variantOf(def, variant)
	local inPort = nil
	for _, p in ports do
		if p.dir == "in" then
			inPort = p
		end
	end
	if not inPort then
		return nil, nil
	end
	local profile = asProfile(s)
	local graph = Water.build(profile)
	local best: Placement.PlaceRequest? = nil
	local bestR: number? = nil
	local bestDist = 4
	local function consider(px: number, py: number, pz: number, dirX: number, dirZ: number)
		local key = Water.portKey(px, py, pz)
		if graph.inIndex[key] then
			return
		end
		local d = math.sqrt((hit.X - px) ^ 2 + (hit.Z - pz) ^ 2)
		if d > bestDist then
			return
		end
		for r = 0, 3 do
			local qx, qz = Placement.rotate(inPort.x, inPort.z, r)
			local len = math.sqrt(qx * qx + qz * qz)
			-- Giriş portu çıxışın sahibinə tərəf baxmalıdır: q istiqaməti = −d
			if len > 0 and math.abs(qx / len + dirX) < 0.01 and math.abs(qz / len + dirZ) < 0.01 then
				local cx, cz = px - qx, pz - qz
				local area = areaAt(cx, py, cz)
				if area then
					local req: Placement.PlaceRequest =
						{ area = area.id, x = cx - area.origin[1], z = cz - area.origin[3], r = r, v = variant }
					local ok = Placement.validate(profile, def.id, req, moveUid)
					if ok then
						best, bestR, bestDist = req, r, d
					end
				end
			end
		end
	end
	for _, obj in Layout.objects do
		if obj.kind == "source" and s.zones[obj.zone] and obj.ports then
			for _, p in obj.ports do
				if p.dir == "out" then
					local len = math.sqrt(p.x * p.x + p.z * p.z)
					consider(obj.pos[1] + p.x, obj.pos[2], obj.pos[3] + p.z, p.x / len, p.z / len)
				end
			end
		end
	end
	for uid, b in s.builds do
		if uid ~= moveUid then
			local bdef = BuildDefs.byId[b.t]
			local c = Placement.worldCenter(b)
			if bdef and c then
				for _, wp in Placement.worldPorts(b) do
					if wp.dir == "out" then
						local dx, dz = wp.x - c[1], wp.z - c[3]
						local len = math.sqrt(dx * dx + dz * dz)
						if len > 0 then
							consider(wp.x, wp.y, wp.z, dx / len, dz / len)
						end
					end
				end
			end
		end
	end
	return best, bestR
end

local function pointerRay(): Ray?
	local cam = camera()
	local pos: Vector2
	if UserInputService.TouchEnabled and lastPointer then
		pos = lastPointer :: Vector2
	elseif UserInputService.GamepadEnabled and not UserInputService.MouseEnabled then
		pos = cam.ViewportSize / 2
	else
		pos = UserInputService:GetMouseLocation()
		return cam:ViewportPointToRay(pos.X, pos.Y)
	end
	return cam:ScreenPointToRay(pos.X, pos.Y)
end

local function update()
	if not active or not buildId then
		return
	end
	local s = Net.state
	if not s then
		return
	end
	local ray = pointerRay()
	if not ray then
		return
	end
	local params = RaycastParams.new()
	local ignore: { Instance } = {}
	if ghost then
		table.insert(ignore, ghost)
	end
	if player.Character then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	params.FilterType = Enum.RaycastFilterType.Exclude
	local result = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	if not result then
		return
	end
	local hit = result.Position
	local def = BuildDefs.byId[buildId]
	local req, snappedR = snapToPort(s, hit)
	if req and snappedR then
		rot = snappedR
	else
		local area = areaAt(hit.X, math.floor(hit.Y + 0.5), hit.Z)
		if not area then
			-- Sahədən kənar: qurğu göstərilir, amma qırmızı
			candidate = nil
			valid = false
			rebuildGhost(Vector3.new(math.floor(hit.X + 0.5), hit.Y, math.floor(hit.Z + 0.5)))
			setGhostColor(false)
			return
		end
		req = {
			area = area.id,
			x = math.floor(hit.X - area.origin[1] + 0.5),
			z = math.floor(hit.Z - area.origin[3] + 0.5),
			r = rot,
			v = variant,
		}
	end
	local finalReq = req :: Placement.PlaceRequest
	candidate = finalReq
	local ok = Placement.validate(asProfile(s), def.id, finalReq, moveUid)
	valid = ok
	local area = Layout.areaById[finalReq.area :: string]
	local center =
		Vector3.new(area.origin[1] + (finalReq.x :: number), area.origin[2], area.origin[3] + (finalReq.z :: number))
	rebuildGhost(center)
	setGhostColor(valid)
end

local function stop()
	active = false
	buildId = nil
	moveUid = nil
	candidate = nil
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	ghostKey = ""
	controls.Visible = false
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
	if Build.onFinished then
		Build.onFinished()
	end
end
Build.cancel = stop

local function confirm()
	if not active or not candidate or not valid or not buildId then
		return
	end
	local req = candidate :: Placement.PlaceRequest
	if moveUid then
		Net.request("MoveBuild", { uid = moveUid, area = req.area, x = req.x, z = req.z, r = req.r, v = req.v })
		stop()
	else
		local id = buildId :: string
		Net.request(
			"Place",
			{ build = id, area = req.area, x = req.x, z = req.z, r = req.r, v = req.v },
			function(result: any)
				-- Eyni qurğudan inventarda qalıbsa yerləşdirməyə davam et (kanal xəttini rahat çəkmək üçün)
				local s = Net.state
				if result.ok and s and (s.buildInv[id] or 0) > 0 and active and buildId == id then
					return
				end
				if active then
					stop()
				end
			end
		)
	end
end

local function rotate()
	rot = (rot + 1) % 4
	update()
end

local function cycleVariant()
	local def = buildId and BuildDefs.byId[buildId]
	if not def or not def.variants then
		return
	end
	local list = def.variants
	local idx = 1
	for i, v in list do
		if v.id == (variant or "straight") then
			idx = i
		end
	end
	variant = list[(idx % #list) + 1].id
	if variant == "straight" then
		variant = nil
	end
	update()
end

function Build.start(id: string, uid: string?)
	local def = BuildDefs.byId[id]
	if not def or def.socketOnly then
		return
	end
	if active then
		stop()
	end
	active = true
	buildId = id
	moveUid = uid
	rot = 0
	variant = nil
	if uid and Net.state then
		local b = Net.state.builds[uid]
		if b then
			rot = b.r
			variant = b.v
		end
	end
	controls.Visible = true
	renderConn = RunService.RenderStepped:Connect(update)
end

function Build.isActive(): boolean
	return active
end

-- Cari önizləmə vəziyyəti (UI və testlər üçün)
function Build.preview(): (Placement.PlaceRequest?, boolean)
	return candidate, valid
end

function Build.init(gui: ScreenGui)
	controls = Kit.frame(gui, {
		name = "BuildControls",
		size = UDim2.fromOffset(0, 52),
		pos = UDim2.new(0.5, 0, 1, -76),
		anchor = Vector2.new(0.5, 1),
		transparency = 1,
		auto = Enum.AutomaticSize.X,
		radius = 0,
	})
	Kit.list(controls, true, 8)
	Kit.button(controls, "ui.rotate", rotate, { style = "soft", order = 1, size = UDim2.fromOffset(110, 52) })
	Kit.button(controls, "ui.variant", cycleVariant, { style = "soft", order = 2, size = UDim2.fromOffset(110, 52) })
	Kit.button(controls, "ui.confirm", confirm, { order = 3, size = UDim2.fromOffset(120, 52) })
	Kit.button(controls, "ui.cancel", stop, { style = "danger", order = 4, size = UDim2.fromOffset(110, 52) })
	controls.Visible = false

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not active then
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch then
			-- Mobil: toxunma yalnız xəyal modeli daşıyır; yerləşdirmə ayrıca "Təsdiq" düyməsi ilədir
			if not processed then
				lastPointer = Vector2.new(input.Position.X, input.Position.Y)
			end
			return
		end
		if processed then
			return
		end
		local k = input.KeyCode
		if input.UserInputType == Enum.UserInputType.MouseButton1 or k == Enum.KeyCode.ButtonA then
			confirm()
		elseif k == Enum.KeyCode.R or k == Enum.KeyCode.ButtonX then
			rotate()
		elseif k == Enum.KeyCode.F or k == Enum.KeyCode.ButtonY then
			cycleVariant()
		elseif
			k == Enum.KeyCode.Backspace
			or k == Enum.KeyCode.X
			or k == Enum.KeyCode.ButtonB
			or k == Enum.KeyCode.B
		then
			stop()
		end
	end)
	UserInputService.TouchMoved:Connect(function(input: InputObject, processed: boolean)
		if active and not processed then
			lastPointer = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
end

return Build
