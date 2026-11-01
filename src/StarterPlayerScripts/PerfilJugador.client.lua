-- Perfil de otro jugador: al pasar el ratón por encima de otro jugador se ilumina (con "Click to view profile") y al
-- pulsarlo se abre a la derecha un panel con su nombre, su nivel, sus monedas, sus estadísticas, su casa y su equipo
-- del Tower Defense (cada tropa con su skin, su nivel y sus estrellas). Botones: ir a su casa y, para los admins,
-- abrir el panel de admin con ese jugador ya elegido.
-- Todo sale de lo que el servidor ya replica: atributos del jugador (PXP, Loadout, XP_<tipo>, Star_<tipo>, Home,
-- Visitors, EndlessBest, Skin_<tipo>) y sus leaderstats (Coins, Scared).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local Config = require(RS:WaitForChild("Config"))
local TD = require(RS:WaitForChild("TowerDefense"))
local Remote = RS:WaitForChild("Remote")
local UI = require(script.Parent:WaitForChild("UI"))
local player = Players.LocalPlayer
local new = UI.new

local FONT = UI.HUD_FONT
local BG = Color3.fromRGB(22, 20, 30)
local LINE = Color3.fromRGB(90, 84, 110)
local BLUE = Color3.fromRGB(86, 168, 255)
local LEFT = Enum.TextXAlignment.Left
local W = 330

local function text(props, parent)
	props.BackgroundTransparency = 1
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or UI.WHITE
	local l = new("TextLabel", props, parent)
	UI.hudStroke(l, (props.TextSize or 14) >= 18 and 2 or 1.5)
	return l
end

local function separator(order, parent)
	new("Frame", {Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = LINE, BackgroundTransparency = 0.4, BorderSizePixel = 0, LayoutOrder = order}, parent)
end

---------- Panel ----------
local panel = UI.round(new("Frame", {
	Name = "PlayerProfile", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.45, 0), Size = UDim2.fromOffset(W, 0),
	AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = BG, BackgroundTransparency = 0.12, Visible = false, ZIndex = 30, Active = true,
}, UI.gui), 12)
UI.stroke(panel, UI.INK, 2.5)
local pop = new("UIScale", {}, panel)
new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center}, panel)
new("UIPadding", {PaddingBottom = UDim.new(0, 14)}, panel)

-- cabecera: degradado con su cara a la derecha, su nombre y @usuario
local header = UI.round(new("Frame", {Size = UDim2.new(1, 0, 0, 78), BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = 1, ZIndex = 30}, panel), 12)
UI.gradient(header, Color3.fromRGB(110, 96, 140), Color3.fromRGB(46, 40, 62))
local face = new("ImageLabel", {
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -44, 0.5, 0), Size = UDim2.fromOffset(70, 70), BackgroundTransparency = 1, Image = "", ZIndex = 31,
}, header)
local nameText = text({Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -140, 0, 30), TextSize = 24, TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd, Text = "", ZIndex = 32}, header)
local userText = text({Position = UDim2.fromOffset(14, 40), Size = UDim2.new(1, -140, 0, 18), TextSize = 14, TextColor3 = UI.MUTED, TextXAlignment = LEFT, Text = "", ZIndex = 32}, header)
local levelChip = UI.chip("", BLUE, {Position = UDim2.fromOffset(14, 58), ZIndex = 32, TextSize = 12, Size = UDim2.fromOffset(0, 18)}, header)
local close = UI.round(new("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = Color3.fromRGB(60, 54, 76),
	BackgroundTransparency = 0.2, Font = FONT, TextSize = 16, TextColor3 = UI.WHITE, Text = "X", AutoButtonColor = true, ZIndex = 33,
}, header), 8)

-- estadísticas (cuadros con icono, número y nombre)
text({Size = UDim2.new(1, 0, 0, 22), TextSize = 18, Text = "Stats", LayoutOrder = 2, ZIndex = 31}, panel)
local statGrid = new("Frame", {Size = UDim2.new(1, -24, 0, 112), BackgroundTransparency = 1, LayoutOrder = 3, ZIndex = 31}, panel)
new("UIGridLayout", {CellSize = UDim2.new(0.5, -4, 0, 52), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder}, statGrid)
local stats = {}
local function statBox(key, icon, label, color, order)
	local box = UI.round(new("Frame", {BackgroundColor3 = Color3.fromRGB(40, 36, 54), BackgroundTransparency = 0.2, LayoutOrder = order, ZIndex = 31}, statGrid), 8)
	UI.icon(icon, {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0), Size = UDim2.fromOffset(34, 34), ZIndex = 32}, box)
	stats[key] = text({Position = UDim2.fromOffset(44, 6), Size = UDim2.new(1, -48, 0, 24), TextSize = 19, TextColor3 = color, TextXAlignment = LEFT, Text = "0", ZIndex = 32}, box)
	text({Position = UDim2.fromOffset(44, 29), Size = UDim2.new(1, -48, 0, 16), TextSize = 12, TextColor3 = UI.MUTED, TextXAlignment = LEFT, Text = label, ZIndex = 32}, box)
end
statBox("level", "star", "Level", BLUE, 1)
statBox("coins", "coin", "Coins", UI.GOLD, 2)
statBox("scared", "ghost", "Visitors scared", UI.WHITE, 3)
statBox("found", "book", "Index", Color3.fromRGB(110, 235, 200), 4)

local infoHolder = new("Frame", {Size = UDim2.new(1, -24, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 4, ZIndex = 31}, panel)
new("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, infoHolder)
local houseText = text({Size = UDim2.new(1, 0, 0, 20), TextSize = 14, TextXAlignment = LEFT, RichText = true, Text = "", LayoutOrder = 1, ZIndex = 31}, infoHolder)
local endlessText = text({Size = UDim2.new(1, 0, 0, 20), TextSize = 14, TextXAlignment = LEFT, RichText = true, Text = "", LayoutOrder = 2, ZIndex = 31}, infoHolder)

separator(5, panel)

-- equipo del Tower Defense: círculos con la tropa (su skin), su nivel y sus estrellas
text({Size = UDim2.new(1, 0, 0, 22), TextSize = 18, Text = "Tower Equipment", LayoutOrder = 6, ZIndex = 31}, panel)
local SLOT = 78
local slotGrid = new("Frame", {Size = UDim2.fromOffset(SLOT * 3 + 24, SLOT * 2 + 34), BackgroundTransparency = 1, LayoutOrder = 7, ZIndex = 31}, panel)
new("UIGridLayout", {
	CellSize = UDim2.fromOffset(SLOT, SLOT + 10), CellPadding = UDim2.fromOffset(12, 6), SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
}, slotGrid)

-- botones de abajo
local buttons = new("Frame", {Size = UDim2.new(1, -24, 0, 44), BackgroundTransparency = 1, LayoutOrder = 8, ZIndex = 31}, panel)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, buttons)
local visitBtn = UI.button({Size = UDim2.fromOffset(150, 42), BackgroundColor3 = UI.BUY, Text = "Visit house", TextSize = 17, LayoutOrder = 1, ZIndex = 32}, buttons)
local adminBtn = UI.button({Size = UDim2.fromOffset(130, 42), BackgroundColor3 = UI.RED, Text = "Admin", TextSize = 17, LayoutOrder = 2, ZIndex = 32, Visible = Config.isAdmin(player)}, buttons)

---------- Rellenar ----------
local target -- el jugador que se está viendo
local function visitorsFound(p)
	local n = 0
	for _ in string.gmatch(p:GetAttribute("Visitors") or "", "[^,]+") do
		n += 1
	end
	return n
end
local function stat(p, name)
	local ls = p:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild(name)
	return v and v.Value or 0
end

local function buildSlots(p)
	for _, c in slotGrid:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local team = TD.loadout(p)
	for i = 1, TD.SLOTS do
		local t = team[i]
		local cell = new("Frame", {BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 31}, slotGrid)
		local circle = UI.round(new("Frame", {
			Size = UDim2.fromOffset(SLOT, SLOT), BackgroundColor3 = Color3.fromRGB(70, 66, 84), BackgroundTransparency = 0.25, ZIndex = 31,
		}, cell), UDim.new(1, 0))
		local edge = UI.stroke(circle, Color3.fromRGB(150, 145, 165), 2):FindFirstChildOfClass("UIStroke")
		if t and Config.Scares[t] then
			local color = Config.Categories[Config.Scares[t].cat].color
			edge.Color = color:Lerp(UI.WHITE, 0.25)
			local vp = UI.viewport(Config.skinFor(p, t), circle, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.92, 0.92), ZIndex = 32}, true)
			UI.round(vp, UDim.new(1, 0))
			if vp.CurrentCamera then
				vp.CurrentCamera.FieldOfView = 30
			end
			local star = Config.starOf(p, t)
			local label = "Lv " .. Config.troopLevel(p, t) .. (star > 0 and (" " .. string.rep("★", star)) or "")
			local lv = text({
				AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 2), Size = UDim2.new(1, 10, 0, 16), TextSize = 13,
				TextColor3 = star > 0 and Config.STAR_COLORS[star] or UI.WHITE, Text = label, ZIndex = 34,
			}, cell)
			lv.TextTruncate = Enum.TextTruncate.AtEnd
			-- nombre al pasar el ratón
			local hit = new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 35}, circle)
			hit.MouseEnter:Connect(function()
				lv.Text = Config.Scares[t].name
			end)
			hit.MouseLeave:Connect(function()
				lv.Text = label
			end)
		else
			circle.BackgroundTransparency = 0.6
			text({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 0.3), TextSize = 13, TextColor3 = UI.MUTED, Text = "Empty", ZIndex = 32}, circle)
		end
	end
end

local function refresh()
	local p = target
	if not (p and p.Parent) then
		return
	end
	local lv = Config.playerLevel(p)
	nameText.Text = p.DisplayName
	userText.Text = "@" .. p.Name
	levelChip.Text = "LEVEL " .. lv
	stats.level.Text = tostring(lv)
	stats.coins.Text = UI.fmt(stat(p, "Coins"))
	stats.scared.Text = UI.fmt(stat(p, "Scared"))
	stats.found.Text = ("%d / %d"):format(visitorsFound(p), #Config.Visitors)
	local home = Config.house(p:GetAttribute("Home")) or Config.Houses[1]
	houseText.Text = ('🏠 House: <font color="#ffd446">%s</font>'):format(home.name)
	local best = p:GetAttribute("EndlessBest") or 0
	endlessText.Text = best > 0 and ('♾ Endless best: <font color="#56a8ff">wave %d</font>'):format(best // 100) or '♾ Endless best: <font color="#cec2e8">—</font>'
end

local loadToken = 0
local function open(p)
	target = p
	loadToken += 1
	local token = loadToken
	face.Image = ""
	task.spawn(function()
		local ok, img = pcall(Players.GetUserThumbnailAsync, Players, p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		if ok and token == loadToken then
			face.Image = img
		end
	end)
	refresh()
	buildSlots(p)
	visitBtn.Visible = p:GetAttribute("Plot") ~= nil
	if not panel.Visible then
		panel.Visible = true
		pop.Scale = 0.85
		TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Back), {Scale = 1}):Play()
	end
	UI.sound("Tab")
end
local function hide()
	panel.Visible = false
	target = nil
end
close.Activated:Connect(hide)
visitBtn.Activated:Connect(function()
	if target then
		if player:GetAttribute("Mode") then
			return UI.toast("Go outside first", UI.ORANGE, "door")
		end
		Remote:FireServer("VisitPlayer", target.UserId)
		hide()
	end
end)
adminBtn.Activated:Connect(function()
	local ev = script.Parent:FindFirstChild("AdminOpen")
	if target and ev then
		ev:Fire(target)
		hide()
	end
end)

-- mientras está abierto se va actualizando (monedas, nivel...) y el equipo si lo cambia
task.spawn(function()
	local lastLoadout
	while true do
		task.wait(1)
		if panel.Visible then
			if not (target and target.Parent) then
				hide()
			else
				refresh()
				local lo = target:GetAttribute("Loadout")
				if lo ~= lastLoadout then
					lastLoadout = lo
					buildSlots(target)
				end
			end
		end
	end
end)

---------- Elegir a un jugador con el ratón / el dedo ----------
local function canPick()
	return player:GetAttribute("Mode") == nil and player:GetAttribute("TDCash") == nil
end
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
-- pos: en coordenadas de pantalla (sin la barra de arriba de Roblox), como InputObject.Position
local function playerAt(pos)
	local cam = workspace.CurrentCamera
	local ray = cam:ScreenPointToRay(pos.X, pos.Y)
	params.FilterDescendantsInstances = {player.Character}
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	local inst = hit and hit.Instance
	while inst and inst ~= workspace do
		if inst:IsA("Model") then
			local p = Players:GetPlayerFromCharacter(inst)
			if p then
				return p ~= player and p or nil, inst
			end
		end
		inst = inst.Parent
	end
	return nil
end

-- brillo y cartel encima del jugador que tiene el ratón encima
local highlight = new("Highlight", {
	FillColor = Color3.fromRGB(120, 170, 255), FillTransparency = 0.7, OutlineColor = UI.WHITE, OutlineTransparency = 0,
	DepthMode = Enum.HighlightDepthMode.Occluded, Enabled = false,
}, player:WaitForChild("PlayerGui"))
local tag = new("BillboardGui", {Size = UDim2.fromOffset(170, 26), StudsOffset = Vector3.new(0, 3.6, 0), AlwaysOnTop = true, Enabled = false}, player.PlayerGui)
local tagText = UI.round(new("TextLabel", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = BG, BackgroundTransparency = 0.2, Font = UI.SMALL, TextSize = 13, TextColor3 = UI.WHITE,
	Text = "Click to view profile",
}, tag), 8)
UI.stroke(tagText, UI.INK, 1.5)

local hovered
local function setHover(char)
	if char == hovered then
		return
	end
	hovered = char
	highlight.Adornee = char
	highlight.Enabled = char ~= nil
	tag.Adornee = char and char:FindFirstChild("Head")
	tag.Enabled = char ~= nil and tag.Adornee ~= nil
end

local nextHover = 0
RunService.RenderStepped:Connect(function()
	if not UserInputService.MouseEnabled or os.clock() < nextHover then
		return
	end
	nextHover = os.clock() + 0.08
	if not canPick() then
		return setHover(nil)
	end
	local inset = GuiService:GetGuiInset()
	local p, char = playerAt(UserInputService:GetMouseLocation() - inset)
	setHover(p and char or nil)
end)

-- clic (sin arrastrar: arrastrar con el botón derecho/izquierdo es mover la cámara)
local downAt
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		downAt = Vector2.new(input.Position.X, input.Position.Y)
	end
end)
UserInputService.InputEnded:Connect(function(input, processed)
	if not (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		return
	end
	local start = downAt
	downAt = nil
	if processed or not start or not canPick() then
		return
	end
	local pos = Vector2.new(input.Position.X, input.Position.Y)
	if (pos - start).Magnitude > 12 then
		return
	end
	local p = playerAt(pos)
	if p then
		open(p)
	end
end)

player:GetAttributeChangedSignal("Mode"):Connect(function()
	if player:GetAttribute("Mode") then
		hide()
		setHover(nil)
	end
end)
