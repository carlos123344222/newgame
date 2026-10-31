-- Tower Defense: mini lobbies. Cada pabellón de workspace.Mapa.TowerDefense.Lobbies es un lobby de hasta
-- Config.LOBBY_MAX jugadores: se entra cruzando su velo (o con su aviso "Join lobby") y el primero es el anfitrión.
-- Cada lobby enseña un mapa en una dificultad (sus pantallas, LobbyUI). Mientras está vacío, cambia cada TD.ROTATE
-- segundos (y en cuanto sale un grupo): los lobbies se reparten mapas y dificultades distintos. El anfitrión solo elige
-- las oleadas (LobbyRemote "Set"). Al acabar la cuenta atrás (o si el anfitrión pulsa "Start") el grupo viaja junto a
-- un servidor reservado solo para ellos, donde se carga ese mapa (TDMaps). En Studio no hay viajes: el mapa se carga
-- aquí mismo.
-- Atributos de cada lobby para la interfaz: Map, Diff, Waves, RotateAt, Count, State, Deadline, Host, HostName.
-- Dentro, el jugador está en el modo "lobby" (atributo Mode): Juego no le deja empezar visitas mientras tanto.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(RS.Config)
local TD = require(RS.TowerDefense)
local TDMaps = require(script.Parent.TDMaps)
local Remote = RS.Remote
local LobbyRemote = RS.LobbyRemote
local td = workspace:WaitForChild("Mapa"):WaitForChild("TowerDefense")
local folder = td:WaitForChild("Lobbies")
local board = td:FindFirstChild("Tablero")

if TDMaps.isMatchServer then
	-- (en el servidor de una partida no hay lobbies)
	for _, m in folder:GetChildren() do
		m:SetAttribute("State", "Closed")
	end
	return
end

local MAX = Config.LOBBY_MAX
local COLORS = {
	Waiting = Color3.fromRGB(255, 170, 60),
	Full = Color3.fromRGB(255, 72, 84),
	Teleporting = Color3.fromRGB(96, 230, 120),
}

local lobbies = {} -- [id] = lobby
local memberOf = {} -- [jugador] = lobby
local cooldown = {} -- [jugador] = os.clock() hasta el que no puede volver a entrar (al salir aparece delante del velo)
local travelers = {} -- [jugador] = true mientras viaja a su partida

local function now()
	return workspace:GetServerTimeNow()
end

---------- Rotación: qué mapa y dificultad enseña cada lobby ----------
-- Se prefiere lo que no esté en otro lobby (dificultad, luego mapa) y que no repita lo que acaba de enseñar
local function reroll(l)
	local shownMaps, shownDiffs = {}, {}
	for _, o in lobbies do
		if o ~= l and o.settings then
			shownMaps[o.settings.map] = true
			shownDiffs[o.settings.diff] = true
		end
	end
	local last = l.settings or {}
	local best, bestScore = nil, -math.huge
	for _, info in TD.MAPS do
		for _, d in TD.mapDiffs(info) do
			local s = math.random()
			s -= shownDiffs[d] and 4 or 0
			s -= shownMaps[info.id] and 2 or 0
			s -= info.id == last.map and 3 or 0
			s -= d == last.diff and 1 or 0
			if s > bestScore then
				best, bestScore = {map = info.id, diff = d}, s
			end
		end
	end
	l.settings = {map = best.map, diff = best.diff, waves = TD.WAVES}
	l.rotateAt = now() + TD.ROTATE
end

local function stateOf(l)
	if l.state == "Teleporting" then
		return "Teleporting"
	end
	local n = #l.players
	return n == 0 and "Open" or (n >= MAX and "Full" or "Waiting")
end

local function statusText(l)
	local s = stateOf(l)
	if s == "Teleporting" then
		return "Starting the match..."
	elseif s == "Open" then
		return "Walk in to start a match"
	end
	local left = math.max(0, math.ceil((l.deadline or now()) - now()))
	return (s == "Full" and "FULL · starting in %ds" or "Starting in %ds"):format(left)
end

-- Atributos (los lee la interfaz de cada jugador y las pantallas), color del velo y de las runas (el de la dificultad
-- mientras espera jugadores) y la fila del tablero
local function refresh(l)
	local m = l.model
	local n = #l.players
	local s = stateOf(l)
	local info = TD.mapInfo(l.settings.map)
	local color = s == "Open" and TD.DIFFS[l.settings.diff].color or COLORS[s]
	m:SetAttribute("Count", n)
	m:SetAttribute("State", s)
	m:SetAttribute("Deadline", l.deadline or 0)
	m:SetAttribute("Host", l.host and l.host.UserId or 0)
	m:SetAttribute("HostName", l.host and l.host.DisplayName or "")
	m:SetAttribute("Map", l.settings.map)
	m:SetAttribute("Diff", l.settings.diff)
	m:SetAttribute("Waves", l.settings.waves)
	m:SetAttribute("RotateAt", l.rotateAt)
	l.ui.bbCount.Text = ("%d/%d"):format(n, MAX)
	l.ui.bbCount.TextColor3 = n >= MAX and COLORS.Full or Color3.fromRGB(245, 238, 255)
	l.prompt.Enabled = n < MAX and s ~= "Teleporting"
	l.veil.Color = color
	l.light.Color = color
	for _, r in l.runes do
		r.Color = color
	end
	if l.row then
		l.row.Cuenta.Text = ("%d/%d"):format(n, MAX)
		local what = ("%s · %s"):format(info and info.name or "?", string.upper(l.settings.diff))
		l.row.Estado.Text = s == "Open" and what or ((l.host and (l.host.DisplayName .. " · ") or "") .. statusText(l))
		l.row.Punto.BackgroundColor3 = color
	end
end

-- Sitio de cada jugador dentro del pabellón: en corro, mirando al centro
local function slotCF(l, i)
	local a = (i - 0.5) / MAX * math.pi * 2
	local pos = l.base * Vector3.new(math.sin(a) * 3.6, 4, math.cos(a) * 3.6)
	return CFrame.lookAt(pos, Vector3.new(l.center.X, pos.Y, l.center.Z))
end

local function freeSlot(l)
	local used = {}
	for _, i in l.slots do
		used[i] = true
	end
	for i = 1, MAX do
		if not used[i] then
			return i
		end
	end
	return 1
end

local function join(plr, l)
	if memberOf[plr] or l.state == "Teleporting" or #l.players >= MAX then
		return
	end
	if (cooldown[plr] or 0) > os.clock() or plr:GetAttribute("Mode") ~= nil then
		return
	end
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (hum and hum.Health > 0 and char:FindFirstChild("HumanoidRootPart")) then
		return
	end
	l.slots[plr] = freeSlot(l)
	table.insert(l.players, plr)
	memberOf[plr] = l
	l.host = l.host or plr
	plr:SetAttribute("Mode", "lobby")
	plr:SetAttribute("Lobby", l.id)
	plr:SetAttribute("LobbySlot", l.slots[plr])
	hum.Sit = false
	char:PivotTo(slotCF(l, l.slots[plr]))
	local t = now()
	l.deadline = l.deadline or (t + Config.LOBBY_WAIT)
	if #l.players >= MAX then
		l.deadline = math.min(l.deadline, t + Config.LOBBY_FULL_WAIT)
	end
	LobbyRemote:FireClient(plr, "Joined", l.id)
	refresh(l)
end

-- why: "button" | "home" | "failed" (sale delante del velo) | "dead" | "gone" | "escaped" | "map" (no se le mueve)
local function leave(plr, why)
	local l = memberOf[plr]
	if not l then
		return
	end
	memberOf[plr] = nil
	local i = table.find(l.players, plr)
	if i then
		table.remove(l.players, i)
	end
	l.slots[plr] = nil
	if l.host == plr then
		l.host = l.players[1]
	end
	if #l.players == 0 then
		l.deadline = nil
		l.settings.waves = TD.WAVES
	end
	if plr.Parent then
		plr:SetAttribute("Lobby", nil)
		plr:SetAttribute("LobbySlot", nil)
		if plr:GetAttribute("Mode") == "lobby" then
			plr:SetAttribute("Mode", nil)
		end
		cooldown[plr] = os.clock() + 2
		local char = plr.Character
		if char and char.Parent and (why == "button" or why == "failed") then
			char:PivotTo(l.exit * CFrame.new((math.random() - 0.5) * 4, 0, (math.random() - 0.5) * 2))
		end
		LobbyRemote:FireClient(plr, "Left", l.id)
	end
	refresh(l)
end

local function notice(plr, text)
	if plr.Parent then
		LobbyRemote:FireClient(plr, "Notice", text)
	end
end

-- El viaje no salió: se queda en este servidor, con sus datos otra vez guardándose
local function travelFailed(plr, text)
	if not travelers[plr] then
		return
	end
	travelers[plr] = nil
	TDMaps.saveFor(plr, false)
	if plr:GetAttribute("Mode") == "travel" then
		plr:SetAttribute("Mode", nil)
	end
	LobbyRemote:FireClient(plr, "TravelFailed")
	notice(plr, text or "The match couldn't start. Try again!")
end

-- El grupo, a un servidor reservado solo para ellos (guardando antes sus datos)
local function teleport(group, settings)
	local left = #group
	for _, p in group do
		task.spawn(function()
			TDMaps.saveFor(p, true)
			left -= 1
		end)
	end
	while left > 0 do
		task.wait()
	end
	local ok, err
	for _ = 1, 3 do
		local going = {}
		for _, p in group do
			if p.Parent and travelers[p] then
				table.insert(going, p)
			end
		end
		if #going == 0 then
			return
		end
		ok, err = pcall(function()
			local code = TeleportService:ReserveServer(game.PlaceId)
			local opts = Instance.new("TeleportOptions")
			opts.ReservedServerAccessCode = code
			opts:SetTeleportData({td = {map = settings.map, diff = settings.diff, waves = settings.waves, host = settings.host, from = game.JobId}})
			TeleportService:TeleportAsync(game.PlaceId, going, opts)
		end)
		if ok then
			break
		end
		task.wait(1.5)
	end
	if not ok then
		warn("Tower Defense: no se pudo empezar la partida: " .. tostring(err))
		for _, p in group do
			travelFailed(p)
		end
		return
	end
	-- van de camino; si alguien sigue aquí al rato, su viaje falló
	task.delay(40, function()
		for _, p in group do
			if p.Parent then
				travelFailed(p)
			end
		end
	end)
end

local function start(l)
	if l.state == "Teleporting" or #l.players == 0 then
		return
	end
	l.state = "Teleporting"
	l.deadline = nil
	refresh(l)
	local group = table.clone(l.players)
	local settings = table.clone(l.settings)
	settings.host = l.host and l.host.UserId -- (en la partida solo él cambia la velocidad)
	for _, p in group do
		LobbyRemote:FireClient(p, "Starting", l.id)
		TDMaps.announceTravel(p, "match", settings)
	end
	task.wait(2) -- (un momento para el "GET READY")
	local going = {}
	for _, p in group do
		if p.Parent and memberOf[p] == l then
			leave(p, "map")
			table.insert(going, p)
		end
	end
	-- el lobby queda libre y enseña otro mapa
	l.state = "Open"
	reroll(l)
	refresh(l)
	if #going == 0 then
		return
	end
	if RunService:IsStudio() then
		-- (Studio: no hay servidores reservados; el mapa se carga en este)
		local Z = TDMaps.get(settings.map)
		if Z then
			Z.send(going, l.id, settings)
		else
			for _, p in going do
				notice(p, "This map couldn't load. Try another lobby!")
			end
		end
		return
	end
	for _, p in going do
		travelers[p] = true
		p:SetAttribute("Mode", "travel")
	end
	teleport(going, settings)
end

---------- Lobbies del mapa ----------
for _, m in folder:GetChildren() do
	local id = m:GetAttribute("Id")
	local base = m:GetAttribute("Base")
	if not (id and base) then
		continue
	end
	local center = base * Vector3.new(0, 1, 0)
	local salida = m.Salida.Position
	local l = {
		id = id, model = m, base = base, center = center,
		exit = CFrame.lookAt(salida, salida + (salida - center) * Vector3.new(1, 0, 1)),
		players = {}, slots = {}, state = "Open",
		veil = m.Velo, prompt = m.Velo.Unirse, light = m.Velo:FindFirstChildOfClass("PointLight"),
		ui = {bbCount = m.Marcador.Gui.Cuenta},
		runes = {},
		row = board and board:FindFirstChild("Fila" .. id, true),
	}
	for _, d in m:GetDescendants() do
		if d.Name == "Runas" and d:IsA("BasePart") then
			table.insert(l.runes, d)
		end
	end
	lobbies[id] = l
end
-- primer reparto; los cambios van escalonados para que no cambien todos a la vez
for id = 1, #folder:GetChildren() do
	local l = lobbies[id]
	if l then
		reroll(l)
		l.rotateAt += (id - 1) * (TD.ROTATE / 6)
	end
end
for _, l in lobbies do
	l.prompt.Triggered:Connect(function(plr)
		join(plr, l)
	end)
	l.veil.Touched:Connect(function(hit)
		local model = hit:FindFirstAncestorOfClass("Model")
		local plr = model and Players:GetPlayerFromCharacter(model)
		if plr then
			join(plr, l)
		end
	end)
	refresh(l)
end

LobbyRemote.OnServerEvent:Connect(function(plr, action, key, value)
	local l = memberOf[plr]
	if action == "Leave" then
		leave(plr, "button")
	elseif action == "Set" and l and l.host == plr and l.state ~= "Teleporting" then
		-- el anfitrión elige las oleadas (el mapa y la dificultad son los del lobby)
		if key == "waves" and table.find(TD.WAVE_OPTIONS, value) then
			l.settings.waves = value
		end
		refresh(l)
	elseif action == "Start" and l and l.host == plr and l.state ~= "Teleporting" then
		-- el anfitrión no quiere esperar: 3, 2, 1...
		l.deadline = math.min(l.deadline or math.huge, now() + 3)
		refresh(l)
	end
end)

-- "Go home" del menú estando en un lobby: sales del lobby y vas a tu casa
Remote.OnServerEvent:Connect(function(plr, action)
	if action == "GoHome" and memberOf[plr] then
		leave(plr, "home")
		local plot = plr:GetAttribute("Plot")
		local char = plr.Character
		if plot and Config.Plots[plot] and char then
			char:PivotTo(Config.frontOf(Config.Plots[plot]) * CFrame.new(0, 3, 0))
		end
	end
end)

TeleportService.TeleportInitFailed:Connect(function(plr, _, msg)
	travelFailed(plr, "Teleport failed: " .. tostring(msg))
end)

local function watch(plr)
	plr.CharacterRemoving:Connect(function()
		leave(plr, "dead")
	end)
end
for _, plr in Players:GetPlayers() do
	watch(plr)
end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(function(plr)
	leave(plr, "gone")
	cooldown[plr] = nil
	travelers[plr] = nil
end)

---------- Bucle: cuentas atrás, rotación y que nadie se quede colgado ----------
while true do
	task.wait(0.25)
	local t = now()
	for _, l in lobbies do
		for _, p in table.clone(l.players) do
			local char = p.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if not (p.Parent and hum and root and hum.Health > 0) then
				leave(p, "dead")
			elseif (root.Position - l.center).Magnitude > 14 then
				leave(p, "escaped") -- lo han movido a otra parte (o se ha colado por donde no debía)
			end
		end
		if l.state ~= "Teleporting" and l.deadline and t >= l.deadline and #l.players > 0 then
			task.spawn(start, l)
		elseif l.state == "Open" and #l.players == 0 and t >= l.rotateAt then
			reroll(l)
		end
		refresh(l)
	end
end
