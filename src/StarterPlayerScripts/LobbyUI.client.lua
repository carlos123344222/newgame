-- Interfaz de los mini lobbies del Tower Defense:
-- · Pantallas de los pabellones (como en los mejores TD): miniatura del mapa, su nombre, la dificultad con sus
--   calaveras, la recompensa, los jugadores y el estado; cuando el lobby cambia de mapa, un destello.
-- · Panel al entrar: los jugadores, la cuenta atrás, el mapa y la dificultad del lobby, las oleadas (las elige el
--   anfitrión) y los botones "Leave" y "Start now" (solo el anfitrión).
-- · Pantalla de viaje: al ir a la partida (o volver), con el mapa y la dificultad; viaja con el jugador
--   (TeleportService:SetTeleportGui) y ReplicatedFirst.LlegadaTD la quita al llegar.
-- Los datos salen de los atributos de cada lobby (TowerDefenseLobbies) y de Lobby/LobbySlot de cada jugador.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")

local Config = require(RS:WaitForChild("Config"))
local TD = require(RS:WaitForChild("TowerDefense"))
local LobbyRemote = RS:WaitForChild("LobbyRemote")
local UI = require(script.Parent:WaitForChild("UI"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local folder = workspace:WaitForChild("Mapa"):WaitForChild("TowerDefense"):WaitForChild("Lobbies")
local new = UI.new
local MAX = Config.LOBBY_MAX
local LEFT = Enum.TextXAlignment.Left
local MUTED = UI.MUTED
local ACCENT = Color3.fromRGB(150, 90, 240)
local BLACK = Color3.new(0, 0, 0)
local WAVE_NAMES = {[5] = "Quick", [10] = "Classic", [20] = "Epic"}
local amHost = false

local function corner(o, r)
	new("UICorner", {CornerRadius = typeof(r) == "UDim" and r or UDim.new(0, r)}, o)
	return o
end
local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
-- Calaveras de la dificultad: las de su nivel encendidas, el resto apagadas
local function skulls(diff)
	local tier = TD.DIFFS[diff] and TD.DIFFS[diff].tier or 1
	return string.rep("💀", tier) .. '<font transparency="0.75">' .. string.rep("💀", #TD.DIFF_ORDER - tier) .. "</font>"
end
local function mapMeta(info)
	return ("%s path  ·  %d hunter types"):format(info.length or "?", info.hunters or 0)
end
local function clock(s)
	return ("%d:%02d"):format(s // 60, s % 60)
end

---------- Panel del lobby (estilo del HUD de partida: el "ascensor" de TDS) ----------
-- Abajo al centro, compacto para que se vea el pabellón: la miniatura del mapa con su nombre y la dificultad; los
-- jugadores (caras, corona del anfitrión); las oleadas (el anfitrión las elige); "Leave" y "Start now". Encima, la
-- cuenta atrás. Cajas oscuras de borde fino y Montserrat blanco con contorno, como la partida y su pantalla de fin.
local Kit = require(script.Parent:WaitForChild("TDKit"))
local MONT = "rbxasset://fonts/families/Montserrat.json"
local INK = Color3.fromRGB(14, 11, 18)
local ICONS = "rbxassetid://129121289352094"
local RECT = {hourglass = Vector2.new(256, 0), players = Vector2.new(512, 128), crown = Vector2.new(0, 384), coin = Vector2.new(640, 128), skull = Vector2.new(640, 256), leave = Vector2.new(384, 128), fast = Vector2.new(256, 128)}
local Lb = {} -- piezas del panel

local function mt(props, parent, weight)
	props.FontFace = Font.new(MONT, weight or Enum.FontWeight.Bold)
	if props.BackgroundTransparency == nil then
		props.BackgroundTransparency = 1
	end
	props.TextColor3 = props.TextColor3 or UI.WHITE
	if props.TextStrokeTransparency == nil then
		props.TextStrokeTransparency = 0
	end
	props.TextStrokeColor3 = INK
	return new("TextLabel", props, parent)
end
local function hicon(name, props, parent)
	props.BackgroundTransparency = 1
	props.Image = ICONS
	props.ImageRectOffset = RECT[name]
	props.ImageRectSize = Vector2.new(128, 128)
	props.ScaleType = Enum.ScaleType.Fit
	return new("ImageLabel", props, parent)
end
-- caja oscura de borde fino
local function dark(props, parent, r)
	props.BackgroundColor3 = props.BackgroundColor3 or Color3.fromRGB(6, 5, 10)
	if props.BackgroundTransparency == nil then
		props.BackgroundTransparency = 0.15
	end
	props.BorderSizePixel = 0
	local f = corner(new("Frame", props, parent), r or 6)
	new("UIStroke", {Color = Color3.fromRGB(235, 235, 245), Thickness = 1.5, Transparency = 0.35, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, f)
	return f
end
-- botón de degradado con letra gruesa (como "Back to lobby" / "Play Again")
local function gradButton(props, parent, top, bottom, edge, text, size)
	props.BackgroundColor3 = UI.WHITE
	props.AutoButtonColor = false
	props.BorderSizePixel = 0
	props.Text = ""
	local b = corner(new("TextButton", props, parent), 5)
	local g = new("UIGradient", {Rotation = 90, Color = ColorSequence.new(top, bottom)}, b)
	local st = new("UIStroke", {Color = edge, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, b)
	local l = mt({Size = UDim2.fromScale(1, 1), TextSize = size or 22, Text = text, TextStrokeTransparency = 1, ZIndex = (props.ZIndex or 1) + 1}, b, Enum.FontWeight.Heavy)
	new("UIStroke", {Color = INK, Thickness = 2.2, LineJoinMode = Enum.LineJoinMode.Round}, l)
	Kit.press(b)
	return b, l, g, st
end

local panel = new("Frame", {
	Name = "Lobby", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.fromOffset(660, 236),
	BackgroundTransparency = 1, Visible = false, ZIndex = 3,
}, UI.gui)
local pop = new("UIScale", {}, panel)

-- cuenta atrás, encima del panel: reloj de arena + "Starting in 0:23"
Lb.timerBox = dark({AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -8), Size = UDim2.fromOffset(0, 44), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 3}, panel, 22)
new("UIPadding", {PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 18)}, Lb.timerBox)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, Lb.timerBox)
Lb.timerIcon = hicon("hourglass", {Size = UDim2.fromOffset(28, 28), LayoutOrder = 1, ZIndex = 4}, Lb.timerBox)
Lb.timerCap = mt({Size = UDim2.fromOffset(0, 44), AutomaticSize = Enum.AutomaticSize.X, TextSize = 19, Text = "Starting in", LayoutOrder = 2, ZIndex = 4}, Lb.timerBox, Enum.FontWeight.SemiBold)
Lb.timer = mt({Size = UDim2.fromOffset(0, 44), AutomaticSize = Enum.AutomaticSize.X, TextSize = 28, Text = "", LayoutOrder = 3, ZIndex = 4}, Lb.timerBox, Enum.FontWeight.Heavy)
Lb.timerPop = new("UIScale", {}, Lb.timerBox)

-- izquierda: el mapa
Lb.mapCard = corner(new("ImageLabel", {Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(250, 236), BackgroundColor3 = Color3.fromRGB(20, 16, 28), ScaleType = Enum.ScaleType.Crop, Image = "", ZIndex = 3}, panel), 6)
Lb.mapStroke = new("UIStroke", {Color = UI.WHITE, Thickness = 2, Transparency = 0.1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, Lb.mapCard)
do
	local shade = corner(new("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 120), BackgroundColor3 = BLACK, BorderSizePixel = 0, ZIndex = 4}, Lb.mapCard), 6)
	new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(1, 0.05)}, shade)
end
Lb.lobbyTag = mt({Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(120, 18), TextSize = 14, TextXAlignment = LEFT, Text = "", ZIndex = 5}, Lb.mapCard, Enum.FontWeight.Heavy)
Lb.newTag = UI.chip("NEW MAP", UI.RED, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), ZIndex = 6}, Lb.mapCard)
Lb.mapName = mt({Position = UDim2.new(0, 12, 1, -86), Size = UDim2.new(1, -24, 0, 30), TextSize = 25, TextXAlignment = LEFT, TextScaled = true, Text = "", ZIndex = 5}, Lb.mapCard, Enum.FontWeight.Heavy)
new("UITextSizeConstraint", {MaxTextSize = 25}, Lb.mapName)
Lb.mapLine = mt({Position = UDim2.new(0, 12, 1, -56), Size = UDim2.new(1, -24, 0, 16), TextSize = 12, TextXAlignment = LEFT, TextColor3 = Color3.fromRGB(205, 200, 220), Text = "", ZIndex = 5}, Lb.mapCard, Enum.FontWeight.SemiBold)
-- dificultad: pastilla de su color con las calaveras, y lo que paga
Lb.diffPill = corner(new("Frame", {Position = UDim2.new(0, 10, 1, -34), Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = UI.GREEN, BorderSizePixel = 0, ZIndex = 5}, Lb.mapCard), 13)
new("UIStroke", {Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, Lb.diffPill)
new("UIGradient", {Rotation = 90, Color = ColorSequence.new(UI.WHITE, Color3.fromRGB(160, 150, 170))}, Lb.diffPill)
new("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}, Lb.diffPill)
Lb.diffName = mt({Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, TextSize = 15, Text = "", RichText = true, ZIndex = 6}, Lb.diffPill, Enum.FontWeight.Heavy)
-- (lo que paga: arriba a la izquierda, bajo "LOBBY n")
Lb.coins = mt({Position = UDim2.fromOffset(10, 28), Size = UDim2.fromOffset(120, 20), TextSize = 15, TextXAlignment = LEFT, TextColor3 = UI.GOLD, Text = "", ZIndex = 5}, Lb.mapCard, Enum.FontWeight.Heavy)

-- derecha: jugadores, oleadas y botones
Lb.body = dark({Position = UDim2.fromOffset(262, 0), Size = UDim2.new(1, -262, 1, 0), ZIndex = 3}, panel)
Lb.playersCap = mt({Position = UDim2.fromOffset(14, 8), Size = UDim2.fromOffset(200, 20), TextSize = 15, TextXAlignment = LEFT, Text = "", ZIndex = 4}, Lb.body, Enum.FontWeight.Bold)
Lb.hostCap = mt({AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 8), Size = UDim2.fromOffset(200, 20), TextSize = 13, TextXAlignment = RIGHT, TextColor3 = Color3.fromRGB(190, 186, 205), Text = "", ZIndex = 4}, Lb.body, Enum.FontWeight.SemiBold)
Lb.faces = new("Frame", {Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -24, 0, 50), BackgroundTransparency = 1, ZIndex = 4}, Lb.body)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 5), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}, Lb.faces)
Lb.cards = {}
for i = 1, MAX do
	local f = corner(new("ImageLabel", {Size = UDim2.fromOffset(38, 38), BackgroundColor3 = Color3.fromRGB(30, 26, 40), Image = "", LayoutOrder = i, ZIndex = 5}, Lb.faces), UDim.new(1, 0))
	local st = new("UIStroke", {Color = Color3.fromRGB(90, 86, 105), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, f)
	local crown = hicon("crown", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(20, 20), Rotation = 18, Visible = false, ZIndex = 7}, f)
	local plus = mt({Size = UDim2.fromScale(1, 1), TextSize = 20, Text = "+", TextColor3 = Color3.fromRGB(90, 86, 105), TextStrokeTransparency = 1, ZIndex = 6}, f, Enum.FontWeight.Bold)
	local s = new("UIScale", {}, f)
	Lb.cards[i] = {face = f, stroke = st, crown = crown, plus = plus, scale = s}
end
-- oleadas
mt({Position = UDim2.fromOffset(14, 90), Size = UDim2.fromOffset(200, 18), TextSize = 15, TextXAlignment = LEFT, Text = "Waves", ZIndex = 4}, Lb.body, Enum.FontWeight.Bold)
Lb.waveNote = mt({AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 90), Size = UDim2.fromOffset(220, 18), TextSize = 13, TextXAlignment = RIGHT, TextColor3 = Color3.fromRGB(190, 186, 205), Text = "", ZIndex = 4}, Lb.body, Enum.FontWeight.SemiBold)
Lb.waveRow = new("Frame", {Position = UDim2.fromOffset(12, 112), Size = UDim2.new(1, -24, 0, 44), BackgroundTransparency = 1, ZIndex = 4}, Lb.body)
new("UIGridLayout", {CellSize = UDim2.new(1 / #TD.WAVE_OPTIONS, -6, 1, 0), CellPadding = UDim2.fromOffset(8, 0), SortOrder = Enum.SortOrder.LayoutOrder}, Lb.waveRow)
Lb.waves = {}
for i, w in TD.WAVE_OPTIONS do
	local b, l, g, st = gradButton({LayoutOrder = i, ZIndex = 5}, Lb.waveRow, UI.WHITE, UI.WHITE, UI.WHITE, "", 18)
	l.RichText = true
	-- (∞: Modo Infinito, hasta que caiga la casa)
	l.Text = TD.isEndless(w) and '<font size="24">∞</font> <font size="13" weight="600">Endless</font>'
		or ('%d <font size="13" weight="600">%s</font>'):format(w, WAVE_NAMES[w] or "")
	b.Activated:Connect(function()
		if amHost then
			UI.sound("Tab")
			LobbyRemote:FireServer("Set", "waves", w)
		else
			UI.sound("Error", 0.6)
			UI.toast("Only the host can change the waves", UI.GOLD, "crown")
		end
	end)
	Lb.waves[w] = {button = b, label = l, grad = g, stroke = st}
end
-- botones
Lb.leave = gradButton({Position = UDim2.new(0, 12, 1, -62), Size = UDim2.new(0.38, -22, 0, 50), ZIndex = 5}, Lb.body,
	Color3.fromRGB(255, 96, 104), Color3.fromRGB(196, 32, 52), Color3.fromRGB(255, 160, 166), "Leave", 23)
Lb.start, Lb.startLabel = gradButton({AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 1, -62), Size = UDim2.new(0.62, -20, 0, 50), ZIndex = 5}, Lb.body,
	Color3.fromRGB(90, 236, 90), Color3.fromRGB(30, 170, 50), Color3.fromRGB(160, 255, 150), "Start now", 23)
Lb.wait = mt({AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 1, -62), Size = UDim2.new(0.62, -12, 0, 50), TextSize = 15, TextWrapped = true, TextColor3 = Color3.fromRGB(200, 196, 215), Text = "", ZIndex = 5}, Lb.body, Enum.FontWeight.SemiBold)
Lb.leave.Activated:Connect(function()
	LobbyRemote:FireServer("Leave")
end)
Lb.start.Activated:Connect(function()
	UI.sound("Success", 0.6)
	LobbyRemote:FireServer("Start")
end)

---------- Caras (se piden una vez por jugador) ----------
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

---------- Pantallas de los pabellones ----------
local screens = {}
local function buildScreen(m)
	local part = m:WaitForChild("Pantalla", 30)
	part = part and part:WaitForChild("Pantalla", 30)
	if not part or screens[m] or not m.Parent then
		return
	end
	local g = new("SurfaceGui", {
		Name = "PantallaLobby" .. tostring(m:GetAttribute("Id")), Adornee = part, Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 50, LightInfluence = 0, Brightness = 1.4, MaxDistance = 260, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)
	local root = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 6, 18), BorderSizePixel = 0, ClipsDescendants = true}, g)
	local img = new("ImageLabel", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Crop}, root)
	local imgScale = new("UIScale", {}, img)
	-- sombras arriba (para el título) y abajo (para la barra)
	local top = new("Frame", {Size = UDim2.fromScale(1, 0.55), BackgroundColor3 = BLACK, BorderSizePixel = 0}, root)
	new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(0.2, 1)}, top)
	local bottom = new("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.45), BackgroundColor3 = BLACK, BorderSizePixel = 0}, root)
	new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(1, 0.15)}, bottom)
	-- calaveras, título y dificultad
	local sk = new("TextLabel", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.new(1, -40, 0, 34), BackgroundTransparency = 1, Font = UI.FONT, TextSize = 30, RichText = true, Text = ""}, root)
	local title = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 92), Size = UDim2.new(1, -40, 0, 76), BackgroundTransparency = 1, Font = UI.TITLE,
		TextScaled = true, TextColor3 = UI.WHITE, Text = "",
	}, root)
	new("UITextSizeConstraint", {MaxTextSize = 70}, title)
	new("UIStroke", {Color = Color3.fromRGB(20, 8, 30), Thickness = 5}, title)
	local titlePop = new("UIScale", {}, title)
	local pill = corner(new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 136), Size = UDim2.fromOffset(0, 46), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UI.GREEN, Font = UI.TITLE, TextSize = 36, TextColor3 = UI.WHITE, Text = "",
	}, root), 23)
	new("UIPadding", {PaddingLeft = UDim.new(0, 22), PaddingRight = UDim.new(0, 22), PaddingTop = UDim.new(0, 4)}, pill)
	new("UIStroke", {Color = Color3.fromRGB(20, 8, 30), Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, pill)
	new("UIStroke", {Color = Color3.fromRGB(20, 8, 30), Thickness = 3}, pill)
	new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 160, 180))}, pill)
	-- recompensa (arriba a la izquierda) y el próximo cambio de mapa (arriba a la derecha)
	local reward = UI.chip("", UI.GOLD, {Position = UDim2.fromOffset(16, 16), TextSize = 22, Size = UDim2.fromOffset(0, 36), TextColor3 = Color3.fromRGB(40, 24, 6), TextStrokeTransparency = 1}, root)
	local nextMap = UI.chip("", Color3.fromRGB(60, 40, 90), {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16), TextSize = 20, Size = UDim2.fromOffset(0, 36)}, root)
	local isNew = UI.chip("✨ NEW MAP", UI.RED, {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 22, 1, -86), TextSize = 22, Size = UDim2.fromOffset(0, 34)}, root)
	-- barra de estado
	local bar = corner(new("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.new(1, -32, 0, 60), BackgroundColor3 = UI.GREEN}, root), 18)
	new("UIStroke", {Color = Color3.fromRGB(20, 8, 30), Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, bar)
	new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 140, 165))}, bar)
	local fill = corner(new("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.75, BorderSizePixel = 0}, bar), 18)
	local status = new("TextLabel", {Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -150, 1, 0), BackgroundTransparency = 1, Font = UI.TITLE, TextSize = 30, TextColor3 = UI.WHITE, TextXAlignment = LEFT, Text = ""}, bar)
	new("UIStroke", {Color = Color3.fromRGB(20, 8, 30), Thickness = 3}, status)
	local count = new("TextLabel", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 0), Size = UDim2.new(0, 120, 1, 0), BackgroundTransparency = 1, Font = UI.TITLE, TextSize = 34, TextColor3 = UI.WHITE, TextXAlignment = Enum.TextXAlignment.Right, Text = ""}, bar)
	new("UIStroke", {Color = Color3.fromRGB(20, 8, 30), Thickness = 3}, count)
	-- destello al cambiar de mapa
	local flash = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 10}, root)
	local s = {gui = g, model = m, borde = m.Pantalla:FindFirstChild("Borde"), img = img, imgScale = imgScale, sk = sk, title = title, titlePop = titlePop, pill = pill, reward = reward,
		nextMap = nextMap, isNew = isNew, bar = bar, fill = fill, status = status, count = count, flash = flash}
	screens[m] = s
	return s
end

local function near(m)
	local cam = workspace.CurrentCamera
	return cam and (cam.CFrame.Position - m:GetPivot().Position).Magnitude < 90
end

local function updateScreen(s, t)
	local m = s.model
	local mapId, diff = m:GetAttribute("Map"), m:GetAttribute("Diff")
	local info, d = TD.mapInfo(mapId or ""), TD.DIFFS[diff or ""]
	if not (info and d) then
		return
	end
	local key = mapId .. diff
	if s.key ~= key then
		local first = s.key == nil
		s.key = key
		s.img.Image = info.image or ""
		s.title.Text = info.name
		s.pill.Text = string.upper(diff)
		s.pill.BackgroundColor3 = d.color
		s.sk.Text = skulls(diff)
		s.reward.Text = ("x%s COINS"):format(tostring(d.coins))
		s.isNew.Visible = info.new == true
		if s.borde then
			s.borde.Color = d.color
		end
		if not first then
			-- ¡mapa nuevo!: destello, el título salta y la imagen se acerca despacio
			s.flash.BackgroundTransparency = 0.1
			tween(s.flash, 0.6, {BackgroundTransparency = 1})
			s.titlePop.Scale = 1.35
			tween(s.titlePop, 0.5, {Scale = 1}, Enum.EasingStyle.Back)
			s.imgScale.Scale = 1.12
			tween(s.imgScale, 1.2, {Scale = 1})
			if near(m) then
				UI.sound("Swoosh", 0.5)
			end
		end
	end
	local state = m:GetAttribute("State") or "Open"
	local n = m:GetAttribute("Count") or 0
	local deadline = m:GetAttribute("Deadline") or 0
	s.count.Text = ("%d/%d"):format(n, MAX)
	local barColor, text, frac = d.color, "", 0
	if state == "Closed" then
		text = "Closed"
	elseif state == "Teleporting" then
		barColor, text, frac = UI.GREEN, "Teleporting...", 1
	elseif state == "Open" then
		text = "Waiting for players" .. string.rep(".", math.floor(t * 2) % 4)
	else
		local left = math.max(0, math.ceil(deadline - workspace:GetServerTimeNow()))
		text = (state == "Full" and "FULL! Starting in %ds" or "Starting in %ds"):format(left)
		frac = 1 - math.clamp(left / Config.LOBBY_WAIT, 0, 1)
		if left <= 5 then
			barColor = (math.floor(t * 4) % 2 == 0) and UI.RED or UI.ORANGE
		else
			barColor = UI.ORANGE
		end
	end
	s.bar.BackgroundColor3 = barColor
	s.status.Text = text
	s.fill.Size = UDim2.fromScale(frac, 1)
	local rot = m:GetAttribute("RotateAt") or 0
	local left = math.max(0, math.ceil(rot - workspace:GetServerTimeNow()))
	s.nextMap.Visible = state == "Open" and n == 0
	s.nextMap.Text = "🔄 New map in " .. clock(left)
	-- el borde late suave
	if s.borde then
		s.borde.Transparency = 0.15 + 0.15 * math.sin(t * 3)
	end
end

-- (con StreamingEnabled los pabellones llegan al cliente más tarde, y se van y vuelven al alejarse)
for _, m in folder:GetChildren() do
	task.spawn(buildScreen, m)
end
folder.ChildAdded:Connect(buildScreen)
folder.ChildRemoved:Connect(function(m)
	local s = screens[m]
	if s then
		screens[m] = nil
		s.gui:Destroy()
	end
end)

---------- Panel: refresco ----------
local lastSecond
local function myLobby()
	local id = player:GetAttribute("Lobby")
	return id and folder:FindFirstChild("Lobby" .. id), id
end

local function refresh()
	local m, id = myLobby()
	if not m then
		if panel.Visible then
			tween(pop, 0.15, {Scale = 0.85})
			task.delay(0.15, function()
				if not myLobby() then
					panel.Visible = false
				end
			end)
		end
		return
	end
	if not panel.Visible then
		panel.Visible = true
		pop.Scale = 0.6
		tween(pop, 0.35, {Scale = 1}, Enum.EasingStyle.Back)
	end
	local count = m:GetAttribute("Count") or 0
	local state = m:GetAttribute("State") or "Open"
	local host = m:GetAttribute("Host") or 0
	local deadline = m:GetAttribute("Deadline") or 0
	local set = {map = m:GetAttribute("Map"), diff = m:GetAttribute("Diff") or "Normal", waves = m:GetAttribute("Waves") or TD.WAVES}
	local info = TD.mapInfo(set.map or "")
	local d = TD.DIFFS[set.diff] or TD.DIFFS.Normal
	amHost = host == player.UserId
	-- el mapa
	Lb.lobbyTag.Text = "LOBBY " .. tostring(id)
	if info then
		Lb.mapCard.Image = info.image or ""
		Lb.mapName.Text = info.name
		Lb.mapLine.Text = mapMeta(info)
		Lb.newTag.Visible = info.new == true
	end
	Lb.mapStroke.Color = d.color:Lerp(UI.WHITE, 0.25)
	Lb.diffPill.BackgroundColor3 = d.color
	Lb.diffName.Text = string.upper(set.diff) .. "  " .. skulls(set.diff)
	Lb.coins.Text = ("x%s coins"):format(tostring(d.coins))
	-- oleadas: la elegida, morada y con borde blanco
	for w, wb in Lb.waves do
		local on = set.waves == w
		wb.grad.Color = on and ColorSequence.new(Color3.fromRGB(176, 110, 255), Color3.fromRGB(106, 46, 200)) or ColorSequence.new(Color3.fromRGB(60, 54, 76), Color3.fromRGB(34, 30, 46))
		wb.stroke.Color = on and UI.WHITE or Color3.fromRGB(96, 90, 112)
		wb.label.TextColor3 = on and UI.WHITE or Color3.fromRGB(176, 170, 196)
	end
	Lb.waveNote.Text = amHost and "You're the host: pick!" or "The host picks"
	if TD.isEndless(set.waves) then
		-- Modo Infinito: tu récord en este mapa
		local best = info and player:GetAttribute("EB_" .. info.id) or 0
		Lb.waveNote.Text = best > 0 and ("Your record here: wave %d"):format(best) or "Endless: how far can you go?"
	end
	-- jugadores
	local members = {}
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Lobby") == id then
			table.insert(members, p)
		end
	end
	table.sort(members, function(a, b)
		return (a:GetAttribute("LobbySlot") or 99) < (b:GetAttribute("LobbySlot") or 99)
	end)
	Lb.playersCap.Text = ("Players %d/%d"):format(count, MAX)
	local hostName = m:GetAttribute("HostName")
	Lb.hostCap.Text = hostName and ("Host: " .. hostName) or ""
	for i, c in Lb.cards do
		local p = members[i]
		local had = c.userId
		c.userId = p and p.UserId or nil
		if p then
			c.face.Image = faceOf(p.UserId)
			c.face.BackgroundColor3 = Color3.fromRGB(60, 54, 80)
			c.stroke.Color = p == player and UI.GOLD or UI.WHITE
			c.crown.Visible = p.UserId == host
			c.plus.Visible = false
			if had ~= p.UserId then
				-- llega alguien: su cara salta
				c.scale.Scale = 0.4
				tween(c.scale, 0.35, {Scale = 1}, Enum.EasingStyle.Back)
				if had == nil and p ~= player then
					UI.sound("Pickup", 0.5)
				end
			end
		else
			c.face.Image = ""
			c.face.BackgroundColor3 = Color3.fromRGB(30, 26, 40)
			c.stroke.Color = Color3.fromRGB(90, 86, 105)
			c.crown.Visible = false
			c.plus.Visible = true
		end
	end
	-- botones
	Lb.start.Visible = amHost and state ~= "Teleporting"
	Lb.wait.Visible = not Lb.start.Visible
	Lb.wait.Text = state == "Teleporting" and "Teleporting..." or "Waiting for the host to start"
	-- cuenta atrás
	if state == "Teleporting" then
		Lb.timerCap.Text = "Teleporting"
		Lb.timer.Text = "GO!"
		Lb.timer.TextColor3 = UI.GREEN
		return
	end
	local left = deadline > 0 and math.max(0, math.ceil(deadline - workspace:GetServerTimeNow())) or 0
	if deadline > 0 then
		Lb.timerCap.Text = count >= MAX and "Lobby full! Starting in" or "Starting in"
		Lb.timer.Text = clock(left)
		Lb.timer.TextColor3 = left <= 5 and UI.RED or UI.WHITE
	else
		Lb.timerCap.Text = "Waiting for players"
		Lb.timer.Text = ""
	end
	if deadline > 0 and left <= 5 and left > 0 and left ~= lastSecond then
		UI.sound("Tab", 1, 1 + (5 - left) * 0.08)
		Lb.timerPop.Scale = 1.25
		tween(Lb.timerPop, 0.3, {Scale = 1}, Enum.EasingStyle.Back)
	end
	lastSecond = left
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc >= 0.15 then
		acc = 0
		refresh()
		local t = os.clock()
		for _, s in screens do
			updateScreen(s, t)
		end
	end
end)
player:GetAttributeChangedSignal("Lobby"):Connect(refresh)

---------- Pantalla de viaje ----------
local TIPS = {
	"Tip: upgrade your troops between waves: each level adds a lot of fear!",
	"Tip: upgraded troops learn to see hidden hunters. A Mirror helps too.",
	"Tip: Soul Wells pay you cash after every wave. Build them early!",
	"Tip: harder difficulties give way more coins and gems.",
	"Tip: traps go ON the path. Hands hold hunters in place!",
	"Tip: vote to skip the wait when you're ready, or turn on Auto skip.",
}
local travelGui
local function closeTravel(fade)
	local g = travelGui
	travelGui = nil
	if not g then
		return
	end
	local root = g:FindFirstChild("Raiz")
	if fade and root then
		tween(root, 0.6, {GroupTransparency = 1}).Completed:Once(function()
			g:Destroy()
		end)
	else
		g:Destroy()
	end
end

-- where: "match" (s = {map, diff, waves}) o "lobby"
local function showTravel(where, s)
	closeTravel(false)
	local info = s and TD.mapInfo(s.map or "")
	local d = s and TD.DIFFS[s.diff or ""]
	local g = new("ScreenGui", {Name = "ViajeTD", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 100, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, playerGui)
	g:SetAttribute("To", where)
	travelGui = g
	local root = new("CanvasGroup", {Name = "Raiz", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(14, 6, 24), BorderSizePixel = 0, GroupTransparency = 1}, g)
	local art = new("ImageLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Crop, Image = info and info.image or UI.PATTERN, ImageTransparency = info and 0.15 or 0.85}, root)
	if not info then
		art.ScaleType = Enum.ScaleType.Tile
		art.TileSize = UDim2.fromOffset(256, 256)
	end
	local dark = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 4, 18), BorderSizePixel = 0}, root)
	new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.5, 0.25), NumberSequenceKeypoint.new(1, 0.05)})}, dark)
	local box = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromOffset(900, 300), BackgroundTransparency = 1}, root)
	new("UIScale", {Scale = math.clamp(workspace.CurrentCamera.ViewportSize.X / 1280, 0.5, 1.2)}, box)
	new("TextLabel", {Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Font = UI.FONT, TextSize = 30, TextColor3 = MUTED, TextStrokeTransparency = 0.4,
		Text = where == "lobby" and "Heading back to" or "Teleporting to your match"}, box)
	local title = new("TextLabel", {Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 100), BackgroundTransparency = 1, Font = UI.TITLE, TextScaled = true,
		TextColor3 = UI.WHITE, Text = where == "lobby" and "THE LOBBY" or string.upper(info and info.name or "Tower Defense")}, box)
	new("UITextSizeConstraint", {MaxTextSize = 96}, title)
	new("UIStroke", {Color = Color3.fromRGB(20, 8, 30), Thickness = 6}, title)
	local row = new("Frame", {Position = UDim2.fromOffset(0, 154), Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1}, box)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 14), VerticalAlignment = Enum.VerticalAlignment.Center}, row)
	if d then
		UI.chip(string.upper(s.diff), d.color, {Size = UDim2.fromOffset(0, 46), TextSize = 30}, row)
		UI.chip(TD.isEndless(s.waves) and "ENDLESS ∞" or ("%d WAVES"):format(s.waves or TD.WAVES), ACCENT, {Size = UDim2.fromOffset(0, 46), TextSize = 30}, row)
		UI.chip(("x%s COINS"):format(tostring(d.coins)), UI.GOLD, {Size = UDim2.fromOffset(0, 46), TextSize = 30, TextColor3 = Color3.fromRGB(40, 24, 6), TextStrokeTransparency = 1}, row)
	end
	local dots = new("TextLabel", {Position = UDim2.fromOffset(0, 220), Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Font = UI.TITLE, TextSize = 40, TextColor3 = UI.GOLD, TextStrokeTransparency = 0, Text = "..."}, box)
	local ghost = UI.icon("ghost", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, -60), Size = UDim2.fromOffset(110, 110)}, box)
	new("TextLabel", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40), Size = UDim2.new(0.9, 0, 0, 30), BackgroundTransparency = 1, Font = UI.FONT, TextSize = 22,
		TextColor3 = UI.WHITE, TextStrokeTransparency = 0.5, TextWrapped = true, Text = TIPS[math.random(#TIPS)]}, root)
	tween(root, 0.4, {GroupTransparency = 0})
	UI.sound("Portal")
	-- (las animaciones no viajan: al llegar se queda quieta hasta que LlegadaTD la quita)
	task.spawn(function()
		local t0 = os.clock()
		while travelGui == g do
			local t = os.clock() - t0
			dots.Text = string.rep("•", math.floor(t * 3) % 4)
			ghost.Position = UDim2.new(0.5, 0, 0, -60 + math.sin(t * 2.4) * 8)
			ghost.Rotation = math.sin(t * 1.7) * 8
			art.Size = UDim2.fromScale(1 + t * 0.01, 1 + t * 0.01)
			art.Position = UDim2.fromScale(-t * 0.005, -t * 0.005)
			task.wait()
		end
	end)
	if not RunService:IsStudio() then
		pcall(TeleportService.SetTeleportGui, TeleportService, g)
	end
end

---------- Mensajes del servidor ----------
LobbyRemote.OnClientEvent:Connect(function(kind, a, b)
	if kind == "Joined" then
		UI.sound("Portal")
		UI.setHint("Tower Defense · Lobby " .. tostring(a), "Up to " .. MAX .. " players · more players means tougher ghost hunters", "skull")
	elseif kind == "Left" then
		UI.sound("Close")
	elseif kind == "Starting" then
		UI.sound("Success")
		UI.big("GET READY!", "Your Tower Defense match is starting!", UI.ORANGE, 2.2)
	elseif kind == "Traveling" then
		showTravel(a, b)
	elseif kind == "TravelFailed" then
		closeTravel(true)
	elseif kind == "Arrived" or kind == "LeftMap" then
		closeTravel(true) -- (en Studio no hay viaje: se quita aquí)
	elseif kind == "Notice" then
		UI.toast(tostring(a), UI.GOLD)
	end
end)
refresh()
