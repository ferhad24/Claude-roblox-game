--!strict
-- UI köməkçiləri: tema, mətn qeydiyyatı (dil dəyişəndə yenilənir), minimum 48×48 toxunma hədəfi.
-- Palitra sənəd bölmə 18-dəndir. İkonlar prototipdə rəngli simvollardır (bölmə 19).
local Lang = require(script.Parent.Parent.Lang)

local Kit = {}

Kit.colors = {
	leaf = Color3.fromHex("#6FA66A"),
	moss = Color3.fromHex("#A8C78D"),
	earth = Color3.fromHex("#8E654A"),
	cream = Color3.fromHex("#F4E7CF"),
	terracotta = Color3.fromHex("#C87958"),
	dew = Color3.fromHex("#86C5D8"),
	lavender = Color3.fromHex("#A995CF"),
	accent = Color3.fromHex("#EDC86D"),
	bg = Color3.fromHex("#243A2B"),
	text = Color3.fromHex("#FFF8E9"),
	bgSoft = Color3.fromHex("#2F4B37"),
	danger = Color3.fromRGB(214, 120, 96),
	muted = Color3.fromRGB(170, 180, 165),
}

Kit.MIN_TOUCH = 48
Kit.font = Enum.Font.GothamMedium
Kit.fontBold = Enum.Font.GothamBold

local textScale = 1
-- Qeyd: Instance açarları üçün zəif cədvəl istifadə etmirik (Roblox-da Lua obyekti Instance yaşayarkən
-- toplana bilər). Silinmiş elementlər (Parent = nil) yeniləmə zamanı və vaxtaşırı təmizlənir.
local registry: { [Instance]: { key: string, params: { [string]: any }?, base: number } } = {}
local registrations = 0

local function prune()
	for label in registry do
		if label.Parent == nil then
			registry[label] = nil
		end
	end
end

local root: ScreenGui
local uiScale: UIScale? = nil

function Kit.init(playerGui: PlayerGui): ScreenGui
	root = Instance.new("ScreenGui")
	root.Name = "TinyGroveUI"
	root.ResetOnSpawn = false
	root.IgnoreGuiInset = false
	root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	root.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	root.Parent = playerGui
	local scale = Instance.new("UIScale")
	uiScale = scale
	scale.Name = "Scale"
	scale.Parent = root
	local function rescale()
		local cam = workspace.CurrentCamera
		if cam then
			local vp = cam.ViewportSize
			-- Telefonlarda kiçiltmirik (48 px toxunma hədəfi qorunur), böyük ekranlarda böyüdürük
			scale.Scale = math.clamp(math.min(vp.X / 1280, vp.Y / 720), 1, 1.4)
		end
	end
	rescale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end
	Lang.Changed:Connect(function()
		Kit.refreshTexts()
	end)
	return root
end

-- Kökdəki UIScale dəyəri (ekran pikseli = offset × miqyas)
function Kit.scale(): number
	return if uiScale then uiScale.Scale else 1
end

function Kit.root(): ScreenGui
	return root
end

function Kit.setTextScale(s: number)
	textScale = s
	prune()
	for label, info in registry do
		if label.Parent then
			(label :: any).TextSize = math.floor(info.base * textScale)
		end
	end
end

function Kit.refreshTexts()
	prune()
	for label, info in registry do
		if label.Parent then
			(label :: any).Text = Lang.t(info.key, info.params)
		end
	end
end

function Kit.corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = parent
end

function Kit.padding(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.Parent = parent
end

function Kit.list(parent: Instance, horizontal: boolean?, gap: number?, align: Enum.HorizontalAlignment?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	l.Padding = UDim.new(0, gap or 6)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	if align then
		l.HorizontalAlignment = align
	end
	if horizontal then
		l.VerticalAlignment = Enum.VerticalAlignment.Center
	end
	l.Parent = parent
	return l
end

export type FrameProps = {
	name: string?,
	size: UDim2?,
	pos: UDim2?,
	anchor: Vector2?,
	color: Color3?,
	transparency: number?,
	radius: number?,
	auto: Enum.AutomaticSize?,
	order: number?,
}

function Kit.frame(parent: Instance, props: FrameProps?): Frame
	local p: FrameProps = props or ({} :: FrameProps)
	local f = Instance.new("Frame")
	f.Name = p.name or "Frame"
	f.Size = p.size or UDim2.fromScale(1, 1)
	f.Position = p.pos or UDim2.new()
	f.AnchorPoint = p.anchor or Vector2.zero
	f.BackgroundColor3 = p.color or Kit.colors.bg
	f.BackgroundTransparency = p.transparency or 0
	f.BorderSizePixel = 0
	f.AutomaticSize = p.auto or Enum.AutomaticSize.None
	f.LayoutOrder = p.order or 0
	if p.radius ~= 0 then
		Kit.corner(f, p.radius)
	end
	f.Parent = parent
	return f
end

export type LabelProps = {
	name: string?,
	size: UDim2?,
	pos: UDim2?,
	anchor: Vector2?,
	textSize: number?,
	bold: boolean?,
	color: Color3?,
	align: Enum.TextXAlignment?,
	wrap: boolean?,
	auto: Enum.AutomaticSize?,
	order: number?,
	params: { [string]: any }?,
	raw: boolean?, -- mətn açarı deyil, hazır mətndir
}

local function applyText(label: any, text: string, props: LabelProps)
	local base = props.textSize or 18
	label.TextSize = math.floor(base * textScale)
	if props.raw then
		label.Text = text
		registry[label] = nil
	else
		label.Text = Lang.t(text, props.params)
		-- Təmizləmə yeni element əlavə olunmazdan ƏVVƏL (o hələ Parent almamış ola bilər)
		registrations += 1
		if registrations % 300 == 0 then
			prune()
		end
		registry[label] = { key = text, params = props.params, base = base }
	end
end

function Kit.label(parent: Instance, text: string, props: LabelProps?): TextLabel
	local p: LabelProps = props or ({} :: LabelProps)
	local l = Instance.new("TextLabel")
	l.Name = p.name or "Label"
	l.Size = p.size or UDim2.new(1, 0, 0, (p.textSize or 18) + 8)
	l.Position = p.pos or UDim2.new()
	l.AnchorPoint = p.anchor or Vector2.zero
	l.BackgroundTransparency = 1
	l.Font = if p.bold then Kit.fontBold else Kit.font
	l.TextColor3 = p.color or Kit.colors.text
	l.TextXAlignment = p.align or Enum.TextXAlignment.Left
	l.TextWrapped = if p.wrap == nil then true else p.wrap
	l.AutomaticSize = p.auto or Enum.AutomaticSize.None
	l.LayoutOrder = p.order or 0
	l.RichText = false
	applyText(l, text, p)
	l.Parent = parent
	return l
end

function Kit.setText(label: any, text: string, params: { [string]: any }?, raw: boolean?)
	local info = registry[label]
	local base = if info then info.base else label.TextSize / textScale
	applyText(label, text, { params = params, raw = raw, textSize = base })
end

export type ButtonProps = LabelProps & {
	style: string?, -- "primary" | "soft" | "ghost" | "danger"
	disabled: boolean?,
}

function Kit.button(parent: Instance, text: string, onClick: () -> (), props: ButtonProps?): TextButton
	local p = props or ({} :: ButtonProps)
	local b = Instance.new("TextButton")
	b.Name = p.name or "Button"
	b.Size = p.size or UDim2.new(0, 140, 0, Kit.MIN_TOUCH)
	b.Position = p.pos or UDim2.new()
	b.AnchorPoint = p.anchor or Vector2.zero
	b.AutoButtonColor = true
	b.Font = Kit.fontBold
	b.TextWrapped = true
	b.LayoutOrder = p.order or 0
	b.AutomaticSize = p.auto or Enum.AutomaticSize.None
	local style = p.style or "primary"
	if style == "primary" then
		b.BackgroundColor3 = Kit.colors.leaf
		b.TextColor3 = Kit.colors.text
	elseif style == "soft" then
		b.BackgroundColor3 = Kit.colors.bgSoft
		b.TextColor3 = Kit.colors.text
	elseif style == "accent" then
		b.BackgroundColor3 = Kit.colors.accent
		b.TextColor3 = Kit.colors.bg
	elseif style == "danger" then
		b.BackgroundColor3 = Kit.colors.terracotta
		b.TextColor3 = Kit.colors.text
	else
		b.BackgroundTransparency = 1
		b.TextColor3 = Kit.colors.text
	end
	if p.disabled then
		b.AutoButtonColor = false
		b.BackgroundColor3 = Kit.colors.bgSoft
		b.TextColor3 = Kit.colors.muted
	end
	Kit.corner(b, 10)
	local sc = Instance.new("UISizeConstraint")
	sc.MinSize = Vector2.new(Kit.MIN_TOUCH, Kit.MIN_TOUCH)
	sc.Parent = b
	applyText(b, text, p)
	b.Activated:Connect(function()
		if not p.disabled then
			onClick()
		end
	end)
	b.Parent = parent
	return b
end

-- Prototip ikonu: rəngli dairə + qısa simvol (final ikonlar M4-də əvəz olunur)
function Kit.icon(parent: Instance, color: Color3, symbol: string, size: number?, order: number?): Frame
	local s = size or 32
	local f =
		Kit.frame(parent, { size = UDim2.fromOffset(s, s), color = color, radius = math.floor(s / 2), order = order })
	f.Name = "Icon"
	local l = Kit.label(f, symbol, {
		raw = true,
		size = UDim2.fromScale(1, 1),
		textSize = math.floor(s * 0.5),
		bold = true,
		align = Enum.TextXAlignment.Center,
		color = Kit.colors.bg,
	})
	l.TextYAlignment = Enum.TextYAlignment.Center
	return f
end

function Kit.scroll(parent: Instance, props: FrameProps?): ScrollingFrame
	local p: FrameProps = props or ({} :: FrameProps)
	local s = Instance.new("ScrollingFrame")
	s.Name = p.name or "Scroll"
	s.Size = p.size or UDim2.fromScale(1, 1)
	s.Position = p.pos or UDim2.new()
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 8
	s.ScrollBarImageColor3 = Kit.colors.moss
	s.CanvasSize = UDim2.new()
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	s.LayoutOrder = p.order or 0
	s.Parent = parent
	return s
end

function Kit.clear(parent: Instance)
	for _, c in parent:GetChildren() do
		if
			not c:IsA("UIListLayout")
			and not c:IsA("UIPadding")
			and not c:IsA("UICorner")
			and not c:IsA("UIGridLayout")
		then
			c:Destroy()
		end
	end
end

function Kit.symbolFor(id: string): string
	-- Kataloq ID-sindən qısa simvol: MAT_FIBER → "F", TOOL_SHEARS_1 → "S"
	local core = id:gsub("^%u+_", "")
	return core:sub(1, 1)
end

return Kit
