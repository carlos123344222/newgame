-- Recompensas (cliente): dos ventanas, con sus botones en el menú lateral (con aviso rojo cuando hay algo que coger).
--  * DAILY REWARDS: las 7 casillas del premio de conexión (las ya cogidas con ✓, la de hoy en verde y latiendo), la
--    racha y el botón CLAIM debajo de la ventana. Se abre sola al entrar si hoy aún no lo has cogido.
--  * FREE GIFTS: 6 regalos que se abren jugando (5, 10, 15, 25, 40 y 60 min hoy), con la cuenta atrás de cada uno, la
--    lupa que enseña qué puede tocar y con qué probabilidad (panel de la izquierda) y cuándo se reinician.
-- Al coger algo, la pantalla del premio (rayos, el premio en grande, confeti).
-- Datos: ReplicatedStorage.Recompensas. Estado (lo pone Juego): atributos LoginDay, LoginStreak, GiftDay, GiftStart y
-- GiftClaimed del jugador. Acciones: Remote "LoginClaim" y "GiftClaim"; respuestas "LoginClaimed" y "GiftClaimed".
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(RS:WaitForChild("Config"))
local R = require(RS:WaitForChild("Recompensas"))
local UI = require(script.Parent:WaitForChild("UI"))
local Portada = require(script.Parent:WaitForChild("Portada"))
local Remote = RS:WaitForChild("Remote")
local player = Players.LocalPlayer
local new, round, stroke = UI.new, UI.round, UI.stroke

local INK, WHITE, MUTED = UI.INK, UI.WHITE, UI.MUTED
local BLACK = Color3.new(0, 0, 0)
local DAILY_ACCENT = Color3.fromRGB(255, 150, 40)
local GIFT_ACCENT = Color3.fromRGB(150, 100, 255)
local CLAIMED_COLOR = Color3.fromRGB(120, 112, 140)
local TODAY_COLOR = Color3.fromRGB(80, 220, 100)
local FUTURE_COLOR = Color3.fromRGB(255, 166, 40)

local function label(props, parent)
	props.BackgroundTransparency = 1
	props.Font = props.Font or UI.FONT
	props.TextColor3 = props.TextColor3 or WHITE
	local l = new("TextLabel", props, parent)
	if props.TextStrokeTransparency == nil then
		UI.hudStroke(l, props.TextSize and props.TextSize >= 24 and 3 or 2)
	end
	return l
end

local function tween(o, t, goal, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

local function now()
	return workspace:GetServerTimeNow()
end

-- La ilustración de un premio (las de los packs de la Shop para monedas y gemas, según la cantidad)
local function artName(r)
	if r.chest then
		return "chest"
	elseif r.kind == "coins" then
		return r.n <= 200 and "coins1" or r.n <= 500 and "coins2" or r.n <= 1000 and "coins3" or "coins4"
	elseif r.kind == "gems" then
		return r.n <= 10 and "gems1" or r.n <= 30 and "gems2" or r.n <= 60 and "gems3" or "gems4"
	elseif r.kind == "spin" then
		return "wheelart"
	elseif r.kind == "scare" then
		return r.cat == "Legendario" and "skull" or "ghost"
	end
	return "gift"
end

local function rewardColor(r)
	if r.kind == "coins" then
		return UI.GOLD
	elseif r.kind == "gems" then
		return UI.GEM
	elseif r.kind == "spin" then
		return Color3.fromRGB(255, 90, 180)
	elseif r.kind == "scare" then
		return Config.Categories[r.cat] and Config.Categories[r.cat].color or UI.PURPLE
	end
	return UI.GOLD
end

---------- Pantalla ----------
local gui = new("ScreenGui", {
	Name = "Recompensas", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 6, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui"))
local scale = new("UIScale", {}, gui)
local function rescale()
	local s = workspace.CurrentCamera.ViewportSize
	scale.Scale = math.clamp(math.min(s.X / 1180, s.Y / 800), 0.5, 1.1)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()
local dim = new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0.45, AutoButtonColor = false, Text = ""}, gui)

local function swallow(win)
	-- los clics en los huecos de la ventana no la atraviesan (si no, llegaban al fondo oscuro y la cerraban)
	new("TextButton", {Name = "Swallow", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = -3}, win)
end

---------- Ventana DAILY REWARDS ----------
local DAILY = Vector2.new(780, 470)
local daily, dailyClose = UI.window({
	Name = "Daily", Size = UDim2.fromOffset(DAILY.X, DAILY.Y), Position = UDim2.new(0.5, 0, 0.5, -20), title = "DAILY REWARDS", icon = "chest",
	accent = DAILY_ACCENT, Visible = false,
}, gui)
swallow(daily)
label({
	Position = UDim2.fromOffset(30, 50), Size = UDim2.new(1, -60, 0, 24), TextSize = 18, TextColor3 = MUTED,
	Text = "Come back every day: the rewards get bigger and bigger!",
}, daily)

local CARD = Vector2.new(150, 150)
local GAP = 14
local dayGrid = new("Frame", {Position = UDim2.fromOffset(0, 86), Size = UDim2.new(1, 0, 0, CARD.Y * 2 + GAP), BackgroundTransparency = 1}, daily)
local dayCards = {}
for i, r in R.LOGIN do
	local row = i <= 4 and 0 or 1
	local inRow = row == 0 and 4 or #R.LOGIN - 4
	local k = row == 0 and i - 1 or i - 5
	local x = (DAILY.X - (inRow * CARD.X + (inRow - 1) * GAP)) / 2 + k * (CARD.X + GAP)
	local holder = new("Frame", {
		Name = "Day" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x + CARD.X / 2, row * (CARD.Y + GAP) + CARD.Y / 2),
		Size = UDim2.fromOffset(CARD.X, CARD.Y), BackgroundTransparency = 1,
	}, dayGrid)
	local pop = new("UIScale", {}, holder)
	local card = UI.card(holder, i, FUTURE_COLOR, {Size = UDim2.fromScale(1, 1)})
	-- franja de arriba con el día
	local band = round(new("Frame", {Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = FUTURE_COLOR, ZIndex = 4}, card), 14)
	new("UIGradient", {Rotation = 90, Color = ColorSequence.new(WHITE, Color3.fromRGB(190, 180, 200))}, band)
	stroke(band, INK, 3)
	local dayText = label({Size = UDim2.fromScale(1, 1), Font = UI.TITLE, TextSize = 24, Text = ("DAY %d"):format(i), ZIndex = 5}, band)
	new("UIPadding", {PaddingTop = UDim.new(0, 4)}, dayText)
	-- el premio
	local glow = UI.piece("glow2", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.58, 0), Size = UDim2.fromOffset(130, 130), ImageColor3 = r.chest and UI.GOLD or rewardColor(r),
		ImageTransparency = 0.6, ZIndex = 4,
	}, card)
	local art = UI.art(artName(r), {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.58, 0), Size = UDim2.fromOffset(r.chest and 92 or 84, r.chest and 92 or 84), ZIndex = 5,
	}, card)
	local amount = label({
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 1, -4), Size = UDim2.fromOffset(100, 26), Font = UI.TITLE, TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Right, Text = r.chest and "???" or R.short(r), ZIndex = 6,
	}, card)
	if r.chest then
		label({
			AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -4), Size = UDim2.fromOffset(80, 22), Font = UI.TITLE, TextSize = 14,
			TextColor3 = UI.GOLD, TextXAlignment = Enum.TextXAlignment.Left, Text = "MYSTERY", ZIndex = 6,
		}, card)
	end
	-- ya cogido: oscuro y con la ✓ grande
	local shade = round(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0.45, Visible = false, ZIndex = 7}, card), 18)
	local check = UI.icon("check", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.58, 0), Size = UDim2.fromOffset(78, 78), ZIndex = 8, Visible = false}, card)
	dayCards[i] = {holder = holder, pop = pop, card = card, band = band, art = art, glow = glow, shade = shade, check = check, amount = amount}
end

-- lo que trae el cofre del día 7
do
	local parts = {}
	for _, e in R.chances(R.LOGIN[#R.LOGIN].pool) do
		table.insert(parts, ("%s %s"):format(R.text(e.r), e.pct >= 1 and ("%d%%"):format(math.floor(e.pct + 0.5)) or ("%.1f%%"):format(e.pct)))
	end
	label({
		Position = UDim2.fromOffset(30, 86 + CARD.Y * 2 + GAP + 10), Size = UDim2.new(1, -60, 0, 20), TextSize = 14, TextColor3 = MUTED,
		Text = ("Day %d Mystery Chest:  %s"):format(#R.LOGIN, table.concat(parts, "  ·  ")),
	}, daily)
end
local streakText = label({
	Position = UDim2.fromOffset(20, DAILY.Y - 84), Size = UDim2.new(1, -40, 0, 40), Font = UI.TITLE, TextSize = 34, Text = "", RichText = true,
}, daily)
new("UIPadding", {PaddingTop = UDim.new(0, 5)}, streakText)
local claimDaily = UI.button({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, 18), Size = UDim2.fromOffset(300, 72), Font = UI.TITLE, TextSize = 34,
	BackgroundColor3 = UI.BUY, Text = "CLAIM!", ZIndex = 9,
}, daily)

---------- Ventana FREE GIFTS ----------
local GIFTW = Vector2.new(640, 610)
local giftsWin, giftsClose = UI.window({
	Name = "Gifts", Size = UDim2.fromOffset(GIFTW.X, GIFTW.Y), Position = UDim2.new(0.5, 120, 0.5, 6), title = "FREE GIFTS", icon = "gift",
	accent = GIFT_ACCENT, Visible = false,
}, gui)
swallow(giftsWin)
label({
	Position = UDim2.fromOffset(30, 50), Size = UDim2.new(1, -60, 0, 24), TextSize = 18, TextColor3 = MUTED, Text = "Play to unlock free gifts! They reset every day.",
}, giftsWin)

local TILE = Vector2.new(170, 150)
local CELL_H = TILE.Y + 52
local giftGrid = new("Frame", {Position = UDim2.fromOffset(0, 88), Size = UDim2.new(1, 0, 0, CELL_H * 2 + 16), BackgroundTransparency = 1}, giftsWin)
local tiles = {}
local selectGift -- (más abajo)
for i, gift in R.GIFTS do
	local style = R.GIFT_STYLES[gift.style]
	local col, row = (i - 1) % 3, (i - 1) // 3
	local x = (GIFTW.X - (3 * TILE.X + 2 * 22)) / 2 + col * (TILE.X + 22)
	local holder = new("Frame", {
		Name = "Gift" .. i, Position = UDim2.fromOffset(x, row * (CELL_H + 16)), Size = UDim2.fromOffset(TILE.X, CELL_H), BackgroundTransparency = 1,
	}, giftGrid)
	local card = UI.card(holder, i, style.color, {Size = UDim2.fromOffset(TILE.X, TILE.Y), Class = "TextButton", Text = "", AutoButtonColor = false})
	local pop = UI.press(card, 1.04)
	local glow = UI.piece("glow2", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(150, 150), ImageColor3 = style.color, ImageTransparency = 0.55, ZIndex = 4,
	}, card)
	local box = UI.icon("gift", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(100, 100), ImageColor3 = style.color:Lerp(WHITE, 0.45), ZIndex = 5,
	}, card)
	local lock = UI.icon("lock", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.55, 0), Size = UDim2.fromOffset(58, 58), ZIndex = 7}, card)
	local count = label({
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 1, -4), Size = UDim2.fromOffset(60, 28), Font = UI.TITLE, TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Right, Text = "x" .. (gift.n or 1), ZIndex = 8,
	}, card)
	label({
		Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -50, 0, 20), Font = UI.TITLE, TextSize = 15, TextColor3 = style.color:Lerp(WHITE, 0.35),
		TextXAlignment = Enum.TextXAlignment.Left, Text = style.name:upper(), ZIndex = 8,
	}, card)
	-- lupa: qué puede tocar
	local info = new("ImageButton", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(32, 32), BackgroundTransparency = 1, Image = UI.ICONS,
		ImageRectOffset = Vector2.new(), ImageRectSize = Vector2.new(128, 128), ZIndex = 9,
	}, card)
	UI.setIcon(info, "info")
	UI.press(info, 1.15)
	local shade = round(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0.5, Visible = false, ZIndex = 8}, card), 18)
	local check = UI.icon("check", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(76, 76), ZIndex = 9, Visible = false}, card)
	-- debajo: la cuenta atrás o el botón
	local pill = round(new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, TILE.Y + 8), Size = UDim2.fromOffset(TILE.X - 10, 40), BackgroundColor3 = UI.DARK,
		BackgroundTransparency = 0.15,
	}, holder), 12)
	stroke(pill, INK, 3)
	local timer = label({Size = UDim2.fromScale(1, 1), Font = UI.TITLE, TextSize = 24, Text = "", ZIndex = 2}, pill)
	new("UIPadding", {PaddingTop = UDim.new(0, 4)}, timer)
	local claim = UI.button({
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, TILE.Y + 4), Size = UDim2.fromOffset(TILE.X - 4, 48), Font = UI.TITLE, TextSize = 24,
		BackgroundColor3 = UI.BUY, Text = "CLAIM!", Visible = false,
	}, holder)
	local function tryClaim()
		Remote:FireServer("GiftClaim", i)
	end
	claim.Activated:Connect(tryClaim)
	card.Activated:Connect(function()
		if claim.Visible then
			tryClaim()
		else
			selectGift(i)
		end
	end)
	info.Activated:Connect(function()
		selectGift(i)
	end)
	card.MouseEnter:Connect(function()
		selectGift(i)
	end)
	tiles[i] = {holder = holder, card = card, box = box, lock = lock, shade = shade, check = check, timer = timer, claim = claim, glow = glow, pill = pill, count = count, pop = pop}
end

-- abajo: cuándo se reinician
local resetBar = round(new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.new(1, -60, 0, 44), BackgroundColor3 = UI.DARK, BackgroundTransparency = 0.2,
}, giftsWin), 14)
stroke(resetBar, INK, 3)
UI.icon("clock", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(32, 32), ZIndex = 2}, resetBar)
local playedText = label({
	Position = UDim2.fromOffset(50, 0), Size = UDim2.new(0.5, -50, 1, 0), TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Text = "", ZIndex = 2,
}, resetBar)
local resetText = label({
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 0), Size = UDim2.new(0.5, -14, 1, 0), TextSize = 18, TextColor3 = MUTED,
	TextXAlignment = Enum.TextXAlignment.Right, Text = "", ZIndex = 2, RichText = true,
}, resetBar)

-- Panel de la izquierda: qué puede tocar en el regalo elegido
local infoPanel = round(new("Frame", {
	Name = "Info", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(0, -18, 0, 40), Size = UDim2.fromOffset(250, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Color3.fromRGB(30, 20, 50), BackgroundTransparency = 0.08,
}, giftsWin), 18)
stroke(infoPanel, INK, 4)
local infoStroke = new("UIStroke", {Color = GIFT_ACCENT, Thickness = 2, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, round(new("Frame", {
	Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), BackgroundTransparency = 1,
}, infoPanel), 14))
new("UIPadding", {PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 14)}, infoPanel)
new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center}, infoPanel)
label({Size = UDim2.new(1, 0, 0, 26), Font = UI.TITLE, TextSize = 22, Text = "REWARD INFO", LayoutOrder = 1}, infoPanel)
local infoName = label({Size = UDim2.new(1, 0, 0, 22), TextSize = 17, Text = "", LayoutOrder = 2}, infoPanel)
local infoList = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 3}, infoPanel)
new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, infoList)
local selected = 1
function selectGift(i)
	if selected == i and #infoList:GetChildren() > 1 then
		return
	end
	selected = i
	local gift = R.GIFTS[i]
	local style = R.GIFT_STYLES[gift.style]
	infoName.Text = ("%s  ·  %s"):format(style.name, gift.n and gift.n > 1 and ("x%d"):format(gift.n) or "x1")
	infoName.TextColor3 = style.color:Lerp(WHITE, 0.3)
	infoStroke.Color = style.color
	for _, c in infoList:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for k, e in R.chances(gift.pool) do
		local row = round(new("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = BLACK, BackgroundTransparency = 0.6, LayoutOrder = k}, infoList), 10)
		UI.art(artName(e.r), {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4, 0.5, 0), Size = UDim2.fromOffset(34, 34), ZIndex = 2}, row)
		label({
			Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -100, 1, 0), TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
			Text = R.text(e.r), ZIndex = 2,
		}, row)
		label({
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = UDim2.fromOffset(56, 40), Font = UI.TITLE, TextSize = 18,
			TextColor3 = rewardColor(e.r):Lerp(WHITE, 0.25), TextXAlignment = Enum.TextXAlignment.Right,
			Text = e.pct >= 1 and ("%d%%"):format(math.floor(e.pct + 0.5)) or ("%.1f%%"):format(e.pct), ZIndex = 2,
		}, row)
	end
end
selectGift(1)

---------- Pantalla del premio ----------
local reveal = new("TextButton", {
	Name = "Reveal", Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0.35, AutoButtonColor = false, Text = "", Visible = false, ZIndex = 50,
}, gui)
local rays = UI.piece("rays", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(620, 620), ImageColor3 = UI.GOLD, ImageTransparency = 0.35, ZIndex = 51,
}, reveal)
local revealTitle = label({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.12, 0), Size = UDim2.fromOffset(800, 64), Font = UI.TITLE, TextSize = 56, Text = "", ZIndex = 53,
}, reveal)
local revealItems = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47), Size = UDim2.fromOffset(0, 270), AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1, ZIndex = 52,
}, reveal)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 30), SortOrder = Enum.SortOrder.LayoutOrder,
}, revealItems)
local revealHint = label({
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.88, 0), Size = UDim2.fromOffset(500, 26), TextSize = 18, TextColor3 = MUTED,
	Text = "Tap anywhere to continue", ZIndex = 53,
}, reveal)
local revealPop = new("UIScale", {}, revealItems)
local revealToken = 0
local function hideReveal()
	revealToken += 1
	reveal.Visible = false
end
reveal.Activated:Connect(hideReveal)
RunService.RenderStepped:Connect(function(dt)
	if reveal.Visible then
		rays.Rotation = (rays.Rotation + dt * 25) % 360
	end
end)

-- list: lo que ha tocado ({kind, n, cat, scare, new}, lo manda el servidor)
local function showReveal(title, list)
	revealToken += 1
	local token = revealToken
	for _, c in revealItems:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local best = UI.GOLD
	for k, got in list do
		local def = got.scare and Config.Scares[got.scare]
		local color = rewardColor(got)
		best = color
		local item = new("Frame", {Size = UDim2.fromOffset(230, 270), BackgroundTransparency = 1, LayoutOrder = k, ZIndex = 52}, revealItems)
		UI.piece("glow2", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 100), Size = UDim2.fromOffset(260, 260), ImageColor3 = color, ImageTransparency = 0.25, ZIndex = 52,
		}, item)
		if def then
			UI.viewport(got.scare, item, {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 100), Size = UDim2.fromOffset(200, 200), ZIndex = 53,
			})
		else
			UI.art(artName(got), {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 100), Size = UDim2.fromOffset(170, 170), ZIndex = 53}, item)
		end
		local text = def and def.name or ("+" .. R.text(got))
		label({
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 206), Size = UDim2.fromOffset(300, 34), Font = UI.TITLE, TextSize = 30,
			TextColor3 = color:Lerp(WHITE, 0.2), Text = text, ZIndex = 54,
		}, item)
		if def then
			local cat = Config.Categories[def.cat]
			label({
				AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 240), Size = UDim2.fromOffset(300, 24), TextSize = 17, TextColor3 = MUTED,
				Text = ("%s%s scare  ·  in your bag"):format(got.new and "NEW!  " or "", cat and cat.name or ""), ZIndex = 54,
			}, item)
		end
	end
	revealTitle.Text = title
	rays.ImageColor3 = best
	revealHint.Visible = false
	reveal.Visible = true
	revealPop.Scale = 0.3
	tween(revealPop, 0.45, {Scale = 1}, Enum.EasingStyle.Back)
	revealTitle.TextTransparency = 1
	tween(revealTitle, 0.3, {TextTransparency = 0})
	UI.sound("Win")
	UI.sound("Sparkle")
	UI.flash(best, 0.4, 0.8)
	UI.confetti(90)
	for _, got in list do
		if got.kind == "coins" then
			UI.sound("CoinTransfer")
			local vs = workspace.CurrentCamera.ViewportSize
			UI.coinFly(Vector2.new(vs.X / 2, vs.Y * 0.47), 12)
		end
	end
	task.delay(1, function()
		if revealToken == token then
			revealHint.Visible = true
		end
	end)
	task.delay(4.5, function()
		if revealToken == token then
			hideReveal()
		end
	end)
end

---------- Estado ----------
local function loginNow()
	return R.loginState(player:GetAttribute("LoginDay"), player:GetAttribute("LoginStreak"), R.today(now()))
end

-- jugado hoy y regalos ya abiertos (si el servidor aún no ha cambiado de día, se adelanta el cliente)
local function giftsNow()
	local t = now()
	local today = R.today(t)
	local claimed = {}
	local played
	if player:GetAttribute("GiftDay") == today then
		played = t - (player:GetAttribute("GiftStart") or t)
		for s in string.gmatch(player:GetAttribute("GiftClaimed") or "", "%d+") do
			claimed[tonumber(s)] = true
		end
	else
		played = math.min(t - today * R.DAY, t - (player:GetAttribute("GiftStart") or t))
	end
	return math.max(0, played), claimed, (today + 1) * R.DAY - t
end

local function giftsReady()
	local played, claimed = giftsNow()
	local n = 0
	for i, g in R.GIFTS do
		if not claimed[i] and played >= g.t then
			n += 1
		end
	end
	return n
end

local pulse = {} -- [UIScale] = true: latiendo
task.spawn(function()
	while true do
		local s = 1 + math.sin(os.clock() * 5) * 0.04
		for p in pulse do
			p.Scale = s
		end
		task.wait()
	end
end)
local function setPulse(p, on)
	if on then
		pulse[p] = true
	elseif pulse[p] then
		pulse[p] = nil
		p.Scale = 1
	end
end

local function refreshDaily()
	local can, streak, idx = loginNow()
	for i, c in dayCards do
		local taken = i < idx or (i == idx and not can)
		local today = i == idx and can
		local color = taken and CLAIMED_COLOR or today and TODAY_COLOR or FUTURE_COLOR
		UI.tintCard(c.card, color)
		c.band.BackgroundColor3 = color
		c.shade.Visible = taken
		c.check.Visible = taken
		c.art.ImageTransparency = taken and 0.35 or 0
		c.glow.Visible = not taken
		c.amount.TextTransparency = taken and 0.4 or 0
		setPulse(c.pop, today)
	end
	local tut = (player:GetAttribute("Tut") or 0) >= 4
	if can then
		streakText.Text = streak > 1 and ("🔥 %d day streak! Claim day %d"):format(streak, idx) or ("Claim your day %d reward!"):format(idx)
		claimDaily.Text = tut and "CLAIM!" or "FINISH THE TUTORIAL"
		claimDaily.BackgroundColor3 = tut and UI.BUY or UI.CANT
	else
		streakText.Text = ("🔥 %d day streak!"):format(math.max(streak, 1))
		local left = (R.today(now()) + 1) * R.DAY - now()
		claimDaily.Text = ("NEXT IN %s"):format(R.clock(left))
		claimDaily.BackgroundColor3 = UI.CANT
	end
end

local function refreshGifts()
	local played, claimed, resetIn = giftsNow()
	for i, g in R.GIFTS do
		local t = tiles[i]
		local done = claimed[i]
		local ready = not done and played >= g.t
		t.lock.Visible = not done and not ready
		t.shade.Visible = done
		t.check.Visible = done
		t.box.ImageTransparency = done and 0.4 or 0
		t.glow.ImageTransparency = ready and 0.25 or 0.65
		t.claim.Visible = ready
		t.pill.Visible = not ready
		if done then
			t.timer.Text = "CLAIMED"
			t.timer.TextColor3 = MUTED
		else
			t.timer.Text = R.clock(g.t - played)
			t.timer.TextColor3 = WHITE
		end
		setPulse(t.pop, ready)
	end
	playedText.Text = ("Played today: %s"):format(R.clock(math.min(played, 24 * 3600)))
	resetText.Text = ("Resets in <font color=\"#FFD446\">%s</font>"):format(R.clock(resetIn))
end

---------- Abrir y cerrar ----------
local function anyOpen()
	return daily.Visible or giftsWin.Visible
end
local function show(win, open)
	if open == win.Visible then
		return
	end
	if open then
		if UI.closeCatalogs then
			UI.closeCatalogs()
		end
		daily.Visible = win == daily
		giftsWin.Visible = win == giftsWin
		UI.popIn(win, 0.85)
		if win == daily then
			refreshDaily()
		else
			refreshGifts()
		end
	else
		win.Visible = false
	end
	gui.Enabled = anyOpen() or reveal.Visible
	UI.sound(open and "Open" or "Close")
end
local function toggleDaily(open)
	if open == nil then
		open = not daily.Visible
	end
	show(daily, open)
end
local function toggleGifts(open)
	if open == nil then
		open = not giftsWin.Visible
	end
	show(giftsWin, open)
end
UI.toggleDaily, UI.toggleGifts = toggleDaily, toggleGifts
dailyClose.Activated:Connect(function()
	toggleDaily(false)
end)
giftsClose.Activated:Connect(function()
	toggleGifts(false)
end)
dim.Activated:Connect(function()
	show(daily, false)
	show(giftsWin, false)
end)
reveal:GetPropertyChangedSignal("Visible"):Connect(function()
	gui.Enabled = anyOpen() or reveal.Visible
	dim.Visible = anyOpen()
end)
gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	dim.Visible = anyOpen()
end)

claimDaily.Activated:Connect(function()
	local can = loginNow()
	if not can then
		UI.toast("Come back tomorrow for your next reward!", UI.ORANGE, "clock")
		return
	end
	if (player:GetAttribute("Tut") or 0) < 4 then
		UI.toast("Finish the tutorial first!", UI.ORANGE, "info")
		return
	end
	Remote:FireServer("LoginClaim")
end)

---------- Botones del menú (con aviso rojo) ----------
local dailyButton = UI.menuButton(11, "chest", "Daily", DAILY_ACCENT)
local dailyBadge = UI.addBadge(dailyButton)
dailyButton.Activated:Connect(function()
	toggleDaily()
end)
local giftsButton = UI.menuButton(12, "gift", "Gifts", GIFT_ACCENT)
local giftsBadge = UI.addBadge(giftsButton)
giftsButton.Activated:Connect(function()
	toggleGifts()
end)

local lastReady = 0
local function refreshBadges()
	if player:GetAttribute("LoginDay") == nil then
		return -- (aún no ha cargado su partida)
	end
	local can = loginNow()
	dailyBadge.Visible = can
	dailyBadge.Count.Text = "!"
	local n = giftsReady()
	giftsBadge.Visible = n > 0
	giftsBadge.Count.Text = tostring(n)
	-- un regalo nuevo listo: aviso (si no está la ventana abierta)
	if n > lastReady and not giftsWin.Visible and (player:GetAttribute("Tut") or 0) >= 4 then
		UI.toast("A free gift is ready! 🎁", GIFT_ACCENT, "gift")
		UI.sound("Jingle")
		local s = giftsBadge:FindFirstChildOfClass("UIScale")
		if s then
			s.Scale = 1.6
			tween(s, 0.4, {Scale = 1}, Enum.EasingStyle.Back)
		end
	end
	lastReady = n
end

-- cuenta atrás y avisos
task.spawn(function()
	while true do
		if daily.Visible then
			refreshDaily()
		end
		if giftsWin.Visible then
			refreshGifts()
		end
		refreshBadges()
		task.wait(0.25)
	end
end)
for _, attr in {"LoginDay", "LoginStreak", "GiftDay", "GiftStart", "GiftClaimed", "Tut"} do
	player:GetAttributeChangedSignal(attr):Connect(function()
		if daily.Visible then
			refreshDaily()
		end
		if giftsWin.Visible then
			refreshGifts()
		end
	end)
end

-- se cierran al ir de visita o al Tower Defense
local function autoClose()
	if anyOpen() and (player:GetAttribute("Mode") == "visit" or player:GetAttribute("TDCash") ~= nil) then
		show(daily, false)
		show(giftsWin, false)
	end
end
player:GetAttributeChangedSignal("Mode"):Connect(autoClose)
player:GetAttributeChangedSignal("TDCash"):Connect(autoClose)

---------- Respuestas del servidor ----------
Remote.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "LoginClaimed" then
		-- a = casilla, b = racha, c = lo que ha tocado
		local card = dayCards[a]
		if card then
			card.pop.Scale = 1.3
			tween(card.pop, 0.4, {Scale = 1}, Enum.EasingStyle.Back)
		end
		refreshDaily()
		task.delay(0.35, function()
			showReveal(("DAY %d REWARD!"):format(a), {c})
		end)
	elseif kind == "GiftClaimed" then
		-- a = regalo, b = lista de lo que ha tocado
		local t = tiles[a]
		if t then
			t.pop.Scale = 1.3
			tween(t.pop, 0.4, {Scale = 1}, Enum.EasingStyle.Back)
		end
		refreshGifts()
		local style = R.GIFT_STYLES[R.GIFTS[a] and R.GIFTS[a].style or "small"]
		task.delay(0.25, function()
			showReveal(("%s!"):format(style.name:upper()), b or {})
		end)
	end
end)

---------- Se abre sola al entrar si hoy aún no has cogido el premio ----------
task.spawn(function()
	repeat
		task.wait(0.5)
	until not Portada.active and UI.gui.Enabled and player:GetAttribute("LoginDay") ~= nil
	task.wait(2.5)
	local can = loginNow()
	if can and (player:GetAttribute("Tut") or 0) >= 4 and not player:GetAttribute("Mode") and player:GetAttribute("TDCash") == nil and not UI.menuOpen() then
		toggleDaily(true)
	end
end)
