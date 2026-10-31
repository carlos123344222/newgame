-- Tropas (cliente). Dos cosas:
--  * La pantalla "Troops" (pestaña Troops o botón del menú), con el estilo de Catalog: SOLO las tropas que tienes, por
--    categoría (las que aún no tienes se ven en la Shop). La elegida sale en grande a la derecha con sus estadísticas del
--    Tower Defense (de nivel 1 o, con MAX LEVEL, al máximo de mejoras), su nivel y experiencia y Equip / Unequip. Abajo,
--    tu equipo de hasta TD.SLOTS (se guarda: acción "Loadout" de Juego). Se cierra sola al entrar en partida.
--  * La barra de tropas: fuera de casa (calle, plaza, lobbies) se ven abajo tus tropas equipadas con su nivel; pulsando
--    una se abre su ficha.
-- Niveles: cada tropa sube con la experiencia (atributo XP_<tipo> que da el servidor; Config.levelOf). Al subir, aviso.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(RS:WaitForChild("Config"))
local TD = require(RS:WaitForChild("TowerDefense"))
local GameRemote = RS:WaitForChild("Remote")
local UI = require(script.Parent:WaitForChild("UI"))
local Kit = require(script.Parent:WaitForChild("TDKit"))
local C = require(script.Parent:WaitForChild("Catalog"))(UI)
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local new, label, corner, outline = UI.new, Kit.label, Kit.corner, Kit.outline
local LEFT = Enum.TextXAlignment.Left
local HORIZONTAL = Enum.FillDirection.Horizontal
local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
local XP_COLOR = Color3.fromRGB(110, 214, 255)
local EQUIPPED = Color3.fromRGB(196, 30, 40) -- carta de una tropa del equipo (roja, como en la referencia)

local function list(props, parent)
	props.SortOrder = Enum.SortOrder.LayoutOrder
	return new("UIListLayout", props, parent)
end

local function pad(o, l, r, t, b)
	new("UIPadding", {PaddingLeft = UDim.new(0, l), PaddingRight = UDim.new(0, r or l), PaddingTop = UDim.new(0, t or l), PaddingBottom = UDim.new(0, b or t or l)}, o)
end

local function owns(t)
	return TD.owns(player, t)
end

-- nivel, experiencia dentro del nivel y la que necesita para el siguiente (0 en el máximo)
local function levelOf(t)
	return Config.levelOf(player:GetAttribute("XP_" .. t) or 0)
end

-- color del nivel: de bronce a oro; el máximo, rosa
local function levelColor(lv)
	if lv >= Config.TROOP_MAX_LEVEL then
		return Color3.fromRGB(255, 110, 210)
	end
	return Color3.fromRGB(205, 140, 80):Lerp(UI.GOLD, (lv - 1) / (Config.TROOP_MAX_LEVEL - 2))
end

---------- Pantalla de tropas ----------
local screen = C.screen("Troops", "Troops")
local stage = screen.stage
local lp = C.leftPanel(stage)
local detail = C.detail(stage)
local scroll = lp.list()
-- (las tropas que vuelan al equipar van en su propia capa)
local flyGui = new("ScreenGui", {Name = "TroopsFly", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 7}, playerGui)

local teamChip = C.chip(lp.right, "", "swords", {Size = UDim2.fromOffset(134, 48), LayoutOrder = 1})
local bestBtn = C.button(lp.right, "Best Team", "orange", {Size = UDim2.fromOffset(176, 48), LayoutOrder = 2, TextSize = 21}, "lightning")
local equipBtn = C.button(detail.buttons, "EQUIP", "green", {Size = UDim2.fromOffset(210, 58), LayoutOrder = 1})
local maxBtn = C.button(detail.buttons, "PREVIEW MAX", "cyan", {Size = UDim2.fromOffset(230, 58), LayoutOrder = 2})
detail.desc.RichText = true

-- nivel de la tropa (bajo las estadísticas): "LV 3  Spooky" y su barra de experiencia
local lvRow = new("Frame", {Position = UDim2.fromOffset(0, 412), Size = UDim2.fromOffset(250, 60), BackgroundTransparency = 1, ZIndex = 3}, detail.frame)
local lvText = C.text({Size = UDim2.new(1, 0, 0, 28), TextSize = 24, TextXAlignment = LEFT, RichText = true, Text = "", ZIndex = 3}, lvRow, 2)
local xpBack = corner(new("Frame", {Position = UDim2.fromOffset(0, 34), Size = UDim2.fromOffset(200, 12), BackgroundColor3 = Color3.fromRGB(10, 10, 14), BackgroundTransparency = 0.15, ZIndex = 3}, lvRow), 6)
outline(xpBack, Color3.fromRGB(96, 96, 106), 1.5)
local xpFill = corner(new("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = XP_COLOR, BorderSizePixel = 0, ZIndex = 4}, xpBack), 6)
new("UIGradient", {Rotation = 90, Color = ColorSequence.new(WHITE, Color3.fromRGB(190, 190, 190))}, xpFill)
local xpText = C.text({AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, 10, 0.5, 0), Size = UDim2.fromOffset(130, 18), Font = C.BOLD, TextSize = 15, TextXAlignment = LEFT, Text = "", ZIndex = 3}, xpBack, 1.5)

local CATS = {"Basico", "Criatura", "Trampa", "Legendario"}
local equipped = {} -- lo que ves en la pantalla (se manda al servidor al cambiar)
local focusType
local showMax = false -- estadísticas al máximo de mejoras de la partida
local filter, query = nil, ""
local cards = {}
local slotFrames = {}

local function refreshCards()
	for t, c in cards do
		local on = table.find(equipped, t) ~= nil
		c.badge(on and "check" or nil)
		c.color(on and EQUIPPED or nil)
		c.select(t == focusType)
	end
	teamChip.label.Text = ("Team %d/%d"):format(#equipped, TD.SLOTS)
end

local function showDetail(t)
	focusType = t
	local def = Config.Scares[t]
	local cat = Config.Categories[def.cat]
	detail.name.Text = def.name
	detail.sub.Text = cat.name .. (showMax and ("  ·  Upgraded to Lv %d"):format(TD.MAX_LEVEL) or "")
	detail.sub.TextColor3 = cat.color:Lerp(WHITE, 0.3)
	if detail.model:GetAttribute("Showing") ~= t then
		detail.setModel(t)
		detail.model:SetAttribute("Showing", t)
	end
	detail.setLock(nil)
	local lv, into, need = levelOf(t)
	local s = TD.stats(t, showMax and TD.MAX_LEVEL or 1, lv)
	local up = showMax and UI.GOLD or nil
	local rows = {{"coins", Kit.money(TD.Troops[t].cost), Kit.CASH, "to place"}}
	if TD.attacks(t) and s.dmg and s.cd then
		table.insert(rows, {"skull", math.floor(s.dmg + 0.5), up, "fear"})
		table.insert(rows, {"hourglass", ("%.2fs"):format(s.cd), up, "cooldown"})
	end
	table.insert(rows, {"target", math.floor(s.range + 0.5), up, "range"})
	table.insert(rows, {"users", "x" .. TD.limit(t), nil, "max placed"})
	detail.setStats(rows)
	lvRow.Position = UDim2.fromOffset(0, 116 + #rows * 58 + 6)
	lvText.Text = ('<font color="#%s">LV %d</font>  %s'):format(levelColor(lv):ToHex(), lv, Config.LEVEL_NAMES[lv] or "")
	xpFill.Size = UDim2.fromScale(need > 0 and into / need or 1, 1)
	xpFill.BackgroundColor3 = need > 0 and XP_COLOR or levelColor(lv)
	xpText.Text = need > 0 and ("%d / %d XP"):format(into, need) or "MAX LEVEL!"
	detail.desc.Text = ('%s\n<font color="#9FE6FF">%s</font>'):format(TD.Troops[t].info, Kit.special(s))
	local on = table.find(equipped, t)
	if on then
		equipBtn.set("UNEQUIP", "red")
	elseif #equipped >= TD.SLOTS then
		equipBtn.set("TEAM FULL", "grey")
	else
		equipBtn.set("EQUIP", "green")
	end
	maxBtn.set(showMax and "SHOW LV 1" or "PREVIEW MAX", "cyan")
	refreshCards()
end

-- tu equipo, abajo: un hueco por tropa con el borde de su color
local function buildTeam()
	for _, c in detail.bottom:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	table.clear(slotFrames)
	for i = 1, TD.SLOTS do
		local t = equipped[i]
		local b = corner(new("TextButton", {
			Size = UDim2.fromOffset(78, 78), BackgroundColor3 = Color3.fromRGB(16, 16, 20), BackgroundTransparency = 0.15, Text = "", AutoButtonColor = false, LayoutOrder = i,
		}, detail.bottom), 6)
		outline(b, t and Kit.color(t) or Color3.fromRGB(120, 120, 130), t and 3 or 2, t and 0 or 0.45)
		if t then
			local vp = UI.viewport(t, b, {Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6)}, true)
			if vp.CurrentCamera then
				vp.CurrentCamera.FieldOfView = 30
			end
			C.text({Position = UDim2.fromOffset(6, 3), Size = UDim2.fromOffset(16, 18), TextSize = 16, Text = tostring(i), ZIndex = 3}, b, 1.5)
			b.Activated:Connect(function()
				UI.sound("Tab")
				showDetail(t)
			end)
		else
			C.text({Size = UDim2.fromScale(1, 1), TextSize = 36, Text = "+", TextColor3 = Color3.fromRGB(150, 150, 160)}, b, 0)
		end
		UI.press(b, 1.08)
		slotFrames[i] = b
	end
end

local function matches(t)
	return query == "" or Config.Scares[t].name:lower():find(query, 1, true) ~= nil
end

local emptyNote
local function buildTroops()
	for _, c in scroll:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	table.clear(cards)
	local first
	for ci, cat in CATS do
		local items = {}
		for i, t in Config.ScareOrder do
			if TD.Troops[t] and Config.Scares[t].cat == cat and owns(t) and (not filter or filter == cat) and matches(t) then
				table.insert(items, {t = t, i = i})
			end
		end
		if #items > 0 then
			local cd = Config.Categories[cat]
			local _, grid = C.section(scroll, cd.name, cd.color:Lerp(WHITE, 0.15), ci)
			for _, e in items do
				local c = C.card(grid, e.i, {t = e.t, name = Config.Scares[e.t].name})
				c.button.Activated:Connect(function()
					UI.sound("Tab")
					showDetail(e.t)
				end)
				cards[e.t] = c
				first = first or e.t
			end
		end
	end
	if not first then
		emptyNote = C.text({Size = UDim2.new(1, 0, 0, 80), Font = C.BOLD, TextSize = 22, TextWrapped = true, TextColor3 = C.MUTED, Text = query ~= "" and "No troops match your search." or "No troops here yet. Get scares in the Shop and they join your army!"}, scroll, 1.5)
	end
	buildTeam()
	if not (focusType and owns(focusType) and TD.Troops[focusType]) then
		focusType = equipped[1] or first
	end
	if focusType then
		showDetail(focusType)
	end
end

lp.setFilters((function()
	local f = {{"All troops", nil}}
	for _, cat in CATS do
		table.insert(f, {Config.Categories[cat].name, cat, Config.Categories[cat].color:Lerp(WHITE, 0.2)})
	end
	return f
end)(), nil, function(v)
	filter = v
	buildTroops()
end)
lp.box:GetPropertyChangedSignal("Text"):Connect(function()
	query = lp.box.Text:lower()
	if screen.root.Visible then
		buildTroops()
	end
end)

local function sendLoadout()
	GameRemote:FireServer("Loadout", equipped)
	buildTeam()
	if focusType then
		showDetail(focusType)
	end
end

-- la tropa vuela desde la ficha hasta su hueco del equipo
local function flyToSlot(t, i)
	local to = slotFrames[i]
	if not to then
		return
	end
	local m = detail.model
	local a = m.AbsolutePosition + m.AbsoluteSize / 2
	local b = to.AbsolutePosition + to.AbsoluteSize / 2
	local s0 = m.AbsoluteSize.Y * 0.5
	local g = UI.viewport(t, flyGui, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(a.X, a.Y), Size = UDim2.fromOffset(s0, s0), ZIndex = 5}, true)
	local tw = TweenService:Create(g, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Position = UDim2.fromOffset(b.X, b.Y), Size = UDim2.fromOffset(to.AbsoluteSize.X, to.AbsoluteSize.Y)})
	tw:Play()
	tw.Completed:Once(function()
		g:Destroy()
		if to.Parent then
			local pop = to:FindFirstChildOfClass("UIScale") or new("UIScale", {}, to)
			pop.Scale = 1.3
			TweenService:Create(pop, TweenInfo.new(0.35, Enum.EasingStyle.Back), {Scale = 1}):Play()
			UI.sound("Place")
		end
	end)
end

equipBtn.button.Activated:Connect(function()
	local t = focusType
	if not t or not owns(t) then
		return
	end
	local i = table.find(equipped, t)
	if i then
		table.remove(equipped, i)
		UI.sound("Close")
		sendLoadout()
	elseif #equipped < TD.SLOTS then
		table.insert(equipped, t)
		UI.sound("Success")
		sendLoadout()
		flyToSlot(t, #equipped)
	else
		UI.toast("Your team is full: unequip a troop first", UI.RED)
	end
end)

maxBtn.button.Activated:Connect(function()
	showMax = not showMax
	UI.sound("Tab")
	if focusType then
		showDetail(focusType)
	end
end)

-- el mejor equipo: las de más nivel (y, a igualdad, las más caras)
bestBtn.button.Activated:Connect(function()
	local pool = {}
	for _, t in Config.ScareOrder do
		if TD.Troops[t] and owns(t) then
			table.insert(pool, t)
		end
	end
	table.sort(pool, function(a, b)
		local la, lb = levelOf(a), levelOf(b)
		if la ~= lb then
			return la > lb
		end
		return Config.Scares[a].price > Config.Scares[b].price
	end)
	table.clear(equipped)
	for k = 1, math.min(TD.SLOTS, #pool) do
		equipped[k] = pool[k]
	end
	UI.sound("Success")
	sendLoadout()
	for k = 1, #equipped do
		local f = slotFrames[k]
		if f then
			local pop = f:FindFirstChildOfClass("UIScale") or new("UIScale", {}, f)
			pop.Scale = 0.3
			TweenService:Create(pop, TweenInfo.new(0.35 + k * 0.06, Enum.EasingStyle.Back), {Scale = 1}):Play()
		end
	end
end)

screen.onToggle = function(open)
	if open then
		buildTroops()
	end
end

local function openTroops(open, focus)
	if open then
		equipped = TD.loadout(player)
		if focus then
			focusType = focus
		end
		if screen.root.Visible and focus then
			showDetail(focus)
		end
	end
	screen.open(open)
end
UI.openTroops = function(focus)
	openTroops(true, focus)
end
C.openers.Troops = function()
	openTroops(true)
end

-- Botón "Troops" en el menú
UI.menuButton(6, "swords", "Troops", Color3.fromRGB(226, 60, 84)).Activated:Connect(function()
	openTroops(not screen.root.Visible)
end)

-- En partida no se cambia el equipo
player:GetAttributeChangedSignal("TDCash"):Connect(function()
	if player:GetAttribute("TDCash") ~= nil and screen.root.Visible then
		openTroops(false)
	end
end)

---------- Barra de tropas (abajo, fuera de casa) ----------
local barGui = new("ScreenGui", {Name = "TroopBar", ResetOnSpawn = false, DisplayOrder = 4, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, playerGui)
local barScale = new("UIScale", {Scale = UI.uiScale.Scale}, barGui)
UI.uiScale:GetPropertyChangedSignal("Scale"):Connect(function()
	barScale.Scale = UI.uiScale.Scale
end)
-- Diseño tipo hotbar de los juegos de defensa: sin panel ni botones extra, solo los huecos: cuadrados oscuros
-- translúcidos con el borde del color de la categoría, el número del hueco en un cuadradito de ese color asomando
-- arriba a la izquierda y el modelo 3D quieto. Pulsar un hueco abre su ficha (o la pantalla de tropas si está vacío);
-- el nombre y el nivel salen en un globo al pasar el ratón. Debajo, la franja del nivel del jugador (la pone
-- NivelJugador en LevelHolder). Aparece y desaparece en su sitio, sin deslizarse.
local SLOT = Vector2.new(62, 62)
local GAP = 12
local SLOT_BG = Color3.fromRGB(22, 20, 30)
local EMPTY = Color3.fromRGB(110, 104, 128)
local SLOTS_W = TD.SLOTS * SLOT.X + (TD.SLOTS - 1) * GAP
local BAR_W = SLOTS_W + 56 -- la franja del nivel, algo más ancha que la fila (como en la referencia)
local bar = new("Frame", {
	Name = "Bar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.fromOffset(BAR_W, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1, Visible = false,
}, barGui)
list({Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center}, bar)
local barSlots = new("Frame", {Name = "Slots", Size = UDim2.fromOffset(SLOTS_W, SLOT.Y), BackgroundTransparency = 1, LayoutOrder = 1}, bar)
list({FillDirection = HORIZONTAL, Padding = UDim.new(0, GAP), VerticalAlignment = Enum.VerticalAlignment.Center}, barSlots)
new("Frame", {Name = "LevelHolder", Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 2}, bar)

-- hueco: fondo oscuro, teñido de su color desde abajo y borde de su color. Al pasar: borde blanco y más luz
local function slotFrame(order, color)
	local b = corner(new("TextButton", {
		Size = UDim2.fromOffset(SLOT.X, SLOT.Y), BackgroundColor3 = SLOT_BG, BackgroundTransparency = 0.18, AutoButtonColor = false, Text = "", LayoutOrder = order, ZIndex = 2,
	}, barSlots), 6)
	local tint = corner(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 2}, b), 6)
	local tintGrad = new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(1, 0.72)}, tint)
	local edge = new("UIStroke", {Color = color, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, b)
	local quick = TweenInfo.new(0.12, Enum.EasingStyle.Quad)
	b.MouseEnter:Connect(function()
		TweenService:Create(edge, quick, {Color = WHITE}):Play()
		tintGrad.Transparency = NumberSequence.new(0.9, 0.5)
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(edge, quick, {Color = color}):Play()
		tintGrad.Transparency = NumberSequence.new(1, 0.72)
	end)
	return b, edge, Kit.press(b)
end

-- número del hueco: cuadradito de su color asomando por la esquina de arriba a la izquierda
local function slotNumber(b, n, color)
	local sq = corner(new("Frame", {Position = UDim2.fromOffset(-5, -5), Size = UDim2.fromOffset(19, 19), BackgroundColor3 = color, ZIndex = 8}, b), 4)
	outline(sq, UI.INK, 1.5)
	local t = label({Size = UDim2.fromScale(1, 1), Font = UI.HUD_FONT, TextSize = 13, Text = tostring(n), ZIndex = 9}, sq)
	UI.hudStroke(t, 1.6)
end

-- globo con el nombre de la tropa (al pasar el ratón)
local tip = Kit.corner(label({
	Name = "Tip", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 0.1,
	BackgroundColor3 = UI.DARK, Font = UI.HUD_FONT, TextSize = 13, TextStrokeTransparency = 0, Text = "", Visible = false, ZIndex = 20,
}, barGui), 6)
Kit.outline(tip, UI.INK, 2)
pad(tip, 10, 10, 0, 0)
local barCards = {}

-- hueco con tropa: modelo 3D y número
local function barSlot(t, i)
	local color = Kit.color(t)
	local b, edge, pop = slotFrame(i, color)
	-- (con tu skin equipada: así sale la tropa al colocarla)
	local vp = UI.viewport(Config.skinFor(player, t), b, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -2, 1, -2), ZIndex = 3}, true)
	if vp.CurrentCamera then
		vp.CurrentCamera.FieldOfView = 27 -- más cerca: el modelo llena el hueco
	end
	slotNumber(b, i, color)
	local c = {button = b, vp = vp, stroke = edge, pop = pop}
	b.MouseEnter:Connect(function()
		tip.Text = ("%s · Lv %d"):format(Config.Scares[t].name, (levelOf(t)))
		local p = b.AbsolutePosition + Vector2.new(b.AbsoluteSize.X / 2, -8)
		tip.Position = UDim2.fromOffset(p.X / barScale.Scale, p.Y / barScale.Scale)
		tip.Visible = true
	end)
	b.MouseLeave:Connect(function()
		tip.Visible = false
	end)
	b.Destroying:Connect(function()
		tip.Visible = false
	end)
	return c
end

local function buildBar()
	for _, c in barSlots:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	table.clear(barCards)
	local team = TD.loadout(player)
	for i = 1, TD.SLOTS do
		local t = team[i]
		if t then
			local c = barSlot(t, i)
			c.button.Activated:Connect(function()
				openTroops(true, t)
			end)
			barCards[t] = {card = c}
		else
			local e, edge = slotFrame(i, EMPTY)
			e.BackgroundTransparency = 0.5
			edge.Transparency = 0.45
			slotNumber(e, i, EMPTY:Lerp(BLACK, 0.25))
			UI.icon("plus", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(26, 26), ImageTransparency = 0.45, ZIndex = 4}, e)
			e.Activated:Connect(function()
				openTroops(true)
			end)
		end
	end
end

-- ¿se ve la barra? solo en la calle (ni en casa, ni de visita, ni en partida, ni con ventanas o diálogos abiertos)
local function wanted()
	if player:GetAttribute("Mode") ~= nil or player:GetAttribute("TDCash") ~= nil or player:GetAttribute("Lobby") then
		return false
	end
	if screen.root.Visible or not UI.gui.Enabled or UI.shop.Visible or UI.menuOpen() then
		return false
	end
	for _, name in {"Stores", "Lobby"} do
		local w = UI.gui:FindFirstChild(name)
		if w and w.Visible then
			return false
		end
	end
	for _, name in {"Dialogo", "Portada", "VisitorBook"} do
		local g = playerGui:FindFirstChild(name)
		if g and g.Enabled then
			return false
		end
	end
	return true
end

local showing = false
local dirty = true
task.spawn(function()
	while true do
		if dirty then
			dirty = false
			buildBar()
		end
		local want = wanted()
		if want ~= showing then
			showing = want
			bar.Visible = want
		end
		task.wait(0.2)
	end
end)

---------- Cambios: equipo, colección y niveles ----------
local known = {} -- nivel de cada tropa la última vez (lo que ya tenía al entrar no avisa)
local function onAttr(name)
	if name:sub(1, 5) == "Skin_" then
		dirty = true
		return
	end
	if name == "Loadout" or name == "PlacedTypes" or name:sub(1, 4) == "Inv_" then
		dirty = true
		if screen.root.Visible and name ~= "Loadout" then
			buildTroops()
		end
		return
	end
	if name:sub(1, 3) ~= "XP_" then
		return
	end
	local t = name:sub(4)
	local lv = Config.levelOf(player:GetAttribute(name) or 0)
	local before = known[t]
	known[t] = lv
	if screen.root.Visible and focusType == t then
		showDetail(t)
	end
	if before and lv > before and Config.Scares[t] then
		-- sube de nivel: aviso discreto (el protagonista es el nivel del jugador, NivelJugador)
		UI.toast(("%s reached Lv %d"):format(Config.Scares[t].name, lv), levelColor(lv), "star")
		dirty = true
		local bc = barCards[t]
		if bc then
			local pop = bc.card.pop
			pop.Scale = 1.35
			TweenService:Create(pop, TweenInfo.new(0.5, Enum.EasingStyle.Elastic), {Scale = 1}):Play()
		end
	end
end
for name, v in player:GetAttributes() do
	if name:sub(1, 3) == "XP_" then
		known[name:sub(4)] = Config.levelOf(v)
	end
end
player.AttributeChanged:Connect(onAttr)
