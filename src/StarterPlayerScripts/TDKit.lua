-- Tower Defense (cliente): piezas de interfaz que comparten el HUD de la partida y la pantalla de tropas.
-- Cartas de tropa (degradado del color de su categoría, contorno grueso, brillo de cristal y destello en las
-- legendarias), retratos 3D de los cazafantasmas, círculos de alcance nítidos (SurfaceGui) y formatos de números.
-- Estilo: el kit de UI (UI.card, UI.chip, contornos gruesos).
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(RS:WaitForChild("Config"))
local TD = require(RS:WaitForChild("TowerDefense"))
local Assets = RS:WaitForChild("Assets")
local UI = require(script.Parent:WaitForChild("UI"))
local new = UI.new

local Kit = {}
Kit.CASH = Color3.fromRGB(110, 236, 130)
Kit.BUY = UI.BUY
Kit.CANT = UI.CANT
Kit.MUTED = UI.MUTED
Kit.LINE = Color3.fromRGB(96, 74, 140)
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local PANEL_TOP, PANEL_BOT = Color3.fromRGB(62, 40, 100), Color3.fromRGB(24, 14, 42)

function Kit.corner(o, r)
	new("UICorner", {CornerRadius = typeof(r) == "UDim" and r or UDim.new(0, r or 12)}, o)
	return o
end

function Kit.outline(o, color, thickness, transparency)
	return new("UIStroke", {Color = color, Thickness = thickness or 2, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, o)
end

function Kit.gradient(o, a, b, rot)
	return new("UIGradient", {Color = ColorSequence.new(a, b), Rotation = rot or 90}, o)
end

function Kit.label(props, parent)
	if props.BackgroundTransparency == nil then
		props.BackgroundTransparency = 1
	end
	props.Font = props.Font or UI.FONT
	props.TextColor3 = props.TextColor3 or UI.WHITE
	return new("TextLabel", props, parent)
end

-- Panel del kit: degradado morado, contorno grueso, bisel del color indicado y el patrón de murciélagos muy suave.
-- Devuelve el marco; su UIStroke (el contorno) se puede recolorear.
function Kit.panel(props, parent, accent)
	accent = accent or UI.PURPLE
	props.BackgroundColor3 = WHITE
	props.BackgroundTransparency = props.BackgroundTransparency == 0 and 0 or 0.04
	local f = Kit.corner(new("Frame", props, parent), 18)
	Kit.gradient(f, PANEL_TOP:Lerp(accent, 0.1), PANEL_BOT)
	local st = Kit.outline(f, UI.INK, 4, 0)
	-- adornos (patrón y bisel) por detrás del contenido; los paneles que se ordenan solos (UIListLayout) o crecen con
	-- AutomaticSize no los llevan: serían un elemento más de la lista y la estirarían
	task.defer(function()
		if f.AutomaticSize ~= Enum.AutomaticSize.None or f:FindFirstChildWhichIsA("UIGridStyleLayout") then
			return
		end
		Kit.corner(new("ImageLabel", {
			Name = "Pattern", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = UI.PATTERN, ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(180, 180), ImageTransparency = 0.95, ZIndex = -1,
		}, f), 18)
		local bevel = Kit.corner(new("Frame", {Name = "Bevel", Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), BackgroundTransparency = 1, ZIndex = -1}, f), 14)
		Kit.outline(bevel, accent:Lerp(WHITE, 0.3), 2, 0.55)
	end)
	return f, st
end

function Kit.money(n) -- 12345 -> "$12,345"
	local s = tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return "$" .. s:gsub("^,", "")
end

function Kit.short(n) -- 12345 -> "12.3K"
	if n >= 1e6 then
		return ("%.1fM"):format(n / 1e6)
	elseif n >= 1e4 then
		return ("%.1fK"):format(n / 1e3)
	end
	return tostring(math.floor(n))
end

function Kit.color(t)
	return Config.Categories[Config.Scares[t].cat].color
end

-- Lo que hace especial a una tropa, en pocas palabras
function Kit.special(s)
	if s.kind == "farm" then
		return ("Earns %s after every wave"):format(Kit.money(s.income))
	elseif s.kind == "support" then
		return ("Aura: +%d%% fear  ·  +%d%% range  ·  reveals hidden"):format(s.buff.dmg * 100 + 0.5, s.buff.range * 100 + 0.5)
	elseif s.kind == "trap" then
		return s.knock and ("Knockback %d"):format(s.knock) or ("Holds hunters %.1fs"):format(s.stun or 0)
	end
	local list = {}
	if s.kind == "aoe" then
		table.insert(list, "Area")
	elseif s.kind == "splash" then
		table.insert(list, ("Splash %d"):format(s.splash + 0.5))
	end
	if s.slow then
		table.insert(list, ("Slow %d%%"):format(s.slow * 100))
	end
	if s.stun then
		table.insert(list, ("Stun %.1fs"):format(s.stun))
	end
	if s.terrify then
		table.insert(list, ("+%d%% fear taken"):format(s.terrify * 100))
	end
	if s.execute then
		table.insert(list, ("%d%% instant scare"):format(s.execute * 100))
	end
	if s.burn then
		table.insert(list, ("Burn %d/s"):format(s.burn.dps + 0.5))
	end
	if s.chain then
		table.insert(list, ("Bounces x%d"):format(s.chain))
	end
	if s.flee then
		table.insert(list, ("Flee %.1fs"):format(s.flee))
	end
	if s.frenzy then
		table.insert(list, "Frenzy")
	end
	if s.drain then
		table.insert(list, ("+%d HP per scare"):format(s.drain))
	end
	if s.detect then
		table.insert(list, "👁 Detects hidden")
	elseif s.detectAt then
		table.insert(list, ("👁 Detects hidden at Lv %d"):format(s.detectAt))
	end
	return #list > 0 and table.concat(list, "  ·  ") or "Single target"
end

-- Crece al pasar por encima, se hunde al pulsar; con los sonidos del kit
function Kit.press(b)
	return UI.press(b, 1.05)
end

---------- Destello que cruza las cartas legendarias ----------
local shines = {}
local function shine(parent)
	local f = Kit.corner(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = parent.ZIndex + 1}, parent), 16)
	local g = new("UIGradient", {
		Rotation = 20,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, 0.5),
			NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1),
		}),
	}, f)
	table.insert(shines, g)
end
RunService.RenderStepped:Connect(function()
	local x = (os.clock() % 2.6) / 2.6 * 3 - 1.5
	for i = #shines, 1, -1 do
		local g = shines[i]
		if g.Parent then
			g.Offset = Vector2.new(x, 0)
		else
			table.remove(shines, i)
		end
	end
end)

---------- Carta de tropa ----------
-- size: Vector2. Devuelve sus piezas para cambiar el estado (key, chip, shade, lock, price, stroke...).
function Kit.card(t, parent, size, order)
	local def = Config.Scares[t]
	local c = Kit.color(t)
	local b, parts = UI.card(parent, order or 0, c, {Class = "TextButton", Size = UDim2.fromOffset(size.X, size.Y), AutoButtonColor = false, Text = "", ZIndex = 2})
	local stroke = parts.stroke
	-- brillo de su color detrás del susto y cristal arriba
	UI.piece("glow2", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.4, 0), Size = UDim2.fromOffset(size.X * 1.1, size.X * 1.1), ImageColor3 = c:Lerp(WHITE, 0.3), ImageTransparency = 0.5, ZIndex = 2}, b)
	local gloss = Kit.corner(new("Frame", {Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0.42, 0), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 2}, b), 13)
	new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(0.82, 1)}, gloss)
	if def.cat == "Legendario" then
		shine(b)
	end
	local vp = UI.viewport(t, b, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.new(1, -8, 1, -44), ZIndex = 3})
	-- fundido oscuro abajo para que se lea el nombre
	local fade = Kit.corner(new("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.5), BackgroundColor3 = UI.DARK, BorderSizePixel = 0, ZIndex = 3}, b), 16)
	new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(1, 0.1)}, fade)
	local name = Kit.label({
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 6, 1, -26), Size = UDim2.new(1, -12, 0, 17), Font = UI.TITLE, TextSize = 14,
		TextStrokeTransparency = 0, TextTruncate = Enum.TextTruncate.AtEnd, Text = def.name, ZIndex = 4,
	}, b)
	local price = Kit.corner(Kit.label({
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -14, 0, 21), BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(18, 60, 34), Font = UI.TITLE, TextSize = 15, TextColor3 = Kit.CASH, TextStrokeTransparency = 0, Text = Kit.money(TD.Troops[t].cost), ZIndex = 4,
	}, b), 10)
	Kit.outline(price, UI.INK, 2, 0)
	local key = UI.chip("", UI.DARK, {Position = UDim2.fromOffset(5, 5), Size = UDim2.fromOffset(24, 24), AutomaticSize = Enum.AutomaticSize.None, Visible = false, ZIndex = 5}, b)
	key.UIPadding.PaddingLeft, key.UIPadding.PaddingRight = UDim.new(0, 0), UDim.new(0, 0)
	local chip = UI.chip("", UI.DARK, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -5, 0, 5), TextSize = 12, Visible = false, ZIndex = 5}, b)
	local shade = Kit.corner(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0.45, Visible = false, ZIndex = 6}, b), 16)
	local lock = UI.icon("lock", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.38), Size = UDim2.fromOffset(44, 44), Visible = false, ZIndex = 7}, b)
	return {
		button = b, vp = vp, stroke = stroke, name = name, price = price, key = key, chip = chip, shade = shade, lock = lock,
		color = c, pop = Kit.press(b),
	}
end

-- Hueco vacío del equipo: oscuro, con contorno y un "+"
function Kit.emptySlot(parent, size, order, text)
	local f = Kit.corner(new("TextButton", {
		Size = UDim2.fromOffset(size.X, size.Y), BackgroundColor3 = UI.DARK, BackgroundTransparency = 0.45, AutoButtonColor = false,
		Text = "", LayoutOrder = order or 0,
	}, parent), 16)
	Kit.outline(f, UI.INK, 3, 0.1)
	local inner = Kit.corner(new("Frame", {Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 1, -12), BackgroundTransparency = 1}, f), 12)
	Kit.outline(inner, Kit.LINE, 2, 0.3)
	local plus = UI.icon("plus", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(40, 40), ImageTransparency = 0.45}, f)
	plus.ImageColor3 = Color3.fromRGB(200, 190, 220)
	Kit.label({Position = UDim2.fromScale(0, 0.66), Size = UDim2.new(1, 0, 0, 16), Font = UI.FONT, TextSize = 13, TextColor3 = Kit.MUTED, Text = text or "Empty"}, f)
	return f
end

---------- Retrato 3D de un cazafantasma (con los colores de su tipo) ----------
function Kit.portrait(kind, parent, props)
	local def = TD.Enemies[kind] or TD.Enemies.visitor
	local vp = new("ViewportFrame", props, parent)
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(190, 180, 210)
	vp.LightColor = Color3.fromRGB(255, 240, 220)
	vp.LightDirection = Vector3.new(-1, -1, -1)
	local m = Assets.TDHunter:Clone()
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") then
			local n = p.Name
			p.Color = (n:find("Torso") or n:find("Arm")) and def.shirt or (n:find("Leg") or n:find("Foot")) and Color3.fromRGB(45, 45, 72)
				or Color3.fromRGB(240, 195, 150)
		elseif p:IsA("Humanoid") then
			p.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end
	m.Parent = vp
	local head = m:FindFirstChild("Head")
	local cam = new("Camera", {FieldOfView = 32}, vp)
	vp.CurrentCamera = cam
	if head then
		-- cabeza y hombros
		local focus = head.Position - Vector3.new(0, 0.35, 0)
		cam.CFrame = CFrame.lookAt(focus + head.CFrame.LookVector * 5.2 + head.CFrame.RightVector * 1.3 + Vector3.new(0, 0.5, 0), focus)
	end
	return vp
end

---------- Círculo de alcance: relleno translúcido y borde nítido ----------
function Kit.circle()
	local p = new("Part", {
		Name = "Alcance", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Transparency = 1,
		Size = Vector3.new(1, 0.05, 1),
	}, workspace)
	local sg = new("SurfaceGui", {
		Face = Enum.NormalId.Top, LightInfluence = 0, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 16, Adornee = p,
	}, p)
	local fill = Kit.corner(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.8, BorderSizePixel = 0}, sg), UDim.new(0.5, 0))
	local edge = new("UIStroke", {Thickness = 5, Transparency = 0.05}, fill)
	-- un segundo aro interior, más tenue
	local inner = Kit.corner(new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.94, 0.94), BackgroundTransparency = 1,
	}, fill), UDim.new(0.5, 0))
	local ring = new("UIStroke", {Thickness = 2, Transparency = 0.6}, inner)
	return {part = p, fill = fill, edge = edge, ring = ring}
end

function Kit.setCircle(c, pos, r, color)
	c.part.Size = Vector3.new(r * 2, 0.05, r * 2)
	c.part.CFrame = CFrame.new(pos + Vector3.new(0, 0.35, 0))
	if color then
		c.fill.BackgroundColor3, c.edge.Color, c.ring.Color = color, color, color
	end
end

return Kit
