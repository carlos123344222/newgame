-- Hace los modelos de las skins nuevas en ReplicatedStorage.Assets.Scares (se ejecuta a mano en Studio, en modo edición):
--   require(game.ServerStorage.SkinsBuilder).build()
-- Cada skin (Config.Scares con theme) es una copia del modelo de su susto base con el aspecto de su tema
-- (Config.SkinThemes): cada pieza toma el color de la escala dark → mid → light según lo clara que era, lo que brilla
-- (neón, luces, fuego, partículas) pasa al color accent, y lleva un aura de partículas y una luz de su color. Las
-- mallas con textura (el armario, el ataúd) la conservan teñida con un SurfaceAppearance (como las skins antiguas).
-- El comportamiento lo copia ScareBehaviors de la base (Config: base).
-- Sin bases ni decorado en el suelo (charcos, braseros, rocas): los sustos no tienen, y la skin es solo su aspecto.
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Config)

local B = {}
local M = Enum.Material
local SKIP = {Hitbox = true, Path = true, Range = true, Root = true}
-- lo que es decorado (el tocón del cuervo, lápidas, el caldero...) no cambia de color del todo: se oscurece y toma un
-- poco del tema, para que destaque el monstruo
local PROP = {}
for _, n in {"Wood", "WoodPlanks", "Slate", "Concrete", "Cobblestone", "Brick", "Granite", "Rock", "Pebble", "Sand", "Ground", "Grass", "Basalt", "Limestone", "Pavement"} do
	PROP[M[n]] = true
end

local function lum(c)
	return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end

-- lo: luminancia más oscura y span lo que va de la más oscura a la más clara del modelo (se estira a toda la escala)
local function ramp(th, c, lo, span)
	local l = math.clamp((lum(c) - lo) / span, 0, 1)
	if l < 0.5 then
		return th.dark:Lerp(th.mid, l / 0.5)
	end
	return th.mid:Lerp(th.light, (l - 0.5) / 0.5)
end

local function seq(a, b)
	return ColorSequence.new(a, b)
end

-- Aura según el tema: partículas que salen del volumen de la pieza (y alguna de más)
local TEX = {
	spark = "rbxasset://textures/particles/sparkles_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
	fire = "rbxasset://textures/particles/fire_main.dds",
}
local function emitter(p, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = "SkinAura"
	e.Shape, e.ShapeStyle = Enum.ParticleEmitterShape.Box, Enum.ParticleEmitterShapeStyle.Volume
	e.LightEmission = 1
	e.LightInfluence = 0
	e.SpreadAngle = Vector2.new(25, 25)
	for k, v in props do
		e[k] = v
	end
	e.Parent = p
	return e
end
local FX = {
	fire = function(p, th)
		emitter(p, {Texture = TEX.fire, Color = seq(th.accent, th.mid), Rate = 9, Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(1.5, 3.5),
			Acceleration = Vector3.new(0, 4, 0), Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0)}),
			Transparency = NumberSequence.new(0.2, 1), RotSpeed = NumberRange.new(-60, 60)})
		emitter(p, {Name = "SkinEmbers", Texture = TEX.spark, Color = seq(th.light, th.accent), Rate = 12, Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(2, 5),
			Acceleration = Vector3.new(0, 3, 0), Size = NumberSequence.new(0.22, 0), SpreadAngle = Vector2.new(60, 60)})
	end,
	frost = function(p, th)
		emitter(p, {Texture = TEX.spark, Color = seq(Color3.new(1, 1, 1), th.accent), Rate = 10, Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(0.3, 1),
			Acceleration = Vector3.new(0, -1.2, 0), Size = NumberSequence.new(0.3, 0), RotSpeed = NumberRange.new(-90, 90)})
		emitter(p, {Name = "SkinMist", Texture = TEX.smoke, Color = seq(th.light, th.mid), Rate = 3, Lifetime = NumberRange.new(2, 3), Speed = NumberRange.new(0.2, 0.6),
			LightEmission = 0.4, Size = NumberSequence.new(1.6, 2.6), Transparency = NumberSequence.new(0.8, 1)})
	end,
	souls = function(p, th)
		emitter(p, {Texture = TEX.smoke, Color = seq(th.accent, th.light), Rate = 5, Lifetime = NumberRange.new(1, 1.8), Speed = NumberRange.new(1, 2.2),
			Acceleration = Vector3.new(0, 2, 0), Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0)}),
			Transparency = NumberSequence.new(0.35, 1), RotSpeed = NumberRange.new(-90, 90)})
		emitter(p, {Name = "SkinSparks", Texture = TEX.spark, Color = seq(th.accent, Color3.new(1, 1, 1)), Rate = 6, Lifetime = NumberRange.new(0.8, 1.4),
			Speed = NumberRange.new(0.5, 1.5), Size = NumberSequence.new(0.25, 0)})
	end,
	gold = function(p, th)
		emitter(p, {Texture = TEX.spark, Color = seq(th.accent, Color3.fromRGB(255, 250, 220)), Rate = 12, Lifetime = NumberRange.new(0.8, 1.6),
			Speed = NumberRange.new(0.4, 1.4), Size = NumberSequence.new(0.32, 0), RotSpeed = NumberRange.new(-120, 120)})
	end,
	sparkle = function(p, th)
		emitter(p, {Texture = TEX.spark, Color = seq(Color3.new(1, 1, 1), th.accent), Rate = 14, Lifetime = NumberRange.new(0.6, 1.2),
			Speed = NumberRange.new(0.2, 1), Size = NumberSequence.new(0.35, 0), RotSpeed = NumberRange.new(-180, 180)})
	end,
	blood = function(p, th)
		emitter(p, {Texture = TEX.smoke, Color = seq(th.accent, th.dark), Rate = 4, Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(0.3, 1),
			LightEmission = 0.6, Size = NumberSequence.new(1, 2), Transparency = NumberSequence.new(0.6, 1)})
		emitter(p, {Name = "SkinSparks", Texture = TEX.spark, Color = seq(th.accent, th.light), Rate = 8, Lifetime = NumberRange.new(1, 1.8),
			Speed = NumberRange.new(0.6, 1.8), Acceleration = Vector3.new(0, 1.5, 0), Size = NumberSequence.new(0.26, 0)})
	end,
	void = function(p, th)
		emitter(p, {Texture = TEX.smoke, Color = seq(th.mid, th.dark), Rate = 5, Lifetime = NumberRange.new(1.5, 2.4), Speed = NumberRange.new(0.3, 0.9),
			LightEmission = 0.2, Size = NumberSequence.new(1.2, 2.2), Transparency = NumberSequence.new(0.45, 1)})
		emitter(p, {Name = "SkinStars", Texture = TEX.spark, Color = seq(th.accent, Color3.new(1, 1, 1)), Rate = 12, Lifetime = NumberRange.new(1, 2),
			Speed = NumberRange.new(0.2, 0.8), Size = NumberSequence.new(0.22, 0), RotSpeed = NumberRange.new(-60, 60)})
	end,
	toxic = function(p, th)
		emitter(p, {Texture = TEX.smoke, Color = seq(th.accent, th.mid), Rate = 5, Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(0.8, 1.8),
			Acceleration = Vector3.new(0, 1.5, 0), Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.2)}),
			Transparency = NumberSequence.new(0.5, 1)})
		emitter(p, {Name = "SkinBubbles", Texture = TEX.spark, Color = seq(th.light, th.accent), Rate = 9, Lifetime = NumberRange.new(1, 1.8),
			Speed = NumberRange.new(1, 2.5), Acceleration = Vector3.new(0, 2, 0), Size = NumberSequence.new(0.3, 0.05)})
	end,
	spectral = function(p, th)
		emitter(p, {Texture = TEX.smoke, Color = seq(th.accent, th.light), Rate = 6, Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(0.6, 1.6),
			Acceleration = Vector3.new(0, 1.2, 0), Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2)}),
			Transparency = NumberSequence.new(0.55, 1), RotSpeed = NumberRange.new(-45, 45)})
		emitter(p, {Name = "SkinSparks", Texture = TEX.spark, Color = seq(th.accent, Color3.new(1, 1, 1)), Rate = 8, Lifetime = NumberRange.new(0.8, 1.4),
			Speed = NumberRange.new(0.4, 1.2), Size = NumberSequence.new(0.24, 0)})
	end,
}

-- Piezas del tema de cada skin (no solo color: carámbanos, nemes, luna de sangre, cuernos de fuego...).
-- add(ref, props, offset): una pieza en offset respecto a la pieza ref. Si ref es de una criatura articulada (Rig:
-- atributos Limb y Rest), la nueva lleva la misma articulación y se mueve con ella; si no, va soldada a ref.
-- (su Rest sale del Rest de ref y no de dónde está ahora: el modelo se guarda en su pose de reposo, con la cabeza
-- ya girada, y si no la pose se aplicaría dos veces y la pieza saldría torcida)
local V, CF, ANG = Vector3.new, CFrame.new, CFrame.Angles
local PI = math.pi
local function add(ref, props, offset, class)
	local p = Instance.new(class or "Part")
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = M.SmoothPlastic
	for k, v in props do
		p[k] = v
	end
	p.CFrame = ref.CFrame * (offset or CF())
	local limb, rest = ref:GetAttribute("Limb"), ref:GetAttribute("Rest")
	if limb and rest then
		p.Anchored = true
		p:SetAttribute("Limb", limb)
		p:SetAttribute("Rest", rest * (offset or CF()))
	else
		p.Anchored, p.Massless = false, true
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = ref, p
		w.Parent = p
	end
	p.Parent = ref.Parent
	return p
end
-- (la pieza de la criatura articulada si la hay: el decorado de alrededor puede llamarse igual, como las calabacitas)
local function find(m, name)
	local loose
	for _, d in m:GetDescendants() do
		if d.Name == name and d:IsA("BasePart") then
			if d.Parent ~= m then
				return d
			end
			loose = loose or d
		end
	end
	return loose
end
local function glowLight(p, color, range, bright)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = color, range, bright, false
	l.Parent = p
	return l
end
-- triángulo plano de cara a -Z hecho con dos cuñas (puntas, carámbanos, púas)
local function tri(ref, w, h, d, props, offset)
	for sgn = -1, 1, 2 do
		local p = table.clone(props)
		p.Size = V(d, h, w / 2)
		add(ref, p, offset * CF(sgn * w / 4, 0, 0) * ANG(0, -sgn * PI / 2, 0), "WedgePart")
	end
end
-- carámbano: dos tramos que se afinan hacia abajo
local function icicle(ref, offset, len, th)
	local ice = {Color = th.light, Material = M.Ice, Transparency = 0.15, Reflectance = 0.2}
	local p1 = table.clone(ice) p1.Size = V(0.2, len * 0.55, 0.2)
	add(ref, p1, offset * CF(0, -len * 0.27, 0))
	local p2 = table.clone(ice) p2.Size = V(0.11, len * 0.5, 0.11)
	add(ref, p2, offset * CF(0, -len * 0.75, 0))
end
-- cristal de hielo: un prisma inclinado con el núcleo brillante
local function shard(ref, offset, h, th)
	add(ref, {Size = V(0.42, h, 0.42), Color = th.light, Material = M.Ice, Transparency = 0.1, Reflectance = 0.25}, offset)
	add(ref, {Size = V(0.18, h * 0.8, 0.18), Color = th.accent, Material = M.Neon}, offset)
	tri(ref, 0.42, 0.4, 0.42, {Color = th.light, Material = M.Ice, Transparency = 0.1}, offset * CF(0, h / 2 + 0.2, 0))
end

local EXTRAS = {}

-- Armario maldito: ojos verdes entre la madera, una rendija de luz, velas con llama verde, cadenas con candado
-- cruzando las puertas y ectoplasma que rezuma por abajo
EXTRAS.ArmarioMaldito = function(m, th)
	local rng = Random.new(7)
	for _, n in {"DoorL", "DoorR"} do
		local d = m:FindFirstChild(n)
		if d then
			for k = 1, 3 do
				local x = rng:NextNumber(-0.45, 0.45) * d.Size.X
				local y = (k - 2) * d.Size.Y * 0.27 + rng:NextNumber(-0.3, 0.3)
				for sgn = -1, 1, 2 do
					local at = CF(x + sgn * 0.24, y, -d.Size.Z / 2)
					add(d, {Name = "Cuenca", Shape = Enum.PartType.Ball, Size = V(0.46, 0.34, 0.1), Color = th.dark}, at * CF(0, 0, -0.02))
					add(d, {Name = "Ojo", Shape = Enum.PartType.Ball, Size = V(0.36, 0.24, 0.1), Color = th.accent, Material = M.Neon}, at * CF(0, 0, -0.05))
					add(d, {Name = "Pupila", Size = V(0.07, 0.2, 0.06), Color = Color3.fromRGB(10, 20, 10)}, at * CF(0, 0, -0.1))
				end
			end
		end
	end
	local body = m:FindFirstChild("Body")
	if not body then
		return
	end
	local B = body.Size
	local front = -B.Z / 2
	local slit = add(body, {Name = "Rendija", Size = V(0.12, B.Y * 0.68, 0.1), Color = th.accent, Material = M.Neon, Transparency = 0.15}, CF(0, -B.Y * 0.04, front - 0.05))
	glowLight(slit, th.accent, 9, 1.2)
	-- velas moradas con llama verde y cera derretida
	for sgn = -1, 1, 2 do
		local c = add(body, {Name = "Vela", Shape = Enum.PartType.Cylinder, Size = V(0.9, 0.32, 0.32), Color = th.mid:Lerp(th.light, 0.35)},
			CF(sgn * B.X * 0.36, B.Y / 2 + 0.3, -0.4) * ANG(0, 0, PI / 2))
		add(c, {Name = "Cera", Shape = Enum.PartType.Cylinder, Size = V(0.12, 0.5, 0.5), Color = th.mid:Lerp(th.light, 0.35)}, CF(-0.42, 0, 0))
		local f = add(c, {Name = "Llama", Shape = Enum.PartType.Ball, Size = V(0.22, 0.34, 0.22), Color = th.accent, Material = M.Neon}, CF(0.58, 0, 0))
		glowLight(f, th.accent, 6, 0.8)
	end
	-- cadenas en aspa por delante, con un candado en el cruce
	local iron = {Color = Color3.fromRGB(70, 64, 80), Material = M.Metal, Reflectance = 0.15}
	for sgn = -1, 1, 2 do
		for k = -4, 4 do
			local props = table.clone(iron)
			props.Size = V(0.12, 0.42, 0.24)
			props.Name = "Cadena"
			add(body, props, CF(0, -B.Y * 0.08, front - 0.12) * ANG(0, 0, sgn * 0.62) * CF(0, k * 0.46, 0) * ANG(0, k % 2 == 0 and 0 or PI / 2, 0))
		end
	end
	add(body, {Name = "Candado", Size = V(0.62, 0.52, 0.22), Color = th.light:Lerp(Color3.fromRGB(200, 170, 80), 0.6), Material = M.Metal, Reflectance = 0.2}, CF(0, -B.Y * 0.1, front - 0.22))
	add(body, {Name = "Candado", Shape = Enum.PartType.Cylinder, Size = V(0.14, 0.42, 0.42), Color = Color3.fromRGB(90, 84, 96), Material = M.Metal}, CF(0, -B.Y * 0.1 + 0.34, front - 0.22) * ANG(0, PI / 2, 0))
	add(body, {Name = "Ojo", Size = V(0.1, 0.16, 0.05), Color = th.accent, Material = M.Neon}, CF(0, -B.Y * 0.1 - 0.05, front - 0.34))
	-- ectoplasma rezumando por las patas
	for k = 0, 5 do
		local x = (k - 2.5) / 2.5 * B.X * 0.42
		add(body, {Name = "Ecto", Shape = Enum.PartType.Ball, Size = V(0.5, 0.28 + (k % 3) * 0.12, 0.5), Color = th.accent, Material = M.Neon, Transparency = 0.25},
			CF(x, -B.Y / 2 + 0.05, front + 0.15))
	end
end

-- Calabaza helada: gorro de nieve, carámbanos colgando de la calabaza y de los brazos y cristales de hielo en los
-- hombros
EXTRAS.CalabazaHelada = function(m, th)
	local head = find(m, "Pumpkin")
	if head and head.Parent:IsA("Model") and head.Parent ~= m then
		local H = head.Size
		-- capa de nieve encima (la cabeza es un bloque), con montoncitos y goterones que caen por los bordes
		local snow = {Color = Color3.fromRGB(240, 250, 255), Material = M.Snow}
		local function sn(size, cf, shape)
			local p = table.clone(snow)
			p.Name, p.Size, p.Shape = "Nieve", size, shape or Enum.PartType.Block
			add(head, p, cf)
		end
		sn(V(H.X + 0.12, 0.26, H.Z + 0.12), CF(0, H.Y / 2 + 0.1, 0))
		sn(V(H.X * 0.7, 0.4, H.Z * 0.6), CF(-0.1, H.Y / 2 + 0.3, 0.1), Enum.PartType.Ball)
		sn(V(H.X * 0.45, 0.32, H.Z * 0.45), CF(0.35, H.Y / 2 + 0.35, -0.2), Enum.PartType.Ball)
		for k = -1, 1 do
			sn(V(0.3, 0.38, 0.12), CF(k * H.X * 0.32, H.Y / 2 - 0.1, -H.Z / 2 - 0.06))
		end
		-- carámbanos colgando del borde de abajo por los lados y por detrás
		for k = -2, 2 do
			icicle(head, CF(k * H.X * 0.2, -H.Y / 2 + 0.05, H.Z / 2 + 0.06), 0.5 + (k % 2) * 0.3, th)
			icicle(head, CF(-H.X / 2 - 0.06, -H.Y / 2 + 0.05, k * H.Z * 0.2), 0.45 + ((k + 1) % 2) * 0.3, th)
			icicle(head, CF(H.X / 2 + 0.06, -H.Y / 2 + 0.05, k * H.Z * 0.2), 0.45 + (k % 2) * 0.3, th)
		end
		add(head, {Name = "Escarcha", Size = V(H.X + 0.05, H.Y + 0.05, H.Z + 0.05), Color = th.light, Material = M.Glass, Transparency = 0.75, Reflectance = 0.3}, CF())
		-- aliento helado saliendo de la boca
		local breath = add(head, {Name = "Aliento", Size = V(0.2, 0.2, 0.2), Transparency = 1}, CF(0, -H.Y * 0.2, -H.Z / 2 - 0.2))
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Color = ColorSequence.new(Color3.new(1, 1, 1), th.light)
		e.Rate, e.Lifetime, e.Speed = 4, NumberRange.new(1, 1.6), NumberRange.new(0.8, 1.4)
		e.EmissionDirection = Enum.NormalId.Front
		e.Size = NumberSequence.new(0.3, 1.2)
		e.Transparency = NumberSequence.new(0.5, 1)
		e.Parent = breath
	end
	for _, n in {"ArmL", "ArmR"} do
		local arm = find(m, n)
		if arm then
			for k = -1, 1 do
				icicle(arm, CF(k * 0.3, -arm.Size.Y * 0.2, 0.25), 0.45 + math.abs(k) * 0.15, th)
			end
			shard(arm, CF(0, arm.Size.Y * 0.55, 0) * ANG(0.3, 0, n == "ArmL" and 0.5 or -0.5), 0.8, th)
		end
	end
	local torso = find(m, "Torso")
	if torso then
		shard(torso, CF(-0.5, torso.Size.Y * 0.55, 0.35) * ANG(-0.3, 0, 0.35), 1.0, th)
		shard(torso, CF(0.45, torso.Size.Y * 0.5, 0.4) * ANG(-0.25, 0, -0.4), 0.7, th)
	end
end

-- Momia faraón: nemes de rayas oro y lapislázuli con la cobra, collar usekh, brazaletes, faldellín de oro, un ankh en
-- la mano
EXTRAS.MomiaFaraon = function(m, th)
	local GOLD, LAPIS, TURQ = Color3.fromRGB(255, 200, 70), Color3.fromRGB(26, 60, 170), Color3.fromRGB(60, 200, 210)
	local gold = {Color = GOLD, Material = M.Foil, Reflectance = 0.1}
	local function G(props)
		local p = table.clone(gold)
		for k, v in props do
			p[k] = v
		end
		return p
	end
	local head = find(m, "Head")
	if head and head.Parent ~= m then
		local H = head.Size
		add(head, G({Name = "Nemes", Size = V(H.X + 0.16, 0.42, H.Z + 0.14)}), CF(0, H.Y / 2 + 0.05, 0.02))
		add(head, {Name = "Nemes", Size = V(H.X + 0.18, 0.12, H.Z + 0.16), Color = LAPIS}, CF(0, H.Y / 2 - 0.12, 0.02))
		for sgn = -1, 1, 2 do
			-- las bandas que caen a los lados de la cara hasta los hombros, a rayas
			for k = 0, 5 do
				add(head, {Name = "Nemes", Size = V(0.3, 0.32, H.Z * 0.75), Color = k % 2 == 0 and GOLD or LAPIS, Material = k % 2 == 0 and M.Foil or M.SmoothPlastic},
					CF(sgn * (H.X / 2 + 0.12), H.Y * 0.32 - k * 0.32, 0.12) * ANG(0, 0, sgn * 0.08))
			end
		end
		for k = 0, 3 do
			add(head, {Name = "Nemes", Size = V(H.X * 0.7, 0.3, 0.3), Color = k % 2 == 0 and GOLD or LAPIS, Material = k % 2 == 0 and M.Foil or M.SmoothPlastic}, CF(0, H.Y * 0.2 - k * 0.3, H.Z / 2 + 0.1))
		end
		-- la cobra de la frente
		add(head, G({Name = "Cobra", Size = V(0.2, 0.42, 0.16)}), CF(0, H.Y / 2 - 0.05, -H.Z / 2 - 0.1))
		add(head, G({Name = "Cobra", Shape = Enum.PartType.Ball, Size = V(0.28, 0.22, 0.2)}), CF(0, H.Y / 2 + 0.2, -H.Z / 2 - 0.12))
		add(head, {Name = "Ojo", Shape = Enum.PartType.Ball, Size = V(0.12, 0.12, 0.08), Color = Color3.fromRGB(255, 50, 60), Material = M.Neon}, CF(0, H.Y / 2 + 0.22, -H.Z / 2 - 0.22))
	end
	local torso = find(m, "Torso")
	if torso and torso.Parent ~= m then
		local T = torso.Size
		-- collar usekh: tres arcos de cuentas oro, lapislázuli y turquesa
		for row = 0, 2 do
			local R = 0.55 + row * 0.22
			for k = 0, 8 do
				local ang = (k / 8 - 0.5) * PI * 0.92
				add(torso, {Name = "Usekh", Size = V(0.24, 0.22, 0.08), Color = ({GOLD, LAPIS, TURQ})[row + 1], Material = row == 0 and M.Foil or M.SmoothPlastic},
					CF(math.sin(ang) * R, T.Y / 2 - 0.05 - math.cos(ang) * R * 0.55, -T.Z / 2 - 0.04) * ANG(0, 0, ang))
			end
		end
		-- escarabajo de oro con alas de lapislázuli en el pecho
		add(torso, G({Name = "Escarabajo", Shape = Enum.PartType.Ball, Size = V(0.4, 0.5, 0.16)}), CF(0, -0.05, -T.Z / 2 - 0.06))
		for sgn = -1, 1, 2 do
			add(torso, {Name = "Escarabajo", Size = V(0.4, 0.22, 0.06), Color = LAPIS}, CF(sgn * 0.32, 0.02, -T.Z / 2 - 0.05) * ANG(0, 0, sgn * 0.35))
		end
		-- cinturón y faldellín
		add(torso, G({Name = "Cinturon", Size = V(T.X + 0.1, 0.24, T.Z + 0.1)}), CF(0, -T.Y / 2 + 0.1, 0))
		add(torso, G({Name = "Faldellin", Size = V(0.7, 1.0, 0.08)}), CF(0, -T.Y / 2 - 0.45, -T.Z / 2 - 0.05))
		for k = -1, 1 do
			add(torso, {Name = "Faldellin", Size = V(0.12, 0.92, 0.09), Color = LAPIS}, CF(k * 0.22, -T.Y / 2 - 0.45, -T.Z / 2 - 0.06))
		end
	end
	for _, n in {"ArmL", "ArmR"} do
		local arm = find(m, n)
		if arm and arm.Parent ~= m then
			local A = arm.Size
			add(arm, G({Name = "Brazalete", Size = V(A.X + 0.12, 0.26, A.Z + 0.12)}), CF(0, A.Y * 0.18, 0))
			add(arm, {Name = "Brazalete", Size = V(A.X + 0.14, 0.1, A.Z + 0.14), Color = LAPIS}, CF(0, A.Y * 0.18, 0))
			add(arm, G({Name = "Brazalete", Size = V(A.X + 0.12, 0.2, A.Z + 0.12)}), CF(0, -A.Y * 0.36, 0))
		end
	end
	local armR = find(m, "ArmR")
	if armR and armR.Parent ~= m then
		-- ankh de oro en la mano derecha
		local at = CF(0, -armR.Size.Y / 2 - 0.1, -0.2)
		add(armR, G({Name = "Ankh", Size = V(0.14, 1.1, 0.14)}), at * CF(0, -0.25, 0))
		add(armR, G({Name = "Ankh", Size = V(0.62, 0.14, 0.14)}), at * CF(0, 0.2, 0))
		for k = 0, 7 do
			local ang = k / 8 * PI * 2
			add(armR, G({Name = "Ankh", Size = V(0.12, 0.14, 0.16)}), at * CF(math.sin(ang) * 0.22, 0.52 + math.cos(ang) * 0.3, 0) * ANG(0, 0, -ang))
		end
	end
end

-- Lobo de la luna de sangre: la luna roja detrás (va con el torso), grilletes rotos con cadena en las muñecas, collar
-- de colmillos, púas de hueso en los hombros y tres zarpazos que brillan en el pecho
EXTRAS.LoboSangre = function(m, th)
	local torso = find(m, "Torso")
	if not torso or torso.Parent == m then
		return
	end
	local T = torso.Size
	local MOON = Color3.fromRGB(255, 70, 52)
	local moon = add(torso, {Name = "Luna", Shape = Enum.PartType.Cylinder, Size = V(0.12, 3.6, 3.6), Color = MOON, Material = M.Neon, Transparency = 0.1}, CF(0, 2.1, T.Z / 2 + 0.9) * ANG(0, PI / 2, 0))
	add(torso, {Name = "Luna", Shape = Enum.PartType.Cylinder, Size = V(0.1, 4.1, 4.1), Color = MOON, Material = M.Neon, Transparency = 0.75}, CF(0, 2.1, T.Z / 2 + 0.95) * ANG(0, PI / 2, 0))
	for _, c in {{-0.7, 2.6, 0.7}, {0.6, 1.6, 0.5}, {0.5, 2.9, 0.35}, {-0.3, 1.5, 0.3}} do
		add(torso, {Name = "Crater", Shape = Enum.PartType.Cylinder, Size = V(0.06, c[3] * 1.6, c[3] * 1.6), Color = Color3.fromRGB(180, 30, 30), Material = M.Neon}, CF(c[1], c[2], T.Z / 2 + 0.82) * ANG(0, PI / 2, 0))
	end
	glowLight(moon, MOON, 14, 1.2)
	-- zarpazos en el pecho
	for k = -1, 1 do
		add(torso, {Name = "Zarpazo", Size = V(0.1, 1.1, 0.06), Color = th.accent, Material = M.Neon}, CF(0.35 + k * 0.28, 0.1, -T.Z / 2 - 0.05) * ANG(0, 0, 0.4))
	end
	-- collar de colmillos
	for k = -3, 3 do
		local ang = k / 3 * 1.2
		tri(torso, 0.22, 0.34, 0.1, {Name = "Colmillo", Color = Color3.fromRGB(245, 235, 215)}, CF(math.sin(ang) * 0.85, T.Y / 2 - 0.25 - math.cos(ang) * 0.2, -T.Z / 2 - 0.08) * ANG(0, 0, PI))
	end
	add(torso, {Name = "Cuerda", Size = V(1.9, 0.08, 0.08), Color = Color3.fromRGB(70, 40, 30)}, CF(0, T.Y / 2 - 0.12, -T.Z / 2 - 0.05))
	-- púas de hueso en los hombros
	for sgn = -1, 1, 2 do
		for k = 0, 2 do
			tri(torso, 0.3, 0.7 - k * 0.12, 0.3, {Name = "Pua", Color = Color3.fromRGB(240, 228, 205)}, CF(sgn * (T.X / 2 - 0.2), T.Y / 2 + 0.3, -0.3 + k * 0.4) * ANG(0, 0, -sgn * 0.5))
		end
	end
	-- grilletes rotos en las muñecas con tres eslabones colgando
	for _, n in {"ArmLHand", "ArmRHand"} do
		local hand = find(m, n)
		if hand and hand.Parent ~= m then
			local iron = {Color = Color3.fromRGB(60, 58, 66), Material = M.Metal, Reflectance = 0.2}
			local ring = table.clone(iron)
			ring.Shape, ring.Size, ring.Name = Enum.PartType.Cylinder, V(0.34, hand.Size.X + 0.3, hand.Size.X + 0.3), "Grillete"
			add(hand, ring, CF(0, 0.45, 0) * ANG(0, 0, PI / 2))
			for k = 1, 3 do
				local link = table.clone(iron)
				link.Size, link.Name = V(0.12, 0.36, 0.24), "Eslabon"
				add(hand, link, CF(0, 0.45 - k * 0.32, 0.55) * ANG(0, k % 2 == 0 and PI / 2 or 0, 0))
			end
		end
	end
end

-- Dragón infernal: corona de cuernos de obsidiana con puntas que arden, púas de obsidiana por el lomo, alas de lava y
-- un corazón fundido que gotea
EXTRAS.DragonInfernal = function(m, th)
	local OBS = Color3.fromRGB(26, 18, 24)
	local skull = find(m, "Skull")
	if skull and skull.Parent ~= m then
		local S = skull.Size
		for _, h in {{-0.75, 0.55, -0.35, 1.6}, {0.75, 0.55, 0.35, 1.6}, {-0.4, 0.75, -0.15, 1.1}, {0.4, 0.75, 0.15, 1.1}} do
			local at = CF(h[1], S.Y / 2 + h[2] * 0.4, 0.5) * ANG(-0.6, 0, h[3])
			add(skull, {Name = "Cuerno", Size = V(0.32, h[4], 0.32), Color = OBS, Material = M.Glass, Reflectance = 0.4}, at * CF(0, h[4] / 2, 0))
			local tipP = add(skull, {Name = "Punta", Size = V(0.2, 0.42, 0.2), Color = th.accent, Material = M.Neon}, at * CF(0, h[4] + 0.18, 0))
			if h[4] > 1.2 then
				local f = Instance.new("Fire")
				f.Size, f.Heat, f.Color, f.SecondaryColor = 1.4, 9, th.accent, th.light
				f.Parent = tipP
			end
		end
	end
	-- púas de obsidiana sobre las placas del lomo
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") and p.Name == "Part" and math.abs(p.Size.X - 0.2) < 0.05 and math.abs(p.Size.Y - 0.7) < 0.05 and math.abs(p.Size.Z - 0.6) < 0.05 then
			tri(p, 0.5, 0.75, 0.16, {Name = "PuaLomo", Color = OBS, Material = M.Glass, Reflectance = 0.4}, CF(0, 0.65, 0) * ANG(0, PI / 2, 0))
			add(p, {Name = "PuaBrillo", Size = V(0.06, 0.5, 0.06), Color = th.accent, Material = M.Neon}, CF(0, 0.55, 0))
		end
	end
	-- corazón fundido que gotea lava
	local core = find(m, "CoreBall")
	if core then
		local drip = Instance.new("ParticleEmitter")
		drip.Name = "Lava"
		drip.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		drip.Color = ColorSequence.new(th.light, th.accent)
		drip.LightEmission, drip.Rate = 1, 10
		drip.Lifetime, drip.Speed = NumberRange.new(0.8, 1.2), NumberRange.new(0.5, 1)
		drip.Acceleration = V(0, -18, 0)
		drip.Size = NumberSequence.new(0.3, 0.1)
		drip.Parent = core
	end
	local mouth = find(m, "Mouth")
	if mouth then
		local smoke = Instance.new("ParticleEmitter")
		smoke.Name = "Humo"
		smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
		smoke.Color = ColorSequence.new(th.accent, Color3.fromRGB(60, 40, 40))
		smoke.LightEmission, smoke.Rate = 0.5, 6
		smoke.Lifetime, smoke.Speed = NumberRange.new(1, 1.6), NumberRange.new(1, 2)
		smoke.Acceleration = V(0, 2.5, 0)
		smoke.Size = NumberSequence.new(0.4, 1.4)
		smoke.Transparency = NumberSequence.new(0.4, 1)
		smoke.Parent = mouth
	end
end

-- ¿Brilla? (neón o casi blanco con luz dentro: ojos, llamas, gemas)
local function glows(p)
	return p.Material == M.Neon or p:FindFirstChildWhichIsA("Light") ~= nil
end
-- los ojos de las skins siempre brillan (con el color de su tema), y lo que diga glowNames del tema (las bobinas de la
-- Toxic...)
local function isEye(p, th)
	local n = p.Name:lower()
	for _, k in th.glowNames or {} do
		if n:find(k) then
			return true
		end
	end
	return (n:find("eye") or n:find("ojo")) and not n:find("brow") and not n:find("lid") and not n:find("socket")
end

function B.skin(t)
	local def = Config.Scares[t]
	local th = def and def.theme and Config.SkinThemes[def.theme]
	local src = def and RS.Assets.Scares:FindFirstChild(def.base)
	assert(th and src, "skin sin tema o sin modelo base: " .. tostring(t))
	local m = src:Clone()
	m.Name = t
	local lo, hi = 1, 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and not SKIP[d.Name] and not glows(d) and d.Transparency < 1 then
			lo, hi = math.min(lo, lum(d.Color)), math.max(hi, lum(d.Color))
		end
	end
	local span = math.max(hi - lo, 0.25)
	local tint = th.tint or th.mid:Lerp(th.light, 0.65)
	local biggest, vol = nil, 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			if SKIP[d.Name] then
				continue
			end
			if d:IsA("MeshPart") and d.TextureID ~= "" and not d:FindFirstChildOfClass("SurfaceAppearance") then
				local sa = Instance.new("SurfaceAppearance")
				sa.ColorMap = d.TextureID
				sa.Color = tint
				sa.Parent = d
			end
			if glows(d) or isEye(d, th) then
				d.Color, d.Material = th.accent, M.Neon
			elseif th.glowTop and (lum(d.Color) - lo) / span >= th.glowTop then
				-- (lo más claro del modelo pasa a brillar: la Toxic reluce)
				d.Color, d.Material = th.accent:Lerp(th.light, 0.3), M.Neon
			elseif PROP[d.Material] then
				d.Color = d.Color:Lerp(th.dark, 0.3):Lerp(th.mid, 0.18)
			else
				d.Color = ramp(th, d.Color, lo, span)
				if th.mat then
					d.Material = th.mat
				end
				d.Reflectance = th.refl or d.Reflectance
				if th.tr and d.Transparency < 1 then
					d.Transparency = math.max(d.Transparency, th.tr)
					if d:GetAttribute("T") then
						d:SetAttribute("T", math.max(d:GetAttribute("T"), th.tr))
					end
				end
			end
			-- el aura va en la pieza visible más grande (la que no se esconde hasta el susto)
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if d.Transparency < 0.5 and not d:GetAttribute("T") and v > vol then
				biggest, vol = d, v
			end
		elseif d:IsA("SurfaceAppearance") then
			d.Color = tint
		elseif d:IsA("Decal") or d:IsA("Texture") then
			d.Color3 = th.light
		elseif d:IsA("Light") then
			d.Color = th.accent
		elseif d:IsA("Fire") then
			d.Color, d.SecondaryColor = th.accent, th.light
		elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") then
			d.Color = seq(th.accent, th.light)
		end
	end
	if EXTRAS[t] then
		EXTRAS[t](m, th)
	end
	if biggest then
		FX[th.fx](biggest, th)
		local l = Instance.new("PointLight")
		l.Name = "SkinGlow"
		l.Color, l.Range, l.Brightness, l.Shadows = th.accent, 11, 0.9, false
		l.Parent = biggest
	end
	m:SetAttribute("Skin", def.theme)
	return m
end

function B.build()
	local folder = RS.Assets.Scares
	local made = {}
	for _, t in Config.SkinOrder do
		if Config.Scares[t].theme then
			local old = folder:FindFirstChild(t)
			if old then
				old:Destroy()
			end
			B.skin(t).Parent = folder
			table.insert(made, t)
		end
	end
	return made
end

return B
