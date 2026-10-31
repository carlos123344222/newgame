-- Interfaz: HUD, menú, objetivo, tienda, barra de sustos, medidor de miedo, avisos y transiciones.
-- Todo el texto que ve el jugador está en inglés. Estilo "Your Haunted House" v2: piezas de UI.ATLAS (botón con
-- relieve, sombra suave, brillos, rayos, cinta de título) e iconos de pegatina de UI.ICONS, dibujados en SVG.
-- Piezas comunes para el resto de pantallas: UI.button, UI.window, UI.card, UI.chip, UI.closeButton, UI.menuButton,
-- UI.currencyPill, UI.piece, UI.icon. Los textos con TextStroke reciben un contorno grueso (UIStroke) automáticamente.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local GuiService = game:GetService("GuiService")
local TextService = game:GetService("TextService")

local Config = require(RS:WaitForChild("Config"))
local Assets = RS:WaitForChild("Assets")
local Remote = RS:WaitForChild("Remote")
local player = Players.LocalPlayer

local UI = {}

UI.INK = Color3.fromRGB(27, 12, 38)
UI.DARK = Color3.fromRGB(18, 11, 30)
UI.PANEL = Color3.fromRGB(46, 30, 74)
UI.CARD = Color3.fromRGB(62, 44, 96)
UI.PURPLE = Color3.fromRGB(134, 84, 232)
UI.ORANGE = Color3.fromRGB(255, 138, 30)
UI.GOLD = Color3.fromRGB(255, 212, 70)
UI.RED = Color3.fromRGB(255, 72, 92)
UI.GREEN = Color3.fromRGB(92, 226, 110)
UI.WHITE = Color3.fromRGB(250, 246, 255)
UI.GEM = Color3.fromRGB(80, 220, 255)
UI.BUY = Color3.fromRGB(62, 196, 88)
UI.CANT = Color3.fromRGB(98, 88, 120)
UI.MUTED = Color3.fromRGB(206, 194, 232)
UI.TAB = Color3.fromRGB(88, 66, 130)
UI.TITLE = Enum.Font.LuckiestGuy
UI.SCARY = Enum.Font.Creepster
UI.FONT = Enum.Font.FredokaOne
UI.SMALL = Enum.Font.GothamBold
UI.money = 0

local BUY, CANT, MUTED = UI.BUY, UI.CANT, UI.MUTED
local PANEL_TOP = Color3.fromRGB(70, 46, 112)
local PANEL_BOT = Color3.fromRGB(28, 17, 48)

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end
UI.new = new

local function round(o, r)
	new("UICorner", {CornerRadius = typeof(r) == "UDim" and r or UDim.new(0, r or 12)}, o)
	return o
end
UI.round = round

local function stroke(o, color, thickness, transparency)
	new("UIStroke", {Color = color, Thickness = thickness or 2, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, o)
	return o
end
UI.stroke = stroke

local function gradient(o, a, b, rot)
	new("UIGradient", {Color = ColorSequence.new(a, b), Rotation = rot or 90}, o)
	return o
end
UI.gradient = gradient

---------- Contorno grueso en los textos ----------
-- Todo texto con TextStroke visible recibe un UIStroke (más grueso y redondeado que el TextStroke de 1 px) que sigue
-- su transparencia, así que los fundidos de texto existentes siguen funcionando.
local function outlineText(o)
	if not (o:IsA("TextLabel") or o:IsA("TextButton")) or o.TextStrokeTransparency >= 0.95 then
		return
	end
	for _, c in o:GetChildren() do
		if c:IsA("UIStroke") and c.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
			return
		end
	end
	local s = Instance.new("UIStroke")
	s.Name = "TextOutline"
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Color = o.TextStrokeColor3 == Color3.new(0, 0, 0) and UI.INK or o.TextStrokeColor3
	local function size()
		local h = o.TextScaled and math.min(o.AbsoluteSize.Y * 0.75, 90) or o.TextSize
		s.Thickness = math.clamp(h / 11, 1.5, 6)
	end
	local function alpha()
		local a = math.clamp(o.TextStrokeTransparency * 0.5, 0, 1)
		s.Transparency = 1 - (1 - a) * (1 - o.TextTransparency)
	end
	size()
	alpha()
	o:GetPropertyChangedSignal("TextSize"):Connect(size)
	if o.TextScaled then
		o:GetPropertyChangedSignal("AbsoluteSize"):Connect(size)
	end
	o:GetPropertyChangedSignal("TextTransparency"):Connect(alpha)
	o:GetPropertyChangedSignal("TextStrokeTransparency"):Connect(alpha)
	s.Parent = o
end
UI.outlineText = outlineText
local playerGui = player:WaitForChild("PlayerGui")
playerGui.DescendantAdded:Connect(function(d)
	if d:IsA("TextLabel") or d:IsA("TextButton") then
		task.defer(outlineText, d) -- después de que su script le ponga sus propios UIStroke
	end
end)

---------- Atlas ----------
UI.ICONS = "rbxassetid://114568727191863"
UI.ATLAS = "rbxassetid://75175405766725"
UI.LOGO = "rbxassetid://127911592067338"
UI.PATTERN = "rbxassetid://125866559253774"
UI.DRIP = "rbxassetid://117021709868589"
local ICON_ORDER = {
	"coin", "gem", "house", "cart", "pumpkin", "rotate", "eye", "door",
	"flashlight", "run", "heart", "skull", "chest", "ghost", "lock", "check",
	"bag", "trophy", "close", "star", "target", "wheel", "hammer", "swords",
	"gift", "gear", "plus", "crown", "map", "clock", "lightning", "shield",
	"question", "info", "arrowR", "arrowL", "bat", "candle", "potion", "sparkle",
	"fire", "music", "ticket", "scroll", "bell", "spider", "tombstone", "cauldron",
	"play", "users", "flag", "bone", "moon", "book", "speaker", "hourglass",
	"coins", "key", "mask", "minus", "web", "zombie", "hand", "thumb",
}
local ICONS = {}
for i, name in ICON_ORDER do
	ICONS[name] = Vector2.new(((i - 1) % 8) * 128, ((i - 1) // 8) * 128)
end
local ICON_SIZE = Vector2.new(128, 128)

function UI.icon(name, props, parent)
	props = props or {}
	props.BackgroundTransparency = 1
	props.Image = UI.ICONS
	props.ImageRectOffset = ICONS[name] or ICONS.target
	props.ImageRectSize = ICON_SIZE
	props.ScaleType = Enum.ScaleType.Fit
	return new("ImageLabel", props, parent)
end

function UI.setIcon(img, name)
	img.ImageRectOffset = ICONS[name] or ICONS.target
end

-- Piezas del atlas de interfaz: {x, y, ancho, alto, SliceCenter si es 9-slice}
local PIECES = {
	button = {0, 0, 128, 128, Rect.new(40, 40, 88, 88)},
	shine = {128, 0, 128, 48, Rect.new(20, 20, 108, 28)},
	round = {256, 0, 128, 128},
	shadow = {384, 0, 128, 128, Rect.new(48, 48, 80, 80)},
	glow = {512, 0, 128, 128},
	sparkle = {640, 0, 64, 64},
	badge = {704, 0, 64, 64},
	track = {768, 0, 128, 128, Rect.new(40, 40, 88, 88)},
	fill = {896, 0, 128, 128, Rect.new(40, 40, 88, 88)},
	rays = {0, 128, 256, 256},
	web = {512, 128, 128, 128},
	ring = {768, 128, 128, 128},
	ribbon = {0, 384, 512, 128, Rect.new(120, 24, 392, 92)},
	vignette = {512, 480, 128, 128, Rect.new(40, 40, 88, 88)},
	glow2 = {640, 480, 128, 128},
	arrow = {768, 480, 64, 64},
	chip = {832, 480, 64, 64, Rect.new(24, 24, 40, 40)},
}
function UI.piece(name, props, parent, class)
	local p = PIECES[name]
	props = props or {}
	props.BackgroundTransparency = 1
	props.Image = UI.ATLAS
	props.ImageRectOffset = Vector2.new(p[1], p[2])
	props.ImageRectSize = Vector2.new(p[3], p[4])
	if p[5] then
		props.ScaleType = Enum.ScaleType.Slice
		props.SliceCenter = p[5]
	end
	return new(class or "ImageLabel", props, parent)
end
local piece = UI.piece

-- Sonidos: plantillas en Assets.Sounds (variantes, volumen normalizado, recorte, grupo de mezcla y anti-saturación:
-- ver ReplicatedStorage.Sfx). gain multiplica el volumen y pitch el tono.
local Sfx = require(RS:WaitForChild("Sfx"))
function UI.sound(name, gain, pitch)
	return Sfx.play(name, nil, gain, pitch)
end

---------- Mezcla (SoundService.Master: Music, Ambience, World y UI) ----------
local master = SoundService:WaitForChild("Master")
local mix = {}
for _, name in {"Music", "Ambience", "World", "UI"} do
	mix[name] = master:WaitForChild(name)
end
local beds = {[mix.Music] = mix.Music.Volume, [mix.Ambience] = mix.Ambience.Volume}

-- La música y el ambiente bajan de golpe y vuelven poco a poco: el susto suena solo y pega más
function UI.duck(depth, time)
	for g, base in beds do
		g.Volume = base * depth
		TweenService:Create(g, TweenInfo.new(time or 1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Volume = base}):Play()
	end
end

-- Sonido apagado, como con los oídos tapados (0..1): amount para la música y el ambiente, world para el mundo
function UI.muffle(amount, world)
	for name, g in mix do
		local eq = g:FindFirstChild("Muffle")
		if eq then
			local a = name == "World" and (world or 0) or amount
			eq.HighGain, eq.MidGain = -a * 40, -a * 12
		end
	end
end

-- Eco de sala dentro de las casas
function UI.reverb(on)
	mix.World.Room.Enabled = on
end

-- Personaje quieto (portada y diálogos). Se puede anidar; también vale para el personaje que aparezca después.
-- (El PlayerModule nuevo no tiene API pública: se frena con la velocidad del Humanoid, que es del cliente.)
local moveLocks = 0
local function applyLock(char)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local sp = game:GetService("StarterPlayer")
	-- al soltar: la velocidad que toca ahora (en una visita se va más despacio)
	local walk = player:GetAttribute("Mode") == "visit" and Config.VISIT_SPEED or sp.CharacterWalkSpeed
	hum.WalkSpeed = moveLocks > 0 and 0 or walk
	hum.JumpHeight = moveLocks > 0 and 0 or sp.CharacterJumpHeight
end
function UI.lockMovement(on)
	moveLocks = math.max(0, moveLocks + (on and 1 or -1))
	applyLock(player.Character)
end
player.CharacterAdded:Connect(function(char)
	if moveLocks > 0 then
		char:WaitForChild("Humanoid", 10)
		applyLock(char)
	end
end)

---------- Pulsar: crece al pasar, se hunde al pulsar (con sus sonidos) ----------
function UI.press(b, hoverScale)
	local pop = b:FindFirstChildOfClass("UIScale") or new("UIScale", {}, b)
	local function to(v)
		TweenService:Create(pop, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {Scale = v}):Play()
	end
	b.MouseEnter:Connect(function()
		to(hoverScale or 1.05)
		UI.sound("Hover")
	end)
	b.MouseLeave:Connect(function()
		to(1)
	end)
	b.MouseButton1Down:Connect(function()
		to(0.92)
		UI.sound("Click")
	end)
	b.MouseButton1Up:Connect(function()
		to(hoverScale or 1.05)
	end)
	return pop
end

-- Botón del kit: base con relieve (9-slice blanca teñida con BackgroundColor3), brillo y el texto en una etiqueta
-- encima con contorno. (El fondo y el texto del propio TextButton quedan invisibles; cambiar Text o
-- BackgroundColor3 sigue funcionando.)
local MIRROR = {"Text", "TextColor3", "TextSize", "Font", "TextScaled", "TextWrapped", "TextXAlignment", "TextYAlignment", "RichText"}
local function button(props, parent)
	props.Radius = nil
	props.Font = props.Font or UI.FONT
	props.TextColor3 = props.TextColor3 or UI.WHITE
	props.BackgroundColor3 = props.BackgroundColor3 or UI.PURPLE
	props.AutoButtonColor = false
	local b = new("TextButton", props, parent)
	b.BackgroundTransparency = 1
	b.TextTransparency = 1
	local z = b.ZIndex
	local base = piece("button", {Name = "Base", Size = UDim2.fromScale(1, 1), ImageColor3 = b.BackgroundColor3, ZIndex = z}, b)
	local shine = piece("shine", {
		Name = "Shine", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.new(1, -14, 0.32, 0),
		ImageTransparency = 0.25, ZIndex = z + 1,
	}, b)
	local label = new("TextLabel", {
		Name = "Label", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -3), Size = UDim2.new(1, -12, 1, -10),
		BackgroundTransparency = 1, TextStrokeTransparency = 0, ZIndex = z + 2,
	}, b)
	for _, p in MIRROR do
		label[p] = b[p]
		b:GetPropertyChangedSignal(p):Connect(function()
			label[p] = b[p]
		end)
	end
	b:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
		base.ImageColor3 = b.BackgroundColor3
	end)
	-- el bisel se adapta al alto del botón
	local function slice()
		local s = math.clamp(b.AbsoluteSize.Y / 110, 0.22, 0.62)
		base.SliceScale = s
		shine.SliceScale = math.clamp(s * 0.9, 0.2, 0.6)
	end
	b:GetPropertyChangedSignal("AbsoluteSize"):Connect(slice)
	slice()
	-- lo que se añada después (iconos, textos) va por encima de la base
	b.ChildAdded:Connect(function(c)
		if c:IsA("GuiObject") and c.ZIndex < z + 2 then
			c.ZIndex = z + 2
		end
	end)
	UI.press(b, 1.04)
	return b
end
UI.button = button

-- Botón con icono a la izquierda (o a la derecha)
local function iconButton(props, parent, icon, right)
	local b = button(props, parent)
	UI.icon(icon, {
		Name = "Icon", AnchorPoint = Vector2.new(right and 1 or 0, 0.5), Position = UDim2.new(right and 1 or 0, right and -6 or 6, 0.5, -3),
		Size = UDim2.fromOffset(36, 36),
	}, b)
	new("UIPadding", {[right and "PaddingRight" or "PaddingLeft"] = UDim.new(0, 32)}, b.Label)
	return b
end
UI.iconButton = iconButton

-- Botón redondo de cerrar (la X roja), para la esquina de las ventanas
function UI.closeButton(parent, props)
	props = props or {}
	props.BackgroundTransparency = 1
	props.Image = UI.ICONS
	props.ImageRectOffset = ICONS.close
	props.ImageRectSize = ICON_SIZE
	props.AutoButtonColor = false
	props.Size = props.Size or UDim2.fromOffset(60, 60)
	local b = new("ImageButton", props, parent)
	UI.press(b, 1.12)
	return b
end

-- Insignia (etiqueta pequeña con contorno): UI.chip("Basic", color, props, parent)
function UI.chip(text, color, props, parent)
	local c = new("TextLabel", {
		Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = color, Font = UI.TITLE, TextSize = 14,
		TextColor3 = UI.WHITE, TextStrokeTransparency = 0, Text = text,
	}, parent)
	round(c, 12)
	stroke(c, UI.INK, 2.5)
	gradient(c, Color3.new(1, 1, 1), Color3.fromRGB(200, 195, 210))
	new("UIPadding", {PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9), PaddingTop = UDim.new(0, 2)}, c)
	for k, v in props or {} do
		c[k] = v
	end
	return c
end

-- Barra de progreso con contorno: devuelve el marco y el relleno (Size en escala X)
function UI.bar(props, parent, color)
	local back = piece("track", props, parent)
	local inner = new("Frame", {Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), BackgroundTransparency = 1, ZIndex = back.ZIndex}, back)
	local fill = piece("fill", {Name = "Fill", Size = UDim2.fromScale(0, 1), ImageColor3 = color or UI.GOLD, ZIndex = back.ZIndex + 1}, inner)
	-- las esquinas no pueden pasar de la mitad del alto
	local function slice()
		local h = back.AbsoluteSize.Y
		back.SliceScale = math.clamp(h / 84, 0.12, 0.5)
		fill.SliceScale = math.clamp((h - 6) / 96, 0.1, 0.45)
	end
	back:GetPropertyChangedSignal("AbsoluteSize"):Connect(slice)
	slice()
	return back, fill
end

---------- Pantallas ----------
local gui = new("ScreenGui", {Name = "HUD", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, playerGui)
local fx = new("ScreenGui", {Name = "FX", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20}, playerGui)
UI.gui = gui

-- En pantallas pequeñas (móvil) todo se escala
local scale = new("UIScale", {}, gui)
local function rescale()
	local size = workspace.CurrentCamera.ViewportSize
	scale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 760), 0.55, 1.15)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()
UI.uiScale = scale

-- Ventana del kit: fondo con degradado, patrón de murciélagos, telaraña, goteo en el borde, sombra, cinta con el
-- título y el icono arriba en el centro y la X roja en la esquina. Devuelve la ventana (los hijos se añaden a ella) y
-- el botón de cerrar.  o = {Name, Size, Position, AnchorPoint, Visible, ZIndex, title, icon, accent, noClose}
local modals = {} -- ventanas que tapan el centro: mientras haya una abierta, el objetivo de arriba se esconde
UI.modals = modals
function UI.window(o, parent)
	local accent = o.accent or UI.PURPLE
	local z = o.ZIndex or 3
	local w = new("Frame", {
		Name = o.Name or "Window", AnchorPoint = o.AnchorPoint or Vector2.new(0.5, 0.5), Position = o.Position or UDim2.fromScale(0.5, 0.52),
		Size = o.Size, BackgroundTransparency = 1, Visible = o.Visible ~= false, ZIndex = z, Active = true,
	}, parent)
	if o.modal ~= false then
		table.insert(modals, w)
	end
	-- sombra y cuerpo por debajo de todo lo que se le añada (ZIndex negativos dentro de la ventana)
	local sh = piece("shadow", {
		Name = "Shadow", Position = UDim2.fromOffset(-30, -18), Size = UDim2.new(1, 60, 1, 64), ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.25, ZIndex = -5,
	}, w)
	sh.SliceScale = 0.8
	local back = round(new("Frame", {Name = "Back", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = -4}, w), 24)
	new("UIGradient", {Name = "Body", Rotation = 90}, back)
	new("UIStroke", {Color = UI.INK, Thickness = 5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, back)
	round(new("ImageLabel", {
		Name = "Pattern", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = UI.PATTERN, ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(200, 200), ImageTransparency = 0.94, ZIndex = -4,
	}, back), 24)
	-- brillo del color de la ventana arriba, detrás de la cinta
	piece("glow2", {
		Name = "TopGlow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0.8, 0, 0, 240),
		ImageColor3 = accent, ImageTransparency = 0.72, ZIndex = -4,
	}, back)
	-- bisel interior
	local bevel = round(new("Frame", {Name = "Bevel", Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -10, 1, -10), BackgroundTransparency = 1, ZIndex = -4}, back), 19)
	new("UIStroke", {Color = accent:Lerp(Color3.new(1, 1, 1), 0.35), Thickness = 2, Transparency = 0.55}, bevel)
	-- goteo bajo el borde de arriba
	new("ImageLabel", {
		Name = "Drip", Position = UDim2.fromOffset(26, 2), Size = UDim2.new(1, -52, 0, 30), BackgroundTransparency = 1, Image = UI.DRIP,
		ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(240, 30), ImageColor3 = accent:Lerp(UI.INK, 0.15), ImageTransparency = 0.15, ZIndex = -4,
	}, back)
	piece("web", {Name = "Web", Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(104, 104), ImageTransparency = 0.78, ZIndex = -4}, back)
	piece("web", {Name = "Web2", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(1, -108, 1, -4), Size = UDim2.fromOffset(104, 104), Rotation = 180, ImageTransparency = 0.82, ZIndex = -4}, back)
	-- cinta con el título
	if o.title then
		local tw = TextService:GetTextSize(o.title, 38, UI.TITLE, Vector2.new(2000, 100)).X
		local ribbon = piece("ribbon", {
			Name = "Ribbon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(tw + (o.icon and 214 or 170), 78),
			ImageColor3 = accent, ZIndex = z + 6,
		}, w)
		ribbon.SliceScale = 0.6
		local row = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 30), Size = UDim2.fromOffset(0, 50), AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1, ZIndex = z + 7,
		}, ribbon)
		new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, row)
		if o.icon then
			UI.icon(o.icon, {Name = "Icon", Size = UDim2.fromOffset(56, 56), LayoutOrder = 1, ZIndex = z + 8}, row)
		end
		local t = new("TextLabel", {
			Name = "Title", Size = UDim2.fromOffset(tw + 4, 46), BackgroundTransparency = 1, Font = UI.TITLE, TextSize = 38, TextColor3 = UI.WHITE,
			Text = o.title, LayoutOrder = 2, ZIndex = z + 8,
		}, row)
		new("UIPadding", {PaddingTop = UDim.new(0, 6)}, t)
		new("UIStroke", {Color = UI.INK, Thickness = 4, LineJoinMode = Enum.LineJoinMode.Round}, t)
		w:SetAttribute("HasRibbon", true)
	end
	local close
	if not o.noClose then
		close = UI.closeButton(w, {Name = "Close", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.fromOffset(64, 64), ZIndex = z + 8})
	end
	UI.setWindowTitle(w, nil, nil, accent)
	return w, close
end

-- Cambia el título, el icono o el color de una ventana hecha con UI.window
function UI.setWindowTitle(w, title, icon, accent)
	local ribbon = w:FindFirstChild("Ribbon")
	local row = ribbon and ribbon:FindFirstChildOfClass("Frame")
	if title and row then
		local tw = TextService:GetTextSize(title, 38, UI.TITLE, Vector2.new(2000, 100)).X
		row.Title.Text = title
		row.Title.Size = UDim2.fromOffset(tw + 4, 46)
		ribbon.Size = UDim2.fromOffset(tw + (row:FindFirstChild("Icon") and 214 or 170), 78)
	end
	if icon and row and row:FindFirstChild("Icon") then
		UI.setIcon(row.Icon, icon)
	end
	if accent then
		if ribbon then
			ribbon.ImageColor3 = accent
		end
		local back = w.Back
		back.Body.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, PANEL_TOP:Lerp(accent, 0.14)), ColorSequenceKeypoint.new(0.35, Color3.fromRGB(46, 30, 76)), ColorSequenceKeypoint.new(1, PANEL_BOT),
		})
		back.TopGlow.ImageColor3 = accent
		back.Drip.ImageColor3 = accent:Lerp(UI.INK, 0.15)
		back.Bevel.UIStroke.Color = accent:Lerp(Color3.new(1, 1, 1), 0.35)
	end
end

-- Ventana que se abre con un "pop"
function UI.popIn(o, from)
	local s = o:FindFirstChild("Pop") or new("UIScale", {Name = "Pop"}, o)
	s.Scale = from or 0.82
	TweenService:Create(s, TweenInfo.new(0.32, Enum.EasingStyle.Back), {Scale = 1}):Play()
end

-- Tarjeta con el color de su rareza: degradado, contorno grueso, bisel de color y brillo de cristal arriba
function UI.card(parent, order, color, props)
	color = color or UI.PURPLE
	props = props or {}
	props.BackgroundColor3 = Color3.new(1, 1, 1)
	props.LayoutOrder = order
	props.ZIndex = props.ZIndex or 3
	local class = props.Class or "Frame"
	props.Class = nil
	local c = round(new(class, props, parent), 18)
	local g = new("UIGradient", {Name = "Tint", Rotation = 90, Color = ColorSequence.new(color:Lerp(PANEL_TOP, 0.35), color:Lerp(UI.DARK, 0.82))}, c)
	local st = new("UIStroke", {Name = "Outline", Color = UI.INK, Thickness = 3.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, c)
	local bevel = round(new("Frame", {Name = "Bevel", Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), BackgroundTransparency = 1, ZIndex = c.ZIndex}, c), 14)
	local bs = new("UIStroke", {Color = color:Lerp(Color3.new(1, 1, 1), 0.4), Thickness = 2, Transparency = 0.35}, bevel)
	return c, {gradient = g, stroke = st, bevel = bs}
end

-- Recolorea una tarjeta hecha con UI.card
function UI.tintCard(c, color)
	local g, b = c:FindFirstChild("Tint"), c:FindFirstChild("Bevel")
	if g then
		g.Color = ColorSequence.new(color:Lerp(PANEL_TOP, 0.35), color:Lerp(UI.DARK, 0.82))
	end
	if b and b:FindFirstChildOfClass("UIStroke") then
		b:FindFirstChildOfClass("UIStroke").Color = color:Lerp(Color3.new(1, 1, 1), 0.4)
	end
end

local flash = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 5}, fx)
local fade = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 10}, fx)

-- Viñeta (bordes oscuros) que crece con el miedo
local vignette = {}
for _, d in {{UDim2.new(1, 0, 0.35, 0), UDim2.new(0, 0, 0, 0), 90}, {UDim2.new(1, 0, 0.35, 0), UDim2.new(0, 0, 0.65, 0), 270}, {UDim2.new(0.3, 0, 1, 0), UDim2.new(0, 0, 0, 0), 0}, {UDim2.new(0.3, 0, 1, 0), UDim2.new(0.7, 0, 0, 0), 180}} do
	local f = new("Frame", {Size = d[1], Position = d[2], BackgroundColor3 = Color3.fromRGB(40, 0, 0), BorderSizePixel = 0, BackgroundTransparency = 1}, fx)
	new("UIGradient", {Rotation = d[3], Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})}, f)
	table.insert(vignette, f)
end

function UI.setVignette(alpha)
	for _, f in vignette do
		f.BackgroundTransparency = 1 - alpha
	end
end

function UI.flash(color, from, time)
	if UI.menuOpen and UI.menuOpen() then
		return
	end
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = from or 0.3
	TweenService:Create(flash, TweenInfo.new(time or 0.6), {BackgroundTransparency = 1}):Play()
end

function UI.fadeOut(t)
	local tw = TweenService:Create(fade, TweenInfo.new(t or 0.4), {BackgroundTransparency = 0})
	tw:Play()
	return tw
end

function UI.fadeIn(t)
	TweenService:Create(fade, TweenInfo.new(t or 0.6), {BackgroundTransparency = 1}):Play()
end

---------- Confeti (pantalla completa, para los grandes momentos): papelitos y destellos ----------
local CONFETTI = {UI.GOLD, UI.ORANGE, UI.PURPLE, UI.GREEN, UI.RED, UI.WHITE, UI.GEM}
function UI.confetti(n, origin)
	local vs = workspace.CurrentCamera.ViewportSize
	if UI.menuOpen and UI.menuOpen() and not origin then
		n, origin = math.min(n or 60, 24), Vector2.new(vs.X * 0.16, vs.Y * 0.08)
	end
	origin = origin or Vector2.new(vs.X / 2, vs.Y * 0.42)
	local bits = {}
	for i = 1, n or 60 do
		local w = math.random(9, 15)
		local a = math.random() * math.pi * 2
		local sp = 300 + math.random() * 700
		local star = i % 5 == 0
		local f
		if star then
			f = piece("sparkle", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(w * 2.4, w * 2.4), ImageColor3 = CONFETTI[math.random(#CONFETTI)], ZIndex = 8}, fx)
		else
			f = round(new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(w, w * 1.6), BackgroundColor3 = CONFETTI[math.random(#CONFETTI)], BorderSizePixel = 0, Rotation = math.random(360), ZIndex = 8}, fx), 3)
		end
		bits[i] = {f = f, star = star, w = w, p = origin, v = Vector2.new(math.cos(a) * sp, math.sin(a) * sp - 550), r = (math.random() - 0.5) * 900, ph = math.random() * 6}
	end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - t0
		for _, b in bits do
			b.v = Vector2.new(b.v.X * (1 - dt * 1.5), b.v.Y + 1300 * dt)
			b.p += b.v * dt
			b.f.Position = UDim2.fromOffset(b.p.X, b.p.Y)
			b.f.Rotation += b.r * dt
			local fadeA = math.clamp((t - 1.5) / 0.6, 0, 1)
			if b.star then
				b.f.ImageTransparency = fadeA
			else
				b.f.Size = UDim2.fromOffset(b.w * math.abs(math.cos(t * 9 + b.ph)), b.w * 1.6) -- aletea como papel
				b.f.BackgroundTransparency = fadeA
			end
		end
		if t > 2.1 then
			conn:Disconnect()
			for _, b in bits do
				b.f:Destroy()
			end
		end
	end)
end

---------- Dinero ----------
-- 1234567 -> "1,234,567"
function UI.fmt(n)
	local s, k = tostring(math.floor(n)), 0
	repeat
		s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return s
end

---------- Ilustraciones del HUD ----------
-- Iconos ilustrados (render 3D cartoon, generados en Figma y recortados) para el menú y las divisas. UI.art(nombre)
-- usa la ilustración si la hay y, si no, el icono del atlas.
UI.ART = {
	house = "rbxassetid://76022608896020", cart = "rbxassetid://77710244567889", swords = "rbxassetid://113144246476731",
	book = "rbxassetid://97621928362686", question = "rbxassetid://102260502564434", coin = "rbxassetid://77406814593874",
	gem = "rbxassetid://93570554604101",
	-- (los de la barra de la Shop: Figma "Your Haunted House - Shop Icons")
	featured = "rbxassetid://126095857680543", pass = "rbxassetid://123896842099528", ghostart = "rbxassetid://93336583341006",
	wheelart = "rbxassetid://95165182567137", tagart = "rbxassetid://96264228775174",
	-- (los de Robux: Figma "Your Haunted House - Robux Shop Art", recortados en Blender)
	robux = "rbxasset://textures/ui/common/robux.png", currency = "rbxassetid://71247878696292",
	coins1 = "rbxassetid://128775346055980", coins2 = "rbxassetid://118673245890785", coins3 = "rbxassetid://139347293936121",
	coins4 = "rbxassetid://96177198227341", coins5 = "rbxassetid://102233363973944",
	gems1 = "rbxassetid://94091052791321", gems2 = "rbxassetid://126523511143258", gems3 = "rbxassetid://71848644197117",
	gems4 = "rbxassetid://77862285826407", gems5 = "rbxassetid://124988590089087",
	coins2x = "rbxassetid://139322735019622", gems2x = "rbxassetid://103101875660682", lucky = "rbxassetid://89012273226389",
}
function UI.art(name, props, parent)
	local img = UI.ART[name]
	if not img then
		return UI.icon(name, props, parent)
	end
	props = props or {}
	props.BackgroundTransparency = 1
	props.Image = img
	props.ScaleType = Enum.ScaleType.Fit
	return new("ImageLabel", props, parent)
end

-- Letra del HUD (como los juegos de defensa: palo seco muy gruesa, blanca con contorno oscuro)
local HUD_FONT = Enum.Font.GothamBlack
UI.HUD_FONT = HUD_FONT
local function hudStroke(label, thickness)
	return new("UIStroke", {Name = "TextOutline", Color = UI.INK, Thickness = thickness or 2, LineJoinMode = Enum.LineJoinMode.Round, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual}, label)
end
UI.hudStroke = hudStroke

---------- Columna izquierda, abajo: el menú y, debajo, las monedas y las gemas ----------
local SIDE_W = 196
local SIDE_DOWN = UDim2.new(0, 16, 1, -14)
local side = new("Frame", {
	Name = "Side", AnchorPoint = Vector2.new(0, 1), Position = SIDE_DOWN, Size = UDim2.fromOffset(SIDE_W, 0),
	AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
}, gui)
new("UIListLayout", {Padding = UDim.new(0, 18), SortOrder = Enum.SortOrder.LayoutOrder}, side)
UI.side = side

-- Monedas y gemas: sin fondo, como en la referencia: la ilustración grande a la izquierda, el nombre en blanco y
-- debajo la cantidad en su color
local currency = new("Frame", {Name = "Currency", Size = UDim2.fromOffset(SIDE_W, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2}, side)
new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, currency)
UI.currency = currency
local CUR_ICON = 54
local CURRENCY_NAMES = {coin = "Coins", gem = "Gems"}
function UI.currencyPill(icon, color, order, parent)
	local pill = new("Frame", {
		Name = icon .. "Pill", Size = UDim2.fromOffset(0, 54), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, LayoutOrder = order or 1,
	}, parent or currency)
	new("UIPadding", {PaddingLeft = UDim.new(0, CUR_ICON + 10), PaddingRight = UDim.new(0, 4)}, pill)
	local ic = UI.art(icon, {Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, -(CUR_ICON / 2 + 8), 0.5, 0), Size = UDim2.fromOffset(CUR_ICON, CUR_ICON), ZIndex = 3}, pill)
	-- "+" en la esquina del icono: abre la Shop en sus packs (UI.openCurrency, de ShopUI)
	local plus = new("TextButton", {
		Name = "Plus", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.1, 0.86), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = UI.WHITE, Text = "",
		AutoButtonColor = false, ZIndex = 4,
	}, ic)
	new("UICorner", {CornerRadius = UDim.new(1, 0)}, plus)
	new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(110, 230, 96), Color3.fromRGB(30, 156, 50))}, plus)
	new("UIStroke", {Color = UI.INK, Thickness = 2}, plus)
	for _, s in {Vector2.new(13, 4), Vector2.new(4, 13)} do
		new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(s.X, s.Y), BackgroundColor3 = UI.WHITE, BorderSizePixel = 0, ZIndex = 5}, plus)
	end
	UI.press(plus, 1.15)
	plus.Activated:Connect(function()
		if UI.openCurrency then
			UI.openCurrency(icon == "gem" and "gems" or "coins")
		end
	end)
	local cap = new("TextLabel", {
		Name = "Caption", Position = UDim2.fromOffset(0, 3), Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
		Font = HUD_FONT, TextSize = 20, TextColor3 = UI.WHITE, TextXAlignment = Enum.TextXAlignment.Left, Text = CURRENCY_NAMES[icon] or "", ZIndex = 2,
	}, pill)
	hudStroke(cap, 2)
	local text = new("TextLabel", {
		Name = "Amount", Position = UDim2.fromOffset(0, 26), Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
		Font = HUD_FONT, TextSize = 23, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, Text = "0", ZIndex = 2,
	}, pill)
	-- (punchMoney hace destellar este contorno)
	local st = hudStroke(text, 2.2)
	return pill, text, ic, st
end

-- fila de las monedas: la píldora y, a su derecha, el "+48" de lo que acabas de ganar
local moneyRow = new("Frame", {Name = "MoneyRow", Size = UDim2.fromOffset(0, 54), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, LayoutOrder = 1}, currency)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder}, moneyRow)
local moneyPill, moneyText, moneyCoin, moneyStroke = UI.currencyPill("coin", Color3.fromRGB(255, 214, 70), 1, moneyRow)
local pillPop = new("UIScale", {}, moneyPill)
UI.moneyPill = moneyPill
local shown, target = 0, 0
local GOLD_TEXT = Color3.fromRGB(255, 214, 70)
RunService.RenderStepped:Connect(function(dt)
	if shown ~= target then
		local step = math.max(1, math.abs(target - shown) * math.min(1, dt * 8))
		shown = shown < target and math.min(target, shown + step) or math.max(target, shown - step)
		moneyText.Text = UI.fmt(shown)
		-- mientras sube, el número brilla en blanco
		moneyText.TextColor3 = shown < target and UI.WHITE or GOLD_TEXT
	elseif moneyText.TextColor3 ~= GOLD_TEXT then
		moneyText.TextColor3 = GOLD_TEXT
	end
end)

-- Golpe del contador: crece, el borde destella y la moneda late
function UI.punchMoney(strength)
	strength = strength or 1
	pillPop.Scale = 1 + 0.12 * strength
	TweenService:Create(pillPop, TweenInfo.new(0.35, Enum.EasingStyle.Back), {Scale = 1}):Play()
	moneyStroke.Color = UI.GOLD
	TweenService:Create(moneyStroke, TweenInfo.new(0.45), {Color = UI.INK}):Play()
	moneyCoin.Size = UDim2.fromOffset(CUR_ICON + 18 * strength, CUR_ICON + 18 * strength)
	moneyCoin.Rotation = math.random(-14, 14)
	TweenService:Create(moneyCoin, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Size = UDim2.fromOffset(CUR_ICON, CUR_ICON), Rotation = 0}):Play()
end

-- "+48" a la derecha del contador: las ganancias seguidas se suman en la misma etiqueta
local delta = new("TextLabel", {
	Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, LayoutOrder = 2,
	Font = HUD_FONT, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, TextStrokeTransparency = 1, Text = "", ZIndex = 4,
}, moneyRow)
local deltaPop = new("UIScale", {}, delta)
local deltaSum, deltaAt, deltaToken = 0, 0, 0
local function showDelta(d)
	local now = os.clock()
	if now - deltaAt > 1.3 or (deltaSum > 0) ~= (d > 0) then
		deltaSum = 0
	end
	deltaSum += d
	deltaAt = now
	deltaToken += 1
	local token = deltaToken
	delta.Text = (deltaSum > 0 and "+" or "-") .. UI.fmt(math.abs(deltaSum))
	delta.TextColor3 = deltaSum > 0 and UI.GREEN or UI.RED
	delta.TextTransparency, delta.TextStrokeTransparency = 0, 0
	deltaPop.Scale = 1.6
	TweenService:Create(deltaPop, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Scale = 1}):Play()
	task.delay(1.3, function()
		if deltaToken == token then
			TweenService:Create(delta, TweenInfo.new(0.4), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
		end
	end)
end

function UI.setMoney(value, instant)
	local d = value - target
	target = value
	UI.money = value
	if instant then
		shown = value
		moneyText.Text = UI.fmt(value)
	elseif d ~= 0 then
		showDelta(d)
		if d > 0 then
			UI.punchMoney(math.clamp(d / 80, 0.6, 1.6))
		end
	end
	if UI.refreshShop then
		UI.refreshShop()
	end
	if not instant and d > 0 and UI.newlyAffordable then
		UI.newlyAffordable(value - d, value)
	end
end

-- Monedas que vuelan desde un punto de la pantalla (píxeles del viewport) hasta el contador
function UI.coinFly(from, count)
	for i = 1, math.min(count or 1, 10) do
		task.delay((i - 1) * 0.05, function()
			local c = UI.art("coin", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(40, 40), ZIndex = 9}, fx)
			local start = from + Vector2.new(math.random(-30, 30), math.random(-30, 30))
			local mid = start + Vector2.new(math.random(-160, 160), -math.random(80, 200))
			local dur = 0.45 + math.random() * 0.2
			local t0 = os.clock()
			while true do
				local a = math.min(1, (os.clock() - t0) / dur)
				local to = moneyCoin.AbsolutePosition + moneyCoin.AbsoluteSize / 2 + GuiService:GetGuiInset()
				local e = a * a
				local p = start:Lerp(mid, e):Lerp(mid:Lerp(to, e), e) -- curva: sale hacia arriba y cae en el contador
				c.Position = UDim2.fromOffset(p.X, p.Y)
				c.Size = UDim2.fromOffset(40 - 12 * a, 40 - 12 * a)
				c.Rotation = a * 360
				if a >= 1 then
					break
				end
				RunService.RenderStepped:Wait()
			end
			c:Destroy()
			UI.punchMoney(0.5)
		end)
	end
end

---------- Combo: "x7 GREAT!" cuando encadenas premios seguidos ----------
local comboLabel = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.22), Size = UDim2.fromScale(0.4, 0.075), BackgroundTransparency = 1,
	Font = UI.TITLE, TextScaled = true, TextStrokeTransparency = 0, Text = "", Visible = false, ZIndex = 7,
}, fx)
local comboPop = new("UIScale", {}, comboLabel)
local COMBO_WORDS = {{40, "GODLIKE!"}, {25, "UNSTOPPABLE!"}, {15, "INSANE!"}, {8, "AMAZING!"}, {5, "GREAT!"}, {3, "NICE!"}}
local comboN, comboAt, comboToken = 0, 0, 0
function UI.combo(word)
	local now = os.clock()
	comboN = now - comboAt < 1.5 and comboN + 1 or 1
	comboAt = now
	if comboN < 3 then
		return
	end
	local praise, milestone = word or "COMBO", false
	for _, w in COMBO_WORDS do
		if comboN >= w[1] then
			praise, milestone = w[2], comboN == w[1]
			break
		end
	end
	comboLabel.Text = ("x%d %s"):format(comboN, praise)
	comboLabel.TextColor3 = UI.GOLD:Lerp(UI.RED, math.clamp((comboN - 3) / 25, 0, 1))
	comboLabel.Rotation = math.random(-7, 7)
	comboLabel.Visible, comboLabel.TextTransparency, comboLabel.TextStrokeTransparency = true, 0, 0
	comboPop.Scale = milestone and 2 or 1.35
	TweenService:Create(comboPop, TweenInfo.new(milestone and 0.5 or 0.25, Enum.EasingStyle.Back), {Scale = 1}):Play()
	if milestone then
		UI.sound("Sparkle", 1, 0.9 + math.min(comboN, 40) / 60)
	end
	comboToken += 1
	local token = comboToken
	task.delay(1.5, function()
		if comboToken == token then
			TweenService:Create(comboLabel, TweenInfo.new(0.35), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
		end
	end)
end

---------- Objetivo: qué hacer ahora (arriba en el centro) ----------
-- (dentro de una franja que se esconde mientras haya una ventana abierta encima)
local goalHolder = new("Frame", {Name = "GoalHolder", Size = UDim2.fromScale(1, 0), BackgroundTransparency = 1}, gui)
local function shown(o)
	while o and o:IsA("GuiObject") do
		if not o.Visible then
			return false
		end
		o = o.Parent
	end
	return o ~= nil and (not o:IsA("LayerCollector") or o.Enabled)
end
RunService.Heartbeat:Connect(function()
	local covered = false
	for _, w in modals do
		if w.Parent and shown(w) then
			covered = true
			break
		end
	end
	goalHolder.Visible = not covered
	UI.menuCovered = covered
end)
-- ¿Hay una ventana o pantalla completa abierta (Troops, Shop, Index...)? Entonces los mensajes grandes van a la esquina
function UI.menuOpen()
	return UI.menuCovered == true
end
local goal = round(new("Frame", {
	Name = "Goal", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(0, 58), AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = Color3.new(1, 1, 1), Visible = false,
}, goalHolder), 20)
gradient(goal, Color3.fromRGB(52, 34, 82), Color3.fromRGB(22, 13, 38))
new("UIStroke", {Color = UI.INK, Thickness = 3.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, goal)
new("UIPadding", {PaddingLeft = UDim.new(0, 50), PaddingRight = UDim.new(0, 22)}, goal)
-- la insignia redonda con el icono asoma por la izquierda (fuera de la lista: posición fija)
local goalBadge = piece("round", {Name = "Badge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, -48, 0.5, 0), Size = UDim2.fromOffset(70, 70), ImageColor3 = UI.ORANGE, ZIndex = 2}, goal)
local goalIcon = UI.icon("target", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromOffset(46, 46), ZIndex = 3}, goalBadge)
local goalText = new("Frame", {Size = UDim2.fromOffset(0, 54), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1}, goal)
new("UIListLayout", {VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}, goalText)
local goalTitle = new("TextLabel", {
	Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Font = UI.TITLE, TextSize = 23,
	TextColor3 = UI.GOLD, TextStrokeTransparency = 0, TextXAlignment = Enum.TextXAlignment.Left, Text = "", LayoutOrder = 1,
}, goalText)
local goalSub = new("TextLabel", {
	Size = UDim2.fromOffset(0, 19), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Font = UI.FONT, TextSize = 15,
	TextColor3 = UI.MUTED, TextXAlignment = Enum.TextXAlignment.Left, Text = "", LayoutOrder = 2,
}, goalText)
local GOAL_COLORS = {house = UI.ORANGE, ghost = UI.PURPLE, trophy = UI.GOLD, skull = UI.RED, target = UI.ORANGE}
-- UI.setHint("título", "detalle", "icono del kit"): sin título se oculta
function UI.setHint(title, sub, icon)
	local was = goal.Visible
	goal.Visible = title ~= nil and title ~= ""
	goalTitle.Text = title or ""
	goalSub.Text = sub or ""
	goalSub.Visible = sub ~= nil and sub ~= ""
	UI.setIcon(goalIcon, icon or "target")
	goalBadge.ImageColor3 = GOAL_COLORS[icon or "target"] or UI.ORANGE
	if goal.Visible and not was then
		UI.popIn(goal, 0.7)
	end
end

---------- Avisos (toasts) ----------
-- Los avisos y el mensaje grande van en su propia capa, por encima de las pantallas completas (Troops, Shop): se ve
-- lo que compras y lo que falta sin cerrarlas. Misma escala que el HUD y se apaga con él.
local overlay = new("ScreenGui", {Name = "Overlay", ResetOnSpawn = false, DisplayOrder = 8, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, playerGui)
local overlayScale = new("UIScale", {Scale = scale.Scale}, overlay)
scale:GetPropertyChangedSignal("Scale"):Connect(function()
	overlayScale.Scale = scale.Scale
end)
gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	overlay.Enabled = gui.Enabled
end)
local toasts = new("Frame", {Name = "Toasts", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 84), Size = UDim2.fromOffset(380, 420), BackgroundTransparency = 1, ZIndex = 50}, overlay)
UI.toasts = toasts
local toastList = new("UIListLayout", {Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder}, toasts)
local function placeToasts()
	local inMenu = UI.menuOpen()
	toasts.AnchorPoint = inMenu and Vector2.new(0, 0) or Vector2.new(1, 0)
	toasts.Position = inMenu and UDim2.fromOffset(16, 6) or UDim2.new(1, -16, 0, 84)
	toastList.HorizontalAlignment = inMenu and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Right
end
local toastCount = 0
local function toastIcon(color)
	if color == UI.RED then
		return "close"
	elseif color == UI.GREEN then
		return "check"
	elseif color == UI.GOLD then
		return "star"
	elseif color == UI.ORANGE then
		return "bell"
	elseif color == UI.GEM then
		return "gem"
	end
	return "info"
end
-- Píldora con el color del aviso en el disco del icono (y en la insignia, si la hay). Sin CanvasGroup: con él se veía
-- gris y como en sombra. opts = {chip = "RARE", tail = "x2", time = 4} (opcional): insignia antes del texto, dorado
-- después y segundos en pantalla.
function UI.toast(text, color, icon, opts)
	opts = opts or {}
	placeToasts()
	toastCount += 1
	color = color or UI.WHITE
	local holder = new("Frame", {Size = UDim2.fromOffset(0, 44), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, LayoutOrder = -toastCount}, toasts)
	local t = round(new("Frame", {Size = UDim2.fromOffset(0, 44), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.new(1, 1, 1)}, holder), UDim.new(1, 0))
	gradient(t, Color3.fromRGB(62, 42, 98), Color3.fromRGB(30, 18, 52))
	new("UIStroke", {Color = UI.INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, t)
	new("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 16)}, t)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 9), SortOrder = Enum.SortOrder.LayoutOrder}, t)
	local disc = round(new("Frame", {Size = UDim2.fromOffset(32, 32), BackgroundColor3 = color, LayoutOrder = 0}, t), UDim.new(1, 0))
	stroke(disc, UI.INK, 2)
	UI.icon(icon or toastIcon(color), {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(28, 28)}, disc)
	if opts.chip then
		local c = UI.chip(opts.chip, color, {TextSize = opts.time and 15 or 13, LayoutOrder = 1}, t)
		c.Size = UDim2.fromOffset(0, opts.time and 26 or 22)
	end
	new("TextLabel", {
		Size = UDim2.fromOffset(0, 44), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Font = UI.FONT, TextSize = 17,
		TextColor3 = opts.chip and UI.WHITE or color:Lerp(UI.WHITE, 0.55), TextStrokeTransparency = 0, Text = text, LayoutOrder = 2,
	}, t)
	if opts.tail then
		local tail = new("TextLabel", {
			Size = UDim2.fromOffset(0, 44), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Font = UI.TITLE, TextSize = 18,
			TextColor3 = UI.GOLD, TextStrokeTransparency = 0, Text = opts.tail, LayoutOrder = 3,
		}, t)
		new("UIPadding", {PaddingTop = UDim.new(0, 4)}, tail)
	end
	local pop = new("UIScale", {Scale = 0.5}, holder)
	TweenService:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Scale = 1}):Play()
	if color == UI.RED then
		UI.sound("Error")
	end
	task.delay(opts.time or 2.8, function()
		-- se encoge y se va (sin fundido: así los colores no se apagan antes de tiempo)
		TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Scale = 0}):Play()
		task.wait(0.27)
		holder:Destroy()
	end)
end

---------- Mensaje grande: rayos que giran, título con contorno y una cinta con el detalle ----------
local bigFrame = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(820, 240), BackgroundTransparency = 1, Visible = false, ZIndex = 20}, overlay)
local bigRays = piece("rays", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(620, 620), ImageTransparency = 0.45, ZIndex = 20}, bigFrame)
local bigRays2 = piece("rays", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(460, 460), ImageTransparency = 0.6, ZIndex = 20}, bigFrame)
local bigTitle = new("TextLabel", {Size = UDim2.new(1, 0, 0.6, 0), BackgroundTransparency = 1, Font = UI.TITLE, TextScaled = true, Text = "", ZIndex = 22}, bigFrame)
new("UIStroke", {Color = UI.INK, Thickness = 7, LineJoinMode = Enum.LineJoinMode.Round}, bigTitle)
new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 205, 225))}, bigTitle)
local bigRibbon = piece("ribbon", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromOffset(560, 74), ImageColor3 = UI.PURPLE, ZIndex = 21}, bigFrame)
bigRibbon.SliceScale = 0.58
local bigSub = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 30), Size = UDim2.new(1, -150, 0, 32), BackgroundTransparency = 1,
	Font = UI.FONT, TextScaled = true, TextColor3 = UI.WHITE, TextStrokeTransparency = 0, Text = "", ZIndex = 22,
}, bigRibbon)
local bigScale = new("UIScale", {}, bigFrame)
RunService.RenderStepped:Connect(function()
	if bigFrame.Visible then
		local a = os.clock()
		bigRays.Rotation = a * 22
		bigRays2.Rotation = -a * 14
	end
end)
local bigToken = 0
-- Aviso de esquina con el estilo del mensaje grande: el título en la insignia y el detalle al lado. Para lo que no
-- merece tapar la pantalla (compras de pases, tags, repetidos...) y para cualquier UI.big con un menú abierto.
function UI.notice(title, sub, color, icon, duration)
	local chip = (title or ""):gsub("!+$", "")
	UI.toast((sub ~= nil and sub ~= "") and sub or title, color, icon, {chip = chip, time = math.max(duration or 0, 3.6)})
end
function UI.big(title, sub, color, duration)
	if UI.menuOpen() then
		return UI.notice(title, sub, color, "star", duration)
	end
	bigToken += 1
	local token = bigToken
	color = color or UI.WHITE
	bigTitle.Text, bigTitle.TextColor3, bigSub.Text = title, color, sub or ""
	bigRays.ImageColor3, bigRays2.ImageColor3 = color, color:Lerp(UI.WHITE, 0.5)
	bigRibbon.Visible = sub ~= nil and sub ~= ""
	bigRibbon.ImageColor3 = color:Lerp(UI.INK, 0.35)
	local tw = TextService:GetTextSize(sub or "", 26, UI.FONT, Vector2.new(2000, 100)).X
	bigRibbon.Size = UDim2.fromOffset(math.clamp(tw + 190, 360, 820), 74)
	bigFrame.Visible = true
	bigScale.Scale = 0.3
	TweenService:Create(bigScale, TweenInfo.new(0.5, Enum.EasingStyle.Back), {Scale = 1}):Play()
	task.delay(duration or 2.4, function()
		if bigToken == token then
			TweenService:Create(bigScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Scale = 0}):Play()
			task.wait(0.2)
			if bigToken == token then
				bigFrame.Visible = false
			end
		end
	end)
end

---------- Menú lateral ----------
-- Como el índice de los juegos de defensa: botones oscuros translúcidos teñidos de su color, borde fino de su color,
-- ilustración grande que se sale del botón y el nombre en blanco con contorno. Los de orden 1-6 (casa, tienda,
-- tropas) son anchos: ilustración a la izquierda, asomando por el borde, y el nombre al lado. Los demás, cuadrados de
-- dos en dos: ilustración arriba y el nombre sobre el borde de abajo. Están quietos: solo reaccionan al ratón (se
-- iluminan, el borde se pone blanco y la ilustración crece) y al pulsar (se hunden y rebotan).
local menu = new("Frame", {Name = "Menu", Size = UDim2.fromOffset(SIDE_W, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1}, side)
new("UIListLayout", {Padding = UDim.new(0, 9), SortOrder = Enum.SortOrder.LayoutOrder}, menu)
local TILE = Vector2.new((SIDE_W - 10) / 2, 86)
local menuGrid = new("Frame", {Name = "Grid", Size = UDim2.fromOffset(SIDE_W, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 100}, menu)
new("UIGridLayout", {CellSize = UDim2.fromOffset(TILE.X, TILE.Y), CellPadding = UDim2.fromOffset(10, 16), SortOrder = Enum.SortOrder.LayoutOrder}, menuGrid)
new("UIPadding", {PaddingTop = UDim.new(0, 6)}, menuGrid)
UI.menu = menu
-- UI.menuButton(orden, icono, texto, color): devuelve el botón (TextButton)
function UI.menuButton(order, icon, text, color)
	local wide = order <= 6
	local size = wide and Vector2.new(SIDE_W, 64) or TILE
	local rest, lit = color:Lerp(UI.DARK, 0.62), color:Lerp(UI.DARK, 0.4)
	local b = round(new("TextButton", {
		Name = text, Text = "", AutoButtonColor = false, BackgroundColor3 = rest, BackgroundTransparency = 0.1, Size = UDim2.fromOffset(size.X, size.Y),
		LayoutOrder = order,
	}, wide and menu or menuGrid), 10)
	-- más claro arriba que abajo
	new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(120, 115, 130))}, b)
	local edgeColor = color:Lerp(UI.WHITE, 0.38)
	local edge = new("UIStroke", {Color = edgeColor, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, b)
	-- brillo de cristal en la mitad de arriba
	local shine = round(new("Frame", {Name = "Shine", Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 0.46, 0), BackgroundColor3 = UI.WHITE, BorderSizePixel = 0}, b), 8)
	new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(0.84, 1)}, shine)
	local icSize = wide and 78 or 72
	local ic = UI.art(icon, {
		Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = wide and UDim2.new(0, 30, 0.5, -4) or UDim2.new(0.5, 0, 0.42, -6),
		Size = UDim2.fromOffset(icSize, icSize), ZIndex = 3,
	}, b)
	local cap = new("TextLabel", {
		Name = "Caption", BackgroundTransparency = 1, Font = HUD_FONT, TextColor3 = UI.WHITE, Text = string.upper(text), ZIndex = 4,
	}, b)
	hudStroke(cap, 2.2)
	if wide then
		cap.AnchorPoint, cap.Position, cap.Size = Vector2.new(0, 0.5), UDim2.new(0, 76, 0.5, 1), UDim2.new(1, -84, 0, 30)
		cap.TextSize, cap.TextXAlignment = 21, Enum.TextXAlignment.Left
	else
		cap.AnchorPoint, cap.Position, cap.Size = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, 8), UDim2.new(1, 8, 0, 24)
		cap.TextSize = 18
	end
	UI.press(b, 1.04)
	local quick = TweenInfo.new(0.14, Enum.EasingStyle.Quad)
	local pop = TweenInfo.new(0.22, Enum.EasingStyle.Back)
	b.MouseEnter:Connect(function()
		TweenService:Create(b, quick, {BackgroundColor3 = lit}):Play()
		TweenService:Create(edge, quick, {Color = UI.WHITE}):Play()
		TweenService:Create(ic, pop, {Size = UDim2.fromOffset(icSize + 10, icSize + 10), Rotation = -5}):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, quick, {BackgroundColor3 = rest}):Play()
		TweenService:Create(edge, quick, {Color = edgeColor}):Play()
		TweenService:Create(ic, quick, {Size = UDim2.fromOffset(icSize, icSize), Rotation = 0}):Play()
	end)
	return b
end
UI.homeButton = UI.menuButton(1, "house", "My House", Color3.fromRGB(255, 136, 36))
UI.shopButton = UI.menuButton(2, "cart", "Shop", Color3.fromRGB(70, 200, 92))
UI.helpButton = UI.menuButton(9, "question", "Help", Color3.fromRGB(140, 92, 236))

---------- Vistas 3D de los sustos (ViewportFrame) ----------
local spinning = {}
-- still = true: vista fija, sin vaivén (el Index)
-- dress(model): lo viste antes de encuadrarlo (la tropa del Tower Defense con el equipo de su nivel)
function UI.viewport(t, parent, props, still, dress)
	local vp = new("ViewportFrame", props, parent)
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(196, 186, 214)
	vp.LightColor = Color3.fromRGB(255, 246, 232)
	vp.LightDirection = Vector3.new(-0.6, -1, -0.9)
	local template = Assets.Scares:FindFirstChild(t)
	if not template then
		return vp
	end
	local model = template:Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "Hitbox" or d.Name == "Path" or d.Name == "Range") then
			d:Destroy()
		elseif d:IsA("BasePart") and d:GetAttribute("T") then
			d.Transparency = d:GetAttribute("T")
		elseif d:IsA("Sound") or d:IsA("Script") then
			d:Destroy()
		end
	end
	if dress then
		dress(model)
	end
	model.Parent = vp
	local cf, size = model:GetBoundingBox()
	local cam = new("Camera", {FieldOfView = 40}, vp)
	vp.CurrentCamera = cam
	local dist = math.max(size.X, size.Y, size.Z) * 1.7
	local center = cf.Position
	-- delante del modelo (los sustos miran hacia su LookVector, -Z) y un poco desde arriba, para que también se vean
	-- las cosas planas (la trampilla)
	local look = model:GetPivot().LookVector
	look = Vector3.new(look.X, 0, look.Z).Unit
	cam.CFrame = CFrame.lookAt(center + look * dist + Vector3.new(0, math.max(size.Y * 0.2, dist * 0.45), 0), center)
	if not still then
		table.insert(spinning, {vp = vp, cam = cam, center = center, base = cam.CFrame, phase = #spinning})
	end
	return vp
end

-- El vaivén lo hace la cámara, que gira alrededor del susto: mover la cámara de un ViewportFrame es barato y se ve
-- a los fps del juego; mover el modelo (cientos de piezas) obliga a recargar toda la escena y Roblox lo racionaba
-- (por eso iba a saltos). Solo se mueven las vistas que están en pantalla.
RunService.RenderStepped:Connect(function()
	local angle = os.clock() * 0.8
	local screen = workspace.CurrentCamera.ViewportSize
	for i = #spinning, 1, -1 do
		local s = spinning[i]
		local vp = s.vp
		if not vp.Parent then
			table.remove(spinning, i)
		elseif vp.Visible and vp.AbsoluteSize.X > 0 then
			local p, sz = vp.AbsolutePosition, vp.AbsoluteSize
			if p.X < screen.X and p.Y < screen.Y and p.X + sz.X > 0 and p.Y + sz.Y > -60 then
				local rot = CFrame.new(s.center) * CFrame.Angles(0, -math.sin(angle + s.phase) * 0.6, 0) * CFrame.new(-s.center)
				s.cam.CFrame = rot * s.base
			end
		end
	end
end)

-- Escenario de una tarjeta: brillo radial del color de la rareza detrás del modelo
function UI.stage(parent, color, props)
	local f = round(new("Frame", props, parent), 14)
	f.BackgroundColor3 = color:Lerp(UI.DARK, 0.7)
	f.BackgroundTransparency = 0.25
	new("UIStroke", {Color = UI.INK, Thickness = 2, Transparency = 0.3}, f)
	piece("glow2", {Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromScale(1.1, 1.35), ImageColor3 = color:Lerp(UI.WHITE, 0.25), ImageTransparency = 0.45, ZIndex = f.ZIndex}, f)
	return f
end

-- Estadísticas pequeñas con icono: UI.stat(parent, "coin", "+6/scare", color, order)
function UI.stat(parent, icon, text, color, order)
	local row = new("Frame", {Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, LayoutOrder = order or 0}, parent)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, row)
	UI.icon(icon, {Size = UDim2.fromOffset(24, 24), LayoutOrder = 1, ZIndex = parent.ZIndex}, row)
	local l = new("TextLabel", {
		Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Font = UI.FONT, TextSize = 15,
		TextColor3 = color or UI.GOLD, TextStrokeTransparency = 0, Text = text, LayoutOrder = 2, ZIndex = parent.ZIndex,
	}, row)
	return row, l
end

-- De dónde sale un susto que no se vende por monedas: texto corto ("WHEEL · SKINS"), icono y a dónde llevar (las
-- skins primero: es comprarlas directamente en la Shop; si no, la ruleta)
local SOURCE_SHORT = {wheel = "WHEEL", skins = "SKINS"}
local SOURCE_PICK = {{"skins", "skins", "gem"}, {"wheel", 1, "wheel"}}
function UI.sourceInfo(t)
	local list = Config.sources(t)
	local names = {}
	for _, s in list do
		if SOURCE_SHORT[s] then
			table.insert(names, SOURCE_SHORT[s])
		end
	end
	for _, p in SOURCE_PICK do
		if table.find(list, p[1]) then
			return {text = table.concat(names, " · "), tab = p[2], icon = p[3]}
		end
	end
	return {text = table.concat(names, " · "), tab = 1, icon = "wheel"}
end
function UI.openSource(t)
	if UI.sourceInfo(t).tab == "skins" and UI.openSkins then
		UI.openSkins()
	elseif UI.openStores then
		UI.openStores()
	end
end

-- Insignia roja con un número (avisos de cosas nuevas)
function UI.addBadge(b)
	local bd = piece("badge", {
		Name = "Badge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(32, 32), ImageColor3 = UI.RED,
		Visible = false, ZIndex = 10,
	}, b)
	new("TextLabel", {
		Name = "Count", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = UI.TITLE, TextSize = 17, TextColor3 = UI.WHITE, TextStrokeTransparency = 0,
		Text = "", ZIndex = 11,
	}, bd)
	new("UIPadding", {PaddingTop = UDim.new(0, 3)}, bd.Count)
	new("UIScale", {}, bd)
	return bd
end

---------- Tienda ----------
-- Pantalla aparte (ShopUI, con el estilo de Catalog): pone UI.shop, UI.toggleShop, UI.refreshShop, UI.refreshHouses,
-- UI.newlyAffordable y UI.shopBadges
require(script.Parent:WaitForChild("ShopUI"))(UI)
-- Sustos: se compran en su pantalla de colección (pestaña Scares, como Troops): UI.toggleScares
require(script.Parent:WaitForChild("ScareStoreUI"))(UI)
-- Fusión: la ventana del Caldero de Hexa (cementerio) y su pantalla de resultado: UI.toggleFusion, UI.refreshFusion
require(script.Parent:WaitForChild("FusionUI"))(UI)

---------- Barra de sustos (en tu casa) ----------
local buildBar = new("Frame", {Name = "BuildBar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(1140, 156), BackgroundTransparency = 1, Visible = false}, gui)
local trayBack = round(new("Frame", {Size = UDim2.new(1, -244, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1)}, buildBar), 20)
gradient(trayBack, Color3.fromRGB(56, 36, 90), Color3.fromRGB(22, 13, 38))
stroke(trayBack, UI.INK, 4)
round(new("ImageLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = UI.PATTERN, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(180, 180), ImageTransparency = 0.94}, trayBack), 20)
local tray = new("ScrollingFrame", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 6, ScrollBarImageColor3 = UI.ORANGE,
	AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(),
}, trayBack)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}, tray)
new("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)}, tray)
UI.tray = tray

-- Ficha al pasar por encima de un susto: qué hace, cuánto da y cómo se usa
local tip = round(new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(290, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, ZIndex = 20,
}, buildBar), 16)
gradient(tip, Color3.fromRGB(60, 40, 96), Color3.fromRGB(24, 14, 40))
stroke(tip, UI.INK, 3.5)
new("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14)}, tip)
new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, tip)
local tipName = new("TextLabel", {Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Font = UI.TITLE, TextSize = 24, TextColor3 = UI.WHITE, TextStrokeTransparency = 0, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, ZIndex = 21}, tip)
local tipDesc = new("TextLabel", {Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, Font = UI.SMALL, TextSize = 13, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, ZIndex = 21}, tip)
local tipStats = new("TextLabel", {Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Font = UI.FONT, TextSize = 15, TextColor3 = UI.GOLD, TextStrokeTransparency = 0, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 3, ZIndex = 21}, tip)
local tipHow = new("TextLabel", {Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Font = UI.FONT, TextSize = 14, TextColor3 = UI.ORANGE, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 4, ZIndex = 21}, tip)
function UI.hideTip()
	tip.Visible = false
end

UI.slots = {}
-- solo se ven los que tienes en el inventario (los especiales, al final)
local trayOrder = table.clone(Config.ScareOrder)
table.move(Config.SpecialOrder, 1, #Config.SpecialOrder, #trayOrder + 1, trayOrder)
for i, t in trayOrder do
	local def = Config.Scares[t]
	local color = Config.Categories[def.cat].color
	local slot, parts = UI.card(tray, i, color, {Class = "TextButton", Size = UDim2.fromOffset(102, 134), Text = "", AutoButtonColor = false})
	piece("glow2", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 48), Size = UDim2.fromOffset(110, 110), ImageColor3 = color:Lerp(UI.WHITE, 0.3), ImageTransparency = 0.55, ZIndex = 3}, slot)
	-- el modelo, con tu skin equipada (cambia al momento si equipas otra)
	local look = new("Frame", {Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -10, 0, 86), BackgroundTransparency = 1, ZIndex = 4}, slot)
	local function showLook()
		look:ClearAllChildren()
		UI.viewport(Config.skinFor(player, t), look, {Size = UDim2.fromScale(1, 1), ZIndex = 4})
	end
	showLook()
	player:GetAttributeChangedSignal("Skin_" .. t):Connect(showLook)
	new("TextLabel", {Position = UDim2.fromOffset(5, 90), Size = UDim2.new(1, -10, 0, 20), BackgroundTransparency = 1, Font = UI.TITLE, TextSize = 16, TextColor3 = UI.WHITE, TextStrokeTransparency = 0, Text = def.name, TextScaled = true, ZIndex = 4}, slot)
	local countRow = new("Frame", {Position = UDim2.fromOffset(4, 110), Size = UDim2.new(1, -8, 0, 20), BackgroundTransparency = 1, ZIndex = 4}, slot)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, countRow)
	local count = new("TextLabel", {Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Font = UI.TITLE, TextSize = 17, TextColor3 = UI.GOLD, TextStrokeTransparency = 0, Text = "", LayoutOrder = 1, ZIndex = 4}, countRow)
	local coin = UI.icon("coin", {Size = UDim2.fromOffset(20, 20), LayoutOrder = 2, Visible = false, ZIndex = 4}, countRow)
	UI.slots[t] = {button = slot, count = count, coin = coin, stroke = parts.stroke, color = color}
	-- estrellas de fusión de este tipo
	local stars = new("TextLabel", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -5, 0, 4), Size = UDim2.fromOffset(70, 18), BackgroundTransparency = 1, Font = UI.TITLE, TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Right, TextStrokeTransparency = 0, Text = "", ZIndex = 6}, slot)
	local function showStars()
		local n = Config.starOf(player, t)
		stars.Text = string.rep("★", n)
		stars.TextColor3 = Config.STAR_COLORS[n] or UI.WHITE
	end
	showStars()
	player:GetAttributeChangedSignal("Star_" .. t):Connect(showStars)
	-- pop al pulsar: coger un susto se siente
	local pop = new("UIScale", {}, slot)
	slot.MouseButton1Down:Connect(function()
		pop.Scale = 0.88
		TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Back), {Scale = 1}):Play()
	end)
	slot.MouseEnter:Connect(function()
		UI.sound("Hover")
		TweenService:Create(pop, TweenInfo.new(0.12), {Scale = 1.06}):Play()
		local n = player:GetAttribute("Inv_" .. t) or 0
		tipName.Text = def.name
		tipName.TextColor3 = color:Lerp(UI.WHITE, 0.35)
		tipDesc.Text = def.desc
		local lv = Config.troopLevel(player, t)
		local star = Config.starOf(player, t)
		tipStats.Text = ("+%d per scare  ·  Fear %d  ·  reach %d%s%s"):format(Config.scarePay(player, t), Config.starDef(t, star).fear, def.radius,
			lv > 1 and ("  ·  LV %d"):format(lv) or "", star > 0 and ("  ·  " .. string.rep("★", star)) or "")
		local slots = Config.slots(t)
		tipHow.Text = n > 0 and (slots > 1 and ("Drag it onto the floor  ·  takes %d spaces"):format(slots) or "Drag it onto the floor of your house")
			or (not Config.inShop(t) and ("None left · get it: " .. UI.sourceInfo(t).text) or ("None left · buy more in the Shop (%d coins)"):format(def.price))
		local center = slot.AbsolutePosition.X + slot.AbsoluteSize.X / 2 - buildBar.AbsolutePosition.X
		tip.Position = UDim2.fromOffset(center / scale.Scale, -104) -- por encima de la pista del tutorial
		tip.Visible = true
	end)
	slot.MouseLeave:Connect(function()
		TweenService:Create(pop, TweenInfo.new(0.12), {Scale = 1}):Play()
		UI.hideTip()
	end)
end
local tools = new("Frame", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 232, 1, 0), BackgroundTransparency = 1}, buildBar)
new("UIGridLayout", {CellSize = UDim2.fromOffset(110, 72), CellPadding = UDim2.fromOffset(10, 12)}, tools)
local function toolButton(icon, text, color)
	local b = button({Text = "", BackgroundColor3 = color}, tools)
	UI.icon(icon, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 3), Size = UDim2.fromOffset(40, 40)}, b)
	new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -9), Size = UDim2.new(1, -8, 0, 20), BackgroundTransparency = 1,
		Font = UI.TITLE, TextSize = 15, TextColor3 = UI.WHITE, TextStrokeTransparency = 0, Text = text,
	}, b)
	return b
end
UI.rotateButton = toolButton("rotate", "Rotate (R)", Color3.fromRGB(96, 76, 160))
UI.testButton = toolButton("play", "Test run", Color3.fromRGB(56, 150, 226))
UI.buildShopButton = toolButton("cart", "Shop", Color3.fromRGB(70, 200, 92))
table.insert(UI.shopBadges, UI.addBadge(UI.buildShopButton))
UI.exitButton = toolButton("door", "Go outside", Color3.fromRGB(220, 60, 74))
-- Resumen de tu casa: sustos colocados / límite
local buildInfo = round(new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, -122, 0, -10), Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = Color3.new(1, 1, 1),
}, buildBar), UDim.new(1, 0))
gradient(buildInfo, Color3.fromRGB(56, 36, 90), Color3.fromRGB(22, 13, 38))
stroke(buildInfo, UI.INK, 3)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, buildInfo)
new("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 16)}, buildInfo)
UI.icon("ghost", {Size = UDim2.fromOffset(32, 32), LayoutOrder = 1}, buildInfo)
local infoScares = new("TextLabel", {Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Font = UI.TITLE, TextSize = 20, TextColor3 = UI.GOLD, TextStrokeTransparency = 0, Text = "", LayoutOrder = 2}, buildInfo)
new("UIPadding", {PaddingTop = UDim.new(0, 3)}, infoScares)
-- sin sustos en el inventario, la bandeja lo dice en vez de quedarse vacía
local trayEmpty = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 3}, trayBack)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10)}, trayEmpty)
UI.icon("ghost", {Size = UDim2.fromOffset(52, 52), LayoutOrder = 1, ZIndex = 3}, trayEmpty)
new("TextLabel", {Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Font = UI.TITLE, TextSize = 24, TextColor3 = UI.WHITE, TextStrokeTransparency = 0, Text = "No scares in your inventory · get more in the Shop!", LayoutOrder = 2, ZIndex = 3}, trayEmpty)
UI.buildBar = buildBar
-- construyendo, la columna de la izquierda (las monedas) se coloca encima de la barra en vez de debajo
buildBar:GetPropertyChangedSignal("Visible"):Connect(function()
	side.Position = buildBar.Visible and UDim2.new(0, 16, 1, -(buildBar.Size.Y.Offset + 30)) or SIDE_DOWN
end)

function UI.refreshBuild(placed, rooms, spaces)
	local anyScare = false
	for t, s in UI.slots do
		local n = player:GetAttribute("Inv_" .. t) or 0
		local wheel = not Config.inShop(t) and not Config.Scares[t].special
		s.count.Text = n > 0 and ("x%d"):format(n) or (wheel and "GET" or UI.fmt(Config.Scares[t].price))
		s.count.TextColor3 = n > 0 and UI.GOLD or (wheel and Color3.fromRGB(255, 140, 210) or Color3.fromRGB(180, 170, 196))
		s.coin.Visible = n <= 0
		UI.setIcon(s.coin, wheel and UI.sourceInfo(t).icon or "coin")
		UI.tintCard(s.button, n > 0 and s.color or s.color:Lerp(UI.CANT, 0.75))
		if s.button.Visible and n <= 0 then
			UI.hideTip() -- (la ficha de una carta que se va no se queda flotando)
		end
		s.button.Visible = n > 0
		anyScare = anyScare or n > 0
	end
	trayEmpty.Visible = not anyScare
	local max = spaces or rooms * Config.SCARES_PER_ROOM
	infoScares.Text = ("Spaces %d/%d"):format(placed, max)
	infoScares.TextColor3 = placed >= max and UI.RED or UI.GOLD
end

---------- Visita: progreso hasta el fondo, miedo, huir y linterna ----------
local visitHud = new("Frame", {Name = "VisitHud", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(540, 170), BackgroundTransparency = 1, Visible = false}, gui)
local progText = new("TextLabel", {Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Font = UI.TITLE, TextSize = 19, TextColor3 = UI.WHITE, TextStrokeTransparency = 0, Text = ""}, visitHud)
local progBack, progFill = UI.bar({Position = UDim2.fromOffset(52, 28), Size = UDim2.new(1, -104, 0, 24)}, visitHud, UI.GOLD)
UI.icon("door", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0, -2, 0.5, 0), Size = UDim2.fromOffset(44, 44)}, progBack)
UI.icon("trophy", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, 2, 0.5, 0), Size = UDim2.fromOffset(44, 44)}, progBack)
local fearHeart = UI.icon("heart", {Position = UDim2.fromOffset(0, 58), Size = UDim2.fromOffset(56, 56), ZIndex = 3}, visitHud)
local heartPop = new("UIScale", {}, fearHeart)
local fearBack, fearFill = UI.bar({Position = UDim2.fromOffset(40, 64), Size = UDim2.new(1, -40, 0, 42)}, visitHud, Color3.new(1, 1, 1))
gradient(fearFill, Color3.fromRGB(255, 214, 80), Color3.fromRGB(255, 40, 70), 0)
local fearText = new("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = UI.TITLE, TextSize = 22, TextColor3 = UI.WHITE, TextStrokeTransparency = 0, Text = "CALM", ZIndex = 5}, fearBack)
new("UIPadding", {PaddingTop = UDim.new(0, 4)}, fearText)
UI.leaveButton = iconButton({Position = UDim2.new(0.5, -200, 0, 118), Size = UDim2.fromOffset(192, 52), BackgroundColor3 = Color3.fromRGB(214, 52, 72), Text = "Run away (Q)", TextSize = 19, Font = UI.TITLE}, visitHud, "run")
UI.lightButton = iconButton({Position = UDim2.new(0.5, 8, 0, 118), Size = UDim2.fromOffset(192, 52), BackgroundColor3 = Color3.fromRGB(226, 176, 40), Text = "Flashlight (F)", TextSize = 19, Font = UI.TITLE}, visitHud, "flashlight")
UI.visitHud = visitHud

local fearLevel, fearValue = 0, 0
function UI.setFear(value)
	fearValue = value
	TweenService:Create(fearFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Size = UDim2.fromScale(math.clamp(value / 100, 0, 1), 1)}):Play()
	fearText.Text = value >= 75 and "PANIC!" or value >= 40 and "SCARED" or "CALM"
	-- al pasar a SCARED o a PANIC suena un golpe grave
	local level = value >= 75 and 2 or value >= 40 and 1 or 0
	if level > fearLevel then
		UI.sound("Deep", level == 2 and 1 or 0.7)
	end
	fearLevel = level
end
-- el corazón late más deprisa con el miedo
RunService.RenderStepped:Connect(function()
	if visitHud.Visible then
		local speed = 4 + fearValue / 100 * 10
		heartPop.Scale = 1 + 0.12 * math.max(0, math.sin(os.clock() * speed)) ^ 6
	end
end)

-- frac: 0 en la puerta, 1 al fondo de la casa
function UI.setProgress(frac, text)
	progFill.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
	progText.Text = text or ""
end

function UI.setLight(on)
	UI.lightButton.Text = on and "Flashlight (F)" or "Light off (F)"
	UI.lightButton.BackgroundColor3 = on and Color3.fromRGB(226, 176, 40) or Color3.fromRGB(86, 78, 104)
end

-- Cartel de entrada a una casa (como el título de un capítulo de terror)
local titleCard = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false}, fx)
new("UIScale", {}, titleCard)
local titleName = new("TextLabel", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.25), Size = UDim2.fromScale(0.7, 0.12), BackgroundTransparency = 1, Font = UI.SCARY, TextScaled = true, TextColor3 = UI.ORANGE, ZIndex = 12}, titleCard)
local titleStroke = new("UIStroke", {Color = UI.INK, Thickness = 5, LineJoinMode = Enum.LineJoinMode.Round}, titleName)
local titleSub = new("TextLabel", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.345), Size = UDim2.fromScale(0.5, 0.045), BackgroundTransparency = 1, Font = UI.FONT, TextScaled = true, TextColor3 = UI.WHITE, TextStrokeTransparency = 0, ZIndex = 12}, titleCard)
function UI.titleCard(name, sub)
	UI.sound("Boom", 0.8)
	UI.duck(0.3, 2)
	titleName.Text, titleSub.Text = name, sub
	titleName.TextTransparency, titleSub.TextTransparency, titleStroke.Transparency = 0, 0, 0
	titleCard.Visible = true
	titleCard.UIScale.Scale = 1.25
	TweenService:Create(titleCard.UIScale, TweenInfo.new(1.8, Enum.EasingStyle.Quad), {Scale = 1}):Play()
	task.delay(1.6, function()
		TweenService:Create(titleName, TweenInfo.new(0.8), {TextTransparency = 1}):Play()
		TweenService:Create(titleStroke, TweenInfo.new(0.8), {Transparency = 1}):Play()
		TweenService:Create(titleSub, TweenInfo.new(0.8), {TextTransparency = 1}):Play()
		task.wait(0.85)
		titleCard.Visible = false
	end)
end

return UI
