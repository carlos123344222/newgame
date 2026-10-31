-- Pasa los mapas del Tower Defense a caminos rectos (como en TDS) conservando todo lo demás: terreno, edificios y
-- decoración de los mapas de siempre (ServerStorage.Backup_MapasCurvos_2026_10_18). Quita el camino curvo y lo que lo
-- bordeaba, repinta el terreno donde estaba, allana una franja por el trazado nuevo (tramos rectos con esquinas en
-- chaflán) y monta el camino al nivel del suelo con su borde y flechas que van del verde al rojo.
-- Uso (barra de comandos, en edición):  local R = require(game.ServerStorage.MapasRectos)
--   R.load("CursedCastle")     -- el mapa antiguo en workspace (con su terreno), para mirarlo
--   R.convert("CursedCastle")  -- lo pasa a camino recto (definiciones en MapasRectosDefs)
--   R.store("CursedCastle")    -- lo guarda en ServerStorage.MapasTD (modelo + terreno)
local ServerStorage = game:GetService("ServerStorage")
local L = require(ServerStorage.MapasNuevosLib)

local Terrain = workspace.Terrain
local V, CF, ANG = Vector3.new, CFrame.new, CFrame.Angles
local V2 = Vector2.new
local C = Color3.fromRGB
local M = Enum.Material
local rad = math.rad

local R = {}
R.BACKUP = "Backup_MapasCurvos_2026_10_18"

---------- Cargar el mapa antiguo ----------
function R.load(id)
	local src = ServerStorage[R.BACKUP]:FindFirstChild(id)
	assert(src, "No hay copia del mapa " .. id)
	local old = workspace:FindFirstChild(id)
	if old then
		old:Destroy()
	end
	local region = src:FindFirstChild("Terreno")
	if region then
		local c = region:GetAttribute("Corner")
		Terrain:PasteRegion(region, Vector3int16.new(c.X, c.Y, c.Z), true)
	end
	local m = src:FindFirstChildOfClass("Model"):Clone()
	m.Parent = workspace
	return m
end

-- Mapa de ocupación en texto (celdas de 'cell' studs): # construcción, t árbol/decoración, ~ agua, . camino antiguo,
-- P plataforma/portal, ^ terreno alto. Para diseñar el trazado nuevo sin atravesar nada importante.
function R.ascii(id, cell)
	cell = cell or 8
	local m = workspace:FindFirstChild(id)
	local o = m:GetAttribute("Origin")
	local b = m:GetAttribute("Bounds")
	local x0, z0, x1, z1 = b.Min.X, b.Min.Y, b.Max.X, b.Max.Y
	local nx, nz = math.ceil((x1 - x0) / cell), math.ceil((z1 - z0) / cell)
	local grid = {}
	for iz = 1, nz do
		grid[iz] = table.create(nx, " ")
	end
	local prio = {[" "] = 0, ["^"] = 1, ["."] = 2, ["~"] = 3, t = 4, ["#"] = 5, P = 6}
	local function mark(lx, lz, ch)
		local ix, iz = math.floor((lx - x0) / cell) + 1, math.floor((lz - z0) / cell) + 1
		if ix >= 1 and ix <= nx and iz >= 1 and iz <= nz and prio[ch] > prio[grid[iz][ix]] then
			grid[iz][ix] = ch
		end
	end
	local function markBox(p, ch)
		local cf, s = p.CFrame, p.Size
		local hx, hz = s.X / 2, s.Z / 2
		for _, k in {{-1, -1}, {1, -1}, {-1, 1}, {1, 1}, {0, 0}} do
			local w = (cf * CF(k[1] * hx * 0.8, 0, k[2] * hz * 0.8)).Position
			local l = o:PointToObjectSpace(w)
			mark(l.X, l.Z, ch)
		end
		if s.X > cell * 1.5 or s.Z > cell * 1.5 then
			for u = -hx, hx, cell / 2 do
				for v = -hz, hz, cell / 2 do
					local l = o:PointToObjectSpace((cf * CF(u, 0, v)).Position)
					mark(l.X, l.Z, ch)
				end
			end
		end
	end
	local tds = m:FindFirstChild("MapaTDS")
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.95 then
			local ch
			if d:IsDescendantOf(m.Edificios) or (m:FindFirstChild("ReturnPortal") and d:IsDescendantOf(m.ReturnPortal)) then
				ch = "P"
			elseif tds and tds:FindFirstChild("Camino") and d:IsDescendantOf(tds.Camino) then
				ch = "."
			elseif d.Name == "Agua" then
				ch = "~"
			elseif (tds and tds:FindFirstChild("Arquitectura") and d:IsDescendantOf(tds.Arquitectura)) or (m:FindFirstChild("Atracciones") and d:IsDescendantOf(m.Atracciones)) then
				ch = (d.Size.Magnitude > 6) and "#" or "t"
			elseif tds and (d:IsDescendantOf(tds:FindFirstChild("Decoracion") or tds) or d:IsDescendantOf(tds:FindFirstChild("Rocas") or tds)) then
				ch = "t"
			end
			if ch and not (tds and tds:FindFirstChild("Flechas") and d:IsDescendantOf(tds.Flechas)) and d.Size.Magnitude < 400 then
				markBox(d, ch)
			end
		end
	end
	-- terreno: agua y zonas altas
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {Terrain}
	params.IgnoreWater = false
	for iz = 1, nz do
		for ix = 1, nx do
			local lx, lz = x0 + (ix - 0.5) * cell, z0 + (iz - 0.5) * cell
			local hit = workspace:Raycast(o:PointToWorldSpace(V(lx, 120, lz)), V(0, -260, 0), params)
			if hit then
				local y = o:PointToObjectSpace(hit.Position).Y
				if hit.Material == M.Water then
					mark(lx, lz, "~")
				elseif y > 3 then
					mark(lx, lz, "^")
				end
			end
		end
	end
	local lines = {}
	local head = "     "
	for ix = 1, nx do
		local x = x0 + (ix - 1) * cell
		head ..= (ix % 5 == 1) and string.format("%-5d", x):sub(1, 1) or " "
	end
	local scale = {}
	for ix = 1, nx, 5 do
		table.insert(scale, string.format("%d", x0 + (ix - 1) * cell))
	end
	table.insert(lines, "x cada 5 celdas desde " .. x0 .. ": " .. table.concat(scale, " "))
	for iz = 1, nz do
		table.insert(lines, string.format("%5d ", z0 + (iz - 1) * cell) .. table.concat(grid[iz]))
	end
	return table.concat(lines, "\n")
end

---------- Vista previa con la luz del mapa (solo en edición) ----------
---------- Utilidades ----------
local function segDist(q, a, b)
	local ab = b - a
	local k = math.clamp((q - a):Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
	return (a + ab * k - q).Magnitude
end
local function polyDist(pts, q)
	local best = math.huge
	for i = 2, #pts do
		best = math.min(best, segDist(q, pts[i - 1], pts[i]))
	end
	return best
end
R.polyDist = polyDist

-- Esquinas {x, z} -> polilínea con chaflanes de 45° (k studs en cada pata)
function R.chamfer(corners, k)
	local pts = {V2(corners[1][1], corners[1][2])}
	for i = 2, #corners - 1 do
		local a = V2(corners[i - 1][1], corners[i - 1][2])
		local p = V2(corners[i][1], corners[i][2])
		local b = V2(corners[i + 1][1], corners[i + 1][2])
		local kk = math.min(k, (p - a).Magnitude / 2 - 1, (b - p).Magnitude / 2 - 1)
		table.insert(pts, p + (a - p).Unit * kk)
		table.insert(pts, p + (b - p).Unit * kk)
	end
	local n = corners[#corners]
	table.insert(pts, V2(n[1], n[2]))
	return pts
end

local function lerpColors(list, t)
	t = math.clamp(t, 0, 1) * (#list - 1)
	local i = math.min(#list - 1, math.floor(t))
	return list[i + 1]:Lerp(list[i + 2], t - i)
end
R.ARROWS = {C(70, 255, 110), C(170, 255, 60), C(255, 232, 50), C(255, 150, 40), C(255, 56, 56)}

-- Caja (en planta, coordenadas locales) de una pieza o modelo: centro y radio
local function footprint(o, inst)
	local cf, size
	if inst:IsA("Model") then
		cf, size = inst:GetBoundingBox()
	else
		cf, size = inst.CFrame, inst.Size
	end
	local l = o:PointToObjectSpace(cf.Position)
	-- radio de la huella proyectada (la pieza puede estar girada)
	local rx = math.abs(cf.RightVector.X) * size.X + math.abs(cf.UpVector.X) * size.Y + math.abs(cf.LookVector.X) * size.Z
	local rz = math.abs(cf.RightVector.Z) * size.X + math.abs(cf.UpVector.Z) * size.Y + math.abs(cf.LookVector.Z) * size.Z
	return V2(l.X, l.Z), rx / 2, rz / 2, l.Y, size
end
R.footprint = footprint

-- Distancia de un rectángulo (centro c, semiejes hx, hz) a la polilínea, aproximada: la del centro menos el radio
-- menor y la del centro menos el mayor
local function boxDist(pts, c, hx, hz)
	return polyDist(pts, c) - math.min(hx, hz) * 0.9, polyDist(pts, c) - math.max(hx, hz)
end

-- Lo que se puede quitar del mapa: los hijos directos de las carpetas de decoración (modelos o piezas sueltas)
local function items(m)
	local list = {}
	local tds = m:FindFirstChild("MapaTDS")
	local folders = {}
	for _, n in {"Decoracion", "Rocas", "Arquitectura", "Cueva", "Estanque"} do
		local f = tds and tds:FindFirstChild(n)
		if f then
			table.insert(folders, f)
		end
	end
	if m:FindFirstChild("Atracciones") then
		table.insert(folders, m.Atracciones)
	end
	for _, f in folders do
		for _, c in f:GetChildren() do
			if c:IsA("Model") or c:IsA("BasePart") then
				table.insert(list, c)
			elseif c:IsA("Folder") then
				for _, cc in c:GetChildren() do
					if cc:IsA("Model") or cc:IsA("BasePart") then
						table.insert(list, cc)
					end
				end
			end
		end
	end
	return list
end
R.items = items

local function keep(def, inst, c)
	for _, n in def.keepNames or {} do
		if inst.Name == n then
			return true
		end
	end
	for _, r in def.keepBoxes or {} do
		if c.X > r[1] and c.X < r[3] and c.Y > r[2] and c.Y < r[4] then
			return true
		end
	end
	if inst:IsA("BasePart") and (inst.Name == "Agua" or inst.Transparency >= 0.98 or inst.Size.Magnitude > 220) then
		return true
	end
	return false
end

-- Lo que bordeaba los caminos viejos (faroles, vallas, postes, flechas...)
R.LINING = {"PathLantern", "WoodFence", "IronFence", "WallFence", "FencePillar", "LampPost", "LampDouble", "Valla", "Poste", "Farol", "Flechas",
	"CarnivalLamp", "Barandilla", "Pilar", "Antorcha", "Linterna", "Baliza", "Neon", "Borde", "Bordillo"}

---------- Convertir ----------
function R.convert(id)
	local Defs = require(script.Parent.MapasRectosDefs)
	local def = Defs[id]
	assert(def, "No hay definición para " .. id)
	local m = workspace:FindFirstChild(id) or R.load(id)
	local o = m:GetAttribute("Origin")
	local tds = m.MapaTDS
	local W = def.width or 9
	local half = W / 2
	local log = {}

	-- 1. el camino viejo: puntos, piezas, flechas y mallas
	local oldPts = {}
	for _, p in m.Camino:GetChildren() do
		local l = o:PointToObjectSpace(p.Position)
		oldPts[tonumber(p.Name)] = V2(l.X, l.Z)
	end
	local oldHalf = (m:GetAttribute("PathWidth") or 8) / 2
	m.Camino:ClearAllChildren()
	for _, n in {"Camino", "Flechas"} do
		local f = tds:FindFirstChild(n)
		if f then
			f:ClearAllChildren()
		end
	end
	for _, d in m:GetDescendants() do
		for _, n in def.removeNames or {} do
			if d.Name == n and d.Parent then
				d:Destroy()
			end
		end
	end
	local suelo = tds:FindFirstChild("Suelo")
	if not suelo then
		suelo = Instance.new("Folder")
		suelo.Name = "Suelo"
		suelo.Parent = tds
	end
	for _, p in suelo:GetChildren() do
		if p:IsA("BasePart") and p.Name == "Pasarela" then
			local l = o:PointToObjectSpace(p.Position)
			if polyDist(oldPts, V2(l.X, l.Z)) < oldHalf + 3 then
				p:Destroy()
			end
		end
	end

	-- (colores retocados: suelos más claros, para que el mapa se lea bien)
	if def.recolor then
		for _, d in m:GetDescendants() do
			local c = d:IsA("BasePart") and def.recolor[d.Name]
			if c then
				d.Color = c
			end
		end
	end

	-- 2. lo que bordeaba el camino viejo (faroles, vallas, postes...): fuera
	local pts = R.chamfer(def.path, def.chamfer or 6)
	local nOld, nNew = 0, 0
	for _, it in items(m) do
		if it.Parent then
			local c, hx, hz = footprint(o, it)
			if not keep(def, it, c) then
				local dOld = polyDist(oldPts, c)
				local small = math.max(hx, hz) < (def.liningMax or 7)
				local lining = table.find(def.liningNames or R.LINING, it.Name) ~= nil
				if small and ((lining and dOld < oldHalf + (def.liningGap or 5)) or dOld < oldHalf + 0.5) then
					it:Destroy()
					nOld += 1
				end
			end
		end
	end

	-- 3. lo que pisa el trazado nuevo: fuera (las construcciones grandes se avisan)
	local clear = half + (def.clear or 3)
	local big = {}
	for _, it in items(m) do
		if it.Parent then
			local c, hx, hz = footprint(o, it)
			if not keep(def, it, c) then
				local dNear, dFar = boxDist(pts, c, hx, hz)
				if dFar < clear and (dNear < clear or math.max(hx, hz) < 10) then
					if math.max(hx, hz) > (def.bigWarn or 9) then
						table.insert(big, string.format("%s(%d,%d r%d)", it.Name, c.X, c.Y, math.max(hx, hz)))
					end
					it:Destroy()
					nNew += 1
				end
			end
		end
	end
	table.insert(log, ("quitados: %d junto al camino viejo, %d sobre el nuevo"):format(nOld, nNew))
	if #big > 0 then
		table.insert(log, "grandes quitadas: " .. table.concat(big, ", "))
	end

	-- 4. repintar el terreno donde estaba el camino viejo
	if def.ground then
		for i = 1, #oldPts do
			local p = oldPts[i]
			local c = o:PointToWorldSpace(V(p.X, 0, p.Y))
			local r = oldHalf + 2
			local region = Region3.new(c - V(r, 12, r), c + V(r, 6, r)):ExpandToGrid(4)
			for _, from in def.oldMats or {M.Ground, M.Mud} do
				Terrain:ReplaceMaterial(region, 4, from, def.ground)
			end
		end
		task.wait()
	end

	-- 5. alturas del trazado (terreno y suelo, sin agua), suavizadas
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {Terrain, suelo}
	params.IgnoreWater = true
	local wparams = RaycastParams.new()
	wparams.FilterType = Enum.RaycastFilterType.Include
	local waters = {Terrain}
	for _, d in tds:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "Agua" or d.Name == "Mar") then
			table.insert(waters, d)
		end
	end
	wparams.FilterDescendantsInstances = waters
	wparams.IgnoreWater = false
	local STEP = 4
	local samples = {}
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local len = (b - a).Magnitude
		local n = math.max(1, math.floor(len / STEP + 0.5))
		for k = 0, n - 1 do
			table.insert(samples, {p = a:Lerp(b, k / n), seg = i})
		end
	end
	table.insert(samples, {p = pts[#pts], seg = #pts - 1})
	for _, s in samples do
		local top = o:PointToWorldSpace(V(s.p.X, 80, s.p.Y))
		local hit = workspace:Raycast(top, V(0, -200, 0), params)
		s.y = hit and o:PointToObjectSpace(hit.Position).Y or 0
		s.onPart = hit ~= nil and hit.Instance ~= Terrain
		local wh = workspace:Raycast(top, V(0, -200, 0), wparams)
		s.water = wh ~= nil and (wh.Material == M.Water or (wh.Instance ~= Terrain and (wh.Instance.Name == "Agua" or wh.Instance.Name == "Mar"))) and not s.onPart
		if s.water then
			s.waterY = o:PointToObjectSpace(wh.Position).Y
		end
	end
	-- (sobre el agua, el camino va a la altura de la orilla)
	local flat = def.flatY
	for _, s in samples do
		if flat then
			s.h = flat
		elseif s.water then
			s.h = math.max(s.waterY + 1, 0)
		else
			s.h = s.y
		end
	end
	if not flat then
		for _ = 1, 3 do
			local hs = {}
			for i = 1, #samples do
				local sum, n = 0, 0
				for j = math.max(1, i - 3), math.min(#samples, i + 3) do
					sum += samples[j].h
					n += 1
				end
				hs[i] = sum / n
			end
			for i, s in samples do
				s.h = hs[i]
			end
		end
	end

	-- 6. allanar el terreno por la franja del camino
	local style = def.style or {}
	local fw = W + 2 * (style.edge or 1.8) + 6
	local mat = def.under or M.Ground
	for i, s in samples do
		local nxt = samples[math.min(#samples, i + 1)]
		local prv = samples[math.max(1, i - 1)]
		local dir = (nxt.p - prv.p)
		if dir.Magnitude < 1e-3 then
			dir = V2(1, 0)
		end
		dir = dir.Unit
		local yaw = math.deg(math.atan2(dir.X, dir.Y))
		local cf = o * CF(s.p.X, 0, s.p.Y) * ANG(0, rad(yaw), 0)
		Terrain:FillBlock(cf * CF(0, s.h + 29.5, 0), V(fw, 60, STEP + 3), M.Air)
		if not s.water and not s.onPart then
			Terrain:FillBlock(cf * CF(0, s.h - 2 - 4, 0), V(fw - 2, 8, STEP + 3), mat)
			-- (sin hierba bajo el camino: las briznas del terreno asomarían entre las piedras)
			local c = o:PointToWorldSpace(V(s.p.X, s.h, s.p.Y))
			local r = W / 2 + 1
			local region = Region3.new(c - V(r, 6, r), c + V(r, 4, r)):ExpandToGrid(4)
			for _, from in {M.Grass, M.LeafyGrass} do
				Terrain:ReplaceMaterial(region, 4, from, mat)
			end
		end
		if i % 20 == 0 then
			task.wait()
		end
	end

	-- 7. el camino: borde, firme, franja, puentes, flechas y puntos para los enemigos
	local B = setmetatable({model = m, O = o, pending = {}, count = 0, F = {Ruta = tds.Camino, Suelo = suelo, Arq = tds:FindFirstChild("Arquitectura") or tds, Flechas = tds:FindFirstChild("Flechas") or tds, Deco = tds:FindFirstChild("Decoracion") or tds, TDS = tds}, rng = Random.new(def.seed or 5)}, L)
	B.avoid, B.pathPts, B.width = {}, pts, W
	R.B = B
	local E = W + 2 * (style.edge or 1.8)
	local function piece(props, parent)
		local p = Instance.new("Part")
		p.Anchored, p.CanTouch, p.CastShadow = true, false, false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		for k, v in props do
			p[k] = v
		end
		return B:add(p, parent)
	end
	local turnTan = {}
	for i = 2, #pts - 1 do
		local d1, d2 = (pts[i] - pts[i - 1]).Unit, (pts[i + 1] - pts[i]).Unit
		turnTan[i] = math.tan(math.acos(math.clamp(d1:Dot(d2), -1, 1)) / 2)
	end
	for i = 1, #samples - 1 do
		local s, t = samples[i], samples[i + 1]
		local a3 = o:PointToWorldSpace(V(s.p.X, s.h, s.p.Y))
		local b3 = o:PointToWorldSpace(V(t.p.X, t.h, t.p.Y))
		local len = (b3 - a3).Magnitude
		if len > 0.05 then
			-- en los vértices se alarga un poco para tapar la esquina
			local e0 = (samples[i - 1] == nil or samples[i - 1].seg ~= s.seg) and (turnTan[s.seg] or 0) or 0
			local e1 = (t.seg ~= s.seg or i + 1 == #samples) and (turnTan[s.seg + 1] or 0) or 0
			local look = CFrame.lookAt((a3 + b3) / 2, b3)
			local function band(width, y, props, parent)
				local x0, x1 = e0 * width / 2, e1 * width / 2
				local p = table.clone(props)
				p.Size = V(width, props.Size.Y, len + x0 + x1)
				p.CFrame = look * CF(0, y, (x1 - x0) / 2 * -1)
				return piece(p, parent)
			end
			local alt = (s.seg % 2) * 0.006
			local ecol = style.edgeColor or C(70, 64, 86)
			if style.edgeColor2 and i % 2 == 0 then
				ecol = style.edgeColor2 -- (borde a rayas: feria)
			end
			band(E, -0.05 + alt, {Name = "Borde", Size = V(0, 1, 0), Material = style.edgeMat or M.Slate, Color = ecol, CanCollide = true}, B.F.Ruta)
			band(W, 0.08 + alt, {Name = "Tierra", Size = V(0, 1, 0), Material = style.mat or M.Ground, Color = style.color or C(122, 86, 58), CanCollide = true}, B.F.Ruta)
			if style.band then
				band(W * 0.4, 0.6 + alt, {Name = "Franja", Size = V(0, 0.05, 0), Material = style.bandMat or style.mat or M.Ground, Color = style.band, CanCollide = false, CanQuery = false}, B.F.Ruta)
			end
			-- puente sobre el agua: tablones, postes y barandilla
			if s.water or t.water then
				local wood, post = style.deck or C(104, 78, 54), style.post or C(64, 48, 36)
				local wy = s.waterY or t.waterY or (s.h - 2)
				local deckH = math.max(1.2, s.h - wy + 1.5)
				piece({Name = "Puente", Size = V(W + 2.4, 0.8, len + 0.6), CFrame = look * CF(0, -0.1, 0), Material = M.WoodPlanks, Color = wood, CanCollide = true}, B.F.Suelo)
				for _, sd in {-1, 1} do
					piece({Name = "Poste", Size = V(0.8, deckH + 3, 0.8), CFrame = look * CF(sd * (E / 2 + 0.6), -deckH / 2 + 1, 0), Material = M.Wood, Color = post, CanCollide = true}, B.F.Arq)
					piece({Name = "Barandilla", Size = V(0.35, 0.35, len + 0.4), CFrame = look * CF(sd * (E / 2 + 0.6), 2.2, 0), Material = M.Wood, Color = post, CanCollide = true}, B.F.Arq)
				end
			end
		end
		if i % 60 == 0 then
			B:flush()
		end
	end
	B:flush()
	-- puntos para los enemigos (cada ~8 studs y en cada vértice)
	local wp = {}
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local n = math.max(1, math.floor((b - a).Magnitude / 8 + 0.5))
		for k = 0, n - 1 do
			table.insert(wp, a:Lerp(b, k / n))
		end
	end
	table.insert(wp, pts[#pts])
	local function hAt(p)
		local best, bd = 0, math.huge
		for _, s in samples do
			local d = (s.p - p).Magnitude
			if d < bd then
				best, bd = s.h, d
			end
		end
		return best
	end
	R.hAt = hAt
	for i, p in wp do
		local pt = Instance.new("Part")
		pt.Name = tostring(i)
		pt.Anchored, pt.CanCollide, pt.CanQuery, pt.CanTouch, pt.CastShadow = true, false, false, false, false
		pt.Transparency = 1
		pt.Size = Vector3.one
		pt.CFrame = o * CF(p.X, hAt(p) + 1, p.Y)
		pt.Parent = m.Camino
	end
	m:SetAttribute("EnemySpawn", o * CF(wp[1].X, hAt(wp[1]) + 1, wp[1].Y))
	m:SetAttribute("Goal", o * CF(wp[#wp].X, hAt(wp[#wp]), wp[#wp].Y))
	m:SetAttribute("PathWidth", W)
	R.pts, R.samples = pts, samples

	-- flechas de neón (">>>") del verde al rojo
	local total = 0
	local cum = {0}
	for i = 2, #pts do
		total += (pts[i] - pts[i - 1]).Magnitude
		cum[i] = total
	end
	local every = def.arrowEvery or 22
	local dist = every * 0.6
	local sc = W / 10
	while dist < total - 10 do
		local i = 2
		while cum[i] < dist do
			i += 1
		end
		local a, b = pts[i - 1], pts[i]
		local segLen = cum[i] - cum[i - 1]
		local into = dist - cum[i - 1]
		if segLen >= 12 and into > 4 and segLen - into > 4 then
			local p = a:Lerp(b, into / segLen)
			local d = (b - a).Unit
			local h = hAt(p)
			local col = lerpColors(def.arrowColors or R.ARROWS, dist / total)
			local look = CFrame.lookAt(o:PointToWorldSpace(V(p.X, h + 0.64, p.Y)), o:PointToWorldSpace(V(p.X + d.X * 2, hAt(p + d * 2) + 0.64, p.Y + d.Y * 2)))
			for k = -1, 1 do
				for _, sd in {-1, 1} do
					local bar = piece({
						Name = "Flecha", Size = V(0.9 * sc, 0.12, 2.9 * sc), Material = M.Neon, Color = col, CanCollide = false, CanQuery = false,
						CFrame = look * CF(0, 0, -k * 1.75 * sc) * CF(sd * 0.9 * sc, 0, 0.68 * sc) * ANG(0, sd * rad(48), 0),
					}, B.F.Flechas)
				end
			end
			dist += every
		else
			dist += 3
		end
	end
	B:flush()

	-- 8. lo propio de cada mapa (faroles, vallas, más decoración) y relleno de los huecos vacíos
	if def.decor then
		def.decor(B, R, pts)
	end
	B:flush()
	local nFill = 0
	for _, f in def.fill or {} do
		nFill += R.fill(B, f)
	end
	if nFill > 0 then
		table.insert(log, "añadidos: " .. nFill)
	end

	-- 9. que la decoración tenga hitbox y luces que no manchen el suelo
	table.insert(log, "con hitbox: " .. R.hitboxes(m))
	table.insert(log, "luces suavizadas: " .. R.tame(m))
	print(("MapasRectos: %s. %s"):format(id, table.concat(log, " | ")))
	return table.concat(log, "\n")
end

-- Rellena los huecos vacíos del mapa con modelos del kit. f: {names, n, smin, smax, gap (al camino), space (radio
-- libre alrededor), box = {x0, z0, x1, z1} (zona; por defecto los límites del mapa), y (giro fijo), collide}
function R.fill(B, f)
	local m, o = B.model, B.O
	local b = m:GetAttribute("Bounds")
	local box = f.box or {b.Min.X + 6, b.Min.Y + 6, b.Max.X - 6, b.Max.Y - 6}
	local rng = B.rng
	local half = B.width / 2
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = {Terrain, m:FindFirstChild("Limites"), m.Camino}
	local wparams = RaycastParams.new()
	wparams.FilterType = Enum.RaycastFilterType.Include
	wparams.FilterDescendantsInstances = {Terrain}
	wparams.IgnoreWater = false
	local placed, tries = 0, 0
	while placed < f.n and tries < f.n * 25 do
		tries += 1
		local x, z = rng:NextNumber(box[1], box[3]), rng:NextNumber(box[2], box[4])
		local q = V2(x, z)
		if polyDist(B.pathPts, q) > half + (f.gap or 7) then
			local top = o:PointToWorldSpace(V(x, 90, z))
			local wh = workspace:Raycast(top, V(0, -200, 0), wparams)
			local y = wh and o:PointToObjectSpace(wh.Position).Y or 0
			local dry = not wh or wh.Material ~= M.Water
			if dry and y > (f.minY or -6) and y < (f.maxY or 14) then
				local probe = o:PointToWorldSpace(V(x, y + 3, z))
				local busy = false
				for _, hit in workspace:GetPartBoundsInRadius(probe, f.space or 4, op) do
					-- (no cuentan los suelos y volúmenes enormes: niebla, chispas, losas)
					if hit.Size.Magnitude < 120 and hit.Transparency < 0.95 then
						busy = true
						break
					end
				end
				if not busy then
					local name = f.names[rng:NextInteger(1, #f.names)]
					local mm = B:kit(name, x, z, f.yaw or rng:NextNumber(0, 360), rng:NextNumber(f.smin or 1, f.smax or 1), B.F.Deco, nil, {noCollide = false, color = f.color})
					if mm then
						B:flush() -- (para que la siguiente comprobación ya lo vea)
						placed += 1
					end
				end
			end
		end
	end
	return placed
end

-- Las piezas de la decoración chocan (no se atraviesan y no dejan poner tropas encima). Se quedan sin chocar el agua, lo
-- transparente, las llamas y luces de neón pequeñas y lo diminuto (flores, briznas).
function R.hitboxes(m)
	local n = 0
	local tds = m:FindFirstChild("MapaTDS")
	local roots = {}
	for _, name in {"Decoracion", "Rocas", "Arquitectura", "Cueva", "Estanque"} do
		local f = tds and tds:FindFirstChild(name)
		if f then
			table.insert(roots, f)
		end
	end
	for _, name in {"Atracciones", "Edificios"} do
		local f = m:FindFirstChild(name)
		if f then
			table.insert(roots, f)
		end
	end
	for _, r in roots do
		for _, d in r:GetDescendants() do
			if d:IsA("BasePart") and not d.CanCollide then
				local s = d.Size
				local tiny = s.X * s.Y * s.Z < 0.6 or math.max(s.X, s.Y, s.Z) < 1
				local skip = d.Transparency >= 0.6 or d.Name == "Agua" or d.Name == "Flecha" or tiny
					or (d.Material == M.Neon and s.Magnitude < 4) or d:FindFirstChildOfClass("Fire") ~= nil or d:FindFirstChildOfClass("ParticleEmitter") ~= nil
				if not skip then
					d.CanCollide = true
					d.CanQuery = true
					n += 1
				end
			end
		end
	end
	return n
end

-- Pinta de hierba las manchas de tierra/barro del terreno (bloques de 8 studs) que estén a más de 'margin' del camino:
-- el campo queda verde y limpio, como en las fotos. Deja la tierra bajo el camino (que no asome la hierba).
function R.regrass(B, pts, margin, from, to)
	local o = B.O
	local b = B.model:GetAttribute("Bounds")
	local half = B.width / 2
	local n = 0
	for x = b.Min.X - 8, b.Max.X + 8, 8 do
		for z = b.Min.Y - 8, b.Max.Y + 8, 8 do
			if polyDist(pts, V2(x, z)) > half + (margin or 8) then
				local c = o:PointToWorldSpace(V(x, 0, z))
				local region = Region3.new(c - V(4, 8, 4), c + V(4, 8, 4)):ExpandToGrid(4)
				for _, mat in from or {M.Ground, M.Mud} do
					Terrain:ReplaceMaterial(region, 4, mat, to or M.Grass)
				end
				n += 1
			end
		end
		task.wait()
	end
	return n
end

-- Las luces de los adornos pequeños (setas, calabazas, braseros) en grande dejaban manchas de color por todo el
-- suelo: se quedan cortas y suaves. Las flechas no llevan luz.
R.TAME = {Mushrooms = {6, 0.35}, JackOLantern = {8, 0.9}, Pumpkin = {7, 0.7}, Brazier = {16, 1.3}, Candles = {8, 0.8}, Candles2 = {8, 0.8}, PathLantern = {14, 1}}
function R.tame(m)
	local n = 0
	for _, l in m:GetDescendants() do
		if l:IsA("Light") then
			if l.Parent and l.Parent.Name == "Flecha" then
				l:Destroy()
				n += 1
			else
				local mdl = l:FindFirstAncestorWhichIsA("Model")
				local t = mdl and R.TAME[mdl.Name]
				if t and (l.Range > t[1] or l.Brightness > t[2]) then
					l.Range, l.Brightness = math.min(l.Range, t[1]), math.min(l.Brightness, t[2])
					n += 1
				end
			end
		end
	end
	return n
end

-- Guarda el mapa (modelo + terreno de su celda) en ServerStorage.MapasTD
function R.store(id)
	return L.store(id)
end

---------- Vista previa ----------
local LKEYS = {"ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "ExposureCompensation"}
local AKEYS = {"Color", "Decay", "Density", "Haze", "Glare"}
function R.light(id)
	local Lighting = game:GetService("Lighting")
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if not Lighting:GetAttribute("__saved") then
		Lighting:SetAttribute("__saved", true)
		for _, k in LKEYS do
			Lighting:SetAttribute("__" .. k, Lighting[k])
		end
		for _, k in AKEYS do
			Lighting:SetAttribute("__a" .. k, atm[k])
		end
	end
	local c = game.ReplicatedStorage.TowerDefense:Clone()
	c.Parent = game.ReplicatedStorage
	local TD = require(c)
	c:Destroy()
	local l = TD.mapInfo(id).light or {}
	for _, k in LKEYS do
		local v = l[k]
		if v == nil then
			v = Lighting:GetAttribute("__" .. k)
		end
		Lighting[k] = v
	end
	for _, k in AKEYS do
		atm[k] = l.atmos and l.atmos[k] or Lighting:GetAttribute("__a" .. k)
	end
	local g = Lighting:FindFirstChild("__TDGradePreview") or Instance.new("ColorCorrectionEffect")
	g.Name = "__TDGradePreview"
	g.Saturation, g.Contrast, g.Brightness, g.TintColor = 0.15, 0.08, 0, Color3.new(1, 1, 1)
	for k, v in l.grade or {} do
		g[k] = v
	end
	g.Parent = Lighting
end

function R.unlight()
	local Lighting = game:GetService("Lighting")
	if not Lighting:GetAttribute("__saved") then
		return
	end
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	for _, k in LKEYS do
		Lighting[k] = Lighting:GetAttribute("__" .. k)
		Lighting:SetAttribute("__" .. k, nil)
	end
	for _, k in AKEYS do
		atm[k] = Lighting:GetAttribute("__a" .. k)
		Lighting:SetAttribute("__a" .. k, nil)
	end
	Lighting:SetAttribute("__saved", nil)
	local g = Lighting:FindFirstChild("__TDGradePreview")
	if g then
		g:Destroy()
	end
end

return R
