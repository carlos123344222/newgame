-- Panel de administrador: solo para Config.isAdmin (lebrowsent y unomasunoasetres). Botón "Admin" en el menú lateral.
-- A la izquierda, la lista de jugadores del servidor (se elige uno); a la derecha, los comandos: monedas, gemas,
-- experiencia, nivel, suerte, dar sustos, ir hasta él, traerlo, echarlo, Noche de Sangre y un anuncio para todos.
-- Cada botón manda Remote:FireServer("Admin", comando, userId, valor, valor2) y el servidor (Juego, actions.Admin)
-- vuelve a comprobar que eres admin y responde con un aviso ("Notice").
-- También se abre desde el perfil de otro jugador (PerfilJugador) con ese jugador ya elegido: evento AdminOpen.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS:WaitForChild("Config"))
local Remote = RS:WaitForChild("Remote")
local UI = require(script.Parent:WaitForChild("UI"))
local player = Players.LocalPlayer
local new = UI.new

-- los anuncios de los admins los ve todo el mundo (el texto ya viene filtrado por el servidor)
Remote.OnClientEvent:Connect(function(kind, who, msg)
	if kind == "AdminAnnounce" then
		UI.big("📢 " .. tostring(msg), "Announcement from " .. tostring(who), UI.GOLD, 5)
		UI.sound("Jingle")
	end
end)

if not Config.isAdmin(player) then
	return
end

local ACCENT = Color3.fromRGB(226, 60, 84)
local FONT = UI.HUD_FONT
local LEFT = Enum.TextXAlignment.Left
local FIELD = Color3.fromRGB(24, 18, 36)

local function text(props, parent)
	props.BackgroundTransparency = 1
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or UI.WHITE
	local l = new("TextLabel", props, parent)
	UI.hudStroke(l, 1.6)
	return l
end
local function box(props, parent)
	props.BackgroundColor3 = FIELD
	props.Font = UI.FONT
	props.TextColor3 = UI.WHITE
	props.PlaceholderColor3 = Color3.fromRGB(150, 140, 170)
	props.ClearTextOnFocus = false
	props.TextSize = props.TextSize or 18
	local b = UI.round(new("TextBox", props, parent), 8)
	UI.stroke(b, UI.INK, 2)
	return b
end

---------- Ventana ----------
local win, close = UI.window({Name = "AdminPanel", Size = UDim2.fromOffset(860, 560), title = "ADMIN", icon = "crown", accent = ACCENT, Visible = false, ZIndex = 8}, UI.gui)

-- jugadores (izquierda)
local listBack = UI.round(new("Frame", {Position = UDim2.fromOffset(24, 56), Size = UDim2.new(0, 230, 1, -80), BackgroundColor3 = FIELD, BackgroundTransparency = 0.3, ZIndex = 9}, win), 12)
text({Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 22), TextSize = 17, TextXAlignment = LEFT, Text = "Players", ZIndex = 10}, listBack)
local list = new("ScrollingFrame", {
	Position = UDim2.fromOffset(8, 36), Size = UDim2.new(1, -16, 1, -44), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 10,
}, listBack)
new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.Name}, list)

-- comandos (derecha)
local right = new("ScrollingFrame", {
	Position = UDim2.fromOffset(270, 56), Size = UDim2.new(1, -294, 1, -80), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 9,
}, win)
new("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, right)
new("UIPadding", {PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10)}, right)

local selected -- jugador elegido
local selectedText = text({Size = UDim2.new(1, 0, 0, 26), TextSize = 20, TextXAlignment = LEFT, RichText = true, Text = "", LayoutOrder = 1, ZIndex = 10}, right)

local function section(title, order)
	text({Size = UDim2.new(1, 0, 0, 20), TextSize = 15, TextColor3 = UI.GOLD, TextXAlignment = LEFT, Text = title, LayoutOrder = order * 10, ZIndex = 10}, right)
	local row = new("Frame", {Size = UDim2.new(1, 0, 0, 44), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order * 10 + 1, ZIndex = 10}, right)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Wraps = true, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center}, row)
	return row
end
local function btn(row, label, color, width, order, onClick)
	local b = UI.button({Size = UDim2.fromOffset(width or 120, 40), BackgroundColor3 = color, Text = label, TextSize = 15, LayoutOrder = order or 0, ZIndex = 11}, row)
	b.Activated:Connect(onClick)
	return b
end

-- El servidor contesta a cada comando con un aviso ("Notice"). Si no contesta, es que su script (Juego) no tiene la
-- parte de admin: pasaba al tener este panel en Studio pero el Juego de otra rama (Rojo no borra los scripts que ya
-- no están en el proyecto). Entonces se avisa en vez de no hacer nada.
local sent, answered = 0, 0
Remote.OnClientEvent:Connect(function(kind)
	if kind == "Notice" then
		answered = sent
	end
end)
local function send(cmd, needsTarget, a, b)
	if needsTarget and not (selected and selected.Parent) then
		return UI.toast("Pick a player first", UI.ORANGE)
	end
	sent += 1
	local n = sent
	Remote:FireServer("Admin", cmd, selected and selected.UserId, a, b)
	task.delay(4, function()
		if answered < n and cmd ~= "Kick" then
			UI.toast("The server didn't answer: its scripts are out of date (sync Rojo and publish again)", UI.RED)
		end
	end)
end
local function numberOf(tb)
	local n = tonumber((tb.Text:gsub("[%s,]", "")))
	if not n then
		UI.toast("Write a number", UI.ORANGE)
	end
	return n
end

-- dinero, gemas, experiencia y nivel (cantidad en la caja; negativo = quitar)
local amountRow = section("Give (use a negative number to take away)", 2)
local amount = box({Size = UDim2.fromOffset(150, 40), PlaceholderText = "Amount", Text = "1000", LayoutOrder = 0, ZIndex = 11}, amountRow)
for i, c in {{"Coins", "+ Coins", UI.GOLD:Lerp(UI.ORANGE, 0.4)}, {"Gems", "+ Gems", UI.GEM:Lerp(UI.PURPLE, 0.3)}, {"XP", "+ XP", Color3.fromRGB(86, 168, 255)}, {"Level", "Set level", Color3.fromRGB(110, 200, 120)}} do
	btn(amountRow, c[2], c[3], 112, i, function()
		local n = numberOf(amount)
		if n then
			send(c[1], true, n)
		end
	end)
end

-- suerte
local luckRow = section("Luck boost", 4)
for i, n in Config.LUCK_BOOSTS do
	btn(luckRow, "Luck x" .. n, n >= 100 and Color3.fromRGB(200, 60, 120) or n >= 10 and Color3.fromRGB(60, 170, 90) or UI.TAB, 110, i, function()
		send("Luck", true, n)
	end)
end

-- dar un susto: buscador por nombre (o id) y cantidad
local scareRow = section("Give a scare (type its name)", 6)
local scareBox = box({Size = UDim2.fromOffset(220, 40), PlaceholderText = "e.g. Dragon, Ghost...", Text = "", LayoutOrder = 0, ZIndex = 11}, scareRow)
local scareCount = box({Size = UDim2.fromOffset(70, 40), PlaceholderText = "Qty", Text = "1", LayoutOrder = 1, ZIndex = 11}, scareRow)
local scareHint = text({Size = UDim2.fromOffset(200, 40), TextSize = 13, TextColor3 = UI.MUTED, TextXAlignment = LEFT, Text = "", LayoutOrder = 3, ZIndex = 11}, scareRow)
local function findScare(q)
	q = string.lower((q:gsub("%s", "")))
	if q == "" then
		return nil
	end
	local best
	for id, def in Config.Scares do
		local name = string.lower((def.name:gsub("%s", "")))
		if string.lower(id) == q or name == q then
			return id
		elseif not best and (name:find(q, 1, true) or string.lower(id):find(q, 1, true)) then
			best = id
		end
	end
	return best
end
scareBox:GetPropertyChangedSignal("Text"):Connect(function()
	local id = findScare(scareBox.Text)
	scareHint.Text = id and ("→ " .. Config.Scares[id].name) or (scareBox.Text ~= "" and "Not found" or "")
end)
btn(scareRow, "Give", UI.BUY, 90, 2, function()
	local id = findScare(scareBox.Text)
	if not id then
		return UI.toast("Scare not found", UI.ORANGE)
	end
	send("Scare", true, id, tonumber(scareCount.Text) or 1)
end)

-- moverse y echar
local moveRow = section("Player", 8)
btn(moveRow, "Go to", UI.PURPLE, 110, 1, function()
	send("TpTo", true, 0)
end)
btn(moveRow, "Bring", UI.PURPLE, 110, 2, function()
	send("Bring", true, 0)
end)
local kickArmed = 0
local kickBtn
kickBtn = btn(moveRow, "Kick", UI.RED, 110, 3, function()
	-- dos pulsaciones (en 3 s) para no echar a nadie sin querer
	if os.clock() - kickArmed > 3 then
		kickArmed = os.clock()
		kickBtn.Text = "Sure?"
		task.delay(3, function()
			kickBtn.Text = "Kick"
		end)
		return
	end
	kickArmed = 0
	kickBtn.Text = "Kick"
	send("Kick", true, 0)
end)

-- servidor
local serverRow = section("Server", 10)
btn(serverRow, "Start Blood Night", Color3.fromRGB(196, 30, 48), 190, 1, function()
	send("BloodStart", false)
end)
btn(serverRow, "Stop Blood Night", Color3.fromRGB(90, 70, 100), 190, 2, function()
	send("BloodStop", false)
end)

local announceRow = section("Announcement for everyone", 12)
local announce = box({Size = UDim2.fromOffset(370, 40), PlaceholderText = "Message...", Text = "", TextSize = 16, LayoutOrder = 0, ZIndex = 11}, announceRow)
btn(announceRow, "Send", UI.BUY, 100, 1, function()
	if announce.Text ~= "" then
		send("Announce", false, announce.Text)
		announce.Text = ""
	end
end)

---------- Lista de jugadores ----------
local rows = {}
local function showSelected()
	if selected and selected.Parent then
		selectedText.Text = ('Selected: <font color="#ffd446">%s</font>  <font color="#cec2e8">@%s · Lv %d</font>'):format(selected.DisplayName, selected.Name, Config.playerLevel(selected))
	else
		selected = nil
		selectedText.Text = '<font color="#cec2e8">Pick a player on the left</font>'
	end
	for p, r in rows do
		r.BackgroundColor3 = p == selected and ACCENT or UI.CARD
	end
end
local function addRow(p)
	local r = UI.round(new("TextButton", {
		Name = string.lower(p.Name), Size = UDim2.new(1, -8, 0, 44), BackgroundColor3 = UI.CARD, AutoButtonColor = true, Text = "", ZIndex = 11,
	}, list), 8)
	text({Position = UDim2.fromOffset(10, 3), Size = UDim2.new(1, -16, 0, 22), TextSize = 15, TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd, Text = p.DisplayName .. (p == player and " (you)" or ""), ZIndex = 12}, r)
	text({Position = UDim2.fromOffset(10, 23), Size = UDim2.new(1, -16, 0, 16), TextSize = 12, TextColor3 = UI.MUTED, TextXAlignment = LEFT, Text = "@" .. p.Name, ZIndex = 12}, r)
	r.Activated:Connect(function()
		selected = p
		showSelected()
		UI.sound("Tab")
	end)
	rows[p] = r
end
for _, p in Players:GetPlayers() do
	addRow(p)
end
Players.PlayerAdded:Connect(addRow)
Players.PlayerRemoving:Connect(function(p)
	if rows[p] then
		rows[p]:Destroy()
		rows[p] = nil
	end
	if p == selected then
		selected = nil
	end
	showSelected()
end)

---------- Abrir y cerrar ----------
local function toggle(on)
	if on == nil then
		on = not win.Visible
	end
	win.Visible = on
	if on then
		selected = selected or player
		showSelected()
		UI.popIn(win)
	end
end
close.Activated:Connect(function()
	toggle(false)
end)
UI.menuButton(50, "crown", "Admin", ACCENT).Activated:Connect(function()
	toggle()
end)

-- desde el perfil de otro jugador: abre con él elegido
local openEvent = new("BindableEvent", {Name = "AdminOpen"}, script.Parent)
openEvent.Event:Connect(function(p)
	selected = p
	toggle(true)
end)
