-- Misiones (compartido por servidor y cliente): siempre hay SLOTS misiones a la vez. Al cobrar una sale otra en su
-- sitio, un poco más difícil: el nivel de misiones (lvl = misiones cobradas) sube las cantidades, las recompensas y
-- desbloquea tipos nuevos (min). Las primeras (FIRST) enseñan el juego: asustar, la ruleta y el Tower Defense.
-- La lógica está en ServerScriptService.MisionesServidor y la interfaz en StarterPlayerScripts.MisionesUI.
-- Cada tipo: text (con %s = la cantidad), desc, icon (UI.ICONS), color, go (a dónde lleva FOLLOW: house, wheel,
-- fuse, td, neighbor, o una pantalla: scares), base y grow (cantidad = base × (1 + lvl × grow), hasta cap),
-- w (peso de la recompensa) y min (nivel de misiones desde el que sale). abs: la cantidad es una meta (el nivel).
local Q = {}

Q.SLOTS = 3

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

Q.Kinds = {
	scare = {text = "Scare %s visitors", desc = "Make visitors flee or faint in YOUR haunted house", icon = "ghost", color = rgb(255, 138, 30),
		go = "house", base = 3, grow = 0.45, w = 1, min = 0},
	rare = {text = "Scare %s Rare visitors", desc = "Rare, Epic or better visitors. The higher your level, the luckier!", icon = "star", color = rgb(70, 160, 255),
		go = "house", base = 1, grow = 0.12, cap = 5, w = 1.6, min = 4},
	coins = {text = "Collect %s coins", desc = "Pick up the coins scared visitors drop in your house", icon = "coins", color = rgb(255, 196, 40),
		go = "house", base = 60, grow = 0.7, w = 0.9, min = 1},
	place = {text = "Place %s scares", desc = "Walk into your house and place scares from your bag", icon = "hammer", color = rgb(150, 110, 255),
		go = "house", base = 1, grow = 0.25, cap = 6, w = 0.8, min = 0},
	spin = {text = "Spin the Wheel of Fright %s", desc = "Win scares you can't buy anywhere else (one free spin every 6 h!)", icon = "wheel", color = rgb(240, 80, 170),
		go = "wheel", base = 1, grow = 0.2, cap = 6, w = 1.2, min = 0},
	buy = {text = "Buy %s scares", desc = "Buy new scares with coins in the Scares shop", icon = "cart", color = rgb(70, 200, 92),
		go = "scares", base = 1, grow = 0.25, cap = 6, w = 0.9, min = 1},
	tdPlay = {text = "Play %s Tower Defense", desc = "Join a lobby on the east plaza and defend the haunted house", icon = "swords", color = rgb(226, 60, 84),
		go = "td", base = 1, grow = 0.15, cap = 4, w = 1.2, min = 0},
	tdPlace = {text = "Deploy %s troops", desc = "Place your scares as troops in a Tower Defense match", icon = "shield", color = rgb(90, 200, 255),
		go = "td", base = 5, grow = 0.5, w = 1, min = 1},
	tdWave = {text = "Survive %s waves", desc = "Clear waves of ghost hunters in Tower Defense", icon = "flag", color = rgb(255, 110, 60),
		go = "td", base = 3, grow = 0.55, w = 1.3, min = 2},
	tdKill = {text = "Scare away %s ghost hunters", desc = "Your troops must make ghost hunters flee in Tower Defense", icon = "skull", color = rgb(255, 72, 92),
		go = "td", base = 15, grow = 0.6, w = 1.3, min = 2},
	tdWin = {text = "Win %s Tower Defense", desc = "Survive every wave of a match (any map, any difficulty)", icon = "trophy", color = rgb(255, 212, 70),
		go = "td", base = 1, grow = 0.1, cap = 3, w = 2, min = 3},
	brave = {text = "Survive %s neighbor houses", desc = "Walk through another house to the very end without fainting", icon = "door", color = rgb(120, 220, 140),
		go = "neighbor", base = 1, grow = 0.2, cap = 4, w = 1, min = 1},
	legend = {text = "Get %s Legendary scares", desc = "Win them on the wheels: the Nightmare Wheel has the most!", icon = "crown", color = rgb(255, 70, 100),
		go = "wheel", base = 1, grow = 0.06, cap = 2, w = 3, min = 6},
	fuse = {text = "Fuse %s scares", desc = "Melt copies into stars at Hexa's Cauldron in the graveyard", icon = "cauldron", color = rgb(160, 90, 255),
		go = "fuse", base = 1, grow = 0.1, cap = 3, w = 1.6, min = 5},
	level = {text = "Reach level %s", desc = "Scaring visitors and playing Tower Defense gives you XP", icon = "lightning", color = rgb(110, 230, 120),
		go = "house", abs = true, w = 1.4, min = 2},
}

-- Las primeras: lo básico del juego (la primera tirada de la ruleta es gratis)
Q.FIRST = {{"scare", 3}, {"spin", 1}, {"tdPlay", 1}}

-- Redondeo bonito: 7, 15, 40, 125, 1250...
local function nice(n)
	local step = n >= 1000 and 50 or n >= 200 and 25 or n >= 40 and 5 or 1
	return math.max(1, math.floor(n / step + 0.5) * step)
end

-- Cuánto pide un tipo a ese nivel de misiones (los abs los decide el servidor)
function Q.amount(kind, lvl)
	local k = Q.Kinds[kind]
	local n = nice(k.base * (1 + lvl * k.grow))
	return k.cap and math.min(n, k.cap) or n
end

-- Recompensa: monedas, gemas y experiencia de jugador (más cuanto más nivel y más difícil el tipo)
function Q.rewards(kind, lvl)
	local w = Q.Kinds[kind].w
	return nice(70 * (1 + lvl * 0.45) * w), math.max(1, math.floor((2 + lvl * 0.7) * w + 0.5)), math.floor((20 + lvl * 10) * w + 0.5)
end

-- "Scare 1,250 visitors" (sin "1" delante en los de una vez: "Spin the Wheel of Fright")
function Q.text(q, fmt)
	local k = Q.Kinds[q.k]
	if not k then
		return "???"
	end
	local n = (fmt or tostring)(q.n)
	if q.n == 1 and not k.abs then
		if q.k == "spin" then
			return "Spin the Wheel of Fright"
		end
		local one = {scare = "Scare a visitor", rare = "Scare a Rare visitor", place = "Place a scare", buy = "Buy a scare", tdPlay = "Play a Tower Defense match",
			tdWin = "Win a Tower Defense match", brave = "Survive a neighbor's house", legend = "Get a Legendary scare", fuse = "Fuse a scare"}
		if one[q.k] then
			return one[q.k]
		end
	end
	if q.k == "spin" then
		return ("Spin the wheel %s times"):format(n)
	end
	if q.k == "tdPlay" then
		return ("Play %s Tower Defense matches"):format(n)
	end
	if q.k == "tdWin" then
		return ("Win %s Tower Defense matches"):format(n)
	end
	return k.text:format(n)
end

return Q
