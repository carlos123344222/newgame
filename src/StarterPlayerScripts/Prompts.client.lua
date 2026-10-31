-- Avisos de interacción (ProximityPrompt) con el estilo del kit: píldora oscura con contorno grueso, la tecla en una
-- insignia redonda naranja, la acción y el objeto, y una barra que se llena si hay que mantener pulsado. En móvil (o si
-- el aviso se puede pulsar) la píldora entera es el botón.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UI = require(script.Parent:WaitForChild("UI"))
local player = Players.LocalPlayer
local new = UI.new

local PAD = {
	[Enum.KeyCode.ButtonA] = "A", [Enum.KeyCode.ButtonB] = "B", [Enum.KeyCode.ButtonX] = "X", [Enum.KeyCode.ButtonY] = "Y",
	[Enum.KeyCode.ButtonL1] = "LB", [Enum.KeyCode.ButtonR1] = "RB",
}

-- todos los avisos del mundo usan este estilo (en este cliente)
local function custom(d)
	if d:IsA("ProximityPrompt") then
		d.Style = Enum.ProximityPromptStyle.Custom
	end
end
for _, d in workspace:GetDescendants() do
	custom(d)
end
workspace.DescendantAdded:Connect(custom)

local gui = new("ScreenGui", {Name = "Prompts", ResetOnSpawn = false, DisplayOrder = 8}, player:WaitForChild("PlayerGui"))

local function keyText(prompt, inputType)
	if inputType == Enum.ProximityPromptInputType.Touch then
		return "TAP"
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		return PAD[prompt.GamepadKeyCode] or "?"
	end
	local s = UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
	return s ~= "" and s or prompt.KeyboardKeyCode.Name
end

ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
		return
	end
	local touch = inputType == Enum.ProximityPromptInputType.Touch or prompt.ClickablePrompt
	local bb = new("BillboardGui", {
		Name = "Prompt", AlwaysOnTop = true, Size = UDim2.fromOffset(320, 90), Adornee = prompt.Parent, ResetOnSpawn = false,
		SizeOffset = Vector2.new(prompt.UIOffset.X / 320, prompt.UIOffset.Y / 90), MaxDistance = prompt.MaxActivationDistance * 3,
	}, gui)
	local pop = new("UIScale", {Scale = 0.5}, bb)
	TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Back), {Scale = 1}):Play()

	local pill = UI.round(new(touch and "TextButton" or "Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 58), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, bb), UDim.new(1, 0))
	if touch then
		pill.Text = ""
		pill.AutoButtonColor = false
	end
	UI.gradient(pill, Color3.fromRGB(60, 40, 96), Color3.fromRGB(22, 13, 38))
	new("UIStroke", {Color = UI.INK, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, pill)
	new("UIPadding", {PaddingLeft = UDim.new(0, 40), PaddingRight = UDim.new(0, 22)}, pill)

	-- relleno de "mantén pulsado": se llena desde la izquierda
	-- (en píxeles: un tamaño relativo a la píldora la haría crecer sin fin con AutomaticSize)
	local fill = UI.round(new("Frame", {Name = "Hold", Position = UDim2.fromOffset(-40, 0), Size = UDim2.fromOffset(0, 58), BackgroundColor3 = UI.ORANGE, BackgroundTransparency = 0.35, ZIndex = 1}, pill), UDim.new(1, 0))

	local badge = UI.piece("round", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, -40, 0.5, 0), Size = UDim2.fromOffset(66, 66), ImageColor3 = UI.ORANGE, ZIndex = 3}, pill)
	local key = keyText(prompt, inputType)
	local keyLabel = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromScale(0.8, 0.5), BackgroundTransparency = 1,
		Font = UI.TITLE, TextScaled = true, TextColor3 = UI.WHITE, Text = key, ZIndex = 4,
	}, badge)
	new("UIStroke", {Color = UI.INK, Thickness = 3, LineJoinMode = Enum.LineJoinMode.Round}, keyLabel)
	new("UIPadding", {PaddingTop = UDim.new(0, 3)}, keyLabel)
	new("UITextSizeConstraint", {MaxTextSize = #key > 1 and 18 or 30}, keyLabel)

	local col = new("Frame", {Position = UDim2.fromOffset(4, 0), Size = UDim2.fromOffset(0, 58), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 2}, pill)
	new("UIListLayout", {VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}, col)
	local object = new("TextLabel", {
		Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Font = UI.FONT, TextSize = 14,
		TextColor3 = UI.MUTED, TextXAlignment = Enum.TextXAlignment.Left, Text = prompt.ObjectText, Visible = prompt.ObjectText ~= "", LayoutOrder = 1, ZIndex = 2,
	}, col)
	local action = new("TextLabel", {
		Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Font = UI.TITLE, TextSize = 24,
		TextColor3 = UI.WHITE, TextXAlignment = Enum.TextXAlignment.Left, Text = prompt.ActionText, LayoutOrder = 2, ZIndex = 2,
	}, col)
	new("UIStroke", {Color = UI.INK, Thickness = 3, LineJoinMode = Enum.LineJoinMode.Round}, action)
	new("UIPadding", {PaddingTop = UDim.new(0, 4)}, action)

	-- mantener pulsado
	local holdTween
	local conns = {}
	local function holdBegan()
		if prompt.HoldDuration > 0 then
			fill.Size = UDim2.fromOffset(0, 58)
			holdTween = TweenService:Create(fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), {Size = UDim2.fromOffset(pill.AbsoluteSize.X / pop.Scale - 22, 58)})
			holdTween:Play()
		end
		TweenService:Create(pop, TweenInfo.new(0.1), {Scale = 0.94}):Play()
	end
	local function holdEnded()
		if holdTween then
			holdTween:Cancel()
			holdTween = nil
		end
		TweenService:Create(fill, TweenInfo.new(0.15), {Size = UDim2.fromOffset(0, 58)}):Play()
		TweenService:Create(pop, TweenInfo.new(0.15, Enum.EasingStyle.Back), {Scale = 1}):Play()
	end
	table.insert(conns, prompt.PromptButtonHoldBegan:Connect(holdBegan))
	table.insert(conns, prompt.PromptButtonHoldEnded:Connect(holdEnded))
	table.insert(conns, prompt.Triggered:Connect(function()
		pop.Scale = 1.15
		TweenService:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Scale = 1}):Play()
		badge.ImageColor3 = UI.GREEN
		TweenService:Create(badge, TweenInfo.new(0.4), {ImageColor3 = UI.ORANGE}):Play()
	end))
	-- textos que cambian mientras se ve
	table.insert(conns, prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
		action.Text = prompt.ActionText
	end))
	table.insert(conns, prompt:GetPropertyChangedSignal("ObjectText"):Connect(function()
		object.Text = prompt.ObjectText
		object.Visible = prompt.ObjectText ~= ""
	end))
	if touch then
		table.insert(conns, pill.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				prompt:InputHoldBegin()
			end
		end))
		table.insert(conns, pill.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				prompt:InputHoldEnd()
			end
		end))
	end

	prompt.PromptHidden:Wait()
	for _, c in conns do
		c:Disconnect()
	end
	TweenService:Create(pop, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Scale = 0}):Play()
	task.wait(0.16)
	bb:Destroy()
end)
