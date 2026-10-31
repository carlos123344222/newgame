-- Librería para montar los mapas del Tower Defense (CursedCastle, WitchBayou, FrozenPeak, FallenCathedral y los
-- nuevos). Cada mapa es un módulo de ServerStorage que hace L.new(id, origen) y va añadiendo terreno, camino,
-- edificios y decoración. Coordenadas locales: x, z respecto al origen del mapa (el suelo está en y = 0 local, = 2 en
-- el mundo). Al acabar, L.store(id) lo saca del juego a ServerStorage.MapasTD (modelo + terreno) para que solo se
-- cargue en los servidores de partida (TDMaps). Cada mapa ocupa una celda de 900 x 800 studs alrededor de su origen.
-- Estructura que esperan TDMaps/TDMatch/TowerDefense: atributos Origin, Bounds, Spawn, PathWidth (y EnemySpawn,
-- Goal), carpetas Camino (puntos 1..N), MapaTDS.Camino / MapaTDS.Suelo (suelo válido para colocar), ReturnPortal.
local ServerStorage = game:GetService("ServerStorage")
local Terrain = workspace.Terrain

local L = {}
L.__index = L

local V, CF, ANG = Vector3.new, CFrame.new, CFrame.Angles
local rad = math.rad
L.V, L.CF, L.ANG = V, CF, ANG

local KITS = {"MapKit", "ZombieHollowKit", "CarnivalKit", "CalabazasKit", "LobbyPlazaKit", "GenKit", "MapasNuevosKit"}

function L.new(id, origin, opts)
	local self = setmetatable({}, L)
	self.id = id
	self.O = origin
	self.rng = Random.new(opts and opts.seed or 7)
	local old = workspace:FindFirstChild(id)
	if old then
		old:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = id
	m.WorldPivot = origin
	self.model = m
	local function folder(name, parent)
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent or m
		return f
	end
	self.F = {}
	self.F.Camino = folder("Camino")
	self.F.Limites = folder("Limites")
	self.F.Edificios = folder("Edificios")
	local tds = folder("MapaTDS")
	self.F.TDS = tds
	self.F.Ruta = folder("Camino", tds)
	self.F.Suelo = folder("Suelo", tds)
	self.F.Deco = folder("Decoracion", tds)
	self.F.Rocas = folder("Rocas", tds)
	self.F.Flechas = folder("Flechas", tds)
	self.F.Arq = folder("Arquitectura", tds)
	m:SetAttribute("Origin", origin)
	m:SetAttribute("PathWidth", opts and opts.width or 7)
	self.width = opts and opts.width or 7
	m.Parent = workspace
	self.pending, self.count = {}, 0
	self.avoid = {} -- círculos donde no se pone decoración (x, z, r)
	return self
end

---------- Coordenadas ----------
function L:w(x, y, z)
	return (self.O * CF(x, y or 0, z)).Position
end
function L:cf(x, y, z, yaw, pitch, roll)
	return self.O * CF(x, y or 0, z) * ANG(rad(pitch or 0), rad(yaw or 0), rad(roll or 0))
end
function L:loc(pos)
	return self.O:PointToObjectSpace(pos)
end

---------- Piezas (se añaden por tandas, con task.wait entre tandas) ----------
function L:flush()
	for _, e in self.pending do
		e[1].Parent = e[2]
	end
	table.clear(self.pending)
	task.wait()
end

function L:add(inst, parent)
	table.insert(self.pending, {inst, parent or self.F.Arq})
	self.count += 1
	if #self.pending >= 120 then
		self:flush()
	end
	return inst
end

-- Pieza anclada. props: Size, CFrame (mundo), Color, Material... Por defecto colisiona y da sombra.
function L:part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanTouch = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		p[k] = v
	end
	return self:add(p, parent)
end

-- Pieza decorativa sin colisión (no estorba al colocar tropas)
function L:deco(props, parent)
	props.CanCollide = false
	props.CanQuery = props.CanQuery or false
	return self:part(props, parent)
end

function L:wedge(props, parent)
	local p = Instance.new("WedgePart")
	p.Anchored, p.CanTouch = true, false
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		p[k] = v
	end
	return self:add(p, parent)
end

function L:light(parent, color, range, bright, shadows)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = color, range, bright, shadows == true
	l.Parent = parent
	return l
end

function L:fire(parent, size, color, sec)
	local f = Instance.new("Fire")
	f.Size, f.Heat = size, 7
	f.Color = color or Color3.fromRGB(255, 130, 40)
	f.SecondaryColor = sec or Color3.fromRGB(255, 220, 110)
	f.Parent = parent
	return f
end

function L:emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0
	for k, v in props do
		e[k] = v
	end
	e.Parent = parent
	return e
end

---------- Kit (mallas de los otros mapas) ----------
function L.kitModel(name)
	for _, k in KITS do
		local f = ServerStorage:FindFirstChild(k)
		local m = f and f:FindFirstChild(name)
		if m then
			return m
		end
	end
	return nil
end

-- Altura del suelo (terreno o Suelo) en x, z locales
function L:groundY(x, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {Terrain, self.F.Suelo}
	local top = self:w(x, 120, z)
	local hit = workspace:Raycast(top, V(0, -260, 0), params)
	return hit and self:loc(hit.Position).Y or 0
end

-- Clona un modelo del kit en x, z (sobre el suelo), con giro y escala
function L:kit(name, x, z, yaw, scale, parent, y, opts)
	local src = L.kitModel(name)
	if not src then
		warn("MapasNuevos: falta el kit " .. tostring(name))
		return nil
	end
	local m = src:Clone()
	if scale and math.abs(scale - 1) > 1e-3 then
		m:ScaleTo(m:GetScale() * scale)
	end
	local gy = y or self:groundY(x, z)
	-- apoyado: la base del modelo en el suelo
	local cf, size = m:GetBoundingBox()
	local pivot = m:GetPivot()
	local bottom = cf.Position.Y - size.Y / 2
	local lift = pivot.Position.Y - bottom
	m:PivotTo(self:cf(x, gy + lift - (opts and opts.sink or 0.15), z, yaw or 0) * (pivot.Rotation * pivot.Rotation:Inverse()))
	if opts and (opts.noCollide or opts.color or opts.lightColor) then
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				if opts.noCollide then
					d.CanCollide = false
				end
				if opts.color and d.Material ~= Enum.Material.Neon then
					d.Color = opts.color
				end
				if opts.lightColor and d.Material == Enum.Material.Neon then
					d.Color = opts.lightColor
				end
			elseif d:IsA("Light") and opts.lightColor then
				d.Color = opts.lightColor
			end
		end
	end
	return self:add(m, parent or self.F.Deco)
end

---------- Camino ----------
-- Catmull-Rom por los puntos de control {x, z} y remuestreado cada 'spacing' studs
local function catmull(p0, p1, p2, p3, t)
	local t2, t3 = t * t, t * t * t
	return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end

function L.smooth(ctrl, spacing)
	local pts = {}
	for _, c in ctrl do
		table.insert(pts, Vector2.new(c[1], c[2]))
	end
	local dense = {}
	for i = 1, #pts - 1 do
		local p0 = pts[math.max(1, i - 1)]
		local p1, p2 = pts[i], pts[i + 1]
		local p3 = pts[math.min(#pts, i + 2)]
		for k = 0, 19 do
			table.insert(dense, catmull(p0, p1, p2, p3, k / 20))
		end
	end
	table.insert(dense, pts[#pts])
	-- remuestreo por longitud
	local out = {dense[1]}
	local acc = 0
	for i = 2, #dense do
		local a, b = dense[i - 1], dense[i]
		local d = (b - a).Magnitude
		while acc + d >= spacing do
			local k = (spacing - acc) / d
			a = a:Lerp(b, k)
			d = (b - a).Magnitude
			table.insert(out, a)
			acc = 0
		end
		acc += d
	end
	if (out[#out] - pts[#pts]).Magnitude > spacing * 0.35 then
		table.insert(out, pts[#pts])
	else
		out[#out] = pts[#pts]
	end
	return out
end

-- Distancia (en planta) de x, z al camino
function L:distToPath(x, z)
	local q = Vector2.new(x, z)
	local best = math.huge
	local pts = self.pathPts or {}
	for i = 2, #pts do
		local a, b = pts[i - 1], pts[i]
		local ab = b - a
		local k = math.clamp((q - a):Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
		best = math.min(best, (a + ab * k - q).Magnitude)
	end
	return best
end

-- ¿Se puede decorar aquí? (lejos del camino y de las zonas reservadas)
function L:free(x, z, gap)
	if self:distToPath(x, z) < self.width / 2 + (gap or 6) then
		return false
	end
	for _, a in self.avoid do
		if (Vector2.new(x, z) - Vector2.new(a[1], a[2])).Magnitude < a[3] then
			return false
		end
	end
	return true
end

-- style: {mat, color, edgeMat, edgeColor, edge (ancho extra del borde), y}
function L:path(ctrl, style)
	style = style or {}
	local pts = L.smooth(ctrl, style.spacing or 9)
	self.pathPts = pts
	local W = self.width
	local E = W + (style.edge or 1.8)
	local mat, col = style.mat or Enum.Material.Ground, style.color or Color3.fromRGB(122, 86, 58)
	local emat, ecol = style.edgeMat or Enum.Material.Cobblestone, style.edgeColor or Color3.fromRGB(80, 72, 98)
	local function gy(p)
		return style.flat and 0 or self:groundY(p.X, p.Y)
	end
	for i, p in pts do
		local y = gy(p)
		local pt = Instance.new("Part")
		pt.Name = tostring(i)
		pt.Anchored, pt.CanCollide, pt.CanQuery, pt.CanTouch, pt.CastShadow = true, false, false, false, false
		pt.Transparency = 1
		pt.Size = Vector3.one
		pt.CFrame = self:cf(p.X, y + 0.5, p.Y)
		self:add(pt, self.F.Camino)
	end
	local ROUTE = self.F.Ruta
	-- sin hierba alta bajo el camino (las briznas del terreno asomarían entre las piedras)
	local under = style.under or Enum.Material.Ground
	for _, p in pts do
		for _, from in {Enum.Material.Grass, Enum.Material.LeafyGrass} do
			self:paint(p.X, p.Y, W / 2 + 1, from, under)
		end
	end
	for i, p in pts do
		local y = gy(p)
		-- disco en cada punto (redondea las curvas)
		self:part({Name = "Tierra", Shape = Enum.PartType.Cylinder, Size = V(0.4, W, W), CFrame = self:cf(p.X, y + 0.1, p.Y, 0, 0, 90), Material = mat, Color = col, CanCollide = false, CastShadow = false, CanTouch = true}, ROUTE)
		self:part({Name = "Borde", Shape = Enum.PartType.Cylinder, Size = V(0.4, E, E), CFrame = self:cf(p.X, y, p.Y, 0, 0, 90), Material = emat, Color = ecol, CanCollide = false, CastShadow = false, CanTouch = true}, ROUTE)
		local q = pts[i + 1]
		if q then
			local yq = gy(q)
			local a, b = self:w(p.X, y, p.Y), self:w(q.X, yq, q.Y)
			local mid = (a + b) / 2
			local len = (b - a).Magnitude
			local look = CFrame.lookAt(mid, b)
			self:part({Name = "Tierra", Size = V(W, 0.4, len), CFrame = look * CF(0, 0.1, 0), Material = mat, Color = col, CanCollide = false, CastShadow = false, CanTouch = true}, ROUTE)
			self:part({Name = "Borde", Size = V(E, 0.4, len), CFrame = look, Material = emat, Color = ecol, CanCollide = false, CastShadow = false, CanTouch = true}, ROUTE)
		end
	end
	local first, last = pts[1], pts[#pts]
	self.model:SetAttribute("EnemySpawn", self:cf(first.X, 1, first.Y))
	self.model:SetAttribute("Goal", self:cf(last.X, 0, last.Y))
	return pts
end

-- Flechas brillantes en el suelo, cada 'every' puntos, apuntando hacia dónde va el camino
function L:arrows(every, color)
	local pts = self.pathPts
	for i = every, #pts - 2, every do
		local p, q = pts[i], pts[i + 1]
		local y = self:groundY(p.X, p.Y)
		local a, b = self:w(p.X, y + 0.36, p.Y), self:w(q.X, y + 0.36, q.Y)
		local look = CFrame.lookAt(a, b)
		for s = -1, 1, 2 do
			self:deco({Name = "Flechas", Size = V(3.4, 0.2, 0.9), CFrame = look * CF(s * 0.95, 0, 0.4) * ANG(0, s * rad(40), 0), Material = Enum.Material.Neon, Color = color or Color3.fromRGB(255, 170, 60), Transparency = 0.15, CastShadow = false}, self.F.Flechas)
		end
	end
end

---------- Terreno ----------
function L:fillBlock(x, y, z, sx, sy, sz, mat, yaw)
	Terrain:FillBlock(self:cf(x, y, z, yaw or 0), V(sx, sy, sz), mat)
end
function L:fillBall(x, y, z, r, mat)
	Terrain:FillBall(self:w(x, y, z), r, mat)
end
function L:fillCyl(x, y, z, h, r, mat)
	Terrain:FillCylinder(self:cf(x, y, z), h, r, mat)
end
-- Suelo base: una losa de terreno con la superficie en y = 0 local. (El terreno va en celdas de 4 studs: llenas hasta
-- y = 0 del mundo, la superficie se dibuja en y = 2, que es el suelo de los mapas; por eso la losa acaba en -2 local.)
function L:ground(sx, sz, mat, depth)
	depth = depth or 16
	self:fillBlock(0, -2 - depth / 2, 0, sx, depth, sz, mat)
end
-- Colina: varias bolas aplastadas
function L:hill(x, z, r, h, mat, cap)
	local n = math.max(2, math.floor(h / (r * 0.35)))
	for k = 0, n do
		local rr = r * (1 - k / (n + 1.2))
		self:fillBall(x, -rr * 0.55 + k * (h / n), z, rr, k == n and (cap or mat) or mat)
	end
end
-- Pinta el material del terreno de la superficie en un círculo (sin cambiar la forma)
function L:paint(x, z, r, from, to)
	local c = self:w(x, 0, z)
	local region = Region3.new(c - V(r, 6, r), c + V(r, 2, r)):ExpandToGrid(4)
	Terrain:ReplaceMaterial(region, 4, from, to)
end

---------- Agua ----------
-- Estanque redondo: hueco en el terreno, fondo de barro y una lámina de agua (pieza, como en Pumpkin Hollow).
-- El agua bloquea colocar tropas encima (CanQuery) y no se puede pisar (CanCollide false: se cae al barro).
function L:pond(x, z, r, color, depth)
	depth = depth or 6
	self:fillCyl(x, -depth / 2, z, depth + 2, r, Enum.Material.Air)
	self:fillCyl(x, -depth - 0.5, z, 2, r + 1, Enum.Material.Mud)
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		self:fillBall(x + math.cos(a) * r, -1.5, z + math.sin(a) * r, 3.4, Enum.Material.Mud)
	end
	local w = self:part({Name = "Agua", Shape = Enum.PartType.Cylinder, Size = V(0.4, r * 2 + 2, r * 2 + 2), CFrame = self:cf(x, -1.4, z, 0, 0, 90), Material = Enum.Material.SmoothPlastic, Color = color, Transparency = 0.1, Reflectance = 0.08, CanCollide = false, CastShadow = false}, self.F.TDS)
	self.ponds = self.ponds or {}
	table.insert(self.ponds, {x, z, r})
	return w
end

function L:inPond(x, z, margin)
	for _, p in self.ponds or {} do
		if (Vector2.new(x - p[1], z - p[2])).Magnitude < p[3] + (margin or 0) then
			return true
		end
	end
	return false
end

-- Pasarela de madera bajo el camino donde cruza el agua (para que los cazafantasmas puedan andar), con postes
function L:decks(color, postColor)
	local pts = self.pathPts
	local W = self.width
	for i = 1, #pts - 1 do
		local p, q = pts[i], pts[i + 1]
		local m = (p + q) / 2
		if self:inPond(m.X, m.Y, 4) then
			local a, b = self:w(p.X, 0, p.Y), self:w(q.X, 0, q.Y)
			local look = CFrame.lookAt((a + b) / 2, b)
			local len = (b - a).Magnitude
			self:part({Name = "Pasarela", Size = V(W + 2, 0.8, len + 1.5), CFrame = look * CF(0, -0.35, 0), Material = Enum.Material.WoodPlanks, Color = color}, self.F.Suelo)
			for s = -1, 1, 2 do
				self:part({Name = "Poste", Size = V(0.8, 6, 0.8), CFrame = look * CF(s * (W / 2 + 1.2), -2, 0), Material = Enum.Material.Wood, Color = postColor})
				self:part({Name = "Barandilla", Size = V(0.4, 0.4, len + 1), CFrame = look * CF(s * (W / 2 + 1.2), 1.6, 0), Material = Enum.Material.Wood, Color = postColor, CanCollide = false})
				self:part({Name = "Pilar", Size = V(0.5, 2.6, 0.5), CFrame = look * CF(s * (W / 2 + 1.2), 0.6, 0), Material = Enum.Material.Wood, Color = postColor, CanCollide = false})
			end
		end
	end
end

-- Juncos y espadañas (sin colisión)
function L:reeds(x, z, n, rng)
	local y = self:groundY(x, z)
	for k = 1, n do
		local ox, oz = rng:NextNumber(-2.5, 2.5), rng:NextNumber(-2.5, 2.5)
		local h = rng:NextNumber(3, 6)
		local lean = CFrame.Angles(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.25, 0.25))
		local base = self:cf(x + ox, y, z + oz) * lean
		self:deco({Name = "Junco", Size = V(0.18, h, 0.18), CFrame = base * CF(0, h / 2, 0), Material = Enum.Material.Grass, Color = Color3.fromRGB(60, 96, 52)})
		if k % 2 == 0 then
			self:deco({Name = "Espadana", Shape = Enum.PartType.Cylinder, Size = V(0.9, 0.36, 0.36), CFrame = base * CF(0, h - 0.6, 0) * ANG(0, 0, rad(90)), Material = Enum.Material.Fabric, Color = Color3.fromRGB(96, 64, 40)})
		end
	end
end

-- Nenúfares sobre el agua de un estanque (alguno con flor)
function L:lilies(px, pz, r, n, rng)
	for k = 1, n do
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(2, r - 1)
		local x, z = px + math.cos(a) * d, pz + math.sin(a) * d
		if self:distToPath(x, z) > self.width / 2 + 2 then
			local s = rng:NextNumber(1.6, 3)
			self:deco({Name = "Nenufar", Shape = Enum.PartType.Cylinder, Size = V(0.12, s, s), CFrame = self:cf(x, -1.1, z, 0, 0, 90), Material = Enum.Material.Grass, Color = Color3.fromRGB(56, 110, 60)})
			if rng:NextNumber() < 0.3 then
				local f = self:deco({Name = "Flor", Shape = Enum.PartType.Ball, Size = V(0.7, 0.5, 0.7), CFrame = self:cf(x, -0.85, z), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 140, 210)})
			end
		end
	end
end

---------- Arquitectura ----------
-- Muro de a(x, z) a b(x, z): altura h, grosor t, almenas arriba
function L:wall(a, b, h, t, mat, color, opts)
	opts = opts or {}
	local y0 = opts.y or 0
	local pa, pb = self:w(a[1], y0, a[2]), self:w(b[1], y0, b[2])
	local len = (pb - pa).Magnitude
	local mid = (pa + pb) / 2
	local look = CFrame.lookAt(mid, pb)
	local parent = opts.parent or self.F.Arq
	self:part({Name = "Muro", Size = V(t, h, len), CFrame = look * CF(0, h / 2, 0), Material = mat, Color = color}, parent)
	-- zócalo y cornisa
	self:part({Name = "Zocalo", Size = V(t + 1, 2, len + 0.6), CFrame = look * CF(0, 1, 0), Material = mat, Color = color:Lerp(Color3.new(0, 0, 0), 0.18)}, parent)
	self:part({Name = "Cornisa", Size = V(t + 1, 0.8, len + 0.6), CFrame = look * CF(0, h + 0.4, 0), Material = mat, Color = color:Lerp(Color3.new(1, 1, 1), 0.08)}, parent)
	if opts.crenels ~= false then
		local step = opts.step or 3.2
		local n = math.floor(len / step)
		for k = 0, n - 1 do
			if k % 2 == 0 then
				local z = -len / 2 + (k + 0.5) * (len / n)
				for s = -1, 1, 2 do
					self:part({Name = "Almena", Size = V(0.9, 2, len / n), CFrame = look * CF(s * (t / 2 + 0.05), h + 1.8, z), Material = mat, Color = color}, parent)
				end
			end
		end
	end
	-- antorchas en la cara exterior (lado +x del muro mirando de a a b)
	if opts.torches then
		local n = math.max(1, math.floor(len / opts.torches))
		for k = 1, n do
			local z = -len / 2 + k * len / (n + 1)
			for _, s in opts.bothSides and {-1, 1} or {opts.side or 1} do
				self:torch(look * CF(s * (t / 2 + 0.4), h * 0.55, z) * ANG(0, s > 0 and rad(90) or rad(-90), 0))
			end
		end
	end
	return look, len
end

-- Antorcha de pared: soporte, palo y fuego (cf: delante = hacia fuera)
function L:torch(cf, color)
	self:deco({Name = "Soporte", Size = V(0.3, 0.3, 0.9), CFrame = cf * CF(0, 0, 0.1), Material = Enum.Material.Metal, Color = Color3.fromRGB(40, 36, 44)})
	local stick = self:deco({Name = "Antorcha", Size = V(0.35, 1.6, 0.35), CFrame = cf * CF(0, 0.6, -0.45) * ANG(rad(-20), 0, 0), Material = Enum.Material.Wood, Color = Color3.fromRGB(70, 46, 30)})
	local flame = self:deco({Name = "Llama", Size = V(0.5, 0.5, 0.5), CFrame = cf * CF(0, 1.55, -0.75), Material = Enum.Material.Neon, Color = color or Color3.fromRGB(255, 150, 50), Transparency = 0.3, Shape = Enum.PartType.Ball})
	self:fire(flame, 2.2, color)
	local l = self:light(flame, color or Color3.fromRGB(255, 160, 70), 16, 1.6)
	l:AddTag("Flicker")
	return stick
end

-- Torre redonda: cuerpo, bandas, almenas, tejado cónico escalonado y aguja; ventanas que brillan
function L:tower(x, z, r, h, opts)
	opts = opts or {}
	local mat, col = opts.mat or Enum.Material.Cobblestone, opts.color or Color3.fromRGB(104, 98, 126)
	local roof = opts.roof or Color3.fromRGB(44, 40, 78)
	local y0 = opts.y or 0
	local parent = opts.parent or self.F.Arq
	local base = self:cf(x, y0, z)
	self:part({Name = "Torre", Shape = Enum.PartType.Cylinder, Size = V(h, r * 2, r * 2), CFrame = base * CF(0, h / 2, 0) * ANG(0, 0, rad(90)), Material = mat, Color = col}, parent)
	self:part({Name = "Base", Shape = Enum.PartType.Cylinder, Size = V(3, r * 2 + 1.6, r * 2 + 1.6), CFrame = base * CF(0, 1.5, 0) * ANG(0, 0, rad(90)), Material = mat, Color = col:Lerp(Color3.new(0, 0, 0), 0.2)}, parent)
	for _, by in {h * 0.45, h - 0.4} do
		self:part({Name = "Banda", Shape = Enum.PartType.Cylinder, Size = V(0.9, r * 2 + 0.8, r * 2 + 0.8), CFrame = base * CF(0, by, 0) * ANG(0, 0, rad(90)), Material = mat, Color = col:Lerp(Color3.new(1, 1, 1), 0.1)}, parent)
	end
	if opts.crenels ~= false then
		local n = math.max(8, math.floor(r * 2.2))
		for k = 0, n - 1, 1 do
			if k % 2 == 0 then
				local a = k / n * math.pi * 2
				self:part({Name = "Almena", Size = V(1.6, 2, 1), CFrame = base * CF(math.cos(a) * (r + 0.1), h + 1, math.sin(a) * (r + 0.1)) * ANG(0, -a + math.pi / 2, 0), Material = mat, Color = col}, parent)
			end
		end
	end
	-- ventanas en saetera, iluminadas
	local wc = opts.window or Color3.fromRGB(255, 170, 70)
	for k = 0, (opts.windows or 3) - 1 do
		local a = rad((opts.windowYaw or 0) + k * 360 / (opts.windows or 3))
		for _, wy in {h * 0.3, h * 0.68} do
			local w = self:deco({Name = "Ventana", Size = V(1, 2.6, 0.3), CFrame = base * CF(math.sin(a) * (r - 0.05), wy, math.cos(a) * (r - 0.05)) * ANG(0, a, 0), Material = Enum.Material.Neon, Color = wc})
			if wy > h * 0.5 and k == 0 then
				self:light(w, wc, 12, 1.2)
			end
		end
	end
	if opts.cone ~= false then
		-- tejado escalonado (anillos cada vez más estrechos) y aguja
		local rh = opts.roofH or r * 2.2
		local steps = opts.steps or 10
		for k = 0, steps - 1 do
			local rr = (r + 1.2) * (1 - k / steps)
			self:part({Name = "Tejado", Shape = Enum.PartType.Cylinder, Size = V(rh / steps + 0.05, rr * 2, rr * 2), CFrame = base * CF(0, h + (opts.crenels == false and 0 or 0.4) + (k + 0.5) * rh / steps, 0) * ANG(0, 0, rad(90)), Material = Enum.Material.Slate, Color = roof}, parent)
		end
		self:part({Name = "Aguja", Size = V(0.4, 4, 0.4), CFrame = base * CF(0, h + rh + 2, 0), Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 56, 70)}, parent)
		if opts.flag then
			self:deco({Name = "Bandera", Size = V(0.1, 1.6, 2.6), CFrame = base * CF(0, h + rh + 3.2, 1.4), Material = Enum.Material.Fabric, Color = opts.flag})
		end
	end
	return base
end

-- Tejado a dos aguas de ancho w, fondo d, altura rh sobre y (cf de la base del tejado), con caballete
function L:gable(cf, w, d, rh, color, mat, parent, endColor, endMat)
	mat = mat or Enum.Material.Slate
	local slope = math.sqrt((w / 2) ^ 2 + rh ^ 2)
	local ang = math.atan2(rh, w / 2)
	for s = -1, 1, 2 do
		self:part({Name = "Tejado", Size = V(slope + 0.8, 0.5, d + 1.2), CFrame = cf * CF(s * w / 4, rh / 2, 0) * ANG(0, 0, -s * ang), Material = mat, Color = color}, parent)
	end
	self:part({Name = "Caballete", Size = V(0.7, 0.7, d + 1.4), CFrame = cf * CF(0, rh + 0.1, 0), Material = Enum.Material.Wood, Color = color:Lerp(Color3.new(0, 0, 0), 0.3)}, parent)
	-- hastiales (triángulos de las fachadas)
	for s = -1, 1, 2 do
		for side = -1, 1, 2 do
			self:wedge({Name = "Hastial", Size = V(0.4, rh, w / 2), CFrame = cf * CF(side * w / 4, rh / 2, s * (d / 2 - 0.2)) * ANG(0, -side * rad(90), 0), Material = endMat or Enum.Material.Plaster, Color = endColor or Color3.fromRGB(200, 184, 160)}, parent)
		end
	end
end

-- Casita de entramado (pueblo medieval): planta w x d, alto h, mirando a yaw
function L:cottage(x, z, yaw, w, d, h, opts)
	opts = opts or {}
	local y = opts.y or self:groundY(x, z)
	local base = self:cf(x, y, z, yaw)
	local parent = opts.parent or self.F.Arq
	local wall = opts.wall or Color3.fromRGB(214, 198, 168)
	local beam = opts.beam or Color3.fromRGB(70, 46, 32)
	local roof = opts.roof or Color3.fromRGB(96, 52, 44)
	self:part({Name = "Zocalo", Size = V(w + 0.6, 1.4, d + 0.6), CFrame = base * CF(0, 0.7, 0), Material = Enum.Material.Cobblestone, Color = Color3.fromRGB(110, 104, 120)}, parent)
	self:part({Name = "Casa", Size = V(w, h, d), CFrame = base * CF(0, 1.4 + h / 2, 0), Material = opts.wallMat or Enum.Material.Plaster, Color = wall}, parent)
	-- vigas del entramado en las 4 caras
	for _, f in opts.noBeams and {} or {{0, d / 2, 0, w}, {0, -d / 2, 0, w}, {w / 2, 0, 90, d}, {-w / 2, 0, 90, d}} do
		local face = base * CF(f[1], 0, f[2]) * ANG(0, rad(f[3]), 0)
		local len = f[4]
		for _, by in {1.6, 1.4 + h / 2, 1.2 + h} do
			self:deco({Name = "Viga", Size = V(len + 0.3, 0.45, 0.3), CFrame = face * CF(0, by, 0), Material = Enum.Material.Wood, Color = beam})
		end
		for k = 0, 3 do
			local bx = -len / 2 + k * len / 3
			self:deco({Name = "Viga", Size = V(0.45, h, 0.3), CFrame = face * CF(bx, 1.4 + h / 2, 0), Material = Enum.Material.Wood, Color = beam})
		end
		self:deco({Name = "Viga", Size = V(0.35, h * 0.55, 0.3), CFrame = face * CF(-len / 6, 1.4 + h * 0.5, 0) * ANG(0, 0, rad(38)), Material = Enum.Material.Wood, Color = beam})
	end
	-- puerta y ventanas con luz
	self:deco({Name = "Puerta", Size = V(2.4, 4.2, 0.4), CFrame = base * CF(0, 1.4 + 2.1, -d / 2 - 0.1), Material = Enum.Material.Wood, Color = Color3.fromRGB(80, 50, 34)})
	local lit = opts.lit ~= false
	for s = -1, 1, 2 do
		local win = self:deco({Name = "Ventana", Size = V(1.8, 1.8, 0.3), CFrame = base * CF(s * w / 3.2, 1.4 + h * 0.62, -d / 2 - 0.12), Material = lit and Enum.Material.Neon or Enum.Material.Glass, Color = lit and Color3.fromRGB(255, 190, 90) or Color3.fromRGB(40, 40, 60)})
		self:deco({Name = "Marco", Size = V(2.3, 0.3, 0.45), CFrame = base * CF(s * w / 3.2, 1.4 + h * 0.62 - 1.05, -d / 2 - 0.15), Material = Enum.Material.Wood, Color = beam})
		if lit and s == 1 then
			self:light(win, Color3.fromRGB(255, 180, 90), 14, 1.1)
		end
	end
	self:gable(base * CF(0, 1.4 + h, 0), w + 1, d, opts.roofH or w * 0.45, roof, opts.roofMat or Enum.Material.Slate, parent, wall, opts.wallMat)
	if opts.chimney ~= false then
		local ch = self:part({Name = "Chimenea", Size = V(1.6, 4.5, 1.6), CFrame = base * CF(w * 0.28, 1.4 + h + 2.2, d * 0.2), Material = Enum.Material.Brick, Color = Color3.fromRGB(120, 70, 60)}, parent)
		self:emitter(ch, {
			Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(120, 116, 130)), Rate = 1.5,
			Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(1.5, 2.5), SpreadAngle = Vector2.new(8, 8), EmissionDirection = Enum.NormalId.Top,
			Size = NumberSequence.new(1.2, 4), Transparency = NumberSequence.new(0.5, 1), LightEmission = 0,
		})
	end
	return base
end

-- Tienda de campaña (prisma triangular de dos cuñas) con rayas
function L:tent(x, z, yaw, w, d, h, colA, colB)
	local y = self:groundY(x, z)
	local base = self:cf(x, y, z, yaw)
	for s = -1, 1, 2 do
		local stripes = 4
		for k = 0, stripes - 1 do
			local sz = d / stripes
			self:wedge({Name = "Lona", Size = V(0.3, h, w / 2), CFrame = base * CF(s * w / 4, h / 2, -d / 2 + (k + 0.5) * sz) * ANG(0, -s * rad(90), 0), Material = Enum.Material.Fabric, Color = k % 2 == 0 and colA or colB}, nil)
			local last = self.pending[#self.pending]
			last[1].Size = V(sz, h, w / 2)
		end
	end
	self:part({Name = "Palo", Size = V(0.3, h + 1.4, 0.3), CFrame = base * CF(0, (h + 1.4) / 2, -d / 2 - 0.3), Material = Enum.Material.Wood, Color = Color3.fromRGB(80, 56, 36)})
	self:deco({Name = "Banderin", Size = V(0.08, 0.8, 1.4), CFrame = base * CF(0, h + 1, -d / 2 - 1), Material = Enum.Material.Fabric, Color = colA})
	self:deco({Name = "Entrada", Size = V(w * 0.45, h * 0.6, 0.2), CFrame = base * CF(0, h * 0.3, -d / 2 - 0.05), Material = Enum.Material.Fabric, Color = Color3.fromRGB(30, 22, 20)})
	return base
end

-- Hoguera: leños, piedras, fuego y luz
function L:campfire(x, z)
	local y = self:groundY(x, z)
	local base = self:cf(x, y, z)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		self:part({Name = "Piedra", Size = V(1, 0.7, 1.2), CFrame = base * CF(math.cos(a) * 1.8, 0.3, math.sin(a) * 1.8) * ANG(0, -a, 0), Material = Enum.Material.Slate, Color = Color3.fromRGB(90, 86, 96)})
	end
	for k = 0, 2 do
		self:deco({Name = "Leño", Shape = Enum.PartType.Cylinder, Size = V(2.6, 0.5, 0.5), CFrame = base * CF(0, 0.45, 0) * ANG(0, k * rad(60), rad(12)), Material = Enum.Material.Wood, Color = Color3.fromRGB(70, 44, 28)})
	end
	local f = self:deco({Name = "Fuego", Size = V(1, 1, 1), CFrame = base * CF(0, 1, 0), Transparency = 1})
	self:fire(f, 5)
	local l = self:light(f, Color3.fromRGB(255, 150, 60), 26, 2.2, false)
	l:AddTag("Flicker")
	self:emitter(f, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(Color3.fromRGB(255, 180, 80)), Rate = 6,
		Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(20, 20), EmissionDirection = Enum.NormalId.Top,
		Size = NumberSequence.new(0.3, 0), LightEmission = 1,
	})
end

-- Estandarte colgante (tela con borde y un emblema)
function L:banner(cf, w, h, color, emblem)
	self:deco({Name = "Barra", Size = V(w + 0.6, 0.3, 0.3), CFrame = cf, Material = Enum.Material.Metal, Color = Color3.fromRGB(50, 46, 56)})
	self:deco({Name = "Estandarte", Size = V(w, h, 0.12), CFrame = cf * CF(0, -h / 2, 0), Material = Enum.Material.Fabric, Color = color})
	self:deco({Name = "Borde", Size = V(w + 0.1, 0.35, 0.16), CFrame = cf * CF(0, -h + 0.15, 0), Material = Enum.Material.Fabric, Color = emblem or Color3.fromRGB(240, 196, 70)})
	if emblem then
		self:deco({Name = "Emblema", Shape = Enum.PartType.Ball, Size = V(w * 0.45, w * 0.45, 0.2), CFrame = cf * CF(0, -h * 0.45, -0.06), Material = Enum.Material.Neon, Color = emblem})
	end
end

---------- Efectos de ambiente ----------
-- Niebla baja y luciérnagas sobre todo el mapa (como NieblaTD / ChispasTD)
function L:ambience(sx, sz, fogColor, sparkColor, fogRate, sparkRate)
	local fog = self:deco({Name = "NieblaTD", Size = V(sx, 1, sz), CFrame = self:cf(0, 1, 0), Transparency = 1}, self.F.TDS)
	self:emitter(fog, {
		Name = "Niebla", Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(fogColor), Rate = fogRate or 4,
		Lifetime = NumberRange.new(10, 16), Speed = NumberRange.new(0.2, 0.8), SpreadAngle = Vector2.new(180, 10), LightEmission = 0.3,
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(1, 16)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.82), NumberSequenceKeypoint.new(0.7, 0.85), NumberSequenceKeypoint.new(1, 1)}),
	})
	local sp = self:deco({Name = "ChispasTD", Size = V(sx, 8, sz), CFrame = self:cf(0, 5, 0), Transparency = 1}, self.F.TDS)
	self:emitter(sp, {
		Name = "Luciernagas", Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(sparkColor), Rate = sparkRate or 4,
		Lifetime = NumberRange.new(5, 9), Speed = NumberRange.new(0.2, 0.8), SpreadAngle = Vector2.new(180, 180), LightEmission = 1,
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.32), NumberSequenceKeypoint.new(0.8, 0.28), NumberSequenceKeypoint.new(1, 0)}),
	})
end

-- Nieve que cae sobre todo el mapa
function L:snowfall(sx, sz, rate)
	local sky = self:deco({Name = "Nevada", Size = V(sx, 1, sz), CFrame = self:cf(0, 60, 0), Transparency = 1}, self.F.TDS)
	self:emitter(sky, {
		Name = "Copos", Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(Color3.fromRGB(240, 248, 255)), Rate = rate or 60,
		Lifetime = NumberRange.new(10, 14), Speed = NumberRange.new(4, 6), SpreadAngle = Vector2.new(15, 15), EmissionDirection = Enum.NormalId.Bottom,
		Size = NumberSequence.new(0.35, 0.25), Acceleration = V(1.5, 0, 0.5), RotSpeed = NumberRange.new(-60, 60), LightEmission = 0.4,
	})
end

-- Aurora boreal: cortinas de luz (paneles de neón casi transparentes) ondulando alto en el cielo
function L:aurora(cx, cz, y, len, colors)
	local holder = Instance.new("Folder")
	holder.Name = "Aurora"
	self:add(holder, self.F.TDS)
	self:flush()
	for layer = 0, 1 do
		local step = 12
		local n = math.floor(len / step)
		for k = 0, n do
			local x = cx - len / 2 + k * step
			local t = k / n
			local z = cz + layer * 34 + math.sin(t * math.pi * 3 + layer * 1.7) * 26
			local z2 = cz + layer * 34 + math.sin((k + 1) / n * math.pi * 3 + layer * 1.7) * 26
			local h = 46 + math.sin(t * math.pi * 5 + layer) * 14
			local yaw = math.atan2(z2 - z, step)
			local col = colors[1]:Lerp(colors[2 + layer] or colors[2], 0.5 + 0.5 * math.sin(t * math.pi * 2 + layer * 2))
			self:deco({
				Name = "Cortina", Size = V(step + 1.5, h, 0.4), CFrame = self:cf(x, y + layer * 14 + h / 2 + math.sin(t * math.pi * 4) * 6, z) * CFrame.Angles(0, -yaw, 0),
				Material = Enum.Material.Neon, Color = col, Transparency = 0.82, CastShadow = false,
			}, holder)
		end
	end
	return holder
end

---------- Llegada de los jugadores, portal de vuelta, cartel y límites ----------
-- spawn: x, z, yaw (los jugadores miran hacia -Z del spawn)
function L:arrival(x, z, yaw, title)
	for _, from in {Enum.Material.Grass, Enum.Material.LeafyGrass, Enum.Material.Snow} do
		self:paint(x, z, 22, from, Enum.Material.Ground)
	end
	local y = self:groundY(x, z)
	local spawn = self:cf(x, y + 1.8, z, yaw)
	self.model:SetAttribute("Spawn", spawn)
	local stored = ServerStorage:FindFirstChild("MapasTD") and ServerStorage.MapasTD:FindFirstChild("ZombieHollow")
	local zh = workspace:FindFirstChild("ZombieHollow") or (stored and stored:FindFirstChild("ZombieHollow"))
	if zh then
		local plat = zh.Edificios.Plataforma:Clone()
		plat:PivotTo(spawn * CF(0, -3.8, 0) * ANG(0, math.pi, 0))
		self:add(plat, self.F.Edificios)
		local sign = zh.Edificios.CartelMapa:Clone()
		sign:PivotTo(spawn * CF(-24, -3.8, -18) * ANG(0, rad(60), 0))
		for _, d in sign:GetDescendants() do
			if d:IsA("TextLabel") then
				d.Text = string.upper(title)
			end
		end
		self:add(sign, self.F.Edificios)
		local portal = zh.ReturnPortal:Clone()
		-- (a un lado de la plataforma: detrás, la cámara del jugador quedaría dentro de su velo)
		portal:PivotTo(spawn * CF(16, -2.1, 2) * ANG(0, math.pi, 0))
		self:add(portal, self.model)
	end
	table.insert(self.avoid, {x, z, 26})
	return spawn
end

-- Límites invisibles (paredes) y Bounds: rectángulo local x0, z0, x1, z1
function L:bounds(x0, z0, x1, z1)
	self.model:SetAttribute("Bounds", Rect.new(x0, z0, x1, z1))
	local H = 90
	local function wall(name, cx, cz, sx, sz)
		self:part({Name = name, Size = V(sx, H, sz), CFrame = self:cf(cx, H / 2, cz), Transparency = 1, CanQuery = false, CastShadow = false}, self.F.Limites)
	end
	wall("Oeste", x0 - 1, (z0 + z1) / 2, 2, z1 - z0 + 4)
	wall("Este", x1 + 1, (z0 + z1) / 2, 2, z1 - z0 + 4)
	wall("Norte", (x0 + x1) / 2, z0 - 1, x1 - x0 + 4, 2)
	wall("Sur", (x0 + x1) / 2, z1 + 1, x1 - x0 + 4, 2)
end

function L:finish()
	self:flush()
	return self.model, self.count
end

---------- Sacar el mapa del juego ----------
-- Mueve workspace.<id> a ServerStorage.MapasTD.<id> con una copia de su terreno (la celda del mapa: half studs a cada
-- lado del origen, de y = -128 a 256) y borra ese terreno del juego. TDMaps lo pega al cargar el mapa.
local HALF = Vector3.new(450, 0, 400)
function L.store(id, half)
	half = half or HALF
	local map = workspace:FindFirstChild(id)
	assert(map, "No está workspace." .. id)
	local o = map:GetAttribute("Origin").Position
	local cmin = Vector3int16.new(math.floor((o.X - half.X) / 4), -32, math.floor((o.Z - half.Z) / 4))
	local cmax = Vector3int16.new(math.ceil((o.X + half.X) / 4) - 1, 63, math.ceil((o.Z + half.Z) / 4) - 1)
	local region = Terrain:CopyRegion(Region3int16.new(cmin, cmax))
	region.Name = "Terreno"
	region:SetAttribute("Corner", Vector3.new(cmin.X, cmin.Y, cmin.Z))
	local root = ServerStorage:FindFirstChild("MapasTD") or Instance.new("Folder")
	root.Name = "MapasTD"
	root.Parent = ServerStorage
	local old = root:FindFirstChild(id)
	if old then
		old:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = id
	region.Parent = f
	map.Parent = f
	f.Parent = root
	local lo = Vector3.new(cmin.X, cmin.Y, cmin.Z) * 4
	local hi = Vector3.new(cmax.X + 1, cmax.Y + 1, cmax.Z + 1) * 4
	Terrain:FillBlock(CFrame.new((lo + hi) / 2), hi - lo, Enum.Material.Air)
	return f
end

return L
