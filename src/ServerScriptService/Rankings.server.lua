-- Rankings: los tableros de la plaza (Mapa.Plaza.Rankings: Top Scarers, Highest Level, Most Loved Houses y Endless
-- Legends) con los TOP mejores del mes (Highest Level: de siempre, nivel 1..100), y la Casa del día: el cartel del arco
-- de la plaza y una corona sobre su tejado.
-- Aquí solo se calculan las listas: cada tablero lleva los atributos BoardKind, BoardTitle, BoardIcon, BoardSub y Rows
-- (JSON: {{i = userId, n = nombre, s = cifra}, ...}) y cada cliente los dibuja (RankingsUI.client: con desplazamiento,
-- rueda del ratón o arrastrando, que en un SurfaceGui solo funciona si es del cliente).
-- El tablero que en Studio tiene Kind = "XP" (antes "Most Experience") ahora es el de nivel ("Level").
-- Datos: OrderedDataStore "R1_<tablero>_<mes>" ("R1_Level_All" para el de nivel: experiencia total, que ordena igual
-- que el nivel) y "Perfiles1" (nombre y nivel), que escribe Juego al guardar. A eso se
-- suman los jugadores del servidor con sus atributos M_* (lo de esta sesión aunque aún no se haya guardado; en Studio,
-- solo eso). La Casa del día sale de los atributos TodayScared y TodayLikes de las casas de este servidor.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")
local CollectionService = game:GetService("CollectionService")

local TD = require(RS.TowerDefense)
local Config = require(RS.Config)
local plaza = workspace:WaitForChild("Mapa"):WaitForChild("Plaza")
local boards = plaza:WaitForChild("Rankings")
local Casas = workspace:WaitForChild("Casas")
local REFRESH = 120 -- segundos entre lecturas de los DataStore
local TOP = 50 -- jugadores que se ven en cada tablero (se desplaza para ver más allá de los primeros)

-- Cada tablero: qué cuenta, su icono y cómo se escribe la cifra
local KINDS = {
	Scared = {attr = "M_Scared", icon = "trophy", stat = "Scared"},
	Level = {attr = "PXP", icon = "star", stat = "Level", title = "Highest Level", allTime = true},
	Likes = {attr = "M_Likes", icon = "thumb", stat = "Likes"},
	Endless = {attr = "M_Endless", icon = "skull", stat = "Wave"},
}
local ALIASES = {XP = "Level"} -- (Kind de los tableros ya puestos en Studio)
local MONTHS = {"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"}
local WHITE, INK = Color3.new(1, 1, 1), Color3.fromRGB(16, 10, 22)

local function fmt(n)
	local s, k = tostring(math.floor(n)), 0
	repeat
		s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return s
end

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function outline(o, t, color)
	return new("UIStroke", {Color = color or INK, Thickness = t or 2, LineJoinMode = Enum.LineJoinMode.Round, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual}, o)
end

---------- Tableros ----------
local ui = {} -- [tablero] = {kind, rows (último JSON enviado)}
for _, b in boards:GetChildren() do
	local kindName = ALIASES[b:GetAttribute("Kind")] or b:GetAttribute("Kind")
	local kind = KINDS[kindName]
	local panel = b:FindFirstChild("Panel")
	if not (kind and panel) then
		continue
	end
	local old = panel:FindFirstChild("Lista") -- (la interfaz que antes hacía el servidor)
	if old then
		old:Destroy()
	end
	b:SetAttribute("BoardKind", kindName)
	b:SetAttribute("BoardTitle", kind.title or b:GetAttribute("Title") or "")
	b:SetAttribute("BoardIcon", kind.icon)
	ui[b] = {kind = kindName}
end

---------- Datos ----------
local okProfiles, profiles = pcall(DataStoreService.GetDataStore, DataStoreService, "Perfiles1")
local profileCache = {} -- [userId] = {n, lv, at}
local function profile(id)
	local c = profileCache[id]
	if c and os.clock() - c.at < 600 then
		return c
	end
	local plr = Players:GetPlayerByUserId(id)
	local n, lv
	local failed = false
	if plr then
		n, lv = plr.Name, plr:FindFirstChild("leaderstats") and plr.leaderstats:FindFirstChild("Level") and plr.leaderstats.Level.Value
	elseif okProfiles then
		-- (con 4 tableros de TOP filas son muchas lecturas: si queda poco cupo de DataStore, se deja para luego y se
		-- usa lo que ya se sabía; las partidas de los jugadores tienen prioridad)
		if DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.GetAsync) < 20 then
			if c then
				c.at = os.clock() - 540
				return c
			end
			failed = true
		else
			local ok, p = pcall(profiles.GetAsync, profiles, "u" .. id)
			if ok and typeof(p) == "table" then
				n, lv = p.n, p.lv
			end
			failed = not ok
		end
	end
	if not n then
		local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, id)
		n = ok and name or ("Player " .. id)
	end
	c = {n = n, lv = lv or 1, at = os.clock() - (failed and 540 or 0)} -- (si falló la lectura, se reintenta en 1 min)
	profileCache[id] = c
	return c
end

local stores = {}
local function sorted(kind, month, n)
	local key = ("R1_%s_%s"):format(kind, month)
	stores[key] = stores[key] or DataStoreService:GetOrderedDataStore(key)
	local ok, page = pcall(function()
		return stores[key]:GetSortedAsync(false, n or TOP):GetCurrentPage()
	end)
	return ok and page or {}
end

local cache = {} -- [tipo] = {[userId] = valor} (lo último leído del DataStore)
local function monthNow()
	return os.date("!%Y-%m"), os.date("!*t")
end

local function statText(kind, v, lv)
	if kind == "Endless" then
		local info = TD.MAPS[v % 100]
		return ("<b>Wave %d</b>   %s"):format(v // 100, info and info.name or "")
	end
	if kind == "Level" then
		local level, into, need = Config.playerLevelOf(v)
		if need == 0 then
			return ("<b>Level %d</b>   MAX"):format(level)
		end
		if into == 0 then
			return ("<b>Level %d</b>"):format(level) -- (sacado de su perfil: no se sabe cuánto lleva del siguiente)
		end
		return ("<b>Level %d</b>   %d%% to next"):format(level, math.floor(into / need * 100))
	end
	return ("%s: <b>%s</b>    Level: <b>%d</b>"):format(KINDS[kind].stat, fmt(v), lv)
end

local function draw()
	local _, t = monthNow()
	for b, u in ui do
		-- lo guardado y lo de los jugadores que están aquí (el mayor de los dos)
		local values = table.clone(cache[u.kind] or {})
		for _, plr in Players:GetPlayers() do
			local v = plr:GetAttribute(KINDS[u.kind].attr) or 0
			if v > (values[plr.UserId] or 0) then
				values[plr.UserId] = v
			end
		end
		local list = {}
		for id, v in values do
			if v > 0 then
				table.insert(list, {id = id, v = v})
			end
		end
		table.sort(list, function(a, c)
			return a.v > c.v
		end)
		local rows = {}
		for i = 1, math.min(#list, TOP) do
			local e = list[i]
			local p = profile(e.id)
			rows[i] = {i = e.id, n = p.n, s = statText(u.kind, e.v, p.lv)}
		end
		local json = HttpService:JSONEncode(rows)
		if json ~= u.rows then
			u.rows = json
			b:SetAttribute("Rows", json)
		end
		b:SetAttribute("BoardSub", KINDS[u.kind].allTime and "All time" or ("%s %d"):format(MONTHS[t.month], t.year))
	end
end

-- Los que salían en el antiguo "Most Experience" (de octubre de 2026 en adelante) y aún no están en el tablero de nivel
-- (la migración de Juego todavía no ha llegado a ellos, o es Studio, donde no se escribe nada): se meten con el nivel de
-- su perfil ("Perfiles1"), como si tuvieran justo la experiencia de ese nivel.
local XP_SINCE = {year = 2026, month = 10}
local function oldPlayers(values)
	local t = os.date("!*t")
	local y, m = XP_SINCE.year, XP_SINCE.month
	while y < t.year or (y == t.year and m <= t.month) do
		for _, e in sorted("XP", ("%04d-%02d"):format(y, m), 30) do
			local id = tonumber(tostring(e.key):match("^u(%d+)$"))
			if id and not values[id] then
				values[id] = math.max(1, Config.pxpTotal(profile(id).lv))
			end
		end
		y, m = m == 12 and y + 1 or y, m % 12 + 1
	end
end

local function fetch()
	local month = monthNow()
	for kind, info in KINDS do
		local values = {}
		for _, e in sorted(kind, info.allTime and "All" or month, TOP) do
			local id = tonumber(tostring(e.key):match("^u(%d+)$"))
			if id then
				values[id] = e.value
			end
		end
		if kind == "Level" then
			oldPlayers(values)
		end
		cache[kind] = values
	end
end

---------- Casa del día: la placa que cuelga bajo el arco de la plaza y la corona del tejado ----------
local arch = workspace.Mapa:FindFirstChild("Calle") and workspace.Mapa.Calle:FindFirstChild("Arco")
local plaque = arch and arch:FindFirstChild("CartelCasaDelDia")
local sign = plaque and plaque:FindFirstChild("Placa")
local signUI = {}
if sign then
	for _, face in {Enum.NormalId.Front, Enum.NormalId.Back} do
		local g = new("SurfaceGui", {
			Name = "CasaDelDia" .. face.Name, Face = face, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 50, LightInfluence = 0,
			Brightness = 1.2, MaxDistance = 220, ZOffset = 1,
		}, sign)
		local top = new("TextLabel", {
			Position = UDim2.fromScale(0, 0.04), Size = UDim2.fromScale(1, 0.4), BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, TextScaled = true,
			TextColor3 = Color3.fromRGB(255, 212, 60), Text = "HOUSE OF THE DAY",
		}, g)
		outline(top, 3)
		local name = new("TextLabel", {
			Position = UDim2.fromScale(0.03, 0.44), Size = UDim2.fromScale(0.94, 0.32), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true,
			TextColor3 = WHITE, Text = "",
		}, g)
		outline(name, 2.5)
		local sub = new("TextLabel", {
			Position = UDim2.fromScale(0.05, 0.76), Size = UDim2.fromScale(0.9, 0.2), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextScaled = true,
			TextColor3 = Color3.fromRGB(236, 226, 214), Text = "",
		}, g)
		outline(sub, 1.5)
		table.insert(signUI, {name = name, sub = sub})
	end
end

local crownT = ServerStorage:WaitForChild("ModelosNuevos"):WaitForChild("Corona")
local crown -- la corona que flota sobre la Casa del día (la hace girar cada cliente: Eventos)
local crownHouse
local function makeCrown()
	local m = crownT:Clone()
	m.Name = "CoronaDelDia"
	m:ScaleTo(2.4)
	local body = m:FindFirstChildWhichIsA("BasePart", true)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		end
	end
	new("PointLight", {Color = Color3.fromRGB(255, 210, 90), Range = 30, Brightness = 3}, body)
	local a = new("Attachment", {Name = "Aura"}, body)
	new("ParticleEmitter", {
		Name = "Chispas", Texture = "rbxasset://textures/particles/sparkles_main.dds", LightEmission = 1, LightInfluence = 0,
		Color = ColorSequence.new(Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 170, 40)), Rate = 22,
		Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0)}),
	}, a)
	-- haz de luz dorado del tejado al cielo
	local b0 = new("Attachment", {Name = "Haz0", Position = Vector3.new(0, -14, 0)}, body)
	local b1 = new("Attachment", {Name = "Haz1", Position = Vector3.new(0, 60, 0)}, body)
	new("Beam", {
		Attachment0 = b0, Attachment1 = b1, Width0 = 7, Width1 = 2, FaceCamera = true, LightEmission = 1, LightInfluence = 0,
		Color = ColorSequence.new(Color3.fromRGB(255, 226, 120)), Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.5, 0.75), NumberSequenceKeypoint.new(1, 1),
		}),
	}, body)
	CollectionService:AddTag(m, "SpinCrown")
	return m
end

local function houseOfDay()
	local best, bestScore
	for _, h in Casas:GetChildren() do
		if (h:GetAttribute("Owner") or 0) ~= 0 then
			local score = (h:GetAttribute("TodayScared") or 0) + (h:GetAttribute("TodayLikes") or 0) * 3
			if score > 0 and (not bestScore or score > bestScore) then
				best, bestScore = h, score
			end
		end
	end
	for _, s in signUI do
		if best then
			s.name.Text = best:GetAttribute("HouseName") or "?"
			s.sub.Text = ("👻 %s scared today  ·  👍 %d"):format(fmt(best:GetAttribute("TodayScared") or 0), best:GetAttribute("TodayLikes") or 0)
		else
			s.name.Text = "Up for grabs!"
			s.sub.Text = "Scare the most visitors today to win the crown"
		end
	end
	for _, h in Casas:GetChildren() do
		h:SetAttribute("HouseOfDay", h == best or nil)
	end
	if best ~= crownHouse or (crown and not crown.Parent) then
		crownHouse = best
		if crown then
			crown:Destroy()
			crown = nil
		end
		if best then
			crown = makeCrown()
			-- sobre el tejado, en el centro de la casa (sin el jardín)
			-- apoyada sobre el tejado: un rayo desde arriba sobre la fachada busca lo más alto de la casa (sin el jardín)
			local origin = best:GetAttribute("Origin")
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			local inc = {}
			for _, name in {"Roof", "Exterior", "Shell"} do
				if best:FindFirstChild(name) then
					table.insert(inc, best[name])
				end
			end
			params.FilterDescendantsInstances = inc
			local roofY = origin.Y + 22
			for _, d in {6, 10, 14} do
				local p = (origin * CFrame.new(0, 0, -d)).Position
				local hit = workspace:Raycast(Vector3.new(p.X, origin.Y + 120, p.Z), Vector3.new(0, -140, 0), params)
				if hit then
					roofY = math.max(roofY, hit.Position.Y)
				end
			end
			local p = (origin * CFrame.new(0, 0, -10)).Position
			crown:PivotTo(CFrame.new(p.X, roofY + 4.5, p.Z))
			crown.Parent = best
		end
	end
end

---------- Bucle ----------
task.spawn(function()
	while true do
		pcall(fetch)
		for _ = 1, REFRESH / 10 do
			local ok, err = pcall(draw)
			if not ok then
				warn("Rankings: " .. tostring(err))
			end
			task.wait(10)
		end
	end
end)
task.spawn(function()
	while true do
		local ok, err = pcall(houseOfDay)
		if not ok then
			warn("Casa del día: " .. tostring(err))
		end
		task.wait(5)
	end
end)
