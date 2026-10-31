-- Mejora de los mapas del Tower Defense (2026-10-24): piezas de calidad (ServerStorage.KitPro, mallas generadas y
-- texturizadas), limpieza de lo que sobraba y animaciones (etiqueta MapFX, ver StarterPlayerScripts.MapFX).
-- Uso (barra de comandos, en edición):
--   local P = require(game.ServerStorage.MapasPro)
--   P.load("CursedCarnival")   -- el mapa guardado, en workspace (con su terreno y su luz)
--   P.Carnival()                -- lo rehace
--   P.store("CursedCarnival")  -- de vuelta a ServerStorage.MapasTD
-- Coordenadas locales: x, z respecto al origen del mapa (atributo Origin); el suelo está en y = 0 local.
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local L = require(ServerStorage.MapasNuevosLib)
local R = require(ServerStorage.MapasRectos)

local V, CF, ANG = Vector3.new, CFrame.new, CFrame.Angles
local C = Color3.fromRGB
local M = Enum.Material
local rad = math.rad

local P = {}
P.Kit = ServerStorage:WaitForChild("KitPro")

---------- Cargar y guardar ----------
function P.load(id)
	local stored = ServerStorage.MapasTD[id]
	local old = workspace:FindFirstChild(id)
	if old then
		old:Destroy()
	end
	local region = stored:FindFirstChild("Terreno")
	if region then
		local c = region:GetAttribute("Corner")
		workspace.Terrain:PasteRegion(region, Vector3int16.new(c.X, c.Y, c.Z), true)
	end
	local m = stored:FindFirstChildOfClass("Model"):Clone()
	m.Parent = workspace
	R.light(id)
	return m
end

function P.store(id)
	R.unlight()
	return L.store(id)
end

-- Pasa al kit una malla generada (la que lleva la etiqueta 'tag' en workspace) con el pivote en el centro de su base
function P.import(tag, name)
	for _, x in CollectionService:GetTagged(tag) do
		if x:IsA("Model") and x.Parent == workspace then
			x.Name = name
			local cf, s = x:GetBoundingBox()
			x.WorldPivot = CF(cf.Position - V(0, s.Y / 2, 0))
			x:PivotTo(CF())
			local old = P.Kit:FindFirstChild(name)
			if old then
				old:Destroy()
			end
			x.Parent = P.Kit
			return ("%s %.1fx%.1fx%.1f"):format(name, s.X, s.Y, s.Z)
		end
	end
	return name .. ": no está"
end

---------- Contexto de un mapa ----------
local Ctx = {}
Ctx.__index = Ctx

function P.ctx(id)
	local m = workspace[id]
	local self = setmetatable({model = m, O = m:GetAttribute("Origin"), rng = Random.new(24)}, Ctx)
	local tds = m.MapaTDS
	self.tds = tds
	self.pro = tds:FindFirstChild("Pro") or Instance.new("Folder")
	self.pro.Name = "Pro"
	self.pro.Parent = tds
	-- el camino en planta (puntos de Camino, locales)
	local pts = {}
	for _, p in m.Camino:GetChildren() do
		local l = self.O:PointToObjectSpace(p.Position)
		pts[tonumber(p.Name)] = Vector2.new(l.X, l.Z)
	 end
	self.path = pts
	self.width = m:GetAttribute("PathWidth") or 9
	return self
end

function Ctx:w(x, y, z)
	return self.O * CF(x, y or 0, z)
end

-- Distancia en planta al camino
function Ctx:dist(x, z)
	local q = Vector2.new(x, z)
	local best = math.huge
	local pts = self.path
	for i = 2, #pts do
		local a, b = pts[i - 1], pts[i]
		local ab = b - a
		local k = math.clamp((q - a):Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
		best = math.min(best, (a + ab * k - q).Magnitude)
	end
	return best
end

-- Altura (local) del suelo en x, z: terreno o piezas de MapaTDS.Suelo / Camino
function Ctx:ground(x, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {workspace.Terrain, self.tds:FindFirstChild("Suelo"), self.tds:FindFirstChild("Camino")}
	params.IgnoreWater = true
	local hit = workspace:Raycast((self.O * CF(x, 150, z)).Position, V(0, -400, 0), params)
	return hit and self.O:PointToObjectSpace(hit.Position).Y or 0
end

-- Quita lo que cumpla f(instancia) entre los hijos de las carpetas dadas
function Ctx:remove(folders, f)
	local n = 0
	for _, folder in folders do
		if folder then
			for _, c in folder:GetChildren() do
				if f(c) then
					c:Destroy()
					n += 1
				end
			end
		end
	end
	return n
end

function Ctx:localPos(inst)
	local pos = inst:IsA("Model") and inst:GetPivot().Position or inst.Position
	return self.O:PointToObjectSpace(pos)
end

---------- Piezas del kit ----------
-- Clona KitPro.<name> en x, z (apoyado en el suelo), girado yaw grados y escalado. opts: y (altura fija), sink,
-- parent, shadows (false = sin sombra, para las pequeñas), collide (false = no estorba)
function Ctx:put(name, x, z, yaw, scale, opts)
	opts = opts or {}
	local src = P.Kit:FindFirstChild(name) or L.kitModel(name)
	assert(src, "Falta KitPro." .. name)
	local m = src:Clone()
	if scale and math.abs(scale - 1) > 1e-3 then
		m:ScaleTo(scale)
	end
	local y = opts.y or self:ground(x, z)
	m:PivotTo(self:w(x, y - (opts.sink or 0.1), z) * ANG(0, rad(yaw or 0), 0))
	local _, size = m:GetBoundingBox()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanTouch = false
			d.CastShadow = opts.shadows ~= false and size.Magnitude > 12
			if opts.collide == false then
				d.CanCollide, d.CanQuery = false, false
			else
				d.CanCollide, d.CanQuery = true, true
			end
		end
	end
	m.Parent = opts.parent or self.pro
	return m
end

-- Marca algo para que MapFX lo anime en los clientes
function P.fx(inst, kind, props)
	inst:SetAttribute("FX", kind)
	for k, v in props or {} do
		inst:SetAttribute("FX" .. k, v)
	end
	CollectionService:AddTag(inst, "MapFX")
	return inst
end

-- Centro de la caja de un modelo (o pieza)
function P.center(inst)
	if inst:IsA("Model") then
		return (inst:GetBoundingBox())
	end
	return inst.CFrame
end

---------- Piezas hechas a mano ----------
function Ctx:part(props, parent)
	local p = Instance.new(props.Shape and "Part" or (props.Class or "Part"))
	props.Class = nil
	p.Anchored, p.CanTouch = true, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = M.SmoothPlastic
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent or self.pro
	return p
end

-- Guirnalda de bombillas entre dos puntos locales (a, b: Vector3) que cuelga 'sag' studs en el centro
function Ctx:festoon(a, b, sag, colors, parent)
	local f = Instance.new("Model")
	f.Name = "Guirnalda"
	local wa, wb = self:w(a.X, a.Y, a.Z).Position, self:w(b.X, b.Y, b.Z).Position
	local len = (wb - wa).Magnitude
	local n = math.max(3, math.floor(len / 2.6))
	local prev
	for i = 0, n do
		local k = i / n
		local p = wa:Lerp(wb, k) - V(0, sag * 4 * k * (1 - k), 0)
		if prev then
			local mid = (prev + p) / 2
			self:part({Name = "Cable", Size = V(0.12, 0.12, (p - prev).Magnitude + 0.05), CFrame = CFrame.lookAt(mid, p), Color = C(25, 22, 30), CanCollide = false, CanQuery = false, CastShadow = false}, f)
		end
		if i > 0 and i < n then
			local col = colors[(i - 1) % #colors + 1]
			local bulb = self:part({Name = "Bombilla", Shape = Enum.PartType.Ball, Size = V(0.55, 0.55, 0.55), CFrame = CF(p - V(0, 0.35, 0)), Material = M.Neon, Color = col, CanCollide = false, CanQuery = false, CastShadow = false}, f)
			if i % 4 == 2 then
				local l = Instance.new("PointLight")
				l.Color, l.Range, l.Brightness = col, 9, 0.7
				l.Parent = bulb
			end
		end
		prev = p
	end
	f.Parent = parent or self.pro
	return f
end

-- Poste de guirnaldas (local x, z, altura h): poste oscuro con remate y bombilla
function Ctx:pole(x, z, h, color, parent)
	local y = self:ground(x, z)
	local f = Instance.new("Model")
	f.Name = "PosteLuces"
	self:part({Name = "Poste", Shape = Enum.PartType.Cylinder, Size = V(h, 0.5, 0.5), CFrame = self:w(x, y + h / 2, z) * ANG(0, 0, rad(90)), Material = M.Metal, Color = C(30, 26, 36)}, f)
	self:part({Name = "Base", Shape = Enum.PartType.Cylinder, Size = V(0.6, 1.4, 1.4), CFrame = self:w(x, y + 0.3, z) * ANG(0, 0, rad(90)), Material = M.Metal, Color = C(30, 26, 36)}, f)
	self:part({Name = "Remate", Shape = Enum.PartType.Ball, Size = V(0.9, 0.9, 0.9), CFrame = self:w(x, y + h + 0.3, z), Material = M.Neon, Color = color or C(255, 190, 90), CanCollide = false}, f)
	f.Parent = parent or self.pro
	return y + h
end

-- Foco que barre el cielo (haz de luz translúcido + SpotLight), animado por MapFX
function Ctx:searchlight(x, z, color, yaw, parent)
	local y = self:ground(x, z)
	local f = Instance.new("Model")
	f.Name = "Foco"
	self:part({Name = "Base", Size = V(3, 1.6, 3), CFrame = self:w(x, y + 0.8, z), Material = M.Metal, Color = C(40, 36, 46)}, f)
	local head = Instance.new("Model")
	head.Name = "Cabeza"
	local pivot = self:w(x, y + 2.4, z) * ANG(0, rad(yaw or 0), 0) * ANG(rad(62), 0, 0)
	self:part({Name = "Lampara", Shape = Enum.PartType.Cylinder, Size = V(2.6, 2.2, 2.2), CFrame = pivot * CF(0, 1, 0) * ANG(0, 0, rad(90)), Material = M.Metal, Color = C(55, 50, 62)}, head)
	local lens = self:part({Name = "Lente", Shape = Enum.PartType.Cylinder, Size = V(0.2, 2, 2), CFrame = pivot * CF(0, 2.35, 0) * ANG(0, 0, rad(90)), Material = M.Neon, Color = color, CanCollide = false}, head)
	local beam = self:part({Name = "Haz", Size = V(3.4, 70, 3.4), CFrame = pivot * CF(0, 37.4, 0), Material = M.Neon, Color = color, Transparency = 0.86, CanCollide = false, CanQuery = false, CastShadow = false}, head)
	local s = Instance.new("SpotLight")
	s.Face, s.Range, s.Angle, s.Brightness, s.Color = Enum.NormalId.Right, 40, 25, 3, color
	s.Parent = lens
	head:SetAttribute("FXHub", self:w(x, y + 2.4, z))
	P.fx(head, "sweep", {Amp = 35, Speed = 0.45, Axis = Vector3.yAxis})
	head.Parent = f
	f.Parent = parent or self.pro
	return f
end

-- Explanada redonda bajo una atracción (suelo válido para tropas) con un aro de bombillas en el borde
function Ctx:pad(x, z, r, color, edge, bulbs)
	local y = self:ground(x, z)
	local suelo = self.tds:FindFirstChild("Suelo")
	self:part({Name = "Explanada", Shape = Enum.PartType.Cylinder, Size = V(0.3, r * 2, r * 2), CFrame = self:w(x, y + 0.12, z) * ANG(0, 0, rad(90)), Material = M.Cobblestone, Color = color, CastShadow = false}, suelo)
	self:part({Name = "Bordillo", Shape = Enum.PartType.Cylinder, Size = V(0.26, r * 2 + 2, r * 2 + 2), CFrame = self:w(x, y + 0.08, z) * ANG(0, 0, rad(90)), Material = M.Slate, Color = edge, CastShadow = false}, suelo)
	if bulbs then
		local f = Instance.new("Model")
		f.Name = "AroLuces"
		local n = math.floor(2 * math.pi * (r + 0.6) / 3.2)
		for i = 1, n do
			local a = i / n * math.pi * 2
			local col = bulbs[(i - 1) % #bulbs + 1]
			self:part({Name = "Bombilla", Shape = Enum.PartType.Ball, Size = V(0.5, 0.5, 0.5), CFrame = self:w(x + math.cos(a) * (r + 0.5), y + 0.4, z + math.sin(a) * (r + 0.5)), Material = M.Neon, Color = col, CanCollide = false, CanQuery = false, CastShadow = false}, f)
		end
		f.Parent = self.pro
	end
end

-- Devuelve del mapa de la copia de seguridad los árboles del borde (lo que cumple keep(modelo, posición local))
function Ctx:restore(folderName, keep)
	local bk = ServerStorage.Backup_Mapas_2026_10_24[self.model.Name]:FindFirstChildOfClass("Model")
	local f = self.tds.Decoracion:FindFirstChild(folderName) or Instance.new("Folder")
	f.Name = folderName
	f:ClearAllChildren()
	local n = 0
	for _, d in bk:GetDescendants() do
		if d:IsA("Model") and d.Parent:IsA("Folder") then
			local p = self.O:PointToObjectSpace(d:GetPivot().Position)
			if keep(d, p) then
				d:Clone().Parent = f
				n += 1
			end
		end
	end
	f.Parent = self.tds.Decoracion
	return n
end

-- ¿Está libre este sitio? (lejos del camino, de lo ya puesto en 'busy' {x, z, r} y dentro de los límites)
function Ctx:free(x, z, gap, busy)
	local B = self.model:GetAttribute("Bounds")
	if x < B.Min.X + 4 or x > B.Max.X - 4 or z < B.Min.Y + 4 or z > B.Max.Y - 4 then
		return false
	end
	if self:dist(x, z) < self.width / 2 + gap then
		return false
	end
	for _, b in busy do
		if (Vector2.new(x, z) - Vector2.new(b[1], b[2])).Magnitude < b[3] then
			return false
		end
	end
	return true
end

-- Grupo de atrezo alrededor de cx, cz: n piezas de 'names' ({nombre, escala}) en un radio r
function Ctx:cluster(names, cx, cz, r, n, busy, gap)
	local placed = 0
	for _ = 1, n * 12 do
		if placed >= n then
			break
		end
		local a, d = self.rng:NextNumber(0, math.pi * 2), r * math.sqrt(self.rng:NextNumber())
		local x, z = cx + math.cos(a) * d, cz + math.sin(a) * d
		local pick = names[self.rng:NextInteger(1, #names)]
		if self:free(x, z, gap or 4, busy) then
			local m = self:put(pick[1], x, z, self.rng:NextNumber(0, 360), pick[2] * self.rng:NextNumber(0.9, 1.1), {shadows = false})
			local _, s = m:GetBoundingBox()
			table.insert(busy, {x, z, math.max(s.X, s.Z) / 2 + 1.5})
			placed += 1
		end
	end
	return placed
end

-- Hijo de un modelo del kit por nombre (las mallas generadas vienen en submodelos)
local function sub(m, name)
	return m:FindFirstChild(name)
end
P.sub = sub

-- Bombillas de feria (cálidas y de colores)
P.BULBS = {C(255, 196, 90), C(255, 90, 160), C(140, 255, 120), C(120, 170, 255), C(255, 140, 50)}

-- Noria: la rueda gira (con un aro de bombillas) y las góndolas dan vueltas colgando siempre derechas
function P.ferris(X, x, z, yaw, scale)
	local m = X:put("FerrisWheelPro", x, z, yaw, scale)
	sub(m, "gondolas"):Destroy()
	local rim = sub(m, "wheel rim and spokes")
	local rcf, rs = rim:GetBoundingBox()
	local hub = CF(rcf.Position) * m:GetPivot().Rotation
	local R = rs.X / 2
	-- bombillas en el aro (giran con la rueda)
	local ring = Instance.new("Model")
	ring.Name = "Bombillas"
	local n = 28
	for i = 1, n do
		local a = i / n * math.pi * 2
		local col = P.BULBS[(i - 1) % #P.BULBS + 1]
		local b = X:part({Name = "Bombilla", Shape = Enum.PartType.Ball, Size = V(0.7, 0.7, 0.7), CFrame = hub * CF(math.cos(a) * R * 0.97, math.sin(a) * R * 0.97, rs.Z / 2 + 0.2), Material = M.Neon, Color = col, CanCollide = false, CanQuery = false, CastShadow = false}, ring)
		if i % 7 == 0 then
			local l = Instance.new("PointLight")
			l.Color, l.Range, l.Brightness = col, 12, 0.8
			l.Parent = b
		end
	end
	ring.Parent = rim
	local speed = 0.13
	rim:SetAttribute("FXHub", hub)
	P.fx(rim, "spin", {Speed = speed, Axis = Vector3.zAxis, Phase = 0})
	-- góndolas: cuelgan de su punto de enganche (el pivote, arriba) en el aro
	local cabins = Instance.new("Folder")
	cabins.Name = "Gondolas"
	cabins.Parent = m
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local g = P.Kit.FerrisGondola:Clone()
		g:ScaleTo(scale * 0.72)
		local gcf, gs = g:GetBoundingBox()
		g.WorldPivot = CF(gcf.Position + V(0, gs.Y / 2, 0)) * gcf.Rotation
		-- (por delante de la rueda: así no las cruzan los radios al girar)
		g:PivotTo(CF((hub * CF(math.cos(a) * R, math.sin(a) * R, rs.Z / 2 + gs.Z / 2 + 0.3)).Position) * hub.Rotation)
		for _, d in g:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored, d.CanTouch, d.CastShadow = true, false, false
			end
		end
		g:SetAttribute("FXHub", hub)
		P.fx(g, "orbit", {Speed = speed, Axis = Vector3.zAxis, Phase = 0})
		g.Parent = cabins
	end
	return m
end

-- Barco pirata: las patas quietas y el barco (con su mástil y velas) meciéndose donde se apoya en ellas
function P.pirate(X, x, z, yaw, scale)
	local m = X:put("PirateShipPro", x, z, yaw, scale)
	local ship = sub(m, "swinging ship with arms")
	local bcf, bs = sub(m, "A-frame base"):GetBoundingBox()
	local scf = ship:GetBoundingBox()
	local hub = CF(scf.Position.X, bcf.Position.Y + bs.Y / 2, scf.Position.Z) * m:GetPivot().Rotation
	ship:SetAttribute("FXHub", hub)
	-- (más, y la proa y la popa atraviesan las patas)
	P.fx(ship, "swing", {Amp = 9, Speed = 1.25, Axis = Vector3.xAxis})
	return m
end

---------- Pasos comunes a todos los mapas ----------
-- Recorrido del camino: devuelve (punto, dirección) a d studs del principio y la longitud total
function Ctx:walker()
	local pts = self.path
	local cum, total = {0}, 0
	for i = 2, #pts do
		total += (pts[i] - pts[i - 1]).Magnitude
		cum[i] = total
	end
	return function(d)
		for i = 2, #pts do
			if cum[i] >= d then
				local k = (d - cum[i - 1]) / math.max(cum[i] - cum[i - 1], 1e-3)
				return pts[i - 1]:Lerp(pts[i], k), (pts[i] - pts[i - 1]).Unit
			end
		end
		return pts[#pts], (pts[#pts] - pts[#pts - 1]).Unit
	end, total
end

function Ctx:inside(x, z, pad)
	local B = self.model:GetAttribute("Bounds")
	pad = pad or 0
	return x > B.Min.X - pad and x < B.Max.X + pad and z > B.Min.Y - pad and z < B.Max.Y + pad
end

-- Quita las flechas fijas del suelo (las sustituyen las que recorren el camino antes de la primera oleada)
function Ctx:noArrows()
	return self:remove({self.tds, self.tds:FindFirstChild("Flechas")}, function(c)
		return c.Name == "Flecha" or c.Name == "Flechas"
	end)
end

-- Quita de las carpetas de MapaTDS lo que se llame como 'names' y esté dentro de la zona de juego (+ pad)
function Ctx:declutter(names, pad, folders)
	local set = {}
	for _, n in names do
		set[n] = true
	end
	local list = {}
	for _, f in folders or {"Decoracion", "Rocas", "Arquitectura"} do
		table.insert(list, self.tds:FindFirstChild(f))
	end
	return self:remove(list, function(c)
		if not set[c.Name] then
			return false
		end
		local p = self:localPos(c)
		return self:inside(p.X, p.Z, pad or 0)
	end)
end

-- Pone derechos los árboles que quedaron tumbados o muy inclinados
function Ctx:upright(match)
	local n = 0
	for _, d in self.model:GetDescendants() do
		if d:IsA("Model") and match(d.Name) then
			local pv = d:GetPivot()
			if pv.UpVector.Y < 0.94 then
				local look = pv.LookVector
				local flat = V(look.X, 0, look.Z)
				if flat.Magnitude < 0.1 then
					flat = V(1, 0, 0)
				end
				-- base apoyada en el suelo: se gira alrededor del punto más bajo
				local cf, s = d:GetBoundingBox()
				local l = self.O:PointToObjectSpace(cf.Position)
				local gy = self:ground(l.X, l.Z)
				d:PivotTo(CFrame.lookAt(pv.Position, pv.Position + flat.Unit))
				local cf2, s2 = d:GetBoundingBox()
				local bottom = self.O:PointToObjectSpace(cf2.Position).Y - s2.Y / 2
				d:PivotTo(d:GetPivot() + self.O:VectorToWorldSpace(V(0, gy - bottom - 0.3, 0)))
				n += 1
			end
		end
	end
	return n
end

-- Entrada (al principio del camino, detrás y mirando hacia él) y casa (al final, mirando al camino que llega)
function Ctx:ends(spawnName, spawnScale, back, goalName, goalScale, fwd, opts)
	opts = opts or {}
	local pts = self.path
	local s0, s1 = pts[1], pts[math.min(4, #pts)]
	local ds = (s1 - s0).Unit
	local sp = s0 - ds * back
	local a = self:put(spawnName, sp.X, sp.Y, math.deg(math.atan2(ds.X, ds.Y)) + (opts.spawnYaw or 0), spawnScale, {y = opts.spawnY})
	local e1, e0 = pts[#pts], pts[math.max(1, #pts - 3)]
	local de = (e1 - e0).Unit
	local gp = e1 + de * fwd
	local b = self:put(goalName, gp.X, gp.Y, math.deg(math.atan2(-de.X, -de.Y)) + (opts.goalYaw or 0), goalScale, {y = opts.goalY})
	return a, b, sp, gp
end

-- Farolas a lo largo del camino, a ambos lados alternando, cada 'every' studs (saltándose lo ocupado en 'busy')
function Ctx:lamps(name, scale, every, busy, offset)
	local at, total = self:walker()
	local n, side = 0, 1
	for d = every * 0.5, total - every * 0.5, every do
		local p, t = at(d)
		local q = p + Vector2.new(-t.Y, t.X) * side * (self.width / 2 + (offset or 2.6))
		if self:free(q.X, q.Y, (offset or 2.6) - 0.6, busy) then
			self:put(name, q.X, q.Y, self.rng:NextNumber(0, 360), scale, {shadows = false})
			table.insert(busy, {q.X, q.Y, 3})
			n += 1
		end
		side = -side
	end
	return n
end

-- Grupos de atrezo repartidos por el mapa: celdas de 'cell' studs, en cada una un sitio libre entre 'near' y 'far' studs
-- del camino
function Ctx:sprinkle(props, cell, near, far, per, busy)
	local B = self.model:GetAttribute("Bounds")
	local total = 0
	for cx = B.Min.X + cell / 2, B.Max.X, cell do
		for cz = B.Min.Y + cell / 2, B.Max.Y, cell do
			for _ = 1, 10 do
				local x, z = cx + self.rng:NextNumber(-cell / 2, cell / 2), cz + self.rng:NextNumber(-cell / 2, cell / 2)
				local d = self:dist(x, z)
				if d > self.width / 2 + near and d < self.width / 2 + far and self:free(x, z, near, busy) then
					total += self:cluster(props, x, z, 7, per, busy, near)
					break
				end
			end
		end
	end
	return total
end

-- Lo que ya ocupa sitio en el mapa (árboles, rocas, edificios grandes...) como círculos {x, z, r}
function Ctx:occupied(minSize)
	local list = {}
	for _, f in {self.tds:FindFirstChild("Decoracion"), self.tds:FindFirstChild("Rocas"), self.tds:FindFirstChild("Arquitectura"), self.pro, self.model:FindFirstChild("Edificios"), self.model:FindFirstChild("Atracciones")} do
		for _, c in f and f:GetChildren() or {} do
			if c:IsA("Model") or c:IsA("BasePart") then
				local cf, s
				if c:IsA("Model") then
					cf, s = c:GetBoundingBox()
				else
					cf, s = c.CFrame, c.Size
				end
				local r = math.max(s.X, s.Z) / 2
				if r >= (minSize or 1) and r < 60 then
					local l = self.O:PointToObjectSpace(cf.Position)
					table.insert(list, {l.X, l.Z, r + 1})
				end
			end
		end
	end
	return list
end

-- Centros de los grupos de piezas 'name' (p. ej. los tramos de valla de cada huerto): {x, z, n}
function Ctx:groups(name, radius)
	local groups = {}
	for _, c in self.tds.Decoracion:GetChildren() do
		if c.Name == name then
			local p = self:localPos(c)
			local g
			for _, q in groups do
				if (Vector2.new(q.x / q.n, q.z / q.n) - Vector2.new(p.X, p.Z)).Magnitude < radius then
					g = q
					break
				end
			end
			if not g then
				g = {x = 0, z = 0, n = 0}
				table.insert(groups, g)
			end
			g.x += p.X
			g.z += p.Z
			g.n += 1
		end
	end
	local out = {}
	for _, g in groups do
		table.insert(out, {g.x / g.n, g.z / g.n, g.n})
	end
	return out
end

-- Pone 'name' en el primer sitio libre de 'spots' ({x, z, yaw}); r: radio que ocupa. Devuelve el modelo o nil
function Ctx:putFree(name, spots, scale, r, busy, gap)
	for _, s in spots do
		if self:free(s[1], s[2], gap or (r + 2), busy) then
			local m = self:put(name, s[1], s[2], s[3] or self.rng:NextNumber(0, 360), scale)
			table.insert(busy, {s[1], s[2], r})
			return m
		end
	end
	return nil
end

-- Busca huecos libres en una zona (x0, z0, x1, z1) para 'name': hasta n piezas
function Ctx:fillZone(name, zone, n, scale, r, busy, gap, yawFn)
	local placed = 0
	for _ = 1, n * 30 do
		if placed >= n then
			break
		end
		local x, z = self.rng:NextNumber(zone[1], zone[3]), self.rng:NextNumber(zone[2], zone[4])
		if self:free(x, z, gap or (r + 2), busy) then
			self:put(name, x, z, yawFn and yawFn(x, z) or self.rng:NextNumber(0, 360), scale)
			table.insert(busy, {x, z, r})
			placed += 1
		end
	end
	return placed
end

-- Cambia las láminas de agua de plástico (piezas "Agua") por agua del terreno: con oleaje y reflejos, y las tropas
-- siguen sin poder ponerse encima (TD.canPlace rechaza el material Water)
function Ctx:realWater(depth)
	local n = 0
	for _, d in self.model:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Agua" and d.Size.Y < 2 then
			local top = d.CFrame * CF(0, d.Size.Y / 2, 0)
			-- hasta el fondo (sin hueco de aire entre el agua y el lecho)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = {workspace.Terrain}
			local hit = workspace:Raycast(top.Position, V(0, -40, 0), params)
			local deep = math.max(depth or 3, hit and (top.Position.Y - hit.Position.Y + 1.5) or 0)
			workspace.Terrain:FillBlock(top * CF(0, -deep / 2, 0), V(d.Size.X, deep, d.Size.Z), M.Water)
			d:Destroy()
			n += 1
		end
	end
	return n
end

-- Ángulo (grados) para que el frente +Z de una pieza en x, z mire hacia tx, tz
function P.face(x, z, tx, tz)
	return math.deg(math.atan2(tx - x, tz - z))
end

local function isTree(n)
	return n:find("Pine") or n:find("Tree") or n:find("Cypress") or n:find("Willow") or n:find("Arbol")
end
P.isTree = isTree

---------- Zombie Hollow ----------
function P.ZombieHollow()
	local X = P.ctx("ZombieHollow")
	local m, tds = X.model, X.tds
	local log = {}
	table.insert(log, "flechas: " .. X:noArrows())
	-- relleno suelto: calabazas y setas repartidas al azar por todo el campo
	table.insert(log, "relleno: " .. X:declutter({"Pumpkin", "PumpkinRound", "PumpkinSquat", "PumpkinTall", "JackClassic", "JackAngry", "JackOLantern", "Mushrooms", "Cart", "Signpost"}, -2))
	-- la entrada (portal plano) y la casa vieja
	local cave = tds:FindFirstChild("Cueva")
	if cave then
		cave:Destroy()
	end
	table.insert(log, "casa: " .. X:remove({tds.Decoracion}, function(c)
		return c.Name == "CasaEmbrujada"
	end))
	table.insert(log, "derechos: " .. X:upright(isTree))
	X.pro:ClearAllChildren()
	local _, _, sp, gp = X:ends("ZombieCrypt", 1.3, 8, "HauntedMansion", 1.3, 15)
	-- fantasmas que flotan
	for _, g in tds.Decoracion:GetChildren() do
		if g.Name == "GenGhost" then
			P.fx(g, "bob", {Amp = 1.3, Speed = 1.6})
		end
	end
	-- huertos vallados: calabazas dentro
	local patches = 0
	for _, g in X:groups("WoodFence", 14) do
		if g[3] >= 2 then
			for k = 1, 3 do
				local a = k / 3 * math.pi * 2 + X.rng:NextNumber(0, 1)
				X:put("PumpkinPile", g[1] + math.cos(a) * 2.6, g[2] + math.sin(a) * 2.6, X.rng:NextNumber(0, 360), 1.15, {shadows = false})
			end
			patches += 1
		end
	end
	table.insert(log, "huertos: " .. patches)
	local busy = X:occupied(1.5)
	table.insert(busy, {sp.X, sp.Y, 16})
	table.insert(busy, {gp.X, gp.Y, 22})
	table.insert(busy, {64, 96, 24}) -- plataforma de llegada
	if P.Kit:FindFirstChild("GothicLamp") then
		table.insert(log, "farolas: " .. X:lamps("GothicLamp", 2, 30, busy))
	end
	-- (las repeticiones del nombre son el peso de cada pieza)
	local props = {{"PumpkinPile", 1.3}, {"PumpkinPile", 1.2}, {"PumpkinPile", 1.1}, {"Tombstones", 1.3}, {"Tombstones", 1.2}, {"Tombstones", 1.4},
		{"DeadTreeLanterns", 1.4}, {"Cauldron", 1.25}}
	table.insert(log, "atrezo: " .. X:sprinkle(props, 46, 6, 34, 2, busy))
	return table.concat(log, " | ")
end

---------- Blood Moon Cemetery ----------
function P.BloodMoonCemetery()
	local X = P.ctx("BloodMoonCemetery")
	local m, tds = X.model, X.tds
	local log = {}
	table.insert(log, "flechas: " .. X:noArrows())
	table.insert(log, "relleno: " .. X:declutter({"JackOLantern", "Mushrooms", "Mound"}, -2))
	X.pro:ClearAllChildren()
	-- el mausoleo: el nuevo, al final del camino y mirando hacia él
	if P.Kit:FindFirstChild("MausoleumPro") then
		X:remove({tds.Arquitectura}, function(c)
			return c.Name == "Mausoleum"
		end)
		local pts = X.path
		local e1, e0 = pts[#pts], pts[#pts - 3]
		local de = (e1 - e0).Unit
		local gp = e1 + de * 16
		X:put("MausoleumPro", gp.X, gp.Y, P.face(gp.X, gp.Y, e1.X, e1.Y), 1.35)
	end
	local busy = X:occupied(1.5)
	table.insert(busy, {40, 104, 24}) -- plataforma
	table.insert(log, "farolas: " .. X:lamps("GothicLamp", 2, 30, busy))
	local props = {{"WeepingAngel", 1.8}, {"Cauldron", 1.2}, {"DeadTreeLanterns", 1.3}, {"GothicRuins", 1.4}, {"PumpkinPile", 1.1}}
	table.insert(log, "atrezo: " .. X:sprinkle(props, 50, 6, 30, 1, busy))
	return table.concat(log, " | ")
end

---------- Voidcore Rift ----------
function P.VoidcoreRift()
	local X = P.ctx("VoidcoreRift")
	local m, tds = X.model, X.tds
	local log = {}
	table.insert(log, "flechas: " .. X:noArrows())
	table.insert(log, "relleno: " .. X:declutter({"Mushrooms", "Mound"}, -2))
	X.pro:ClearAllChildren()
	-- el Corazón del Vacío: el nuevo altar con el orbe flotando y girando
	if P.Kit:FindFirstChild("VoidHeartPro") then
		local old = tds.Arquitectura:FindFirstChild("VoidHeart")
		local at = old and X:localPos(old) or V(6, 0, -14)
		if old then
			old:Destroy()
		end
		local h = X:put("VoidHeartPro", at.X, at.Z, 0, 1.3)
		local orb = sub(h, "floating orb")
		if orb then
			P.fx(orb, "bob", {Amp = 1.2, Speed = 1.2})
			local ocf = orb:GetBoundingBox()
			local mp = orb:FindFirstChildWhichIsA("BasePart", true)
			local att = Instance.new("Attachment")
			att.WorldPosition = ocf.Position
			att.Parent = mp
			local l = Instance.new("PointLight")
			l.Color, l.Range, l.Brightness = C(220, 80, 255), 30, 2
			l.Parent = att
		end
	end
	-- los anillos de runas giran y los cristales grandes flotan
	for _, d in tds.Arquitectura:GetChildren() do
		if d.Name == "Aro" or d.Name == "Circulo" then
			local p = d:IsA("BasePart") and d.Position or d:GetPivot().Position
			d:SetAttribute("FXHub", CF(p))
			P.fx(d, "spin", {Speed = 0.25})
		end
	end
	local nb = 0
	for _, d in tds.Decoracion:GetChildren() do
		if d.Name == "VoidCrystals" then
			local _, s = d:GetBoundingBox()
			if s.Y > 10 then
				P.fx(d, "bob", {Amp = 0.8, Speed = 0.8})
				nb += 1
			end
		end
	end
	table.insert(log, "cristales: " .. nb)
	local busy = X:occupied(1.5)
	table.insert(busy, {6, -14, 22})
	table.insert(busy, {40, 106, 24}) -- plataforma
	if P.Kit:FindFirstChild("VoidShards") then
		local props = {{"VoidShards", 1.4}, {"VoidShards", 1.2}, {"VoidShards", 1.7}}
		table.insert(log, "atrezo: " .. X:sprinkle(props, 50, 6, 26, 1, busy))
	end
	return table.concat(log, " | ")
end

---------- Ghost Harbor ----------
function P.GhostHarbor()
	local X = P.ctx("GhostHarbor")
	local m, tds = X.model, X.tds
	local log = {}
	table.insert(log, "flechas: " .. X:noArrows())
	table.insert(log, "relleno: " .. X:declutter({"Pumpkin", "JackOLantern", "Mushrooms", "Cart", "NoticeBoard", "Mound", "CrateStack", "Signpost"}, -2))
	X.pro:ClearAllChildren()
	-- el haz del faro gira alrededor de la linterna
	local arq = tds.Arquitectura
	local lantern = arq:FindFirstChild("Linterna")
	local beam = arq:FindFirstChild("Haz")
	if lantern and beam then
		beam:SetAttribute("FXHub", CF(lantern.Position))
		P.fx(beam, "spin", {Speed = 0.7, Phase = 0})
	end
	-- el barco fantasma: el nuevo, meciéndose en el agua donde estaba el viejo
	local old = tds.Decoracion:FindFirstChild("GhostShip")
	if old and P.Kit:FindFirstChild("GhostShipPro") then
		local at = X:localPos(old)
		local yaw = select(2, old:GetPivot():ToOrientation())
		local glow = arq:FindFirstChild("Brillo")
		for _, b in arq:GetChildren() do
			if b.Name == "Brillo" and b:IsA("BasePart") and b.Size.X > 10 then
				glow = b
			end
		end
		old:Destroy()
		local ship = X:put("GhostShipPro", at.X, at.Z, math.deg(yaw), 2.3, {y = -1.4 - 4})
		P.fx(ship, "swing", {Amp = 4, Speed = 0.9, Axis = Vector3.zAxis})
		if glow then
			glow:Destroy()
		end
	end
	local busy = X:occupied(1.5)
	table.insert(busy, {40, 104, 24}) -- plataforma
	table.insert(busy, {154, -108, 24}) -- faro
	table.insert(log, "farolas: " .. X:lamps("GothicLamp", 2, 30, busy))
	local props = {{"DockProps", 1.3}, {"DockProps", 1.2}, {"BarrelStack", 1.1}, {"BarrelStack", 1.2}, {"PumpkinPile", 1.1}}
	table.insert(log, "atrezo: " .. X:sprinkle(props, 44, 6, 32, 2, busy))
	return table.concat(log, " | ")
end

---------- Scarecrow Fields ----------
function P.ScarecrowFields()
	local X = P.ctx("ScarecrowFields")
	local m, tds = X.model, X.tds
	local log = {}
	table.insert(log, "flechas: " .. X:noArrows())
	table.insert(log, "relleno: " .. X:declutter({"Pumpkin", "JackOLantern", "Mushrooms", "Cart", "NoticeBoard", "Mound", "CrateStack"}, -2))
	-- el granero: el nuevo, al final del camino y mirando hacia él (el viejo era un bloque rojo lejos del camino)
	X:remove({tds.Arquitectura}, function(c)
		return c.Name == "Barn"
	end)
	X.pro:ClearAllChildren()
	local pts = X.path
	local e1, e0 = pts[#pts], pts[#pts - 3]
	local de = (e1 - e0).Unit
	local gp = e1 + de * 15
	X:put("BarnPro", gp.X, gp.Y, P.face(gp.X, gp.Y, e1.X, e1.Y), 1.2)
	local busy = X:occupied(1.5)
	table.insert(busy, {gp.X, gp.Y, 22})
	table.insert(busy, {40, 104, 24}) -- plataforma
	-- molinos de bombeo con las aspas girando
	local pumps = 0
	for _, z in {{-150, 20, 60, 110}, {0, -60, 120, 30}, {-170, -120, -60, -60}} do
		for _ = 1, 200 do
			local x, zz = X.rng:NextNumber(z[1], z[3]), X.rng:NextNumber(z[2], z[4])
			if X:free(x, zz, 9, busy) then
				local w = X:put("FarmWindPump", x, zz, X.rng:NextNumber(0, 360), 1.6)
				local fan = sub(w, "fan blades")
				local fcf = fan:GetBoundingBox()
				fan:SetAttribute("FXHub", CF(fcf.Position) * w:GetPivot().Rotation)
				P.fx(fan, "spin", {Speed = 1.4, Axis = Vector3.zAxis})
				table.insert(busy, {x, zz, 7})
				pumps += 1
				break
			end
		end
	end
	table.insert(log, "molinos: " .. pumps)
	table.insert(log, "farolas: " .. X:lamps("GothicLamp", 2, 32, busy))
	local props = {{"PumpkinPile", 1.3}, {"PumpkinPile", 1.2}, {"PumpkinPile", 1.4}, {"BarrelStack", 1.1}, {"DeadTreeLanterns", 1.3}}
	table.insert(log, "atrezo: " .. X:sprinkle(props, 44, 6, 32, 2, busy))
	return table.concat(log, " | ")
end

---------- Fallen Cathedral ----------
function P.FallenCathedral()
	local X = P.ctx("FallenCathedral")
	local m, tds = X.model, X.tds
	local log = {}
	table.insert(log, "flechas: " .. X:noArrows())
	table.insert(log, "relleno: " .. X:declutter({"JackOLantern", "Mushrooms"}, -2))
	X.pro:ClearAllChildren()
	-- la catedral: la nueva, en ruinas, al final del camino (la vieja era una malla borrosa)
	if P.Kit:FindFirstChild("CathedralPro") then
		X:remove({tds.Arquitectura}, function(c)
			return c.Name == "Cathedral"
		end)
		local pts = X.path
		local e1, e0 = pts[#pts], pts[#pts - 3]
		local de = (e1 - e0).Unit
		-- (la malla tiene la fachada en su -X: +90º para que mire al camino)
		local gp = e1 + de * 31
		X:put("CathedralPro", gp.X, gp.Y, P.face(gp.X, gp.Y, e1.X, e1.Y) + 90, 1.55)
	end
	local busy = X:occupied(1.5)
	table.insert(busy, {130, 30, 30})
	table.insert(busy, {-22, 104, 24}) -- plataforma
	table.insert(log, "farolas: " .. X:lamps("GothicLamp", 2, 32, busy))
	local props = {{"GothicRuins", 1.7}, {"GothicRuins", 1.5}, {"WeepingAngel", 1.9}, {"Tombstones", 1.3}, {"Tombstones", 1.2}, {"PumpkinPile", 1.1}}
	table.insert(log, "atrezo: " .. X:sprinkle(props, 44, 6, 32, 2, busy))
	return table.concat(log, " | ")
end

---------- Frozen Peak ----------
function P.FrozenPeak()
	local X = P.ctx("FrozenPeak")
	local m, tds = X.model, X.tds
	local log = {}
	table.insert(log, "flechas: " .. X:noArrows())
	X.pro:ClearAllChildren()
	local pts = X.path
	local e1 = pts[#pts]
	-- el castillo de hielo (Arquitectura.Aguja...) está junto al final: la mancha oscura de su alrededor pasa a nieve y
	-- un paseo helado lleva del final del camino a su puerta
	local castle = Vector2.new(146, 70)
	local c3 = X:w(castle.X, 0, castle.Y).Position
	local region = Region3.new(c3 - V(52, 30, 52), c3 + V(52, 40, 52)):ExpandToGrid(4)
	for _, from in {M.Rock, M.Slate, M.Basalt, M.Ground, M.Mud, M.Glacier} do
		workspace.Terrain:ReplaceMaterial(region, 4, from, M.Snow)
	end
	local dir = (castle - e1).Unit
	local len = (castle - e1).Magnitude - 15
	local y0, y1 = X:ground(e1.X, e1.Y), X:ground(castle.X - dir.X * 16, castle.Y - dir.Y * 16)
	local a = X:w(e1.X, y0 + 0.2, e1.Y).Position
	local b = X:w(e1.X + dir.X * len, y1 + 0.2, e1.Y + dir.Y * len).Position
	X:part({Name = "PaseoHelado", Size = V(X.width, 0.4, (b - a).Magnitude + 2), CFrame = CFrame.lookAt((a + b) / 2, b), Material = M.Ice, Color = C(170, 220, 255), CanCollide = true, CastShadow = false})
	for k = 0, 3 do
		for _, sd in {-1, 1} do
			local p = a:Lerp(b, (k + 0.5) / 4) + X.O:VectorToWorldSpace(V(-dir.Y * sd * (X.width / 2 + 1.2), 0, dir.X * sd * (X.width / 2 + 1.2)))
			local post = X:part({Name = "FarolHielo", Size = V(0.9, 4, 0.9), CFrame = CF(p + V(0, 2, 0)), Material = M.Ice, Color = C(190, 230, 255)})
			local gem = X:part({Name = "Llama", Shape = Enum.PartType.Ball, Size = V(1.2, 1.2, 1.2), CFrame = CF(p + V(0, 4.6, 0)), Material = M.Neon, Color = C(120, 210, 255), CanCollide = false}, post)
			local l = Instance.new("PointLight")
			l.Color, l.Range, l.Brightness = C(120, 200, 255), 12, 1
			l.Parent = gem
		end
	end
	local busy = X:occupied(1.5)
	table.insert(busy, {castle.X, castle.Y, 30})
	table.insert(busy, {-4, 93, 24}) -- plataforma
	-- el campamento de la expedición junto a la entrada
	local s = pts[1]
	X:putFree("ExpeditionCamp", {{s.X + 12, s.Y + 18, 0}, {s.X + 12, s.Y - 18, 180}, {s.X + 28, s.Y + 18, 0}, {s.X + 28, s.Y - 18, 180}}, 1.3, 11, busy, 9)
	X:putFree("ExpeditionCamp", {{s.X + 32, s.Y - 20, 200}, {s.X + 40, s.Y + 22, -20}}, 1.2, 11, busy, 9)
	table.insert(log, "farolas: " .. X:lamps("GothicLamp", 2, 34, busy))
	local props = {{"EvilSnowman", 1.4}, {"EvilSnowman", 1.2}, {"BarrelStack", 1}, {"ExpeditionCamp", 1.1}}
	table.insert(log, "atrezo: " .. X:sprinkle(props, 60, 6, 32, 1, busy))
	return table.concat(log, " | ")
end

---------- Witch Bayou ----------
function P.WitchBayou()
	local X = P.ctx("WitchBayou")
	local m, tds = X.model, X.tds
	local log = {}
	table.insert(log, "flechas: " .. X:noArrows())
	table.insert(log, "relleno: " .. X:declutter({"Pumpkin", "Mushrooms", "Cart", "NoticeBoard", "Mound"}, -2))
	-- la casa: la cabaña sobre pilotes en lugar de la vieja
	X:remove({tds.Arquitectura}, function(c)
		return c.Name == "WitchHut"
	end)
	X.pro:ClearAllChildren()
	local pts = X.path
	local e1, e0 = pts[#pts], pts[#pts - 3]
	local de = (e1 - e0).Unit
	local gp = e1 + de * 12
	X:put("WitchHutPro", gp.X, gp.Y, P.face(gp.X, gp.Y, e1.X, e1.Y), 1.35)
	local busy = X:occupied(1.5)
	table.insert(busy, {gp.X, gp.Y, 18})
	table.insert(busy, {40, 102, 24}) -- plataforma
	if P.Kit:FindFirstChild("SwampDock") then
		local s = pts[1]
		X:putFree("SwampDock", {{s.X + 14, s.Y - 18, 180}, {s.X + 14, s.Y + 18, 0}, {s.X + 30, s.Y - 18, 180}}, 1.3, 14, busy, 10)
	end
	table.insert(log, "farolas: " .. X:lamps("GothicLamp", 2, 32, busy))
	local props = {{"GlowShrooms", 1.3}, {"GlowShrooms", 1.1}, {"GlowShrooms", 1.5}, {"Cauldron", 1.25}, {"Tombstones", 1.1}}
	if P.Kit:FindFirstChild("VoodooTotem") then
		table.insert(props, {"VoodooTotem", 1.3})
	end
	table.insert(log, "atrezo: " .. X:sprinkle(props, 44, 6, 32, 2, busy))
	return table.concat(log, " | ")
end

---------- Cursed Castle ----------
function P.CursedCastle()
	local X = P.ctx("CursedCastle")
	local m, tds = X.model, X.tds
	local log = {}
	table.insert(log, "flechas: " .. X:noArrows())
	table.insert(log, "relleno: " .. X:declutter({"Pumpkin", "PumpkinRound", "PumpkinTall", "JackOLantern", "Mushrooms", "Cart", "Signpost", "NoticeBoard"}, -2))
	X.pro:ClearAllChildren()
	-- el río: agua del terreno, no plástico azul
	table.insert(log, "agua: " .. X:realWater(3))
	local busy = X:occupied(1.5)
	table.insert(busy, {-6, 100, 26}) -- plataforma
	-- el campamento de los campesinos en la entrada: empalizada, tiendas y catapultas apuntando al castillo
	local s = X.path[1]
	X:putFree("PalisadeGate", {{s.X + 10, s.Y - 17, 180}, {s.X + 10, s.Y + 17, 0}, {s.X + 24, s.Y - 17, 180}}, 1.6, 13, busy, 8)
	local castle = Vector2.new(140, 30)
	if P.Kit:FindFirstChild("KnightTent") then
		table.insert(log, "tiendas: " .. X:fillZone("KnightTent", {-168, -116, -120, -78}, 4, 1.25, 8, busy, 8))
		table.insert(log, "tiendas2: " .. X:fillZone("KnightTent", {-168, -44, -128, 0}, 3, 1.25, 8, busy, 8))
	end
	if P.Kit:FindFirstChild("SiegeCatapult") then
		table.insert(log, "catapultas: " .. X:fillZone("SiegeCatapult", {-150, -40, 60, 60}, 4, 1.3, 9, busy, 10, function(x, z)
			return P.face(x, z, castle.X, castle.Y)
		end))
	end
	-- la aldea: un molino con las aspas girando
	local mill = X:putFree("Windmill", {{-120, 60}, {-100, 70}, {-150, 80}, {-60, 60}, {-60, -100}, {40, 100}}, 1.5, 15, busy, 14)
	if not mill then
		-- (en la aldea, al oeste del río, donde haya sitio)
		for _ = 1, 300 do
			local x, z = X.rng:NextNumber(-165, -60), X.rng:NextNumber(-110, 110)
			if X:free(x, z, 13, busy) then
				mill = X:put("Windmill", x, z, P.face(x, z, x, z - 1), 1.5)
				table.insert(busy, {x, z, 15})
				break
			end
		end
	end
	table.insert(log, "molino: " .. tostring(mill ~= nil))
	if mill then
		local sails = sub(mill, "sails")
		local scf = sails:GetBoundingBox()
		sails:SetAttribute("FXHub", CF(scf.Position) * mill:GetPivot().Rotation)
		P.fx(sails, "spin", {Speed = 0.6, Axis = Vector3.zAxis})
	end
	table.insert(log, "farolas: " .. X:lamps("GothicLamp", 2, 30, busy))
	local props = {{"PumpkinPile", 1.2}, {"PumpkinPile", 1.2}, {"BarrelStack", 1.1}, {"BarrelStack", 1.1}, {"Tombstones", 1.2}}
	table.insert(log, "atrezo: " .. X:sprinkle(props, 50, 6, 30, 2, busy))
	return table.concat(log, " | ")
end

---------- Cursed Carnival ----------
function P.Carnival()
	local id = "CursedCarnival"
	local X = P.ctx(id)
	local m, tds = X.model, X.tds
	local B = m:GetAttribute("Bounds")
	local function inside(p, pad)
		pad = pad or 0
		return p.X > B.Min.X - pad and p.X < B.Max.X + pad and p.Z > B.Min.Y - pad and p.Z < B.Max.Y + pad
	end
	local log = {}
	-- 1. fuera: flechas fijas (las sustituyen las que recorren el camino), atracciones viejas, lo que flotaba fuera del
	-- mapa y el relleno suelto (calabazas gigantes, peluches, globos y cajas al azar)
	table.insert(log, "flechas: " .. X:remove({tds, tds:FindFirstChild("Flechas")}, function(c)
		return c.Name == "Flecha" or c.Name == "Flechas"
	end))
	local KEEP = {SwingRide = true, DropTower = true, CircusWagon = true}
	table.insert(log, "atracciones: " .. X:remove({m:FindFirstChild("Atracciones")}, function(c)
		local p = X:localPos(c)
		return not KEEP[c.Name] or not inside(p, -4) or X:dist(p.X, p.Z) < 14
	end))
	table.insert(log, "deco: " .. X:remove({tds:FindFirstChild("Decoracion")}, function(c)
		return c.Name ~= "Valla" and c.Name ~= "Bosque" -- (las farolas viejas también: las sustituyen las guirnaldas)
	end))
	table.insert(log, "manchas: " .. X:remove({tds:FindFirstChild("Suelo")}, function(c)
		if c.Name == "Explanada" or c.Name == "Bordillo" then
			return true -- (de una pasada anterior)
		end
		if c.Name ~= "Tierra" then
			return false
		end
		local p = X:localPos(c)
		return not ((p - V(-144, p.Y, -50)).Magnitude < 3 or (p - V(-64, p.Y, -118)).Magnitude < 3)
	end))
	X.pro:ClearAllChildren()

	-- 2. la entrada y la casa: el arco del payaso por donde entran y la casa de la risa al final
	X:put("ClownGate", -157, -96, 90, 1.15)
	local pts = X.path
	local last, before = pts[#pts], pts[#pts - 3]
	local dir = (last - before).Unit
	local c = last + dir * 12
	X:put("FunHouse", c.X, c.Y, math.deg(math.atan2(-dir.X, -dir.Y)), 1.15)

	-- 3. atracciones: una en el centro de cada vuelta del camino (quedan franjas libres para las tropas) y las grandes al
	-- fondo
	X:pad(-78, 18, 15, C(58, 40, 74), C(30, 22, 40), P.BULBS)
	local car = X:put("Carousel", -78, 18, 0, 1.15, {y = X:ground(-78, 18) + 0.3})
	P.fx(car, "spin", {Speed = 0.45})

	X:pad(66, 14, 25, C(58, 40, 74), C(30, 22, 40), P.BULBS)
	X:put("BigTop", 66, 14, 20, 1.25, {y = X:ground(66, 14) + 0.3})

	X:pad(-112, 125, 15, C(48, 60, 52), C(26, 34, 30), P.BULBS)
	local cups = X:put("Teacups", -112, 125, 0, 2.2, {y = X:ground(-112, 125) + 0.3})
	P.fx(sub(cups, "platform"), "spin", {Speed = 0.35})
	P.fx(sub(cups, "teacups"), "spin", {Speed = -0.9})

	X:pad(96, -100, 20, C(40, 52, 40), C(22, 30, 24), P.BULBS)
	local bump = X:put("BumperCars", 96, -100, 0, 2, {y = X:ground(96, -100) + 0.3})
	P.fx(sub(bump, "bumper cars"), "spin", {Speed = 0.7})

	if P.Kit:FindFirstChild("FerrisWheelPro") then
		X:pad(-8, -116, 14, C(58, 40, 74), C(30, 22, 40), P.BULBS)
		P.ferris(X, -8, -118, 0, 1.75)
	end
	if P.Kit:FindFirstChild("PirateShipPro") then
		X:pad(-10, -12, 16, C(48, 40, 66), C(26, 22, 38), P.BULBS)
		P.pirate(X, -10, -12, 0, 1.4)
	end

	-- 4. el paseo de la feria (midway): adoquinado al sur del camino con las casetas en fila mirando hacia él
	local gy = X:ground(-52, 86)
	X:part({Name = "Explanada", Size = V(214, 0.3, 14), CFrame = X:w(-52, gy + 0.12, 86), Material = M.Cobblestone, Color = C(70, 56, 84), CastShadow = false}, tds.Suelo)
	X:part({Name = "Bordillo", Size = V(217, 0.26, 17), CFrame = X:w(-52, gy + 0.08, 86), Material = M.Slate, Color = C(34, 26, 44), CastShadow = false}, tds.Suelo)
	local row = {{"GameStall", -150, 1.3}, {"CottonCandy", -128, 1.35}, {"GameStall", -106, 1.3}, {"HighStriker", -86, 1.7}, {"GameStall", -66, 1.3},
		{"PopcornCart", -46, 1.3}, {"GameStall", -26, 1.3}, {"CottonCandy", -4, 1.35}, {"GameStall", 18, 1.3}, {"HighStriker", 38, 1.7}}
	local busy = {}
	for _, s in row do
		X:put(s[1], s[2], 101, 180, s[3])
		table.insert(busy, {s[2], 101, 9})
	end
	-- guirnaldas sobre el paseo, de poste a poste por su borde sur
	local prevPole
	for x = -158, 54, 22 do
		local top = X:pole(x, 94.5, 10, P.BULBS[(x // 22) % #P.BULBS + 1])
		local here = V(x, top - 0.3, 94.5)
		if prevPole then
			X:festoon(prevPole, here, 1.2, P.BULBS)
		end
		prevPole = here
	end
	X:put("GameStall", -150, 20, 90, 1.3)
	X:put("GameStall", 150, -40, -90, 1.3)
	X:put("HighStriker", 136, -70, -90, 1.7)
	for _, s in {{-150, -10, 90}, {140, -10, -60}, {-60, -96, 0}} do
		X:put("PopcornCart", s[1], s[2], s[3], 1.25, {shadows = false})
	end
	X:put("TicketBooth", 70, 114, 90, 1.35)

	-- bosque del borde (de la copia de seguridad: lo que quedaba fuera de la zona de juego)
	X:restore("Bosque", function(d, p)
		local tree = d.Name:find("Pine") or d.Name:find("Tree") or d.Name:find("Cypress")
		return tree and (math.abs(p.X) > 166 or math.abs(p.Z) > 136)
	end)

	-- atrezo en grupos (calabazas, cajas, globos) en los rincones y junto a las atracciones del fondo
	for _, r in {{-78, 18, 18}, {66, 14, 27}, {-112, 125, 18}, {96, -100, 22}, {-8, -118, 24}, {-10, -12, 16}, {-157, -96, 18}, {c.X, c.Y, 24},
		{-144, -50, 16}, {-64, -118, 10}, {104, 124, 32}, {70, 114, 8}, {-150, 20, 9}, {150, -40, 9}, {136, -70, 5}} do
		table.insert(busy, r)
	end
	local props = {{"PumpkinPile", 1.3}, {"PumpkinPile", 1.3}, {"BarrelStack", 1.1}, {"BalloonCart", 1.1}}
	local nProps = 0
	for _, g in {{-150, -128, 16, 5}, {40, -128, 18, 6}, {150, -128, 14, 4}, {-160, 60, 12, 4}, {160, 100, 12, 4}, {-30, 128, 16, 5},
		{30, 128, 14, 4}, {150, 5, 10, 3}, {-150, -75, 10, 3}, {-90, -128, 12, 3}} do
		nProps += X:cluster(props, g[1], g[2], g[3], g[4], busy, 6)
	end
	table.insert(log, "atrezo: " .. nProps)

	-- 5. luces: guirnaldas de bombillas a lo largo del camino (a un lado) y focos que barren el cielo
	local rides = {{-78, 18, 18}, {66, 14, 27}, {-112, 125, 16}, {96, -100, 22}, {-8, -118, 26}, {-10, -12, 16}, {-157, -96, 18}, {c.X, c.Y, 22}, {-144, -50, 16}, {-64, -118, 10}}
	local function clear(x, z)
		if not inside(V(x, 0, z), -3) then
			return false
		end
		for _, r in rides do
			if (Vector2.new(x, z) - Vector2.new(r[1], r[2])).Magnitude < r[3] then
				return false
			end
		end
		return true
	end
	local total, cum = 0, {0}
	for i = 2, #pts do
		total += (pts[i] - pts[i - 1]).Magnitude
		cum[i] = total
	end
	local function at(d)
		for i = 2, #pts do
			if cum[i] >= d then
				local k = (d - cum[i - 1]) / math.max(cum[i] - cum[i - 1], 1e-3)
				return pts[i - 1]:Lerp(pts[i], k), (pts[i] - pts[i - 1]).Unit
			end
		end
		return pts[#pts], (pts[#pts] - pts[#pts - 1]).Unit
	end
	local prev
	local nPoles = 0
	for d = 14, total - 16, 22 do
		local p, t = at(d)
		local side = Vector2.new(-t.Y, t.X) -- a la izquierda del camino
		local q = p + side * (X.width / 2 + 3.2)
		if clear(q.X, q.Y) and X:dist(q.X, q.Y) > X.width / 2 + 2.5 then
			local top = X:pole(q.X, q.Y, 11, P.BULBS[nPoles % #P.BULBS + 1])
			nPoles += 1
			local here = V(q.X, top - 0.3, q.Y)
			if prev and (here - prev).Magnitude < 34 then
				X:festoon(prev, here, 1.4, P.BULBS)
			end
			prev = here
		else
			prev = nil
		end
	end
	table.insert(log, "postes: " .. nPoles)
	X:searchlight(-160, 130, C(190, 90, 255), 30)
	X:searchlight(160, -132, C(120, 255, 140), 210)
	X:searchlight(-160, -132, C(255, 150, 60), 140)
	X:searchlight(150, 128, C(255, 80, 150), -40)
	return table.concat(log, " | ")
end

P.Ctx = Ctx
return P
