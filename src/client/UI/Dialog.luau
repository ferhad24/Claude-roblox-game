--!strict
-- NPC dialoqu: 1–3 cümlə, istifadəçi növbətini özü keçir (mətn oxunmadan yox olmur).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NpcDefs = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Defs"):WaitForChild("NpcDefs"))
local Kit = require(script.Parent.Kit)

local Dialog = {}

local frame: Frame
local nameLabel: TextLabel
local textLabel: TextLabel
local nextButton: TextButton
local lines: { string } = {}
local index = 0
local onDone: (() -> ())? = nil

local function show()
	Kit.setText(textLabel, lines[index])
	Kit.setText(nextButton, if index < #lines then "ui.next" else "ui.close")
end

function Dialog.open(npcId: string, done: (() -> ())?)
	local npc = NpcDefs.byId[npcId]
	if not npc then
		return
	end
	lines = npc.lines
	index = 1
	onDone = done
	Kit.setText(nameLabel, npc.nameKey)
	show()
	frame.Visible = true
end

function Dialog.advance()
	if not frame.Visible then
		return
	end
	if index < #lines then
		index += 1
		show()
	else
		frame.Visible = false
		local cb = onDone
		onDone = nil
		if cb then
			cb()
		end
	end
end

function Dialog.isOpen(): boolean
	return frame.Visible
end

function Dialog.init(gui: ScreenGui)
	frame = Kit.frame(gui, {
		name = "Dialog",
		size = UDim2.new(1, -32, 0, 0),
		pos = UDim2.new(0.5, 0, 1, -96),
		anchor = Vector2.new(0.5, 1),
		auto = Enum.AutomaticSize.Y,
		transparency = 0.05,
	})
	local sc = Instance.new("UISizeConstraint")
	sc.MaxSize = Vector2.new(640, 400)
	sc.Parent = frame
	frame.ZIndex = 15
	Kit.padding(frame, 14)
	Kit.list(frame, false, 8)
	nameLabel = Kit.label(
		frame,
		"",
		{ raw = true, textSize = 16, bold = true, color = Kit.colors.accent, order = 1, auto = Enum.AutomaticSize.Y }
	)
	textLabel = Kit.label(frame, "", { raw = true, textSize = 20, order = 2, auto = Enum.AutomaticSize.Y })
	nextButton = Kit.button(frame, "ui.next", function()
		Dialog.advance()
	end, { order = 3, size = UDim2.fromOffset(160, 48) })
	frame.Visible = false
end

return Dialog
