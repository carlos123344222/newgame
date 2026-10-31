-- Fusión: la ventana del Caldero de Hexa (cementerio; lo construye ServerStorage.FusionBuilder) y la pantalla de
-- resultado. Diseño: lienzo "Fusion System – Haunted House" (https://claude.ai/artifact/7kgCxrDRUky2kiuwWppMX5).
-- Izquierda: tus sustos con copias en la mochila (READY! si llegan para la siguiente estrella). Derecha: el elegido
-- grande sobre la boca del caldero, sus estrellas ahora -> después, las copias que se funden, monedas y miedo antes ->
-- después y el botón FUSE! (acción Fuse; el servidor exige estar junto al caldero). Al fusionar: rayos, confeti y la
-- estrella nueva. Avisa con un toast cuando un susto ya se puede fusionar.
-- Uso: require(FusionUI)(UI) desde UI. Pone UI.toggleFusion(open, susto).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(RS:WaitForChild("Config"))
local Remote = RS:WaitForChild("Remote")
local player = Players.LocalPlayer

local REACH = 26 -- se cierra si te alejas del caldero

return function(UI)
	local new, round = UI.new, UI.round
	local INK, WHITE, MUTED = UI.INK, UI.WHITE, UI.MUTED
	local GREEN = Color3.fromRGB(118, 214, 84)
	local LIME = Color3.fromRGB(140, 255, 110)
	local EMPTY = Color3.fromRGB(60, 44, 84)
	local STARS = Config.STAR_COLORS
	local TIER = {"GOLD", "DIAMOND", "MYTHIC"}
	local SEQ_GREEN = ColorSequence.new(Color3.fromRGB(150, 232, 110), Color3.fromRGB(56, 168, 60))

	local function outline(o, thickness)
		new("UIStroke", {Name = "TextOutline", Color = INK, Thickness = thickness or 3, LineJoinMode = Enum.LineJoinMode.Round, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual}, o)
		return o
	end
	local function text(props, parent, thickness)
		props.BackgroundTransparency = 1
		props.TextColor3 = props.TextColor3 or WHITE
		props.Font = props.Font or UI.FONT
		local l = new("TextLabel", props, parent)
		if thickness ~= 0 then
			outline(l, thickness)
		end
		return l
	end
	local function tween(o, t, goal, style, dir)
		local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
		tw:Play()
		return tw
	end
	-- fila de 3 estrellas (★) de un tamaño: devuelve la fila y sus etiquetas
	local function starRow(parent, size, props)
		local row = new("Frame", props, parent)
		row.BackgroundTransparency = 1
		new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder}, row)
		local list = {}
		for k = 1, 3 do
			list[k] = text({Size = UDim2.fromOffset(size, size), Text = "★", TextSize = size, LayoutOrder = k, TextColor3 = EMPTY}, row, math.max(2, size / 11))
			new("UIScale", {}, list[k])
		end
		return row, list
	end
	local function paintStars(list, n, extra)
		for k, l in list do
			l.TextColor3 = (k <= n or k == extra) and STARS[k] or EMPTY
		end
	end

	-- ¿Cuántas copias hay en la mochila, qué estrella tiene y cuántas pide la siguiente?
	local function info(t)
		local star = Config.starOf(player, t)
		local n = player:GetAttribute("Inv_" .. t) or 0
		local cost = star < Config.STAR_MAX and Config.STAR_COST[star + 1] or 0
		return n, star, cost, star < Config.STAR_MAX and n >= cost
	end
	local ALL = {}
	for _, list in {Config.ScareOrder, Config.SpecialOrder} do
		for _, t in list do
			if not Config.Scares[t].skin and not Config.Scares[t].base then
				table.insert(ALL, t)
			end
		end
	end
	local function catColor(t)
		return Config.Categories[Config.Scares[t].cat].color
	end

	---------- Ventana ----------
	-- en su propia capa, como Troops y Scares: por encima de la barra de tropas y del HUD, con el fondo oscurecido
	local layer = new("ScreenGui", {Name = "FusionGui", ResetOnSpawn = false, DisplayOrder = 6, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, player:WaitForChild("PlayerGui"))
	local layerScale = new("UIScale", {Scale = UI.uiScale.Scale}, layer)
	UI.uiScale:GetPropertyChangedSignal("Scale"):Connect(function()
		layerScale.Scale = UI.uiScale.Scale
	end)
	local shade = new("Frame", {Size = UDim2.new(1, 0, 1, 80), Position = UDim2.fromOffset(0, -60), BackgroundColor3 = Color3.fromRGB(8, 4, 16), BackgroundTransparency = 0.45, BorderSizePixel = 0, Visible = false, Active = true}, layer)
	local win, close = UI.window({Name = "Fusion", Size = UDim2.fromOffset(1080, 612), title = "FUSION CAULDRON", icon = "cauldron", accent = GREEN, Visible = false}, layer)
	win:GetPropertyChangedSignal("Visible"):Connect(function()
		shade.Visible = win.Visible
	end)

	-- izquierda: tus sustos
	local left = round(new("Frame", {Name = "Scares", Position = UDim2.fromOffset(26, 50), Size = UDim2.fromOffset(474, 534), BackgroundColor3 = Color3.fromRGB(18, 10, 32), BackgroundTransparency = 0.45, ClipsDescendants = true}, win), 18)
	new("UIStroke", {Color = Color3.fromRGB(130, 100, 190), Transparency = 0.6, Thickness = 2}, left)
	local function chip(label, x, w)
		local b = round(new("TextButton", {Position = UDim2.fromOffset(x, 14), Size = UDim2.fromOffset(w, 38), BackgroundColor3 = WHITE, Text = "", AutoButtonColor = false, ZIndex = 4}, left), 15)
		local g = new("UIGradient", {Rotation = 90}, b)
		new("UIStroke", {Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, b)
		local l = text({Size = UDim2.new(1, -10, 1, 0), Position = UDim2.fromOffset(10, 1), TextSize = 17, Text = label, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5}, b, 2.5)
		UI.press(b, 1.05)
		return {b = b, g = g, l = l}
	end
	local readyChip = chip("Ready to fuse", 16, 172)
	local allChip = chip("All scares", 196, 120)
	local readyBadge = round(new("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(26, 24), BackgroundColor3 = UI.RED, ZIndex = 6}, readyChip.b), 10)
	new("UIStroke", {Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, readyBadge)
	local readyCount = text({Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 2), Font = UI.TITLE, TextSize = 15, Text = "0", ZIndex = 7}, readyBadge, 2)

	local scroll = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, -4, 1, -62), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
		ScrollBarImageColor3 = Color3.fromRGB(200, 190, 230), AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y,
	}, left)
	new("UIPadding", {PaddingLeft = UDim.new(0, 22), PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 18)}, scroll)
	new("UIGridLayout", {CellSize = UDim2.fromOffset(132, 168), CellPadding = UDim2.fromOffset(14, 18), SortOrder = Enum.SortOrder.LayoutOrder}, scroll)
	local emptyText = text({Position = UDim2.fromOffset(30, 220), Size = UDim2.fromOffset(414, 80), TextSize = 19, TextWrapped = true, TextColor3 = MUTED, Visible = false, ZIndex = 5,
		Text = "No copies to fuse yet! Spin the Wheel of Fright: every duplicate you get can be fused here."}, left, 2.5)

	-- la casilla que lleva a la ruleta (de ahí salen las copias)
	local more = round(new("TextButton", {Size = UDim2.fromOffset(132, 168), BackgroundColor3 = Color3.fromRGB(30, 20, 50), BackgroundTransparency = 0.35, Text = "", AutoButtonColor = false, LayoutOrder = 9999, ZIndex = 3}, scroll), 18)
	new("UIStroke", {Color = Color3.fromRGB(255, 120, 200), Thickness = 3, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, more)
	UI.icon("wheel", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16), Size = UDim2.fromOffset(64, 64), ZIndex = 4}, more)
	text({Position = UDim2.fromOffset(8, 88), Size = UDim2.fromOffset(116, 64), TextSize = 15, TextWrapped = true, TextColor3 = Color3.fromRGB(255, 208, 238), Text = "More copies at the Wheel of Fright!", ZIndex = 4}, more, 2.5)
	UI.press(more, 1.04)

	-- derecha: el susto elegido
	local D = round(new("Frame", {Name = "Fuse", Position = UDim2.fromOffset(514, 50), Size = UDim2.fromOffset(540, 534), BackgroundColor3 = WHITE, ClipsDescendants = true}, win), 18)
	new("UIGradient", {Rotation = 90, Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(36, 52, 44)), ColorSequenceKeypoint.new(0.55, Color3.fromRGB(30, 22, 52)), ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 14, 38))})}, D)
	new("UIStroke", {Color = Color3.fromRGB(140, 230, 110), Transparency = 0.6, Thickness = 2}, D)
	local rays = UI.piece("rays", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 130), Size = UDim2.fromOffset(470, 470), ImageColor3 = Color3.fromRGB(200, 255, 176), ImageTransparency = 0.8}, D)
	UI.piece("glow2", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 140), Size = UDim2.fromOffset(440, 360), ImageColor3 = GREEN, ImageTransparency = 0.4}, D)
	-- la boca del caldero: aro de hierro, la poción verde dentro y unas burbujas (el susto sale de ahí)
	local ped = new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 228), Size = UDim2.fromOffset(250, 46), BackgroundColor3 = WHITE}, D)
	round(ped, UDim.new(0.5, 0))
	new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(96, 86, 112), Color3.fromRGB(38, 32, 48))}, ped)
	new("UIStroke", {Color = INK, Thickness = 4}, ped)
	local brew = round(new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(212, 28), BackgroundColor3 = WHITE}, ped), UDim.new(0.5, 0))
	new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(170, 255, 140), Color3.fromRGB(60, 200, 70))}, brew)
	new("UIStroke", {Color = Color3.fromRGB(30, 70, 30), Thickness = 2}, brew)
	for _, b in {{-62, -6, 16}, {-20, -10, 22}, {34, -5, 14}, {70, -9, 18}} do
		local bub = round(new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, b[1], 0.5, b[2]), Size = UDim2.fromOffset(b[3], b[3]), BackgroundColor3 = Color3.fromRGB(200, 255, 180), ZIndex = 2}, brew), UDim.new(0.5, 0))
		new("UIStroke", {Color = Color3.fromRGB(30, 70, 30), Thickness = 2}, bub)
	end
	UI.piece("glow2", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 240), Size = UDim2.fromOffset(330, 110), ImageColor3 = Color3.fromRGB(130, 255, 100), ImageTransparency = 0.35}, D)
	local bigVp -- (el modelo grande: se rehace al elegir)
	local nameRow = new("Frame", {Position = UDim2.fromOffset(0, 270), Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1}, D)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, nameRow)
	local bigName = text({Size = UDim2.fromOffset(0, 46), AutomaticSize = Enum.AutomaticSize.X, Font = UI.TITLE, TextSize = 38, Text = "", LayoutOrder = 1}, nameRow, 4)
	new("UIPadding", {PaddingTop = UDim.new(0, 6)}, bigName)
	local rarity = UI.chip("", GREEN, {LayoutOrder = 2, TextSize = 15}, nameRow)

	local starsHolder = new("Frame", {Position = UDim2.fromOffset(0, 320), Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1}, D)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder}, starsHolder)
	local function starBox(order)
		local f = round(new("Frame", {Size = UDim2.fromOffset(112, 40), BackgroundColor3 = INK, BackgroundTransparency = 0.25, LayoutOrder = order}, starsHolder), 16)
		local st = new("UIStroke", {Color = Color3.fromRGB(190, 170, 240), Transparency = 0.55, Thickness = 1.5}, f)
		local _, list = starRow(f, 32, {Size = UDim2.fromScale(1, 1)})
		return f, list, st
	end
	local nowBox, nowStars = starBox(1)
	local arrow = UI.icon("arrowR", {Size = UDim2.fromOffset(38, 38), LayoutOrder = 2, ImageColor3 = LIME}, starsHolder)
	local nextBox, nextStars, nextStroke = starBox(3)
	local tierText = text({Position = UDim2.fromOffset(0, 362), Size = UDim2.new(1, 0, 0, 22), TextSize = 16, Text = ""}, D, 2.5)
	local maxText = text({Position = UDim2.fromOffset(0, 380), Size = UDim2.new(1, 0, 0, 60), Font = UI.TITLE, TextSize = 34, TextColor3 = Color3.fromRGB(255, 140, 230), Text = "MAX STARS!", Visible = false}, D, 4)

	local copies = new("Frame", {Position = UDim2.fromOffset(32, 394), Size = UDim2.fromOffset(470, 44), BackgroundTransparency = 1}, D)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 9), SortOrder = Enum.SortOrder.LayoutOrder}, copies)
	text({Size = UDim2.fromOffset(62, 30), TextSize = 18, TextColor3 = MUTED, Text = "Copies", LayoutOrder = 0}, copies, 2.5)
	local copiesText = text({Size = UDim2.fromOffset(60, 34), Font = UI.TITLE, TextSize = 24, Text = "", LayoutOrder = 99, TextXAlignment = Enum.TextXAlignment.Left}, copies, 3)
	local slots = {}

	local statsBox = new("Frame", {Position = UDim2.fromOffset(32, 446), Size = UDim2.fromOffset(280, 70), BackgroundTransparency = 1}, D)
	new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, statsBox)
	local function statRow(order, iconFn, suffix)
		local r = new("Frame", {Size = UDim2.fromOffset(280, 30), BackgroundTransparency = 1, LayoutOrder = order}, statsBox)
		new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder}, r)
		iconFn({Size = UDim2.fromOffset(30, 30), LayoutOrder = 1}, r)
		local a = text({Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, Font = UI.TITLE, TextSize = 23, Text = "", LayoutOrder = 2}, r, 3)
		UI.icon("arrowR", {Size = UDim2.fromOffset(22, 22), LayoutOrder = 3, ImageColor3 = LIME}, r)
		local b = text({Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, Font = UI.TITLE, TextSize = 23, TextColor3 = LIME, Text = "", LayoutOrder = 4}, r, 3)
		local p = text({Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, TextSize = 15, TextColor3 = MUTED, Text = "", LayoutOrder = 5}, r, 0)
		for _, l in {a, b} do
			new("UIPadding", {PaddingTop = UDim.new(0, 4)}, l)
		end
		return {a = a, b = b, p = p, suffix = suffix}
	end
	local coinRow = statRow(1, function(p, parent) return UI.art("coin", p, parent) end, "coins per scare")
	local fearRow = statRow(2, function(p, parent) return UI.icon("skull", p, parent) end, "fear")

	local fuseHolder = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(416, 471), Size = UDim2.fromOffset(196, 70), BackgroundTransparency = 1}, D)
	local fusePulse = new("UIScale", {}, fuseHolder)
	local fuseBtn = UI.button({Name = "FuseButton", Size = UDim2.fromScale(1, 1), BackgroundColor3 = UI.BUY, Text = "FUSE!", Font = UI.TITLE, TextSize = 42}, fuseHolder)
	local note = text({Position = UDim2.fromOffset(296, 510), Size = UDim2.fromOffset(240, 18), TextSize = 12, TextColor3 = Color3.fromRGB(184, 172, 214), Text = "", TextScaled = true}, D, 0)

	---------- Pantalla de resultado ----------
	local resultGui = new("ScreenGui", {Name = "FusionResult", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 30, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, player:WaitForChild("PlayerGui"))
	local dim = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 4, 16), BackgroundTransparency = 0.08, BorderSizePixel = 0, Active = true}, resultGui)
	local R = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1280, 760), BackgroundTransparency = 1}, resultGui)
	local rScale = new("UIScale", {}, R)
	local rRays = UI.piece("rays", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(640, 230), Size = UDim2.fromOffset(820, 820), ImageTransparency = 0.5}, R)
	local rRays2 = UI.piece("rays", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(640, 230), Size = UDim2.fromOffset(600, 600), ImageTransparency = 0.7}, R)
	local rGlow = UI.piece("glow2", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(640, 230), Size = UDim2.fromOffset(560, 460), ImageTransparency = 0.25}, R)
	local rTitle = UI.piece("ribbon", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(640, 28), Size = UDim2.fromOffset(560, 80), ZIndex = 4}, R)
	rTitle.SliceScale = 0.6
	text({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 34), Size = UDim2.new(1, -120, 0, 46), Font = UI.TITLE, TextSize = 40, Text = "FUSION COMPLETE!", ZIndex = 5}, rTitle, 4)
	local rVpHolder = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(640, 262), Size = UDim2.fromOffset(300, 300), BackgroundTransparency = 1, ZIndex = 3}, R)
	local rStarsRow, rStars = starRow(R, 76, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(640, 404), Size = UDim2.fromOffset(300, 84), ZIndex = 5})
	local rTier = text({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(640, 488), Size = UDim2.fromOffset(900, 62), Font = UI.TITLE, TextSize = 62, Text = "", ZIndex = 5}, R, 6)
	local rName = text({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(640, 548), Size = UDim2.fromOffset(900, 36), Font = UI.TITLE, TextSize = 32, Text = "", ZIndex = 5}, R, 4)
	local rChips = new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(640, 594), Size = UDim2.fromOffset(900, 44), BackgroundTransparency = 1, ZIndex = 5}, R)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder}, rChips)
	local function rewardChip(order, iconFn)
		local c = round(new("Frame", {Size = UDim2.fromOffset(0, 44), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = INK, BackgroundTransparency = 0.1, LayoutOrder = order}, rChips), 16)
		new("UIStroke", {Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, c)
		new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 16)}, c)
		new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, c)
		iconFn({Size = UDim2.fromOffset(32, 32), LayoutOrder = 1}, c)
		local l = text({Size = UDim2.fromOffset(0, 44), AutomaticSize = Enum.AutomaticSize.X, TextSize = 20, Text = "", RichText = true, LayoutOrder = 2}, c, 2.5)
		return l
	end
	local rCoins = rewardChip(1, function(p, parent) return UI.art("coin", p, parent) end)
	local rFear = rewardChip(2, function(p, parent) return UI.icon("skull", p, parent) end)
	local rAura = rewardChip(3, function(p, parent) return UI.icon("sparkle", p, parent) end)
	local rPlaced = text({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(640, 646), Size = UDim2.fromOffset(900, 22), TextSize = 16, TextColor3 = MUTED, Text = "", ZIndex = 5}, R, 2)
	local okHolder = new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(640, 680), Size = UDim2.fromOffset(220, 62), BackgroundTransparency = 1, ZIndex = 5}, R)
	local okPulse = new("UIScale", {}, okHolder)
	local okBtn = UI.button({Name = "AwesomeButton", Size = UDim2.fromScale(1, 1), BackgroundColor3 = UI.BUY, Text = "AWESOME!", Font = UI.TITLE, TextSize = 32, ZIndex = 6}, okHolder)

	---------- Estado ----------
	local cards, focus, filter, busy = {}, nil, "ready", false
	local popAt = {} -- [t] = os.clock() de la última estrella (late la carta)

	local function setChip(c, on)
		c.g.Color = on and SEQ_GREEN or ColorSequence.new(Color3.fromRGB(70, 50, 108), Color3.fromRGB(52, 36, 84))
		c.l.TextColor3 = on and WHITE or MUTED
	end

	local function makeCard(t)
		local def = Config.Scares[t]
		local b, parts = UI.card(scroll, 0, catColor(t), {Class = "TextButton", Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(132, 168)})
		UI.piece("glow2", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 66), Size = UDim2.fromOffset(120, 120), ImageColor3 = catColor(t):Lerp(WHITE, 0.4), ImageTransparency = 0.6, ZIndex = 3}, b)
		local vp = UI.viewport(t, b, {Position = UDim2.fromOffset(12, 6), Size = UDim2.fromOffset(108, 112), ZIndex = 4}, true)
		local _, stars = starRow(b, 22, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 114), Size = UDim2.fromOffset(80, 24), ZIndex = 5})
		text({Position = UDim2.fromOffset(4, 138), Size = UDim2.new(1, -8, 0, 22), TextSize = 15, TextScaled = true, Text = def.name, ZIndex = 5}, b, 2)
		local pill = round(new("Frame", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -7, 0, 7), Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = INK, BackgroundTransparency = 0.15, ZIndex = 6}, b), 10)
		new("UIStroke", {Color = Color3.fromRGB(190, 170, 240), Transparency = 0.4, Thickness = 1.5}, pill)
		new("UIPadding", {PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7), PaddingTop = UDim.new(0, 3)}, pill)
		local count = text({Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, Font = UI.TITLE, TextSize = 16, Text = "", ZIndex = 7}, pill, 0)
		local ready = UI.chip("READY!", UI.GREEN, {Position = UDim2.fromOffset(-12, -10), Rotation = 8, ZIndex = 8, TextSize = 14}, b)
		local pop = new("UIScale", {}, b)
		b.Name = "Card_" .. t
		b.Activated:Connect(function()
			UI.sound("Tab")
			focus = t
			UI.refreshFusion()
		end)
		cards[t] = {b = b, parts = parts, vp = vp, stars = stars, count = count, ready = ready, pop = pop}
		return cards[t]
	end

	local function setBig(t)
		if bigVp and bigVp:GetAttribute("T") == t then
			return
		end
		if bigVp then
			bigVp:Destroy()
		end
		bigVp = UI.viewport(t, D, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, 256), Size = UDim2.fromOffset(260, 246), ZIndex = 3})
		bigVp:SetAttribute("T", t)
		for _, s in slots do
			s:Destroy()
		end
		table.clear(slots)
	end

	local function show(t)
		local def = Config.Scares[t]
		local n, star, cost, can = info(t)
		setBig(t)
		bigName.Text = def.name:upper()
		local cat = Config.Categories[def.cat]
		rarity.Text = cat.name
		rarity.BackgroundColor3 = cat.color
		local maxed = star >= Config.STAR_MAX
		paintStars(nowStars, star)
		arrow.Visible, nextBox.Visible = not maxed, not maxed
		copies.Visible, statsBox.Visible, fuseHolder.Visible, note.Visible = not maxed, not maxed, not maxed, not maxed
		maxText.Visible = maxed
		if maxed then
			tierText.Text = "MYTHIC  ·  this scare can't get any scarier"
			tierText.TextColor3 = STARS[3]
			return
		end
		local nx = star + 1
		paintStars(nextStars, star, nx)
		nextStroke.Color, nextStroke.Transparency = STARS[nx], 0.1
		tierText.Text = (star == 0 and "NO STAR" or TIER[star]) .. "  →  " .. TIER[nx]
		tierText.TextColor3 = STARS[nx]:Lerp(WHITE, 0.2)
		-- casillas de copias (una por copia que pide)
		if #slots ~= cost then
			for _, s in slots do
				s:Destroy()
			end
			table.clear(slots)
			for k = 1, cost do
				local s = round(new("Frame", {Size = UDim2.fromOffset(40, 40), BackgroundColor3 = WHITE, LayoutOrder = k, ClipsDescendants = true}, copies), UDim.new(0.5, 0))
				new("UIGradient", {Name = "Fill", Rotation = 90}, s)
				new("UIStroke", {Color = INK, Thickness = 3}, s)
				UI.viewport(t, s, {Position = UDim2.fromOffset(-4, -2), Size = UDim2.fromOffset(48, 48), Name = "Vp"}, true)
				slots[k] = s
			end
		end
		local have = math.min(n, cost)
		for k, s in slots do
			local on = k <= have
			s.Fill.Color = on and ColorSequence.new(Color3.fromRGB(110, 220, 90), Color3.fromRGB(40, 120, 50)) or ColorSequence.new(Color3.fromRGB(46, 34, 66))
			s.Vp.ImageTransparency = on and 0 or 0.75
		end
		copiesText.Text = ("%d/%d"):format(have, cost)
		copiesText.TextColor3 = can and Color3.fromRGB(150, 255, 120) or Color3.fromRGB(255, 140, 156)
		-- (el % es lo que sube lo que ves: de un número al otro)
		local now, nxt = Config.starDef(t, star), Config.starDef(t, nx)
		local payA = Config.scarePay(player, t)
		local payB = math.floor(payA * nxt.pay / now.pay + 0.5)
		local function rise(a, b)
			return math.max(1, math.floor((b / math.max(a, 1) - 1) * 100 + 0.5))
		end
		coinRow.a.Text, coinRow.b.Text = UI.fmt(payA), UI.fmt(payB)
		coinRow.p.Text = ("(+%d%%)  coins per scare"):format(rise(payA, payB))
		fearRow.a.Text, fearRow.b.Text = tostring(now.fear), tostring(nxt.fear)
		fearRow.p.Text = ("(+%d%%)  fear"):format(rise(now.fear, nxt.fear))
		if can then
			fuseBtn.Text, fuseBtn.TextSize, fuseBtn.BackgroundColor3 = "FUSE!", 42, UI.BUY
		else
			local need = cost - n
			fuseBtn.Text, fuseBtn.TextSize, fuseBtn.BackgroundColor3 = ("NEED %d MORE"):format(need), 22, UI.CANT
		end
		note.Text = ("Copies are used up · all your %ss get the star"):format(def.name)
	end

	function UI.refreshFusion()
		local list, readyN = {}, 0
		for i, t in ALL do
			local n, star, _, can = info(t)
			if n > 0 or star > 0 then
				readyN += can and 1 or 0
				if filter == "all" or can then
					table.insert(list, {t = t, n = n, star = star, can = can, i = i})
				end
			end
		end
		table.sort(list, function(a, b)
			if a.can ~= b.can then
				return a.can
			end
			if a.n ~= b.n then
				return a.n > b.n
			end
			return a.i < b.i
		end)
		readyCount.Text = tostring(readyN)
		readyBadge.Visible = readyN > 0
		setChip(readyChip, filter == "ready")
		setChip(allChip, filter == "all")
		local shown = {}
		for order, e in list do
			local c = cards[e.t] or makeCard(e.t)
			shown[e.t] = true
			c.b.LayoutOrder = order
			c.b.Visible = true
			c.count.Text = "x" .. e.n
			c.ready.Visible = e.can
			paintStars(c.stars, e.star)
		end
		for t, c in cards do
			if not shown[t] then
				c.b.Visible = false
			end
		end
		if not (focus and shown[focus]) then
			focus = list[1] and list[1].t or focus
		end
		for t, c in cards do
			local sel = t == focus
			c.parts.stroke.Color = sel and UI.GOLD or INK
			c.parts.stroke.Thickness = sel and 4.5 or 3.5
			c.b.BackgroundTransparency = (sel or (c.ready.Visible)) and 0 or 0.25
		end
		emptyText.Visible = #list == 0
		D.Visible = focus ~= nil and (shown[focus] or filter == "all")
		if focus and D.Visible then
			show(focus)
		end
	end

	---------- Abrir y cerrar ----------
	local function station()
		local f = workspace:FindFirstChild("Mapa") and workspace.Mapa:FindFirstChild("Tiendas")
		return f and f:FindFirstChild("Fusion")
	end
	function UI.toggleFusion(open, t)
		if open == nil then
			open = not win.Visible
		end
		if open == win.Visible then
			return
		end
		if open then
			if t then
				focus = t
			end
			filter = "ready"
			UI.refreshFusion()
			if #scroll:GetChildren() > 0 and readyCount.Text == "0" then
				filter = "all"
				UI.refreshFusion()
			end
			win.Visible = true
			UI.popIn(win)
			UI.sound("Open")
		else
			win.Visible = false
			UI.sound("Close")
		end
	end
	close.Activated:Connect(function()
		UI.toggleFusion(false)
	end)
	readyChip.b.Activated:Connect(function()
		filter = "ready"
		UI.sound("Tab")
		UI.refreshFusion()
	end)
	allChip.b.Activated:Connect(function()
		filter = "all"
		UI.sound("Tab")
		UI.refreshFusion()
	end)
	more.Activated:Connect(function()
		UI.toggleFusion(false)
		if UI.goToStall then
			UI.goToStall("wheel", "Duplicates come from the Wheel")
		end
	end)
	game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
		local s = station()
		if s and prompt:IsDescendantOf(s) then
			UI.toggleFusion(true)
		end
	end)

	fuseBtn.Activated:Connect(function()
		if busy or not focus then
			return
		end
		local n, star, cost, can = info(focus)
		if star >= Config.STAR_MAX then
			return
		end
		if not can then
			UI.toast(("You need %d more %s copies · spin the Wheel of Fright!"):format(cost - n, Config.Scares[focus].name), UI.ORANGE, "wheel")
			return
		end
		busy = true
		UI.sound("Sparkle")
		Remote:FireServer("Fuse", focus)
		task.delay(3, function()
			busy = false
		end)
	end)

	---------- Resultado ----------
	local resultOpen = false
	local function closeResult()
		if not resultOpen then
			return
		end
		resultOpen = false
		UI.sound("Close")
		tween(rScale, 0.2, {Scale = 0}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.wait(0.2)
		resultGui.Enabled = false
	end
	okBtn.Activated:Connect(closeResult)

	local function placedCount(t)
		local plot = player:GetAttribute("Plot")
		local casas = workspace:FindFirstChild("Casas")
		local house = plot and casas and casas:FindFirstChild("Casa" .. plot)
		local placed = house and house:FindFirstChild("Scares")
		local n = 0
		for _, m in placed and placed:GetChildren() or {} do
			n += m.Name == t and 1 or 0
		end
		return n
	end

	local function showResult(t, star)
		local def = Config.Scares[t]
		local col = STARS[star]
		for _, c in rVpHolder:GetChildren() do
			c:Destroy()
		end
		UI.viewport(t, rVpHolder, {Size = UDim2.fromScale(1, 1), ZIndex = 3})
		rRays.ImageColor3, rRays2.ImageColor3, rGlow.ImageColor3 = col, col:Lerp(WHITE, 0.5), col
		rTitle.ImageColor3 = col:Lerp(INK, 0.15)
		paintStars(rStars, star)
		rTier.Text = TIER[star] .. "!"
		rTier.TextColor3 = col:Lerp(WHITE, 0.25)
		rName.Text = def.name:upper()
		local gain = function(list)
			return math.floor(list[star] * 100 + 0.5)
		end
		rCoins.Text = ("<font color='#8CFF6E'>+%d%%</font> coins"):format(gain(Config.STAR_PAY))
		rFear.Text = ("<font color='#8CFF6E'>+%d%%</font> fear"):format(gain(Config.STAR_FEAR))
		rAura.Text = ("<font color='#%s'>%s</font> aura"):format(col:ToHex(), TIER[star]:sub(1, 1) .. TIER[star]:sub(2):lower())
		local placed = placedCount(t)
		rPlaced.Text = placed > 0 and ("Your %d placed %s%s got the star too!"):format(placed, def.name, placed == 1 and "" or "s") or ("Every %s you place now shines with it!"):format(def.name)
		resultGui.Enabled = true
		resultOpen = true
		local vs = workspace.CurrentCamera.ViewportSize
		local fit = math.clamp(math.min(vs.X / 1280, vs.Y / 760), 0.5, 1.2)
		rScale.Scale = 0.2
		tween(rScale, 0.55, {Scale = fit}, Enum.EasingStyle.Back)
		-- la estrella nueva aparece de golpe
		local s = rStars[star]:FindFirstChildOfClass("UIScale")
		s.Scale = 3
		task.delay(0.25, function()
			tween(s, 0.45, {Scale = 1.15}, Enum.EasingStyle.Back)
			UI.sound("Sparkle", 1, 1.2)
		end)
		UI.sound("Win")
		UI.flash(col, 0.35, 0.8)
		UI.confetti(110)
	end

	Remote.OnClientEvent:Connect(function(kind, a, b)
		if kind == "Fused" then
			busy = false
			popAt[a] = os.clock()
			UI.refreshFusion()
			showResult(a, b)
		end
	end)

	---------- Aviso: ya puedes fusionar ----------
	-- (resultOpen se declara arriba, en Resultado)
	local told = {}
	for _, t in ALL do
		local _, star, _, can = info(t)
		if can then
			told[t .. star] = true -- (lo que ya podías al entrar no avisa)
		end
	end
	player.AttributeChanged:Connect(function(name)
		local t = name:match("^Inv_(.+)$") or name:match("^Star_(.+)$")
		if not (t and Config.Scares[t]) then
			return
		end
		local _, star, _, can = info(t)
		if can and not told[t .. star] then
			told[t .. star] = true
			if win.Visible or resultOpen then
				-- (ya estás en el caldero: la carta lo dice con READY!)
				return UI.refreshFusion()
			end
			UI.toast(("You can fuse %s! Visit Hexa's Cauldron in the cemetery"):format(Config.Scares[t].name), GREEN, "star", {time = 5})
		end
		if win.Visible then
			UI.refreshFusion()
		end
	end)

	---------- Cada frame: rayos, botón que late, modelo que flota y cerrar al alejarse ----------
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		if win.Visible then
			rays.Rotation = t * 14
			if bigVp then
				bigVp.Position = UDim2.new(0.5, 0, 0, 252 + math.sin(t * 2.4) * 6)
			end
			fusePulse.Scale = fuseBtn.BackgroundColor3 == UI.BUY and 1 + math.sin(t * 5) * 0.04 or 1
			for ct, c in cards do
				if c.ready.Visible then
					c.ready.Rotation = 8 + math.sin(t * 4 + #ct) * 5
				end
				local since = popAt[ct] and t - popAt[ct]
				c.pop.Scale = since and since < 0.6 and 1 + math.sin(since / 0.6 * math.pi) * 0.15 or 1
			end
			local s = station()
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if s and root and (root.Position - s:GetPivot().Position).Magnitude > REACH then
				UI.toggleFusion(false)
			end
		end
		if resultOpen then
			rRays.Rotation = t * 20
			rRays2.Rotation = -t * 12
			rVpHolder.Position = UDim2.fromOffset(640, 262 + math.sin(t * 2.4) * 8)
			okPulse.Scale = 1 + math.sin(t * 5) * 0.04
		end
	end)
end
