--!strict
-- Toxumçunun görünüşü (bölmə 2): torpaq rəngli kombinezon, yaşıl boyun yaylığı, yarpaq formalı papaq.
-- Dəri tonu (6) və dörd ilkin geyim rəngi pulsuz seçilir. Güc artdıqca bədən şişmir;
-- güc 20-də dekorativ əlcək (bölmə 6). PROTOTİP: Roblox standart personajı + primitiv aksesuarlar.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local CharacterLook = {}

CharacterLook.SKINS = {
	Color3.fromRGB(255, 224, 189),
	Color3.fromRGB(234, 192, 150),
	Color3.fromRGB(205, 155, 110),
	Color3.fromRGB(170, 115, 80),
	Color3.fromRGB(130, 85, 60),
	Color3.fromRGB(95, 65, 45),
}

CharacterLook.OUTFITS = {
	Color3.fromHex("#8E654A"), -- torpaq
	Color3.fromHex("#A8C78D"), -- mamır
	Color3.fromHex("#C87958"), -- terrakota
	Color3.fromHex("#A995CF"), -- lavanda
}

local GLOVE_SOFT = Color3.fromHex("#F4E7CF")
local GLOVE_MASTER = Color3.fromHex("#EDC86D")

local function weldTo(part: BasePart, target: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = part
	w.Part1 = target
	w.Parent = part
end

local function accessoryPart(
	char: Model,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	shape: Enum.PartType?
): Part
	local existing = char:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Shape = shape or Enum.PartType.Block
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.Parent = char
	return p
end

function CharacterLook.apply(char: Model, settings: { [string]: any }, power: number)
	local skin = CharacterLook.SKINS[math.clamp(tonumber(settings.skin) or 2, 1, #CharacterLook.SKINS)]
	local outfit = CharacterLook.OUTFITS[math.clamp(tonumber(settings.outfit) or 1, 1, #CharacterLook.OUTFITS)]
	local found = char:FindFirstChildOfClass("BodyColors")
	local bc: BodyColors
	if found then
		bc = found
	else
		bc = Instance.new("BodyColors")
		bc.Parent = char
	end
	bc.HeadColor3 = skin
	bc.LeftArmColor3 = skin
	bc.RightArmColor3 = skin
	bc.TorsoColor3 = outfit
	bc.LeftLegColor3 = outfit
	bc.RightLegColor3 = outfit

	local head = char:FindFirstChild("Head") :: BasePart?
	if head then
		local hat = accessoryPart(
			char,
			"TG_LeafHat",
			Vector3.new(2.6, 0.3, 1.8),
			head.CFrame * CFrame.new(0, head.Size.Y / 2 + 0.1, 0) * CFrame.Angles(0, 0, math.rad(8)),
			Color3.fromHex("#6FA66A")
		)
		weldTo(hat, head)
		local stem = accessoryPart(
			char,
			"TG_LeafStem",
			Vector3.new(0.15, 0.6, 0.15),
			head.CFrame * CFrame.new(0.2, head.Size.Y / 2 + 0.45, 0),
			Color3.fromHex("#8E654A")
		)
		weldTo(stem, head)
		local scarf = accessoryPart(
			char,
			"TG_Scarf",
			Vector3.new(1.6, 0.35, 1.2),
			head.CFrame * CFrame.new(0, -head.Size.Y / 2 - 0.1, 0),
			Color3.fromHex("#6FA66A")
		)
		weldTo(scarf, head)
	end
	-- Əlcəklər: yumşaq (krem); güc 20-də "Bağın ustası" qızılı əlcəyi
	local gloveColor = if power >= Constants.POWER_MAX then GLOVE_MASTER else GLOVE_SOFT
	for _, handName in { "LeftHand", "RightHand", "Left Arm", "Right Arm" } do
		local hand = char:FindFirstChild(handName) :: BasePart?
		if hand then
			local isR6 = handName:find(" ") ~= nil
			local size = if isR6 then Vector3.new(1.1, 0.5, 1.1) else hand.Size + Vector3.new(0.08, 0.08, 0.08)
			local cf = if isR6 then hand.CFrame * CFrame.new(0, -hand.Size.Y / 2 + 0.25, 0) else hand.CFrame
			local gloveName = "TG_Glove_" .. (handName:gsub(" ", ""))
			local glove = accessoryPart(char, gloveName, size, cf, gloveColor)
			weldTo(glove, hand)
		end
	end
end

return CharacterLook
