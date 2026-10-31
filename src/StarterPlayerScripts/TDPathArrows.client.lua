-- Tower Defense (cliente): flechas que recorren el camino enseñando por dónde vendrán los cazafantasmas.
-- Solo durante la preparación (fase "setup" de <mapa>.TD, antes de la primera oleada): salen de la entrada, viajan
-- por todo el camino del verde al rojo y se desvanecen al llegar a la casa. Al empezar la oleada 1 se apagan.
-- Las flechas fijas que traen los mapas (MapaTDS.Flechas) se esconden: estas las sustituyen.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local V, CF, ANG = Vector3.new, CFrame.new, CFrame.Angles

local SPEED = 15 -- studs por segundo
local GAP = 24 -- distancia entre grupos de flechas
local FADE_IN, FADE_OUT = 8, 14 -- studs al principio y al final del camino en los que aparecen y se desvanecen
local COLORS = { -- del verde (entrada) al rojo (la casa), como las de MapasRectos
	Color3.fromRGB(70, 255, 110), Color3.fromRGB(170, 255, 60), Color3.fromRGB(255, 232, 50), Color3.fromRGB(255, 150, 40), Color3.fromRGB(255, 56, 56),
}

local function colorAt(f)
	f = math.clamp(f, 0, 1) * (#COLORS - 1)
	local i = math.min(math.floor(f) + 1, #COLORS - 1)
	return COLORS[i]:Lerp(COLORS[i + 1], f - (i - 1))
end

-- El camino a ras del suelo: puntos de Camino con la altura de la tierra del camino debajo
local function track(map)
	local folder = map:WaitForChild("Camino", 20)
	if not folder then
		return nil
	end
	local pts = {}
	for _, p in folder:GetChildren() do
		local n = tonumber(p.Name)
		if n then
			pts[n] = p.Position
		end
	end
	if #pts < 2 then
		return nil
	end
	local tds = map:FindFirstChild("MapaTDS")
	local floor = {workspace.Terrain}
	for _, n in {"Camino", "Suelo"} do
		local f = tds and tds:FindFirstChild(n)
		if f then
			table.insert(floor, f)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = floor
	local cum = {0}
	for i, p in pts do
		local hit = workspace:Raycast(p + V(0, 4, 0), V(0, -12, 0), params)
		pts[i] = V(p.X, hit and hit.Position.Y + 0.07 or p.Y - 0.36, p.Z)
		if i > 1 then
			local d = pts[i] - pts[i - 1]
			cum[i] = cum[i - 1] + V(d.X, 0, d.Z).Magnitude
		end
	end
	return {pts = pts, cum = cum, total = cum[#pts], width = map:GetAttribute("PathWidth") or 9}
end

-- Punto del camino a d studs de la entrada (búsqueda binaria por los tramos)
local function at(t, d)
	local pts, cum = t.pts, t.cum
	d = math.clamp(d, 0, t.total)
	local lo, hi = 2, #pts
	while lo < hi do
		local mid = (lo + hi) // 2
		if cum[mid] < d then
			lo = mid + 1
		else
			hi = mid
		end
	end
	local seg = cum[lo] - cum[lo - 1]
	return pts[lo - 1]:Lerp(pts[lo], seg > 0 and (d - cum[lo - 1]) / seg or 1)
end

---------- Las flechas ----------
local live -- {map, track, folder, trains, parts, cfs, alpha, target}

local function hideStatic(map)
	local tds = map:FindFirstChild("MapaTDS")
	local f = tds and tds:FindFirstChild("Flechas")
	if f then
		for _, d in f:GetDescendants() do
			if d:IsA("BasePart") then
				d.Transparency = 1
			end
			if d:IsA("Light") then
				d.Enabled = false
			end
		end
	end
end

local function build(map, t)
	local folder = Instance.new("Folder")
	folder.Name = "FlechasCamino"
	local sc = t.width / 10
	local trains = {}
	local parts = {}
	for n = 0, math.floor(t.total / GAP) do
		local train = {offset = n * GAP, chevrons = {}}
		for k = 0, 2 do
			local ch = {back = k * 1.75 * sc, bars = {}}
			for _, sd in {-1, 1} do
				local bar = Instance.new("Part")
				bar.Name = "Flecha"
				bar.Anchored, bar.CanCollide, bar.CanQuery, bar.CanTouch, bar.CastShadow = true, false, false, false, false
				bar.Material = Enum.Material.Neon
				bar.Size = V(0.9 * sc, 0.12, 2.9 * sc)
				bar.Transparency = 1
				bar.Parent = folder
				table.insert(ch.bars, {part = bar, off = CF(sd * 0.9 * sc, 0, 0.68 * sc) * ANG(0, sd * math.rad(48), 0)})
				table.insert(parts, bar)
			end
			table.insert(train.chevrons, ch)
		end
		table.insert(trains, train)
	end
	folder.Parent = workspace
	return {map = map, track = t, folder = folder, trains = trains, parts = parts, cfs = table.create(#parts), alpha = 0, target = 1, clock = 0}
end

local function step(dt)
	local L = live
	if not L then
		return
	end
	-- fundido de todo el conjunto (aparecer al empezar la preparación, apagarse con la oleada); mientras colocas una
	-- tropa (TowerDefenseUI tiñe el camino: CaminoVista) se quedan casi apagadas para no tapar la huella
	local goal = L.target
	if goal > 0 and workspace:FindFirstChild("CaminoVista") then
		goal = 0.15
	end
	L.alpha += math.clamp(goal - L.alpha, -dt * 2.2, dt * 2.2)
	if L.target == 0 and L.alpha <= 0 then
		L.folder:Destroy()
		live = nil
		return
	end
	L.clock += dt
	local t = L.track
	local total = t.total
	local span = math.floor(total / GAP + 1) * GAP -- (vuelta completa: los grupos se reparten sin huecos al reiniciar)
	local pulse = 0.12 + 0.08 * math.sin(L.clock * 5)
	local n = 0
	for _, train in L.trains do
		local head = (train.offset + L.clock * SPEED) % span
		for _, ch in train.chevrons do
			local d = head - ch.back
			local vis = 0
			local cf = CF(0, -500, 0)
			if d > 0 and d < total then
				vis = math.min(1, d / FADE_IN, (total - d) / FADE_OUT)
				local p = at(t, d)
				local a, b = at(t, d - 1.6), at(t, d + 1.6)
				local dir = V(b.X - a.X, 0, b.Z - a.Z)
				if dir.Magnitude < 0.01 then
					dir = V(0, 0, -1)
				end
				cf = CFrame.lookAt(p, p + dir)
			end
			local color = colorAt(d / total)
			local tr = 1 - (1 - pulse) * vis * L.alpha
			for _, bar in ch.bars do
				n += 1
				L.cfs[n] = cf * bar.off
				local part = bar.part
				if part.Transparency ~= tr then
					part.Transparency = tr
				end
				part.Color = color
			end
		end
	end
	workspace:BulkMoveTo(L.parts, L.cfs, Enum.BulkMoveMode.FireCFrameChanged)
end
RunService.RenderStepped:Connect(step)

---------- Cuándo se ven: en tu mapa, mientras la partida está en preparación ----------
local bound -- conexiones del mapa actual
local function refresh(map, state)
	local show = state and state.Parent and state:GetAttribute("Active") and state:GetAttribute("Phase") == "setup"
	if show then
		if live and live.map ~= map then
			live.folder:Destroy()
			live = nil
		end
		if not live then
			local t = track(map)
			if t and t.total > 20 then
				live = build(map, t)
			end
		end
		if live then
			live.target = 1
		end
	elseif live then
		live.target = 0
	end
end

local function bindMap()
	if bound then
		for _, c in bound do
			c:Disconnect()
		end
		bound = nil
	end
	local id = player:GetAttribute("TDMap")
	local map = id and workspace:WaitForChild(id, 30)
	if not map or player:GetAttribute("TDMap") ~= id then
		refresh(nil, nil)
		return
	end
	hideStatic(map)
	local state = map:WaitForChild("TD", 30)
	if not state then
		return
	end
	bound = {
		state:GetAttributeChangedSignal("Phase"):Connect(function()
			refresh(map, state)
		end),
		state:GetAttributeChangedSignal("Active"):Connect(function()
			refresh(map, state)
		end),
	}
	refresh(map, state)
end
player:GetAttributeChangedSignal("TDMap"):Connect(bindMap)
task.spawn(bindMap)
