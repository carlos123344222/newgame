-- Index (botón "Index" del menú y pestaña Index de Troops / Shop): los visitantes. (Los sustos ya no salen aquí: los
-- que tienes están en Troops y todos, con cómo conseguirlos, en la Shop.) Todos los tipos de visitante, ordenados por rareza,
-- con su retrato en 3D vestido (Outfits), cuántos has asustado y cuánto pagan. Los que aún no has asustado salen
-- en sombra. Al pulsar uno se abre su ficha: estadísticas, descripción, los materiales en los que te ha llegado
-- (Config.Variants) y un visor 3D grande que gira solo y se arrastra. También los avisos: llega un visitante poco
-- común o mejor a tu casa, alguien recibe uno legendario o mítico, descubres uno nuevo o un material nuevo. Y el
-- arcoíris de los visitantes míticos (cada cliente lo anima).
-- Datos: Config.Visitors / Config.Rarities y los atributos del jugador Visitors ("id:veces,...") y VisitorMats
-- ("id.material:veces,..."), que pone Juego.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local UIS = game:GetService("UserInputService")

local Config = require(RS:WaitForChild("Config"))
local Outfits = require(RS:WaitForChild("Outfits"))
local Assets = RS:WaitForChild("Assets")
local Remote = RS:WaitForChild("Remote")
local UI = require(script.Parent:WaitForChild("UI"))
local player = Players.LocalPlayer
local new = UI.new

local ACCENT = Color3.fromRGB(60, 190, 210)
local LEFT = Enum.TextXAlignment.Left
local RIGHT = Enum.TextXAlignment.Right
local BLACK = Color3.new(0, 0, 0)
local MUTED = UI.MUTED

local function label(props, parent)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or UI.FONT
	props.TextColor3 = props.TextColor3 or UI.WHITE
	return new("TextLabel", props, parent)
end

-- Buscador junto a la barra de progreso: llama a onChange con el texto en minúsculas
local function searchBox(page, accent, onChange)
	local box = UI.round(new("Frame", {Position = UDim2.fromOffset(752, 73), Size = UDim2.fromOffset(234, 28), BackgroundColor3 = UI.DARK, BackgroundTransparency = 0.15}, page), 14)
	UI.stroke(box, accent, 2, 0.25)
	local tb = new("TextBox", {
		Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0), BackgroundTransparency = 1, Font = UI.FONT, TextSize = 15, TextColor3 = UI.WHITE,
		PlaceholderText = "Search...", PlaceholderColor3 = MUTED, Text = "", ClearTextOnFocus = false, TextXAlignment = LEFT,
	}, box)
	tb:GetPropertyChangedSignal("Text"):Connect(function()
		onChange(tb.Text:lower())
	end)
end

local function matches(q, name)
	return q == "" or name:lower():find(q, 1, true) ~= nil
end

local function rarityOf(v)
	return Config.Rarities[Config.RarityIndex[v.rarity]]
end

-- Cuántas veces has asustado a cada tipo
local function counts()
	local c = {}
	for pair in string.gmatch(player:GetAttribute("Visitors") or "", "[^,]+") do
		local id, n = pair:match("^(%w+):(%d+)$")
		if id then
			c[id] = tonumber(n)
		end
	end
	return c
end

-- Materiales de cada tipo: mats[id][material] = veces
local function matCounts()
	local m = {}
	for pair in string.gmatch(player:GetAttribute("VisitorMats") or "", "[^,]+") do
		local id, mat, n = pair:match("^(%w+)%.(%w+):(%d+)$")
		if id then
			m[id] = m[id] or {}
			m[id][mat] = tonumber(n)
		end
	end
	return m
end

-- Los que ya son de una materia (Golden, Diamond) o brillan (arcoíris, cósmico, el secreto) nunca llegan de otra
local function canVary(v)
	return not (v.variant or v.rainbow or v.cosmic or v.secret)
end

local function matsOwned(mats, v)
	local n = 0
	for _ in mats[v.id] or {} do
		n += 1
	end
	return n
end

-- El material más valioso que tienes de ese visitante (el color de su insignia)
local function bestMat(mats, v)
	local best
	for id in mats[v.id] or {} do
		local m = Config.VariantById[id]
		if m and (not best or m.mult > best.mult) then
			best = m
		end
	end
	return best
end

---------- Retrato 3D de un visitante (vestido como en el juego; variant: hecho de esa materia) ----------
local function portrait(v, parent, props, locked, variant)
	local vp = new("ViewportFrame", props, parent)
	vp.BackgroundTransparency = 1
	vp.Ambient = locked and BLACK or Color3.fromRGB(200, 190, 215)
	vp.LightColor = locked and BLACK or Color3.fromRGB(255, 245, 230)
	vp.LightDirection = Vector3.new(-0.6, -0.8, -1)
	local rig = Assets.TDHunter:Clone()
	for _, d in rig:GetDescendants() do
		if d:IsA("Humanoid") then
			d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		elseif d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	local ok = pcall(Outfits.dress, rig, v, Random.new(#v.id))
	if not ok then
		warn("VisitorBook: no se pudo vestir a " .. v.id)
	end
	if variant and not locked then
		pcall(Outfits.applyVariant, rig, variant)
	end
	for _, d in rig:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			-- (en un ViewportFrame no hay entorno que reflejar: el reflejo solo lo lava a blanco)
			d.Reflectance = 0
			if locked then
				d.Color, d.Material = BLACK, Enum.Material.SmoothPlastic
				if d:IsA("MeshPart") then
					d.TextureID = ""
				end
			end
		elseif d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Fire") or d:IsA("SurfaceAppearance") then
			if locked or not d:IsA("SurfaceAppearance") then
				d:Destroy()
			end
		end
	end
	rig.Parent = vp
	local cam = new("Camera", {FieldOfView = 30}, vp)
	vp.CurrentCamera = cam
	local cf, size = rig:GetBoundingBox()
	local focus = cf.Position + Vector3.new(0, size.Y * 0.08, 0)
	local root = rig:FindFirstChild("HumanoidRootPart")
	local look = root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
	local right = root and root.CFrame.RightVector or Vector3.new(1, 0, 0)
	cam.CFrame = CFrame.lookAt(focus + look * size.Y * 2.15 + right * size.Y * 0.55 + Vector3.new(0, size.Y * 0.25, 0), focus)
	return vp, rig
end

---------- Ventana ----------
local gui = new("ScreenGui", {Name = "VisitorBook", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, player:WaitForChild("PlayerGui"))
local scale = new("UIScale", {}, gui)
local function rescale()
	local s = workspace.CurrentCamera.ViewportSize
	scale.Scale = math.clamp(math.min(s.X / 1100, s.Y / 790), 0.5, 1.15)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()
local dim = new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0.45, AutoButtonColor = false, Text = ""}, gui)
local win, close = UI.window({Name = "BookWindow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53), Size = UDim2.fromOffset(1010, 630), title = "INDEX", icon = "book", accent = ACCENT}, gui)
-- los clics en los huecos de la ventana no la atraviesan (si no, llegaban al fondo oscuro y la cerraban)
new("TextButton", {Name = "Swallow", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = -3}, win)
local visitorsPage = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1}, win)
local sub = label({Position = UDim2.fromOffset(26, 50), Size = UDim2.fromOffset(940, 20), TextSize = 15, TextColor3 = MUTED, TextXAlignment = LEFT, Text = ""}, visitorsPage)
-- barra de progreso de la colección
local progBack, progFill = UI.bar({Position = UDim2.fromOffset(24, 76), Size = UDim2.fromOffset(716, 22)}, visitorsPage, ACCENT)
local progText = label({Size = UDim2.fromScale(1, 1), TextSize = 14, TextStrokeTransparency = 0, Text = "", ZIndex = progBack.ZIndex + 3}, progBack)
-- leyenda: probabilidad de cada rareza
local legend = new("Frame", {Position = UDim2.fromOffset(24, 106), Size = UDim2.fromOffset(960, 28), BackgroundTransparency = 1}, visitorsPage)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Wraps = true, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, legend)
local legendChips = {}
for i, r in Config.Rarities do
	local pct = r.weight >= 1 and ("%g%%"):format(r.weight) or ("%.2g%%"):format(r.weight)
	legendChips[r.id] = UI.chip(("%s %s"):format(r.name, pct), r.color:Lerp(BLACK, 0.15), {TextSize = 12, LayoutOrder = i}, legend)
end
local grid = new("ScrollingFrame", {
	Position = UDim2.fromOffset(20, 140), Size = UDim2.fromOffset(970, 470), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 7,
	ScrollBarImageColor3 = ACCENT, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
}, visitorsPage)
new("UIGridLayout", {CellSize = UDim2.fromOffset(129, 156), CellPadding = UDim2.fromOffset(8, 10), SortOrder = Enum.SortOrder.LayoutOrder}, grid)
new("UIPadding", {PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8)}, grid)

---------- Ficha de un visitante (se abre al pulsarlo) ----------
local detailPage = new("Frame", {Name = "Detail", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false}, win)

-- Caja de sección: fondo oscuro con contorno y su título en una franja arriba
local function section(title, pos, size, parent)
	local box = UI.round(new("Frame", {Position = pos, Size = size, BackgroundColor3 = UI.DARK, BackgroundTransparency = 0.3, ZIndex = 3}, parent or detailPage), 16)
	UI.stroke(box, UI.INK, 3)
	if title then
		local strip = UI.round(new("Frame", {Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 30), BackgroundColor3 = UI.PANEL, BackgroundTransparency = 0.1, ZIndex = 3}, box), 10)
		UI.gradient(strip, Color3.new(1, 1, 1), Color3.fromRGB(190, 185, 205))
		label({Name = "Title", Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), Font = UI.TITLE, TextSize = 19, TextStrokeTransparency = 0, TextXAlignment = LEFT, Text = title, ZIndex = 4}, strip)
		new("UIPadding", {PaddingTop = UDim.new(0, 3)}, strip)
		box:SetAttribute("Strip", true)
		return box, strip
	end
	return box
end

-- Cabecera: retrato pequeño, nombre, insignias y el botón de volver
local head = section(nil, UDim2.fromOffset(22, 52), UDim2.fromOffset(540, 100))
local headThumb = UI.stage(head, ACCENT, {Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(80, 80), ZIndex = 4})
local dName = label({Position = UDim2.fromOffset(104, 12), Size = UDim2.fromOffset(280, 38), Font = UI.TITLE, TextSize = 32, TextXAlignment = LEFT, TextStrokeTransparency = 0, TextScaled = true, Text = "", ZIndex = 5}, head)
new("UITextSizeConstraint", {MaxTextSize = 32}, dName)
local chipRow = new("Frame", {Position = UDim2.fromOffset(104, 58), Size = UDim2.fromOffset(300, 26), BackgroundTransparency = 1, ZIndex = 5}, head)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center}, chipRow)
local dRarity = UI.chip("", ACCENT, {TextSize = 14, LayoutOrder = 1, ZIndex = 5}, chipRow)
local dTimes = UI.chip("", UI.DARK, {TextSize = 14, LayoutOrder = 2, ZIndex = 5}, chipRow)
local back = UI.iconButton({
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(128, 54), BackgroundColor3 = UI.ORANGE,
	Font = UI.TITLE, TextSize = 22, Text = "BACK", ZIndex = 5,
}, head, "arrowL")

-- Estadísticas: 4 casillas con icono, nombre y valor
local statsBox = section("STATS", UDim2.fromOffset(22, 162), UDim2.fromOffset(540, 128))
local statGrid = new("Frame", {Position = UDim2.fromOffset(10, 46), Size = UDim2.new(1, -20, 0, 74), BackgroundTransparency = 1, ZIndex = 4}, statsBox)
new("UIGridLayout", {CellSize = UDim2.new(0.5, -4, 0, 34), CellPadding = UDim2.fromOffset(8, 6), SortOrder = Enum.SortOrder.LayoutOrder}, statGrid)
local function statTile(icon, name, color, order)
	local f = UI.round(new("Frame", {BackgroundColor3 = UI.PANEL, BackgroundTransparency = 0.35, LayoutOrder = order, ZIndex = 4}, statGrid), 10)
	UI.icon(icon, {Position = UDim2.fromOffset(5, 2), Size = UDim2.fromOffset(30, 30), ZIndex = 5}, f)
	label({Position = UDim2.fromOffset(40, 0), Size = UDim2.new(0.5, -40, 1, 0), Font = UI.SMALL, TextSize = 13, TextColor3 = MUTED, TextXAlignment = LEFT, Text = name, ZIndex = 5}, f)
	return label({AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Size = UDim2.new(0.6, 0, 1, 0), TextSize = 17, TextColor3 = color, TextStrokeTransparency = 0, TextXAlignment = RIGHT, Text = "", ZIndex = 5}, f)
end
local dCoins = statTile("coins", "Coins", UI.GOLD, 1)
local dChance = statTile("star", "Chance", ACCENT:Lerp(UI.WHITE, 0.3), 2)
local dBrave = statTile("shield", "Courage", Color3.fromRGB(150, 200, 255), 3)
local dSpeed = statTile("run", "Speed", Color3.fromRGB(255, 170, 120), 4)

-- Descripción
local descBox = section("DESCRIPTION", UDim2.fromOffset(22, 300), UDim2.fromOffset(540, 70))
local dDesc = label({Position = UDim2.fromOffset(18, 42), Size = UDim2.new(1, -36, 0, 24), Font = UI.SMALL, TextScaled = true, TextColor3 = UI.WHITE, TextWrapped = true, TextXAlignment = LEFT, TextYAlignment = Enum.TextYAlignment.Center, Text = "", ZIndex = 4}, descBox)
new("UITextSizeConstraint", {MaxTextSize = 14}, dDesc)

-- Materiales: uno por cada materia (y el normal); los que te han tocado, con su retrato hecho de esa materia
local matBox, matStrip = section("MATERIALS", UDim2.fromOffset(22, 380), UDim2.fromOffset(540, 230))
local matBack, matFill = UI.bar({AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, -1), Size = UDim2.fromOffset(170, 26), ZIndex = 4}, matStrip, UI.GEM)
local matText = label({Size = UDim2.fromScale(1, 1), Font = UI.TITLE, TextSize = 17, TextStrokeTransparency = 0, Text = "", ZIndex = matBack.ZIndex + 3}, matBack)
new("UIPadding", {PaddingTop = UDim.new(0, 2)}, matText)
local matGrid = new("Frame", {Position = UDim2.fromOffset(12, 44), Size = UDim2.new(1, -24, 0, 180), BackgroundTransparency = 1, ZIndex = 4}, matBox)
new("UIGridLayout", {CellSize = UDim2.fromOffset(80, 88), CellPadding = UDim2.fromOffset(7, 4), SortOrder = Enum.SortOrder.LayoutOrder}, matGrid)
local matNote = label({Position = UDim2.fromOffset(20, 60), Size = UDim2.new(1, -40, 0, 130), TextSize = 18, TextColor3 = MUTED, TextWrapped = true, Text = "", Visible = false, ZIndex = 4}, matBox)

-- Visor 3D grande: el visitante sobre un suelo de rejilla; gira solo y se arrastra para girarlo
local viewBox = section(nil, UDim2.fromOffset(574, 52), UDim2.fromOffset(414, 558))
local vStage = UI.stage(viewBox, ACCENT, {Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 1, -16), ZIndex = 4})
vStage.ClipsDescendants = true
local vMatChip = UI.chip("", ACCENT, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40), TextSize = 20, Size = UDim2.fromOffset(0, 34), ZIndex = 7}, vStage)
local vMult = label({AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -20, 0, 22), TextSize = 15, TextColor3 = UI.GOLD, TextStrokeTransparency = 0, Text = "", ZIndex = 7}, vStage)
local vHint = new("Frame", {Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 7}, vStage)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), VerticalAlignment = Enum.VerticalAlignment.Center}, vHint)
UI.icon("rotate", {Size = UDim2.fromOffset(24, 24), ImageTransparency = 0.2, ZIndex = 7}, vHint)
label({Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, Font = UI.SMALL, TextSize = 13, TextColor3 = MUTED, Text = "Drag to rotate", ZIndex = 7}, vHint)
local drag = new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 6}, vStage)

local cards = {}
local built = false
local focus
local focusSig
local selMat -- material que se ve en el visor (nil: el normal)
local matTiles = {}
local query = ""

local ORDER = {}
for _, v in Config.Visitors do
	table.insert(ORDER, v)
end
table.sort(ORDER, function(a, b)
	local ra, rb = Config.RarityIndex[a.rarity], Config.RarityIndex[b.rarity]
	if ra ~= rb then
		return ra < rb
	end
	return a.name < b.name
end)

-- Probabilidad de que el siguiente visitante sea este (rareza a tu nivel × 1/cuántos hay de esa rareza)
local function chanceOf(v)
	local n = 0
	for _, o in Config.Visitors do
		if o.rarity == v.rarity then
			n += 1
		end
	end
	return Config.rarityChances(Config.playerLevel(player), player:GetAttribute("LuckBoost"))[Config.RarityIndex[v.rarity]] / n
end

local function pct(x)
	return x >= 1 and ("%.1f%%"):format(x) or ("%.2g%%"):format(x)
end

---------- Visor ----------
local view = {yaw = 0.45, spin = 0.35}
local function buildViewer(v, mat, locked)
	for _, x in vStage:GetChildren() do
		if x:IsA("ViewportFrame") then
			x:Destroy()
		end
	end
	local vp, rig = portrait(v, vStage, {Name = "Big", Size = UDim2.fromScale(1, 1), ZIndex = 5}, locked, mat and mat.id)
	local cf, size = rig:GetBoundingBox()
	local bottom = cf.Position.Y - size.Y / 2
	local root = rig:FindFirstChild("HumanoidRootPart")
	local look = root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
	look = Vector3.new(look.X, 0, look.Z).Unit
	-- suelo: losa oscura con rejilla clara y un disco brillante del color del material / rareza bajo los pies
	local color = mat and mat.color or rarityOf(v).color
	local floor = new("Model", {Name = "Suelo"}, nil)
	local base = CFrame.new(cf.Position.X, bottom - 0.05, cf.Position.Z)
	new("Part", {Anchored = true, Size = Vector3.new(90, 0.1, 90), CFrame = base, Color = Color3.fromRGB(22, 16, 34), Material = Enum.Material.SmoothPlastic}, floor)
	for i = -22, 22 do
		local c = Color3.fromRGB(58, 44, 86)
		new("Part", {Anchored = true, Size = Vector3.new(0.05, 0.02, 90), CFrame = base * CFrame.new(i * 2, 0.06, 0), Color = c, Material = Enum.Material.SmoothPlastic}, floor)
		new("Part", {Anchored = true, Size = Vector3.new(90, 0.02, 0.05), CFrame = base * CFrame.new(0, 0.06, i * 2), Color = c, Material = Enum.Material.SmoothPlastic}, floor)
	end
	if not locked then
		local d = size.Y * 0.62
		new("Part", {
			Shape = Enum.PartType.Cylinder, Anchored = true, Size = Vector3.new(0.04, d, d), CFrame = base * CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color = color:Lerp(Color3.new(0, 0, 0), 0.25), Material = Enum.Material.SmoothPlastic, Transparency = 0.35,
		}, floor)
		new("Part", {
			Shape = Enum.PartType.Cylinder, Anchored = true, Size = Vector3.new(0.03, d * 1.35, d * 1.35), CFrame = base * CFrame.new(0, 0.07, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color = color:Lerp(Color3.new(0, 0, 0), 0.55), Material = Enum.Material.SmoothPlastic, Transparency = 0.6,
		}, floor)
	end
	floor.Parent = vp
	-- (siempre con luz: el que no has asustado ya es negro de por sí, y así se sigue viendo el suelo)
	vp.Ambient = Color3.fromRGB(170, 160, 190)
	vp.LightColor = Color3.fromRGB(255, 245, 230)
	view.cam = vp.CurrentCamera
	view.cam.FieldOfView = 34
	-- (encuadre: el visitante un poco por encima del centro, que abajo van el nombre del material y las monedas)
	view.center = cf.Position - Vector3.new(0, size.Y * 0.12, 0)
	view.look = look
	view.dist = size.Y * 2.75
	view.height = size.Y * 0.62
	view.yaw = 0.45
end

RunService.RenderStepped:Connect(function(dt)
	if not (gui.Enabled and detailPage.Visible and view.cam and view.cam.Parent) then
		return
	end
	if not view.dragging then
		view.yaw += dt * view.spin
	end
	local offset = CFrame.fromAxisAngle(Vector3.yAxis, view.yaw):VectorToWorldSpace(view.look * view.dist)
	view.cam.CFrame = CFrame.lookAt(view.center + offset + Vector3.new(0, view.height, 0), view.center)
end)
drag.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		view.dragging, view.lastX = true, input.Position.X
	end
end)
UIS.InputChanged:Connect(function(input)
	if view.dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		view.yaw -= (input.Position.X - view.lastX) * 0.012
		view.lastX = input.Position.X
	end
end)
UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		view.dragging = false
	end
end)

---------- Ficha ----------
local function showMat(v, mat, known)
	selMat = mat
	buildViewer(v, mat, not known)
	local r = rarityOf(v)
	local color = mat and mat.color or r.color
	vStage.BackgroundColor3 = color:Lerp(UI.DARK, 0.72)
	vStage.Glow.ImageColor3 = color:Lerp(UI.WHITE, 0.25)
	vMatChip.Text = not known and "???" or mat and string.upper(mat.name) or string.upper(v.variant and (Config.VariantById[v.variant] or r).name or "Normal")
	vMatChip.BackgroundColor3 = color:Lerp(BLACK, 0.15)
	vMult.Text = known and ("Coins x%g"):format((v.mult or 1) * (mat and mat.mult or 1)) or ""
	for id, t in matTiles do
		local on = (mat and mat.id or "Normal") == id
		t.stroke.Color = on and UI.WHITE or UI.INK
		t.stroke.Thickness = on and 4.5 or 3
	end
end

local function matTile(v, mat, n, have, order, known)
	local color = mat and mat.color or rarityOf(v).color
	local t, parts = UI.card(matGrid, order, color, {Class = "TextButton", AutoButtonColor = false, Text = "", ZIndex = 4})
	parts.stroke.Thickness = 3
	-- (el retrato ocupa toda la casilla; el nombre va encima, abajo)
	local st = UI.stage(t, color, {Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), ZIndex = 4})
	if have then
		portrait(v, st, {Size = UDim2.fromScale(1, 1), ZIndex = 5}, not known, mat and mat.id)
	else
		st.BackgroundColor3 = color:Lerp(UI.DARK, 0.85)
		st.Glow.ImageTransparency = 0.8
		UI.icon("lock", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(32, 32), ZIndex = 6}, st)
	end
	local nameLabel = label({
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 3, 1, -5), Size = UDim2.new(1, -6, 0, 18), Font = UI.TITLE, TextSize = 15, TextStrokeTransparency = 0, TextScaled = true,
		TextColor3 = have and color:Lerp(UI.WHITE, 0.35) or MUTED, Text = mat and mat.name or "Normal", ZIndex = 7,
	}, t)
	new("UITextSizeConstraint", {MaxTextSize = 15}, nameLabel)
	if mat and have then
		UI.chip(("x%d"):format(n), UI.DARK, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, 2), TextSize = 11, Size = UDim2.fromOffset(0, 18), ZIndex = 7}, t)
	end
	UI.press(t, 1.06)
	t.Activated:Connect(function()
		if have then
			UI.sound("Tab")
			showMat(v, mat, known)
		else
			UI.sound("Error")
			UI.toast(("Scare a %s %s to unlock it  ·  Coins x%g"):format(mat.name, v.name, (v.mult or 1) * mat.mult), mat.color, "lock")
		end
	end)
	matTiles[mat and mat.id or "Normal"] = {card = t, stroke = parts.stroke}
end

local function showDetail(v, keepMat)
	focus = v
	local c = counts()
	local mats = matCounts()
	local mine = mats[v.id] or {}
	local known = (c[v.id] or 0) > 0
	local r = rarityOf(v)
	focusSig = (c[v.id] or 0) .. "|" .. (player:GetAttribute("VisitorMats") or "")
	-- cabecera
	for _, x in headThumb:GetChildren() do
		if x:IsA("ViewportFrame") then
			x:Destroy()
		end
	end
	portrait(v, headThumb, {Size = UDim2.fromScale(1, 1), ZIndex = 5}, not known)
	headThumb.BackgroundColor3 = r.color:Lerp(UI.DARK, 0.7)
	headThumb.Glow.ImageColor3 = r.color:Lerp(UI.WHITE, 0.25)
	dName.Text = known and v.name or "???"
	dName.TextColor3 = r.color:Lerp(UI.WHITE, 0.3)
	dRarity.Text = string.upper(r.name)
	dRarity.BackgroundColor3 = r.color:Lerp(BLACK, 0.15)
	dTimes.Text = known and ("SCARED x%d"):format(c[v.id]) or "NOT SCARED YET"
	-- estadísticas
	dCoins.Text = ("x%g"):format(v.mult or 1)
	dChance.Text = pct(chanceOf(v)) .. " / visit"
	local courage = r.courage * (v.courage or 1)
	dBrave.Text = courage < 0.8 and "Very brave" or courage < 0.95 and "Brave" or courage > 1.1 and "Easily scared" or "Normal"
	local speed = (r.speed or 1) * (v.speed or 1)
	dSpeed.Text = speed < 0.5 and "Very slow" or speed < 0.85 and "Slow" or speed > 1.12 and "Fast" or "Normal"
	dDesc.Text = known and v.desc or "Scare this visitor in your house to add it to your Index and reveal its secrets."
	-- materiales
	for _, x in matGrid:GetChildren() do
		if x:IsA("GuiObject") then
			x:Destroy()
		end
	end
	table.clear(matTiles)
	local vary = canVary(v)
	matGrid.Visible = vary
	matNote.Visible = not vary
	local owned = matsOwned(mats, v)
	if vary then
		matFill.Size = UDim2.fromScale(owned / #Config.Variants, 1)
		matText.Text = ("%d / %d"):format(owned, #Config.Variants)
		matTile(v, nil, c[v.id] or 0, true, 0, known)
		for i, m in Config.Variants do
			local n = mine[m.id] or 0
			matTile(v, m, n, n > 0, i, known)
		end
	else
		matFill.Size = UDim2.fromScale(1, 1)
		matText.Text = "UNIQUE"
		local own = v.variant and Config.VariantById[v.variant]
		matNote.Text = own and ("Made of pure %s from head to toe:\nit never comes in other materials."):format(own.id:lower())
			or "Too special to be made of anything else:\nit always comes just like this."
	end
	-- visor: el material que estaba elegido (si lo sigues teniendo) o el normal
	local mat = keepMat and selMat and (mine[selMat.id] or 0) > 0 and selMat or nil
	showMat(v, mat, known)
	UI.tintCard(head, r.color)
end

local function openDetail(v)
	showDetail(v)
	visitorsPage.Visible = false
	detailPage.Visible = true
	UI.popIn(detailPage, 0.92)
end

local function closeDetail()
	detailPage.Visible = false
	visitorsPage.Visible = true
	UI.popIn(visitorsPage, 0.96)
end
back.Activated:Connect(function()
	UI.sound("Tab")
	closeDetail()
end)

local function refresh()
	local c = counts()
	local mats = matCounts()
	local have, total = 0, #ORDER
	local byRarity = {}
	for _, v in ORDER do
		local known = (c[v.id] or 0) > 0
		if known then
			have += 1
		end
		local b = byRarity[v.rarity] or {0, 0}
		b[1] += known and 1 or 0
		b[2] += 1
		byRarity[v.rarity] = b
		local card = cards[v.id]
		if card then
			if card.known ~= known then
				-- se ha descubierto: retrato a color
				card.known = known
				card.vp:Destroy()
				card.vp = portrait(v, card.stage, {Size = UDim2.fromScale(1, 1), ZIndex = 4}, not known)
			end
			card.name.Text = known and v.name or "???"
			card.count.Text = known and ("x%d"):format(c[v.id]) or ""
			card.count.Visible = known
			card.lock.Visible = not known
			card.card.Visible = matches(query, known and v.name or "???")
			-- insignia de materiales: cuántos tienes, del color del más valioso
			local n = matsOwned(mats, v)
			local best = bestMat(mats, v)
			card.mats.Visible = n > 0
			card.matsText.Text = ("%d/%d"):format(n, #Config.Variants)
			if best then
				card.mats.BackgroundColor3 = best.color:Lerp(BLACK, 0.2)
			end
		end
	end
	sub.Text = "Scare visitors in your house to collect them all. Click one to see its details and the materials you got!"
	progFill.Size = UDim2.fromScale(have / total, 1)
	progText.Text = ("DISCOVERED %d / %d"):format(have, total)
	local chances = Config.rarityChances(Config.playerLevel(player), player:GetAttribute("LuckBoost")) -- (con la suerte de tu nivel)
	for id, chip in legendChips do
		local b = byRarity[id] or {0, 0}
		local r = Config.Rarities[Config.RarityIndex[id]]
		chip.Text = ("%s %s  ·  %d/%d"):format(r.name, pct(chances[Config.RarityIndex[id]]), b[1], b[2])
	end
	-- la ficha abierta solo se rehace si ha cambiado algo suyo (no reinicia el visor por cualquier susto)
	if focus and detailPage.Visible then
		local sig = (c[focus.id] or 0) .. "|" .. (player:GetAttribute("VisitorMats") or "")
		if sig ~= focusSig then
			showDetail(focus, true)
		end
	end
end

local function build()
	built = true
	local c = counts()
	for i, v in ORDER do
		local r = rarityOf(v)
		local known = (c[v.id] or 0) > 0
		local card, parts = UI.card(grid, i, r.color, {Class = "TextButton", AutoButtonColor = false, Text = ""})
		local stage = UI.stage(card, r.color, {Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 100), ZIndex = 3})
		local vp = portrait(v, stage, {Size = UDim2.fromScale(1, 1), ZIndex = 4}, not known)
		local name = label({Position = UDim2.fromOffset(6, 110), Size = UDim2.new(1, -12, 0, 18), Font = UI.TITLE, TextSize = 14, TextStrokeTransparency = 0, TextScaled = true, Text = known and v.name or "???", ZIndex = 4}, card)
		UI.new("UITextSizeConstraint", {MaxTextSize = 14, MinTextSize = 9}, name)
		label({Position = UDim2.fromOffset(6, 130), Size = UDim2.new(1, -12, 0, 16), Font = UI.SMALL, TextSize = 11, TextColor3 = r.color:Lerp(UI.WHITE, 0.2), Text = string.upper(r.name), ZIndex = 4}, card)
		local count = UI.chip("", UI.DARK, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), TextSize = 12, ZIndex = 6, Visible = known, Text = known and ("x%d"):format(c[v.id]) or ""}, card)
		local lock = UI.icon("lock", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(30, 30), ZIndex = 6, Visible = not known}, card)
		-- insignia de materiales (abajo a la izquierda del retrato)
		local mats = UI.round(new("Frame", {Position = UDim2.fromOffset(9, 81), Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = UI.GEM, Visible = false, ZIndex = 6}, card), 11)
		UI.stroke(mats, UI.INK, 2)
		new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 1)}, mats)
		new("UIPadding", {PaddingLeft = UDim.new(0, 1), PaddingRight = UDim.new(0, 7)}, mats)
		UI.icon("gem", {Size = UDim2.fromOffset(22, 22), ZIndex = 7}, mats)
		local matsText = label({Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, Font = UI.TITLE, TextSize = 13, TextStrokeTransparency = 0, Text = "", ZIndex = 7}, mats)
		new("UIPadding", {PaddingTop = UDim.new(0, 3)}, matsText)
		if Config.RarityIndex[r.id] >= 5 then
			UI.piece("sparkle", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(26, 26), ImageColor3 = r.color, ZIndex = 6}, card)
		end
		UI.press(card, 1.04)
		card.Activated:Connect(function()
			UI.sound("Open")
			openDetail(v)
		end)
		cards[v.id] = {card = card, stage = stage, vp = vp, name = name, count = count, lock = lock, stroke = parts.stroke, known = known, mats = mats, matsText = matsText}
		if i % 6 == 0 then
			task.wait() -- (no congela al abrir por primera vez)
		end
	end
end

local function toggle(open)
	if open == nil then
		open = not gui.Enabled
	end
	if open == gui.Enabled then
		return
	end
	gui.Enabled = open
	UI.sound(open and "Open" or "Close")
	if open then
		if UI.closeCatalogs then
			UI.closeCatalogs()
		end
		-- siempre se abre en la lista
		detailPage.Visible = false
		visitorsPage.Visible = true
		UI.popIn(win, 0.85)
		if not built then
			task.spawn(function()
				build()
				refresh()
			end)
		else
			refresh()
		end
	end
end
close.Activated:Connect(function()
	toggle(false)
end)
dim.Activated:Connect(function()
	toggle(false)
end)
for _, attr in {"Visitors", "VisitorMats"} do
	player:GetAttributeChangedSignal(attr):Connect(function()
		if gui.Enabled and built then
			refresh()
		end
	end)
end
searchBox(visitorsPage, ACCENT, function(q)
	query = q
	if built then
		refresh()
	end
end)

UI.toggleIndex = toggle
require(script.Parent:WaitForChild("Catalog"))(UI).openers.Index = function()
	toggle(true)
end

local bookButton = UI.menuButton(7, "book", "Index", Color3.fromRGB(46, 170, 196))
local badge = UI.addBadge(bookButton)
bookButton.Activated:Connect(function()
	badge.Visible = false
	toggle()
end)
local function autoClose()
	if gui.Enabled and (player:GetAttribute("Mode") == "visit" or player:GetAttribute("TDCash") ~= nil) then
		toggle(false)
	end
end
player:GetAttributeChangedSignal("Mode"):Connect(autoClose)
player:GetAttributeChangedSignal("TDCash"):Connect(autoClose)

---------- Avisos ----------
local newCount = 0
Remote.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "VisitorVariant" then
		-- llega alguien hecho de otra materia (rarísimo)
		local v, m = Config.VisitorById[a], Config.VariantById[b]
		if v and m then
			UI.big(string.upper(m.name) .. " VISITOR!", ("A %s %s is coming to your house  ·  Coins x%g"):format(m.name, v.name, (v.mult or 1) * m.mult), m.color, 3.4)
			UI.sound("Win")
			UI.flash(m.color, 0.7, 0.8)
			UI.confetti(90)
		end
	elseif kind == "Visitor" then
		-- llega a tu casa alguien poco común o mejor
		local v = Config.VisitorById[a]
		if not v then
			return
		end
		if v.secret then
			return -- (el Rey Calabaza lo anuncia SecretAnnounce, para todos)
		end
		local r = rarityOf(v)
		local idx = Config.RarityIndex[r.id]
		if idx >= 5 then
			UI.big(string.upper(r.name) .. " VISITOR!", ("%s is coming to your house  ·  Coins x%g"):format(v.name, v.mult or 1), r.color, 3.2)
			UI.sound("Win")
			UI.flash(r.color, 0.7, 0.8)
			if idx >= 5 then
				UI.confetti(110)
			end
		else
			UI.toast(("%s is visiting!"):format(v.name), r.color, idx >= 3 and "star" or "ghost", {chip = string.upper(r.name), tail = ("x%g"):format(v.mult or 1)})
			UI.sound("Sparkle")
		end
	elseif kind == "SecretAnnounce" then
		-- el Rey Calabaza llega a una casa: cartel enorme, destello naranja y morado y mensaje en el chat, para todos
		local v = Config.VisitorById[b]
		if not v then
			return
		end
		local mine = c == player.UserId
		local ORANGE, PURPLE = Color3.fromRGB(255, 150, 40), Color3.fromRGB(170, 80, 255)
		UI.big("THE PUMPKIN KING!", mine and ("He is coming to YOUR house!  ·  Coins x%g"):format(v.mult or 1) or ("%s's house got the Pumpkin King!"):format(a), ORANGE, 5)
		UI.sound("Win")
		UI.sound("Jingle")
		UI.flash(ORANGE, 0.55, 0.6)
		task.delay(0.35, UI.flash, PURPLE, 0.45, 0.8)
		UI.confetti(mine and 160 or 90)
		UI.toast(mine and "The rarest visitor in the game is at your door. Scare him!" or ("%s found the SECRET visitor!"):format(a), ORANGE, "crown", {chip = "SECRET"})
		task.spawn(pcall, function()
			local channel = game:GetService("TextChatService"):WaitForChild("TextChannels", 3):WaitForChild("RBXGeneral", 3)
			channel:DisplaySystemMessage(('<font color="#FF9628"><b>🎃 THE PUMPKIN KING</b></font> <font color="#FFFFFF">is visiting</font> <font color="#B464FF"><b>%s</b></font><font color="#FFFFFF">\'s house! The rarest visitor of all!</font>'):format(a))
		end)
	elseif kind == "VisitorAnnounce" then
		local v = Config.VisitorById[b]
		if v and v.secret then
			return
		end
		if v and a ~= player.DisplayName then
			local r = rarityOf(v)
			local m = c and Config.VariantById[c]
			UI.toast(("%s's house got %s!"):format(a, m and ("a " .. m.name .. " " .. v.name) or v.name), m and m.color or r.color, "crown", {chip = string.upper(m and m.name or r.name)})
			UI.sound("Jingle")
		end
	elseif kind == "VisitorMat" then
		-- el primero de ese tipo hecho de esa materia: material nuevo en su ficha del Index
		local v, m = Config.VisitorById[a], Config.VariantById[b]
		if not (v and m) then
			return
		end
		UI.toast(("NEW MATERIAL in your Index: %s %s!"):format(m.name, v.name), m.color, "gem", {chip = string.upper(m.name)})
		UI.sound("Success")
		UI.confetti(60)
		if not gui.Enabled then
			newCount += 1
			badge.Count.Text = tostring(math.min(newCount, 99))
			badge.Visible = true
		end
	elseif kind == "VisitorNew" then
		local v = Config.VisitorById[a]
		if not v then
			return
		end
		local r = rarityOf(v)
		UI.toast(("NEW in your Index: %s  (+%d coins)"):format(v.name, b or 0), r.color, "book")
		UI.sound("Success")
		if Config.RarityIndex[r.id] >= 3 then
			UI.confetti(50)
		end
		if not gui.Enabled then
			newCount += 1
			badge.Count.Text = tostring(math.min(newCount, 99))
			badge.Visible = true
		end
	end
end)
bookButton.Activated:Connect(function()
	newCount = 0
end)

---------- Visitantes míticos: arcoíris y polvo de estrellas ----------
local shiny = {}
local function track(m)
	if m:GetAttribute("Rainbow") or m:GetAttribute("Cosmic") then
		shiny[m] = {rainbow = m:GetAttribute("Rainbow"), seed = math.random() * 10}
	end
end
for _, m in CollectionService:GetTagged("Visitor") do
	task.spawn(track, m)
end
CollectionService:GetInstanceAddedSignal("Visitor"):Connect(function(m)
	task.wait(0.5) -- (los atributos llegan con el modelo; un respiro por si acaso)
	track(m)
end)
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for m, s in shiny do
		if not m.Parent then
			shiny[m] = nil
			continue
		end
		local hl = m:FindFirstChild("Contorno")
		if s.rainbow then
			local c = Color3.fromHSV((t * 0.25 + s.seed) % 1, 0.75, 1)
			if hl then
				hl.OutlineColor, hl.FillColor = c, c
			end
			for _, n in {"UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm"} do
				local p = m:FindFirstChild(n)
				if p then
					p.Color = Color3.fromHSV((t * 0.25 + s.seed + #n * 0.03) % 1, 0.7, 1)
				end
			end
		elseif hl then
			hl.OutlineColor = Color3.fromRGB(150, 110, 255):Lerp(Color3.fromRGB(255, 255, 255), 0.5 + 0.5 * math.sin(t * 3 + s.seed))
		end
	end
end)

---------- Aura de los legendarios para arriba: el círculo de runas y los orbes giran (Weld "Giro" de Juego) ----------
local spins = {}
local function trackSpin(m)
	for _, w in m:GetDescendants() do
		if w:IsA("Weld") and w.Name == "Giro" then
			spins[w] = {c0 = w.C0, speed = w:GetAttribute("Speed") or 1}
		end
	end
end
for _, m in CollectionService:GetTagged("Visitor") do
	task.spawn(trackSpin, m)
end
CollectionService:GetInstanceAddedSignal("Visitor"):Connect(function(m)
	task.wait(0.5)
	trackSpin(m)
end)
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for w, s in spins do
		if not w.Parent then
			spins[w] = nil
			continue
		end
		w.C0 = s.c0 * CFrame.Angles(0, t * s.speed, 0) * CFrame.new(0, math.sin(t * 2) * 0.08, 0)
	end
end)
