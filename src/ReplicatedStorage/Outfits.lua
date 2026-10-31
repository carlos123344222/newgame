-- Ropa y complementos de los bots (cazafantasmas del Tower Defense y visitantes de las casas). Cada complemento es una
-- función GEAR[nombre](bot, def) que suelda piezas (sin colisión ni masa) a una parte del cuerpo del bot R15.
-- Ejes de las partes del bot: -Z = delante. Lo que se lleva en la mano derecha apunta a -Z (con la pose "sneak" de
-- NPCAnim el brazo va hacia delante y la muñeca enderezada, como la linterna). Los escudos van en la mano izquierda.
-- Las mallas (cascos, sombreros...) salen de ReplicatedStorage.Assets.Gear: G_<nombre>, de frente a -Z.
-- Outfits.dress(bot, def): colores (shirt, pants, skin) y def.gear. Lo usan TDMatch y Juego.
local RS = game:GetService("ReplicatedStorage")
local Kit = RS:WaitForChild("Assets"):WaitForChild("Gear")

local Outfits = {}

local V, CF, ANG = Vector3.new, CFrame.new, CFrame.Angles
local PI = math.pi
local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball
local M = Enum.Material
local NEON, METAL, FABRIC, PLASTIC, WOOD = M.Neon, M.Metal, M.Fabric, M.SmoothPlastic, M.Wood
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local STEEL, DARKSTEEL, GOLD, IRON = rgb(178, 184, 196), rgb(90, 94, 106), rgb(240, 196, 70), rgb(58, 60, 68)
local WOODC, DARKWOOD, LEATHER, BLACK = rgb(120, 82, 48), rgb(72, 48, 30), rgb(104, 66, 40), rgb(26, 24, 30)
local WHITE, RED = rgb(240, 238, 232), rgb(190, 30, 40)
Outfits.SKINS = {rgb(255, 220, 180), rgb(200, 150, 110), rgb(120, 80, 55), rgb(240, 195, 150), rgb(250, 205, 165), rgb(170, 120, 85)}
-- ropa al azar (los que no dicen la suya): colores bonitos, no cualquiera
Outfits.SHIRTS = {rgb(220, 70, 60), rgb(240, 140, 40), rgb(245, 205, 70), rgb(90, 180, 90), rgb(50, 150, 140), rgb(70, 140, 220), rgb(60, 80, 170), rgb(140, 80, 190), rgb(220, 100, 160), rgb(235, 235, 235), rgb(60, 60, 70), rgb(150, 110, 80), rgb(120, 150, 70), rgb(180, 40, 60)}
Outfits.PANTS = {rgb(50, 70, 120), rgb(40, 52, 90), rgb(36, 36, 44), rgb(70, 60, 50), rgb(110, 90, 70), rgb(60, 70, 50), rgb(80, 80, 92)}

---------- Piezas ----------
local function piece(bot, attach, props, offset, class)
	local base = bot:FindFirstChild(attach)
	if not base then
		return
	end
	local p = Instance.new(class or "Part")
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = false, false, false, true, false
	p.CollisionGroup = "Bots"
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = PLASTIC
	for k, v in props do
		p[k] = v
	end
	p.CFrame = base.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = base, p
	w.Parent = p
	p.Parent = bot
	return p
end
Outfits.piece = piece

-- Malla del kit (G_<name>) con un ancho dado, en offset respecto a la parte attach
local function mesh(bot, attach, name, width, offset)
	local src = Kit:FindFirstChild("G_" .. name) or Kit:FindFirstChild(name)
	src = src and (src:IsA("MeshPart") and src or src:FindFirstChildWhichIsA("MeshPart", true))
	local base = bot:FindFirstChild(attach)
	if not (src and base) then
		return nil
	end
	local p = src:Clone()
	for _, c in p:GetChildren() do
		if not c:IsA("SurfaceAppearance") then
			c:Destroy()
		end
	end
	p.Name = "Gear_" .. name
	p.Size = src.Size * (width / src.Size.X)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = false, false, false, false, true, false
	p.CollisionGroup = "Bots"
	p.CFrame = base.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = base, p
	w.Parent = p
	p.Parent = bot
	return p
end
Outfits.mesh = mesh

-- Sombrero de malla apoyado en la cabeza: su base a 'sink' studs por debajo de la coronilla
local function hat(bot, name, width, sink, z, tilt)
	local src = Kit:FindFirstChild("G_" .. name)
	src = src and src:FindFirstChildWhichIsA("MeshPart", true)
	if not src then
		return nil
	end
	local h = src.Size.Y * (width / src.Size.X)
	return mesh(bot, "Head", name, width, CF(0, 0.59 + h / 2 - (sink or 0.3), z or 0) * ANG(math.rad(tilt or 0), 0, 0))
end

-- (atenuadas: sin sombras, a toda potencia quemaban en blanco a los visitantes y lo que tienen cerca)
local function light(p, range, bright, color)
	if p then
		local l = Instance.new("PointLight")
		l.Range, l.Brightness, l.Color, l.Shadows = range * 0.85, bright * 0.5, color, false
		l.Parent = p
		return l
	end
end

local function fire(p, size, color)
	if p then
		local f = Instance.new("Fire")
		f.Size, f.Heat = size, 8
		f.Color = color or rgb(255, 140, 40)
		f.SecondaryColor = rgb(255, 230, 120)
		f.Parent = p
		return f
	end
end

local function sparkle(p, color, rate)
	if p then
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(color)
		e.LightEmission, e.Rate, e.Lifetime, e.Speed = 1, rate or 5, NumberRange.new(0.5, 1), NumberRange.new(0.3, 1)
		e.Size = NumberSequence.new(0.25, 0)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Parent = p
		return e
	end
end

-- Arma en la mano derecha: un palo de largo len que sale de la mano hacia delante (-Z), con 'back' studs por detrás
local function shaft(bot, len, back, thick, color, mat, hand)
	return piece(bot, hand or "RightHand", {Name = "Shaft", Shape = CYL, Size = V(len, thick, thick), Color = color, Material = mat or WOOD}, CF(0, -0.3, -(len / 2 - back)) * ANG(0, PI / 2, 0))
end
-- Punto a d studs delante de la mano derecha (para colocar cabezas de armas)
local function tip(d, y)
	return CF(0, -0.3 + (y or 0), -d)
end

-- Hoja de espada: hoja, filo brillante, guarda, empuñadura y pomo. len: largo de la hoja
local function blade(bot, len, width, bladeColor, guardColor, glow, hand)
	hand = hand or "RightHand"
	piece(bot, hand, {Name = "Grip", Shape = CYL, Size = V(0.9, 0.22, 0.22), Color = LEATHER, Material = FABRIC}, CF(0, -0.3, 0.05) * ANG(0, PI / 2, 0))
	piece(bot, hand, {Name = "Pommel", Shape = BALL, Size = V(0.3, 0.3, 0.3), Color = guardColor, Material = METAL}, CF(0, -0.3, 0.55))
	piece(bot, hand, {Name = "Guard", Size = V(1.1, 0.16, 0.22), Color = guardColor, Material = METAL}, CF(0, -0.3, -0.45))
	local b = piece(bot, hand, {Name = "Blade", Size = V(width, 0.08, len), Color = bladeColor, Material = glow and NEON or METAL, Reflectance = glow and 0 or 0.25}, CF(0, -0.3, -0.5 - len / 2))
	piece(bot, hand, {Name = "Point", Size = V(width * 0.7, 0.07, width * 0.7), Color = bladeColor, Material = glow and NEON or METAL}, CF(0, -0.3, -0.5 - len) * ANG(0, PI / 4, 0))
	piece(bot, hand, {Name = "Fuller", Size = V(width * 0.25, 0.1, len * 0.75), Color = bladeColor:Lerp(BLACK, 0.25), Material = METAL}, CF(0, -0.3, -0.5 - len * 0.42))
	-- filos que brillan a los lados, gema en la guarda y vueltas de cuero en la empuñadura
	for s = -1, 1, 2 do
		piece(bot, hand, {Name = "Edge", Size = V(0.04, 0.09, len * 0.96), Color = bladeColor:Lerp(WHITE, 0.55), Material = glow and NEON or METAL, Reflectance = 0.4}, CF(s * (width / 2 - 0.02), -0.3, -0.5 - len / 2))
		piece(bot, hand, {Name = "Quillon", Shape = BALL, Size = V(0.24, 0.24, 0.24), Color = guardColor, Material = METAL}, CF(s * 0.58, -0.3, -0.45))
	end
	piece(bot, hand, {Name = "Gem", Shape = BALL, Size = V(0.2, 0.2, 0.2), Color = glow and bladeColor or RED, Material = NEON}, CF(0, -0.18, -0.45))
	for k = -1, 1 do
		piece(bot, hand, {Name = "Wrap", Shape = CYL, Size = V(0.08, 0.25, 0.25), Color = LEATHER:Lerp(BLACK, 0.35), Material = FABRIC}, CF(0, -0.3, 0.05 + k * 0.28) * ANG(0, PI / 2, 0))
	end
	return b
end

-- Escudo en la mano izquierda: plano de cara a -Z, delante del puño
local function shieldAt(bot, w, h, color, rim, shape)
	local off = CF(0, 0.55, -0.75) * ANG(0, PI / 2, 0)
	local s
	if shape == "round" then
		s = piece(bot, "LeftHand", {Name = "Shield", Shape = CYL, Size = V(0.22, w, w), Color = color, Material = WOOD}, off)
		piece(bot, "LeftHand", {Name = "Rim", Shape = CYL, Size = V(0.18, w + 0.18, w + 0.18), Color = rim, Material = METAL}, off * CF(0.03, 0, 0))
		piece(bot, "LeftHand", {Name = "Boss", Shape = BALL, Size = V(0.55, 0.55, 0.55), Color = rim, Material = METAL}, off * CF(-0.14, 0, 0))
	else
		s = piece(bot, "LeftHand", {Name = "Shield", Size = V(0.22, h * 0.75, w), Color = color, Material = PLASTIC}, off * CF(0, h * 0.125, 0))
		-- punta de escudo de cometa (dos cuñas)
		for sgn = -1, 1, 2 do
			piece(bot, "LeftHand", {Name = "Point", Class = nil, Size = V(0.22, h * 0.28, w / 2), Color = color, Material = PLASTIC}, off * CF(0, -h * 0.36, sgn * w / 4) * ANG(sgn * 0.5, 0, 0))
		end
		piece(bot, "LeftHand", {Name = "Rim", Size = V(0.18, h * 0.78, w + 0.16), Color = rim, Material = METAL}, off * CF(0.03, h * 0.125, 0))
	end
	return s, off
end

-- Tela que cuelga de los hombros por la espalda
local function capeOf(bot, color, len, width, trim)
	len, width = len or 3.2, width or 2.1
	local back = CF(0, 0.75 - len / 2, 0.62) * ANG(-0.14, 0, 0)
	local c = piece(bot, "UpperTorso", {Name = "Cape", Size = V(width * 0.5, len, 0.12), Color = color, Material = FABRIC}, back)
	-- pliegues: dos paños a los lados que envuelven un poco los hombros, más oscuros, y el forro asomando por el borde
	for s = -1, 1, 2 do
		local side = back * CF(s * width * 0.36, 0.02, 0.04) * ANG(0, s * 0.3, 0)
		piece(bot, "UpperTorso", {Name = "Cape", Size = V(width * 0.32, len * 0.98, 0.12), Color = color:Lerp(BLACK, 0.14), Material = FABRIC}, side)
		piece(bot, "UpperTorso", {Name = "CapeLining", Size = V(0.08, len * 0.96, 0.1), Color = (trim or color:Lerp(WHITE, 0.25)), Material = FABRIC}, side * CF(s * width * 0.16, 0, -0.03))
		-- broches en los hombros
		piece(bot, "UpperTorso", {Name = "Clasp", Shape = BALL, Size = V(0.26, 0.26, 0.26), Color = GOLD, Material = METAL, Reflectance = 0.2}, CF(s * 0.62, 0.78, -0.5))
	end
	piece(bot, "UpperTorso", {Name = "CapeTop", Size = V(width + 0.1, 0.35, 1.25), Color = color:Lerp(BLACK, 0.15), Material = FABRIC}, CF(0, 0.82, 0.05))
	piece(bot, "UpperTorso", {Name = "Chain", Size = V(1.1, 0.06, 0.06), Color = GOLD, Material = METAL}, CF(0, 0.72, -0.52))
	if trim then
		piece(bot, "UpperTorso", {Name = "Trim", Size = V(width + 0.06, 0.28, 0.16), Color = trim, Material = FABRIC}, CF(0, 0.75 - len + 0.1, 0.62 + len * 0.07) * ANG(-0.14, 0, 0))
	end
	return c
end

-- Faldas de abrigo / túnica sobre las piernas
local function skirt(bot, color, len, open)
	if open then
		for s = -1, 1, 2 do
			piece(bot, "LowerTorso", {Name = "Coat", Size = V(0.95, len, 1.2), Color = color, Material = FABRIC}, CF(s * 0.52, -len / 2 + 0.1, 0.05))
		end
	else
		piece(bot, "LowerTorso", {Name = "Robe", Size = V(2.15, len, 1.35), Color = color, Material = FABRIC}, CF(0, -len / 2 + 0.1, 0))
		-- dobladillo, cordón a la cintura con sus borlas y una raja delante
		piece(bot, "LowerTorso", {Name = "Hem", Size = V(2.19, 0.2, 1.39), Color = color:Lerp(BLACK, 0.3), Material = FABRIC}, CF(0, -len + 0.2, 0))
		piece(bot, "LowerTorso", {Name = "Cord", Size = V(2.2, 0.14, 1.4), Color = color:Lerp(GOLD, 0.6), Material = FABRIC}, CF(0, 0.02, 0))
		for s = -1, 1, 2 do
			piece(bot, "LowerTorso", {Name = "Tassel", Size = V(0.1, 0.55, 0.1), Color = color:Lerp(GOLD, 0.6), Material = FABRIC}, CF(s * 0.18, -0.3, -0.72))
		end
		piece(bot, "LowerTorso", {Name = "Fold", Size = V(0.06, len * 0.8, 0.04), Color = color:Lerp(BLACK, 0.35), Material = FABRIC}, CF(0, -len * 0.5, -0.69))
	end
end

---------- Complementos ----------
local GEAR = {}
Outfits.GEAR = GEAR

---------- Complementos modelados en Blender (ReplicatedStorage.BlenderGear) ----------
-- Cada línea: nombre;parte;forma (x caja, o bola, c cilindro);posición [y rotación 3x3];tamaño;color;material;transparencia
local BlenderGear = RS:WaitForChild("BlenderGear")
local blenderCache = {}
local function blenderParts(name)
	if blenderCache[name] then
		return blenderCache[name]
	end
	local list = {}
	local function nums(s)
		local t = {}
		for v in s:gmatch("[^,]+") do
			table.insert(t, tonumber(v))
		end
		return t
	end
	for line in (require(BlenderGear)[name] or ""):gmatch("[^\n]+") do
		local n, attach, shape, cf, size, col, mat, tr = line:match("^([^;]+);([^;]+);(%a);([^;]+);([^;]+);([^;]+);([^;]+);([^;]+)$")
		if n then
			local c, s, rgbv = nums(cf), nums(size), nums(col)
			local off = #c >= 12 and CFrame.new(table.unpack(c, 1, 12)) or CF(c[1], c[2], c[3])
			if shape == "c" then
				off *= ANG(0, 0, PI / 2) -- (Blender: eje Z; Roblox: el cilindro va por X)
			end
			table.insert(list, {
				name = n, attach = attach, offset = off, shape = shape, size = V(s[1], s[2], s[3]),
				color = Color3.fromRGB(rgbv[1], rgbv[2], rgbv[3]), mat = M[mat] or PLASTIC, tr = tonumber(tr) or 0,
			})
		end
	end
	blenderCache[name] = list
	return list
end
local function blender(b, name)
	local made = {}
	for _, d in blenderParts(name) do
		local props = {Name = d.name, Size = d.size, Color = d.color, Material = d.mat, Transparency = d.tr}
		if d.shape == "c" then
			props.Shape = CYL
		elseif d.shape == "o" then
			props.Shape = BALL
		end
		if d.mat == M.Glass then
			props.Reflectance = 0.15
		end
		made[d.name] = piece(b, d.attach, props, d.offset)
	end
	return made
end
Outfits.blender = blender

-- El Exorcista (jefe final de la colina y la granja): sotana, estola, capa, sombrero de ala ancha, gafas, báculo con
-- la gran cruz que brilla y el libro sagrado abierto
GEAR.Exorcist = function(b)
	local p = blender(b, "Exorcist")
	if p.CrossGem then
		light(p.CrossGem, 12, 1, rgb(255, 230, 150)) -- (más fuerte quemaba en blanco el alzacuellos)
		sparkle(p.CrossGem, rgb(255, 240, 170), 6)
	end
	if p.BookGlow then
		light(p.BookGlow, 6, 0.8, rgb(255, 236, 160))
	end
end

-- El Experto Paranormal (jefe cada 5 oleadas): mochila de protones con el ciclotrón encendido, gafas espectrales,
-- gorra con auricular, lanza de protones y detector EMF
GEAR.Paranormal = function(b)
	local p = blender(b, "Paranormal")
	if p.PackCore then
		light(p.PackCore, 10, 1.6, rgb(255, 150, 60))
	end
	if p.WandTip then
		light(p.WandTip, 9, 1.4, rgb(255, 130, 50))
	end
end

-- (los de siempre del Tower Defense)
GEAR.cap = function(b, def)
	local c = def and def.capColor or rgb(30, 30, 40)
	piece(b, "Head", {Size = V(1.3, 0.35, 1.3), Color = c, Material = FABRIC}, CF(0, 0.55, 0))
	piece(b, "Head", {Size = V(1, 0.12, 0.7), Color = c, Material = FABRIC}, CF(0, 0.42, -0.75))
end
GEAR.camera = function(b)
	local c = piece(b, "RightHand", {Size = V(0.6, 0.45, 0.4), Color = rgb(25, 25, 28), Material = METAL}, CF(0, -0.3, -0.35))
	light(c, 7, 1.4, rgb(255, 80, 80))
end
GEAR.jester = function(b)
	for s = -1, 1, 2 do
		piece(b, "Head", {Size = V(0.5, 1.1, 0.5), Color = s < 0 and rgb(150, 40, 200) or rgb(250, 200, 40), Material = FABRIC}, CF(s * 0.45, 0.85, 0) * ANG(0, 0, -s * 0.6))
		piece(b, "Head", {Shape = BALL, Size = V(0.35, 0.35, 0.35), Color = rgb(255, 220, 60), Material = NEON}, CF(s * 0.85, 1.25, 0))
	end
end
GEAR.sunhat = function(b)
	piece(b, "Head", {Shape = CYL, Size = V(0.12, 2.2, 2.2), Color = rgb(225, 200, 140), Material = FABRIC}, CF(0, 0.5, 0) * ANG(0, 0, PI / 2))
	piece(b, "Head", {Shape = CYL, Size = V(0.5, 1.2, 1.2), Color = rgb(225, 200, 140), Material = FABRIC}, CF(0, 0.75, 0) * ANG(0, 0, PI / 2))
end
GEAR.scarf = function(b)
	piece(b, "Head", {Size = V(1.35, 0.7, 1.35), Color = rgb(150, 60, 200), Material = FABRIC}, CF(0, 0.45, 0.05))
	piece(b, "Head", {Shape = BALL, Size = V(0.4, 0.4, 0.4), Color = rgb(110, 255, 140), Material = NEON}, CF(0, 0.5, -0.65))
end
GEAR.robe = function(b, def)
	skirt(b, b:GetAttribute("Shirt") or (def and def.shirt) or rgb(100, 50, 150), 1.9)
end
GEAR.helmet = function(b)
	piece(b, "Head", {Shape = BALL, Size = V(1.45, 1.45, 1.45), Color = rgb(60, 66, 76), Material = METAL}, CF(0, 0.25, 0.05))
	piece(b, "Head", {Size = V(1.2, 0.35, 0.1), Color = rgb(120, 200, 255), Material = M.Glass, Transparency = 0.3}, CF(0, 0.1, -0.68))
end
GEAR.jetpack = function(b)
	for s = -1, 1, 2 do
		piece(b, "UpperTorso", {Shape = CYL, Size = V(1.4, 0.55, 0.55), Color = rgb(200, 205, 215), Material = METAL}, CF(s * 0.35, 0, 0.75) * ANG(0, 0, PI / 2))
		fire(piece(b, "UpperTorso", {Size = V(0.3, 0.3, 0.3), Transparency = 1}, CF(s * 0.35, -0.85, 0.75)), 2)
	end
end
GEAR.collar = function(b)
	piece(b, "UpperTorso", {Size = V(0.5, 0.3, 0.1), Color = WHITE}, CF(0, 0.55, -0.52))
end
GEAR.halo = function(b)
	local h = piece(b, "Head", {Shape = CYL, Size = V(0.12, 1.5, 1.5), Color = rgb(255, 230, 140), Material = NEON, Transparency = 0.2}, CF(0, 1.05, 0) * ANG(0, 0, PI / 2))
	light(h, 8, 1.2, rgb(255, 230, 140))
end
GEAR.riotshield = function(b)
	piece(b, "LeftHand", {Size = V(0.2, 3.4, 2.1), Color = rgb(150, 200, 255), Material = M.Glass, Transparency = 0.35}, CF(0, 0.6, -0.8) * ANG(0, PI / 2, 0))
end
GEAR.beads = function(b)
	for k = 0, 5 do
		local a = k / 6 * PI * 2
		piece(b, "UpperTorso", {Shape = BALL, Size = V(0.25, 0.25, 0.25), Color = rgb(120, 60, 30), Material = WOOD}, CF(math.sin(a) * 0.6, 0.45 - math.abs(math.cos(a)) * 0.35, -0.55))
	end
end
GEAR.mustache = function(b, def)
	local c = def and def.hair or rgb(40, 25, 15)
	for s = -1, 1, 2 do
		piece(b, "Head", {Size = V(0.45, 0.14, 0.1), Color = c, Material = FABRIC}, CF(s * 0.2, -0.18, -0.6) * ANG(0, 0, s * 0.25))
	end
end
GEAR.dumbbell = function(b)
	piece(b, "RightHand", {Shape = CYL, Size = V(1.8, 0.2, 0.2), Color = rgb(60, 60, 66), Material = METAL}, CF(0, -0.2, 0))
	for s = -1, 1, 2 do
		piece(b, "RightHand", {Shape = CYL, Size = V(0.3, 0.8, 0.8), Color = rgb(30, 30, 34), Material = METAL}, CF(s * 0.8, -0.2, 0))
	end
end
GEAR.tophat = function(b, def)
	local c = def and def.hatColor or rgb(20, 18, 22)
	piece(b, "Head", {Shape = CYL, Size = V(0.12, 1.8, 1.8), Color = c, Material = FABRIC}, CF(0, 0.55, 0) * ANG(0, 0, PI / 2))
	piece(b, "Head", {Shape = CYL, Size = V(1.4, 1.2, 1.2), Color = c, Material = FABRIC}, CF(0, 1.25, 0) * ANG(0, 0, PI / 2))
	piece(b, "Head", {Shape = CYL, Size = V(0.25, 1.22, 1.22), Color = def and def.bandColor or rgb(190, 20, 30), Material = FABRIC}, CF(0, 0.75, 0) * ANG(0, 0, PI / 2))
end
GEAR.cane = function(b)
	piece(b, "RightHand", {Size = V(0.18, 3, 0.18), Color = rgb(20, 18, 22)}, CF(0, -1.2, -0.2))
	piece(b, "RightHand", {Shape = BALL, Size = V(0.45, 0.45, 0.45), Color = rgb(240, 196, 60), Material = METAL}, CF(0, 0.3, -0.2))
end

---------- Cabeza ----------
GEAR.knighthelm = function(b)
	mesh(b, "Head", "KnightHelm", 1.62, CF(0, 0.55, 0.02))
end
GEAR.blackhelm = function(b)
	local h = mesh(b, "Head", "blackhelm", 2.05, CF(0, 0.45, 0.02))
	light(h, 6, 1.5, rgb(255, 40, 40))
end
GEAR.crown = function(b)
	local c = hat(b, "crown", 1.3, 0.28)
	sparkle(c, rgb(255, 230, 120), 3)
end
GEAR.furhat = function(b)
	hat(b, "furhat", 1.5, 0.55)
end
GEAR.tricorn = function(b)
	hat(b, "tricorn", 1.95, 0.32)
end
GEAR.pilgrimhat = function(b)
	hat(b, "pilgrimhat", 1.75, 0.32)
end
GEAR.strawhat = function(b)
	hat(b, "strawhat", 2.4, 0.3)
end
GEAR.wizardhat = function(b)
	hat(b, "wizardhat", 2.05, 0.32)
end
GEAR.fedora = function(b)
	if not hat(b, "fedora", 1.75, 0.3) then
		piece(b, "Head", {Shape = CYL, Size = V(0.1, 2, 2), Color = rgb(120, 86, 54), Material = FABRIC}, CF(0, 0.55, 0) * ANG(0, 0, PI / 2))
		piece(b, "Head", {Size = V(1.2, 0.6, 1.2), Color = rgb(120, 86, 54), Material = FABRIC}, CF(0, 0.85, 0))
		piece(b, "Head", {Size = V(1.24, 0.18, 1.24), Color = rgb(50, 34, 24), Material = FABRIC}, CF(0, 0.65, 0))
	end
end
GEAR.wingedhelm = function(b)
	if not mesh(b, "Head", "wingedhelm", 2.3, CF(0, 0.35, 0.05)) then
		piece(b, "Head", {Shape = BALL, Size = V(1.5, 1.5, 1.5), Color = STEEL, Material = METAL, Reflectance = 0.2}, CF(0, 0.25, 0.05))
		for s = -1, 1, 2 do
			piece(b, "Head", {Size = V(0.12, 0.9, 0.6), Color = GOLD, Material = METAL}, CF(s * 0.78, 0.6, 0.15) * ANG(0, 0, -s * 0.5))
		end
	end
end
GEAR.leathercap = function(b)
	piece(b, "Head", {Shape = BALL, Size = V(1.38, 1.3, 1.38), Color = LEATHER, Material = M.Leather or FABRIC}, CF(0, 0.32, 0.05))
	piece(b, "Head", {Size = V(1.36, 0.16, 1.36), Color = DARKWOOD, Material = FABRIC}, CF(0, 0.12, 0.04))
end
GEAR.kettlehat = function(b)
	if not hat(b, "kettlehat", 2.1, 0.35) then
		piece(b, "Head", {Shape = CYL, Size = V(0.1, 2.1, 2.1), Color = STEEL, Material = METAL, Reflectance = 0.15}, CF(0, 0.45, 0) * ANG(0, 0, PI / 2))
		piece(b, "Head", {Shape = BALL, Size = V(1.36, 1.2, 1.36), Color = STEEL, Material = METAL, Reflectance = 0.15}, CF(0, 0.55, 0))
	end
end
GEAR.hood = function(b, def)
	local c = def and def.hood or rgb(70, 50, 40)
	piece(b, "Head", {Shape = BALL, Size = V(1.5, 1.45, 1.5), Color = c, Material = FABRIC}, CF(0, 0.2, 0.14))
	piece(b, "Head", {Size = V(0.7, 0.9, 0.5), Color = c, Material = FABRIC}, CF(0, 0.5, 0.65) * ANG(-0.6, 0, 0))
	piece(b, "UpperTorso", {Size = V(2.05, 0.4, 1.15), Color = c:Lerp(BLACK, 0.12), Material = FABRIC}, CF(0, 0.75, 0.02))
end
GEAR.mask = function(b)
	piece(b, "Head", {Size = V(1.2, 0.5, 0.12), Color = rgb(30, 26, 36), Material = FABRIC}, CF(0, -0.25, -0.6))
end
GEAR.widehat = function(b, def)
	local c = def and def.hatColor or rgb(96, 66, 40)
	piece(b, "Head", {Shape = CYL, Size = V(0.1, 2.5, 2.5), Color = c, Material = FABRIC}, CF(0, 0.52, 0) * ANG(0.08, 0, PI / 2))
	piece(b, "Head", {Shape = CYL, Size = V(0.75, 1.3, 1.3), Color = c, Material = FABRIC}, CF(0, 0.85, 0) * ANG(0, 0, PI / 2))
	piece(b, "Head", {Shape = CYL, Size = V(0.18, 1.32, 1.32), Color = def and def.bandColor or rgb(40, 28, 20), Material = FABRIC}, CF(0, 0.6, 0) * ANG(0, 0, PI / 2))
	piece(b, "Head", {Size = V(0.08, 0.9, 0.22), Color = rgb(200, 60, 50), Material = FABRIC}, CF(0.62, 1, 0.1) * ANG(0, 0, -0.35))
end
GEAR.slayerhat = function(b)
	GEAR.widehat(b, {hatColor = rgb(30, 26, 30), bandColor = rgb(150, 20, 30)})
	piece(b, "Head", {Size = V(0.3, 0.3, 0.08), Color = rgb(200, 205, 215), Material = METAL}, CF(0, 0.62, -0.67))
end
GEAR.inquisitorhat = function(b)
	piece(b, "Head", {Shape = CYL, Size = V(1.5, 1.25, 1.25), Color = rgb(170, 20, 30), Material = FABRIC}, CF(0, 1.38, 0) * ANG(0, 0, PI / 2))
	piece(b, "Head", {Shape = CYL, Size = V(0.2, 1.3, 1.3), Color = GOLD, Material = METAL}, CF(0, 0.72, 0) * ANG(0, 0, PI / 2))
	piece(b, "Head", {Size = V(0.12, 0.7, 0.12), Color = GOLD, Material = METAL}, CF(0, 1.45, -0.64))
	piece(b, "Head", {Size = V(0.45, 0.12, 0.12), Color = GOLD, Material = METAL}, CF(0, 1.6, -0.64))
end
GEAR.beanie = function(b, def)
	local c = def and def.hatColor or rgb(210, 50, 50)
	piece(b, "Head", {Shape = BALL, Size = V(1.35, 1.2, 1.35), Color = c, Material = FABRIC}, CF(0, 0.4, 0.04))
	piece(b, "Head", {Shape = CYL, Size = V(0.3, 1.38, 1.38), Color = c:Lerp(WHITE, 0.25), Material = FABRIC}, CF(0, 0.2, 0.04) * ANG(0, 0, PI / 2))
	piece(b, "Head", {Shape = BALL, Size = V(0.5, 0.5, 0.5), Color = WHITE, Material = FABRIC}, CF(0, 1.05, 0.04))
end
GEAR.goggles = function(b)
	piece(b, "Head", {Size = V(1.25, 0.16, 1.25), Color = BLACK, Material = FABRIC}, CF(0, 0.3, 0.02))
	for s = -1, 1, 2 do
		piece(b, "Head", {Shape = CYL, Size = V(0.18, 0.42, 0.42), Color = rgb(120, 210, 255), Material = M.Glass, Transparency = 0.15, Reflectance = 0.3}, CF(s * 0.25, 0.3, -0.62) * ANG(0, PI / 2, 0))
	end
end
GEAR.minerhelm = function(b)
	piece(b, "Head", {Shape = BALL, Size = V(1.45, 1.3, 1.45), Color = rgb(240, 196, 50), Material = PLASTIC}, CF(0, 0.38, 0.04))
	piece(b, "Head", {Shape = CYL, Size = V(0.1, 1.7, 1.7), Color = rgb(220, 176, 40), Material = PLASTIC}, CF(0, 0.2, 0) * ANG(0, 0, PI / 2))
	local lamp = piece(b, "Head", {Shape = CYL, Size = V(0.25, 0.42, 0.42), Color = rgb(255, 250, 200), Material = NEON}, CF(0, 0.55, -0.7) * ANG(0, PI / 2, 0))
	if lamp then
		local s = Instance.new("SpotLight")
		s.Range, s.Angle, s.Brightness, s.Face = 18, 45, 1.1, Enum.NormalId.Right
		s.Parent = lamp
	end
end
GEAR.pithhelmet = function(b)
	piece(b, "Head", {Shape = BALL, Size = V(1.5, 1.2, 1.6), Color = rgb(226, 206, 160), Material = FABRIC}, CF(0, 0.5, 0.04))
	piece(b, "Head", {Shape = CYL, Size = V(0.1, 2, 2.1), Color = rgb(210, 190, 146), Material = FABRIC}, CF(0, 0.35, 0.04) * ANG(0, 0, PI / 2))
	piece(b, "Head", {Shape = CYL, Size = V(0.15, 1.52, 1.52), Color = rgb(110, 80, 50), Material = FABRIC}, CF(0, 0.45, 0.04) * ANG(0, 0, PI / 2))
end
GEAR.archmagehat = function(b)
	local h = hat(b, "wizardhat", 2.2, 0.32)
	if h then
		h.Name = "Gear_archmagehat"
	end
	local gem = piece(b, "Head", {Shape = BALL, Size = V(0.4, 0.4, 0.4), Color = rgb(120, 220, 255), Material = NEON}, CF(0, 1.2, -0.85))
	light(gem, 8, 1.6, rgb(120, 220, 255))
	sparkle(gem, rgb(160, 230, 255), 6)
end
GEAR.sorceresshat = function(b)
	local h = hat(b, "wizardhat", 1.8, 0.3)
	local gem = piece(b, "Head", {Shape = BALL, Size = V(0.3, 0.3, 0.3), Color = rgb(255, 80, 220), Material = NEON}, CF(0, 0.75, -0.7))
	light(gem, 6, 1.4, rgb(255, 80, 220))
	return h
end
GEAR.mitre = function(b)
	piece(b, "Head", {Size = V(1.1, 1.5, 0.9), Color = WHITE, Material = FABRIC}, CF(0, 1.2, 0))
	for s = -1, 1, 2 do
		piece(b, "Head", {Size = V(0.78, 0.78, 0.9), Color = WHITE, Material = FABRIC}, CF(s * 0.28, 1.9, 0) * ANG(0, 0, PI / 4))
	end
	piece(b, "Head", {Size = V(0.16, 1.5, 0.92), Color = GOLD, Material = METAL}, CF(0, 1.25, 0))
	piece(b, "Head", {Size = V(1.12, 0.18, 0.92), Color = GOLD, Material = METAL}, CF(0, 0.55, 0))
end
GEAR.featherhat = function(b)
	piece(b, "Head", {Shape = BALL, Size = V(1.45, 0.8, 1.45), Color = rgb(40, 130, 70), Material = FABRIC}, CF(0, 0.65, 0.08) * ANG(0.15, 0, 0.15))
	piece(b, "Head", {Size = V(0.12, 1.6, 0.3), Color = rgb(220, 50, 50), Material = FABRIC}, CF(0.55, 1.1, 0.4) * ANG(-0.6, 0, -0.4))
end
GEAR.valkyriehelm = function(b)
	piece(b, "Head", {Shape = BALL, Size = V(1.5, 1.4, 1.5), Color = STEEL, Material = METAL, Reflectance = 0.2}, CF(0, 0.3, 0.05))
	piece(b, "Head", {Size = V(0.18, 0.6, 0.12), Color = STEEL, Material = METAL}, CF(0, 0.1, -0.72))
	for s = -1, 1, 2 do
		for k = 0, 2 do
			piece(b, "Head", {Size = V(0.1, 1.1 - k * 0.2, 0.32), Color = WHITE, Material = FABRIC}, CF(s * (0.75 + k * 0.08), 0.65 + k * 0.12, 0.15 + k * 0.18) * ANG(-0.5 - k * 0.2, 0, -s * (0.45 + k * 0.1)))
		end
	end
end
GEAR.championhelm = function(b)
	piece(b, "Head", {Shape = BALL, Size = V(1.55, 1.55, 1.55), Color = GOLD, Material = METAL, Reflectance = 0.15}, CF(0, 0.22, 0.05))
	piece(b, "Head", {Size = V(1.1, 0.14, 0.1), Color = BLACK}, CF(0, 0.15, -0.76))
	piece(b, "Head", {Size = V(0.16, 0.6, 0.1), Color = BLACK}, CF(0, -0.15, -0.76))
	piece(b, "Head", {Size = V(0.26, 0.5, 1.6), Color = rgb(40, 80, 210), Material = FABRIC}, CF(0, 1.1, 0.35) * ANG(-0.3, 0, 0))
end
GEAR.herohair = function(b, def)
	local c = def and def.hair or rgb(110, 70, 36)
	piece(b, "Head", {Shape = BALL, Size = V(1.32, 1.05, 1.36), Color = c, Material = PLASTIC}, CF(0, 0.38, 0.08))
	for i, s in {{-0.4, 0.75, -0.25, 0.5}, {0, 0.85, -0.3, 0}, {0.4, 0.75, -0.25, -0.5}, {-0.3, 0.75, 0.3, 0.6}, {0.3, 0.75, 0.3, -0.6}} do
		piece(b, "Head", {Size = V(0.35, 0.6, 0.35), Color = c, Material = PLASTIC}, CF(s[1], s[2], s[3]) * ANG(-0.4, 0, s[4]))
	end
end
GEAR.beard = function(b, def)
	local c = def and def.hair or rgb(200, 196, 190)
	piece(b, "Head", {Size = V(1.05, 0.7, 0.4), Color = c, Material = FABRIC}, CF(0, -0.42, -0.45))
	piece(b, "Head", {Size = V(0.7, 0.6, 0.35), Color = c, Material = FABRIC}, CF(0, -0.85, -0.42) * ANG(0.15, 0, 0))
end

---------- Cuerpo y espalda ----------
GEAR.tabard = function(b, def)
	local c = def and def.tabard or rgb(40, 70, 170)
	piece(b, "UpperTorso", {Size = V(1.3, 1.72, 1.06), Color = c, Material = FABRIC}, CF(0, 0, 0))
	piece(b, "LowerTorso", {Size = V(1.2, 1.5, 1.06), Color = c, Material = FABRIC}, CF(0, -0.6, 0))
	-- emblema: cruz dorada
	piece(b, "UpperTorso", {Size = V(0.2, 0.8, 0.05), Color = GOLD, Material = METAL}, CF(0, 0.05, -0.54))
	piece(b, "UpperTorso", {Size = V(0.6, 0.2, 0.05), Color = GOLD, Material = METAL}, CF(0, 0.2, -0.54))
	piece(b, "LowerTorso", {Size = V(2.05, 0.25, 1.1), Color = LEATHER, Material = FABRIC}, CF(0, 0.05, 0))
	-- armadura: cota de malla, hombreras, guanteletes y grebas de acero
	for _, n in {"UpperTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm"} do
		local p = b:FindFirstChild(n)
		if p then
			p.Material, p.Reflectance = M.DiamondPlate, 0.05
		end
	end
	for _, s in {"Left", "Right"} do
		local x = s == "Left" and -1 or 1
		piece(b, s .. "UpperArm", {Name = "Pauldron", Shape = BALL, Size = V(1.15, 0.62, 1.12), Color = STEEL, Material = METAL, Reflectance = 0.2}, CF(x * 0.06, 0.48, 0))
		piece(b, s .. "UpperArm", {Name = "PauldronRim", Size = V(1.1, 0.1, 1.1), Color = GOLD, Material = METAL}, CF(x * 0.06, 0.3, 0))
		piece(b, s .. "LowerArm", {Name = "Gauntlet", Size = V(1.1, 0.55, 1.1), Color = STEEL, Material = METAL, Reflectance = 0.2}, CF(0, -0.3, 0))
		piece(b, s .. "LowerLeg", {Name = "Greave", Size = V(1.06, 0.95, 1.04), Color = STEEL, Material = METAL, Reflectance = 0.2}, CF(0, -0.12, -0.02))
		piece(b, s .. "LowerLeg", {Name = "Knee", Shape = BALL, Size = V(0.6, 0.55, 0.45), Color = STEEL, Material = METAL, Reflectance = 0.2}, CF(0, 0.55, -0.42))
	end
end
GEAR.coat = function(b, def)
	local c = def and def.coat or (def and def.shirt and def.shirt:Lerp(BLACK, 0.2)) or rgb(50, 40, 36)
	skirt(b, c, 1.7, true)
	piece(b, "UpperTorso", {Size = V(2.1, 0.5, 1.15), Color = c:Lerp(BLACK, 0.1), Material = FABRIC}, CF(0, 0.72, 0.04))
	piece(b, "LowerTorso", {Size = V(2.05, 0.22, 1.08), Color = LEATHER, Material = FABRIC}, CF(0, 0.05, 0))
	piece(b, "LowerTorso", {Size = V(0.3, 0.24, 0.1), Color = GOLD, Material = METAL}, CF(0, 0.05, -0.56))
end
GEAR.cape = function(b, def)
	capeOf(b, def and def.cape or rgb(150, 20, 30), 3.2, 2.1)
end
GEAR.royalcape = function(b, def)
	local c = def and def.cape or rgb(170, 20, 40)
	capeOf(b, c, 3.6, 2.4, WHITE)
	-- cuello de armiño (con motas por la espalda)
	piece(b, "UpperTorso", {Size = V(2.2, 0.32, 1.2), Color = WHITE, Material = FABRIC}, CF(0, 0.9, 0.08))
	for k = -2, 2 do
		piece(b, "UpperTorso", {Size = V(0.1, 0.06, 0.16), Color = BLACK}, CF(k * 0.42, 1.07, 0.35))
	end
end
GEAR.backpack = function(b, def)
	local c = def and def.pack or rgb(120, 90, 50)
	piece(b, "UpperTorso", {Size = V(1.5, 1.6, 0.8), Color = c, Material = FABRIC}, CF(0, -0.05, 0.85))
	piece(b, "UpperTorso", {Size = V(1.3, 0.6, 0.35), Color = c:Lerp(BLACK, 0.2), Material = FABRIC}, CF(0, -0.45, 1.3))
	piece(b, "UpperTorso", {Shape = CYL, Size = V(1.7, 0.55, 0.55), Color = rgb(90, 110, 70), Material = FABRIC}, CF(0, 0.9, 0.9))
	for s = -1, 1, 2 do
		piece(b, "UpperTorso", {Size = V(0.22, 1.7, 0.08), Color = LEATHER, Material = FABRIC}, CF(s * 0.5, 0.05, -0.53))
	end
end
GEAR.quiver = function(b)
	local q = piece(b, "UpperTorso", {Shape = CYL, Size = V(1.8, 0.6, 0.6), Color = LEATHER, Material = FABRIC}, CF(0.35, 0.1, 0.75) * ANG(0, 0, PI / 2 - 0.35))
	for k = -1, 1 do
		piece(b, "UpperTorso", {Size = V(0.06, 0.6, 0.06), Color = WOODC}, CF(0.72 + k * 0.1, 1.1, 0.75 + k * 0.08) * ANG(0, 0, -0.35))
		piece(b, "UpperTorso", {Size = V(0.04, 0.3, 0.18), Color = rgb(230, 230, 220), Material = FABRIC}, CF(0.82 + k * 0.1, 1.38, 0.75 + k * 0.08) * ANG(0, 0, -0.35))
	end
	piece(b, "UpperTorso", {Size = V(0.18, 2.2, 0.08), Color = LEATHER, Material = FABRIC}, CF(0, 0, -0.53) * ANG(0, 0, 0.6))
	return q
end
GEAR.wings = function(b, def)
	local c = def and def.wingColor or WHITE
	for s = -1, 1, 2 do
		for k = 0, 3 do
			piece(b, "UpperTorso", {Size = V(0.12, 2.2 - k * 0.35, 0.55), Color = c:Lerp(rgb(255, 230, 160), k * 0.08), Material = FABRIC}, CF(s * (0.7 + k * 0.32), 0.3 + k * 0.18, 0.75 + k * 0.08) * ANG(0.2, -s * 0.5, -s * (0.75 + k * 0.18)))
		end
	end
end

---------- Mano derecha ----------
GEAR.pitchfork = function(b)
	shaft(b, 5.2, 1.4, 0.18, WOODC)
	local d = 5.2 - 1.4
	piece(b, "RightHand", {Size = V(1, 0.12, 0.14), Color = IRON, Material = METAL}, tip(d))
	for k = -1, 1 do
		piece(b, "RightHand", {Size = V(0.1, 0.1, 0.9), Color = IRON, Material = METAL}, tip(d + 0.45) * CF(k * 0.42, 0, 0))
	end
end
GEAR.torch = function(b)
	local t = piece(b, "RightHand", {Name = "Torch", Shape = CYL, Size = V(2.2, 0.24, 0.24), Color = DARKWOOD, Material = WOOD}, CF(0, 0.6, -0.3) * ANG(0, 0, PI / 2))
	local head = piece(b, "RightHand", {Shape = CYL, Size = V(0.45, 0.4, 0.4), Color = rgb(70, 50, 40), Material = FABRIC}, CF(0, 1.65, -0.3) * ANG(0, 0, PI / 2))
	fire(head, 2.4)
	light(head, 12, 1.6, rgb(255, 150, 60))
	return t
end
GEAR.shortsword = function(b)
	blade(b, 2, 0.32, STEEL, rgb(140, 100, 50))
end
GEAR.sword = function(b)
	blade(b, 2.8, 0.36, STEEL, GOLD)
end
GEAR.greatsword = function(b, def)
	local dark = def and def.shirt and def.shirt.R < 0.3
	local bl = blade(b, 4.2, 0.55, dark and rgb(60, 60, 70) or STEEL, dark and rgb(150, 20, 30) or GOLD)
	if dark then
		local e = piece(b, "RightHand", {Size = V(0.1, 0.1, 3.6), Color = rgb(255, 40, 40), Material = NEON}, CF(0, -0.25, -0.5 - 2.1))
		light(e, 7, 1.2, rgb(255, 40, 40))
	end
	return bl
end
GEAR.silversword = function(b)
	local bl = blade(b, 3.2, 0.4, rgb(220, 230, 245), rgb(200, 205, 215))
	sparkle(bl, rgb(220, 240, 255), 4)
end
GEAR.herosword = function(b)
	local bl = blade(b, 3, 0.42, rgb(200, 220, 255), GOLD)
	piece(b, "RightHand", {Shape = BALL, Size = V(0.28, 0.28, 0.28), Color = rgb(60, 200, 255), Material = NEON}, CF(0, -0.3, -0.45))
	return bl
end
GEAR.holysword = function(b)
	local bl = blade(b, 4, 0.55, rgb(255, 240, 180), GOLD, true)
	light(bl, 12, 2, rgb(255, 230, 150))
	sparkle(bl, rgb(255, 240, 180), 8)
end
GEAR.lance = function(b, def)
	local c = def and def.tabard or rgb(200, 160, 40)
	piece(b, "RightHand", {Shape = CYL, Size = V(6, 0.3, 0.3), Color = WHITE, Material = WOOD}, CF(0, -0.3, -2.4) * ANG(0, PI / 2, 0))
	for k = 0, 3 do
		piece(b, "RightHand", {Shape = CYL, Size = V(0.4, 0.32, 0.32), Color = c, Material = WOOD}, CF(0, -0.3, -0.6 - k * 1.3) * ANG(0, PI / 2, 0))
	end
	piece(b, "RightHand", {Shape = CYL, Size = V(0.5, 1.2, 1.2), Color = STEEL, Material = METAL}, CF(0, -0.3, 0.2) * ANG(0, PI / 2, 0))
	piece(b, "RightHand", {Size = V(0.35, 0.35, 0.8), Color = STEEL, Material = METAL}, CF(0, -0.3, -5.6) * ANG(0, 0, PI / 4))
end
GEAR.spear = function(b)
	shaft(b, 5.4, 1.2, 0.18, WOODC)
	piece(b, "RightHand", {Size = V(0.4, 0.08, 1.1), Color = STEEL, Material = METAL}, tip(4.7))
	piece(b, "RightHand", {Size = V(0.3, 0.07, 0.3), Color = STEEL, Material = METAL}, tip(5.25) * ANG(0, PI / 4, 0))
	piece(b, "RightHand", {Size = V(0.12, 0.3, 0.12), Color = rgb(200, 40, 40), Material = FABRIC}, tip(4.05, -0.18))
end
GEAR.crossbow = function(b)
	piece(b, "RightHand", {Size = V(0.3, 0.3, 2.4), Color = DARKWOOD, Material = WOOD}, CF(0, -0.15, -0.9))
	piece(b, "RightHand", {Size = V(2.2, 0.16, 0.2), Color = DARKWOOD, Material = WOOD}, CF(0, -0.05, -1.85) * ANG(0, 0.0, 0))
	for s = -1, 1, 2 do
		piece(b, "RightHand", {Size = V(0.04, 0.04, 1.2), Color = WHITE, Material = FABRIC}, CF(s * 0.55, -0.05, -1.35) * ANG(0, s * 1.05, 0))
	end
	piece(b, "RightHand", {Size = V(0.08, 0.08, 1.4), Color = STEEL, Material = METAL}, CF(0, 0.05, -1.4))
end
GEAR.longbow = function(b)
	-- arco curvado en la mano izquierda (vertical) y una flecha en la derecha
	for k = -3, 3 do
		local a = k / 3 * 0.55
		piece(b, "LeftHand", {Size = V(0.14, 0.75, 0.14), Color = WOODC, Material = WOOD}, CF(0, 0.2 + math.sin(a) * 2.2, -0.6 - (1 - math.cos(a)) * 1.8) * ANG(-a, 0, 0))
	end
	piece(b, "LeftHand", {Size = V(0.03, 4.6, 0.03), Color = WHITE, Material = FABRIC}, CF(0, 0.2, -0.05))
	piece(b, "RightHand", {Size = V(0.06, 0.06, 2), Color = WOODC}, CF(0, -0.3, -0.8))
end
GEAR.warhammer = function(b)
	shaft(b, 3, 0.5, 0.2, rgb(240, 236, 220), METAL)
	local h = piece(b, "RightHand", {Size = V(0.7, 0.7, 1.3), Color = GOLD, Material = METAL, Reflectance = 0.1}, tip(2.6, 0.35))
	sparkle(h, rgb(255, 240, 160), 4)
	light(h, 8, 1.2, rgb(255, 230, 140))
end
GEAR.scepter = function(b)
	shaft(b, 2.6, 0.4, 0.2, GOLD, METAL)
	local g = piece(b, "RightHand", {Shape = BALL, Size = V(0.55, 0.55, 0.55), Color = rgb(255, 60, 90), Material = NEON}, tip(2.3))
	piece(b, "RightHand", {Size = V(0.12, 0.6, 0.12), Color = GOLD, Material = METAL}, tip(2.3, 0.5))
	light(g, 8, 1.5, rgb(255, 80, 110))
end
GEAR.axe = function(b)
	shaft(b, 2.6, 0.4, 0.2, WOODC)
	piece(b, "RightHand", {Size = V(0.12, 0.9, 0.75), Color = STEEL, Material = METAL}, tip(2.1, 0.45))
end
GEAR.iceaxe = function(b)
	shaft(b, 2.2, 0.3, 0.16, rgb(60, 60, 70), METAL)
	piece(b, "RightHand", {Size = V(0.12, 1.2, 0.2), Color = STEEL, Material = METAL}, tip(1.85, 0.2))
	piece(b, "RightHand", {Size = V(0.1, 0.16, 0.3), Color = rgb(255, 120, 40), Material = PLASTIC}, tip(1.4))
end
GEAR.pickaxe = function(b)
	shaft(b, 2.6, 0.4, 0.2, WOODC)
	for s = -1, 1, 2 do
		piece(b, "RightHand", {Size = V(0.18, 0.95, 0.24), Color = DARKSTEEL, Material = METAL}, tip(2.15, s * 0.45) * ANG(s * 0.35, 0, 0))
	end
end
GEAR.daggers = function(b)
	for _, hand in {"RightHand", "LeftHand"} do
		piece(b, hand, {Size = V(0.22, 0.06, 1.1), Color = rgb(190, 196, 210), Material = METAL, Reflectance = 0.2}, CF(0, -0.3, -0.75))
		piece(b, hand, {Size = V(0.55, 0.1, 0.12), Color = rgb(60, 50, 70), Material = METAL}, CF(0, -0.3, -0.2))
	end
end
GEAR.whip = function(b)
	piece(b, "RightHand", {Shape = CYL, Size = V(0.7, 0.2, 0.2), Color = LEATHER, Material = FABRIC}, CF(0, -0.3, -0.1) * ANG(0, PI / 2, 0))
	for k = 0, 5 do
		local a = k / 6 * PI * 2
		piece(b, "RightHand", {Size = V(0.1, 0.1, 0.5), Color = LEATHER, Material = FABRIC}, CF(math.cos(a) * 0.5 + 0.7, -0.6, math.sin(a) * 0.5) * ANG(0, -a, 0))
	end
end
GEAR.lantern = function(b)
	piece(b, "RightHand", {Size = V(0.06, 0.6, 0.06), Color = IRON, Material = METAL}, CF(0, -0.55, -0.3))
	local l = piece(b, "RightHand", {Size = V(0.6, 0.8, 0.6), Color = rgb(255, 200, 90), Material = NEON, Transparency = 0.15}, CF(0, -1.2, -0.3))
	piece(b, "RightHand", {Size = V(0.75, 0.15, 0.75), Color = IRON, Material = METAL}, CF(0, -0.75, -0.3))
	piece(b, "RightHand", {Size = V(0.75, 0.15, 0.75), Color = IRON, Material = METAL}, CF(0, -1.65, -0.3))
	light(l, 16, 2.2, rgb(255, 200, 100))
end
GEAR.holybook = function(b)
	local bk = piece(b, "LeftHand", {Size = V(1, 0.3, 1.3), Color = rgb(120, 30, 30), Material = M.Leather or FABRIC}, CF(0, 0.15, -0.5))
	piece(b, "LeftHand", {Size = V(0.94, 0.26, 1.24), Color = rgb(240, 230, 200), Material = PLASTIC}, CF(0.04, 0.15, -0.5))
	piece(b, "LeftHand", {Size = V(0.1, 0.32, 0.6), Color = GOLD, Material = METAL}, CF(-0.02, 0.16, -0.5))
	piece(b, "LeftHand", {Size = V(0.4, 0.32, 0.1), Color = GOLD, Material = METAL}, CF(-0.02, 0.16, -0.6))
	sparkle(bk, rgb(255, 240, 180), 3)
end
GEAR.holystaff = function(b)
	shaft(b, 4.2, 1.2, 0.2, GOLD, METAL)
	piece(b, "RightHand", {Size = V(0.14, 1.1, 0.14), Color = GOLD, Material = METAL}, tip(3.1, 0.5))
	piece(b, "RightHand", {Size = V(0.7, 0.14, 0.14), Color = GOLD, Material = METAL}, tip(3.1, 0.7))
	light(piece(b, "RightHand", {Shape = BALL, Size = V(0.3, 0.3, 0.3), Color = rgb(255, 240, 180), Material = NEON}, tip(3.1, 1.1)), 8, 1.5, rgb(255, 230, 150))
end
GEAR.staff = function(b)
	local s = piece(b, "RightHand", {Shape = CYL, Size = V(4.6, 0.22, 0.22), Color = DARKWOOD, Material = WOOD}, CF(0, 1.1, -0.25) * ANG(0, 0, PI / 2))
	local c = piece(b, "RightHand", {Shape = BALL, Size = V(0.55, 0.55, 0.55), Color = rgb(110, 200, 255), Material = NEON}, CF(0, 3.5, -0.25))
	light(c, 10, 1.6, rgb(110, 200, 255))
	sparkle(c, rgb(160, 220, 255), 5)
	return s
end
GEAR.archstaff = function(b)
	piece(b, "RightHand", {Shape = CYL, Size = V(5.2, 0.24, 0.24), Color = rgb(60, 40, 90), Material = WOOD}, CF(0, 1.4, -0.25) * ANG(0, 0, PI / 2))
	for k = 0, 2 do
		local a = k / 3 * PI * 2
		piece(b, "RightHand", {Size = V(0.1, 0.9, 0.1), Color = GOLD, Material = METAL}, CF(math.cos(a) * 0.3, 4.1, -0.25 + math.sin(a) * 0.3) * ANG(math.sin(a) * 0.4, 0, -math.cos(a) * 0.4))
	end
	local c = piece(b, "RightHand", {Shape = BALL, Size = V(0.7, 0.7, 0.7), Color = rgb(190, 110, 255), Material = NEON}, CF(0, 4.3, -0.25))
	light(c, 14, 2, rgb(190, 110, 255))
	sparkle(c, rgb(210, 160, 255), 8)
end
GEAR.orb = function(b)
	local o = piece(b, "RightHand", {Shape = BALL, Size = V(0.8, 0.8, 0.8), Color = rgb(255, 80, 220), Material = NEON, Transparency = 0.1}, CF(0, 0.2, -0.6))
	light(o, 10, 1.8, rgb(255, 80, 220))
	sparkle(o, rgb(255, 140, 240), 8)
end
GEAR.goldsack = function(b)
	local s = piece(b, "UpperTorso", {Shape = BALL, Size = V(1.6, 1.7, 1.4), Color = rgb(160, 120, 70), Material = FABRIC}, CF(0.2, -0.1, 0.95))
	for k = 1, 4 do
		piece(b, "UpperTorso", {Shape = CYL, Size = V(0.1, 0.5, 0.5), Color = GOLD, Material = NEON}, CF(-0.2 + k * 0.15, 0.75 + k % 2 * 0.1, 0.9) * ANG(0.4, 0, PI / 2 + k))
	end
	sparkle(s, rgb(255, 220, 90), 6)
end
GEAR.flag = function(b)
	piece(b, "RightHand", {Shape = CYL, Size = V(6, 0.2, 0.2), Color = WOODC, Material = WOOD}, CF(0, 2, -0.25) * ANG(0, 0, PI / 2))
	local f = piece(b, "RightHand", {Size = V(0.06, 1.4, 2.2), Color = rgb(200, 40, 40), Material = FABRIC}, CF(0, 4.2, 0.9))
	piece(b, "RightHand", {Size = V(0.08, 0.5, 0.5), Color = WHITE, Material = FABRIC}, CF(0, 4.2, 0.9) * ANG(PI / 4, 0, 0))
	return f
end
GEAR.lute = function(b)
	local body = piece(b, "UpperTorso", {Shape = BALL, Size = V(1.2, 1.4, 0.55), Color = rgb(170, 110, 50), Material = WOOD}, CF(-0.1, -0.35, -0.75) * ANG(0, 0, 0.7))
	piece(b, "UpperTorso", {Size = V(0.22, 1.6, 0.12), Color = DARKWOOD, Material = WOOD}, CF(0.6, 0.35, -0.8) * ANG(0, 0, 0.7))
	piece(b, "UpperTorso", {Shape = CYL, Size = V(0.05, 0.35, 0.35), Color = BLACK}, CF(-0.1, -0.35, -1.03) * ANG(0, PI / 2, 0))
	return body
end

---------- Mano izquierda: escudos ----------
GEAR.kiteshield = function(b, def)
	local s, off = shieldAt(b, 1.6, 2.6, def and def.tabard or rgb(40, 70, 170), STEEL)
	piece(b, "LeftHand", {Size = V(0.06, 1.2, 0.25), Color = GOLD, Material = METAL}, off * CF(-0.12, 0.3, 0))
	piece(b, "LeftHand", {Size = V(0.06, 0.25, 0.8), Color = GOLD, Material = METAL}, off * CF(-0.12, 0.5, 0))
	return s
end
GEAR.towershield = function(b, def)
	local c = def and def.tabard or rgb(150, 30, 40)
	local off = CF(0, 0.7, -0.85) * ANG(0, PI / 2, 0)
	local s = piece(b, "LeftHand", {Name = "Shield", Size = V(0.25, 3.8, 2.3), Color = c, Material = PLASTIC}, off)
	piece(b, "LeftHand", {Size = V(0.2, 3.95, 2.45), Color = STEEL, Material = METAL}, off * CF(0.04, 0, 0))
	piece(b, "LeftHand", {Size = V(0.06, 2.6, 0.3), Color = GOLD, Material = METAL}, off * CF(-0.14, 0.1, 0))
	piece(b, "LeftHand", {Size = V(0.06, 0.3, 1.6), Color = GOLD, Material = METAL}, off * CF(-0.14, 0.6, 0))
	return s
end
GEAR.heroshield = function(b)
	local s, off = shieldAt(b, 1.9, 1.9, rgb(40, 80, 200), GOLD, "round")
	piece(b, "LeftHand", {Size = V(0.06, 0.9, 0.9), Color = GOLD, Material = METAL}, off * CF(-0.14, 0, 0) * ANG(PI / 4, 0, 0))
	return s
end

---------- Visitantes de las casas ----------
local HAIRS = {rgb(60, 40, 26), rgb(110, 70, 36), rgb(30, 26, 24), rgb(200, 160, 90), rgb(150, 60, 30), rgb(90, 60, 40)}
Outfits.HAIRS = HAIRS

GEAR.hair = function(b, def)
	local c = def and def.hair or HAIRS[1]
	piece(b, "Head", {Name = "Pelo", Shape = BALL, Size = V(1.3, 1, 1.32), Color = c, Material = PLASTIC}, CF(0, 0.36, 0.1))
	piece(b, "Head", {Name = "Flequillo", Size = V(1.2, 0.32, 0.4), Color = c, Material = PLASTIC}, CF(0, 0.48, -0.48) * ANG(0.3, 0, 0))
	for s = -1, 1, 2 do
		piece(b, "Head", {Name = "Patilla", Size = V(0.16, 0.6, 0.6), Color = c, Material = PLASTIC}, CF(s * 0.6, 0.15, 0.1))
	end
end
GEAR.bun = function(b, def)
	GEAR.hair(b, def)
	piece(b, "Head", {Name = "Moño", Shape = BALL, Size = V(0.75, 0.75, 0.75), Color = def and def.hair or rgb(220, 220, 225), Material = PLASTIC}, CF(0, 0.85, 0.35))
end
GEAR.headphones = function(b, def)
	GEAR.hair(b, def)
	piece(b, "Head", {Size = V(1.45, 0.2, 0.3), Color = rgb(30, 30, 36), Material = PLASTIC}, CF(0, 0.66, 0.05))
	for s = -1, 1, 2 do
		piece(b, "Head", {Size = V(0.2, 0.75, 0.3), Color = rgb(30, 30, 36), Material = PLASTIC}, CF(s * 0.68, 0.32, 0.05))
		piece(b, "Head", {Shape = CYL, Size = V(0.3, 0.62, 0.62), Color = rgb(230, 60, 90), Material = PLASTIC}, CF(s * 0.66, 0, 0.05))
	end
end
local function lenses(b, color, mat, tr)
	for s = -1, 1, 2 do
		piece(b, "Head", {Size = V(0.38, 0.26, 0.08), Color = color, Material = mat, Transparency = tr or 0, Reflectance = 0.2}, CF(s * 0.24, 0.12, -0.6))
	end
	piece(b, "Head", {Size = V(0.14, 0.06, 0.06), Color = rgb(20, 20, 24)}, CF(0, 0.15, -0.61))
	for s = -1, 1, 2 do
		piece(b, "Head", {Size = V(0.06, 0.06, 0.6), Color = rgb(20, 20, 24)}, CF(s * 0.46, 0.15, -0.32))
	end
end
GEAR.glasses = function(b)
	lenses(b, rgb(200, 230, 255), M.Glass, 0.75)
	-- montura: solo el borde, para que se vean los ojos
	for s = -1, 1, 2 do
		for _, y in {0.27, -0.03} do
			piece(b, "Head", {Size = V(0.42, 0.05, 0.05), Color = rgb(30, 26, 24)}, CF(s * 0.24, y, -0.63))
		end
		for _, x in {0.03, 0.45} do
			piece(b, "Head", {Size = V(0.05, 0.3, 0.05), Color = rgb(30, 26, 24)}, CF(s * x, 0.12, -0.63))
		end
	end
end
GEAR.sunglasses = function(b)
	lenses(b, rgb(20, 20, 28), M.Glass, 0)
end
GEAR.eyepatch = function(b)
	piece(b, "Head", {Size = V(0.32, 0.3, 0.08), Color = rgb(20, 20, 24)}, CF(0.24, 0.12, -0.61))
	piece(b, "Head", {Size = V(1.24, 0.07, 1.24), Color = rgb(20, 20, 24)}, CF(0, 0.2, 0) * ANG(0, 0, 0.25))
end
GEAR.headband = function(b, def)
	GEAR.hair(b, def)
	-- cinta alrededor de la frente (cuatro tiras)
	local c = def and def.bandColor or rgb(255, 255, 255)
	piece(b, "Head", {Size = V(1.24, 0.24, 0.08), Color = c, Material = FABRIC}, CF(0, 0.32, -0.6))
	piece(b, "Head", {Size = V(1.24, 0.24, 0.08), Color = c, Material = FABRIC}, CF(0, 0.32, 0.6))
	for s = -1, 1, 2 do
		piece(b, "Head", {Size = V(0.08, 0.24, 1.24), Color = c, Material = FABRIC}, CF(s * 0.6, 0.32, 0))
	end
end
GEAR.pumpkinhead = function(b)
	local p = piece(b, "Head", {Name = "Calabaza", Shape = BALL, Size = V(1.9, 1.6, 1.9), Color = rgb(255, 130, 30), Material = PLASTIC}, CF(0, 0.15, 0))
	piece(b, "Head", {Size = V(0.25, 0.5, 0.25), Color = rgb(70, 120, 40)}, CF(0, 1.05, 0) * ANG(0, 0, 0.3))
	for s = -1, 1, 2 do
		piece(b, "Head", {Size = V(0.32, 0.3, 0.1), Color = rgb(255, 230, 90), Material = NEON}, CF(s * 0.35, 0.3, -0.92) * ANG(0, 0, s * 0.4))
	end
	piece(b, "Head", {Size = V(0.9, 0.2, 0.1), Color = rgb(255, 230, 90), Material = NEON}, CF(0, -0.2, -0.93))
	light(p, 6, 0.8, rgb(255, 170, 60))
end
GEAR.pail = function(b)
	piece(b, "LeftHand", {Shape = CYL, Size = V(0.9, 1, 1), Color = rgb(255, 130, 30), Material = PLASTIC}, CF(0, -0.75, -0.2) * ANG(0, 0, PI / 2))
	piece(b, "LeftHand", {Size = V(0.08, 0.7, 1), Color = rgb(30, 30, 30)}, CF(0, -0.2, -0.2))
	for k = 0, 2 do
		piece(b, "LeftHand", {Shape = BALL, Size = V(0.28, 0.28, 0.28), Color = ({rgb(255, 60, 120), rgb(90, 220, 255), rgb(255, 230, 60)})[k + 1], Material = PLASTIC}, CF((k - 1) * 0.22, -0.3, -0.2))
	end
end
GEAR.sheet = function(b)
	piece(b, "Head", {Name = "Sabana", Shape = BALL, Size = V(1.5, 1.5, 1.5), Color = rgb(245, 245, 245), Material = FABRIC}, CF(0, 0.15, 0))
	for s = -1, 1, 2 do
		piece(b, "Head", {Shape = BALL, Size = V(0.32, 0.4, 0.1), Color = rgb(10, 10, 14)}, CF(s * 0.28, 0.2, -0.73))
	end
	piece(b, "UpperTorso", {Name = "Sabana", Size = V(2.4, 1.9, 1.3), Color = rgb(245, 245, 245), Material = FABRIC}, CF(0, -0.05, 0))
	piece(b, "LowerTorso", {Name = "Sabana", Size = V(2.5, 1.8, 1.35), Color = rgb(245, 245, 245), Material = FABRIC}, CF(0, -0.7, 0))
end
GEAR.tie = function(b, def)
	local c = def and def.tieColor or rgb(190, 30, 40)
	piece(b, "UpperTorso", {Size = V(0.3, 0.25, 0.08), Color = c}, CF(0, 0.7, -0.53))
	piece(b, "UpperTorso", {Size = V(0.32, 1.1, 0.06), Color = c}, CF(0, 0.1, -0.53))
end
GEAR.briefcase = function(b)
	piece(b, "LeftHand", {Size = V(0.4, 1.3, 1.7), Color = rgb(80, 50, 30), Material = M.Leather or FABRIC}, CF(0, -0.9, 0))
	piece(b, "LeftHand", {Size = V(0.12, 0.3, 0.7), Color = rgb(40, 30, 20)}, CF(0, -0.15, 0))
end
GEAR.pizza = function(b)
	piece(b, "RightHand", {Size = V(1.7, 0.3, 1.7), Color = rgb(235, 225, 205), Material = M.Cardboard or PLASTIC}, CF(-0.5, 0.05, -0.6))
	piece(b, "RightHand", {Size = V(0.8, 0.05, 0.8), Color = rgb(200, 40, 40)}, CF(-0.5, 0.22, -0.6))
end
GEAR.firehelm = function(b)
	piece(b, "Head", {Shape = BALL, Size = V(1.5, 1.3, 1.6), Color = rgb(200, 30, 30), Material = PLASTIC}, CF(0, 0.45, 0.05))
	piece(b, "Head", {Size = V(1.6, 0.1, 2.3), Color = rgb(190, 26, 26), Material = PLASTIC}, CF(0, 0.2, 0.25) * ANG(-0.1, 0, 0))
	piece(b, "Head", {Size = V(0.5, 0.55, 0.08), Color = GOLD, Material = METAL}, CF(0, 0.55, -0.78))
end
GEAR.policecap = function(b)
	GEAR.cap(b, {capColor = rgb(26, 34, 70)})
	piece(b, "Head", {Size = V(0.3, 0.3, 0.06), Color = GOLD, Material = METAL}, CF(0, 0.6, -0.66))
end
GEAR.badge = function(b)
	piece(b, "UpperTorso", {Size = V(0.34, 0.34, 0.06), Color = GOLD, Material = METAL}, CF(0.45, 0.35, -0.53) * ANG(0, 0, PI / 4))
end
GEAR.chefhat = function(b)
	piece(b, "Head", {Shape = CYL, Size = V(0.8, 1.25, 1.25), Color = WHITE, Material = FABRIC}, CF(0, 0.85, 0) * ANG(0, 0, PI / 2))
	piece(b, "Head", {Shape = BALL, Size = V(1.7, 1.1, 1.7), Color = WHITE, Material = FABRIC}, CF(0, 1.45, 0))
end
GEAR.apron = function(b)
	piece(b, "UpperTorso", {Size = V(1.4, 1.2, 0.08), Color = WHITE, Material = FABRIC}, CF(0, -0.2, -0.53))
	piece(b, "LowerTorso", {Size = V(1.5, 1.4, 0.08), Color = WHITE, Material = FABRIC}, CF(0, -0.6, -0.55))
end
GEAR.labcoat = function(b)
	GEAR.coat(b, {coat = rgb(245, 245, 248)})
end
GEAR.stethoscope = function(b)
	for k = 0, 6 do
		local a = k / 6 * PI
		piece(b, "UpperTorso", {Size = V(0.12, 0.12, 0.3), Color = rgb(30, 30, 36)}, CF(math.cos(a) * 0.55, 0.75 - math.sin(a) * 0.55, -0.52))
	end
	piece(b, "UpperTorso", {Shape = CYL, Size = V(0.1, 0.3, 0.3), Color = rgb(190, 196, 210), Material = METAL}, CF(0, 0.15, -0.55) * ANG(0, PI / 2, 0))
end
GEAR.scouthat = function(b)
	GEAR.widehat(b, {hatColor = rgb(170, 150, 90), bandColor = rgb(110, 80, 40)})
end
GEAR.sash = function(b)
	piece(b, "UpperTorso", {Size = V(0.4, 2.2, 0.06), Color = rgb(200, 60, 60), Material = FABRIC}, CF(0, 0, -0.53) * ANG(0, 0, 0.6))
	for k = 0, 2 do
		piece(b, "UpperTorso", {Shape = CYL, Size = V(0.06, 0.25, 0.25), Color = ({GOLD, rgb(90, 200, 255), rgb(120, 230, 120)})[k + 1], Material = PLASTIC}, CF(-0.35 + k * 0.32, 0.4 - k * 0.42, -0.56) * ANG(0, PI / 2, 0))
	end
end
GEAR.parrot = function(b)
	local body = piece(b, "UpperTorso", {Shape = BALL, Size = V(0.55, 0.7, 0.55), Color = rgb(40, 200, 70), Material = PLASTIC}, CF(0.85, 1.25, 0))
	piece(b, "UpperTorso", {Shape = BALL, Size = V(0.42, 0.42, 0.42), Color = rgb(40, 200, 70), Material = PLASTIC}, CF(0.85, 1.7, -0.08))
	piece(b, "UpperTorso", {Size = V(0.14, 0.14, 0.22), Color = rgb(255, 200, 40)}, CF(0.85, 1.68, -0.32))
	piece(b, "UpperTorso", {Size = V(0.2, 0.7, 0.18), Color = rgb(220, 40, 40), Material = PLASTIC}, CF(0.85, 0.85, 0.22) * ANG(0.4, 0, 0))
	return body
end
GEAR.hook = function(b)
	for k = 0, 3 do
		local a = k / 4 * PI
		piece(b, "LeftHand", {Size = V(0.12, 0.12, 0.3), Color = rgb(200, 205, 215), Material = METAL}, CF(0, -0.55 - math.sin(a) * 0.3, -math.cos(a) * 0.3))
	end
end
GEAR.astropack = function(b)
	piece(b, "UpperTorso", {Size = V(1.6, 1.7, 0.8), Color = rgb(235, 235, 240), Material = PLASTIC}, CF(0, 0, 0.85))
	piece(b, "UpperTorso", {Size = V(0.8, 0.5, 0.08), Color = rgb(60, 130, 230), Material = NEON}, CF(0, 0.3, -0.53))
end
GEAR.astrohelm = function(b)
	piece(b, "Head", {Shape = BALL, Size = V(2, 2, 2), Color = rgb(190, 225, 255), Material = M.Glass, Transparency = 0.55, Reflectance = 0.3}, CF(0, 0.1, 0))
	piece(b, "Head", {Shape = CYL, Size = V(0.5, 1.9, 1.9), Color = rgb(235, 235, 240), Material = PLASTIC}, CF(0, -0.75, 0) * ANG(0, 0, PI / 2))
end
GEAR.katana = function(b)
	piece(b, "RightHand", {Size = V(0.18, 0.06, 3.4), Color = rgb(210, 215, 225), Material = METAL, Reflectance = 0.3}, CF(0, -0.3, -2.1))
	piece(b, "RightHand", {Shape = CYL, Size = V(0.12, 0.6, 0.6), Color = GOLD, Material = METAL}, CF(0, -0.3, -0.35) * ANG(0, PI / 2, 0))
	piece(b, "RightHand", {Size = V(0.2, 0.2, 0.9), Color = rgb(30, 30, 36), Material = FABRIC}, CF(0, -0.3, 0.15))
end
GEAR.cowboyhat = function(b)
	local c = rgb(130, 86, 50)
	piece(b, "Head", {Shape = CYL, Size = V(0.12, 2.5, 2.5), Color = c, Material = FABRIC}, CF(0, 0.55, 0) * ANG(0, 0, PI / 2))
	for s = -1, 1, 2 do
		piece(b, "Head", {Size = V(0.5, 0.12, 2.2), Color = c, Material = FABRIC}, CF(s * 1.1, 0.75, 0) * ANG(0, 0, s * 0.6))
	end
	piece(b, "Head", {Size = V(1.25, 0.8, 1.35), Color = c, Material = FABRIC}, CF(0, 0.95, 0))
	piece(b, "Head", {Size = V(1.28, 0.18, 1.38), Color = rgb(60, 36, 20), Material = FABRIC}, CF(0, 0.7, 0))
end
GEAR.lasso = function(b)
	for k = 0, 7 do
		local a = k / 8 * PI * 2
		piece(b, "LowerTorso", {Size = V(0.14, 0.14, 0.42), Color = rgb(190, 160, 110), Material = FABRIC}, CF(1.15 + math.cos(a) * 0.45, -0.3 + math.sin(a) * 0.45, 0) * ANG(0, 0, a))
	end
end
GEAR.supermask = function(b)
	piece(b, "Head", {Size = V(1.24, 0.3, 0.1), Color = rgb(30, 30, 40)}, CF(0, 0.15, -0.6))
end
GEAR.antenna = function(b)
	for s = -1, 1, 2 do
		piece(b, "Head", {Size = V(0.08, 0.9, 0.08), Color = rgb(90, 200, 90)}, CF(s * 0.3, 0.95, 0) * ANG(0, 0, -s * 0.3))
		local tip = piece(b, "Head", {Shape = BALL, Size = V(0.3, 0.3, 0.3), Color = rgb(180, 255, 120), Material = NEON}, CF(s * 0.45, 1.38, 0))
		if s == 1 then
			light(tip, 6, 1, rgb(180, 255, 120))
		end
	end
	for s = -1, 1, 2 do
		piece(b, "Head", {Shape = BALL, Size = V(0.42, 0.55, 0.12), Color = rgb(10, 10, 14)}, CF(s * 0.26, 0.15, -0.58) * ANG(0, 0, s * 0.4))
	end
end
GEAR.santahat = function(b)
	piece(b, "Head", {Shape = CYL, Size = V(0.35, 1.4, 1.4), Color = WHITE, Material = FABRIC}, CF(0, 0.55, 0) * ANG(0, 0, PI / 2))
	for k = 0, 3 do
		piece(b, "Head", {Shape = CYL, Size = V(0.35, 1.2 - k * 0.25, 1.2 - k * 0.25), Color = rgb(200, 30, 40), Material = FABRIC}, CF(0.1 * k, 0.85 + k * 0.3, 0.05 * k) * ANG(0, 0, PI / 2 - k * 0.15))
	end
	piece(b, "Head", {Shape = BALL, Size = V(0.45, 0.45, 0.45), Color = WHITE, Material = FABRIC}, CF(0.45, 1.95, 0.2))
end
GEAR.giftsack = function(b)
	local s = piece(b, "UpperTorso", {Shape = BALL, Size = V(1.8, 1.9, 1.5), Color = rgb(140, 100, 60), Material = FABRIC}, CF(0.2, 0, 1))
	for k = 0, 2 do
		piece(b, "UpperTorso", {Size = V(0.6, 0.6, 0.6), Color = ({rgb(220, 40, 40), rgb(40, 160, 70), rgb(240, 200, 50)})[k + 1], Material = PLASTIC}, CF(-0.3 + k * 0.35, 0.95, 0.9) * ANG(0, k, 0.2))
	end
	sparkle(s, rgb(255, 230, 150), 4)
end

---------- Visitantes nuevos ----------
GEAR.beret = function(b, def)
	local c = def and def.hatColor or rgb(30, 28, 34)
	piece(b, "Head", {Shape = CYL, Size = V(0.32, 1.55, 1.55), Color = c, Material = FABRIC}, CF(0.12, 0.62, 0.05) * ANG(0, 0, PI / 2 - 0.22))
	piece(b, "Head", {Size = V(0.08, 0.18, 0.08), Color = c}, CF(0.2, 0.84, 0.05))
end
GEAR.stripes = function(b, def)
	local c = def and def.stripe or BLACK
	for k = 0, 3 do
		piece(b, "UpperTorso", {Name = "Raya", Size = V(1.97, 0.16, 1.03), Color = c, Material = FABRIC}, CF(0, 0.55 - k * 0.38, 0))
	end
	for _, arm in {"LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm"} do
		for k = 0, 1 do
			piece(b, arm, {Name = "Raya", Size = V(1.03, 0.14, 1.03), Color = c, Material = FABRIC}, CF(0, 0.25 - k * 0.42, 0))
		end
	end
end
GEAR.backcap = function(b, def)
	local c = def and def.capColor or rgb(30, 30, 40)
	piece(b, "Head", {Shape = BALL, Size = V(1.32, 0.9, 1.32), Color = c, Material = FABRIC}, CF(0, 0.4, 0.03))
	piece(b, "Head", {Size = V(0.9, 0.08, 0.65), Color = c:Lerp(BLACK, 0.2), Material = FABRIC}, CF(0, 0.32, 0.8))
	piece(b, "Head", {Size = V(0.4, 0.12, 0.05), Color = WHITE}, CF(0, 0.45, 0.65))
end
GEAR.skateboard = function(b)
	local deck = rgb(225, 70, 50)
	local s = piece(b, "LeftHand", {Name = "Skate", Size = V(0.14, 2.5, 0.85), Color = deck, Material = WOOD}, CF(-0.28, -0.45, 0))
	piece(b, "LeftHand", {Size = V(0.04, 2.3, 0.75), Color = rgb(30, 30, 34), Material = M.Sand}, CF(-0.2, -0.45, 0))
	piece(b, "LeftHand", {Size = V(0.05, 0.5, 0.5), Color = rgb(255, 220, 60)}, CF(-0.36, -0.45, 0) * ANG(PI / 4, 0, 0))
	for _, y in {-1.45, 0.55} do
		piece(b, "LeftHand", {Size = V(0.14, 0.14, 0.6), Color = STEEL, Material = METAL}, CF(-0.42, y, 0))
		for zs = -1, 1, 2 do
			piece(b, "LeftHand", {Shape = CYL, Size = V(0.16, 0.28, 0.28), Color = rgb(250, 240, 200)}, CF(-0.48, y, zs * 0.32))
		end
	end
	return s
end
GEAR.mailbag = function(b, def)
	local c = def and def.pack or rgb(130, 92, 54)
	piece(b, "UpperTorso", {Size = V(0.22, 2.3, 0.08), Color = c:Lerp(BLACK, 0.25), Material = FABRIC}, CF(0, -0.05, -0.54) * ANG(0, 0, 0.62))
	piece(b, "UpperTorso", {Size = V(0.22, 2.3, 0.08), Color = c:Lerp(BLACK, 0.25), Material = FABRIC}, CF(0, -0.05, 0.54) * ANG(0, 0, 0.62))
	local bag = piece(b, "LowerTorso", {Name = "Bolsa", Size = V(0.95, 1.0, 0.45), Color = c, Material = M.Leather or FABRIC}, CF(0.62, -0.35, 0.75))
	piece(b, "LowerTorso", {Size = V(1, 0.45, 0.5), Color = c:Lerp(BLACK, 0.15), Material = M.Leather or FABRIC}, CF(0.62, 0.02, 0.76))
	piece(b, "LowerTorso", {Size = V(0.2, 0.15, 0.06), Color = GOLD, Material = METAL}, CF(0.62, -0.18, 1.02))
	for k = 0, 2 do
		piece(b, "LowerTorso", {Size = V(0.55, 0.4, 0.05), Color = ({WHITE, rgb(250, 235, 200), rgb(220, 235, 255)})[k + 1]}, CF(0.5 + k * 0.12, 0.32 - k * 0.04, 0.68 + k * 0.07) * ANG(0, 0, (k - 1) * 0.15))
	end
	return bag
end
GEAR.palette = function(b)
	local off = CF(0, -0.05, -0.7)
	local p = piece(b, "LeftHand", {Name = "Paleta", Shape = CYL, Size = V(0.08, 1.3, 1.3), Color = rgb(200, 160, 110), Material = WOOD}, off * ANG(0, 0, PI / 2))
	for k = 0, 4 do
		local a = k / 5 * PI * 1.4 - 0.2
		piece(b, "LeftHand", {Shape = BALL, Size = V(0.24, 0.12, 0.24), Color = ({rgb(230, 40, 50), rgb(255, 210, 40), rgb(40, 110, 230), rgb(60, 190, 90), WHITE})[k + 1]}, off * CF(math.cos(a) * 0.4, 0.06, math.sin(a) * 0.4))
	end
	return p
end
GEAR.brush = function(b)
	shaft(b, 1.7, 0.4, 0.09, rgb(40, 40, 46), PLASTIC)
	piece(b, "RightHand", {Shape = CYL, Size = V(0.22, 0.13, 0.13), Color = STEEL, Material = METAL}, tip(1.32) * ANG(0, PI / 2, 0))
	piece(b, "RightHand", {Size = V(0.14, 0.1, 0.26), Color = rgb(230, 40, 50)}, tip(1.52))
end
GEAR.tutu = function(b, def)
	local c = def and def.tutu or rgb(255, 160, 205)
	for k = 0, 2 do
		piece(b, "LowerTorso", {Name = "Tutu", Shape = CYL, Size = V(0.16, 2.7 - k * 0.3, 2.7 - k * 0.3), Color = c:Lerp(WHITE, k * 0.22), Material = FABRIC}, CF(0, -0.28 + k * 0.1, 0) * ANG(0, 0, PI / 2))
	end
end
GEAR.wand = function(b)
	shaft(b, 1.5, 0.3, 0.1, BLACK, PLASTIC)
	local t = piece(b, "RightHand", {Shape = CYL, Size = V(0.25, 0.12, 0.12), Color = WHITE}, tip(1.12) * ANG(0, PI / 2, 0))
	sparkle(t, rgb(255, 240, 160), 6)
end
GEAR.hornedhelm = function(b)
	local brass = rgb(176, 124, 56)
	piece(b, "Head", {Shape = BALL, Size = V(1.45, 1.25, 1.45), Color = STEEL, Material = METAL, Reflectance = 0.15}, CF(0, 0.42, 0.04))
	piece(b, "Head", {Shape = CYL, Size = V(0.2, 1.47, 1.47), Color = brass, Material = METAL}, CF(0, 0.25, 0.04) * ANG(0, 0, PI / 2))
	piece(b, "Head", {Size = V(0.14, 1.1, 0.1), Color = brass, Material = METAL}, CF(0, 0.6, -0.7) * ANG(-0.25, 0, 0))
	for s = -1, 1, 2 do
		for k = 0, 2 do
			local w = 0.4 - k * 0.1
			piece(b, "Head", {Name = "Cuerno", Size = V(w, 0.45, w), Color = rgb(240, 230, 200):Lerp(rgb(120, 100, 80), k * 0.15)}, CF(s * (0.72 + k * 0.2), 0.55 + k * 0.32, 0.05) * ANG(0, 0, -s * (0.9 - k * 0.45)))
		end
	end
end
GEAR.fangs = function(b)
	for s = -1, 1, 2 do
		piece(b, "Head", {Name = "Colmillo", Size = V(0.07, 0.12, 0.04), Color = WHITE}, CF(s * 0.08, -0.38, -0.61))
	end
end
GEAR.vampcollar = function(b, def)
	local c = def and def.cape or rgb(20, 12, 20)
	for s = -1, 1, 2 do
		piece(b, "UpperTorso", {Name = "Cuello", Size = V(0.85, 1.1, 0.1), Color = c, Material = FABRIC}, CF(s * 0.6, 1.2, 0.38) * ANG(-0.3, s * 0.55, 0))
		piece(b, "UpperTorso", {Name = "Cuello", Size = V(0.75, 0.95, 0.06), Color = rgb(170, 20, 40), Material = FABRIC}, CF(s * 0.58, 1.18, 0.31) * ANG(-0.3, s * 0.55, 0))
	end
	local g = piece(b, "UpperTorso", {Shape = BALL, Size = V(0.3, 0.3, 0.3), Color = rgb(200, 20, 40), Material = NEON}, CF(0, 0.7, -0.56))
	light(g, 5, 0.8, rgb(255, 40, 60))
end
GEAR.wildhair = function(b, def)
	local c = def and def.hair or rgb(235, 235, 240)
	piece(b, "Head", {Name = "Pelo", Shape = BALL, Size = V(1.35, 1.0, 1.4), Color = c, Material = PLASTIC}, CF(0, 0.38, 0.12))
	for k = 0, 13 do
		local a = k / 14 * PI * 2
		if math.sin(a) > -0.55 then -- (ninguna púa delante de la cara)
			piece(b, "Head", {Name = "Pelo", Size = V(0.3, 0.8, 0.3), Color = c, Material = PLASTIC}, CF(math.cos(a) * 0.55, 0.5 + (k % 2) * 0.12, 0.12 + math.sin(a) * 0.55) * ANG(math.sin(a) * 0.95, 0, -math.cos(a) * 0.95))
		end
	end
end
GEAR.flask = function(b)
	local f = piece(b, "RightHand", {Name = "Matraz", Shape = BALL, Size = V(0.7, 0.7, 0.7), Color = rgb(120, 255, 120), Material = NEON, Transparency = 0.1}, CF(0, -0.3, -0.6))
	piece(b, "RightHand", {Shape = BALL, Size = V(0.82, 0.82, 0.82), Color = rgb(210, 255, 225), Material = M.Glass, Transparency = 0.6}, CF(0, -0.3, -0.6))
	piece(b, "RightHand", {Shape = CYL, Size = V(0.5, 0.26, 0.26), Color = rgb(210, 255, 225), Material = M.Glass, Transparency = 0.45}, CF(0, 0.12, -0.6) * ANG(0, 0, PI / 2))
	piece(b, "RightHand", {Shape = CYL, Size = V(0.16, 0.22, 0.22), Color = WOODC, Material = WOOD}, CF(0, 0.42, -0.6) * ANG(0, 0, PI / 2))
	light(f, 10, 1.6, rgb(120, 255, 120))
	sparkle(f, rgb(170, 255, 170), 6)
end
GEAR.headless = function(b)
	local h = b:FindFirstChild("Head")
	if h then
		h.Transparency = 1
	end
	piece(b, "UpperTorso", {Name = "Gorguera", Size = V(1.25, 0.32, 1.1), Color = rgb(30, 24, 34), Material = FABRIC}, CF(0, 0.92, 0))
	local stump = piece(b, "UpperTorso", {Name = "Cuello", Shape = CYL, Size = V(0.14, 0.7, 0.7), Color = rgb(70, 10, 24)}, CF(0, 1.1, 0) * ANG(0, 0, PI / 2))
	fire(piece(b, "UpperTorso", {Size = V(0.3, 0.3, 0.3), Transparency = 1}, CF(0, 1.35, 0)), 2.6, rgb(130, 70, 255))
	light(stump, 12, 1.8, rgb(150, 90, 255))
end
GEAR.pumpkinhand = function(b)
	local off = CF(0, -0.15, -0.75)
	local p = piece(b, "LeftHand", {Name = "Calabaza", Shape = BALL, Size = V(1.35, 1.15, 1.35), Color = rgb(255, 120, 20), Material = PLASTIC}, off)
	for k = -1, 1, 2 do
		piece(b, "LeftHand", {Shape = BALL, Size = V(0.6, 1.12, 1.25), Color = rgb(230, 100, 15), Material = PLASTIC}, off * CF(k * 0.38, 0, 0))
	end
	for s = -1, 1, 2 do
		piece(b, "LeftHand", {Size = V(0.24, 0.24, 0.08), Color = rgb(255, 230, 90), Material = NEON}, off * CF(s * 0.25, 0.15, -0.66) * ANG(0, 0, PI / 4))
	end
	piece(b, "LeftHand", {Size = V(0.6, 0.14, 0.08), Color = rgb(255, 230, 90), Material = NEON}, off * CF(0, -0.22, -0.66))
	piece(b, "LeftHand", {Size = V(0.18, 0.4, 0.18), Color = rgb(70, 110, 40)}, off * CF(0, 0.7, 0) * ANG(0, 0, 0.3))
	light(p, 10, 1.4, rgb(255, 160, 50))
	return p
end

---------- Disfraces de los niños y el viajero cósmico ----------
-- Trick-or-Treater: disfraz de calabaza (barriga redonda con gajos y cara de jack-o'-lantern, cuello de hojas),
-- gorro verde con tallo y su cubo-calabaza lleno de caramelos
GEAR.stemhat = function(b)
	local g = rgb(70, 150, 60)
	piece(b, "Head", {Name = "Gorro", Shape = BALL, Size = V(1.34, 0.9, 1.34), Color = g, Material = FABRIC}, CF(0, 0.42, 0.03))
	piece(b, "Head", {Name = "Gorro", Shape = CYL, Size = V(0.18, 1.36, 1.36), Color = g:Lerp(BLACK, 0.2), Material = FABRIC}, CF(0, 0.2, 0.03) * ANG(0, 0, PI / 2))
	piece(b, "Head", {Name = "Tallo", Shape = CYL, Size = V(0.5, 0.2, 0.2), Color = rgb(96, 70, 34)}, CF(0.05, 0.98, 0) * ANG(0, 0, PI / 2 - 0.35))
	piece(b, "Head", {Name = "Hoja", Size = V(0.5, 0.05, 0.32), Color = rgb(90, 180, 70)}, CF(0.3, 0.92, 0.05) * ANG(0, 0.4, -0.35))
end
GEAR.pumpkinsuit = function(b)
	local O, O2 = rgb(255, 138, 30), rgb(226, 100, 18)
	local at = CF(0, -0.35, 0)
	piece(b, "UpperTorso", {Name = "Disfraz", Shape = BALL, Size = V(2.55, 2.25, 1.85), Color = O, Material = FABRIC}, at)
	for k = -2, 2 do
		piece(b, "UpperTorso", {Name = "Gajo", Shape = BALL, Size = V(0.34, 2.28, 1.88), Color = O2, Material = FABRIC}, at * CF(k * 0.48, 0, 0) * ANG(0, 0, -k * 0.1))
	end
	-- cara de calabaza en la barriga (tela negra cosida)
	local face = at * CF(0, 0, -0.9)
	for s = -1, 1, 2 do
		piece(b, "UpperTorso", {Name = "Cara", Size = V(0.32, 0.32, 0.06), Color = rgb(30, 20, 16), Material = FABRIC}, face * CF(s * 0.38, 0.3, 0.02) * ANG(0, 0, PI / 4))
	end
	piece(b, "UpperTorso", {Name = "Cara", Size = V(0.18, 0.18, 0.06), Color = rgb(30, 20, 16), Material = FABRIC}, face * CF(0, 0.02, 0.01) * ANG(0, 0, PI / 4))
	piece(b, "UpperTorso", {Name = "Cara", Size = V(0.9, 0.16, 0.06), Color = rgb(30, 20, 16), Material = FABRIC}, face * CF(0, -0.32, 0.04))
	for s = -1, 1, 2 do
		piece(b, "UpperTorso", {Name = "Cara", Size = V(0.16, 0.16, 0.06), Color = rgb(30, 20, 16), Material = FABRIC}, face * CF(s * 0.5, -0.22, 0.05) * ANG(0, 0, PI / 4))
	end
	-- cuello de hojas
	for k = 0, 7 do
		local a = k / 8 * PI * 2
		piece(b, "UpperTorso", {Name = "Hoja", Size = V(0.5, 0.08, 0.38), Color = k % 2 == 0 and rgb(80, 170, 64) or rgb(60, 140, 50), Material = FABRIC},
			CF(math.sin(a) * 0.62, 0.84, math.cos(a) * 0.48) * ANG(0, a, 0) * ANG(-0.35, 0, 0))
	end
	-- mangas y medias a juego
	for _, n in {"LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm"} do
		piece(b, n, {Name = "Manga", Size = V(1.04, 1.1, 1.04), Color = n:find("Lower") and rgb(70, 150, 60) or O, Material = FABRIC}, CF(0, 0.02, 0))
	end
	for _, n in {"LeftLowerLeg", "RightLowerLeg"} do
		for k = 0, 2 do
			piece(b, n, {Name = "Raya", Size = V(1.02, 0.18, 1.0), Color = k % 2 == 0 and BLACK or O, Material = FABRIC}, CF(0, 0.3 - k * 0.3, 0))
		end
	end
end
GEAR.candybucket = function(b)
	local off = CF(0, -0.85, -0.25)
	local pail = piece(b, "LeftHand", {Name = "Cubo", Shape = CYL, Size = V(0.95, 1.05, 1.05), Color = rgb(255, 132, 26)}, off * ANG(0, 0, PI / 2))
	piece(b, "LeftHand", {Name = "Cubo", Shape = CYL, Size = V(0.1, 1.12, 1.12), Color = rgb(220, 96, 14)}, off * CF(0, 0.46, 0) * ANG(0, 0, PI / 2))
	for s = -1, 1, 2 do
		piece(b, "LeftHand", {Size = V(0.2, 0.2, 0.06), Color = rgb(255, 225, 90), Material = NEON}, off * CF(s * 0.2, 0.08, -0.52) * ANG(0, 0, PI / 4))
	end
	piece(b, "LeftHand", {Size = V(0.46, 0.1, 0.06), Color = rgb(255, 225, 90), Material = NEON}, off * CF(0, -0.17, -0.52))
	for k = -2, 2 do
		local a = k / 2 * 1.2
		piece(b, "LeftHand", {Name = "Asa", Size = V(0.07, 0.3, 0.07), Color = BLACK}, off * CF(math.sin(a) * 0.48, 0.55 + math.cos(a) * 0.4, 0) * ANG(0, 0, -a))
	end
	local cols = {rgb(255, 60, 120), rgb(90, 220, 255), rgb(255, 230, 60), rgb(160, 90, 255), rgb(110, 230, 90)}
	for k = 0, 4 do
		piece(b, "LeftHand", {Name = "Caramelo", Shape = BALL, Size = V(0.26, 0.22, 0.26), Color = cols[k + 1]}, off * CF(math.cos(k) * 0.26, 0.5, math.sin(k) * 0.26))
	end
	piece(b, "LeftHand", {Name = "Piruleta", Size = V(0.05, 0.5, 0.05), Color = WHITE}, off * CF(0.1, 0.75, 0))
	piece(b, "LeftHand", {Name = "Piruleta", Shape = CYL, Size = V(0.06, 0.34, 0.34), Color = rgb(255, 80, 150)}, off * CF(0.1, 1.05, 0) * ANG(0, PI / 2, 0))
	light(pail, 6, 0.8, rgb(255, 170, 60))
	return pail
end

-- Sheet Ghost Kid: una sábana de verdad (cúpula en la cabeza, caída que se abre, bajo rasgado, mangas que cuelgan y
-- pliegues), con los agujeros de los ojos y la boca; asoman las zapatillas
GEAR.ghostsheet = function(b)
	local W, F = rgb(246, 246, 248), rgb(222, 222, 230)
	piece(b, "Head", {Name = "Sabana", Shape = BALL, Size = V(1.62, 1.6, 1.62), Color = W, Material = FABRIC}, CF(0, 0.18, 0))
	for s = -1, 1, 2 do
		piece(b, "Head", {Name = "Agujero", Shape = BALL, Size = V(0.3, 0.42, 0.12), Color = rgb(14, 12, 18)}, CF(s * 0.27, 0.22, -0.76) * ANG(0, -s * 0.3, 0))
	end
	piece(b, "Head", {Name = "Agujero", Shape = BALL, Size = V(0.22, 0.16, 0.1), Color = rgb(14, 12, 18)}, CF(0, -0.2, -0.78))
	-- cuerpo: tramos cada vez más anchos hasta las rodillas
	piece(b, "UpperTorso", {Name = "Sabana", Size = V(2.3, 1.9, 1.35), Color = W, Material = FABRIC}, CF(0, 0, 0))
	piece(b, "LowerTorso", {Name = "Sabana", Size = V(2.6, 1.3, 1.6), Color = W, Material = FABRIC}, CF(0, -0.45, 0))
	piece(b, "LowerTorso", {Name = "Sabana", Size = V(2.9, 0.9, 1.8), Color = W, Material = FABRIC}, CF(0, -1.4, 0.02))
	-- pliegues
	for k = -2, 2 do
		piece(b, "LowerTorso", {Name = "Pliegue", Size = V(0.12, 2.0, 0.06), Color = F, Material = FABRIC}, CF(k * 0.55, -0.9, -0.9 - math.abs(k) * 0.02) * ANG(0, 0, k * 0.06))
	end
	-- bajo rasgado (picos)
	for k = 0, 11 do
		local a = k / 12 * PI * 2
		local cf = CF(math.sin(a) * 1.35, -1.95, math.cos(a) * 0.82) * ANG(0, a + PI, 0)
		piece(b, "LowerTorso", {Name = "Pico", Size = V(0.12, 0.36, 0.36), Color = k % 2 == 0 and W or F, Material = FABRIC}, cf * ANG(PI / 4, 0, 0))
	end
	-- mangas que cuelgan de los brazos
	for s = -1, 1, 2 do
		local side = s < 0 and "Left" or "Right"
		piece(b, side .. "UpperArm", {Name = "Manga", Size = V(1.14, 1.3, 1.14), Color = W, Material = FABRIC}, CF(0, 0, 0))
		piece(b, side .. "LowerArm", {Name = "Manga", Size = V(1.2, 1.2, 1.2), Color = W, Material = FABRIC}, CF(0, -0.05, 0))
		piece(b, side .. "LowerArm", {Name = "Pico", Size = V(0.9, 0.42, 0.12), Color = F, Material = FABRIC}, CF(s * 0.1, -0.7, 0) * ANG(0, 0, s * 0.2))
	end
end

-- Cosmic Wanderer: capa de noche estrellada con estrellas que brillan, ojos de luz, una constelación en el pecho y
-- polvo de nebulosa
GEAR.cosmos = function(b, def)
	local rng = Random.new(5)
	local stars = {rgb(255, 255, 255), rgb(150, 220, 255), rgb(220, 160, 255), rgb(255, 230, 150)}
	for _, n in {"UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftUpperLeg", "RightUpperLeg"} do
		local p = b:FindFirstChild(n)
		if p then
			for _ = 1, n:find("Torso") and 7 or 3 do
				local face = rng:NextInteger(0, 1) == 0 and -1 or 1
				piece(b, n, {Name = "Estrella", Size = V(0.08, 0.08, 0.04), Color = stars[rng:NextInteger(1, #stars)], Material = NEON},
					CF(rng:NextNumber(-0.42, 0.42) * p.Size.X, rng:NextNumber(-0.42, 0.42) * p.Size.Y, face * (p.Size.Z / 2 + 0.02)) * ANG(0, 0, PI / 4))
			end
		end
	end
	-- constelación en el pecho: cinco estrellas unidas
	local pts = {V(-0.5, 0.45), V(-0.15, 0.2), V(0.2, 0.35), V(0.45, 0.0), V(0.1, -0.35)}
	for k, p in pts do
		piece(b, "UpperTorso", {Name = "Constelacion", Shape = BALL, Size = V(0.14, 0.14, 0.06), Color = WHITE, Material = NEON}, CF(p.X, p.Y, -0.54))
		local q = pts[k + 1]
		if q then
			local d = (q - p)
			piece(b, "UpperTorso", {Name = "Constelacion", Size = V(d.Magnitude, 0.03, 0.03), Color = rgb(150, 200, 255), Material = NEON, Transparency = 0.3},
				CF((p.X + q.X) / 2, (p.Y + q.Y) / 2, -0.53) * ANG(0, 0, math.atan2(d.Y, d.X)))
		end
	end
	-- capucha con el borde de luz y los ojos brillando dentro
	local hood = def and def.cape or rgb(60, 30, 140)
	piece(b, "Head", {Name = "Capucha", Shape = BALL, Size = V(1.5, 1.45, 1.5), Color = hood, Material = FABRIC}, CF(0, 0.2, 0.12))
	for k = 0, 13 do
		local a = k / 14 * PI * 2
		piece(b, "Head", {Name = "Capucha", Size = V(0.3, 0.07, 0.07), Color = rgb(150, 200, 255), Material = NEON}, CF(math.cos(a) * 0.66, 0.08 + math.sin(a) * 0.7, -0.64) * ANG(0, 0, a + PI / 2))
	end
	piece(b, "Head", {Name = "Sombra", Size = V(1.05, 1.05, 0.05), Color = rgb(10, 6, 24)}, CF(0, 0.06, -0.6))
	for s = -1, 1, 2 do
		local e = piece(b, "Head", {Name = "OjoLuz", Size = V(0.22, 0.12, 0.06), Color = rgb(180, 240, 255), Material = NEON}, CF(s * 0.22, 0.1, -0.65))
		if s == 1 then
			light(e, 7, 1.2, rgb(150, 210, 255))
		end
	end
	local torso = b:FindFirstChild("UpperTorso")
	if torso then
		local e = Instance.new("ParticleEmitter")
		e.Name = "Nebulosa"
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(rgb(170, 120, 255), rgb(110, 210, 255))
		e.LightEmission, e.Rate = 1, 10
		e.Lifetime, e.Speed = NumberRange.new(1.5, 2.5), NumberRange.new(0.2, 0.8)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new(0.25, 0)
		e.Parent = torso
	end
end

---------- El Rey Calabaza (visitante secreto) ----------
-- El mismo ADN que el susto Rey Calabaza: cabeza de calabaza tallada que arde por dentro, corona de oro, casaca real
-- morada con ribetes de oro, faja carmesí y capa con armiño. Su magia es fuego de almas verde (corona, cetro, orbe).
local SOUL, SOUL2 = rgb(80, 255, 150), rgb(200, 255, 220)
local PUMPKIN, PUMPKIN2, PUMPKIN3 = rgb(255, 132, 26), rgb(224, 92, 14), rgb(150, 52, 8)
local CARVE, CARVE_RIM = rgb(255, 214, 90), rgb(60, 18, 4)
local ROYAL, ROYAL2 = rgb(96, 40, 160), rgb(62, 22, 112)
local KGOLD = rgb(255, 196, 64)
local CRIMSON = rgb(176, 18, 40)

local function souls(p, rate, size)
	if p then
		local e = Instance.new("ParticleEmitter")
		e.Name = "Almas"
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Color = ColorSequence.new(SOUL, SOUL2)
		e.LightEmission, e.Rate = 1, rate
		e.Lifetime, e.Speed = NumberRange.new(0.8, 1.5), NumberRange.new(1, 2.5)
		e.Acceleration = V(0, 2, 0)
		e.SpreadAngle = Vector2.new(15, 15)
		e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0)})
		e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)})
		e.RotSpeed = NumberRange.new(-90, 90)
		e.Parent = p
		return e
	end
end

-- Triángulo plano de cara a -Z (dos cuñas): base w abajo, vértice arriba, alto h y grosor d
local function tri(bot, attach, w, h, d, props, cf)
	for s = -1, 1, 2 do
		local p = table.clone(props)
		p.Size = V(d, h, w / 2)
		piece(bot, attach, p, cf * CF(s * w / 4, 0, 0) * ANG(0, -s * PI / 2, 0), "WedgePart")
	end
end

-- La calabaza es un elipsoide (radio RX de lado, RY de alto): lo tallado se pega a su superficie, girado con ella
local RX, RY = 1.25, 1.0
local HEAD_AT = CF(0, 0.32, 0)
local function onFace(x, y, out)
	local r = RX * math.sqrt(math.max(0.05, 1 - (y / RY) ^ 2))
	local phi = x / r
	local tilt = math.asin(math.clamp(y / RY, -1, 1)) * 0.75
	return HEAD_AT * CF(r * math.sin(phi), y, -r * math.cos(phi)) * ANG(0, -phi, 0) * ANG(tilt, 0, 0) * CF(0, 0, -(out or 0))
end

GEAR.pumpkinking = function(b)
	local head = b:FindFirstChild("Head")
	if head then
		head.Transparency = 1
	end
	-- calabaza: el cuerpo y ocho gajos (franjas un poco salientes y más oscuras)
	local p = piece(b, "Head", {Name = "Calabaza", Shape = BALL, Size = V(RX * 2, RY * 2, RX * 2), Color = PUMPKIN}, HEAD_AT)
	for k = 0, 3 do
		piece(b, "Head", {Name = "Gajo", Shape = BALL, Size = V(0.46, RY * 2 + 0.04, RX * 2 + 0.06), Color = PUMPKIN2}, HEAD_AT * ANG(0, k * PI / 4, 0))
	end
	piece(b, "Head", {Name = "Hoyo", Shape = CYL, Size = V(0.1, 0.9, 0.9), Color = PUMPKIN3}, HEAD_AT * CF(0, RY - 0.03, 0) * ANG(0, 0, PI / 2))
	-- tallado: cejas de enfado, ojos triangulares, nariz y una sonrisa de dientes de sierra; todo arde de oro por dentro
	local glow = {Name = "Tallado", Color = CARVE, Material = NEON}
	local rim = {Name = "Borde", Color = CARVE_RIM}
	for s = -1, 1, 2 do
		local eye = onFace(s * 0.52, 0.27, 0.02) * ANG(0, 0, -s * 0.3)
		tri(b, "Head", 0.62, 0.48, 0.1, rim, eye * CF(0, 0, 0.02))
		tri(b, "Head", 0.48, 0.36, 0.1, glow, eye * CF(0, -0.02, -0.02))
		piece(b, "Head", {Name = "Ceja", Size = V(0.52, 0.11, 0.14), Color = PUMPKIN3}, onFace(s * 0.55, 0.6, 0.04) * ANG(0, 0, s * 0.42))
	end
	tri(b, "Head", 0.26, 0.22, 0.1, rim, onFace(0, -0.02, 0.02) * ANG(0, 0, PI))
	tri(b, "Head", 0.17, 0.14, 0.1, glow, onFace(0, -0.02, 0.0) * ANG(0, 0, PI))
	-- boca: tres tramos que suben hacia las comisuras, con su borde oscuro y dientes de calabaza
	for k = -2, 2 do
		local x, y, r = k * 0.3, -0.5 + math.abs(k) ^ 1.6 * 0.07, -k * 0.2
		piece(b, "Head", {Name = "Borde", Size = V(0.36, 0.34, 0.1), Color = CARVE_RIM}, onFace(x, y, 0.02) * ANG(0, 0, r))
		piece(b, "Head", {Name = "Tallado", Size = V(0.32, 0.24, 0.1), Color = CARVE, Material = NEON}, onFace(x, y, 0.04) * ANG(0, 0, r))
	end
	-- dientes: dos arriba y uno abajo, del color de la calabaza, mordiendo la sonrisa
	for _, t in {{-0.18, -0.4, 0}, {0.18, -0.4, 0}, {0, -0.6, PI}} do
		tri(b, "Head", 0.16, 0.13, 0.1, {Name = "Diente", Color = PUMPKIN}, onFace(t[1], t[2], 0.07) * ANG(0, 0, t[3] + PI))
	end
	light(p, 16, 2.4, rgb(255, 180, 70))
	-- tallo retorcido, zarcillo y una hoja (asoman por encima de la corona)
	local stem = HEAD_AT * CF(0, RY + 0.12, 0)
	piece(b, "Head", {Name = "Tallo", Shape = CYL, Size = V(0.5, 0.32, 0.32), Color = rgb(72, 96, 36)}, stem * CF(0, 0.1, 0) * ANG(0, 0, PI / 2))
	piece(b, "Head", {Name = "Tallo", Shape = CYL, Size = V(0.42, 0.26, 0.26), Color = rgb(84, 110, 40)}, stem * CF(0.08, 0.42, 0) * ANG(0, 0, PI / 2 - 0.5))
	for k = 0, 5 do
		local a = k / 6 * PI * 1.6
		piece(b, "Head", {Name = "Zarcillo", Shape = CYL, Size = V(0.18, 0.07, 0.07), Color = rgb(96, 140, 48)}, stem * CF(-0.25 - math.cos(a) * 0.18, 0.2 + math.sin(a) * 0.18, 0.1) * ANG(0, 0, a))
	end
	-- corona de oro: aro, terciopelo morado dentro, puntas con gemas de alma y rubíes, y fuego de almas encima
	local crown = HEAD_AT * CF(0, RY - 0.14, 0) * ANG(-0.1, 0, 0.06)
	piece(b, "Head", {Name = "Terciopelo", Shape = BALL, Size = V(1.62, 0.8, 1.62), Color = ROYAL, Material = FABRIC}, crown * CF(0, 0.22, 0))
	piece(b, "Head", {Name = "Corona", Shape = CYL, Size = V(0.44, 1.82, 1.82), Color = KGOLD, Material = METAL, Reflectance = 0.25}, crown * ANG(0, 0, PI / 2))
	piece(b, "Head", {Name = "Corona", Shape = CYL, Size = V(0.1, 1.9, 1.9), Color = rgb(255, 230, 140), Material = METAL, Reflectance = 0.3}, crown * CF(0, -0.2, 0) * ANG(0, 0, PI / 2))
	for k = 0, 7 do
		local dir = crown * ANG(0, k / 8 * PI * 2, 0)
		local tall = k % 2 == 0
		local h = tall and 0.86 or 0.5
		tri(b, "Head", 0.46, h, 0.12, {Name = "Punta", Color = KGOLD, Material = METAL, Reflectance = 0.25}, dir * CF(0, 0.2 + h / 2, -0.88) * ANG(-0.12, 0, 0))
		piece(b, "Head", {Name = tall and "GemaAlma" or "Rubi", Shape = BALL, Size = V(0.2, 0.2, 0.2), Color = tall and SOUL or rgb(255, 40, 70), Material = NEON},
			dir * CF(0, 0.24 + h, -0.9))
		piece(b, "Head", {Name = "Engarce", Shape = BALL, Size = V(0.16, 0.16, 0.16), Color = k % 2 == 0 and rgb(255, 40, 70) or SOUL, Material = NEON}, dir * CF(0, 0, -0.93))
	end
	local gem = piece(b, "Head", {Name = "Esmeralda", Size = V(0.34, 0.34, 0.14), Color = SOUL, Material = NEON}, crown * CF(0, 0.02, -0.96) * ANG(0, 0, PI / 4))
	light(gem, 6, 1, SOUL)
	local flame = piece(b, "Head", {Name = "Llama", Size = V(0.3, 0.3, 0.3), Transparency = 1}, crown * CF(0, 0.75, 0))
	fire(flame, 2.6, SOUL)
	souls(flame, 7, 0.8)
end

GEAR.kingrobe = function(b, def)
	local coat = def and def.shirt or ROYAL
	-- casaca morada abierta sobre un chaleco negro con botones de oro, ribetes de oro en los bordes
	piece(b, "UpperTorso", {Name = "Casaca", Size = V(2.04, 1.74, 1.1), Color = coat, Material = FABRIC}, CF(0, 0, 0))
	piece(b, "UpperTorso", {Name = "Chaleco", Size = V(0.7, 1.66, 0.04), Color = rgb(30, 18, 40), Material = FABRIC}, CF(0, -0.02, -0.56))
	for s = -1, 1, 2 do
		piece(b, "UpperTorso", {Name = "Ribete", Size = V(0.1, 1.7, 0.05), Color = KGOLD, Material = METAL}, CF(s * 0.39, 0, -0.57))
		-- solapas
		piece(b, "UpperTorso", {Name = "Solapa", Size = V(0.36, 0.62, 0.06), Color = coat:Lerp(WHITE, 0.12), Material = FABRIC}, CF(s * 0.56, 0.5, -0.57) * ANG(0, 0, s * 0.35))
	end
	for k = 0, 2 do
		piece(b, "UpperTorso", {Name = "Boton", Shape = BALL, Size = V(0.15, 0.15, 0.1), Color = KGOLD, Material = METAL, Reflectance = 0.2}, CF(0, 0.42 - k * 0.38, -0.58))
	end
	-- faja carmesí en diagonal con el medallón del rey (una calabacita de oro)
	piece(b, "UpperTorso", {Name = "Faja", Size = V(0.36, 2.3, 0.06), Color = CRIMSON, Material = FABRIC}, CF(0, 0, -0.6) * ANG(0, 0, -0.62))
	for s = -1, 1, 2 do
		piece(b, "UpperTorso", {Name = "Faja", Size = V(0.04, 2.3, 0.07), Color = KGOLD, Material = METAL}, CF(0, 0, -0.6) * ANG(0, 0, -0.62) * CF(s * 0.17, 0, 0))
	end
	piece(b, "UpperTorso", {Name = "Medalla", Shape = CYL, Size = V(0.08, 0.5, 0.5), Color = KGOLD, Material = METAL, Reflectance = 0.25}, CF(-0.18, 0.12, -0.64) * ANG(0, PI / 2, 0))
	local med = piece(b, "UpperTorso", {Name = "Medalla", Shape = BALL, Size = V(0.3, 0.26, 0.12), Color = PUMPKIN, Material = PLASTIC}, CF(-0.18, 0.12, -0.69))
	light(med, 5, 0.6, rgb(255, 170, 60))
	-- charreteras de oro con flecos
	for s = -1, 1, 2 do
		local arm = s < 0 and "LeftUpperArm" or "RightUpperArm"
		piece(b, arm, {Name = "Charretera", Shape = BALL, Size = V(1.3, 0.46, 1.24), Color = KGOLD, Material = METAL, Reflectance = 0.2}, CF(s * 0.06, 0.62, 0))
		for k = -2, 2 do
			piece(b, arm, {Name = "Fleco", Size = V(0.08, 0.34, 0.08), Color = rgb(255, 222, 120), Material = METAL}, CF(s * 0.5, 0.36, k * 0.22))
		end
		local low = s < 0 and "LeftLowerArm" or "RightLowerArm"
		piece(b, arm, {Name = "Manga", Size = V(1.04, 1.26, 1.04), Color = coat, Material = FABRIC}, CF(0, 0, 0))
		piece(b, low, {Name = "Manga", Size = V(1.04, 1.12, 1.04), Color = coat, Material = FABRIC}, CF(0, 0, 0))
		piece(b, low, {Name = "Puno", Size = V(1.1, 0.26, 1.1), Color = KGOLD, Material = METAL}, CF(0, -0.36, 0))
		piece(b, low, {Name = "Encaje", Size = V(1.16, 0.12, 1.16), Color = WHITE, Material = FABRIC}, CF(0, -0.53, 0))
		-- botas negras con vuelta de oro
		local leg = s < 0 and "LeftLowerLeg" or "RightLowerLeg"
		piece(b, leg, {Name = "Bota", Size = V(1.06, 1.1, 1.04), Color = rgb(24, 18, 28), Material = PLASTIC}, CF(0, -0.12, 0))
		piece(b, leg, {Name = "Bota", Size = V(1.12, 0.22, 1.1), Color = KGOLD, Material = METAL}, CF(0, 0.48, 0))
	end
	-- faldones de la casaca con ribete de oro, y cinturón con hebilla de calabaza
	skirt(b, coat, 1.75, true)
	for s = -1, 1, 2 do
		piece(b, "LowerTorso", {Name = "Ribete", Size = V(0.97, 0.12, 1.22), Color = KGOLD, Material = METAL}, CF(s * 0.52, -1.6, 0.05))
	end
	piece(b, "LowerTorso", {Name = "Cinturon", Size = V(2.08, 0.26, 1.14), Color = rgb(24, 16, 26), Material = PLASTIC}, CF(0, 0.08, 0))
	piece(b, "LowerTorso", {Name = "Hebilla", Shape = BALL, Size = V(0.4, 0.34, 0.16), Color = KGOLD, Material = METAL, Reflectance = 0.25}, CF(0, 0.08, -0.6))
end

GEAR.kingscepter = function(b)
	-- cetro de oro con una espiral negra y, arriba, una garra que sujeta un farol de calabaza con fuego de almas
	shaft(b, 4.2, 0.6, 0.2, KGOLD, METAL)
	for k = 0, 5 do
		piece(b, "RightHand", {Shape = CYL, Size = V(0.1, 0.25, 0.25), Color = rgb(30, 20, 34), Material = METAL}, tip(0.6 + k * 0.5) * ANG(0, PI / 2, 0) * ANG(0.5, 0, 0))
	end
	piece(b, "RightHand", {Shape = BALL, Size = V(0.4, 0.4, 0.4), Color = KGOLD, Material = METAL, Reflectance = 0.2}, tip(-0.6))
	local head = tip(3.95, 0.05)
	local lamp = piece(b, "RightHand", {Name = "Farol", Shape = BALL, Size = V(0.72, 0.62, 0.72), Color = PUMPKIN}, head)
	for s = -1, 1, 2 do
		piece(b, "RightHand", {Size = V(0.14, 0.14, 0.06), Color = CARVE, Material = NEON}, head * CF(s * 0.14, 0.07, -0.36) * ANG(0, 0, PI / 4))
	end
	piece(b, "RightHand", {Size = V(0.32, 0.08, 0.06), Color = CARVE, Material = NEON}, head * CF(0, -0.12, -0.35))
	-- copa de oro que lo sujeta por detrás (abraza la calabaza hacia la mano)
	piece(b, "RightHand", {Name = "Copa", Shape = CYL, Size = V(0.16, 0.6, 0.6), Color = KGOLD, Material = METAL, Reflectance = 0.2}, head * CF(0, 0, 0.34) * ANG(0, PI / 2, 0))
	for k = 0, 3 do
		local dir = head * ANG(0, 0, k / 4 * PI * 2 + PI / 4)
		piece(b, "RightHand", {Name = "Garra", Size = V(0.08, 0.34, 0.08), Color = KGOLD, Material = METAL}, dir * CF(0, 0.3, 0.12) * ANG(-0.35, 0, 0))
	end
	light(lamp, 10, 1.6, rgb(255, 180, 70))
	local flame = piece(b, "RightHand", {Name = "Llama", Size = V(0.2, 0.2, 0.2), Transparency = 1}, head * CF(0, 0.6, 0))
	fire(flame, 1.4, SOUL)
	souls(flame, 4, 0.5)
end

GEAR.soulorb = function(b)
	-- un orbe de almas sobre una garra de oro en la palma izquierda
	local at = CF(0, -0.15, -0.85)
	local orb = piece(b, "LeftHand", {Name = "Orbe", Shape = BALL, Size = V(0.72, 0.72, 0.72), Color = SOUL, Material = NEON, Transparency = 0.05}, at)
	piece(b, "LeftHand", {Shape = BALL, Size = V(1.0, 1.0, 1.0), Color = SOUL2, Material = M.ForceField}, at)
	piece(b, "LeftHand", {Name = "Cuna", Shape = CYL, Size = V(0.12, 0.7, 0.7), Color = KGOLD, Material = METAL}, at * CF(0, -0.4, 0) * ANG(0, 0, PI / 2))
	for k = 0, 3 do
		local dir = at * ANG(0, k / 4 * PI * 2, 0)
		piece(b, "LeftHand", {Name = "Garra", Size = V(0.09, 0.5, 0.1), Color = KGOLD, Material = METAL}, dir * CF(0, -0.18, -0.36) * ANG(0.45, 0, 0))
	end
	light(orb, 12, 2, SOUL)
	souls(orb, 10, 0.6)
	sparkle(orb, SOUL2, 8)
end

---------- Detalle (lo que llevan todos, visitantes y cazafantasmas) ----------
-- Cara de bloques (ojos con brillo, cejas, nariz, boca), orejas, cuello, pelo bajo el sombrero, camisa con costuras
-- (camiseta lisa, con franja, con dibujo o camisa abotonada), cinturón, bajos del pantalón y zapatos con suela.
-- Va antes de los complementos, que se ponen encima.
local function set(list)
	local s = {}
	for _, n in list do
		s[n] = true
	end
	return s
end
-- tapan toda la cabeza: sin cara, orejas ni pelo
local FULL_HEAD = set({"sheet", "ghostsheet", "cosmos", "pumpkinhead", "astrohelm", "helmet", "knighthelm", "blackhelm", "wingedhelm", "valkyriehelm", "championhelm", "headless", "pumpkinking"})
-- ya traen su pelo (o lo tapan)
local HAS_HAIR = set({"hair", "stemhat", "bun", "headphones", "headband", "herohair", "wildhair", "hood", "beanie", "leathercap", "firehelm", "minerhelm", "hornedhelm", "backcap"})
local COVER_CHEST = set({"sheet", "ghostsheet", "pumpkinsuit", "tabard", "apron", "astropack", "stripes", "kingrobe"})
local COVER_WAIST = set({"sheet", "ghostsheet", "pumpkinsuit", "tabard", "coat", "labcoat", "robe", "kingrobe"})
local EYES = {rgb(70, 45, 30), rgb(40, 90, 160), rgb(50, 120, 70), rgb(25, 22, 26), rgb(110, 80, 40)}
local SHOES = {
	{rgb(30, 28, 30), rgb(60, 56, 58)}, -- zapatos negros
	{rgb(96, 60, 34), rgb(50, 32, 20)}, -- marrones
	{rgb(236, 236, 240), rgb(250, 250, 252), true}, -- zapatillas blancas
	{rgb(200, 40, 50), rgb(245, 245, 245), true}, -- zapatillas rojas
	{rgb(40, 60, 120), rgb(240, 240, 240), true}, -- zapatillas azules
}
local PRINTS = {rgb(255, 140, 30), rgb(250, 250, 250), rgb(255, 220, 60), rgb(120, 230, 140), rgb(30, 28, 34)}

local function face(b, def, rng, skin)
	local head = b:FindFirstChild("Head")
	if head and head:IsA("MeshPart") then
		head.TextureID = "" -- (la cara de la textura la cambiamos por la de bloques)
	end
	local hair = def.hair or HAIRS[1]
	local iris = def.eyes or EYES[rng:NextInteger(1, #EYES)]
	local angry = def.boss
	for s = -1, 1, 2 do
		piece(b, "Head", {Name = "Ojo", Size = V(0.24, 0.28, 0.05), Color = rgb(250, 250, 250)}, CF(s * 0.22, 0.08, -0.575))
		piece(b, "Head", {Name = "Pupila", Size = V(0.14, 0.18, 0.05), Color = iris:Lerp(BLACK, 0.35)}, CF(s * 0.2, 0.06, -0.595))
		piece(b, "Head", {Name = "Brillo", Size = V(0.05, 0.05, 0.04), Color = WHITE, Material = NEON}, CF(s * 0.2 - 0.04, 0.1, -0.615))
		piece(b, "Head", {Name = "Ceja", Size = V(0.3, 0.07, 0.06), Color = hair:Lerp(BLACK, 0.25)}, CF(s * 0.23, angry and 0.27 or 0.3, -0.58) * ANG(0, 0, (angry and 0.3 or -0.12) * s))
		if rng:NextNumber() < 0.35 and not angry then
			piece(b, "Head", {Name = "Rubor", Size = V(0.18, 0.08, 0.04), Color = rgb(255, 120, 130), Transparency = 0.45}, CF(s * 0.36, -0.13, -0.565))
		end
	end
	piece(b, "Head", {Name = "Nariz", Size = V(0.14, 0.18, 0.1), Color = skin:Lerp(rgb(150, 70, 50), 0.15)}, CF(0, -0.08, -0.6))
	piece(b, "Head", {Name = "Boca", Size = V(angry and 0.36 or 0.3, 0.07, 0.05), Color = rgb(90, 30, 34)}, CF(0, -0.32, -0.575))
	if not angry then
		for s = -1, 1, 2 do
			piece(b, "Head", {Name = "Boca", Size = V(0.06, 0.06, 0.05), Color = rgb(90, 30, 34)}, CF(s * 0.17, -0.29, -0.575))
		end
	end
	for s = -1, 1, 2 do
		piece(b, "Head", {Name = "Oreja", Size = V(0.12, 0.3, 0.22), Color = skin, Material = PLASTIC}, CF(s * 0.6, 0, 0.02))
	end
end

local function details(b, def, rng, skin, shirt, pants)
	local g = set(def.gear or {})
	local dark = function(c, k)
		return c:Lerp(BLACK, k)
	end
	-- cabeza
	local full = false
	for n in g do
		full = full or FULL_HEAD[n]
	end
	if not full then
		face(b, def, rng, skin)
		local hairy = false
		for n in g do
			hairy = hairy or HAS_HAIR[n]
		end
		if not hairy and not def.bald then
			-- pelo que asoma por detrás y por los lados bajo el sombrero
			local c = def.hair or HAIRS[1]
			piece(b, "Head", {Name = "Pelo", Size = V(1.18, 0.6, 0.32), Color = c, Material = PLASTIC}, CF(0, 0.12, 0.46))
			for s = -1, 1, 2 do
				piece(b, "Head", {Name = "Pelo", Size = V(0.12, 0.45, 0.4), Color = c, Material = PLASTIC}, CF(s * 0.59, 0.18, 0.27))
			end
		end
	end
	if not g.headless then
		piece(b, "UpperTorso", {Name = "Cuello", Shape = CYL, Size = V(0.3, 0.55, 0.55), Color = skin:Lerp(BLACK, 0.08), Material = PLASTIC}, CF(0, 0.92, 0) * ANG(0, 0, PI / 2))
	end
	if g.sheet or g.ghostsheet then
		return
	end
	-- camisa: bajo, puños y estilo
	piece(b, "UpperTorso", {Name = "Bajo", Size = V(1.97, 0.14, 1.03), Color = dark(shirt, 0.18), Material = FABRIC}, CF(0, -0.79, 0))
	for _, s in {"Left", "Right"} do
		piece(b, s .. "LowerArm", {Name = "Puno", Size = V(1.03, 0.16, 1.03), Color = dark(shirt, 0.2), Material = FABRIC}, CF(0, -0.48, 0))
		piece(b, s .. "UpperArm", {Name = "Costura", Size = V(1.03, 0.06, 1.03), Color = dark(shirt, 0.15), Material = FABRIC}, CF(0, 0.5, 0))
	end
	do
		local covered = false
		for n in g do
			covered = covered or COVER_CHEST[n]
		end
		-- (los que llevan traje propio, lisos: sin dibujos ni franjas)
		local style = def.shirtStyle or (def.shirt and 0) or rng:NextInteger(1, 3)
		if g.tie then
			style = 3
		end
		if not covered then
			if style == 3 then
				-- camisa: cuello de picos, tapeta con botones y bolsillo
				for s = -1, 1, 2 do
					piece(b, "UpperTorso", {Name = "CuelloCamisa", Size = V(0.42, 0.26, 0.06), Color = shirt:Lerp(WHITE, 0.3), Material = FABRIC}, CF(s * 0.2, 0.72, -0.52) * ANG(0, 0, s * 0.5))
				end
				if not g.tie then
					piece(b, "UpperTorso", {Name = "Tapeta", Size = V(0.12, 1.4, 0.04), Color = dark(shirt, 0.15), Material = FABRIC}, CF(0, -0.08, -0.515))
					for k = 0, 2 do
						piece(b, "UpperTorso", {Name = "Boton", Shape = CYL, Size = V(0.04, 0.1, 0.1), Color = shirt:Lerp(WHITE, 0.6)}, CF(0, 0.35 - k * 0.42, -0.535) * ANG(0, PI / 2, 0))
					end
				end
				piece(b, "UpperTorso", {Name = "Bolsillo", Size = V(0.38, 0.34, 0.04), Color = dark(shirt, 0.1), Material = FABRIC}, CF(-0.48, 0.25, -0.515))
				piece(b, "UpperTorso", {Name = "Bolsillo", Size = V(0.4, 0.06, 0.05), Color = dark(shirt, 0.25), Material = FABRIC}, CF(-0.48, 0.42, -0.52))
			else
				-- camiseta: cuello redondo y una franja o un dibujo (fantasmita, calabaza o estrella)
				piece(b, "UpperTorso", {Name = "CuelloCamiseta", Size = V(0.8, 0.1, 0.05), Color = dark(shirt, 0.28), Material = FABRIC}, CF(0, 0.79, -0.515))
				local accent = PRINTS[rng:NextInteger(1, #PRINTS)]
				if accent == shirt or (accent.R + accent.G + accent.B - shirt.R - shirt.G - shirt.B) ^ 2 < 0.1 then
					accent = shirt:Lerp(WHITE, 0.6)
				end
				if style == 0 then
					-- lisa
				elseif style == 1 then
					piece(b, "UpperTorso", {Name = "Franja", Size = V(1.97, 0.24, 1.03), Color = accent, Material = FABRIC}, CF(0, 0.18, 0))
					for _, s in {"Left", "Right"} do
						piece(b, s .. "UpperArm", {Name = "Franja", Size = V(1.03, 0.2, 1.03), Color = accent, Material = FABRIC}, CF(0, 0.1, 0))
					end
				else
					local kind = rng:NextInteger(1, 3)
					local at = CF(0, 0.15, -0.52)
					if kind == 1 then -- fantasmita
						piece(b, "UpperTorso", {Name = "Dibujo", Shape = CYL, Size = V(0.04, 0.5, 0.5), Color = accent}, at * CF(0, 0.12, 0) * ANG(0, PI / 2, 0))
						piece(b, "UpperTorso", {Name = "Dibujo", Size = V(0.5, 0.35, 0.04), Color = accent}, at * CF(0, -0.08, 0))
						for s = -1, 1, 2 do
							piece(b, "UpperTorso", {Name = "Dibujo", Size = V(0.07, 0.11, 0.04), Color = dark(shirt, 0.6)}, at * CF(s * 0.1, 0.13, -0.012))
						end
					elseif kind == 2 then -- calabaza
						piece(b, "UpperTorso", {Name = "Dibujo", Shape = CYL, Size = V(0.04, 0.55, 0.55), Color = rgb(255, 130, 30)}, at * ANG(0, PI / 2, 0))
						piece(b, "UpperTorso", {Name = "Dibujo", Size = V(0.08, 0.14, 0.04), Color = rgb(70, 130, 40)}, at * CF(0, 0.32, 0))
						for s = -1, 1, 2 do
							piece(b, "UpperTorso", {Name = "Dibujo", Size = V(0.1, 0.1, 0.04), Color = rgb(40, 20, 10)}, at * CF(s * 0.12, 0.06, -0.012) * ANG(0, 0, PI / 4))
						end
						piece(b, "UpperTorso", {Name = "Dibujo", Size = V(0.28, 0.06, 0.04), Color = rgb(40, 20, 10)}, at * CF(0, -0.1, -0.012))
					else -- estrella
						for k = 0, 1 do
							piece(b, "UpperTorso", {Name = "Dibujo", Size = V(0.38, 0.38, 0.04), Color = accent}, at * ANG(0, 0, k * PI / 4))
						end
					end
				end
			end
		end
	end
	-- pantalón: cinturón con hebilla y bajos
	local waist = false
	for n in g do
		waist = waist or COVER_WAIST[n]
	end
	if not waist then
		piece(b, "LowerTorso", {Name = "Cinturon", Size = V(2.01, 0.16, 1.03), Color = rgb(46, 32, 24), Material = M.Leather or FABRIC}, CF(0, 0.1, 0))
		piece(b, "LowerTorso", {Name = "Hebilla", Size = V(0.26, 0.2, 0.05), Color = rng:NextNumber() < 0.5 and GOLD or STEEL, Material = METAL, Reflectance = 0.2}, CF(0, 0.1, -0.53))
	end
	for _, s in {"Left", "Right"} do
		piece(b, s .. "LowerLeg", {Name = "Bajo", Size = V(1.0, 0.14, 0.99), Color = dark(pants, 0.22), Material = FABRIC}, CF(0, -0.56, 0))
		piece(b, s .. "UpperLeg", {Name = "Costura", Size = V(1.0, 0.9, 0.04), Color = dark(pants, 0.12), Material = FABRIC}, CF(0, 0, 0.47))
	end
	-- zapatos: color, suela y puntera (las zapatillas, con cordones)
	local shoe = def.shoes and {def.shoes, dark(def.shoes, 0.4)} or SHOES[rng:NextInteger(1, #SHOES)]
	for _, s in {"Left", "Right"} do
		local foot = b:FindFirstChild(s .. "Foot")
		if foot then
			foot.Color, foot.Material = shoe[1], PLASTIC
			piece(b, s .. "Foot", {Name = "Suela", Size = V(1.04, 0.1, 1.08), Color = shoe[2]}, CF(0, -0.13, -0.03))
			piece(b, s .. "Foot", {Name = "Puntera", Size = V(0.98, 0.24, 0.3), Color = shoe[1]:Lerp(WHITE, 0.08)}, CF(0, -0.02, -0.4))
			if shoe[3] then
				piece(b, s .. "Foot", {Name = "Cordones", Size = V(0.4, 0.04, 0.34), Color = WHITE}, CF(0, 0.16, -0.12))
			end
		end
	end
end

---------- Variantes de material (muy raras: Config.Variants) ----------
-- Todo el visitante, ropa y complementos, pasa a ser de esa materia. Cada pieza conserva lo claro u oscuro que era
-- (así se sigue viendo quién es: una abuela de oro sigue siendo la abuela).
Outfits.VARIANTS = {
	Chocolate = {color = rgb(130, 76, 42), mat = PLASTIC, refl = 0.08},
	Marble = {color = rgb(236, 233, 226), mat = M.Marble},
	Ice = {color = rgb(170, 222, 255), mat = M.Ice, tr = 0.12, refl = 0.2, fx = rgb(220, 245, 255)},
	Gold = {color = rgb(255, 196, 60), mat = M.Foil, refl = 0.3, fx = rgb(255, 230, 140)},
	Ecto = {color = rgb(110, 255, 150), mat = M.ForceField, fx = rgb(160, 255, 190)},
	Lava = {color = rgb(255, 100, 30), mat = M.CrackedLava, fire = true},
	Emerald = {color = rgb(50, 220, 120), mat = M.Glass, tr = 0.2, refl = 0.35, fx = rgb(150, 255, 190)},
	Ruby = {color = rgb(240, 40, 80), mat = M.Glass, tr = 0.2, refl = 0.35, fx = rgb(255, 150, 180)},
	Diamond = {color = rgb(170, 238, 255), mat = M.Glass, tr = 0.25, refl = 0.5, fx = rgb(230, 250, 255)},
	Obsidian = {color = rgb(70, 30, 110), mat = M.Glass, tr = 0.05, refl = 0.6, fx = rgb(170, 90, 255), glowEyes = rgb(190, 110, 255)},
}

function Outfits.applyVariant(bot, id)
	local v = Outfits.VARIANTS[id]
	if not v then
		return
	end
	local junk = {}
	for _, p in bot:GetDescendants() do
		if p:IsA("BasePart") then
			if p.Name ~= "HumanoidRootPart" and p.Transparency < 1 then
				local _, _, val = p.Color:ToHSV()
				local k = 0.55 + 0.6 * val
				p.Color = Color3.new(math.min(1, v.color.R * k), math.min(1, v.color.G * k), math.min(1, v.color.B * k))
				p.Material = v.mat
				p.Reflectance = v.refl or 0
				if v.tr then
					p.Transparency = math.max(p.Transparency, v.tr)
				end
				if p:IsA("MeshPart") then
					p.TextureID = ""
				end
				if v.glowEyes and (p.Name == "Pupila" or p.Name == "Brillo") then
					p.Color, p.Material, p.Transparency = v.glowEyes, NEON, 0
				end
			end
		elseif p:IsA("SurfaceAppearance") then
			table.insert(junk, p)
		elseif p:IsA("Light") then
			p.Color = v.fx or v.color
		end
	end
	for _, j in junk do
		j:Destroy()
	end
	local torso = bot:FindFirstChild("UpperTorso")
	sparkle(torso, v.fx or v.color, 8)
	light(torso, 10, 1.4, v.fx or v.color)
	if v.fire then
		fire(torso, 3, rgb(255, 90, 20))
		for _, n in {"LeftHand", "RightHand", "Head"} do
			local f = fire(bot:FindFirstChild(n), 1.2, rgb(255, 90, 20))
			if f then
				f.Heat = 4
			end
		end
	end
	bot:SetAttribute("Variant", id)
end

---------- Vestir ----------
-- def: shirt, pants, skin (o al azar), gear {nombres}, golden, torch. Colorea el cuerpo y pone los complementos.
function Outfits.dress(bot, def, rng)
	rng = rng or Random.new()
	local colors = bot:FindFirstChildOfClass("BodyColors")
	if colors then
		colors:Destroy()
	end
	local skin = def.skin or Outfits.SKINS[rng:NextInteger(1, #Outfits.SKINS)]
	-- pelo: el suyo o uno al azar (lo usan los complementos de pelo)
	if not def.hair then
		def = setmetatable({hair = HAIRS[rng:NextInteger(1, #HAIRS)]}, {__index = def})
	end
	local shirt = def.shirt or Outfits.SHIRTS[rng:NextInteger(1, #Outfits.SHIRTS)]
	local pants = def.pants or (def.golden and rgb(200, 140, 30) or Outfits.PANTS[rng:NextInteger(1, #Outfits.PANTS)])
	for _, p in bot:GetChildren() do
		if p:IsA("BasePart") then
			local n = p.Name
			local cloth = n:find("Torso") or n:find("Arm") or n:find("Leg")
			p.Color = (n:find("Torso") or n:find("Arm")) and shirt or (n:find("Leg") or n:find("Foot")) and pants or skin
			if n ~= "HumanoidRootPart" then
				p.Material = cloth and FABRIC or PLASTIC
			end
			p.CollisionGroup = "Bots"
		end
	end
	bot:SetAttribute("Shirt", shirt)
	local ok, err = pcall(details, bot, def, rng, skin, shirt, pants)
	if not ok then
		warn("Outfits: detalle: " .. tostring(err))
	end
	for _, g in def.gear or {} do
		local f = GEAR[g]
		if f then
			local ok, err = pcall(f, bot, def)
			if not ok then
				warn("Outfits: " .. g .. ": " .. tostring(err))
			end
		else
			warn("Outfits: no existe el complemento " .. tostring(g))
		end
	end
	if def.variant then
		Outfits.applyVariant(bot, def.variant)
	end
	return skin, shirt, pants
end

return Outfits
