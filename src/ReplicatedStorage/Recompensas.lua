-- Recompensas: los datos que comparten servidor (Juego) y cliente (Recompensas.client).
--  * Premio de conexión: 7 días seguidos (si un día no entras, la racha vuelve al día 1). Del 7º se vuelve a empezar
--    por el 1, pero la racha sigue contando. Se reclama con un botón (ventana "Daily Rewards").
--  * Regalos por tiempo: 6 regalos que se abren al llevar 5, 10, 15, 25, 40 y 60 minutos jugados HOY (el tiempo se
--    suma entre servidores, también en el Tower Defense). Todo se reinicia a las 00:00 UTC.
-- Cada premio es directo ({kind, n}) o un sorteo ({pool = {{kind, n, w}, ...}}, w = probabilidad en %).
--   kind: "coins" | "gems" | "spin" (tirada gratis en la ruleta de la tirada gratis) | "scare" (un susto al azar de la
--   categoría cat; los más fuertes salen menos: Config.prizeOdds)
local R = {}

R.DAY = 86400

---------- Premio de conexión ----------
R.LOGIN = {
	{kind = "coins", n = 150},
	{kind = "coins", n = 300},
	{kind = "gems", n = 15},
	{kind = "spin", n = 1},
	{kind = "coins", n = 800},
	{kind = "gems", n = 40},
	-- día 7: el cofre grande (un sorteo)
	{chest = true, pool = {
		{kind = "scare", cat = "Criatura", n = 1, w = 60},
		{kind = "gems", n = 100, w = 30},
		{kind = "spin", n = 3, w = 8},
		{kind = "scare", cat = "Legendario", n = 1, w = 2},
	}},
}

-- Día de hoy (UTC) a partir de un tiempo en segundos (os.time() en el servidor, GetServerTimeNow() en el cliente)
function R.today(now)
	return math.floor(now / R.DAY)
end

-- Casilla (1..7) del día número 'streak' de la racha
function R.loginIndex(streak)
	return (math.max(streak, 1) - 1) % #R.LOGIN + 1
end

-- Estado del premio de conexión con el último día reclamado (lastDay) y la racha que tenía entonces (streak):
-- ¿se puede reclamar hoy?, la racha que tendrá (o tiene) y la casilla que toca (o la que reclamó hoy)
function R.loginState(lastDay, streak, today)
	lastDay, streak = lastDay or 0, streak or 0
	if today > lastDay then
		local nextStreak = (today == lastDay + 1) and streak + 1 or 1
		return true, nextStreak, R.loginIndex(nextStreak)
	end
	return false, streak, R.loginIndex(streak)
end

---------- Regalos por tiempo ----------
R.GIFT_STYLES = {
	small = {name = "Spooky Gift", color = Color3.fromRGB(86, 150, 255)},
	big = {name = "Haunted Gift", color = Color3.fromRGB(92, 214, 110)},
	epic = {name = "Cursed Gift", color = Color3.fromRGB(255, 196, 50)},
}
local POOLS = {
	small = {
		{kind = "coins", n = 150, w = 50},
		{kind = "coins", n = 300, w = 30},
		{kind = "gems", n = 5, w = 15},
		{kind = "spin", n = 1, w = 5},
	},
	big = {
		{kind = "coins", n = 500, w = 45},
		{kind = "gems", n = 12, w = 25},
		{kind = "spin", n = 1, w = 20},
		{kind = "scare", cat = "Criatura", n = 1, w = 10},
	},
	epic = {
		{kind = "coins", n = 1500, w = 40},
		{kind = "gems", n = 30, w = 30},
		{kind = "spin", n = 2, w = 18},
		{kind = "scare", cat = "Criatura", n = 1, w = 10},
		{kind = "scare", cat = "Legendario", n = 1, w = 2},
	},
}
R.GIFTS = {
	{t = 5 * 60, style = "small", n = 1, pool = POOLS.small},
	{t = 10 * 60, style = "small", n = 1, pool = POOLS.small},
	{t = 15 * 60, style = "big", n = 1, pool = POOLS.big},
	{t = 25 * 60, style = "big", n = 2, pool = POOLS.big},
	{t = 40 * 60, style = "epic", n = 1, pool = POOLS.epic},
	{t = 60 * 60, style = "epic", n = 2, pool = POOLS.epic},
}
-- (n: cuántas veces se sortea al abrirlo: el "x2" de la esquina)

---------- Textos ----------
local CAT_NAMES = {Basico = "Basic", Criatura = "Creature", Trampa = "Trap", Legendario = "Legendary", Especial = "Special"}

-- "150 Coins", "15 Gems", "1 Free Spin", "Creature Scare"... (con r.scare: el nombre del susto que tocó)
function R.text(r, scareName)
	if r.kind == "coins" then
		return ("%s Coins"):format(R.fmt(r.n))
	elseif r.kind == "gems" then
		return ("%s Gems"):format(R.fmt(r.n))
	elseif r.kind == "spin" then
		return r.n == 1 and "1 Free Spin" or ("%d Free Spins"):format(r.n)
	elseif r.kind == "scare" then
		return scareName or ("%s Scare"):format(CAT_NAMES[r.cat] or "Random")
	end
	return "?"
end

-- La cifra corta de la esquina de la casilla ("x150")
function R.short(r)
	if r.kind == "scare" then
		return "x1"
	end
	return "x" .. R.fmt(r.n)
end

function R.fmt(n)
	local s, k = tostring(math.floor(n)), 0
	repeat
		s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return s
end

-- Las probabilidades de un sorteo, de la más probable a la menos: {{r, pct}, ...}
function R.chances(pool)
	local total = 0
	for _, r in pool do
		total += r.w
	end
	local list = {}
	for _, r in pool do
		table.insert(list, {r = r, pct = r.w / total * 100})
	end
	table.sort(list, function(a, b)
		return a.pct > b.pct
	end)
	return list
end

-- Sortea un premio de pool (servidor)
function R.roll(pool)
	local total = 0
	for _, r in pool do
		total += r.w
	end
	local x = math.random() * total
	for _, r in pool do
		x -= r.w
		if x <= 0 then
			return r
		end
	end
	return pool[#pool]
end

-- "1:05:09" / "4:59"
function R.clock(s)
	s = math.max(0, math.ceil(s))
	local h, m, sec = s // 3600, (s // 60) % 60, s % 60
	if h > 0 then
		return ("%d:%02d:%02d"):format(h, m, sec)
	end
	return ("%d:%02d"):format(m, sec)
end

return R
