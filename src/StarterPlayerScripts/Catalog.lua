-- Catalog: el estilo de las pantallas de colección (Troops y Shop), como el inventario de los juegos de defensa:
-- fondo desenfocado y oscurecido, barra de pestañas arriba en el centro (Troops · Shop · Index) con la X roja, las
-- divisas arriba a la derecha, a la izquierda un panel translúcido con buscador, filtro y secciones de cartas grises
-- (triángulo del color de la sección en la esquina, nombre abajo, la elegida con borde dorado) y a la derecha la ficha sin marco:
-- nombre enorme, subtítulo, estadísticas con icono, el modelo 3D grande, la descripción sobre una franja oscura y los
-- botones con degradado. Letra: Montserrat (GothamBlack / GothamBold).
-- Uso: local C = require(Catalog)(UI). No requiere UI (UI lo carga a su vez para montar la tienda).
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")

local player = Players.LocalPlayer
local C

return function(UI)
	if C then
		return C
	end
	C = {}
	local new = UI.new
	local W, H = 1440, 880 -- escenario (se escala a la pantalla)
	C.W, C.H = W, H
	local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
	local INK = Color3.fromRGB(14, 12, 18)
	local LEFT = Enum.TextXAlignment.Left
	local HEAVY, BOLD = Enum.Font.GothamBlack, Enum.Font.GothamBold
	C.HEAVY, C.BOLD = HEAVY, BOLD
	C.PANEL = Color3.fromRGB(12, 12, 16)
	C.EDGE = Color3.fromRGB(150, 150, 158)
	C.SELECT = Color3.fromRGB(255, 212, 0)
	C.MUTED = Color3.fromRGB(196, 196, 206)
	C.CARD = Vector2.new(140, 176)
	local CARD_TINT = ColorSequence.new(Color3.fromRGB(84, 84, 92), Color3.fromRGB(34, 34, 40))
	-- botones: {arriba, abajo, borde}
	C.KIND = {
		green = {Color3.fromRGB(110, 226, 96), Color3.fromRGB(36, 158, 50), Color3.fromRGB(200, 255, 190)},
		cyan = {Color3.fromRGB(70, 212, 255), Color3.fromRGB(16, 140, 226), Color3.fromRGB(205, 245, 255)},
		orange = {Color3.fromRGB(255, 206, 54), Color3.fromRGB(242, 146, 14), Color3.fromRGB(255, 240, 170)},
		red = {Color3.fromRGB(255, 104, 104), Color3.fromRGB(210, 34, 50), Color3.fromRGB(255, 205, 205)},
		grey = {Color3.fromRGB(134, 134, 140), Color3.fromRGB(78, 78, 86), Color3.fromRGB(208, 208, 214)},
		purple = {Color3.fromRGB(206, 104, 255), Color3.fromRGB(138, 40, 220), Color3.fromRGB(240, 205, 255)},
		dark = {Color3.fromRGB(46, 46, 52), Color3.fromRGB(24, 24, 28), Color3.fromRGB(96, 96, 106)},
	}

	local function corner(o, r)
		new("UICorner", {CornerRadius = typeof(r) == "UDim" and r or UDim.new(0, r or 8)}, o)
		return o
	end
	local function edge(o, color, t, tr)
		return new("UIStroke", {Color = color, Thickness = t or 2, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, o)
	end
	local function seq(a, b)
		return ColorSequence.new(a, b)
	end
	C.corner, C.edge = corner, edge

	-- Texto blanco con contorno oscuro fino (sin el contorno grueso automático de UI)
	function C.text(props, parent, stroke)
		props.BackgroundTransparency = 1
		props.Font = props.Font or HEAVY
		props.TextColor3 = props.TextColor3 or WHITE
		props.TextStrokeTransparency = 1
		local l = new("TextLabel", props, parent)
		if stroke ~= 0 then
			new("UIStroke", {Name = "TextOutline", Color = INK, Thickness = stroke or 2, LineJoinMode = Enum.LineJoinMode.Round, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual}, l)
		end
		return l
	end
	local text = C.text

	-- Botón con degradado, borde claro y brillo arriba; icono opcional a la izquierda del texto.
	-- Devuelve {button, label, set(texto, tipo, icono)}
	function C.button(parent, label, kind, props, icon)
		props = props or {}
		local size = props.TextSize or 24
		props.TextSize = nil
		props.Text, props.AutoButtonColor, props.BackgroundColor3 = "", false, WHITE
		local b = corner(new("TextButton", props, parent), 6)
		local grad = new("UIGradient", {Rotation = 90}, b)
		local st = edge(b, WHITE, 2)
		local shine = corner(new("Frame", {Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 0.46, 0), BackgroundColor3 = WHITE, BorderSizePixel = 0}, b), 4)
		new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(0.72, 1)}, shine)
		local row = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
		}, b)
		new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, row)
		local o = {button = b}
		o.label = text({Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X, TextSize = size, Text = label, LayoutOrder = 2}, row, 2)
		function o.set(t, k, ic)
			o.label.Text = t or o.label.Text
			local c = C.KIND[k or o.kind]
			o.kind = k or o.kind
			grad.Color = seq(c[1], c[2])
			st.Color = c[3]
			if ic ~= o.iconName then
				o.iconName = ic
				if o.icon then
					o.icon:Destroy()
					o.icon = nil
				end
				if ic then
					o.icon = UI.art(ic, {Size = UDim2.fromOffset(size + 10, size + 10), LayoutOrder = 1}, row)
				end
			end
		end
		o.set(label, kind, icon)
		UI.press(b, 1.04)
		return o
	end

	-- Etiqueta oscura con icono (información en la barra, no se pulsa). Devuelve {frame, label}
	function C.chip(parent, label, icon, props)
		props = props or {}
		props.BackgroundColor3 = WHITE
		local f = corner(new("Frame", props, parent), 6)
		new("UIGradient", {Rotation = 90, Color = seq(C.KIND.dark[1], C.KIND.dark[2])}, f)
		edge(f, C.KIND.dark[3], 2)
		local row = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1}, f)
		new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, row)
		local ic = icon and UI.art(icon, {Size = UDim2.fromOffset(32, 32), LayoutOrder = 1}, row)
		local l = text({Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X, TextSize = 20, Text = label, LayoutOrder = 2}, row, 2)
		return {frame = f, label = l, icon = ic}
	end

	---------- Pantalla ----------
	C.screens = {}
	C.openers = {} -- pestaña -> función que la abre (cada pantalla pone la suya; Index: VisitorBook)
	C.TABS = {{"Troops", "swords"}, {"Scares", "ghostart"}, {"Index", "book"}}
	local blur = Lighting:FindFirstChild("MenuBlur") or new("BlurEffect", {Name = "MenuBlur", Size = 0}, Lighting)
	local function syncBlur()
		local any = false
		for _, s in C.screens do
			any = any or s.root.Visible
		end
		TweenService:Create(blur, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {Size = any and 20 or 0}):Play()
		-- el menú y las divisas del HUD se esconden mientras (la pantalla trae los suyos)
		if UI.side then
			UI.side.Visible = not any
		end
		-- (y los avisos bajan un poco: arriba a la derecha están las divisas de la pantalla)
		if UI.toasts then
			UI.toasts.Position = UDim2.new(1, -16, 0, any and 150 or 84)
		end
	end

	function UI.closeCatalogs(except)
		for _, s in C.screens do
			if s ~= except then
				s.open(false, true)
			end
		end
	end

	-- Divisas (arriba a la derecha): monedas y gemas como en el HUD
	local moneyLabels, gemLabels = {}, {}
	local function syncMoney()
		local ls = player:FindFirstChild("leaderstats")
		local coins = ls and ls:FindFirstChild("Coins")
		for _, l in moneyLabels do
			l.Text = UI.fmt(coins and coins.Value or 0)
		end
		for _, l in gemLabels do
			l.Text = UI.fmt(player:GetAttribute("Gems") or 0)
		end
	end
	task.spawn(function()
		player:WaitForChild("leaderstats"):WaitForChild("Coins").Changed:Connect(syncMoney)
		syncMoney()
	end)
	player:GetAttributeChangedSignal("Gems"):Connect(syncMoney)

	-- C.screen(nombre, pestaña activa, bare): ScreenGui a pantalla completa. Devuelve {root, stage, open(v)}; root.Visible = abierta.
	-- s.onToggle(v) se llama al abrir y cerrar. bare: sin pestañas ni divisas (la pantalla pone las suyas; s.close es su X).
	function C.screen(name, active, bare)
		local gui = new("ScreenGui", {Name = name, ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 6, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, player:WaitForChild("PlayerGui"))
		local root = new("Frame", {Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false}, gui)
		if UI.modals then
			table.insert(UI.modals, root)
		end
		local dim = new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0, AutoButtonColor = false, Text = "", Modal = true}, root)
		new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.45, 0.55), NumberSequenceKeypoint.new(1, 0.2),
		})}, dim)
		local stage = new("Frame", {Name = "Stage", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1}, root)
		local sc = new("UIScale", {}, stage)
		local function rescale()
			local v = workspace.CurrentCamera.ViewportSize
			sc.Scale = math.clamp(math.min(v.X / (W + 40), v.Y / (H + 16)), 0.4, 1.6)
		end
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
		rescale()
		-- (el "pop" al abrir va en un marco interior: dos UIScale en el mismo objeto no se suman)
		local content = new("Frame", {Name = "Content", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1}, stage)
		local pop = new("UIScale", {}, content)

		-- pestañas (arriba en el centro) y la X
		local tabs = corner(new("Frame", {
			Name = "Tabs", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(0, 96), AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = C.PANEL, BackgroundTransparency = 0.2,
		}, content), 12)
		edge(tabs, Color3.fromRGB(74, 74, 84), 2)
		new("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}, tabs)
		new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, tabs)
		for i, t in C.TABS do
			local on = t[1] == active
			local b = corner(new("TextButton", {
				Name = t[1], Size = UDim2.fromOffset(100, 82), BackgroundColor3 = Color3.fromRGB(40, 150, 255), BackgroundTransparency = on and 0.45 or 1, Text = "",
				AutoButtonColor = false, LayoutOrder = i,
			}, tabs), 10)
			if on then
				edge(b, Color3.fromRGB(130, 205, 255), 2)
				new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(0.2, 0.8)}, b)
			end
			UI.art(t[2], {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -4), Size = UDim2.fromOffset(68, 68), ImageColor3 = on and WHITE or Color3.fromRGB(176, 176, 184)}, b)
			text({AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.new(1, 8, 0, 22), TextSize = 19, Text = t[1], ZIndex = 2}, b, 2)
			UI.press(b, 1.06)
			b.Activated:Connect(function()
				if not on and C.openers[t[1]] then
					C.openers[t[1]]()
				end
			end)
		end
		tabs.Visible = not bare
		local close = corner(new("TextButton", {Name = "Close", Size = UDim2.fromOffset(70, 70), BackgroundColor3 = WHITE, Text = "", AutoButtonColor = false, LayoutOrder = 99}, tabs), 8)
		if bare then
			close.Parent = content
		end
		new("UIGradient", {Rotation = 90, Color = seq(Color3.fromRGB(255, 92, 100), Color3.fromRGB(214, 30, 46))}, close)
		edge(close, Color3.fromRGB(255, 196, 196), 2)
		for _, r in {45, -45} do
			corner(new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(42, 10), Rotation = r, BackgroundColor3 = WHITE, BorderSizePixel = 0}, close), 3)
		end
		UI.press(close, 1.08)

		-- divisas
		local money = new("Frame", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 2), Size = UDim2.fromOffset(200, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Visible = not bare}, content)
		new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, money)
		local _, coinText = UI.currencyPill("coin", Color3.fromRGB(255, 214, 70), 1, money)
		local _, gemText = UI.currencyPill("gem", Color3.fromRGB(150, 236, 255), 2, money)
		table.insert(moneyLabels, coinText)
		table.insert(gemLabels, gemText)
		syncMoney()

		local s = {gui = gui, root = root, stage = content, name = name, close = close}
		function s.open(v, quiet)
			if v == root.Visible then
				return
			end
			if v then
				UI.closeCatalogs(s)
				if UI.toggleIndex then
					UI.toggleIndex(false)
				end
			end
			root.Visible = v
			if not quiet then
				UI.sound(v and "Open" or "Close")
			end
			if v then
				syncMoney()
				pop.Scale = 0.94
				TweenService:Create(pop, TweenInfo.new(0.22, Enum.EasingStyle.Back), {Scale = 1}):Play()
			end
			syncBlur()
			if s.onToggle then
				s.onToggle(v)
			end
		end
		close.Activated:Connect(function()
			s.open(false)
		end)
		dim.Activated:Connect(function()
			s.open(false)
		end)
		C.screens[name] = s
		return s
	end

	---------- Panel izquierdo: barra (buscador, filtro, botones) y lista con scroll ----------
	C.LEFT_X, C.TOP_Y, C.LEFT_W = 118, 112, 700
	function C.leftPanel(stage)
		local x, y, w = C.LEFT_X, C.TOP_Y, C.LEFT_W
		local bar = corner(new("Frame", {Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, 66), BackgroundColor3 = Color3.fromRGB(28, 28, 32), BackgroundTransparency = 0.1, ZIndex = 2}, stage), 8)
		local panel = corner(new("Frame", {
			Position = UDim2.fromOffset(x + 14, y + 66), Size = UDim2.fromOffset(w - 28, H - y - 66 - 12), BackgroundColor3 = C.PANEL, BackgroundTransparency = 0.38,
		}, stage), 8)
		-- buscador
		local search = corner(new("Frame", {Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(282, 46), BackgroundColor3 = Color3.fromRGB(8, 8, 10), BackgroundTransparency = 0.2}, bar), 8)
		edge(search, Color3.fromRGB(84, 84, 92), 2)
		local lens = corner(new("Frame", {Position = UDim2.fromOffset(15, 10), Size = UDim2.fromOffset(19, 19), BackgroundTransparency = 1}, search), UDim.new(1, 0))
		edge(lens, WHITE, 3)
		corner(new("Frame", {Position = UDim2.fromOffset(30, 26), Size = UDim2.fromOffset(4, 11), Rotation = -45, BackgroundColor3 = WHITE, BorderSizePixel = 0}, search), 2)
		local box = new("TextBox", {
			Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -58, 1, 0), BackgroundTransparency = 1, Font = BOLD, TextSize = 24, TextColor3 = WHITE,
			PlaceholderText = "Search...", PlaceholderColor3 = Color3.fromRGB(150, 150, 160), Text = "", ClearTextOnFocus = false, TextTruncate = Enum.TextTruncate.AtEnd,
		}, search)
		-- filtro (icono de deslizadores)
		local filter = corner(new("TextButton", {Position = UDim2.fromOffset(306, 10), Size = UDim2.fromOffset(46, 46), BackgroundColor3 = Color3.fromRGB(8, 8, 10), BackgroundTransparency = 0.2, Text = "", AutoButtonColor = false}, bar), 8)
		local filterEdge = edge(filter, Color3.fromRGB(84, 84, 92), 2)
		for i, kx in {16, 28} do
			local yy = 14 + (i - 1) * 14
			corner(new("Frame", {Position = UDim2.fromOffset(10, yy + 2), Size = UDim2.fromOffset(26, 3), BackgroundColor3 = WHITE, BorderSizePixel = 0}, filter), 2)
			local knob = corner(new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(kx, yy + 3), Size = UDim2.fromOffset(9, 9), BackgroundColor3 = Color3.fromRGB(20, 20, 24), ZIndex = 2}, filter), UDim.new(1, 0))
			edge(knob, WHITE, 2)
		end
		UI.press(filter, 1.06)
		-- a la derecha: los botones de cada pantalla
		local right = new("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(0, 48), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1}, bar)
		new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, right)

		local lp = {bar = bar, panel = panel, box = box, filter = filter, right = right}
		-- Lista con scroll (una por página; lp.list() crea otra)
		function lp.list()
			local scroll = new("ScrollingFrame", {
				Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, ScrollBarImageColor3 = Color3.fromRGB(210, 210, 216),
				ScrollBarImageTransparency = 0.15, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
				ScrollingDirection = Enum.ScrollingDirection.Y,
			}, panel)
			new("UIPadding", {PaddingLeft = UDim.new(0, 24), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 26)}, scroll)
			new("UIListLayout", {Padding = UDim.new(0, 22), SortOrder = Enum.SortOrder.LayoutOrder}, scroll)
			return scroll
		end

		-- Menú del filtro: lp.setFilters({{texto, valor}, ...}, valor actual, al elegir)
		local menu = corner(new("Frame", {
			Position = UDim2.fromOffset(306, 62), Size = UDim2.fromOffset(210, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.fromRGB(20, 20, 24),
			BackgroundTransparency = 0.04, Visible = false, ZIndex = 20,
		}, bar), 8)
		edge(menu, Color3.fromRGB(96, 96, 106), 2)
		new("UIPadding", {PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6)}, menu)
		new("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, menu)
		local filters, current, onPick = {}, nil, nil
		local function drawMenu()
			for _, c in menu:GetChildren() do
				if c:IsA("GuiObject") then
					c:Destroy()
				end
			end
			for i, f in filters do
				local on = f[2] == current
				local b = corner(new("TextButton", {
					Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = WHITE, BackgroundTransparency = on and 0.86 or 1, Text = "", AutoButtonColor = false, LayoutOrder = i, ZIndex = 21,
				}, menu), 6)
				text({Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), TextSize = 19, TextXAlignment = LEFT, Text = f[1], TextColor3 = on and C.SELECT or (f[3] or WHITE), ZIndex = 22}, b, 1.5)
				b.MouseEnter:Connect(function()
					b.BackgroundTransparency = 0.8
				end)
				b.MouseLeave:Connect(function()
					b.BackgroundTransparency = on and 0.86 or 1
				end)
				b.Activated:Connect(function()
					current = f[2]
					menu.Visible = false
					UI.sound("Tab")
					filterEdge.Color = current ~= nil and C.SELECT or Color3.fromRGB(84, 84, 92)
					onPick(current)
				end)
			end
		end
		function lp.setFilters(list, value, pick)
			filters, current, onPick = list, value, pick
			menu.Visible = false
			filterEdge.Color = current ~= nil and C.SELECT or Color3.fromRGB(84, 84, 92)
			filter.Visible = #list > 0
		end
		filter.Activated:Connect(function()
			menu.Visible = not menu.Visible
			if menu.Visible then
				drawMenu()
			end
		end)
		return lp
	end

	-- Sección con título de color y línea fina a la derecha; devuelve el contenedor y la rejilla de cartas
	function C.section(scroll, title, color, order, cell)
		cell = cell or C.CARD
		local holder = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order}, scroll)
		new("UIListLayout", {Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder}, holder)
		local head = new("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 1}, holder)
		local tw = TextService:GetTextSize(title, 32, HEAVY, Vector2.new(1000, 100)).X
		text({Size = UDim2.fromOffset(tw + 8, 40), TextSize = 32, TextColor3 = color, Text = title, TextXAlignment = LEFT}, head, 2.5)
		corner(new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, tw + 22, 0.5, 2), Size = UDim2.new(1, -(tw + 40), 0, 2), BackgroundColor3 = Color3.fromRGB(210, 210, 216),
			BackgroundTransparency = 0.45, BorderSizePixel = 0,
		}, head), 1)
		local grid = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2}, holder)
		grid:SetAttribute("Accent", color) -- (las cartas la usan en su triángulo de la esquina)
		new("UIGridLayout", {CellSize = UDim2.fromOffset(cell.X, cell.Y), CellPadding = UDim2.fromOffset(14, 14), SortOrder = Enum.SortOrder.LayoutOrder}, grid)
		return holder, grid
	end

	---------- Carta ----------
	-- o = {t = susto (modelo 3D) | art = icono, name = texto, size = Vector2}. Devuelve {button, vp, select(on), badge("check"|"lock"|nil),
	-- locked(on), color(c|nil)}
	function C.card(grid, order, o)
		local size = o.size or C.CARD
		local b = corner(new("TextButton", {Size = UDim2.fromOffset(size.X, size.Y), BackgroundColor3 = WHITE, Text = "", AutoButtonColor = false, LayoutOrder = order}, grid), 6)
		local tint = new("UIGradient", {Rotation = 90, Color = CARD_TINT}, b)
		local st = edge(b, C.EDGE, 2)
		local inner = corner(new("Frame", {Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -10, 1, -10), BackgroundTransparency = 1}, b), 4)
		edge(inner, BLACK, 1, 0.55)
		-- triángulo en la esquina, del color de su sección
		local tri = new("Frame", {Position = UDim2.fromOffset(5, 5), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = o.accent or grid:GetAttribute("Accent") or WHITE, BorderSizePixel = 0, ZIndex = 4}, b)
		new("UIGradient", {Rotation = 45, Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(0.505, 1), NumberSequenceKeypoint.new(1, 1),
		})}, tri)
		local vp
		if o.t then
			vp = UI.viewport(o.t, b, {Position = UDim2.fromOffset(4, 6), Size = UDim2.new(1, -8, 1, -26), ZIndex = 2}, true)
			if vp.CurrentCamera then
				vp.CurrentCamera.FieldOfView = 33
			end
		elseif o.art then
			vp = UI.art(o.art, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.44, 0), Size = UDim2.fromOffset(size.X * 0.7, size.X * 0.7), ZIndex = 2}, b)
		end
		local fade = corner(new("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = BLACK, BorderSizePixel = 0, ZIndex = 3}, b), 6)
		new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(1, 0.4)}, fade)
		local name = text({
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -7), Size = UDim2.new(1, -10, 0, 22), TextSize = 17, Text = o.name or "",
			TextScaled = true, ZIndex = 5,
		}, b, 2)
		new("UITextSizeConstraint", {MaxTextSize = 17, MinTextSize = 11}, name)
		-- insignia arriba a la derecha (asoma por la esquina)
		local badge = corner(new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -3, 0, 3), Size = UDim2.fromOffset(28, 28), BackgroundColor3 = WHITE, Visible = false, ZIndex = 7}, b), 6)
		local badgeGrad = new("UIGradient", {Rotation = 90}, badge)
		edge(badge, WHITE, 2)
		local badgeIcon = UI.icon("check", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(24, 24), ZIndex = 8}, badge)
		-- elegida: borde dorado y halo
		local glow = corner(new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 10, 1, 10), BackgroundTransparency = 1, Visible = false}, b), 10)
		local glowEdge = edge(glow, C.SELECT, 4, 0.6)
		local c = {button = b, vp = vp, name = name, stroke = st, pop = UI.press(b, 1.05)}
		function c.select(on)
			st.Color = on and C.SELECT or C.EDGE
			st.Thickness = on and 3 or 2
			glow.Visible = on
			glowEdge.Transparency = 0.6
		end
		function c.badge(kind)
			badge.Visible = kind ~= nil
			if kind then
				badgeGrad.Color = kind == "lock" and seq(Color3.fromRGB(255, 80, 86), Color3.fromRGB(200, 20, 36)) or seq(Color3.fromRGB(96, 230, 110), Color3.fromRGB(30, 160, 60))
				UI.setIcon(badgeIcon, kind)
			end
		end
		local tinted
		function c.color(col)
			tinted = col
			tint.Color = col and seq(col:Lerp(WHITE, 0.06), col:Lerp(BLACK, 0.6)) or CARD_TINT
		end
		function c.locked(on)
			if vp then
				vp.ImageColor3 = on and Color3.fromRGB(64, 64, 72) or WHITE
			end
			if on then
				tint.Color = seq(Color3.fromRGB(58, 58, 64), Color3.fromRGB(24, 24, 28))
			else
				c.color(tinted)
			end
		end
		return c
	end

	---------- Ficha (a la derecha) ----------
	C.DETAIL_X, C.DETAIL_Y = 846, 124
	function C.detail(stage)
		local d = new("Frame", {Name = "Detail", Position = UDim2.fromOffset(C.DETAIL_X, C.DETAIL_Y), Size = UDim2.fromOffset(W - C.DETAIL_X - 6, H - C.DETAIL_Y - 6), BackgroundTransparency = 1}, stage)
		-- franja oscura detrás de la descripción y los botones (se funde por los lados)
		local band = new("Frame", {Position = UDim2.fromOffset(-34, 494), Size = UDim2.new(1, 68, 0, 166), BackgroundColor3 = BLACK, BorderSizePixel = 0}, d)
		new("UIGradient", {Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.12, 0.5), NumberSequenceKeypoint.new(0.88, 0.5), NumberSequenceKeypoint.new(1, 1),
		})}, band)
		local model = new("Frame", {Name = "Model", Position = UDim2.fromOffset(176, 44), Size = UDim2.fromOffset(414, 460), BackgroundTransparency = 1}, d)
		local name = text({Size = UDim2.new(1, 0, 0, 64), TextSize = 58, TextScaled = true, TextXAlignment = LEFT, Text = "", ZIndex = 3}, d, 3)
		new("UITextSizeConstraint", {MaxTextSize = 58}, name)
		local sub = text({Position = UDim2.fromOffset(2, 62), Size = UDim2.new(1, 0, 0, 34), TextSize = 28, TextXAlignment = LEFT, Text = "", ZIndex = 3}, d, 2)
		local stats = new("Frame", {Position = UDim2.fromOffset(0, 116), Size = UDim2.fromOffset(240, 420), BackgroundTransparency = 1, ZIndex = 3}, d)
		new("UIListLayout", {Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder}, stats)
		local lock = text({
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 290), Size = UDim2.new(1, -20, 0, 200), TextScaled = true, TextWrapped = true, Text = "",
			Visible = false, ZIndex = 4,
		}, d, 3)
		new("UITextSizeConstraint", {MaxTextSize = 42}, lock)
		local desc = text({
			Position = UDim2.fromOffset(22, 504), Size = UDim2.new(1, -44, 0, 70), Font = BOLD, TextSize = 21, TextWrapped = true, TextXAlignment = LEFT,
			TextYAlignment = Enum.TextYAlignment.Top, Text = "", ZIndex = 3,
		}, d, 1.5)
		local buttons = new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 586), Size = UDim2.fromOffset(0, 58), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 3}, d)
		new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder}, buttons)
		local bottom = new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 662), Size = UDim2.fromOffset(0, 82), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 3}, d)
		new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}, bottom)

		local o = {frame = d, name = name, sub = sub, stats = stats, model = model, lock = lock, desc = desc, buttons = buttons, bottom = bottom}
		function o.clearModel()
			for _, x in model:GetChildren() do
				x:Destroy()
			end
		end
		-- modelo 3D grande (silhouette: en negro, como lo que aún no tienes)
		function o.setModel(t, silhouette)
			o.clearModel()
			local vp = UI.viewport(t, model, {Size = UDim2.fromScale(1, 1)})
			if vp.CurrentCamera then
				vp.CurrentCamera.FieldOfView = 31
			end
			if silhouette then
				vp.ImageColor3 = Color3.fromRGB(14, 14, 18)
			end
			return vp
		end
		-- filas {icono, valor, color, sufijo}
		function o.setStats(rows)
			for _, x in stats:GetChildren() do
				if x:IsA("GuiObject") then
					x:Destroy()
				end
			end
			for i, r in rows do
				local row = new("Frame", {Size = UDim2.fromOffset(240, 46), BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 3}, stats)
				UI.art(r[1], {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(46, 46), ZIndex = 3}, row)
				local v = text({
					Position = UDim2.fromOffset(58, 0), Size = UDim2.new(1, -58, 1, 0), TextSize = 30, TextXAlignment = LEFT, RichText = true, TextColor3 = r[3] or WHITE,
					Text = tostring(r[2]) .. (r[4] and ('<font size="19" color="#C8C8D2"> ' .. r[4] .. "</font>") or ""), ZIndex = 3,
				}, row, 2)
				v.Name = "Value"
			end
		end
		-- texto grande en el centro en vez de las estadísticas (lo que aún no se puede tener)
		function o.setLock(msg)
			lock.Text = msg or ""
			lock.Visible = msg ~= nil
			stats.Visible = msg == nil
		end
		return o
	end

	return C
end
