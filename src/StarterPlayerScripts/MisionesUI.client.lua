-- Misiones (cliente). Datos: ReplicatedStorage.Misiones; lógica: ServerScriptService.MisionesServidor (atributo Quests
-- del jugador y QuestRemote). Tres piezas:
--  * El panel de la derecha (en la calle y dentro de tu casa): las 3 misiones con su barra y el botón GO / CLAIM.
--  * La ventana MISSIONS (al pulsar el panel): cabecera oscura con la ilustración, filas con título, descripción,
--    progreso, recompensas (monedas, gemas, experiencia) y FOLLOW / CLAIM, como los menús de misiones de los juegos
--    de defensa.
--  * FOLLOW: flechas en el suelo en línea recta (sin rodear nada)
--    desde tus pies hasta el sitio (tu casa, la ruleta, los lobbies del Tower Defense, el caldero, la casa de un
--    vecino), una columna de luz con anillos en el destino, un marcador encima con la distancia y, si no lo ves, una
--    flecha en el borde de la pantalla. Al llegar se apaga solo. Las de comprar abren la pantalla de sustos.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local Config = require(RS:WaitForChild("Config"))
local Q = require(RS:WaitForChild("Misiones"))
local UI = require(script.Parent:WaitForChild("UI"))
local QuestRemote = RS:WaitForChild("QuestRemote")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local new, round, stroke = UI.new, UI.round, UI.stroke

local ART = "rbxassetid://98035399837542" -- pergamino con el sello de calabaza (Figma, recortado)
local INK, WHITE, MUTED = UI.INK, UI.WHITE, UI.MUTED
local LEFT, RIGHT = Enum.TextXAlignment.Left, Enum.TextXAlignment.Right
local CLAIM_COLOR = UI.BUY
local GO_COLOR = UI.ORANGE
local STOP_COLOR = Color3.fromRGB(150, 96, 240)

local function label(props, parent)
	props.BackgroundTransparency = 1
	props.Font = props.Font or UI.FONT
	props.TextColor3 = props.TextColor3 or WHITE
	return new("TextLabel", props, parent)
end

local function tween(o, t, goal, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

local function kindOf(q)
	return Q.Kinds[q.k] or Q.Kinds.scare
end

local function done(q)
	return q.p >= q.n
end

local function progressText(q)
	return ("%s / %s"):format(UI.fmt(math.min(q.p, q.n)), UI.fmt(q.n))
end

-- disco redondo del color del tipo con su icono (como las insignias del kit)
local function disc(q, size, parent, props)
	props = props or {}
	props.Size = UDim2.fromOffset(size, size)
	props.BackgroundColor3 = kindOf(q).color
	local d = round(new("Frame", props, parent), UDim.new(1, 0))
	new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 140, 160))}, d)
	stroke(d, INK, size > 56 and 3.5 or 2.5)
	local ic = UI.icon(kindOf(q).icon, {Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.78, 0.78), ZIndex = d.ZIndex + 1}, d)
	return d, ic
end

---------- Estado ----------
local quests = {lvl = 0, list = {}}
local following -- id de la misión que se sigue
local refreshAll -- (más abajo)
local tracker -- el panel de la derecha (más abajo)

local function byId(id)
	for i, q in quests.list do
		if q.id == id then
			return q, i
		end
	end
end

---------- FOLLOW: rastro, marcador y flecha del borde ----------
local guide -- {id, q, go, pos, reach, part, color, dist, t0, track, tracedAt, s0}

-- El rastro: triángulos rosas con borde negro pegados al suelo, en fila recta hacia el destino. Corren hacia allí,
-- cada poco los recorre una ola de luz y junto a tus pies y al final se desvanecen.
local TRAIL_GAP = 3 -- separación entre flechas (studs)
local TRAIL_SPEED = 5.5 -- lo que corren hacia el destino (studs/s)
local TRAIL_AHEAD = 130 -- hasta dónde se dibujan por delante de ti
local TRAIL_SIZE = 3 -- lado del cuadro de cada flecha
local OFF_TRACK = 2.5 -- si te sales más de la línea, se vuelve a trazar desde donde estás
local ARROW_ROT = 90 -- (el triángulo apunta arriba del lienzo, que en la cara de arriba cae de lado)
local ARROW_COLOR = Color3.fromRGB(255, 128, 128)
local trailFolder = new("Folder", {Name = "MisionRastro"})
local arrows = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true

local function arrowAt(i)
	local a = arrows[i]
	if a then
		return a
	end
	local p = new("Part", {
		Name = "Flecha", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Transparency = 1,
		Size = Vector3.new(TRAIL_SIZE, 0.05, TRAIL_SIZE),
	}, trailFolder)
	local sg = new("SurfaceGui", {Face = Enum.NormalId.Top, LightInfluence = 0, Brightness = 1.4, CanvasSize = Vector2.new(128, 128)}, p)
	local img = new("TextLabel", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), Rotation = ARROW_ROT,
		BackgroundTransparency = 1, Text = "▲", TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = ARROW_COLOR}, sg)
	local stroke = new("UIStroke", {Color = Color3.fromRGB(20, 12, 16), Thickness = 5}, img)
	a = {part = p, img = img, stroke = stroke}
	arrows[i] = a
	return a
end

-- El suelo bajo un punto (lo que se pisa: CanCollide) y su normal
local function groundAt(p)
	local hit = workspace:Raycast(p + Vector3.new(0, 4, 0), Vector3.new(0, -16, 0), rayParams)
	if hit then
		return hit.Position, hit.Normal
	end
	return p, Vector3.yAxis
end

-- El camino como polilínea a ras de suelo, muestreada cada stud: {p = puntos, n = normales, d = distancia acumulada}
local function buildTrack(points)
	local tr = {p = {}, n = {}, d = {}}
	local total = 0
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local steps = math.max(1, math.ceil((b - a).Magnitude))
		for s = (i == 1 and 0 or 1), steps do
			local q, nrm = groundAt(a:Lerp(b, s / steps))
			local last = tr.p[#tr.p]
			if last then
				total += (q - last).Magnitude
			end
			table.insert(tr.p, q)
			table.insert(tr.n, nrm)
			table.insert(tr.d, total)
		end
	end
	tr.len = total
	return tr
end

-- Punto, dirección y normal del camino a una distancia d (búsqueda binaria en las distancias acumuladas)
local function sample(tr, d)
	local lo, hi = 1, #tr.d
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if tr.d[mid] <= d then
			lo = mid
		else
			hi = mid
		end
	end
	local span = tr.d[hi] - tr.d[lo]
	local k = span > 0 and math.clamp((d - tr.d[lo]) / span, 0, 1) or 0
	local a, b = tr.p[lo], tr.p[hi]
	-- la dirección mira un poco más lejos para que las flechas no tiemblen en las esquinas
	local ahead = tr.p[math.min(#tr.p, hi + 1)]
	local dir = (ahead - a)
	dir = Vector3.new(dir.X, 0, dir.Z)
	return a:Lerp(b, k), dir.Magnitude > 1e-3 and dir.Unit or nil, tr.n[lo]:Lerp(tr.n[hi], k)
end

-- Lo más cerca que pasa el camino de ti (busca cerca de la última vez)
local function progress(tr, pos, from)
	local best, bi = math.huge, from or 1
	local a, b = 1, #tr.p
	if from then
		a, b = math.max(1, from - 25), math.min(#tr.p, from + 70)
	end
	for i = a, b do
		local q = tr.p[i]
		local dd = (q.X - pos.X) ^ 2 + (q.Z - pos.Z) ^ 2
		if dd < best then
			best, bi = dd, i
		end
	end
	return bi, math.sqrt(best)
end

-- Traza la línea recta desde donde estás hasta el destino
local function requestPath()
	local g = guide
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (g and root) or os.clock() - (g.tracedAt or 0) < 0.15 then
		return -- (como mucho unas pocas veces por segundo: cada trazado mira el suelo cada stud)
	end
	g.tracedAt = os.clock()
	rayParams.FilterDescendantsInstances = {player.Character, trailFolder, g.part}
	g.track = buildTrack({(groundAt(root.Position - Vector3.new(0, 3, 0))), g.pos})
	g.s0 = nil
end

local function hideTrail()
	trailFolder.Parent = nil
end

-- Cada frame: las flechas en su sitio del camino, corriendo hacia el destino
local function updateTrail(root, t)
	local tr = guide.track
	if not tr or #tr.p < 2 then
		return
	end
	local idx, off = progress(tr, root.Position, guide.s0)
	guide.s0 = idx
	if off > OFF_TRACK then
		requestPath()
	end
	trailFolder.Parent = workspace
	local start = tr.d[idx] + 1.8
	local stop = math.min(tr.len - 0.5, start + TRAIL_AHEAD)
	local phase = (t * TRAIL_SPEED) % TRAIL_GAP
	local first = math.ceil((start - phase) / TRAIL_GAP)
	local parts, cfs = {}, {}
	local used = 0
	for k = first, math.huge do
		local d = k * TRAIL_GAP + phase
		if d > stop or used >= 44 then
			break
		end
		local pos, dir, nrm = sample(tr, d)
		if dir then
			used += 1
			local a = arrowAt(used)
			-- aparecen a tus pies, se apagan al final y una ola de luz las recorre hacia el destino
			local fadeIn = math.clamp((d - start) / 3.5, 0, 1)
			local fadeOut = math.clamp((tr.len - d) / 5, 0, 1)
			local far = math.clamp(1 - (d - start - TRAIL_AHEAD * 0.7) / (TRAIL_AHEAD * 0.3), 0, 1)
			local vis = fadeIn * fadeOut * far
			local wave = math.max(0, math.sin((d - t * 26) / 10)) ^ 6
			local s = (0.5 + 0.5 * vis) * (1 + 0.28 * wave)
			a.img.Size = UDim2.fromScale(s, s)
			a.img.TextTransparency = 1 - vis
			a.stroke.Transparency = 1 - vis
			a.img.TextColor3 = ARROW_COLOR:Lerp(WHITE, wave * 0.5)
			local up = nrm.Magnitude > 0.5 and nrm.Unit or Vector3.yAxis
			local at = pos + up * 0.14
			table.insert(parts, a.part)
			table.insert(cfs, CFrame.lookAt(at, at + dir, up))
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
	-- las que sobran, fuera de la vista
	for i = used + 1, #arrows do
		arrows[i].img.TextTransparency = 1
		arrows[i].stroke.Transparency = 1
	end
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
-- el marcador sobre el destino cuando se ve: insignia del tipo con rayos que giran, una flecha hacia abajo y la
-- distancia. Se dibuja en pantalla (no con un BillboardGui: los AlwaysOnTop no salen en este juego y si no, lo
-- taparían las paredes)
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

-- Dónde está lo que pide (nil si no hay sitio al que ir) y a qué distancia ya cuenta como "has llegado"
local function homeFront()
	local plot = player:GetAttribute("Plot")
	return plot and Config.Plots[plot] and Config.frontOf(Config.Plots[plot]).Position
end
local function targetOf(go)
	local mapa = workspace:FindFirstChild("Mapa")
	local tiendas = mapa and mapa:FindFirstChild("Tiendas")
	if go == "house" then
		return homeFront(), 10
	elseif go == "wheel" then
		local booth = tiendas and tiendas:FindFirstChild("Ruleta")
		local counter = booth and booth:FindFirstChild("Mostrador", true)
		return counter and counter.Position or booth and booth:GetPivot().Position, 34
	elseif go == "fuse" then
		local station = tiendas and tiendas:FindFirstChild("Fusion")
		return station and station:GetPivot().Position, 22
	elseif go == "td" then
		local td = mapa and mapa:FindFirstChild("TowerDefense")
		local lobbies = td and td:FindFirstChild("Lobbies")
		local sum, n = Vector3.zero, 0
		for _, l in lobbies and lobbies:GetChildren() or {} do
			if l:IsA("PVInstance") then
				sum += l:GetPivot().Position
				n += 1
			end
		end
		return n > 0 and sum / n or nil, 38
	elseif go == "neighbor" then
		-- la casa ajena más cercana (de otro jugador o abandonada)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local casas = workspace:FindFirstChild("Casas")
		local best, bd
		for _, h in casas and casas:GetChildren() or {} do
			local origin = h:GetAttribute("Origin")
			if origin and h:GetAttribute("Owner") ~= player.UserId then
				local p = Config.frontOf(origin).Position
				local d = root and (p - root.Position).Magnitude or 0
				if not bd or d < bd then
					best, bd = p, d
				end
			end
		end
		return best, 10
	end
end

local function stopFollow()
	if guide then
		guide.part:Destroy()
		guide = nil
	end
	hideTrail()
	following = nil
	edge.Visible = false
	marker.Visible = false
	if refreshAll then
		refreshAll()
	end
end

-- El destino: una columna de luz del color de la misión y dos anillos que se abren en el suelo, en bucle
local function beacon(pos, color)
	local floor = groundAt(pos)
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

local function startFollow(q)
	local k = kindOf(q)
	if k.go == "scares" then
		stopFollow()
		if UI.toggleScares then
			UI.toggleScares(true)
		end
		return
	end
	local mode = player:GetAttribute("Mode")
	if k.go == "house" and mode == "home" then
		UI.toast(q.k == "place" and "You're home! Open your bag and place a scare" or "You're already in your house: scare those visitors!", UI.GREEN, "house")
		return
	end
	local pos, reach = targetOf(k.go)
	if not pos then
		return UI.toast(k.go == "house" and "You don't have a house yet: wait for a free plot!" or "Can't find the way from here", UI.RED)
	end
	stopFollow()
	following = q.id
	local color = k.color
	rayParams.FilterDescendantsInstances = {player.Character, trailFolder}
	local part, rings = beacon(pos, color)
	guide = {id = q.id, q = q, go = k.go, pos = pos, reach = reach, part = part, rings = rings, color = color, dist = "", t0 = os.clock()}
	for _, a in arrows do
		a.img.TextTransparency, a.stroke.Transparency = 1, 1
	end
	requestPath()
	edgeDisc.BackgroundColor3 = color
	UI.setIcon(edgeIcon, k.icon)
	markerDisc.BackgroundColor3 = color
	markerRays.ImageColor3 = color
	UI.setIcon(markerIcon, k.icon)
	markerScale.Scale = 0.2
	tween(markerScale, 0.45, {Scale = 1}, Enum.EasingStyle.Back)
	UI.sound("Sparkle")
	UI.toast("Follow the arrows!", color, k.icon, {chip = "GO"})
	refreshAll()
end

-- Al llegar: aviso con lo que toca hacer allí
local ARRIVE = {
	house = "Here's your house! Walk in to place scares and scare visitors",
	wheel = "The Wheel of Fright! Walk up to the counter to spin",
	fuse = "Hexa's Cauldron: melt copies of a scare into stars",
	td = "The Tower Defense lobbies: walk into one to join a match",
	neighbor = "Walk in and reach the end without fainting!",
}
local function arrive()
	local go = guide and guide.go
	stopFollow()
	UI.sound("Success")
	UI.toast(ARRIVE[go] or "You're here!", UI.GREEN, "check", {chip = "ARRIVED", time = 4})
end

RunService.RenderStepped:Connect(function()
	if not guide then
		return
	end
	local t = os.clock() - guide.t0
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
	if d <= guide.reach or (guide.go == "house" and player:GetAttribute("Mode") == "home") then
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
	local minX, maxX = math.min(c.X - 60, 280), math.max(c.X + 60, vs.X - (tracker.Visible and 360 or 80))
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

-- En el Tower Defense (o de viaje) no hay calle: se apaga
player:GetAttributeChangedSignal("Mode"):Connect(function()
	local mode = player:GetAttribute("Mode")
	if guide and (mode == "td" or mode == "travel" or mode == "lobby") then
		if guide.go == "td" then
			arrive()
		else
			stopFollow()
		end
	end
end)

local function claim(q, button)
	if button then
		button.Active = false
		task.delay(1, function()
			button.Active = true
		end)
	end
	QuestRemote:FireServer("Claim", q.id)
end

-- El botón de una misión: CLAIM si está hecha, STOP si la sigues, GO si no
local function press(q, button)
	if done(q) then
		return claim(q, button)
	end
	if following == q.id then
		UI.sound("Close")
		return stopFollow()
	end
	startFollow(q)
end

local function setButton(b, q, big)
	if done(q) then
		b.Text = "CLAIM"
		b.BackgroundColor3 = CLAIM_COLOR
	elseif following == q.id then
		b.Text = "STOP"
		b.BackgroundColor3 = STOP_COLOR
	else
		b.Text = big and (kindOf(q).go == "scares" and "OPEN" or "FOLLOW") or "GO"
		b.BackgroundColor3 = GO_COLOR
	end
	local ic = b:FindFirstChild("Icon")
	if ic then
		UI.setIcon(ic, done(q) and "gift" or following == q.id and "close" or kindOf(q).go == "scares" and "cart" or "map")
	end
end

---------- Panel de la derecha ----------
local W = 312
tracker = new("Frame", {
	Name = "Missions", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, -22), -- (encima de los botones de construir) Size = UDim2.fromOffset(W, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1, Visible = false,
}, UI.gui)
new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right}, tracker)
local trackerPop = new("UIScale", {}, tracker)

-- cabecera: el pergamino asomando, MISSIONS y el nivel de misiones; la flecha pliega el panel
local head = round(new("TextButton", {Name = "Head", Size = UDim2.fromOffset(W, 54), BackgroundColor3 = Color3.new(1, 1, 1), AutoButtonColor = false, Text = "", LayoutOrder = 0}, tracker), 16)
new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(84, 54, 132), Color3.fromRGB(30, 18, 52))}, head)
stroke(head, INK, 3.5)
local headArt = new("ImageLabel", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 34, 0.5, -6), Size = UDim2.fromOffset(78, 78), BackgroundTransparency = 1, Image = ART, Rotation = -8, ZIndex = 3}, head)
local headTitle = label({Position = UDim2.fromOffset(74, 5), Size = UDim2.new(1, -120, 0, 28), Font = UI.TITLE, TextSize = 26, TextXAlignment = LEFT, TextStrokeTransparency = 0, Text = "MISSIONS", ZIndex = 3}, head)
new("UIPadding", {PaddingTop = UDim.new(0, 4)}, headTitle)
local headSub = label({Position = UDim2.fromOffset(75, 31), Size = UDim2.new(1, -120, 0, 16), TextSize = 14, TextColor3 = UI.GOLD, TextXAlignment = LEFT, TextStrokeTransparency = 0.4, Text = "", ZIndex = 3}, head)
local fold = round(new("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(34, 34), BackgroundColor3 = UI.DARK, AutoButtonColor = false, Text = "", ZIndex = 3}, head), UDim.new(1, 0))
stroke(fold, Color3.fromRGB(120, 90, 180), 2)
local foldIcon = UI.icon("arrowR", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(24, 24), Rotation = 90, ZIndex = 4}, fold)
local headBadge = round(new("TextLabel", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -60, 0, 4), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = UI.RED,
	Font = UI.HUD_FONT, TextSize = 15, TextColor3 = WHITE, Text = "!", Visible = false, ZIndex = 6}, head), UDim.new(1, 0))
stroke(headBadge, INK, 2.5)
UI.press(head, 1.03)
UI.press(fold, 1.12)
local folded = false

local cards = {} -- [hueco] = {frame, ...}
local function makeCard(i)
	local c = round(new("TextButton", {Name = "Mission" .. i, Size = UDim2.fromOffset(W, 86), BackgroundColor3 = Color3.new(1, 1, 1), AutoButtonColor = false, Text = "", LayoutOrder = i, ClipsDescendants = false}, tracker), 16)
	local grad = new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(56, 36, 88), Color3.fromRGB(22, 13, 38))}, c)
	local st = new("UIStroke", {Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, c)
	-- brillo de cristal arriba
	local shine = round(new("Frame", {Position = UDim2.fromOffset(4, 3), Size = UDim2.new(1, -8, 0.42, 0), BackgroundColor3 = WHITE, BorderSizePixel = 0}, c), 12)
	new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(0.88, 1)}, shine)
	-- destello que cruza la carta cuando está hecha
	local sweepHolder = round(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 2}, c), 16)
	local sweep = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(-0.3, 0.5), Size = UDim2.new(0, 60, 2, 0), Rotation = 20, BackgroundColor3 = WHITE, BorderSizePixel = 0, Visible = false, ZIndex = 2}, sweepHolder)
	new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.65), NumberSequenceKeypoint.new(1, 1)})}, sweep)
	local holder = new("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(52, 52), BackgroundTransparency = 1, ZIndex = 3}, c)
	local title = label({Position = UDim2.fromOffset(72, 7), Size = UDim2.new(1, -158, 0, 38), TextSize = 16, TextXAlignment = LEFT, TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true, TextStrokeTransparency = 0, Text = "", ZIndex = 3}, c)
	local back, fill = UI.bar({Position = UDim2.new(0, 72, 1, -30), Size = UDim2.new(1, -158, 0, 20), ZIndex = 3}, c, UI.GOLD)
	local prog = label({Size = UDim2.fromScale(1, 1), Font = UI.HUD_FONT, TextSize = 13, Text = "", ZIndex = 6}, back)
	UI.hudStroke(prog, 2)
	local b = UI.button({AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(74, 50), Text = "GO", Font = UI.TITLE, TextSize = 20, BackgroundColor3 = GO_COLOR, ZIndex = 4}, c)
	local bPop = new("UIScale", {Name = "Pulse"}, b.Label)
	local newChip = UI.chip("NEW!", UI.RED, {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(-6, 2), Rotation = -8, TextSize = 13, Visible = false, ZIndex = 8}, c)
	local check = UI.icon("check", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 36, 0.5, 0), Size = UDim2.fromOffset(34, 34), Visible = false, ZIndex = 9}, c)
	local pop = new("UIScale", {}, c)
	local card = {frame = c, grad = grad, stroke = st, holder = holder, title = title, fill = fill, prog = prog, button = b, bPop = bPop, newChip = newChip, check = check, pop = pop, sweep = sweep}
	c.Activated:Connect(function()
		if UI.openMissions then
			UI.openMissions()
		end
	end)
	b.Activated:Connect(function()
		local q = quests.list[i]
		if q then
			press(q, b)
		end
	end)
	cards[i] = card
	return card
end
for i = 1, Q.SLOTS do
	makeCard(i)
end

local shown = {} -- [hueco] = {id, p} lo que se ve
local function floatText(parent, text, color)
	local f = label({AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(120, 30), Font = UI.TITLE, TextSize = 24, TextColor3 = color,
		TextStrokeTransparency = 0, Text = text, ZIndex = 20}, parent)
	local s = new("UIScale", {Scale = 0.4}, f)
	tween(s, 0.3, {Scale = 1}, Enum.EasingStyle.Back)
	tween(f, 0.9, {Position = UDim2.new(0.5, 0, 0, -26)})
	task.delay(0.55, function()
		tween(f, 0.35, {TextTransparency = 1, TextStrokeTransparency = 1})
	end)
	game:GetService("Debris"):AddItem(f, 1)
end

local function paintCard(i)
	local card, q = cards[i], quests.list[i]
	card.frame.Visible = q ~= nil and not folded
	if not q then
		return
	end
	local k = kindOf(q)
	local before = shown[i]
	if not before or before.id ~= q.id then
		-- misión nueva en este hueco
		card.holder:ClearAllChildren()
		disc(q, 52, card.holder, {ZIndex = 3})
		card.fill.Size = UDim2.fromScale(math.clamp(q.p / q.n, 0, 1), 1)
		if before then
			card.pop.Scale = 0.2
			tween(card.pop, 0.45, {Scale = 1}, Enum.EasingStyle.Back)
			card.newChip.Visible = true
			local id = q.id
			task.delay(6, function()
				if quests.list[i] and quests.list[i].id == id then
					card.newChip.Visible = false
				end
			end)
		end
	elseif q.p > before.p then
		-- ha avanzado: la barra se llena, la carta da un saltito y "+N"
		tween(card.fill, 0.45, {Size = UDim2.fromScale(math.clamp(q.p / q.n, 0, 1), 1)}, Enum.EasingStyle.Back)
		card.pop.Scale = 1.06
		tween(card.pop, 0.3, {Scale = 1}, Enum.EasingStyle.Back)
		if not kindOf(q).abs then
			floatText(card.frame, "+" .. UI.fmt(q.p - before.p), k.color:Lerp(WHITE, 0.3))
		end
	end
	shown[i] = {id = q.id, p = q.p}
	local isDone = done(q)
	card.title.Text = Q.text(q, UI.fmt)
	card.prog.Text = isDone and "COMPLETE!" or progressText(q)
	card.fill.ImageColor3 = isDone and UI.GREEN or k.color:Lerp(UI.GOLD, 0.25)
	card.grad.Color = isDone and ColorSequence.new(Color3.fromRGB(70, 110, 52), Color3.fromRGB(22, 40, 20))
		or following == q.id and ColorSequence.new(Color3.fromRGB(78, 50, 128), Color3.fromRGB(28, 16, 50))
		or ColorSequence.new(Color3.fromRGB(56, 36, 88), Color3.fromRGB(22, 13, 38))
	card.stroke.Color = isDone and UI.GOLD or following == q.id and k.color or INK
	card.stroke.Thickness = (isDone or following == q.id) and 3.5 or 3
	card.sweep.Visible = isDone
	card.check.Visible = isDone
	setButton(card.button, q, false)
	card.button.TextSize = (isDone or following == q.id) and 16 or 20
end

---------- Ventana MISSIONS ----------
local WIN = Vector2.new(940, 540)
local win, _ = UI.window({Name = "Missions", Size = UDim2.fromOffset(WIN.X, WIN.Y), Position = UDim2.new(0.5, 0, 0.5, 18), accent = Color3.fromRGB(255, 150, 50), Visible = false, noClose = true, ZIndex = 6}, UI.gui)
-- cabecera como la de las referencias: barra oscura más ancha que la ventana, la ilustración grande que se sale por
-- arriba, el título, el nivel de misiones y la X
local bar = round(new("Frame", {Name = "Header", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.new(1, 34, 0, 80), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 8}, win), 18)
new("UIGradient", {Rotation = 90, Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(72, 48, 112)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(40, 26, 66)), ColorSequenceKeypoint.new(1, Color3.fromRGB(24, 14, 42)),
})}, bar)
stroke(bar, INK, 4.5)
local barShine = round(new("Frame", {Position = UDim2.fromOffset(5, 4), Size = UDim2.new(1, -10, 0.45, 0), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 8}, bar), 14)
new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(0.86, 1)}, barShine)
local winArt = new("ImageLabel", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 62, 0.5, -10), Size = UDim2.fromOffset(132, 132), BackgroundTransparency = 1, Image = ART, Rotation = -8, ZIndex = 10}, bar)
local winTitle = label({Position = UDim2.fromOffset(134, 6), Size = UDim2.fromOffset(400, 64), Font = UI.TITLE, TextSize = 50, TextXAlignment = LEFT, Text = "MISSIONS", ZIndex = 10}, bar)
new("UIPadding", {PaddingTop = UDim.new(0, 8)}, winTitle)
new("UIStroke", {Color = INK, Thickness = 5, LineJoinMode = Enum.LineJoinMode.Round}, winTitle)
new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 240, 200), Color3.fromRGB(255, 186, 70))}, winTitle)
-- nivel de misiones
local lvlPill = round(new("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -96, 0.5, 0), Size = UDim2.fromOffset(0, 46), AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = UI.DARK, BackgroundTransparency = 0.1, ZIndex = 9}, bar), 12)
stroke(lvlPill, Color3.fromRGB(110, 80, 170), 2)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, lvlPill)
new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 16)}, lvlPill)
UI.icon("trophy", {Size = UDim2.fromOffset(34, 34), LayoutOrder = 1, ZIndex = 10}, lvlPill)
local lvlText = label({Size = UDim2.fromOffset(0, 46), AutomaticSize = Enum.AutomaticSize.X, Font = UI.HUD_FONT, TextSize = 19, Text = "", RichText = true, LayoutOrder = 2, ZIndex = 10}, lvlPill)
UI.hudStroke(lvlText, 2)
local close = UI.closeButton(bar, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(66, 66), ZIndex = 10})

-- título de la sección y, a la derecha, cómo funcionan
local sectionIcon = UI.icon("scroll", {Position = UDim2.fromOffset(28, 66), Size = UDim2.fromOffset(42, 42), ZIndex = 4}, win)
local section = label({Position = UDim2.fromOffset(78, 68), Size = UDim2.fromOffset(330, 40), Font = UI.TITLE, TextSize = 27, TextXAlignment = LEFT, TextStrokeTransparency = 0, Text = "ACTIVE MISSIONS", ZIndex = 4}, win)
new("UIPadding", {PaddingTop = UDim.new(0, 5)}, section)
local how = round(new("Frame", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 66), Size = UDim2.fromOffset(0, 42), AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = UI.DARK, BackgroundTransparency = 0.25, ZIndex = 4}, win), 10)
stroke(how, Color3.fromRGB(100, 72, 150), 2)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, how)
new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 14)}, how)
UI.icon("lightning", {Size = UDim2.fromOffset(28, 28), LayoutOrder = 1, ZIndex = 5}, how)
label({Size = UDim2.fromOffset(0, 42), AutomaticSize = Enum.AutomaticSize.X, TextSize = 16, TextColor3 = MUTED, TextStrokeTransparency = 0.5,
	Text = "Finish one and a harder one appears, with bigger rewards!", LayoutOrder = 2, ZIndex = 5}, how)

local rowsFrame = new("Frame", {Position = UDim2.fromOffset(24, 122), Size = UDim2.new(1, -48, 0, 3 * 112 + 2 * 12), BackgroundTransparency = 1, ZIndex = 4}, win)
new("UIListLayout", {Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder}, rowsFrame)

-- pie: misiones cumplidas en total
local footer = label({AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.new(1, -60, 0, 24), TextSize = 16, TextColor3 = MUTED,
	TextStrokeTransparency = 0.5, RichText = true, Text = "", ZIndex = 4}, win)

local REWARD_ART = {{"coin", "c", Color3.fromRGB(255, 214, 70)}, {"gem", "g", Color3.fromRGB(150, 236, 255)}, {"lightning", "x", Color3.fromRGB(140, 255, 150)}}
local rows = {}
local function makeRow(i)
	local r = round(new("Frame", {Name = "Row" .. i, Size = UDim2.new(1, 0, 0, 112), BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = i, ZIndex = 4}, rowsFrame), 18)
	local grad = new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(46, 30, 72), Color3.fromRGB(22, 14, 38))}, r)
	local st = new("UIStroke", {Color = INK, Thickness = 3.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, r)
	local bevel = round(new("Frame", {Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), BackgroundTransparency = 1, ZIndex = 4}, r), 14)
	local bevelStroke = new("UIStroke", {Color = Color3.fromRGB(120, 90, 180), Thickness = 2, Transparency = 0.5}, bevel)
	local holder = new("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 18, 0.5, 0), Size = UDim2.fromOffset(70, 70), BackgroundTransparency = 1, ZIndex = 5}, r)
	local title = label({Position = UDim2.fromOffset(104, 16), Size = UDim2.fromOffset(285, 30), Font = UI.FONT, TextSize = 23, TextXAlignment = LEFT, TextStrokeTransparency = 0,
		TextTruncate = Enum.TextTruncate.AtEnd, Text = "", ZIndex = 5}, r)
	local desc = label({Position = UDim2.fromOffset(104, 48), Size = UDim2.fromOffset(278, 46), TextSize = 16, TextColor3 = MUTED, TextXAlignment = LEFT,
		TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, TextStrokeTransparency = 0.6, Text = "", ZIndex = 5}, r)
	-- progreso: "2 / 5" encima de la barra
	local prog = label({Position = UDim2.fromOffset(394, 22), Size = UDim2.fromOffset(124, 30), Font = UI.HUD_FONT, TextSize = 24, Text = "", ZIndex = 5}, r)
	UI.hudStroke(prog, 2.4)
	local back, fill = UI.bar({Position = UDim2.fromOffset(394, 60), Size = UDim2.fromOffset(124, 22), ZIndex = 5}, r, UI.GOLD)
	-- recompensas: cuadros oscuros con el icono y la cantidad abajo
	local rewards = {}
	for k, d in REWARD_ART do
		local tile = round(new("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 532 + (k - 1) * 64, 0.5, 0), Size = UDim2.fromOffset(58, 66),
			BackgroundColor3 = Color3.fromRGB(16, 10, 28), BackgroundTransparency = 0.15, ZIndex = 5}, r), 10)
		stroke(tile, Color3.fromRGB(90, 66, 140), 2)
		local ic = UI.art(d[1], {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(40, 40), ZIndex = 6}, tile)
		local amt = label({AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.new(1, 4, 0, 18), Font = UI.HUD_FONT, TextSize = 14, TextColor3 = d[3], Text = "", ZIndex = 7}, tile)
		UI.hudStroke(amt, 1.8)
		rewards[k] = {tile = tile, icon = ic, amount = amt, field = d[2]}
	end
	local b = UI.iconButton({AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(142, 58), Text = "FOLLOW", Font = UI.TITLE, TextSize = 21,
		BackgroundColor3 = GO_COLOR, ZIndex = 6}, r, "map")
	local check = UI.icon("check", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 53, 0.5, 0), Size = UDim2.fromOffset(44, 44), Visible = false, ZIndex = 9}, r)
	local pop = new("UIScale", {}, r)
	local bPop = new("UIScale", {Name = "Pulse"}, b.Label)
	b.Activated:Connect(function()
		local q = quests.list[i]
		if q then
			press(q, b)
			if not done(q) and following == q.id then
				UI.closeMissions() -- (a seguir las flechas)
			end
		end
	end)
	rows[i] = {frame = r, grad = grad, stroke = st, bevel = bevelStroke, holder = holder, title = title, desc = desc, prog = prog, fill = fill, rewards = rewards, button = b, bPop = bPop, check = check, pop = pop}
end
for i = 1, Q.SLOTS do
	makeRow(i)
end

local rowShown = {}
local function paintRow(i)
	local row, q = rows[i], quests.list[i]
	row.frame.Visible = q ~= nil
	if not q then
		return
	end
	local k = kindOf(q)
	if rowShown[i] ~= q.id then
		rowShown[i] = q.id
		row.holder:ClearAllChildren()
		disc(q, 70, row.holder, {ZIndex = 5})
	end
	local isDone = done(q)
	row.title.Text = Q.text(q, UI.fmt)
	row.desc.Text = k.desc
	row.prog.Text = isDone and "COMPLETE!" or progressText(q)
	row.prog.TextColor3 = isDone and UI.GREEN or WHITE
	tween(row.fill, 0.35, {Size = UDim2.fromScale(math.clamp(q.p / q.n, 0, 1), 1)})
	row.fill.ImageColor3 = isDone and UI.GREEN or k.color:Lerp(UI.GOLD, 0.25)
	for _, rw in row.rewards do
		local v = q[rw.field] or 0
		rw.amount.Text = rw.field == "x" and (UI.fmt(v) .. " XP") or UI.fmt(v)
		rw.tile.Visible = v > 0
	end
	row.grad.Color = isDone and ColorSequence.new(Color3.fromRGB(58, 96, 46), Color3.fromRGB(20, 36, 18))
		or ColorSequence.new(Color3.fromRGB(46, 30, 72), Color3.fromRGB(22, 14, 38))
	row.bevel.Color = isDone and UI.GOLD or following == q.id and k.color or Color3.fromRGB(120, 90, 180)
	row.bevel.Transparency = (isDone or following == q.id) and 0.1 or 0.5
	row.check.Visible = isDone
	setButton(row.button, q, true)
end

local function setOpen(open)
	if win.Visible == open then
		return
	end
	UI.sound(open and "Open" or "Close")
	win.Visible = open
	if open then
		if UI.toggleShop then
			UI.toggleShop(false)
		end
		refreshAll()
		UI.popIn(win)
	end
end
function UI.openMissions()
	setOpen(true)
end
function UI.closeMissions()
	setOpen(false)
end
close.Activated:Connect(function()
	setOpen(false)
end)
head.Activated:Connect(function()
	setOpen(not win.Visible)
end)
fold.Activated:Connect(function()
	folded = not folded
	tween(foldIcon, 0.2, {Rotation = folded and -90 or 90})
	refreshAll()
end)

---------- Pintar todo ----------
function refreshAll()
	local ready = 0
	for i = 1, Q.SLOTS do
		paintCard(i)
		paintRow(i)
		if quests.list[i] and done(quests.list[i]) then
			ready += 1
		end
	end
	headSub.Text = ready > 0 and ("%d ready to claim!"):format(ready) or ("Mission Level %d"):format(quests.lvl + 1)
	headSub.TextColor3 = ready > 0 and UI.GREEN or UI.GOLD
	headBadge.Visible = ready > 0
	headBadge.Text = tostring(ready)
	lvlText.Text = ("MISSION LEVEL <font color=\"#FFD446\">%d</font>"):format(quests.lvl + 1)
	footer.Text = quests.lvl > 0 and ("Missions completed: <font color=\"#FFD446\">%s</font>  ·  Tip: press FOLLOW and chase the glowing arrows!"):format(UI.fmt(quests.lvl))
		or "Tip: press <font color=\"#FF8A1E\">FOLLOW</font> and chase the glowing arrows to find where to go!"
end

-- Animaciones que no paran: el botón de CLAIM late, el destello cruza las cartas hechas, la insignia salta
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for i, card in cards do
		local q = quests.list[i]
		local live = q and (done(q) or following == q.id)
		card.bPop.Scale = live and (1 + 0.07 * math.sin(t * 7)) or 1
		if q and done(q) then
			local a = (t * 0.6 + i * 0.3) % 1.6
			card.sweep.Position = UDim2.fromScale(-0.3 + a, 0.5)
			card.check.Rotation = math.sin(t * 3 + i) * 8
		end
	end
	for i, row in rows do
		local q = quests.list[i]
		row.bPop.Scale = (q and done(q)) and (1 + 0.06 * math.sin(t * 7)) or 1
	end
	headBadge.Rotation = math.sin(t * 5) * 10
	headArt.Rotation = -8 + math.sin(t * 1.6) * 4
	winArt.Rotation = -8 + math.sin(t * 1.4) * 4
end)

---------- Datos del servidor ----------
local function read()
	local raw = player:GetAttribute("Quests")
	local ok, d = pcall(HttpService.JSONDecode, HttpService, raw or "")
	if ok and typeof(d) == "table" then
		quests = {lvl = d.lvl or 0, list = d.list or {}}
	end
	if following and not byId(following) then
		stopFollow()
	end
	refreshAll()
end
player:GetAttributeChangedSignal("Quests"):Connect(read)
read()

QuestRemote.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "Done" then
		local q, i = byId(a)
		if following == a then
			stopFollow()
		end
		UI.sound("Sparkle")
		UI.toast(q and (Q.text(q, UI.fmt) .. "  ·  claim your reward!") or "Claim your reward!", UI.GREEN, "check", {chip = "MISSION COMPLETE", time = 4.5})
		if i and cards[i] then
			cards[i].pop.Scale = 1.18
			tween(cards[i].pop, 0.5, {Scale = 1}, Enum.EasingStyle.Elastic)
		end
	elseif kind == "Claimed" then
		-- a = la misión cobrada (con sus premios), c = nivel de misiones
		local q = a
		local from
		for i, s in shown do
			if s.id == q.id or s.id == b then -- (el hueco: la cobrada o la que ya ha ocupado su sitio)
				local f = win.Visible and rows[i].frame or cards[i].frame
				from = f.AbsolutePosition + f.AbsoluteSize / 2 + game:GetService("GuiService"):GetGuiInset()
			end
		end
		UI.sound("Success")
		UI.sound("Coins")
		UI.confetti(70, from)
		if from and q.c > 0 then
			UI.coinFly(from, 10)
		end
		local parts = {}
		if q.c > 0 then
			table.insert(parts, "+" .. UI.fmt(q.c) .. " coins")
		end
		if q.g > 0 then
			table.insert(parts, "+" .. UI.fmt(q.g) .. " gems")
		end
		if q.x > 0 then
			table.insert(parts, "+" .. UI.fmt(q.x) .. " XP")
		end
		UI.toast(table.concat(parts, "  ·  "), UI.GOLD, "gift", {chip = "REWARD", time = 4})
		if c and c % 5 == 0 then
			UI.big("MISSION LEVEL " .. (c + 1), "New missions are harder... and pay more!", UI.GOLD, 3)
		end
	end
end)

---------- ¿Se ve el panel? ----------
-- En la calle y dentro de tu casa; no en el Tower Defense (ni en su lobby o de viaje), ni con ventanas, diálogos o
-- la portada encima
local function wanted()
	if player:GetAttribute("TDCash") ~= nil or player:GetAttribute("Lobby") then
		return false
	end
	local mode = player:GetAttribute("Mode")
	if mode == "td" or mode == "travel" or mode == "lobby" then
		return false
	end
	if #quests.list == 0 or UI.menuOpen() then
		return false
	end
	for _, name in {"Dialogo", "Portada", "VisitorBook", "Troops", "Scares", "Shop"} do
		local g = playerGui:FindFirstChild(name)
		if g and g:IsA("ScreenGui") and g.Enabled then
			local root = g:FindFirstChildWhichIsA("GuiObject")
			if name == "Dialogo" or name == "Portada" or name == "VisitorBook" or (root and root.Visible) then
				return false
			end
		end
	end
	return true
end

local visible = false
task.spawn(function()
	while true do
		local want = wanted()
		if want ~= visible then
			visible = want
			tracker.Visible = want
			if want then
				trackerPop.Scale = 0.85
				tween(trackerPop, 0.3, {Scale = 1}, Enum.EasingStyle.Back)
			end
		end
		-- (la flecha del borde, solo con el HUD a la vista)
		edgeGui.Enabled = UI.gui.Enabled and not UI.menuOpen()
		task.wait(0.2)
	end
end)

-- (pruebas: MisionesDebug:Fire("open") / ("follow", hueco) desde la barra de comandos)
local dbg = new("BindableEvent", {Name = "MisionesDebug"}, script)
dbg.Event:Connect(function(cmd, a)
	if cmd == "open" then
		setOpen(true)
	elseif cmd == "close" then
		setOpen(false)
	elseif cmd == "follow" and quests.list[a] then
		startFollow(quests.list[a])
	elseif cmd == "stop" then
		stopFollow()
	end
end)
