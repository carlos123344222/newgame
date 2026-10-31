-- Construye las tiendas del mapa en workspace.Mapa.Tiendas (se ejecuta a mano en Studio, en modo edición):
--   require(game.ServerStorage.TiendasMapaBuilder).build()
-- La Ruleta tiene su propia zona al oeste de la plaza (donde estaba la capilla). Altar de Fusión y Mercado en la
-- entrada de la calle; Gemas y Laboratorio al final, junto al puente del Tower Defense. Cada puesto mira a la calle
-- (su -Z local) y lleva el atributo Kind, un mostrador con ProximityPrompt
-- y una pieza BadgeAnchor para el cartel flotante. Lo que se mueve (ruleta, gema, engranajes, rayos...) lo anima cada
-- cliente (TiendasFX); lo que deja quieto el decorado está en ServerStorage.DecoradoQuitado.
local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")

local B = {}

B.SPOTS = {
	-- la zona de la ruleta: centro de la plazoleta, mirando a la plaza (este)
	wheel = CFrame.lookAt(Vector3.new(-242, 0, 0), Vector3.new(-200, 0, 0)),
	fuse = CFrame.lookAt(Vector3.new(-115, 0, -28), Vector3.new(-115, 0, 0)),
	market = CFrame.lookAt(Vector3.new(-115, 0, 28), Vector3.new(-115, 0, 0)),
	gems = CFrame.lookAt(Vector3.new(110, 0, -28), Vector3.new(110, 0, 0)),
	lab = CFrame.lookAt(Vector3.new(110, 0, 28), Vector3.new(110, 0, 0)),
}
B.R = 11 -- radio de la ruleta gigante
B.ZONE_R = 18 -- radio de la plazoleta de la ruleta

local C = Color3.fromRGB
local M = Enum.Material
local GOLD = C(255, 196, 70)

local O -- CFrame del puesto que se está construyendo
local function part(parent, name, cf, size, color, mat, solid, shape)
	local p = Instance.new(shape == "Wedge" and "WedgePart" or "Part")
	if shape and shape ~= "Wedge" then
		p.Shape = Enum.PartType[shape]
	end
	p.Name = name
	p.Anchored = true
	p.CanCollide = solid == true
	p.CanTouch = false
	p.CanQuery = solid == true
	p.CastShadow = mat ~= M.Neon
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = O * cf
	p.Color = color
	p.Material = mat or M.SmoothPlastic
	p.Parent = parent
	return p
end

local function at(x, y, z)
	return CFrame.new(x, y, z)
end

local function light(p, color, range, brightness, kind)
	local l = Instance.new(kind or "PointLight")
	l.Color, l.Range, l.Brightness = color, range, brightness or 1.5
	l.Shadows = false
	l.Parent = p
	return l
end

local function model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Cartel con marco de neón: tabla oscura y un texto grande con degradado
local function sign(parent, cf, w, h, text, c1, c2, font)
	local board = part(parent, "Cartel", cf, Vector3.new(w, h, 0.6), C(22, 14, 30), M.Wood, true)
	for _, e in {{0, h / 2 + 0.15, w + 0.6, 0.3}, {0, -h / 2 - 0.15, w + 0.6, 0.3}, {w / 2 + 0.15, 0, 0.3, h}, {-w / 2 - 0.15, 0, 0.3, h}} do
		part(parent, "Neon", cf * at(e[1], e[2], -0.1), Vector3.new(e[3], e[4], 0.35), c1, M.Neon)
	end
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.PixelsPerStud = 20 -- (TextScaled no pasa de 100 px: con más píxeles por stud el texto se queda pequeño)
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.LightInfluence = 0
	sg.Brightness = 1.6
	sg.Parent = board
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(0.94, 0.86)
	t.Position = UDim2.fromScale(0.03, 0.07)
	t.BackgroundTransparency = 1
	t.Font = font or Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Parent = sg
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c1, c2)
	g.Rotation = 90
	g.Parent = t
	local s = Instance.new("UIStroke")
	s.Thickness = 5
	s.Color = C(10, 5, 15)
	s.Parent = t
	light(board, c1, 14, 1.2)
	return board
end

-- Antorcha / brasero con fuego del color dado
local function torch(parent, x, z, color, height)
	height = height or 8
	part(parent, "Poste", at(x, height / 2, z), Vector3.new(0.6, height, 0.6), C(30, 26, 34), M.Metal, true)
	local bowl = part(parent, "Brasero", at(x, height + 0.3, z), Vector3.new(0.8, 1.8, 1.8), C(40, 34, 40), M.Metal, false, "Cylinder")
	bowl.CFrame = O * at(x, height + 0.3, z) * CFrame.Angles(0, 0, math.pi / 2)
	local f = Instance.new("Fire")
	f.Color, f.SecondaryColor, f.Size, f.Heat = color, color:Lerp(Color3.new(1, 1, 1), 0.4), 4, 9
	f.Parent = bowl
	light(bowl, color, 18, 2.2)
end

-- Mostrador con el ProximityPrompt que abre la tienda
local function counter(parent, cf, size, color, action, object)
	local c = part(parent, "Mostrador", cf, size, color, M.Wood, true)
	part(parent, "MostradorTapa", cf * at(0, size.Y / 2 + 0.1, 0), Vector3.new(size.X + 0.4, 0.2, size.Z + 0.4), GOLD, M.Metal)
	local pp = Instance.new("ProximityPrompt")
	pp.Name = "Abrir"
	pp.ActionText = action
	pp.ObjectText = object
	pp.HoldDuration = 0
	pp.MaxActivationDistance = 16
	pp.RequiresLineOfSight = false
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.Parent = c
	return c
end

local function stage(parent, color, mat, trim)
	part(parent, "Suelo", at(0, 0.5, 0), Vector3.new(28, 1, 16), color, mat, true)
	part(parent, "Escalon", at(0, 0.25, -8.75), Vector3.new(14, 0.5, 1.5), color, mat, true)
	part(parent, "Borde", at(0, 1.05, -7.95), Vector3.new(28, 0.12, 0.25), trim, M.Neon)
	-- un halo en el suelo delante del puesto, para que se vea desde lejos
	local ring = part(parent, "Halo", at(0, 0.08, -12), Vector3.new(0.1, 9, 9), trim, M.Neon, false, "Cylinder")
	ring.CFrame = O * at(0, 0.08, -12) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Transparency = 0.75
end

-- Hilera de bombillas de feria de un punto a otro (el cliente las enciende en cadena: atributo Marquee = orden)
local function marquee(parent, from, to, spacing)
	local n = math.max(2, math.floor((to - from).Magnitude / spacing + 0.5))
	for i = 0, n do
		local b = part(parent, "Marquesina", CFrame.new(from:Lerp(to, i / n)), Vector3.one * 0.45, C(255, 236, 170), M.Neon, false, "Ball")
		b.CastShadow = false
		b:SetAttribute("Marquee", i)
	end
end

local function badge(parent, y, z)
	local a = part(parent, "BadgeAnchor", at(0, y, z or 0), Vector3.one, Color3.new(), M.SmoothPlastic)
	a.Transparency = 1
end

-- Banderines de feria colgando entre dos puntos
local function bunting(parent, from, to, n, colors)
	for i = 1, n do
		local t = (i - 0.5) / n
		local p = from:Lerp(to, t) - Vector3.new(0, math.sin(t * math.pi) * 1.2 + 0.7, 0)
		local f = part(parent, "Banderin", CFrame.new(p) * CFrame.Angles(0, 0, math.pi / 4), Vector3.new(1.1, 1.1, 0.08), colors[(i - 1) % #colors + 1], M.Fabric)
		f.CastShadow = false
	end
end

-- Disco plano (cilindro tumbado) centrado en el eje del puesto
local function disc(parent, name, x, y, z, d, h, color, mat, solid)
	return part(parent, name, at(x, y, z) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(h, d, d), color, mat, solid, "Cylinder")
end

-- Viga de a hasta b (posiciones locales del puesto)
local function strut(parent, name, a, b, t, color, mat, solid)
	return part(parent, name, CFrame.lookAt((a + b) / 2, b), Vector3.new(t, t, (b - a).Magnitude), color, mat, solid)
end

---------- Ruleta gigante ----------
-- Dirección en el plano de la rueda: a grados en el sentido de las agujas del reloj desde arriba, visto desde la calle
local function dir(a)
	local r = math.rad(a)
	return Vector3.new(-math.sin(r), math.cos(r), 0)
end

-- La rueda en sí (lo que gira, el alfiler y el halo): eje en A (local), radio R. TiendasFX la anima.
local function wheelRotor(m, A, R)
	local halo = part(m, "Halo", at(A.X, A.Y, A.Z + 0.9) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(0.2, 2 * R + 4, 2 * R + 4), C(200, 80, 255), M.Neon, false, "Cylinder")
	halo.Transparency = 0.65
	local rotor = model(m, "Rotor")
	local axle = part(rotor, "Eje", at(A.X, A.Y, A.Z), Vector3.one, Color3.new(), M.SmoothPlastic)
	axle.Transparency = 1
	rotor.PrimaryPart = axle
	rotor:SetAttribute("Base", axle.CFrame)
	part(rotor, "Fondo", at(A.X, A.Y, A.Z + 0.35) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(0.3, 2 * R + 0.4, 2 * R + 0.4), C(20, 14, 26), M.SmoothPlastic, false, "Cylinder")
	local a, b = R * math.cos(math.rad(22.5)), R * math.sin(math.rad(22.5))
	for k = 1, 8 do
		local u = dir((k - 1) * 45)
		local v = dir((k - 1) * 45 + 90)
		local mid = A + u * a
		for _, vd in {v, -v} do
			local Y, Z = -u, -vd
			local center = mid - u * (a / 2) + vd * (b / 2)
			local w = part(rotor, "Casilla", CFrame.fromMatrix(center, Y:Cross(Z), Y, Z), Vector3.new(0.8, a, b), k % 2 == 0 and C(150, 120, 255) or C(255, 70, 100), M.SmoothPlastic, false, "Wedge")
			w:SetAttribute("Seg", k)
		end
		local d = (k - 1) * 45 + 22.5
		part(rotor, "Radio", CFrame.new(A + dir(d) * (R / 2 + 0.6) - Vector3.new(0, 0, 0.45)) * CFrame.Angles(0, 0, math.rad(d)), Vector3.new(0.3, R - 1.2, 0.2), GOLD, M.Neon)
	end
	local n = math.floor(R * 3.8)
	for j = 1, n do
		local c = (j - 0.5) * 360 / n
		part(rotor, "Llanta", CFrame.new(A + dir(c) * (R + 0.4)) * CFrame.Angles(0, 0, math.rad(c)), Vector3.new(2 * math.pi * (R + 0.4) / n + 0.05, 0.8, 1.3), GOLD, M.Metal)
	end
	for j = 1, 24 do
		local bulb = part(rotor, "Bombilla", CFrame.new(A + dir((j - 1) * 15) * (R + 0.4) - Vector3.new(0, 0, 0.7)), Vector3.one * 0.65, C(255, 240, 200), M.Neon, false, "Ball")
		bulb:SetAttribute("I", j)
	end
	part(rotor, "Buje", at(A.X, A.Y, A.Z - 0.3) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(1.2, 4.4, 4.4), GOLD, M.Metal, false, "Cylinder")
	local pumpkin = part(rotor, "Calabaza", at(A.X, A.Y, A.Z - 1.1), Vector3.new(2.8, 2.3, 2.8), C(255, 130, 20), M.Neon, false, "Ball")
	light(pumpkin, C(255, 140, 40), 12, 1.2)
	local face = part(rotor, "Caras", at(A.X, A.Y, A.Z - 0.42), Vector3.new(2 * R, 2 * R, 0.05), Color3.new(), M.SmoothPlastic)
	face.Transparency = 1
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Premios"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 32
	sg.LightInfluence = 0
	sg.Brightness = 1.4
	sg.Parent = face
	local pointer = part(m, "Flecha", at(A.X, A.Y + R + 1.4, A.Z - 0.9) * CFrame.Angles(0, 0, math.pi / 4), Vector3.new(1.9, 1.9, 0.6), C(255, 40, 60), M.Neon)
	light(pointer, C(255, 60, 80), 10, 1.5)
	part(m, "FlechaTapa", at(A.X, A.Y + R + 2.9, A.Z - 0.6), Vector3.new(3.2, 1.2, 1.4), GOLD, M.Metal)
end

---------- Zona de la Ruleta (donde estaba la capilla, al oeste de la plaza) ----------
-- Sencilla pero con fuerza: la plazoleta redonda ES una ruleta tumbada (anillos de neón y radios dorados), la rueda
-- gigante al fondo entre dos torres de feria con su telón de estrellas, la taquilla delante (abre la ventana), un arco
-- de entrada desde la plaza y farolas de colores con guirnaldas que suben hasta la rueda. Todo mira a la plaza (-Z).
local function buildWheelZone(m)
	local Z = B.ZONE_R
	local PINK, VIOLET, ORANGE = C(255, 80, 170), C(160, 110, 255), C(255, 150, 40)
	-- suelo: base que se pisa y, encima, la ruleta tumbada
	disc(m, "Suelo", 0, -0.1, 0, 2 * Z, 1, C(38, 28, 48), M.Slate, true)
	disc(m, "SueloAro", 0, 0.42, 0, 2 * Z - 1.6, 0.05, PINK, M.Neon)
	disc(m, "SueloMadera", 0, 0.45, 0, 2 * Z - 2.6, 0.05, C(74, 50, 38), M.WoodPlanks)
	for k = 1, 8 do
		-- casillas tumbadas: cuñas de color entre los radios (alternas, como la rueda)
		local a = math.rad((k - 1) * 45 + 22.5)
		local r0, r1 = 6, Z - 2.4
		local mid = (r0 + r1) / 2
		local tile = part(m, "SueloCasilla", at(math.sin(a) * mid, 0.47, math.cos(a) * mid) * CFrame.Angles(0, a, 0), Vector3.new(2 * mid * math.tan(math.rad(22.5)) * 0.62, 0.05, r1 - r0 - 1), k % 2 == 0 and C(90, 50, 120) or C(120, 40, 70), M.Slate)
		tile.Transparency = 0.15
		local b = math.rad((k - 1) * 45)
		part(m, "SueloRadio", at(math.sin(b) * (r0 + r1) / 2, 0.5, math.cos(b) * (r0 + r1) / 2) * CFrame.Angles(0, b, 0), Vector3.new(0.35, 0.06, r1 - r0), GOLD, M.Metal)
	end
	disc(m, "SueloAroInterior", 0, 0.48, 0, 12.6, 0.06, VIOLET, M.Neon)
	disc(m, "Medallon", 0, 0.5, 0, 11.4, 0.08, C(52, 36, 62), M.Slate)
	disc(m, "MedallonOro", 0, 0.54, 0, 4.4, 0.1, GOLD, M.Metal)
	disc(m, "MedallonCentro", 0, 0.58, 0, 3, 0.1, ORANGE, M.Neon)

	-- la rueda, al fondo, entre dos torres
	local R = B.R
	local A = Vector3.new(0, 16.5, 15.5)
	for _, x in {-15, 15} do
		for _, dz in {-1.2, 1.2} do
			for _, dx in {-1.2, 1.2} do
				part(m, "Torre", at(x + dx, 15.5, 16.5 + dz), Vector3.new(0.7, 31, 0.7), C(46, 30, 26), M.Wood, true)
			end
		end
		for y = 4, 28, 6 do
			part(m, "TorreTravesano", at(x, y, 15.3), Vector3.new(3.1, 0.4, 0.4), C(66, 42, 32), M.Wood)
			part(m, "TorreTravesano", at(x, y, 17.7), Vector3.new(3.1, 0.4, 0.4), C(66, 42, 32), M.Wood)
		end
		part(m, "TorreNeon", at(x, 15.5, 15.05), Vector3.new(0.3, 30, 0.12), PINK, M.Neon)
		marquee(m, Vector3.new(x - 1.2, 1.5, 15.0), Vector3.new(x - 1.2, 30.5, 15.0), 1.25)
		marquee(m, Vector3.new(x + 1.2, 1.5, 15.0), Vector3.new(x + 1.2, 30.5, 15.0), 1.25)
		-- tejadillo puntiagudo con banderín
		local cone = part(m, "TorreTejado", at(x, 33, 16.5), Vector3.new(4.4, 4.2, 4.4), C(120, 30, 70), M.Fabric)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.FileMesh
		mesh.MeshId = "rbxassetid://1033714" -- cono
		mesh.Scale = Vector3.new(2.2, 4.2, 2.2)
		mesh.Parent = cone
		part(m, "Mastil", at(x, 36.6, 16.5), Vector3.new(0.2, 3, 0.2), C(30, 26, 34), M.Metal)
		local flag = part(m, "Bandera", at(x + 0.9, 37.4, 16.5), Vector3.new(1.6, 1, 0.08), ORANGE, M.Fabric)
		flag.CastShadow = false
	end
	part(m, "Viga", at(0, 31.2, 16.5), Vector3.new(33, 1.8, 1.8), C(46, 30, 26), M.Wood, true)
	marquee(m, Vector3.new(-13.5, 31.2, 15.5), Vector3.new(13.5, 31.2, 15.5), 1.25)
	-- telón morado con estrellas detrás de la rueda
	part(m, "Telon", at(0, 15.5, 18.4), Vector3.new(28.6, 29.5, 0.4), C(58, 16, 70), M.Fabric)
	local rng = Random.new(7)
	for _ = 1, 40 do
		local s = part(m, "Estrella", at(rng:NextNumber(-13.5, 13.5), rng:NextNumber(2, 29), 18.15), Vector3.new(0.3, 0.3, 0.05), C(255, 220, 140), M.Neon)
		s.CFrame *= CFrame.Angles(0, 0, math.pi / 4)
	end
	-- caballete de la rueda: dos patas en A hasta el eje
	for _, x in {-6.5, 6.5} do
		strut(m, "Pata", Vector3.new(x, 0.4, 16.6), Vector3.new(0, A.Y, 16.6), 1.3, C(40, 26, 24), M.Wood, true)
	end
	part(m, "EjeSoporte", at(0, A.Y, 16.3) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(1.6, 1.8, 1.8), C(40, 34, 40), M.Metal, false, "Cylinder")
	wheelRotor(m, A, R)
	sign(m, at(0, 35.2, 16), 24, 4.8, "WHEEL OF FRIGHT", C(255, 230, 120), C(255, 90, 160), Enum.Font.Creepster)
	bunting(m, Vector3.new(-14, 29.4, 15.2), Vector3.new(14, 29.4, 15.2), 16, {C(255, 70, 100), C(255, 200, 60), C(150, 120, 255), C(110, 200, 120)})
	-- focos desde el suelo hacia la rueda
	for _, x in {-8, 8} do
		local f = part(m, "Foco", at(x, 1.2, 7), Vector3.new(0.9, 0.9, 1.4), C(30, 30, 34), M.Metal)
		f.CFrame = CFrame.lookAt((O * at(x, 1.2, 7)).Position, (O * at(0, A.Y, A.Z)).Position)
		local s = light(f, x < 0 and PINK or VIOLET, 30, 1.6, "SpotLight")
		s.Angle = 50
		s.Face = Enum.NormalId.Front
	end

	-- taquilla (abre la ventana de la ruleta): mostrador con boletos, campana y dos farolillos
	counter(m, at(0, 1.6, 6), Vector3.new(7, 2.4, 1.8), C(150, 30, 50), "Spin", "Wheel of Fright")
	part(m, "MostradorFrente", at(0, 1.6, 5.05), Vector3.new(6.2, 1.4, 0.1), GOLD, M.Neon).Transparency = 0.35
	local ticket = part(m, "Boletos", at(-2.2, 3.35, 6), Vector3.new(1.2, 0.9, 0.9), C(200, 40, 60), M.SmoothPlastic)
	part(m, "Boleto", at(-2.2, 3.4, 5.4) * CFrame.Angles(math.rad(-20), 0, 0), Vector3.new(0.8, 0.05, 0.6), C(255, 220, 120), M.SmoothPlastic)
	ticket.CastShadow = false
	part(m, "Campana", at(2.2, 3.15, 6), Vector3.new(0.9, 0.5, 0.9), GOLD, M.Metal, false, "Ball")
	for _, x in {-4.4, 4.4} do
		part(m, "Farol", at(x, 2.5, 6), Vector3.new(0.35, 4.2, 0.35), C(30, 26, 34), M.Metal)
		local l = part(m, "Farolillo", at(x, 5, 6), Vector3.new(1, 1.3, 1), ORANGE, M.Neon, false, "Ball")
		light(l, ORANGE, 12, 1.4)
	end

	-- arco de entrada desde la plaza
	local ez = -Z + 0.5
	for _, x in {-6.5, 6.5} do
		part(m, "ArcoPilar", at(x, 6.5, ez), Vector3.new(1.6, 13, 1.6), C(46, 30, 26), M.Wood, true)
		part(m, "ArcoPilarNeon", at(x, 6.5, ez - 0.85), Vector3.new(0.3, 12, 0.1), PINK, M.Neon)
		marquee(m, Vector3.new(x, 1.4, ez - 0.95), Vector3.new(x, 12.5, ez - 0.95), 1.1)
		part(m, "ArcoRemate", at(x, 13.6, ez), Vector3.new(2.2, 1.2, 2.2), GOLD, M.Metal)
		local ball = part(m, "ArcoBola", at(x, 14.8, ez), Vector3.one * 1.4, ORANGE, M.Neon, false, "Ball")
		light(ball, ORANGE, 14, 1.5)
	end
	part(m, "ArcoViga", at(0, 12.2, ez), Vector3.new(14.6, 1.2, 1.4), C(46, 30, 26), M.Wood)
	sign(m, at(0, 10.2, ez - 0.2), 11.4, 2.6, "WHEEL OF FRIGHT", C(255, 230, 120), C(255, 90, 160), Enum.Font.Creepster)

	-- farolas de colores alrededor
	local colors = {PINK, VIOLET, ORANGE}
	for i, deg in {-55, -100, -145, 55, 100, 145} do
		local a = math.rad(deg)
		local p = Vector3.new(math.sin(a) * (Z - 1.2), 0, -math.cos(a) * (Z - 1.2))
		part(m, "Farola", at(p.X, 4.6, p.Z), Vector3.new(0.5, 9, 0.5), C(30, 26, 34), M.Metal, true)
		part(m, "FarolaBase", at(p.X, 0.9, p.Z), Vector3.new(1.2, 1, 1.2), C(30, 26, 34), M.Metal, true)
		local col = colors[(i - 1) % 3 + 1]
		local l = part(m, "FarolaLuz", at(p.X, 9.5, p.Z), Vector3.one * 1.3, col, M.Neon, false, "Ball")
		light(l, col, 18, 1.8)
	end
	badge(m, 40, 16)
end

local function buildWheel(m)
	local R = B.R
	local A = Vector3.new(0, 13, 3.5) -- eje
	stage(m, C(70, 48, 38), M.WoodPlanks, C(200, 80, 255))
	for _, x in {-12, 12} do
		part(m, "Poste", at(x, 12.5, 5.5), Vector3.new(1.6, 24, 1.6), C(46, 30, 26), M.Wood, true)
		part(m, "PosteNeon", at(x, 12.5, 4.65), Vector3.new(0.3, 24, 0.12), C(255, 70, 160), M.Neon)
		marquee(m, Vector3.new(x, 1.6, 4.5), Vector3.new(x, 23.4, 4.5), 1.2)
	end
	part(m, "Viga", at(0, 24.5, 5.5), Vector3.new(26, 1.6, 1.6), C(46, 30, 26), M.Wood, true)
	marquee(m, Vector3.new(-11, 24.5, 4.6), Vector3.new(11, 24.5, 4.6), 1.2)
	-- halo de neón detrás de la rueda
	local halo = part(m, "Halo", at(0, 13, 4.3) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(0.2, 2 * B.R + 3, 2 * B.R + 3), C(200, 80, 255), M.Neon, false, "Cylinder")
	halo.Transparency = 0.55
	part(m, "Telon", at(0, 12.5, 6.6), Vector3.new(22.4, 23, 0.4), C(58, 16, 70), M.Fabric)
	-- estrellas en el telón
	local rng = Random.new(7)
	for _ = 1, 26 do
		local s = part(m, "Estrella", at(rng:NextNumber(-10.5, 10.5), rng:NextNumber(2, 23), 6.35), Vector3.new(0.25, 0.25, 0.05), C(255, 220, 140), M.Neon)
		s.CFrame *= CFrame.Angles(0, 0, math.pi / 4)
	end
	part(m, "Pie", at(0, 6, 4.6), Vector3.new(3, 10, 1.6), C(40, 26, 24), M.Wood, true)

	local rotor = model(m, "Rotor")
	local axle = part(rotor, "Eje", at(A.X, A.Y, A.Z), Vector3.one, Color3.new(), M.SmoothPlastic)
	axle.Transparency = 1
	rotor.PrimaryPart = axle
	rotor:SetAttribute("Base", axle.CFrame)
	part(rotor, "Fondo", at(A.X, A.Y, A.Z + 0.35) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(0.3, 2 * R + 0.4, 2 * R + 0.4), C(20, 14, 26), M.SmoothPlastic, false, "Cylinder")
	-- 8 casillas: cada una, dos cuñas (triángulos rectángulos) del centro al borde
	local a, b = R * math.cos(math.rad(22.5)), R * math.sin(math.rad(22.5))
	for k = 1, 8 do
		local u = dir((k - 1) * 45)
		local v = dir((k - 1) * 45 + 90)
		local mid = A + u * a
		for h, vd in {v, -v} do
			local Y, Z = -u, -vd
			local center = mid - u * (a / 2) + vd * (b / 2)
			local w = part(rotor, "Casilla", CFrame.fromMatrix(center, Y:Cross(Z), Y, Z), Vector3.new(0.8, a, b), k % 2 == 0 and C(150, 120, 255) or C(255, 70, 100), M.SmoothPlastic, false, "Wedge")
			w:SetAttribute("Seg", k)
		end
		local d = (k - 1) * 45 + 22.5
		part(rotor, "Radio", CFrame.new(A + dir(d) * (R / 2 + 0.6) - Vector3.new(0, 0, 0.45)) * CFrame.Angles(0, 0, math.rad(d)), Vector3.new(0.25, R - 1.2, 0.2), GOLD, M.Neon)
	end
	for j = 1, 32 do
		local c = (j - 0.5) * 11.25
		part(rotor, "Llanta", CFrame.new(A + dir(c) * (R + 0.35)) * CFrame.Angles(0, 0, math.rad(c)), Vector3.new(1.75, 0.7, 1.2), GOLD, M.Metal)
	end
	for j = 1, 16 do
		local bulb = part(rotor, "Bombilla", CFrame.new(A + dir((j - 1) * 22.5) * (R + 0.35) - Vector3.new(0, 0, 0.65)), Vector3.one * 0.6, C(255, 240, 200), M.Neon, false, "Ball")
		bulb:SetAttribute("I", j)
	end
	part(rotor, "Buje", at(A.X, A.Y, A.Z - 0.3) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(1.2, 3.6, 3.6), GOLD, M.Metal, false, "Cylinder")
	local pumpkin = part(rotor, "Calabaza", at(A.X, A.Y, A.Z - 1), Vector3.new(2.2, 1.8, 2.2), C(255, 130, 20), M.Neon, false, "Ball")
	light(pumpkin, C(255, 140, 40), 10, 1)
	-- nombres de los premios (los escribe el cliente) sobre la cara delantera
	local face = part(rotor, "Caras", at(A.X, A.Y, A.Z - 0.42), Vector3.new(2 * R, 2 * R, 0.05), Color3.new(), M.SmoothPlastic)
	face.Transparency = 1
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Premios"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	sg.Brightness = 1.4
	sg.Parent = face

	-- flecha arriba
	local pointer = part(m, "Flecha", at(A.X, A.Y + R + 1.2, A.Z - 0.9) * CFrame.Angles(0, 0, math.pi / 4), Vector3.new(1.5, 1.5, 0.5), C(255, 40, 60), M.Neon)
	light(pointer, C(255, 60, 80), 8, 1.5)
	part(m, "FlechaTapa", at(A.X, A.Y + R + 2.4, A.Z - 0.6), Vector3.new(2.6, 1, 1.2), GOLD, M.Metal)

	sign(m, at(0, 27.6, 5), 22, 4.4, "WHEEL OF FRIGHT", C(255, 230, 120), C(255, 90, 160), Enum.Font.Creepster)
	bunting(m, Vector3.new(-12, 23.6, 4.4), Vector3.new(12, 23.6, 4.4), 12, {C(255, 70, 100), C(255, 200, 60), C(150, 120, 255), C(110, 200, 120)})
	torch(m, -13, -6.5, C(255, 120, 40))
	torch(m, 13, -6.5, C(255, 120, 40))
	-- focos desde el suelo hacia la rueda
	for _, x in {-6, 6} do
		local f = part(m, "Foco", CFrame.lookAt((O * at(x, 1.4, -5)).Position, (O * at(0, 13, 3.5)).Position) * CFrame.new(), Vector3.new(0.8, 0.8, 1.2), C(30, 30, 34), M.Metal)
		f.CFrame = CFrame.lookAt((O * at(x, 1.4, -5)).Position, (O * at(0, 13, 3.5)).Position)
		local s = light(f, x < 0 and C(255, 90, 200) or C(140, 120, 255), 30, 4, "SpotLight")
		s.Angle = 50
		s.Face = Enum.NormalId.Front
	end
	counter(m, at(0, 2.2, -5.4), Vector3.new(6, 2.4, 1.6), C(150, 30, 50), "Spin", "Wheel of Fright")
	badge(m, 32, 5)
end

---------- Mercado de sustos (tienda de monedas) ----------
local function buildMarket(m)
	stage(m, C(84, 58, 40), M.WoodPlanks, C(255, 170, 40))
	for _, p in {{-12.5, -6.6}, {12.5, -6.6}, {-12.5, 6.6}, {12.5, 6.6}} do
		part(m, "Poste", at(p[1], 6.5, p[2]), Vector3.new(0.8, 12, 0.8), C(60, 40, 30), M.Wood, true)
	end
	-- toldo a rayas, inclinado hacia delante
	local slope = math.atan2(2.6, 15)
	for i = 1, 8 do
		local x = -14 + (i - 0.5) * 3.5
		part(m, "Toldo", at(x, 13.3, 0) * CFrame.Angles(-slope, 0, 0), Vector3.new(3.5, 0.3, 15.8), i % 2 == 0 and C(110, 40, 170) or C(255, 120, 30), M.Fabric)
		-- faldón con picos
		part(m, "Faldon", at(x, 11.4, -7.95), Vector3.new(3.5, 1.1, 0.2), i % 2 == 0 and C(255, 120, 30) or C(110, 40, 170), M.Fabric)
		for j = -1, 1, 2 do
			local pico = part(m, "Pico", at(x + j * 0.88, 10.85, -7.95) * CFrame.Angles(0, 0, math.pi / 4), Vector3.new(1.24, 1.24, 0.18), i % 2 == 0 and C(255, 120, 30) or C(110, 40, 170), M.Fabric)
			pico.CastShadow = false
		end
	end
	marquee(m, Vector3.new(-13.8, 12, -8.15), Vector3.new(13.8, 12, -8.15), 1.15)
	for _, x in {-12.5, 12.5} do
		marquee(m, Vector3.new(x, 1.6, -7.1), Vector3.new(x, 11, -7.1), 1.15)
	end
	part(m, "Fondo", at(0, 6.5, 7.2), Vector3.new(25, 12, 0.4), C(50, 24, 60), M.Fabric)
	-- tres sustos en vitrina, cada uno en su pedestal con foco
	local Scares = RS.Assets.Scares
	for i, t in {"Armario", "Muneca", "Payaso"} do
		local x = (i - 2) * 7.5
		part(m, "Pedestal", at(x, 2.2, 3.6), Vector3.new(3.4, 2.4, 3.4), C(34, 22, 40), M.Marble, true)
		part(m, "PedestalNeon", at(x, 3.45, 3.6), Vector3.new(3.6, 0.12, 3.6), C(255, 170, 40), M.Neon)
		local tpl = Scares:FindFirstChild(t)
		if tpl then
			local s = tpl:Clone()
			for _, d in s:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored, d.CanCollide, d.CanTouch, d.CanQuery = true, false, false, false
					if d.Name == "Hitbox" or d.Name == "Range" or d.Name == "Path" then
						d.Transparency = 1
					end
				elseif d:IsA("Sound") or d:IsA("Script") then
					d:Destroy()
				end
			end
			-- el pivote de los sustos está a ras de suelo y mira hacia donde asustan: aquí, a la calle
			s:PivotTo(O * at(x, 3.5, 3.6))
			s:ScaleTo(0.7)
			s.Name = "Vitrina"
			s.Parent = m
		end
		local f = part(m, "Foco", at(x, 12.2, 1), Vector3.new(0.6, 0.6, 0.6), C(30, 30, 34), M.Metal)
		f.CFrame = CFrame.lookAt(f.Position, (O * at(x, 4, 3.6)).Position)
		local s = light(f, C(255, 210, 150), 16, 3, "SpotLight")
		s.Angle = 40
	end
	counter(m, at(0, 2.2, -5.2), Vector3.new(18, 2.4, 1.8), C(120, 60, 30), "Shop", "Scare Market")
	-- montones de monedas en el mostrador
	local rng = Random.new(3)
	for _, x in {-6.5, 6.5} do
		for j = 1, 7 do
			local coin = part(m, "Moneda", at(x + rng:NextNumber(-1, 1), 3.55 + j * 0.16, -5.2 + rng:NextNumber(-0.4, 0.4)) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(0.16, 1.1, 1.1), GOLD, M.Foil, false, "Cylinder")
			coin.CastShadow = false
		end
		local sp = Instance.new("Sparkles")
		sp.SparkleColor = GOLD
		sp.Parent = m:FindFirstChild("Moneda")
	end
	-- farolillos colgando del borde del toldo
	for _, x in {-9, 0, 9} do
		part(m, "Cadena", at(x, 11.2, -7.2), Vector3.new(0.1, 1.4, 0.1), C(30, 30, 30), M.Metal)
		local l = part(m, "Farolillo", at(x, 10.1, -7.2), Vector3.new(1.1, 1.3, 1.1), C(255, 150, 50), M.Neon, false, "Ball")
		light(l, C(255, 150, 60), 14, 1.6)
	end
	sign(m, at(0, 16.4, -6.4), 18, 3.8, "SCARE MARKET", C(255, 225, 90), C(255, 120, 30))
	torch(m, -13.5, -7.5, C(255, 140, 40), 7)
	torch(m, 13.5, -7.5, C(255, 140, 40), 7)
	badge(m, 20.5, -6)
end

---------- Cámara de gemas ----------
local CYAN = C(80, 230, 255)
local VIOLET = C(170, 90, 255)

local function crystals(m, x, z, n, seed)
	local rng = Random.new(seed)
	for i = 1, n do
		local h = rng:NextNumber(1.5, 4.5)
		local c = part(m, "Cristal", at(x + rng:NextNumber(-1.4, 1.4), 1 + h / 2 - 0.4, z + rng:NextNumber(-1.4, 1.4))
			* CFrame.Angles(rng:NextNumber(-0.45, 0.45), rng:NextNumber(0, math.pi), rng:NextNumber(-0.45, 0.45)),
			Vector3.new(0.7, h, 0.7), i % 2 == 0 and VIOLET or CYAN, M.Neon)
		c.Transparency = 0.15
	end
end

local function gem(parent, name, cf, size, color)
	-- un cubo apoyado en un vértice parece una gema tallada
	local g = part(parent, name, cf * CFrame.Angles(math.rad(45), 0, math.rad(35.26)), Vector3.one * size, color, M.Glass)
	g.Transparency = 0.25
	g.Reflectance = 0.2
	local core = part(parent, name .. "Nucleo", cf * CFrame.Angles(math.rad(45), 0, math.rad(35.26)), Vector3.one * size * 0.62, color, M.Neon)
	return g, core
end

local function buildGems(m)
	stage(m, C(40, 40, 58), M.Slate, CYAN)
	for _, x in {-10, 10} do
		part(m, "Pilar", at(x, 9, 5), Vector3.new(2.6, 17, 2.6), C(62, 60, 84), M.Slate, true)
		part(m, "PilarNeon", at(x, 9, 3.65), Vector3.new(0.3, 15, 0.1), CYAN, M.Neon)
		part(m, "Capitel", at(x, 17.8, 5), Vector3.new(3.4, 1, 3.4), C(80, 78, 104), M.Slate)
	end
	part(m, "Arco", at(0, 19.2, 5), Vector3.new(23.6, 2.4, 3), C(62, 60, 84), M.Slate, true)
	for _, x in {-10, 10} do
		marquee(m, Vector3.new(x, 1.8, 3.5), Vector3.new(x, 17, 3.5), 1.2)
	end
	marquee(m, Vector3.new(-11.6, 19.2, 3.4), Vector3.new(11.6, 19.2, 3.4), 1.2)
	gem(m, "Clave", at(0, 19.2, 3.4), 1.3, CYAN)
	part(m, "Fondo", at(0, 9, 6.6), Vector3.new(17.4, 17, 0.5), C(18, 16, 44), M.Fabric)
	local rng = Random.new(11)
	for _ = 1, 30 do
		part(m, "Estrella", at(rng:NextNumber(-8.4, 8.4), rng:NextNumber(1.6, 17), 6.3), Vector3.one * rng:NextNumber(0.12, 0.3), rng:NextNumber() < 0.5 and CYAN or VIOLET, M.Neon)
	end
	-- pedestal y gema gigante flotando (la anima el cliente: gira y sube y baja)
	part(m, "Pedestal", at(0, 1.9, 1) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(1.8, 5.5, 5.5), C(62, 60, 84), M.Slate, true, "Cylinder")
	local ring = part(m, "PedestalNeon", at(0, 2.85, 1) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(0.1, 5.9, 5.9), CYAN, M.Neon, false, "Cylinder")
	ring.Transparency = 0.2
	local big = model(m, "GemaGigante")
	local g, core = gem(big, "Gema", at(0, 9.5, 1), 3.6, CYAN)
	big.PrimaryPart = g
	big:SetAttribute("Base", O * at(0, 9.5, 1))
	light(core, CYAN, 26, 3)
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(CYAN, VIOLET)
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0)})
	pe.Lifetime = NumberRange.new(1.2, 2)
	pe.Rate = 18
	pe.Speed = NumberRange.new(1.5, 3)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Parent = core
	for i = 1, 4 do
		local s = gem(big, "Satelite", at(0, 9.5, 1), 0.8, i % 2 == 0 and VIOLET or CYAN)
		s:SetAttribute("Orbit", i)
	end
	for _, d in big:GetDescendants() do
		if d:IsA("BasePart") and d.Name:find("Nucleo") and d.Parent == big and d ~= core then
			d:Destroy() -- los satélites, sin núcleo
		end
	end
	crystals(m, -11.2, -5.6, 6, 1)
	crystals(m, 11.2, -5.6, 6, 2)
	crystals(m, -6.5, 4.5, 4, 3)
	crystals(m, 6.5, 4.5, 4, 4)
	counter(m, at(0, 2.2, -5.6), Vector3.new(11, 2.4, 1.6), C(54, 52, 76), "Trade gems", "Gem Vault")
	for i = 1, 9 do
		local x = -4.5 + (i - 1) * 1.1
		local small = part(m, "Gemita", at(x, 3.75, -5.6) * CFrame.Angles(math.rad(45), i, math.rad(35)), Vector3.one * 0.55, i % 3 == 0 and VIOLET or CYAN, M.Neon)
		small.CastShadow = false
	end
	sign(m, at(0, 22.6, 4.4), 15, 3.6, "GEM VAULT", C(170, 250, 255), C(160, 100, 255))
	torch(m, -13, -6.8, CYAN)
	torch(m, 13, -6.8, CYAN)
	badge(m, 26.5, 4)
end

---------- Laboratorio de ensamblaje ----------
local GREEN = C(110, 255, 90)

local function gear(parent, name, cf, r, color, speed)
	local g = model(parent, name)
	local hub = part(g, "Centro", cf * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(0.5, 2 * r, 2 * r), color, M.Metal, false, "Cylinder")
	g.PrimaryPart = hub
	local teeth = math.floor(r * 5)
	for i = 1, teeth do
		local a = i / teeth * math.pi * 2
		part(g, "Diente", cf * CFrame.Angles(0, 0, a) * CFrame.new(0, r + 0.25, 0), Vector3.new(0.55, 0.7, 0.45), color, M.Metal)
	end
	part(g, "Eje", cf * CFrame.new(0, 0, -0.3) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(0.3, 0.6, 0.6), C(40, 40, 40), M.Metal, false, "Cylinder")
	g:SetAttribute("Base", O * cf)
	g:SetAttribute("Speed", speed)
	return g
end

local function coil(m, x, z)
	part(m, "BobinaBase", at(x, 1.8, z), Vector3.new(2.4, 1.6, 2.4), C(50, 50, 56), M.DiamondPlate, true)
	part(m, "BobinaColumna", at(x, 5.6, z) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(6.4, 1.1, 1.1), C(180, 110, 60), M.Metal, true, "Cylinder")
	for i, y in {3.6, 5.4, 7.2} do
		part(m, "BobinaAro", at(x, y, z) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(0.35, 2.6 - i * 0.3, 2.6 - i * 0.3), C(200, 130, 70), M.Metal, false, "Cylinder")
	end
	local top = part(m, "BobinaBola", at(x, 9.6, z), Vector3.one * 2.2, C(200, 150, 255), M.Neon, false, "Ball")
	light(top, C(190, 140, 255), 14, 1.5)
	local att = Instance.new("Attachment")
	att.Parent = top
	return top, att
end

local function buildLab(m)
	stage(m, C(74, 76, 82), M.DiamondPlate, GREEN)
	part(m, "Pared", at(0, 8, 6.8), Vector3.new(27, 15, 1), C(86, 48, 44), M.Brick, true)
	part(m, "ParedNeon", at(0, 15.4, 6.25), Vector3.new(27, 0.3, 0.1), GREEN, M.Neon)
	-- tuberías
	for _, y in {4, 13} do
		part(m, "Tuberia", at(0, y, 6.1) * CFrame.Angles(0, 0, 0), Vector3.new(26, 0.6, 0.6), C(70, 140, 100), M.Metal, false, "Cylinder")
	end
	gear(m, "Engranaje", at(-7.5, 10, 6.05), 2.2, C(150, 140, 120), 0.6)
	gear(m, "Engranaje", at(-3.9, 12.1, 6.05), 1.4, C(190, 120, 70), -0.95)
	gear(m, "Engranaje", at(7.5, 10.5, 6.05), 1.8, C(150, 140, 120), -0.75)
	-- banco de trabajo con frascos brillantes
	part(m, "Banco", at(-5.5, 3.2, 3), Vector3.new(10, 0.5, 3.6), C(96, 66, 44), M.WoodPlanks, true)
	for _, p in {{-10, 1.6}, {-1, 1.6}, {-10, 4.4}, {-1, 4.4}} do
		part(m, "Pata", at(p[1], 2.1, p[2]), Vector3.new(0.4, 2.2, 0.4), C(60, 44, 30), M.Wood, true)
	end
	for i, col in {C(110, 255, 90), C(255, 80, 200), C(80, 200, 255), C(255, 200, 60)} do
		local x = -9 + i * 1.6
		local jar = part(m, "Frasco", at(x, 4.15, 3.4) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(1.4, 0.9, 0.9), Color3.new(1, 1, 1), M.Glass, false, "Cylinder")
		jar.Transparency = 0.6
		part(m, "Liquido", at(x, 3.95, 3.4) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(0.9, 0.75, 0.75), col, M.Neon, false, "Cylinder")
	end
	part(m, "Calavera", at(-2.4, 3.95, 2.6), Vector3.new(1, 1, 1), C(235, 225, 200), M.SmoothPlastic, false, "Ball")
	-- caldero burbujeante
	part(m, "Caldero", at(5.2, 3, 0.6) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(4, 5.6, 5.6), C(26, 26, 30), M.Metal, true, "Cylinder")
	part(m, "CalderoBorde", at(5.2, 5.05, 0.6) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(0.4, 6.1, 6.1), C(40, 40, 46), M.Metal, false, "Cylinder")
	local brew = part(m, "Pocion", at(5.2, 5.0, 0.6) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(0.3, 5.1, 5.1), GREEN, M.Neon, false, "Cylinder")
	light(brew, GREEN, 18, 2.5)
	local bub = Instance.new("ParticleEmitter")
	bub.Name = "Burbujas"
	bub.Color = ColorSequence.new(GREEN)
	bub.LightEmission = 0.8
	bub.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.8, 0.5), NumberSequenceKeypoint.new(1, 0)})
	bub.Lifetime = NumberRange.new(0.8, 1.6)
	bub.Rate = 22
	bub.Speed = NumberRange.new(1.5, 3)
	bub.SpreadAngle = Vector2.new(20, 20)
	bub.EmissionDirection = Enum.NormalId.Right
	bub.Parent = brew
	local smoke = Instance.new("Smoke")
	smoke.Color, smoke.Opacity, smoke.RiseVelocity, smoke.Size = GREEN, 0.08, 3, 2
	smoke.Parent = brew
	local fire = Instance.new("Fire")
	fire.Size, fire.Heat = 3, 2
	fire.Parent = part(m, "Fogon", at(5.2, 1.2, 0.6), Vector3.new(3, 0.4, 3), C(30, 20, 20), M.Slate)
	-- bobinas de Tesla con un rayo entre ellas (el cliente lo hace chisporrotear)
	local _, a0 = coil(m, -12, 4.4)
	local _, a1 = coil(m, 12, 4.4)
	local beam = Instance.new("Beam")
	beam.Name = "Rayo"
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Color = ColorSequence.new(C(220, 190, 255), C(140, 255, 255))
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Width0, beam.Width1 = 0.5, 0.5
	beam.Segments = 24
	beam.FaceCamera = true
	beam.Enabled = false
	beam.Parent = m
	counter(m, at(-5.5, 2.2, -5.4), Vector3.new(9, 2.4, 1.6), C(70, 80, 70), "Craft", "Assembly Lab")
	sign(m, at(0, 18.4, 5.8), 18, 3.8, "ASSEMBLY LAB", C(190, 255, 120), C(60, 200, 90))
	marquee(m, Vector3.new(-13.4, 17.5, -6.8), Vector3.new(13.4, 17.5, -6.8), 1.2)
	for _, x in {-13.4, 13.4} do
		marquee(m, Vector3.new(x, 1.6, -7.3), Vector3.new(x, 16.4, -7.3), 1.2)
	end
	for _, x in {-8, 8} do
		part(m, "Cable", at(x, 15.9, -6.8), Vector3.new(0.1, 1.6, 0.1), C(20, 20, 20), M.Metal)
		local bulb = part(m, "Bombilla", at(x, 14.9, -6.8), Vector3.new(0.8, 1, 0.8), C(255, 240, 180), M.Neon, false, "Ball")
		light(bulb, C(255, 230, 170), 14, 1.4)
	end
	part(m, "Viga", at(0, 16.9, -6.8), Vector3.new(27, 0.6, 0.6), C(60, 60, 64), M.Metal, true)
	for _, x in {-13.4, 13.4} do
		part(m, "PosteViga", at(x, 8.7, -6.8), Vector3.new(0.6, 16.4, 0.6), C(60, 60, 64), M.Metal, true)
	end
	badge(m, 23, 4)
end

---------- Altar de fusión (donde estaba la ruleta, a la entrada de la calle) ----------
-- Un altar gótico: gradas de piedra, círculo de runas con pentagrama, el altar con una gran estrella flotante y tres
-- orbes (los colores de las estrellas: oro, diamante y mítico) que la rodean, pilares con cristales y braseros
-- violetas, y un rosetón de neón al fondo. El cliente (TiendasFX) hace girar la estrella y los orbes y late las runas.
local STAR_COLORS = {C(255, 200, 60), C(80, 230, 255), C(255, 90, 220)}
local function buildFuse(m)
	local PURPLE = C(170, 90, 255)
	stage(m, C(40, 34, 52), M.Slate, GOLD)
	part(m, "Grada", at(0, 1.25, 3), Vector3.new(17, 0.5, 10), C(56, 46, 70), M.Slate, true)
	part(m, "Grada", at(0, 1.75, 3.5), Vector3.new(12.5, 0.5, 8), C(66, 54, 82), M.Slate, true)
	for _, x in {-8.5, 8.5} do
		part(m, "GradaNeon", at(x, 1.26, -2.05), Vector3.new(0.1, 0.06, 0.1), GOLD, M.Neon)
	end
	part(m, "GradaBorde", at(0, 1.52, -2.02), Vector3.new(17, 0.06, 0.12), GOLD, M.Neon)
	part(m, "GradaBorde", at(0, 2.02, -0.52), Vector3.new(12.5, 0.06, 0.12), PURPLE, M.Neon)
	-- círculo de runas con pentagrama (late)
	local runes = model(m, "Runas")
	disc(runes, "RunaAro", 0, 2.03, 3.5, 7.6, 0.04, GOLD, M.Neon)
	disc(m, "RunaFondo", 0, 2.05, 3.5, 7, 0.04, C(30, 20, 44), M.Slate)
	disc(runes, "RunaAroInterior", 0, 2.07, 3.5, 6.2, 0.03, PURPLE, M.Neon)
	disc(m, "RunaFondo2", 0, 2.08, 3.5, 5.9, 0.03, C(30, 20, 44), M.Slate)
	local pts = {}
	for i = 0, 4 do
		local a = math.rad(i * 72)
		pts[i + 1] = Vector3.new(math.sin(a) * 2.9, 2.1, 3.5 - math.cos(a) * 2.9)
	end
	for i = 1, 5 do
		strut(runes, "RunaLinea", pts[i], pts[(i + 1) % 5 + 1], 0.12, GOLD, M.Neon)
	end
	-- altar
	disc(m, "Altar", 0, 2.9, 3.5, 3, 1.8, C(70, 60, 86), M.Marble, true)
	disc(m, "AltarTapa", 0, 3.9, 3.5, 3.5, 0.25, GOLD, M.Metal)
	disc(m, "AltarLuz", 0, 4.05, 3.5, 2.4, 0.06, GOLD, M.Neon)
	-- estrella flotante (dos cubos cruzados = estrella de 8 puntas) y tres orbes
	local starModel = model(m, "EstrellaFusion")
	local s1 = part(starModel, "Estrella", at(0, 8.2, 3.5) * CFrame.Angles(0, 0, math.pi / 4), Vector3.new(3.4, 3.4, 1.1), C(255, 176, 30), M.Neon)
	part(starModel, "Estrella2", at(0, 8.2, 3.5), Vector3.new(3.4, 3.4, 1.1), C(255, 150, 20), M.Neon)
	local core = part(starModel, "EstrellaNucleo", at(0, 8.2, 3.5), Vector3.one * 1.5, C(255, 240, 170), M.Neon, false, "Ball")
	starModel.PrimaryPart = s1
	starModel:SetAttribute("Base", O * at(0, 8.2, 3.5))
	light(core, GOLD, 24, 3)
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(GOLD, C(255, 90, 220))
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0)})
	pe.Lifetime = NumberRange.new(1, 1.8)
	pe.Rate = 20
	pe.Speed = NumberRange.new(1.5, 3)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Parent = core
	for i, col in STAR_COLORS do
		local orb = part(starModel, "Orbe", at(0, 8.2, 3.5), Vector3.one * 0.9, col, M.Neon, false, "Ball")
		orb:SetAttribute("Orbit", i)
		light(orb, col, 8, 1.5)
		local tr = Instance.new("Trail")
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = Vector3.new(0, 0.3, 0), Vector3.new(0, -0.3, 0)
		a0.Parent, a1.Parent = orb, orb
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Color = ColorSequence.new(col)
		tr.LightEmission = 1
		tr.Lifetime = 0.5
		tr.Transparency = NumberSequence.new(0.2, 1)
		tr.Parent = orb
	end
	-- fondo: muro de piedra con rosetón de neón
	part(m, "Retablo", at(0, 8.5, 7.4), Vector3.new(24, 15, 1), C(30, 22, 40), M.Slate, true)
	part(m, "RetabloCornisa", at(0, 16.2, 7.2), Vector3.new(25, 0.8, 1.6), C(60, 48, 76), M.Slate)
	-- frontón gótico con pináculo encima del muro
	for side = -1, 1, 2 do
		-- (la cuña sube hacia su +Z: cada mitad, hacia el centro)
		part(m, "Fronton", at(side * 3, 18.9, 7.4) * CFrame.Angles(0, -side * math.pi / 2, 0), Vector3.new(1, 4.6, 6), C(30, 22, 40), M.Slate, false, "Wedge")
		part(m, "FrontonNeon", at(side * 3, 19, 6.85) * CFrame.Angles(0, 0, -side * math.atan2(4.6, 6)), Vector3.new(7.4, 0.15, 0.1), GOLD, M.Neon)
	end
	part(m, "Pinaculo", at(0, 21.9, 7.4), Vector3.new(0.5, 1.6, 0.5), GOLD, M.Metal)
	part(m, "PinaculoBola", at(0, 23, 7.4), Vector3.one * 0.9, C(255, 90, 220), M.Neon, false, "Ball")
	local rose = part(m, "Roseton", at(0, 10, 6.85) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(0.12, 7.2, 7.2), C(255, 90, 220), M.Neon, false, "Cylinder")
	light(rose, C(255, 90, 220), 12, 0.6)
	part(m, "RosetonFondo", at(0, 10, 6.75) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(0.12, 6.4, 6.4), C(26, 14, 36), M.Slate, false, "Cylinder")
	for k = 0, 7 do
		local a = math.rad(k * 22.5)
		part(m, "RosetonRadio", at(0, 10, 6.65) * CFrame.Angles(0, 0, a), Vector3.new(0.18, 6.2, 0.1), C(255, 150, 230), M.Neon)
	end
	-- pilares con cristal y brasero
	for i, x in {-9.5, 9.5} do
		part(m, "Pilar", at(x, 6.2, 5.6), Vector3.new(2.2, 10.4, 2.2), C(70, 60, 86), M.Slate, true)
		part(m, "PilarBase", at(x, 1.6, 5.6), Vector3.new(2.8, 1.2, 2.8), C(56, 46, 70), M.Slate, true)
		part(m, "Capitel", at(x, 11.7, 5.6), Vector3.new(2.9, 0.8, 2.9), C(84, 72, 100), M.Slate)
		local crystal = part(m, "Cristal", at(x, 13.4, 5.6) * CFrame.Angles(math.rad(45), 0, math.rad(35.26)), Vector3.one * 1.8, STAR_COLORS[i], M.Neon)
		crystal:SetAttribute("Spin", i == 1 and 1 or -1)
		light(crystal, STAR_COLORS[i], 16, 2)
		part(m, "Estandarte", at(x, 7.5, 4.45), Vector3.new(1.8, 5.5, 0.1), C(90, 30, 110), M.Fabric)
		part(m, "EstandarteOro", at(x, 7.5, 4.39), Vector3.new(0.3, 5.5, 0.05), GOLD, M.Metal)
	end
	-- velas por las gradas
	local rng = Random.new(5)
	for _, p in {{-5.6, 0.2}, {-4.4, -0.2}, {5.4, 0.1}, {4.6, -0.3}, {-7.6, -1.4}, {7.4, -1.5}, {-6.6, 6.4}, {6.6, 6.4}} do
		local h = rng:NextNumber(0.6, 1.3)
		local y = p[2] > -0.5 and 2 or 1.5
		local c = part(m, "Vela", at(p[1], y + h / 2, p[2]), Vector3.new(0.35, h, 0.35), C(235, 225, 205), M.SmoothPlastic)
		local f = Instance.new("Fire")
		f.Size, f.Heat, f.Color, f.SecondaryColor = 1, 3, C(255, 170, 60), C(255, 230, 150)
		f.Parent = c
	end
	counter(m, at(0, 2.2, -5.4), Vector3.new(8, 2.4, 1.6), C(70, 44, 96), "Fuse", "Fusion Altar")
	sign(m, at(0, 15.1, -6.2), 15, 3.2, "FUSION ALTAR", C(255, 230, 130), C(255, 90, 220), Enum.Font.Creepster)
	marquee(m, Vector3.new(-13.4, 17.5, -6.8), Vector3.new(13.4, 17.5, -6.8), 1.2)
	for _, x in {-13.4, 13.4} do
		marquee(m, Vector3.new(x, 1.6, -7.3), Vector3.new(x, 16.4, -7.3), 1.2)
		part(m, "PosteViga", at(x, 8.7, -6.8), Vector3.new(0.6, 16.4, 0.6), C(60, 50, 70), M.Metal, true)
	end
	part(m, "Viga", at(0, 16.9, -6.8), Vector3.new(27, 0.6, 0.6), C(60, 50, 70), M.Metal, true)
	for _, x in {-10.5, 10.5} do
		part(m, "Cadena", at(x, 15.9, -6.8), Vector3.new(0.1, 1.6, 0.1), C(20, 20, 20), M.Metal)
		local l = part(m, "Farolillo", at(x, 14.9, -6.8), Vector3.new(0.9, 1.2, 0.9), PURPLE, M.Neon, false, "Ball")
		light(l, PURPLE, 14, 1.4)
	end
	torch(m, -13, -6.6, PURPLE)
	torch(m, 13, -6.6, PURPLE)
	badge(m, 24, 5)
end

---------- Todo ----------
local BUILDERS = {wheel = buildWheelZone, market = buildMarket, gems = buildGems, lab = buildLab, fuse = buildFuse}
local NAMES = {wheel = "Ruleta", market = "Mercado", gems = "Gemas", lab = "Laboratorio", fuse = "Fusion"}

-- Saca del sitio el decorado que estorba (se guarda en ServerStorage.DecoradoQuitado, por si acaso)
local function clearSpot(cf)
	local keep = game:GetService("ServerStorage"):FindFirstChild("DecoradoQuitado")
	if not keep then
		keep = Instance.new("Folder")
		keep.Name = "DecoradoQuitado"
		keep.Parent = game:GetService("ServerStorage")
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {workspace.Mapa.Decorado}
	for _, p in workspace:GetPartBoundsInBox(cf * CFrame.new(0, 6, -2), Vector3.new(30, 10, 22), params) do
		local m = p:FindFirstAncestorWhichIsA("Model")
		if m and m.Parent and m:IsDescendantOf(workspace.Mapa.Decorado) and m.Name ~= "IndicadorTD" then
			m.Parent = keep
		end
	end
end

-- Bajo el puesto, tierra en vez de hierba: si no, la hierba del terreno atraviesa el suelo
local function noGrass(cf, r)
	local c = cf.Position
	r = r or 17
	local region = Region3.new(c - Vector3.new(r, 4, r), c + Vector3.new(r, 4, r)):ExpandToGrid(4)
	for _, mat in {M.Grass, M.LeafyGrass} do
		workspace.Terrain:ReplaceMaterial(region, 4, mat, M.Ground)
	end
end

function B.build()
	local folder = workspace.Mapa:FindFirstChild("Tiendas")
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Tiendas"
	-- la capilla (y lo que la rodeaba dentro de la plazoleta) deja sitio a la zona de la ruleta
	local capilla = workspace.Mapa.Decorado:FindFirstChild("Capilla")
	if capilla then
		local keep = game:GetService("ServerStorage"):FindFirstChild("DecoradoQuitado") or Instance.new("Folder")
		keep.Name = "DecoradoQuitado"
		keep.Parent = game:GetService("ServerStorage")
		local c = B.SPOTS.wheel.Position
		for _, m in capilla:GetChildren() do
			local p = m:GetPivot().Position
			if m.Name == "Capilla" or (math.abs(p.Z - c.Z) < B.ZONE_R + 6 and p.X > c.X - B.ZONE_R - 4) then
				m.Parent = keep
			end
		end
	end
	for kind, cf in B.SPOTS do
		clearSpot(cf)
		noGrass(cf, kind == "wheel" and B.ZONE_R + 4 or 17)
		O = cf
		local m = model(folder, NAMES[kind])
		m:SetAttribute("Kind", kind)
		BUILDERS[kind](m)
		CollectionService:AddTag(m, "Tienda")
	end
	folder.Parent = workspace.Mapa
	return folder
end

return B
