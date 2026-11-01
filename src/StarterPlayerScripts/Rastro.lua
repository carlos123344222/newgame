-- Rastro: las flechas que te llevan a un sitio (las de FOLLOW de las misiones y las del tutorial).
--  * Una banda de chevrones en línea recta desde justo delante de ti hasta el destino, vista a través de todo, que
--    corre hacia allí, con una ola de luz y el color según la distancia (lima cerca, naranja en medio, amarillo claro
--    al fondo).
--  * En el destino, una columna de luz del color del rastro con dos anillos que se abren en el suelo.
--  * Encima del destino, si se ve, una insignia con su icono, una flecha hacia abajo y la distancia; si no se ve, una
--    flecha en el borde de la pantalla que apunta hacia allí.
-- Solo hay un rastro a la vez: Rastro.start lo cambia (al anterior se le avisa con onCancel).
--   Rastro.start({owner, pos | getPos, reach, color, icon, done, onArrive, onCancel})
--     pos: Vector3 fijo · getPos(): el destino cada frame (puede moverse; nil = de momento no hay)
--     reach: a qué distancia (en planta) ya has llegado · done(dist): otra forma de haber llegado (opcional)
--   Rastro.stop(owner) (sin owner: el que sea) · Rastro.owner() · Rastro.rightInset(): hueco a la derecha de la
--   pantalla que la flecha del borde no pisa (lo cambia MisionesUI cuando se ve su panel)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UI = require(script.Parent:WaitForChild("UI"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local new, round, stroke = UI.new, UI.round, UI.stroke
local INK, WHITE = UI.INK, UI.WHITE

local Rastro = {}
Rastro.rightInset = function()
	return 80
end

local CHEVRON_GAP = 2.6 -- separación entre chevrones (studs)
local CHEVRON_SIZE = 3 -- lado del cuadro de cada chevrón (lo ancho que es)
local TRAIL_SPEED = 5 -- lo que corren hacia el destino (studs/s)
local TRAIL_START = 3.2 -- dónde sale el primero, por delante de tu centro (fuera del cuerpo)
local TRAIL_AHEAD = 70 -- hasta dónde se dibujan
local TRAIL_OPACITY = 0.85
local TRAIL_COLORS = {
	{0, Color3.fromRGB(176, 255, 92)},
	{0.3, Color3.fromRGB(255, 214, 64)},
	{0.65, Color3.fromRGB(255, 156, 44)},
	{1, Color3.fromRGB(255, 238, 168)},
}

local guide -- {owner, pos, getPos, floor, reach, done, onArrive, onCancel, part, rings, color, dist, t0}
local trailFolder = new("Folder", {Name = "MisionRastro"})
local chevrons = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true

local function tween(o, t, goal, style)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad), goal)
	tw:Play()
	return tw
end

local function trailColor(u)
	for i = 2, #TRAIL_COLORS do
		local k0, k1 = TRAIL_COLORS[i - 1], TRAIL_COLORS[i]
		if u <= k1[1] then
			return k0[2]:Lerp(k1[2], (u - k0[1]) / (k1[1] - k0[1]))
		end
	end
	return TRAIL_COLORS[#TRAIL_COLORS][2]
end

-- Un chevrón: dos barras redondeadas en V en una SurfaceGui. En la cara de arriba de la pieza,
-- la derecha del lienzo es su frente.
local function bar(sg, center, angle, len)
	local b = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(center.X, center.Y), Size = UDim2.fromOffset(len, 14),
		Rotation = angle, BackgroundColor3 = WHITE, BorderSizePixel = 0}, sg)
	new("UICorner", {CornerRadius = UDim.new(1, 0)}, b)
	return b
end

local function chevronAt(i)
	local c = chevrons[i]
	if c then
		return c
	end
	local p = new("Part", {
		Name = "Chevron", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Transparency = 1,
		Size = Vector3.new(CHEVRON_SIZE, 0.05, CHEVRON_SIZE),
	}, trailFolder)
	local sg = new("SurfaceGui", {Face = Enum.NormalId.Top, AlwaysOnTop = true, LightInfluence = 0, CanvasSize = Vector2.new(100, 100), Enabled = false}, p)
	-- punta en (68, 50), colas en (32, 12) y (32, 88)
	local len = math.sqrt(36 ^ 2 + 38 ^ 2) + 14
	local angle = math.deg(math.atan2(38, 36))
	c = {part = p, gui = sg, bars = {bar(sg, Vector2.new(50, 31), angle, len), bar(sg, Vector2.new(50, 69), -angle, len)}}
	chevrons[i] = c
	return c
end

local function paint(c, color, alpha)
	for _, b in c.bars do
		b.BackgroundColor3 = color
		b.BackgroundTransparency = 1 - alpha
	end
end

-- El suelo bajo un punto (lo que se pisa: CanCollide) y su normal
local function groundAt(p)
	local hit = workspace:Raycast(p + Vector3.new(0, 4, 0), Vector3.new(0, -16, 0), rayParams)
	if hit then
		return hit.Position, hit.Normal
	end
	return p, Vector3.yAxis
end
Rastro.groundAt = groundAt

local function hideTrail()
	trailFolder.Parent = nil
	for _, c in chevrons do
		c.gui.Enabled = false
	end
end

-- Cada frame: la fila de chevrones de delante de ti al destino, corriendo hacia allí
local function updateTrail(root, t)
	local hum = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
	local feet = root.Position - Vector3.new(0, (hum and hum.HipHeight or 2) + root.Size.Y / 2 - 0.2, 0)
	local goal = guide.floor + Vector3.new(0, 0.2, 0)
	local flat = Vector3.new(goal.X - feet.X, 0, goal.Z - feet.Z)
	local used = 0
	if flat.Magnitude > TRAIL_START + 4 then
		trailFolder.Parent = workspace
		local len = (goal - feet).Magnitude
		local frame = CFrame.lookAt(feet, goal)
		local stop = math.min(len - 3.5, TRAIL_START + TRAIL_AHEAD)
		local phase = (t * TRAIL_SPEED) % CHEVRON_GAP
		local parts, cfs = {}, {}
		for k = 0, math.huge do
			local d = TRAIL_START + k * CHEVRON_GAP + phase
			if d > stop then
				break
			end
			used += 1
			local c = chevronAt(used)
			local fadeIn = math.clamp((d - TRAIL_START) / CHEVRON_GAP, 0, 1) -- (el que nace no aparece de golpe)
			local fadeOut = math.clamp((stop - d) / 7, 0, 1)
			local wave = math.max(0, math.sin((d - t * 30) / 8)) ^ 6
			local color = trailColor(math.clamp((d - TRAIL_START) / TRAIL_AHEAD, 0, 1)):Lerp(WHITE, wave * 0.5)
			paint(c, color, math.min(1, TRAIL_OPACITY + 0.15 * wave) * fadeIn * fadeOut)
			c.gui.Enabled = true
			table.insert(parts, c.part)
			table.insert(cfs, frame * CFrame.new(0, 0, -d))
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end
	-- los que sobran, apagados del todo (no basta con hacerlos transparentes: se quedarían donde estaban)
	for i = used + 1, #chevrons do
		chevrons[i].gui.Enabled = false
	end
end

---------- Flecha del borde y marcador del destino ----------
local GO_COLOR = UI.ORANGE
local function label(props, parent)
	props.BackgroundTransparency = 1
	props.TextColor3 = props.TextColor3 or WHITE
	return new("TextLabel", props, parent)
end
local edgeGui = new("ScreenGui", {Name = "MisionFlecha", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 3}, playerGui)
local edge = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(84, 84), BackgroundTransparency = 1, Visible = false}, edgeGui)
local edgeDisc = round(new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(56, 56), BackgroundColor3 = GO_COLOR}, edge), UDim.new(1, 0))
stroke(edgeDisc, INK, 3)
new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 140, 160))}, edgeDisc)
local edgeIcon = UI.icon("target", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(40, 40), ZIndex = 2}, edgeDisc)
local edgeArrow = UI.icon("arrowR", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(40, 40), ZIndex = 3}, edge)
local edgeDist = label({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.fromOffset(90, 22), Font = UI.HUD_FONT, TextSize = 17, Text = "", ZIndex = 4}, edge)
UI.hudStroke(edgeDist, 2)
-- el marcador sobre el destino cuando se ve: insignia con rayos que giran, una flecha hacia abajo y la distancia. Se
-- dibuja en pantalla (no con un BillboardGui: los AlwaysOnTop no salen en este juego y si no, lo taparían las paredes)
local marker = new("Frame", {AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(150, 176), BackgroundTransparency = 1, Visible = false}, edgeGui)
local markerScale = new("UIScale", {}, marker)
local markerRays = UI.piece("rays", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 62), Size = UDim2.fromOffset(160, 160), ImageColor3 = GO_COLOR, ImageTransparency = 0.3}, marker)
local markerDisc = round(new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 62), Size = UDim2.fromOffset(76, 76), BackgroundColor3 = GO_COLOR, ZIndex = 2}, marker), UDim.new(1, 0))
stroke(markerDisc, INK, 3.5)
new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 140, 160))}, markerDisc)
local markerIcon = UI.icon("target", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.78, 0.78), ZIndex = 3}, markerDisc)
local markerArrow = UI.icon("arrowR", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 116), Size = UDim2.fromOffset(34, 34), Rotation = 90, ZIndex = 2}, marker)
local markerDist = label({AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(150, 30), Font = UI.HUD_FONT, TextSize = 24, Text = "", ZIndex = 4}, marker)
UI.hudStroke(markerDist, 2.6)

-- (la flecha del borde y el marcador, solo con el HUD a la vista)
task.spawn(function()
	while true do
		edgeGui.Enabled = UI.gui.Enabled and not UI.menuOpen()
		task.wait(0.2)
	end
end)

-- El destino: una columna de luz y dos anillos que se abren en el suelo, en bucle
local function beacon(floor, color)
	local part = new("Part", {
		Name = "MisionDestino", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Transparency = 1,
		Size = Vector3.new(14, 0.05, 14), CFrame = CFrame.new(floor + Vector3.new(0, 0.18, 0)),
	}, workspace)
	local base = new("Attachment", {Name = "Base"}, part)
	local top = new("Attachment", {Name = "Cima", Position = Vector3.new(0, 34, 0)}, part)
	local fade = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.55, 0.7), NumberSequenceKeypoint.new(1, 1)})
	new("Beam", {
		Name = "Columna", Attachment0 = base, Attachment1 = top, FaceCamera = true, Width0 = 4.5, Width1 = 2.2, Segments = 1, LightEmission = 1, LightInfluence = 0,
		Color = ColorSequence.new(color), Transparency = fade,
	}, part)
	new("Beam", {
		Name = "Nucleo", Attachment0 = base, Attachment1 = top, FaceCamera = true, Width0 = 1.4, Width1 = 0.5, Segments = 1, LightEmission = 1, LightInfluence = 0,
		Color = ColorSequence.new(color:Lerp(WHITE, 0.7)), Transparency = fade,
	}, part)
	new("PointLight", {Color = color, Range = 16, Brightness = 1.4, Shadows = false}, base)
	local sg = new("SurfaceGui", {Face = Enum.NormalId.Top, LightInfluence = 0, Brightness = 1.4, CanvasSize = Vector2.new(256, 256)}, part)
	UI.piece("glow2", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.55, 0.55), ImageColor3 = color, ImageTransparency = 0.3}, sg)
	local rings = {}
	for i = 1, 2 do
		rings[i] = UI.piece("ring", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.2, 0.2), ImageColor3 = color:Lerp(WHITE, 0.35), ZIndex = 2}, sg)
	end
	return part, rings
end

---------- API ----------
function Rastro.owner()
	return guide and guide.owner
end

function Rastro.stop(owner)
	if not guide or (owner and guide.owner ~= owner) then
		return
	end
	guide.part:Destroy()
	guide = nil
	hideTrail()
	edge.Visible = false
	marker.Visible = false
end

function Rastro.start(o)
	if guide then
		local old = guide
		Rastro.stop()
		if old.onCancel and old.owner ~= o.owner then
			task.spawn(old.onCancel)
		end
	end
	local color = o.color or GO_COLOR
	local pos = o.pos or (o.getPos and o.getPos())
	rayParams.FilterDescendantsInstances = {player.Character, trailFolder}
	local floor = pos and groundAt(pos) or Vector3.new(0, -1000, 0)
	local part, rings = beacon(floor, color)
	guide = {
		owner = o.owner, pos = pos, getPos = o.getPos, floor = floor, reach = o.reach or 10, done = o.done, onArrive = o.onArrive, onCancel = o.onCancel,
		part = part, rings = rings, color = color, dist = "", t0 = os.clock(),
	}
	hideTrail()
	edgeDisc.BackgroundColor3 = color
	UI.setIcon(edgeIcon, o.icon or "target")
	markerDisc.BackgroundColor3 = color
	markerRays.ImageColor3 = color
	UI.setIcon(markerIcon, o.icon or "target")
	markerScale.Scale = 0.2
	tween(markerScale, 0.45, {Scale = 1}, Enum.EasingStyle.Back)
end

local function arrive()
	local g = guide
	Rastro.stop()
	if g and g.onArrive then
		task.spawn(g.onArrive)
	end
end

RunService.RenderStepped:Connect(function()
	if not guide then
		return
	end
	local t = os.clock() - guide.t0
	-- destino que se mueve (la moneda más cercana...): se recoloca la columna
	if guide.getPos then
		local p = guide.getPos()
		if not p then
			guide.pos = nil
		elseif not guide.pos or (p - guide.pos).Magnitude > 0.5 then
			guide.pos = p
			guide.floor = groundAt(p)
			guide.part.CFrame = CFrame.new(guide.floor + Vector3.new(0, 0.18, 0))
		end
	end
	if not guide.pos then
		hideTrail()
		edge.Visible, marker.Visible = false, false
		guide.part.Parent = nil
		return
	end
	guide.part.Parent = workspace
	-- anillos del destino: se abren y se apagan, uno detrás del otro
	for i, r in guide.rings do
		local k = (t * 0.55 + (i - 1) * 0.5) % 1
		r.Size = UDim2.fromScale(0.2 + 0.8 * k, 0.2 + 0.8 * k)
		r.ImageTransparency = k ^ 1.5
	end
	markerRays.Rotation = t * 40
	markerDisc.Size = UDim2.fromOffset(76 + math.sin(t * 6) * 3, 76 + math.sin(t * 6) * 3)
	markerArrow.Position = UDim2.new(0.5, 0, 0, 116 + math.sin(t * 5) * 5)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	updateTrail(root, os.clock())
	local flat = Vector3.new(guide.pos.X - root.Position.X, 0, guide.pos.Z - root.Position.Z)
	local d = flat.Magnitude
	guide.dist = ("%dm"):format(math.floor(d / 3.5 + 0.5)) -- (en metros: ~3.5 studs)
	markerDist.Text = guide.dist
	if d <= guide.reach or (guide.done and guide.done(d)) then
		return arrive()
	end
	-- fuera de la pantalla: la flecha del borde apunta hacia allí
	local cam = workspace.CurrentCamera
	local vs = cam.ViewportSize
	local sp, onScreen = cam:WorldToViewportPoint(guide.pos + Vector3.new(0, 3, 0))
	if onScreen and sp.Z > 0 then
		edge.Visible = false
		-- (sin subir encima de los avisos de arriba: el marcador baja un poco y su flecha sigue señalando)
		marker.Position = UDim2.fromOffset(sp.X, math.max(sp.Y, 300))
		marker.Visible = edgeGui.Enabled
		return
	end
	marker.Visible = false
	local dir = Vector2.new(sp.X, sp.Y) - vs / 2
	if sp.Z < 0 then
		dir = -dir
	end
	if dir.Magnitude < 1 then
		dir = Vector2.new(0, 1)
	end
	dir = dir.Unit
	-- dentro del hueco libre: sin pisar el menú de la izquierda, el panel de misiones, los avisos ni la hotbar
	local c = vs / 2
	local minX, maxX = math.min(c.X - 60, 280), math.max(c.X + 60, vs.X - Rastro.rightInset())
	local minY, maxY = math.min(c.Y - 60, 230), math.max(c.Y + 60, vs.Y - 235)
	local kx = dir.X > 0 and (maxX - c.X) / dir.X or dir.X < 0 and (minX - c.X) / dir.X or math.huge
	local ky = dir.Y > 0 and (maxY - c.Y) / dir.Y or dir.Y < 0 and (minY - c.Y) / dir.Y or math.huge
	local p = c + dir * math.min(kx, ky)
	edge.Position = UDim2.fromOffset(p.X, p.Y)
	edgeArrow.Position = UDim2.new(0.5, dir.X * 40, 0.5, dir.Y * 40)
	edgeArrow.Rotation = math.deg(math.atan2(dir.Y, dir.X))
	edgeDist.Text = guide.dist
	edge.Visible = edgeGui.Enabled
	edgeDisc.Size = UDim2.fromOffset(56 + math.sin(t * 6) * 3, 56 + math.sin(t * 6) * 3)
end)

return Rastro
