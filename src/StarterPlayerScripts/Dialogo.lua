-- Bocadillos de cómic de Don Calabaza: su retrato animado (ViewportFrame) asomando de un círculo y un globo
-- blanco con la cola hacia él. El texto se escribe solo; clic, toque, Espacio o Enter: completa la frase o
-- pasa a la siguiente.  Dialogo.say({"frase 1", "frase 2"}, {npc = calabazaDelMundo})  (espera hasta el final)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local SoundService = game:GetService("SoundService")

local UI = require(script.Parent:WaitForChild("UI"))
local Calabaza = require(script.Parent:WaitForChild("Calabaza"))
local Assets = RS:WaitForChild("Assets")
local player = Players.LocalPlayer
local new = UI.new

local Dialogo = {active = false}

local INK = Color3.fromRGB(26, 14, 20)
local PAPER = Color3.fromRGB(255, 251, 238)
local TEXT = Color3.fromRGB(46, 28, 24)
local ACCENT = Color3.fromRGB(236, 96, 10)
local CPS = 48 -- letras por segundo

local gui = new("ScreenGui", {Name = "Dialogo", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 40, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, player:WaitForChild("PlayerGui"))
local catcher = new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Selectable = false, ZIndex = 1}, gui)
local shade = new("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.45), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 1}, gui)
new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.4)})}, shade)

local box = new("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(1000, 250), BackgroundTransparency = 1, ZIndex = 2}, gui)
local boxScale = new("UIScale", {}, box)
local function rescale()
	local v = workspace.CurrentCamera.ViewportSize
	boxScale.Scale = math.clamp(math.min(v.X / 1060, v.Y / 620), 0.42, 1.1)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()

-- Triángulo con un degradado que corta en diagonal: queda la mitad que mira hacia "rotation"
local function halfRect(parent, props, rotation, color, z)
	local f = new("Frame", props, parent)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = z
	new("UIGradient", {Rotation = rotation, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.495, 1), NumberSequenceKeypoint.new(0.505, 0), NumberSequenceKeypoint.new(1, 0),
	})}, f)
	return f
end

---------- Retrato ----------
local portrait = new("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 6, 1, -4), Size = UDim2.fromOffset(220, 230), BackgroundTransparency = 1, ZIndex = 3}, box)
local disc = new("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.fromOffset(196, 196), BackgroundColor3 = Color3.fromRGB(255, 190, 80), ZIndex = 3}, portrait)
new("UICorner", {CornerRadius = UDim.new(1, 0)}, disc)
new("UIStroke", {Color = INK, Thickness = 6}, disc)
new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 232, 150), Color3.fromRGB(246, 132, 40))}, disc)
-- rayos de fondo (giran despacio)
local rays = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3}, disc)
for k = 0, 5 do
	local r = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 34, 0.88, 0), Rotation = k * 30, BackgroundColor3 = Color3.fromRGB(255, 244, 200), BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 3}, rays)
	new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1)})}, r)
end
local vpf = new("ViewportFrame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40), Size = UDim2.fromOffset(236, 236),
	BackgroundTransparency = 1, Ambient = Color3.fromRGB(176, 158, 150), LightColor = Color3.fromRGB(255, 238, 214),
	LightDirection = Vector3.new(-0.35, -0.7, 1), ZIndex = 4,
}, portrait)
local cam = new("Camera", {FieldOfView = 30}, vpf)
vpf.CurrentCamera = cam
local actor = Calabaza.new({scale = 1})
actor.model.Parent = vpf
cam.CFrame = CFrame.lookAt(Vector3.new(1.4, 6.9, -9.6), Vector3.new(0, 6.15, 0))
local nameTag = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -30), Size = UDim2.fromOffset(238, 46), Rotation = -3, BackgroundColor3 = Color3.fromRGB(255, 120, 18), ZIndex = 6}, portrait)
new("UICorner", {CornerRadius = UDim.new(0, 12)}, nameTag)
new("UIStroke", {Color = INK, Thickness = 4}, nameTag)
new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 166, 50), Color3.fromRGB(236, 96, 10))}, nameTag)
local nameLabel = new("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, TextSize = 25, TextColor3 = Color3.new(1, 1, 1), TextStrokeColor3 = INK, TextStrokeTransparency = 0, Text = "MAYOR PUMPKIN", ZIndex = 7}, nameTag)
new("UIPadding", {PaddingTop = UDim.new(0, 4)}, nameLabel)

---------- Globo ----------
local group = new("Frame", {Position = UDim2.fromOffset(250, 24), Size = UDim2.new(1, -258, 1, -40), BackgroundTransparency = 1, ZIndex = 3}, box)
local bubbleScale = new("UIScale", {}, group)
local bubble = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = PAPER, ZIndex = 3}, group)
new("UICorner", {CornerRadius = UDim.new(0, 30)}, bubble)
new("UIStroke", {Color = INK, Thickness = 6}, bubble)
-- cola hacia el retrato: la negra va detrás del globo (su contorno) y la blanca encima del borde, para "abrirlo"
halfRect(group, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(10, 72), Size = UDim2.fromOffset(76, 54)}, 45, INK, 2)
halfRect(group, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(10, 79), Size = UDim2.fromOffset(57, 41)}, 45, PAPER, 4)
local text = new("TextLabel", {
	Position = UDim2.fromOffset(30, 20), Size = UDim2.new(1, -60, 1, -44), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne,
	TextSize = 30, TextColor3 = TEXT, TextWrapped = true, RichText = true, TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top, Text = "", ZIndex = 6,
}, bubble)
-- triangulito "sigue" que bota abajo a la derecha
local more = new("Frame", {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -26, 1, -16), Size = UDim2.fromOffset(28, 16), BackgroundTransparency = 1, ZIndex = 6}, bubble)
halfRect(more, {Size = UDim2.fromScale(0.5, 1)}, -45, ACCENT, 6)
halfRect(more, {Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.5, 1)}, -135, ACCENT, 6)
local hintLabel = new("TextLabel", {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -62, 1, -10), Size = UDim2.fromOffset(200, 24), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextSize = 17, TextColor3 = Color3.fromRGB(170, 140, 120), TextXAlignment = Enum.TextXAlignment.Right, Text = game:GetService("UserInputService").TouchEnabled and "tap to continue" or "click to continue", ZIndex = 6}, bubble)

---------- Voz: blips con tono variable ----------
local blips = {}
local blipTemplate = Assets:WaitForChild("Sounds"):FindFirstChild("Blip")
if blipTemplate then
	for i = 1, 3 do
		local s = blipTemplate:Clone()
		s.Parent = SoundService
		blips[i] = s
	end
end
local blipIndex = 0
local function blip()
	if #blips == 0 then
		return
	end
	blipIndex = blipIndex % #blips + 1
	local s = blips[blipIndex]
	s.PlaybackSpeed = blipTemplate.PlaybackSpeed * (0.85 + math.random() * 0.35)
	s.TimePosition = 0
	s:Play()
end

---------- Lógica ----------
local clicked = false
local typing = false
local worldNpc
catcher.Activated:Connect(function()
	clicked = true
end)

local function onKey(_, state)
	if state == Enum.UserInputState.Begin then
		clicked = true
	end
	return Enum.ContextActionResult.Sink
end

RunService.RenderStepped:Connect(function(dt)
	if not gui.Enabled then
		return
	end
	actor.talking = typing
	actor:update(dt)
	rays.Rotation = (rays.Rotation + dt * 12) % 360
	more.Position = UDim2.new(1, -26, 1, -16 + math.abs(math.sin(os.clock() * 5)) * -6)
	more.Visible = not typing
	hintLabel.Visible = not typing
	if worldNpc then
		worldNpc.talking = typing
	end
end)

local function typeLine(line)
	text.Text = line
	text.MaxVisibleGraphemes = 0
	local total = utf8.len(text.ContentText) or #text.ContentText
	bubbleScale.Scale = 0.94
	TweenService:Create(bubbleScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), {Scale = 1}):Play()
	typing = true
	clicked = false
	local shown = 0
	local last = 0
	while shown < total do
		local dt = RunService.RenderStepped:Wait()
		if clicked then
			break
		end
		shown = math.min(total, shown + dt * CPS)
		local n = math.floor(shown)
		if n ~= last then
			text.MaxVisibleGraphemes = n
			if n % 2 == 0 then
				blip()
			end
			last = n
		end
	end
	text.MaxVisibleGraphemes = -1
	typing = false
	clicked = false
	while not clicked do
		RunService.RenderStepped:Wait()
	end
	clicked = false
	UI.sound("Click", 0.7)
end

-- Muestra las frases una tras otra y vuelve cuando el jugador ha leído la última
function Dialogo.say(lines, opts)
	opts = opts or {}
	while Dialogo.active do
		task.wait(0.1)
	end
	Dialogo.active = true
	worldNpc = opts.npc
	text.Text = ""
	gui.Enabled = true
	box.Position = UDim2.new(0.5, 0, 1, 300)
	TweenService:Create(box, TweenInfo.new(0.45, Enum.EasingStyle.Back), {Position = UDim2.new(0.5, 0, 1, -16)}):Play()
	ContextActionService:BindActionAtPriority("DialogoSigue", onKey, false, 3000, Enum.KeyCode.Space, Enum.KeyCode.Return, Enum.KeyCode.ButtonA)
	UI.sound("Swoosh", 0.8)
	task.wait(0.35)
	for _, line in lines do
		typeLine(line)
	end
	ContextActionService:UnbindAction("DialogoSigue")
	if worldNpc then
		worldNpc.talking = false
	end
	worldNpc = nil
	TweenService:Create(box, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0.5, 0, 1, 320)}):Play()
	task.wait(0.3)
	gui.Enabled = false
	Dialogo.active = false
end

return Dialogo
