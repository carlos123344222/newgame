-- Tower Defense (cliente): tus sustos como tropas.
-- HUD de la partida al estilo Tower Defense Simulator (diseño en Figma: "Haunted House TD — HUD de partida (Fase 2)"):
-- Montserrat blanco con contorno oscuro, iconos de la hoja HUD_ICONS y solo lo que hace falta para jugar.
-- · Arriba al centro: "Wave: 5 / 20" | "Base Health" (barra verde con la cruz) | "Time left: 00:36"; debajo, la barra
--   del jefe (nombre, rombo y vida) y los votos "Ready?" / "Skip wave?" con su marcador; luego, las recompensas.
-- · Arriba a la derecha: los jugadores con su dinero y la dificultad.
-- · Abajo: velocidad y vista táctica, la barra de tropas (tecla, modelo, precio) y tu dinero (contador que corre y "+$")
--   con las tropas que tienes puestas.
-- · Abajo a la izquierda: saltar oleadas solo ("Auto skip") y salir.
-- · Izquierda: panel de la tropa elegida (nivel, estadísticas actuales → siguientes, objetivo, mejorar y vender).
-- Todo sale de los atributos que pone TDMatch (<mapa>.TD del mapa en el que estás, TDMap/TDCash/TDFear/TDKills/TDAuto de
-- cada jugador, cada tropa y cada enemigo) y de los avisos de TDRemote. Piezas visuales: TDKit.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local Config = require(RS:WaitForChild("Config"))
local TD = require(RS:WaitForChild("TowerDefense"))
local Remote = RS:WaitForChild("TDRemote")
local Assets = RS:WaitForChild("Assets")
local UI = require(script.Parent:WaitForChild("UI"))
local Kit = require(script.Parent:WaitForChild("TDKit"))
local Musica = require(script.Parent:WaitForChild("Musica"))
local Sfx = require(RS:WaitForChild("Sfx"))
local player = Players.LocalPlayer
-- El mapa en el que juegas (atributo TDMap); fuera de partida se queda el último. Los mapas solo existen donde se
-- juegan: hasta tener uno, un estado vacío.
local map
local state = Instance.new("Folder")
local towersF = Instance.new("Folder")
towersF.Name = "Towers"
towersF.Parent = state
local function bindMap()
	local id = player:GetAttribute("TDMap")
	local m = id and workspace:WaitForChild(id, 30)
	if m then
		map = m
		state = m:WaitForChild("TD")
		towersF = state:WaitForChild("Towers")
	end
end
bindMap()
player:GetAttributeChangedSignal("TDMap"):Connect(bindMap)

local new, label, corner, outline = UI.new, Kit.label, Kit.corner, Kit.outline
local CASH, BUY, CANT, MUTED = Kit.CASH, Kit.BUY, Kit.CANT, Kit.MUTED
local LEFT, RIGHT = Enum.TextXAlignment.Left, Enum.TextXAlignment.Right
local HORIZONTAL = Enum.FillDirection.Horizontal
local CENTER, BOTTOM = Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom
local MIDDLE = Enum.VerticalAlignment.Center
local AUTO_X, AUTO_Y = Enum.AutomaticSize.X, Enum.AutomaticSize.Y
local TOUCH = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local KEYS = {Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six}
local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
local SHIELD = Color3.fromRGB(80, 170, 255)
-- Estilo
local BOX = Color3.fromRGB(14, 10, 22) -- fondo de las cajas
local SOFT = Color3.fromRGB(66, 56, 92) -- botones neutros, huecos vacíos
local BOLD, HEAVY = Enum.Font.GothamBold, Enum.Font.GothamBlack
local Sty, Wt, Vt = {}, {}, {} -- estilo, pesos de letra y piezas del voto (en tablas: el script ya roza el límite de locales)
local SLOT = Vector2.new(58, 60) -- hueco de la barra de tropas
Sty.PRICE = Color3.fromRGB(92, 242, 90) -- precios y dinero que entra
-- Tipografía e iconos del HUD de partida (diseño en Figma: "Haunted House TD — HUD de partida (Fase 2)")
Sty.MONT = "rbxasset://fonts/families/Montserrat.json"
Wt.MED, Wt.SEMI, Wt.BOLD, Wt.XBOLD, Wt.BLACK = Enum.FontWeight.Medium, Enum.FontWeight.SemiBold, Enum.FontWeight.Bold, Enum.FontWeight.ExtraBold, Enum.FontWeight.Heavy
Sty.INK = Color3.fromRGB(14, 11, 18) -- contorno de los textos (casi negro, como en TDS)
Sty.ICONS = "rbxassetid://129121289352094"
Sty.RECT = {}
for i, n in {
	"cash", "plus", "hourglass", "boss", "pin", "lock", "check", "cross", "chevron", "map", "fast", "leave", "players", "coin", "gem", "xp",
	"range", "fear", "sword", "detect", "heart", "skull", "pumpkin", "trophy", "crown", "flame", "snow", "shield", "bolt", "target", "upgrade", "gift",
} do
	Sty.RECT[n] = Vector2.new(((i - 1) % 8) * 128, ((i - 1) // 8) * 128)
end
-- Icono de la hoja del HUD (32 iconos de 128 px)
local function hicon(name, props, parent)
	props.BackgroundTransparency = 1
	props.Image = Sty.ICONS
	props.ImageRectOffset = Sty.RECT[name]
	props.ImageRectSize = Vector2.new(128, 128)
	props.ScaleType = Enum.ScaleType.Fit
	return UI.new("ImageLabel", props, parent)
end
local function setHicon(img, name)
	img.ImageRectOffset = Sty.RECT[name]
end
-- Texto del HUD de partida: Montserrat blanco con contorno oscuro (el kit de UI lo convierte en un UIStroke)
local function mt(props, parent, weight)
	props.FontFace = Font.new(Sty.MONT, weight or Wt.BOLD)
	if props.BackgroundTransparency == nil then
		props.BackgroundTransparency = 1
	end
	props.TextColor3 = props.TextColor3 or WHITE
	if props.TextStrokeTransparency == nil then
		props.TextStrokeTransparency = 0
	end
	props.TextStrokeColor3 = Sty.INK
	return UI.new("TextLabel", props, parent)
end

-- ¿Está abierta la pantalla de tropas (TDTroops)? La ScreenGui (Catalog) está siempre activa: abierta = su marco visible
local function troopsOpen()
	local g = player.PlayerGui:FindFirstChild("Troops")
	local root = g and g:FindFirstChild("Troops")
	return g ~= nil and g.Enabled and (root == nil or root.Visible)
end

local function inMatch()
	return player:GetAttribute("TDCash") ~= nil
end

local function tween(o, time, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function clock(s)
	return ("%d:%02d"):format(s // 60, s % 60)
end

local function list(props, parent)
	props.SortOrder = Enum.SortOrder.LayoutOrder
	return new("UIListLayout", props, parent)
end

local function pad(o, l, r, t, b)
	new("UIPadding", {PaddingLeft = UDim.new(0, l), PaddingRight = UDim.new(0, r or l), PaddingTop = UDim.new(0, t or l), PaddingBottom = UDim.new(0, b or t or l)}, o)
end

-- Texto del HUD: Gotham, blanco y con contorno fino (el kit de UI convierte el TextStroke en un UIStroke)
local function txt(props, parent)
	props.Font = props.Font or HEAVY
	if props.TextStrokeTransparency == nil then
		props.TextStrokeTransparency = 0.2
	end
	return label(props, parent)
end

-- Caja oscura translúcida con esquinas suaves y un borde negro tenue. props.Class: otra clase (TextButton...)
local function box(props, parent, r)
	local class = props.Class or "Frame"
	props.Class = nil
	props.BackgroundColor3 = props.BackgroundColor3 or BOX
	if props.BackgroundTransparency == nil then
		props.BackgroundTransparency = 0.3
	end
	props.BorderSizePixel = 0
	if class == "TextButton" then
		props.AutoButtonColor = false
		props.Text = props.Text or ""
	end
	local f = corner(new(class, props, parent), r or 8)
	outline(f, BLACK, 1.5, 0.5)
	return f
end

-- Botón plano de color (con un leve degradado) que crece al pasar por encima y se hunde al pulsar
local function flatButton(props, parent, color)
	props.Class = "TextButton"
	props.BackgroundColor3 = color
	props.BackgroundTransparency = 0
	props.Font = props.Font or HEAVY
	props.TextColor3 = WHITE
	if props.TextStrokeTransparency == nil then
		props.TextStrokeTransparency = 0.3
	end
	local b = box(props, parent, 8)
	new("UIGradient", {Rotation = 90, Color = ColorSequence.new(WHITE, Color3.fromRGB(200, 200, 205))}, b)
	Kit.press(b)
	return b
end

-- Cuántas tropas de cada tipo tengo puestas (y en total)
local function counts()
	local n, total = {}, 0
	for _, m in towersF:GetChildren() do
		if m:GetAttribute("Owner") == player.UserId and not m:GetAttribute("Sold") then
			local t = m:GetAttribute("Type")
			n[t] = (n[t] or 0) + 1
			total += 1
		end
	end
	return n, total
end

local faces = {}
local function faceOf(userId)
	if faces[userId] == nil then
		faces[userId] = false
		task.spawn(function()
			local ok, img = pcall(Players.GetUserThumbnailAsync, Players, userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
			faces[userId] = ok and img or ""
		end)
	end
	return faces[userId] or ""
end

-- (se definen más abajo; los usan botones creados antes)
local selectTower, refreshPanel, startPlacing, stopPlacing, toggle, confirm, rotate, setTactical, shake
local selected, placing

local P = {} -- piezas del HUD que se tocan después (así no se pasa del límite de variables locales)
local Mj, Rs = {}, {} -- Major Pumpkin y la pantalla de fin (Fase 6: más abajo, tras las tropas)
---------- HUD ----------
local hud = new("Frame", {Name = "TowerDefense", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false}, UI.gui)

---------- Arriba al centro: oleada | vida de la base | tiempo (como en TDS) ----------
local top = new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1}, hud)
list({HorizontalAlignment = CENTER, Padding = UDim.new(0, 7)}, top)
local topPos = top.Position
P.topRow = new("Frame", {Size = UDim2.fromOffset(0, 54), AutomaticSize = AUTO_X, BackgroundTransparency = 1, LayoutOrder = 1}, top)
list({FillDirection = HORIZONTAL, VerticalAlignment = MIDDLE, Padding = UDim.new(0, 22)}, P.topRow)
-- "Wave:" / "5 / 20"
P.waveCol = new("Frame", {Size = UDim2.fromOffset(96, 54), BackgroundTransparency = 1, LayoutOrder = 1}, P.topRow)
mt({Size = UDim2.new(1, 0, 0, 16), TextSize = 13, Text = "Wave:"}, P.waveCol, Wt.BOLD)
local waveText = mt({Position = UDim2.fromOffset(0, 17), Size = UDim2.new(1, 0, 0, 34), TextSize = 28, Text = "--"}, P.waveCol, Wt.XBOLD)
P.wavePop = new("UIScale", {}, waveText)
-- "Base Health": barra verde con la cruz (se vuelve amarilla y roja al bajar)
P.hpCol = new("Frame", {Size = UDim2.fromOffset(376, 54), BackgroundTransparency = 1, LayoutOrder = 2}, P.topRow)
mt({Size = UDim2.new(1, 0, 0, 16), TextSize = 13, Text = "Base Health"}, P.hpCol, Wt.BOLD)
P.hpBack = corner(new("Frame", {Position = UDim2.fromOffset(0, 21), Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = Color3.fromRGB(11, 11, 14), BackgroundTransparency = 0.28, BorderSizePixel = 0}, P.hpCol), 6)
outline(P.hpBack, BLACK, 2, 0.05)
-- lo que se acaba de perder: un trozo claro que se encoge detrás del relleno
P.hpLoss = corner(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 236, 236), BackgroundTransparency = 0.1, BorderSizePixel = 0}, P.hpBack), 6)
P.hpFill = corner(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 2}, P.hpBack), 6)
P.hpGrad = new("UIGradient", {Rotation = 90}, P.hpFill)
corner(new("Frame", {Position = UDim2.fromOffset(4, 3), Size = UDim2.new(1, -8, 0, 7), BackgroundColor3 = WHITE, BackgroundTransparency = 0.78, BorderSizePixel = 0, ZIndex = 2}, P.hpFill), 4) -- brillo
local heart = hicon("plus", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 1, 0.5, 0), Size = UDim2.fromOffset(25, 25), ZIndex = 4}, P.hpBack)
P.heartPop = new("UIScale", {}, heart)
P.hpText = mt({Size = UDim2.fromScale(1, 1), TextSize = 13, Text = "", ZIndex = 4}, P.hpBack, Wt.BOLD)
-- "Time left:" / "00:36"
P.timeCol = new("Frame", {Size = UDim2.fromOffset(100, 54), BackgroundTransparency = 1, LayoutOrder = 3}, P.topRow)
P.timeHead = new("Frame", {Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1}, P.timeCol)
list({FillDirection = HORIZONTAL, HorizontalAlignment = CENTER, VerticalAlignment = MIDDLE, Padding = UDim.new(0, 3)}, P.timeHead)
hicon("hourglass", {Size = UDim2.fromOffset(14, 14), LayoutOrder = 1}, P.timeHead)
mt({Size = UDim2.fromOffset(0, 16), AutomaticSize = AUTO_X, TextSize = 11, Text = "Time left:", LayoutOrder = 2}, P.timeHead, Wt.BOLD)
local timeText = mt({Position = UDim2.fromOffset(0, 17), Size = UDim2.new(1, 0, 0, 34), TextSize = 28, Text = "00:00"}, P.timeCol, Wt.XBOLD)
-- qué pasa ahora ("6 hunters left"...), discreto bajo el marcador
local status = mt({Size = UDim2.fromOffset(420, 15), TextSize = 12, TextColor3 = Color3.fromRGB(228, 228, 236), TextStrokeTransparency = 0.25, RichText = true, Text = "", LayoutOrder = 2}, top, Wt.SEMI)

---------- Barra del jefe: nombre arriba, rombo con calavera y la vida que le queda ----------
local boss = new("Frame", {Size = UDim2.fromOffset(470, 52), BackgroundTransparency = 1, LayoutOrder = 3, Visible = false}, top)
P.bossName = mt({Size = UDim2.new(1, 0, 0, 22), TextSize = 18, Text = ""}, boss, Wt.BOLD)
P.bossBack = corner(new("Frame", {Position = UDim2.fromOffset(18, 27), Size = UDim2.new(1, -18, 0, 21), BackgroundColor3 = BLACK, BackgroundTransparency = 0.15, BorderSizePixel = 0}, boss), 7)
outline(P.bossBack, WHITE, 1.5, 0.2)
P.bossFill = corner(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0}, P.bossBack), 7)
new("UIGradient", {Color = ColorSequence.new(WHITE, Color3.fromRGB(226, 27, 226))}, P.bossFill)
new("Frame", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = Color3.fromRGB(255, 90, 255), BorderSizePixel = 0}, P.bossFill) -- el filo
P.bossShield = corner(new("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = SHIELD, BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 2}, P.bossBack), 7)
P.bossPct = mt({AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -9, 0, 0), Size = UDim2.new(1, -40, 1, 0), TextSize = 13, TextXAlignment = RIGHT, Text = "", ZIndex = 3}, P.bossBack, Wt.BOLD)
P.bossIcon = hicon("boss", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(18, 37), Size = UDim2.fromOffset(38, 38), ZIndex = 4}, boss)
P.bossPop = new("UIScale", {}, P.bossIcon)
local bossModel, bossKind

---------- Votos: "Ready?" (preparación) y "Skip wave?" (descanso), con su marcador ----------
Vt.panel = corner(new("Frame", {Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, BackgroundColor3 = BLACK, BackgroundTransparency = 0.45, BorderSizePixel = 0, LayoutOrder = 4, Visible = false}, top), 6)
pad(Vt.panel, 16, 7, 7, 7)
list({FillDirection = HORIZONTAL, VerticalAlignment = MIDDLE, Padding = UDim.new(0, 14)}, Vt.panel)
Vt.pop = new("UIScale", {}, Vt.panel)
P.voteCol = new("Frame", {Size = UDim2.fromOffset(0, 46), AutomaticSize = AUTO_X, BackgroundTransparency = 1, LayoutOrder = 1}, Vt.panel)
list({HorizontalAlignment = CENTER, VerticalAlignment = MIDDLE}, P.voteCol)
Vt.title = mt({Size = UDim2.fromOffset(0, 26), AutomaticSize = AUTO_X, TextSize = 21, Text = "Ready?", LayoutOrder = 1}, P.voteCol, Wt.XBOLD)
Vt.sub = mt({Size = UDim2.fromOffset(0, 18), AutomaticSize = AUTO_X, TextSize = 15, TextStrokeTransparency = 1, Text = "", LayoutOrder = 2}, P.voteCol, Wt.MED)
-- botón de voto: degradado, borde blanco, franja oscura abajo con su texto y el icono arriba
function P.voteButton(w, h, hi, lo, strip, order)
	local b = corner(new("TextButton", {Size = UDim2.fromOffset(w, h), BackgroundColor3 = WHITE, BorderSizePixel = 0, AutoButtonColor = false, Text = "", LayoutOrder = order}, Vt.panel), 6)
	new("UIGradient", {Rotation = 90, Color = ColorSequence.new(hi, lo)}, b)
	outline(b, WHITE, 2, 0)
	local band = corner(new("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.36), BackgroundColor3 = strip, BorderSizePixel = 0, ZIndex = 2}, b), 6)
	new("Frame", {Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = strip, BorderSizePixel = 0, ZIndex = 2}, band) -- (arriba, sin redondear)
	corner(new("Frame", {Position = UDim2.fromOffset(4, 3), Size = UDim2.new(1, -8, 0, 7), BackgroundColor3 = WHITE, BackgroundTransparency = 0.72, BorderSizePixel = 0, ZIndex = 2}, b), 4)
	local label = mt({AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.36), TextSize = 16, Text = "", ZIndex = 4}, b, Wt.BLACK)
	-- ya votado: se apaga
	local dim = corner(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 5}, b), 6)
	Kit.press(b)
	return b, label, dim
end
P.GREEN_HI, P.GREEN_LO, P.GREEN_BAND = Color3.fromRGB(86, 242, 58), Color3.fromRGB(45, 196, 28), Color3.fromRGB(31, 150, 18)
Vt.ready, Vt.readyLabel, Vt.readyDim = P.voteButton(140, 50, P.GREEN_HI, P.GREEN_LO, P.GREEN_BAND, 2)
Vt.readyLabel.Text = "READY"
Vt.face = corner(new("ImageLabel", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 3), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = Color3.fromRGB(36, 120, 28), Image = "", ZIndex = 3}, Vt.ready), UDim.new(0.5, 0))
outline(Vt.face, Sty.INK, 1.5, 0.2)
Vt.yes, Vt.yesCount, Vt.yesDim = P.voteButton(52, 64, P.GREEN_HI, P.GREEN_LO, P.GREEN_BAND, 3)
hicon("check", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(32, 32), ZIndex = 3}, Vt.yes)
Vt.no, Vt.noCount, Vt.noDim = P.voteButton(52, 64, Color3.fromRGB(255, 92, 100), Color3.fromRGB(224, 35, 46), Color3.fromRGB(160, 18, 28), 4)
hicon("cross", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(32, 32), ZIndex = 3}, Vt.no)

---------- Arriba a la derecha: los jugadores (cabecera oscura y una fila por jugador) ----------
local team = new("Frame", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(300, 0), AutomaticSize = AUTO_Y, BackgroundTransparency = 1}, hud)
list({Padding = UDim.new(0, 2)}, team)
P.teamHead = new("Frame", {Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Color3.fromRGB(18, 16, 21), BackgroundTransparency = 0.12, BorderSizePixel = 0, LayoutOrder = 0}, team)
local teamTitle = mt({Position = UDim2.fromOffset(11, 0), Size = UDim2.new(1, -130, 1, 0), TextSize = 13, TextXAlignment = LEFT, Text = "PLAYERS"}, P.teamHead, Wt.BLACK)
local diffChip = corner(mt({
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -46, 0.5, 0), Size = UDim2.fromOffset(0, 18), AutomaticSize = AUTO_X, BackgroundTransparency = 0,
	BackgroundColor3 = UI.GOLD, TextSize = 10, TextStrokeTransparency = 0.4, Text = "",
}, P.teamHead, Wt.BLACK), 4)
pad(diffChip, 7, 7, 0, 0)
new("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -37, 0.5, 0), Size = UDim2.fromOffset(1, 22), BackgroundColor3 = WHITE, BackgroundTransparency = 0.75, BorderSizePixel = 0}, P.teamHead)
hicon("players", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(22, 22)}, P.teamHead)
local teamRows = {}

local function refreshTeam()
	local members = {}
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("TDCash") ~= nil then
			table.insert(members, p)
		end
	end
	for p, r in teamRows do
		if not table.find(members, p) then
			r:Destroy()
			teamRows[p] = nil
		end
	end
	for i, p in members do
		local r = teamRows[p]
		if not r then
			r = new("Frame", {Size = UDim2.new(1, 0, 0, 29), BackgroundColor3 = BLACK, BackgroundTransparency = p == player and 0.3 or 0.42, BorderSizePixel = 0}, team)
			mt({
				Position = UDim2.fromOffset(11, 0), Size = UDim2.new(1, -96, 1, 0), TextSize = 13, TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd,
				Text = p.DisplayName,
			}, r, Wt.BOLD)
			mt({Name = "Cash", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -11, 0, 0), Size = UDim2.new(0, 80, 1, 0), TextSize = 12, TextXAlignment = RIGHT, Text = ""}, r, Wt.BOLD)
			teamRows[p] = r
		end
		r.LayoutOrder = i + 1
		local cash = p:GetAttribute("TDCash") or 0
		r.Cash.Text = cash >= 1e4 and "$" .. Kit.short(cash) or Kit.money(cash)
	end
end

---------- Abajo: velocidad y mapa | barra de tropas | dinero y tropas puestas ----------
local bar = new("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.fromOffset(0, SLOT.Y + 12), AutomaticSize = AUTO_X, BackgroundTransparency = 1}, hud)
list({FillDirection = HORIZONTAL, VerticalAlignment = BOTTOM, Padding = UDim.new(0, 8)}, bar)
-- botón gris cuadrado (velocidad, mapa)
function P.squareButton(order)
	local b = corner(new("TextButton", {Size = UDim2.fromOffset(46, 46), BackgroundColor3 = Color3.fromRGB(58, 58, 66), BackgroundTransparency = 0.12, BorderSizePixel = 0, AutoButtonColor = false, Text = "", LayoutOrder = order}, bar), 4)
	local st = outline(b, BLACK, 1.5, 0.4)
	Kit.press(b)
	return b, st
end
local speedBtn, speedStroke = P.squareButton(0)
local speedIcon = hicon("chevron", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 3), Size = UDim2.fromOffset(25, 25)}, speedBtn)
local speedText = mt({AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 16), TextSize = 12, Text = "x1"}, speedBtn, Wt.BOLD)
-- candado (como la tecla del mapa): solo el anfitrión cambia la velocidad
local speedLock = corner(mt({
	Position = UDim2.fromOffset(-5, -7), Size = UDim2.fromOffset(17, 17), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(40, 32, 56), TextStrokeTransparency = 1,
	TextSize = 10, Text = "🔒", Visible = false, ZIndex = 3,
}, speedBtn, Wt.BLACK), 4)
local mapBtn, mapStroke = P.squareButton(1)
hicon("map", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(33, 33)}, mapBtn)
P.mapKey = corner(mt({
	Position = UDim2.fromOffset(-5, -7), Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 0, BackgroundColor3 = WHITE, TextColor3 = Sty.INK, TextStrokeTransparency = 1,
	TextSize = 11, Text = "V", Visible = not TOUCH, ZIndex = 3,
}, mapBtn, Wt.BLACK), 4)
outline(P.mapKey, Sty.INK, 1.5, 0)
local hand = new("Frame", {Size = UDim2.fromOffset(0, SLOT.Y + 12), AutomaticSize = AUTO_X, BackgroundTransparency = 1, LayoutOrder = 2}, bar)
list({FillDirection = HORIZONTAL, VerticalAlignment = BOTTOM, Padding = UDim.new(0, 6)}, hand)
-- dinero (billetes) y tropas puestas (chincheta), en franjas de color que se desvanecen
local wallet = new("Frame", {Size = UDim2.fromOffset(132, SLOT.Y), BackgroundTransparency = 1, LayoutOrder = 3}, bar)
function P.walletRow(y, iconName, isz, color)
	local p = corner(new("Frame", {Position = UDim2.fromOffset(isz * 0.55, y + 2), Size = UDim2.new(1, -isz * 0.55, 0, 23), BackgroundColor3 = color, BorderSizePixel = 0}, wallet), 3)
	new("UIGradient", {Transparency = NumberSequence.new(0.05, 1)}, p)
	local t = mt({Position = UDim2.fromOffset(isz * 0.5 + 5, 0), Size = UDim2.new(1, -(isz * 0.5 + 5), 1, 0), TextSize = 14, TextXAlignment = LEFT, Text = ""}, p, Wt.BOLD)
	local ic = hicon(iconName, {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(0, y + 13), Size = UDim2.fromOffset(isz, isz), ZIndex = 2}, wallet)
	return t, ic
end
local cashText, cashIcon = P.walletRow(2, "cash", 36, Color3.fromRGB(47, 154, 62))
local cashPop = new("UIScale", {}, cashIcon)
local unitsText = P.walletRow(32, "pin", 28, Color3.fromRGB(201, 48, 60))

---------- Abajo a la izquierda: saltar solo y salir (iconos sin caja, como en TDS) ----------
local side = new("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -8), Size = UDim2.fromOffset(0, 58), AutomaticSize = AUTO_X, BackgroundTransparency = 1}, hud)
list({FillDirection = HORIZONTAL, Padding = UDim.new(0, 8)}, side)
function P.sideButton(icon, caption, order)
	local b = new("TextButton", {Size = UDim2.fromOffset(58, 58), BackgroundTransparency = 1, Text = "", LayoutOrder = order}, side)
	Kit.press(b)
	local ic = hicon(icon, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(40, 40)}, b)
	local cap = mt({Position = UDim2.new(0, -8, 1, -17), Size = UDim2.new(1, 16, 0, 16), TextSize = 11, Text = caption}, b, Wt.BOLD)
	return b, cap, ic
end
local autoBtn, autoLabel, autoIcon = P.sideButton("fast", "Auto skip", 1)
local leave, leaveLabel = P.sideButton("leave", "Leave", 2)

P.leaveArmed = 0
leave.Activated:Connect(function()
	if os.clock() - P.leaveArmed < 3 then
		Remote:FireServer("Leave")
	else
		P.leaveArmed = os.clock()
		leaveLabel.Text, leaveLabel.TextColor3 = "Sure?", UI.RED
		UI.sound("Tab")
		task.delay(3, function()
			leaveLabel.Text, leaveLabel.TextColor3 = "Leave", WHITE
		end)
	end
end)
autoBtn.Activated:Connect(function()
	Remote:FireServer("AutoSkip")
	UI.sound("Tab")
end)

---------- Colocar: la lista de teclas junto al ratón (PC), los botones (móvil), la huella rayada y el camino teñido ----------
local Hn = {}
Hn.list = new("Frame", {Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1, Visible = false, ZIndex = 30}, hud)
list({Padding = UDim.new(0, 4)}, Hn.list)
-- una fila: [tecla] texto, en una pastilla oscura (como el "Lieu / R Tourner / Q Annuler" de TDS)
function Hn.row(order, key, text, small)
	local r = corner(new("Frame", {Size = UDim2.fromOffset(0, 24), AutomaticSize = AUTO_X, BackgroundColor3 = Color3.fromRGB(22, 22, 26), BackgroundTransparency = 0.12, BorderSizePixel = 0, LayoutOrder = order, ZIndex = 30}, Hn.list), 4)
	pad(r, 4, 9, 3, 3)
	list({FillDirection = HORIZONTAL, VerticalAlignment = MIDDLE, Padding = UDim.new(0, 7)}, r)
	local k = corner(new("Frame", {Size = UDim2.fromOffset(0, 18), AutomaticSize = AUTO_X, BackgroundColor3 = Color3.fromRGB(64, 64, 72), BorderSizePixel = 0, LayoutOrder = 1, ZIndex = 31}, r), 3)
	pad(k, 5, 5, 0, 0)
	mt({Size = UDim2.fromOffset(0, 18), AutomaticSize = AUTO_X, TextSize = small and 9 or 12, Text = key, ZIndex = 32}, k, Wt.BLACK)
	local tt = mt({Size = UDim2.fromOffset(0, 18), AutomaticSize = AUTO_X, TextSize = small and 11 or 13, Text = text, LayoutOrder = 2, ZIndex = 31}, r, Wt.BOLD)
	return tt, k
end
Hn.placeText, Hn.placeBox = Hn.row(1, "", "Place")
-- el ratón dibujado, con el botón izquierdo encendido (verde: se puede; rojo: no)
Hn.mouseBody = corner(new("Frame", {Position = UDim2.fromOffset(0, 2), Size = UDim2.fromOffset(11, 14), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 33}, Hn.placeBox), UDim.new(0.5, 0))
Hn.mouseBtn = corner(new("Frame", {Size = UDim2.fromOffset(5, 6), BackgroundColor3 = Sty.PRICE, BorderSizePixel = 0, ZIndex = 34}, Hn.mouseBody), 2)
Hn.row(2, "R", "Rotate")
Hn.row(3, "Q", "Cancel")
Hn.row(4, "LSHIFT", "Quick place", true)
-- móvil: botones grandes
Hn.touch = new("Frame", {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -(SLOT.Y + 28)), Size = UDim2.fromOffset(330, 52), BackgroundTransparency = 1, Visible = false}, hud)
list({FillDirection = HORIZONTAL, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 8)}, Hn.touch)
function Hn.button(text, w, hi, lo, order)
	local b = corner(new("TextButton", {Size = UDim2.fromOffset(w, 50), BackgroundColor3 = WHITE, BorderSizePixel = 0, AutoButtonColor = false, Text = "", LayoutOrder = order}, Hn.touch), 6)
	new("UIGradient", {Rotation = 90, Color = ColorSequence.new(hi, lo)}, b)
	outline(b, WHITE, 2, 0)
	mt({Size = UDim2.fromScale(1, 1), TextSize = 18, Text = text}, b, Wt.XBOLD)
	Kit.press(b)
	return b
end
Hn.rotate = Hn.button("Rotate", 96, Color3.fromRGB(112, 112, 122), Color3.fromRGB(68, 68, 78), 1)
Hn.cancel = Hn.button("Cancel", 96, Color3.fromRGB(255, 72, 80), Color3.fromRGB(214, 28, 40), 2)
Hn.place = Hn.button("Place", 120, Color3.fromRGB(86, 242, 58), Color3.fromRGB(45, 196, 28), 3)
-- huella de la tropa: disco rayado bajo la vista previa (blanco: se puede; rojo: no)
function Hn.footprint()
	local p = new("Part", {Name = "Huella", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Transparency = 1, Size = Vector3.new(4.6, 0.05, 4.6)}, workspace)
	local sg = new("SurfaceGui", {Face = Enum.NormalId.Top, LightInfluence = 0, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 30, Adornee = p}, p)
	-- el disco va girado 45° y cada raya es una cuerda del círculo (su largo exacto en esa franja): no se sale nunca
	-- (los marcos girados no se recortan bien, ni con ClipsDescendants ni con CanvasGroup)
	local disc = corner(new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -12, 1, -12), Rotation = 45, BackgroundColor3 = WHITE, BackgroundTransparency = 0.72, BorderSizePixel = 0}, sg), UDim.new(0.5, 0))
	local stripes = {}
	local w = 0.05 -- ancho de cada raya (fracción del diámetro)
	for k = -5, 5 do
		local x = k * 0.085
		local out = math.abs(x) + w / 2
		local len = 2 * math.sqrt(math.max(0, 0.25 - out * out)) - 0.04
		if len > 0.08 then
			table.insert(stripes, corner(new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5 + x, 0.5), Size = UDim2.fromScale(w, len), BackgroundColor3 = WHITE, BackgroundTransparency = 0.3, BorderSizePixel = 0}, disc), UDim.new(0.5, 0)))
		end
	end
	local edge = new("UIStroke", {Color = WHITE, Thickness = 5, Transparency = 0.05}, disc)
	return {part = p, disc = disc, edge = edge, stripes = stripes}
end
-- color de la huella (blanco: se puede; rojo: no)
function Hn.paintFoot(f, c)
	f.disc.BackgroundColor3, f.edge.Color = c, c
	for _, s in f.stripes do
		s.BackgroundColor3 = c
	end
end
-- el camino se tiñe mientras colocas: rojo si la tropa no puede ir en él; verde si es una trampa (solo va en él)
function Hn.lane(t)
	local f = new("Folder", {Name = "CaminoVista"}, workspace)
	local color = TD.Troops[t].kind == "trap" and Color3.fromRGB(100, 240, 120) or Color3.fromRGB(255, 96, 96)
	-- copias translúcidas de la tierra del camino (encajan sin solaparse: el tinte queda uniforme, como en TDS)
	local lane = map:FindFirstChild("MapaTDS") and map.MapaTDS:FindFirstChild("Camino")
	if lane and lane:FindFirstChild("Tierra") then
		for _, d in lane:GetChildren() do
			if d.Name == "Tierra" and d:IsA("BasePart") then
				new("Part", {
					Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.SmoothPlastic,
					Color = color, Transparency = 0.5, Size = d.Size + Vector3.new(0, 0.04, 0), CFrame = d.CFrame * CFrame.new(0, 0.03, 0),
				}, f)
			end
		end
		return f
	end
	-- (mapas sin esas piezas: una losa por tramo)
	local pts = TD.path(map).pts
	local w = (map:GetAttribute("PathWidth") or 7) + 0.6
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip = {f, state}
	for _, p in Players:GetPlayers() do
		table.insert(skip, p.Character)
	end
	params.FilterDescendantsInstances = skip
	-- ¿gira el camino en el punto i? (ahí el tramo se alarga medio ancho para tapar la esquina)
	local function turns(i)
		local a, b, c = pts[i - 1], pts[i], pts[i + 1]
		if not (a and c) then
			return false
		end
		local u, v = Vector3.new(b.X - a.X, 0, b.Z - a.Z), Vector3.new(c.X - b.X, 0, c.Z - b.Z)
		return u.Magnitude > 0.01 and v.Magnitude > 0.01 and u.Unit:Dot(v.Unit) < 0.97
	end
	for i = 2, #pts do
		local a, b = pts[i - 1], pts[i]
		local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local len = dir.Magnitude
		if len > 0.1 then
			dir = dir.Unit
			-- a ras del suelo del camino (los puntos del recorrido van algo más altos)
			local mid = a:Lerp(b, 0.5)
			local hit = workspace:Raycast(mid + Vector3.new(0, 6, 0), Vector3.new(0, -20, 0), params)
			local dy = (hit and hit.Position.Y or mid.Y - 0.4) + 0.12 - mid.Y
			local ea, eb = turns(i - 1) and w / 2 or 0, turns(i) and w / 2 or 0
			local from = a - dir * ea + Vector3.new(0, dy, 0)
			local to = b + dir * eb + Vector3.new(0, dy, 0)
			new("Part", {
				Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.SmoothPlastic,
				Color = color, Transparency = 0.5, Size = Vector3.new(w, 0.1, len + ea + eb), CFrame = CFrame.lookAt(from:Lerp(to, 0.5), to + (to - from).Unit * 0.01),
			}, f)
		end
	end
	return f
end

-- Ficha de una tropa al pasar por encima de su carta
local tip = corner(new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(240, 0), AutomaticSize = AUTO_Y, BackgroundColor3 = Color3.fromRGB(22, 22, 26),
	BackgroundTransparency = 0.06, BorderSizePixel = 0, Visible = false, ZIndex = 20,
}, hud), 6)
P.tipStroke = outline(tip, WHITE, 2, 0.1)
pad(tip, 10, 10, 8, 9)
list({Padding = UDim.new(0, 3)}, tip)
P.tipName = mt({Size = UDim2.new(1, 0, 0, 20), TextSize = 16, TextXAlignment = LEFT, LayoutOrder = 1, ZIndex = 21}, tip, Wt.BLACK)
P.tipKind = mt({Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AUTO_Y, TextSize = 11, TextColor3 = UI.GOLD, TextStrokeTransparency = 1, TextWrapped = true, TextXAlignment = LEFT, LayoutOrder = 2, ZIndex = 21}, tip, Wt.BOLD)
P.tipInfo = mt({Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AUTO_Y, TextSize = 11, TextColor3 = Color3.fromRGB(222, 222, 230), TextStrokeTransparency = 1, TextWrapped = true, TextXAlignment = LEFT, LayoutOrder = 3, ZIndex = 21}, tip, Wt.MED)
P.tipStats = mt({Size = UDim2.new(1, 0, 0, 16), TextSize = 12, TextXAlignment = LEFT, LayoutOrder = 4, ZIndex = 21}, tip, Wt.BOLD)

---------- Panel de la tropa (abajo, sobre la barra, como el de TDS): estadísticas a la izquierda; la tropa con su objetivo,
---------- nivel, gastado, miedo causado y venta; a la derecha, la siguiente mejora con lo que cambia ----------
local Pn = {} -- piezas del panel
Pn.TARGETS = {First = "First enemy", Last = "Last enemy", Strong = "Strongest", Close = "Closest"}
function Pn.pct(v)
	return ("+%d%%"):format(v * 100 + 0.5)
end
function Pn.secs(v)
	return ("%.2fs"):format(v)
end
function Pn.dec(v)
	return ("%.1f"):format(v)
end
Pn.root = new("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 110, 1, -(SLOT.Y + 26)), Size = UDim2.fromOffset(560, 286), BackgroundTransparency = 1, Visible = false}, hud)
Pn.pop = new("UIScale", {}, Pn.root)
Pn.body = corner(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(22, 22, 26), BackgroundTransparency = 0.06, BorderSizePixel = 0}, Pn.root), 6)
outline(Pn.body, BLACK, 2, 0.2)
do
	-- izquierda: la tropa
	local L = new("Frame", {Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(262, 258), BackgroundTransparency = 1}, Pn.body)
	Pn.face = corner(new("Frame", {Size = UDim2.fromOffset(262, 166), BackgroundColor3 = Color3.fromRGB(34, 32, 40), BorderSizePixel = 0, ClipsDescendants = true}, L), 6)
	outline(Pn.face, Color3.fromRGB(78, 78, 88), 1.5, 0)
	Pn.glow = UI.piece("glow", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(250, 250), ImageTransparency = 0.1}, Pn.face)
	Pn.name = mt({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.new(1, -10, 0, 30), TextSize = 24, Text = "", ZIndex = 5}, Pn.face, Wt.BLACK)
	Pn.targetCap = mt({AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(120, 15), TextSize = 12, Text = "Target:", ZIndex = 5}, Pn.face, Wt.BOLD)
	Pn.target = mt({AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, -80, 0, 20), TextSize = 15, Text = "", ZIndex = 5}, Pn.face, Wt.XBOLD)
	local function arrow(dx)
		local b = corner(new("TextButton", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, dx, 1, -4), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = Color3.fromRGB(78, 78, 88), BorderSizePixel = 0, AutoButtonColor = false, Text = "", ZIndex = 5}, Pn.face), UDim.new(0.5, 0))
		outline(b, WHITE, 1.5, 0.25)
		hicon("chevron", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(16, 16), Rotation = dx < 0 and 180 or 0, ZIndex = 6}, b)
		Kit.press(b)
		return b
	end
	Pn.prev, Pn.next = arrow(-108), arrow(108)
	-- nivel y gastado | miedo causado
	Pn.info = corner(new("Frame", {Position = UDim2.fromOffset(0, 172), Size = UDim2.fromOffset(262, 46), BackgroundColor3 = BLACK, BackgroundTransparency = 0.45, BorderSizePixel = 0}, L), 5)
	outline(Pn.info, Color3.fromRGB(150, 150, 160), 1.5, 0.35)
	Pn.level = mt({Position = UDim2.fromOffset(9, 4), Size = UDim2.fromOffset(130, 18), TextSize = 13, TextXAlignment = LEFT, Text = ""}, Pn.info, Wt.BOLD)
	Pn.spent = mt({Position = UDim2.fromOffset(9, 23), Size = UDim2.fromOffset(130, 18), TextSize = 13, TextXAlignment = LEFT, Text = ""}, Pn.info, Wt.BOLD)
	Pn.dealtCap = mt({AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -9, 0, 4), Size = UDim2.fromOffset(120, 18), TextSize = 13, TextXAlignment = RIGHT, Text = ""}, Pn.info, Wt.BOLD)
	Pn.dealt = mt({AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -9, 0, 23), Size = UDim2.fromOffset(120, 18), TextSize = 13, TextXAlignment = RIGHT, Text = ""}, Pn.info, Wt.BOLD)
	-- vender: [X] y el botón rojo
	local row = new("Frame", {Position = UDim2.fromOffset(0, 226), Size = UDim2.fromOffset(262, 32), BackgroundTransparency = 1}, L)
	Pn.sellKey = corner(mt({AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 0, BackgroundColor3 = WHITE, TextColor3 = Sty.INK, TextStrokeTransparency = 1, TextSize = 15, Text = "X", Visible = not TOUCH}, row, Wt.BLACK), 4)
	Pn.sell = corner(new("TextButton", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(1, TOUCH and 0 or -34, 1, 0), BackgroundColor3 = WHITE, BorderSizePixel = 0, AutoButtonColor = false, Text = ""}, row), 5)
	new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 76, 84), Color3.fromRGB(212, 26, 38))}, Pn.sell)
	outline(Pn.sell, WHITE, 2, 0)
	Pn.sellText = mt({Size = UDim2.fromScale(1, 1), TextSize = 17, Text = ""}, Pn.sell, Wt.XBOLD)
	Kit.press(Pn.sell)
	Pn.owner = mt({Size = UDim2.fromScale(1, 1), TextSize = 13, TextColor3 = Color3.fromRGB(205, 205, 215), Text = "", Visible = false}, row, Wt.SEMI)

	-- derecha: la siguiente mejora (tarjeta verde con la imagen, el nivel y el precio; una pastilla por nivel)
	local R = new("Frame", {Position = UDim2.fromOffset(290, 14), Size = UDim2.fromOffset(256, 258), BackgroundTransparency = 1}, Pn.body)
	Pn.up = corner(new("TextButton", {Size = UDim2.fromOffset(256, 98), BackgroundColor3 = WHITE, BorderSizePixel = 0, AutoButtonColor = false, Text = ""}, R), 6)
	Pn.upGrad = new("UIGradient", {Rotation = 90}, Pn.up)
	Pn.upStroke = outline(Pn.up, Color3.fromRGB(130, 255, 150), 2, 0.15)
	Kit.press(Pn.up)
	Pn.upImg = corner(new("Frame", {Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(66, 66), BackgroundColor3 = Color3.fromRGB(18, 52, 26), BackgroundTransparency = 0.2, BorderSizePixel = 0, ClipsDescendants = true}, Pn.up), 5)
	outline(Pn.upImg, BLACK, 1.5, 0.3)
	Pn.upKey = corner(mt({Position = UDim2.fromOffset(60, 60), Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 0, BackgroundColor3 = WHITE, TextColor3 = Sty.INK, TextStrokeTransparency = 1, TextSize = 13, Text = "E", ZIndex = 4}, Pn.up, Wt.BLACK), 4)
	outline(Pn.upKey, Sty.INK, 1.5, 0)
	Pn.upTitle = mt({Position = UDim2.fromOffset(84, 8), Size = UDim2.new(1, -92, 0, 24), TextSize = 19, TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd, Text = ""}, Pn.up, Wt.XBOLD)
	Pn.upSub = mt({Position = UDim2.fromOffset(84, 31), Size = UDim2.new(1, -92, 0, 15), TextSize = 12, TextXAlignment = LEFT, TextColor3 = Color3.fromRGB(215, 240, 215), Text = ""}, Pn.up, Wt.BOLD)
	Pn.upPrice = mt({Position = UDim2.fromOffset(84, 47), Size = UDim2.new(1, -92, 0, 26), TextSize = 21, TextXAlignment = LEFT, Text = ""}, Pn.up, Wt.BLACK)
	local pips = new("Frame", {Position = UDim2.fromOffset(8, 82), Size = UDim2.new(1, -16, 0, 9), BackgroundTransparency = 1}, Pn.up)
	list({FillDirection = HORIZONTAL, Padding = UDim.new(0, 5)}, pips)
	Pn.pip = {}
	for i = 1, TD.MAX_LEVEL do
		Pn.pip[i] = corner(new("Frame", {Size = UDim2.new(1 / TD.MAX_LEVEL, -4, 1, 0), BorderSizePixel = 0, LayoutOrder = i}, pips), 4)
		outline(Pn.pip[i], BLACK, 1, 0.45)
	end
	-- lo que cambia con la mejora: "16 → 23"
	Pn.changes = corner(new("Frame", {Position = UDim2.fromOffset(0, 106), Size = UDim2.fromOffset(256, 0), AutomaticSize = AUTO_Y, BackgroundColor3 = BLACK, BackgroundTransparency = 0.45, BorderSizePixel = 0}, R), 5)
	outline(Pn.changes, Color3.fromRGB(150, 150, 160), 1.5, 0.35)
	pad(Pn.changes, 12, 10, 10, 10)
	list({Padding = UDim.new(0, 6)}, Pn.changes)
	Pn.rows = {}
	for i = 1, 4 do
		local r = new("Frame", {Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = i}, Pn.changes)
		local ic = hicon("fear", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(22, 22)}, r)
		local tx = mt({Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -32, 1, 0), TextSize = 15, TextXAlignment = LEFT, RichText = true, Text = ""}, r, Wt.SEMI)
		Pn.rows[i] = {frame = r, icon = ic, text = tx}
	end
	Pn.desc = mt({Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AUTO_Y, TextSize = 11, TextWrapped = true, TextXAlignment = LEFT, TextStrokeTransparency = 1, TextColor3 = Color3.fromRGB(226, 226, 234), Text = "", LayoutOrder = 9}, Pn.changes, Wt.MED)

	-- "?": la descripción de la tropa en lugar de la mejora
	Pn.help = corner(new("TextButton", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(34, 34), BackgroundColor3 = Color3.fromRGB(40, 130, 232), BorderSizePixel = 0, AutoButtonColor = false, Text = "", ZIndex = 6}, Pn.root), UDim.new(0.5, 0))
	outline(Pn.help, WHITE, 2.5, 0)
	mt({Size = UDim2.fromScale(1, 1), TextSize = 22, Text = "?", ZIndex = 7}, Pn.help, Wt.BLACK)
	Kit.press(Pn.help)

	-- fuera, a la izquierda: estadísticas y DPS (o lo ganado, o el aura)
	Pn.stats = corner(new("Frame", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(0, -8, 0, 12), Size = UDim2.fromOffset(88, 106), BackgroundColor3 = Color3.fromRGB(22, 22, 26), BackgroundTransparency = 0.06, BorderSizePixel = 0}, Pn.root), 5)
	outline(Pn.stats, BLACK, 2, 0.2)
	mt({Position = UDim2.fromOffset(0, 3), Size = UDim2.new(1, 0, 0, 13), TextSize = 9, TextStrokeTransparency = 1, Text = "STATS"}, Pn.stats, Wt.BLACK)
	new("Frame", {Position = UDim2.fromOffset(8, 18), Size = UDim2.new(1, -16, 0, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.6, BorderSizePixel = 0}, Pn.stats)
	Pn.stat = {}
	for i = 1, 3 do
		local ic = hicon("hourglass", {Position = UDim2.fromOffset(7, 23 + (i - 1) * 27), Size = UDim2.fromOffset(19, 19)}, Pn.stats)
		local tx = mt({Position = UDim2.fromOffset(28, 22 + (i - 1) * 27), Size = UDim2.new(1, -35, 0, 21), TextSize = 15, TextXAlignment = RIGHT, Text = ""}, Pn.stats, Wt.BOLD)
		Pn.stat[i] = {icon = ic, text = tx}
	end
	Pn.dps = corner(new("Frame", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(0, -8, 0, 126), Size = UDim2.fromOffset(88, 54), BackgroundColor3 = Color3.fromRGB(22, 22, 26), BackgroundTransparency = 0.06, BorderSizePixel = 0}, Pn.root), 5)
	outline(Pn.dps, BLACK, 2, 0.2)
	Pn.dpsCap = mt({Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 18), TextSize = 14, Text = "DPS"}, Pn.dps, Wt.BOLD)
	Pn.dpsIcon = hicon("sword", {Position = UDim2.fromOffset(7, 27), Size = UDim2.fromOffset(20, 20)}, Pn.dps)
	Pn.dpsText = mt({Position = UDim2.fromOffset(28, 26), Size = UDim2.new(1, -35, 0, 22), TextSize = 15, TextXAlignment = RIGHT, Text = ""}, Pn.dps, Wt.BOLD)
	-- el nivel de la tropa (★) y su miedo extra
	Pn.bonus = mt({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 31), Size = UDim2.new(1, -10, 0, 16), TextSize = 12, TextColor3 = UI.GOLD, Text = "", ZIndex = 5}, Pn.face, Wt.BOLD)
end

---------- Banner de oleada: texto grande en el centro, sin fondo ----------
local showBanner
do
	local banner = new("CanvasGroup", {
		-- (a media pantalla: arriba, bajo el marcador, salen las recompensas de la oleada y no se pisan)
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.new(1, 0, 0, 100), BackgroundTransparency = 1,
		GroupTransparency = 1, Visible = false, ZIndex = 30,
	}, hud)
	local bTitle = mt({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.new(1, 0, 0, 56), TextSize = 46, Text = ""}, banner, Wt.BLACK)
	local bSub = mt({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 62), Size = UDim2.new(1, 0, 0, 26), TextSize = 18, RichText = true, Text = ""}, banner, Wt.BOLD)
	local bannerToken = 0

	function showBanner(title, sub, color, hold)
		bannerToken += 1
		local token = bannerToken
		bTitle.Text, bSub.Text = title, sub or ""
		bTitle.TextColor3 = color
		banner.Visible = true
		banner.GroupTransparency = 1
		bTitle.Position = UDim2.new(0.5, 0, 0, -20)
		tween(banner, 0.2, {GroupTransparency = 0})
		tween(bTitle, 0.45, {Position = UDim2.new(0.5, 0, 0, 4)}, Enum.EasingStyle.Back)
		task.delay(hold or 2, function()
			if bannerToken ~= token then
				return
			end
			tween(banner, 0.35, {GroupTransparency = 1})
			task.wait(0.4)
			if bannerToken == token then
				banner.Visible = false
			end
		end)
	end
end

---------- Recompensas de la oleada: líneas con icono bajo el marcador (como el "Wave Reward" de TDS) ----------
local rewards = new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 196), Size = UDim2.fromOffset(600, 0), AutomaticSize = AUTO_Y, BackgroundTransparency = 1, ZIndex = 25}, hud)
list({HorizontalAlignment = CENTER, Padding = UDim.new(0, 6)}, rewards)
P.rewardToken = 0
local function clearRewards()
	for _, c in rewards:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end
-- lines = {{icono, texto, color?}, ...}: entran una a una con un saltito y se van a los 3 s
local function showRewards(lines)
	P.rewardToken += 1
	local token = P.rewardToken
	clearRewards()
	for i, ln in lines do
		local row = new("Frame", {Size = UDim2.fromOffset(0, 28), AutomaticSize = AUTO_X, BackgroundTransparency = 1, LayoutOrder = i}, rewards)
		list({FillDirection = HORIZONTAL, VerticalAlignment = MIDDLE, Padding = UDim.new(0, 8)}, row)
		hicon(ln[1], {Size = UDim2.fromOffset(26, 26), LayoutOrder = 1}, row)
		mt({Size = UDim2.fromOffset(0, 28), AutomaticSize = AUTO_X, TextSize = 17, TextColor3 = ln[3] or WHITE, Text = ln[2], LayoutOrder = 2}, row, Wt.BOLD)
		local s = new("UIScale", {Scale = 0}, row)
		task.delay((i - 1) * 0.16, function()
			if P.rewardToken == token then
				tween(s, 0.35, {Scale = 1}, Enum.EasingStyle.Back)
				UI.sound("Coin", 0.45, 1 + i * 0.08)
			end
		end)
	end
	task.delay(3.4, function()
		if P.rewardToken ~= token then
			return
		end
		for _, d in rewards:GetDescendants() do
			if d:IsA("TextLabel") then
				tween(d, 0.4, {TextTransparency = 1, TextStrokeTransparency = 1})
			elseif d:IsA("ImageLabel") then
				tween(d, 0.4, {ImageTransparency = 1})
			end
		end
		task.wait(0.45)
		if P.rewardToken == token then
			clearRewards()
		end
	end)
end

---------- Resultados (se definen más abajo: Fase 6) ----------
local results
local showResults

---------- Efectos en el mundo (solo los ves tú) ----------
local function at(pos)
	local a = new("Attachment", {WorldPosition = pos}, workspace.Terrain)
	Debris:AddItem(a, 3)
	return a
end

local function near(pos, dist)
	return (workspace.CurrentCamera.CFrame.Position - pos).Magnitude < dist
end

local function sound3D(name, pos, gain)
	Sfx.play(name, at(pos), gain)
end

local function fxPart(props)
	props.Anchored, props.CanCollide, props.CanQuery, props.CanTouch, props.CastShadow = true, false, false, false, false
	props.Material = Enum.Material.Neon
	return new("Part", props, workspace)
end

-- Onda que se abre en el suelo
local function ring(pos, r, color, time)
	time = time or 0.45
	local p = fxPart({
		Shape = Enum.PartType.Cylinder, Color = color, Transparency = 0.3, Size = Vector3.new(0.15, 1, 1),
		CFrame = CFrame.new(pos + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.pi / 2),
	})
	tween(p, time, {Size = Vector3.new(0.15, r * 2, r * 2), Transparency = 1})
	Debris:AddItem(p, time + 0.05)
end

-- Estallido de miedo
local function burst(pos, color, size)
	local p = fxPart({Shape = Enum.PartType.Ball, Color = color, Transparency = 0.15, Size = Vector3.one * 0.6, CFrame = CFrame.new(pos)})
	tween(p, 0.3, {Size = Vector3.one * (size or 3), Transparency = 1})
	Debris:AddItem(p, 0.35)
end

-- Rayo de miedo de la tropa al objetivo
local function bolt(from, to, color)
	local a0, a1 = at(from), at(to)
	new("Beam", {
		Attachment0 = a0, Attachment1 = a1, Color = ColorSequence.new(color), LightEmission = 1, LightInfluence = 0, FaceCamera = true,
		Width0 = 0.8, Width1 = 0.25, Segments = 1, Transparency = NumberSequence.new(0.05),
	}, a0)
	Debris:AddItem(a0, 0.12)
	Debris:AddItem(a1, 0.12)
end

-- Texto que sube y se desvanece ("+$8", "-5 HP")
local function floater(pos, text, color)
	local a = at(pos + Vector3.new(0, 4, 0))
	local bb = new("BillboardGui", {Size = UDim2.fromOffset(140, 34), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 150}, a)
	local l = label({Size = UDim2.fromScale(1, 1), TextSize = 26, TextColor3 = color, TextStrokeTransparency = 0.2, Text = text}, bb)
	tween(bb, 0.9, {StudsOffset = Vector3.new(0, 2.5, 0)})
	tween(l, 0.9, {TextTransparency = 1, TextStrokeTransparency = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
end

-- "+10" con billetes sobre el cazafantasmas que huye (como en TDS); también al vender o cobrar un pozo
local function cashFloater(pos, text)
	local a = at(pos + Vector3.new(0, 4, 0))
	local bb = new("BillboardGui", {Size = UDim2.fromOffset(150, 36), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 150}, a)
	local row = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1}, bb)
	list({FillDirection = HORIZONTAL, HorizontalAlignment = CENTER, VerticalAlignment = MIDDLE, Padding = UDim.new(0, 3)}, row)
	local ic = hicon("cash", {Size = UDim2.fromOffset(28, 28), LayoutOrder = 1}, row)
	local l = mt({Size = UDim2.fromOffset(0, 34), AutomaticSize = AUTO_X, TextSize = 24, Text = "+" .. text, LayoutOrder = 2}, row, Wt.XBOLD)
	local st = new("UIStroke", {Color = Sty.INK, Thickness = 2.2, LineJoinMode = Enum.LineJoinMode.Round}, l) -- (fuera de la pantalla no hay contorno automático)
	local s = new("UIScale", {Scale = 0.4}, row)
	tween(s, 0.25, {Scale = 1}, Enum.EasingStyle.Back)
	tween(bb, 1, {StudsOffset = Vector3.new(0, 2.6, 0)})
	task.delay(0.6, function()
		tween(l, 0.4, {TextTransparency = 1, TextStrokeTransparency = 1})
		tween(st, 0.4, {Transparency = 1})
		tween(ic, 0.4, {ImageTransparency = 1})
	end)
end

-- Número de miedo en el objetivo (salta, sube y se apaga)
local function fearNumber(pos, n, color)
	local a = at(pos + Vector3.new((math.random() - 0.5) * 1.6, 3 + math.random(), (math.random() - 0.5) * 1.6))
	local bb = new("BillboardGui", {Size = UDim2.fromOffset(n < 0 and 120 or 70, 30), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 170}, a)
	local l = label({
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0, 0), TextScaled = true,
		TextColor3 = n < 0 and UI.RED or color:Lerp(Color3.new(1, 1, 1), 0.35), TextStrokeTransparency = 0.15, Text = n < 0 and "SCARED!" or tostring(n),
	}, bb)
	tween(l, 0.15, {Size = UDim2.fromScale(1, 1)}, Enum.EasingStyle.Back)
	tween(bb, 0.7, {StudsOffset = Vector3.new(0, 2, 0)})
	task.delay(0.35, function()
		tween(l, 0.35, {TextTransparency = 1, TextStrokeTransparency = 1})
	end)
	Debris:AddItem(a, 0.8)
end

---------- Proyectiles y efectos de las tropas nuevas ----------
local RunServiceFx = RunService
-- Rayo en zigzag (rebotes del Poltergeist)
local function zigzag(a, b, color)
	local pts = {a}
	for k = 1, 3 do
		local m = a:Lerp(b, k / 4)
		table.insert(pts, m + Vector3.new((math.random() - 0.5) * 1.6, (math.random() - 0.5) * 1.6, (math.random() - 0.5) * 1.6))
	end
	table.insert(pts, b)
	for k = 2, #pts do
		bolt(pts[k - 1], pts[k], color)
	end
end

-- Pequeños murciélagos (copias de los del modelo) que vuelan hasta el objetivo
local function batsTo(model, from, to)
	local src = model:FindFirstChild("Bat")
	for k = 1, 3 do
		local b
		if src and src:IsA("Model") then
			-- el murciélago es una criatura de bloques: una copia pequeña con las alas abiertas
			b = src:Clone()
			for _, p in b:GetDescendants() do
				if p:IsA("BasePart") then
					p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
					p.Transparency = p.Name == "Root" and 1 or (p:GetAttribute("T") or 0)
					p:SetAttribute("Orbit", nil)
				elseif p:IsA("ParticleEmitter") or p:IsA("Light") then
					p:Destroy()
				end
			end
			b:ScaleTo(0.55)
			b.Parent = workspace
		else
			b = fxPart({Color = Color3.fromRGB(30, 20, 40), Size = Vector3.new(0.8, 0.15, 0.4)})
		end
		local off = Vector3.new((math.random() - 0.5) * 3, math.random() * 2, (math.random() - 0.5) * 3)
		local t0, time = os.clock(), 0.22 + k * 0.05
		local conn
		conn = RunServiceFx.RenderStepped:Connect(function()
			local a = math.min(1, (os.clock() - t0) / time)
			local pos = from:Lerp(to, a) + off * math.sin(a * math.pi) + Vector3.new(0, math.sin(os.clock() * 40) * 0.2, 0)
			local cf = CFrame.lookAt(pos, to) * CFrame.Angles(0, 0, math.sin(os.clock() * 30) * 0.5)
			if b:IsA("Model") then
				b:PivotTo(cf)
			else
				b.CFrame = cf
			end
			if a >= 1 then
				conn:Disconnect()
				b:Destroy()
			end
		end)
	end
end

-- Aliento del dragón: chorro de partículas hacia el objetivo
local function breath(from, to, color)
	local a = new("Attachment", {WorldCFrame = CFrame.lookAt(from, to)}, workspace.Terrain)
	local e = new("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/fire_main.dds", Color = ColorSequence.new(color, Color3.new(1, 1, 1)), LightEmission = 1,
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3.5)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)}),
		Speed = NumberRange.new((to - from).Magnitude * 2.2), Lifetime = NumberRange.new(0.45, 0.55), SpreadAngle = Vector2.new(9, 9),
		EmissionDirection = Enum.NormalId.Front, Rate = 0, Drag = 1,
	}, a)
	e:Emit(26)
	Debris:AddItem(a, 1)
end

-- Zarpazo: tres tajos que cruzan al objetivo
local function claw(pos, color)
	local yaw = select(2, workspace.CurrentCamera.CFrame:ToEulerAnglesYXZ())
	for k = -1, 1 do
		local p = fxPart({Color = color, Size = Vector3.new(0.18, 3.2, 0.18), Transparency = 0.1, CFrame = CFrame.new(pos) * CFrame.Angles(0, yaw, 0) * CFrame.new(k * 0.6, 0, 0) * CFrame.Angles(0, 0, 0.6)})
		tween(p, 0.25, {Transparency = 1, Size = Vector3.new(0.05, 4, 0.05)})
		Debris:AddItem(p, 0.3)
	end
end

-- Onda (lamento de la Banshee): una esfera que crece y se apaga
local function shockwave(pos, r, color)
	local p = fxPart({Shape = Enum.PartType.Ball, Color = color, Transparency = 0.55, Size = Vector3.one, CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))})
	tween(p, 0.5, {Size = Vector3.one * r * 2, Transparency = 1})
	Debris:AddItem(p, 0.55)
end

---------- Tropas en el mundo: equipo de cada nivel, aura y animaciones ----------
-- Lo pone este cliente sobre el modelo que crea el servidor (y solo aquí la mueve, con BulkMoveTo). Sin peana: la tropa
-- pisa el suelo y cada nivel se nota en ella misma:
-- · El equipo que estrena en cada nivel (TowerGear[<tropa>], L2..L4, modelado en Blender), y cada nivel bastante más
--   grande (Tw.SCALE).
-- · Fuegos fatuos (TowerGear "Wisp", modelado en Blender) que la rodean: uno por mejora, del color de su nivel
--   (Tw.TIER: verde, morado, oro). Así el nivel se cuenta de un vistazo, también desde lejos.
-- · Aura del mismo color: chispas que suben alrededor, cada nivel más (y en el 4, un halo de luz dorada).
-- · Al colocarla sale del suelo de un salto; al mejorarla, destello dorado, columna de luz y estirón; al venderla
--   (atributo Sold: el servidor la quita enseguida) gira, se encoge y suelta monedas.
-- · Al atacar se gira hacia el objetivo: las de cuerpo a cuerpo dan un empellón, las de distancia retroceden y las de
--   área laten. En reposo flotan, se balancean o revolotean.
local Tw = {
	Gear = require(RS:WaitForChild("TowerGear")),
	SCALE = {1, 1.1, 1.2, 1.32}, -- tamaño en cada nivel
	RING = {5.3, 5.7, 6.1, 6.6}, -- aro cian bajo tus tropas
	AURA = {0, 3, 6, 10}, -- chispas por segundo del aura de cada nivel
	-- color de los fuegos fatuos de cada nivel (más saturado que Tw.TIER: el neón aclara) y su tamaño
	WISP = {nil, Color3.fromRGB(30, 225, 70), Color3.fromRGB(150, 50, 255), Color3.fromRGB(255, 170, 0)},
	WISP_SIZE = 1.6,
	LUNGE = {Zombie = true, Armario = true, Parca = true, HombreLobo = true},
	STATIC = {Pad = true, Poste = true, Brazo = true, Anillo = true},
	TIER = {Color3.fromRGB(200, 200, 215), Color3.fromRGB(110, 236, 120), Color3.fromRGB(196, 120, 255), Color3.fromRGB(255, 200, 70)},
	ps = {}, cfs = {}, -- (tablas que se reutilizan cada fotograma)
}
local anims = {} -- [tropa] = estado de su animación (Tw.anim)

-- 1 -> 1 pasando por encima (o: cuánto se pasa)
function Tw.backOut(k, o)
	return 1 + (o + 1) * (k - 1) ^ 3 + o * (k - 1) ^ 2
end

-- Pieza del equipo. Por el nombre: Rune* brilla del color de la categoría, Flame* arde y Glow* alumbra
-- (dark: sin luz, que no se pase de luces).
function Tw.part(d, parent, tint, cf, dark)
	local p = Instance.new("Part")
	p.Name = d.name
	p.Anchored, p.CanCollide, p.CanTouch = true, false, false
	p.CastShadow = d.mat ~= Enum.Material.Neon and d.size.Magnitude > 0.7
	p.Size, p.Material, p.Transparency = d.size, d.mat, d.tr
	p.Color = (tint and d.name:sub(1, 4) == "Rune") and tint or d.color
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if d.shape == "c" then
		p.Shape = Enum.PartType.Cylinder
	elseif d.shape == "o" then
		p.Shape = Enum.PartType.Ball
	end
	if d.name:sub(1, 5) == "Flame" then
		new("ParticleEmitter", {
			Texture = "rbxasset://textures/particles/fire_main.dds", Color = ColorSequence.new(p.Color, Color3.new(1, 1, 1)), LightEmission = 1,
			Size = NumberSequence.new({NumberSequenceKeypoint.new(0, d.size.X * 1.6), NumberSequenceKeypoint.new(1, 0)}),
			Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)}),
			Lifetime = NumberRange.new(0.35, 0.55), Rate = 9, Speed = NumberRange.new(1.2, 2), SpreadAngle = Vector2.new(12, 12),
			Acceleration = Vector3.new(0, 3, 0), LockedToPart = false,
		}, p)
	end
	if not dark and (d.name:sub(1, 5) == "Flame" or d.name:sub(1, 4) == "Glow") then
		new("PointLight", {Color = p.Color, Range = 6, Brightness = 1.1, Shadows = false}, p)
	end
	p.CFrame = cf or CFrame.identity
	p.Parent = parent
	return p
end

function Tw.anim(model)
	local a = anims[model]
	if a then
		return a
	end
	local base = model:GetPivot()
	local _, size = model:GetBoundingBox()
	local t = model:GetAttribute("Type") or ""
	local troop = TD.Troops[t]
	local def = Config.Scares[t]
	local cat = def and Config.Categories[def.cat]
	local kind = troop and troop.kind
	a = {
		base = base, look = base, goal = base, parts = {}, orbit = {}, h = math.min(size.Y * 0.6, 10), idle = troop and troop.idle,
		seed = math.random() * 10, type = t, level = 0, scale = 1, lift = 0, dirty = true, cat = cat and cat.color,
		grounded = kind ~= "trap", turns = kind ~= "trap" and def and not def.ceiling and def.facing, w = math.min(math.max(size.X, size.Z), 6),
		style = (def and def.ceiling and kind ~= "aoe") and "drop" or (kind == "aoe" or kind == "trap" or kind == "farm" or kind == "support") and "pulse"
			or Tw.LUNGE[t] and "lunge" or "recoil",
	}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not Tw.STATIC[d.Name] then
			a.parts[d] = {base:ToObjectSpace(d.CFrame), d.Size}
			if d:GetAttribute("Orbit") then
				a.orbit[d] = d:GetAttribute("Orbit")
				a.hasOrbit = true
			end
		end
	end
	anims[model] = a
	return a
end

-- Equipo y aura del nivel lv (añade el equipo de los niveles que falten)
function Tw.setLevel(model, a, lv, ringPart)
	-- (como mucho dos luces en el equipo)
	local function lit(d)
		if d.name:sub(1, 4) == "Glow" or d.name:sub(1, 5) == "Flame" then
			a.lights = (a.lights or 0) + 1
			return a.lights > 2
		end
		return true
	end
	for l = a.level + 1, lv do
		for _, d in Tw.Gear.parts(a.type) do
			if d.level == "L" .. l then
				a.parts[Tw.part(d, model, a.cat, a.look * d.offset, lit(d))] = {d.offset, d.size}
			end
		end
	end
	if ringPart then
		ringPart.Size = Vector3.new(Tw.RING[lv] or 5.4, 0.05, Tw.RING[lv] or 5.4)
	end
	a.level = lv
	a.scale = Tw.SCALE[lv] or 1
	Tw.aura(model, a, lv)
	Tw.wisps(model, a, lv)
	a.dirty = true
	a.shown = nil -- (que el equipo nuevo coja el tamaño de la tropa)
end

-- Fuegos fatuos: lv - 1, repartidos en círculo a media altura y girando alrededor de la tropa (Tw.frame: a.orbit).
-- Miran hacia donde van, con la llama hacia atrás. Se rehacen en cada nivel (cambian de número y de color).
function Tw.wisps(model, a, lv)
	for _, p in a.wisp or {} do
		a.parts[p], a.orbit[p] = nil, nil
		p:Destroy()
	end
	a.wisp = {}
	local n = lv - 1
	if n <= 0 then
		return
	end
	local r = a.w * 0.5 + 0.9
	local at = CFrame.new(r, a.grounded and math.max(2.5, a.h * 0.85) or 1.6, 0)
	for k = 0, n - 1 do
		local phase = k * math.pi * 2 / (1.7 * n) -- (Tw.frame gira cada uno phase * 1.7)
		for _, d in Tw.Gear.parts("Wisp") do
			local off = at * CFrame.new(d.offset.Position * Tw.WISP_SIZE) * d.offset.Rotation
			local p = Tw.part(d, model, Tw.WISP[lv], a.look * off, true)
			p.CanQuery, p.CastShadow = false, false
			a.parts[p] = {off, d.size * Tw.WISP_SIZE}
			a.orbit[p] = phase
			table.insert(a.wisp, p)
		end
	end
	a.hasOrbit = true
end

-- Aura del nivel: chispas del color del nivel que suben alrededor de la tropa (y en el 4, halo de luz dorada). Va en una
-- pieza invisible que se mueve con la tropa.
function Tw.aura(model, a, lv)
	local rate = Tw.AURA[lv] or 0
	if rate <= 0 or not a.grounded then
		return
	end
	local c = Tw.TIER[lv]
	if not a.auraPart then
		a.auraPart = new("Part", {
			Name = "Aura", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Transparency = 1,
			Size = Vector3.new(a.w * 0.8, 0.2, a.w * 0.8), CFrame = a.look,
		}, model)
		a.aura = new("ParticleEmitter", {
			Texture = "rbxasset://textures/particles/sparkles_main.dds", LightEmission = 1, LightInfluence = 0,
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = Enum.NormalId.Top,
			Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.42), NumberSequenceKeypoint.new(1, 0)}),
			Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.6)}),
			Lifetime = NumberRange.new(1.1, 1.7), Speed = NumberRange.new(1.6, 2.8), SpreadAngle = Vector2.new(8, 8), Drag = 0.5,
			RotSpeed = NumberRange.new(-90, 90), LockedToPart = false,
		}, a.auraPart)
		a.parts[a.auraPart] = {CFrame.new(0, 0.2, 0), a.auraPart.Size}
	end
	a.aura.Rate = rate
	a.aura.Color = ColorSequence.new(c, c:Lerp(WHITE, 0.5))
	if lv >= TD.MAX_LEVEL and not a.halo then
		a.halo = new("PointLight", {Color = c, Range = 9, Brightness = 1.4, Shadows = false}, a.auraPart)
	end
end

-- Claro bajo la tropa: la hierba alta del terreno (Grass) se vuelve hierba baja (LeafyGrass) para que se vean el aro y
-- los pies. Solo en este cliente; al irse la tropa se devuelve lo que había (y se rehacen los claros vecinos).
Tw.cleared = {}
function Tw.clearGrass(a)
	local T = workspace.Terrain
	local p = a.base.Position
	local region = Region3.new(p - Vector3.new(4, 6, 4), p + Vector3.new(4, 2, 4)):ExpandToGrid(4)
	local ok, mats, occ = pcall(T.ReadVoxels, T, region, 4)
	if not ok then
		return
	end
	if not a.grass then
		a.grass = {region = region, mats = mats, occ = occ}
		Tw.cleared[a] = true
	end
	T:ReplaceMaterial(region, 4, Enum.Material.Grass, Enum.Material.LeafyGrass)
end
function Tw.restoreGrass(a)
	local g = a.grass
	if not g then
		return
	end
	a.grass = nil
	Tw.cleared[a] = nil
	workspace.Terrain:WriteVoxels(g.region, 4, g.mats, g.occ)
	for o in Tw.cleared do
		if (o.base.Position - a.base.Position).Magnitude < 16 then
			workspace.Terrain:ReplaceMaterial(o.grass.region, 4, Enum.Material.Grass, Enum.Material.LeafyGrass)
		end
	end
end

-- Viste una copia de la tropa con el equipo del nivel lv (retratos del panel)
function Tw.dress(model, t, lv)
	local def = Config.Scares[t]
	local cat = def and Config.Categories[def.cat] and Config.Categories[def.cat].color
	local top = model:GetPivot()
	for _, d in Tw.Gear.parts(t) do
		local l = tonumber(d.level:sub(2))
		if l and l <= lv then
			Tw.part(d, model, cat, top * d.offset, true)
		end
	end
end

-- Nube de partículas en un punto (polvo al colocar, chispas al mejorar, monedas al vender)
function Tw.puff(pos, n, props)
	local at = new("Attachment", {WorldPosition = pos}, workspace.Terrain)
	props.Rate = 0
	props.LightInfluence = props.LightInfluence or 0
	local e = new("ParticleEmitter", props, at)
	e:Emit(n)
	Debris:AddItem(at, 3)
end

function Tw.place(model, a)
	a.pop = {kind = "place", t0 = os.clock(), dur = 0.5 * Tw.slow()}
	local pos = a.base.Position
	if near(pos, 160) then
		Tw.puff(pos + Vector3.new(0, 0.5, 0), 16, {
			Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(150, 132, 118)), LightInfluence = 1,
			Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3)}),
			Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1)}),
			Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(7, 11), SpreadAngle = Vector2.new(85, 5),
			EmissionDirection = Enum.NormalId.Top, Drag = 6, Acceleration = Vector3.new(0, 2, 0),
		})
	end
end

function Tw.upgradeFx(model, a, lv, from)
	a.pop = {kind = "up", t0 = os.clock(), dur = 0.65 * Tw.slow(), from = from}
	local pos = a.base.Position
	if not near(pos, 160) then
		return
	end
	local c = Tw.TIER[lv] or UI.GOLD
	-- destello: la tropa entera se enciende y se apaga
	local hl = new("Highlight", {FillColor = Color3.fromRGB(255, 226, 120), FillTransparency = 0.1, OutlineColor = WHITE, OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.Occluded}, model)
	tween(hl, 0.7 * Tw.slow(), {FillTransparency = 1, OutlineTransparency = 1})
	Debris:AddItem(hl, 0.75 * Tw.slow())
	-- columna de luz que se estrecha
	local col = fxPart({Shape = Enum.PartType.Cylinder, Color = c, Transparency = 0.25, Size = Vector3.new(16, 4.2, 4.2), CFrame = CFrame.new(pos + Vector3.new(0, 8, 0)) * CFrame.Angles(0, 0, math.pi / 2)})
	tween(col, 0.6 * Tw.slow(), {Size = Vector3.new(18, 0.2, 0.2), Transparency = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(col, 0.65 * Tw.slow())
	ring(pos, 6, c, 0.55)
	Tw.puff(pos + Vector3.new(0, 2, 0), 34, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(c, WHITE), LightEmission = 1,
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0)}),
		Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(9, 16), SpreadAngle = Vector2.new(180, 180), Drag = 4,
		Acceleration = Vector3.new(0, 6, 0),
	})
end

function Tw.sell(model, a)
	a.pop = {kind = "sell", t0 = os.clock(), dur = 0.45 * Tw.slow()}
	if model == selected then
		selectTower(nil)
	end
	local pos = a.base.Position
	if not near(pos, 160) then
		return
	end
	task.delay(0.4 * Tw.slow(), function()
		Tw.puff(pos + Vector3.new(0, 1.5, 0), 14, {
			Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(210, 205, 220)), LightInfluence = 1,
			Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 3.2)}),
			Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)}),
			Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(4, 8), SpreadAngle = Vector2.new(180, 180), Drag = 5,
		})
		Tw.coins(pos + Vector3.new(0, 1.5, 0), 9)
		sound3D("Coin", pos, 0.6)
	end)
end

-- Monedas que saltan y caen (al vender)
function Tw.coins(pos, n)
	local list = {}
	for _ = 1, n do
		local ang = math.random() * math.pi * 2
		local p = new("Part", {
			Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.14, 0.8, 0.8), Color = Color3.fromRGB(255, 202, 54), Material = Enum.Material.Metal,
			Reflectance = 0.3, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, CFrame = CFrame.new(pos),
		}, workspace)
		table.insert(list, {p = p, v = Vector3.new(math.cos(ang) * (3 + math.random() * 4), 15 + math.random() * 6, math.sin(ang) * (3 + math.random() * 4)), spin = math.random() * 24 - 12})
	end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		local k = os.clock() - t0
		for _, c in list do
			c.v += Vector3.new(0, -62 * dt, 0)
			c.p.CFrame = CFrame.new(c.p.Position + c.v * dt) * CFrame.Angles(0, k * c.spin, math.pi / 2 + k * c.spin)
			c.p.Transparency = math.clamp((k - 0.55) / 0.25, 0, 1)
		end
		if k > 0.8 then
			conn:Disconnect()
			for _, c in list do
				c.p:Destroy()
			end
		end
	end)
end

-- Coloca las piezas de la tropa (giro, ataque, reposo, saltos de colocar/mejorar/vender)
function Tw.frame(model, a, now, dt)
	local k = a.t0 and (now - a.t0) / 0.32 or 2
	if a.t0 then
		a.look = k >= 1.5 and a.goal or a.look:Lerp(a.goal, math.min(1, dt * 16))
	end
	local hit = k < 1 and math.sin(k * math.pi) or 0
	local s, spin = a.scale, 0
	local pop = a.pop
	if pop then
		local q = math.min(1, (now - pop.t0) / pop.dur)
		if pop.kind == "place" then
			s *= math.max(0.05, Tw.backOut(q, 2.6))
		elseif pop.kind == "up" then
			-- del tamaño de antes al nuevo, con un estirón por el camino
			s += (pop.from - s) * (1 - q) ^ 3 + s * 0.24 * math.sin(math.pi * math.min(1, q * 1.7)) * (1 - q)
		else
			s *= math.max(0.01, 1 - q * q * (2.7 * q - 1.7))
			spin = q * q * math.pi * 3
		end
		if q >= 1 and pop.kind ~= "sell" then
			a.pop = nil
		end
	end
	local cf = a.look * CFrame.new(0, a.lift, 0)
	if spin ~= 0 then
		cf *= CFrame.Angles(0, spin, 0)
	end
	if a.style == "lunge" then
		cf *= CFrame.new(0, 0, -hit * 0.9)
	elseif a.style == "drop" then
		cf *= CFrame.new(0, -hit * 1.6, 0)
	elseif a.style == "recoil" then
		cf *= CFrame.new(0, hit * 0.1, hit * 0.45) * CFrame.Angles(hit * 0.12, 0, 0)
	else
		s *= 1 + hit * 0.12
	end
	if a.idle == "float" then
		cf *= CFrame.new(0, 0.35 + 0.35 * math.sin(now * 2 + a.seed), 0)
	elseif a.idle == "sway" then
		cf *= CFrame.Angles(0, math.rad(6) * math.sin(now * 0.9 + a.seed), math.rad(2) * math.sin(now * 1.3 + a.seed))
	end
	local resize = math.abs(s - (a.shown or -1)) > 1e-3
	a.shown = s
	local ps, cfs = Tw.ps, Tw.cfs
	table.clear(ps)
	table.clear(cfs)
	for p, o in a.parts do
		local off = o[1]
		local at = CFrame.new(off.Position * s) * off.Rotation
		local phase = a.orbit[p]
		if phase then
			at = CFrame.Angles(0, now * 1.4 + phase * 1.7, 0) * at * CFrame.new(0, 0.25 * math.sin(now * 6 + phase), 0)
		end
		if resize then
			p.Size = o[2] * s
		end
		table.insert(ps, p)
		table.insert(cfs, cf * at)
	end
	workspace:BulkMoveTo(ps, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	if a.t0 and k >= 1.5 then
		a.t0 = nil
	end
end

---------- Ataques: cada tropa con lo suyo (proyectiles modelados en Blender: TowerGear "Proj_*") ----------
-- Lo que se lanza vuela recto o en parábola, girando o mirando hacia donde va, con su estela; al llegar revienta en el
-- objetivo (chispas, onda, humo) y entonces sale el número de miedo. Los de área sueltan algo alrededor (notas, cuervos).
Tw.projCache = {}
-- (prueba: el atributo TDFxSlow del workspace ralentiza las animaciones para poder verlas en capturas)
function Tw.slow()
	return workspace:GetAttribute("TDFxSlow") or 1
end

-- Copia de un proyectil (de una plantilla hecha con sus piezas; una sola luz)
function Tw.projectile(name)
	local tpl = Tw.projCache[name]
	if not tpl then
		tpl = Instance.new("Model")
		tpl.Name = name
		local biggest, bs, lit = nil, 0, false
		for _, d in Tw.Gear.parts("Proj_" .. name) do
			local p = Tw.part(d, tpl, nil, d.offset)
			p.CanQuery, p.CastShadow = false, false
			local light = p:FindFirstChildOfClass("PointLight")
			if light and lit then
				light:Destroy()
			elseif light then
				lit = true
				light.Range, light.Brightness = 6, 0.7
			end
			if d.size.Magnitude > bs then
				biggest, bs = p, d.size.Magnitude
			end
		end
		tpl.PrimaryPart = biggest
		tpl.WorldPivot = CFrame.identity
		Tw.projCache[name] = tpl
	end
	return tpl:Clone()
end

-- Lanza un proyectil de from a to. o: time, arc (altura de la parábola), spin (vueltas por segundo, de frente), face (mira
-- hacia donde va), upright (de pie, solo se mece: el globo), trail (color de la estela), size, onLand
function Tw.shoot(name, from, to, o)
	local m = Tw.projectile(name)
	if o.size and o.size ~= 1 then
		m:ScaleTo(o.size)
	end
	m:PivotTo(CFrame.new(from))
	m.Parent = workspace
	local p = m.PrimaryPart
	if o.trail and p then
		local a0 = new("Attachment", {Position = Vector3.new(0, 0.3, 0)}, p)
		local a1 = new("Attachment", {Position = Vector3.new(0, -0.3, 0)}, p)
		new("Trail", {
			Attachment0 = a0, Attachment1 = a1, Color = ColorSequence.new(o.trail, o.trail:Lerp(WHITE, 0.5)), LightEmission = 1, Lifetime = 0.22,
			Transparency = NumberSequence.new(0.25, 1), WidthScale = NumberSequence.new(1, 0.2), FaceCamera = true,
		}, p)
	end
	local time = (o.time or 0.4) * Tw.slow()
	local arc = o.arc or 0
	local flatDir = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local yaw = flatDir.Magnitude > 0.05 and CFrame.lookAt(Vector3.zero, flatDir) or CFrame.identity
	local t0, last = os.clock(), from
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local el = os.clock() - t0
		local k = math.min(1, el / time)
		local pos = from:Lerp(to, k) + Vector3.new(0, arc * 4 * k * (1 - k), 0)
		local cf
		if o.face then
			local dir = pos - last
			cf = dir.Magnitude > 1e-3 and CFrame.lookAt(pos, pos + dir) or CFrame.new(pos) * yaw
		elseif o.upright then
			cf = CFrame.new(pos) * yaw * CFrame.Angles(0, 0, math.sin(el * 9) * 0.25)
		else
			cf = CFrame.new(pos) * yaw * CFrame.Angles(-el / Tw.slow() * (o.spin or 0) * math.pi * 2, 0, 0)
		end
		last = pos
		m:PivotTo(cf)
		if k >= 1 then
			conn:Disconnect()
			m:Destroy()
			if o.onLand then
				o.onLand()
			end
		end
	end)
end

-- Chispas al dar
function Tw.impact(pos, color, n, size)
	Tw.puff(pos, n or 10, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(color, WHITE), LightEmission = 1,
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, size or 0.7), NumberSequenceKeypoint.new(1, 0)}),
		Lifetime = NumberRange.new(0.25, 0.45), Speed = NumberRange.new(8, 15), SpreadAngle = Vector2.new(180, 180), Drag = 6,
	})
end

-- Destello al disparar (la mano, la boca, el cañón)
function Tw.flash(pos, color, size)
	burst(pos, color, size or 1.4)
	local l = new("PointLight", {Color = color, Range = 9, Brightness = 3, Shadows = false}, at(pos))
	Debris:AddItem(l, 0.12)
end

-- Explosión de las de área: onda en el suelo, bola, chispas y humo
function Tw.boom(pos, r, color, smoke)
	ring(pos, r, color, 0.45)
	burst(pos + Vector3.new(0, 1, 0), color, r * 0.75)
	Tw.impact(pos + Vector3.new(0, 1, 0), color, 14, 0.9)
	Tw.puff(pos + Vector3.new(0, 0.6, 0), 7, {
		Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(smoke or Color3.fromRGB(60, 52, 64)), LightInfluence = 1,
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 3.2)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1)}),
		Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(3, 6), SpreadAngle = Vector2.new(180, 180), Drag = 3,
	})
end

-- Llamas que se quedan un momento en el suelo (fuego del Jinete, el Demonio, la Bruja)
function Tw.fire(pos, r, color)
	Tw.puff(pos + Vector3.new(0, 0.4, 0), 18, {
		Texture = "rbxasset://textures/particles/fire_main.dds", Color = ColorSequence.new(color, Color3.fromRGB(255, 230, 120)), LightEmission = 1,
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0.2)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1)}),
		Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(1, r * 0.9), SpreadAngle = Vector2.new(80, 80),
		EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, 7, 0), Drag = 2,
	})
end

-- Un modelo que aparece en el objetivo, crece y se desvanece (el tajo, la mano que agarra)
function Tw.pop(name, cf, time, from, to)
	local m = Tw.projectile(name)
	m:PivotTo(cf)
	m.Parent = workspace
	time *= Tw.slow()
	local base = {}
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			base[p] = {cf:ToObjectSpace(p.CFrame), p.Size, p.Transparency}
		end
	end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = math.min(1, (os.clock() - t0) / time)
		local s = from + (to - from) * (1 - (1 - k) ^ 2)
		for p, b in base do
			p.Size = b[2] * s
			p.CFrame = cf * CFrame.new(b[1].Position * s) * b[1].Rotation
			p.Transparency = b[3] + (1 - b[3]) * math.max(0, (k - 0.45) / 0.55)
		end
		if k >= 1 then
			conn:Disconnect()
			m:Destroy()
		end
	end)
	return m
end

-- Cosas que salen en círculo desde la tropa hasta su alcance (las notas del gramófono, los cuervos)
function Tw.radiate(name, from, r, n, time, rise)
	for k = 1, n do
		local ang = (k / n + math.random() * 0.08) * math.pi * 2
		local to = from + Vector3.new(math.cos(ang) * r, rise or 0, math.sin(ang) * r)
		Tw.shoot(name, from, to, {time = time, arc = 1.5, face = true})
	end
end

local FX = {}
Tw.FX = FX
-- c: model, a, pos (pie de la tropa), top (de donde sale), target, hitAt, color, s (estadísticas), chain, hit() (número)
function FX.Calabaza(c)
	Tw.shoot("Pumpkin", c.top, c.hitAt, {time = 0.55, arc = 6, spin = 1.6, trail = c.color, onLand = function()
		Tw.boom(c.target, c.s.splash or 5, c.color)
		sound3D("Boom", c.target, 0.35)
		c.hit()
	end})
end
function FX.Jinete(c)
	Tw.flash(c.top, c.color, 2)
	Tw.shoot("Head", c.top, c.hitAt, {time = 0.6, arc = 8, spin = 1.2, trail = c.color, onLand = function()
		Tw.boom(c.target, c.s.splash or 9, c.color)
		Tw.fire(c.target, c.s.splash or 9, c.color)
		sound3D("Boom", c.target, 0.55)
		c.hit()
	end})
end
function FX.Bruja(c)
	Tw.shoot("Potion", c.top, c.hitAt, {time = 0.5, arc = 5, spin = 2.4, trail = c.color, onLand = function()
		Tw.boom(c.target, c.s.splash or 7, c.color, Color3.fromRGB(70, 140, 60))
		Tw.fire(c.target, (c.s.splash or 7) * 0.7, Color3.fromRGB(120, 255, 90))
		sound3D("Poof", c.target, 0.5)
		c.hit()
	end})
end
function FX.Esqueleto(c)
	Tw.shoot("Skull", c.top, c.hitAt, {time = 0.5, arc = 5, spin = 1.5, trail = c.color, onLand = function()
		Tw.boom(c.target, c.s.splash or 5, c.color)
		Tw.fire(c.target, c.s.splash or 5, c.color)
		sound3D("Thud", c.target, 0.5)
		c.hit()
	end})
end
function FX.Demonio(c)
	Tw.flash(c.top, c.color, 2.2)
	Tw.shoot("Hellfire", c.top, c.hitAt, {time = 0.45, arc = 3, spin = 0.8, trail = c.color, onLand = function()
		Tw.boom(c.target, c.s.splash or 9, c.color, Color3.fromRGB(50, 20, 16))
		Tw.fire(c.target, c.s.splash or 9, c.color)
		sound3D("Boom", c.target, 0.55)
		c.hit()
	end})
end
function FX.Fantasma(c)
	Tw.shoot("Ecto", c.top, c.hitAt, {time = 0.18, face = true, trail = Color3.fromRGB(120, 255, 230), onLand = function()
		Tw.impact(c.hitAt, Color3.fromRGB(140, 255, 235), 8)
		burst(c.hitAt, Color3.fromRGB(140, 255, 235), 2)
		c.hit()
	end})
end
function FX.Muneca(c)
	Tw.flash(c.top, Color3.fromRGB(255, 80, 110), 1.6)
	Tw.shoot("Needle", c.top, c.hitAt, {time = 0.22, face = true, trail = Color3.fromRGB(255, 70, 110), onLand = function()
		Tw.impact(c.hitAt, Color3.fromRGB(255, 70, 110), 12)
		burst(c.hitAt, Color3.fromRGB(255, 70, 110), 2.5)
		c.hit()
	end})
end
function FX.Cuervo(c)
	for k = 0, 2 do
		task.delay(k * 0.06, function()
			local off = Vector3.new((k - 1) * 0.5, 0, 0)
			Tw.shoot("Feather", c.top + off, c.hitAt + off * 0.3, {time = 0.24, face = true, trail = Color3.fromRGB(150, 110, 255), onLand = k == 1 and function()
				Tw.impact(c.hitAt, Color3.fromRGB(170, 120, 255), 10)
				c.hit()
			end or nil})
		end)
	end
end
function FX.Arana(c)
	Tw.shoot("Web", c.top, c.hitAt, {time = 0.3, arc = 1.5, spin = 1, onLand = function()
		-- la telaraña se queda pegada en el suelo lo que dura el aturdimiento
		local web = Tw.pop("Web", CFrame.new(c.target + Vector3.new(0, 0.3, 0)) * CFrame.Angles(math.pi / 2, 0, 0), 1, 1.6, 2.6)
		Tw.impact(c.hitAt, WHITE, 8)
		c.hit()
		return web
	end})
end
function FX.Ataud(c)
	Tw.shoot("Bone", c.top, c.hitAt, {time = 0.5, arc = 5, spin = 3, onLand = function()
		Tw.boom(c.target, c.s.splash or 7, Color3.fromRGB(236, 228, 204), Color3.fromRGB(150, 140, 120))
		sound3D("WoodBreak", c.target, 0.4)
		c.hit()
	end})
end
function FX.Payaso(c)
	Tw.shoot("Balloon", c.top, c.hitAt + Vector3.new(0, 1.5, 0), {time = 0.6, arc = 3, upright = true, onLand = function()
		-- ¡pum!: confeti de colores y onda
		ring(c.target, c.s.splash or 6, Color3.fromRGB(255, 90, 120), 0.45)
		for _, col in {Color3.fromRGB(255, 70, 90), Color3.fromRGB(255, 210, 60), Color3.fromRGB(80, 200, 255), Color3.fromRGB(120, 255, 120)} do
			Tw.puff(c.hitAt + Vector3.new(0, 1.5, 0), 6, {
				Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(col), LightEmission = 0.6,
				Size = NumberSequence.new(0.5, 0.2), Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(10, 16),
				SpreadAngle = Vector2.new(180, 180), Drag = 4, Acceleration = Vector3.new(0, -12, 0),
			})
		end
		sound3D("Poof", c.target, 0.6)
		c.hit()
	end})
end
function FX.Poltergeist(c)
	-- el libro va de un cazafantasmas a otro
	local stops = {c.hitAt}
	for _, p in c.chain or {} do
		table.insert(stops, p + Vector3.new(0, 1, 0))
	end
	local function hop(i, from)
		local to = stops[i]
		Tw.shoot("Book", from, to, {time = i == 1 and 0.28 or 0.16, arc = i == 1 and 3 or 1.2, spin = 2.5, trail = c.color, onLand = function()
			Tw.impact(to, c.color, 9)
			burst(to, c.color, 2)
			if i == 1 then
				c.hit()
			end
			if stops[i + 1] then
				hop(i + 1, to)
			end
		end})
	end
	hop(1, c.top)
end
function FX.Gramofono(c)
	Tw.radiate("Note", c.top, c.s.range, 6, 0.65, 1)
	ring(c.pos, c.s.range, Color3.fromRGB(255, 180, 255), 0.6)
end
function FX.Parca(c)
	local dir = Vector3.new(c.target.X - c.pos.X, 0, c.target.Z - c.pos.Z)
	local cf = CFrame.lookAt(c.hitAt + Vector3.new(0, 1, 0), c.hitAt + Vector3.new(0, 1, 0) + (dir.Magnitude > 0.1 and dir or Vector3.new(0, 0, -1))) * CFrame.Angles(0, 0, -0.5)
	Tw.pop("Slash", cf, 0.3, 0.7, 1.35)
	Tw.impact(c.hitAt, Color3.fromRGB(200, 240, 255), 12)
	if c.dmg == -1 then
		-- golpe mortal: el alma sale volando
		burst(c.hitAt, Color3.fromRGB(170, 110, 255), 6)
		Tw.puff(c.hitAt, 20, {
			Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(190, 140, 255)), LightEmission = 1,
			Size = NumberSequence.new(1.6, 0.2), Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(6, 10), EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(25, 25),
		})
	end
	c.hit()
end
function FX.Zombie(c)
	local dir = Vector3.new(c.target.X - c.pos.X, 0, c.target.Z - c.pos.Z)
	local cf = CFrame.lookAt(c.hitAt + Vector3.new(0, 0.6, 0), c.hitAt + Vector3.new(0, 0.6, 0) - (dir.Magnitude > 0.1 and dir or Vector3.new(0, 0, -1)))
	local jaws = Tw.projectile("Jaws")
	jaws:PivotTo(cf)
	jaws.Parent = workspace
	local parts = {}
	for _, p in jaws:GetChildren() do
		if p:IsA("BasePart") then
			parts[p] = {cf:ToObjectSpace(p.CFrame), p.Name:sub(1, 2) == "Up" and 1 or -1}
		end
	end
	local t0, time = os.clock(), 0.35 * Tw.slow()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = math.min(1, (os.clock() - t0) / time)
		-- se abren y se cierran de golpe (¡ñam!)
		local open = k < 0.45 and k / 0.45 * 0.7 or math.max(0, 0.7 - (k - 0.45) / 0.15 * 0.7)
		for p, b in parts do
			p.CFrame = cf * CFrame.new(0, b[2] * open, 0) * b[1]
			p.Transparency = math.max(0, (k - 0.7) / 0.3)
		end
		if k >= 1 then
			conn:Disconnect()
			jaws:Destroy()
		end
	end)
	task.delay(0.16 * Tw.slow(), function()
		Tw.impact(c.hitAt, Color3.fromRGB(150, 230, 90), 12)
		sound3D("Snap", c.target, 0.6)
		c.hit()
	end)
end
function FX.Armario(c)
	local from = c.pos + Vector3.new(0, c.a.h * 0.8 * c.a.scale + c.a.lift, 0)
	local beam = Tw.beam(from, c.hitAt, Color3.fromRGB(60, 20, 90), 0.5, 0.28)
	Tw.shoot("Hand", from, c.hitAt, {time = 0.2, face = true, onLand = function()
		local dir = c.hitAt - from
		Tw.pop("Hand", CFrame.lookAt(c.hitAt, c.hitAt + dir) * CFrame.Angles(math.rad(-30), 0, 0), 0.3, 1, 1.5)
		Tw.impact(c.hitAt, Color3.fromRGB(190, 120, 255), 10)
		c.hit()
	end})
	return beam
end
function FX.Espantapajaros(c)
	Tw.radiate("Crow", c.top, c.s.range * 0.9, 5, 0.55, 1.5)
	ring(c.pos, c.s.range, Color3.fromRGB(170, 200, 255), 0.55)
end
function FX.Momia(c)
	-- la venda sale disparada y lo envuelve entero (Tw.wrap): se queda en él mientras está aturdido
	Tw.beam(c.top, c.hitAt, Tw.WRAPS.Momia.colors[1], 0.55, 0.4, 1.5)
	task.delay(0.1 * Tw.slow(), function()
		Tw.wrap(c.target, Tw.WRAPS.Momia)
		Tw.impact(c.hitAt, Color3.fromRGB(240, 230, 200), 8)
		c.hit()
	end)
end
function FX.HombreCalabaza(c)
	Tw.beam(c.top, c.hitAt, Tw.WRAPS.HombreCalabaza.colors[1], 0.45, 0.3, 2.5)
	task.delay(0.1 * Tw.slow(), function()
		Tw.wrap(c.target, Tw.WRAPS.HombreCalabaza)
		Tw.puff(c.hitAt, 10, {
			Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(Color3.fromRGB(120, 220, 70)), LightEmission = 0.4,
			Size = NumberSequence.new(0.6, 0.1), Lifetime = NumberRange.new(0.4, 0.6), Speed = NumberRange.new(6, 10), SpreadAngle = Vector2.new(180, 180),
			Drag = 4, Acceleration = Vector3.new(0, -10, 0),
		})
		c.hit()
	end)
end

-- Lo que envuelve al cazafantasmas (vendas de la Momia, lianas del Hombre Calabaza): bandas que se enrollan de los pies al
-- cuello y se ciñen, van con él mientras está aturdido (💫 en su Status) y luego se desenrollan y caen; si vuelve a
-- recibir, se ciñen otra vez. n: bandas; h: alto de cada una (1 = tocan justo); tails: tiras sueltas que cuelgan.
Tw.WRAPS = {
	Momia = {n = 7, h = 1.3, tilt = 0.2, tails = 2, mat = Enum.Material.Fabric, colors = {Color3.fromRGB(236, 226, 194), Color3.fromRGB(206, 192, 152)}},
	HombreCalabaza = {n = 5, h = 0.3, tilt = 0.55, tails = 0, mat = Enum.Material.SmoothPlastic, colors = {Color3.fromRGB(104, 196, 58), Color3.fromRGB(64, 142, 44)}},
}
Tw.wraps = {} -- [enemigo] = lo que lo envuelve

-- El cazafantasmas que está en pos (el más cercano, a menos de 5 studs)
function Tw.enemyAt(pos)
	local best, bd = nil, 5
	for _, m in CollectionService:GetTagged("TDEnemy") do
		local r = m:FindFirstChild("HumanoidRootPart")
		if r then
			local d = Vector2.new(r.Position.X - pos.X, r.Position.Z - pos.Z).Magnitude
			if d < bd then
				best, bd = m, d
			end
		end
	end
	return best
end

function Tw.wrap(pos, o)
	local e = Tw.enemyAt(pos)
	local root = e and e:FindFirstChild("HumanoidRootPart")
	local head = e and e:FindFirstChild("Head")
	if not (root and head and near(root.Position, 170)) then
		return
	end
	local w = Tw.wraps[e]
	if w then
		-- ya va envuelto: se ciñe otra vez
		w.t0, w.done = os.clock(), nil
		return
	end
	-- medidas del cuerpo: de los pies al cuello, y su ancho
	local hum = e:FindFirstChildOfClass("Humanoid")
	local feet = root.Position.Y - root.Size.Y / 2 - (hum and hum.HipHeight or 2)
	local neck = head.Position.Y - head.Size.Y * 0.45
	local span = math.max(1, neck - feet - 0.15)
	local d = root.Size.X * 1.08
	w = {e = e, root = root, t0 = os.clock(), bands = {}, tails = {}}
	Tw.wraps[e] = w
	for i = 1, o.n do
		local y = 0.15 + span * (i - 0.5) / o.n
		local k = y / span -- (las piernas, más estrechas)
		local p = new("Part", {
			Name = "Venda", Shape = Enum.PartType.Cylinder, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
			Material = o.mat, Color = o.colors[i % 2 + 1], Transparency = 1, Size = Vector3.one * 0.1,
		}, workspace)
		table.insert(w.bands, {p = p, y = y - (root.Position.Y - feet), d = d * (k < 0.45 and 0.88 or 1), h = span / o.n * o.h, delay = (i - 1) * 0.04, tilt = (i % 2 == 0 and 1 or -1) * o.tilt * (0.7 + 0.6 * math.random()), spin = math.random() * 6})
	end
	for i = 1, o.tails do
		local p = new("Part", {
			Name = "Tira", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = o.mat,
			Color = o.colors[1], Transparency = 1, Size = Vector3.new(0.4, span * 0.32, 0.06),
		}, workspace)
		table.insert(w.tails, {p = p, y = -span * (0.05 + 0.3 * i) + span * 0.5, ang = i * 2.4, seed = math.random() * 6})
	end
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local el = (now - w.t0) / Tw.slow()
		local stunned = (e:GetAttribute("Status") or ""):find("💫") ~= nil
		if not w.done and el > 0.35 and not stunned then
			w.done = now -- se suelta
		end
		local off = w.done and (now - w.done) / Tw.slow() / 0.45 or 0 -- 0..1 desenrollándose
		if not e.Parent or not root.Parent or off >= 1 or el > 8 then
			conn:Disconnect()
			Tw.wraps[e] = nil
			for _, b in w.bands do
				b.p:Destroy()
			end
			for _, t in w.tails do
				t.p:Destroy()
			end
			return
		end
		local rcf = root.CFrame
		local yaw = CFrame.new(rcf.Position) * CFrame.Angles(0, select(2, rcf:ToEulerAnglesYXZ()), 0)
		for _, b in w.bands do
			-- se enrolla (llega ancha y girando, y se ciñe con un rebote); al soltarse se abre, cae y se desvanece
			local q = math.clamp((el - b.delay) / 0.16, 0, 1)
			local tight = q < 1 and Tw.backOut(q, 1.4) or 1
			local dd = b.d * (1.9 - 0.9 * tight) * (1 + off * 0.7)
			b.p.Size = Vector3.new(b.h, dd, dd)
			b.p.Transparency = q <= 0 and 1 or math.max(0.02, off)
			local spin = b.spin + (1 - tight) * 5 + off * 3
			b.p.CFrame = yaw * CFrame.new(0, b.y - off * off * 2.5, 0) * CFrame.Angles(0, spin, 0) * CFrame.Angles(b.tilt * (1 + off), 0, math.pi / 2)
		end
		for _, t in w.tails do
			-- tiras sueltas que cuelgan y se mecen
			local sway = math.sin(now * 5 + t.seed) * 0.35
			t.p.Transparency = el < 0.25 and 1 or math.max(0.02, off)
			t.p.CFrame = yaw * CFrame.Angles(0, t.ang, 0) * CFrame.new(0, t.y - off * off * 2.5, -(w.bands[1].d * 0.5 + 0.05)) * CFrame.Angles(0.25 + sway, 0, sway * 0.4) * CFrame.new(0, -t.p.Size.Y * 0.4, 0)
		end
	end)
end
function FX.Vampiro(c)
	-- gotas de sangre que vuelan del cazafantasmas al vampiro
	local red = Color3.fromRGB(220, 20, 50)
	for k = 0, 5 do
		task.delay(k * 0.04, function()
			local p = fxPart({Shape = Enum.PartType.Ball, Color = red, Size = Vector3.one * 0.45})
			local from, to = c.hitAt, c.top
			local side = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 3
			local t0, time = os.clock(), 0.35 * Tw.slow()
			local conn
			conn = RunService.RenderStepped:Connect(function()
				local q = math.min(1, (os.clock() - t0) / time)
				p.CFrame = CFrame.new(from:Lerp(to, q) + side * math.sin(q * math.pi) + Vector3.new(0, 2 * math.sin(q * math.pi), 0))
				if q >= 1 then
					conn:Disconnect()
					p:Destroy()
				end
			end)
		end)
	end
	Tw.impact(c.hitAt, red, 10)
	burst(c.hitAt, Color3.fromRGB(200, 20, 40), 3)
	task.delay(0.4 * Tw.slow(), function()
		burst(c.top, red, 2.5)
	end)
	c.hit()
end
function FX.Frankenstein(c)
	Tw.flash(c.top, c.color, 2.2)
	zigzag(c.top, c.hitAt, c.color)
	zigzag(c.top, c.hitAt, WHITE)
	Tw.impact(c.hitAt, c.color, 12)
	local last = c.hitAt
	for _, p in c.chain or {} do
		local to = p + Vector3.new(0, 1, 0)
		zigzag(last, to, c.color)
		Tw.impact(to, c.color, 8)
		last = to
	end
	c.hit()
end
function FX.Dragon(c)
	Tw.flash(c.top, c.color, 2.5)
	breath(c.pos + Vector3.new(0, c.a.h * 0.9 * c.a.scale + c.a.lift, 0) + (c.target - c.pos).Unit * 2, c.hitAt, c.color)
	task.delay(0.3, function()
		Tw.boom(c.target, c.s.splash or 10, c.color, Color3.fromRGB(30, 70, 40))
		Tw.fire(c.target, c.s.splash or 10, c.color)
		c.hit()
	end)
end
function FX.Banshee(c)
	for k = 0, 2 do
		task.delay(k * 0.12, function()
			shockwave(c.pos, c.s.range * (1 - k * 0.2), c.color or Color3.fromRGB(200, 230, 255))
			ring(c.pos, c.s.range * (1 - k * 0.2), Color3.fromRGB(200, 230, 255), 0.6)
		end)
	end
end
function FX.HombreLobo(c)
	claw(c.hitAt, Color3.fromRGB(255, 70, 70))
	Tw.impact(c.hitAt, Color3.fromRGB(255, 90, 90), 12)
	burst(c.hitAt, Color3.fromRGB(255, 70, 70), 2.5)
	c.hit()
end
function FX.Velas(c)
	ring(c.pos, c.s.range, c.color, 0.5)
	Tw.fire(c.pos, c.s.range * 0.5, c.color)
	burst(c.top, c.color, 3)
end
function FX.Luz(c)
	local l = new("PointLight", {Color = Color3.fromRGB(255, 240, 180), Range = c.s.range + 4, Brightness = 6, Shadows = false}, at(c.top))
	for k = 1, 4 do
		task.delay(k * 0.05, function()
			l.Enabled = k % 2 == 0
		end)
	end
	Debris:AddItem(l, 0.3)
	ring(c.pos, c.s.range, Color3.fromRGB(255, 236, 150), 0.5)
end
function FX.Sombra(c)
	shockwave(c.pos, c.s.range * 0.8, Color3.fromRGB(70, 30, 110))
	ring(c.pos, c.s.range, Color3.fromRGB(130, 70, 200), 0.55)
	Tw.puff(c.pos + Vector3.new(0, 1, 0), 16, {
		Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(40, 16, 60)), LightInfluence = 0.3,
		Size = NumberSequence.new(1.5, 3.5), Transparency = NumberSequence.new(0.35, 1), Lifetime = NumberRange.new(0.5, 0.8),
		Speed = NumberRange.new(c.s.range * 0.8, c.s.range * 1.2), SpreadAngle = Vector2.new(90, 5), EmissionDirection = Enum.NormalId.Top, Drag = 4,
	})
end
function FX.Manos(c)
	ring(c.pos, 4, c.color, 0.4)
	Tw.puff(c.target + Vector3.new(0, 0.5, 0), 12, {
		Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(110, 86, 60)), LightInfluence = 1,
		Size = NumberSequence.new(1, 2.6), Transparency = NumberSequence.new(0.3, 1), Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(5, 9),
		SpreadAngle = Vector2.new(70, 70), EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -14, 0),
	})
	c.hit()
end
FX.Trampilla = FX.Manos
function FX.Murcielagos(c)
	batsTo(c.model, c.top, c.hitAt)
	burst(c.hitAt, c.color, 1.6)
	c.hit()
end

-- Rayo curvo que se desvanece (la venda o la liana al salir, la sombra del armario)
function Tw.beam(from, to, color, w0, w1, curve)
	local a0, a1 = at(from), at(to)
	local b = new("Beam", {
		Attachment0 = a0, Attachment1 = a1, Color = ColorSequence.new(color), LightEmission = 0.3, LightInfluence = 0.4, FaceCamera = true,
		Width0 = w0, Width1 = w1, Segments = 12, CurveSize0 = curve or 0, CurveSize1 = -(curve or 0), Transparency = NumberSequence.new(0.05),
	}, a0)
	task.delay(0.15 * Tw.slow(), function()
		for k = 1, 5 do
			task.delay(k * 0.03, function()
				b.Transparency = NumberSequence.new(k / 5)
			end)
		end
	end)
	Debris:AddItem(a0, 0.4 * Tw.slow())
	Debris:AddItem(a1, 0.4 * Tw.slow())
	return b
end

local function onHit(model, target, dmg, chain)
	local t = model and model.Parent and model:GetAttribute("Type")
	local troop = t and TD.Troops[t]
	if not troop or model:GetAttribute("Sold") then
		return
	end
	local a = Tw.anim(model)
	local pos = a.base.Position
	if not near(pos, 160) then
		return
	end
	a.goal = a.turns and CFrame.lookAt(pos, Vector3.new(target.X, pos.Y, target.Z)) or a.look
	a.t0 = os.clock()
	if os.clock() - (a.sound or 0) > 1.1 then
		a.sound = os.clock()
		sound3D(troop.sound, pos, 0.55)
	end
	local color = troop.color or Kit.color(t)
	-- de donde sale: a la altura de las manos/la cabeza, un poco hacia el objetivo
	local toward = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
	toward = toward.Magnitude > 0.1 and toward.Unit or Vector3.zero
	local c = {
		model = model, a = a, pos = pos, target = target, hitAt = target + Vector3.new(0, 1, 0), color = color, dmg = dmg, chain = chain,
		s = TD.stats(t, model:GetAttribute("Level") or 1), top = pos + Vector3.new(0, a.h * a.scale + a.lift, 0) + toward * 1.2,
	}
	local shown = false
	c.hit = function()
		if dmg and not shown and near(target, 170) then
			shown = true
			fearNumber(target, dmg, color)
		end
	end
	local f = FX[t]
	if f then
		f(c)
	elseif troop.kind == "aoe" then
		ring(pos, c.s.range, color, 0.5)
	else
		bolt(c.top, c.hitAt, color)
		burst(c.hitAt, color, 2.5)
		c.hit()
	end
end

local function badge(model)
	local padPart = model:WaitForChild("Pad", 5)
	if not (padPart and model.Parent) then
		return
	end
	local _, size = model:GetBoundingBox()
	local mine = model:GetAttribute("Owner") == player.UserId
	padPart.LocalTransparencyModifier = 1 -- (solo marca el sitio)
	-- aro bajo la tropa (como en TDS): cian y brillante en las tuyas, tenue en las de los demás
	local ringPart = new("Part", {
		Name = "Anillo", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Transparency = 1,
		Size = Vector3.new(5.4, 0.05, 5.4), CFrame = CFrame.new(padPart.Position + Vector3.new(0, 0.16, 0)),
	}, padPart)
	local ringGui = new("SurfaceGui", {Face = Enum.NormalId.Top, LightInfluence = 0, Brightness = 2, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 24, Adornee = ringPart}, ringPart)
	local ringDisc = corner(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = mine and Color3.fromRGB(30, 200, 255) or WHITE, BackgroundTransparency = mine and 0.9 or 0.96, BorderSizePixel = 0}, ringGui), UDim.new(0.5, 0))
	new("UIStroke", {Color = mine and Color3.fromRGB(30, 205, 255) or Color3.fromRGB(190, 200, 222), Thickness = mine and 7 or 4, Transparency = mine and 0 or 0.45}, ringDisc)
	-- equipo, aura y tamaño de su nivel (y si se acaba de poner, sale del suelo)
	local a = Tw.anim(model)
	Tw.setLevel(model, a, model:GetAttribute("Level") or 1, ringPart)
	if a.grounded then
		Tw.clearGrass(a)
	end
	if workspace:GetServerTimeNow() - (model:GetAttribute("PlacedAt") or 0) < 1.5 then
		Tw.place(model, a)
	end
	model:GetAttributeChangedSignal("Level"):Connect(function()
		local lv = model:GetAttribute("Level") or 1
		if lv > a.level then
			local from = a.shown or a.scale
			Tw.setLevel(model, a, lv, ringPart)
			Tw.upgradeFx(model, a, lv, from)
		end
	end)
	model:GetAttributeChangedSignal("Sold"):Connect(function()
		Tw.sell(model, a)
	end)
	-- estado sobre la cabeza, solo cuando hay algo que contar: aturdida por un rastreador (💫, en rojo), con un Espejo
	-- cerca (✨) o el frenesí del lobo (🔥)
	local bb = new("BillboardGui", {
		Name = "Nivel", Size = UDim2.fromOffset(48, 22), StudsOffsetWorldSpace = Vector3.new(0, math.min(size.Y, 14) * 1.12 + 1.6, 0),
		MaxDistance = 140, LightInfluence = 0, Adornee = padPart, Enabled = false,
	}, padPart)
	local pill = corner(label({Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.15, BackgroundColor3 = UI.DARK, TextSize = 14, TextColor3 = UI.GOLD, Text = ""}, bb), 11)
	local pillStroke = outline(pill, mine and UI.GOLD or Kit.LINE, 1.5, 0.15)
	local function update()
		local stunned = (model:GetAttribute("Disabled") or 0) > workspace:GetServerTimeNow()
		local text = stunned and "💫" or (model:GetAttribute("Buffed") and "✨" or "")
		if model:GetAttribute("Frenzy") then
			text ..= (text ~= "" and " " or "") .. "🔥" .. model:GetAttribute("Frenzy")
		end
		bb.Enabled = text ~= ""
		pill.Text = text
		pill.TextColor3 = stunned and UI.RED or UI.GOLD
		pillStroke.Color = stunned and UI.RED or (mine and UI.GOLD or Kit.LINE)
		bb.Size = UDim2.fromOffset(math.max(30, utf8.len(text) * 12 + 14), 22)
	end
	for _, attr in {"Buffed", "Frenzy"} do
		model:GetAttributeChangedSignal(attr):Connect(update)
	end
	model:GetAttributeChangedSignal("Disabled"):Connect(function()
		update()
		local left = (model:GetAttribute("Disabled") or 0) - workspace:GetServerTimeNow()
		if left > 0 then
			task.delay(left + 0.05, update)
		end
	end)
	update()
end
-- (los mapas se cargan cuando hace falta: se vigilan al aparecer)
local function watchTowers(m)
	if not TD.mapInfo(m.Name) then
		return
	end
	local f = m:WaitForChild("TD", 30)
	f = f and f:WaitForChild("Towers", 30)
	if not f then
		return
	end
	for _, x in f:GetChildren() do
		task.spawn(badge, x)
	end
	f.ChildAdded:Connect(function(x)
		task.spawn(badge, x)
	end)
end
for _, m in workspace:GetChildren() do
	task.spawn(watchTowers, m)
end
workspace.ChildAdded:Connect(watchTowers)

---------- Major Pumpkin: el comandante de la casa (como el "Commandant" de TDS) ----------
-- Abajo, sobre la barra de tropas: su retrato (modelado en Blender: TowerGear "MajorPumpkin") saluda, parpadea y mueve
-- la boca mientras el texto sale letra a letra en un bocadillo con su nombre. Habla al empezar, en la primera oleada,
-- cada 5, en la final, cuando llega un jefe, la primera vez que se cuela uno, con la casa a menos del 40%, la primera
-- vez que salen ocultos, voladores o con escudo, y al ganar o perder. Los mensajes van en cola.
Mj.LINES = {
	intro = {
		"Attention, recruits! Ghost hunters are marching on our haunted house. Place your scares along the path!",
		"Welcome to the front, recruit! Put your scares by the path and press READY when you're set.",
	},
	first = {"Here they come! Show them what real fear looks like!", "Steady... steady... SCARE THEM!"},
	milestone = {
		"Wave %d! They're getting braver. Upgrade your troops, recruits!",
		"Wave %d and the house still stands! Keep those scares coming!",
		"Wave %d! Spend that cash: a stronger troop beats two weak ones.",
	},
	final = {"This is it: the FINAL wave! Hold the line and the house is ours!"},
	boss = {"Brace yourselves! %s is coming. Focus every scare on that one!", "Boss incoming: %s! Bosses shrug off weak scares, upgrade NOW!"},
	leak = {"A hunter got inside the house! Plug that path, recruits!"},
	low = {"The house is crumbling! Not one more hunter gets through!"},
	hidden = {"Hidden hunters! Only troops that DETECT can see them. Upgrade your troops to unlock it, or use a Haunted Mirror."},
	fly = {"Flying hunters! Trapdoors and Grasping Hands can't reach them."},
	shield = {"Those hunters carry shields! Hit them hard to break the bubble first."},
	won = {"VICTORY! Those hunters won't stop running for a week. Splendid work, troops!"},
	lost = {"Retreat, retreat! We'll scare them silly next time, recruits..."},
}
Mj.queue, Mj.said = {}, {}
Mj.ORANGE = Color3.fromRGB(255, 150, 40)

Mj.root = new("CanvasGroup", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 60, 1, -96), Size = UDim2.fromOffset(600, 200), BackgroundTransparency = 1,
	GroupTransparency = 1, Visible = false, ZIndex = 35,
}, hud)
Mj.pop = new("UIScale", {}, Mj.root)
Mj.box = corner(new("Frame", {
	Position = UDim2.fromOffset(150, 108), Size = UDim2.new(1, -150, 0, 84), BackgroundColor3 = Color3.fromRGB(8, 6, 14), BackgroundTransparency = 0.25,
	BorderSizePixel = 0, ZIndex = 35,
}, Mj.root), 6)
new("UIStroke", {Color = WHITE, Thickness = 1.5, Transparency = 0.15}, Mj.box)
Mj.name = mt({
	Position = UDim2.fromOffset(164, 84), Size = UDim2.fromOffset(0, 32), AutomaticSize = AUTO_X, TextSize = 27, TextXAlignment = LEFT,
	TextColor3 = Mj.ORANGE, Text = "Major Pumpkin", TextStrokeTransparency = 1, ZIndex = 38,
}, Mj.root, Wt.BLACK)
new("UIStroke", {Color = Sty.INK, Thickness = 3, LineJoinMode = Enum.LineJoinMode.Round}, Mj.name)
Mj.text = mt({
	Position = UDim2.fromOffset(168, 120), Size = UDim2.new(1, -182, 0, 68), TextSize = 21, TextWrapped = true, TextXAlignment = LEFT,
	TextYAlignment = Enum.TextYAlignment.Top, Text = "", MaxVisibleGraphemes = 0, ZIndex = 37,
}, Mj.root, Wt.BOLD)
-- retrato: el modelo de Blender en un ViewportFrame que se sale por arriba del bocadillo
Mj.vp = new("ViewportFrame", {
	Position = UDim2.fromOffset(-14, 2), Size = UDim2.fromOffset(190, 190), BackgroundTransparency = 1, ZIndex = 39, -- (abajo acaba justo en el borde del bocadillo)
	Ambient = Color3.fromRGB(200, 190, 215), LightColor = Color3.fromRGB(255, 244, 228), LightDirection = Vector3.new(0.3, -0.6, 1),
}, Mj.root)
do
	local model = Instance.new("Model")
	for _, d in Tw.Gear.parts("MajorPumpkin") do
		Tw.part(d, model, nil, d.offset, true)
	end
	model.Parent = Mj.vp
	Mj.model = model
	Mj.parts = {}
	for _, p in model:GetChildren() do
		Mj.parts[p] = {p.CFrame, p.Size}
	end
	local cam = new("Camera", {FieldOfView = 34}, Mj.vp)
	Mj.vp.CurrentCamera = cam
	-- de frente y un poco de lado, encuadrando cabeza, gorra y hombros (el modelo mira a -Z)
	cam.CFrame = CFrame.lookAt(Vector3.new(-2.4, 3.8, -8.4), Vector3.new(0.2, 3.0, 0))
end

function Mj.say(key, ...)
	local list = Mj.LINES[key]
	if not list then
		return
	end
	local line = list[math.random(#list)]
	if select("#", ...) > 0 then
		line = line:format(...)
	end
	table.insert(Mj.queue, line)
	if not Mj.busy then
		task.spawn(Mj.run)
	end
end

-- Solo una vez por partida
function Mj.once(key, ...)
	if not Mj.said[key] then
		Mj.said[key] = true
		Mj.say(key, ...)
	end
end

-- (Mj.gen: cada vez que se le corta, la tanda que estaba hablando se calla y no toca nada más)
Mj.gen = 0
function Mj.run()
	Mj.busy = true
	local gen = Mj.gen
	local function alive()
		return Mj.gen == gen
	end
	local root = Mj.root
	root.Visible = true
	root.GroupTransparency = 1
	Mj.pop.Scale = 0.85
	tween(root, 0.25, {GroupTransparency = 0})
	tween(Mj.pop, 0.35, {Scale = 1}, Enum.EasingStyle.Back)
	UI.sound("Pickup", 0.6)
	while #Mj.queue > 0 and alive() do
		local line = table.remove(Mj.queue, 1)
		Mj.text.Text = line
		Mj.text.MaxVisibleGraphemes = 0
		Mj.talking = true
		local n = utf8.len(line) or #line
		for i = 1, n do
			if not (alive() and inMatch()) then
				break
			end
			Mj.text.MaxVisibleGraphemes = i
			if i % 3 == 0 then
				UI.sound("Blip", 0.18, 0.9 + math.random() * 0.25)
			end
			task.wait(0.026)
		end
		Mj.text.MaxVisibleGraphemes = -1
		Mj.talking = false
		local t0 = os.clock()
		while alive() and os.clock() - t0 < math.clamp(n * 0.045, 3, 5.5) do
			task.wait(0.1)
		end
	end
	if not alive() then
		return
	end
	tween(root, 0.3, {GroupTransparency = 1})
	task.wait(0.32)
	if not alive() then
		return
	end
	if #Mj.queue == 0 then
		root.Visible = false
		Mj.busy = false
	else
		task.spawn(Mj.run)
	end
end

-- Se calla y se va (al salir los resultados, o para decir algo más urgente)
function Mj.stop()
	Mj.gen += 1
	table.clear(Mj.queue)
	Mj.busy, Mj.talking = false, false
	Mj.root.Visible = false
end

-- Lo dice ya, cortando lo que estuviera diciendo (ganar o perder)
function Mj.interrupt(key, ...)
	Mj.stop()
	Mj.say(key, ...)
end

-- Un aviso de jefe por oleada (a veces llegan dos o tres seguidos)
function Mj.boss(name)
	local w = state:GetAttribute("Wave")
	if name and Mj.bossWave ~= w then
		Mj.bossWave = w
		Mj.say("boss", name)
	end
end

-- Al entrar en una partida: se olvida de lo ya dicho y da la bienvenida
function Mj.reset()
	Mj.stop()
	table.clear(Mj.said)
	Mj.lowHp, Mj.bossWave = false, nil
end

-- El retrato vive: sube y baja, parpadea, mueve la boca al hablar y el brazo del saludo
RunService.RenderStepped:Connect(function()
	if not Mj.root.Visible then
		return
	end
	local t = os.clock()
	local blink = (t % 3.4) < 0.12
	local talk = Mj.talking and (0.35 + 0.65 * math.abs(math.sin(t * 13))) or 0.35
	local bob = CFrame.new(0, 0.06 * math.sin(t * 2.2), 0) * CFrame.Angles(0, 0.06 * math.sin(t * 0.9), 0.02 * math.sin(t * 1.7))
	for p, base in Mj.parts do
		local cf, size = base[1], base[2]
		local n = p.Name
		if n:sub(1, 5) == "Mouth" then
			p.Size = Vector3.new(size.X, size.Y, size.Z * (0.5 + talk * 1.6))
			p.CFrame = bob * cf * CFrame.new(0, -0.1 * talk, 0)
		elseif n:sub(1, 7) == "GlowEye" then
			p.Size = Vector3.new(size.X, blink and size.Y * 0.15 or size.Y, size.Z)
			p.CFrame = bob * cf
		else
			p.CFrame = bob * cf
		end
	end
end)

---------- Pantalla de fin (como la "VICTOIRE !" de TDS) ----------
-- Arriba, tus tropas; una franja roja con "VICTORY!" (o morada con "DEFEAT"); a la izquierda tu nivel con la barra de
-- experiencia que se llena y las recompensas en fichas que entran una a una; a la derecha, los datos de la partida;
-- debajo, la vida que le queda a la casa con las estrellas, y "Back to lobby" / "Play Again" (cuenta los votos).
Rs.W = 740
results = new("CanvasGroup", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47), Size = UDim2.fromOffset(Rs.W, 640), BackgroundTransparency = 1,
	Visible = false, ZIndex = 40,
}, hud)
Rs.pop = new("UIScale", {}, results)
-- (una franja oscura detrás, para que se lea sobre cualquier mapa)
Rs.shade = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47), Size = UDim2.new(3, 0, 3, 0), BackgroundColor3 = BLACK,
	BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ZIndex = 39,
}, hud)
-- tus tropas, en fila sobre la franja
Rs.troops = new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -44), Size = UDim2.fromOffset(Rs.W + 120, 200), BackgroundTransparency = 1, ZIndex = 40}, results)
list({FillDirection = HORIZONTAL, HorizontalAlignment = CENTER, VerticalAlignment = BOTTOM, Padding = UDim.new(0, -46)}, Rs.troops)
-- la franja
Rs.banner = new("Frame", {Position = UDim2.fromOffset(-20, 118), Size = UDim2.new(1, 40, 0, 78), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 41}, results)
Rs.bannerGrad = new("UIGradient", {Rotation = 90}, Rs.banner)
-- bordes rotos de los extremos (cuadraditos girados, como los píxeles quemados de TDS)
Rs.chips = {}
for side = 0, 1 do
	for k = 1, 22 do
		local x = side == 0 and math.random(-46, 30) or math.random(Rs.W + 10, Rs.W + 86)
		local s = math.random(8, 22)
		local c = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x - 20, 118 + math.random(4, 74)), Size = UDim2.fromOffset(s, s), Rotation = math.random(0, 90),
			BorderSizePixel = 0, ZIndex = 42, BackgroundColor3 = WHITE,
		}, results)
		table.insert(Rs.chips, c)
	end
end
Rs.title = mt({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 157), Size = UDim2.fromOffset(Rs.W, 70), TextSize = 62, Text = "", TextStrokeTransparency = 1, ZIndex = 44}, results, Wt.BLACK)
Rs.titleGrad = new("UIGradient", {Rotation = 90}, Rs.title)
Rs.titleStroke = new("UIStroke", {Color = Color3.fromRGB(70, 8, 14), Thickness = 4, LineJoinMode = Enum.LineJoinMode.Round}, Rs.title)
Rs.titlePop = new("UIScale", {}, Rs.title)

-- caja oscura de borde fino (las dos del cuerpo y la tira de abajo)
function Rs.panel(props)
	props.BackgroundColor3 = Color3.fromRGB(6, 5, 10)
	props.BackgroundTransparency = 0.12
	props.BorderSizePixel = 0
	props.ZIndex = 41
	local f = corner(new("Frame", props, results), 5)
	new("UIStroke", {Color = Color3.fromRGB(235, 235, 245), Thickness = 1.5, Transparency = 0.35}, f)
	return f
end
Rs.left = Rs.panel({Position = UDim2.fromOffset(0, 210), Size = UDim2.fromOffset(420, 300)})
Rs.right = Rs.panel({Position = UDim2.fromOffset(432, 210), Size = UDim2.fromOffset(Rs.W - 432, 300)})
-- nivel y experiencia
mt({Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(60, 14), TextSize = 12, TextXAlignment = LEFT, Text = "Level", ZIndex = 42}, Rs.left, Wt.BOLD)
mt({Position = UDim2.new(1, -74, 0, 10), Size = UDim2.fromOffset(60, 14), TextSize = 12, TextXAlignment = RIGHT, Text = "Level", ZIndex = 42}, Rs.left, Wt.BOLD)
Rs.lv = mt({Position = UDim2.fromOffset(14, 24), Size = UDim2.fromOffset(80, 34), TextSize = 32, TextXAlignment = LEFT, TextColor3 = Color3.fromRGB(70, 170, 255), Text = "1", ZIndex = 42}, Rs.left, Wt.BLACK)
Rs.lvNext = mt({Position = UDim2.new(1, -94, 0, 24), Size = UDim2.fromOffset(80, 34), TextSize = 32, TextXAlignment = RIGHT, TextColor3 = Color3.fromRGB(70, 170, 255), Text = "2", ZIndex = 42}, Rs.left, Wt.BLACK)
Rs.xpGain = mt({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 22), Size = UDim2.fromOffset(220, 36), TextSize = 28, TextColor3 = UI.GOLD, Text = "", ZIndex = 42}, Rs.left, Wt.BLACK)
Rs.lvPop = new("UIScale", {}, Rs.lv)
Rs.barBack = corner(new("Frame", {Position = UDim2.fromOffset(14, 64), Size = UDim2.new(1, -28, 0, 16), BackgroundColor3 = Color3.fromRGB(26, 26, 32), BorderSizePixel = 0, ZIndex = 42}, Rs.left), 8)
Rs.barFill = corner(new("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 43}, Rs.barBack), 8)
new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(90, 190, 255), Color3.fromRGB(20, 100, 230))}, Rs.barFill)
for k = 1, 9 do
	new("Frame", {Position = UDim2.new(k / 10, -1, 0, 0), Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = Color3.fromRGB(6, 5, 10), BorderSizePixel = 0, ZIndex = 44}, Rs.barBack)
end
Rs.xpNow = mt({Position = UDim2.fromOffset(16, 64), Size = UDim2.fromOffset(80, 16), TextSize = 11, TextXAlignment = LEFT, Text = "", ZIndex = 45}, Rs.left, Wt.BOLD)
Rs.xpNeed = mt({Position = UDim2.new(1, -96, 0, 64), Size = UDim2.fromOffset(80, 16), TextSize = 11, TextXAlignment = RIGHT, Text = "", ZIndex = 45}, Rs.left, Wt.BOLD)
-- fichas de recompensa
Rs.tiles = new("Frame", {Position = UDim2.fromOffset(14, 96), Size = UDim2.new(1, -28, 1, -108), BackgroundColor3 = BLACK, BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 42}, Rs.left)
new("UIStroke", {Color = Color3.fromRGB(60, 60, 70), Thickness = 1}, Rs.tiles)
pad(Rs.tiles, 8)
new("UIGridLayout", {CellSize = UDim2.fromOffset(86, 86), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder}, Rs.tiles)

-- Ficha: icono de la hoja del HUD (o un emoji) y su texto debajo
function Rs.tile(order, icon, label, color)
	local f = corner(new("Frame", {BackgroundColor3 = Color3.fromRGB(22, 20, 30), BorderSizePixel = 0, LayoutOrder = order, ZIndex = 43}, Rs.tiles), 4)
	new("UIStroke", {Color = color or Color3.fromRGB(90, 90, 105), Thickness = 1.5, Transparency = 0.2}, f)
	new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 165))}, f)
	if Config.Scares[icon] then
		-- (la tropa MVP, en pequeño)
		UI.viewport(icon, f, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(70, 64), ZIndex = 44}, true)
	elseif Sty.RECT[icon] then
		hicon(icon, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(52, 52), ZIndex = 44}, f)
	else
		mt({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(56, 54), TextSize = 40, Text = icon, TextStrokeTransparency = 1, ZIndex = 44}, f)
	end
	mt({AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, -6, 0, 22), TextSize = 13, TextScaled = true, Text = label, ZIndex = 45}, f, Wt.XBOLD)
	local s = new("UIScale", {Scale = 0}, f)
	return s
end

-- datos de la partida
list({Padding = UDim.new(0, 2)}, Rs.right)
pad(Rs.right, 14, 14, 10, 10)
Rs.rows = {}
for i = 1, 7 do
	local row = new("Frame", {Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 42}, Rs.right)
	local cap = mt({Size = UDim2.new(0.55, 0, 1, 0), TextSize = 17, TextXAlignment = LEFT, Text = "", ZIndex = 42}, row, Wt.BOLD)
	local val = mt({Position = UDim2.fromScale(0.42, 0), Size = UDim2.new(0.58, 0, 1, 0), TextSize = 17, TextXAlignment = RIGHT, TextTruncate = Enum.TextTruncate.AtEnd, Text = "", ZIndex = 42}, row, Wt.BOLD)
	Rs.rows[i] = {cap = cap, val = val}
end

-- tira de abajo: la casa (estrellas) y la cuenta atrás
Rs.strip = Rs.panel({Position = UDim2.fromOffset(0, 520), Size = UDim2.fromOffset(Rs.W, 54)})
Rs.starRow = new("Frame", {Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(130, 54), BackgroundTransparency = 1, ZIndex = 42}, Rs.strip)
list({FillDirection = HORIZONTAL, VerticalAlignment = MIDDLE, Padding = UDim.new(0, 4)}, Rs.starRow)
Rs.stars = {}
for i = 1, 3 do
	local s = UI.icon("star", {Size = UDim2.fromOffset(36, 36), LayoutOrder = i, ZIndex = 43}, Rs.starRow)
	Rs.stars[i] = {img = s, scale = new("UIScale", {}, s)}
end
Rs.house = mt({Position = UDim2.fromOffset(140, 6), Size = UDim2.new(1, -330, 0, 22), TextSize = 17, TextXAlignment = LEFT, Text = "", ZIndex = 42}, Rs.strip, Wt.XBOLD)
Rs.houseSub = mt({Position = UDim2.fromOffset(140, 28), Size = UDim2.new(1, -330, 0, 18), TextSize = 13, TextXAlignment = LEFT, TextColor3 = Color3.fromRGB(190, 190, 205), Text = "", ZIndex = 42}, Rs.strip, Wt.SEMI)
Rs.timer = mt({Position = UDim2.new(1, -196, 0, 0), Size = UDim2.fromOffset(180, 54), TextSize = 15, TextXAlignment = RIGHT, TextColor3 = Color3.fromRGB(200, 200, 215), Text = "", ZIndex = 42}, Rs.strip, Wt.BOLD)

-- botones: gris (lobby) y verde (otra vez), grandes, con letra gruesa y contorno, como en TDS
function Rs.button(x, text, top, bottom, edge)
	local b = corner(new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, x, 0, 584), Size = UDim2.fromOffset(280, 56), BackgroundColor3 = WHITE,
		AutoButtonColor = false, BorderSizePixel = 0, Text = "", ZIndex = 42,
	}, results), 5)
	new("UIGradient", {Rotation = 90, Color = ColorSequence.new(top, bottom)}, b)
	new("UIStroke", {Color = edge, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, b)
	local l = mt({Size = UDim2.fromScale(1, 1), TextSize = 27, Text = text, TextStrokeTransparency = 1, ZIndex = 43}, b, Wt.BLACK)
	new("UIStroke", {Color = Sty.INK, Thickness = 2.4, LineJoinMode = Enum.LineJoinMode.Round}, l)
	Kit.press(b)
	return b, l
end
Rs.back, Rs.backLabel = Rs.button(-146, "Back to lobby", Color3.fromRGB(196, 196, 202), Color3.fromRGB(128, 128, 136), Color3.fromRGB(230, 230, 236))
Rs.again, Rs.againLabel = Rs.button(146, "Play Again", Color3.fromRGB(90, 236, 90), Color3.fromRGB(30, 170, 50), Color3.fromRGB(160, 255, 150))
Rs.back.Activated:Connect(function()
	UI.sound("Tab")
	Remote:FireServer("Leave")
end)
Rs.again.Activated:Connect(function()
	if not Rs.voted then
		Rs.voted = true
		UI.sound("Success", 0.6)
		Remote:FireServer("Again")
	end
end)

-- 10m 47s
function Rs.duration(s)
	s = math.max(0, math.floor(s or 0))
	return s >= 60 and ("%dm %02ds"):format(s // 60, s % 60) or ("%ds"):format(s)
end

function showResults(r)
	stopPlacing()
	selectTower(nil)
	setTactical(false)
	Rs.voted = false
	local won = r.won
	-- colores de la franja y del título
	local hi, lo = won and Color3.fromRGB(240, 40, 46) or Color3.fromRGB(88, 60, 120), won and Color3.fromRGB(150, 10, 24) or Color3.fromRGB(38, 26, 58)
	Rs.bannerGrad.Color = ColorSequence.new(hi, lo)
	for i, c in Rs.chips do
		c.BackgroundColor3 = (i % 3 == 0) and BLACK or (i % 3 == 1 and hi or lo)
	end
	Rs.title.Text = won and "VICTORY!" or "DEFEAT"
	Rs.titleGrad.Color = won and ColorSequence.new(Color3.fromRGB(255, 240, 130), Color3.fromRGB(255, 170, 30)) or ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 170, 220))
	Rs.titleStroke.Color = won and Color3.fromRGB(80, 10, 14) or Color3.fromRGB(26, 14, 40)
	-- tus tropas
	for _, c in Rs.troops:GetChildren() do
		if c:IsA("ViewportFrame") then
			c:Destroy()
		end
	end
	for i, t in r.troops or {} do
		if i <= 6 and Config.Scares[t] then
			local vp = UI.viewport(t, Rs.troops, {Size = UDim2.fromOffset(176, 200), LayoutOrder = i, ZIndex = 40}, true)
			vp.Ambient = won and Color3.fromRGB(200, 190, 220) or Color3.fromRGB(120, 110, 140)
			vp.ImageColor3 = won and Color3.new(1, 1, 1) or Color3.fromRGB(120, 112, 140) -- (al perder, apagadas)
		end
	end
	-- nivel y experiencia: de donde estaba a donde está
	local after = r.pxp or 0
	local before = math.max(0, after - (r.xp or 0))
	local lv0, x0, need0 = Config.playerLevelOf(before)
	local lv1, x1, need1 = Config.playerLevelOf(after)
	Rs.lv.Text, Rs.lvNext.Text = tostring(lv0), tostring(lv0 + 1)
	Rs.xpGain.Text = ("+%d EXP"):format(r.xp or 0)
	Rs.barFill.Size = UDim2.fromScale(need0 > 0 and x0 / need0 or 1, 1)
	Rs.xpNow.Text, Rs.xpNeed.Text = tostring(x0), tostring(need0)
	-- fichas
	for _, c in Rs.tiles:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local tiles = {}
	if (r.xp or 0) > 0 then
		table.insert(tiles, {"xp", ("%d EXP"):format(r.xp), Color3.fromRGB(80, 180, 255)})
	end
	table.insert(tiles, {"coin", ("%s Coins"):format(Kit.short(r.coins or 0)), UI.GOLD})
	if (r.gems or 0) > 0 then
		table.insert(tiles, {"gem", ("%d Gems"):format(r.gems), Color3.fromRGB(110, 220, 255)})
	end
	for id, n in r.parts or {} do
		local part = Config.Parts[id]
		table.insert(tiles, {part and part.icon or "🎁", ("x%d %s"):format(n, part and part.name or id), Color3.fromRGB(200, 140, 255)})
	end
	if r.mvp and Config.Scares[r.mvp] then
		table.insert(tiles, {r.mvp, "MVP", Kit.color(r.mvp)})
	end
	local scales = {}
	for i, tl in tiles do
		if i <= 8 then
			scales[i] = Rs.tile(i, tl[1], tl[2], tl[3])
		end
	end
	-- datos
	local rows = {
		{"Time:", Rs.duration(r.time)},
		{"Map:", r.map or "?"},
		{"Waves:", r.endless and (("%d  (Endless)"):format(math.max(r.waves, 0))) or ("%d / %d"):format(math.max(r.waves, 0), r.total or TD.WAVES), r.record and UI.GOLD},
		{"Difficulty:", r.diff or "Normal", TD.DIFFS[r.diff or ""] and TD.DIFFS[r.diff].color},
		{"Hunters scared:", ("%d  (you %d)"):format(r.teamKills or 0, r.kills or 0)},
		{"Fear dealt:", Kit.short(r.damage or 0)},
		{"MVP troop:", r.mvp and Config.Scares[r.mvp] and Config.Scares[r.mvp].name or "-", r.mvp and Kit.color(r.mvp)},
	}
	for i, row in Rs.rows do
		row.cap.Text, row.val.Text = rows[i][1], rows[i][2]
		row.val.TextColor3 = rows[i][3] or WHITE
	end
	-- la casa
	local hp, maxHp = r.hp or 0, r.maxHp or TD.BASE_HP
	if won then
		Rs.house.Text = r.stars >= 3 and "Perfect defense!" or (r.stars == 2 and "Great defense!" or "The house survived!")
		Rs.houseSub.Text = ("House health: %d / %d"):format(hp, maxHp)
	else
		Rs.house.Text = "The hunters took the house..."
		Rs.houseSub.Text = ("You survived %d of %d waves"):format(math.max(r.waves, 0), r.total or TD.WAVES)
		if r.endless then
			-- Modo Infinito: la casa siempre acaba cayendo; lo que cuenta es hasta dónde has llegado
			Rs.house.Text = r.record and "NEW RECORD!" or "The endless night is over"
			Rs.houseSub.Text = ("You held out for %d waves"):format(math.max(r.waves, 0))
			if r.record then
				task.delay(1.2, function()
					UI.big("NEW RECORD!", ("Wave %d on %s"):format(math.max(r.waves, 0), r.map or "this map"), UI.GOLD, 3)
					UI.sound("Win")
					UI.confetti(120)
				end)
			end
		end
	end
	for _, s in Rs.stars do
		s.img.ImageColor3 = Color3.fromRGB(56, 52, 70)
		s.scale.Scale = 1
	end
	Rs.againLabel.Text = "Play Again"
	-- entrada: fondo, franja que se abre, título que cae, cuerpo que sube
	Mj.stop()
	Rs.shade.Visible = true
	Rs.shade.BackgroundTransparency = 1
	tween(Rs.shade, 0.4, {BackgroundTransparency = 0.45})
	results.Visible = true
	results.GroupTransparency = 1
	Rs.pop.Scale = 0.8
	Rs.titlePop.Scale = 2.2
	tween(results, 0.25, {GroupTransparency = 0})
	tween(Rs.pop, 0.45, {Scale = 1}, Enum.EasingStyle.Back)
	tween(Rs.titlePop, 0.5, {Scale = 1}, Enum.EasingStyle.Back)
	UI.sound(won and "Win" or "Thunder")
	if won then
		UI.flash(UI.GOLD, 0.5, 1)
		UI.confetti(140)
	else
		UI.flash(Color3.fromRGB(120, 20, 40), 0.5, 0.8)
	end
	local token = {}
	Rs.token = token
	task.spawn(function()
		task.wait(0.55)
		-- fichas, una a una
		for i, s in scales do
			if Rs.token ~= token then
				return
			end
			tween(s, 0.3, {Scale = 1}, Enum.EasingStyle.Back)
			UI.sound("Coin", 0.45, 0.9 + i * 0.07)
			task.wait(0.12)
		end
		-- estrellas
		for i = 1, r.stars or 0 do
			Rs.stars[i].img.ImageColor3 = WHITE
			Rs.stars[i].scale.Scale = 1.7
			tween(Rs.stars[i].scale, 0.35, {Scale = 1}, Enum.EasingStyle.Back)
			UI.sound("Sparkle", 1, 0.9 + i * 0.12)
			task.wait(0.22)
		end
		-- la barra se llena (y si sube de nivel, se vacía y sigue)
		local lv, x, need = lv0, x0, need0
		local goalLv = lv1
		while Rs.token == token and (lv < goalLv or (lv == goalLv and x < x1)) do
			local target = lv < goalLv and need or x1
			local step = math.max(1, math.ceil((target - x) / 18))
			x = math.min(target, x + step)
			Rs.barFill.Size = UDim2.fromScale(need > 0 and x / need or 1, 1)
			Rs.xpNow.Text = tostring(x)
			if x >= need and lv < goalLv then
				lv += 1
				x = 0
				need = Config.pxpNeed and Config.pxpNeed(lv) or need
				Rs.lv.Text, Rs.lvNext.Text, Rs.xpNeed.Text = tostring(lv), tostring(lv + 1), tostring(need)
				Rs.lvPop.Scale = 1.6
				tween(Rs.lvPop, 0.4, {Scale = 1}, Enum.EasingStyle.Back)
				Rs.xpGain.Text = "LEVEL UP!"
				UI.sound("Success")
			end
			task.wait(0.03)
		end
	end)
end

-- Cuenta atrás y votos de "Play Again" (cada 0.1 s, con el resto del HUD)
function Rs.update()
	if not results.Visible then
		if Rs.shade.Visible then
			Rs.shade.Visible = false
		end
		return
	end
	local left = math.max(0, math.ceil((state:GetAttribute("NextAt") or 0) - workspace:GetServerTimeNow()))
	Rs.timer.Text = ("Returning in %ds"):format(left)
	local n, need = state:GetAttribute("Again") or 0, math.max(1, state:GetAttribute("Players") or 1)
	Rs.againLabel.Text = (Rs.voted or n > 0) and ("Play Again (%d/%d)"):format(n, need) or "Play Again"
end

---------- Cazafantasmas: lo que se ve de cada uno (como en TDS) ----------
-- · Una marca por tipo, para leerlos de un vistazo: burbuja de escudo, sombra y propulsor de los que vuelan, estela de
--   los rápidos, humo de los ocultos, aro de los que curan o ayudan y aro rojo de los jefes.
-- · Barra de vida pequeña con sus estados (iconos), solo cuando ya les han asustado algo.
-- · Al pasar el ratón: ficha con nombre, vida y rasgos. Los jefes: barra grande sobre ellos (rombo, nombre y vida).
local En = {live = {}, bars = {}}
En.STATUS = {{"💫", "bolt"}, {"🐢", "snow"}, {"😨", "fear"}, {"🔥", "flame"}, {"😱", "skull"}, {"💨", "fast"}, {"🎵", "crown"}}
En.SUPPORT = {heal = Color3.fromRGB(90, 235, 120), cleanse = Color3.fromRGB(255, 236, 170), barrier = SHIELD, inspire = Color3.fromRGB(255, 206, 60)}
En.HP = {
	{0.6, Color3.fromRGB(96, 238, 104), Color3.fromRGB(32, 168, 60)},
	{0.3, Color3.fromRGB(255, 214, 72), Color3.fromRGB(214, 140, 24)},
	{0, Color3.fromRGB(255, 96, 104), Color3.fromRGB(196, 32, 52)},
}

-- lo que hace especial a cada tipo, en pocas palabras (ficha al pasar el ratón)
function En.traits(def)
	local t = {}
	local function add(s)
		table.insert(t, s)
	end
	if def.boss then add("BOSS") end
	if def.shield then add("Shielded") end
	if def.armor then add(("Armor %d%%"):format(def.armor * 100 + 0.5)) end
	if def.fly then add("Flying") end
	if def.hidden then add("Hidden") end
	if def.speed >= 12 then add("Fast") end
	if def.steady then add("Unstoppable") end
	if def.regen then add("Regenerates") end
	if def.heal then add("Heals allies") end
	if def.barrier then add("Shields allies") end
	if def.cleanse then add("Cleanses") end
	if def.inspire then add("Inspires") end
	if def.summon then add("Summons") end
	if def.disable then add("Stuns troops") end
	if def.blink then add("Teleports") end
	if def.dash or def.burst then add("Dashes") end
	if def.split then add("Splits") end
	if def.golden then add("Bonus cash") end
	return table.concat(t, "  ·  ")
end

function En.part(props)
	props.Anchored, props.CanCollide, props.CanQuery, props.CanTouch, props.CastShadow = true, false, false, false, false
	return new("Part", props, workspace)
end
-- aro plano en el suelo (SurfaceGui: borde de color y relleno tenue)
function En.disc(d, color, edge, fill)
	local p = En.part({Name = "AroEnemigo", Transparency = 1, Size = Vector3.new(d, 0.05, d)})
	local g = new("SurfaceGui", {Face = Enum.NormalId.Top, LightInfluence = 0, Brightness = 1.6, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 20, Adornee = p}, p)
	local f = corner(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BackgroundTransparency = fill or 0.85, BorderSizePixel = 0}, g), UDim.new(0.5, 0))
	local st = new("UIStroke", {Color = color, Thickness = edge or 5, Transparency = 0.05}, f)
	return {part = p, frame = f, stroke = st}
end

-- Barra pequeña (vida, escudo y estados) sobre la cabeza
function En.smallBar(m, head, def)
	local bb = new("BillboardGui", {
		Name = "TDBar", Size = UDim2.fromOffset(70, 26), StudsOffset = Vector3.new(0, 1.5 + def.scale * 0.55, 0),
		MaxDistance = 320, LightInfluence = 0, Adornee = head, Enabled = false,
	}, head)
	local icons = new("Frame", {Size = UDim2.new(1, 0, 0, 15), BackgroundTransparency = 1}, bb)
	list({FillDirection = HORIZONTAL, HorizontalAlignment = CENTER, VerticalAlignment = MIDDLE, Padding = UDim.new(0, 1)}, icons)
	local back = corner(new("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -1), Size = UDim2.new(1, -6, 0, 8), BackgroundColor3 = Color3.fromRGB(14, 12, 16), BorderSizePixel = 0}, bb), 4)
	new("UIStroke", {Color = BLACK, Thickness = 1.5, Transparency = 0.1}, back)
	local loss = corner(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 236, 236), BorderSizePixel = 0}, back), 4)
	local fill = corner(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 2}, back), 4)
	local grad = new("UIGradient", {Rotation = 90}, fill)
	local shield = corner(new("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(110, 190, 255), BorderSizePixel = 0, ZIndex = 3}, back), 4)
	return {bb = bb, icons = icons, fill = fill, grad = grad, loss = loss, shield = shield}
end

-- Barra grande de jefe sobre él (como la de "Boss lent"): rombo con calavera, nombre y vida
function En.bossBar(m, head, def)
	local bb = new("BillboardGui", {
		Name = "TDBossBar", Size = UDim2.fromOffset(250, 42), StudsOffset = Vector3.new(0, 2.4 + def.scale * 0.9, 0),
		MaxDistance = 400, LightInfluence = 0, Adornee = head,
	}, head)
	mt({Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -30, 0, 20), TextSize = 17, TextXAlignment = LEFT, Text = def.name}, bb, Wt.BOLD)
	local back = corner(new("Frame", {Position = UDim2.fromOffset(20, 23), Size = UDim2.new(1, -20, 0, 19), BackgroundColor3 = BLACK, BackgroundTransparency = 0.12, BorderSizePixel = 0}, bb), 6)
	new("UIStroke", {Color = WHITE, Thickness = 1.5, Transparency = 0.2}, back)
	local fill = corner(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0}, back), 6)
	new("UIGradient", {Color = ColorSequence.new(WHITE, Color3.fromRGB(226, 27, 226))}, fill)
	new("Frame", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = Color3.fromRGB(255, 90, 255), BorderSizePixel = 0}, fill)
	local shield = corner(new("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(110, 190, 255), BackgroundTransparency = 0.15, BorderSizePixel = 0, ZIndex = 2}, back), 6)
	local hp = mt({AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = UDim2.new(1, -30, 1, 0), TextSize = 13, TextXAlignment = RIGHT, Text = "", ZIndex = 3}, back, Wt.BOLD)
	hicon("boss", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(20, 32), Size = UDim2.fromOffset(34, 34), ZIndex = 4}, bb)
	return {bb = bb, fill = fill, shield = shield, hp = hp}
end

function En.add(m)
	local head = m:WaitForChild("Head", 5)
	local root = m:WaitForChild("HumanoidRootPart", 5)
	if not (head and root and m.Parent) or En.bars[m] then
		return
	end
	local def = TD.Enemies[m:GetAttribute("Kind")] or TD.Enemies.visitor
	local e = {model = m, root = root, def = def, fx = {}, shown = false}
	if m:GetAttribute("Hidden") then
		Mj.once("hidden")
	elseif def.fly then
		Mj.once("fly")
	elseif def.shield then
		Mj.once("shield")
	end
	-- los ocultos se ven medio transparentes (solo los ven las tropas que detectan) y echan humo violeta
	local torso = m:FindFirstChild("UpperTorso") or root
	if m:GetAttribute("Hidden") then
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
				p.Transparency = 1 - (1 - p.Transparency) * 0.35
			end
		end
		new("ParticleEmitter", {
			Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(120, 70, 170)), Rate = 6, LightEmission = 0.3,
			Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(0.5, 1.2), Size = NumberSequence.new(1.2, 2.6), Transparency = NumberSequence.new(0.7, 1),
		}, torso)
	end
	-- en llamas mientras le dure el fuego
	e.flames = new("Fire", {Size = 3, Heat = 6, Color = Color3.fromRGB(255, 120, 30), SecondaryColor = Color3.fromRGB(255, 220, 90), Enabled = false}, torso)
	-- aturdidos: estrellas que giran sobre la cabeza; ralentizados: charco helado bajo los pies; aterrados: humo oscuro
	e.stars = {}
	for _ = 1, 3 do
		local s = En.part({Name = "Estrella", Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 226, 90), Size = Vector3.new(0.4, 0.4, 0.12) * def.scale, Transparency = 1})
		table.insert(e.stars, s)
		table.insert(e.fx, s)
	end
	e.goo = En.disc(3.4 * def.scale, Color3.fromRGB(140, 210, 255), 3, 0.45)
	e.goo.part.Parent = nil
	table.insert(e.fx, e.goo.part)
	e.dread = new("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(70, 20, 110)), Rate = 10, LightEmission = 0.2, Enabled = false,
		Lifetime = NumberRange.new(0.6, 0.9), Speed = NumberRange.new(0.5, 1.5), Size = NumberSequence.new(1.5, 2.8), Transparency = NumberSequence.new(0.5, 1),
	}, torso)
	-- escudo: burbuja de energía mientras le quede
	if def.shield or m:GetAttribute("Shield") then
		e.bubble = En.part({Name = "Burbuja", Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Color = Color3.fromRGB(90, 170, 255), Size = Vector3.one * 5.4 * def.scale})
		table.insert(e.fx, e.bubble)
	end
	-- vuelan: sombra en el suelo y propulsor
	if def.fly then
		e.shadow = En.part({Name = "Sombra", Shape = Enum.PartType.Cylinder, Material = Enum.Material.SmoothPlastic, Color = BLACK, Transparency = 0.55, Size = Vector3.new(0.05, 3.2 * def.scale, 3.2 * def.scale)})
		table.insert(e.fx, e.shadow)
		local a = new("Attachment", {Position = Vector3.new(0, -0.4, 0.6), Orientation = Vector3.new(0, 0, 180)}, torso)
		new("ParticleEmitter", {
			Texture = "rbxasset://textures/particles/fire_main.dds", Color = ColorSequence.new(Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 80, 30)), LightEmission = 1,
			Rate = 40, Lifetime = NumberRange.new(0.18, 0.28), Speed = NumberRange.new(9, 12), SpreadAngle = Vector2.new(8, 8),
			Size = NumberSequence.new(0.7, 0.1), Transparency = NumberSequence.new(0.1, 1), EmissionDirection = Enum.NormalId.Top,
		}, a)
	end
	-- rápidos: estela blanca
	if def.speed >= 12 and not def.fly then
		local a0 = new("Attachment", {Position = Vector3.new(0, 0.7, 0.3)}, torso)
		local a1 = new("Attachment", {Position = Vector3.new(0, -0.7, 0.3)}, torso)
		new("Trail", {
			Attachment0 = a0, Attachment1 = a1, Lifetime = 0.22, MinLength = 0.05, FaceCamera = true, LightEmission = 0.5,
			Color = ColorSequence.new(def.golden and UI.GOLD or WHITE), Transparency = NumberSequence.new(0.55, 1),
		}, torso)
	end
	-- ayudan a los suyos: aro de su color bajo los pies
	for k, color in En.SUPPORT do
		if def[k] then
			e.aura = En.disc(4.2 * def.scale, color, 4, 0.82)
			table.insert(e.fx, e.aura.part)
			break
		end
	end
	-- se curan solos: chispas verdes que suben
	if def.regen then
		new("ParticleEmitter", {
			Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(Color3.fromRGB(110, 255, 130)), LightEmission = 1, Rate = 4,
			Lifetime = NumberRange.new(0.8, 1.1), Speed = NumberRange.new(1.5, 2.5), Size = NumberSequence.new(0.5, 0.1), EmissionDirection = Enum.NormalId.Top,
		}, torso)
	end
	-- jefes: aro rojo que late y su barra grande
	if def.boss then
		e.aura = En.disc(6.5 * def.scale, Color3.fromRGB(255, 40, 60), 7, 0.78)
		table.insert(e.fx, e.aura.part)
		e.big = En.bossBar(m, head, def)
	end
	e.bar = En.smallBar(m, head, def)
	e.bar.bb.Enabled = false
	local function update()
		local hp, max = m:GetAttribute("HP") or 1, math.max(1, m:GetAttribute("MaxHP") or 1)
		local f = math.clamp(hp / max, 0, 1)
		local sh = (m:GetAttribute("Shield") or 0) / 100
		local b = e.bar
		if (f < 0.999 or (def.shield and sh < 0.999)) and not e.shown then
			e.shown = true
		end
		b.bb.Enabled = e.shown and not def.boss or e.hover == true
		tween(b.fill, 0.15, {Size = UDim2.fromScale(math.max(f, 0.001), 1)})
		task.delay(0.3, function()
			if b.loss.Parent then
				tween(b.loss, 0.45, {Size = UDim2.fromScale(math.max(f, 0.001), 1)})
			end
		end)
		for _, hc in En.HP do
			if f > hc[1] or hc[1] == 0 then
				b.grad.Color = ColorSequence.new(hc[2], hc[3])
				break
			end
		end
		tween(b.shield, 0.15, {Size = UDim2.fromScale(sh, 1)})
		if e.bubble then
			e.bubble.Transparency = sh > 0 and 0 or 1
		end
		if e.big then
			tween(e.big.fill, 0.2, {Size = UDim2.fromScale(math.max(f, 0.001), 1)})
			tween(e.big.shield, 0.2, {Size = UDim2.fromScale(sh, 1)})
			e.big.hp.Text = ("%s / %s"):format(Kit.money(hp):sub(2), Kit.money(max):sub(2))
		end
	end
	local function status()
		local st = m:GetAttribute("Status") or ""
		for _, c in e.bar.icons:GetChildren() do
			if c:IsA("ImageLabel") then
				c:Destroy()
			end
		end
		for i, pair in En.STATUS do
			if st:find(pair[1], 1, true) then
				hicon(pair[2], {Size = UDim2.fromOffset(15, 15), LayoutOrder = i}, e.bar.icons)
			end
		end
		e.flames.Enabled = st:find("🔥", 1, true) ~= nil
		e.stunned = st:find("💫", 1, true) ~= nil
		e.dread.Enabled = st:find("😨", 1, true) ~= nil
		for _, s in e.stars do
			s.Transparency = e.stunned and 0 or 1
		end
		e.goo.part.Parent = st:find("🐢", 1, true) and workspace or nil
	end
	m:GetAttributeChangedSignal("HP"):Connect(update)
	m:GetAttributeChangedSignal("Shield"):Connect(update)
	m:GetAttributeChangedSignal("Status"):Connect(status)
	e.update = update
	update()
	status()
	En.bars[m] = e
end

function En.remove(m)
	local e = En.bars[m]
	if not e then
		return
	end
	En.bars[m] = nil
	for _, p in e.fx do
		p:Destroy()
	end
	if e.bar then
		e.bar.bb:Destroy()
	end
	if e.big then
		e.big.bb:Destroy()
	end
	if e.bubble and e.bubble.Parent then
		e.bubble:Destroy()
	end
end

for _, m in CollectionService:GetTagged("TDEnemy") do
	task.spawn(En.add, m)
end
CollectionService:GetInstanceAddedSignal("TDEnemy"):Connect(function(m)
	task.spawn(En.add, m)
end)
CollectionService:GetInstanceRemovedSignal("TDEnemy"):Connect(En.remove)

-- Las marcas siguen a su dueño (piezas locales: más fiable que soldarlas a un modelo del servidor)
En.groundAt = {}
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for m, e in En.bars do
		if not m.Parent then
			En.remove(m)
			continue
		end
		local pos = e.root.Position
		local scale = e.def.scale
		if e.bubble then
			e.bubble.CFrame = CFrame.new(pos + Vector3.new(0, 0.3 * scale, 0))
		end
		-- la barra grande sobre el jefe solo si no es el de la barra de arriba (como el "Boss lent" de TDS)
		if e.big then
			e.big.bb.Enabled = m ~= bossModel
		end
		-- el suelo bajo sus pies (cada 0.2 s): ahí van la sombra y los aros
		local g = En.groundAt[m]
		if not g or t - g.t > 0.2 then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = {state, workspace:FindFirstChild("CaminoVista")}
			local hit = workspace:Raycast(pos, Vector3.new(0, -24, 0), params)
			g = {t = t, y = hit and hit.Position.Y or pos.Y - 3 * scale}
			En.groundAt[m] = g
		end
		local floor = Vector3.new(pos.X, g.y + 0.12, pos.Z)
		if e.stunned then
			local top = pos + Vector3.new(0, 2.9 * scale, 0)
			for k, s in e.stars do
				local ang = t * 5 + k * 2.094
				s.CFrame = CFrame.new(top + Vector3.new(math.cos(ang) * 1.1 * scale, 0.15 * math.sin(t * 8 + k), math.sin(ang) * 1.1 * scale)) * CFrame.Angles(0, -ang, math.pi / 4)
			end
		end
		if e.goo.part.Parent then
			e.goo.part.CFrame = CFrame.new(floor + Vector3.new(0, 0.03, 0))
		end
		if e.shadow then
			e.shadow.CFrame = CFrame.new(floor) * CFrame.Angles(0, 0, math.pi / 2)
		end
		if e.aura then
			local k = e.def.boss and (1 + 0.06 * math.sin(t * 5)) or 1
			e.aura.part.Size = Vector3.new(4.2 * scale * k * (e.def.boss and 1.55 or 1), 0.05, 4.2 * scale * k * (e.def.boss and 1.55 or 1))
			e.aura.part.CFrame = CFrame.new(floor + Vector3.new(0, 0.05, 0))
			e.aura.stroke.Transparency = e.def.boss and (0.15 + 0.25 * (0.5 + 0.5 * math.sin(t * 5))) or 0.1
		end
	end
end)

-- Ficha al pasar el ratón: nombre, vida y rasgos
En.tip = corner(new("Frame", {Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, BackgroundColor3 = Color3.fromRGB(22, 22, 26), BackgroundTransparency = 0.08, BorderSizePixel = 0, Visible = false, ZIndex = 40}, hud), 5)
outline(En.tip, BLACK, 2, 0.15)
pad(En.tip, 9, 10, 6, 7)
list({Padding = UDim.new(0, 3)}, En.tip)
En.tipName = mt({Size = UDim2.fromOffset(0, 18), AutomaticSize = AUTO_X, TextSize = 15, TextXAlignment = LEFT, Text = "", LayoutOrder = 1, ZIndex = 41}, En.tip, Wt.BLACK)
do
	local row = new("Frame", {Size = UDim2.fromOffset(170, 16), BackgroundTransparency = 1, LayoutOrder = 2, ZIndex = 41}, En.tip)
	hicon("heart", {Size = UDim2.fromOffset(16, 16), ZIndex = 43}, row)
	local back = corner(new("Frame", {Position = UDim2.fromOffset(10, 3), Size = UDim2.new(1, -10, 0, 11), BackgroundColor3 = Color3.fromRGB(14, 12, 16), BorderSizePixel = 0, ZIndex = 41}, row), 4)
	En.tipFill = corner(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(60, 210, 80), BorderSizePixel = 0, ZIndex = 42}, back), 4)
	En.tipHP = mt({Size = UDim2.fromScale(1, 1), TextSize = 10, Text = "", ZIndex = 43}, back, Wt.BOLD)
end
En.tipTraits = mt({Size = UDim2.fromOffset(170, 0), AutomaticSize = AUTO_Y, TextSize = 10, TextWrapped = true, TextXAlignment = LEFT, TextColor3 = UI.GOLD, TextStrokeTransparency = 1, Text = "", LayoutOrder = 3, ZIndex = 41}, En.tip, Wt.BOLD)
En.hoverAt = 0
function En.hover()
	if placing or os.clock() - En.hoverAt < 0.05 then
		return
	end
	En.hoverAt = os.clock()
	local cam = workspace.CurrentCamera
	local mouse = UserInputService:GetMouseLocation()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {state:FindFirstChild("Enemies")}
	local ray = cam:ViewportPointToRay(mouse.X, mouse.Y)
	local hit = state:FindFirstChild("Enemies") and workspace:Raycast(ray.Origin, ray.Direction * 400, params)
	local m = hit and hit.Instance:FindFirstAncestorOfClass("Model")
	while m and m.Parent and m.Parent.Name ~= "Enemies" do
		m = m.Parent:FindFirstAncestorOfClass("Model")
	end
	local e = m and En.bars[m]
	if En.hovered and En.hovered ~= e then
		En.hovered.hover = false
		En.hovered.update()
	end
	En.hovered = e
	En.tip.Visible = e ~= nil
	if not e then
		return
	end
	e.hover = true
	e.update()
	local def = e.def
	local hp, max = m:GetAttribute("HP") or 0, math.max(1, m:GetAttribute("MaxHP") or 1)
	En.tipName.Text = def.name
	En.tipName.TextColor3 = def.boss and Color3.fromRGB(255, 96, 110) or (def.golden and UI.GOLD or WHITE)
	En.tipFill.Size = UDim2.fromScale(math.clamp(hp / max, 0, 1), 1)
	En.tipHP.Text = ("%s / %s"):format(Kit.money(hp):sub(2), Kit.money(max):sub(2))
	local tr = En.traits(def)
	En.tipTraits.Text = tr
	En.tipTraits.Visible = tr ~= ""
	local inset = game:GetService("GuiService"):GetGuiInset()
	local k = math.max(UI.uiScale.Scale, 0.1)
	En.tip.Position = UDim2.fromOffset((mouse.X + 18) / k, (mouse.Y - inset.Y + 12) / k)
end

-- Llega un jefe: aviso a pantalla completa (franjas rojas, su retrato, su nombre), onda en el suelo y rugido
En.intro = new("CanvasGroup", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, GroupTransparency = 1, Visible = false, ZIndex = 50}, hud)
do
	local vig = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 50}, En.intro)
	new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.5, 0.75), NumberSequenceKeypoint.new(1, 0.2)}), Rotation = 90}, vig)
	-- la franja: roja con rayas de peligro arriba y abajo
	En.band = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.new(1.2, 0, 0, 150), Rotation = -3, BackgroundColor3 = Color3.fromRGB(200, 20, 40), BorderSizePixel = 0, ZIndex = 51}, En.intro)
	new("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 150)), Rotation = 90}, En.band)
	for _, y in {0, 1} do
		local stripe = new("Frame", {AnchorPoint = Vector2.new(0, y), Position = UDim2.fromScale(0, y), Size = UDim2.new(1, 0, 0, 14), BackgroundColor3 = BLACK, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 52}, En.band)
		for k = 0, 90 do
			new("Frame", {Position = UDim2.fromOffset(k * 28, -10), Size = UDim2.fromOffset(13, 40), Rotation = 35, BackgroundColor3 = Color3.fromRGB(255, 206, 40), BorderSizePixel = 0, ZIndex = 53}, stripe)
		end
	end
	En.introFace = corner(new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, -270, 0.5, 0), Size = UDim2.fromOffset(150, 150), BackgroundColor3 = Color3.fromRGB(40, 8, 16), BorderSizePixel = 0, ZIndex = 54}, En.band), UDim.new(0.5, 0))
	new("UIStroke", {Color = WHITE, Thickness = 4}, En.introFace)
	En.introWarn = mt({AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.5, -175, 0.5, -38), Size = UDim2.fromOffset(600, 26), TextSize = 22, TextXAlignment = LEFT, TextColor3 = Color3.fromRGB(255, 220, 80), Text = "⚠  BOSS INCOMING  ⚠", ZIndex = 55}, En.band, Wt.BLACK)
	En.introName = mt({AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.5, -175, 0.5, 4), Size = UDim2.fromOffset(700, 56), TextSize = 50, TextXAlignment = LEFT, Text = "", ZIndex = 55}, En.band, Wt.BLACK)
	En.introSub = mt({AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.5, -175, 0.5, 44), Size = UDim2.fromOffset(760, 22), TextSize = 16, TextXAlignment = LEFT, TextColor3 = Color3.fromRGB(255, 225, 225), Text = "", ZIndex = 55}, En.band, Wt.SEMI)
	En.introPop = new("UIScale", {}, En.introName)
end
En.introToken = 0
function En.bossIntro(model, name)
	En.introToken += 1
	local token = En.introToken
	local def = TD.Enemies[model and model:GetAttribute("Kind") or ""] or {}
	-- su retrato: una copia del jefe de verdad, de frente
	for _, c in En.introFace:GetChildren() do
		if c:IsA("ViewportFrame") then
			c:Destroy()
		end
	end
	if model and model.Parent then
		local vp = corner(new("ViewportFrame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = Color3.fromRGB(200, 170, 180), LightColor = Color3.fromRGB(255, 220, 210), LightDirection = Vector3.new(-0.5, -1, -1), ZIndex = 55}, En.introFace), UDim.new(0.5, 0))
		local ok, copy = pcall(function()
			model.Archivable = true
			return model:Clone()
		end)
		if ok and copy then
			for _, d in copy:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
				elseif d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("Fire") then
					d:Destroy()
				end
			end
			copy.Parent = vp
			local head = copy:FindFirstChild("Head")
			local cam = new("Camera", {FieldOfView = 30}, vp)
			vp.CurrentCamera = cam
			if head then
				local look = head.CFrame.LookVector
				local focus = head.Position - Vector3.new(0, head.Size.Y * 0.6, 0)
				cam.CFrame = CFrame.lookAt(focus + look * head.Size.Y * 5.5 + Vector3.new(0, head.Size.Y * 0.6, 0), focus)
			end
		end
	end
	En.introName.Text = string.upper(name)
	local tr = En.traits(def)
	tr = tr:sub(1, 4) == "BOSS" and tr:sub(5):gsub("^[%s·]+", "") or tr
	En.introSub.Text = tr ~= "" and (tr .. "  ·  Scare it away before it reaches the house!") or "Scare it away before it reaches the house!"
	En.intro.Visible = true
	En.intro.GroupTransparency = 1
	En.band.Position = UDim2.fromScale(-0.7, 0.55)
	En.introPop.Scale = 1.6
	tween(En.intro, 0.2, {GroupTransparency = 0})
	tween(En.band, 0.45, {Position = UDim2.fromScale(0.5, 0.55)}, Enum.EasingStyle.Back)
	task.delay(0.25, function()
		tween(En.introPop, 0.35, {Scale = 1}, Enum.EasingStyle.Back)
	end)
	UI.flash(Color3.fromRGB(255, 30, 50), 0.55, 0.6)
	UI.sound("Growl")
	UI.sound("Thunder", 0.6)
	shake()
	if model and model.Parent and model:FindFirstChild("HumanoidRootPart") then
		local pos = model.HumanoidRootPart.Position
		ring(pos - Vector3.new(0, 2.5, 0), 16, Color3.fromRGB(255, 40, 60), 0.8)
		burst(pos, Color3.fromRGB(255, 60, 80), 9)
		sound3D("Boom", pos, 0.8)
	end
	task.delay(2.6, function()
		if En.introToken ~= token then
			return
		end
		tween(En.band, 0.35, {Position = UDim2.fromScale(1.7, 0.55)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(En.intro, 0.4, {GroupTransparency = 1})
		task.wait(0.45)
		if En.introToken == token then
			En.intro.Visible = false
		end
	end)
end

---------- Selección y panel de la tropa ----------
local selCircle, selLight, panelType

local function whole(v)
	return tostring(math.floor(v + 0.5))
end
local function perSecond(v)
	return ("%.2f/s"):format(v)
end

function refreshPanel()
	local m = selected
	local t = m and m.Parent and m:GetAttribute("Type")
	if not t then
		return
	end
	local level = m:GetAttribute("Level") or 1
	local c = Kit.color(t)
	local mastery = m:GetAttribute("Mastery") or 1 -- (el nivel de la tropa: más miedo)
	local s = TD.stats(t, level, mastery)
	local nx = level < TD.MAX_LEVEL and TD.stats(t, level + 1, mastery)
	local mine = m:GetAttribute("Owner") == player.UserId
	local cash = player:GetAttribute("TDCash") or 0
	-- (el retrato, con su nivel; la tarjeta de mejora, con el siguiente)
	if panelType ~= t .. level then
		panelType = t .. level
		for _, holder in {Pn.face, Pn.upImg} do
			for _, x in holder:GetChildren() do
				if x:IsA("ViewportFrame") then
					x:Destroy()
				end
			end
		end
		UI.viewport(t, Pn.face, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(200, 200), ZIndex = 2}, false, function(model)
			Tw.dress(model, t, level)
		end)
		UI.viewport(t, Pn.upImg, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(1.35, 1.35), ZIndex = 2}, true, function(model)
			Tw.dress(model, t, math.min(level + 1, TD.MAX_LEVEL))
		end)
		Pn.glow.ImageColor3 = c
		Pn.name.Text = Config.Scares[t].name
	end
	-- estadísticas y la caja de abajo (DPS; lo ganado en los pozos; el aura en los espejos)
	local stats, dps
	if s.kind == "farm" then
		stats = {{"cash", Kit.money(s.income)}, {"range", Pn.dec(s.range)}}
		dps = {"EARNED", "cash", Kit.short(m:GetAttribute("Earned") or 0)}
	elseif s.kind == "support" then
		stats = {{"fear", Pn.pct(s.buff.dmg)}, {"range", Pn.pct(s.buff.range)}, {"detect", "Yes"}}
		dps = {"AURA", "range", Pn.dec(s.range)}
	else
		stats = {{"hourglass", ("%.2f"):format(s.cd)}, {"range", Pn.dec(s.range)}, {"fear", whole(s.dmg)}}
		dps = {"DPS", "sword", ("%.2f"):format(s.dmg * (s.chain or 1) / s.cd + (s.burn and s.burn.dps or 0))}
	end
	for i, st in Pn.stat do
		local row = stats[i]
		st.icon.Visible, st.text.Visible = row ~= nil, row ~= nil
		if row then
			setHicon(st.icon, row[1])
			st.text.Text = row[2]
		end
	end
	Pn.dpsCap.Text = dps[1]
	setHicon(Pn.dpsIcon, dps[2])
	Pn.dpsText.Text = dps[3]
	Pn.bonus.Text = mastery > 1 and ("★ Troop Lv %d  ·  +%d%% fear"):format(mastery, Config.LEVEL_FEAR * (mastery - 1) * 100 + 0.5) or ""
	-- objetivo
	local attacks = TD.attacks(t)
	Pn.targetCap.Visible = attacks
	Pn.target.Text = attacks and (Pn.TARGETS[m:GetAttribute("Target") or "First"] or "First enemy") or (s.kind == "farm" and "Earns every wave" or "Boosts nearby troops")
	Pn.prev.Visible, Pn.next.Visible = attacks and mine, attacks and mine
	-- nivel y gastado | miedo causado (lo ganado en los pozos)
	Pn.level.Text = ("Level: %d"):format(level)
	Pn.spent.Text = ("Spent: %s"):format(Kit.money(m:GetAttribute("Spent") or 0))
	if s.kind == "farm" then
		Pn.dealtCap.Text, Pn.dealt.Text, Pn.dealt.TextColor3 = "Earned:", Kit.money(m:GetAttribute("Earned") or 0), Sty.PRICE
	elseif s.kind == "support" then
		Pn.dealtCap.Text, Pn.dealt.Text, Pn.dealt.TextColor3 = "Tier:", TD.TIERS[level], UI.GOLD
	else
		Pn.dealtCap.Text, Pn.dealt.Text, Pn.dealt.TextColor3 = "Fear dealt:", Kit.short(m:GetAttribute("Damage") or 0), Color3.fromRGB(255, 86, 96)
	end
	-- vender (o de quién es)
	Pn.sell.Visible, Pn.sellKey.Visible = mine, mine and not TOUCH
	Pn.owner.Visible = not mine
	Pn.owner.Text = "Placed by " .. (m:GetAttribute("OwnerName") or "?")
	Pn.sellText.Text = ("Sell: %s"):format(Kit.money(TD.sellValue(m:GetAttribute("Spent") or 0)))
	-- la mejora
	for i, pip in Pn.pip do
		pip.BackgroundColor3 = i <= level and Sty.PRICE or (i == level + 1 and Color3.fromRGB(40, 96, 48) or Color3.fromRGB(34, 34, 40))
	end
	Pn.upKey.Visible = (mine and nx and not TOUCH) or false
	local ch = {}
	if nx then
		local cost = TD.upgradeCost(t, level)
		local can = mine and cash >= cost
		Pn.upTitle.Text = TD.TIERS[level + 1]
		Pn.upSub.Text = ("Level %d upgrade"):format(level + 1)
		Pn.upPrice.Text = Kit.money(cost)
		Pn.upPrice.TextColor3 = cash >= cost and Sty.PRICE or Color3.fromRGB(255, 96, 104)
		Pn.upGrad.Color = can and ColorSequence.new(Color3.fromRGB(50, 164, 66), Color3.fromRGB(22, 92, 36)) or ColorSequence.new(Color3.fromRGB(62, 78, 66), Color3.fromRGB(34, 44, 38))
		Pn.upStroke.Color = can and Color3.fromRGB(130, 255, 150) or Color3.fromRGB(112, 132, 116)
		local function add(icon, a, b, fmt)
			if fmt(a) ~= fmt(b) then
				table.insert(ch, {icon, ('%s <font color="#6CF08A">→ %s</font>'):format(fmt(a), fmt(b))})
			end
		end
		if s.kind == "farm" then
			add("cash", s.income, nx.income, Kit.money)
		elseif s.kind == "support" then
			add("fear", s.buff.dmg, nx.buff.dmg, Pn.pct)
			add("range", s.buff.range, nx.buff.range, Pn.pct)
		else
			add("fear", s.dmg, nx.dmg, whole)
			add("hourglass", s.cd, nx.cd, Pn.secs)
			add("range", s.range, nx.range, Pn.dec)
			if s.chain then
				add("bolt", s.chain, nx.chain, whole)
			end
			if s.splash then
				add("target", s.splash, nx.splash, Pn.dec)
			end
		end
		if nx.detect and not s.detect then -- (lo primero: con esta mejora ya ve a los ocultos)
			table.insert(ch, 1, {"detect", '<font color="#6CF08A">Sees hidden hunters!</font>'})
		end
	else
		Pn.upTitle.Text = "MAX LEVEL"
		Pn.upSub.Text = TD.TIERS[level]
		Pn.upPrice.Text = "★★★★"
		Pn.upPrice.TextColor3 = UI.GOLD
		Pn.upGrad.Color = ColorSequence.new(Color3.fromRGB(232, 172, 34), Color3.fromRGB(140, 86, 14))
		Pn.upStroke.Color = Color3.fromRGB(255, 226, 120)
	end
	for i, r in Pn.rows do
		local row = not Pn.showInfo and ch[i]
		r.frame.Visible = row and true or false
		if row then
			setHicon(r.icon, row[1])
			r.text.Text = row[2]
		end
	end
	if Pn.showInfo then
		Pn.desc.TextSize, Pn.desc.Text = 13, TD.Troops[t].info .. "\n\n" .. Kit.special(s)
	else
		Pn.desc.TextSize, Pn.desc.Text = 11, Kit.special(nx or s)
	end
	if selCircle then
		Kit.setCircle(selCircle, (anims[m] and anims[m].base or m:GetPivot()).Position, s.range, WHITE)
	end
end

function selectTower(model)
	if model == selected then
		return
	end
	selected = model
	if selCircle then
		selCircle.part:Destroy()
		selCircle = nil
	end
	if selLight then
		selLight:Destroy()
		selLight = nil
	end
	if not model then
		if Pn.root.Visible then
			tween(Pn.pop, 0.1, {Scale = 0.9})
			task.delay(0.1, function()
				if not selected then
					Pn.root.Visible = false
				end
			end)
		end
		return
	end
	tip.Visible = false
	Pn.root.Visible = true
	Pn.showInfo = false
	selCircle = Kit.circle()
	selCircle.fill.BackgroundTransparency, selCircle.edge.Thickness, selCircle.ring.Transparency = 0.9, 3, 1
	selLight = new("Highlight", {FillTransparency = 1, OutlineColor = WHITE, DepthMode = Enum.HighlightDepthMode.Occluded}, model)
	refreshPanel()
	Pn.pop.Scale = 0.85
	tween(Pn.pop, 0.25, {Scale = 1}, Enum.EasingStyle.Back)
	UI.sound("Tab")
end

local function towerOf(inst)
	while inst and inst.Parent ~= towersF do
		inst = inst.Parent
	end
	return inst
end

-- La tropa bajo el clic: la que toca el rayo o, si da en el suelo, la más cercana a menos de 3 studs (las tropas con
-- huecos, como los murciélagos, se dejaban atravesar)
local function pickTower(hit)
	if not hit then
		return nil
	end
	local m = towerOf(hit.Instance)
	if m then
		return not m:GetAttribute("Sold") and m or nil
	end
	local best, bd = nil, 3
	for _, x in towersF:GetChildren() do
		local d = TD.flat(x:GetPivot().Position - hit.Position)
		if d < bd then
			best, bd = x, d
		end
	end
	return best
end

local function upgrade()
	if selected and selected:GetAttribute("Owner") == player.UserId then
		Remote:FireServer("Upgrade", selected)
	end
end

local function sell()
	if selected and selected:GetAttribute("Owner") == player.UserId then
		Remote:FireServer("Sell", selected)
		selectTower(nil)
	end
end

-- dir: 1 = siguiente objetivo, -1 = el anterior (flechas del panel; la T pasa al siguiente)
local function cycleTarget(dir)
	local t = selected and selected:GetAttribute("Type")
	if t and selected:GetAttribute("Owner") == player.UserId and TD.attacks(t) then
		local n = #TD.TARGETS
		local i = table.find(TD.TARGETS, selected:GetAttribute("Target") or "First") or 1
		UI.sound("Tab")
		Remote:FireServer("Target", selected, TD.TARGETS[(i - 1 + (dir or 1)) % n + 1])
	end
end

Pn.prev.Activated:Connect(function()
	cycleTarget(-1)
end)
Pn.next.Activated:Connect(function()
	cycleTarget(1)
end)
Pn.up.Activated:Connect(upgrade)
Pn.sell.Activated:Connect(sell)
Pn.help.Activated:Connect(function()
	Pn.showInfo = not Pn.showInfo
	UI.sound("Tab")
	refreshPanel()
end)

---------- Colocar ----------
local pointer -- móvil: último toque en el mundo (pantalla)
local rot = 0

-- Copia de un susto para la vista previa (con tu skin equipada): sin hitbox, sonidos ni colisiones, medio transparente
local function ghostOf(t)
	local m = Assets.Scares[Config.skinFor(player, t)]:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "Hitbox" or d.Name == "Path" or d.Name == "Range" then
				d:Destroy()
			else
				d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = true, false, false, false, false
				d.Transparency = 1 - (1 - (d:GetAttribute("T") or d.Transparency)) * 0.85
			end
		elseif d:IsA("Sound") or d:IsA("LuaSourceContainer") or d:IsA("ParticleEmitter") then
			d:Destroy()
		end
	end
	return m
end

-- Mientras colocas, el alcance de tus otras tropas se ve tenue (para no pisarlas ni dejar huecos)
local others = {}
local function clearOthers()
	for _, c in others do
		c.part:Destroy()
	end
	table.clear(others)
end
local function showOthers()
	clearOthers()
	for _, m in towersF:GetChildren() do
		local t = m:GetAttribute("Type")
		if t and TD.Troops[t] and m:GetAttribute("Owner") == player.UserId and TD.Troops[t].range > 0 then
			local c = Kit.circle()
			local s = TD.stats(t, m:GetAttribute("Level") or 1, m:GetAttribute("Mastery") or 1)
			Kit.setCircle(c, (anims[m] and anims[m].base or m:GetPivot()).Position, s.range, WHITE)
			c.fill.BackgroundTransparency, c.edge.Transparency, c.ring.Transparency = 0.94, 0.7, 1
			table.insert(others, c)
		end
	end
end

function stopPlacing()
	if placing then
		placing.ghost:Destroy()
		placing.circle.part:Destroy()
		placing.foot.part:Destroy()
		placing.lane:Destroy()
		placing = nil
	end
	clearOthers()
	Hn.list.Visible = false
	Hn.touch.Visible = false
end

function startPlacing(t)
	stopPlacing()
	selectTower(nil)
	local troop = TD.Troops[t]
	local cash = player:GetAttribute("TDCash") or 0
	if cash < troop.cost then
		return UI.toast(("You need %s more"):format(Kit.money(troop.cost - cash)), UI.RED)
	end
	local n, total = counts()
	if (n[t] or 0) >= TD.limit(t) then
		return UI.toast(("Limit reached: %d %s"):format(TD.limit(t), Config.Scares[t].name), UI.RED)
	end
	if total >= TD.MAX_UNITS then
		return UI.toast(("Troop limit reached: %d"):format(TD.MAX_UNITS), UI.RED)
	end
	local ghost = ghostOf(t)
	local light = new("Highlight", {FillTransparency = 0.82, OutlineTransparency = 0.15, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop}, ghost)
	ghost.Parent = workspace
	local circle = Kit.circle()
	circle.edge.Thickness, circle.edge.Transparency, circle.ring.Transparency = 4, 0, 1
	placing = {t = t, ghost = ghost, circle = circle, light = light, ok = false, foot = Hn.footprint(), lane = Hn.lane(t)}
	showOthers()
	pointer = nil
	tip.Visible = false
	Hn.list.Visible = not TOUCH
	Hn.touch.Visible = TOUCH
	UI.sound("Pickup")
end

function toggle(t)
	if placing and placing.t == t then
		stopPlacing()
	else
		startPlacing(t)
	end
end

-- El ratón atraviesa lo invisible (muros de los límites, zonas, marcadores): desde la vista
-- de mapa, los límites altos tapaban el suelo y la tropa salía flotando, enorme, "fuera del mapa".
local function cast(ray, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local origin, dir = ray.Origin, ray.Direction * 900
	for _ = 1, 8 do
		local hit = workspace:Raycast(origin, dir, params)
		if not (hit and hit.Instance.Transparency >= 0.95) then
			return hit
		end
		params:AddToFilter(hit.Instance)
	end
	return nil
end

local function pointerRay()
	local cam = workspace.CurrentCamera
	if TOUCH then
		return pointer and cam:ScreenPointToRay(pointer.X, pointer.Y) or cam:ViewportPointToRay(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
	end
	local mouse = UserInputService:GetMouseLocation()
	return cam:ViewportPointToRay(mouse.X, mouse.Y)
end

local function updatePlacing()
	local p = placing
	-- la lista de teclas sigue al ratón
	if not TOUCH then
		local mouse = UserInputService:GetMouseLocation() - game:GetService("GuiService"):GetGuiInset()
		local k = math.max(UI.uiScale.Scale, 0.1)
		Hn.list.Position = UDim2.fromOffset(mouse.X / k + 26, mouse.Y / k - 6)
	end
	local ignore = {p.ghost, p.circle.part, player.Character, state}
	for _, c in others do
		table.insert(ignore, c.part)
	end
	local hit = cast(pointerRay(), ignore)
	if not hit then
		p.ok = false
		return
	end
	local ok, why, pos = TD.canPlace(p.t, hit.Position, p.ghost, map)
	p.ok, p.why, p.at = ok, why, pos or hit.Position
	p.ghost:PivotTo(CFrame.new(p.at) * CFrame.Angles(0, rot, 0))
	local c = ok and WHITE or Color3.fromRGB(255, 60, 70)
	Kit.setCircle(p.circle, p.at, TD.Troops[p.t].range, c)
	p.circle.fill.BackgroundTransparency = ok and 0.9 or 0.8
	p.foot.part.CFrame = CFrame.new(p.at + Vector3.new(0, 0.34, 0))
	Hn.paintFoot(p.foot, c)
	p.light.FillColor, p.light.OutlineColor = c, c
	Hn.placeText.Text = ok and "Place" or (why or "You can't place it there")
	Hn.placeText.TextColor3 = ok and WHITE or Color3.fromRGB(255, 96, 104)
	Hn.mouseBtn.BackgroundColor3 = ok and Sty.PRICE or UI.RED
end

function confirm()
	local p = placing
	if not p then
		return
	end
	if not p.ok then
		return UI.toast(p.why or "You can't place it there", UI.RED)
	end
	Remote:FireServer("Place", p.t, p.at, rot)
	local t = p.t
	stopPlacing()
	-- Mayús: seguir colocando la misma tropa (como en TDS)
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
		task.delay(0.15, function()
			if not placing and inMatch() then
				startPlacing(t)
			end
		end)
	end
end

function rotate()
	rot = (rot + math.pi / 2) % (math.pi * 2)
	UI.sound("Rotate")
end

Hn.rotate.Activated:Connect(rotate)
Hn.cancel.Activated:Connect(function()
	stopPlacing()
end)
Hn.place.Activated:Connect(confirm)

---------- Barra de tropas: tu equipo ----------
local cards = {} -- {t, card} en orden
local handKey

local function showTip(t, button)
	if placing or selected then
		return
	end
	local troop, def = TD.Troops[t], Config.Scares[t]
	local lv = Config.troopLevel(player, t)
	local s = TD.stats(t, 1, lv)
	P.tipName.Text = lv > 1 and ("%s  ★%d"):format(def.name, lv) or def.name
	P.tipName.TextColor3 = Kit.color(t):Lerp(WHITE, 0.55)
	P.tipStroke.Color = Kit.color(t)
	P.tipKind.Text = Config.Categories[def.cat].name .. "  ·  " .. Kit.special(s)
	P.tipInfo.Text = troop.info
	P.tipStats.Text = TD.attacks(t) and ("Fear %d  ·  %.2fs  ·  Range %d"):format(s.dmg, s.cd, s.range)
		or (s.kind == "farm" and (Kit.money(s.income) .. " per wave") or ("Range %d"):format(s.range))
	local k = math.max(UI.uiScale.Scale, 0.1)
	tip.Position = UDim2.fromOffset((button.AbsolutePosition.X + button.AbsoluteSize.X / 2) / k, button.AbsolutePosition.Y / k - 10)
	P.tipOwner = button
	tip.Visible = true
end

-- Hueco de la barra (como en TDS): fondo gris, borde y tecla del color de su categoría, el modelo y el precio en verde
local function slot(t, i)
	local c = Kit.color(t)
	local b = corner(new("TextButton", {Size = UDim2.fromOffset(SLOT.X, SLOT.Y), BackgroundColor3 = WHITE, BorderSizePixel = 0, AutoButtonColor = false, Text = "", LayoutOrder = i, ClipsDescendants = true}, hand), 4)
	new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(62, 62, 70), Color3.fromRGB(26, 26, 31))}, b)
	local st = outline(b, c, 2, 0)
	local pop = Kit.press(b)
	local tint = corner(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = c, BorderSizePixel = 0, ZIndex = 1}, b), 4)
	new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(1, 0.6)}, tint)
	-- (la vista es más grande que la carta y se recorta: el susto la llena, como los retratos de TDS)
	UI.viewport(t, b, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromScale(1.35, 1.35), ZIndex = 2})
	local key = corner(mt({Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 0, BackgroundColor3 = c, TextSize = 12, TextStrokeTransparency = 0.3, Text = tostring(i), Visible = not TOUCH, ZIndex = 5}, b, Wt.BLACK), 3)
	local chip = mt({AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -3, 0, 1), Size = UDim2.fromOffset(34, 13), TextSize = 10, TextXAlignment = RIGHT, Text = "", ZIndex = 5}, b, Wt.BOLD)
	local shade = corner(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0.5, BorderSizePixel = 0, Visible = false, ZIndex = 4}, b), 4)
	local price = mt({AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 1), Size = UDim2.new(1, 6, 0, 18), TextSize = 14, TextColor3 = Sty.PRICE, Text = Kit.money(TD.Troops[t].cost), ZIndex = 6}, b, Wt.BLACK)
	-- destello al llegar al dinero
	local glow = corner(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 7}, b), 4)
	return {button = b, stroke = st, color = c, key = key, chip = chip, price = price, shade = shade, pop = pop, glow = glow}
end

local function refreshHand()
	local loadout = TD.loadout(player)
	local key = table.concat(loadout, ",")
	if key == handKey then
		return
	end
	handKey = key
	tip.Visible = false
	tip.Parent = hud
	for _, c in hand:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	table.clear(cards)
	for i = 1, TD.SLOTS do
		local t = loadout[i]
		if t then
			local c = slot(t, i)
			c.button.Activated:Connect(function()
				toggle(t)
			end)
			c.button.MouseEnter:Connect(function()
				showTip(t, c.button)
			end)
			c.button.MouseLeave:Connect(function()
				if P.tipOwner == c.button then
					tip.Visible = false
				end
			end)
			cards[i] = {t = t, card = c}
		else
			local e = corner(new("Frame", {Size = UDim2.fromOffset(SLOT.X, SLOT.Y), BackgroundColor3 = Color3.fromRGB(40, 40, 46), BackgroundTransparency = 0.45, BorderSizePixel = 0, LayoutOrder = i}, hand), 4)
			outline(e, BLACK, 1.5, 0.5)
			mt({Size = UDim2.fromScale(1, 1), TextSize = 12, TextColor3 = Color3.fromRGB(170, 170, 180), TextStrokeTransparency = 0.5, Text = #loadout == 0 and "No troops" or tostring(i)}, e, Wt.BOLD)
		end
	end
end

local function updateHand()
	local cash = player:GetAttribute("TDCash") or 0
	local n, total = counts()
	for _, e in cards do
		local c, t = e.card, e.t
		local cost, lim = TD.Troops[t].cost, TD.limit(t)
		local placed = n[t] or 0
		local full = placed >= lim or total >= TD.MAX_UNITS
		c.chip.Text = placed > 0 and (placed .. "/" .. lim) or ""
		c.chip.TextColor3 = placed >= lim and UI.RED or WHITE
		c.price.TextColor3 = cash >= cost and Sty.PRICE or Color3.fromRGB(255, 84, 96)
		local can = cash >= cost and not full
		c.shade.Visible = not can
		c.shade.Size = UDim2.fromScale(1, full and 1 or math.clamp(1 - cash / cost, 0, 1))
		-- te acaba de llegar el dinero: destello y saltito
		if can and c.can == false then
			c.glow.BackgroundTransparency = 0.6
			tween(c.glow, 0.45, {BackgroundTransparency = 1})
			c.pop.Scale = 1.14
			tween(c.pop, 0.35, {Scale = 1}, Enum.EasingStyle.Back)
		end
		c.can = can
		local active = placing and placing.t == t
		c.stroke.Color = active and WHITE or c.color
		c.stroke.Thickness = active and 3 or 2
	end
	unitsText.Text = ("%d / %d"):format(total, TD.MAX_UNITS)
	unitsText.TextColor3 = total >= TD.MAX_UNITS and Color3.fromRGB(255, 120, 120) or WHITE
end

---------- Vista táctica: cámara cenital (WASD / arrastrar para mover, rueda / pellizco para acercar) ----------
local tac = {on = false, focus = Vector3.zero, zoom = 95}

function setTactical(on)
	if on == tac.on then
		return
	end
	tac.on = on
	local cam = workspace.CurrentCamera
	if on then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		tac.focus = root and root.Position or map:GetAttribute("Origin").Position
		tac.zoom = 70
		cam.CameraType = Enum.CameraType.Scriptable
		UI.lockMovement(true)
		UI.sound("Whoosh")
	else
		cam.CameraType = Enum.CameraType.Custom
		UI.lockMovement(false)
	end
	mapStroke.Color, mapStroke.Transparency, mapStroke.Thickness = on and UI.ORANGE or BLACK, on and 0 or 0.4, on and 2.5 or 1.5
end

local function panBy(dx, dz)
	local o, b = map:GetAttribute("Origin"), map:GetAttribute("Bounds")
	local f = tac.focus + Vector3.new(dx, 0, dz)
	local lp = o:PointToObjectSpace(f)
	tac.focus = o:PointToWorldSpace(Vector3.new(math.clamp(lp.X, b.Min.X, b.Max.X), lp.Y, math.clamp(lp.Z, b.Min.Y, b.Max.Y)))
end

mapBtn.Activated:Connect(function()
	setTactical(not tac.on)
end)

local pinchZoom
UserInputService.TouchPinch:Connect(function(_, scale, _, st, processed)
	if not tac.on or processed then
		return
	end
	if st == Enum.UserInputState.Begin then
		pinchZoom = tac.zoom
	end
	tac.zoom = math.clamp((pinchZoom or tac.zoom) / math.max(scale, 0.1), 35, 170)
end)
local lastPan
UserInputService.TouchPan:Connect(function(_, total, _, st, processed)
	if not tac.on or processed or placing then
		return
	end
	if st == Enum.UserInputState.Begin then
		lastPan = total
	end
	local d = total - (lastPan or total)
	lastPan = total
	panBy(-d.X * tac.zoom * 0.004, -d.Y * tac.zoom * 0.004)
end)

---------- Entrada ----------
UserInputService.InputBegan:Connect(function(input, processed)
	if troopsOpen() or not inMatch() then
		return
	end
	local kind = input.UserInputType
	if kind == Enum.UserInputType.MouseButton1 and not processed then
		if placing then
			confirm()
		else
			local hit = cast(pointerRay(), {player.Character})
			selectTower(pickTower(hit))
		end
	elseif kind == Enum.UserInputType.MouseButton2 and placing then
		stopPlacing()
	elseif kind == Enum.UserInputType.Keyboard and not processed then
		local k = input.KeyCode
		if k == Enum.KeyCode.R and placing then
			rotate()
		elseif k == Enum.KeyCode.Q or k == Enum.KeyCode.Backspace then
			stopPlacing()
			selectTower(nil)
		elseif k == Enum.KeyCode.E then
			upgrade()
		elseif k == Enum.KeyCode.X then
			sell()
		elseif k == Enum.KeyCode.T then
			cycleTarget()
		elseif k == Enum.KeyCode.V then
			setTactical(not tac.on)
		else
			local i = table.find(KEYS, k)
			if i and cards[i] then
				toggle(cards[i].t)
			end
		end
	end
end)

UserInputService.InputChanged:Connect(function(input, processed)
	if not tac.on then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
		tac.zoom = math.clamp(tac.zoom - input.Position.Z * 9, 35, 170)
	elseif input.UserInputType == Enum.UserInputType.MouseMovement and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
		panBy(-input.Delta.X * tac.zoom * 0.004, -input.Delta.Y * tac.zoom * 0.004)
	end
end)

-- Móvil: tocar el mundo mueve la vista previa (y se confirma con "Place") o selecciona una tropa
UserInputService.TouchTapInWorld:Connect(function(pos, processed)
	if processed or not inMatch() or troopsOpen() then
		return
	end
	if placing then
		pointer = pos
	else
		local hit = cast(workspace.CurrentCamera:ScreenPointToRay(pos.X, pos.Y), {player.Character})
		selectTower(pickTower(hit))
	end
end)

local voted, lastPhase = false, nil -- voted: false, "yes" o "no"
local function castVote(yes)
	if voted then
		return
	end
	voted = yes and "yes" or "no"
	UI.sound("Tab", 1, yes and 1.1 or 0.85)
	Remote:FireServer(yes and "Skip" or "SkipNo")
	Vt.pop.Scale = 0.94
	tween(Vt.pop, 0.25, {Scale = 1}, Enum.EasingStyle.Back)
end
Vt.ready.Activated:Connect(function()
	castVote(true)
end)
Vt.yes.Activated:Connect(function()
	castVote(true)
end)
Vt.no.Activated:Connect(function()
	castVote(false)
end)
speedBtn.Activated:Connect(function()
	-- solo el anfitrión (el que creó el lobby) cambia la velocidad
	if (state:GetAttribute("Host") or 0) ~= player.UserId then
		UI.sound("Tab", 1, 0.7)
		return UI.toast("Only the host can change the speed", UI.RED)
	end
	Remote:FireServer("Speed")
end)

-- Dinero: el contador corre hasta la cifra nueva (RenderStepped) y junto a los billetes sale "+$25" o "-$300"
local shownCash, lastCash = 0, nil
P.pendCash, P.pendAt = 0, 0
local function cashDelta(d)
	local l = mt({
		Position = UDim2.fromOffset(44, -4), Size = UDim2.fromOffset(0, 20), AutomaticSize = AUTO_X, TextSize = 16, TextXAlignment = LEFT,
		TextColor3 = d > 0 and Sty.PRICE or Color3.fromRGB(255, 84, 96), Text = (d > 0 and "+" or "-") .. Kit.money(math.abs(d)), ZIndex = 5,
	}, wallet, Wt.BLACK)
	tween(l, 0.9, {Position = UDim2.fromOffset(44, -26)})
	task.delay(0.5, function()
		tween(l, 0.4, {TextTransparency = 1, TextStrokeTransparency = 1})
	end)
	Debris:AddItem(l, 1)
end
player:GetAttributeChangedSignal("TDCash"):Connect(function()
	local v = player:GetAttribute("TDCash")
	if not v then
		lastCash = nil
		return
	end
	if lastCash and v ~= lastCash then
		-- (las bajas llegan de una en una: se juntan en un solo "+$" cada 0.3 s)
		P.pendCash += v - lastCash
		if os.clock() - P.pendAt > 0.3 then
			P.pendAt = os.clock()
			task.delay(0.3, function()
				if P.pendCash ~= 0 then
					cashDelta(P.pendCash)
					P.pendCash = 0
				end
			end)
		end
		if v > lastCash then
			cashPop.Scale = 1.25
			tween(cashPop, 0.35, {Scale = 1}, Enum.EasingStyle.Back)
		end
	else
		shownCash = 0 -- (al empezar la partida, el contador sube desde cero)
	end
	lastCash = v
end)

---------- Avisos del servidor ----------
local coinAt = 0
function shake()
	for i, dx in {-10, 8, -6, 4, 0} do
		task.delay(i * 0.04, function()
			top.Position = topPos + UDim2.fromOffset(dx, 0)
		end)
	end
	P.heartPop.Scale = 1.4
	tween(P.heartPop, 0.4, {Scale = 1}, Enum.EasingStyle.Back)
end

Remote.OnClientEvent:Connect(function(kind, a, b, c, d, e)
	if kind == "Hit" then
		onHit(a, b, c, d)
	elseif kind == "Kill" then
		if near(a, 150) then
			cashFloater(a, tostring(b))
		end
		if os.clock() - coinAt > 0.08 then
			coinAt = os.clock()
			UI.sound("Coin", 0.5)
		end
		if c then
			Musica.boss = false
			ring(a, 18, UI.GOLD, 0.9)
			burst(a + Vector3.new(0, 3, 0), UI.GOLD, 12)
			sound3D("Boom", a, 0.8)
			showBanner("BOSS SCARED AWAY!", ("+%s for everyone"):format(Kit.money(b)), UI.GOLD, 2.4)
			UI.sound("Win")
			UI.confetti(90)
		end
	elseif kind == "Leak" then
		Mj.once("leak")
		UI.flash(UI.RED, 0.6, 0.5)
		UI.sound("Thud")
		shake()
		if near(b, 150) then
			floater(b, "-" .. a .. " HP", UI.RED)
		end
	elseif kind == "Wave" then
		if b then
			showBanner("FINAL WAVE", "Survive this one and the house is yours!", UI.RED, 3)
			UI.sound("Thunder")
		else
			showBanner("WAVE " .. a, "Ghost hunters incoming!", WHITE, 1.8)
			UI.sound("Sting")
		end
		P.wavePop.Scale = 1.4
		tween(P.wavePop, 0.45, {Scale = 1}, Enum.EasingStyle.Back)
		if b then
			Mj.say("final")
		elseif a == 1 then
			Mj.say("first")
		elseif a % 5 == 0 then
			Mj.say("milestone", a)
		end
	elseif kind == "Cleared" then
		-- recompensa de la oleada y, si se despejó a tiempo, el extra (como el "Wave Reward" de TDS)
		local lines = {{"cash", ("Wave Reward: %s"):format(Kit.money(b))}}
		if (e or 0) > 0 then
			table.insert(lines, {"cash", ("Wave Clear Bonus: %s"):format(Kit.money(e))})
		end
		if (c or 0) > 0 then
			table.insert(lines, {"coin", ("+%d coins"):format(c), UI.GOLD})
		end
		if d then -- se acabó el tiempo: la siguiente llega ya
			table.insert(lines, 1, {"hourglass", "Time's up! Next wave incoming", UI.ORANGE})
		else
			UI.confetti(30)
		end
		showRewards(lines)
		UI.sound("Success")
	elseif kind == "ShieldBreak" then
		if near(a, 150) then
			ring(a, 5, SHIELD, 0.45)
			floater(a, "SHIELD BROKEN!", SHIELD)
		end
	elseif kind == "Boss" then
		bossModel, bossKind = a, a and a:GetAttribute("Kind")
		Musica.boss = a ~= nil -- su propia música mientras esté
		P.bossName.Text = b
		P.bossPop.Scale = 1.7
		tween(P.bossPop, 0.5, {Scale = 1}, Enum.EasingStyle.Back)
		En.bossIntro(a, b)
		task.delay(2.6, Mj.boss, b)
	elseif kind == "Placed" then
		if a and a.Parent then
			ring(a:GetPivot().Position, 4, Kit.color(a:GetAttribute("Type")), 0.4)
		end
		if b == player then
			UI.sound("Place")
		end
	elseif kind == "Upgraded" then
		if a and a.Parent then
			local pos = a:GetPivot().Position
			if a:GetAttribute("Owner") == player.UserId then
				UI.sound("Sparkle")
				floater(pos, TD.TIERS[b] .. "!", UI.GOLD)
			end
			if a == selected then
				Pn.pop.Scale = 1.06
				tween(Pn.pop, 0.3, {Scale = 1}, Enum.EasingStyle.Back)
			end
		end
	elseif kind == "Sold" then
		ring(a, 3, UI.GOLD, 0.35)
		if c == player then
			UI.sound("Cash")
			cashFloater(a, Kit.money(b))
		end
	elseif kind == "Heal" then
		if near(a, 150) then
			ring(a, b, UI.GREEN, 0.5)
		end
	elseif kind == "Summon" then
		if near(a, 150) then
			ring(a, 6, UI.PURPLE, 0.6)
			burst(a + Vector3.new(0, 3, 0), UI.PURPLE, 6)
		end
	elseif kind == "Drain" then
		-- el Vampiro devuelve vida a la casa
		if near(a, 150) and b and b.Parent then
			bolt(a + Vector3.new(0, 1, 0), b:GetPivot().Position + Vector3.new(0, 4, 0), Color3.fromRGB(255, 40, 70))
			floater(b:GetPivot().Position, "+" .. c .. " ❤", Color3.fromRGB(255, 90, 110))
		end
		P.heartPop.Scale = 1.3
		tween(P.heartPop, 0.4, {Scale = 1}, Enum.EasingStyle.Back)
	elseif kind == "Income" then
		if a and a.Parent then
			local pos = a:GetPivot().Position
			ring(pos, 4, UI.GOLD, 0.5)
			burst(pos + Vector3.new(0, 4, 0), Color3.fromRGB(190, 140, 255), 4)
			if c == player then
				cashFloater(pos, Kit.money(b))
				UI.sound("Cash")
			end
		end
	elseif kind == "Cleanse" then
		if near(a, 150) then
			ring(a, b, Color3.fromRGB(255, 240, 180), 0.55)
			floater(a, "CLEANSED!", Color3.fromRGB(255, 240, 180))
		end
	elseif kind == "Barrier" then
		if near(a, 150) then
			ring(a, b, SHIELD, 0.55)
			shockwave(a, b * 0.5, SHIELD)
			floater(a, "BARRIER!", SHIELD)
		end
	elseif kind == "Blink" then
		if near(a, 150) then
			burst(a + Vector3.new(0, 2, 0), UI.PURPLE, 5)
			burst(b + Vector3.new(0, 2, 0), UI.PURPLE, 5)
			bolt(a + Vector3.new(0, 2, 0), b + Vector3.new(0, 2, 0), UI.PURPLE)
		end
	elseif kind == "Inspire" then
		if near(a, 150) then
			ring(a, b, UI.GREEN, 0.6)
			floater(a, "🎵 INSPIRED!", UI.GREEN)
		end
	elseif kind == "Disable" then
		if near(a, 150) then
			ring(a, b, Color3.fromRGB(255, 230, 120), 0.6)
			shockwave(a, b * 0.6, Color3.fromRGB(255, 230, 140))
			floater(a, "TROOPS STUNNED!", UI.ORANGE)
			UI.flash(Color3.fromRGB(255, 240, 180), 0.85, 0.35)
		end
	elseif kind == "Speed" then
		UI.toast(("%s set the speed to x%d"):format(b, a), UI.GOLD)
	elseif kind == "Error" then
		UI.toast(tostring(a), UI.RED)
	elseif kind == "End" then
		-- remate musical (la música calla para que suene solo); primero habla el comandante; luego, los resultados
		Musica.boss = false
		Musica.quiet(7)
		UI.duck(0.2, 3)
		if a.won then
			UI.sound("Win")
			task.delay(0.25, UI.sound, "Jingle")
		else
			UI.sound("Faint")
			task.delay(0.3, UI.sound, "Deep")
		end
		Mj.interrupt(a.won and "won" or "lost")
		task.delay(2.6, showResults, a)
	end
end)

---------- Cada fotograma: vista previa, cámara táctica y animación de las tropas ----------
RunService.RenderStepped:Connect(function(dt)
	local cashNow = player:GetAttribute("TDCash")
	if cashNow then
		shownCash += (cashNow - shownCash) * math.min(1, dt * 9)
		if math.abs(cashNow - shownCash) < 1 then
			shownCash = cashNow
		end
		cashText.Text = Kit.money(math.floor(shownCash + 0.5))
	end
	-- el voto late mientras te toca votar
	if Vt.panel.Visible and P.voteLive and os.clock() > (P.votePopUntil or 0) then
		Vt.pop.Scale = 1 + 0.025 * math.sin(os.clock() * 6)
	end
	if placing then
		updatePlacing()
	end
	En.hover()
	if tac.on then
		if not UserInputService:GetFocusedTextBox() then
			local x, z = 0, 0
			for key, d in {[Enum.KeyCode.W] = Vector2.new(0, -1), [Enum.KeyCode.S] = Vector2.new(0, 1), [Enum.KeyCode.A] = Vector2.new(-1, 0), [Enum.KeyCode.D] = Vector2.new(1, 0)} do
				if UserInputService:IsKeyDown(key) then
					x += d.X
					z += d.Y
				end
			end
			panBy(x * dt * tac.zoom, z * dt * tac.zoom)
		end
		local cam = workspace.CurrentCamera
		local goal = CFrame.lookAt(tac.focus + Vector3.new(0, tac.zoom, tac.zoom * 0.5), tac.focus)
		cam.CFrame = cam.CFrame:Lerp(goal, math.min(1, dt * 10))
	end
	local now = os.clock()
	for model, a in anims do
		if not model.Parent then
			anims[model] = nil
			Tw.restoreGrass(a)
		elseif a.t0 or a.pop or a.dirty or ((a.idle or a.hasOrbit) and near(a.base.Position, 140)) then
			a.dirty = false
			Tw.frame(model, a, now, dt)
		end
	end
end)

---------- Cada 0.1 s: marcador, jugadores, barra de tropas y panel ----------
local HP_COLORS = {
	{0.6, Color3.fromRGB(78, 224, 104), Color3.fromRGB(28, 158, 60)},
	{0.3, Color3.fromRGB(255, 214, 72), Color3.fromRGB(214, 140, 24)},
	{0, Color3.fromRGB(255, 96, 104), Color3.fromRGB(196, 32, 52)},
}
local toastsHome -- (los avisos bajan un poco en partida para no tapar la lista de jugadores)
local was = false
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.1 then
		return
	end
	acc = 0
	local on = inMatch()
	if on ~= was then
		was = on
		hud.Visible = on
		results.Visible = false
		UI.menu.Visible = not on
		UI.moneyPill.Visible = not on -- en partida manda el dinero de la partida (abajo)
		if UI.currency then
			UI.currency.Visible = not on -- (y el nivel del jugador no se cruza con el HUD)
		end
		local toasts = UI.gui:FindFirstChild("Toasts")
		if toasts then
			toastsHome = toastsHome or toasts.Position
			toasts.Position = on and toastsHome + UDim2.fromOffset(0, 90) or toastsHome
		end
		if on then
			UI.setHint(nil)
			Mj.reset()
			task.delay(1.5, Mj.say, "intro")
			handKey, bossKind = nil, nil
			P.hpLast = nil
			clearRewards()
		else
			stopPlacing()
			selectTower(nil)
			setTactical(false)
			bossModel = nil
			Musica.boss = false
		end
	end
	if not on then
		return
	end
	refreshHand()
	updateHand()
	refreshTeam()

	local phase = state:GetAttribute("Phase")
	if not phase then
		return -- (aún no ha llegado del servidor)
	end
	local wave = state:GetAttribute("Wave") or 0
	local waves = state:GetAttribute("Waves") or TD.WAVES
	local nextAt = state:GetAttribute("NextAt") or 0
	local left = math.max(0, math.ceil(nextAt - workspace:GetServerTimeNow()))
	local waiting = phase == "setup" or phase == "break"
	local endless = TD.isEndless(waves)
	waveText.Text = wave > 0 and (endless and ("%d / ∞"):format(wave) or ("%d / %d"):format(wave, waves)) or "--"
	timeText.Text = (phase == "wave" and nextAt <= 0) and "--:--" or ("%02d:%02d"):format(left // 60, left % 60)
	timeText.TextColor3 = (waiting and left <= 5) and UI.GOLD or WHITE
	if phase == "setup" then
		status.Text = "Place your troops before the ghost hunters arrive!"
	elseif phase == "break" then
		status.Text = '<font color="#6EEC82">Wave cleared!</font>  Next wave soon'
	elseif phase == "wave" then
		local n = state:GetAttribute("Left") or 0
		local tag = endless and (wave % 10 == 0 and '<font color="#FF5A6E">BOSS WAVE</font>  ·  ' or "") or (wave >= waves and '<font color="#FF5A6E">FINAL WAVE</font>  ·  ' or "")
		status.Text = tag .. (n == 1 and "1 hunter left" or ("%d hunters left"):format(n))
	else
		status.Text = (phase == "won" and "Victory!" or "Defeat") .. "  ·  back to the lobby in " .. clock(left)
	end
	local hp, max = state:GetAttribute("HP") or 0, state:GetAttribute("MaxHP") or TD.BASE_HP
	local f = math.clamp(hp / max, 0, 1)
	if f ~= P.hpLast then
		local w = UDim2.fromScale(math.max(f, 0.001), 1)
		if P.hpLast and f < P.hpLast then
			-- el trozo perdido se queda un momento en claro y luego se encoge
			P.hpLoss.Size = UDim2.fromScale(P.hpLast, 1)
			task.delay(0.35, function()
				tween(P.hpLoss, 0.55, {Size = w})
			end)
		else
			P.hpLoss.Size = w
		end
		P.hpLast = f
		tween(P.hpFill, 0.25, {Size = w})
	end
	for _, hc in HP_COLORS do
		if f > hc[1] or hc[1] == 0 then
			P.hpGrad.Color = ColorSequence.new(hc[2], hc[3])
			break
		end
	end
	P.hpText.Text = hp .. " / " .. max
	heart.ImageColor3 = f < 0.3 and (math.floor(os.clock() * 4) % 2 == 0 and Color3.fromRGB(255, 120, 120) or WHITE) or WHITE

	-- votos: "Ready?" en la preparación y "Skip wave?" entre oleadas o en cuanto termina de salir la oleada
	-- (CanSkip; con Auto skip votas solo)
	local canSkip = phase == "wave" and state:GetAttribute("CanSkip") == true
	local voteKey = phase .. wave
	if voteKey ~= lastPhase then
		lastPhase, voted = voteKey, false
	end
	local auto = player:GetAttribute("TDAuto") == true
	autoLabel.Text = auto and "Auto: ON" or "Auto skip"
	autoLabel.TextColor3 = auto and UI.GOLD or WHITE
	autoIcon.ImageColor3 = auto and WHITE or Color3.fromRGB(165, 165, 175)
	local need = state:GetAttribute("VotesNeed") or 1
	local votes = state:GetAttribute("Votes") or 0
	local no = state:GetAttribute("VotesNo") or 0
	local mine = voted or (auto and (phase == "break" or canSkip) and "yes")
	local showVote = (waiting or canSkip) and not (need <= 1 and mine == "yes")
	if showVote and not Vt.panel.Visible then
		Vt.pop.Scale = 0.5
		tween(Vt.pop, 0.35, {Scale = 1}, Enum.EasingStyle.Back)
		P.votePopUntil = os.clock() + 0.4
		if canSkip then
			UI.sound("Tab", 1, 1.25) -- (en plena oleada no hay "Wave cleared!" que lo anuncie)
		end
	end
	Vt.panel.Visible = showVote
	P.voteLive = not mine
	local setup = phase == "setup"
	Vt.title.Text = setup and "Ready?" or "Skip wave?"
	Vt.sub.Text = ("%d/%d required"):format(votes, need)
	if canSkip then
		-- (la línea de estado se oculta con el voto: que no se pierda cuántos quedan)
		local n = state:GetAttribute("Left") or 0
		Vt.sub.Text ..= n == 1 and "  ·  1 left" or ("  ·  %d left"):format(n)
	end
	Vt.ready.Visible = setup
	Vt.yes.Visible, Vt.no.Visible = not setup, not setup
	Vt.yesCount.Text, Vt.noCount.Text = tostring(votes), tostring(no)
	Vt.face.Image = faceOf(player.UserId)
	Vt.readyDim.BackgroundTransparency = mine and 0.5 or 1
	Vt.yesDim.BackgroundTransparency = mine == "no" and 0.5 or 1
	Vt.noDim.BackgroundTransparency = mine == "yes" and 0.5 or 1
	Vt.readyLabel.Text = mine and "WAITING" or "READY"

	local n = math.max(1, state:GetAttribute("Players") or 1)
	local d = state:GetAttribute("Diff") or "Normal"
	local dc = TD.DIFFS[d] and TD.DIFFS[d].color or UI.GOLD
	diffChip.Text = string.upper(d)
	diffChip.BackgroundColor3 = dc:Lerp(BLACK, 0.2)
	teamTitle.Text = ("PLAYERS (%d/%d)"):format(n, Config.LOBBY_MAX or 8)
	local speed = state:GetAttribute("Speed") or 1
	speedText.Text = "x" .. speed
	speedText.TextColor3 = speed > 1 and UI.GOLD or WHITE
	local speedHost = (state:GetAttribute("Host") or 0) == player.UserId
	speedText.TextTransparency = speedHost and 0 or 0.5
	speedIcon.ImageTransparency = speedHost and 0 or 0.55
	speedBtn.BackgroundTransparency = speedHost and 0.12 or 0.45
	speedLock.Visible = not speedHost
	setHicon(speedIcon, speed > 1 and "fast" or "chevron")
	speedStroke.Color, speedStroke.Transparency, speedStroke.Thickness = speed > 1 and UI.GOLD or BLACK, speed > 1 and 0 or 0.4, speed > 1 and 2 or 1.5
	speedBtn.Visible = phase ~= "won" and phase ~= "lost"
	-- con los resultados en pantalla, fuera lo demás
	if results.Visible and phase == "setup" then
		-- (votaron "Play Again": empieza otra partida en el mismo mapa)
		results.Visible = false
		Mj.reset()
		task.delay(1, Mj.say, "intro")
	end
	Rs.update()
	if f <= 0.4 and f > 0 and phase == "wave" and not Mj.lowHp then
		Mj.lowHp = true
		Mj.say("low")
	end
	bar.Visible, team.Visible, side.Visible, top.Visible = not results.Visible, not results.Visible, not results.Visible, not results.Visible

	local bossOn = bossModel and bossModel.Parent and CollectionService:HasTag(bossModel, "TDEnemy")
	Musica.boss = bossOn or false -- (también si el jefe llega a la casa en vez de huir)
	boss.Visible = (bossOn and not waiting and not results.Visible) or false
	if bossOn then
		local bhp, bmax = bossModel:GetAttribute("HP") or 0, math.max(1, bossModel:GetAttribute("MaxHP") or 1)
		local sh = (bossModel:GetAttribute("Shield") or 0) / 100
		tween(P.bossFill, 0.2, {Size = UDim2.fromScale(math.clamp(bhp / bmax, 0, 1), 1)})
		tween(P.bossShield, 0.2, {Size = UDim2.fromScale(sh, 1)})
		P.bossPct.Text = (sh > 0 and ("SHIELD %d%%  ·  "):format(sh * 100) or "") .. ("%s / %s"):format(Kit.money(bhp):sub(2), Kit.money(bmax):sub(2))
	end

	-- la línea de estado solo cuando no hay voto ni jefe (como en TDS, arriba no se amontona nada)
	status.Visible = not (Vt.panel.Visible or boss.Visible)
	-- las recompensas, justo debajo de lo que haya arriba (con alturas fijas: así no bailan con el saltito del voto)
	local below = topPos.Y.Offset + 54 + 7
	if status.Visible then
		below += 15 + 7
	end
	if boss.Visible then
		below += 52 + 7
	end
	if Vt.panel.Visible then
		below += (setup and 64 or 78) + 7
	end
	rewards.Position = UDim2.new(0.5, 0, 0, below + 8)

	if selected then
		if selected.Parent then
			refreshPanel()
		else
			selectTower(nil)
		end
	end
end)
