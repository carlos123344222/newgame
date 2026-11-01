-- Tableros de la plaza (cliente): dibuja en cada tablero (Mapa.Plaza.Rankings) la lista que calcula el servidor
-- (ServerScriptService.Rankings: atributos BoardKind, BoardTitle, BoardIcon, BoardSub y Rows del tablero).
-- La lista se desplaza con la rueda del ratón (con el ratón encima del tablero) o arrastrando con el dedo: por eso el
-- SurfaceGui vive en PlayerGui (Adornee = el panel), que es lo único que recibe la entrada. Abajo, tu puesto.
-- Con StreamingEnabled el tablero puede desaparecer y volver (otra instancia): cada segundo se comprueba y se rehace.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ICONS = "rbxassetid://114568727191863"
local ICON_ORDER = {
	coin = 1, gem = 2, house = 3, heart = 11, skull = 12, ghost = 14, trophy = 18, star = 20, crown = 28, thumb = 64,
}
local RANK_COLORS = {Color3.fromRGB(255, 212, 60), Color3.fromRGB(214, 222, 236), Color3.fromRGB(230, 150, 90)}
local WHITE, INK = Color3.new(1, 1, 1), Color3.fromRGB(16, 10, 22)
local ROW_H, ROW_GAP = 56, 6
local HEAD_H = 106 -- título y mes
local FOOT_H = 46 -- tu puesto

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function outline(o, t, color)
	return new("UIStroke", {Color = color or INK, Thickness = t or 2, LineJoinMode = Enum.LineJoinMode.Round, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual}, o)
end
local function corner(o, r)
	new("UICorner", {CornerRadius = UDim.new(0, r)}, o)
	return o
end
local function icon(name, props, parent)
	local i = ICON_ORDER[name] or 18
	props.BackgroundTransparency = 1
	props.Image = ICONS
	props.ImageRectOffset = Vector2.new(((i - 1) % 8) * 128, ((i - 1) // 8) * 128)
	props.ImageRectSize = Vector2.new(128, 128)
	props.ScaleType = Enum.ScaleType.Fit
	return new("ImageLabel", props, parent)
end

local built = {} -- [tablero] = {gui, panel, conns, ...}

local function makeRow(u, i)
	local accent = u.accent
	local f = corner(new("Frame", {
		Name = "Row" .. i, Size = UDim2.new(1, -14, 0, ROW_H), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55, LayoutOrder = i,
	}, u.list), 10)
	local st = new("UIStroke", {
		Color = RANK_COLORS[i] or accent, Thickness = i <= 3 and 2 or 1, Transparency = i <= 3 and 0.1 or 0.7, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, f)
	local face = corner(new("ImageLabel", {Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(48, 48), BackgroundColor3 = Color3.fromRGB(40, 34, 52), Image = ""}, f), 24)
	new("UIStroke", {Color = RANK_COLORS[i] or accent, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, face)
	local rank = new("TextLabel", {
		Position = UDim2.fromOffset(62, 3), Size = UDim2.fromOffset(52, 30), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 26,
		TextColor3 = RANK_COLORS[i] or WHITE, TextXAlignment = Enum.TextXAlignment.Left, Text = "#" .. i,
	}, f)
	outline(rank, 2.5)
	local name = new("TextLabel", {
		Position = UDim2.fromOffset(i >= 10 and 118 or 104, 3), Size = UDim2.new(1, i >= 10 and -126 or -112, 0, 30), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack, TextSize = 23, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = "",
	}, f)
	outline(name, 2.5)
	local stat = new("TextLabel", {
		Position = UDim2.fromOffset(64, 31), Size = UDim2.new(1, -72, 0, 20), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 16,
		TextColor3 = Color3.fromRGB(226, 220, 236), TextXAlignment = Enum.TextXAlignment.Left, RichText = true, Text = "",
	}, f)
	outline(stat, 1.5)
	-- tu fila: se ilumina
	local me = new("UIGradient", {
		Enabled = false, Rotation = 0,
		Color = ColorSequence.new(accent:Lerp(WHITE, 0.3), WHITE),
		Transparency = NumberSequence.new(0.2, 0.6),
	}, f)
	return {frame = f, face = face, name = name, stat = stat, stroke = st, me = me, rank = i}
end

local function refresh(u)
	local b = u.board
	local ok, rows = pcall(HttpService.JSONDecode, HttpService, b:GetAttribute("Rows") or "[]")
	rows = ok and typeof(rows) == "table" and rows or {}
	u.sub.Text = b:GetAttribute("BoardSub") or ""
	u.empty.Visible = #rows == 0
	local mine
	for i, e in rows do
		local row = u.rows[i] or makeRow(u, i)
		u.rows[i] = row
		row.frame.Visible = true
		row.face.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(e.i or 0)
		row.name.Text = tostring(e.n or "?")
		row.stat.Text = tostring(e.s or "")
		local isMe = e.i == player.UserId
		row.me.Enabled = isMe
		row.frame.BackgroundTransparency = isMe and 0.35 or 0.55
		if isMe then
			row.frame.BackgroundColor3 = u.accent:Lerp(Color3.new(0, 0, 0), 0.55)
			mine = i
		else
			row.frame.BackgroundColor3 = Color3.new(0, 0, 0)
		end
	end
	for i = #rows + 1, #u.rows do
		u.rows[i].frame.Visible = false
	end
	-- abajo: tu puesto y, si hay más de lo que cabe, el aviso de que se puede desplazar
	if mine then
		u.you.Text = ("Your rank: <font color=\"#FFD43C\">#%d</font>"):format(mine)
	elseif #rows > 0 then
		u.you.Text = ("Your rank: not in the top %d yet"):format(#rows)
	else
		u.you.Text = ""
	end
	u.more.Visible = u.list.AbsoluteCanvasSize.Y > u.list.AbsoluteWindowSize.Y + 4
end

local function build(b, panel)
	local accent = b:GetAttribute("Accent") or WHITE
	local g = new("SurfaceGui", {
		Name = "Ranking_" .. b.Name, Adornee = panel, Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 50,
		LightInfluence = 0, Brightness = 1.15, MaxDistance = 140, ZOffset = 1, ResetOnSpawn = false,
	}, playerGui)
	-- oscurece un poco los tablones por detrás del texto
	local shade = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0}, g)
	new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.25, 0.55), NumberSequenceKeypoint.new(1, 0.35),
	})}, shade)
	-- título entre dos iconos y el mes
	local iconName = b:GetAttribute("BoardIcon") or "trophy"
	local iconColor = iconName == "trophy" and WHITE or accent:Lerp(WHITE, 0.25)
	local head = new("Frame", {Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 58), BackgroundTransparency = 1}, g)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
	}, head)
	icon(iconName, {Size = UDim2.fromOffset(46, 46), LayoutOrder = 1, ImageColor3 = iconColor}, head)
	local title = new("TextLabel", {
		Size = UDim2.fromOffset(0, 58), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, TextSize = 38,
		TextColor3 = WHITE, Text = b:GetAttribute("BoardTitle") or "", LayoutOrder = 2,
	}, head)
	new("UIPadding", {PaddingTop = UDim.new(0, 6)}, title)
	outline(title, 3.5)
	new("UIGradient", {Rotation = 90, Color = ColorSequence.new(WHITE, accent:Lerp(WHITE, 0.55))}, title)
	icon(iconName, {Size = UDim2.fromOffset(46, 46), LayoutOrder = 3, ImageColor3 = iconColor}, head)
	local sub = new("TextLabel", {
		Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 24,
		TextColor3 = WHITE, Text = "",
	}, g)
	outline(sub, 2.5)
	-- la lista que se desplaza
	local list = new("ScrollingFrame", {
		Name = "List", Position = UDim2.fromOffset(16, HEAD_H), Size = UDim2.new(1, -24, 1, -(HEAD_H + FOOT_H + 6)), BackgroundTransparency = 1,
		BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 8, ScrollBarImageColor3 = accent:Lerp(WHITE, 0.3), ScrollBarImageTransparency = 0.15,
		VerticalScrollBarInset = Enum.ScrollBarInset.None, ElasticBehavior = Enum.ElasticBehavior.Always, Active = true,
	}, g)
	new("UIListLayout", {Padding = UDim.new(0, ROW_GAP), SortOrder = Enum.SortOrder.LayoutOrder}, list)
	new("UIPadding", {PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4)}, list)
	local empty = new("TextLabel", {
		Position = UDim2.fromOffset(20, 130), Size = UDim2.new(1, -40, 0, 120), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 26,
		TextColor3 = WHITE, TextWrapped = true, Visible = false,
		Text = b:GetAttribute("BoardKind") == "Level" and "Nobody yet...\nBe the first!" or "Nobody yet this month...\nBe the first!",
	}, g)
	outline(empty, 2.5)
	-- pie: tu puesto y "scroll"
	local foot = corner(new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -32, 0, FOOT_H - 6), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
	}, g), 10)
	new("UIStroke", {Color = accent, Thickness = 1.5, Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, foot)
	local you = new("TextLabel", {
		Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -130, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 19,
		TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, RichText = true, TextTruncate = Enum.TextTruncate.AtEnd, Text = "",
	}, foot)
	outline(you, 2)
	local more = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Size = UDim2.new(0, 116, 1, 0), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = accent:Lerp(WHITE, 0.45), TextXAlignment = Enum.TextXAlignment.Right,
		Text = "SCROLL ▼", Visible = false,
	}, foot)
	outline(more, 1.5)
	-- el aviso de "scroll" se mueve un poco para que se note
	task.spawn(function()
		while more.Parent do
			if more.Visible then
				TweenService:Create(more, TweenInfo.new(0.6, Enum.EasingStyle.Sine), {Position = UDim2.new(1, -10, 0, 3)}):Play()
				task.wait(0.6)
				TweenService:Create(more, TweenInfo.new(0.6, Enum.EasingStyle.Sine), {Position = UDim2.new(1, -10, 0, -1)}):Play()
			end
			task.wait(0.6)
		end
	end)

	local u = {board = b, gui = g, panel = panel, accent = accent, list = list, sub = sub, empty = empty, you = you, more = more, rows = {}, conns = {}}
	-- arriba del todo: "SCROLL ▼"; abajo del todo: "▲ TOP"
	table.insert(u.conns, list:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		local bottom = list.CanvasPosition.Y >= list.AbsoluteCanvasSize.Y - list.AbsoluteWindowSize.Y - 4
		more.Text = bottom and "▲ TOP" or "SCROLL ▼"
	end))
	table.insert(u.conns, list:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function()
		more.Visible = list.AbsoluteCanvasSize.Y > list.AbsoluteWindowSize.Y + 4
	end))
	for _, attr in {"Rows", "BoardSub"} do
		table.insert(u.conns, b:GetAttributeChangedSignal(attr):Connect(function()
			refresh(u)
		end))
	end
	refresh(u)
	return u
end

local function unbuild(b)
	local u = built[b]
	if u then
		for _, c in u.conns do
			c:Disconnect()
		end
		u.gui:Destroy()
		built[b] = nil
	end
end

while true do
	local mapa = workspace:FindFirstChild("Mapa")
	local plaza = mapa and mapa:FindFirstChild("Plaza")
	local boards = plaza and plaza:FindFirstChild("Rankings")
	-- los que ya no están (o cambiaron de panel por el streaming)
	for b, u in built do
		if not b:IsDescendantOf(workspace) or not u.panel:IsDescendantOf(b) then
			unbuild(b)
		end
	end
	for _, b in boards and boards:GetChildren() or {} do
		local panel = b:FindFirstChild("Panel")
		if panel and panel:IsA("BasePart") and b:GetAttribute("BoardKind") and not built[b] then
			built[b] = build(b, panel)
		end
	end
	task.wait(1)
end
