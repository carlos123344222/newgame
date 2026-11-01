-- Recompensas (cliente). Dos ventanas y dos botones pequeños arriba a la derecha (como las barras de iconos de los
-- juegos de defensa: cuadrados azulados con el nombre debajo):
--  * Botón del regalo (rojo): cuenta atrás hasta el siguiente regalo ("04:59"), "Claim!" con un número rojo cuando
--    hay alguno listo. Abre FREE GIFTS.
--  * Botón del calendario (con el día de hoy): "Daily", con "!" rojo si hoy aún no has cogido el premio. Abre DAILY
--    REWARDS (también se abre sola al entrar si no lo has cogido).
--  * DAILY REWARDS: panel oscuro con borde claro, cabecera translúcida (calendario, título y "las recompensas suben
--    con tu racha"), los días 1-5 arriba y 6-7 abajo (pestaña de color con el día: gris ya cogido, verde hoy,
--    amarillo por llegar; el premio y la cantidad; ✓ verde en los cogidos; el de hoy con borde blanco), "Streak of N
--    days!" y debajo del panel el botón CLAIM (verde) o CLOSE (gris).
--  * FREE GIFTS: panel oscuro translúcido con título, subtítulo y la X roja; 3×2 regalos (azul, verde, dorado) con
--    candado, lupa y "x1/x2", y debajo de cada uno su cuenta atrás o CLAIM; abajo cuándo se reinician, cuántos llevas y
--    CLAIM ALL. A la izquierda, el panel "Reward Info" con lo que puede tocar en el regalo elegido.
--  * Al coger algo, la pantalla del premio (rayos, el premio en grande, confeti). Cuando se abre un regalo nuevo, un
--    aviso en el centro de arriba.
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
local playerGui = player:WaitForChild("PlayerGui")
local new = UI.new

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local MUTED = Color3.fromRGB(205, 205, 215)
local GREEN = Color3.fromRGB(86, 214, 92)
local RED = Color3.fromRGB(232, 52, 60)
local CLAIMED_TAB = Color3.fromRGB(150, 150, 158)
local TODAY_TAB = Color3.fromRGB(96, 226, 96)
local FUTURE_TAB = Color3.fromRGB(255, 176, 16)
local GIFT_COLORS = {small = Color3.fromRGB(70, 110, 220), big = Color3.fromRGB(70, 170, 70), epic = Color3.fromRGB(214, 160, 40)}
local RIBBON = Color3.fromRGB(226, 230, 238)

local HEAVY = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local BOLD = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)

---------- Piezas ----------
local function corner(o, r)
	new("UICorner", {CornerRadius = typeof(r) == "UDim" and r or UDim.new(0, r or 8)}, o)
	return o
end
local function outline(o, color, t, transparency)
	return new("UIStroke", {Color = color, Thickness = t or 2, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, o)
end
local function vgrad(o, top, bottom)
	return new("UIGradient", {Rotation = 90, Color = ColorSequence.new(top, bottom)}, o)
end

-- Texto blanco grueso con contorno negro (props.heavy = false: Bold en vez de Heavy)
local function text(props, parent)
	local heavy = props.heavy ~= false
	props.heavy = nil
	local strokeT = props.strokeT
	props.strokeT = nil
	props.BackgroundTransparency = 1
	props.FontFace = heavy and HEAVY or BOLD
	props.TextColor3 = props.TextColor3 or WHITE
	local l = new("TextLabel", props, parent)
	new("UIStroke", {
		Color = BLACK, Thickness = strokeT or math.clamp((props.TextSize or 14) / 9, 1, 3.2), LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	}, l)
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

-- Un regalo dibujado (caja, tapa, cinta y lazo) que llena 'parent' (cuadrado). Devuelve el marco (para moverlo).
local function drawGift(parent, color, z, ribbon)
	z = z or 2
	ribbon = ribbon or RIBBON
	local g = new("Frame", {Name = "Gift", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = z}, parent)
	local body = corner(new("Frame", {Position = UDim2.fromScale(0.15, 0.44), Size = UDim2.fromScale(0.7, 0.48), BackgroundColor3 = WHITE, ZIndex = z}, g), UDim.new(0.1, 0))
	vgrad(body, color:Lerp(WHITE, 0.15), color:Lerp(BLACK, 0.35))
	outline(body, BLACK, 1.5, 0.35)
	local lid = corner(new("Frame", {Position = UDim2.fromScale(0.09, 0.31), Size = UDim2.fromScale(0.82, 0.17), BackgroundColor3 = WHITE, ZIndex = z + 1}, g), UDim.new(0.18, 0))
	vgrad(lid, color:Lerp(WHITE, 0.35), color:Lerp(BLACK, 0.1))
	outline(lid, BLACK, 1.5, 0.35)
	local band = new("Frame", {Position = UDim2.fromScale(0.43, 0.31), Size = UDim2.fromScale(0.14, 0.61), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = z + 2}, g)
	vgrad(band, ribbon, ribbon:Lerp(BLACK, 0.3))
	for _, side in {-1, 1} do
		local loop = corner(new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5 + side * 0.13, 0.24), Size = UDim2.fromScale(0.26, 0.15), Rotation = side * -24,
			BackgroundColor3 = WHITE, ZIndex = z + 3,
		}, g), UDim.new(0.5, 0))
		vgrad(loop, ribbon, ribbon:Lerp(BLACK, 0.25))
		outline(loop, BLACK, 1.2, 0.4)
	end
	local knot = corner(new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.29), Size = UDim2.fromScale(0.13, 0.12), BackgroundColor3 = ribbon, ZIndex = z + 4,
	}, g), UDim.new(0.5, 0))
	outline(knot, BLACK, 1.2, 0.4)
	return g
end

-- Calendario (anillas, cabecera roja y el día del mes)
local function drawCalendar(parent, z)
	z = z or 2
	local c = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Rotation = -7, ZIndex = z}, parent)
	local page = corner(new("Frame", {Position = UDim2.fromScale(0.12, 0.18), Size = UDim2.fromScale(0.76, 0.72), BackgroundColor3 = WHITE, ZIndex = z}, c), UDim.new(0.12, 0))
	vgrad(page, WHITE, Color3.fromRGB(214, 214, 222))
	outline(page, BLACK, 1.6, 0.2)
	local head = corner(new("Frame", {Position = UDim2.fromScale(0.12, 0.18), Size = UDim2.fromScale(0.76, 0.24), BackgroundColor3 = WHITE, ZIndex = z + 1}, c), UDim.new(0.3, 0))
	vgrad(head, Color3.fromRGB(255, 90, 90), Color3.fromRGB(200, 30, 40))
	new("Frame", {Position = UDim2.fromScale(0.12, 0.3), Size = UDim2.fromScale(0.76, 0.12), BackgroundColor3 = Color3.fromRGB(205, 34, 44), BorderSizePixel = 0, ZIndex = z + 1}, c)
	for _, x in {0.32, 0.68} do
		local ring = corner(new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.2), Size = UDim2.fromScale(0.09, 0.2), BackgroundColor3 = Color3.fromRGB(70, 70, 80), ZIndex = z + 2,
		}, c), UDim.new(0.5, 0))
		outline(ring, BLACK, 1, 0.3)
	end
	local day = new("TextLabel", {
		Position = UDim2.fromScale(0.12, 0.42), Size = UDim2.fromScale(0.76, 0.46), BackgroundTransparency = 1, FontFace = HEAVY, TextScaled = true,
		TextColor3 = Color3.fromRGB(40, 36, 52), Text = tostring(os.date("*t").day), ZIndex = z + 2,
	}, c)
	return c, day
end

-- Lupa
local function drawMagnifier(parent, z)
	local m = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = z}, parent)
	local lens = corner(new("Frame", {Position = UDim2.fromScale(0.28, 0.06), Size = UDim2.fromScale(0.62, 0.62), BackgroundColor3 = WHITE, BackgroundTransparency = 0.85, ZIndex = z}, m), UDim.new(0.5, 0))
	outline(lens, WHITE, 2.2)
	local handle = corner(new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.25, 0.75), Size = UDim2.fromScale(0.42, 0.14), Rotation = -45, BackgroundColor3 = WHITE, ZIndex = z,
	}, m), UDim.new(0.5, 0))
	return m, lens, handle
end

-- La X blanca de cerrar (dos barras)
local function drawX(parent, z)
	for _, r in {45, -45} do
		corner(new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.15), Rotation = r, BackgroundColor3 = WHITE, ZIndex = z,
		}, parent), UDim.new(0.5, 0))
	end
end

-- La ilustración de un premio
local function rewardArt(r, parent, props)
	if r.chest then
		props.ImageColor3 = Color3.fromRGB(255, 225, 140)
		return UI.icon("chest", props, parent)
	elseif r.kind == "coins" then
		return UI.art(r.n <= 200 and "coins1" or r.n <= 500 and "coins2" or r.n <= 1000 and "coins3" or "coins4", props, parent)
	elseif r.kind == "gems" then
		return UI.art(r.n <= 10 and "gems1" or r.n <= 30 and "gems2" or r.n <= 60 and "gems3" or "gems4", props, parent)
	elseif r.kind == "spin" then
		return UI.art("wheelart", props, parent)
	elseif r.kind == "scare" then
		return UI.icon(r.cat == "Legendario" and "skull" or "ghost", props, parent)
	end
	return UI.icon("gift", props, parent)
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

-- "150x Coins", "1x Free Spin", "1x Creature Scare"
local function infoLine(r)
	if r.kind == "coins" then
		return ("%sx Coins"):format(R.fmt(r.n))
	elseif r.kind == "gems" then
		return ("%sx Gems"):format(R.fmt(r.n))
	elseif r.kind == "spin" then
		return ("%dx Free Spin%s"):format(r.n, r.n == 1 and "" or "s")
	end
	return "1x " .. R.text(r)
end

local function pct(p)
	return p >= 1 and ("%d%%"):format(math.floor(p + 0.5)) or ("%.1f%%"):format(p)
end

-- Botón grande de abajo (CLAIM / CLOSE): degradado, borde blanco y letras grandes con contorno
local function bigButton(props, parent)
	local b = new("TextButton", {
		AnchorPoint = props.AnchorPoint, Position = props.Position, Size = props.Size, BackgroundColor3 = WHITE, AutoButtonColor = false, Text = "",
		ZIndex = props.ZIndex or 5,
	}, parent)
	corner(b, 6)
	local grad = vgrad(b, GREEN:Lerp(WHITE, 0.2), GREEN:Lerp(BLACK, 0.25))
	outline(b, WHITE, 3, 0.05)
	local shine = corner(new("Frame", {Position = UDim2.fromOffset(4, 3), Size = UDim2.new(1, -8, 0.42, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 0.82, BorderSizePixel = 0, ZIndex = b.ZIndex}, b), 4)
	local l = text({Size = UDim2.fromScale(1, 1), TextSize = props.TextSize or 26, Text = props.Text or "", ZIndex = b.ZIndex + 1}, b)
	local pop = UI.press(b, 1.04)
	local function paint(color)
		grad.Color = ColorSequence.new(color:Lerp(WHITE, 0.2), color:Lerp(BLACK, 0.28))
	end
	return b, l, paint, pop, shine
end

---------- Pantalla de las ventanas ----------
local gui = new("ScreenGui", {
	Name = "Recompensas", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 6, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
local scale = new("UIScale", {}, gui)
local function rescale()
	local s = workspace.CurrentCamera.ViewportSize
	scale.Scale = math.clamp(math.min(s.X / 1100, s.Y / 720), 0.5, 1.35)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()
local dim = new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0.55, AutoButtonColor = false, Text = ""}, gui)

local function swallow(win)
	new("TextButton", {Name = "Swallow", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 0}, win)
end

---------- DAILY REWARDS ----------
local DAILY = Vector2.new(640, 380)
local daily = new("Frame", {
	Name = "Daily", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -26), Size = UDim2.fromOffset(DAILY.X, DAILY.Y),
	BackgroundColor3 = WHITE, Visible = false, Active = true,
}, gui)
table.insert(UI.modals, daily)
corner(daily, 10)
vgrad(daily, Color3.fromRGB(64, 58, 72), Color3.fromRGB(26, 22, 32))
outline(daily, Color3.fromRGB(228, 228, 234), 3)
swallow(daily)
-- fondo: montones de monedas y cofres oscurecidos, como una escena del tesoro detrás
local scene = corner(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 1}, daily), 10)
for _, d in {
	{"coins5", UDim2.new(0, -40, 1, -150), 230, -12}, {"coins4", UDim2.new(1, -190, 1, -150), 220, 10}, {"coins3", UDim2.new(0.5, -90, 1, -95), 180, 0},
	{"gems3", UDim2.new(1, -110, 0, 70), 110, 18}, {"coins2", UDim2.new(0, -20, 0, 80), 120, -20},
} do
	UI.art(d[1], {Position = d[2], Size = UDim2.fromOffset(d[3], d[3]), Rotation = d[4], ImageColor3 = Color3.fromRGB(110, 100, 112), ImageTransparency = 0.35, ZIndex = 1}, scene)
end
UI.icon("chest", {Position = UDim2.new(1, -150, 1, -128), Size = UDim2.fromOffset(150, 150), Rotation = 8, ImageColor3 = Color3.fromRGB(90, 90, 110), ImageTransparency = 0.3, ZIndex = 1}, scene)
local shadeScene = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 1}, scene)
new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.6, 0.45), NumberSequenceKeypoint.new(1, 0.15),
})}, shadeScene)
-- cabecera translúcida
local header = corner(new("Frame", {Size = UDim2.new(1, 0, 0, 66), BackgroundColor3 = WHITE, BackgroundTransparency = 0.8, ZIndex = 2}, daily), 10)
new("Frame", {Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = WHITE, BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = 2}, header)
local calHolder = new("Frame", {Position = UDim2.fromOffset(10, 2), Size = UDim2.fromOffset(62, 62), BackgroundTransparency = 1, ZIndex = 3}, header)
drawCalendar(calHolder, 3)
text({Position = UDim2.fromOffset(78, 4), Size = UDim2.fromOffset(250, 58), TextSize = 24, TextWrapped = true, LineHeight = 0.9, Text = "Daily\nRewards", ZIndex = 4}, header)
text({
	Position = UDim2.fromOffset(340, 6), Size = UDim2.fromOffset(286, 54), TextSize = 14, heavy = false, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Rewards get bigger with your login streak!", ZIndex = 4,
}, header)

-- casillas
local CARD = Vector2.new(92, 102)
local TAB_H = 30
local dayCards = {}
local tooltip -- (más abajo)
for i, r in R.LOGIN do
	local top = i <= 5
	local n = top and 5 or #R.LOGIN - 5
	local k = top and i - 1 or i - 6
	local x = (DAILY.X - (n * CARD.X + (n - 1) * 18)) / 2 + k * (CARD.X + 18)
	local y = top and 80 or 80 + CARD.Y + 18
	local card = new("TextButton", {
		Name = "Day" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x + CARD.X / 2, y + CARD.Y / 2), Size = UDim2.fromOffset(CARD.X, CARD.Y),
		BackgroundColor3 = WHITE, AutoButtonColor = false, Text = "", ZIndex = 3,
	}, daily)
	corner(card, 4)
	vgrad(card, Color3.fromRGB(62, 62, 70), Color3.fromRGB(22, 22, 28))
	local border = outline(card, FUTURE_TAB, 2.5)
	local pop = new("UIScale", {}, card)
	local tab = corner(new("Frame", {Size = UDim2.new(1, 0, 0, TAB_H), BackgroundColor3 = WHITE, ZIndex = 4}, card), 4)
	local tabGrad = vgrad(tab, FUTURE_TAB:Lerp(WHITE, 0.15), FUTURE_TAB:Lerp(BLACK, 0.12))
	text({Size = UDim2.fromScale(1, 1), TextSize = 19, Text = ("Day %d"):format(i), ZIndex = 5}, tab)
	local glow = UI.piece("glow2", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, TAB_H + (CARD.Y - TAB_H) / 2), Size = UDim2.fromOffset(90, 90),
		ImageColor3 = r.chest and UI.GOLD or rewardColor(r), ImageTransparency = 0.7, ZIndex = 4,
	}, card)
	local art = rewardArt(r, card, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, TAB_H + (CARD.Y - TAB_H) / 2), Size = UDim2.fromOffset(r.chest and 66 or 60, r.chest and 66 or 60),
		ZIndex = 5,
	})
	local amount = text({
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, -2), Size = UDim2.fromOffset(70, 18), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right,
		Text = r.chest and "" or R.short(r), ZIndex = 7,
	}, card)
	local check = UI.icon("check", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 4, 0, TAB_H + (CARD.Y - TAB_H) / 2 + 2), Size = UDim2.fromOffset(52, 52), ZIndex = 8, Visible = false,
	}, card)
	card.MouseEnter:Connect(function()
		if tooltip then
			tooltip(i, card)
		end
	end)
	card.MouseLeave:Connect(function()
		if tooltip then
			tooltip(nil)
		end
	end)
	dayCards[i] = {card = card, border = border, pop = pop, tabGrad = tabGrad, art = art, glow = glow, check = check, amount = amount}
end

local streakText = text({
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -40, 0, 40), TextSize = 30, Text = "", ZIndex = 4,
}, daily)
local dailyButton, dailyButtonText, paintDailyButton = bigButton({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 16), Size = UDim2.fromOffset(196, 54), TextSize = 26, Text = "CLAIM", ZIndex = 5,
}, daily)

-- Al pasar el ratón por una casilla: qué es (el cofre del día 7 dice qué puede traer)
local tip = corner(new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(220, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.fromRGB(18, 16, 24),
	BackgroundTransparency = 0.05, Visible = false, ZIndex = 20,
}, daily), 8)
outline(tip, WHITE, 2, 0.3)
new("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8)}, tip)
new("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, tip)
local tipLines = {}
function tooltip(i, card)
	if not i then
		tip.Visible = false
		return
	end
	for _, l in tipLines do
		l:Destroy()
	end
	table.clear(tipLines)
	local r = R.LOGIN[i]
	local lines = {}
	if r.pool then
		table.insert(lines, {"Mystery Chest", 16, UI.GOLD})
		for _, e in R.chances(r.pool) do
			table.insert(lines, {("%s (%s)"):format(infoLine(e.r), pct(e.pct)), 13, WHITE})
		end
	else
		table.insert(lines, {("Day %d"):format(i), 16, UI.GOLD})
		table.insert(lines, {R.text(r), 14, WHITE})
	end
	for k, l in lines do
		table.insert(tipLines, text({
			Size = UDim2.new(1, 0, 0, l[2] + 4), TextSize = l[2], TextColor3 = l[3], heavy = k == 1, Text = l[1], LayoutOrder = k, ZIndex = 21,
		}, tip))
	end
	tip.Position = UDim2.fromOffset(card.Position.X.Offset, card.Position.Y.Offset - CARD.Y / 2 - 6)
	tip.Visible = true
end

---------- FREE GIFTS ----------
local GW = Vector2.new(440, 556)
local gifts = new("Frame", {
	Name = "Gifts", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 110, 0.5, 0), Size = UDim2.fromOffset(GW.X, GW.Y), BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.12, Visible = false, Active = true,
}, gui)
table.insert(UI.modals, gifts)
corner(gifts, 10)
vgrad(gifts, Color3.fromRGB(44, 42, 50), Color3.fromRGB(14, 13, 18))
outline(gifts, WHITE, 2.5, 0.15)
swallow(gifts)
text({Position = UDim2.fromOffset(18, 10), Size = UDim2.fromOffset(340, 44), TextSize = 32, TextXAlignment = Enum.TextXAlignment.Left, Text = "Free Gifts", ZIndex = 3}, gifts)
text({Position = UDim2.fromOffset(18, 52), Size = UDim2.fromOffset(340, 24), TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, Text = "Earn rewards by playing!", ZIndex = 3}, gifts)
local giftsClose = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.fromOffset(46, 46), BackgroundColor3 = WHITE, AutoButtonColor = false, Text = "", ZIndex = 4,
}, gifts)
corner(giftsClose, 6)
vgrad(giftsClose, Color3.fromRGB(255, 92, 92), Color3.fromRGB(196, 24, 36))
outline(giftsClose, Color3.fromRGB(90, 10, 16), 2)
drawX(giftsClose, 5)
UI.press(giftsClose, 1.08)
new("Frame", {Position = UDim2.fromOffset(18, 86), Size = UDim2.new(1, -36, 0, 2), BackgroundColor3 = WHITE, BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 3}, gifts)

local TILE = 118
local tiles = {}
local selectGift -- (más abajo)
for i, gift in R.GIFTS do
	local col, row = (i - 1) % 3, (i - 1) // 3
	local x = (GW.X - (3 * TILE + 2 * 14)) / 2 + col * (TILE + 14)
	local y = 102 + row * (TILE + 54)
	local color = GIFT_COLORS[gift.style]
	local tile = new("TextButton", {
		Name = "Gift" .. i, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(TILE, TILE), BackgroundColor3 = WHITE, AutoButtonColor = false, Text = "", ZIndex = 3,
	}, gifts)
	corner(tile, 8)
	vgrad(tile, Color3.fromRGB(52, 52, 60), Color3.fromRGB(12, 12, 16))
	local border = outline(tile, Color3.fromRGB(96, 96, 108), 2)
	local pop = UI.press(tile, 1.04)
	local glow = UI.piece("glow2", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(120, 120), ImageColor3 = color, ImageTransparency = 1, ZIndex = 3,
	}, tile)
	local giftHolder = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromOffset(84, 84), BackgroundTransparency = 1, ZIndex = 4}, tile)
	local art = drawGift(giftHolder, color, 4)
	local lock = UI.icon("lock", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.fromOffset(52, 52), ZIndex = 12}, tile)
	text({
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 1, -3), Size = UDim2.fromOffset(40, 24), TextSize = 20, TextColor3 = Color3.fromRGB(196, 196, 204),
		TextXAlignment = Enum.TextXAlignment.Right, Text = "x" .. (gift.n or 1), ZIndex = 13,
	}, tile)
	local lupa = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -5, 0, 5), Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 1, Text = "", ZIndex = 13,
	}, tile)
	drawMagnifier(lupa, 13)
	UI.press(lupa, 1.2)
	local dark = corner(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0.45, Visible = false, ZIndex = 11}, tile), 8)
	local check = UI.icon("check", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(64, 64), ZIndex = 12, Visible = false}, tile)
	-- debajo: la cuenta atrás (gris) o CLAIM (verde)
	local pill = new("TextButton", {
		Position = UDim2.fromOffset(x, y + TILE + 10), Size = UDim2.fromOffset(TILE, 32), BackgroundColor3 = WHITE, AutoButtonColor = false, Text = "", ZIndex = 3,
	}, gifts)
	corner(pill, 5)
	local pillGrad = vgrad(pill, Color3.fromRGB(96, 96, 104), Color3.fromRGB(56, 56, 64))
	local pillBorder = outline(pill, Color3.fromRGB(130, 130, 140), 1.5)
	local pillText = text({Size = UDim2.fromScale(1, 1), TextSize = 18, Text = "", ZIndex = 4}, pill)
	local pillPop = UI.press(pill, 1.05)
	local function tryClaim()
		Remote:FireServer("GiftClaim", i)
	end
	pill.Activated:Connect(function()
		if tiles[i].ready then
			tryClaim()
		end
	end)
	tile.Activated:Connect(function()
		if tiles[i].ready then
			tryClaim()
		else
			selectGift(i)
		end
	end)
	lupa.Activated:Connect(function()
		selectGift(i)
	end)
	tile.MouseEnter:Connect(function()
		selectGift(i)
	end)
	tiles[i] = {
		tile = tile, border = border, pop = pop, glow = glow, art = art, giftHolder = giftHolder, lock = lock, dark = dark, check = check, pill = pill,
		pillGrad = pillGrad, pillBorder = pillBorder, pillText = pillText, pillPop = pillPop, ready = false,
	}
end

-- abajo: reinicio, cuántos llevas y CLAIM ALL
local foot = corner(new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -24, 0, 82), BackgroundColor3 = BLACK, BackgroundTransparency = 0.45, ZIndex = 3,
}, gifts), 8)
outline(foot, WHITE, 2, 0.1)
text({Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(150, 20), TextSize = 14, Text = "Daily gifts reset in", ZIndex = 4}, foot)
local resetPill = corner(new("Frame", {Position = UDim2.fromOffset(22, 32), Size = UDim2.fromOffset(130, 30), BackgroundColor3 = Color3.fromRGB(70, 70, 78), ZIndex = 4}, foot), 15)
outline(resetPill, Color3.fromRGB(150, 150, 160), 1.5)
local resetText = text({Size = UDim2.fromScale(1, 1), TextSize = 17, Text = "", ZIndex = 5}, resetPill)
local progLabel = text({Position = UDim2.fromOffset(172, 8), Size = UDim2.fromOffset(110, 20), TextSize = 14, Text = "", ZIndex = 4}, foot)
local progBack = corner(new("Frame", {Position = UDim2.fromOffset(172, 36), Size = UDim2.fromOffset(110, 22), BackgroundColor3 = Color3.fromRGB(40, 40, 46), ZIndex = 4}, foot), 11)
outline(progBack, BLACK, 2)
local progFill = corner(new("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, ZIndex = 5}, progBack), 11)
vgrad(progFill, Color3.fromRGB(150, 245, 120), Color3.fromRGB(50, 170, 60))
local claimAll, claimAllText, paintClaimAll = bigButton({
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(110, 50), TextSize = 16, Text = "CLAIM ALL", ZIndex = 5,
}, foot)

-- Panel de la izquierda: lo que puede tocar en el regalo elegido
local info = new("Frame", {
	Name = "Info", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(0, -12, 0, 20), Size = UDim2.fromOffset(206, 380), BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.12, ZIndex = 2, Active = true,
}, gifts)
corner(info, 10)
vgrad(info, Color3.fromRGB(44, 42, 50), Color3.fromRGB(14, 13, 18))
outline(info, WHITE, 2.5, 0.15)
text({Position = UDim2.fromOffset(8, 10), Size = UDim2.new(1, -16, 0, 20), TextSize = 15, Text = "Reward Info", ZIndex = 3}, info)
local infoName = text({Position = UDim2.fromOffset(8, 32), Size = UDim2.new(1, -16, 0, 18), TextSize = 13, Text = "", ZIndex = 3}, info)
new("Frame", {Position = UDim2.fromOffset(14, 56), Size = UDim2.new(1, -28, 0, 2), BackgroundColor3 = WHITE, BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = 3}, info)
local infoPreview = new("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(96, 96), BackgroundTransparency = 1, ZIndex = 3}, info)
local infoList = new("Frame", {Position = UDim2.fromOffset(8, 64), Size = UDim2.new(1, -16, 1, -180), BackgroundTransparency = 1, ZIndex = 3}, info)
new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center}, infoList)
local selected
function selectGift(i)
	if selected == i then
		return
	end
	selected = i
	local gift = R.GIFTS[i]
	local style = R.GIFT_STYLES[gift.style]
	local color = GIFT_COLORS[gift.style]
	infoName.Text = ("%s · x%d"):format(style.name, gift.n or 1)
	infoName.TextColor3 = color:Lerp(WHITE, 0.45)
	for _, c in infoList:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for k, e in R.chances(gift.pool) do
		text({
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = k == 1 and 15 or 14, heavy = false, TextWrapped = true,
			Text = ("%s (%s)"):format(infoLine(e.r), pct(e.pct)), LayoutOrder = k, ZIndex = 3,
			TextColor3 = e.r.kind == "scare" and rewardColor(e.r):Lerp(WHITE, 0.35) or WHITE,
		}, infoList)
	end
	for _, c in infoPreview:GetChildren() do
		c:Destroy()
	end
	drawGift(infoPreview, color, 4)
	for _, t in tiles do
		t.selected = false
	end
	tiles[i].selected = true
end

---------- Pantalla del premio ----------
local reveal = new("TextButton", {
	Name = "Reveal", Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0.35, AutoButtonColor = false, Text = "", Visible = false, ZIndex = 50,
}, gui)
local rays = UI.piece("rays", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromOffset(620, 620), ImageColor3 = UI.GOLD, ImageTransparency = 0.35, ZIndex = 51,
}, reveal)
local revealTitle = text({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.12, 0), Size = UDim2.fromOffset(800, 60), TextSize = 46, Text = "", ZIndex = 53,
}, reveal)
local revealItems = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromOffset(0, 270), AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1, ZIndex = 52,
}, reveal)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 30), SortOrder = Enum.SortOrder.LayoutOrder,
}, revealItems)
local revealHint = text({
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.88, 0), Size = UDim2.fromOffset(500, 24), TextSize = 17, heavy = false, TextColor3 = MUTED,
	Text = "Tap anywhere to continue", ZIndex = 53,
}, reveal)
local revealPop = new("UIScale", {}, revealItems)
local revealToken = 0
local function hideReveal()
	revealToken += 1
	reveal.Visible = false
end
reveal.Activated:Connect(hideReveal)

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
			UI.viewport(got.scare, item, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 100), Size = UDim2.fromOffset(200, 200), ZIndex = 53})
		else
			rewardArt(got, item, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 100), Size = UDim2.fromOffset(170, 170), ZIndex = 53})
		end
		text({
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 206), Size = UDim2.fromOffset(320, 34), TextSize = 28, TextColor3 = color:Lerp(WHITE, 0.25),
			Text = def and def.name or ("+" .. R.text(got)), ZIndex = 54,
		}, item)
		if def then
			local cat = Config.Categories[def.cat]
			text({
				AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 240), Size = UDim2.fromOffset(320, 22), TextSize = 15, heavy = false, TextColor3 = MUTED,
				Text = ("%s%s scare · in your bag"):format(got.new and "NEW! " or "", cat and cat.name or ""), ZIndex = 54,
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
			UI.coinFly(Vector2.new(vs.X / 2, vs.Y * 0.48), 12)
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

---------- Botones de arriba a la derecha y el aviso del centro ----------
local top = new("ScreenGui", {Name = "RecompensasBotones", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 2, Enabled = false}, playerGui)
local topScale = new("UIScale", {}, top)
local function rescaleTop()
	local s = workspace.CurrentCamera.ViewportSize
	topScale.Scale = math.clamp(math.min(s.X / 1300, s.Y / 760), 0.72, 1.15)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescaleTop)
rescaleTop()
local bar = new("Frame", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 6), Size = UDim2.fromOffset(0, 66), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
}, top)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
}, bar)

-- Un botón cuadrado con su ilustración, el nombre debajo (pisando el borde) y el número rojo de la esquina
local function topButton(order, colorTop, colorBottom)
	local holder = new("Frame", {Size = UDim2.fromOffset(52, 66), BackgroundTransparency = 1, LayoutOrder = order}, bar)
	local b = new("TextButton", {Size = UDim2.fromOffset(52, 52), BackgroundColor3 = WHITE, AutoButtonColor = false, Text = "", ZIndex = 2}, holder)
	corner(b, 9)
	vgrad(b, colorTop, colorBottom)
	outline(b, Color3.fromRGB(24, 30, 56), 2)
	local shine = corner(new("Frame", {Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 0.45, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 0.72, BorderSizePixel = 0, ZIndex = 2}, b), 7)
	new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(0.2, 1)}, shine)
	local caption = text({
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 56), Size = UDim2.fromOffset(80, 16), TextSize = 12, Text = "", ZIndex = 6, strokeT = 1.6,
	}, holder)
	local badge = corner(new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -3, 0, 3), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = RED, Visible = false, ZIndex = 7,
	}, holder), UDim.new(0.5, 0))
	outline(badge, WHITE, 1.5)
	local badgeText = text({Size = UDim2.fromScale(1, 1), TextSize = 12, Text = "", ZIndex = 8, strokeT = 1}, badge)
	local badgeScale = new("UIScale", {}, badge)
	local pop = UI.press(b, 1.1)
	return {holder = holder, button = b, caption = caption, badge = badge, badgeText = badgeText, badgeScale = badgeScale, pop = pop}
end

local giftBtn = topButton(1, Color3.fromRGB(255, 128, 128), Color3.fromRGB(196, 40, 56))
local giftIconHolder = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromOffset(46, 46), BackgroundTransparency = 1, ZIndex = 3}, giftBtn.button)
local giftIcon = drawGift(giftIconHolder, Color3.fromRGB(236, 50, 60), 3, Color3.fromRGB(255, 208, 70))
local dayBtn = topButton(2, Color3.fromRGB(168, 196, 236), Color3.fromRGB(78, 104, 164))
local calHolder2 = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(46, 46), BackgroundTransparency = 1, ZIndex = 3}, dayBtn.button)
local _, calDay = drawCalendar(calHolder2, 3)
dayBtn.caption.Text = "Daily"

-- aviso del centro de arriba ("You have a new playtime reward to claim!")
local notice = text({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.25, 0), Size = UDim2.fromOffset(700, 30), TextSize = 22, Text = "", Visible = false, ZIndex = 10,
}, top)
local noticeToken = 0
local function showNotice(msg)
	noticeToken += 1
	local token = noticeToken
	notice.Text = msg
	notice.Visible = true
	notice.TextTransparency = 1
	notice.Position = UDim2.new(0.5, 0, 0.25, 12)
	tween(notice, 0.35, {TextTransparency = 0, Position = UDim2.new(0.5, 0, 0.25, 0)}, Enum.EasingStyle.Back)
	task.delay(4, function()
		if noticeToken == token then
			tween(notice, 0.5, {TextTransparency = 1})
			task.wait(0.5)
			if noticeToken == token then
				notice.Visible = false
			end
		end
	end)
end

---------- Estado ----------
local function loaded()
	return player:GetAttribute("LoginDay") ~= nil
end
local function tutDone()
	return (player:GetAttribute("Tut") or 0) >= 4
end
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

local function giftCounts()
	local played, claimed = giftsNow()
	local ready, taken, nextIn = 0, 0, nil
	for i, g in R.GIFTS do
		if claimed[i] then
			taken += 1
		elseif played >= g.t then
			ready += 1
		elseif not nextIn or g.t - played < nextIn then
			nextIn = g.t - played
		end
	end
	return ready, taken, nextIn
end

-- "04:59" (y "1:04:59" si pasa de una hora)
local function clock2(s)
	s = math.max(0, math.ceil(s))
	local h, m, sec = s // 3600, (s // 60) % 60, s % 60
	if h > 0 then
		return ("%d:%02d:%02d"):format(h, m, sec)
	end
	return ("%02d:%02d"):format(m, sec)
end

local function refreshDaily()
	local can, streak, idx = loginNow()
	for i, c in dayCards do
		local taken = i < idx or (i == idx and not can)
		local isToday = i == idx
		local color = taken and CLAIMED_TAB or isToday and TODAY_TAB or FUTURE_TAB
		c.tabGrad.Color = ColorSequence.new(color:Lerp(WHITE, 0.15), color:Lerp(BLACK, 0.15))
		c.border.Color = isToday and WHITE or color
		c.border.Thickness = isToday and 3 or 2.5
		c.check.Visible = taken
		c.art.ImageTransparency = taken and 0.25 or 0
		c.glow.ImageTransparency = taken and 0.9 or isToday and 0.45 or 0.72
		c.card.ZIndex = isToday and 6 or 3
		c.pop.Scale = isToday and 1.08 or 1
	end
	if can then
		streakText.Text = streak > 1 and ("Streak of %d days!"):format(streak) or "Welcome back!"
		dailyButtonText.Text = tutDone() and "CLAIM" or "TUTORIAL FIRST"
		dailyButtonText.TextSize = tutDone() and 26 or 17
		paintDailyButton(tutDone() and GREEN or Color3.fromRGB(150, 150, 158))
	else
		streakText.Text = ("Streak of %d day%s!"):format(math.max(streak, 1), streak == 1 and "" or "s")
		dailyButtonText.Text = "CLOSE"
		dailyButtonText.TextSize = 26
		paintDailyButton(Color3.fromRGB(150, 150, 158))
	end
end

local function refreshGifts()
	local played, claimed, resetIn = giftsNow()
	local ready, taken = 0, 0
	for i, g in R.GIFTS do
		local t = tiles[i]
		local done = claimed[i] == true
		local isReady = not done and played >= g.t
		t.ready = isReady
		ready += isReady and 1 or 0
		taken += done and 1 or 0
		t.lock.Visible = not done and not isReady
		t.dark.Visible = done
		t.check.Visible = done
		t.glow.ImageTransparency = isReady and 0.3 or 1
		t.border.Color = isReady and GREEN or t.selected and WHITE or Color3.fromRGB(96, 96, 108)
		t.border.Thickness = isReady and 3 or 2
		if isReady then
			t.pillText.Text = "CLAIM!"
			t.pillGrad.Color = ColorSequence.new(GREEN:Lerp(WHITE, 0.2), GREEN:Lerp(BLACK, 0.3))
			t.pillBorder.Color = WHITE
		elseif done then
			t.pillText.Text = "Claimed"
			t.pillGrad.Color = ColorSequence.new(Color3.fromRGB(70, 70, 78), Color3.fromRGB(40, 40, 46))
			t.pillBorder.Color = Color3.fromRGB(100, 100, 110)
		else
			t.pillText.Text = R.clock(g.t - played)
			t.pillGrad.Color = ColorSequence.new(Color3.fromRGB(96, 96, 104), Color3.fromRGB(56, 56, 64))
			t.pillBorder.Color = Color3.fromRGB(130, 130, 140)
		end
		t.pillText.TextColor3 = done and MUTED or WHITE
	end
	resetText.Text = R.clock(resetIn)
	progLabel.Text = ("Claimed %d/%d"):format(taken, #R.GIFTS)
	progFill.Size = UDim2.fromScale(taken / #R.GIFTS, 1)
	progFill.Visible = taken > 0
	paintClaimAll(ready > 0 and GREEN or Color3.fromRGB(110, 110, 118))
	claimAllText.Text = ready > 1 and ("CLAIM ALL (%d)"):format(ready) or "CLAIM ALL"
	claimAllText.TextSize = ready > 1 and 13 or 16
end

---------- Abrir y cerrar ----------
local function anyOpen()
	return daily.Visible or gifts.Visible
end
local function syncGui()
	gui.Enabled = anyOpen() or reveal.Visible
	dim.Visible = anyOpen()
end
local function popIn(w)
	local s = w:FindFirstChild("Pop") or new("UIScale", {Name = "Pop"}, w)
	s.Scale = 0.82
	tween(s, 0.32, {Scale = 1}, Enum.EasingStyle.Back)
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
		gifts.Visible = win == gifts
		popIn(win)
		if win == daily then
			refreshDaily()
		else
			if not selected then
				local played, claimed = giftsNow()
				local pick = 1
				for i, g in R.GIFTS do
					if not claimed[i] and played < g.t then
						pick = i
						break
					end
				end
				selectGift(pick)
			end
			refreshGifts()
		end
	else
		win.Visible = false
		tip.Visible = false
	end
	syncGui()
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
		open = not gifts.Visible
	end
	show(gifts, open)
end
UI.toggleDaily, UI.toggleGifts = toggleDaily, toggleGifts
giftsClose.Activated:Connect(function()
	toggleGifts(false)
end)
dim.Activated:Connect(function()
	show(daily, false)
	show(gifts, false)
end)
reveal:GetPropertyChangedSignal("Visible"):Connect(syncGui)

dailyButton.Activated:Connect(function()
	local can = loginNow()
	if not can then
		return toggleDaily(false)
	end
	if not tutDone() then
		UI.toast("Finish Mayor Pumpkin's tutorial first!", UI.ORANGE, "info")
		return
	end
	Remote:FireServer("LoginClaim")
end)
claimAll.Activated:Connect(function()
	local any = false
	for i, t in tiles do
		if t.ready then
			any = true
			Remote:FireServer("GiftClaim", i)
			task.wait(0.55) -- (el servidor no deja abrir dos a la vez)
		end
	end
	if not any then
		UI.toast("Keep playing to unlock more gifts!", UI.ORANGE, "clock")
	end
end)
giftBtn.button.Activated:Connect(function()
	toggleGifts()
end)
dayBtn.button.Activated:Connect(function()
	toggleDaily()
end)

---------- Bucle: cuentas atrás, botones de arriba y avisos ----------
local lastReady
local t0 = os.clock()
RunService.RenderStepped:Connect(function()
	local t = os.clock() - t0
	-- los regalos listos se balancean; la casilla de hoy late
	for _, tile in tiles do
		if tile.ready then
			tile.art.Rotation = math.sin(t * 6) * 8
			tile.giftHolder.Size = UDim2.fromOffset(84 + math.sin(t * 6) * 3, 84 + math.sin(t * 6) * 3)
		else
			tile.art.Rotation = 0
			tile.giftHolder.Size = UDim2.fromOffset(84, 84)
		end
	end
	if reveal.Visible then
		rays.Rotation = (rays.Rotation + 0.4) % 360
	end
	if giftBtn.badge.Visible then
		giftIcon.Rotation = math.sin(t * 7) * 10 * math.max(0, math.sin(t * 1.6))
	else
		giftIcon.Rotation = 0
	end
end)

task.spawn(function()
	while true do
		top.Enabled = UI.gui.Enabled and not Portada.active
		if loaded() then
			-- botón del regalo: cuenta atrás, "Claim!" o "Done!"
			local ready, _, nextIn = giftCounts()
			giftBtn.badge.Visible = ready > 0
			giftBtn.badgeText.Text = tostring(ready)
			giftBtn.caption.Text = ready > 0 and "Claim!" or nextIn and clock2(nextIn) or "Done!"
			if lastReady and ready > lastReady and tutDone() then
				if not gifts.Visible then
					showNotice("You have a new playtime reward to claim!")
				end
				UI.sound("Jingle")
				giftBtn.badgeScale.Scale = 1.7
				tween(giftBtn.badgeScale, 0.4, {Scale = 1}, Enum.EasingStyle.Back)
			end
			lastReady = ready
			-- botón del calendario
			local can = loginNow()
			dayBtn.badge.Visible = can
			dayBtn.badgeText.Text = "!"
			calDay.Text = tostring(os.date("*t").day)
			if daily.Visible then
				refreshDaily()
			end
			if gifts.Visible then
				refreshGifts()
			end
		end
		task.wait(0.25)
	end
end)

for _, attr in {"LoginDay", "LoginStreak", "GiftDay", "GiftStart", "GiftClaimed", "Tut"} do
	player:GetAttributeChangedSignal(attr):Connect(function()
		if daily.Visible then
			refreshDaily()
		end
		if gifts.Visible then
			refreshGifts()
		end
	end)
end

-- se cierran al ir de visita o al Tower Defense
-- se cierran al empezar una visita (en la casa ajena tienes que ver tu miedo). En el Tower Defense sí se pueden abrir:
-- antes también se cerraban con cada cambio de TDCash (el dinero de la partida, que cambia todo el rato), así que allí
-- se cerraban nada más abrirlas
player:GetAttributeChangedSignal("Mode"):Connect(function()
	if anyOpen() and player:GetAttribute("Mode") == "visit" then
		show(daily, false)
		show(gifts, false)
	end
end)

---------- Respuestas del servidor ----------
Remote.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "LoginClaimed" then
		-- a = casilla, b = racha, c = lo que ha tocado
		local card = dayCards[a]
		refreshDaily()
		if card then
			card.pop.Scale = 1.35
			tween(card.pop, 0.4, {Scale = 1.08}, Enum.EasingStyle.Back)
		end
		task.delay(0.35, function()
			showReveal(("DAY %d REWARD!"):format(a), {c})
		end)
	elseif kind == "GiftClaimed" then
		-- a = regalo, b = lista de lo que ha tocado
		local t = tiles[a]
		refreshGifts()
		if t then
			t.pop.Scale = 1.3
			tween(t.pop, 0.4, {Scale = 1}, Enum.EasingStyle.Back)
		end
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
	until not Portada.active and UI.gui.Enabled and loaded()
	task.wait(2.5)
	local can = loginNow()
	if can and tutDone() and not player:GetAttribute("Mode") and player:GetAttribute("TDCash") == nil and not UI.menuOpen() then
		toggleDaily(true)
	end
end)
