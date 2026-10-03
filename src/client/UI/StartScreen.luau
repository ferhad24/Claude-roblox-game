--!strict
-- Başla / Davam et ekranı; yükləmə və yükləmə xətası (yenidən cəhd). Xəta zamanı köhnə save toxunulmazdır.
local Net = require(script.Parent.Parent.Net)
local Kit = require(script.Parent.Kit)

local StartScreen = {}

local frame: Frame
local status: TextLabel
local startButton: TextButton
local retryButton: TextButton

StartScreen.onStart = nil :: ((boolean) -> ())?

local function apply(msg: { [string]: any })
	if msg.status == "loading" then
		Kit.setText(status, "ui.loading")
		startButton.Visible = false
		retryButton.Visible = false
	elseif msg.status == "failed" then
		Kit.setText(status, "ui.loadFailed")
		startButton.Visible = false
		retryButton.Visible = true
	elseif msg.status == "ready" then
		Kit.setText(status, if msg.testMode then "ui.testMode" else "ui.subtitle")
		Kit.setText(startButton, if msg.isNew then "ui.start" else "ui.continue")
		startButton.Visible = true
		retryButton.Visible = false
	end
end

function StartScreen.hide()
	frame.Visible = false
end

function StartScreen.isVisible(): boolean
	return frame.Visible
end

function StartScreen.init(gui: ScreenGui)
	frame = Kit.frame(gui, { name = "Start", transparency = 0.15, radius = 0 })
	frame.ZIndex = 30
	local box = Kit.frame(frame, {
		size = UDim2.fromOffset(420, 0),
		pos = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		transparency = 1,
		auto = Enum.AutomaticSize.Y,
		radius = 0,
	})
	Kit.list(box, false, 12, Enum.HorizontalAlignment.Center)
	Kit.label(box, "ui.title", {
		textSize = 48,
		bold = true,
		align = Enum.TextXAlignment.Center,
		color = Kit.colors.accent,
		order = 1,
		auto = Enum.AutomaticSize.Y,
	})
	status = Kit.label(
		box,
		"ui.loading",
		{ textSize = 20, align = Enum.TextXAlignment.Center, order = 2, auto = Enum.AutomaticSize.Y }
	)
	startButton = Kit.button(box, "ui.start", function()
		frame.Visible = false
		if StartScreen.onStart then
			StartScreen.onStart(Net.session.isNew == true)
		end
	end, { order = 3, size = UDim2.fromOffset(220, 56), textSize = 22 })
	retryButton = Kit.button(box, "ui.retry", function()
		Kit.setText(status, "ui.loading")
		retryButton.Visible = false
		Net.retryLoad()
	end, { order = 4, size = UDim2.fromOffset(220, 56), style = "accent" })
	startButton.Visible = false
	retryButton.Visible = false
	Net.SessionChanged:Connect(apply)
	apply(Net.session)
end

return StartScreen
