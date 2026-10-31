-- Misiones (servidor). Datos y textos: ReplicatedStorage.Misiones. Juego las carga y las guarda con la partida
-- (M.load / M.export / M.drop); Juego y TDMatch avisan de lo que pasa (M.add: "he asustado a 1 visitante").
-- El cliente (MisionesUI) lee el atributo Quests del jugador (JSON: {lvl, list = {{k, n, p, id, c, g, x}...}}) y cobra
-- con QuestRemote:FireServer("Claim", id).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Config = require(RS.Config)
local Q = require(RS.Misiones)

local M = {}
local data = {} -- [jugador] = {lvl, seq, last, list}

local remote = RS:FindFirstChild("QuestRemote") or Instance.new("RemoteEvent")
remote.Name = "QuestRemote"
remote.Parent = RS

local function sync(plr)
	local d = data[plr]
	if d then
		plr:SetAttribute("Quests", HttpService:JSONEncode({lvl = d.lvl, list = d.list}))
	end
end

-- Lo que lleva ya hecho un tipo "abs" (el nivel del jugador)
local function current(plr, kind)
	if kind == "level" then
		return Config.playerLevel(plr)
	end
	return 0
end

local function quest(plr, d, kind, n)
	d.seq += 1
	local k = Q.Kinds[kind]
	if k.abs and kind == "level" then
		n = n or math.min(Config.PLAYER_MAX_LEVEL, current(plr, kind) + 1 + d.lvl // 6)
	end
	local c, g, x = Q.rewards(kind, d.lvl)
	return {k = kind, n = n or Q.amount(kind, d.lvl), p = k.abs and current(plr, kind) or 0, id = d.seq, c = c, g = g, x = x}
end

-- Una misión nueva para el hueco que queda libre: de los tipos ya desbloqueados, ninguno de los que ya están ni el que
-- se acaba de cobrar; los nuevos aún sin probar pesan más (así el jugador va descubriendo todo el juego)
local function pick(plr, d)
	local pool, total = {}, 0
	for kind, k in Q.Kinds do
		local busy = kind == d.last
		for _, q in d.list do
			busy = busy or q.k == kind
		end
		if kind == "level" and current(plr, kind) >= Config.PLAYER_MAX_LEVEL then
			busy = true
		end
		if not busy and d.lvl >= k.min then
			local w = d.done[kind] and 1 or 2.5
			table.insert(pool, {kind, w})
			total += w
		end
	end
	if #pool == 0 then
		return quest(plr, d, "scare")
	end
	local r = math.random() * total
	for _, e in pool do
		r -= e[2]
		if r <= 0 then
			return quest(plr, d, e[1])
		end
	end
	return quest(plr, d, pool[#pool][1])
end

-- saved: lo que guardó Juego (M.export) o nil si es nuevo
function M.load(plr, saved)
	local d = {lvl = 0, seq = 0, list = {}, done = {}}
	if typeof(saved) == "table" and typeof(saved.list) == "table" then
		d.lvl = math.max(0, math.floor(tonumber(saved.lvl) or 0))
		d.seq = math.max(0, math.floor(tonumber(saved.seq) or 0))
		d.last = typeof(saved.last) == "string" and saved.last or nil
		for kind in typeof(saved.done) == "table" and saved.done or {} do
			if Q.Kinds[kind] then
				d.done[kind] = true
			end
		end
		for _, q in saved.list do
			if typeof(q) == "table" and Q.Kinds[q.k] and #d.list < Q.SLOTS then
				d.seq = math.max(d.seq, tonumber(q.id) or 0)
				table.insert(d.list, {k = q.k, n = tonumber(q.n) or 1, p = tonumber(q.p) or 0, id = tonumber(q.id) or 0, c = tonumber(q.c) or 0, g = tonumber(q.g) or 0, x = tonumber(q.x) or 0})
			end
		end
	else
		for _, f in Q.FIRST do
			table.insert(d.list, quest(plr, d, f[1], f[2]))
		end
	end
	data[plr] = d
	while #d.list < Q.SLOTS do
		table.insert(d.list, pick(plr, d))
	end
	for _, q in d.list do
		if Q.Kinds[q.k].abs then
			q.p = math.max(q.p, current(plr, q.k))
		end
	end
	sync(plr)
	-- el nivel del jugador cuenta solo
	plr:GetAttributeChangedSignal("PXP"):Connect(function()
		M.set(plr, "level", Config.playerLevel(plr))
	end)
end

function M.export(plr)
	local d = data[plr]
	return d and {lvl = d.lvl, seq = d.seq, last = d.last, done = d.done, list = d.list} or nil
end

function M.drop(plr)
	data[plr] = nil
end

local function advance(plr, kind, f)
	local d = data[plr]
	if not d then
		return
	end
	local changed = false
	for _, q in d.list do
		if q.k == kind and q.p < q.n then
			local p = math.min(q.n, f(q.p))
			if p ~= q.p then
				q.p, changed = p, true
				if p >= q.n then
					remote:FireClient(plr, "Done", q.id)
				end
			end
		end
	end
	if changed then
		sync(plr)
	end
end

-- Ha hecho n más de lo que pide ese tipo
function M.add(plr, kind, n)
	if plr and (n or 1) > 0 then
		advance(plr, kind, function(p)
			return p + (n or 1)
		end)
	end
end

-- Ya lleva value (tipos abs: el nivel)
function M.set(plr, kind, value)
	advance(plr, kind, function(p)
		return math.max(p, value)
	end)
end

local function claim(plr, id)
	local d = data[plr]
	if not d then
		return
	end
	for i, q in d.list do
		if q.id == id and q.p >= q.n then
			local stats = plr:FindFirstChild("leaderstats")
			if stats then
				stats.Coins.Value += q.c
			end
			plr:SetAttribute("Gems", (plr:GetAttribute("Gems") or 0) + q.g)
			Config.addPlayerXP(plr, q.x)
			d.lvl += 1
			d.last = q.k
			d.done[q.k] = true
			table.remove(d.list, i)
			local fresh = pick(plr, d)
			table.insert(d.list, i, fresh)
			sync(plr)
			remote:FireClient(plr, "Claimed", q, fresh.id, d.lvl)
			return
		end
	end
end

local lastClaim = {}
remote.OnServerEvent:Connect(function(plr, action, id)
	if action == "Claim" and typeof(id) == "number" then
		local t = os.clock()
		if t - (lastClaim[plr] or 0) < 0.3 then
			return
		end
		lastClaim[plr] = t
		claim(plr, id)
	end
end)
Players.PlayerRemoving:Connect(function(plr)
	lastClaim[plr] = nil
end)

return M
