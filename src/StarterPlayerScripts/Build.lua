-- Modo edición: SOLO dentro de tu casa. Andas por ella con tu personaje y la cámara normal; arrastras sustos
-- desde la barra hasta el suelo, R los gira y pinchando uno ya colocado lo coges para moverlo o guardarlo.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Config = require(RS:WaitForChild("Config"))
local Assets = RS:WaitForChild("Assets")
local Remote = RS:WaitForChild("Remote")
local UI = require(script.Parent:WaitForChild("UI"))
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	camera = workspace.CurrentCamera
end)

local Build = {active = false}

local house
local dragging -- {type, model, highlight, guide, start, moved, fromWorld, valid, x, z, reason, tilt, tiltVel}
local rotation = 0
local pointer = Vector2.zero
local touch -- en móvil, el dedo que mueve el puntero (no el del joystick)
-- balanceo del susto en la mano: se inclina contra el movimiento (inercia) y oscila un poco al parar
local SWAY = 0.014 -- radianes de inclinación por stud/s de velocidad
local MAX_TILT = 0.22 -- inclinación máxima (rad)
local STIFF, DAMP = 140, 9 -- muelle: más STIFF = vuelve antes; menos DAMP = más rebote
local LIFT = 0.3 -- cuánto se levanta del suelo mientras lo llevas
local lastSnap = 0 -- último tic de la rejilla
local DOUBLE_CLICK = 0.4 -- segundos entre los dos clics de un doble clic (guarda el susto en la mochila)
local hover = Instance.new("Highlight")
hover.FillTransparency = 1
hover.OutlineColor = Color3.new(1, 1, 1)
hover.DepthMode = Enum.HighlightDepthMode.Occluded
local saved
local tip = UI.new("TextLabel", {
	Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = UI.DARK, BackgroundTransparency = 0.2,
	Font = UI.FONT, TextSize = 18, TextColor3 = UI.RED, Visible = false, ZIndex = 20,
}, UI.gui)

local function rooms()
	return house and house:GetAttribute("Rooms") or 1
end

-- Medio fondo de lo que SE VE del susto (el modelo puede sobresalir de su hueco en el suelo: la momia, el dragón...)
local visualHalf = {}
local function halfDepth(t, r)
	local key = t .. r % 2
	if not visualHalf[key] then
		local tpl = Assets.Scares:FindFirstChild(t)
		local ext = tpl and tpl:GetExtentsSize() or Vector3.zero
		visualHalf[key] = math.max(Config.footprint(t, r).Y, r % 2 == 1 and ext.X or ext.Z) / 2
	end
	return visualHalf[key]
end

-- El susto no se deja llevar a la entrada ni a través de las paredes: se queda pegado al borde de la zona válida.
-- (En la puerta estorbaría: los visitantes se asustarían nada más entrar, sin recorrer la casa, y taparía la salida.)
local function clampToFloor(t, r, x, z)
	local fp = Config.footprint(t, r)
	local maxX = Config.roomW(house) / 2 - 0.5 - fp.X / 2
	local minZ = math.ceil((Config.ENTRY_SAFE + halfDepth(t, r)) * 2) / 2
	local maxZ = math.floor((rooms() * Config.ROOM_D - Config.BACK_SAFE - fp.Y / 2) * 2) / 2
	return math.clamp(x, -math.floor(maxX * 2) / 2, math.floor(maxX * 2) / 2), math.clamp(z, minZ, math.max(minZ, maxZ))
end

-- Rayo desde la cámara por el puntero contra la casa (paredes incluidas: no se coloca a través de un muro)
local function cast()
	if not house then
		return nil
	end
	local list = {}
	for _, name in {"Shell", "Floors", "Props", "Scares", "Roof"} do
		local f = house:FindFirstChild(name)
		if f then
			table.insert(list, f)
		end
	end
	local ray = camera:ScreenPointToRay(pointer.X, pointer.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = list
	return workspace:Raycast(ray.Origin, ray.Direction * 300, params)
end

-- El susto (modelo dentro de Scares) al que pertenece una pieza, si es uno
local function scareOf(inst)
	local folder = house and house:FindFirstChild("Scares")
	if not folder or not inst:IsDescendantOf(folder) then
		return nil
	end
	local m = inst
	while m.Parent ~= folder do
		m = m.Parent
	end
	return m
end

local function overBar(pos)
	pos = pos or pointer
	for _, o in player.PlayerGui:GetGuiObjectsAtPosition(pos.X, pos.Y) do
		if o:IsDescendantOf(UI.buildBar) and o.Visible then
			return true
		end
	end
	return false
end

-- Guía en el suelo mientras colocas un susto: su alcance hecho con Beams (brillo suave con degradado, borde con halo,
-- un anillo a media distancia y una onda de radar que lo recorre hacia fuera). Si ataca hacia delante es un sector con
-- tres chevrones que marcan la dirección; si no, un círculo. Delante = -Z del pivote.
local FLAT = CFrame.Angles(0, 0, math.pi / 2) -- un Beam se ensancha por el eje Y de sus Attachments: así queda plano
local RIM = NumberSequence.new(0.1)
local INNER = NumberSequence.new(0.72)
local HALO = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1)})
local EDGE = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.95), NumberSequenceKeypoint.new(1, 0.1)})

local function makeGuide(t)
	local def = Config.Scares[t]
	local g = {model = Instance.new("Model"), fill = {}, beams = {}, atts = {}, chevrons = {}}
	g.model.Name = "Guide"
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.one * 0.2
	base.Transparency = 1
	base.Anchored = true
	base.CanCollide, base.CanQuery, base.CanTouch = false, false, false
	base.Parent = g.model
	g.model.PrimaryPart = base
	local function beam(p0, p1, w0, w1, transparency)
		local dir = p1 - p0
		local b = Instance.new("Beam")
		for i, p in {p0, p1} do
			local a = Instance.new("Attachment")
			a.CFrame = CFrame.lookAt(p, p + dir) * FLAT
			a.Parent = base
			table.insert(g.atts, {a, a.CFrame})
			b["Attachment" .. (i - 1)] = a
		end
		b.Width0, b.Width1 = w0, w1
		b.FaceCamera, b.Segments = false, 1
		b.LightEmission, b.LightInfluence = 1, 0
		b.Transparency = transparency
		b.Parent = base
		table.insert(g.beams, {b, w0, w1})
		return b
	end
	local r = def.radius
	local half = def.facing and math.rad(Config.REACH_ANGLE / 2) or math.pi
	local n = def.facing and 24 or 48
	local step = 2 * half / n
	local k, w = math.cos(step / 2), 2 * math.sin(step / 2) -- de un radio a la cuerda de cada porción
	local function at(a, d, y)
		return Vector3.new(math.sin(a) * d, y, -math.cos(a) * d)
	end
	for i = 0, n - 1 do
		local a0, mid = -half + step * i, -half + step * (i + 0.5)
		-- relleno: un triángulo (Beam de ancho 0 a la cuerda) desde el centro; halo: un trapecio hacia fuera del borde
		table.insert(g.fill, beam(at(mid, 0, 0.05), at(mid, r * k, 0.05), 0, r * w, RIM))
		beam(at(mid, r * k, 0.06), at(mid, (r + 1) * k, 0.06), r * w, (r + 1) * w, HALO)
		beam(at(a0, r, 0.07), at(a0 + step, r, 0.07), 0.22, 0.22, RIM)
		beam(at(a0, r / 2, 0.06), at(a0 + step, r / 2, 0.06), 0.07, 0.07, INNER)
	end
	if def.facing then
		for _, a in {-half, half} do
			beam(at(a, 0.4, 0.07), at(a, r, 0.07), 0.04, 0.22, EDGE)
		end
		local front = def.size.Y / 2 + 0.7
		for i = 0, 2 do
			local point = Vector3.new(0, 0.08, -(front + i * 1.1))
			g.chevrons[i + 1] = {}
			for side = -1, 1, 2 do
				table.insert(g.chevrons[i + 1], beam(point, point + Vector3.new(side, 0, 1).Unit * 1.4, 0.3, 0.3, RIM))
			end
		end
	end
	return g
end

-- Cada frame: aparece creciendo (se pasa un poco y vuelve), la onda de radar sale del centro, los chevrones laten
-- hacia fuera y todo se tiñe del color que toque (rojo donde no cabe)
local function animateGuide(g, color, now)
	g.born = g.born or now
	if not g.grown then
		local a = math.min((now - g.born) / 0.35, 1)
		g.grown = a >= 1
		a -= 1
		local s = 1 + a * a * (2.7 * a + 1.7)
		for _, x in g.atts do
			x[1].CFrame = x[2].Rotation + x[2].Position * Vector3.new(s, 1, s)
		end
		for _, x in g.beams do
			x[1].Width0, x[1].Width1 = x[2] * s, x[3] * s
		end
	end
	local phase = (now * 0.75) % 1.4 - 0.2
	local kps = table.create(20)
	for i = 0, 19 do
		local t = i / 19
		local wave = math.exp(-((t - phase) / 0.07) ^ 2) * 0.35 * math.sqrt(t)
		kps[i + 1] = NumberSequenceKeypoint.new(t, math.clamp(1 - 0.4 * t ^ 1.6 - wave, 0, 1))
	end
	local seq = NumberSequence.new(kps)
	for _, b in g.fill do
		b.Transparency = seq
	end
	for i, arms in g.chevrons do
		local tr = NumberSequence.new(1 - 0.95 * (0.35 + 0.65 * (math.sin(now * 5 - (i - 1) * 1.3) + 1) / 2))
		for _, b in arms do
			b.Transparency = tr
		end
	end
	if color ~= g.color then
		g.color = color
		local cs = ColorSequence.new(color)
		for _, x in g.beams do
			x[1].Color = cs
		end
	end
end

-- Oculta (o vuelve a mostrar) el susto colocado que has cogido: hasta que el servidor lo borra, que no tape el rayo
-- ni se vea doble
local function ghost(m, on)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = on and 1 or 0
			if on then
				p:SetAttribute("QueryWas", p.CanQuery)
				p.CanQuery = false
			elseif p:GetAttribute("QueryWas") ~= nil then
				p.CanQuery = p:GetAttribute("QueryWas")
			end
		end
	end
end

function Build.cancel()
	if dragging then
		if dragging.source and dragging.source.Parent then
			ghost(dragging.source, false) -- el servidor no lo ha recogido: vuelve a verse
		end
		dragging.model:Destroy()
		dragging.guide.model:Destroy()
		if dragging.locked and camera.CameraType == Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Custom
		end
		dragging = nil
	end
	tip.Visible = false
end

function Build.rotate()
	rotation = (rotation + 1) % 4
	UI.sound("Rotate")
end

function Build.startDrag(t, fromWorld, source)
	if not Build.active or dragging then
		return
	end
	if not fromWorld and (player:GetAttribute("Inv_" .. t) or 0) < 1 then
		if not Config.inShop(t) then
			local src = UI.sourceInfo(t)
			UI.toast("None left: get it from " .. Config.sourceText(t), UI.ORANGE, src.icon)
			UI.openSource(t)
		else
			UI.toast("None left: buy more in Scares", UI.ORANGE)
			UI.toggleScares(true, t)
		end
		return
	end
	UI.sound("Pickup")
	local def = Config.Scares[t]
	local model = Assets.Scares[Config.skinFor(player, t)]:Clone() -- (con tu skin equipada, como saldrá al soltarlo)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
			if d.Name == "Hitbox" then
				d.Transparency = 1
			elseif d.Name == "Path" then
				d.Transparency = 0.35
			elseif d:GetAttribute("T") then
				d.Transparency = d:GetAttribute("T")
			end
		elseif d:IsA("Sound") or d:IsA("ParticleEmitter") then
			d:Destroy()
		end
	end
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.55
	highlight.OutlineTransparency = 0
	highlight.Parent = model
	model.Parent = camera
	local guide = makeGuide(t)
	guide.model.Parent = camera
	-- puedes andar y girar la cámara con el susto en la mano: te sigue. Solo en móvil, al coger uno ya colocado, la
	-- cámara se queda quieta mientras arrastras (si no, el dedo la giraría)
	local locked = fromWorld and UIS:GetLastInputType() == Enum.UserInputType.Touch
	if locked then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	if source then
		ghost(source, true)
	end
	-- moved empieza en false también al coger uno colocado: un clic sin arrastrar lo lleva hasta el siguiente clic
	dragging = {type = t, model = model, highlight = highlight, guide = guide, locked = locked, start = pointer, moved = false, fromWorld = fromWorld, source = source,
		tilt = Vector3.zero, tiltVel = Vector3.zero, picked = os.clock()}
	-- hasta apuntar al suelo, que no se vea flotando en mitad de la pantalla
	model:PivotTo(CFrame.new(0, -1000, 0))
	guide.model:PivotTo(CFrame.new(0, -1000, 0))
end

-- Pone el susto en d.cf con su balanceo: se inclina contra la velocidad con la que se mueve (si lo llevas a la
-- derecha, se va hacia la izquierda) y un muelle lo devuelve con un pequeño vaivén. Los del suelo pivotan en su
-- base (y se levantan lo justo para no hundirse al inclinarse); los del techo cuelgan de él como un péndulo.
local function sway(d, dt)
	local def = Config.Scares[d.type]
	local pos = d.cf.Position
	local vel = d.last and dt > 0 and (pos - d.last) / dt or Vector3.zero
	d.last = pos
	local target = Vector3.new(-vel.X, 0, -vel.Z) * SWAY
	if target.Magnitude > MAX_TILT then
		target = target.Unit * MAX_TILT
	end
	local h = math.min(dt, 1 / 30) -- paso estable aunque baje el framerate
	d.tiltVel += ((target - d.tilt) * STIFF - d.tiltVel * DAMP) * h
	d.tilt += d.tiltVel * h
	local angle = d.tilt.Magnitude
	local cf = d.cf
	if angle > 1e-4 then
		local pivot = (cf * CFrame.new(0, def.ceiling and Config.roomH(house) or 0, 0)).Position
		local rot = CFrame.fromAxisAngle(Vector3.yAxis:Cross(d.tilt).Unit, def.ceiling and -angle or angle)
		cf = CFrame.new(pivot) * rot * CFrame.new(-pivot) * cf
	end
	if not def.ceiling then
		cf += Vector3.new(0, LIFT + math.max(def.size.X, def.size.Y) / 2 * math.sin(angle), 0)
	end
	d.model:PivotTo(cf)
end

local updateDrag

local function drop()
	local d = dragging
	updateDrag(0) -- un clic rápido puede soltar antes del primer frame: calcula ya dónde cae
	Build.cancel()
	if overBar() then
		if d.fromWorld then
			UI.toast("Stored in your bag", UI.GOLD)
			UI.sound("Store")
		end
		return
	end
	if d.valid then
		Remote:FireServer("Place", d.type, d.x, d.z, rotation)
		UI.sound("Place")
		UI.sound("Sparkle", 0.7)
	elseif d.fromWorld then
		UI.toast("Stored in your bag", UI.GOLD)
		UI.sound("Store")
	elseif d.reason then
		UI.toast(d.reason, UI.RED)
	end
end

function updateDrag(dt)
	local d = dragging
	if (pointer - d.start).Magnitude > 10 then
		d.moved = true
	end
	local hit = cast()
	d.valid, d.reason = false, nil
	local floors = house:FindFirstChild("Floors")
	if hit and floors and hit.Instance:IsDescendantOf(floors) then
		local origin = house:GetAttribute("Origin")
		local p = origin:PointToObjectSpace(hit.Position)
		d.x, d.z = clampToFloor(d.type, rotation, math.round(p.X * 2) / 2, math.round(-p.Z * 2) / 2)
		local r = rooms()
		-- (la comprobación calcula la ruta por la casa: solo se repite al cambiar de casilla o de giro)
		local key = ("%g,%g,%d,%d"):format(d.x, d.z, rotation, #house.Scares:GetChildren())
		if key ~= d.key then
			d.key = key
			d.ok, d.why = Config.canPlace(house, r, d.type, d.x, d.z, rotation)
		end
		d.valid, d.reason = d.ok, d.why
		local slots = Config.slots(d.type)
		if d.valid and (player:GetAttribute("Placed") or 0) + slots > (house and house:GetAttribute("Spaces") or r * Config.SCARES_PER_ROOM) then
			d.valid, d.reason = false, slots > 1 and ("Not enough space: it takes %d spaces"):format(slots) or "Scare limit reached: buy a bigger house"
		end
		-- un tic por cada casilla de la rejilla (más grave si ahí no cabe)
		if (d.x ~= d.cellX or d.z ~= d.cellZ) and os.clock() - lastSnap > 0.05 then
			d.cellX, d.cellZ, lastSnap = d.x, d.z, os.clock()
			UI.sound("Snap", 1, d.valid and 1 or 0.75)
		end
		-- se desliza hasta la casilla y gira suave al pulsar R (la primera vez aparece directamente)
		local cf = Config.scareCFrame(origin, d.x, d.z, rotation)
		d.cf = d.cf and d.cf:Lerp(cf, 1 - math.exp(-dt * 22)) or cf
	elseif hit and not overBar() then
		d.reason = "Point at the floor of your house"
	end
	if d.cf then
		sway(d, dt)
		d.guide.model:PivotTo(d.cf) -- la guía no se balancea: se queda plana en el suelo
		animateGuide(d.guide, d.valid and Config.Categories[Config.Scares[d.type].cat].color or UI.RED, os.clock())
	end
	d.highlight.FillColor = d.valid and UI.GREEN or UI.RED
	d.highlight.OutlineColor = d.valid and UI.GREEN or UI.RED
	tip.Visible = d.reason ~= nil and not overBar()
	if tip.Visible then
		tip.Text = "  " .. d.reason .. "  "
		tip.Position = UDim2.fromOffset(pointer.X + 18, pointer.Y + 10)
	end
end

function Build.enter(model)
	house = model
	Build.active = true
	rotation = 0
	-- un poco más de luz para ver bien lo que decoras, y la cámara sin alejarse más allá de las paredes
	saved = {Ambient = Lighting.Ambient, ExposureCompensation = Lighting.ExposureCompensation, zoom = player.CameraMaxZoomDistance}
	Lighting.Ambient = Color3.fromRGB(92, 82, 104)
	-- (sin subir mucho la exposición: con las luces de los sustos lo cercano se quemaba en blanco)
	Lighting.ExposureCompensation = math.max(saved.ExposureCompensation, 0.2)
	player.CameraMaxZoomDistance = 22
	UI.buildBar.Visible = true
	UI.menu.Visible = false
	UI.setHint("Decorate your house", "Drag scares onto the floor  ·  R rotates  ·  Click a scare to move it  ·  Double-click to store it  ·  Walk out the door when you're done", "ghost")
end

function Build.exit()
	Build.cancel()
	hover.Parent = nil
	if saved then
		Lighting.Ambient = saved.Ambient
		Lighting.ExposureCompensation = saved.ExposureCompensation
		player.CameraMaxZoomDistance = saved.zoom
		saved = nil
	end
	Build.active = false
	house = nil
	UI.buildBar.Visible = false
end

---------- Entrada ----------
local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

UIS.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input == touch then
		pointer = Vector2.new(input.Position.X, input.Position.Y)
	end
end)

UIS.InputBegan:Connect(function(input, processed)
	if isPress(input) then
		-- un dedo sobre otro botón (el joystick, por ejemplo) no mueve el puntero: así puedes andar con el susto
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		local isTouch = input.UserInputType == Enum.UserInputType.Touch
		if not isTouch or not processed or overBar(pos) then
			pointer = pos
			touch = isTouch and input or nil
		end
	end
	if not Build.active or processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.R then
		Build.rotate()
	end
	-- doble clic en un susto colocado: el primer clic ya lo ha devuelto a la mochila (Pickup); el segundo lo deja ahí
	if isPress(input) and dragging and dragging.fromWorld and dragging.carried and not dragging.moved
		and os.clock() - dragging.picked < DOUBLE_CLICK then
		dragging.source = nil -- sigue oculto hasta que el servidor lo borre
		Build.cancel()
		UI.toast("Stored in your bag", UI.GOLD)
		UI.sound("Store")
		return
	end
	-- pinchar un susto colocado lo coge para moverlo (o devolverlo a la barra)
	if isPress(input) and not dragging then
		local hit = cast()
		local m = hit and scareOf(hit.Instance)
		if m and m:GetAttribute("Busy") then
			UI.toast("It's scaring someone: wait a moment", UI.ORANGE)
		elseif m then
			rotation = m:GetAttribute("R") or rotation
			Remote:FireServer("Pickup", m:GetAttribute("Id"))
			Build.startDrag(m.Name, true, m)
		end
	end
end)

UIS.InputEnded:Connect(function(input)
	if not dragging or not isPress(input) then
		return
	end
	if not dragging.moved and not dragging.carried and (overBar() or dragging.fromWorld) then
		dragging.carried = true
		return -- solo has pulsado (la tarjeta o el susto): lo llevas hasta el siguiente clic
	end
	drop()
end)

RunService.RenderStepped:Connect(function(dt)
	if not Build.active or not house or not house.Parent then
		return
	end
	if dragging then
		hover.Parent = nil
		updateDrag(dt)
	else
		local hit = not overBar() and cast()
		hover.Parent = hit and scareOf(hit.Instance) or nil
	end
end)

return Build
