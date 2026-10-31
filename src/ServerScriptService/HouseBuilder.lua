-- Construye una casa encantada completa: fachada, tejado, porche, jardín, interiores decorados y puerta-portal.
-- Todo se calcula desde h.cf (centro de la puerta, a la altura del suelo, mirando hacia dentro).
-- at(x, y, z): x lateral (+ = derecha mirando a la casa), y altura sobre el suelo de la casa, z profundidad (+ = dentro).
local RS = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Config = require(RS.Config)
local Assets = RS:WaitForChild("Assets")
local ServerStorage = game:GetService("ServerStorage")

local W, D, H = Config.ROOM_W, Config.ROOM_D, Config.ROOM_H
local DW, DH = Config.DOOR_W, Config.DOOR_H
local GROUND = -Config.FLOOR_Y -- el terreno, en coordenadas de la casa

local M = Enum.Material
local CYL = Enum.PartType.Cylinder
local STONE = {M.Cobblestone, Color3.fromRGB(78, 74, 80)}
local IRON = {M.Metal, Color3.fromRGB(26, 26, 30)}
local BRASS = {M.Metal, Color3.fromRGB(200, 160, 70)}
local DARKWOOD = {M.WoodPlanks, Color3.fromRGB(48, 30, 24)}
local WAINSCOT = {M.WoodPlanks, Color3.fromRGB(56, 36, 28)}
local LIT = {M.Neon, Color3.fromRGB(176, 106, 44)}
local DARKGLASS = {M.Glass, Color3.fromRGB(16, 20, 32)}
local MOON = {M.Neon, Color3.fromRGB(34, 50, 78)}
local WEB = {M.SmoothPlastic, Color3.fromRGB(196, 196, 208)}
local FLAME = {M.Neon, Color3.fromRGB(255, 140, 40)}
local WAX = {M.SmoothPlastic, Color3.fromRGB(232, 222, 196)}
local SHADOW = {M.SmoothPlastic, Color3.fromRGB(10, 7, 12)}
local REDEYE = {M.Neon, Color3.fromRGB(255, 36, 24)}
local FLAG = {M.SmoothPlastic, Color3.fromRGB(196, 28, 28)}
local PORTAL = {M.Neon, Color3.fromRGB(236, 240, 255)}

local Builder = {}

local function part(parent, size, cf, look, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Material = look[1]
	p.Color = look[2]
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

-- Detalle pequeño: sin colisión, sin sombra y que no estorbe a los rayos de colocar sustos
local function detail(parent, size, cf, look, props)
	local p = part(parent, size, cf, look, props)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

local function wedge(parent, size, cf, look, props)
	local p = Instance.new("WedgePart")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Material = look[1]
	p.Color = look[2]
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function light(parent, class, props)
	local l = Instance.new(class)
	for k, v in props do
		l[k] = v
	end
	l.Parent = parent
	return l
end

-- Disco plano (cilindro de canto) mirando hacia donde mira cf
local function disc(parent, diameter, thick, cf, look, props)
	local p = detail(parent, Vector3.new(thick, diameter, diameter), cf * CFrame.Angles(0, math.pi / 2, 0), look, props)
	p.Shape = CYL
	return p
end

-- Hilo recto entre dos puntos (telarañas, varillas)
local function rod(parent, a, b, thick, look)
	local len = (b - a).Magnitude
	return detail(parent, Vector3.new(thick, thick, len), CFrame.lookAt((a + b) / 2, b), look)
end

-- Telaraña en una esquina. cf está en la esquina; los hilos se abren hacia su RightVector y hacia abajo.
local function web(parent, cf, r)
	local spokes = {}
	for i = 0, 4 do
		local a = math.rad(i * 22.5)
		spokes[i] = Vector3.new(math.cos(a), -math.sin(a), 0)
	end
	for i = 0, 4 do
		local t = rod(parent, cf.Position, cf * (spokes[i] * r), 0.035, WEB)
		t.Transparency = 0.45
	end
	for _, k in {0.38, 0.7} do
		for i = 0, 3 do
			local t = rod(parent, cf * (spokes[i] * r * k), cf * (spokes[i + 1] * r * (k + 0.04)), 0.03, WEB)
			t.Transparency = 0.5
		end
	end
end

-- Ventana: c es el centro de la ventana sobre la pared, con LookVector hacia fuera.
-- o.curtains: cortinas · o.shutters: contraventanas (o.crooked = lado descolgado) · o.figure: silueta con ojos rojos
local function window(parent, c, glass, pal, o)
	o = o or {}
	part(parent, Vector3.new(3.8, 4.8, 0.12), c * CFrame.new(0, 0, -0.06), glass, {CastShadow = false})
	for _, s in {-1, 1} do
		part(parent, Vector3.new(0.4, 5.6, 0.35), c * CFrame.new(s * 2.1, 0, -0.17), pal.trim)
		part(parent, Vector3.new(4.6, 0.4, 0.35), c * CFrame.new(0, s * 2.6, -0.17), pal.trim)
	end
	detail(parent, Vector3.new(0.2, 4.8, 0.3), c * CFrame.new(0, 0, -0.15), pal.trim)
	detail(parent, Vector3.new(3.8, 0.2, 0.3), c * CFrame.new(0, 0.4, -0.15), pal.trim)
	part(parent, Vector3.new(5, 0.35, 0.9), c * CFrame.new(0, -2.9, -0.4), pal.trim)
	if o.hood then
		part(parent, Vector3.new(4.2, 0.5, 0.25), c * CFrame.new(0, 3.05, -0.3) * CFrame.Angles(math.rad(-20), 0, 0), pal.trim) -- tejadillo
	end
	if o.curtains then
		for _, s in {-1, 1} do
			detail(parent, Vector3.new(1.3, 5.4, 0.2), c * CFrame.new(s * 2.3, 0.1, -0.45), {M.Fabric, Color3.fromRGB(70, 16, 24)})
		end
		detail(parent, Vector3.new(5.6, 0.18, 0.18), c * CFrame.new(0, 2.85, -0.5), BRASS)
	end
	if o.shutters then
		for _, s in {-1, 1} do
			local w = 1.4
			local cf = c * CFrame.new(s * 2.3, 2.7, -0.22) -- bisagra de arriba
			if o.crooked == s then
				cf *= CFrame.Angles(0, 0, s * math.rad(17)) -- cuelga de una sola bisagra
			end
			cf *= CFrame.new(s * w / 2, -2.7, 0)
			local sh = part(parent, Vector3.new(w, 5.4, 0.16), cf, pal.shutter)
			for k = -2, 2 do
				detail(parent, Vector3.new(w - 0.32, 0.14, 0.06), sh.CFrame * CFrame.new(0, k * 0.95, -0.1), pal.trim)
			end
		end
	end
	if o.figure then
		-- una silueta mirando desde dentro, recortada contra la luz
		local base = c * CFrame.new(o.figure, -0.95, -0.14) -- entre el cristal y los travesaños
		disc(parent, 1.1, 0.03, base * CFrame.new(0, 1.2, 0), SHADOW)
		detail(parent, Vector3.new(1.5, 1.45, 0.03), base * CFrame.new(0, -0.65, 0), SHADOW)
		for _, s in {-1, 1} do
			disc(parent, 0.9, 0.03, base * CFrame.new(s * 0.45, -0.05, 0), SHADOW)
			disc(parent, 0.17, 0.04, base * CFrame.new(s * 0.21, 1.27, -0.03), REDEYE)
		end
	end
end

local function cloneProp(name)
	local t = Assets.Props:FindFirstChild(name)
	return t and t:Clone()
end

-- Aplique de pared con una vela. c: sobre la pared, LookVector hacia la habitación.
local function sconce(parent, c)
	detail(parent, Vector3.new(0.5, 1, 0.16), c * CFrame.new(0, 0, -0.08), BRASS)
	detail(parent, Vector3.new(0.16, 0.16, 0.8), c * CFrame.new(0, -0.25, -0.45), BRASS)
	detail(parent, Vector3.new(0.7, 0.1, 0.7), c * CFrame.new(0, -0.25, -0.85), BRASS)
	detail(parent, Vector3.new(0.26, 0.62, 0.26), c * CFrame.new(0, 0.11, -0.85), WAX)
	local flame = detail(parent, Vector3.new(0.2, 0.3, 0.2), c * CFrame.new(0, 0.55, -0.85), FLAME)
	CollectionService:AddTag(light(flame, "PointLight", {Range = 14, Brightness = 0.85, Color = Color3.fromRGB(255, 150, 70), Shadows = false}), "Flicker")
end

-- Calabaza pequeña del jardín (el modelo de Props, encogido)
local function pumpkin(parent, cf, scale)
	local p = cloneProp("Calabaza")
	if p then
		p:ScaleTo(scale)
		p:PivotTo(cf)
		p.Parent = parent
	end
end

-- Casa de jugador (diseño 3D de ServerStorage, ver Config.Houses): hace de fachada, tejado y porche; dentro siguen
-- las salas de siempre. Atributo DoorAt de la plantilla: el centro de la puerta a ras del suelo de la casa, relativo a
-- su pivote (sin él, el pivote ya es ese punto). Devuelve la altura del tejado (para el cartel flotante).
-- CasaPrincipal: las paredes (Walls_Core, Siding...) no chocan (su caja tapaba la
-- puerta): paredes, cimientos y rampa invisibles sacados de las medidas de sus piezas. Tejado, chimenea, molduras,
-- porche, tablones y calabazas sí chocan, con PreciseConvexDecomposition (en la plantilla). Animaciones: HauntClient.
local function principal(h, template, style, at, OUT)
	local ext = template:Clone()
	ext.Name = "Exterior"
	for _, p in ext:GetDescendants() do
		local role = p:IsA("BasePart") and p:GetAttribute("Style")
		if role then
			-- los colores de la parcela, como las demás casas (la madera de las paredes, algo más oscura: con las luces naranjas se veía rosa)
			p.Color = role == "siding" and style.siding:Lerp(Color3.new(), 0.3) or style[role]
		end
	end
	local doorAt = template:GetAttribute("DoorAt")
	ext:PivotTo(doorAt and h.cf * doorAt:Inverse() or h.cf)
	-- animaciones y eventos del diseño (Claude Design: HauntServer + HauntClient); en la plantilla están apagados
	ext.HauntServer.Enabled = true
	ext.HauntClient.Enabled = true
	-- negro detrás de la puerta: cuando se abre sola se ve oscuridad, no la sala iluminada
	local void = Instance.new("Part")
	void.Name = "DoorVoid"
	void.Anchored, void.CanCollide, void.CanQuery, void.CanTouch, void.CastShadow = true, false, false, false, false
	void.Material, void.Color = Enum.Material.SmoothPlastic, Color3.new(0, 0, 0)
	void.Size, void.CFrame = Vector3.new(DW + 1.2, DH + 0.2, 0.1), at(0, DH / 2, 0.42)
	void.Parent = ext
	local bcf, bsize = ext:GetBoundingBox()
	local top = h.cf:PointToObjectSpace(bcf.Position).Y + bsize.Y / 2
	if not ext:FindFirstChild("Walls_Core") then
		-- diseño hecho de piezas (CasaLarga): sus muros ya chocan; la puerta no (la cruzan los bots) y el suelo y el
		-- techo de dentro los ponen las salas (preparado en la propia plantilla)
		ext.Parent = h.model
		return top
	end
	local function solid(size, cf, class)
		local p = Instance.new(class or "Part")
		p.Anchored, p.Transparency, p.CastShadow = true, 1, false
		p.Size, p.CFrame = size, cf
		p.Parent = ext
	end
	-- caja de una pieza en coordenadas de la casa: centro (x, y, z) y tamaño
	local function box(name)
		local p = ext[name]
		local c = h.cf:ToObjectSpace(p.CFrame)
		return Vector3.new(c.X, c.Y, -c.Z), p.Size
	end
	local wc, ws = box("Walls_Core")
	local x0, x1, z0 = wc.X - ws.X / 2, wc.X + ws.X / 2, wc.Z - ws.Z / 2
	for _, x in {x0 + 0.5, x1 - 0.5} do
		solid(Vector3.new(1, ws.Y, ws.Z), at(x, wc.Y, wc.Z)) -- paredes laterales
	end
	solid(Vector3.new(ws.X, ws.Y, 1), at(wc.X, wc.Y, wc.Z + ws.Z / 2 - 0.5)) -- pared trasera
	local dw = DW / 2
	for _, e in {{x0, -dw}, {dw, x1}} do
		solid(Vector3.new(e[2] - e[1], ws.Y, 0.2), at((e[1] + e[2]) / 2, wc.Y, z0 + 0.1)) -- fachada a los lados de la puerta
	end
	local fc, fs = box("Foundation")
	solid(fs, at(fc.X, fc.Y, fc.Z)) -- cimientos y porche
	local sc, ss = box("Porch_Steps")
	local rise = fc.Y + fs.Y / 2 - GROUND
	solid(Vector3.new(ss.X, rise, ss.Z), at(sc.X, GROUND + rise / 2, sc.Z) * OUT, "WedgePart") -- rampa por los escalones
	ext.Parent = h.model
	return top
end

-- Construye (o reconstruye) la casa. Devuelve referencias al portal y a los carteles.
function Builder.build(h)
	W, H = h.roomW or Config.ROOM_W, h.roomH or Config.ROOM_H -- cada casa puede ser más ancha/alta (Config.houseDims)
	for _, name in {"Shell", "Floors", "Roof", "Props", "Door", "Portal", "Yard", "Exterior"} do
		local old = h.model:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local f = {}
	for _, name in {"Shell", "Floors", "Roof", "Props", "Yard"} do
		f[name] = Instance.new("Folder")
		f[name].Name = name
	end
	local cf, n = h.cf, h.rooms
	local L = n * D
	local function at(x, y, z)
		return cf * CFrame.new(x, y, -z)
	end
	local OUT = CFrame.Angles(0, math.pi, 0) -- mira hacia la calle
	local style = Config.HouseStyles[(h.i - 1) % #Config.HouseStyles + 1]
	local SIDING = {M.WoodPlanks, style.siding}
	local TRIM = {M.Wood, style.trim}
	local ROOF = {M.RoofShingles, style.roof}
	local pal = {trim = TRIM, shutter = {M.WoodPlanks, style.shutter}}
	local fancy = h.template and ServerStorage:FindFirstChild(h.template) -- todas las casas (de jugador y no reclamadas) usan un diseño 3D
	local roofTop = H + 8 -- punta del tejado (el de las casas sin diseño 3D)

	local side = (W - DW) / 2 -- muro a cada lado de la puerta
	if not fancy then
		---------- Exterior ----------
		part(f.Shell, Vector3.new(W + 3, Config.FLOOR_Y - 0.05, L + 2), at(0, GROUND / 2 - 0.025, L / 2), STONE)
		for _, s in {-1, 1} do
			part(f.Shell, Vector3.new(1, H, L + 1), at(s * (W / 2 + 0.5), H / 2, L / 2), SIDING)
			part(f.Shell, Vector3.new(1.5, H + 0.4, 1.5), at(s * (W / 2 + 0.5), H / 2, -0.25), TRIM)
			part(f.Shell, Vector3.new(1.5, H + 0.4, 1.5), at(s * (W / 2 + 0.5), H / 2, L + 0.25), TRIM)
			part(f.Shell, Vector3.new(1.5, 0.6, L + 1), at(s * (W / 2 + 0.6), H - 0.3, L / 2), TRIM) -- cornisa
			part(f.Shell, Vector3.new(1.3, 0.8, L + 1), at(s * (W / 2 + 0.55), 0.4, L / 2), TRIM) -- zócalo
		end
		part(f.Shell, Vector3.new(W, H, 1), at(0, H / 2, L), SIDING)
		part(f.Shell, Vector3.new(side, H, 1), at(-(DW + side) / 2, H / 2, 0), SIDING)
		part(f.Shell, Vector3.new(side, H, 1), at((DW + side) / 2, H / 2, 0), SIDING)
		part(f.Shell, Vector3.new(DW, H - DH, 1), at(0, (H + DH) / 2, 0), SIDING)
		for _, s in {-1, 1} do
			part(f.Shell, Vector3.new(side + 0.5, 0.8, 1.3), at(s * (DW / 2 + (side + 0.5) / 2), 0.4, -0.15), TRIM) -- zócalo de la fachada
		end
		-- marco de la puerta (con frontón) y ventanas de la fachada
		for _, s in {-1, 1} do
			part(f.Shell, Vector3.new(0.7, DH + 0.7, 0.5), at(s * (DW / 2 + 0.35), (DH + 0.7) / 2, -0.6), TRIM)
			window(f.Shell, at(s * 7.5, 6.8, -0.5) * OUT, s == 1 and LIT or DARKGLASS, pal, {shutters = true, crooked = s == -1 and -1 or nil, figure = s == 1 and 0.55 or nil})
		end
		part(f.Shell, Vector3.new(DW + 1.4, 0.7, 0.5), at(0, DH + 0.35, -0.6), TRIM)
		part(f.Shell, Vector3.new(DW + 2.2, 0.35, 0.9), at(0, DH + 0.85, -0.75), TRIM)
		local idx = 0
		for i = 1, n do
			local zc = (i - 0.5) * D
			for _, s in {-1, 1} do
				idx += 1
				local lit = (i + (s == 1 and 1 or 0)) % 3 == 0
				window(f.Shell, at(s * (W / 2 + 1), 6.8, zc) * CFrame.Angles(0, -s * math.pi / 2, 0), lit and LIT or DARKGLASS, pal, {
					shutters = true, hood = true, crooked = (idx + h.i) % 4 == 0 and 1 or nil, figure = lit and (i % 2 == 0) and -0.5 or nil,
				})
			end
		end
	
	---------- Tejado a dos aguas ----------
		local rise = 7
		local slope = math.atan2(rise, W / 2 + 1)
		local run = W / 2 + 2.5
		local len = run / math.cos(slope)
		local top = H + 0.4 + rise
		for _, s in {-1, 1} do
			local mid = run / 2
			local slab = part(f.Roof, Vector3.new(len, 0.8, L + 3), at(s * mid, top - mid * math.tan(slope) - 0.45, L / 2) * CFrame.Angles(0, 0, -s * slope), ROOF)
			part(f.Roof, Vector3.new(0.3, 1, L + 3.3), slab.CFrame * CFrame.new(s * (len / 2 + 0.12), -0.12, 0), TRIM) -- tabla del alero
			for _, e in {-1, 1} do
				part(f.Roof, Vector3.new(len + 0.35, 1, 0.3), slab.CFrame * CFrame.new(0, -0.18, e * ((L + 3) / 2 + 0.13)), TRIM) -- tabla del hastial
			end
			for _, z in {0, L} do
				wedge(f.Roof, Vector3.new(1, rise, W / 2 + 1), at(s * (W / 2 + 1) / 2, H + 0.4 + rise / 2, z) * CFrame.Angles(0, -s * math.pi / 2, 0), SIDING)
			end
		end
		part(f.Roof, Vector3.new(1, 1, L + 3), at(0, top + 0.1, L / 2) * CFrame.Angles(0, 0, math.rad(45)), {M.Slate, Color3.fromRGB(30, 24, 34)})
		part(f.Roof, Vector3.new(W + 2, 0.4, L + 1), at(0, H + 0.2, L / 2), TRIM) -- techo plano bajo el tejado
		-- ventanuco redondo del desván, iluminado
		disc(f.Roof, 3.2, 0.25, at(0, H + 3.2, -0.5) * OUT, TRIM)
		local attic = disc(f.Roof, 2.6, 0.3, at(0, H + 3.2, -0.6) * OUT, {M.Neon, Color3.fromRGB(120, 66, 150)})
		detail(f.Roof, Vector3.new(2.6, 0.16, 0.12), at(0, H + 3.2, -0.8), TRIM)
		detail(f.Roof, Vector3.new(0.16, 2.6, 0.12), at(0, H + 3.2, -0.8), TRIM)
		light(attic, "PointLight", {Range = 9, Brightness = 0.8, Color = Color3.fromRGB(170, 110, 255), Shadows = false})
		-- veleta en la punta del tejado
		detail(f.Roof, Vector3.new(0.14, 2.6, 0.14), at(0, top + 1.4, -0.8), IRON)
		detail(f.Roof, Vector3.new(0.4, 0.4, 0.4), at(0, top + 2.8, -0.8), IRON, {Shape = Enum.PartType.Ball})
		detail(f.Roof, Vector3.new(2.2, 0.1, 0.1), at(0, top + 2.2, -0.8) * CFrame.Angles(0, math.rad(35), 0), IRON)
		wedge(f.Roof, Vector3.new(0.08, 0.45, 0.55), at(0, top + 2.2, -0.8) * CFrame.Angles(0, math.rad(35), 0) * CFrame.new(1.25, 0, 0) * CFrame.Angles(0, math.rad(90), 0), IRON, {CanCollide = false, CastShadow = false})
		-- chimenea con humo
		part(f.Roof, Vector3.new(3.2, 12, 3.2), at(8, H + 6, L - 5), {M.Brick, Color3.fromRGB(70, 42, 38)})
		local cap = part(f.Roof, Vector3.new(3.8, 0.6, 3.8), at(8, H + 12.2, L - 5), STONE)
		local smoke = Instance.new("ParticleEmitter")
		smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
		smoke.Rate = 2.5
		smoke.Lifetime = NumberRange.new(6, 9)
		smoke.Speed = NumberRange.new(2, 3.2)
		smoke.SpreadAngle = Vector2.new(12, 12)
		smoke.EmissionDirection = Enum.NormalId.Top
		smoke.Acceleration = Vector3.new(1.2, 0.3, 0.6)
		smoke.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 7)})
		smoke.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.62), NumberSequenceKeypoint.new(1, 1)})
		smoke.Color = ColorSequence.new(Color3.fromRGB(96, 90, 110))
		smoke.Rotation = NumberRange.new(0, 360)
		smoke.RotSpeed = NumberRange.new(-15, 15)
		smoke.Parent = cap
	
	else
		roofTop = principal(h, fancy, style, at, OUT)
		part(f.Roof, Vector3.new(W + 2, 0.4, L + 1), at(0, H + 0.2, L / 2), TRIM) -- techo de la sala
	end

	---------- Interior ----------
	for i = 1, n do
		local room = Config.Rooms[i]
		local z0, zc = (i - 1) * D, (i - 0.5) * D
		part(f.Floors, Vector3.new(W, 1, D), at(0, -0.5, zc), room.floor, {Name = "Floor"})
		for _, s in {-1, 1} do
			part(f.Shell, Vector3.new(0.2, H, D), at(s * (W / 2 - 0.1), H / 2, zc), room.wall)
			part(f.Shell, Vector3.new(0.15, 3.4, D), at(s * (W / 2 - 0.27), 1.7, zc), WAINSCOT) -- friso de madera
			part(f.Shell, Vector3.new(0.3, 0.25, D), at(s * (W / 2 - 0.3), 3.45, zc), TRIM) -- moldura
			part(f.Shell, Vector3.new(0.4, 0.9, D), at(s * (W / 2 - 0.35), 0.45, zc), TRIM)
			part(f.Shell, Vector3.new(0.4, 0.5, D), at(s * (W / 2 - 0.35), H - 0.25, zc), TRIM)
			window(f.Shell, at(s * (W / 2 - 0.2), 6.8, zc) * CFrame.Angles(0, s * math.pi / 2, 0), MOON, pal, {curtains = true})
			-- un aplique con vela junto a cada ventana (los cuadros de Config.Rooms van a ±7 del centro)
			sconce(f.Shell, at(s * (W / 2 - 0.2), 7.6, zc + s * 4.2) * CFrame.Angles(0, s * math.pi / 2, 0))
		end
		-- vigas del techo
		for _, dz in {-7, 7} do
			part(f.Roof, Vector3.new(W, 0.7, 0.9), at(0, H - 0.35, zc + dz), TRIM)
		end
		-- sin tabiques entre salas: toda la casa es un único salón; solo la fachada por dentro
		if i == 1 then
			part(f.Shell, Vector3.new(side, H, 0.2), at(-(DW + side) / 2, H / 2, 0.6), room.wall)
			part(f.Shell, Vector3.new(side, H, 0.2), at((DW + side) / 2, H / 2, 0.6), room.wall)
			part(f.Shell, Vector3.new(DW, H - DH, 0.2), at(0, (H + DH) / 2, 0.6), room.wall)
			-- marco de la puerta por dentro (el portal se ve como una puerta cerrada también desde la casa)
			for _, s in {-1, 1} do
				part(f.Shell, Vector3.new(0.6, DH + 0.6, 0.3), at(s * (DW / 2 + 0.3), (DH + 0.6) / 2, 0.85), TRIM)
			end
			part(f.Shell, Vector3.new(DW + 1.2, 0.6, 0.3), at(0, DH + 0.3, 0.85), TRIM)
			-- telaraña en una esquina alta de la entrada
			web(f.Shell, at(-(W / 2 - 0.3), H - 0.2, 1), 3.2)
		end
		-- decoración fija de la sala
		for _, p in room.props do
			local prop = cloneProp(p[1])
			if prop then
				prop:PivotTo(at(p[2] * W / Config.ROOM_W, p[5] or 0, z0 + p[3]) * CFrame.Angles(0, math.pi + p[4] * math.pi / 2, 0))
				prop.Parent = f.Props
			end
		end
	end
	part(f.Shell, Vector3.new(W, H, 0.2), at(0, H / 2, L - 0.6), Config.Rooms[n].wall)

	---------- Portal blanco en la puerta ----------
	-- Opaco y sólido para los jugadores (grupo "Portal"): la puerta está cerrada por fuera y por dentro y se cruza
	-- con la animación del cliente (Portales.lua). Los bots lo atraviesan. CanQuery para que la cámara no lo cruce.
	local portal = Instance.new("Model")
	portal.Name = "Portal"
	local PW, PH = DW - 0.2, DH - 0.1
	-- (sin velos delante: la cámara se queda junto al portal al cruzarlo y cualquier capa semitransparente la tiñe)
	local glow = part(portal, Vector3.new(PW, PH, 0.3), at(0, PH / 2, 0), PORTAL, {Name = "Glow", CastShadow = false, CollisionGroup = "Portal"})
	if fancy then
		glow.Transparency = 1 -- se ve la puerta del diseño; el portal sigue ahí (sólido, con su luz y sus chispas)
	end
	light(glow, "PointLight", {Range = 16, Brightness = 1.4, Color = Color3.fromRGB(214, 222, 255), Shadows = false})
	for _, dir in {Enum.NormalId.Back, Enum.NormalId.Front} do
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Rate = 9
		sparkle.Lifetime = NumberRange.new(1, 2.2)
		sparkle.Speed = NumberRange.new(0.3, 1.3)
		sparkle.SpreadAngle = Vector2.new(35, 35)
		sparkle.EmissionDirection = dir -- Back = hacia la calle, Front = hacia dentro
		sparkle.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0)})
		sparkle.Transparency = NumberSequence.new(0.1, 1)
		sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 170, 255))
		sparkle.LightEmission = 1
		sparkle.Rotation = NumberRange.new(0, 360)
		sparkle.RotSpeed = NumberRange.new(-90, 90)
		sparkle.Parent = glow
	end
	CollectionService:AddTag(portal, "Portal")
	portal.PrimaryPart = glow
	portal.Parent = h.model
	-- marca para la flecha "¡ENTRA!" del tutorial: sobre el propio portal (más arriba la tapa el texto de ayuda del HUD)
	part(f.Shell, Vector3.new(1, 1, 1), at(0, DH * 0.62, -0.8), TRIM, {Name = "DoorMark", Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false})
	if not fancy then
		-- farolillo junto a la puerta
		local lantern = part(f.Shell, Vector3.new(0.6, 0.6, 0.6), at(DW / 2 + 1.5, 7.2, -1), {M.Neon, Color3.fromRGB(255, 150, 60)}, {Shape = Enum.PartType.Ball})
		part(f.Shell, Vector3.new(0.9, 0.22, 0.9), at(DW / 2 + 1.5, 7.65, -1), IRON)
		part(f.Shell, Vector3.new(0.2, 0.2, 0.9), at(DW / 2 + 1.5, 7.7, -0.6), IRON)
		local ll = light(lantern, "PointLight", {Range = 18, Brightness = 1.4, Color = Color3.fromRGB(255, 150, 70)})
		CollectionService:AddTag(ll, "Flicker")
	end

	if not fancy then
		---------- Porche ----------
		part(f.Shell, Vector3.new(14, Config.FLOOR_Y, 5.5), at(0, GROUND / 2, -2.75), DARKWOOD)
		part(f.Shell, Vector3.new(7, 1, 1.4), at(0, GROUND + 0.5, -6.2), DARKWOOD, {CanCollide = false})
		wedge(f.Shell, Vector3.new(7, Config.FLOOR_Y, 2), at(0, GROUND / 2, -6.4) * OUT, DARKWOOD, {Transparency = 1}) -- rampa invisible para que los bots suban
		for _, s in {-1, 1} do
			part(f.Shell, Vector3.new(0.7, 9.4, 0.7), at(s * 6.2, 4.7, -5.1), TRIM)
			part(f.Shell, Vector3.new(1, 0.35, 1), at(s * 6.2, 0.18, -5.1), TRIM)
			-- barandilla lateral y delantera con balaustres
			part(f.Shell, Vector3.new(0.4, 0.25, 4.6), at(s * 6.2, 2.6, -2.8), TRIM)
			detail(f.Shell, Vector3.new(0.3, 0.2, 4.6), at(s * 6.2, 0.35, -2.8), TRIM)
			for k = 0, 7 do
				detail(f.Shell, Vector3.new(0.18, 2.3, 0.18), at(s * 6.2, 1.35, -0.85 - k * 0.55), TRIM)
			end
			part(f.Shell, Vector3.new(2.3, 0.25, 0.4), at(s * 4.9, 2.6, -5.1), TRIM)
			for k = 0, 3 do
				detail(f.Shell, Vector3.new(0.18, 2.3, 0.18), at(s * (3.95 + k * 0.55), 1.35, -5.1), TRIM)
			end
			-- tornapuntas entre el poste y la viga
			rod(f.Shell, at(s * 6.2, 7.7, -5.1).Position, at(s * 4.9, 9, -5.1).Position, 0.22, TRIM)
			web(f.Shell, at(s * 5.85, 9.05, -5.3) * CFrame.Angles(0, s == 1 and math.pi or 0, 0), 2.4)
		end
		part(f.Shell, Vector3.new(13.1, 0.5, 0.5), at(0, 9.05, -5.1), TRIM) -- viga delantera
		local porchRoof = part(f.Roof, Vector3.new(15, 0.5, 6.6), at(0, 9.5, -3) * CFrame.Angles(math.rad(8), 0, 0), ROOF)
		part(f.Roof, Vector3.new(15.3, 0.7, 0.3), porchRoof.CFrame * CFrame.new(0, -0.1, 3.4), TRIM)
	
	end

	---------- Jardín ----------
	local YARD = -17
	for _, s in {-1, 1} do
		-- verja de hierro con pinchos
		for k = 0, 7 do
			local x = s * (3.6 + k * 3)
			part(f.Yard, Vector3.new(0.35, 4.2, 0.35), at(x, GROUND + 2.1, YARD), IRON)
			part(f.Yard, Vector3.new(0.45, 0.45, 0.45), at(x, GROUND + 4.3, YARD) * CFrame.Angles(math.rad(45), 0, math.rad(45)), IRON)
		end
		for _, y in {1, 3.6} do
			part(f.Yard, Vector3.new(21.5, 0.22, 0.22), at(s * 14.1, GROUND + y, YARD), IRON)
		end
		-- pilares de la entrada con farolillos
		part(f.Yard, Vector3.new(1.5, 5.6, 1.5), at(s * 3.6, GROUND + 2.8, YARD), STONE)
		part(f.Yard, Vector3.new(1.8, 0.3, 1.8), at(s * 3.6, GROUND + 5.65, YARD), STONE)
		local gl = part(f.Yard, Vector3.new(0.7, 0.7, 0.7), at(s * 3.6, GROUND + 6.15, YARD), {M.Neon, Color3.fromRGB(255, 140, 50)}, {Shape = Enum.PartType.Ball})
		part(f.Yard, Vector3.new(1, 0.25, 1), at(s * 3.6, GROUND + 6.65, YARD), IRON)
		CollectionService:AddTag(light(gl, "PointLight", {Range = 14, Brightness = 1.1, Color = Color3.fromRGB(255, 140, 60)}), "Flicker")
		-- verja de la entrada, abierta hacia el jardín
		local leaf = at(s * 2.85, GROUND, YARD) * CFrame.Angles(0, -s * math.rad(72), 0)
		for _, y in {0.6, 3.4} do
			detail(f.Yard, Vector3.new(2.6, 0.18, 0.18), leaf * CFrame.new(-s * 1.35, y, 0), IRON)
		end
		for k = 0, 4 do
			local x = -s * (0.25 + k * 0.55)
			detail(f.Yard, Vector3.new(0.14, 3.6, 0.14), leaf * CFrame.new(x, 1.95, 0), IRON)
			detail(f.Yard, Vector3.new(0.26, 0.26, 0.26), leaf * CFrame.new(x, 3.85, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), IRON)
		end
	end
	-- camino de losas
	for k = 0, 4 do
		local stone = part(f.Yard, Vector3.new(0.25, 2.6, 2.6), at((k % 2 == 0 and -0.4 or 0.4), GROUND + 0.05, YARD + 1.8 + k * 2.1) * CFrame.Angles(0, 0, math.pi / 2), {M.Slate, Color3.fromRGB(84, 82, 88)}, {Shape = Enum.PartType.Cylinder, CanCollide = false})
		stone.CFrame = at((k % 2 == 0 and -0.4 or 0.4), GROUND + 0.05, YARD + 1.8 + k * 2.1) * CFrame.Angles(0, 0, math.pi / 2)
	end
	-- los puestos del final de la calle invaden la parcela de las casas de los extremos:
	-- los props grandes se apartan hacia dentro hasta no tocar ninguno
	local shops = workspace:FindFirstChild("Mapa") and workspace.Mapa:FindFirstChild("Tiendas")
	local shopParams = OverlapParams.new()
	shopParams.FilterType = Enum.RaycastFilterType.Include
	shopParams.FilterDescendantsInstances = {shops}
	local function freeX(x, z, r)
		while shops and math.abs(x) >= 1 and #workspace:GetPartBoundsInBox(at(x, GROUND + 4, z), Vector3.new(2 * r + 1, 8, 2 * r + 1), shopParams) > 0 do
			x -= math.sign(x)
		end
		return x
	end
	local yardProps = {{"Calabaza", fancy and -7.4 or -3.6, fancy and -10.8 or -7.2, 0}, {"Calabaza", fancy and 7.4 or 3.6, fancy and -11.2 or -7.4, 0}, {"Lapida", -11, -10, 0}, {"Lapida", -16, -13, 0}, {"Lapida", 13, -12, 0}, {"Arbol", 19, -8, 0}}
	for _, p in yardProps do
		local prop = cloneProp(p[1])
		if prop then
			local x = p[1] == "Arbol" and freeX(p[2], p[3], 3.5) or p[2]
			prop:PivotTo(at(x, GROUND, p[3]) * OUT * CFrame.Angles(0, p[4] + (p[2] * 7 % 3) * 0.3, 0))
			prop.Parent = f.Yard
		end
	end
	pumpkin(f.Yard, at(-2.5, GROUND, -11.4) * OUT * CFrame.Angles(0, 0.4, 0), 0.55)
	pumpkin(f.Yard, at(2.6, GROUND, -13.3) * OUT * CFrame.Angles(0, -0.5, 0), 0.5)
	-- buzón con la bandera levantada
	local mb = at(-6.6, GROUND, -18.4) * OUT
	part(f.Yard, Vector3.new(0.35, 3.6, 0.35), mb * CFrame.new(0, 1.8, 0), {M.Wood, Color3.fromRGB(62, 46, 36)})
	local box = part(f.Yard, Vector3.new(1.1, 0.75, 1.9), mb * CFrame.new(0, 3.95, 0), {M.Metal, Color3.fromRGB(42, 46, 56)})
	local lid = part(f.Yard, Vector3.new(1.9, 1.1, 1.1), mb * CFrame.new(0, 4.3, 0) * CFrame.Angles(0, math.pi / 2, 0), {M.Metal, Color3.fromRGB(42, 46, 56)})
	lid.Shape = CYL
	detail(f.Yard, Vector3.new(0.08, 1, 0.08), mb * CFrame.new(0.6, 4.4, 0.5), IRON)
	detail(f.Yard, Vector3.new(0.05, 0.42, 0.6), mb * CFrame.new(0.62, 4.72, 0.72), FLAG)
	local mg2 = Instance.new("SurfaceGui")
	mg2.Face = Enum.NormalId.Left
	mg2.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	mg2.PixelsPerStud = 50
	mg2.LightInfluence = 0.8
	mg2.Parent = box
	local mtx = Instance.new("TextLabel")
	mtx.Name = "MailName"
	mtx.Size = UDim2.fromScale(1, 1)
	mtx.BackgroundTransparency = 1
	mtx.Font = Enum.Font.FredokaOne
	mtx.TextScaled = true
	mtx.TextColor3 = Color3.fromRGB(235, 220, 190)
	mtx.Text = h.owner and h.owner.DisplayName or "No owner"
	mtx.Parent = mg2
	-- caldero burbujeante en una esquina del jardín
	local cc = fancy and at(freeX(-20.5, -9, 2), GROUND, -9) or at(freeX(-16.5, -4.8, 2), GROUND, -4.8)
	for k = 0, 2 do
		detail(f.Yard, Vector3.new(0.55, 0.55, 2.8), cc * CFrame.Angles(0, k * math.pi / 3, 0) * CFrame.new(0, 0.28, 0), {M.Wood, Color3.fromRGB(70, 46, 30)})
	end
	local embers = detail(f.Yard, Vector3.new(1.7, 0.25, 1.7), cc * CFrame.new(0, 0.5, 0), {M.Neon, Color3.fromRGB(255, 86, 20)})
	CollectionService:AddTag(light(embers, "PointLight", {Range = 9, Brightness = 1, Color = Color3.fromRGB(255, 110, 40)}), "Flicker")
	part(f.Yard, Vector3.new(3, 3, 3), cc * CFrame.new(0, 2, 0), {M.Metal, Color3.fromRGB(24, 24, 28)}, {Shape = Enum.PartType.Ball})
	disc(f.Yard, 2.7, 0.35, cc * CFrame.new(0, 3.08, 0) * CFrame.Angles(math.pi / 2, 0, 0), IRON)
	local potion = disc(f.Yard, 2.35, 0.1, cc * CFrame.new(0, 3.3, 0) * CFrame.Angles(math.pi / 2, 0, 0), {M.Neon, Color3.fromRGB(96, 230, 70)})
	light(potion, "PointLight", {Range = 12, Brightness = 1.3, Color = Color3.fromRGB(110, 255, 90)})
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Rate = 6
	bubbles.Lifetime = NumberRange.new(0.8, 1.6)
	bubbles.Speed = NumberRange.new(1.5, 3)
	bubbles.SpreadAngle = Vector2.new(25, 25)
	bubbles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.05)})
	bubbles.Transparency = NumberSequence.new(0.2, 1)
	bubbles.Color = ColorSequence.new(Color3.fromRGB(150, 255, 110))
	bubbles.LightEmission = 1
	bubbles.Parent = potion
	-- niebla baja en el jardín
	local fogPart = part(f.Yard, Vector3.new(W + 12, 1, 12), at(0, GROUND + 0.6, -11), STONE, {Name = "Fog", Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false})
	local fog = Instance.new("ParticleEmitter")
	fog.Texture = "rbxasset://textures/particles/smoke_main.dds"
	fog.Rate = 1.6
	fog.Lifetime = NumberRange.new(9, 14)
	fog.Speed = NumberRange.new(0.2, 0.6)
	fog.SpreadAngle = Vector2.new(180, 10)
	fog.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 7), NumberSequenceKeypoint.new(1, 13)})
	fog.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.84), NumberSequenceKeypoint.new(0.7, 0.88), NumberSequenceKeypoint.new(1, 1)})
	fog.Color = ColorSequence.new(Color3.fromRGB(150, 140, 190))
	fog.Rotation = NumberRange.new(0, 360)
	fog.RotSpeed = NumberRange.new(-6, 6)
	fog.Parent = fogPart
	-- cartel de madera junto a la verja: nombre y "me gusta" (por encima de los pinchos, que llegan a 4.6: si no, la verja tapaba los likes)
	local board = part(f.Yard, Vector3.new(7, 3.6, 0.35), at(9.5, GROUND + 6.8, YARD + 0.8) * OUT, DARKWOOD, {Name = "SignBoard"})
	for _, s in {-1, 1} do
		part(f.Yard, Vector3.new(0.4, 8, 0.4), at(9.5 + s * 3, GROUND + 4, YARD + 0.8), TRIM)
	end
	part(f.Yard, Vector3.new(7.6, 0.3, 0.7), at(9.5, GROUND + 8.75, YARD + 0.8), TRIM)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0.5
	sg.Parent = board
	local function boardLabel(y, hgt, font, color)
		local t = Instance.new("TextLabel")
		t.Position = UDim2.fromScale(0.04, y)
		t.Size = UDim2.fromScale(0.92, hgt)
		t.BackgroundTransparency = 1
		t.TextScaled = true
		t.Font = font
		t.TextColor3 = color
		t.TextStrokeTransparency = 0.6
		t.Parent = sg
		return t
	end
	local boardName = boardLabel(0.06, 0.56, Enum.Font.Creepster, Color3.fromRGB(255, 196, 110))
	local boardLikes = boardLabel(0.66, 0.27, Enum.Font.FredokaOne, Color3.fromRGB(255, 226, 150))
	local likePrompt
	if h.owner then
		likePrompt = Instance.new("ProximityPrompt")
		likePrompt.Name = "LikePrompt"
		likePrompt.ActionText = "Like 👍"
		likePrompt.ObjectText = h.name
		likePrompt.HoldDuration = 0.25
		likePrompt.MaxActivationDistance = 11
		likePrompt.RequiresLineOfSight = false
		likePrompt.Parent = board
	end
	-- cartel flotante sobre la casa, visible desde lejos
	local topPart = part(f.Yard, Vector3.one, at(0, roofTop + 4, 2), TRIM, {Name = "Sign", Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false})
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(22, 3.4) -- en studs: de lejos se ve más pequeño y no se pisa con otros (solo el nombre)
	bb.MaxDistance = 260
	bb.LightInfluence = 0
	bb.Parent = topPart
	local topText = Instance.new("TextLabel")
	topText.Size = UDim2.fromScale(1, 1)
	topText.BackgroundTransparency = 1
	topText.RichText = true
	topText.TextScaled = true
	topText.Font = Enum.Font.Creepster
	topText.TextColor3 = Color3.fromRGB(255, 170, 70)
	topText.TextStrokeTransparency = 0.2
	topText.Parent = bb

	-- (ya no hay cofre al fondo: los visitantes asustados sueltan monedas; quedan dos candelabros de adorno)
	for _, s in {-1, 1} do
		local c = cloneProp("Candelabro")
		if c then
			c:PivotTo(at(s * 4.5, 0, L - 3))
			c.Parent = f.Props
		end
	end

	for _, name in {"Shell", "Floors", "Roof", "Props", "Yard"} do
		f[name].Parent = h.model
	end
	return {
		portal = portal,
		boardName = boardName,
		boardLikes = boardLikes,
		likePrompt = likePrompt,
		topText = topText,
	}
end

return Builder
