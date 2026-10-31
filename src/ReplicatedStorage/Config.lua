-- Tu Casa Encantada: datos compartidos por servidor y cliente. Para equilibrar el juego, toca aquí.
local Config = {}

---------- Casa ----------
Config.ROOM_W = 27 -- ancho interior de cada habitación (lo máximo que cabe: los muros de las casas 3D están en x = +13.5)
Config.ROOM_D = 24 -- fondo de cada habitación
Config.ROOM_H = 13 -- altura interior
Config.FLOOR_Y = 2 -- el suelo de la casa está sobre unos cimientos
Config.DOOR_W = 4.4 -- la puerta de la casa principal (diseño 3D, a escala 4.4)
Config.DOOR_H = 9.4
Config.SCARES_PER_ROOM = 5 -- espacios para sustos = habitaciones × esto (los grandes ocupan más de uno: slots)
Config.ENTRY_SAFE = 5 -- sin sustos pegados a la entrada...
Config.BACK_SAFE = 2 -- ...ni contra la pared del fondo
-- Los sustos se pueden poner en cualquier sitio, también en mitad del camino, mientras quede una ruta de la puerta al
-- fondo por la que quepa alguien (CLEARANCE: medio ancho de quien pasa). Los visitantes bot la siguen (Config.route).
Config.CLEARANCE = 1.3
Config.ROUTE_CELL = 0.5 -- tamaño de la rejilla de la ruta
Config.SPAWN_DIST = 12 -- apareces en tu jardín, a esta distancia del portal de la puerta y mirando a tu casa

-- Colores de cada casa (una por parcela), para que en la calle se distingan de un vistazo
Config.HouseStyles = {
	{siding = Color3.fromRGB(78, 62, 104), trim = Color3.fromRGB(32, 24, 40), roof = Color3.fromRGB(46, 34, 62), shutter = Color3.fromRGB(28, 54, 46)},
	{siding = Color3.fromRGB(52, 80, 78), trim = Color3.fromRGB(24, 34, 34), roof = Color3.fromRGB(40, 46, 52), shutter = Color3.fromRGB(96, 34, 40)},
	{siding = Color3.fromRGB(104, 76, 52), trim = Color3.fromRGB(40, 28, 22), roof = Color3.fromRGB(58, 40, 34), shutter = Color3.fromRGB(34, 40, 64)},
	{siding = Color3.fromRGB(66, 72, 94), trim = Color3.fromRGB(26, 28, 38), roof = Color3.fromRGB(36, 38, 50), shutter = Color3.fromRGB(110, 70, 30)},
	{siding = Color3.fromRGB(98, 50, 56), trim = Color3.fromRGB(34, 20, 24), roof = Color3.fromRGB(48, 30, 36), shutter = Color3.fromRGB(30, 30, 34)},
	{siding = Color3.fromRGB(58, 70, 50), trim = Color3.fromRGB(26, 30, 22), roof = Color3.fromRGB(42, 40, 36), shutter = Color3.fromRGB(80, 40, 90)},
}

---------- Visitas ----------
Config.VISIT_SPEED = 12
Config.FEAR_DECAY = 6 -- miedo que se recupera por segundo (tras 2 s tranquilo)
Config.COMBO_WINDOW = 6 -- segundos entre sustos para encadenar combo
Config.FLEE_BONUS = 40 -- monedas extra que suelta un visitante que se desmaya o al que atrapan
Config.BOT_EVERY = {14, 24} -- cada cuánto llega un bot a tu casa (más a menudo cuanto más poder y 👍 tenga)
Config.START_MONEY = 0
-- (el visitante dorado y los demás raros: Config.Visitors, más abajo)

---------- Visitantes (bots que llegan a tu casa) ----------
-- Cada visitante tiene una rareza: la inmensa mayoría son normales, algunos poco comunes y cada vez menos raros,
-- épicos, legendarios y míticos. Los raros sueltan más monedas (mult) pero son más valientes (courage < 1: el miedo les
-- sube más despacio). gear: complementos de Outfits; shirt/pants/skin/hair: colores (sin ellos, al azar).
-- speed: los raros caminan más despacio (da tiempo a volver a casa a verlos).
-- Los que asustas por primera vez se apuntan en tu Libro de Visitantes (y te dan un premio).
Config.Rarities = {
	{id = "Common", name = "Common", weight = 80, color = Color3.fromRGB(200, 205, 215), courage = 1, speed = 1},
	{id = "Uncommon", name = "Uncommon", weight = 14, color = Color3.fromRGB(90, 225, 110), courage = 0.95, speed = 0.92},
	{id = "Rare", name = "Rare", weight = 4.5, color = Color3.fromRGB(70, 160, 255), courage = 0.85, speed = 0.8},
	{id = "Epic", name = "Epic", weight = 1.2, color = Color3.fromRGB(190, 90, 255), courage = 0.75, speed = 0.68},
	{id = "Legendary", name = "Legendary", weight = 0.27, color = Color3.fromRGB(255, 196, 40), courage = 0.65, speed = 0.55},
	{id = "Mythic", name = "Mythic", weight = 0.03, color = Color3.fromRGB(255, 70, 120), courage = 0.55, speed = 0.45},
	{id = "Secret", name = "Secret", weight = 0.002, color = Color3.fromRGB(60, 255, 170), courage = 0.45, speed = 0.34},
}
Config.RarityIndex = {}
for i, r in Config.Rarities do
	Config.RarityIndex[r.id] = i
end
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
Config.Visitors = {
	-- Comunes
	{id = "TrickOrTreater", name = "Trick-or-Treater", rarity = "Common", mult = 1, scale = 0.8, speed = 1.15, shirt = rgb(255, 138, 30), pants = rgb(40, 34, 30), gear = {"stemhat", "pumpkinsuit", "candybucket"}, desc = "Just here for the candy. Easily spooked!"},
	{id = "SheetGhost", name = "Sheet Ghost Kid", rarity = "Common", mult = 1, scale = 0.78, speed = 1.1, shirt = rgb(240, 240, 240), pants = rgb(240, 240, 240), gear = {"ghostsheet", "candybucket"}, desc = "A kid in a bedsheet. Ironic."},
	{id = "Teen", name = "Teenager", rarity = "Common", mult = 1, gear = {"hair", "headphones"}, desc = "Pretends not to be scared. Is very scared."},
	{id = "Tourist", name = "Tourist", rarity = "Common", mult = 1, shirt = rgb(250, 120, 160), gear = {"sunhat", "sunglasses", "camera"}, desc = "Takes a photo of every scare."},
	{id = "Jogger", name = "Jogger", rarity = "Common", mult = 1, speed = 1.3, shirt = rgb(60, 200, 220), gear = {"hair", "headband"}, desc = "Runs through haunted houses for cardio."},
	{id = "Grandma", name = "Grandma", rarity = "Common", mult = 1, courage = 1.25, speed = 0.75, shirt = rgb(170, 110, 160), pants = rgb(110, 80, 110), hair = rgb(220, 220, 225), gear = {"bun", "glasses"}, desc = "Slow, sweet... and screams the loudest."},
	{id = "Grandpa", name = "Grandpa", rarity = "Common", mult = 1, courage = 1.15, speed = 0.75, shirt = rgb(120, 100, 80), hair = rgb(220, 220, 225), gear = {"glasses", "mustache", "cane"}, desc = "Has seen scarier things in the war."},
	{id = "OfficeWorker", name = "Office Worker", rarity = "Common", mult = 1, shirt = rgb(235, 235, 240), pants = rgb(40, 44, 60), gear = {"hair", "tie", "briefcase"}, desc = "Lost on the way home from work."},
	{id = "PizzaGuy", name = "Pizza Delivery", rarity = "Common", mult = 1, shirt = rgb(210, 40, 40), gear = {"cap", "pizza"}, desc = "30 minutes or it's free. Even here.", capColor = rgb(200, 30, 30)},
	{id = "Student", name = "Student", rarity = "Common", mult = 1, gear = {"hair", "glasses", "backpack"}, desc = "Doing a school project on ghosts."},
	{id = "Gamer", name = "Gamer", rarity = "Common", mult = 1, shirt = rgb(40, 40, 50), gear = {"hair", "headphones"}, desc = "Thought it was a VR game."},
	{id = "Camper", name = "Camper", rarity = "Common", mult = 1, shirt = rgb(70, 120, 70), gear = {"beanie", "backpack"}, desc = "Took a wrong turn in the woods.", hatColor = rgb(230, 140, 40)},
	{id = "Mime", name = "Mime", rarity = "Common", mult = 1, skin = rgb(245, 245, 245), shirt = rgb(240, 240, 240), pants = rgb(30, 28, 34), stripe = rgb(30, 28, 34), hatColor = rgb(30, 28, 34), gear = {"beret", "stripes"}, desc = "Screams silently. Very, very silently."},
	{id = "Skater", name = "Skater", rarity = "Common", mult = 1, speed = 1.25, capColor = rgb(230, 70, 50), gear = {"backcap", "skateboard"}, desc = "Came to grind the haunted handrails."},
	{id = "Mailman", name = "Mail Carrier", rarity = "Common", mult = 1, shirt = rgb(90, 125, 175), pants = rgb(40, 50, 80), capColor = rgb(40, 50, 90), gear = {"cap", "mailbag"}, desc = "Delivering a letter addressed to 'The Ghost'."},
	{id = "Farmer", name = "Farmer", rarity = "Common", mult = 1, courage = 1.1, shirt = rgb(170, 60, 50), pants = rgb(60, 80, 130), gear = {"strawhat", "pitchfork"}, desc = "Thought the corn maze was scarier."},
	-- Poco comunes
	{id = "Golden", name = "Golden Visitor", rarity = "Uncommon", mult = 3, golden = true, variant = "Gold", shirt = rgb(255, 196, 50), pants = rgb(200, 140, 30), gear = {"hair", "sunglasses"}, desc = "Shiny and rich: drops triple coins!"},
	{id = "GhostHunter", name = "Ghost Hunter", rarity = "Uncommon", mult = 1.5, courage = 0.85, shirt = rgb(60, 120, 200), gear = {"cap", "camera"}, desc = "Hunting for proof. Finds only screams."},
	{id = "Detective", name = "Detective", rarity = "Uncommon", mult = 1.5, shirt = rgb(150, 120, 80), gear = {"fedora", "coat", "mustache"}, coat = rgb(140, 110, 70), desc = "Investigating the case of the missing visitors."},
	{id = "Firefighter", name = "Firefighter", rarity = "Uncommon", mult = 1.5, shirt = rgb(70, 60, 50), pants = rgb(70, 60, 50), gear = {"firehelm", "axe"}, desc = "Brave... until the lights go out."},
	{id = "Police", name = "Police Officer", rarity = "Uncommon", mult = 1.5, shirt = rgb(40, 60, 120), pants = rgb(30, 36, 60), gear = {"policecap", "badge", "sunglasses"}, desc = "Responding to a noise complaint. From ghosts."},
	{id = "Chef", name = "Chef", rarity = "Uncommon", mult = 1.5, shirt = rgb(240, 240, 240), pants = rgb(60, 60, 70), gear = {"chefhat", "apron", "mustache"}, desc = "Smelled something cooking in the cauldron."},
	{id = "Doctor", name = "Doctor", rarity = "Uncommon", mult = 1.5, shirt = rgb(120, 180, 220), gear = {"hair", "labcoat", "stethoscope", "glasses"}, desc = "Checks the pulse of every scared visitor."},
	{id = "Scout", name = "Scout", rarity = "Uncommon", mult = 1.5, scale = 0.85, shirt = rgb(150, 140, 80), gear = {"scouthat", "sash"}, desc = "Earning the 'Survived a Haunted House' badge."},
	{id = "Painter", name = "Painter", rarity = "Uncommon", mult = 1.5, shirt = rgb(235, 230, 215), pants = rgb(60, 70, 110), hatColor = rgb(170, 30, 40), gear = {"beret", "mustache", "palette", "brush"}, desc = "Wants to paint your ghosts. Ghosts don't pose."},
	{id = "Ballerina", name = "Ballerina", rarity = "Uncommon", mult = 1.5, scale = 0.9, speed = 1.1, shirt = rgb(255, 170, 210), pants = rgb(255, 215, 230), shoes = rgb(255, 190, 215), gear = {"bun", "tutu"}, desc = "Pirouettes away from every single scare."},
	-- Raros
	{id = "Knight", name = "Wandering Knight", rarity = "Rare", mult = 2.5, shirt = rgb(172, 178, 190), pants = rgb(120, 124, 136), tabard = rgb(40, 70, 170), gear = {"knighthelm", "tabard", "sword", "kiteshield"}, desc = "A knight from the cursed castle, far from home."},
	{id = "Pirate", name = "Pirate", rarity = "Rare", mult = 2.5, shirt = rgb(230, 225, 210), pants = rgb(60, 40, 30), gear = {"tricorn", "eyepatch", "parrot", "hook"}, desc = "Arr! Looking for buried treasure."},
	{id = "Astronaut", name = "Astronaut", rarity = "Rare", mult = 2.5, shirt = rgb(235, 235, 240), pants = rgb(235, 235, 240), gear = {"astropack", "astrohelm"}, desc = "One small step into a haunted house."},
	{id = "Ninja", name = "Ninja", rarity = "Rare", mult = 2.5, speed = 1.25, shirt = rgb(30, 30, 36), pants = rgb(30, 30, 36), hood = rgb(30, 30, 36), gear = {"hood", "mask", "katana"}, desc = "Silent and swift. Screams anyway."},
	{id = "Wizard", name = "Old Wizard", rarity = "Rare", mult = 2.5, shirt = rgb(60, 70, 170), pants = rgb(50, 56, 140), hair = rgb(230, 230, 235), gear = {"wizardhat", "beard", "robe", "staff"}, desc = "Came to study the magic of your house."},
	{id = "Cowboy", name = "Cowboy", rarity = "Rare", mult = 2.5, shirt = rgb(170, 70, 50), pants = rgb(60, 80, 130), gear = {"cowboyhat", "mustache", "lasso"}, desc = "Yeehaw... YEE-AAAH!"},
	{id = "VampHunter", name = "Vampire Hunter", rarity = "Rare", mult = 2.5, courage = 0.8, shirt = rgb(60, 40, 36), pants = rgb(40, 34, 30), gear = {"tricorn", "coat", "crossbow"}, desc = "Armed with garlic and a crossbow."},
	{id = "Magician", name = "Stage Magician", rarity = "Rare", mult = 2.5, shirt = rgb(30, 28, 36), pants = rgb(30, 28, 36), cape = rgb(110, 30, 140), gear = {"tophat", "mustache", "cape", "wand"}, desc = "Tries to make the ghosts disappear. Disappears instead."},
	{id = "Viking", name = "Viking", rarity = "Rare", mult = 2.5, courage = 0.85, shirt = rgb(120, 90, 60), pants = rgb(70, 56, 44), hair = rgb(200, 100, 40), gear = {"hornedhelm", "beard", "axe", "heroshield"}, desc = "Sailed the seven seas to get spooked."},
	-- Épicos
	{id = "Prince", name = "Royal Prince", rarity = "Epic", mult = 4, shirt = rgb(70, 60, 170), pants = rgb(240, 240, 245), cape = rgb(150, 30, 60), gear = {"hair", "crown", "royalcape"}, desc = "Visiting incognito. Very poorly."},
	{id = "Superhero", name = "Superhero", rarity = "Epic", mult = 4, shirt = rgb(40, 90, 220), pants = rgb(200, 30, 40), cape = rgb(220, 30, 40), gear = {"hair", "supermask", "badge", "cape"}, desc = "Faster than a ghost. Not braver though."},
	{id = "RockStar", name = "Rock Star", rarity = "Epic", mult = 4, shirt = rgb(30, 30, 36), pants = rgb(40, 40, 50), hair = rgb(200, 40, 120), gear = {"herohair", "sunglasses", "lute"}, desc = "On a world tour of haunted houses."},
	{id = "Vampire", name = "Count Vampire", rarity = "Epic", mult = 4, skin = rgb(225, 225, 235), shirt = rgb(40, 30, 40), pants = rgb(26, 22, 28), hair = rgb(20, 18, 24), cape = rgb(20, 12, 20), gear = {"hair", "fangs", "vampcollar", "cape"}, desc = "Came to visit his cousin. Wrong house."},
	{id = "Slayer", name = "Monster Slayer", rarity = "Epic", mult = 4, courage = 0.7, shirt = rgb(70, 30, 30), pants = rgb(30, 28, 30), cape = rgb(40, 20, 24), gear = {"slayerhat", "coat", "cape", "silversword"}, desc = "The real deal. Good luck scaring this one."},
	-- Legendarios
	{id = "King", name = "The King", rarity = "Legendary", mult = 8, scale = 1.1, shirt = rgb(140, 28, 44), pants = rgb(60, 30, 70), cape = rgb(170, 20, 40), hair = rgb(200, 196, 190), gear = {"crown", "beard", "royalcape", "scepter"}, desc = "His Majesty demands to be frightened."},
	{id = "Diamond", name = "Diamond Visitor", rarity = "Legendary", mult = 10, diamond = true, variant = "Diamond", shirt = rgb(120, 230, 255), pants = rgb(80, 180, 230), gear = {"hair", "sunglasses"}, desc = "Made of pure diamonds. Drops x10 coins!"},
	{id = "Celebrity", name = "Celebrity", rarity = "Legendary", mult = 8, shirt = rgb(255, 210, 90), pants = rgb(40, 40, 50), hair = rgb(250, 230, 150), gear = {"herohair", "sunglasses", "camera"}, desc = "Famous for being famous. Screams on camera."},
	{id = "MadScientist", name = "Mad Scientist", rarity = "Legendary", mult = 8, shirt = rgb(120, 160, 120), pants = rgb(50, 50, 60), hair = rgb(240, 240, 245), gear = {"wildhair", "goggles", "labcoat", "flask"}, desc = "IT'S ALIVE! ...and it's chasing him."},
	{id = "Alien", name = "Alien", rarity = "Legendary", mult = 8, bald = true, skin = rgb(120, 230, 120), shirt = rgb(150, 150, 170), pants = rgb(120, 120, 140), gear = {"antenna", "sunglasses"}, desc = "Came from very far to visit YOUR house."},
	-- Míticos
	{id = "Rainbow", name = "Rainbow Visitor", rarity = "Mythic", mult = 25, rainbow = true, shirt = rgb(255, 80, 80), pants = rgb(80, 120, 255), gear = {"hair", "sunglasses"}, desc = "A legend among legends. Drops x25 coins!"},
	{id = "Santa", name = "Lost Santa", rarity = "Mythic", mult = 20, shirt = rgb(200, 30, 40), pants = rgb(200, 30, 40), hair = rgb(240, 240, 240), gear = {"santahat", "beard", "giftsack"}, desc = "Wrong holiday. Very wrong house."},
	{id = "Horseman", name = "Headless Horseman", rarity = "Mythic", mult = 22, courage = 0.8, shirt = rgb(34, 28, 38), pants = rgb(46, 34, 30), cape = rgb(20, 16, 24), gear = {"headless", "cape", "pumpkinhand"}, desc = "Lost his head in another haunted house."},
	{id = "Cosmic", name = "Cosmic Wanderer", rarity = "Mythic", mult = 25, cosmic = true, skin = rgb(40, 20, 80), shirt = rgb(30, 15, 70), pants = rgb(20, 10, 50), gear = {"cosmos", "cape", "halo"}, cape = rgb(60, 30, 140), desc = "Born from a dying star. Drops x25 coins!"},
	-- Secreto (uno solo): más grande que nadie, lentísimo y nunca llega hecho de otra materia (secret)
	{id = "PumpkinKing", name = "The Pumpkin King", rarity = "Secret", mult = 100, scale = 1.75, secret = true, bald = true,
		skin = rgb(30, 22, 36), shirt = rgb(96, 40, 160), pants = rgb(34, 18, 46), shoes = rgb(24, 18, 28), cape = rgb(70, 20, 116),
		gear = {"pumpkinking", "kingrobe", "royalcape", "kingscepter", "soulorb"}, desc = "Ruler of every haunted house. Nobody has ever seen him scream. Drops x100 coins!"},
}
Config.VisitorById = {}
for _, v in Config.Visitors do
	Config.VisitorById[v.id] = v
end
Config.VISITOR_DISCOVER_BONUS = 15 -- monedas × mult la primera vez que asustas a un visitante nuevo

-- Variantes de material: muy de vez en cuando (VARIANT_CHANCE) cualquier visitante llega hecho de otra materia
-- (chocolate, mármol, hielo, oro... diamante). Cuál, por weight; mult multiplica sus monedas. El aspecto lo pone
-- Outfits.applyVariant (def.variant). Los que ya son de una materia (Golden, Diamond) o brillan (arcoíris, cósmico), no.
Config.VARIANT_CHANCE = 0.012
Config.Variants = {
	{id = "Chocolate", name = "Chocolate", weight = 30, mult = 2, color = rgb(170, 105, 60)},
	{id = "Marble", name = "Marble", weight = 26, mult = 2.5, color = rgb(235, 232, 225)},
	{id = "Ice", name = "Frozen", weight = 22, mult = 3, color = rgb(160, 220, 255)},
	{id = "Gold", name = "Golden", weight = 18, mult = 4, color = rgb(255, 196, 50)},
	{id = "Ecto", name = "Ectoplasm", weight = 14, mult = 4, color = rgb(120, 255, 150)},
	{id = "Lava", name = "Molten", weight = 10, mult = 5, color = rgb(255, 110, 30)},
	{id = "Emerald", name = "Emerald", weight = 8, mult = 6, color = rgb(60, 220, 120)},
	{id = "Ruby", name = "Ruby", weight = 6, mult = 7, color = rgb(240, 50, 90)},
	{id = "Diamond", name = "Diamond", weight = 4, mult = 10, color = rgb(150, 235, 255)},
	{id = "Obsidian", name = "Void", weight = 2, mult = 15, color = rgb(170, 90, 255)},
}
Config.VariantById = {}
for _, v in Config.Variants do
	Config.VariantById[v.id] = v
end

-- (con suerte extra, como mucho la mitad de los visitantes llegan de otra materia)
function Config.variantChance(boost)
	return math.min(0.5, Config.VARIANT_CHANCE * (boost or 1))
end

function Config.rollVariant(rng, boost)
	rng = rng or Random.new()
	if rng:NextNumber() >= Config.variantChance(boost) then
		return nil
	end
	local total = 0
	for _, v in Config.Variants do
		total += v.weight
	end
	local x = rng:NextNumber() * total
	for _, v in Config.Variants do
		x -= v.weight
		if x <= 0 then
			return v
		end
	end
	return Config.Variants[1]
end

---------- Nivel del jugador (suerte) ----------
-- El jugador sube de nivel (1..PLAYER_MAX_LEVEL) con la experiencia de asustar en su casa y del Tower Defense.
-- Se guarda como atributo PXP del jugador (solo lo cambia el servidor). Cada nivel es más suerte: los visitantes
-- raros pesan más (cuanto más raros, más se multiplican; los comunes no cambian).
Config.PLAYER_MAX_LEVEL = 100
Config.PXP_SCARE = 1 -- por cada susto que funciona en tu casa
Config.PXP_FINISH = 4 -- × índice de rareza (común 1 ... mítico 6) por visitante que huye o atrapas
Config.PXP_TD_WAVE = 8 -- por oleada superada en el Tower Defense
Config.LUCK_PER_LEVEL = 0.03 -- cada nivel: +3% × (índice de rareza - 1) al peso de esa rareza
-- Cada nivel del dueño: sus visitantes se asustan menos (el miedo les sube entre 1 + lv·LEVEL_COURAGE) pero sueltan
-- más monedas (× 1 + lv·LEVEL_COINS). A nivel 100: un 30% del miedo y el triple de monedas.
Config.LEVEL_COURAGE = 0.024
Config.LEVEL_COINS = 0.02

function Config.levelFear(lv)
	return 1 / (1 + ((lv or 1) - 1) * Config.LEVEL_COURAGE)
end

-- Cuando TÚ visitas otra casa: parte del miedo que sientes según tu nivel. Baja en curva de VISIT_FEAR_L1 (nivel 1)
-- a VISIT_FEAR_MAX (nivel máximo); a nivel máximo además el miedo nunca llega a 100 (puedes entrar en cualquier casa)
Config.VISIT_FEAR_L1 = 0.5
Config.VISIT_FEAR_MAX = 0.04
function Config.visitFear(lv)
	local t = math.clamp(((lv or 1) - 1) / (Config.PLAYER_MAX_LEVEL - 1), 0, 1)
	return Config.VISIT_FEAR_L1 * (Config.VISIT_FEAR_MAX / Config.VISIT_FEAR_L1) ^ t
end

function Config.levelCoins(lv)
	return 1 + ((lv or 1) - 1) * Config.LEVEL_COINS
end

-- Monedas sin recoger a partir de las que tu casa empieza a soltar menos, y el multiplicador con 'pile' en el suelo
function Config.coinPileCap(lv)
	return Config.COIN_PILE_BASE + ((lv or 1) - 1) * Config.COIN_PILE_LEVEL
end
-- capMult: la Aspiradora de almas aguanta más (VACUUM_CAP)
function Config.coinPileMult(pile, lv, capMult)
	local cap = Config.coinPileCap(lv) * (capMult or 1)
	return pile <= cap and 1 or 0.5 ^ ((pile - cap) / (cap * Config.COIN_PILE_HALF))
end

-- Lo rápido que camina un visitante: según su rareza y, si llega hecho de otra materia, más lento cuanto más valiosa
-- (un mítico de lava va a ~1/3 de lo normal)
function Config.visitorSpeed(rarity, variant)
	return (rarity.speed or 1) / (1 + (variant and variant.mult or 0) * 0.05)
end

function Config.pxpNeed(lv)
	return math.floor(50 * lv ^ 1.5 / 5 + 0.5) * 5
end

-- Nivel con esa experiencia, lo que lleva del nivel y lo que necesita para el siguiente (0 en el máximo)
function Config.playerLevelOf(xp)
	local lv = 1
	xp = xp or 0
	while lv < Config.PLAYER_MAX_LEVEL and xp >= Config.pxpNeed(lv) do
		xp -= Config.pxpNeed(lv)
		lv += 1
	end
	return lv, xp, lv < Config.PLAYER_MAX_LEVEL and Config.pxpNeed(lv) or 0
end

function Config.playerLevel(plr)
	return (Config.playerLevelOf(plr and plr:GetAttribute("PXP") or 0))
end

function Config.addPlayerXP(plr, n)
	if plr and plr.Parent and n > 0 then
		plr:SetAttribute("PXP", (plr:GetAttribute("PXP") or 0) + n)
	end
end

-- Multiplicador de suerte de una rareza a ese nivel, y la probabilidad (%) de cada rareza
function Config.luckMult(i, lv)
	return 1 + ((lv or 1) - 1) * Config.LUCK_PER_LEVEL * (i - 1)
end
-- Suerte extra (x10, x100) que solo pueden activarse los de LUCK_ADMINS: botón junto a la tarjeta de nivel
-- (NivelJugador); Juego lo comprueba y pone el atributo LuckBoost del jugador (no se guarda: al volver, x1).
-- Multiplica el peso de las rarezas, más cuanto más raras (el mítico, por todo el boost; la común, nada), y la
-- probabilidad de las variantes de material.
Config.LUCK_ADMINS = {[1718637537] = true} -- lebrowsent
Config.LUCK_BOOSTS = {1, 10, 100}
-- Siempre al nivel máximo (solo estos UserId): Juego les sube la experiencia al entrar
Config.MAX_LEVEL_USERS = {} -- (vacío: lebrowsent empieza desde cero, 2026-10-29)

-- Experiencia total para llegar al nivel lv desde el 1
function Config.pxpTotal(lv)
	local n = 0
	for k = 1, math.min(lv, Config.PLAYER_MAX_LEVEL) - 1 do
		n += Config.pxpNeed(k)
	end
	return n
end

function Config.rarityChances(lv, boost)
	local w, total = {}, 0
	for i, r in Config.Rarities do
		w[i] = r.weight * Config.luckMult(i, lv) * (boost or 1) ^ ((i - 1) / (#Config.Rarities - 1))
		total += w[i]
	end
	for i in w do
		w[i] = w[i] / total * 100
	end
	return w
end

-- Visitante al azar: primero la rareza (por peso, con la suerte del nivel lv) y luego uno de esa rareza
function Config.rollVisitor(rng, lv, boost)
	rng = rng or Random.new()
	local chances = Config.rarityChances(lv, boost)
	local x = rng:NextNumber() * 100
	local rarity = Config.Rarities[1]
	for i, r in Config.Rarities do
		x -= chances[i]
		if x <= 0 then
			rarity = r
			break
		end
	end
	local pool = {}
	for _, v in Config.Visitors do
		if v.rarity == rarity.id then
			table.insert(pool, v)
		end
	end
	return pool[rng:NextInteger(1, #pool)], rarity
end

---------- Recompensas ----------
Config.BRAVE_BASE = 8 -- monedas por llegar al fondo de una casa ajena...
Config.BRAVE_PER_FEAR = 0.08 -- ...más esto por cada punto de poder (miedo) de la casa
Config.BRAVE_COOLDOWN = 180 -- la misma casa no vuelve a pagarte hasta pasados estos segundos
Config.DAILY = {50, 75, 100, 150, 200, 275, 400} -- premio diario según los días seguidos (del 7º en adelante, el último)
Config.OFFLINE_RATE = 0.04 -- monedas por minuto fuera = suma de "pay" de tus sustos colocados × esto
Config.OFFLINE_MAX_H = 6 -- como mucho se cuentan estas horas fuera
Config.AUTOSAVE = 120 -- segundos entre guardados automáticos

---------- Monedas ----------
-- Ya no hay cofre: cada susto que funciona hace que el visitante (bot o jugador) suelte monedas en el suelo de la
-- casa. Solo el dueño las recoge: al acercarse vuelan hacia él.
Config.COIN_RATE = 0.4 -- todo lo que sueltan los visitantes se multiplica por esto (equilibrio: progreso lento)
Config.COIN_VALUE = 3 -- lo que vale como mucho cada moneda (y al menos 3 monedas: un susto de 6 suelta 3 de 2)
Config.COIN_MAX = 80 -- piezas de moneda como mucho por casa: a partir de ahí lo nuevo se suma a las que ya hay (no se pierde)
-- Monedas sin recoger: no caducan, pero cuando en el suelo hay más de coinPileCap (sube con tu nivel) los visitantes
-- sueltan cada vez menos, de forma exponencial (x0.5 cada COIN_PILE_HALF × tope de más). Hay que volver a recogerlas.
Config.COIN_PILE_BASE = 300 -- tope a nivel 1...
Config.COIN_PILE_LEVEL = 30 -- ...+ esto por nivel (nivel 50: 1770; nivel 100: 3270)
Config.COIN_PILE_HALF = 0.25
Config.COIN_MAGNET = 9 -- a esta distancia de su dueño, las monedas vuelan hacia él

---------- Sustos ----------
-- pay: dinero para el dueño cada vez que asusta (× combo). fear: miedo que mete al visitante (100 = huye).
-- radius: a qué distancia salta. size: hueco que ocupa en el suelo (ancho, fondo).
-- solid: choca (no se atraviesa: la ruta lo rodea). catches: si te toca, te atrapa. ceiling: cuelga del techo.
-- slots: espacios de la casa que ocupa (1 si no se dice). wheel: solo sale en la ruleta (no se vende en la tienda).
-- facing: ataca hacia delante, en un sector de REACH_ANGLE grados (al construir se ve su alcance y dirección); los
-- demás saltan en un círculo a su alrededor.
Config.REACH_ANGLE = 120
Config.RESCARE = 120 -- segundos hasta que un mismo susto puede volver a asustar a la misma persona (aunque salga y entre)
Config.Categories = {
	Basico = {name = "Basic", color = Color3.fromRGB(110, 200, 120)},
	Criatura = {name = "Creature", color = Color3.fromRGB(150, 120, 255)},
	Trampa = {name = "Trap", color = Color3.fromRGB(255, 160, 60)},
	Legendario = {name = "Legendary", color = Color3.fromRGB(255, 70, 100)},
	Especial = {name = "Special", color = Color3.fromRGB(70, 230, 255)},
}

Config.Scares = {
	Armario = {
		name = "Wardrobe", cat = "Basico", price = 60, pay = 6, fear = 25, radius = 8, size = Vector2.new(5, 3.5), solid = true, facing = true,
		desc = "The doors burst open and something stares at you from inside.",
	},
	Luz = {
		name = "Flickering Light", cat = "Basico", price = 40, pay = 4, fear = 12, radius = 9, size = Vector2.new(2.5, 2.5), ceiling = true,
		desc = "It flickers, crackles and plunges the room into darkness.",
	},
	Gramofono = {
		name = "Gramophone", cat = "Basico", price = 90, pay = 8, fear = 22, radius = 8, size = Vector2.new(3, 3), solid = true,
		desc = "A creepy lullaby starts playing by itself. The closer you get, the scarier it is.",
	},
	Fantasma = {
		name = "Ghost", cat = "Criatura", price = 150, pay = 10, fear = 30, radius = 7, size = Vector2.new(3, 3), catches = true, facing = true,
		desc = "It appears out of nowhere and floats in place. Walk into it and it rushes right through you: a huge fright!",
	},
	Muneca = {
		name = "Doll", cat = "Criatura", price = 250, pay = 14, fear = 35, radius = 8, size = Vector2.new(2.5, 2.5), solid = true, facing = true,
		desc = "It turns its head to watch you... then suddenly grows and screams at you.",
	},
	Sombra = {
		name = "Shadow", cat = "Criatura", price = 400, pay = 18, fear = 20, radius = 10, size = Vector2.new(3, 3), facing = true,
		desc = "It rises from the floor and stares at you. If you get too close, fear shoots up.",
	},
	Trampilla = {
		name = "Trapdoor", cat = "Trampa", price = 300, pay = 15, fear = 40, radius = 2.6, size = Vector2.new(5, 5),
		desc = "The floor opens under your feet and drops you back at the start of the room.",
	},
	Payaso = {
		name = "Clown", cat = "Legendario", price = 1500, pay = 40, fear = 30, radius = 10, size = Vector2.new(3, 3), catches = true, facing = true,
		desc = "It laughs and stares at you... Walk into it and it grabs you: a terrifying fright!",
	},
	Arana = {
		name = "Giant Spider", cat = "Criatura", price = 600, pay = 22, fear = 32, radius = 6, size = Vector2.new(3, 3), ceiling = true,
		desc = "It drops from the ceiling on its thread, right down to the height of your face.",
	},
	Ataud = {
		name = "Coffin", cat = "Trampa", price = 450, pay = 18, fear = 34, radius = 7, size = Vector2.new(3.5, 2.5), solid = true, facing = true,
		desc = "Something knocks from inside... then the lid bursts open and a skeleton grabs at you.",
	},
	Zombie = {
		name = "Zombie", cat = "Legendario", price = 2500, pay = 55, fear = 34, radius = 9, size = Vector2.new(3, 3), catches = true, facing = true,
		desc = "It twitches awake, roars and stares you down... Get too close and it bites: a terrifying fright!",
	},
	Parca = {
		name = "Grim Reaper", cat = "Legendario", price = 4000, pay = 70, fear = 30, radius = 11, size = Vector2.new(3, 3), catches = true, facing = true,
		desc = "It vanishes and reappears... again and again. If it touches you, the fright is terrifying.",
	},
}
---------- Sustos nuevos (también son tropas del Tower Defense) ----------
Config.Scares.Velas = {
	name = "Cursed Candles", cat = "Basico", price = 100, pay = 7, fear = 16, radius = 8, size = Vector2.new(2.5, 2.5), solid = true,
	desc = "The candles blaze up in green flames and a screaming skull rises from the smoke.",
}
Config.Scares.Murcielagos = {
	name = "Bat Swarm", cat = "Basico", price = 120, pay = 9, fear = 18, radius = 9, size = Vector2.new(3, 3),
	desc = "The bats hanging from the old coat rack wake up and swarm around your face.",
}
Config.Scares.Cuervo = {
	name = "Raven", cat = "Basico", price = 140, pay = 10, fear = 20, radius = 12, size = Vector2.new(3, 3), solid = true, facing = true,
	desc = "It watches you with red eyes from its stump... then spreads its wings and shrieks.",
}
Config.Scares.Calabaza = {
	name = "Pumpkin Bomber", cat = "Basico", price = 160, pay = 11, fear = 24, radius = 9, size = Vector2.new(3.5, 4.5), solid = true, facing = true,
	desc = "A creaky catapult that launches a cackling jack-o'-lantern at you.",
}
Config.Scares.Espantapajaros = {
	name = "Scarecrow", cat = "Criatura", price = 350, pay = 16, fear = 28, radius = 8, size = Vector2.new(3, 2.5), solid = true, facing = true,
	desc = "Just a scarecrow... until its head turns, its eyes burn and it tears itself off the pole.",
}
Config.Scares.Momia = {
	name = "Mummy", cat = "Criatura", price = 500, pay = 20, fear = 32, radius = 7, size = Vector2.new(3.2, 3.4), solid = true, catches = true, facing = true,
	desc = "It wakes up in front of its sarcophagus and lashes its bandages at you. If it grabs you, the fright is terrifying.",
}
Config.Scares.Bruja = {
	name = "Witch", cat = "Criatura", price = 700, pay = 24, fear = 34, radius = 9, size = Vector2.new(4, 4), solid = true, facing = true,
	desc = "She cackles over her cauldron and hurls a bubbling potion at you.",
}
Config.Scares.Poltergeist = {
	name = "Poltergeist", cat = "Criatura", price = 800, pay = 26, fear = 30, radius = 9, size = Vector2.new(4, 3), solid = true, facing = true, wheel = true,
	desc = "The old dresser rattles, its drawers burst open and a ghost girl crawls out.",
}
Config.Scares.Banshee = {
	name = "Banshee", cat = "Criatura", price = 900, pay = 28, fear = 30, radius = 11, size = Vector2.new(3, 3), facing = true, wheel = true,
	desc = "A ghostly woman rises and lets out a wail so loud it pushes you back.",
}
Config.Scares.Manos = {
	name = "Grasping Hands", cat = "Trampa", price = 350, pay = 16, fear = 36, radius = 2.6, size = Vector2.new(5, 5),
	desc = "Rotten hands burst out of the floor and grab your ankles.",
}
Config.Scares.Espejo = {
	name = "Haunted Mirror", cat = "Trampa", price = 600, pay = 20, fear = 30, radius = 7, size = Vector2.new(3.5, 2), solid = true, facing = true, wheel = true,
	desc = "Your reflection smiles at you... then presses its hands on the glass and breaks it.",
}
Config.Scares.Pozo = {
	name = "Soul Well", cat = "Trampa", price = 1200, pay = 30, fear = 22, radius = 8, size = Vector2.new(5, 5), solid = true, wheel = true, bonus = 25,
	desc = "Lost souls swirl out of the well moaning... and drop extra coins for you.",
}
Config.Scares.HombreLobo = {
	name = "Werewolf", cat = "Legendario", price = 5000, pay = 85, fear = 36, radius = 10, size = Vector2.new(3.5, 3.5), solid = true, catches = true, facing = true,
	wheel = true, slots = 2,
	desc = "It howls, then roars with its claws up. Get close and it lunges: a terrifying fright!",
}
Config.Scares.Vampiro = {
	name = "Vampire Lord", cat = "Legendario", price = 6500, pay = 100, fear = 34, radius = 11, size = Vector2.new(3.5, 3), solid = true, catches = true, facing = true,
	wheel = true, slots = 2,
	desc = "He spreads his cape like wings and a cloud of bats bursts out of it. His touch is a terrifying fright.",
}
Config.Scares.Jinete = {
	name = "Headless Horseman", cat = "Legendario", price = 8000, pay = 120, fear = 38, radius = 12, size = Vector2.new(4.5, 6.5), solid = true, catches = true, facing = true,
	wheel = true, slots = 3, mythic = true,
	desc = "Thunder! The horse rears up and its headless rider hurls a flaming pumpkin at you.",
}
Config.Scares.Dragon = {
	name = "Bone Dragon", cat = "Legendario", price = 12000, pay = 160, fear = 40, radius = 13, size = Vector2.new(7, 6.5), solid = true, catches = true, facing = true,
	wheel = true, slots = 3, mythic = true,
	desc = "A skeletal dragon spreads its wings and breathes ghost fire. The rarest beast of all.",
}

---------- Personajes nuevos (se quedan en su sitio: solo animaciones y proyectiles) ----------
Config.Scares.HombreCalabaza = {
	name = "Pumpkinhead", cat = "Basico", price = 200, pay = 12, fear = 24, radius = 8, size = Vector2.new(3, 3), solid = true, facing = true,
	desc = "Slumped on a hay bale like a decoration... until its grin catches fire and its vines lash at your ankles.",
}
Config.Scares.Esqueleto = {
	name = "Skeleton", cat = "Criatura", price = 550, pay = 21, fear = 32, radius = 9, size = Vector2.new(3, 3), solid = true, facing = true,
	desc = "Rattles awake against its tombstone, cackles with a clacking jaw and throws its own skull at you.",
}
Config.Scares.Frankenstein = {
	name = "Frankenstein", cat = "Legendario", price = 7000, pay = 105, fear = 36, radius = 11, size = Vector2.new(4.5, 3.5), solid = true, catches = true, facing = true,
	wheel = true, slots = 2,
	desc = "Lightning strikes the lab! The monster snaps its straps and the tesla coils zap you. Get close and it grabs you: a terrifying fright!",
}
Config.Scares.Demonio = {
	name = "Demon", cat = "Legendario", price = 10000, pay = 140, fear = 40, radius = 12, size = Vector2.new(5.5, 4.5), solid = true, catches = true, facing = true,
	wheel = true, slots = 3, mythic = true,
	desc = "It rises from a burning pentagram, spreads its wings and hurls a hellfire orb. Its claws are pure terror.",
}

-- Los sustos buenos cuestan muchísimo más que su precio base: × 2.5 × (1 + precio / 500)
-- (40 → 110, 200 → 700, 1500 → 15000, 12000 → 750000)
for _, def in Config.Scares do
	def.price = math.floor(def.price * 2.5 * (1 + def.price / 500) / 5 + 0.5) * 5
end

-- Espacios de la casa que ocupa un susto
function Config.slots(t)
	local def = Config.Scares[t]
	return def and def.slots or 1
end

-- ¿Se vende en la tienda (por monedas)? Solo los básicos: los demás salen de las ruletas, de las skins de la Shop
-- (con gemas) o con Robux (Config.sources)
function Config.inShop(t)
	local def = Config.Scares[t]
	return def ~= nil and def.cat == "Basico" and not def.special and not def.wheel
end

Config.ScareOrder = {
	"Armario", "Luz", "Gramofono", "Velas", "Murcielagos", "Cuervo", "Calabaza", "HombreCalabaza",
	"Fantasma", "Muneca", "Sombra", "Espantapajaros", "Esqueleto", "Momia", "Arana", "Bruja", "Poltergeist", "Banshee",
	"Trampilla", "Manos", "Ataud", "Espejo", "Pozo",
	"Payaso", "Zombie", "Parca", "HombreLobo", "Vampiro", "Frankenstein", "Jinete", "Demonio", "Dragon",
}
Config.StarterScares = {Armario = 1, Luz = 1, Fantasma = 1}

---------- Sustos especiales y skins ----------
-- base: el susto normal del que copian modelo y comportamiento (los modelos los hace ServerStorage.SkinsBuilder en
-- Assets.Scares). Las skins NO son sustos: son solo el aspecto de su susto base. Se compran una vez con gemas (acción
-- BuySkin, en las ofertas de la Shop y solo si tienes su susto base) y se equipan (acción EquipSkin): desde entonces
-- ese susto, en casa y en el Tower Defense, sale con el modelo de la skin, pero sigue siendo el mismo susto (mismas
-- monedas, miedo, daño, nivel y estrellas). Atributos del jugador: OwnSkin_<skin> = true y Skin_<base> = la equipada.
-- rarity: una de Config.Rarities (el color y el nombre de su carta en la Shop). simple: solo cambia color y material.
local function special(base, t)
	local b = Config.Scares[base]
	t.base, t.special, t.cat, t.price = base, true, "Especial", 0
	t.pay, t.fear = b.pay, b.fear -- (una skin no cambia nada del susto: lo que enseñan las fichas es lo de su base)
	t.radius, t.size, t.solid, t.catches, t.ceiling, t.facing = b.radius, b.size, b.solid, b.catches, b.ceiling, b.facing
	t.slots, t.mythic, t.bonus = b.slots, b.mythic, b.bonus
	return t
end
local function skin(base, t)
	t.skin = true
	return special(base, t)
end
Config.Scares.FantasmaEcto = skin("Fantasma", {name = "Ecto Phantom", rarity = "Rare", gems = 120, tint = Color3.fromRGB(90, 255, 120),
	desc = "A ghost made of glowing ectoplasm that oozes fear."})
Config.Scares.MunecaReina = skin("Muneca", {name = "Porcelain Queen", rarity = "Rare", gems = 150, tint = Color3.fromRGB(240, 220, 255),
	desc = "The queen of all dolls. Her scream cracks glass."})
Config.Scares.AranaAbismo = skin("Arana", {name = "Abyss Spider", rarity = "Epic", gems = 400, tint = Color3.fromRGB(150, 60, 255),
	desc = "It crawls up from the abyss with glowing purple eyes."})
Config.Scares.PayasoInfernal = skin("Payaso", {name = "Inferno Clown", rarity = "Epic", gems = 900, tint = Color3.fromRGB(255, 80, 30),
	desc = "A clown on fire. Its laugh burns."})
Config.Scares.ZombiePlaga = skin("Zombie", {name = "Plague Zombie", rarity = "Epic", gems = 1000, tint = Color3.fromRGB(150, 210, 60),
	desc = "Rotting and toxic, dripping green slime."})
Config.Scares.ParcaDorada = skin("Parca", {name = "Golden Reaper", rarity = "Legendary", gems = 1600, tint = Color3.fromRGB(255, 200, 60),
	desc = "Death itself, dressed in gold."})
-- Temas de las skins nuevas: color (el de su carta en la Shop) y lo que usa SkinsBuilder para hacer su modelo: cada
-- pieza toma el color de la escala dark → mid → light según lo clara que era (así se sigue viendo qué susto es), lo
-- que brilla pasa a accent, mat/tr/refl cambian el material y fx es su aura (partículas).
Config.SkinThemes = {
	Cursed = {color = rgb(160, 80, 230), dark = rgb(30, 14, 44), mid = rgb(92, 44, 130), light = rgb(186, 140, 236), accent = rgb(110, 255, 140), tint = rgb(140, 100, 255), fx = "souls"},
	Frost = {color = rgb(120, 210, 255), dark = rgb(26, 64, 116), mid = rgb(104, 176, 236), light = rgb(226, 246, 255), accent = rgb(150, 240, 255), mat = Enum.Material.Ice, refl = 0.15, fx = "frost"},
	Pharaoh = {color = rgb(255, 196, 60), dark = rgb(16, 36, 110), mid = rgb(190, 116, 26), light = rgb(255, 204, 70), accent = rgb(90, 180, 255), mat = Enum.Material.Foil, refl = 0.08, fx = "gold"},
	Blood = {color = rgb(235, 40, 60), dark = rgb(30, 6, 10), mid = rgb(150, 18, 34), light = rgb(250, 206, 196), accent = rgb(255, 40, 56), fx = "blood"},
	-- (los de las skins simples: solo paleta y material, como las variantes de color)
	Gold = {color = rgb(255, 200, 60), dark = rgb(120, 70, 10), mid = rgb(220, 150, 30), light = rgb(255, 226, 120), accent = rgb(255, 245, 190), mat = Enum.Material.Foil, refl = 0.15, fx = "gold"},
	Ghost = {color = rgb(110, 230, 255), dark = rgb(70, 150, 190), mid = rgb(140, 220, 245), light = rgb(230, 255, 255), accent = rgb(140, 255, 255), mat = Enum.Material.Glass, tr = 0.35, refl = 0.1, fx = "spectral"},
	Albino = {color = rgb(240, 236, 250), dark = rgb(150, 140, 160), mid = rgb(214, 208, 222), light = rgb(255, 255, 255), accent = rgb(255, 50, 70), fx = "sparkle"},
	Inferno = {color = rgb(255, 90, 20), dark = rgb(40, 10, 6), mid = rgb(204, 54, 12), light = rgb(255, 196, 70), accent = rgb(255, 150, 30), mat = Enum.Material.CrackedLava, glowNames = {"membrane"}, fx = "fire"},
}

-- Skins con tema: theme: sus colores (Config.SkinThemes); SkinsBuilder les añade además las piezas de su tema
-- (carámbanos, nemes, luna de sangre, cuernos de fuego...), no solo el color. Sin bases ni decorado en el suelo: como
-- los sustos, solo el personaje
-- simples (solo color y material)
Config.Scares.CuervoAlbino = skin("Cuervo", {name = "Albino Raven", rarity = "Common", gems = 30, theme = "Albino", simple = true,
	desc = "A snow-white raven with blood-red eyes. Bad luck, but very pretty."})
Config.Scares.EsqueletoDorado = skin("Esqueleto", {name = "Golden Skeleton", rarity = "Uncommon", gems = 90, theme = "Gold", simple = true,
	desc = "Every bone dipped in gold. It still throws its own skull at you, just more expensively."})
Config.Scares.BrujaFantasma = skin("Bruja", {name = "Ghost Witch", rarity = "Rare", gems = 170, theme = "Ghost", simple = true,
	desc = "She died stirring her cauldron and never stopped. You can see right through her."})
-- temáticas (con piezas propias)
Config.Scares.ArmarioMaldito = skin("Armario", {name = "Cursed Wardrobe", rarity = "Rare", gems = 40, theme = "Cursed",
	desc = "Rotten violet wood and a hundred green eyes blinking in the dark between its doors."})
Config.Scares.CalabazaHelada = skin("HombreCalabaza", {name = "Frostbite Pumpkinhead", rarity = "Rare", gems = 75, theme = "Frost",
	desc = "A pumpkin frozen solid in a cursed winter, dripping with icicles."})
Config.Scares.MomiaFaraon = skin("Momia", {name = "Pharaoh Mummy", rarity = "Epic", gems = 150, theme = "Pharaoh",
	desc = "Wrapped in golden bandages and lapis jewels, the pharaoh wakes to curse the thieves."})
Config.Scares.LoboSangre = skin("HombreLobo", {name = "Blood Moon Werewolf", rarity = "Legendary", gems = 900, theme = "Blood",
	desc = "The red moon rises behind him. His eyes burn like coals."})
Config.Scares.DragonInfernal = skin("Dragon", {name = "Inferno Dragon", rarity = "Mythic", gems = 2500, theme = "Inferno",
	desc = "Molten bones and a heart of lava. The hottest beast ever summoned."})
-- El Rey Calabaza no copia a ninguno: es la versión jefe del alcalde Calabaza, con su modelo y su susto propios
Config.Scares.ReyCalabaza = {
	name = "Pumpkin King", cat = "Especial", special = true, price = 0, pay = 130, fear = 42, radius = 12, size = Vector2.new(4.5, 4),
	solid = true, catches = true, facing = true, slots = 2,
	desc = "The Mayor's dark side. His crown bursts into flames and he hurls a storm of jack-o'-lanterns. His touch is a terrifying fright.",
}
-- los especiales que pueden salir en la casilla Especial de la ruleta (las skins no: no son sustos)
Config.WheelSpecials = {"ReyCalabaza"}
-- las skins, en el orden de la Shop (de las más baratas a las más caras)
Config.SkinOrder = {
	"CuervoAlbino", "ArmarioMaldito", "CalabazaHelada", "EsqueletoDorado", "FantasmaEcto", "MunecaReina", "BrujaFantasma", "MomiaFaraon",
	"AranaAbismo", "LoboSangre", "PayasoInfernal", "ZombiePlaga", "ParcaDorada", "DragonInfernal",
}
-- Ofertas de skins (Daily Deals de la Shop): cada día (igual que las ofertas del día) salen SKIN_OFFERS skins de las
-- que puedes comprar (tienes su susto base), algunas rebajadas. Cada skin saca una "suerte" por periodo y salen las de más suerte: así, si
-- desbloqueas una skin nueva a mitad de periodo, las demás ofertas no se barajan. Igual en el servidor y en el cliente.
Config.SKIN_ROTATE = 86400
Config.SKIN_OFFERS = 5
Config.SKIN_DISCOUNTS = {0, 0, 10, 20, 25, 40}
function Config.skinPeriod(now)
	return math.floor(now / Config.SKIN_ROTATE)
end
-- unlocked(t): ¿puede comprar esa skin? (tiene su susto base y aún no es suya) Devuelve {skin, off (% de rebaja), price} de la más barata a la más cara
function Config.skinOffers(period, unlocked)
	local list = {}
	for i, t in Config.SkinOrder do
		if unlocked(t) then
			local rng = Random.new(period * 977 + i * 131)
			local score, off = rng:NextNumber(), Config.SKIN_DISCOUNTS[rng:NextInteger(1, #Config.SKIN_DISCOUNTS)]
			table.insert(list, {skin = t, score = score, off = off, price = math.max(1, math.floor(Config.Scares[t].gems * (1 - off / 100) + 0.5))})
		end
	end
	table.sort(list, function(a, b)
		return a.score > b.score
	end)
	for k = #list, Config.SKIN_OFFERS + 1, -1 do
		list[k] = nil
	end
	table.sort(list, function(a, b)
		return a.price < b.price
	end)
	return list
end

-- los especiales que son sustos de verdad (las skins no: van con su base)
Config.SpecialOrder = {"ReyCalabaza"}
-- las skins de cada susto, de la más común a la más rara (botón Skins de la pantalla Scares)
Config.SkinsOf = {}
for _, t in Config.SkinOrder do
	local base = Config.Scares[t].base
	Config.SkinsOf[base] = Config.SkinsOf[base] or {}
	table.insert(Config.SkinsOf[base], t)
end
for _, list in Config.SkinsOf do
	table.sort(list, function(a, b)
		return (Config.RarityIndex[Config.Scares[a].rarity] or 3) < (Config.RarityIndex[Config.Scares[b].rarity] or 3)
	end)
end

-- ¿Tiene esa skin? (comprada una vez, para siempre)
function Config.ownsSkin(plr, s)
	return plr ~= nil and plr:GetAttribute("OwnSkin_" .. s) == true
end
-- La skin equipada en el susto t (nil: el original)
function Config.equippedSkin(plr, t)
	local s = plr and plr:GetAttribute("Skin_" .. t)
	local def = typeof(s) == "string" and Config.Scares[s]
	return def and def.skin and def.base == t and Config.ownsSkin(plr, s) and s or nil
end
-- El modelo (de Assets.Scares) con el que sale el susto t de ese jugador: su skin equipada o el original
function Config.skinFor(plr, t)
	return Config.equippedSkin(plr, t) or t
end

---------- Curva de potencia ----------
-- Los flojos casi no hacen nada y los mejores arrasan: pay y fear se estiran según lo bueno que es cada susto (su
-- pay de arriba, que queda en basePay). pay → pay^1.5 / 2 (4 → 4, 10 → 16, 40 → 126, 160 → 1012) y fear × (pay/10)^0.55
-- (Luz 12 → 7, Fantasma 30, Parca 30 → 88, Dragón 40 → 184: los míticos hacen huir de un susto a casi cualquiera).
Config.PAY_CURVE = 1.5
Config.FEAR_CURVE = 0.55
for _, def in Config.Scares do
	def.basePay = def.pay
	def.pay = math.max(1, math.floor(def.pay ^ Config.PAY_CURVE / 2 + 0.5))
	def.fear = math.floor(def.fear * (def.basePay / 10) ^ Config.FEAR_CURVE + 0.5)
end

---------- Niveles de las tropas ----------
-- Cada susto que tienes es una tropa con su propio nivel (1..TROOP_MAX_LEVEL), que sube con la experiencia: cada vez que
-- asusta a alguien en tu casa y cada cazafantasmas que hace huir en el Tower Defense. Se guarda como atributo del
-- jugador XP_<tipo> (solo lo cambia el servidor). Cada nivel: +LEVEL_PAY de monedas por susto en casa y +LEVEL_FEAR de
-- miedo en el Tower Defense.
Config.TROOP_MAX_LEVEL = 10
Config.LEVEL_PAY = 0.06
Config.LEVEL_FEAR = 0.05
Config.XP_SCARE = 1 -- por cada susto que funciona en tu casa
Config.XP_FINISH = 6 -- si ese susto hace huir o atrapa al visitante
Config.XP_TD_KILL = 3 -- por cazafantasmas que hace huir en el Tower Defense
Config.XP_TD_WAVE = 4 -- a cada tipo de tropa desplegada, por oleada superada
Config.LEVEL_NAMES = {"Rookie", "Spooky", "Creepy", "Eerie", "Haunting", "Sinister", "Dreadful", "Terrifying", "Nightmarish", "Legend"}

-- Experiencia para pasar del nivel lv al siguiente
function Config.xpNeed(lv)
	return math.floor(35 * lv ^ 1.7 / 5 + 0.5) * 5
end

-- Nivel con esa experiencia, lo que lleva del nivel y lo que necesita para el siguiente (0 en el máximo)
function Config.levelOf(xp)
	local lv = 1
	xp = xp or 0
	while lv < Config.TROOP_MAX_LEVEL and xp >= Config.xpNeed(lv) do
		xp -= Config.xpNeed(lv)
		lv += 1
	end
	return lv, xp, lv < Config.TROOP_MAX_LEVEL and Config.xpNeed(lv) or 0
end

function Config.troopLevel(plr, t)
	return (Config.levelOf(plr:GetAttribute("XP_" .. t) or 0))
end

-- Suma experiencia a una tropa (en el servidor; los especiales no tienen nivel)
function Config.addXP(plr, t, n)
	local def = Config.Scares[t]
	if not (plr and plr.Parent and def) or def.special or n <= 0 then
		return
	end
	plr:SetAttribute("XP_" .. t, (plr:GetAttribute("XP_" .. t) or 0) + n)
end

---------- Gemas ----------
-- Las gemas se ganan en el Tower Defense (y con Robux) y se gastan en las skins de la Shop. Atributo Gems del
-- jugador, que solo cambia el servidor.
Config.TD_GEMS_WAVE = 1 -- gemas por oleada superada
Config.TD_GEMS_WIN = 10 -- gemas extra por ganar la partida
Config.SKIN_ANNOUNCE = 900 -- las skins de este precio en gemas o más se anuncian a todo el servidor
-- (Piezas del antiguo ensamblaje: ya no salen ni se usan; se siguen guardando, atributos Part_<id>)
Config.Parts = {
	Hueso = {name = "Old Bone", icon = "🦴", from = "td", w = 40},
	Ectoplasma = {name = "Ectoplasm", icon = "🧪", from = "td", w = 30},
	Engranaje = {name = "Rusty Gear", icon = "⚙️", from = "td", w = 30},
	Tela = {name = "Cursed Cloth", icon = "🧣", from = "npc", w = 50},
	Ojo = {name = "Glass Eye", icon = "👁️", from = "npc", w = 40},
	Calavera = {name = "Golden Skull", icon = "💀", from = "npc", w = 3},
}
Config.PartOrder = {"Hueso", "Ectoplasma", "Engranaje", "Tela", "Ojo", "Calavera"}

-- De dónde sale un susto: {"shop", "wheel", "skins"} (lo enseñan la tienda y la barra de sustos)
Config.SOURCE_NAMES = {shop = "Shop", wheel = "Wheels", skins = "Skins"}
function Config.sources(t)
	local def = Config.Scares[t]
	local list = {}
	if not def then
		return list
	end
	if Config.inShop(t) then
		table.insert(list, "shop")
	end
	if table.find(Config.ScareOrder, t) or table.find(Config.WheelSpecials, t) then
		table.insert(list, "wheel")
	end
	if def.gems then
		table.insert(list, "skins")
	end
	return list
end

-- "Wheels · Skins" (sin la tienda)
function Config.sourceText(t)
	local names = {}
	for _, s in Config.sources(t) do
		if s ~= "shop" then
			table.insert(names, Config.SOURCE_NAMES[s])
		end
	end
	return table.concat(names, " · ")
end

---------- Fusión (estrellas) ----------
-- Juntando copias repetidas del mismo susto (de la mochila) sube de estrella, hasta STAR_MAX. Cada estrella vale para
-- TODOS los de ese tipo (los colocados también): STAR_PAY[estrella] de monedas y STAR_FEAR[estrella] de miedo, y brillan
-- con un aura del color de su estrella. Se guarda como atributo Star_<tipo> del jugador (solo lo cambia el servidor).
Config.STAR_MAX = 3
Config.STAR_COST = {3, 4, 5} -- copias que se funden para pasar a ★1, ★2 y ★3
-- (una mejora pequeña por estrella, acumulada: no dispara la economía; se funden en el Caldero de Hexa, el cementerio)
Config.STAR_PAY = {0.15, 0.30, 0.50}
Config.STAR_FEAR = {0.05, 0.10, 0.15}
Config.STAR_COLORS = {Color3.fromRGB(255, 200, 60), Color3.fromRGB(80, 230, 255), Color3.fromRGB(255, 90, 220)}
Config.STAR_NAMES = {"Gold", "Diamond", "Mythic"}

function Config.starOf(plr, t)
	return plr and plr:GetAttribute("Star_" .. t) or 0
end

-- Los datos del susto con su estrella aplicada (lo demás, igual que en Config.Scares)
local starDefs = {}
function Config.starDef(t, star)
	local def = Config.Scares[t]
	if not def or (star or 0) <= 0 then
		return def
	end
	local key = t .. star
	if not starDefs[key] then
		starDefs[key] = setmetatable({
			pay = math.floor(def.pay * (1 + Config.STAR_PAY[star]) + 0.5),
			fear = math.floor(def.fear * (1 + Config.STAR_FEAR[star]) + 0.5),
			star = star,
		}, {__index = def})
	end
	return starDefs[key]
end

-- Monedas por susto de un jugador con ese tipo: su nivel de tropa y su estrella
function Config.scarePay(plr, t)
	local def = Config.starDef(t, Config.starOf(plr, t))
	return math.floor(def.pay * (1 + Config.LEVEL_PAY * (Config.troopLevel(plr, t) - 1)) + 0.5)
end

---------- Ruletas ----------
-- Cada ruleta tiene 8 casillas: una categoría y un peso (probabilidad en %). Cada WHEEL_ROTATE segundos cambia qué susto
-- hay en cada casilla (se elige al azar dentro de su categoría, igual en el servidor y en todos los clientes).
-- Las caras tienen más casillas buenas y con más peso.
Config.WHEEL_ROTATE = 6 * 3600
Config.WHEEL_SPIN_TIME = 5.5 -- lo que dura la animación (el servidor no deja girar otra vez antes)
Config.FREE_SPIN_WHEEL = 1 -- una tirada gratis en esta ruleta...
Config.FREE_SPIN_EVERY = 6 * 3600 -- ...cada tanto (la primera, nada más entrar)
-- pity: como mucho tantas tiradas seguidas sin premio gordo (Legendario o Especial); la siguiente lo trae seguro
Config.Wheels = {
	{name = "Creepy Wheel", price = 1200, pity = 60, color = Color3.fromRGB(110, 200, 120), slots = {
		{"Basico", 20}, {"Criatura", 6}, {"Basico", 20}, {"Criatura", 6}, {"Basico", 20}, {"Legendario", 1.5}, {"Basico", 20}, {"Criatura", 6},
	}},
	{name = "Haunted Wheel", price = 6000, pity = 45, color = Color3.fromRGB(150, 120, 255), slots = {
		{"Criatura", 15}, {"Trampa", 15}, {"Basico", 20}, {"Legendario", 3}, {"Criatura", 15}, {"Trampa", 15}, {"Criatura", 15}, {"Legendario", 3},
	}},
	{name = "Nightmare Wheel", price = 25000, pity = 30, color = Color3.fromRGB(255, 70, 100), slots = {
		{"Legendario", 5}, {"Criatura", 18}, {"Trampa", 15}, {"Legendario", 5}, {"Especial", 1}, {"Criatura", 18}, {"Trampa", 15}, {"Legendario", 5},
	}},
}

-- Los premios gordos pesan menos cuanto más fuertes: × (40 / basePay)^1.3 (Payaso 1, Parca 0.48, Dragón 0.16; el
-- Rey Calabaza 0.22). Lo usa wheelPrizes: el porcentaje de cada casilla depende del susto que le toque.
function Config.prizeOdds(t)
	local def = Config.Scares[t]
	if not Config.isJackpot(t) then
		return 1
	end
	return math.min(1, (40 / def.basePay) ^ 1.3)
end

-- ¿Es un premio gordo? (lo que cuenta para el pity y lo que se anuncia a todo el servidor)
function Config.isJackpot(t)
	local c = Config.Scares[t].cat
	return c == "Legendario" or c == "Especial"
end

-- Periodo actual (cambia cada WHEEL_ROTATE). En el cliente usa workspace:GetServerTimeNow() para ir a la par.
function Config.wheelPeriod(now)
	return math.floor(now / Config.WHEEL_ROTATE)
end

-- Los 8 premios {scare, peso} de la ruleta i en ese periodo. Sin repetir susto dentro de una ruleta si se puede.
function Config.wheelPrizes(i, period)
	local rng = Random.new(period * 7 + i)
	local byCat = {}
	for _, t in Config.ScareOrder do
		local c = Config.Scares[t].cat
		byCat[c] = byCat[c] or {}
		table.insert(byCat[c], t)
	end
	byCat.Especial = table.clone(Config.WheelSpecials)
	local used, list = {}, {}
	for k, slot in Config.Wheels[i].slots do
		local pool = {}
		for _, t in byCat[slot[1]] do
			if not used[t] then
				table.insert(pool, t)
			end
		end
		if #pool == 0 then
			pool = byCat[slot[1]]
		end
		local t = pool[rng:NextInteger(1, #pool)]
		used[t] = true
		list[k] = {scare = t, w = slot[2] * Config.prizeOdds(t)}
	end
	return list
end

---------- Casas que se compran ----------
-- Las casas no crecen: se compra otra casa (más grande) y sustituye a la tuya en la parcela. Las que ya tienes se
-- pueden volver a poner gratis. template: modelo en ServerStorage. rooms: salas de dentro (límite de sustos = rooms ×
-- SCARES_PER_ROOM). La primera es la que tiene todo el mundo al empezar.
Config.Houses = {
	{id = "Cottage", name = "Haunted Cottage", template = "CasaPrincipal", rooms = 1, price = 0,
		desc = "Your first haunted house. One room, room for " .. Config.SCARES_PER_ROOM .. " scares."},
	{id = "Long", name = "Long Haunted House", template = "CasaLarga", rooms = 2, price = 6000,
		desc = "A long, creaky house with two rooms: room for " .. 2 * Config.SCARES_PER_ROOM .. " scares."},
	{id = "Manor", name = "Haunted Manor", template = "CasaMansion", rooms = 3, price = 25000,
		desc = "A long manor with a haunted belfry on the roof: three rooms, room for " .. 3 * Config.SCARES_PER_ROOM .. " scares."},
	-- más ancha y alta por dentro (width/height) y con más espacios para sustos (spaces) que las demás
	{id = "Grand", name = "Grand Haunted Manor", template = "CasaGran", rooms = 3, price = 75000, width = 36, height = 15, spaces = 20,
		desc = "A wide, tall Victorian manor with a corner tower, glowing dormers and a belfry: three big rooms, room for 20 scares."},
}
-- Medidas de dentro de una casa (según su plantilla): ancho, alto y espacios para sustos
function Config.houseDims(template, rooms)
	for _, def in Config.Houses do
		if def.template == template then
			return def.width or Config.ROOM_W, def.height or Config.ROOM_H, def.spaces or def.rooms * Config.SCARES_PER_ROOM
		end
	end
	return Config.ROOM_W, Config.ROOM_H, (rooms or 1) * Config.SCARES_PER_ROOM
end
-- Las mismas medidas leídas del modelo de una casa ya construida (atributos que pone el servidor)
function Config.roomW(house)
	return house and house:GetAttribute("RoomW") or Config.ROOM_W
end
function Config.roomH(house)
	return house and house:GetAttribute("RoomH") or Config.ROOM_H
end
function Config.house(id)
	for _, def in Config.Houses do
		if def.id == id then
			return def
		end
	end
	return nil
end

---------- Habitaciones ----------
-- Decoración de cada sala, de la entrada al fondo (las casas de varias salas usan las primeras).
-- props: decoración fija {modelo, x, z dentro de la sala, giro, altura opcional}. Los sustos no pueden pisarla.
Config.Rooms = {
	{
		name = "Entrance Hall",
		floor = {Enum.Material.WoodPlanks, Color3.fromRGB(78, 54, 40)},
		wall = {Enum.Material.Fabric, Color3.fromRGB(96, 36, 48)},
		props = {{"Butaca", -11.1, 19, 1}, {"Retrato", 13.2, 19, 3, 6.5}, {"Candelabro", 11.5, 3, 3}},
	},
	{
		name = "Hallway",
		floor = {Enum.Material.WoodPlanks, Color3.fromRGB(64, 46, 36)},
		wall = {Enum.Material.Wood, Color3.fromRGB(58, 66, 56)},
		props = {{"Retrato", -13.2, 5, 1, 6.5}, {"Retrato", 13.2, 19, 3, 6.5}, {"Candelabro", -11.5, 20, 1}},
	},
	{
		name = "Basement",
		floor = {Enum.Material.Cobblestone, Color3.fromRGB(70, 68, 66)},
		wall = {Enum.Material.Brick, Color3.fromRGB(78, 54, 46)},
		props = {{"Barril", -11.5, 4, 0}, {"Barril", 11.5, 20, 0}, {"Candelabro", 11.5, 4, 3}},
	},
	{
		name = "Attic",
		floor = {Enum.Material.WoodPlanks, Color3.fromRGB(104, 80, 56)},
		wall = {Enum.Material.WoodPlanks, Color3.fromRGB(88, 68, 50)},
		props = {{"Butaca", 11.1, 5, 3}, {"Barril", -11.5, 20, 0}, {"Retrato", -13.2, 5, 1, 6.5}},
	},
	{
		name = "Graveyard",
		floor = {Enum.Material.Grass, Color3.fromRGB(44, 56, 38)},
		wall = {Enum.Material.Slate, Color3.fromRGB(56, 58, 66)},
		props = {{"Lapida", -9.5, 5, 1}, {"Lapida", 9.5, 11, 3}, {"Lapida", -9.5, 17, 1}, {"Calabaza", 10, 20, 3}},
	},
}

---------- Casas no reclamadas ----------
-- Las parcelas sin jugador tienen una casa "no reclamada" (sin dueño) que se puede visitar para pasar miedo.
-- Cuando entra un jugador nuevo, se queda una de estas parcelas.
-- Usan los mismos diseños 3D que las casas de jugador (template = Config.Houses), con sus mismas salas.
-- Sustos: {tipo, x, z, giro}. r = 0 mira a la entrada, 1 mira a la derecha (+x), 3 a la izquierda.
Config.UNCLAIMED_NAME = "Unclaimed House"
Config.NPCHouses = {
	{name = Config.UNCLAIMED_NAME, template = "CasaPrincipal", rooms = 1, scares = {
		{"Armario", -8, 10, 1}, {"Luz", 0, 13, 0}, {"Fantasma", 0, 19, 0},
	}},
	{name = Config.UNCLAIMED_NAME, template = "CasaLarga", rooms = 2, scares = {
		{"Armario", -8, 10, 1}, {"Luz", 0, 13, 0}, {"Gramofono", 8, 20, 3}, {"Fantasma", 0, 34, 0}, {"Arana", -6, 28, 0},
	}},
	{name = Config.UNCLAIMED_NAME, template = "CasaMansion", rooms = 3, scares = {
		{"Luz", 0, 9, 0}, {"Armario", 8, 15, 3}, {"Muneca", -8, 30, 1}, {"Fantasma", 0, 38, 0},
		{"Trampilla", 0, 52, 0}, {"Gramofono", -8, 60, 1}, {"Sombra", 6, 62, 0}, {"Ataud", 9.5, 20, 3}, {"Arana", -6, 44, 0},
	}},
}

---------- Parcelas ----------
-- 8 parcelas (una por jugador, servidores de 8), 4 a cada lado de la calle y centradas en ella. Se reparten de la plaza
-- (oeste) hacia el fondo, alternando acera: los vecinos quedan enfrente. Cada CFrame es el centro de la puerta, a la
-- altura del suelo, mirando hacia dentro. (El mapa de workspace.Mapa está hecho para estas 8 parcelas.)
Config.MAX_PLAYERS = 8
Config.PLOT_GAP = 52
Config.Plots = {}
for i = 0, Config.MAX_PLAYERS - 1 do
	local side = i % 2 == 0 and 1 or -1
	local k = i // 2
	local x = (k - (Config.MAX_PLAYERS / 2 - 1) / 2) * Config.PLOT_GAP
	Config.Plots[i + 1] = CFrame.new(x, Config.FLOOR_Y, side * 34) * CFrame.Angles(0, side == 1 and math.pi or 0, 0)
end

---------- Tower Defense: mini lobbies ----------
-- 6 pabellones en la explanada del este (workspace.Mapa.TowerDefense.Lobbies). Cada uno enseña un mapa en una
-- dificultad que va cambiando (TowerDefenseLobbies). Se entra cruzando el velo de uno; el primero que entra es el
-- anfitrión. Al acabar la cuenta atrás (o si el anfitrión pulsa "Start") el grupo entero viaja junto a un servidor
-- reservado solo para ellos, donde se carga ese mapa (TDMaps).
Config.LOBBY_MAX = 8 -- jugadores por lobby
Config.LOBBY_WAIT = 30 -- segundos de cuenta atrás desde que entra el primero
Config.LOBBY_FULL_WAIT = 6 -- con el lobby lleno, la cuenta atrás baja a esto
Config.TD_MAP_NAME = "Pumpkin Hollow"

---------- Funciones ----------
-- Punto del jardín delante de la puerta, a ras de suelo y mirando a la casa (aquí apareces)
function Config.frontOf(origin)
	return origin * CFrame.new(0, -Config.FLOOR_Y + 0.1, Config.SPAWN_DIST)
end

-- Posición dentro de una casa: x lateral, y altura sobre el suelo, z profundidad desde la puerta (>0 = dentro)
function Config.toHouse(origin, pos)
	local p = origin:PointToObjectSpace(pos)
	return p.X, p.Y, -p.Z
end

-- Dónde queda un susto. x = lateral, z = profundidad desde la puerta, r = giros de 90°.
function Config.scareCFrame(origin, x, z, r)
	return origin * CFrame.new(x, 0, -z) * CFrame.Angles(0, math.pi + r * math.pi / 2, 0)
end

-- ¿Está pos al alcance de un susto colocado en cf? Círculo, o sector delante (-Z del pivote) si tiene facing.
function Config.inReach(def, cf, pos)
	local rel = cf:PointToObjectSpace(pos)
	local dist = Vector2.new(rel.X, rel.Z).Magnitude
	if dist >= def.radius then
		return false
	end
	return not def.facing or -rel.Z >= dist * math.cos(math.rad(Config.REACH_ANGLE / 2))
end

function Config.footprint(t, r)
	local s = Config.Scares[t].size
	return r % 2 == 1 and Vector2.new(s.Y, s.X) or s
end

---------- Ruta por la casa ----------
-- Rectángulos {x0, x1, z0, z1} (en la casa) de lo que no se puede atravesar: sustos sólidos y muebles (sus Hitbox).
-- extra = {t, x, z, r}: un susto que aún no está (el que se va a colocar). skipId: un susto que no cuenta.
local function blockers(house, rooms, extra, skipId)
	local origin = house:GetAttribute("Origin")
	local list = {}
	local function add(t, x, z, r)
		local def = Config.Scares[t]
		if def and def.solid then
			local fp = Config.footprint(t, r)
			table.insert(list, {x - fp.X / 2, x + fp.X / 2, z - fp.Y / 2, z + fp.Y / 2})
		end
	end
	local scares = house:FindFirstChild("Scares")
	for _, m in scares and scares:GetChildren() or {} do
		if m:IsA("Model") and (not skipId or m:GetAttribute("Id") ~= skipId) then
			local x, _, z = Config.toHouse(origin, m:GetPivot().Position)
			add(m.Name, x, z, m:GetAttribute("R") or 0)
		end
	end
	local props = house:FindFirstChild("Props")
	for _, p in props and props:GetDescendants() or {} do
		if p:IsA("BasePart") and p.Name == "Hitbox" then
			local x, _, z = Config.toHouse(origin, p.Position)
			if math.abs(x) < Config.roomW(house) / 2 and z > 0 and z < rooms * Config.ROOM_D then
				local rel = origin:ToObjectSpace(p.CFrame)
				local sx = math.abs(rel.XVector.X) * p.Size.X + math.abs(rel.YVector.X) * p.Size.Y + math.abs(rel.ZVector.X) * p.Size.Z
				local sz = math.abs(rel.XVector.Z) * p.Size.X + math.abs(rel.YVector.Z) * p.Size.Y + math.abs(rel.ZVector.Z) * p.Size.Z
				table.insert(list, {x - sx / 2, x + sx / 2, z - sz / 2, z + sz / 2})
			end
		end
	end
	if extra then
		add(extra[1], extra[2], extra[3], extra[4])
	end
	return list
end

-- Ruta de la puerta al fondo de la casa (lista de puntos {x, z}, con la entrada primero) que esquiva lo sólido dejando
-- CLEARANCE a cada lado; nil si no hay. Búsqueda en anchura por una rejilla y luego se quitan los puntos que sobran.
function Config.route(house, rooms, extra, skipId)
	local G, CL = Config.ROUTE_CELL, Config.CLEARANCE
	local rects = blockers(house, rooms, extra, skipId)
	local xmin, xmax = -Config.roomW(house) / 2 + CL, Config.roomW(house) / 2 - CL
	local zmin, zmax = 0.8, rooms * Config.ROOM_D - 1
	local nx, nz = math.floor((xmax - xmin) / G) + 1, math.floor((zmax - zmin) / G) + 1
	local function free(x, z)
		for _, r in rects do
			if x > r[1] - CL and x < r[2] + CL and z > r[3] - CL and z < r[4] + CL then
				return false
			end
		end
		return true
	end
	local grid = table.create(nx * nz, false)
	for j = 0, nz - 1 do
		local z = zmin + j * G
		for i = 0, nx - 1 do
			grid[j * nx + i + 1] = free(xmin + i * G, z)
		end
	end
	-- empieza en la casilla libre más cercana a la puerta (x = 0, primera fila)
	local start
	local ci = math.floor((0 - xmin) / G + 0.5)
	for d = 0, nx do
		for _, i in {ci - d, ci + d} do
			if i >= 0 and i < nx and grid[i + 1] then
				start = i + 1
				break
			end
		end
		if start then
			break
		end
	end
	if not start then
		return nil
	end
	local goalRow = math.floor((rooms * Config.ROOM_D - 4.5 - zmin) / G)
	local prev = {[start] = 0}
	local queue, head = {start}, 1
	local goal
	while head <= #queue do
		local k = queue[head]
		head += 1
		local j, i = (k - 1) // nx, (k - 1) % nx
		if j >= goalRow then
			goal = k
			break
		end
		-- primero hacia el fondo y hacia el centro: la ruta prefiere ir recta
		for _, d in {{0, 1}, {i > ci and -1 or 1, 0}, {i > ci and 1 or -1, 0}, {0, -1}} do
			local ni, nj = i + d[1], j + d[2]
			if ni >= 0 and ni < nx and nj >= 0 and nj < nz then
				local n = nj * nx + ni + 1
				if grid[n] and prev[n] == nil then
					prev[n] = k
					table.insert(queue, n)
				end
			end
		end
	end
	if not goal then
		return nil
	end
	local cells = {}
	local k = goal
	while k ~= 0 do
		table.insert(cells, 1, k)
		k = prev[k]
	end
	local function pos(k)
		return Vector2.new(xmin + ((k - 1) % nx) * G, zmin + ((k - 1) // nx) * G)
	end
	-- ¿se puede ir en línea recta de a a b sin tocar nada?
	local function clear(a, b)
		local n = math.ceil((b - a).Magnitude / (G * 0.5))
		for s = 1, n do
			local p = a:Lerp(b, s / n)
			if not free(p.X, p.Y) then
				return false
			end
		end
		return true
	end
	local pts = {pos(cells[1])}
	local last = 1
	while last < #cells do
		local best = last + 1
		for n = #cells, last + 2, -1 do
			if clear(pos(cells[last]), pos(cells[n])) then
				best = n
				break
			end
		end
		table.insert(pts, pos(cells[best]))
		last = best
	end
	-- y sigue recto hasta el fondo si se puede
	local tail = Vector2.new(pts[#pts].X, rooms * Config.ROOM_D - 3.5)
	if clear(pts[#pts], tail) then
		table.insert(pts, tail)
	end
	return pts
end

-- ¿Se puede colocar aquí? Lo usan el cliente (vista previa verde/roja) y el servidor (validación).
function Config.canPlace(house, rooms, t, x, z, r)
	local def = Config.Scares[t]
	if not def or x ~= x or z ~= z then
		return false
	end
	local fp = Config.footprint(t, r)
	local hw, hd = fp.X / 2, fp.Y / 2
	if math.abs(x) + hw > Config.roomW(house) / 2 - 0.5 then
		return false, "Too close to the wall"
	end
	if z - hd < Config.ENTRY_SAFE then
		return false, "Keep the entrance clear"
	end
	if z + hd > rooms * Config.ROOM_D - Config.BACK_SAFE then
		return false, "Too close to the back wall"
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {house:FindFirstChild("Scares"), house:FindFirstChild("Props")}
	local y = def.ceiling and Config.roomH(house) - 2 or 1.5
	local cf = house:GetAttribute("Origin") * CFrame.new(x, y, -z)
	for _, p in workspace:GetPartBoundsInBox(cf, Vector3.new(fp.X - 0.2, 2.5, fp.Y - 0.2), params) do
		if p.Name == "Hitbox" then
			return false, "Something is already there"
		end
	end
	-- puede ir en mitad del camino, pero siempre tiene que quedar paso de la puerta al fondo
	if def.solid and not Config.route(house, rooms, {t, x, z, r}) then
		return false, "It would block the way through the house"
	end
	return true
end

---------- Aspiradora de almas (Shop: pase "Vacuum" de Config.Passes) ----------
-- Recoge sola las monedas de tu casa y, al volver, te enseña lo que ha juntado mientras no estabas ("Welcome back").
-- Solo con Robux (quien la compró antes con gemas la conserva: dato vacuum). Atributo Vacuum del jugador. Lo que junta
-- mientras no estás cuenta para el rendimiento decreciente (coinPileMult), con un tope VACUUM_CAP veces mayor.
Config.VACUUM_CAP = 3
Config.VACUUM_AWAY = 40 -- a más de estos studs de tu casa "no estás"
Config.WELCOME_MIN = 30 -- segundos fuera como mínimo para la pantalla de bienvenida

---------- Robux (Shop: Passes y Currency; sustos en su pantalla) ----------
-- Los ids se crean en Creator Hub > tu experiencia > Monetization: los pases en "Passes" y lo demás en "Developer
-- Products" (el precio de verdad es el que pongas allí; robux es solo lo que enseña la tienda: que coincidan).
-- Con id 0: en Studio la compra se simula (se da al momento, para probar) y en el juego publicado dice "coming soon".
-- Pases (atributo Pass_<id> del jugador, se comprueba al entrar en cualquier servidor):
Config.Passes = {
	{id = "Vacuum", name = "Soul Vacuum", robux = 299, pass = 2056930928, art = "vacuumart", color = Color3.fromRGB(110, 255, 160),
		desc = "Collects every coin in your house for you, even while you explore."},
	{id = "Coins2x", name = "2x Coins", robux = 399, pass = 2057272945, art = "coins2x", color = Color3.fromRGB(255, 196, 40),
		desc = "Every visitor you scare drops DOUBLE coins. Forever."},
	{id = "Gems2x", name = "2x Gems", robux = 249, pass = 2058190918, art = "gems2x", color = Color3.fromRGB(80, 220, 255),
		desc = "Earn DOUBLE gems in every Tower Defense wave and win."},
	{id = "Lucky", name = "Lucky Visitors", robux = 199, pass = 2057854919, art = "lucky", color = Color3.fromRGB(110, 235, 90),
		desc = "x2 luck: rare and mythic visitors come twice as often."},
}
Config.PassById = {}
for _, p in Config.Passes do
	Config.PassById[p.id] = p
end
Config.LUCKY_BOOST = 2 -- (pase Lucky: multiplica la suerte de los visitantes como el LuckBoost)

-- Packs de monedas y gemas (productos; se pueden regalar a otro jugador del servidor). big: la carta alta de la columna;
-- bonus: la cinta "+N% MORE"
Config.CoinPacks = {
	{id = "coins1", name = "Pile of Coins", amount = 2500, robux = 29, product = 3722999019, art = "coins1"},
	{id = "coins2", name = "Stack of Coins", amount = 7500, robux = 79, product = 3722999158, art = "coins2"},
	{id = "coins3", name = "Bag of Coins", amount = 20000, robux = 199, product = 3722999379, art = "coins3"},
	{id = "coins4", name = "Mega Coins", amount = 60000, robux = 499, product = 3723004702, art = "coins4", bonus = 35},
	{id = "coins5", name = "Deluxe Coins", amount = 150000, robux = 999, product = 3723004908, art = "coins5", bonus = 70, big = true},
}
-- (~1 gema por Robux: comprar un susto con gemas compradas siempre sale al menos un 37% más caro que comprarlo directo
-- con Robux en Config.ScareTiers; si subes estas cantidades, compruébalo)
Config.GemPacks = {
	{id = "gems5", name = "Deluxe Gems", amount = 1500, robux = 1499, product = 3723006211, art = "gems5", bonus = 40, big = true},
	{id = "gems1", name = "Handful of Gems", amount = 35, robux = 49, product = 3723005430, art = "gems1"},
	{id = "gems2", name = "Gem Cluster", amount = 120, robux = 149, product = 3723005692, art = "gems2"},
	{id = "gems3", name = "Bag of Gems", amount = 300, robux = 349, product = 3723005850, art = "gems3"},
	{id = "gems4", name = "Mega Gems", amount = 650, robux = 699, product = 3723006013, art = "gems4", bonus = 30},
}
Config.PackById = {}
for _, list in {Config.CoinPacks, Config.GemPacks} do
	for _, p in list do
		p.gems = list == Config.GemPacks
		Config.PackById[p.id] = p
	end
end

-- Sustos con Robux: los que no se venden por monedas, por escalones (un producto por escalón: el servidor apunta
-- qué susto pediste antes de abrir la compra). Escalón según lo que paga el susto (pay)
Config.ScareTiers = {
	{upTo = 30, robux = 49, product = 3723006346},
	{upTo = 60, robux = 99, product = 3723006609},
	{upTo = 100, robux = 199, product = 3723007241},
	{upTo = 300, robux = 399, product = 3723007426},
	{upTo = 600, robux = 799, product = 3723007687},
	{upTo = math.huge, robux = 1499, product = 3723007809},
}
-- Escalón de un susto (nil: se compra con monedas, no con Robux)
function Config.scareTier(t)
	local def = Config.Scares[t]
	if not def or def.skin or Config.inShop(t) then
		return nil
	end
	for i, tier in Config.ScareTiers do
		if def.pay <= tier.upTo then
			return i, tier
		end
	end
end
-- Los que salen destacados en la Shop (Featured: "Premium Scares")
Config.PremiumScares = {"Dragon", "Demonio", "Jinete", "ReyCalabaza", "Parca"}

---------- Noche de Sangre (evento para todos los servidores a la vez) ----------
-- Cada hora en punto (hora del servidor, UTC), BLOOD_LENGTH segundos de luna roja: llegan BLOOD_RATE veces más
-- visitantes (hasta BLOOD_MAX_BOTS a la vez por casa), con más suerte de rareza y de materia, y sueltan más monedas.
Config.BLOOD_EVERY = 3600
Config.BLOOD_LENGTH = 180
Config.BLOOD_OFFSET = 0
Config.BLOOD_RATE = 3
Config.BLOOD_MAX_BOTS = 3
Config.BLOOD_LUCK = 6 -- multiplica la suerte (los míticos x6; los menos raros, menos: rarityChances)
Config.BLOOD_VARIANT = 3 -- y la probabilidad de llegar hecho de otra materia
Config.BLOOD_COINS = 1.5
-- ¿Hay Noche de Sangre en now (GetServerTimeNow)? Devuelve si está activa y cuándo acaba (o cuándo empieza la siguiente)
function Config.bloodNight(now)
	local t = (now - Config.BLOOD_OFFSET) % Config.BLOOD_EVERY
	if t < Config.BLOOD_LENGTH then
		return true, now - t + Config.BLOOD_LENGTH
	end
	return false, now - t + Config.BLOOD_EVERY
end

---------- Ofertas del día (Shop) ----------
-- Cada día (UTC) la tienda vende por monedas DAILY_SLOTS sustos que normalmente solo salen de las ruletas, una vez
-- cada uno (acción DailyBuy). Las mismas en el servidor y en todos los clientes (semilla: el día).
Config.DAILY_SLOTS = 5
Config.DAILY_MARKUP = 2
function Config.dailyDay(now)
	return math.floor(now / 86400)
end
function Config.dailyDeals(day)
	local rng = Random.new(day * 31 + 7)
	local pool, legend = {}, {}
	for _, t in Config.ScareOrder do
		if not Config.inShop(t) then
			table.insert(Config.Scares[t].cat == "Legendario" and legend or pool, t)
		end
	end
	local list = {}
	local function take(from)
		local t = table.remove(from, rng:NextInteger(1, #from))
		local price = math.floor(Config.Scares[t].price * Config.DAILY_MARKUP / 50 + 0.5) * 50
		table.insert(list, {scare = t, price = price})
	end
	-- un legendario (de vez en cuando) y el resto criaturas y trampas, de más caro a más barato
	if #legend > 0 and rng:NextNumber() < 0.35 then
		take(legend)
	end
	while #list < Config.DAILY_SLOTS and #pool > 0 do
		take(pool)
	end
	table.sort(list, function(a, b)
		return a.price > b.price
	end)
	return list
end

---------- Tags (Shop) ----------
-- Título que sale encima de tu nombre ("[ Phantom ]") y pinta tu nombre con su degradado. Se compran con monedas en la
-- Shop y se equipa uno (acciones BuyTag / EquipTag de Juego). Atributos del jugador: Tags (ids que tiene, con comas) y
-- Tag (el equipado). Los míticos se animan (el degradado se desliza; lo hace cada cliente: TagFX).
Config.TagRarities = {
	{id = "Uncommon", color = Color3.fromRGB(110, 235, 120), top = Color3.fromRGB(64, 196, 88), bottom = Color3.fromRGB(18, 104, 46), price = 1000},
	{id = "Rare", color = Color3.fromRGB(110, 200, 255), top = Color3.fromRGB(40, 150, 255), bottom = Color3.fromRGB(14, 58, 168), price = 2500},
	{id = "Epic", color = Color3.fromRGB(205, 140, 255), top = Color3.fromRGB(160, 84, 255), bottom = Color3.fromRGB(66, 22, 150), price = 6000},
	{id = "Legendary", color = Color3.fromRGB(255, 205, 70), top = Color3.fromRGB(255, 168, 36), bottom = Color3.fromRGB(160, 62, 10), price = 15000},
	{id = "Mythic", color = Color3.fromRGB(255, 120, 200), top = Color3.fromRGB(255, 76, 160), bottom = Color3.fromRGB(104, 18, 120), price = 40000},
}
Config.TagRarityIndex = {}
for i, r in Config.TagRarities do
	Config.TagRarityIndex[r.id] = i
end
local rgb = Color3.fromRGB
Config.Tags = {
	{id = "TrickOrTreat", name = "Trick or Treat", rarity = "Uncommon", colors = {rgb(255, 170, 50), rgb(255, 230, 90)}},
	{id = "Ghostly", name = "Ghostly", rarity = "Uncommon", colors = {rgb(255, 255, 255), rgb(170, 220, 255)}},
	{id = "Graveyard", name = "Graveyard", rarity = "Uncommon", colors = {rgb(200, 230, 200), rgb(120, 160, 135)}},
	{id = "Pumpkin", name = "Pumpkin", rarity = "Rare", colors = {rgb(255, 196, 60), rgb(255, 110, 20)}},
	{id = "Witchy", name = "Witchy", rarity = "Rare", colors = {rgb(190, 110, 255), rgb(100, 240, 130)}},
	{id = "Bloodmoon", name = "Bloodmoon", rarity = "Rare", colors = {rgb(255, 110, 110), rgb(190, 16, 40)}},
	{id = "CandyCorn", name = "Candy Corn", rarity = "Rare", colors = {rgb(255, 245, 140), rgb(255, 160, 30), rgb(255, 255, 255)}},
	{id = "Ectoplasm", name = "Ectoplasm", rarity = "Epic", colors = {rgb(170, 255, 90), rgb(40, 235, 200)}},
	{id = "Nightmare", name = "Nightmare", rarity = "Epic", colors = {rgb(180, 90, 255), rgb(255, 60, 130)}},
	{id = "Frostbite", name = "Frostbite", rarity = "Epic", colors = {rgb(235, 252, 255), rgb(90, 190, 255)}},
	{id = "Hellfire", name = "Hellfire", rarity = "Legendary", colors = {rgb(255, 240, 100), rgb(255, 130, 20), rgb(235, 36, 36)}},
	{id = "Phantom", name = "Phantom", rarity = "Legendary", colors = {rgb(70, 240, 255), rgb(160, 100, 255), rgb(80, 100, 255)}},
	{id = "PumpkinKing", name = "Pumpkin King", rarity = "Mythic", colors = {rgb(255, 225, 90), rgb(255, 120, 20), rgb(180, 70, 255), rgb(255, 225, 90)}},
	{id = "SoulReaper", name = "Soul Reaper", rarity = "Mythic", colors = {rgb(255, 255, 255), rgb(90, 235, 255), rgb(195, 90, 255), rgb(255, 90, 205), rgb(255, 255, 255)}},
}
Config.TagById = {}
for _, tag in Config.Tags do
	tag.price = Config.TagRarities[Config.TagRarityIndex[tag.rarity]].price
	Config.TagById[tag.id] = tag
end

-- Degradado del tag (para un UIGradient)
function Config.tagGradient(tag)
	local keys = {}
	for i, c in tag.colors do
		keys[i] = ColorSequenceKeypoint.new((i - 1) / (#tag.colors - 1), c)
	end
	return ColorSequence.new(keys)
end

function Config.tagRarity(tag)
	return Config.TagRarities[Config.TagRarityIndex[tag.rarity]]
end

return Config
