-- La Wheel of Fright (el puesto de la ruleta, con monedas) y las gemas del HUD. Texto en inglés.
-- Todo lo decide el servidor (Juego: Spin); aquí solo se dibuja y se anima la ruleta. (Las gemas se gastan en las
-- skins de la Shop: ShopUI.)
-- Los premios de cada ruleta cambian cada Config.WHEEL_ROTATE (6 h) y salen de Config.wheelPrizes, igual que en el servidor.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(RS:WaitForChild("Config"))
local UI = require(script.Parent:WaitForChild("UI"))
local Remote = RS:WaitForChild("Remote")
local player = Players.LocalPlayer
local new, round, stroke = UI.new, UI.round, UI.stroke

local GEM = UI.GEM
local GEM_TEXT = Color3.fromRGB(150, 236, 255)
local BUY, CANT, MUTED = UI.BUY, UI.CANT, UI.MUTED
local LEFT = Enum.TextXAlignment.Left

local function label(props, parent)
	props.BackgroundTransparency = 1
	props.Font = props.Font or UI.FONT
	props.TextColor3 = props.TextColor3 or UI.WHITE
	return new("TextLabel", props, parent)
end

local coinStat = player:WaitForChild("leaderstats"):WaitForChild("Coins")
local function coins()
	return coinStat.Value
end

local function gems()
	return player:GetAttribute("Gems") or 0
end

local function catColor(t)
	return Config.Categories[Config.Scares[t].cat].color
end

local refreshers = {}
local function refreshAll()
	for _, f in refreshers do
		f()
	end
end

---------- Gemas en el HUD (debajo de las monedas) ----------
local gemPill, gemText = UI.currencyPill("gem", GEM_TEXT, 2)
UI.moneyPill:GetPropertyChangedSignal("Visible"):Connect(function()
	gemPill.Visible = UI.moneyPill.Visible
end)

---------- Ventana ----------
-- El puesto de la ruleta abre su página (no hay botón en el menú): hay que ir hasta él.
local TABS = {
	{name = "Wheels", title = "WHEEL OF FRIGHT", icon = "wheel", accent = Color3.fromRGB(240, 80, 170), kind = "wheel",
		sub = "Spin for scares you can't buy anywhere else. The prizes change every 6 hours!"},
}
local panel, close = UI.window({Name = "Stores", Size = UDim2.fromOffset(900, 620), title = "WHEELS", icon = "wheel", accent = TABS[1].accent, Visible = false, ZIndex = 3}, UI.gui)

-- saldo: monedas y gemas
local balance = round(new("Frame", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 60), Size = UDim2.fromOffset(0, 46), AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = UI.DARK, BackgroundTransparency = 0.15, ZIndex = 4,
}, panel), UDim.new(1, 0))
stroke(balance, UI.INK, 3)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, balance)
new("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 18)}, balance)
UI.icon("coin", {Size = UDim2.fromOffset(38, 38), LayoutOrder = 1, ZIndex = 5}, balance)
local coinText = label({Size = UDim2.fromOffset(0, 46), AutomaticSize = Enum.AutomaticSize.X, Font = UI.TITLE, TextSize = 24, TextColor3 = Color3.fromRGB(255, 226, 110), TextStrokeTransparency = 0, Text = "0", LayoutOrder = 2, ZIndex = 5}, balance)
UI.icon("gem", {Size = UDim2.fromOffset(36, 36), LayoutOrder = 3, ZIndex = 5}, balance)
local balanceGems = label({Size = UDim2.fromOffset(0, 46), AutomaticSize = Enum.AutomaticSize.X, Font = UI.TITLE, TextSize = 24, TextColor3 = GEM_TEXT, TextStrokeTransparency = 0, Text = "", LayoutOrder = 4, ZIndex = 5}, balance)
for _, l in {coinText, balanceGems} do
	new("UIPadding", {PaddingTop = UDim.new(0, 4)}, l)
end

-- lo que hace el puesto, donde antes iban las pestañas
local header = label({Position = UDim2.fromOffset(28, 64), Size = UDim2.fromOffset(560, 46), Font = UI.FONT, TextSize = 17, TextColor3 = MUTED, TextWrapped = true,
	TextXAlignment = LEFT, TextStrokeTransparency = 0.6, Text = "", ZIndex = 4}, panel)
local pages, tabs = {}, {}
local openTab = 1
local function selectTab(i)
	openTab = i
	for k, p in pages do
		p.Visible = k == i
		tabs[k].BackgroundColor3 = k == i and TABS[k].accent or UI.TAB
	end
	header.Text = TABS[i].sub
	UI.setWindowTitle(panel, TABS[i].title, TABS[i].icon, TABS[i].accent)
end
for i, d in TABS do
	tabs[i] = UI.iconButton({Name = "Tab" .. d.title:gsub(" ", ""), Position = UDim2.fromOffset(26 + (i - 1) * 146, 60), Size = UDim2.fromOffset(138, 50), Text = d.name, TextSize = 19, Font = UI.TITLE, ZIndex = 4, Visible = false}, panel, d.icon)
	pages[i] = new("Frame", {Position = UDim2.fromOffset(22, 124), Size = UDim2.new(1, -44, 1, -142), BackgroundTransparency = 1, Visible = i == 1}, panel)
	tabs[i].Activated:Connect(function()
		if not pages[i].Visible then
			UI.sound("Tab")
		end
		selectTab(i)
	end)
end
selectTab(1)

local function toggle(open, tab)
	if open and tab then
		selectTab(tab)
	end
	if open == panel.Visible then
		return
	end
	UI.sound(open and "Open" or "Close")
	panel.Visible = open
	if open then
		UI.toggleShop(false)
		refreshAll()
		UI.popIn(panel)
	end
end
close.Activated:Connect(function()
	toggle(false)
end)
-- una tienda a la vez; y en una visita, nada de tiendas
UI.shop:GetPropertyChangedSignal("Visible"):Connect(function()
	if UI.shop.Visible then
		toggle(false)
	end
end)
player:GetAttributeChangedSignal("Mode"):Connect(function()
	if player:GetAttribute("Mode") == "visit" then
		toggle(false)
	end
end)

---------- Ir al puesto ----------
-- Las tiendas ya no están en el menú: lo que antes las abría (la tienda, la barra de sustos...) te dice a qué puesto
-- ir y tiende un rayo de luz desde ti hasta él, que se apaga al llegar. Si ya estás al lado, se abre directamente.
local REACH = 22 -- a esta distancia del mostrador ya estás "en el puesto"
local LEAVE = 34 -- y si te alejas más que esto con la ventana abierta, se cierra
local BOOTH_NAME = {wheel = "Wheel of Fright"}
local function boothCounter(kind)
	local folder = workspace:FindFirstChild("Mapa") and workspace.Mapa:FindFirstChild("Tiendas")
	for _, m in folder and folder:GetChildren() or {} do
		if m:GetAttribute("Kind") == kind then
			return m:FindFirstChild("Mostrador", true)
		end
	end
end
local function rootPart()
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end
local function distTo(kind)
	local c, r = boothCounter(kind), rootPart()
	return c and r and (c.Position - r.Position).Magnitude or math.huge
end

local guide -- {beam, a0, a1, kind}
local function stopGuide()
	if guide then
		guide.beam:Destroy()
		guide.a0:Destroy()
		guide.a1:Destroy()
		guide = nil
	end
end
function UI.goToStall(kind, why)
	local tab
	for i, d in TABS do
		if d.kind == kind then
			tab = i
		end
	end
	if tab and distTo(kind) <= REACH then
		return toggle(true, tab)
	end
	UI.toast((why and (why .. "  ·  ") or "") .. ("Go to the %s on the street!"):format(BOOTH_NAME[kind] or "stall"), tab and TABS[tab].accent or UI.ORANGE, tab and TABS[tab].icon or "map")
	UI.sound("Sparkle")
	local counter, root = boothCounter(kind), rootPart()
	local mode = player:GetAttribute("Mode")
	if not (counter and root) or (mode ~= nil and mode ~= "home") then
		return
	end
	stopGuide()
	local color = tab and TABS[tab].accent or UI.ORANGE
	local a0 = new("Attachment", {Name = "GuiaPuesto", Position = Vector3.new(0, -1.5, 0)}, root)
	local a1 = new("Attachment", {Name = "GuiaPuesto", Position = Vector3.new(0, 3, 0)}, counter)
	local beam = new("Beam", {
		Attachment0 = a0, Attachment1 = a1, Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.4), color), LightEmission = 1, LightInfluence = 0,
		Width0 = 0.5, Width1 = 1.6, FaceCamera = true, Segments = 30, CurveSize0 = 6, CurveSize1 = -6,
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.15, 0.25), NumberSequenceKeypoint.new(1, 0.1)}),
	}, root)
	guide = {beam = beam, a0 = a0, a1 = a1, kind = kind, t0 = os.clock()}
end
-- (la tienda y la barra de sustos: "cómo lo consigo" lleva a la ruleta)
function UI.openStores()
	UI.goToStall("wheel")
end


-- Botón de precio: el icono de la divisa a la derecha y "Need N" (gris) si no llega
local function priceButton(b, have, price, icon)
	local can = have >= price
	b.Text = can and UI.fmt(price) or ("Need %s"):format(UI.fmt(price - have))
	b.BackgroundColor3 = can and BUY or CANT
	UI.setIcon(b.Icon, icon)
end

---------- 1. Ruletas ----------
-- Diseño: Figma "Wheel of Fright – UI Redesign" (https://www.figma.com/design/mt8mc45NoQOtCyGGIDTL4A).
-- Ruleta de feria grande a la izquierda: aro de madera con bombillas, casillas del color de la rareza de su premio
-- (cuñas de verdad), el susto en 3D en cada casilla, buje dorado (también es el botón) y un alfiler arriba. A la
-- derecha: las 3 ruletas en pestañas, la cuenta atrás, los premios, la barra de pity y el botón de girar.
local wheelPage = pages[1]
local RIM = 214 -- radio exterior (aro)
local R = 180 -- radio del disco de colores
local CHIP_R = 118 -- a qué distancia del centro van los premios
local selected, spinning, rotation = 1, false, 0
local shownWheel, shownPeriod
local SLICE = {
	Color3.fromRGB(255, 64, 110), Color3.fromRGB(255, 138, 36), Color3.fromRGB(255, 206, 52), Color3.fromRGB(84, 206, 84),
	Color3.fromRGB(40, 196, 222), Color3.fromRGB(66, 118, 255), Color3.fromRGB(148, 78, 240), Color3.fromRGB(232, 66, 200),
}
-- cada casilla, del color de la rareza de su premio (las vecinas, un poco más claras u oscuras para distinguirlas)
local CAT_SLICE = {
	Basico = Color3.fromRGB(70, 190, 90), Criatura = Color3.fromRGB(140, 84, 236), Trampa = Color3.fromRGB(255, 132, 36),
	Legendario = Color3.fromRGB(255, 190, 30), Especial = Color3.fromRGB(40, 200, 230),
}
local slotColors = table.clone(SLICE)
local angVel = 0 -- velocidad de giro (grados/s): la aguja, el tic-tac y el desenfoque dependen de ella
local skip = false -- pulsar durante el giro lo acelera

local function freeReady()
	return selected == Config.FREE_SPIN_WHEEL and workspace:GetServerTimeNow() >= (player:GetAttribute("FreeSpinAt") or math.huge)
end

-- la ruleta (izquierda, centrada en su mitad de la página)
local wheelBox = new("Frame", {Position = UDim2.fromOffset(235 - RIM, 246 - RIM), Size = UDim2.fromOffset(2 * RIM, 2 * RIM), BackgroundTransparency = 1}, wheelPage)
local boxScale = new("UIScale", {}, wheelBox)
-- rayos de luz detrás (giran más rápido mientras gira)
local rays = UI.piece("rays", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(640, 640), ImageTransparency = 0.6}, wheelBox)
round(new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 10), Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45}, wheelBox), UDim.new(1, 0))
local rim = round(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1)}, wheelBox), UDim.new(1, 0))
new("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(150, 90, 50), Color3.fromRGB(64, 34, 20)), Rotation = 90}, rim)
local rimStroke = new("UIStroke", {Thickness = 6, Color = UI.INK}, rim)
local rimRing = round(new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -8, 1, -8), BackgroundTransparency = 1}, rim), UDim.new(1, 0))
local rimColor = new("UIStroke", {Thickness = 4, Color = UI.GOLD}, rimRing)
local function polarAt(c, angle, r)
	local a = math.rad(angle)
	return UDim2.fromOffset(c + math.sin(a) * r, c - math.cos(a) * r)
end
-- bombillas del aro (quietas; la luz corre por ellas)
local bulbs = {}
for k = 1, 16 do
	local b = round(new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = polarAt(RIM, (k - 1) * 22.5 + 11.25, RIM - 14), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Color3.fromRGB(255, 236, 150), BorderSizePixel = 0}, wheelBox), 7)
	stroke(b, UI.INK, 2)
	bulbs[k] = b
end

-- disco: CanvasGroup redondo y QUIETO. Las cuñas se pintan con medios discos (degradado con corte duro): en cada mitad
-- de la pantalla (derecha/izquierda, recortadas), el último medio disco pintado gana, así que cinco por mitad dibujan
-- las cuñas exactas. Al girar se repintan cada fotograma con el ángulo de `rot` (el recorte no funciona si se rota).
local disc = round(new("CanvasGroup", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(2 * R, 2 * R), BackgroundColor3 = Color3.new(0, 0, 0)}, wheelBox), UDim.new(1, 0))
local HALF = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.499, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 0)})
local halfFrames = {}
for h = 1, 2 do -- 1: derecha (0..180°), 2: izquierda (180..360°)
	local half = new("Frame", {Position = UDim2.fromOffset(h == 1 and R or 0, 0), Size = UDim2.fromOffset(R, 2 * R), BackgroundTransparency = 1, ClipsDescendants = true}, disc)
	halfFrames[h] = {}
	for n = 1, 5 do
		local f = new("Frame", {Position = UDim2.fromOffset(h == 1 and -R or 0, 0), Size = UDim2.fromOffset(2 * R, 2 * R), BorderSizePixel = 0}, half)
		halfFrames[h][n] = {frame = f, grad = new("UIGradient", {Transparency = HALF}, f)}
	end
end
-- la casilla k ocupa los ángulos (k-1)*45 ± 22.5 de la ruleta, más lo que haya girado (theta)
local function paint(theta)
	for h = 1, 2 do
		local h0 = h == 1 and 0 or 180
		local rel = (h0 - theta + 22.5) % 360
		local j = math.floor(rel / 45) -- casilla (desde 0) que cruza el borde de esta mitad
		local start = h0 - rel % 45
		for n, hf in halfFrames[h] do
			hf.frame.BackgroundColor3 = slotColors[(j + n - 1) % 8 + 1]
			hf.grad.Rotation = start + (n - 1) * 45
		end
	end
end
paint(0)
-- sombra interior del borde y brillo radial en el centro
local inner = round(new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(2 * R - 24, 2 * R - 24), BackgroundTransparency = 1}, disc), UDim.new(1, 0))
new("UIStroke", {Thickness = 12, Color = Color3.new(0, 0, 0), Transparency = 0.65}, inner)
UI.piece("glow2", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), ImageTransparency = 0.82}, disc)
-- lo que gira: líneas entre casillas y premios
local rot = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1}, disc)
for k = 1, 8 do
	local d = (k - 1) * 45 + 22.5
	new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = polarAt(R, d, R / 2), Size = UDim2.fromOffset(5, R), Rotation = d, BackgroundColor3 = UI.WHITE, BackgroundTransparency = 0.1, BorderSizePixel = 0}, rot)
end
-- premios: el susto en 3D y la probabilidad grande, mirando hacia fuera
local chips = {}
for k = 1, 8 do
	local a = (k - 1) * 45
	local holder = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = polarAt(R, a, CHIP_R), Size = UDim2.fromOffset(86, 106), Rotation = a, BackgroundTransparency = 1}, rot)
	local pct = label({AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(1, 0, 0, 30), Font = UI.TITLE, TextSize = 26, Text = "", ZIndex = 3}, holder)
	new("UIStroke", {Color = UI.INK, Thickness = 3, LineJoinMode = Enum.LineJoinMode.Round}, pct)
	local star = UI.icon("star", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -18), Size = UDim2.fromOffset(30, 30), Visible = false, ZIndex = 3}, holder)
	-- brillo detrás del premio (las legendarias brillan siempre; la ganadora, a tope)
	local glow = UI.piece("glow2", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(130, 130), ImageTransparency = 1, ZIndex = 1}, holder)
	chips[k] = {frame = holder, pct = pct, star = star, glow = glow, scale = new("UIScale", {}, holder)}
end
-- buje dorado (botón de girar) y el alfiler arriba
local hub = UI.piece("round", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(108, 108), ImageColor3 = Color3.fromRGB(255, 196, 60), AutoButtonColor = false}, wheelBox, "ImageButton")
local hubScale = new("UIScale", {}, hub)
local hubText = label({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(1, -12, 0, 34), Font = UI.TITLE, Text = "SPIN", TextSize = 30, TextColor3 = UI.WHITE, TextStrokeTransparency = 0}, hub)
new("UIPadding", {PaddingTop = UDim.new(0, 5)}, hubText)
local pointer = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.3), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(52, 66), BackgroundTransparency = 1, ZIndex = 5}, wheelBox)
UI.piece("arrow", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(46, 46), ImageColor3 = UI.RED, ZIndex = 5}, pointer)
local knob = UI.piece("round", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(26, 14), Size = UDim2.fromOffset(34, 34), ImageColor3 = UI.GOLD, ZIndex = 6}, pointer)
round(new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = UI.INK, ZIndex = 7}, knob), 5)

-- derecha: pestañas de ruleta, cuenta atrás, premios, pity y botón de girar
local side = new("Frame", {Position = UDim2.fromOffset(492, 0), Size = UDim2.new(0, 364, 1, 0), BackgroundTransparency = 1}, wheelPage)
local wheelButtons = {}
for i, w in Config.Wheels do
	local b = UI.button({Position = UDim2.fromOffset((i - 1) * 124, 2), Size = UDim2.fromOffset(116, 64), BackgroundColor3 = w.color, Text = "", ZIndex = 4}, side)
	local title = label({Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 24), Font = UI.TITLE, Text = (w.name:gsub(" Wheel", "")), TextScaled = true, TextStrokeTransparency = 0, ZIndex = 6}, b)
	new("UITextSizeConstraint", {MaxTextSize = 19}, title)
	local price = new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 32), Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 6}, b)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, price)
	UI.icon("coin", {Size = UDim2.fromOffset(20, 20), LayoutOrder = 1, ZIndex = 6}, price)
	label({Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, Font = UI.TITLE, Text = UI.fmt(w.price), TextSize = 16, TextColor3 = Color3.fromRGB(255, 226, 110), TextStrokeTransparency = 0, LayoutOrder = 2, ZIndex = 6}, price)
	-- la elegida lleva un contorno blanco
	local sel = round(new("Frame", {Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -6), BackgroundTransparency = 1, ZIndex = 7}, b), 14)
	local selStroke = new("UIStroke", {Color = UI.WHITE, Thickness = 3}, sel)
	-- etiqueta "FREE" en la ruleta que tiene tirada gratis lista
	local free = UI.chip("FREE", UI.RED, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 8, 0, 2), Rotation = 12, Visible = false, ZIndex = 9}, b)
	wheelButtons[i] = {button = b, sel = selStroke, free = free}
end
local timerRow = new("Frame", {Position = UDim2.fromOffset(0, 74), Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1}, side)
UI.icon("clock", {Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(0, 1)}, timerRow)
local timer = label({Position = UDim2.fromOffset(22, 0), Size = UDim2.new(0.55, -22, 1, 0), Text = "", TextSize = 14, TextColor3 = MUTED, TextXAlignment = LEFT}, timerRow)
local freeRow = new("Frame", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.45, 0, 1, 0), BackgroundTransparency = 1}, timerRow)
local freeText = label({Size = UDim2.fromScale(1, 1), Text = "", TextSize = 14, TextColor3 = UI.ORANGE, TextXAlignment = Enum.TextXAlignment.Right, TextStrokeTransparency = 0}, freeRow)
local rows = {}
for k = 1, 8 do
	local row = round(new("Frame", {Position = UDim2.fromOffset(0, 100 + (k - 1) * 31), Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = UI.DARK, BackgroundTransparency = 0.25}, side), 10)
	local rowStroke = new("UIStroke", {Thickness = 2, Color = UI.INK, Transparency = 0.2}, row)
	local dot = round(new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 17, 0.5, 0), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = SLICE[k]}, row), UDim.new(1, 0))
	stroke(dot, UI.INK, 2)
	local name = label({Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -96, 1, 0), TextSize = 15, TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd, Text = ""}, row)
	local pct = label({AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.new(0, 60, 1, 0), Font = UI.TITLE, TextSize = 15, TextColor3 = UI.GOLD, TextStrokeTransparency = 0, TextXAlignment = Enum.TextXAlignment.Right, Text = ""}, row)
	new("UIPadding", {PaddingTop = UDim.new(0, 3)}, pct)
	rows[k] = {name = name, pct = pct, stroke = rowStroke, dot = dot}
end
local pityBack, pityFill = UI.bar({Position = UDim2.new(0, 0, 1, -110), Size = UDim2.new(1, 0, 0, 32)}, side, Color3.new(1, 1, 1))
UI.gradient(pityFill, Color3.fromRGB(255, 120, 40), UI.GOLD, 0)
local pityText = label({Size = UDim2.fromScale(1, 1), Font = UI.TITLE, Text = "", TextSize = 14, TextStrokeTransparency = 0, ZIndex = 5}, pityBack)
new("UIPadding", {PaddingTop = UDim.new(0, 3)}, pityText)
local spinButton = UI.iconButton({Position = UDim2.new(0, 0, 1, -70), Size = UDim2.new(1, 0, 0, 66), Text = "", TextSize = 28, Font = UI.TITLE, BackgroundColor3 = BUY, ZIndex = 4}, side, "wheel")

local function buildWheel(period)
	local w = Config.Wheels[selected]
	local prizes = Config.wheelPrizes(selected, period)
	local total = 0
	for _, p in prizes do
		total += p.w
	end
	for k, p in prizes do
		local def = Config.Scares[p.scare]
		local jackpot = Config.isJackpot(p.scare)
		local chance = ("%g%%"):format(math.floor(p.w / total * 1000 + 0.5) / 10)
		local c = chips[k]
		for _, x in c.frame:GetChildren() do
			if x:IsA("ViewportFrame") then
				x:Destroy()
			end
		end
		UI.viewport(p.scare, c.frame, {Size = UDim2.fromOffset(86, 78), ZIndex = 2})
		c.pct.Text = chance
		c.pct.TextColor3 = jackpot and UI.GOLD or UI.WHITE
		c.star.Visible = jackpot
		c.glow.ImageColor3 = catColor(p.scare):Lerp(UI.WHITE, 0.35)
		c.glow.ImageTransparency = jackpot and 0.35 or 1
		c.scale.Scale = 1
		slotColors[k] = (CAT_SLICE[def.cat] or SLICE[k]):Lerp(k % 2 == 0 and Color3.new(1, 1, 1) or Color3.new(0, 0, 0), 0.14)
		local exclusive = not Config.inShop(p.scare) and not def.special
		rows[k].name.Text = (jackpot and "★ " or "") .. def.name .. (exclusive and "  ✦" or "")
		rows[k].name.TextColor3 = jackpot and UI.GOLD or (exclusive and Color3.fromRGB(255, 150, 220) or UI.WHITE)
		rows[k].pct.Text = chance
		rows[k].stroke.Color = jackpot and UI.GOLD or UI.INK
		rows[k].dot.BackgroundColor3 = slotColors[k]
	end
	paint(rot.Rotation)
	rimColor.Color = w.color
	rays.ImageColor3 = w.color
	for i, b in wheelButtons do
		local on = i == selected
		b.button.BackgroundColor3 = on and Config.Wheels[i].color or Config.Wheels[i].color:Lerp(UI.CARD, 0.65)
		b.sel.Enabled = on
	end
	shownWheel, shownPeriod = selected, period
end

local function currentPeriod()
	return Config.wheelPeriod(workspace:GetServerTimeNow())
end

local function refreshSpin()
	if spinning then
		spinButton.Text, spinButton.BackgroundColor3 = spinning == "anim" and "Tap to skip!" or "Spinning...", CANT
		UI.setIcon(spinButton.Icon, "wheel")
	elseif freeReady() then
		spinButton.Text, spinButton.BackgroundColor3 = "FREE SPIN!", UI.ORANGE
		UI.setIcon(spinButton.Icon, "gift")
	else
		local price = Config.Wheels[selected].price
		local can = coins() >= price
		spinButton.Text = can and ("SPIN  %s"):format(UI.fmt(price)) or ("Need %s"):format(UI.fmt(price - coins()))
		spinButton.BackgroundColor3 = can and BUY or CANT
		UI.setIcon(spinButton.Icon, can and "wheel" or "coin")
	end
	hubText.Text = spinning == "anim" and "SKIP" or spinning and "..." or freeReady() and "FREE" or "SPIN"
	-- pity: tras pity-1 tiradas sin premio gordo, la siguiente lo trae seguro (lo decide el servidor)
	local w = Config.Wheels[selected]
	local streak = player:GetAttribute("Pity" .. selected) or 0
	local left = math.max(1, w.pity - streak)
	pityFill.Size = UDim2.fromScale(math.clamp(streak / math.max(1, w.pity - 1), 0, 1), 1)
	pityText.Text = left <= 1 and "JACKPOT GUARANTEED NEXT SPIN!" or ("Jackpot guaranteed in %d spins"):format(left)
	for i, b in wheelButtons do
		b.free.Visible = i == Config.FREE_SPIN_WHEEL and workspace:GetServerTimeNow() >= (player:GetAttribute("FreeSpinAt") or math.huge)
	end
end
table.insert(refreshers, refreshSpin)

for i, b in wheelButtons do
	b.button.Activated:Connect(function()
		if spinning or selected == i then
			return
		end
		selected = i
		UI.sound("Tab")
		buildWheel(currentPeriod())
		refreshSpin()
	end)
end

local function doSpin()
	if spinning == "anim" then
		skip = true -- ya gira: acelera hasta el final
		return
	end
	if spinning then
		return
	end
	local free = freeReady()
	local price = Config.Wheels[selected].price
	if not free and coins() < price then
		return UI.toast(("You need %s more coins"):format(UI.fmt(price - coins())), UI.RED)
	end
	spinning = true
	refreshSpin()
	Remote:FireServer("Spin", selected, free)
	-- si el servidor no responde (p. ej. no te llegaba el dinero), se desbloquea
	task.delay(3, function()
		if spinning == true then
			spinning = false
			refreshSpin()
		end
	end)
end
spinButton.Activated:Connect(doSpin)
hub.Activated:Connect(doSpin)
hub.MouseButton1Down:Connect(function()
	UI.sound("Click")
	hubScale.Scale = 0.9
	TweenService:Create(hubScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Scale = 1}):Play()
end)

-- tic-tac al pasar cada casilla por el alfiler, que da un respingo; luces que corren, rayos y botones que laten
local lastSlot, lastStep = 0, 0
local litRow = 0
RunService.RenderStepped:Connect(function()
	if not panel.Visible or not wheelPage.Visible then
		return
	end
	local t = os.clock()
	if spinning ~= "anim" then
		-- en reposo la ruleta se mece un poco, como si respirara
		rot.Rotation = rotation + 5 * math.sin(t * 0.9)
		paint(rot.Rotation)
	end
	local slot = math.floor((rot.Rotation + 22.5) / 45)
	if slot ~= lastSlot then
		lastSlot = slot
		if spinning == "anim" then
			-- tic-tac más agudo cuanto más rápido; la aguja salta más cuanto más rápido
			local speed = math.min(1, math.abs(angVel) / 1400)
			UI.sound("Click", 0.5 + 0.4 * (1 - speed), 1 + speed * 0.5)
			pointer.Rotation = (slot % 2 == 0 and -1 or 1) * (14 + 20 * (1 - speed))
			TweenService:Create(pointer, TweenInfo.new(0.16, Enum.EasingStyle.Back), {Rotation = 0}):Play()
		end
	end
	-- la fila del premio que está bajo la aguja se ilumina en la lista
	local under = math.round(-rot.Rotation / 45) % 8 + 1
	if under ~= litRow then
		if rows[litRow] then
			rows[litRow].dot.Size = UDim2.fromOffset(16, 16)
			rows[litRow].name.TextTransparency = 0
		end
		litRow = under
		rows[under].dot.Size = UDim2.fromOffset(20, 20)
	end
	for k, c in chips do
		if c.star.Visible and spinning ~= "anim" then
			c.glow.ImageTransparency = 0.3 + 0.25 * math.sin(t * 3 + k)
		end
	end
	local step = math.floor(t * (spinning and 14 or 3))
	if step ~= lastStep then
		lastStep = step
		for k, b in bulbs do
			local on = spinning and (k + step) % 4 < 2 or (k + step) % 2 == 0
			b.BackgroundColor3 = on and Color3.fromRGB(255, 240, 160) or Color3.fromRGB(110, 70, 40)
		end
	end
	rays.Rotation = t * (spinning and 120 or 10)
	-- lo que se puede pulsar ya, late
	local ready = not spinning and (freeReady() or coins() >= Config.Wheels[selected].price)
	local s = 0.5 + 0.5 * math.sin(t * 5)
	spinButton.Shine.ImageTransparency = ready and s * 0.7 or 0.25
	if not spinning then
		hubScale.Scale = ready and 1 + s * 0.06 or 1
	end
end)

-- carta de premio: tapa el panel, con rayos del color de la rareza y el susto girando
local reveal = round(new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 6, 18), BackgroundTransparency = 0.08, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 30}, panel), 24)
local revealRays = UI.piece("rays", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromOffset(720, 720), ImageTransparency = 0.35, ZIndex = 30}, reveal)
local revealRays2 = UI.piece("rays", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromOffset(480, 480), ImageTransparency = 0.5, ZIndex = 30}, reveal)
local revealTitle = label({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 26), Size = UDim2.fromOffset(640, 76), Font = UI.TITLE, TextSize = 72, Text = "", ZIndex = 32}, reveal)
new("UIStroke", {Color = UI.INK, Thickness = 6, LineJoinMode = Enum.LineJoinMode.Round}, revealTitle)
-- halo del color de la rareza detrás del susto (los sustos oscuros, como la Parca, se recortan sobre él)
local revealGlow = UI.piece("glow2", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromOffset(300, 300), ZIndex = 31}, reveal)
local revealBox = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromOffset(240, 240), BackgroundTransparency = 1, ZIndex = 31}, reveal)
local revealScale = new("UIScale", {}, revealBox)
local revealNew = UI.chip("NEW!", UI.RED, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 136, 0.44, -104), Rotation = 14, TextSize = 24, ZIndex = 33}, reveal)
local revealName = label({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.44, 124), Size = UDim2.fromOffset(640, 46), Font = UI.TITLE, TextSize = 42, TextStrokeTransparency = 0, Text = "", ZIndex = 32}, reveal)
local revealCat = UI.chip("", UI.PURPLE, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.44, 174), TextSize = 16, ZIndex = 32}, reveal)
local revealStats = new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.44, 206), Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 32}, reveal)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder}, revealStats)
local _, revealPay = UI.stat(revealStats, "coin", "", UI.GOLD, 1)
local _, revealFear = UI.stat(revealStats, "skull", "", Color3.fromRGB(255, 150, 160), 2)
label({AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(600, 20), Text = "Added to your bag  ·  click to continue", TextSize = 15, TextColor3 = MUTED, ZIndex = 32}, reveal)
local revealToken = 0
local function hideReveal()
	revealToken += 1
	reveal.Visible = false
end
reveal.Activated:Connect(hideReveal)
RunService.RenderStepped:Connect(function()
	if reveal.Visible then
		local a = os.clock()
		revealRays.Rotation = a * 30
		revealRays2.Rotation = -a * 18
	end
end)

-- estrellas de rareza, etiquetas (exclusivo de la ruleta, espacios que ocupa) y la esfera que se carga en los premios gordos
local revealStars = new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 108), Size = UDim2.fromOffset(0, 38), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 33}, reveal)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, revealStars)
local starIcons = {}
for i = 1, 5 do
	local s = UI.icon("star", {Size = UDim2.fromOffset(38, 38), LayoutOrder = i, ZIndex = 33}, revealStars)
	starIcons[i] = {icon = s, scale = new("UIScale", {}, s)}
end
local revealTags = new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.44, 240), Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 33}, reveal)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, revealTags)
local tagWheel = UI.chip("✦ WHEEL EXCLUSIVE", Color3.fromRGB(236, 78, 168), {LayoutOrder = 1, TextSize = 14, ZIndex = 33}, revealTags)
local tagSlots = UI.chip("", Color3.fromRGB(90, 70, 150), {LayoutOrder = 2, TextSize = 14, ZIndex = 33}, revealTags)
local orb = UI.piece("glow2", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromOffset(40, 40), Visible = false, ZIndex = 34}, reveal)
local orbCore = UI.piece("round", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.35, 0.35), ImageTransparency = 0.1, ZIndex = 35}, orb)
local titleGrad = new("UIGradient", {Enabled = false}, revealTitle)
-- nivel de cada categoría: estrellas y lo que se grita
local TIER = {Basico = {1, "NICE!"}, Criatura = {2, "GREAT!"}, Trampa = {3, "AWESOME!"}, Legendario = {4, "LEGENDARY!"}, Especial = {5, "SPECIAL!"}}
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)), ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 210, 60)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 230, 120)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 170, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 90, 255)),
})
RunService.RenderStepped:Connect(function()
	if reveal.Visible and titleGrad.Enabled then
		titleGrad.Offset = Vector2.new(math.sin(os.clock() * 2) * 0.5, 0)
	end
end)

-- un número que sube de 0 a n
local function countUp(l, n, fmt, time)
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < time do
			l.Text = fmt:format(math.floor(n * (os.clock() - t0) / time))
			RunService.RenderStepped:Wait()
		end
		l.Text = fmt:format(n)
	end)
end

local function showReveal(t, isNew)
	local def, color = Config.Scares[t], catColor(t)
	local rare = Config.isJackpot(t)
	local tier = TIER[def.cat] or {1, "YOU GOT"}
	local stars = def.mythic and 5 or tier[1]
	revealToken += 1
	local token = revealToken
	-- todo preparado pero escondido
	revealTitle.Text = def.mythic and "MYTHIC!!" or tier[2]
	revealTitle.TextColor3 = def.mythic and UI.WHITE or (rare and UI.GOLD or color:Lerp(UI.WHITE, 0.3))
	titleGrad.Enabled = def.mythic == true
	titleGrad.Color = RAINBOW
	revealName.Text, revealName.TextColor3 = def.name, color:Lerp(UI.WHITE, 0.2)
	revealCat.Text, revealCat.BackgroundColor3 = Config.Categories[def.cat].name, color
	revealPay.Text, revealFear.Text = "+0 per scare", "Fear 0"
	revealNew.Visible = false
	tagWheel.Visible = not Config.inShop(t) and not def.special
	tagSlots.Visible = Config.slots(t) > 1
	tagSlots.Text = ("TAKES %d SPACES"):format(Config.slots(t))
	revealRays.ImageColor3, revealRays2.ImageColor3 = color, color:Lerp(UI.WHITE, 0.5)
	revealGlow.ImageColor3 = color:Lerp(UI.WHITE, 0.45)
	for _, x in revealBox:GetChildren() do
		if x:IsA("ViewportFrame") then
			x:Destroy()
		end
	end
	local vp = UI.viewport(t, revealBox, {Size = UDim2.fromScale(1, 1), ZIndex = 32})
	vp.Ambient, vp.LightColor = Color3.fromRGB(220, 215, 235), Color3.new(1, 1, 1)
	local content = {revealTitle, revealName, revealCat, revealStats, revealStars, revealTags, revealBox, revealRays, revealRays2, revealGlow}
	for _, o in content do
		o.Visible = false
	end
	for _, s in starIcons do
		s.scale.Scale = 0
	end
	reveal.Visible = true
	revealScale.Scale = 1
	-- premio gordo: una esfera de su color se carga temblando con un tic-tac cada vez más agudo... y estalla
	if rare then
		orb.Visible = true
		orb.ImageColor3 = color
		orbCore.ImageColor3 = color:Lerp(UI.WHITE, 0.6)
		local t0, nextTick = os.clock(), 0
		local dur = def.mythic and 1.6 or 1.15
		while os.clock() - t0 < dur do
			if revealToken ~= token then
				orb.Visible = false
				return
			end
			local k = (os.clock() - t0) / dur
			local sz = 40 + 320 * k * k
			orb.Size = UDim2.fromOffset(sz, sz)
			orb.Position = UDim2.new(0.5, math.random(-6, 6) * k, 0.44, math.random(-6, 6) * k)
			orb.Rotation = math.random(-10, 10) * k
			if os.clock() - t0 > nextTick then
				nextTick = os.clock() - t0 + 0.16 * (1 - k * 0.75)
				UI.sound("Click", 0.8, 0.8 + k * 1.4)
			end
			RunService.RenderStepped:Wait()
		end
		orb.Visible = false
		UI.flash(Color3.new(1, 1, 1), 0.05, 0.9)
		UI.sound("Boom", 0.9)
		UI.sound("Win")
		UI.confetti(def.mythic and 120 or 80)
	end
	for _, o in content do
		o.Visible = true
	end
	revealTags.Visible = tagWheel.Visible or tagSlots.Visible
	revealScale.Scale = rare and 0.4 or 0.2
	TweenService:Create(revealScale, TweenInfo.new(0.55, Enum.EasingStyle.Back), {Scale = 1}):Play()
	-- las estrellas van saliendo una a una
	for i, s in starIcons do
		local lit = i <= stars
		s.icon.ImageColor3 = lit and (def.mythic and Color3.fromRGB(255, 120, 220) or UI.GOLD) or Color3.fromRGB(50, 40, 60)
		s.icon.ImageTransparency = lit and 0 or 0.4
		task.delay(0.25 + i * 0.11, function()
			if revealToken ~= token then
				return
			end
			s.scale.Scale = 1.6
			TweenService:Create(s.scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Scale = 1}):Play()
			if lit then
				UI.sound("Click", 0.9, 1 + i * 0.15)
			end
		end)
	end
	countUp(revealPay, def.pay, "+%d per scare", 0.7)
	countUp(revealFear, def.fear, "Fear %d", 0.7)
	task.delay(0.9, function()
		if revealToken == token and isNew then
			revealNew.Visible = true
			revealNew.Rotation = 30
			TweenService:Create(revealNew, TweenInfo.new(0.5, Enum.EasingStyle.Elastic), {Rotation = 14}):Play()
			UI.sound("Sparkle")
		end
	end)
	task.delay(rare and 6 or 4.5, function()
		if revealToken == token then
			hideReveal()
		end
	end)
end

---------- Efectos del giro ----------
-- fondo oscurecido y desenfocado mientras gira (la ruleta, en primer plano)
local dimGui = new("ScreenGui", {Name = "WheelFocus", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = -1, Enabled = false}, player:WaitForChild("PlayerGui"))
local dimFrame = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0}, dimGui)
local blur = Instance.new("BlurEffect")
blur.Name = "WheelBlur"
blur.Size = 0
blur.Parent = game:GetService("Lighting")
local function focus(on)
	dimGui.Enabled = true
	TweenService:Create(dimFrame, TweenInfo.new(0.4), {BackgroundTransparency = on and 0.45 or 1}):Play()
	TweenService:Create(blur, TweenInfo.new(0.4), {Size = on and 10 or 0}):Play()
	if not on then
		task.delay(0.45, function()
			if dimFrame.BackgroundTransparency >= 0.99 then
				dimGui.Enabled = false
			end
		end)
	end
end
-- la ruleta se cierra (o se gira a otra tienda): el fondo vuelve a verse
panel:GetPropertyChangedSignal("Visible"):Connect(function()
	if not panel.Visible then
		focus(false)
	end
end)

-- chispas que salen disparadas del centro de la ruleta
local function sparkBurst(color, n)
	for _ = 1, n do
		local s = UI.piece("sparkle", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 30), ImageColor3 = color:Lerp(UI.WHITE, math.random() * 0.5), ZIndex = 8}, wheelBox)
		local a = math.random() * math.pi * 2
		local d = 150 + math.random() * 190
		TweenService:Create(s, TweenInfo.new(0.7 + math.random() * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, math.cos(a) * d, 0.5, math.sin(a) * d), ImageTransparency = 1, Rotation = math.random(-180, 180), Size = UDim2.fromOffset(10, 10),
		}):Play()
		task.delay(1.2, s.Destroy, s)
	end
end

-- la ruleta tiembla (más con los premios gordos)
local boxPos = wheelBox.Position
local function shakeWheel(time, amount)
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < time do
			local k = (1 - (os.clock() - t0) / time) * amount
			wheelBox.Position = boxPos + UDim2.fromOffset(math.random(-6, 6) * k, math.random(-6, 6) * k)
			RunService.RenderStepped:Wait()
		end
		wheelBox.Position = boxPos
	end)
end

local function spin(i, period, k, t, isNew)
	spinning = "anim"
	skip = false
	selected = i
	hideReveal()
	buildWheel(period)
	refreshSpin()
	focus(true)
	TweenService:Create(boxScale, TweenInfo.new(0.4, Enum.EasingStyle.Back), {Scale = 1.06}):Play()
	-- la casilla k (centrada en (k-1)*45°) acaba bajo la aguja tras unas cuantas vueltas: primero coge impulso
	-- hacia atrás, luego gira y frena poco a poco... a veces se pasa a la casilla de al lado y vuelve
	local start = rot.Rotation
	local target = rotation - rotation % 360 + 360 * 7 + (-(k - 1) * 45 + math.random(-15, 15)) % 360
	if target - start < 360 * 5 then
		target += 360
	end
	local over = math.random() < 0.55 and 20 or 7
	local WIND, MAIN, SETTLE = 0.45, Config.WHEEL_SPIN_TIME - 1.5, 0.9
	local t0, last = 0, start
	while t0 < WIND + MAIN + SETTLE do
		local dt = RunService.RenderStepped:Wait()
		t0 += dt * (skip and 5 or 1)
		local r
		if t0 < WIND then
			r = start - 20 * math.sin(math.pi / 2 * t0 / WIND)
		elseif t0 < WIND + MAIN then
			local u = (t0 - WIND) / MAIN
			r = start - 20 + (target + over - start + 20) * (1 - (1 - u) ^ 4)
		else
			local u = math.min(1, (t0 - WIND - MAIN) / SETTLE)
			r = target + over * math.cos(u * math.pi * 1.25) * (1 - u) ^ 2
		end
		angVel = (r - last) / math.max(dt, 1e-3)
		last = r
		rot.Rotation = r
		paint(r)
		blur.Size = 8 + math.min(14, math.abs(angVel) / 80)
	end
	angVel = 0
	rotation = target
	rot.Rotation = target
	paint(target)
	TweenService:Create(boxScale, TweenInfo.new(0.3), {Scale = 1}):Play()
	-- ¡premio! la casilla ganadora brilla, las demás se apagan, chispas y temblor
	local color = catColor(t)
	local jackpot = Config.isJackpot(t)
	local c = chips[k]
	for n, ch in chips do
		for _, x in ch.frame:GetChildren() do
			if x:IsA("ViewportFrame") then
				TweenService:Create(x, TweenInfo.new(0.3), {ImageTransparency = n == k and 0 or 0.7}):Play()
			end
		end
	end
	c.glow.ImageColor3 = color:Lerp(UI.WHITE, 0.3)
	c.glow.ImageTransparency = 0
	c.scale.Scale = 1.6
	TweenService:Create(c.scale, TweenInfo.new(0.7, Enum.EasingStyle.Elastic), {Scale = 1.2}):Play()
	UI.sound("Win")
	UI.sound("Sparkle")
	sparkBurst(color, jackpot and 44 or 20)
	shakeWheel(jackpot and 0.7 or 0.3, jackpot and 1.6 or 0.7)
	if jackpot then
		UI.flash(color, 0.35, 1)
		UI.sound("Boom", 0.6)
	end
	task.wait(0.9)
	focus(false)
	showReveal(t, isNew)
	-- todo vuelve a como estaba
	for _, ch in chips do
		for _, x in ch.frame:GetChildren() do
			if x:IsA("ViewportFrame") then
				x.ImageTransparency = 0
			end
		end
		ch.scale.Scale = 1
		ch.glow.ImageTransparency = ch.star.Visible and 0.35 or 1
	end
	task.wait(0.4)
	spinning = false
	refreshSpin()
end

-- los premios cambian cada 6 h: cuenta atrás y, al cambiar, la ruleta se rehace
task.spawn(function()
	while true do
		local now = workspace:GetServerTimeNow()
		local p = Config.wheelPeriod(now)
		if not spinning and (p ~= shownPeriod or selected ~= shownWheel) then
			buildWheel(p)
		end
		local left = math.max(0, math.floor((p + 1) * Config.WHEEL_ROTATE - now))
		timer.Text = ("New prizes in %02d:%02d:%02d"):format(left // 3600, left % 3600 // 60, left % 60)
		local freeAt = player:GetAttribute("FreeSpinAt")
		local secs = freeAt and math.max(0, math.floor(freeAt - now))
		local name = Config.Wheels[Config.FREE_SPIN_WHEEL].name
		freeRow.Visible = secs ~= nil
		freeText.Text = not secs and "" or secs == 0 and ("Free %s spin ready!"):format(name:gsub(" Wheel", "")) or ("Free spin in %02d:%02d:%02d"):format(secs // 3600, secs % 3600 // 60, secs % 60)
		if not spinning then
			refreshSpin()
		end
		task.wait(1)
	end
end)

---------- Saldo y avisos ----------
table.insert(refreshers, function()
	coinText.Text = UI.fmt(coins())
	balanceGems.Text = UI.fmt(gems())
	gemText.Text = UI.fmt(gems())
end)

-- al ganar gemas (Tower Defense, packs), un aviso; lo que ya tenías al entrar no avisa
local knownGems = player:GetAttribute("Gems")
player:GetAttributeChangedSignal("Gems"):Connect(function()
	local v = player:GetAttribute("Gems") or 0
	if knownGems and v > knownGems then
		UI.toast(("+%d gems"):format(v - knownGems), GEM, "gem")
	end
	knownGems = v
	refreshAll()
end)
coinStat.Changed:Connect(refreshAll)

Remote.OnClientEvent:Connect(function(kind, a, b, c, d, e)
	if kind == "Spin" then
		toggle(true, 1)
		task.spawn(spin, a, b, c, d, e)
	elseif kind == "Announce" then
		-- alguien del servidor ha conseguido un premio gordo (o una skin cara)
		if c == "skin" then
			UI.toast(("%s unlocked the %s skin!"):format(a, Config.Scares[b].name), catColor(b), "gem")
		elseif c == "fuse" then
			UI.toast(("%s fused a MYTHIC %s!"):format(a, Config.Scares[b].name), Config.STAR_COLORS[3], "star")
		else
			UI.toast(("%s got %s!"):format(a, Config.Scares[b].name), catColor(b), "trophy")
		end
		UI.sound("Jingle")
	elseif kind == "GotScare" then
		local def = Config.Scares[a]
		if not b then
			UI.notice("GOT IT", ("%s  ·  in your bag"):format(def.name), catColor(a), "bag")
			UI.sound("Success")
			return
		end
		UI.big("NEW!", def.name, catColor(a), 3)
		UI.sound("Win")
		UI.flash(catColor(a), 0.4, 0.8)
		UI.toast(("New scare: %s (in your bag)"):format(def.name), catColor(a), "bag")
	elseif kind == "GotSkin" then
		-- skin comprada: no es un susto nuevo, ya la lleva puesta su susto
		local def = Config.Scares[a]
		local col = Config.Rarities[Config.RarityIndex[def.rarity or "Rare"] or 3].color
		UI.big("NEW SKIN!", def.name, col, 3)
		UI.confetti(80)
		UI.sound("Win")
		UI.flash(col, 0.4, 0.8)
		UI.toast(("Equipped on your %s: every one you place wears it!"):format(Config.Scares[def.base].name), col, "check")
	end
end)

-- El puesto de la ruleta (workspace.Mapa.Tiendas): su mostrador la abre
game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
	local booth = prompt.Parent
	while booth and booth ~= workspace and not booth:GetAttribute("Kind") do
		booth = booth.Parent
	end
	if booth and booth:GetAttribute("Kind") == "wheel" then
		toggle(true, 1)
	end
end)

RunService.Heartbeat:Connect(function()
	-- el rayo late y se apaga al llegar (o al minuto, o si el personaje cambia)
	if guide then
		local d = distTo(guide.kind)
		if d <= REACH or os.clock() - guide.t0 > 60 or not guide.a0.Parent or not guide.a0.Parent.Parent then
			stopGuide()
		else
			local s = 0.5 + 0.5 * math.sin(os.clock() * 5)
			guide.beam.Width1 = 1.2 + s * 0.8
		end
	end
	-- te vas del puesto con la ventana abierta: se cierra (menos mientras gira la ruleta)
	if panel.Visible and not spinning and distTo(TABS[openTab].kind) > LEAVE then
		toggle(false)
	end
end)
buildWheel(currentPeriod())
refreshAll()
