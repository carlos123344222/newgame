-- Shop (botón Shop del menú y el de la barra de construcción), con el estilo de las tiendas de los juegos de defensa:
-- barra lateral con las secciones a la izquierda (Featured · Passes · Scares · Houses · Wheels · Tags · Currency), una sola lista con scroll (la barra salta a cada sección y se ilumina la que se ve), la X roja y las divisas
-- arriba a la derecha (su "+" lleva a Currency).
--  * Featured: la Aspiradora de almas y las skins nuevas; los sustos premium (Robux) y las 5 ofertas del día
--    (Config.dailyDeals: acción DailyBuy) con la cuenta atrás hasta las siguientes.
--  * Passes: la Aspiradora con todo lo que hace y el resto de Config.Passes (Robux: acción RobuxBuy).
--  * Currency: los packs de monedas y gemas (Config.CoinPacks / GemPacks), con su botón de regalo (elige a quién).
--  * Daily Deals: además de los sustos por monedas, una fila de skins por gemas (Config.skinOffers del día, de las skins
--    cuyo susto base tienes; algunas rebajadas: acción BuySkin). Las skins de cada susto se ven en la pantalla Scares.
--  * Scares (su pantalla, ScareStoreUI), Houses, Wheels (al puesto de la ruleta) y Tags (comprar y equipar).
-- Uso: require(ShopUI)(UI) desde UI. Pone UI.shop (la raíz: Visible = abierta), UI.toggleShop(open, susto),
-- UI.openCurrency("coins" | "gems"), UI.refreshShop, UI.refreshHouses, UI.newlyAffordable y UI.shopBadges.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")

local Config = require(RS:WaitForChild("Config"))
local Remote = RS:WaitForChild("Remote")
local Assets = RS:WaitForChild("Assets")
local player = Players.LocalPlayer

return function(UI)
	local C = require(script.Parent:WaitForChild("Catalog"))(UI)
	local new, text, corner, edge = UI.new, C.text, C.corner, C.edge
	local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
	local LEFT, RIGHT = Enum.TextXAlignment.Left, Enum.TextXAlignment.Right
	local HORIZONTAL = Enum.FillDirection.Horizontal
	local GREY_TEXT = Color3.fromRGB(196, 196, 206)
	local VAC_GREEN = Color3.fromRGB(110, 255, 160)
	local VAC = Config.PassById.Vacuum
	local function seq(a, b)
		return ColorSequence.new(a, b)
	end
	local function tween(o, t, props, style)
		TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad), props):Play()
	end

	local screen = C.screen("Shop", "Shop", true)
	local stage = screen.stage
	UI.shop = screen.root
	C.openers.Shop = function()
		UI.toggleShop(true)
	end
	local LIST_X, LIST_W = 244, 912 -- (LIST_W: el ancho útil, ya sin la barra de scroll)

	---------- Lo que tienes ----------
	local ALL = table.clone(Config.ScareOrder)
	table.move(Config.SpecialOrder, 1, #Config.SpecialOrder, #ALL + 1, ALL)
	local function counts()
		local c = {}
		for _, t in ALL do
			c[t] = player:GetAttribute("Inv_" .. t) or 0
		end
		local plot = player:GetAttribute("Plot")
		local casas = workspace:FindFirstChild("Casas")
		local house = plot and casas and casas:FindFirstChild("Casa" .. plot)
		local placed = house and house:FindFirstChild("Scares")
		for _, m in placed and placed:GetChildren() or {} do
			if c[m.Name] then
				c[m.Name] += 1
			end
		end
		return c
	end
	local function list(attr)
		return string.split(player:GetAttribute(attr) or "", ",")
	end
	local function gems()
		return player:GetAttribute("Gems") or 0
	end
	local function catColor(t)
		return Config.Categories[Config.Scares[t].cat].color
	end
	-- skins: su rareza (el color de su carta, como en las tiendas de skins de los juegos de defensa) y si ya puedes
	-- comprarla (tienes su susto base y aún no es tuya: se compran una sola vez)
	local function skinRarity(t)
		return Config.Rarities[Config.RarityIndex[Config.Scares[t].rarity or "Rare"] or 3]
	end
	local function skinColor(t)
		return skinRarity(t).color
	end
	local function skinUnlocked(t, c)
		local base = Config.Scares[t].base
		return ((c[base] or 0) > 0 or Config.starOf(player, base) > 0) and not Config.ownsSkin(player, t)
	end

	---------- Piezas ----------
	-- botón verde con precio (gris con lo que falta si no llegas)
	local function setPrice(o, price, have, icon)
		local can = have >= price
		o.set(can and UI.fmt(price) or ("Need %s"):format(UI.fmt(price - have)), can and "green" or "grey", icon)
	end

	-- franjas diagonales finas en el fondo de las cartas (como las de la referencia)
	local STRIPES = (function()
		local keys, n = {}, 9
		for i = 0, n do
			local a = i / n
			local on = i % 2 == 0
			table.insert(keys, NumberSequenceKeypoint.new(a, on and 0.93 or 1))
			if i < n then
				table.insert(keys, NumberSequenceKeypoint.new(math.min(1, a + 1 / n - 0.001), on and 0.93 or 1))
			end
		end
		return NumberSequence.new(keys)
	end)()
	local function stripes(parent)
		local f = corner(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = parent.ZIndex}, parent), 8)
		new("UIGradient", {Rotation = 120, Transparency = STRIPES}, f)
		return f
	end

	-- carta: botón con degradado y borde fino
	local function card(parent, size, order, top, bottom, edgeColor)
		local b = corner(new("TextButton", {Size = UDim2.fromOffset(size.X, size.Y), BackgroundColor3 = WHITE, Text = "", AutoButtonColor = false, LayoutOrder = order}, parent), 8)
		local g = new("UIGradient", {Rotation = 90, Color = seq(top, bottom)}, b)
		local st = edge(b, edgeColor or Color3.fromRGB(104, 104, 114), 2)
		local pop = UI.press(b, 1.03)
		b.MouseEnter:Connect(function()
			st.Color = WHITE
		end)
		b.MouseLeave:Connect(function()
			st.Color = edgeColor or Color3.fromRGB(104, 104, 114)
		end)
		return b, g, st, pop
	end

	-- vista 3D de un modelo cualquiera (la aspiradora), girando despacio
	local turning = {}
	local function modelView(model, parent, props, from)
		local vp = new("ViewportFrame", props, parent)
		vp.BackgroundTransparency = 1
		vp.Ambient = Color3.fromRGB(190, 180, 210)
		vp.LightColor = Color3.fromRGB(255, 246, 232)
		vp.LightDirection = Vector3.new(-0.6, -1, -0.9)
		local m = model:Clone()
		for _, d in m:GetDescendants() do
			if d:IsA("Sound") or d:IsA("LuaSourceContainer") or d:IsA("ParticleEmitter") or d:IsA("Trail") then
				d:Destroy()
			end
		end
		m.Parent = vp
		local cf, size = m:GetBoundingBox()
		local cam = new("Camera", {FieldOfView = 34}, vp)
		vp.CurrentCamera = cam
		local dist = math.max(size.X, size.Y, size.Z) * 1.75
		local dir = (from or Vector3.new(-0.55, 0.32, -1)).Unit
		local base = CFrame.lookAt(cf.Position + dir * dist, cf.Position)
		cam.CFrame = base
		table.insert(turning, {vp = vp, cam = cam, center = cf.Position, base = base})
		return vp
	end
	RunService.RenderStepped:Connect(function()
		if not screen.root.Visible then
			return
		end
		local a = math.sin(os.clock() * 0.7) * 0.55
		for _, s in turning do
			s.cam.CFrame = CFrame.new(s.center) * CFrame.Angles(0, a, 0) * CFrame.new(-s.center) * s.base
		end
	end)

	-- ficha al pasar el ratón (qué es y qué hace)
	local tip = corner(new("Frame", {Size = UDim2.fromOffset(300, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.fromRGB(16, 16, 20), BackgroundTransparency = 0.04, Visible = false, ZIndex = 40}, stage), 8)
	edge(tip, Color3.fromRGB(120, 120, 132), 2)
	new("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14)}, tip)
	new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, tip)
	local tipName = text({Size = UDim2.new(1, 0, 0, 26), TextSize = 22, TextXAlignment = LEFT, Text = "", LayoutOrder = 1, ZIndex = 41}, tip, 2)
	local tipDesc = text({Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = C.BOLD, TextSize = 15, TextWrapped = true, TextXAlignment = LEFT, TextColor3 = GREY_TEXT, Text = "", LayoutOrder = 2, ZIndex = 41}, tip, 1)
	local tipStats = text({Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 15, TextWrapped = true, TextXAlignment = LEFT, TextColor3 = UI.GOLD, Text = "", RichText = true, LayoutOrder = 3, ZIndex = 41}, tip, 1.5)
	local tipOwner
	local function hoverTip(b, fill)
		b.MouseEnter:Connect(function()
			local name, desc, stats = fill()
			tipName.Text, tipDesc.Text, tipStats.Text = name, desc or "", stats or ""
			tipStats.Visible = stats ~= nil
			tipOwner = b
			tip.Visible = true
		end)
		b.MouseLeave:Connect(function()
			if tipOwner == b then
				tip.Visible = false
			end
		end)
	end
	RunService.RenderStepped:Connect(function()
		if tip.Visible then
			if not (tipOwner and tipOwner.Parent and screen.root.Visible) then
				tip.Visible = false
				return
			end
			local m = UserInputService:GetMouseLocation() - game:GetService("GuiService"):GetGuiInset()
			local sa, sp = stage.AbsoluteSize, stage.AbsolutePosition
			local k = sa.X / C.W
			local x, y = (m.X - sp.X) / k + 18, (m.Y - sp.Y) / k + 18
			if x + 300 > C.W then
				x -= 336
			end
			tip.Position = UDim2.fromOffset(x, math.min(y, C.H - tip.AbsoluteSize.Y / k - 6))
		end
	end)

	---------- La X y las divisas ----------
	local close = screen.close
	close.AnchorPoint, close.Position, close.Size = Vector2.new(0, 0), UDim2.fromOffset(1178, 20), UDim2.fromOffset(64, 64)
	local function moneyRow(y, art, caption, color, order)
		local f = new("Frame", {Position = UDim2.fromOffset(1252, y), Size = UDim2.fromOffset(188, 58), BackgroundTransparency = 1}, stage)
		local plus = corner(new("TextButton", {Position = UDim2.fromOffset(0, 14), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = WHITE, Text = "", AutoButtonColor = false}, f), 6)
		new("UIGradient", {Rotation = 90, Color = seq(Color3.fromRGB(70, 212, 255), Color3.fromRGB(16, 140, 226))}, plus)
		edge(plus, Color3.fromRGB(205, 245, 255), 2)
		for _, s in {Vector2.new(18, 5), Vector2.new(5, 18)} do
			corner(new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(s.X, s.Y), BackgroundColor3 = WHITE, BorderSizePixel = 0}, plus), 2)
		end
		UI.press(plus, 1.1)
		UI.art(art, {Position = UDim2.fromOffset(36, 4), Size = UDim2.fromOffset(50, 50)}, f)
		text({Position = UDim2.fromOffset(90, 2), Size = UDim2.fromOffset(100, 26), TextSize = 24, TextXAlignment = LEFT, Text = caption}, f, 2.5)
		local amt = text({Position = UDim2.fromOffset(90, 28), Size = UDim2.fromOffset(100, 28), TextSize = 25, TextXAlignment = LEFT, TextColor3 = color, Text = "0"}, f, 2.5)
		return amt, plus
	end
	local coinAmt, coinPlus = moneyRow(84, "coin", "Coins", Color3.fromRGB(255, 214, 70))
	local gemAmt, gemPlus = moneyRow(150, "gem", "Gems", Color3.fromRGB(190, 140, 255))

	---------- Barra lateral y lista ----------
	local SECTIONS = {
		{id = "featured", name = "Featured", art = "featured"},
		{id = "passes", name = "Passes", art = "pass"},
		{id = "scares", name = "Scares", art = "ghostart"},
		{id = "houses", name = "Houses", art = "house"},
		{id = "wheels", name = "Wheels", art = "wheelart"},
		{id = "tags", name = "Tags", art = "tagart"},
		{id = "currency", name = "Currency", art = "currency"},
	}
	local nav = corner(new("Frame", {
		Name = "Nav", Position = UDim2.fromOffset(110, 118), Size = UDim2.fromOffset(112, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.fromRGB(14, 14, 18),
		BackgroundTransparency = 0.22,
	}, stage), 30)
	edge(nav, Color3.fromRGB(78, 78, 90), 2)
	new("UIPadding", {PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12)}, nav)
	new("UIListLayout", {Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}, nav)

	local scroll = new("ScrollingFrame", {
		Name = "Lista", Position = UDim2.fromOffset(LIST_X, 0), Size = UDim2.fromOffset(LIST_W + 22, C.H), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
		ScrollBarImageColor3 = Color3.fromRGB(210, 210, 216), ScrollBarImageTransparency = 0.2, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y, VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
	}, stage)
	new("UIPadding", {PaddingTop = UDim.new(0, 20), PaddingBottom = UDim.new(0, 60), PaddingRight = UDim.new(0, 14), PaddingLeft = UDim.new(0, 4)}, scroll)
	new("UIListLayout", {Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder}, scroll)

	-- título de sección (blanco, con línea debajo) o subtítulo (gris)
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	local function header(title, sub)
		local f = new("Frame", {Size = UDim2.new(1, 0, 0, sub and 40 or 56), BackgroundTransparency = 1, LayoutOrder = nextOrder()}, scroll)
		local l = text({
			Position = UDim2.fromOffset(sub and 0 or 2, sub and 2 or 0), Size = UDim2.new(0.7, 0, 0, sub and 36 or 46), TextSize = sub and 28 or 38, TextXAlignment = LEFT, Text = title,
			TextColor3 = sub and Color3.fromRGB(176, 176, 186) or WHITE,
		}, f, sub and 2 or 2.5)
		if not sub then
			new("Frame", {Position = UDim2.new(0, 0, 1, -4), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Color3.fromRGB(200, 200, 208), BackgroundTransparency = 0.5, BorderSizePixel = 0}, f)
		end
		return f, l
	end
	local function row(height, cols, cell)
		local f = new("Frame", {Size = UDim2.new(1, 0, 0, height or 0), AutomaticSize = height and Enum.AutomaticSize.None or Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = nextOrder()}, scroll)
		if cols then
			-- (las columnas se reparten el ancho que haya: la barra de scroll y la escala lo cambian un poco)
			local pad = 16
			new("UIGridLayout", {CellSize = UDim2.new(1 / cols, -pad * (cols - 1) / cols - 1, 0, cell.Y), CellPadding = UDim2.fromOffset(pad, pad), SortOrder = Enum.SortOrder.LayoutOrder}, f)
		else
			new("UIListLayout", {FillDirection = HORIZONTAL, Padding = UDim.new(0, 18), SortOrder = Enum.SortOrder.LayoutOrder}, f)
		end
		return f
	end
	-- "Show more": la rejilla enseña las primeras n cartas hasta que se pulsa
	local function showMore(cards, n)
		local holder = new("Frame", {Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, LayoutOrder = nextOrder()}, scroll)
		local b = C.button(holder, "Show more", "cyan", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(250, 50), TextSize = 22})
		local open = false
		local function apply()
			for i, c in cards do
				c.Visible = open or i <= n
			end
			holder.Visible = #cards > n
			b.set(open and "Show less" or "Show more", "cyan")
		end
		b.button.Activated:Connect(function()
			open = not open
			UI.sound("Tab")
			apply()
		end)
		return apply
	end

	local anchors = {} -- [id] = encabezado de su sección
	local navButtons = {}
	local current
	local function highlight(id)
		if current == id then
			return
		end
		current = id
		for sid, nb in navButtons do
			local on = sid == id
			nb.button.BackgroundTransparency = on and 0.5 or 1
			nb.stroke.Enabled = on
			nb.art.ImageColor3 = on and WHITE or Color3.fromRGB(186, 186, 194)
			nb.label.TextColor3 = on and WHITE or Color3.fromRGB(214, 214, 222)
		end
	end
	local function scrollTo(id)
		local a = anchors[id]
		if not a then
			return
		end
		-- (CanvasPosition va en píxeles de pantalla, como AbsolutePosition)
		local k = scroll.AbsoluteSize.Y / C.H
		local y = scroll.CanvasPosition.Y + (a.AbsolutePosition.Y - scroll.AbsolutePosition.Y) - 14 * k
		local max = math.max(0, scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteSize.Y)
		tween(scroll, 0.35, {CanvasPosition = Vector2.new(0, math.clamp(y, 0, max))}, Enum.EasingStyle.Quart)
	end
	for i, s in SECTIONS do
		local b = corner(new("TextButton", {
			Name = s.name, Size = UDim2.fromOffset(98, 94), BackgroundColor3 = Color3.fromRGB(40, 150, 255), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = i,
		}, nav), 16)
		new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(0.1, 0.7)}, b)
		local st = edge(b, Color3.fromRGB(130, 205, 255), 2)
		st.Enabled = false
		local art = UI.art(s.art, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(66, 66)}, b)
		local l = text({AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3), Size = UDim2.new(1, 10, 0, 22), TextSize = 17, Text = s.name, ZIndex = 2}, b, 2.2)
		UI.press(b, 1.07)
		b.Activated:Connect(function()
			UI.sound("Tab")
			if s.id == "scares" then
				-- los sustos se compran en su pantalla (como las tropas)
				return UI.toggleScares(true)
			end
			highlight(s.id)
			scrollTo(s.id)
		end)
		navButtons[s.id] = {button = b, stroke = st, art = art, label = l}
	end
	-- al hacer scroll se ilumina la sección que se ve
	scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		local top = scroll.AbsolutePosition.Y + scroll.AbsoluteSize.Y * 0.18
		local pick = SECTIONS[1].id
		for _, s in SECTIONS do
			local a = anchors[s.id]
			if a and a.AbsolutePosition.Y <= top then
				pick = s.id
			end
		end
		-- al final del todo, la última (su título ya no puede subir hasta arriba)
		if scroll.CanvasPosition.Y >= scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteSize.Y - 4 and anchors[SECTIONS[#SECTIONS].id] then
			pick = SECTIONS[#SECTIONS].id
		end
		highlight(pick)
	end)
	highlight("featured")

	local refreshers = {}
	local function refreshAll()
		for _, f in refreshers do
			f()
		end
	end

	---------- Comprar / ir al puesto ----------
	local function goStall(kind, why)
		UI.toggleShop(false)
		if UI.goToStall then
			UI.goToStall(kind, why)
		end
	end
	-- con Robux: el servidor abre la compra de Roblox (kind: "pass" | "pack" | "scare"; giftTo: UserId)
	local function buyRobux(kind, id, giftTo)
		UI.sound("Tab")
		Remote:FireServer("RobuxBuy", kind, id, giftTo)
	end
	local function ownsPass(p)
		return player:GetAttribute(p.id == "Vacuum" and "Vacuum" or "Pass_" .. p.id) == true
	end

	-- lo que gira o flota mientras la tienda está abierta (rayos detrás de las ilustraciones)
	local spinners = {}
	RunService.RenderStepped:Connect(function()
		if screen.root.Visible then
			local t = os.clock()
			for _, f in spinners do
				f(t)
			end
		end
	end)
	local function spinRays(rays, speed)
		table.insert(spinners, function(t)
			rays.Rotation = t * (speed or 14)
		end)
	end
	local function bob(o, amp, phase)
		local base = o.Position
		table.insert(spinners, function(t)
			o.Position = base + UDim2.fromOffset(0, math.sin(t * 2 + (phase or 0)) * (amp or 4))
		end)
	end

	-- colores de los packs (monedas: amarillo; gemas: morado), en sus cartas y en la cabecera del regalo
	local PACK_STYLE = {
		[false] = {top = Color3.fromRGB(255, 226, 84), bottom = Color3.fromRGB(244, 158, 18), edge = Color3.fromRGB(255, 246, 200), icon = "coin", word = "coins", glow = Color3.fromRGB(255, 252, 214)},
		[true] = {top = Color3.fromRGB(196, 130, 255), bottom = Color3.fromRGB(116, 48, 210), edge = Color3.fromRGB(236, 214, 255), icon = "gem", word = "gems", glow = Color3.fromRGB(200, 250, 255)},
	}

	---------- Regalar un pack: a quién del servidor ----------
	-- Cabecera del color del pack con su ilustración; debajo, los jugadores (o, si no hay nadie, invitar amigos)
	-- (el oscurecido sobrepasa el escenario: tapa toda la pantalla, sea cual sea su forma)
	local giftDim = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(4, 4), BackgroundColor3 = BLACK, BackgroundTransparency = 0.45, Text = "",
		AutoButtonColor = false, Visible = false, ZIndex = 50,
	}, stage)
	local gbox = corner(new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 9), Size = UDim2.fromOffset(560, 540), BackgroundColor3 = WHITE, Text = "", AutoButtonColor = false, ZIndex = 51,
	}, giftDim), 14)
	new("UIGradient", {Rotation = 90, Color = seq(Color3.fromRGB(52, 52, 60), Color3.fromRGB(22, 22, 26))}, gbox)
	edge(gbox, Color3.fromRGB(150, 150, 160), 2)
	local gPop = new("UIScale", {}, gbox)
	local band = corner(new("Frame", {Size = UDim2.new(1, 0, 0, 124), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 51}, gbox), 14)
	local bandGrad = new("UIGradient", {Rotation = 90}, band)
	-- (esquinas de abajo rectas: tapa con el color del final del degradado)
	local bandFoot = new("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 16), BorderSizePixel = 0, ZIndex = 51}, band)
	corner(new("ImageLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = UI.PATTERN, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(120, 120), ImageTransparency = 0.86, ZIndex = 51}, band), 14)
	local gPack = UI.art("coins1", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(78, 64), Size = UDim2.fromOffset(118, 118), ZIndex = 53}, gbox)
	bob(gPack, 4)
	local gArt = UI.art("gift", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(122, 100), Size = UDim2.fromOffset(54, 54), Rotation = 12, ZIndex = 54}, gbox)
	bob(gArt, 3, 1.5)
	text({Position = UDim2.fromOffset(150, 34), Size = UDim2.new(1, -224, 0, 42), TextSize = 36, TextXAlignment = LEFT, Text = "Send a Gift", ZIndex = 52}, gbox, 3)
	local gSub = text({Position = UDim2.fromOffset(151, 76), Size = UDim2.new(1, -224, 0, 28), TextSize = 22, TextXAlignment = LEFT, Text = "", RichText = true, ZIndex = 52}, gbox, 2.5)
	local gList = corner(new("ScrollingFrame", {
		Position = UDim2.fromOffset(20, 134), Size = UDim2.new(1, -40, 1, -154), BackgroundColor3 = Color3.fromRGB(10, 10, 14), BackgroundTransparency = 0.35, BorderSizePixel = 0,
		ScrollBarThickness = 5, ScrollBarImageColor3 = Color3.fromRGB(210, 210, 216), AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 52,
	}, gbox), 10)
	new("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 14)}, gList)
	new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, gList)
	-- nadie más en el servidor: icono, texto y el botón de invitar (SocialService)
	local gEmpty = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 336), Size = UDim2.fromOffset(440, 260), BackgroundTransparency = 1, ZIndex = 53}, gbox)
	local emptyIcon = UI.icon("users", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(84, 84), ZIndex = 53}, gEmpty)
	bob(emptyIcon, 4)
	text({
		Position = UDim2.fromOffset(0, 92), Size = UDim2.new(1, 0, 0, 60), Font = C.BOLD, TextSize = 21, TextWrapped = true, TextColor3 = GREY_TEXT,
		Text = "Nobody else is in this server yet.\nInvite a friend to send them a gift!", ZIndex = 53,
	}, gEmpty, 1.5)
	local invite = C.button(gEmpty, "INVITE FRIENDS", "cyan", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 170), Size = UDim2.fromOffset(280, 58), TextSize = 24, ZIndex = 54}, "users")
	invite.button.Activated:Connect(function()
		local Social = game:GetService("SocialService")
		local ok, can = pcall(Social.CanSendGameInviteAsync, Social, player)
		if ok and can then
			Social:PromptGameInvite(player)
		else
			UI.toast("Invites aren't available right now", UI.ORANGE, "users")
		end
	end)
	local gClose = corner(new("TextButton", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.fromOffset(46, 46), BackgroundColor3 = WHITE, Text = "", AutoButtonColor = false, ZIndex = 53}, gbox), 8)
	new("UIGradient", {Rotation = 90, Color = seq(Color3.fromRGB(255, 92, 100), Color3.fromRGB(214, 30, 46))}, gClose)
	edge(gClose, Color3.fromRGB(255, 196, 196), 2)
	for _, r in {45, -45} do
		corner(new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(28, 7), Rotation = r, BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 54}, gClose), 2)
	end
	UI.press(gClose, 1.08)
	local function closeGift()
		giftDim.Visible = false
		UI.sound("Close")
	end
	gClose.Activated:Connect(closeGift)
	giftDim.Activated:Connect(closeGift)
	local function openGift(pack)
		local s = PACK_STYLE[pack.gems == true]
		bandGrad.Color = seq(s.top, s.bottom)
		bandFoot.BackgroundColor3 = s.bottom
		gPack.Image = UI.ART[pack.art]
		gSub.Text = ('%s %s  ·  <font color="#B4FFB4">R$ %s</font>'):format(UI.fmt(pack.amount), s.word, UI.fmt(pack.robux))
		for _, c in gList:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local n = 0
		for _, other in Players:GetPlayers() do
			if other == player then
				continue
			end
			n += 1
			local e = corner(new("Frame", {Size = UDim2.new(1, 0, 0, 74), BackgroundColor3 = Color3.fromRGB(44, 44, 52), BackgroundTransparency = 0.15, LayoutOrder = n, ZIndex = 53}, gList), 10)
			edge(e, Color3.fromRGB(90, 90, 100), 1.5)
			local head = corner(new("ImageLabel", {Position = UDim2.fromOffset(9, 9), Size = UDim2.fromOffset(56, 56), BackgroundColor3 = Color3.fromRGB(80, 80, 92), ZIndex = 54}, e), UDim.new(1, 0))
			edge(head, WHITE, 2)
			task.spawn(function()
				local ok, img = pcall(Players.GetUserThumbnailAsync, Players, other.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
				if ok then
					head.Image = img
				end
			end)
			text({Position = UDim2.fromOffset(78, 11), Size = UDim2.new(1, -230, 0, 28), TextSize = 23, TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd, Text = other.DisplayName, ZIndex = 54}, e, 2)
			text({Position = UDim2.fromOffset(79, 40), Size = UDim2.new(1, -230, 0, 20), Font = C.BOLD, TextSize = 16, TextXAlignment = LEFT, TextColor3 = GREY_TEXT, Text = "@" .. other.Name, ZIndex = 54}, e, 1)
			local gb = C.button(e, "GIFT", "cyan", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(132, 52), TextSize = 22, ZIndex = 55}, "gift")
			gb.button.Activated:Connect(function()
				giftDim.Visible = false
				buyRobux("pack", pack.id, other.UserId)
			end)
		end
		gEmpty.Visible = n == 0
		tip.Visible = false
		giftDim.Visible = true
		gPop.Scale = 0.8
		tween(gPop, 0.25, {Scale = 1}, Enum.EasingStyle.Back)
		UI.sound("Open")
	end

	---------- Carta de un pack de monedas o gemas ----------
	-- Como las de la referencia: fondo de color con dibujo, título y cantidad arriba a la izquierda, la ilustración grande
	-- y abajo el botón de Robux y el de regalo; la cinta roja "+N% MORE" asoma por la derecha. big: la carta alta.
	local function packCard(parent, pack, pos, size)
		local s = PACK_STYLE[pack.gems == true]
		local big = pack.big == true
		local b = corner(new("TextButton", {Position = pos, Size = size, BackgroundColor3 = WHITE, Text = "", AutoButtonColor = false}, parent), 12)
		new("UIGradient", {Rotation = 90, Color = seq(s.top, s.bottom)}, b)
		local st = edge(b, s.edge, 3)
		corner(new("ImageLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = UI.PATTERN, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(120, 120), ImageTransparency = 0.86}, b), 12)
		local shine = corner(new("Frame", {Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, big and 150 or 90), BackgroundColor3 = WHITE, BorderSizePixel = 0}, b), 10)
		new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(0.7, 1)}, shine)
		-- ilustración (con brillo detrás; la alta, también rayos girando)
		local artCenter = big and UDim2.fromScale(0.5, 0.57) or UDim2.new(1, -86, 1, -92)
		if big then
			local rays = UI.piece("rays", {AnchorPoint = Vector2.new(0.5, 0.5), Position = artCenter, Size = UDim2.fromOffset(420, 420), ImageColor3 = WHITE, ImageTransparency = 0.72}, b)
			spinRays(rays, 10)
		end
		UI.piece("glow2", {AnchorPoint = Vector2.new(0.5, 0.5), Position = artCenter, Size = big and UDim2.fromOffset(330, 330) or UDim2.fromOffset(200, 180), ImageColor3 = s.glow, ImageTransparency = 0.3}, b)
		local art = UI.art(pack.art, big and {AnchorPoint = Vector2.new(0.5, 0.5), Position = artCenter, Size = UDim2.new(1, -16, 0, 300), ZIndex = 2}
			or {AnchorPoint = Vector2.new(0.5, 0.5), Position = artCenter, Size = UDim2.fromOffset(176, 176), ZIndex = 2}, b)
		bob(art, big and 5 or 3, #pack.id)
		-- título y cantidad
		-- (con cinta, el título se encoge si no cabe a su lado)
		local title = text({Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, pack.bonus and -130 or -30, 0, 38), TextSize = 31, TextScaled = true, TextXAlignment = LEFT, Text = pack.name, ZIndex = 4}, b, 3)
		new("UITextSizeConstraint", {MaxTextSize = 31}, title)
		local amt = new("Frame", {Position = UDim2.fromOffset(16, 50), Size = UDim2.fromOffset(0, 38), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 4}, b)
		new("UIListLayout", {FillDirection = HORIZONTAL, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, amt)
		UI.art(s.icon, {Size = UDim2.fromOffset(36, 36), LayoutOrder = 1, ZIndex = 4}, amt)
		text({Size = UDim2.fromOffset(0, 38), AutomaticSize = Enum.AutomaticSize.X, TextSize = 30, Text = UI.fmt(pack.amount), LayoutOrder = 2, ZIndex = 4}, amt, 3)
		-- botones
		local bw = big and 134 or 112
		local buy = C.button(b, UI.fmt(pack.robux), "green", {Position = UDim2.new(0, 14, 1, -64), Size = UDim2.fromOffset(bw, 50), TextSize = 23, ZIndex = 5}, "robux")
		local gift = C.button(b, "", "green", {Position = UDim2.new(0, bw + 22, 1, -64), Size = UDim2.fromOffset(50, 50), TextSize = 23, ZIndex = 5}, "gift")
		gift.label.Visible = false
		gift.icon.Size = UDim2.fromOffset(40, 40)
		-- cinta "+N% MORE" (con su punta a la izquierda)
		if pack.bonus then
			local red1, red2 = Color3.fromRGB(255, 84, 84), Color3.fromRGB(204, 18, 38)
			local tipF = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -86, 0, 39), Size = UDim2.fromOffset(34, 34), Rotation = 45, BackgroundColor3 = red1:Lerp(red2, 0.5), BorderSizePixel = 0, ZIndex = 6}, b)
			edge(tipF, Color3.fromRGB(255, 200, 200), 2)
			local rib = corner(new("Frame", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 8, 0, 15), Size = UDim2.fromOffset(94, 48), BackgroundColor3 = WHITE, ZIndex = 7}, b), 3)
			new("UIGradient", {Rotation = 90, Color = seq(red1, red2)}, rib)
			local ribEdge = edge(rib, Color3.fromRGB(255, 200, 200), 2)
			ribEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			text({Size = UDim2.fromScale(1, 1), TextSize = 18, LineHeight = 0.92, Text = ("+%d%%\nMORE"):format(pack.bonus), ZIndex = 8}, rib, 2)
			-- (tapa la línea del borde entre la punta y la cinta)
			new("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(3, 44), BackgroundColor3 = red1:Lerp(red2, 0.5), BorderSizePixel = 0, ZIndex = 8}, rib)
		end
		local pop = UI.press(b, 1.025)
		b.MouseEnter:Connect(function()
			st.Color = WHITE
		end)
		b.MouseLeave:Connect(function()
			st.Color = s.edge
		end)
		local function buy1()
			pop.Scale = 0.96
			tween(pop, 0.3, {Scale = 1}, Enum.EasingStyle.Back)
			buyRobux("pack", pack.id)
		end
		b.Activated:Connect(buy1)
		buy.button.Activated:Connect(buy1)
		gift.button.Activated:Connect(function()
			openGift(pack)
		end)
		hoverTip(b, function()
			return pack.name, ("%s %s for R$ %s"):format(UI.fmt(pack.amount), s.word, UI.fmt(pack.robux)),
				(pack.bonus and ('<font color="#FF8A8A">+%d%% more value!</font>  '):format(pack.bonus) or "") .. "Tap the gift to send it to a friend"
		end)
		return b
	end

	---------- Contenido (se construye al abrirla la primera vez) ----------
	local built = false
	local VAC_ROWS = {
		"Collects every coin in your house automatically: no more running around",
		("Stores what it sucks up while you're away, then gives it all back with a big WELCOME BACK!"),
		("Your house keeps producing x%d longer before coins start slowing down"):format(Config.VACUUM_CAP),
		"A glowing Soul Vacuum in your yard, for every visitor to see",
		"Works forever, in every server",
	}

	local function build()
		built = true
		local vacModel = Assets:FindFirstChild("Aspiradora")

		---------- Featured ----------
		anchors.featured = header("Featured")
		local feat = row(nil, 2, Vector2.new(447, 236))
		-- 1) la Aspiradora de almas
		do
			local b = card(feat, Vector2.new(447, 236), 1, Color3.fromRGB(70, 40, 128), Color3.fromRGB(16, 58, 44), Color3.fromRGB(150, 240, 190))
			local rays = UI.piece("rays", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(250, 136), Size = UDim2.fromOffset(340, 340), ImageColor3 = VAC_GREEN, ImageTransparency = 0.72}, b)
			spinRays(rays)
			UI.piece("glow2", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(250, 140), Size = UDim2.fromOffset(300, 260), ImageColor3 = VAC_GREEN, ImageTransparency = 0.5}, b)
			if vacModel then
				-- en el centro, bajo el título, grande (el precio queda a su izquierda)
				local vp = modelView(vacModel, b, {Position = UDim2.fromOffset(110, 46), Size = UDim2.fromOffset(280, 190), ZIndex = 2})
				vp.CurrentCamera.FieldOfView = 27
			end
			text({AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 12), Size = UDim2.fromOffset(300, 40), TextSize = 34, TextXAlignment = RIGHT, Text = "Soul Vacuum", ZIndex = 3}, b, 2.5)
			text({AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 50), Size = UDim2.fromOffset(300, 30), TextSize = 27, TextXAlignment = RIGHT, Text = "Gamepass", TextColor3 = Color3.fromRGB(255, 110, 210), ZIndex = 3}, b, 2.5)
			local priceRow = new("Frame", {Position = UDim2.new(0, 16, 1, -60), Size = UDim2.fromOffset(0, 50), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 3}, b)
			new("UIListLayout", {FillDirection = HORIZONTAL, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, priceRow)
			local pIcon = UI.art("robux", {Size = UDim2.fromOffset(42, 42), LayoutOrder = 1, ZIndex = 3}, priceRow)
			local pText = text({Size = UDim2.fromOffset(0, 50), AutomaticSize = Enum.AutomaticSize.X, TextSize = 40, Text = "", LayoutOrder = 2, ZIndex = 3}, priceRow, 3)
			-- cinta "New" que asoma por la esquina
			local tag = corner(new("Frame", {Position = UDim2.fromOffset(-14, 18), Size = UDim2.fromOffset(98, 44), BackgroundColor3 = WHITE, ZIndex = 6}, b), 4)
			new("UIGradient", {Rotation = 90, Color = seq(Color3.fromRGB(255, 70, 80), Color3.fromRGB(200, 20, 40))}, tag)
			edge(tag, Color3.fromRGB(255, 190, 190), 2)
			text({Size = UDim2.fromScale(1, 1), TextSize = 28, Text = "New", ZIndex = 7}, tag, 2.5)
			table.insert(refreshers, function()
				local owned = player:GetAttribute("Vacuum") == true
				pIcon.Visible = not owned
				pText.Text = owned and "OWNED" or UI.fmt(VAC.robux)
				pText.TextColor3 = owned and Color3.fromRGB(150, 255, 150) or WHITE
			end)
			b.Activated:Connect(function()
				if ownsPass(VAC) then
					return scrollTo("passes")
				end
				buyRobux("pass", VAC.id)
			end)
			hoverTip(b, function()
				return "Soul Vacuum", "Collects every coin in your house for you, even while you explore. Tap to see everything it does.", nil
			end)
		end
		-- 2) las skins (con gemas): enseña la mejor que ya puedes comprar (si no, la más cara) y lleva a su sección
		do
			local b = card(feat, Vector2.new(447, 236), 2, Color3.fromRGB(96, 40, 160), Color3.fromRGB(18, 12, 40), Color3.fromRGB(210, 170, 255))
			local rays = UI.piece("rays", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(318, 136), Size = UDim2.fromOffset(340, 340), ImageColor3 = Color3.fromRGB(200, 150, 255), ImageTransparency = 0.74}, b)
			spinRays(rays, -12)
			local glow = UI.piece("glow2", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(318, 140), Size = UDim2.fromOffset(300, 270), ImageColor3 = Color3.fromRGB(190, 130, 255), ImageTransparency = 0.45}, b)
			local holder = new("Frame", {Position = UDim2.fromOffset(186, 26), Size = UDim2.fromOffset(256, 208), BackgroundTransparency = 1, ZIndex = 2}, b)
			text({Position = UDim2.fromOffset(18, 12), Size = UDim2.fromOffset(300, 40), TextSize = 34, TextXAlignment = LEFT, Text = "Skins", ZIndex = 3}, b, 2.5)
			text({Position = UDim2.fromOffset(18, 50), Size = UDim2.fromOffset(300, 30), TextSize = 27, TextXAlignment = LEFT, Text = "Limited offers", TextColor3 = Color3.fromRGB(255, 110, 110), ZIndex = 3}, b, 2.5)
			local sub = text({Position = UDim2.fromOffset(19, 84), Size = UDim2.fromOffset(190, 26), TextSize = 21, TextScaled = true, TextXAlignment = LEFT, Text = "", ZIndex = 3}, b, 2)
			new("UITextSizeConstraint", {MaxTextSize = 21}, sub)
			local ends = text({Position = UDim2.fromOffset(19, 112), Size = UDim2.fromOffset(190, 22), Font = C.BOLD, TextSize = 17, TextXAlignment = LEFT, Text = "", TextColor3 = GREY_TEXT, ZIndex = 3}, b, 1.5)
			RunService.Heartbeat:Connect(function()
				if screen.root.Visible then
					local now = workspace:GetServerTimeNow()
					local left = math.max(0, (Config.skinPeriod(now) + 1) * Config.SKIN_ROTATE - now)
					ends.Text = ("Ends in %d:%02d:%02d"):format(left // 3600, left % 3600 // 60, left % 60)
				end
			end)
			-- cinta roja de la rebaja en la esquina (como la "New" de la aspiradora)
			local ribbon = corner(new("Frame", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 14, 0, 18), Size = UDim2.fromOffset(98, 44), BackgroundColor3 = WHITE, Visible = false, ZIndex = 6}, b), 4)
			new("UIGradient", {Rotation = 90, Color = seq(Color3.fromRGB(255, 70, 80), Color3.fromRGB(200, 20, 40))}, ribbon)
			edge(ribbon, Color3.fromRGB(255, 190, 190), 2)
			local ribbonText = text({Size = UDim2.fromScale(1, 1), TextSize = 28, Text = "", ZIndex = 7}, ribbon, 2.5)
			local priceRow = new("Frame", {Position = UDim2.new(0, 16, 1, -60), Size = UDim2.fromOffset(0, 50), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 3}, b)
			new("UIListLayout", {FillDirection = HORIZONTAL, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, priceRow)
			UI.art("gem", {Size = UDim2.fromOffset(46, 46), LayoutOrder = 1, ZIndex = 3}, priceRow)
			local priceText = text({Size = UDim2.fromOffset(0, 50), AutomaticSize = Enum.AutomaticSize.X, TextSize = 40, Text = "", LayoutOrder = 2, ZIndex = 3}, priceRow, 3)
			local oldText = text({Size = UDim2.fromOffset(0, 50), AutomaticSize = Enum.AutomaticSize.X, TextSize = 24, RichText = true, Text = "", TextColor3 = Color3.fromRGB(255, 150, 150), LayoutOrder = 3, ZIndex = 3}, priceRow, 2)
			local shown, focus
			table.insert(refreshers, function()
				local c = counts()
				local offers = Config.skinOffers(Config.skinPeriod(workspace:GetServerTimeNow()), function(t)
					return skinUnlocked(t, c)
				end)
				local best
				for _, o in offers do
					if not best or o.off > best.off or (o.off == best.off and o.price > best.price) then
						best = o
					end
				end
				focus = best and best.skin or Config.SkinOrder[#Config.SkinOrder]
				sub.Text = best and Config.Scares[best.skin].name or "Get scares first!"
				ends.Visible = best ~= nil
				priceText.Text = UI.fmt(best and best.price or Config.Scares[focus].gems)
				local off = best and best.off or 0
				ribbon.Visible = off > 0
				ribbonText.Text = ("-%d%%"):format(off)
				oldText.Text = off > 0 and ("<s>%s</s>"):format(UI.fmt(Config.Scares[best.skin].gems)) or ""
				if shown ~= focus then
					shown = focus
					local col = skinColor(focus)
					rays.ImageColor3, glow.ImageColor3 = col:Lerp(WHITE, 0.4), col:Lerp(WHITE, 0.25)
					holder:ClearAllChildren()
					local vp = UI.viewport(focus, holder, {Size = UDim2.fromScale(1, 1), ZIndex = 2})
					if vp.CurrentCamera then
						vp.CurrentCamera.FieldOfView = 34
					end
				end
			end)
			b.Activated:Connect(function()
				scrollTo("daily")
			end)
			hoverTip(b, function()
				local def = Config.Scares[focus]
				return "Skins", "New looks for the scares you already own. Buy once, keep forever: every one you place wears it!", ("%s  ·  %s skin"):format(def.name, Config.Scares[def.base].name)
			end)
		end

		-- Sustos premium: con Robux, sin depender de la suerte (al pulsar la carta, su ficha en Scares)
		local premHead = header("Premium Scares", true)
		local premChip = corner(new("Frame", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(250, 40), BackgroundColor3 = Color3.fromRGB(12, 12, 16), BackgroundTransparency = 0.15}, premHead), 20)
		edge(premChip, Color3.fromRGB(150, 150, 160), 2)
		UI.icon("lightning", {Position = UDim2.fromOffset(10, 6), Size = UDim2.fromOffset(28, 28)}, premChip)
		text({Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -50, 1, 0), Font = C.BOLD, TextSize = 17, TextXAlignment = LEFT, Text = "Instant · no luck needed"}, premChip, 1.5)
		local premRow = row(nil, 5, Vector2.new(168, 236))
		local premCount = {}
		for k, t in Config.PremiumScares do
			local def = Config.Scares[t]
			local _, tier = Config.scareTier(t)
			if not (def and tier) then
				continue
			end
			local col = catColor(t)
			local b = card(premRow, Vector2.new(168, 236), k, col:Lerp(WHITE, 0.1), col:Lerp(BLACK, 0.62), col:Lerp(WHITE, 0.55))
			local rays = UI.piece("rays", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(84, 108), Size = UDim2.fromOffset(230, 230), ImageColor3 = col:Lerp(WHITE, 0.5), ImageTransparency = 0.8}, b)
			spinRays(rays, 9 + k)
			UI.piece("glow2", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(84, 108), Size = UDim2.fromOffset(170, 160), ImageColor3 = col:Lerp(WHITE, 0.4), ImageTransparency = 0.55}, b)
			local vp = UI.viewport(t, b, {Position = UDim2.fromOffset(4, 46), Size = UDim2.fromOffset(160, 128), ZIndex = 2}, true)
			if vp.CurrentCamera then
				vp.CurrentCamera.FieldOfView = 24
			end
			text({Position = UDim2.fromOffset(4, 5), Size = UDim2.new(1, -8, 0, 24), TextSize = 20, Text = def.name, TextScaled = true, ZIndex = 3}, b, 2)
			text({Position = UDim2.fromOffset(4, 28), Size = UDim2.new(1, -8, 0, 17), TextSize = 15, Text = def.mythic and "MYTHIC" or Config.Categories[def.cat].name, TextColor3 = def.mythic and Color3.fromRGB(255, 120, 230) or col:Lerp(WHITE, 0.55), ZIndex = 3}, b, 1.5)
			local own = text({AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 150), Size = UDim2.fromOffset(60, 20), TextSize = 16, TextXAlignment = RIGHT, Text = "", TextColor3 = Color3.fromRGB(150, 255, 150), ZIndex = 3}, b, 1.5)
			premCount[t] = own
			local btn = C.button(b, UI.fmt(tier.robux), "green", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -9), Size = UDim2.new(1, -18, 0, 46), TextSize = 22, ZIndex = 4}, "robux")
			btn.button.Activated:Connect(function()
				buyRobux("scare", t)
			end)
			b.Activated:Connect(function()
				UI.toggleScares(true, t)
			end)
			hoverTip(b, function()
				return def.name, def.desc, ("+%d per scare  ·  Fear %d  ·  <font color=\"#8CFF8C\">instant, no wheel luck needed!</font>"):format(def.pay, def.fear)
			end)
		end
		table.insert(refreshers, function()
			local c = counts()
			for t, l in premCount do
				l.Text = (c[t] or 0) > 0 and ("x%d"):format(c[t]) or ""
			end
		end)

		-- Ofertas del día
		local dailyHead = header("Daily Deals", true)
		anchors.daily = dailyHead
		local timer = corner(new("Frame", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(250, 40), BackgroundColor3 = Color3.fromRGB(12, 12, 16), BackgroundTransparency = 0.15}, dailyHead), 20)
		edge(timer, Color3.fromRGB(150, 150, 160), 2)
		UI.icon("clock", {Position = UDim2.fromOffset(10, 6), Size = UDim2.fromOffset(28, 28)}, timer)
		local timerText = text({Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -50, 1, 0), Font = C.BOLD, TextSize = 17, TextXAlignment = LEFT, Text = ""}, timer, 1.5)
		local dailyRow = row(nil, 5, Vector2.new(168, 172))
		local dailyCards = {}
		local shownDay
		local function buildDaily()
			local day = Config.dailyDay(workspace:GetServerTimeNow())
			if day == shownDay then
				return
			end
			shownDay = day
			for _, c in dailyRow:GetChildren() do
				if c:IsA("GuiObject") then
					c:Destroy()
				end
			end
			table.clear(dailyCards)
			for k, deal in Config.dailyDeals(day) do
				local def = Config.Scares[deal.scare]
				local col = catColor(deal.scare)
				local b = card(dailyRow, Vector2.new(168, 172), k, col:Lerp(WHITE, 0.08), col:Lerp(BLACK, 0.55), col:Lerp(WHITE, 0.55))
				UI.piece("glow2", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(84, 92), Size = UDim2.fromOffset(166, 150), ImageColor3 = col:Lerp(WHITE, 0.4), ImageTransparency = 0.6}, b)
				local vp = UI.viewport(deal.scare, b, {Position = UDim2.fromOffset(4, 38), Size = UDim2.fromOffset(160, 116), ZIndex = 2}, true)
				if vp.CurrentCamera then
					vp.CurrentCamera.FieldOfView = 22
				end
				text({Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 24), TextSize = 20, Text = def.name, TextScaled = true, ZIndex = 3}, b, 2)
				text({Position = UDim2.fromOffset(4, 26), Size = UDim2.new(1, -8, 0, 17), TextSize = 15, Text = Config.Categories[def.cat].name, TextColor3 = col:Lerp(WHITE, 0.55), ZIndex = 3}, b, 1.5)
				local pr = new("Frame", {Position = UDim2.new(0, 10, 1, -40), Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 3}, b)
				new("UIListLayout", {FillDirection = HORIZONTAL, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, pr)
				UI.art("coin", {Size = UDim2.fromOffset(32, 32), LayoutOrder = 1, ZIndex = 3}, pr)
				local pt = text({Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, TextSize = 26, Text = UI.fmt(deal.price), LayoutOrder = 2, ZIndex = 3}, pr, 2.5)
				-- vendida hoy
				local sold = corner(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0.38, Visible = false, ZIndex = 8}, b), 8)
				text({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(160, 40), TextSize = 32, Text = "SOLD", Rotation = -12, TextColor3 = Color3.fromRGB(150, 255, 150), ZIndex = 9}, sold, 3)
				dailyCards[k] = {sold = sold, price = pt, deal = deal}
				b.Activated:Connect(function()
					if sold.Visible then
						return UI.toast("You already got this deal today", UI.ORANGE, "clock")
					end
					if UI.money < deal.price then
						return UI.toast(("You need %s more coins"):format(UI.fmt(deal.price - UI.money)), UI.RED)
					end
					Remote:FireServer("DailyBuy", k)
				end)
				hoverTip(b, function()
					return def.name, def.desc, ("+%d per scare  ·  Fear %d  ·  <font color=\"#FF9AE0\">normally not sold for coins!</font>"):format(def.pay, def.fear)
				end)
			end
		end
		buildDaily()
		table.insert(refreshers, function()
			buildDaily()
			local day, list2 = string.match(player:GetAttribute("DailyBought") or "", "^(%d+):(.*)$")
			local bought = {}
			if tonumber(day) == shownDay then
				for _, n in string.split(list2, ",") do
					bought[tonumber(n) or 0] = true
				end
			end
			for k, c in dailyCards do
				c.sold.Visible = bought[k] == true
				c.price.TextColor3 = UI.money >= c.deal.price and WHITE or Color3.fromRGB(255, 150, 150)
			end
		end)
		RunService.Heartbeat:Connect(function()
			if screen.root.Visible then
				local left = 86400 - workspace:GetServerTimeNow() % 86400
				timerText.Text = ("Refreshes in %d:%02d:%02d"):format(left // 3600, left % 3600 // 60, left % 60)
				if left < 1 then
					refreshAll()
				end
			end
		end)
		-- Daily Deals de skins (con gemas): Config.skinOffers del día, solo de los sustos que tienes; algunas rebajadas
		local skinRow = row(nil, 5, Vector2.new(168, 172))
		local skinDeals, skinKey = {}, nil
		local function skinDeal(k, o)
			local t = o.skin
			local def = Config.Scares[t]
			local r = skinRarity(t)
			local col = r.color
			local b = card(skinRow, Vector2.new(168, 172), k, col:Lerp(WHITE, 0.05), col:Lerp(BLACK, 0.6), col:Lerp(WHITE, 0.55))
			stripes(b)
			UI.piece("glow2", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(84, 92), Size = UDim2.fromOffset(166, 150), ImageColor3 = col:Lerp(WHITE, 0.4), ImageTransparency = 0.6}, b)
			local vp = UI.viewport(t, b, {Position = UDim2.fromOffset(4, 38), Size = UDim2.fromOffset(160, 116), ZIndex = 2}, true)
			if vp.CurrentCamera then
				vp.CurrentCamera.FieldOfView = 22
			end
			text({Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 24), TextSize = 20, Text = def.name, TextScaled = true, ZIndex = 3}, b, 2)
			text({Position = UDim2.fromOffset(4, 26), Size = UDim2.new(1, -8, 0, 17), TextSize = 15, Text = r.name .. " Skin", TextColor3 = col:Lerp(WHITE, 0.45), ZIndex = 3}, b, 1.5)
			if o.off > 0 then
				local rib = corner(new("Frame", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 6, 0, 46), Size = UDim2.fromOffset(62, 28), Rotation = 8, BackgroundColor3 = WHITE, ZIndex = 6}, b), 4)
				new("UIGradient", {Rotation = 90, Color = seq(Color3.fromRGB(255, 84, 84), Color3.fromRGB(204, 18, 38))}, rib)
				edge(rib, Color3.fromRGB(255, 200, 200), 2)
				text({Size = UDim2.fromScale(1, 1), TextSize = 19, Text = ("-%d%%"):format(o.off), ZIndex = 7}, rib, 2)
			end
			local pr = new("Frame", {Position = UDim2.new(0, 10, 1, -40), Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 3}, b)
			new("UIListLayout", {FillDirection = HORIZONTAL, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, pr)
			UI.art("gem", {Size = UDim2.fromOffset(32, 32), LayoutOrder = 1, ZIndex = 3}, pr)
			local pt = text({Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, TextSize = 26, Text = UI.fmt(o.price), LayoutOrder = 2, ZIndex = 3}, pr, 2.5)
			if o.off > 0 then
				text({Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, TextSize = 17, RichText = true, Text = ("<s>%s</s>"):format(UI.fmt(def.gems)), TextColor3 = Color3.fromRGB(255, 170, 170), LayoutOrder = 3, ZIndex = 3}, pr, 1.5)
			end
			local own = text({AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 1, -10), Size = UDim2.fromOffset(40, 20), TextSize = 16, TextXAlignment = RIGHT, Text = "", TextColor3 = Color3.fromRGB(150, 255, 150), ZIndex = 3}, b, 1.5)
			b.Activated:Connect(function()
				if gems() < o.price then
					UI.toast(("You need %s more gems"):format(UI.fmt(o.price - gems())), Color3.fromRGB(190, 140, 255), "gem")
					return scrollTo("gems")
				end
				Remote:FireServer("BuySkin", t)
			end)
			hoverTip(b, function()
				local base = Config.Scares[def.base]
				return def.name, def.desc, ("New look for your %s (same stats)  ·  <font color=\"#C8A0FF\">skin, today only!</font>"):format(base.name)
			end)
			skinDeals[t] = {price = pt, own = own, offer = o}
		end
		table.insert(refreshers, function()
			local c = counts()
			local offers = Config.skinOffers(Config.skinPeriod(workspace:GetServerTimeNow()), function(t)
				return skinUnlocked(t, c)
			end)
			local key = {}
			for _, o in offers do
				table.insert(key, o.skin .. o.price)
			end
			key = table.concat(key, ",")
			if key ~= skinKey then
				skinKey = key
				for _, ch in skinRow:GetChildren() do
					if ch:IsA("GuiObject") then
						ch:Destroy()
					end
				end
				table.clear(skinDeals)
				for k, o in offers do
					skinDeal(k, o)
				end
			end
			skinRow.Visible = #offers > 0
			for t, sd in skinDeals do
				sd.own.Text = ""
				sd.price.TextColor3 = gems() >= sd.offer.price and WHITE or Color3.fromRGB(255, 150, 150)
			end
		end)
		task.wait()

		---------- Passes ----------
		anchors.passes = header("Passes")
		local passRow = row(nil, 1, Vector2.new(LIST_W, 232))
		do
			local b = card(passRow, Vector2.new(LIST_W, 232), 1, Color3.fromRGB(44, 44, 50), Color3.fromRGB(20, 20, 24), Color3.fromRGB(120, 120, 130))
			b.AutoButtonColor = false
			local art = corner(new("Frame", {Size = UDim2.new(0, 260, 1, 0), BackgroundColor3 = WHITE, ZIndex = 2}, b), 8)
			new("UIGradient", {Rotation = 90, Color = seq(Color3.fromRGB(255, 176, 40), Color3.fromRGB(220, 84, 20))}, art)
			UI.piece("glow2", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(130, 140), Size = UDim2.fromOffset(250, 220), ImageColor3 = Color3.fromRGB(255, 240, 160), ImageTransparency = 0.45, ZIndex = 2}, art)
			if vacModel then
				modelView(vacModel, art, {Position = UDim2.fromOffset(10, 40), Size = UDim2.fromOffset(240, 190), ZIndex = 3}, Vector3.new(0.6, 0.3, -1))
			end
			text({Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 34), TextSize = 30, Text = "Soul Vacuum", ZIndex = 4}, art, 2.5)
			text({Position = UDim2.fromOffset(284, 14), Size = UDim2.fromOffset(400, 36), TextSize = 32, TextXAlignment = LEFT, Text = "Unlocks...", ZIndex = 3}, b, 2.5)
			local desc = new("ScrollingFrame", {
				Position = UDim2.fromOffset(280, 56), Size = UDim2.new(1, -300, 0, 104), BackgroundColor3 = Color3.fromRGB(14, 14, 18), BackgroundTransparency = 0.3, BorderSizePixel = 0,
				ScrollBarThickness = 5, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 3,
			}, b)
			corner(desc, 6)
			new("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 8)}, desc)
			new("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, desc)
			for i, r in VAC_ROWS do
				text({Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = C.BOLD, TextSize = 17, TextWrapped = true, TextXAlignment = LEFT, Text = "• " .. r, LayoutOrder = i, ZIndex = 4}, desc, 1.2)
			end
			local robuxBtn = C.button(b, "", "green", {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -14), Size = UDim2.fromOffset(190, 54), TextSize = 26, ZIndex = 4}, "robux")
			robuxBtn.button.Activated:Connect(function()
				buyRobux("pass", VAC.id)
			end)
			table.insert(refreshers, function()
				if ownsPass(VAC) then
					robuxBtn.set("OWNED", "grey", "check")
				else
					robuxBtn.set(UI.fmt(VAC.robux), "green", "robux")
				end
			end)
		end
		-- los demás pases, en cartas: la ilustración con rayos, el nombre, qué hace y su botón
		local pgrid = row(nil, 3, Vector2.new(293, 332))
		for i, p in Config.Passes do
			if p.id == VAC.id then
				continue
			end
			local b = card(pgrid, Vector2.new(293, 332), i, p.color:Lerp(BLACK, 0.35), p.color:Lerp(BLACK, 0.84), p.color:Lerp(WHITE, 0.45))
			stripes(b)
			local rays = UI.piece("rays", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 106), Size = UDim2.fromOffset(320, 320), ImageColor3 = p.color, ImageTransparency = 0.74}, b)
			spinRays(rays, 8 + i * 2)
			UI.piece("glow2", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 106), Size = UDim2.fromOffset(240, 220), ImageColor3 = p.color:Lerp(WHITE, 0.35), ImageTransparency = 0.5}, b)
			local art = UI.art(p.art, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 106), Size = UDim2.fromOffset(180, 180), ZIndex = 3}, b)
			bob(art, 5, i)
			local tag = corner(new("Frame", {Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = WHITE, ZIndex = 4}, b), 6)
			new("UIGradient", {Rotation = 90, Color = seq(Color3.fromRGB(255, 110, 210), Color3.fromRGB(196, 40, 160))}, tag)
			edge(tag, Color3.fromRGB(255, 200, 240), 1.5)
			new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, tag)
			text({Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, TextSize = 14, Text = "GAMEPASS", ZIndex = 5}, tag, 1.5)
			text({Position = UDim2.fromOffset(10, 198), Size = UDim2.new(1, -20, 0, 32), TextSize = 29, Text = p.name, ZIndex = 4}, b, 2.5)
			text({Position = UDim2.fromOffset(16, 230), Size = UDim2.new(1, -32, 0, 40), Font = C.BOLD, TextSize = 15, TextWrapped = true, TextColor3 = GREY_TEXT, Text = p.desc, ZIndex = 4}, b, 1.2)
			local btn = C.button(b, "", "green", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -28, 0, 50), TextSize = 25, ZIndex = 4}, "robux")
			local function act()
				if ownsPass(p) then
					return UI.toast(("%s is already yours!"):format(p.name), UI.GREEN, "check")
				end
				buyRobux("pass", p.id)
			end
			b.Activated:Connect(act)
			btn.button.Activated:Connect(act)
			hoverTip(b, function()
				return p.name, p.desc, "Gamepass: yours forever, in every server"
			end)
			table.insert(refreshers, function()
				if ownsPass(p) then
					btn.set("OWNED", "grey", "check")
				else
					btn.set(UI.fmt(p.robux), "green", "robux")
				end
			end)
		end
		task.wait()

		-- (los sustos no se venden aquí: su pantalla de colección, ScareStoreUI; el botón Scares de la barra la abre)

		---------- Houses ----------
		anchors.houses = header("Houses")
		local hgrid = row(nil, 3, Vector2.new(296, 190))
		local houseCards = {}
		for i, def in Config.Houses do
			local col = Color3.fromRGB(255, 150, 60):Lerp(UI.PURPLE, (i - 1) / math.max(1, #Config.Houses - 1))
			local b = card(hgrid, Vector2.new(296, 190), i, Color3.fromRGB(64, 64, 72), Color3.fromRGB(28, 28, 32))
			stripes(b)
			UI.piece("glow2", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(210, 104), Size = UDim2.fromOffset(200, 170), ImageColor3 = col, ImageTransparency = 0.62}, b)
			UI.art("house", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(212, 108), Size = UDim2.fromOffset(120 + i * 12, 120 + i * 12), ZIndex = 2, ImageColor3 = col:Lerp(WHITE, 0.45)}, b)
			text({Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(270, 28), TextSize = 22, TextXAlignment = LEFT, Text = def.name, TextScaled = true, ZIndex = 3}, b, 2.2)
			local spaces = select(3, Config.houseDims(def.template, def.rooms))
			text({Position = UDim2.fromOffset(15, 38), Size = UDim2.fromOffset(200, 20), Font = C.BOLD, TextSize = 17, TextXAlignment = LEFT, Text = ("%d %s · %d spaces"):format(def.rooms, def.rooms == 1 and "room" or "rooms", spaces), TextColor3 = GREY_TEXT, ZIndex = 3}, b, 1.5)
			if (def.fear or 1) < 1 then
				text({Position = UDim2.fromOffset(15, 60), Size = UDim2.fromOffset(200, 20), Font = C.BOLD, TextSize = 16, TextXAlignment = LEFT, Text = ("Braver visitors · x%s coins"):format(def.coins or 1), TextColor3 = Color3.fromRGB(255, 120, 110), ZIndex = 3}, b, 1.5)
			end
			local btn = C.button(b, "", "green", {Position = UDim2.new(0, 12, 1, -56), Size = UDim2.fromOffset(170, 44), TextSize = 21, ZIndex = 4}, "coin")
			local function act()
				local home = player:GetAttribute("Home") or Config.Houses[1].id
				if home == def.id then
					return UI.toast("You already live here", UI.ORANGE, "house")
				end
				local own = i == 1 or table.find(list("Houses"), def.id) ~= nil
				if not own and UI.money < def.price then
					return UI.toast(("You need %s more coins"):format(UI.fmt(def.price - UI.money)), UI.RED)
				end
				Remote:FireServer("Buy", "House", def.id)
			end
			b.Activated:Connect(act)
			btn.button.Activated:Connect(act)
			hoverTip(b, function()
				return def.name, def.desc, nil
			end)
			houseCards[i] = btn
		end
		table.insert(refreshers, function()
			local owned = list("Houses")
			local home = player:GetAttribute("Home") or Config.Houses[1].id
			for i, def in Config.Houses do
				local btn = houseCards[i]
				if def.id == home then
					btn.set("LIVING HERE", "grey", "check")
				elseif i == 1 or table.find(owned, def.id) then
					btn.set("MOVE IN", "green", "house")
				else
					setPrice(btn, def.price, UI.money, "coin")
				end
			end
		end)

		---------- Wheels ----------
		anchors.wheels = header("Wheels")
		local wgrid = row(nil, 3, Vector2.new(296, 190))
		local wheelBtns = {}
		for i, w in Config.Wheels do
			local b = card(wgrid, Vector2.new(296, 190), i, w.color:Lerp(BLACK, 0.25), w.color:Lerp(BLACK, 0.75), w.color:Lerp(WHITE, 0.5))
			stripes(b)
			local ic = UI.art("wheelart", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(214, 102), Size = UDim2.fromOffset(150, 150), ZIndex = 2}, b)
			RunService.RenderStepped:Connect(function()
				if screen.root.Visible then
					ic.Rotation = math.sin(os.clock() * 1.2 + i) * 8
				end
			end)
			text({Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(270, 28), TextSize = 23, TextXAlignment = LEFT, Text = w.name, ZIndex = 3}, b, 2.2)
			text({Position = UDim2.fromOffset(15, 38), Size = UDim2.fromOffset(200, 20), Font = C.BOLD, TextSize = 16, TextXAlignment = LEFT, Text = ("Jackpot guaranteed in %d"):format(w.pity), TextColor3 = GREY_TEXT, ZIndex = 3}, b, 1.5)
			local btn = C.button(b, "", "green", {Position = UDim2.new(0, 12, 1, -56), Size = UDim2.fromOffset(150, 44), TextSize = 21, ZIndex = 4}, "coin")
			local free = UI.chip("FREE", UI.RED, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Rotation = 10, Visible = false, ZIndex = 5}, b)
			local function act()
				goStall("wheel", w.name)
			end
			b.Activated:Connect(act)
			btn.button.Activated:Connect(act)
			hoverTip(b, function()
				return w.name, "Spin it at the Wheel of Fright, at the start of the street. Its prizes change every 6 hours!", ("Spin: %s coins  ·  a Legendary at most every %d spins"):format(UI.fmt(w.price), w.pity)
			end)
			wheelBtns[i] = {btn = btn, free = free, price = w.price}
		end
		table.insert(refreshers, function()
			for i, wb in wheelBtns do
				local ready = i == Config.FREE_SPIN_WHEEL and workspace:GetServerTimeNow() >= (player:GetAttribute("FreeSpinAt") or math.huge)
				wb.free.Visible = ready
				if ready then
					wb.btn.set("FREE", "orange", "wheel")
				else
					setPrice(wb.btn, wb.price, UI.money, "coin")
				end
			end
		end)
		task.wait()

		---------- Tags ----------
		anchors.tags = header("Tags")
		local tgrid = row(nil, 5, Vector2.new(172, 172))
		local tagCards, tagList = {}, {}
		for i, tag in Config.Tags do
			local r = Config.tagRarity(tag)
			local b = card(tgrid, Vector2.new(172, 172), i, r.top, r.bottom, r.color:Lerp(WHITE, 0.45))
			corner(new("ImageLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = UI.PATTERN, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(120, 120), ImageTransparency = 0.9}, b), 8)
			text({Position = UDim2.fromOffset(6, 8), Size = UDim2.new(1, -12, 0, 24), TextSize = 21, Text = tag.name, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2}, b, 2)
			text({Position = UDim2.fromOffset(6, 31), Size = UDim2.new(1, -12, 0, 17), TextSize = 15, Text = tag.rarity, TextColor3 = r.color:Lerp(WHITE, 0.4), ZIndex = 2}, b, 1.5)
			local prev = text({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.new(1, -14, 0, 40), TextScaled = true, Text = tag.name, ZIndex = 2}, b, 2.5)
			new("UITextSizeConstraint", {MaxTextSize = 30}, prev)
			local g = new("UIGradient", {Color = Config.tagGradient(tag)}, prev)
			g:SetAttribute("Rarity", tag.rarity)
			CollectionService:AddTag(g, "TagGradient") -- (TagFX: los míticos se mueven y los legendarios brillan)
			local pr = new("Frame", {Position = UDim2.new(0, 10, 1, -40), Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 2}, b)
			new("UIListLayout", {FillDirection = HORIZONTAL, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, pr)
			local coin = UI.art("coin", {Size = UDim2.fromOffset(32, 32), LayoutOrder = 1, ZIndex = 2}, pr)
			local pt = text({Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, TextSize = 25, Text = UI.fmt(tag.price), LayoutOrder = 2, ZIndex = 2}, pr, 2.5)
			b.Activated:Connect(function()
				local owned = table.find(list("Tags"), tag.id) ~= nil
				if player:GetAttribute("Tag") == tag.id then
					Remote:FireServer("EquipTag", nil)
					UI.sound("Close")
				elseif owned then
					Remote:FireServer("EquipTag", tag.id)
					UI.sound("Success")
				elseif UI.money < tag.price then
					UI.toast(("You need %s more coins"):format(UI.fmt(tag.price - UI.money)), UI.RED)
				else
					Remote:FireServer("BuyTag", tag.id)
				end
			end)
			hoverTip(b, function()
				local owned = table.find(list("Tags"), tag.id) ~= nil
				return ("[ %s ]"):format(tag.name), ("A %s title above your name, with your name in its colors."):format(tag.rarity:lower()),
					owned and "Click to equip or unequip" or "Click to buy (equips it)"
			end)
			tagCards[tag.id] = {coin = coin, price = pt, tag = tag}
			tagList[i] = b
		end
		local moreTags = showMore(tagList, 10)
		table.insert(refreshers, function()
			local owned = list("Tags")
			local eq = player:GetAttribute("Tag")
			for id, tc in tagCards do
				local own = table.find(owned, id) ~= nil
				tc.coin.Visible = not own
				tc.price.Text = eq == id and "EQUIPPED" or own and "OWNED" or UI.fmt(tc.tag.price)
				tc.price.TextColor3 = eq == id and Color3.fromRGB(150, 255, 150) or (own or UI.money >= tc.tag.price) and WHITE or Color3.fromRGB(255, 160, 160)
			end
			moreTags()
		end)
		task.wait()

		---------- Currency: packs de monedas y gemas ----------
		-- Tres columnas: cuatro cartas pequeñas (2×2) y la alta, a la derecha en las monedas y a la izquierda en las gemas
		anchors.currency = header("Currency")
		local SMALL_H, PAD = 236, 16
		local function block(id, title, packs)
			anchors[id] = header(title, true)
			local f = new("Frame", {Size = UDim2.new(1, 0, 0, SMALL_H * 2 + PAD), BackgroundTransparency = 1, LayoutOrder = nextOrder()}, scroll)
			local function col(c)
				return UDim2.new(c / 3, c * PAD / 3, 0, 0)
			end
			local colW = UDim2.new(1 / 3, -PAD * 2 / 3, 0, 0)
			local small = {}
			local bigCol
			for i, p in packs do
				if p.big then
					bigCol = i == 1 and 0 or 2
					packCard(f, p, col(bigCol), colW + UDim2.fromOffset(0, SMALL_H * 2 + PAD))
				else
					table.insert(small, p)
				end
			end
			local first = bigCol == 0 and 1 or 0
			for k, p in small do
				local c, r = first + (k - 1) % 2, (k - 1) // 2
				packCard(f, p, col(c) + UDim2.fromOffset(0, r * (SMALL_H + PAD)), colW + UDim2.fromOffset(0, SMALL_H))
			end
		end
		block("coins", "Coins", Config.CoinPacks)
		block("gems", "Gems", Config.GemPacks)
		task.wait()

		refreshAll()
	end

	---------- Divisas ----------
	local function syncMoney()
		coinAmt.Text = UI.fmt(UI.money)
		gemAmt.Text = UI.fmt(gems())
	end
	coinPlus.Activated:Connect(function()
		UI.sound("Tab")
		scrollTo("coins")
	end)
	gemPlus.Activated:Connect(function()
		UI.sound("Tab")
		scrollTo("gems")
	end)
	player:GetAttributeChangedSignal("Gems"):Connect(syncMoney)

	---------- Avisos: puedes permitirte algo nuevo (insignia en los botones de la tienda) ----------
	UI.shopBadges = {UI.addBadge(UI.shopButton)}
	local newCount = 0
	RunService.RenderStepped:Connect(function()
		if newCount > 0 then
			local s = 1 + 0.15 * math.abs(math.sin(os.clock() * 4))
			for _, bd in UI.shopBadges do
				bd.UIScale.Scale = s
			end
		end
	end)
	function UI.newlyAffordable(old, now)
		if screen.root.Visible then
			return
		end
		local c = counts()
		local names = {}
		for _, t in Config.ScareOrder do
			local def = Config.Scares[t]
			if Config.inShop(t) and (c[t] or 0) <= 0 and def.price > old and def.price <= now then
				table.insert(names, def.name)
			end
		end
		local ownedHouses = list("Houses")
		for _, def in Config.Houses do
			if def.price > old and def.price <= now and not table.find(ownedHouses, def.id) then
				table.insert(names, def.name)
			end
		end
		local ownedTags = list("Tags")
		for _, tag in Config.Tags do
			if tag.price > old and tag.price <= now and not table.find(ownedTags, tag.id) then
				table.insert(names, tag.name .. " tag")
			end
		end
		if #names == 0 then
			return
		end
		newCount += #names
		for _, bd in UI.shopBadges do
			bd.Count.Text, bd.Visible = tostring(math.min(newCount, 99)), true
		end
		UI.toast(("You can afford: %s! Open the Shop or Scares"):format(names[#names]), UI.GREEN, "cart")
		UI.sound("Sparkle")
	end

	---------- Abrir y refrescar ----------
	-- focus: un susto que enseñar (p. ej. el que se te ha acabado al construir): salta a los sustos
	local goTo -- sección a la que saltar al abrir (UI.openCurrency)
	function UI.toggleShop(open, focus)
		-- (un susto concreto: a su pantalla)
		if open and focus and Config.Scares[focus] and UI.toggleScares then
			return UI.toggleScares(true, focus)
		end
		if open == nil then
			open = not screen.root.Visible
		end
		if open then
			newCount = 0
			for _, bd in UI.shopBadges do
				bd.Visible = false
			end
		end
		screen.open(open)
		if open then
			syncMoney()
			task.spawn(function()
				if not built then
					build()
				end
				refreshAll()
				if goTo then
					task.wait() -- (que se coloque la lista antes de saltar)
					scrollTo(goTo)
					goTo = nil
				end
			end)
		end
	end

	-- la Shop en sus skins (desde la pantalla Scares: "cómo consigo esta skin")
	function UI.openSkins()
		if screen.root.Visible and built then
			return scrollTo("daily")
		end
		goTo = "daily"
		UI.toggleShop(true)
	end

	-- el "+" de las monedas o gemas (HUD y pantallas): la Shop en sus packs
	function UI.openCurrency(kind)
		UI.sound("Tab")
		if screen.root.Visible and built then
			return scrollTo(kind)
		end
		goTo = kind
		UI.toggleShop(true)
	end

	-- (pruebas: ShopDebug:Fire("open") / ("close") / ("scroll", sección) desde la barra de comandos)
	local dbg = new("BindableEvent", {Name = "ShopDebug"}, screen.gui)
	dbg.Event:Connect(function(cmd, a)
		if cmd == "open" then
			UI.toggleShop(true)
		elseif cmd == "close" then
			UI.toggleShop(false)
		elseif cmd == "scroll" then
			scrollTo(a)
		end
	end)

	function UI.refreshShop()
		if screen.root.Visible then
			syncMoney()
			if built then
				refreshAll()
			end
		end
	end
	UI.refreshHouses = UI.refreshShop

	local WATCH = {Inv_ = true, Star_ = true, Pass_ = true}
	player.AttributeChanged:Connect(function(name)
		if screen.root.Visible and (WATCH[name:match("^%a+_") or ""] or name == "Tags" or name == "Tag" or name == "Houses" or name == "Home" or name == "Gems"
			or name == "Vacuum" or name == "DailyBought" or name == "FreeSpinAt") then
			UI.refreshShop()
		end
	end)

	Remote.OnClientEvent:Connect(function(kind, a, b)
		if kind == "Bought" then
			UI.sound("Success")
			UI.refreshShop()
		elseif kind == "TagBought" then
			local tag = Config.TagById[a]
			if tag then
				local r = Config.tagRarity(tag)
				UI.notice("NEW TAG", ("[ %s ]  is now above your name"):format(tag.name), r.color, "star", 4)
				UI.sound("Success")
				UI.confetti(40)
			end
			UI.refreshShop()
		elseif kind == "VacuumGot" or kind == "GotScare" or kind == "GotSkin" then
			UI.refreshShop()
		elseif kind == "PackGot" then
			-- monedas o gemas compradas (o regaladas: b = quien te las manda)
			local p = Config.PackById[a]
			if p then
				local col = p.gems and Color3.fromRGB(120, 230, 255) or UI.GOLD
				UI.big(("+%s %s!"):format(UI.fmt(p.amount), p.gems and "GEMS" or "COINS"), b and ("A gift from %s! 🎁"):format(b) or p.name, col, 3.5)
				UI.sound("Win")
				UI.sound("Sparkle")
				UI.flash(col, 0.4, 0.8)
				UI.confetti(p.big and 120 or 70)
			end
		elseif kind == "GiftSent" then
			local p = Config.PackById[a]
			UI.toast(("You gifted %s to %s! 🎁"):format(p and p.name or "a pack", b), UI.GREEN, "gift")
			UI.sound("Success")
			UI.confetti(40)
		elseif kind == "PassGot" then
			local p = Config.PassById[a]
			if p then
				UI.notice(p.name:upper(), p.desc, p.color, "star", 4.5)
				UI.sound("Success")
				UI.sound("Sparkle")
				UI.confetti(50)
			end
			UI.refreshShop()
		end
	end)
end
