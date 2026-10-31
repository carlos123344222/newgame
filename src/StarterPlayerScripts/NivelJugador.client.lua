-- Nivel del jugador: franja abajo, bajo la barra de tropas (TDTroops deja el hueco LevelHolder), como el "Niveau" de
-- los juegos de defensa: "LEVEL" encima a la izquierda y la suerte a la derecha; tu nivel en azul a la izquierda, la
-- barra fina por tramos (la experiencia que llevas dentro a la izquierda y la que pide el nivel a la derecha) y el
-- siguiente nivel a la derecha. Al ganar experiencia la barra destella. Al pulsarla, la probabilidad de cada rareza a
-- tu nivel y al siguiente. Al subir de nivel, mensaje grande.
-- Datos: atributo PXP del jugador (lo pone Juego / TDMatch) y Config.playerLevelOf / Config.rarityChances.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")

local Config = require(RS:WaitForChild("Config"))
local UI = require(script.Parent:WaitForChild("UI"))
local player = Players.LocalPlayer
local new = UI.new

local ACCENT = Color3.fromRGB(110, 235, 140) -- verde trébol: suerte
local BLUE = Color3.fromRGB(86, 168, 255) -- nivel y experiencia
local SEGMENTS = 8
local FONT = UI.HUD_FONT
local LEFT, RIGHT = Enum.TextXAlignment.Left, Enum.TextXAlignment.Right

-- suerte = probabilidad de que llegue alguien no común, comparada con la del nivel 1
local function boost()
	return player:GetAttribute("LuckBoost") or 1
end
local function luck(lv)
	return (100 - Config.rarityChances(lv, boost())[1]) / (100 - Config.rarityChances(1)[1])
end

---------- Franja ----------
local holder = player:WaitForChild("PlayerGui"):WaitForChild("TroopBar"):WaitForChild("Bar"):WaitForChild("LevelHolder")
local card = new("TextButton", {Name = "PlayerLevel", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, AutoButtonColor = false, Text = ""}, holder)
local pop = new("UIScale", {}, card)
local function text(props, parent)
	props.BackgroundTransparency = 1
	props.Font = FONT
	props.TextColor3 = props.TextColor3 or UI.WHITE
	local l = new("TextLabel", props, parent or card)
	UI.hudStroke(l, props.TextSize >= 16 and 2 or 1.6)
	return l
end
text({Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(120, 15), TextSize = 13, TextXAlignment = LEFT, Text = "Level"})
local luckText = text({AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(200, 15), TextSize = 12, TextColor3 = ACCENT, TextXAlignment = RIGHT, Text = ""})
-- tu nivel y el siguiente, a los lados de la barra
local lvText = text({Position = UDim2.fromOffset(0, 17), Size = UDim2.fromOffset(36, 22), TextSize = 19, TextColor3 = BLUE, TextXAlignment = LEFT, Text = "1"})
local nextText = text({AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 17), Size = UDim2.fromOffset(36, 22), TextSize = 19, TextColor3 = BLUE, TextXAlignment = RIGHT, Text = "2"})
-- barra fina por tramos
local track = UI.round(new("Frame", {Position = UDim2.fromOffset(38, 20), Size = UDim2.new(1, -76, 0, 16), BackgroundColor3 = Color3.fromRGB(16, 15, 22), BackgroundTransparency = 0.2}, card), UDim.new(1, 0))
local trackStroke = UI.stroke(track, UI.INK, 1.5, 0.2):FindFirstChildOfClass("UIStroke")
local barFill = UI.round(new("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2}, track), UDim.new(1, 0))
UI.gradient(barFill, Color3.fromRGB(140, 205, 255), Color3.fromRGB(52, 128, 240))
local fillGradient = barFill:FindFirstChildOfClass("UIGradient")
local BLUE_FILL = fillGradient and fillGradient.Color
local GOLD_FILL = ColorSequence.new(Color3.fromRGB(255, 236, 140), Color3.fromRGB(255, 160, 40)) -- (nivel máximo)
local fillFlash = UI.round(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = UI.WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3}, barFill), UDim.new(1, 0))
for i = 1, SEGMENTS - 1 do
	new("Frame", {Position = UDim2.new(i / SEGMENTS, -1, 0, 2), Size = UDim2.new(0, 2, 1, -4), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 4}, track)
end
local xpText = text({Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0.6, 0, 1, 0), TextSize = 11, TextXAlignment = LEFT, Text = "", ZIndex = 5}, track)
local needText = text({AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = UDim2.new(0.4, 0, 1, 0), TextSize = 11, TextXAlignment = RIGHT, Text = "", ZIndex = 5}, track)
card.MouseEnter:Connect(function()
	trackStroke.Color = BLUE
end)
card.MouseLeave:Connect(function()
	trackStroke.Color = UI.INK
end)

---------- Panel de suerte (al pulsar la franja; se abre hacia arriba) ----------
local panel = UI.round(new("Frame", {
	Name = "LuckPanel", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -8), Size = UDim2.fromOffset(300, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Color3.fromRGB(20, 18, 28), BackgroundTransparency = 0.06, Visible = false, ZIndex = 10,
}, card), 10)
UI.stroke(panel, BLUE, 2)
new("UIPadding", {PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12)}, panel)
new("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, panel)
new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Font = FONT, TextSize = 15, TextColor3 = UI.GOLD, TextStrokeTransparency = 0,
	TextXAlignment = Enum.TextXAlignment.Left, Text = "Higher level = rarer visitors", LayoutOrder = -1, ZIndex = 11,
}, panel)
local panelTitle = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 16), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Font = UI.SMALL, TextSize = 12, TextColor3 = UI.MUTED, TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left, Text = "", LayoutOrder = 0, ZIndex = 11,
}, panel)
local rows = {}
for i, r in Config.Rarities do
	rows[i] = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 19), BackgroundTransparency = 1, Font = UI.SMALL, TextSize = 14, TextColor3 = UI.WHITE, RichText = true,
		TextStrokeTransparency = 0, TextXAlignment = Enum.TextXAlignment.Left, Text = "", LayoutOrder = i, ZIndex = 11,
	}, panel)
end
-- valentía al visitar otras casas (Config.visitFear), debajo de las rarezas
local braveRow = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Font = UI.SMALL, TextSize = 14, TextColor3 = UI.WHITE, RichText = true,
	TextStrokeTransparency = 0, TextXAlignment = Enum.TextXAlignment.Left, Text = "", LayoutOrder = #Config.Rarities + 1, ZIndex = 11,
}, panel)
local function hex(c)
	return c:Lerp(UI.WHITE, 0.15):ToHex()
end
local function pct(x)
	return x >= 1 and ("%.1f%%"):format(x) or ("%.2g%%"):format(x)
end

---------- Actualizar ----------
local shownLevel, lastXP
local function refresh()
	local xp = player:GetAttribute("PXP") or 0
	local lv, have, need = Config.playerLevelOf(xp)
	if lastXP and xp > lastXP then
		-- destello al ganar experiencia
		fillFlash.BackgroundTransparency = 0.25
		TweenService:Create(fillFlash, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
	end
	lastXP = xp
	lvText.Text = tostring(lv)
	nextText.Text = tostring(lv + 1)
	-- el hueco del nivel crece con el número ("100" no cabía y pisaba la barra); al máximo no hay siguiente nivel: la
	-- barra llega hasta el borde, dorada, con un solo "MAX LEVEL" dentro
	local maxed = lv >= Config.PLAYER_MAX_LEVEL
	local lw = math.max(36, TextService:GetTextSize(lvText.Text, lvText.TextSize, FONT, Vector2.new(200, 40)).X + 4)
	lvText.Size = UDim2.fromOffset(lw, 22)
	nextText.Visible = not maxed
	track.Position = UDim2.fromOffset(lw + 2, 20)
	track.Size = UDim2.new(1, -(lw + 2) - (maxed and 0 or 38), 0, 16)
	if fillGradient then
		fillGradient.Color = maxed and GOLD_FILL or BLUE_FILL
	end
	lvText.TextColor3 = maxed and UI.GOLD or BLUE
	luckText.Text = ("🍀 Luck x%.2f"):format(luck(lv))
	local frac = need > 0 and have / need or 1
	barFill.Visible = frac > 0.01
	TweenService:Create(barFill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {Size = UDim2.fromScale(math.max(frac, 0.04), 1)}):Play()
	xpText.Text = maxed and "MAX LEVEL" or ("%s XP"):format(UI.fmt(have))
	xpText.TextXAlignment = maxed and Enum.TextXAlignment.Center or LEFT
	xpText.Position = maxed and UDim2.new() or UDim2.fromOffset(8, 0)
	xpText.Size = maxed and UDim2.fromScale(1, 1) or UDim2.new(0.6, 0, 1, 0)
	needText.Text = maxed and "" or UI.fmt(need)
	local now = Config.rarityChances(lv, boost())
	local nxt = lv < Config.PLAYER_MAX_LEVEL and Config.rarityChances(lv + 1, boost())
	panelTitle.Text = ("Scare visitors and win waves to level up! Your visitors get braver (fear x%.2f) but drop more coins (x%.2f)."):format(Config.levelFear(lv), Config.levelCoins(lv))
		.. (boost() > 1 and ("  ·  ⚡ Boost x%d  ·  Materials %s"):format(boost(), pct(Config.variantChance(boost()) * 100)) or "")
	-- (el alto a mano: dentro de la lista, AutomaticSize no lo ajustaba y salía una sola línea)
	panelTitle.Size = UDim2.new(1, 0, 0, TextService:GetTextSize(panelTitle.Text, panelTitle.TextSize, panelTitle.Font, Vector2.new(272, 1000)).Y + 2)
	braveRow.Text = lv >= Config.PLAYER_MAX_LEVEL and '<font color="#ffcc48">🛡 Fearless!</font>   no house can make you faint'
		or ('<font color="#ffcc48">🛡 Bravery</font>   %d%% fear on visits  <font color="#cec2e8">→</font>  <font color="#6eeb8c">%d%%</font>'):format(
			math.floor(Config.visitFear(lv) * 100 + 0.5), math.floor(Config.visitFear(lv + 1) * 100 + 0.5))
	for i, r in Config.Rarities do
		rows[i].Text = ('<font color="#%s">● %s</font>   %s'):format(hex(r.color), r.name, pct(now[i]))
			.. (nxt and i > 1 and ('  <font color="#cec2e8">→</font>  <font color="#6eeb8c">%s</font>'):format(pct(nxt[i])) or "")
	end
	if shownLevel and lv > shownLevel then
		-- ¡sube de nivel! (el jugador, no las tropas: esto sí es grande)
		UI.big("LEVEL " .. lv .. "!", ("🍀 Luck x%.2f  ·  Rarer visitors are coming"):format(luck(lv)), ACCENT, 3)
		UI.sound("Win")
		UI.sound("Sparkle")
		UI.confetti(60)
		pop.Scale = 1.25
		TweenService:Create(pop, TweenInfo.new(0.5, Enum.EasingStyle.Elastic), {Scale = 1}):Play()
	end
	shownLevel = player:GetAttribute("PXP") ~= nil and lv or nil -- (lo cargado al entrar no avisa)
end

card.Activated:Connect(function()
	panel.Visible = not panel.Visible
	UI.sound("Tab")
end)
player:GetAttributeChangedSignal("PXP"):Connect(refresh)
player:GetAttributeChangedSignal("LuckBoost"):Connect(refresh)
refresh()

---------- Suerte extra (solo los de Config.LUCK_ADMINS) ----------
-- Botón a la derecha de la tarjeta: x1 → x10 → x100 → x1. El servidor (Juego) vuelve a comprobar quién eres.
if Config.LUCK_ADMINS[player.UserId] then
	local remote = RS:WaitForChild("LuckBoost")
	local btn = UI.round(new("TextButton", {
		Name = "LuckBoost", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, 10, 0, 28), Size = UDim2.fromOffset(54, 26),
		BackgroundColor3 = Color3.fromRGB(40, 60, 46), Font = FONT, TextSize = 13, TextColor3 = UI.WHITE, TextStrokeTransparency = 0,
		Text = "", AutoButtonColor = true, ZIndex = 2,
	}, card), 6)
	UI.stroke(btn, ACCENT, 1.5)
	local function show()
		local b = boost()
		btn.Text = "⚡x" .. b
		btn.BackgroundColor3 = b >= 100 and Color3.fromRGB(200, 60, 120) or b >= 10 and Color3.fromRGB(60, 170, 90) or Color3.fromRGB(40, 60, 46)
	end
	btn.Activated:Connect(function()
		local i = table.find(Config.LUCK_BOOSTS, boost()) or 1
		remote:FireServer(Config.LUCK_BOOSTS[i % #Config.LUCK_BOOSTS + 1])
		UI.sound("Tab")
	end)
	player:GetAttributeChangedSignal("LuckBoost"):Connect(show)
	show()
end
