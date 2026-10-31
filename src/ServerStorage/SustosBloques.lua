-- Sustos nuevos con el estilo de los de siempre: criaturas de bloques articuladas (ReplicatedStorage.Rig) y atrezo de
-- bloques. Cada modelo: pivote en el suelo (0, 0, 0) mirando a -Z, Hitbox (huella), Solid (choque, si es sólido),
-- una o varias criaturas (Model con Root y articulaciones J_/P_/Par_) y sus luces y partículas.
-- Uso (barra de comandos): require(game.ServerStorage.SustosBloques).all()  ó  .build("Momia")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Config)
local Rig = require(RS.Rig)

local B = {}
local V = Vector3.new
local C = Color3.fromRGB
local M = Enum.Material
local function R(x, y, z)
	return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end
B.R, B.V, B.C = R, V, C

---------- Piezas ----------
-- o = {size, at (Vector3 o CFrame), rot, color, mat, name, shape ("Ball" | "Cyl"), axis ("Y" por defecto | "X" | "Z"),
--   wedge, corner, neon, t (transparencia visible), hidden (invisible hasta el susto), refl, shadow = false, collide}
-- Los cilindros se dan con su tamaño "de pie": size = (diámetro, alto, diámetro).
local function mk(o)
	local p
	local size, extra = o.size, CFrame.identity
	if o.wedge then
		p = Instance.new("WedgePart")
	elseif o.corner then
		p = Instance.new("CornerWedgePart")
	else
		p = Instance.new("Part")
		if o.shape == "Ball" then
			p.Shape = Enum.PartType.Ball
		elseif o.shape == "Cyl" then
			p.Shape = Enum.PartType.Cylinder
			local axis = o.axis or "Y"
			if axis == "Y" then
				size, extra = V(o.size.Y, o.size.X, o.size.Z), R(0, 0, 90)
			elseif axis == "Z" then
				size, extra = V(o.size.Z, o.size.Y, o.size.X), R(0, 90, 0)
			end
		end
	end
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, o.collide == true, false, true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = o.neon and M.Neon or o.mat or M.Plastic -- (Plastic, como los sustos de siempre: SmoothPlastic brilla demasiado)
	p.Color = o.color or C(200, 200, 200)
	p.Size = size
	p.CastShadow = o.shadow ~= false and o.size.X * o.size.Y * o.size.Z > 0.2
	p.Name = o.name or "Part"
	if o.t then
		p:SetAttribute("T", o.t)
		p.Transparency = o.t
	end
	if o.hidden then
		p:SetAttribute("T", o.t or 0)
		p.Transparency = 1
	end
	if o.refl then
		p.Reflectance = o.refl
	end
	local cf = typeof(o.at) == "CFrame" and o.at or CFrame.new(o.at or Vector3.zero)
	if o.rot then
		cf *= o.rot
	end
	return p, cf * extra
end

-- Atrezo quieto (directamente en el modelo del susto)
local function prop(m, o)
	local p, cf = mk(o)
	p.CFrame = cf
	p.Parent = m
	return p
end
B.prop = prop

---------- Criaturas ----------
local function newRig(name, origin)
	local m = Instance.new("Model")
	m.Name = name or "Creature"
	local root = mk({size = V(0.4, 0.4, 0.4), name = "Root", shadow = false})
	root.Transparency = 1
	root.CanQuery = false
	root.CFrame = origin or CFrame.new()
	root.Parent = m
	m.PrimaryPart = root
	return {m = m, root = root, o = origin or CFrame.new()}
end
B.newRig = newRig

-- Articulación: pivote (en reposo, respecto a Root), padre (si no es de las de siempre) y pose de reposo (grados)
local function joint(c, name, pivot, parent, idle)
	c.m:SetAttribute("J_" .. name, pivot)
	if parent then
		c.m:SetAttribute("Par_" .. name, parent)
	end
	if idle then
		c.m:SetAttribute("P_" .. name, idle)
	end
end
B.joint = joint

-- Dónde queda la articulación 'limb' en la pose de reposo (P_), respecto a Root
local PARENT = {Torso = "Root", Head = "Torso", ArmL = "Torso", ArmR = "Torso", LegL = "Root", LegR = "Root"}
local function idleWorld(c, limb)
	if limb == "Root" then
		return CFrame.identity
	end
	local j = c.m:GetAttribute("J_" .. limb) or Vector3.zero
	local p = c.m:GetAttribute("P_" .. limb) or Vector3.zero
	local par = c.m:GetAttribute("Par_" .. limb) or PARENT[limb] or "Root"
	return idleWorld(c, par) * CFrame.new(j) * R(p.X, p.Y, p.Z) * CFrame.new(-j)
end

-- Pieza de la criatura que va con la articulación 'limb' (o.at: en el espacio de Root, en reposo; con o.posed, o.at
-- es dónde se ve en la pose de reposo: para lo que se sujeta con la mano y cosas así)
local function piece(c, limb, o)
	local p, cf = mk(o)
	if o.posed then
		cf = idleWorld(c, limb):Inverse() * cf
	end
	p:SetAttribute("Limb", limb)
	p:SetAttribute("Rest", cf)
	p.CFrame = c.o * cf
	p.Parent = c.m
	return p
end
B.piece = piece

-- Rasgos sobre la cara delantera (-Z) de una caja: {dx, dy, ancho, alto, color, opciones}
local function face(c, limb, center, size, list)
	local z = center.Z - size.Z / 2 - 0.025
	local out = {}
	for _, d in list do
		local o = table.clone(d[6] or {})
		o.size = V(d[3], d[4], o.depth or 0.06)
		o.depth = nil
		o.at = CFrame.new(center.X + d[1], center.Y + d[2], z - (o.out or 0)) * (o.rot or CFrame.identity)
		o.rot, o.out = nil, nil
		o.color = d[5]
		o.shadow = false
		table.insert(out, piece(c, limb, o))
	end
	return out
end
B.face = face

-- Robloxiano de bloques. o: {hip, torso, head, arm, leg (Vector3), shirt, pants, skin, arms, hands, mat, idle = {Torso...}}
local function humanoid(c, o)
	local T, H, A, L = o.torso, o.head, o.arm, o.leg
	local hip = o.hip or L.Y
	local top = hip + T.Y
	local sh = top - 0.2
	local ax = T.X / 2 + A.X / 2 + (o.armGap or 0)
	local idle = o.idle or {}
	joint(c, "Torso", V(0, hip, 0), nil, idle.Torso)
	joint(c, "Head", V(0, top, 0), nil, idle.Head)
	joint(c, "ArmL", V(-ax, sh, 0), nil, idle.ArmL)
	joint(c, "ArmR", V(ax, sh, 0), nil, idle.ArmR)
	joint(c, "LegL", V(-L.X / 2, hip, 0), nil, idle.LegL)
	joint(c, "LegR", V(L.X / 2, hip, 0), nil, idle.LegR)
	local parts = {}
	parts.Torso = piece(c, "Torso", {size = T, at = V(0, hip + T.Y / 2, 0), color = o.shirt, mat = o.mat, name = "Torso"})
	if not o.noHead then
		parts.Head = piece(c, "Head", {size = H, at = V(0, top + H.Y / 2, 0), color = o.skin, mat = o.headMat or o.mat, name = "Head"})
	end
	local hand = o.hands and (o.handH or 0.55) or 0
	for s = -1, 1, 2 do
		local an = s < 0 and "ArmL" or "ArmR"
		parts[an] = piece(c, an, {size = V(A.X, A.Y - hand, A.Z), at = V(s * ax, top - (A.Y - hand) / 2, 0), color = o.arms or o.shirt, mat = o.mat, name = an})
		if hand > 0 then
			parts[an .. "Hand"] = piece(c, an, {size = V(A.X * 0.94, hand, A.Z * 0.94), at = V(s * ax, top - A.Y + hand / 2, 0), color = o.hands, mat = o.handMat or o.mat, name = an .. "Hand"})
		end
		if not o.noLegs then
			local ln = s < 0 and "LegL" or "LegR"
			parts[ln] = piece(c, ln, {size = L, at = V(s * L.X / 2, hip - L.Y / 2, 0), color = o.pants, mat = o.legMat or o.mat, name = ln})
		end
	end
	return {hip = hip, top = top, sh = sh, ax = ax, hc = V(0, top + H.Y / 2, 0), hs = H, parts = parts, T = T, A = A, L = L}
end
B.humanoid = humanoid

---------- Luces y partículas ----------
-- (atenuadas x0.45 de brillo y x0.85 de alcance: sin sombras, a toda potencia quemaban en blanco las piezas cercanas.
-- Las plantillas de Assets.Scares ya están así; los flares de ScareBehaviors aplican lo mismo)
local function light(parent, color, range, bright, enabled, name)
	local l = Instance.new("PointLight")
	l.Name = name or "Glow"
	l.Color, l.Range, l.Brightness, l.Shadows = color, range * 0.85, bright * 0.45, false
	l.Enabled = enabled ~= false
	l.Parent = parent
	return l
end
B.light = light

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0
	for k, v in props do
		e[k] = v
	end
	e.Parent = parent
	return e
end
B.emitter = emitter

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
B.SPARK, B.SMOKE, B.FIRE = SPARK, SMOKE, FIRE

local function mist(parent, color, rate, name)
	return emitter(parent, {
		Name = name or "Mist", Texture = SMOKE, Color = ColorSequence.new(color), Rate = rate or 4, Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(0.3, 1), SpreadAngle = Vector2.new(180, 30), LightEmission = 0.6,
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.7), NumberSequenceKeypoint.new(1, 1)}),
	})
end
B.mist = mist

local function sparkles(parent, color, rate, name)
	return emitter(parent, {
		Name = name or "Sparkles", Texture = SPARK, Color = ColorSequence.new(color), Rate = rate or 6, Lifetime = NumberRange.new(0.8, 1.5),
		Speed = NumberRange.new(0.5, 2), SpreadAngle = Vector2.new(180, 180), LightEmission = 1,
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0)}),
	})
end
B.sparkles = sparkles

local function flame(parent, color, size, name)
	return emitter(parent, {
		Name = name or "Flame", Texture = FIRE, Color = ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 0.7), 0.5)), Rate = 22, Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(1, 2), SpreadAngle = Vector2.new(8, 8), LightEmission = 1, Acceleration = Vector3.new(0, 3, 0),
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, size or 0.5), NumberSequenceKeypoint.new(1, 0)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)}),
	})
end
B.flame = flame

-- Ráfaga (Rate 0: solo con :Emit) para los sustos
local function burst(parent, color, name, size, speed, texture)
	return emitter(parent, {
		Name = name or "Burst", Texture = texture or SPARK, Color = ColorSequence.new(color), Rate = 0, Lifetime = NumberRange.new(0.5, 1),
		Speed = NumberRange.new(speed or 6, (speed or 6) * 1.8), SpreadAngle = Vector2.new(180, 180), LightEmission = 0.8, Drag = 3,
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, size or 0.5), NumberSequenceKeypoint.new(1, 0)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)}),
	})
end
B.burst = burst

-- Punto invisible (para luces y partículas); en una criatura va con su articulación
local function anchor(m, name, pos, c, limb)
	local o = {size = V(0.2, 0.2, 0.2), at = pos, name = name, shadow = false}
	local p
	if c then
		p = piece(c, limb, o)
	else
		p = prop(m, o)
	end
	p.Transparency = 1
	p.CanQuery = false
	return p
end
B.anchor = anchor

-- Puñado de paja (o pelo, o plumas): n palitos alrededor de 'at' que apuntan hacia dir
local function tuft(c, limb, at, n, spread, dir, colors, len, thick)
	for k = 1, n do
		local a = k / n * math.pi * 2
		local off = V(math.cos(a) * spread, 0, math.sin(a) * spread)
		local l = (len or 0.55) * (0.8 + (k % 3) * 0.2)
		local d = (dir + off * 0.6).Unit
		local cf = CFrame.lookAt(at + off, at + off + d) * CFrame.new(0, 0, -l / 2) * R(0, 0, k * 37)
		piece(c, limb, {size = V(thick or 0.14, thick or 0.14, l), at = cf, color = colors[k % #colors + 1], mat = M.Fabric, shadow = false})
	end
end
B.tuft = tuft

---------- Modelo y remate ----------
local function model(t)
	local m = Instance.new("Model")
	m.Name = t
	return m
end
B.model = model

-- Hitbox (huella en el suelo, como los demás sustos), Solid (si es sólido: choca con quien pasa), la pose de reposo de
-- cada criatura y el pivote en el suelo
-- Agranda todo (piezas, reposo de las criaturas, pivotes y luces) k veces respecto al pivote del suelo
local function grow(m, k)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Size *= k
			d.CFrame = d.CFrame.Rotation + d.CFrame.Position * k
			local rest = d:GetAttribute("Rest")
			if rest then
				d:SetAttribute("Rest", rest.Rotation + rest.Position * k)
			end
		elseif d:IsA("Model") then
			for name, v in d:GetAttributes() do
				if name:sub(1, 2) == "J_" or name == "Hook" then
					d:SetAttribute(name, v * k)
				end
			end
		elseif d:IsA("Light") then
			d.Range *= k
		end
	end
end
B.grow = grow

local function finish(m, t, rigs, scale)
	local def = Config.Scares[t]
	for _, c in rigs do
		c.m.Parent = m
	end
	if scale then
		grow(m, scale)
	end
	local hb = prop(m, {size = V(def.size.X, 3, def.size.Y), at = V(0, 1.5, 0), name = "Hitbox", shadow = false})
	hb.Transparency = 1
	-- los legendarios de la ruleta brillan aunque estén quietos: chispas que suben del suelo (los míticos, rosas).
	-- (Sin disco de neón en el suelo: parecía una base y deslumbraba)
	if def.cat == "Legendario" and def.wheel then
		local col = def.mythic and C(255, 120, 220) or C(255, 196, 60)
		local r = math.max(def.size.X, def.size.Y) * 0.95
		local host = prop(m, {size = V(r * 0.8, 0.2, r * 0.8), at = V(0, 0.2, 0), name = "AuraFX", shadow = false})
		host.Transparency = 1
		host.CanQuery = false
		emitter(host, {
			Name = "Rise", Texture = SPARK, Color = ColorSequence.new(col, C(255, 255, 255)), Rate = def.mythic and 12 or 7, Lifetime = NumberRange.new(1.4, 2.2),
			Speed = NumberRange.new(1.2, 2.6), SpreadAngle = Vector2.new(15, 15), LightEmission = 1, Acceleration = V(0, 0.8, 0),
			Size = NumberSequence.new({NumberSequenceKeypoint.new(0, def.mythic and 0.45 or 0.35), NumberSequenceKeypoint.new(1, 0)}),
			EmissionDirection = Enum.NormalId.Top,
		})
	end
	if def.solid then
		local s = prop(m, {size = V(math.max(0.5, def.size.X - 0.4), 6, math.max(0.5, def.size.Y - 0.4)), at = V(0, 3, 0), name = "Solid", shadow = false, collide = true})
		s.Transparency = 1
		s.CanQuery = false
	end
	for _, c in rigs do
		c.m.Parent = m
	end
	m.WorldPivot = CFrame.new()
	return m
end
B.finish = finish

local BUILD = {}
B.BUILD = BUILD

---------- Colores comunes ----------
local WOOD, WOOD_D = C(116, 78, 46), C(84, 56, 34)
local BURLAP = C(206, 170, 112)
local STRAW = {C(240, 204, 92), C(214, 168, 64), C(250, 222, 120)}
local INK = C(28, 18, 14)
local BONE, BONE_D = C(222, 212, 188), C(186, 174, 148)

-- Calabaza de bloques con cara tallada (que brilla): cf = centro, k = tamaño. Va al rig (c, limb) o al modelo (m).
local function pumpkin(where, limb, cf, k, glow, name, posed)
	local add = function(o)
		o.posed = posed
		local p = limb and piece(where, limb, o) or prop(where, o)
		if name then
			p:SetAttribute("Group", name)
		end
		return p
	end
	local ORANGE, ORANGE_D = C(240, 132, 32), C(204, 100, 22)
	local body = add({size = V(1.2, 1, 1.15) * k, at = cf, color = ORANGE, name = name or "Pumpkin"})
	for s = -1, 1, 2 do
		add({size = V(0.3, 0.9, 1.0) * k, at = cf * CFrame.new(V(s * 0.62, 0, 0) * k), color = ORANGE_D})
	end
	add({size = V(0.18, 0.35, 0.18) * k, at = cf * CFrame.new(V(0, 0.62, 0) * k) * R(0, 0, 12), color = C(80, 110, 40)})
	local face = glow and C(255, 214, 80) or C(40, 20, 10)
	local z = -0.585 * k
	for s = -1, 1, 2 do
		add({wedge = true, size = V(0.06, 0.22, 0.26) * k, at = cf * CFrame.new(V(s * 0.28, 0.16, 0) * k + V(0, 0, z)) * R(90, 90, 0), color = face, neon = glow, shadow = false, name = "Face"})
	end
	add({size = V(0.62, 0.14, 0.06) * k, at = cf * CFrame.new(V(0, -0.2, 0) * k + V(0, 0, z)), color = face, neon = glow, shadow = false, name = "Face"})
	for x = -1, 1, 2 do
		add({size = V(0.12, 0.12, 0.065) * k, at = cf * CFrame.new(V(x * 0.14, -0.1, 0) * k + V(0, 0, z)), color = ORANGE, shadow = false})
	end
	return body
end
B.pumpkin = pumpkin

-- Pájaro de bloques (el cuervo del espantapájaros y el Cuervo). Articulaciones <p>Body, <p>Head, <p>Beak (pico de
-- abajo), <p>WingL, <p>WingR, <p>Tail. at: entre las patas; k: escala.
local function bird(c, p, at, k, col, eyeCol)
	local function v(x, y, z)
		return at + V(x, y, z) * k
	end
	local body, head, beak, wl, wr, tail = p .. "Body", p .. "Head", p .. "Beak", p .. "WingL", p .. "WingR", p .. "Tail"
	joint(c, body, v(0, 0.25, 0), "Root", V(-6, 0, 0))
	joint(c, head, v(0, 1.15, -0.35), body, V(8, 0, 0))
	joint(c, beak, v(0, 1.3, -0.8), head, V(0, 0, 0))
	joint(c, wl, v(-0.45, 1.1, -0.2), body, V(0, 0, 0))
	joint(c, wr, v(0.45, 1.1, -0.2), body, V(0, 0, 0))
	joint(c, tail, v(0, 0.55, 0.55), body, V(0, 0, 0))
	local DARK = col:Lerp(Color3.new(0, 0, 0), 0.3)
	local SHEEN = col:Lerp(C(96, 84, 150), 0.4)
	local LEG = C(44, 40, 46)
	for s = -1, 1, 2 do
		piece(c, body, {size = V(0.13, 0.42, 0.13) * k, at = v(s * 0.2, 0.21, 0), color = LEG})
		for d = -1, 1 do
			piece(c, body, {size = V(0.08, 0.07, 0.36) * k, at = CFrame.new(v(s * 0.2, 0.035, -0.12)) * R(0, d * 28, 0), color = LEG, shadow = false})
		end
	end
	piece(c, body, {size = V(0.95, 0.9, 1.3) * k, at = CFrame.new(v(0, 0.78, 0.05)) * R(-14, 0, 0), color = col, name = "Body"})
	piece(c, body, {size = V(0.78, 0.62, 0.45) * k, at = CFrame.new(v(0, 0.9, -0.48)) * R(-32, 0, 0), color = SHEEN})
	-- cabeza con cresta, pico y ojos que brillan
	local hc = v(0, 1.45, -0.6)
	piece(c, head, {size = V(0.78, 0.72, 0.82) * k, at = hc, color = col, name = "Head"})
	piece(c, head, {size = V(0.5, 0.22, 0.55) * k, at = hc + V(0, 0.42, 0.12) * k, color = DARK})
	piece(c, head, {size = V(0.6, 0.3, 0.3) * k, at = hc + V(0, -0.38, -0.1) * k, color = SHEEN})
	piece(c, head, {wedge = true, size = V(0.3, 0.26, 0.75) * k, at = hc + V(0, 0.02, -0.78) * k, color = C(46, 44, 52), name = "Beak"})
	piece(c, beak, {wedge = true, size = V(0.26, 0.14, 0.6) * k, at = CFrame.new(hc + V(0, -0.18, -0.7) * k) * R(0, 0, 180), color = C(34, 32, 38)})
	for s = -1, 1, 2 do
		piece(c, head, {size = V(0.06, 0.2, 0.22) * k, at = hc + V(s * 0.4, 0.1, -0.18) * k, color = eyeCol, neon = true, name = "Eye", shadow = false})
	end
	-- alas plegadas con sus plumas largas
	for s = -1, 1, 2 do
		local w = s < 0 and wl or wr
		piece(c, w, {size = V(0.14, 0.8, 1.25) * k, at = CFrame.new(v(s * 0.53, 0.72, 0.22)) * R(-16, 0, 0), color = DARK, name = "Wing"})
		for f = 1, 3 do
			piece(c, w, {size = V(0.1, 0.2, 0.6) * k, at = CFrame.new(v(s * 0.53, 0.42 + f * 0.1, 0.9 + f * 0.06)) * R(-26 + f * 7, 0, 0), color = f == 2 and SHEEN or col, shadow = false})
		end
	end
	-- cola en abanico
	for d = -1, 1 do
		piece(c, tail, {size = V(0.24, 0.09, 0.85) * k, at = CFrame.new(v(d * 0.16, 0.42, 1.0)) * R(28, d * 14, 0), color = d == 0 and DARK or col, shadow = false})
	end
end
B.bird = bird

---------- Criaturas ----------
-- ESPANTAPÁJAROS: colgado de su poste, con camisa de cuadros remendada, saco por cabeza, sombrero picudo y un cuervo
-- en el travesaño. Al asustar: gira la cabeza, le arden los ojos y se arranca del poste agitando los brazos.
function BUILD.Espantapajaros()
	local m = model("Espantapajaros")
	prop(m, {size = V(0.5, 7.2, 0.5), at = V(0, 3.6, 0.55), color = WOOD, mat = M.Wood, name = "Pole"})
	prop(m, {size = V(4.4, 0.42, 0.42), at = V(0, 5.0, 0.55), color = WOOD_D, mat = M.Wood, name = "Bar"})
	for s = -1, 1, 2 do
		prop(m, {size = V(0.5, 0.18, 0.5), at = V(s * 1.9, 5.0, 0.55), color = C(196, 160, 96), mat = M.Fabric})
	end
	prop(m, {shape = "Cyl", size = V(2.6, 0.3, 2.6), at = V(0, 0.15, 0.3), color = C(76, 56, 38), mat = M.Ground})
	for k = 1, 5 do
		local a = k * 1.25
		prop(m, {size = V(0.5, 0.35, 0.45), at = CFrame.new(math.cos(a) * 1.1, 0.3, 0.3 + math.sin(a) * 1.0) * R(0, k * 50, 8), color = C(104, 98, 92), mat = M.Slate})
	end
	pumpkin(m, nil, CFrame.new(-0.95, 0.55, -0.7) * R(0, 25, 0), 0.75, false)
	local c = newRig()
	local hip = 3.5
	local SHIRT, PLAID, PANTS, ROPE = C(184, 68, 52), C(112, 36, 32), C(70, 92, 142), C(204, 170, 104)
	local h = humanoid(c, {hip = hip, torso = V(2.1, 2.1, 1.1), head = V(1.7, 1.7, 1.5), arm = V(0.95, 2.0, 0.95), leg = V(0.95, 1.8, 0.95),
		shirt = SHIRT, pants = PANTS, skin = BURLAP, mat = M.Fabric,
		idle = {Head = V(-4, 0, 14), ArmL = V(4, 0, -58), ArmR = V(-4, 0, 48), LegL = V(6, 0, -4), LegR = V(-8, 0, 5)}})
	local tc = V(0, hip + 1.05, 0)
	for _, y in {-0.5, 0.35} do
		piece(c, "Torso", {size = V(2.14, 0.16, 1.14), at = tc + V(0, y, 0), color = PLAID, mat = M.Fabric, shadow = false})
	end
	for _, x in {-0.5, 0.45} do
		piece(c, "Torso", {size = V(0.16, 2.14, 1.14), at = tc + V(x, 0, 0), color = PLAID, mat = M.Fabric, shadow = false})
	end
	piece(c, "Torso", {size = V(0.62, 0.56, 0.06), at = CFrame.new(tc + V(0.48, -0.42, -0.58)) * R(0, 0, 8), color = C(80, 120, 176), mat = M.Fabric})
	for k = -1, 1, 2 do
		piece(c, "Torso", {size = V(0.06, 0.62, 0.07), at = CFrame.new(tc + V(0.48 + k * 0.27, -0.42, -0.6)) * R(0, 0, 8), color = INK, shadow = false})
	end
	for k = 0, 2 do
		piece(c, "Torso", {size = V(0.16, 0.16, 0.06), at = tc + V(-0.1, 0.65 - k * 0.45, -0.58), color = C(230, 210, 160), shadow = false})
	end
	piece(c, "Torso", {size = V(2.2, 0.22, 1.2), at = V(0, hip + 0.15, 0), color = ROPE, mat = M.Fabric})
	piece(c, "Torso", {size = V(0.3, 0.5, 0.12), at = CFrame.new(-0.4, hip - 0.05, -0.6) * R(0, 0, 20), color = ROPE, mat = M.Fabric})
	tuft(c, "Torso", V(-0.2, hip + 0.1, -0.35), 6, 0.6, V(0, -1, -0.4).Unit, STRAW, 0.6)
	tuft(c, "Torso", V(0, hip + 2.05, 0), 6, 0.55, V(0, 0.4, -1).Unit, STRAW, 0.45)
	for s = -1, 1, 2 do
		local an = s < 0 and "ArmL" or "ArmR"
		local ax = s * h.ax
		piece(c, an, {size = V(1.0, 0.16, 1.0), at = V(ax, h.top - 0.55, 0), color = PLAID, mat = M.Fabric, shadow = false})
		piece(c, an, {size = V(1.02, 0.22, 1.02), at = V(ax, h.top - 1.8, 0), color = ROPE, mat = M.Fabric})
		tuft(c, an, V(ax, h.top - 1.95, 0), 7, 0.28, V(0, -1, 0), STRAW, 0.6)
		local ln = s < 0 and "LegL" or "LegR"
		piece(c, ln, {size = V(1.0, 0.2, 1.0), at = V(s * 0.475, hip - 1.6, 0), color = ROPE, mat = M.Fabric})
		tuft(c, ln, V(s * 0.475, hip - 1.75, 0), 6, 0.26, V(0, -1, 0), STRAW, 0.55)
	end
	piece(c, "LegR", {size = V(0.55, 0.5, 0.06), at = CFrame.new(0.5, hip - 0.8, -0.5) * R(0, 0, -10), color = C(200, 120, 60), mat = M.Fabric})
	-- cabeza de saco: atada al cuello, ojos y boca cosidos
	local hc = h.hc
	piece(c, "Head", {size = V(1.1, 0.3, 1.0), at = hc + V(0, -0.95, 0), color = BURLAP, mat = M.Fabric})
	piece(c, "Head", {size = V(1.18, 0.16, 1.08), at = hc + V(0, -0.92, 0), color = C(150, 110, 60), mat = M.Fabric})
	face(c, "Head", hc, h.hs, {
		{-0.4, 0.26, 0.46, 0.34, INK, {name = "Eye", rot = R(0, 0, 14)}}, {0.4, 0.26, 0.46, 0.34, INK, {name = "Eye", rot = R(0, 0, -14)}},
		{-0.4, 0.12, 0.24, 0.2, INK, {name = "Eye"}}, {0.4, 0.12, 0.24, 0.2, INK, {name = "Eye"}},
		{0, -0.06, 0.22, 0.22, C(122, 80, 40), {depth = 0.14, out = 0.04}},
		{0, -0.42, 1.04, 0.08, INK},
		{-0.42, -0.42, 0.07, 0.3, INK, {rot = R(0, 0, 15)}}, {-0.21, -0.42, 0.07, 0.3, INK, {rot = R(0, 0, 15)}}, {0, -0.42, 0.07, 0.3, INK, {rot = R(0, 0, 15)}},
		{0.21, -0.42, 0.07, 0.3, INK, {rot = R(0, 0, 15)}}, {0.42, -0.42, 0.07, 0.3, INK, {rot = R(0, 0, 15)}},
		{0.62, 0.55, 0.3, 0.06, INK, {rot = R(0, 0, 40)}}, {0.62, 0.55, 0.06, 0.3, INK, {rot = R(0, 0, 40)}},
	})
	light(h.parts.Head, C(255, 140, 30), 10, 2, false, "EyeLight")
	-- sombrero picudo y doblado
	local hy = hc.Y + 0.86
	piece(c, "Head", {shape = "Cyl", size = V(3.1, 0.16, 3.1), at = V(0, hy, 0), color = C(150, 116, 66), mat = M.Fabric, name = "Brim"})
	local cf, prev = CFrame.new(0, hy + 0.08, 0.05), 0
	for k, s in {{1.75, 0.5, 0}, {1.48, 0.48, 8}, {1.18, 0.46, 14}, {0.86, 0.42, 22}, {0.56, 0.4, 32}, {0.3, 0.34, 40}} do
		cf = cf * CFrame.new(0, prev / 2, 0) * R(-3, 0, -s[3] * 0.45) * CFrame.new(0, s[2] / 2, 0)
		piece(c, "Head", {size = V(s[1], s[2], s[1]), at = cf, color = k % 2 == 0 and C(138, 104, 58) or C(160, 124, 72), mat = M.Fabric})
		prev = s[2]
	end
	piece(c, "Head", {size = V(1.8, 0.22, 1.8), at = V(0, hy + 0.2, 0.05), color = C(130, 40, 40), mat = M.Fabric})
	tuft(c, "Head", V(0, hy - 0.05, 0), 9, 1.1, V(0, -0.5, 0), STRAW, 0.5)
	-- el cuervo del travesaño (mueve la cabeza y sale volando al asustar)
	bird(c, "Crow", V(2.05, 5.21, 0.72), 0.6, C(32, 30, 40), C(255, 70, 50))
	local eyes = anchor(m, "Eyes", hc, c, "Head")
	burst(eyes, C(255, 170, 60), "Embers", 0.35, 5)
	burst(anchor(m, "Straw", tc, c, "Torso"), C(240, 204, 92), "StrawBurst", 0.4, 9).Texture = SPARK
	return finish(m, "Espantapajaros", {c})
end

-- MOMIA: vendada de pies a cabeza delante de su sarcófago dorado abierto; un ojo verde le brilla entre las vendas.
function BUILD.Momia()
	local m = model("Momia")
	local GOLD, LAPIS, DARK, RED = C(228, 178, 62), C(44, 76, 168), C(34, 26, 24), C(170, 50, 40)
	local z = 1.25
	prop(m, {size = V(2.9, 6.6, 0.3), at = V(0, 3.3, z + 0.34), color = GOLD, mat = M.Metal})
	prop(m, {size = V(2.35, 6.0, 0.05), at = V(0, 3.2, z + 0.17), color = DARK})
	for s = -1, 1, 2 do
		prop(m, {size = V(0.3, 6.6, 0.8), at = V(s * 1.3, 3.3, z), color = GOLD, mat = M.Metal})
		for k = 0, 4 do
			prop(m, {size = V(0.32, 0.22, 0.82), at = V(s * 1.3, 0.9 + k * 1.2, z), color = k % 2 == 0 and LAPIS or RED, shadow = false})
		end
		for k = 0, 3 do
			prop(m, {size = V(0.06, 0.32, 0.18), at = V(s * 1.47, 1.5 + k * 1.2, z - 0.2 + (k % 2) * 0.25), color = DARK, shadow = false})
		end
	end
	prop(m, {size = V(2.9, 0.35, 0.8), at = V(0, 6.45, z), color = GOLD, mat = M.Metal})
	prop(m, {size = V(2.9, 0.3, 0.8), at = V(0, 0.15, z), color = GOLD, mat = M.Metal})
	-- tocado del faraón arriba, con el ojo
	prop(m, {size = V(3.3, 0.55, 0.95), at = V(0, 6.9, z), color = LAPIS, mat = M.Metal})
	for k = -2, 2 do
		prop(m, {size = V(0.3, 0.57, 0.97), at = V(k * 0.62, 6.9, z), color = GOLD, mat = M.Metal, shadow = false})
	end
	prop(m, {size = V(0.9, 0.3, 0.1), at = V(0, 7.35, z - 0.45), color = GOLD, mat = M.Metal})
	prop(m, {size = V(0.35, 0.2, 0.06), at = V(0, 7.35, z - 0.52), color = LAPIS, shadow = false})
	-- vasos canópicos a los lados
	for s = -1, 1, 2 do
		prop(m, {size = V(0.55, 0.8, 0.55), at = V(s * 1.15, 0.4, -0.95), color = C(214, 196, 150), mat = M.Slate})
		prop(m, {size = V(0.45, 0.35, 0.45), at = V(s * 1.15, 0.97, -0.95), color = s < 0 and C(60, 90, 160) or C(196, 150, 60)})
	end
	-- la momia
	local c = newRig()
	local BAND, BAND2, BAND3 = C(226, 212, 172), C(186, 168, 126), C(206, 190, 150)
	local h = humanoid(c, {torso = V(2, 2.1, 1.05), head = V(1.55, 1.55, 1.4), arm = V(0.95, 2.35, 0.95), leg = V(1, 2.1, 1), shirt = BAND, pants = BAND, skin = BAND, mat = M.Fabric,
		idle = {Torso = V(-10, 0, 4), Head = V(12, 0, -14), ArmL = V(84, 6, -6), ArmR = V(68, -8, 10), LegL = V(10, 0, 0), LegR = V(-6, 0, 0)}})
	local function wraps(limb, center, size, n, seed)
		for k = 1, n do
			local y = center.Y - size.Y / 2 + size.Y * (k - 0.5) / n
			piece(c, limb, {size = V(size.X + 0.06, 0.13, size.Z + 0.06), at = CFrame.new(center.X, y, center.Z) * R(((k + seed) % 3 - 1) * 2, 0, ((k + seed) % 2 == 0 and 1 or -1) * (3 + (k * 3) % 5)),
				color = (k + seed) % 2 == 0 and BAND2 or BAND3, mat = M.Fabric, shadow = false})
		end
	end
	wraps("Torso", V(0, h.hip + 1.05, 0), h.T, 5, 0)
	wraps("Head", h.hc, h.hs, 3, 1)
	for s = -1, 1, 2 do
		wraps(s < 0 and "ArmL" or "ArmR", V(s * h.ax, h.top - 1.175, 0), h.A, 5, s + 2)
		wraps(s < 0 and "LegL" or "LegR", V(s * 0.5, 1.05, 0), h.L, 4, s + 5)
	end
	-- vendas sueltas que cuelgan
	for s = -1, 1, 2 do
		local an = s < 0 and "ArmL" or "ArmR"
		local wrist = (idleWorld(c, an) * CFrame.new(s * h.ax, h.top - 1.9, 0)).Position
		piece(c, an, {size = V(0.36, s < 0 and 1.1 or 1.6, 0.06), at = CFrame.new(wrist + V(s * 0.2, s < 0 and -0.55 or -0.8, 0.1)) * R(0, 20, s * 6), color = s < 0 and BAND3 or BAND2, mat = M.Fabric, posed = true})
	end
	piece(c, "Torso", {size = V(0.3, 1.4, 0.06), at = CFrame.new(-0.55, h.hip - 0.45, -0.56) * R(0, 0, -8), color = BAND2, mat = M.Fabric})
	piece(c, "Head", {size = V(0.26, 1.2, 0.06), at = CFrame.new(0.55, h.hc.Y - 0.6, 0.72) * R(0, 0, 12), color = BAND3, mat = M.Fabric})
	-- cara: franja oscura de los ojos, uno que brilla verde y la boca entreabierta
	face(c, "Head", h.hc, h.hs, {
		{0, 0.18, 1.2, 0.36, DARK},
		{-0.3, 0.18, 0.28, 0.24, C(120, 255, 140), {neon = true, name = "Eye", out = 0.01}},
		{0.32, 0.18, 0.24, 0.16, C(70, 50, 40), {out = 0.01}},
		{0.05, -0.38, 0.5, 0.16, DARK},
		{-0.3, 0.42, 0.5, 0.14, BAND2, {rot = R(0, 0, 10), out = 0.02}},
	})
	local eye = anchor(m, "Eye", h.hc + V(-0.3, 0.18, -0.8), c, "Head")
	light(eye, C(110, 255, 140), 7, 1.6, true)
	burst(anchor(m, "Dust", V(0, 2.5, 0), c, "Torso"), C(214, 196, 150), "DustBurst", 1.2, 5).Texture = SMOKE
	mist(anchor(m, "Feet", V(0, 0.3, 0)), C(200, 180, 140), 2, "Dust")
	return finish(m, "Momia", {c})
end

-- BRUJA: de piel verde, con su sombrero picudo, removiendo un caldero que burbujea. Al asustar suelta una carcajada y
-- te lanza una poción.
function BUILD.Bruja()
	local m = model("Bruja")
	local POT, POT2 = C(46, 44, 54), C(66, 64, 76)
	local cz = -0.95
	prop(m, {size = V(2.3, 1.45, 2.3), at = V(0, 1.1, cz), color = POT, mat = M.Metal, name = "Cauldron"})
	for s = -1, 1, 2 do
		prop(m, {size = V(2.62, 0.28, 0.3), at = V(0, 1.88, cz + s * 1.16), color = POT2, mat = M.Metal})
		prop(m, {size = V(0.3, 0.28, 2.62), at = V(s * 1.16, 1.88, cz), color = POT2, mat = M.Metal})
	end
	prop(m, {size = V(1.9, 0.3, 1.9), at = V(0, 0.42, cz), color = POT, mat = M.Metal})
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2 + 0.5
		prop(m, {size = V(0.32, 0.5, 0.32), at = V(math.cos(a) * 0.85, 0.25, cz + math.sin(a) * 0.85), color = POT, mat = M.Metal})
	end
	for s = -1, 1, 2 do
		prop(m, {size = V(0.16, 0.5, 0.7), at = V(s * 1.3, 1.6, cz), color = POT2, mat = M.Metal})
	end
	prop(m, {size = V(2.08, 0.12, 2.08), at = V(0, 1.95, cz), color = C(120, 255, 90), neon = true, name = "Brew", shadow = false})
	for k = 1, 5 do
		local a = k * 1.9
		prop(m, {shape = "Ball", size = V(1, 1, 1) * (0.25 + (k % 3) * 0.1), at = V(math.cos(a) * 0.6, 2.0, cz + math.sin(a) * 0.6), color = C(90, 210, 70), name = "Bubble", shadow = false})
	end
	local pot = anchor(m, "Potion", V(0, 2.2, cz))
	light(pot, C(110, 255, 90), 12, 2)
	emitter(pot, {
		Name = "Bubbles", Texture = SPARK, Color = ColorSequence.new(C(140, 255, 110)), Rate = 8, Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(1, 2.5), SpreadAngle = Vector2.new(25, 25), LightEmission = 1,
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.05)}),
	})
	mist(pot, C(90, 200, 90), 3, "Steam")
	burst(pot, C(140, 255, 110), "Splash", 0.6, 9)
	for s = -1, 1, 2 do
		prop(m, {size = V(0.3, 0.3, 2.2), at = CFrame.new(0, 0.18, cz) * R(0, s * 40, 0), color = WOOD_D, mat = M.Wood})
	end
	local fire = anchor(m, "Fire", V(0, 0.3, cz))
	flame(fire, C(255, 140, 40), 0.8)
	light(fire, C(255, 130, 40), 8, 1.4, true, "FireLight")
	-- la bruja, detrás del caldero
	local c = newRig(nil, CFrame.new(0, 0, 0.95))
	local SKIN, DRESS, DRESS2, HAT, HAIR = C(132, 198, 98), C(98, 54, 144), C(70, 36, 106), C(52, 38, 74), C(44, 32, 56)
	local h = humanoid(c, {torso = V(2, 2.1, 1.05), head = V(1.6, 1.6, 1.45), arm = V(0.9, 2.3, 0.9), leg = V(1, 2.1, 1), shirt = DRESS, skin = SKIN, hands = SKIN,
		mat = M.Fabric, headMat = M.Plastic, handMat = M.Plastic, noLegs = true,
		idle = {Torso = V(-6, 0, 0), Head = V(8, 0, -6), ArmL = V(36, 0, -12), ArmR = V(64, 0, 14)}})
	-- falda hasta el suelo (quieta aunque se doble el torso) y botas puntiagudas
	joint(c, "Skirt", V(0, h.hip, 0), "Root")
	piece(c, "Skirt", {size = V(2.2, 0.9, 1.25), at = V(0, 1.65, 0), color = DRESS, mat = M.Fabric})
	piece(c, "Skirt", {size = V(2.5, 0.9, 1.5), at = V(0, 0.85, 0), color = DRESS2, mat = M.Fabric})
	for k = -3, 3 do
		piece(c, "Skirt", {size = V(0.36, 0.4, 1.62), at = V(k * 0.37, 0.28 - (k % 2) * 0.1, 0), color = DRESS2, mat = M.Fabric})
	end
	for s = -1, 1, 2 do
		piece(c, "Skirt", {size = V(0.5, 0.4, 0.9), at = V(s * 0.5, 0.2, -0.6), color = C(30, 26, 34)})
		piece(c, "Skirt", {wedge = true, size = V(0.4, 0.4, 0.5), at = CFrame.new(s * 0.5, 0.28, -1.25) * R(0, 180, 0) * R(0, 0, 0), color = C(30, 26, 34)})
	end
	piece(c, "Torso", {size = V(2.06, 0.3, 1.1), at = V(0, h.hip + 0.3, 0), color = C(36, 28, 40)})
	piece(c, "Torso", {size = V(0.5, 0.36, 0.08), at = V(0, h.hip + 0.3, -0.56), color = C(240, 196, 70), mat = M.Metal})
	piece(c, "Torso", {wedge = true, size = V(2.04, 0.6, 0.5), at = CFrame.new(0, h.top - 0.25, -0.3) * R(0, 180, 0), color = DRESS2, mat = M.Fabric})
	-- pelo largo y cara: nariz ganchuda con verruga, ojos amarillos y sonrisa con dientes
	local hc = h.hc
	piece(c, "Head", {size = V(1.75, 1.9, 0.5), at = hc + V(0, -0.35, 0.6), color = HAIR, mat = M.Fabric})
	for s = -1, 1, 2 do
		piece(c, "Head", {size = V(0.3, 1.7, 1.3), at = hc + V(s * 0.88, -0.25, 0.08), color = HAIR, mat = M.Fabric})
		piece(c, "Head", {size = V(0.3, 0.7, 0.4), at = CFrame.new(hc + V(s * 0.9, -1.25, 0.3)) * R(0, 0, s * 10), color = HAIR, mat = M.Fabric})
	end
	piece(c, "Head", {size = V(0.3, 0.3, 0.55), at = hc + V(0, -0.05, -0.98), color = C(112, 172, 82)})
	piece(c, "Head", {size = V(0.24, 0.26, 0.24), at = hc + V(0, -0.2, -1.2), color = C(112, 172, 82)})
	piece(c, "Head", {shape = "Ball", size = V(0.14, 0.14, 0.14), at = hc + V(0.13, 0.02, -1.0), color = C(90, 150, 70), shadow = false})
	face(c, "Head", hc, h.hs, {
		{-0.38, 0.22, 0.36, 0.26, C(255, 236, 90), {name = "Eye"}}, {0.38, 0.22, 0.36, 0.26, C(255, 236, 90), {name = "Eye"}},
		{-0.38, 0.22, 0.08, 0.24, INK, {out = 0.01}}, {0.38, 0.22, 0.08, 0.24, INK, {out = 0.01}},
		{-0.38, 0.45, 0.5, 0.1, HAIR, {rot = R(0, 0, -18), out = 0.01}}, {0.38, 0.45, 0.5, 0.1, HAIR, {rot = R(0, 0, 18), out = 0.01}},
		{0, -0.48, 0.8, 0.2, INK, {name = "Mouth"}},
		{-0.22, -0.43, 0.1, 0.1, C(250, 240, 200), {out = 0.01}}, {0.18, -0.43, 0.1, 0.1, C(250, 240, 200), {out = 0.01}},
		{0.4, -0.4, 0.16, 0.08, INK, {rot = R(0, 0, 30)}}, {-0.4, -0.4, 0.16, 0.08, INK, {rot = R(0, 0, -30)}},
	})
	-- sombrero
	local hy = hc.Y + 0.82
	piece(c, "Head", {shape = "Cyl", size = V(3.0, 0.16, 3.0), at = V(0, hy, 0), color = HAT, name = "Brim"})
	local cf, prev = CFrame.new(0, hy + 0.08, 0.05), 0
	for _, s in {{1.7, 0.6, 0}, {1.4, 0.55, 6}, {1.1, 0.55, 12}, {0.8, 0.5, 20}, {0.52, 0.45, 32}, {0.3, 0.4, 44}} do
		cf = cf * CFrame.new(0, prev / 2, 0) * R(s[3] * 0.55, 0, 0) * CFrame.new(0, s[2] / 2, 0)
		piece(c, "Head", {size = V(s[1], s[2], s[1]), at = cf, color = HAT})
		prev = s[2]
	end
	piece(c, "Head", {size = V(1.76, 0.26, 1.76), at = V(0, hy + 0.22, 0.05), color = C(130, 70, 190)})
	piece(c, "Head", {size = V(0.42, 0.34, 0.08), at = V(0, hy + 0.22, -0.85), color = C(240, 196, 70), mat = M.Metal})
	-- cucharón en la mano derecha, metido en el caldero; frasco de poción en la izquierda
	local handR = (idleWorld(c, "ArmR") * CFrame.new(h.ax, h.top - h.A.Y + 0.25, 0)).Position
	local brew = V(0.25, 1.75, cz - 0.95)
	local len = (brew - handR).Magnitude + 0.3
	piece(c, "ArmR", {size = V(0.16, 0.16, len), at = CFrame.lookAt(handR, brew) * CFrame.new(0, 0, -len / 2 + 0.25), color = WOOD, mat = M.Wood, posed = true, name = "Spoon"})
	local handL = (idleWorld(c, "ArmL") * CFrame.new(-h.ax, h.top - h.A.Y + 0.1, 0)).Position
	local flask = piece(c, "ArmL", {size = V(0.5, 0.55, 0.5), at = CFrame.new(handL + V(0, -0.15, -0.15)), color = C(120, 255, 90), neon = true, posed = true, name = "Flask", t = 0.15})
	piece(c, "ArmL", {size = V(0.2, 0.3, 0.2), at = CFrame.new(handL + V(0, 0.25, -0.15)), color = C(200, 230, 210), posed = true, mat = M.Glass, t = 0.3, name = "FlaskNeck"})
	light(flask, C(120, 255, 90), 5, 1, true, "FlaskGlow")
	return finish(m, "Bruja", {c})
end

-- HOMBRE LOBO: enorme, encorvado, con hocico, colmillos, garras y la ropa hecha jirones. Aúlla y luego ruge con las
-- garras en alto.
function BUILD.HombreLobo()
	local m = model("HombreLobo")
	local FUR, FUR_D, FUR_L, PANTS, CLAW, PINK = C(104, 90, 100), C(64, 54, 64), C(162, 148, 150), C(96, 62, 156), C(244, 240, 222), C(220, 130, 150)
	local c = newRig()
	local h = humanoid(c, {hip = 2.6, torso = V(2.8, 2.6, 1.5), head = V(1.8, 1.6, 1.7), arm = V(1.2, 3.0, 1.2), leg = V(1.25, 2.6, 1.3), shirt = FUR, pants = PANTS,
		skin = FUR, arms = FUR, hands = FUR_D, handH = 0.7, mat = M.Fabric,
		idle = {Torso = V(-20, 0, 0), Head = V(24, 0, 4), ArmL = V(34, 0, -18), ArmR = V(40, 0, 16), LegL = V(16, 0, -4), LegR = V(-6, 0, 4)}})
	-- pecho claro, melena oscura y jirones
	local tc = V(0, h.hip + 1.3, 0)
	piece(c, "Torso", {size = V(1.8, 1.5, 0.1), at = tc + V(0, 0.3, -0.78), color = FUR_L, mat = M.Fabric})
	for k = -2, 2 do
		piece(c, "Torso", {wedge = true, size = V(0.5, 0.9, 0.7), at = CFrame.new(tc + V(k * 0.55, 1.35, 0.25)) * R(90, 0, 0) * R(0, 0, k * 10), color = FUR_D, mat = M.Fabric})
	end
	for s = -1, 1, 2 do
		piece(c, "Torso", {wedge = true, size = V(0.6, 0.8, 0.9), at = CFrame.new(tc + V(s * 1.3, 1.25, 0)) * R(90, 0, 0) * R(0, 0, s * 30), color = FUR_D, mat = M.Fabric})
	end
	for k = -3, 3 do
		piece(c, "Torso", {size = V(0.36, 0.3, 1.56), at = V(k * 0.38, h.hip - 0.12 - (k % 2) * 0.12, 0), color = PANTS, mat = M.Fabric})
	end
	for s = -1, 1, 2 do
		local ln = s < 0 and "LegL" or "LegR"
		piece(c, ln, {size = V(1.0, 0.9, 1.0), at = V(s * 0.625, 0.45, 0), color = FUR, mat = M.Fabric})
		piece(c, ln, {size = V(1.2, 0.5, 1.6), at = V(s * 0.625, 0.25, -0.25), color = FUR_D, mat = M.Fabric})
		for d = -1, 1 do
			piece(c, ln, {wedge = true, size = V(0.18, 0.3, 0.38), at = V(s * 0.625 + d * 0.36, 0.15, -1.2), color = CLAW, shadow = false})
		end
		for k = -1, 1 do
			piece(c, ln, {size = V(0.4, 0.4, 1.32), at = V(s * 0.625 + k * 0.42, 0.95 - (k % 2) * 0.12, 0), color = PANTS, mat = M.Fabric})
		end
		local an = s < 0 and "ArmL" or "ArmR"
		piece(c, an, {size = V(1.26, 0.8, 1.26), at = V(s * h.ax, h.top - 0.6, 0), color = FUR_D, mat = M.Fabric})
		for d = -1, 1 do
			piece(c, an, {wedge = true, size = V(0.18, 0.55, 0.3), at = CFrame.new(s * h.ax + d * 0.36, h.top - 3.18, -0.35) * R(-90, 0, 0), color = CLAW, name = "Claw", shadow = false})
		end
	end
	-- cabeza de lobo: hocico, mandíbula (se abre), nariz, colmillos, orejas y ojos amarillos
	local hc = h.hc
	joint(c, "Jaw", hc + V(0, -0.55, -0.6), "Head")
	piece(c, "Head", {size = V(1.1, 0.75, 1.15), at = hc + V(0, -0.25, -1.35), color = FUR, mat = M.Fabric, name = "Snout"})
	piece(c, "Head", {size = V(0.95, 0.2, 1.1), at = hc + V(0, 0.18, -1.3), color = FUR_L, mat = M.Fabric})
	piece(c, "Head", {size = V(0.5, 0.36, 0.3), at = hc + V(0, 0.0, -1.95), color = C(30, 26, 30), name = "Nose"})
	piece(c, "Jaw", {size = V(1.0, 0.32, 1.05), at = hc + V(0, -0.78, -1.3), color = FUR_L, mat = M.Fabric, name = "Jaw"})
	piece(c, "Jaw", {size = V(0.8, 0.1, 0.9), at = hc + V(0, -0.6, -1.3), color = C(150, 40, 50)})
	for s = -1, 1, 2 do
		piece(c, "Head", {wedge = true, size = V(0.16, 0.36, 0.2), at = CFrame.new(hc + V(s * 0.38, -0.78, -1.82)) * R(-90, 0, 0), color = CLAW, shadow = false})
		piece(c, "Jaw", {wedge = true, size = V(0.14, 0.3, 0.18), at = CFrame.new(hc + V(s * 0.3, -0.5, -1.72)) * R(90, 0, 0), color = CLAW, shadow = false})
		piece(c, "Head", {wedge = true, size = V(0.6, 0.85, 0.42), at = CFrame.new(hc + V(s * 0.62, 1.12, 0.15)) * R(90, 0, 0) * R(0, 0, s * -12), color = FUR, mat = M.Fabric, name = "Ear"})
		piece(c, "Head", {wedge = true, size = V(0.32, 0.5, 0.1), at = CFrame.new(hc + V(s * 0.62, 1.02, -0.06)) * R(90, 0, 0) * R(0, 0, s * -12), color = PINK, shadow = false})
		piece(c, "Head", {wedge = true, size = V(0.45, 0.6, 0.6), at = CFrame.new(hc + V(s * 0.95, -0.2, 0.1)) * R(0, s * 90, 0), color = FUR_D, mat = M.Fabric})
	end
	face(c, "Head", hc, h.hs, {
		{-0.45, 0.32, 0.4, 0.2, C(255, 214, 40), {neon = true, name = "Eye", rot = R(0, 0, -12)}}, {0.45, 0.32, 0.4, 0.2, C(255, 214, 40), {neon = true, name = "Eye", rot = R(0, 0, 12)}},
		{-0.45, 0.52, 0.56, 0.14, FUR_D, {rot = R(0, 0, -22), out = 0.01}}, {0.45, 0.52, 0.56, 0.14, FUR_D, {rot = R(0, 0, 22), out = 0.01}},
	})
	-- cola peluda
	joint(c, "Tail", V(0, h.hip + 0.3, 0.7), "Torso", V(-30, 0, 0))
	piece(c, "Tail", {size = V(0.6, 0.6, 1.4), at = V(0, h.hip + 0.2, 1.35), color = FUR, mat = M.Fabric})
	piece(c, "Tail", {size = V(0.45, 0.45, 0.8), at = V(0, h.hip + 0.15, 2.3), color = FUR_D, mat = M.Fabric})
	local eyes = anchor(m, "Eyes", hc + V(0, 0.3, -0.9), c, "Head")
	light(eyes, C(255, 210, 60), 8, 1.5)
	burst(eyes, C(150, 140, 150), "Fur", 0.5, 8).Texture = SMOKE
	burst(anchor(m, "Howl", hc + V(0, -0.2, -1.9), c, "Head"), C(220, 230, 255), "Breath", 1, 6).Texture = SMOKE
	return finish(m, "HombreLobo", {c})
end

-- CUERVO: un cuervo enorme posado en un tocón seco, con ojos rojos. Abre las alas, grazna y picotea hacia ti.
function BUILD.Cuervo()
	local m = model("Cuervo")
	local BARK, BARK_D, RING = C(96, 72, 54), C(68, 52, 40), C(150, 118, 84)
	prop(m, {size = V(1.5, 3.0, 1.5), at = V(0, 1.5, 0.25), color = BARK, mat = M.Wood, name = "Stump"})
	prop(m, {size = V(1.35, 0.06, 1.35), at = V(0, 3.02, 0.25), color = RING, mat = M.Wood})
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + 0.4
		prop(m, {wedge = true, size = V(0.6, 0.7, 0.9), at = CFrame.new(math.cos(a) * 0.95, 0.35, 0.25 + math.sin(a) * 0.95) * R(0, -math.deg(a) - 90, 0), color = BARK_D, mat = M.Wood})
	end
	for s = -1, 1, 2 do
		prop(m, {size = V(0.18, 0.3, 1.0), at = CFrame.new(0.2 * s, 1.0 + s * 0.4, -0.2) * R(0, 0, 0), color = BARK_D, mat = M.Wood, shadow = false})
	end
	prop(m, {size = V(1.4, 0.32, 0.32), at = CFrame.new(1.2, 2.3, 0.25) * R(0, 0, 30), color = BARK, mat = M.Wood})
	prop(m, {size = V(0.7, 0.18, 0.18), at = CFrame.new(1.95, 2.85, 0.25) * R(0, 0, 70), color = BARK_D, mat = M.Wood})
	-- calavera a los pies
	prop(m, {size = V(0.8, 0.7, 0.75), at = CFrame.new(-0.7, 0.35, -0.85) * R(0, 20, 0), color = BONE})
	for s = -1, 1, 2 do
		prop(m, {size = V(0.2, 0.2, 0.06), at = CFrame.new(-0.7, 0.42, -0.85) * R(0, 20, 0) * CFrame.new(s * 0.18, 0, -0.38), color = INK, shadow = false})
	end
	local c = newRig()
	bird(c, "", V(0, 3.04, 0.2), 1.75, C(34, 32, 46), C(255, 40, 40))
	local eyes = anchor(m, "Eyes", V(0, 3.04 + 1.5 * 1.75, 0.2 - 0.9), c, "Head")
	light(eyes, C(255, 40, 40), 6, 1.5)
	burst(anchor(m, "Feathers", V(0, 4.2, 0.2), c, "Body"), C(40, 36, 56), "Feathers", 0.6, 8).Texture = SMOKE
	return finish(m, "Cuervo", {c})
end

-- Viga entre dos puntos (a la criatura si se da limb, si no al modelo)
local function beam(where, limb, a, b, thick, color, mat, name)
	local o = {size = V(thick, thick, (b - a).Magnitude), at = CFrame.lookAt((a + b) / 2, b), color = color, mat = mat, name = name}
	return limb and piece(where, limb, o) or prop(where, o)
end
B.beam = beam

-- VELAS MALDITAS: candelabro de hierro con tres velas sobre una mesita con libros y una calavera. Al asustar, las llamas
-- se vuelven verdes y de ellas sale un espíritu con forma de calavera que grita.
function BUILD.Velas()
	local m = model("Velas")
	local IRON, IRON2, WAX, WAX2 = C(46, 42, 50), C(74, 68, 80), C(226, 214, 184), C(198, 186, 154)
	prop(m, {size = V(2.3, 0.24, 2.3), at = V(0, 2.1, 0), color = WOOD, mat = M.WoodPlanks, name = "Table"})
	prop(m, {size = V(2.4, 0.12, 2.4), at = V(0, 1.94, 0), color = WOOD_D, mat = M.Wood})
	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			prop(m, {size = V(0.26, 1.9, 0.26), at = V(x * 0.9, 0.95, z * 0.9), color = WOOD_D, mat = M.Wood})
		end
	end
	prop(m, {size = V(2.0, 0.16, 2.0), at = V(0, 0.55, 0), color = WOOD_D, mat = M.Wood})
	prop(m, {size = V(0.95, 0.28, 0.7), at = CFrame.new(-0.3, 0.77, 0.1) * R(0, 10, 0), color = C(120, 40, 44)})
	prop(m, {size = V(0.85, 0.24, 0.62), at = CFrame.new(-0.28, 1.03, 0.08) * R(0, -14, 0), color = C(46, 74, 120)})
	prop(m, {size = V(0.9, 0.22, 0.66), at = CFrame.new(0.62, 2.33, 0.5) * R(0, 15, 0), color = C(130, 42, 40)})
	prop(m, {size = V(0.8, 0.2, 0.6), at = CFrame.new(0.6, 2.54, 0.48) * R(0, -10, 0), color = C(52, 84, 132)})
	prop(m, {size = V(0.84, 0.05, 0.56), at = CFrame.new(0.6, 2.42, 0.48) * R(0, -10, 0), color = C(236, 226, 196), shadow = false})
	local sk = CFrame.new(-0.62, 2.5, -0.55) * R(0, 25, 0)
	prop(m, {size = V(0.62, 0.55, 0.62), at = sk, color = BONE})
	prop(m, {size = V(0.48, 0.2, 0.3), at = sk * CFrame.new(0, -0.3, -0.18), color = BONE_D})
	for s = -1, 1, 2 do
		prop(m, {size = V(0.17, 0.17, 0.05), at = sk * CFrame.new(s * 0.14, 0.04, -0.31), color = INK, shadow = false})
	end
	for k = 1, 4 do
		prop(m, {shape = "Cyl", size = V(0.3 + k * 0.05, 0.04, 0.3 + k * 0.05), at = V(math.cos(k * 1.7) * 0.7, 2.24, math.sin(k * 1.7) * 0.7), color = WAX2, shadow = false})
	end
	-- candelabro
	local b0 = 2.22
	prop(m, {size = V(0.8, 0.16, 0.8), at = V(0, b0 + 0.08, 0), color = IRON, mat = M.Metal})
	prop(m, {size = V(0.24, 1.55, 0.24), at = V(0, b0 + 0.85, 0), color = IRON, mat = M.Metal})
	prop(m, {shape = "Ball", size = V(0.42, 0.42, 0.42), at = V(0, b0 + 0.75, 0), color = IRON2, mat = M.Metal})
	prop(m, {size = V(2.1, 0.16, 0.16), at = V(0, b0 + 1.55, 0), color = IRON, mat = M.Metal})
	for s = -1, 1, 2 do
		prop(m, {size = V(0.14, 0.45, 0.14), at = CFrame.new(s * 0.85, b0 + 1.35, 0) * R(0, 0, s * 35), color = IRON, mat = M.Metal})
	end
	prop(m, {size = V(0.16, 0.45, 0.16), at = V(0, b0 + 1.8, 0), color = IRON, mat = M.Metal})
	local candles = {{-1.0, b0 + 1.63, 0.95}, {0, b0 + 2.03, 1.25}, {1.0, b0 + 1.63, 0.75}}
	for k, cd in candles do
		local x, y0, hgt = cd[1], cd[2], cd[3]
		prop(m, {size = V(0.5, 0.12, 0.5), at = V(x, y0, 0), color = IRON2, mat = M.Metal})
		prop(m, {size = V(0.36, hgt, 0.36), at = V(x, y0 + 0.06 + hgt / 2, 0), color = WAX, name = "Candle"})
		prop(m, {size = V(0.1, 0.35, 0.1), at = V(x + 0.18, y0 + hgt - 0.1, -0.08), color = WAX2, shadow = false})
		prop(m, {size = V(0.1, 0.22, 0.1), at = V(x - 0.1, y0 + hgt - 0.05, 0.18), color = WAX2, shadow = false})
		prop(m, {size = V(0.05, 0.14, 0.05), at = V(x, y0 + hgt + 0.13, 0), color = INK, shadow = false})
		prop(m, {size = V(0.2, 0.34, 0.2), at = V(x, y0 + hgt + 0.33, 0), color = C(255, 196, 90), neon = true, name = "Flame", shadow = false})
		local wick = anchor(m, "Wick", V(x, y0 + hgt + 0.3, 0))
		flame(wick, C(255, 160, 60), 0.4, "Fire")
		local curse = flame(wick, C(110, 255, 120), 1.0, "CurseFire")
		curse.Enabled = false
		curse.Rate = 40
		curse.Speed = NumberRange.new(3, 6)
	end
	local main = anchor(m, "Flames", V(0, b0 + 2.9, 0))
	light(main, C(255, 170, 70), 14, 2.2)
	sparkles(main, C(255, 200, 120), 2)
	-- el espíritu (invisible hasta el susto): calavera verde con mandíbula, manos de garra y una estela que baja a la vela
	local GH, GH2 = C(140, 255, 170), C(90, 220, 130)
	local c = newRig("Spirit", CFrame.new(0, b0 + 4.4, 0))
	joint(c, "Head", V(0, -0.3, 0), "Root", V(8, 0, 0))
	joint(c, "Jaw", V(0, -0.35, 0.35), "Head")
	joint(c, "ArmL", V(-0.85, -0.5, 0), "Root", V(20, 0, -40))
	joint(c, "ArmR", V(0.85, -0.5, 0), "Root", V(20, 0, 40))
	joint(c, "Wisp", V(0, -0.6, 0.1), "Root", V(10, 0, 0))
	piece(c, "Head", {size = V(1.3, 1.05, 1.2), at = V(0, 0.15, 0), color = GH, neon = true, hidden = true, t = 0.35, name = "Skull"})
	piece(c, "Head", {size = V(1.1, 0.3, 0.9), at = V(0, -0.45, -0.1), color = GH, neon = true, hidden = true, t = 0.35})
	face(c, "Head", V(0, 0.15, 0), V(1.3, 1.05, 1.2), {
		{-0.3, 0.08, 0.36, 0.4, INK, {hidden = true, t = 0.05}}, {0.3, 0.08, 0.36, 0.4, INK, {hidden = true, t = 0.05}},
		{-0.3, 0.05, 0.12, 0.12, C(255, 255, 255), {neon = true, hidden = true, t = 0, out = 0.01, name = "Eye"}}, {0.3, 0.05, 0.12, 0.12, C(255, 255, 255), {neon = true, hidden = true, t = 0, out = 0.01, name = "Eye"}},
		{0, -0.25, 0.16, 0.2, INK, {hidden = true, t = 0.05}},
	})
	piece(c, "Jaw", {size = V(1.0, 0.32, 0.95), at = V(0, -0.72, -0.05), color = GH2, neon = true, hidden = true, t = 0.35})
	for k = -2, 2 do
		piece(c, "Jaw", {size = V(0.13, 0.18, 0.08), at = V(k * 0.19, -0.5, -0.54), color = C(240, 255, 240), hidden = true, t = 0.1, shadow = false})
		piece(c, "Head", {size = V(0.13, 0.18, 0.08), at = V(k * 0.19, -0.42, -0.58), color = C(240, 255, 240), hidden = true, t = 0.1, shadow = false})
	end
	for s = -1, 1, 2 do
		local an = s < 0 and "ArmL" or "ArmR"
		piece(c, an, {size = V(0.3, 1.3, 0.3), at = V(s * 0.85, -1.1, 0), color = GH2, neon = true, hidden = true, t = 0.45})
		for f = -1, 1 do
			piece(c, an, {size = V(0.1, 0.5, 0.1), at = CFrame.new(s * 0.85 + f * 0.13, -1.9, -0.05) * R(-15, 0, f * 12), color = GH, neon = true, hidden = true, t = 0.3, shadow = false})
		end
	end
	for k, d in {{0.9, 0.55, -0.85}, {0.62, 0.5, -1.3}, {0.34, 0.45, -1.7}} do
		piece(c, "Wisp", {size = V(d[1], d[2], d[1] * 0.8), at = V(0, d[3], 0.1 + k * 0.05), color = GH2, neon = true, hidden = true, t = 0.5})
	end
	local sg = anchor(m, "SpiritGlow", V(0, 0, 0), c, "Head")
	light(sg, C(110, 255, 140), 16, 3, false)
	burst(sg, C(150, 255, 170), "Wail", 0.8, 7).Texture = SMOKE
	return finish(m, "Velas", {c})
end

-- Murciélago de bloques (es una criatura: Root en el cuerpo; Head, WingL y WingR). En reposo cuelga boca abajo con
-- las alas plegadas; extendidas, las alas van a lo ancho (eje X).
local function bat(at, k, name)
	local c = newRig(name or "Bat", at)
	local FUR, WING, BONEC = C(66, 52, 80), C(46, 36, 60), C(30, 24, 40)
	joint(c, "Head", V(0, 0.28, -0.12) * k, "Root")
	joint(c, "WingL", V(-0.24, 0.12, 0) * k, "Root", V(0, 0, 88))
	joint(c, "WingR", V(0.24, 0.12, 0) * k, "Root", V(0, 0, -88))
	piece(c, "Root", {size = V(0.55, 0.62, 0.5) * k, at = V(0, 0, 0), color = FUR, mat = M.Fabric, name = "Body"})
	piece(c, "Root", {size = V(0.4, 0.4, 0.1) * k, at = V(0, -0.02, -0.26) * k, color = C(110, 86, 120), shadow = false})
	for s = -1, 1, 2 do
		piece(c, "Root", {size = V(0.1, 0.18, 0.1) * k, at = V(s * 0.13, -0.38, 0) * k, color = BONEC, shadow = false})
	end
	piece(c, "Head", {size = V(0.5, 0.42, 0.46) * k, at = V(0, 0.48, -0.1) * k, color = FUR, mat = M.Fabric, name = "Head"})
	for s = -1, 1, 2 do
		piece(c, "Head", {wedge = true, size = V(0.16, 0.36, 0.2) * k, at = CFrame.new(V(s * 0.16, 0.85, -0.08) * k) * R(90, 0, 0), color = FUR, shadow = false})
		piece(c, "Head", {size = V(0.1, 0.1, 0.05) * k, at = V(s * 0.12, 0.52, -0.34) * k, color = C(255, 50, 60), neon = true, shadow = false, name = "Eye"})
		piece(c, "Head", {wedge = true, size = V(0.06, 0.1, 0.06) * k, at = CFrame.new(V(s * 0.07, 0.31, -0.33) * k) * R(-90, 0, 0), color = C(250, 250, 250), shadow = false})
	end
	for s = -1, 1, 2 do
		local w = s < 0 and "WingL" or "WingR"
		piece(c, w, {size = V(1.1, 0.06, 0.62) * k, at = V(s * 0.8, 0.12, 0.04) * k, color = WING, name = "Wing"})
		piece(c, w, {size = V(0.55, 0.06, 0.4) * k, at = V(s * 1.5, 0.12, 0.12) * k, color = WING, name = "Wing"})
		piece(c, w, {size = V(1.75, 0.09, 0.09) * k, at = V(s * 1.1, 0.13, -0.24) * k, color = BONEC, shadow = false})
		for f = 1, 2 do
			piece(c, w, {size = V(0.07, 0.07, 0.6) * k, at = CFrame.new(V(s * (0.6 + f * 0.45), 0.14, 0.06) * k) * R(0, s * -20, 0), color = BONEC, shadow = false})
		end
	end
	return c
end
B.bat = bat

-- ENJAMBRE DE MURCIÉLAGOS: un perchero viejo lleno de murciélagos colgados boca abajo (y una capa y una chistera). Al
-- asustar despiertan y salen volando en espiral hacia tu cara chillando.
function BUILD.Murcielagos()
	local m = model("Murcielagos")
	local WD, WD2, BRASS = C(70, 46, 34), C(52, 34, 26), C(196, 156, 70)
	for s = -1, 1, 2 do
		prop(m, {size = V(2.6, 0.26, 0.34), at = CFrame.new(0, 0.13, 0) * R(0, 45 * s, 0), color = WD2, mat = M.Wood})
	end
	prop(m, {size = V(0.6, 0.4, 0.6), at = V(0, 0.4, 0), color = WD, mat = M.Wood})
	prop(m, {size = V(0.36, 6.3, 0.36), at = V(0, 3.45, 0), color = WD, mat = M.Wood, name = "Pole"})
	for _, y in {1.6, 3.4, 5.4} do
		prop(m, {size = V(0.46, 0.16, 0.46), at = V(0, y, 0), color = WD2, mat = M.Wood})
	end
	prop(m, {shape = "Ball", size = V(0.6, 0.6, 0.6), at = V(0, 6.7, 0), color = BRASS, mat = M.Metal})
	-- chistera en lo alto
	prop(m, {shape = "Cyl", size = V(1.2, 0.1, 1.2), at = CFrame.new(0, 6.98, 0) * R(0, 0, 8), color = C(30, 28, 34)})
	prop(m, {shape = "Cyl", size = V(0.8, 0.8, 0.8), at = CFrame.new(0.06, 7.4, 0) * R(0, 0, 8), color = C(30, 28, 34)})
	prop(m, {shape = "Cyl", size = V(0.82, 0.14, 0.82), at = CFrame.new(0.03, 7.1, 0) * R(0, 0, 8), color = C(140, 30, 40)})
	-- perchas: cuatro arriba y dos a media altura; de una cuelga una capa raída
	local hooks = {}
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		local d = V(math.cos(a), 0, math.sin(a))
		local a0, a1 = V(0, 6.1, 0) + d * 0.15, V(0, 6.45, 0) + d * 0.95
		beam(m, nil, a0, a1, 0.16, WD2, M.Wood)
		prop(m, {shape = "Ball", size = V(0.24, 0.24, 0.24), at = a1, color = BRASS, mat = M.Metal})
		table.insert(hooks, a1)
	end
	for _, s in {-1, 1} do
		local d = V(s, 0, 0)
		local a0, a1 = V(0, 4.3, 0) + d * 0.15, V(0, 4.6, 0) + d * 1.05
		beam(m, nil, a0, a1, 0.16, WD2, M.Wood)
		prop(m, {shape = "Ball", size = V(0.24, 0.24, 0.24), at = a1, color = BRASS, mat = M.Metal})
		table.insert(hooks, a1)
	end
	local cloak = hooks[2]
	prop(m, {size = V(1.2, 2.8, 0.28), at = CFrame.new(cloak + V(0, -1.45, 0)) * R(0, 45, 3), color = C(40, 26, 50), mat = M.Fabric})
	prop(m, {size = V(1.0, 0.4, 0.4), at = CFrame.new(cloak + V(0, -0.15, 0)) * R(0, 45, 0), color = C(120, 20, 40), mat = M.Fabric})
	for k = -1, 1 do
		prop(m, {size = V(0.36, 0.5, 0.3), at = CFrame.new(cloak + V(0, -2.95, 0)) * R(0, 45, 0) * CFrame.new(k * 0.4, -(k % 2) * 0.15, 0), color = C(40, 26, 50), mat = M.Fabric})
	end
	-- los murciélagos, colgados de las otras perchas (Orbit: el Tower Defense los hace revolotear)
	local rigs = {}
	local n = 0
	for i, hk in hooks do
		if i ~= 2 then
			n += 1
			local k = n == 3 and 1.25 or 1.05
			local c = bat(CFrame.new(hk + V(0, -0.5 * k, 0)) * R(0, -90 + i * 75, 180), k)
			c.m:SetAttribute("Hook", hk)
			for _, p in c.m:GetChildren() do
				if p:IsA("BasePart") and p.Name ~= "Root" then
					p:SetAttribute("Orbit", n)
				end
			end
			table.insert(rigs, c)
		end
	end
	local top = anchor(m, "Moon", V(0, 6.6, 0))
	light(top, C(190, 120, 255), 10, 1.2)
	local swarm = anchor(m, "Swarm", V(0, 5, 0))
	burst(swarm, C(80, 50, 110), "Screech", 0.8, 8).Texture = SMOKE
	return finish(m, "Murcielagos", rigs)
end

-- CALABAZA BOMBARDERA: catapulta de madera con ruedas, montones de calabazas y una enorme con la cara encendida en el
-- cazo. Al asustar cruje, el brazo se suelta de golpe y la calabaza sale volando riendo hacia ti.
function BUILD.Calabaza()
	local m = model("Calabaza")
	local W1, W2, IRON, ROPE = C(132, 88, 52), C(94, 62, 38), C(62, 60, 70), C(196, 166, 110)
	for s = -1, 1, 2 do
		prop(m, {size = V(0.45, 0.5, 4.0), at = V(s * 1.2, 0.95, 0), color = W1, mat = M.Wood})
		for z = -1, 1, 2 do
			local at = V(s * 1.58, 0.75, z * 1.35)
			prop(m, {shape = "Cyl", axis = "X", size = V(0.3, 1.5, 1.5), at = at, color = W2, mat = M.Wood})
			prop(m, {shape = "Cyl", axis = "X", size = V(0.34, 1.62, 1.62), at = at, color = IRON, mat = M.Metal})
			prop(m, {shape = "Cyl", axis = "X", size = V(0.36, 1.36, 1.36), at = at, color = W2, mat = M.Wood})
			for r = 0, 1 do
				prop(m, {size = V(0.4, 1.3, 0.14), at = CFrame.new(at) * R(r * 90 + 20, 0, 0), color = W1, mat = M.Wood, shadow = false})
			end
			prop(m, {shape = "Cyl", axis = "X", size = V(0.44, 0.4, 0.4), at = at, color = IRON, mat = M.Metal})
		end
		beam(m, nil, V(s * 1.2, 1.1, -1.1), V(s * 1.2, 3.05, 0.0), 0.36, W1, M.Wood)
		beam(m, nil, V(s * 1.2, 1.1, 1.1), V(s * 1.2, 3.05, 0.0), 0.36, W1, M.Wood)
		beam(m, nil, V(s * 1.2, 1.1, -1.85), V(s * 1.2, 3.5, -1.85), 0.34, W2, M.Wood)
	end
	for _, z in {-1.65, 0, 1.7} do
		prop(m, {size = V(2.85, 0.36, 0.4), at = V(0, 0.95, z), color = W2, mat = M.Wood})
	end
	prop(m, {size = V(2.5, 0.12, 2.6), at = V(0, 1.25, 0.2), color = W1, mat = M.WoodPlanks})
	prop(m, {shape = "Cyl", axis = "X", size = V(2.95, 0.34, 0.34), at = V(0, 2.85, -0.05), color = IRON, mat = M.Metal})
	prop(m, {size = V(2.8, 0.4, 0.4), at = V(0, 3.55, -1.85), color = W2, mat = M.Wood})
	prop(m, {size = V(1.4, 0.55, 0.55), at = V(0, 3.55, -1.95), color = BURLAP, mat = M.Fabric})
	prop(m, {shape = "Cyl", axis = "X", size = V(2.4, 0.5, 0.5), at = V(0, 1.6, 1.75), color = W1, mat = M.Wood})
	for s = -1, 1, 2 do
		prop(m, {size = V(0.14, 0.7, 0.14), at = CFrame.new(s * 1.3, 1.6, 1.75) * R(30 * s, 0, 0) * CFrame.new(0, 0.3, 0), color = IRON, mat = M.Metal})
	end
	prop(m, {shape = "Cyl", axis = "X", size = V(1.6, 0.6, 0.6), at = V(0, 1.6, 1.75), color = ROPE, mat = M.Fabric})
	-- munición: calabacitas en el suelo
	pumpkin(m, nil, CFrame.new(-0.55, 1.75, -0.7) * R(0, 20, 0), 0.6, false)
	pumpkin(m, nil, CFrame.new(0.55, 1.7, -0.95) * R(0, -30, 0), 0.5, false)
	pumpkin(m, nil, CFrame.new(1.9, 0.35, -1.9) * R(0, -50, 0), 0.6, false)
	-- el brazo (articulación Arm, en el eje): armado hacia atrás con la calabaza en el cazo
	local c = newRig()
	joint(c, "Arm", V(0, 2.85, -0.05), "Root", V(30, 0, 0))
	piece(c, "Arm", {size = V(0.42, 0.42, 3.0), at = V(0, 2.85, 0.95), color = W1, mat = M.Wood, name = "Beam"})
	for _, z in {0.3, 1.4} do
		piece(c, "Arm", {size = V(0.48, 0.48, 0.12), at = V(0, 2.85, z), color = IRON, mat = M.Metal, shadow = false})
	end
	piece(c, "Arm", {size = V(1.4, 0.18, 1.4), at = V(0, 3.13, 2.35), color = W2, mat = M.Wood})
	for s = -1, 1, 2 do
		piece(c, "Arm", {size = V(1.4, 0.45, 0.16), at = V(0, 3.4, 2.35 + s * 0.62), color = W2, mat = M.Wood})
		piece(c, "Arm", {size = V(0.16, 0.45, 1.4), at = V(s * 0.62, 3.4, 2.35), color = W2, mat = M.Wood})
	end
	pumpkin(c, "Arm", CFrame.new(0, 3.85, 2.35), 1.05, true, "Ammo")
	local pk = anchor(m, "Pumpkin", V(0, 3.9, 2.35), c, "Arm")
	light(pk, C(255, 140, 40), 10, 1.8)
	flame(pk, C(255, 140, 40), 0.4)
	burst(pk, C(255, 160, 60), "Launch", 0.6, 7)
	return finish(m, "Calabaza", {c})
end

-- POLTERGEIST: una cómoda vieja con sus cosas encima y objetos que flotan. Al asustar tiembla, los cajones se abren de
-- golpe, todo vuela hacia ti y de dentro sale una niña fantasma de pelo largo.
function BUILD.Poltergeist()
	local m = model("Poltergeist")
	local WD, WD2, WD3, BRASS = C(104, 64, 46), C(72, 44, 32), C(128, 84, 58), C(220, 176, 84)
	local z0 = 0.4
	prop(m, {size = V(3.6, 3.0, 1.5), at = V(0, 1.75, z0), color = WD, mat = M.Wood, name = "Dresser"})
	prop(m, {size = V(3.9, 0.22, 1.75), at = V(0, 3.36, z0), color = WD2, mat = M.Wood})
	prop(m, {size = V(3.7, 0.2, 1.6), at = V(0, 0.3, z0), color = WD2, mat = M.Wood})
	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			prop(m, {size = V(0.32, 0.25, 0.32), at = V(x * 1.6, 0.12, z0 + z * 0.6), color = WD2, mat = M.Wood})
		end
	end
	-- cajones (se abren al asustar: atributo D con su número)
	for k = 1, 3 do
		local y = 0.85 + (k - 1) * 0.9
		local function dp(o)
			local p = prop(m, o)
			p.Name = "Drawer"
			p:SetAttribute("D", k)
			return p
		end
		dp({size = V(3.2, 0.78, 0.16), at = V(0, y, z0 - 0.78), color = WD3, mat = M.Wood})
		dp({size = V(3.0, 0.6, 1.3), at = V(0, y - 0.02, z0 - 0.05), color = WD2, mat = M.Wood})
		for s = -1, 1, 2 do
			dp({shape = "Ball", size = V(0.22, 0.22, 0.22), at = V(s * 0.8, y, z0 - 0.9), color = BRASS, mat = M.Metal})
		end
		dp({size = V(0.5, 0.18, 0.06), at = V(0, y + 0.1, z0 - 0.88), color = BRASS, mat = M.Metal})
	end
	-- encima: lámpara, retrato y joyero
	prop(m, {size = V(0.5, 0.2, 0.5), at = V(-1.3, 3.57, z0 + 0.2), color = BRASS, mat = M.Metal})
	prop(m, {size = V(0.16, 0.9, 0.16), at = V(-1.3, 4.1, z0 + 0.2), color = BRASS, mat = M.Metal})
	prop(m, {size = V(0.9, 0.6, 0.9), at = V(-1.3, 4.7, z0 + 0.2), color = C(200, 130, 140), mat = M.Fabric})
	local lamp = anchor(m, "Lamp", V(-1.3, 4.5, z0 + 0.2))
	light(lamp, C(255, 200, 150), 9, 1)
	prop(m, {size = V(1.1, 1.3, 0.12), at = CFrame.new(0.6, 4.15, z0 + 0.45) * R(-10, 0, 0), color = BRASS, mat = M.Metal})
	prop(m, {size = V(0.85, 1.05, 0.06), at = CFrame.new(0.6, 4.15, z0 + 0.38) * R(-10, 0, 0), color = C(60, 70, 80)})
	prop(m, {size = V(0.4, 0.45, 0.04), at = CFrame.new(0.6, 4.12, z0 + 0.34) * R(-10, 0, 0), color = C(220, 220, 230), shadow = false})
	prop(m, {size = V(0.6, 0.35, 0.45), at = V(1.45, 3.65, z0 - 0.2), color = C(140, 40, 60)})
	-- cosas que flotan alrededor (Orbit)
	local BOOK = {C(150, 40, 50), C(50, 70, 140), C(60, 110, 60)}
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		local pos = V(math.cos(a) * 2.4, 4.4 + (i % 2) * 0.9, z0 + math.sin(a) * 1.8)
		local o
		if i == 2 or i == 4 then
			o = prop(m, {shape = "Cyl", size = V(1.0, 0.1, 1.0), at = CFrame.new(pos) * R(30, 0, 20), color = C(240, 236, 226), name = "Float"})
		elseif i == 5 then
			o = prop(m, {size = V(0.4, 0.4, 0.4), at = CFrame.new(pos) * R(10, 30, 15), color = C(230, 230, 240), name = "Float"})
		else
			o = prop(m, {size = V(0.85, 0.25, 0.65), at = CFrame.new(pos) * R(20, a * 50, 15), color = BOOK[i % 3 + 1], name = "Float"})
		end
		o:SetAttribute("Orbit", i)
	end
	-- la niña fantasma (invisible hasta el susto), escondida en la cómoda
	local DRESS, SKIN, HAIR = C(236, 236, 246), C(196, 212, 230), C(18, 16, 24)
	local c = newRig("Ghost", CFrame.new(0, 1.2, z0 - 0.2))
	local h = humanoid(c, {hip = 1.6, torso = V(1.3, 1.4, 0.7), head = V(1.15, 1.15, 1.0), arm = V(0.5, 1.6, 0.5), leg = V(0.6, 1.6, 0.6), shirt = DRESS, skin = SKIN, arms = DRESS, hands = SKIN, handH = 0.35, noLegs = true,
		idle = {Torso = V(-10, 0, 0), Head = V(-20, 0, 8), ArmL = V(40, 0, -10), ArmR = V(40, 0, 10)}})
	for _, p in c.m:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "Root" then
			p:SetAttribute("T", 0.25)
			p.Transparency = 1
		end
	end
	joint(c, "Tail", V(0, h.hip, 0), "Torso", V(16, 0, 0))
	piece(c, "Tail", {size = V(1.5, 0.9, 0.85), at = V(0, h.hip - 0.45, 0), color = DRESS, hidden = true, t = 0.3})
	piece(c, "Tail", {size = V(1.1, 0.7, 0.6), at = V(0, h.hip - 1.15, 0.05), color = DRESS, hidden = true, t = 0.45})
	piece(c, "Tail", {size = V(0.6, 0.5, 0.4), at = V(0, h.hip - 1.7, 0.1), color = DRESS, hidden = true, t = 0.6})
	piece(c, "Head", {size = V(1.25, 1.7, 0.4), at = h.hc + V(0, -0.35, 0.4), color = HAIR, hidden = true, t = 0.1})
	for s = -1, 1, 2 do
		piece(c, "Head", {size = V(0.32, 1.9, 1.15), at = h.hc + V(s * 0.6, -0.45, 0), color = HAIR, hidden = true, t = 0.1})
	end
	piece(c, "Head", {size = V(0.8, 1.55, 0.1), at = h.hc + V(0.18, -0.35, -0.55), color = HAIR, hidden = true, t = 0.1})
	piece(c, "Head", {size = V(1.2, 0.3, 1.1), at = h.hc + V(0, 0.55, 0), color = HAIR, hidden = true, t = 0.1})
	piece(c, "Head", {size = V(0.18, 0.18, 0.05), at = h.hc + V(-0.3, 0.12, -0.53), color = C(255, 255, 255), neon = true, hidden = true, t = 0, name = "Eye"})
	piece(c, "Head", {size = V(0.3, 0.12, 0.05), at = h.hc + V(-0.3, -0.3, -0.53), color = INK, hidden = true, t = 0, name = "Mouth"})
	local gh = anchor(m, "Ghost", h.hc, c, "Head")
	light(gh, C(190, 110, 255), 11, 1.8)
	sparkles(gh, C(200, 140, 255), 4)
	burst(anchor(m, "Crash", V(0, 2, z0 - 0.8)), C(140, 100, 70), "Splinters", 0.4, 10)
	return finish(m, "Poltergeist", {c})
end

-- BANSHEE: mujer fantasma que flota, con el pelo larguísimo y el vestido deshecho en jirones. Al asustar se eleva,
-- abre la boca de par en par y su lamento te empuja hacia atrás.
function BUILD.Banshee()
	local m = model("Banshee")
	local GH, GH2, GH3, HAIR, DARK = C(196, 222, 250), C(156, 190, 238), C(118, 156, 224), C(206, 216, 240), C(12, 14, 30)
	local c = newRig()
	joint(c, "Torso", V(0, 3.0, 0), nil, V(6, 0, 0))
	joint(c, "Head", V(0, 5.0, 0), nil, V(-10, 0, 6))
	joint(c, "ArmL", V(-1.2, 4.75, 0), nil, V(12, 0, -16))
	joint(c, "ArmR", V(1.2, 4.75, 0), nil, V(18, 0, 12))
	joint(c, "Tail1", V(0, 3.0, 0), "Torso", V(12, 0, 0))
	joint(c, "Tail2", V(0, 2.0, 0.1), "Tail1", V(14, 0, 0))
	joint(c, "Hair", V(0, 6.2, 0.4), "Head", V(12, 0, 0))
	joint(c, "Jaw", V(0, 5.35, -0.3), "Head")
	piece(c, "Torso", {size = V(1.75, 2.0, 0.95), at = V(0, 4.0, 0), color = GH, t = 0.2, name = "Torso"})
	piece(c, "Torso", {size = V(1.9, 0.35, 1.05), at = V(0, 4.85, 0), color = GH2, t = 0.25})
	for k = -2, 2 do
		piece(c, "Torso", {wedge = true, size = V(0.35, 0.5, 1.0), at = CFrame.new(k * 0.36, 3.2, 0) * R(0, 0, 180), color = GH2, t = 0.25, shadow = false})
	end
	piece(c, "Tail1", {size = V(2.0, 1.1, 1.2), at = V(0, 2.45, 0), color = GH2, t = 0.3})
	for k = -2, 2 do
		piece(c, "Tail1", {size = V(0.4, 0.5 + (k % 2) * 0.35, 1.25), at = V(k * 0.4, 1.75 - (k % 2) * 0.18, 0), color = GH2, t = 0.35, shadow = false})
	end
	piece(c, "Tail2", {size = V(1.4, 0.8, 0.9), at = V(0, 1.45, 0.12), color = GH3, t = 0.4})
	piece(c, "Tail2", {size = V(0.85, 0.7, 0.55), at = V(0, 0.85, 0.2), color = GH3, t = 0.5})
	piece(c, "Tail2", {size = V(0.4, 0.5, 0.3), at = V(0, 0.4, 0.25), color = GH3, t = 0.6, shadow = false})
	for s = -1, 1, 2 do
		local an = s < 0 and "ArmL" or "ArmR"
		piece(c, an, {size = V(0.6, 2.4, 0.6), at = V(s * 1.2, 3.75, 0), color = GH, t = 0.2, name = an})
		piece(c, an, {size = V(0.8, 0.9, 0.8), at = V(s * 1.2, 4.35, 0.05), color = GH2, t = 0.3})
		for f = -1, 1 do
			piece(c, an, {size = V(0.11, 0.7, 0.11), at = CFrame.new(s * 1.2 + f * 0.17, 2.3, -0.05) * R(-10, 0, f * 8), color = GH, t = 0.2, shadow = false})
		end
	end
	local hc = V(0, 5.75, 0)
	piece(c, "Head", {size = V(1.35, 1.5, 1.25), at = hc, color = GH, t = 0.15, name = "Head"})
	face(c, "Head", hc, V(1.35, 1.5, 1.25), {
		{-0.32, 0.15, 0.42, 0.58, DARK, {name = "Eye", rot = R(0, 0, -6)}}, {0.32, 0.15, 0.42, 0.58, DARK, {name = "Eye", rot = R(0, 0, 6)}},
		{-0.32, 0.08, 0.09, 0.09, C(190, 240, 255), {neon = true, out = 0.01}}, {0.32, 0.08, 0.09, 0.09, C(190, 240, 255), {neon = true, out = 0.01}},
		{-0.52, -0.3, 0.08, 0.45, GH3, {out = 0.005}}, {0.52, -0.3, 0.08, 0.45, GH3, {out = 0.005}},
		{-0.07, -0.12, 0.06, 0.1, DARK, {out = 0.005}}, {0.07, -0.12, 0.06, 0.1, DARK, {out = 0.005}},
	})
	piece(c, "Jaw", {size = V(0.42, 0.5, 0.06), at = V(0, 5.3, -0.655), color = DARK, name = "Mouth", shadow = false})
	piece(c, "Jaw", {size = V(1.1, 0.3, 1.0), at = V(0, 5.05, -0.05), color = GH, t = 0.2})
	-- melena larga
	for k = -2, 2 do
		piece(c, "Hair", {size = V(0.36, 3.2 - math.abs(k) * 0.4, 0.32), at = CFrame.new(k * 0.32, 5.0, 0.68) * R(6, 0, k * 4), color = HAIR, t = 0.1})
	end
	for s = -1, 1, 2 do
		piece(c, "Hair", {size = V(0.3, 2.4, 0.9), at = CFrame.new(s * 0.75, 5.3, 0.05) * R(0, 0, s * -4), color = HAIR, t = 0.1})
	end
	piece(c, "Hair", {size = V(1.45, 0.35, 1.35), at = V(0, 6.55, 0.05), color = HAIR, t = 0.1})
	-- mechones que le caen por delante de los hombros
	for s = -1, 1, 2 do
		piece(c, "Hair", {size = V(0.3, 2.1, 0.14), at = CFrame.new(s * 0.56, 5.0, -0.62) * R(-4, 0, s * 3), color = HAIR, t = 0.15})
	end
	piece(c, "Hair", {size = V(0.6, 0.5, 0.14), at = V(-0.3, 6.35, -0.66), color = HAIR, t = 0.15})
	local w = anchor(m, "Wisp", V(0, 1.4, 0))
	light(w, C(140, 220, 255), 12, 1.6)
	mist(w, C(170, 230, 255), 5)
	sparkles(anchor(m, "Hair", V(0, 5.6, 0.7), c, "Hair"), C(200, 240, 255), 3)
	local scream = burst(anchor(m, "Scream", hc + V(0, -0.4, -0.8), c, "Jaw"), C(120, 170, 240), "Scream", 1.4, 14)
	scream.Texture = SMOKE
	scream.LightEmission = 0.15
	scream.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1)})
	return finish(m, "Banshee", {c})
end

-- MANOS: tierra removida delante de una lápida rota; cuatro brazos podridos esperan bajo el suelo (en casa empiezan
-- hundidos: ScareBehaviors.setup) y revientan para agarrarte de los tobillos.
function BUILD.Manos()
	local m = model("Manos")
	local DIRT, DIRT2, DIRT3, STONE = C(72, 54, 40), C(52, 38, 28), C(96, 72, 52), C(116, 114, 122)
	prop(m, {shape = "Cyl", size = V(4.9, 0.18, 4.9), at = V(0, 0.09, 0), color = DIRT, mat = M.Ground})
	prop(m, {shape = "Cyl", size = V(3.4, 0.22, 3.4), at = V(0, 0.11, 0), color = DIRT2, mat = M.Ground})
	for k = 1, 7 do
		local a = k / 7 * math.pi * 2
		prop(m, {size = V(0.1, 0.24, 1.8), at = CFrame.new(math.cos(a) * 1.4, 0.12, math.sin(a) * 1.4) * R(0, -math.deg(a) + 90, 0), color = C(30, 22, 18), shadow = false})
		prop(m, {size = V(0.6, 0.35, 0.5), at = CFrame.new(math.cos(a + 0.4) * 2.2, 0.2, math.sin(a + 0.4) * 2.2) * R(10, k * 40, 12), color = DIRT3, mat = M.Ground})
	end
	-- lápida rota detrás
	prop(m, {size = V(1.6, 1.9, 0.4), at = CFrame.new(0.3, 0.9, 2.1) * R(-8, 10, 6), color = STONE, mat = M.Slate})
	prop(m, {wedge = true, size = V(1.6, 0.5, 0.4), at = CFrame.new(0.3, 2.0, 2.1) * R(-8, 10, 6) * CFrame.new(0, 0.05, 0) * R(0, 180, 0), color = STONE, mat = M.Slate})
	prop(m, {size = V(0.18, 0.9, 0.06), at = CFrame.new(0.3, 1.25, 2.1) * R(-8, 10, 6) * CFrame.new(0, 0, -0.22), color = C(60, 58, 66), shadow = false})
	prop(m, {size = V(0.6, 0.18, 0.06), at = CFrame.new(0.3, 1.45, 2.1) * R(-8, 10, 6) * CFrame.new(0, 0, -0.22), color = C(60, 58, 66), shadow = false})
	prop(m, {size = V(0.7, 0.3, 0.42), at = CFrame.new(-0.4, 0.25, 2.0) * R(0, 30, 20), color = C(80, 120, 60), mat = M.Grass})
	-- brazos (una criatura: A# brazo, H# mano, F# dedos)
	local c = newRig("Hands")
	local SKIN, SKIN2, NAIL, SLEEVE = C(120, 152, 94), C(96, 124, 74), C(56, 46, 38), C(64, 56, 78)
	local spots = {{-1.1, -0.65, 14, 20}, {1.15, -0.4, -12, -25}, {0.15, 0.95, 4, 0}, {-0.25, 0.1, -20, 40}}
	for i, sp in spots do
		local x, z = sp[1], sp[2]
		local A, H, F = "A" .. i, "H" .. i, "F" .. i
		local k = i == 3 and 1.15 or 1
		joint(c, A, V(x, 0, z), "Root", V(sp[3] * 0.6, sp[4], sp[3]))
		joint(c, H, V(x, 2.25 * k, z), A, V(-18, 0, 0))
		joint(c, F, V(x, 2.85 * k, z), H, V(-35, 0, 0))
		piece(c, A, {size = V(0.7, 2.4, 0.7) * V(k, k, k), at = V(x, 1.05 * k, z), color = SKIN, name = "Arm"})
		piece(c, A, {size = V(0.84, 0.55, 0.84) * k, at = CFrame.new(x, 0.25, z) * R(0, 20, 6), color = SLEEVE, mat = M.Fabric})
		piece(c, A, {size = V(0.3, 0.4, 0.06), at = V(x + 0.1, 1.2 * k, z - 0.36 * k), color = C(150, 60, 60), shadow = false})
		piece(c, H, {size = V(0.85, 0.6, 0.45) * k, at = V(x, 2.55 * k, z), color = SKIN2, name = "Hand"})
		for f = 0, 3 do
			local fx = x + (-0.3 + f * 0.2) * k
			piece(c, F, {size = V(0.16, 0.65, 0.16) * k, at = V(fx, 3.15 * k, z), color = SKIN, shadow = false})
			piece(c, F, {size = V(0.17, 0.12, 0.17) * k, at = V(fx, 3.47 * k, z), color = NAIL, shadow = false})
		end
		piece(c, H, {size = V(0.18, 0.5, 0.18) * k, at = CFrame.new(x + 0.48 * k, 2.6 * k, z - 0.1) * R(0, 0, -40), color = SKIN, shadow = false})
	end
	local d = anchor(m, "Dirt", V(0, 0.4, 0))
	burst(d, C(110, 82, 58), "DirtBurst", 1.4, 12).Texture = SMOKE
	mist(d, C(120, 200, 120), 4)
	return finish(m, "Manos", {c})
end

-- Alma en pena (las del Pozo): cabecita con ojos y boca negros y una estela que se afina. Invisible hasta el susto.
local function soul(at, k, col)
	local c = newRig("Soul", at)
	joint(c, "Head", V(0, 0, 0), "Root")
	joint(c, "Wisp", V(0, -0.45, 0) * k, "Root", V(14, 0, 0))
	joint(c, "ArmL", V(-0.45, -0.35, 0) * k, "Root", V(30, 0, -50))
	joint(c, "ArmR", V(0.45, -0.35, 0) * k, "Root", V(30, 0, 50))
	piece(c, "Head", {size = V(0.9, 0.95, 0.85) * k, at = V(0, 0.05, 0) * k, color = col, neon = true, hidden = true, t = 0.35, name = "Head"})
	face(c, "Head", V(0, 0.05, 0) * k, V(0.9, 0.95, 0.85) * k, {
		{-0.2 * k, 0.12 * k, 0.2 * k, 0.28 * k, INK, {hidden = true, t = 0}}, {0.2 * k, 0.12 * k, 0.2 * k, 0.28 * k, INK, {hidden = true, t = 0}},
		{0, -0.22 * k, 0.24 * k, 0.3 * k, INK, {hidden = true, t = 0, name = "Mouth"}},
	})
	for n, d in {{0.75, 0.5, -0.75}, {0.5, 0.45, -1.2}, {0.25, 0.4, -1.6}} do
		piece(c, "Wisp", {size = V(d[1], d[2], d[1]) * k, at = V(0, d[3], 0.05 * n) * k, color = col, neon = true, hidden = true, t = 0.45 + n * 0.08})
	end
	for s = -1, 1, 2 do
		piece(c, s < 0 and "ArmL" or "ArmR", {size = V(0.18, 0.7, 0.18) * k, at = V(s * 0.45, -0.7, 0) * k, color = col, neon = true, hidden = true, t = 0.45, shadow = false})
	end
	return c
end
B.soul = soul

-- POZO DE ALMAS: pozo de piedra con tejadillo, cubo y monedas de oro en el brocal; dentro brilla un resplandor
-- morado. Al asustar salen tres almas en espiral gimiendo y sueltan monedas de más.
function BUILD.Pozo()
	local m = model("Pozo")
	local ST = {C(128, 124, 136), C(104, 100, 112), C(148, 144, 154)}
	local WD, WD2, ROOF, ROOF2, GOLD = C(112, 76, 48), C(82, 56, 36), C(86, 48, 56), C(66, 36, 44), C(255, 200, 60)
	local R0 = 1.72
	for k = 0, 7 do
		for row = 0, 2 do
			local a = k / 8 * math.pi * 2 + (row % 2) * math.pi / 8
			prop(m, {size = V(1.45, 0.62, 0.55), at = CFrame.new(math.cos(a) * R0, 0.31 + row * 0.62, math.sin(a) * R0) * R(0, -math.deg(a) - 90, 0), color = ST[(k + row) % 3 + 1], mat = M.Slate, collide = false})
		end
		local a = k / 8 * math.pi * 2
		prop(m, {size = V(1.5, 0.22, 0.75), at = CFrame.new(math.cos(a) * R0, 1.97, math.sin(a) * R0) * R(0, -math.deg(a) - 90, 0), color = C(90, 86, 98), mat = M.Slate})
	end
	prop(m, {shape = "Cyl", size = V(3.1, 1.6, 3.1), at = V(0, 0.85, 0), color = C(18, 12, 28)})
	prop(m, {shape = "Cyl", size = V(2.95, 0.08, 2.95), at = V(0, 1.55, 0), color = C(170, 100, 255), neon = true, name = "SoulPool", t = 0.15, shadow = false})
	-- monedas de oro en el brocal
	for k, a in {0.4, 0.9, 2.6, 4.2, 5.3} do
		prop(m, {shape = "Cyl", size = V(0.42, 0.08, 0.42), at = CFrame.new(math.cos(a) * R0, 2.12 + (k % 2) * 0.08, math.sin(a) * R0) * R(k * 9, 0, k * 6), color = GOLD, mat = M.Metal, shadow = false, name = "Coin"})
	end
	-- postes, eje con manivela y tejadillo
	for s = -1, 1, 2 do
		prop(m, {size = V(0.42, 5.3, 0.42), at = V(s * 1.95, 2.65, 0), color = WD, mat = M.Wood})
	end
	prop(m, {shape = "Cyl", axis = "X", size = V(4.4, 0.36, 0.36), at = V(0, 4.35, 0), color = WD2, mat = M.Wood})
	prop(m, {shape = "Cyl", axis = "X", size = V(1.0, 0.6, 0.6), at = V(0, 4.35, 0), color = C(196, 166, 110), mat = M.Fabric})
	prop(m, {size = V(0.14, 0.75, 0.14), at = V(2.3, 4.0, 0), color = C(70, 68, 76), mat = M.Metal})
	prop(m, {size = V(0.45, 0.14, 0.14), at = V(2.5, 3.65, 0), color = C(70, 68, 76), mat = M.Metal})
	for s = -1, 1, 2 do
		prop(m, {size = V(4.9, 0.2, 2.0), at = CFrame.new(0, 5.55, s * 0.82) * R(s * 30, 0, 0), color = ROOF, mat = M.WoodPlanks})
		for r = 0, 2 do
			prop(m, {size = V(4.95, 0.08, 0.14), at = CFrame.new(0, 5.55, s * 0.82) * R(s * 30, 0, 0) * CFrame.new(0, 0.13, -0.7 + r * 0.7), color = ROOF2, shadow = false})
		end
	end
	prop(m, {size = V(5.0, 0.3, 0.3), at = V(0, 6.05, 0), color = WD2, mat = M.Wood})
	-- cubo colgado de la cuerda (se balancea)
	local bk = newRig("Bucket")
	joint(bk, "Rope", V(0, 4.35, 0), "Root", V(4, 0, 3))
	piece(bk, "Rope", {size = V(0.08, 1.15, 0.08), at = V(0, 3.75, 0), color = C(196, 166, 110), mat = M.Fabric, shadow = false})
	piece(bk, "Rope", {size = V(0.75, 0.7, 0.75), at = V(0, 2.85, 0), color = WD, mat = M.Wood, name = "Bucket"})
	piece(bk, "Rope", {size = V(0.8, 0.12, 0.8), at = V(0, 3.05, 0), color = C(70, 68, 76), mat = M.Metal, shadow = false})
	piece(bk, "Rope", {size = V(0.6, 0.06, 0.6), at = V(0, 3.18, 0), color = GOLD, mat = M.Metal, shadow = false})
	-- las almas (invisibles hasta el susto)
	local rigs = {bk}
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2
		local s = soul(CFrame.new(math.cos(a) * 0.7, 1.3, math.sin(a) * 0.7), 1.25, C(190, 140, 255))
		s.m:SetAttribute("Phase", i)
		table.insert(rigs, s)
	end
	local a = anchor(m, "Souls", V(0, 2.0, 0))
	light(a, C(170, 100, 255), 12, 2)
	emitter(a, {
		Name = "Souls", Texture = SMOKE, Color = ColorSequence.new(C(190, 140, 255)), Rate = 4, Lifetime = NumberRange.new(1.6, 2.4),
		Speed = NumberRange.new(1.5, 2.5), SpreadAngle = Vector2.new(12, 12), LightEmission = 1, Acceleration = Vector3.new(0, 1, 0),
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.4)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.4), NumberSequenceKeypoint.new(1, 1)}),
	})
	sparkles(a, C(220, 180, 255), 5)
	burst(a, GOLD, "Gold", 0.5, 10)
	return finish(m, "Pozo", rigs)
end

-- ESPEJO EMBRUJADO: espejo de pie con marco dorado y una calavera en el remate. Tu "reflejo" (una silueta negra con una
-- sonrisa enorme) aparece, apoya las manos en el cristal... y lo rompe.
function BUILD.Espejo()
	local m = model("Espejo")
	local GOLD, GOLD2, DARK, GEM = C(218, 172, 72), C(168, 122, 46), C(26, 20, 34), C(170, 80, 255)
	for s = -1, 1, 2 do
		prop(m, {size = V(0.6, 0.5, 1.7), at = V(s * 1.15, 0.25, 0.1), color = GOLD2, mat = M.Metal})
		prop(m, {shape = "Ball", size = V(0.5, 0.5, 0.5), at = V(s * 1.15, 0.35, -0.75), color = GOLD, mat = M.Metal})
		prop(m, {size = V(0.45, 6.3, 0.62), at = V(s * 1.55, 3.55, 0.05), color = GOLD, mat = M.Metal})
		for k = 0, 3 do
			prop(m, {size = V(0.5, 0.3, 0.66), at = V(s * 1.55, 1.3 + k * 1.5, 0.05), color = GOLD2, mat = M.Metal, shadow = false})
		end
		prop(m, {shape = "Ball", size = V(0.5, 0.5, 0.5), at = V(s * 1.55, 6.95, 0.05), color = GOLD, mat = M.Metal})
		prop(m, {size = V(0.18, 0.18, 0.08), at = V(s * 1.55, 3.6, -0.3), color = GEM, neon = true, shadow = false})
	end
	prop(m, {size = V(3.55, 0.5, 0.62), at = V(0, 0.65, 0.05), color = GOLD, mat = M.Metal})
	prop(m, {size = V(3.55, 0.45, 0.62), at = V(0, 6.5, 0.05), color = GOLD, mat = M.Metal})
	for k, w in {2.6, 1.8, 1.0} do
		prop(m, {size = V(w, 0.32, 0.55), at = V(0, 6.85 + k * 0.3, 0.05), color = k % 2 == 0 and GOLD2 or GOLD, mat = M.Metal})
	end
	-- calavera del remate
	local sk = CFrame.new(0, 8.05, 0)
	prop(m, {size = V(0.75, 0.65, 0.6), at = sk, color = BONE})
	prop(m, {size = V(0.55, 0.22, 0.45), at = sk * CFrame.new(0, -0.38, -0.05), color = BONE_D})
	for s = -1, 1, 2 do
		prop(m, {size = V(0.2, 0.2, 0.05), at = sk * CFrame.new(s * 0.17, 0.04, -0.31), color = GEM, neon = true, shadow = false})
		prop(m, {wedge = true, size = V(0.3, 0.6, 0.5), at = CFrame.new(s * 0.7, 7.75, 0.05) * R(90, 0, 0) * R(0, 0, s * 30), color = GOLD2, mat = M.Metal})
	end
	prop(m, {size = V(3.1, 5.8, 0.12), at = V(0, 3.58, 0.33), color = DARK, name = "Back"})
	prop(m, {size = V(2.7, 5.4, 0.04), at = V(0, 3.58, 0.25), color = C(90, 60, 140), neon = true, t = 0.75, name = "GlassGlow", shadow = false})
	local glass = prop(m, {size = V(2.7, 5.4, 0.08), at = V(0, 3.58, -0.12), color = C(80, 60, 120), mat = M.Glass, t = 0.45, refl = 0.25, name = "Glass", shadow = false})
	glass.CanQuery = true
	-- grietas (aparecen al romperse)
	local hit = V(0.35, 4.6, -0.17)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2 + 0.3
		local len = 0.8 + (k % 3) * 0.55
		local p = prop(m, {size = V(0.07, len, 0.03), at = CFrame.new(hit) * R(0, 0, math.deg(a)) * CFrame.new(0, len / 2, 0), color = C(240, 230, 255), neon = true, hidden = true, t = 0, name = "Crack", shadow = false})
		p.CanQuery = false
	end
	-- el reflejo (invisible hasta el susto): silueta negra con ojos y sonrisa blancos
	local c = newRig("Reflection", CFrame.new(0, 0.95, 0.12))
	local SIL = C(22, 16, 30)
	local h = humanoid(c, {hip = 1.8, torso = V(1.7, 1.8, 0.4), head = V(1.35, 1.35, 0.4), arm = V(0.7, 2.0, 0.4), leg = V(0.8, 1.8, 0.4), shirt = SIL, pants = SIL, skin = SIL,
		idle = {Head = V(0, 0, 10), ArmL = V(0, 0, -6), ArmR = V(0, 0, 6)}})
	for _, p in c.m:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "Root" then
			p:SetAttribute("T", 0.05)
			p.Transparency = 1
		end
	end
	local hc = h.hc
	local WHITE = C(255, 255, 255)
	for _, d in {{-0.32, 0.18, 0.3, 0.16}, {0.32, 0.18, 0.3, 0.16}, {0, -0.28, 0.9, 0.1}, {-0.42, -0.2, 0.12, 0.18}, {0.42, -0.2, 0.12, 0.18}} do
		piece(c, "Head", {size = V(d[3], d[4], 0.05), at = hc + V(d[1], d[2], -0.23), color = WHITE, neon = true, hidden = true, t = 0, name = "Grin", shadow = false})
	end
	for k = -3, 3 do
		piece(c, "Head", {size = V(0.06, 0.12, 0.05), at = hc + V(k * 0.12, -0.28, -0.25), color = INK, hidden = true, t = 0, shadow = false})
	end
	local g = anchor(m, "Glass", V(0, 3.6, -0.4))
	light(g, C(180, 110, 255), 12, 2)
	sparkles(g, C(210, 160, 255), 3)
	burst(g, C(230, 220, 255), "Shatter", 0.4, 16)
	return finish(m, "Espejo", {c})
end

-- VAMPIRO: alto, pálido, de frac negro y chaleco rojo, con una capa de cuello alto y ojos rojos. Al asustar abre la
-- capa como unas alas, sisea enseñando los colmillos y una nube de murciélagos sale de ella.
function BUILD.Vampiro()
	local m = model("Vampiro")
	local SKIN, SUIT, VEST, SHIRT, CAPE, CAPE_IN, HAIR, GOLD = C(226, 222, 238), C(30, 28, 38), C(156, 20, 42), C(244, 242, 248), C(24, 20, 30), C(176, 18, 42), C(20, 18, 26), C(232, 188, 70)
	local c = newRig()
	local h = humanoid(c, {hip = 2.4, torso = V(2.1, 2.3, 1.05), head = V(1.5, 1.6, 1.4), arm = V(0.92, 2.6, 0.92), leg = V(1.05, 2.4, 1.0), shirt = SUIT, pants = SUIT, skin = SKIN, arms = SUIT,
		hands = SKIN, handH = 0.45, idle = {Torso = V(-4, 0, 0), Head = V(8, 0, -5), ArmL = V(22, 0, -12), ArmR = V(40, 0, 18)}})
	local tc = V(0, h.hip + 1.15, 0)
	local z = -0.535
	piece(c, "Torso", {wedge = true, size = V(1.2, 1.9, 0.06), at = CFrame.new(tc + V(0, 0.15, z)) * R(0, 0, 180) * R(0, 180, 0), color = VEST, shadow = false})
	piece(c, "Torso", {size = V(1.0, 1.7, 0.06), at = tc + V(0, -0.1, z), color = VEST, shadow = false})
	piece(c, "Torso", {size = V(0.55, 1.0, 0.07), at = tc + V(0, 0.55, z - 0.005), color = SHIRT, shadow = false})
	for k = 0, 2 do
		piece(c, "Torso", {size = V(0.5 - k * 0.1, 0.2, 0.18), at = tc + V(0, 0.75 - k * 0.22, z - 0.06), color = SHIRT, shadow = false})
	end
	for k = 0, 2 do
		piece(c, "Torso", {size = V(0.12, 0.12, 0.06), at = tc + V(0, -0.15 - k * 0.38, z - 0.01), color = GOLD, mat = M.Metal, shadow = false})
	end
	piece(c, "Torso", {size = V(0.42, 0.42, 0.1), at = tc + V(0, 0.15, z - 0.12), color = GOLD, mat = M.Metal, name = "Medal"})
	piece(c, "Torso", {size = V(0.22, 0.22, 0.06), at = tc + V(0, 0.15, z - 0.18), color = C(255, 30, 60), neon = true, shadow = false})
	for s = -1, 1, 2 do
		piece(c, "Torso", {size = V(0.85, 1.4, 0.15), at = CFrame.new(s * 0.6, h.hip - 0.55, 0.45) * R(-8, 0, s * 6), color = SUIT})
		piece(c, s < 0 and "LegL" or "LegR", {size = V(1.12, 0.42, 1.35), at = V(s * 0.525, 0.21, -0.15), color = C(14, 12, 18), refl = 0.15})
	end
	-- cabeza: pelo engominado con pico, orejas puntiagudas, ojos rojos y colmillos
	local hc = h.hc
	piece(c, "Head", {size = V(1.6, 0.4, 1.5), at = hc + V(0, 0.75, 0.04), color = HAIR})
	piece(c, "Head", {size = V(1.6, 1.4, 0.35), at = hc + V(0, 0.1, 0.62), color = HAIR})
	for s = -1, 1, 2 do
		piece(c, "Head", {size = V(0.2, 0.9, 1.3), at = hc + V(s * 0.75, 0.3, 0.05), color = HAIR})
		piece(c, "Head", {wedge = true, size = V(0.12, 0.5, 0.45), at = CFrame.new(hc + V(s * 0.8, 0.05, 0.05)) * R(90, 0, 0) * R(0, 0, s * -25), color = SKIN})
	end
	piece(c, "Head", {wedge = true, size = V(0.5, 0.45, 0.08), at = CFrame.new(hc + V(0, 0.5, -0.72)) * R(-90, 0, 0), color = HAIR, shadow = false})
	face(c, "Head", hc, h.hs, {
		{-0.34, 0.12, 0.34, 0.18, C(255, 40, 50), {neon = true, name = "Eye"}}, {0.34, 0.12, 0.34, 0.18, C(255, 40, 50), {neon = true, name = "Eye"}},
		{-0.34, 0.33, 0.46, 0.1, HAIR, {rot = R(0, 0, -20), out = 0.01}}, {0.34, 0.33, 0.46, 0.1, HAIR, {rot = R(0, 0, 20), out = 0.01}},
		{-0.34, -0.06, 0.32, 0.08, C(170, 160, 190), {out = 0.005}}, {0.34, -0.06, 0.32, 0.08, C(170, 160, 190), {out = 0.005}},
		{0, -0.4, 0.62, 0.1, C(90, 10, 30), {name = "Mouth"}},
		{-0.17, -0.5, 0.09, 0.16, C(255, 255, 255), {out = 0.01, name = "Fang"}}, {0.17, -0.5, 0.09, 0.16, C(255, 255, 255), {out = 0.01, name = "Fang"}},
	})
	-- capa de cuello alto (CapeL y CapeR se abren como alas)
	for s = -1, 1, 2 do
		local cn = s < 0 and "CapeL" or "CapeR"
		local piv = V(s * 0.85, h.top - 0.05, 0.6)
		joint(c, cn, piv, "Torso", V(-4, 0, s * -3))
		piece(c, cn, {size = V(1.35, 4.7, 0.16), at = CFrame.new(piv + V(s * 0.35, -2.35, 0.08)) * R(0, 0, s * -4), color = CAPE, name = "Cape"})
		piece(c, cn, {size = V(1.3, 4.6, 0.05), at = CFrame.new(piv + V(s * 0.35, -2.33, -0.02)) * R(0, 0, s * -4), color = CAPE_IN, shadow = false})
		for k = 0, 1 do
			piece(c, cn, {wedge = true, size = V(0.16, 0.6, 0.6), at = CFrame.new(piv + V(s * (0.05 + k * 0.62), -4.9, 0.08)) * R(0, 90, 0) * R(-90, 0, 0), color = CAPE, shadow = false})
		end
		piece(c, cn, {size = V(1.0, 1.7, 0.14), at = CFrame.new(piv + V(s * 0.25, 0.85, -0.05)) * R(-12, s * 28, s * -14), color = CAPE, name = "Collar"})
		piece(c, cn, {size = V(0.95, 1.6, 0.05), at = CFrame.new(piv + V(s * 0.24, 0.84, -0.14)) * R(-12, s * 28, s * -14), color = CAPE_IN, shadow = false})
	end
	-- murciélagos escondidos en la capa (salen al asustar)
	local rigs = {c}
	for i = 1, 4 do
		local b = bat(CFrame.new((i - 2.5) * 0.5, 3.5 + (i % 2) * 0.6, 0.6), 0.8)
		b.m.Name = "Bat"
		for _, p in b.m:GetChildren() do
			if p:IsA("BasePart") and p.Name ~= "Root" then
				p:SetAttribute("T", 0)
				p.Transparency = 1
			end
		end
		table.insert(rigs, b)
	end
	local eyes = anchor(m, "Eyes", hc + V(0, 0.1, -0.9), c, "Head")
	light(eyes, C(255, 30, 50), 9, 1.6)
	mist(anchor(m, "Fog", V(0, 0.3, 0)), C(150, 30, 50), 3, "Fog")
	burst(anchor(m, "Poof", V(0, 3.5, 0), c, "Torso"), C(60, 10, 30), "Poof", 2, 8).Texture = SMOKE
	return finish(m, "Vampiro", rigs)
end

-- JINETE SIN CABEZA: caballo negro con crin y cola de fuego y ojos rojos; el jinete, sin cabeza (le sale fuego del
-- cuello), sujeta en alto una calabaza en llamas. El caballo se encabrita y el jinete te la lanza.
function BUILD.Jinete()
	local m = model("Jinete")
	local HORSE, HORSE2, FIREC, HOOF, SADDLE = C(40, 36, 46), C(28, 24, 34), C(255, 124, 30), C(18, 16, 20), C(120, 34, 34)
	local COAT, COAT2, SHIRT, GLOVE, PANTS = C(52, 42, 62), C(36, 28, 46), C(226, 220, 206), C(30, 26, 30), C(46, 40, 40)
	local c = newRig()
	-- caballo: Body gira sobre las caderas (encabritarse)
	joint(c, "Body", V(0, 3.3, 1.5), "Root")
	piece(c, "Body", {size = V(2.1, 2.1, 4.2), at = V(0, 3.9, 0.1), color = HORSE, name = "Horse"})
	piece(c, "Body", {size = V(1.9, 1.7, 0.7), at = V(0, 3.75, -2.1), color = HORSE})
	piece(c, "Body", {size = V(1.95, 0.4, 3.6), at = V(0, 2.85, 0.1), color = HORSE2})
	-- silla, manta y estribos
	piece(c, "Body", {size = V(2.25, 0.3, 1.9), at = V(0, 5.02, -0.2), color = SADDLE})
	piece(c, "Body", {size = V(2.3, 1.2, 1.7), at = V(0, 4.4, -0.2), color = C(70, 20, 30), mat = M.Fabric})
	piece(c, "Body", {size = V(1.4, 0.45, 0.4), at = V(0, 5.3, 0.6), color = SADDLE})
	piece(c, "Body", {size = V(1.0, 0.35, 0.3), at = V(0, 5.3, -1.0), color = SADDLE})
	-- cuello, cabeza y crin de fuego
	joint(c, "Neck", V(0, 4.6, -1.8), "Body")
	piece(c, "Neck", {size = V(1.1, 2.6, 1.35), at = CFrame.new(0, 4.6, -1.8) * R(-32, 0, 0) * CFrame.new(0, 1.15, 0), color = HORSE, name = "Neck"})
	local top = (CFrame.new(0, 4.6, -1.8) * R(-32, 0, 0) * CFrame.new(0, 2.35, 0)).Position
	for k = 0, 5 do
		piece(c, "Neck", {wedge = true, size = V(0.3, 0.7 - k * 0.04, 0.55), at = CFrame.new(0, 4.6, -1.8) * R(-32, 0, 0) * CFrame.new(0, 0.3 + k * 0.42, 0.72) * R(-60, 0, 0), color = FIREC, neon = true, shadow = false, name = "Mane"})
	end
	joint(c, "HHead", top, "Neck")
	local hcf = CFrame.new(top) * R(-28, 0, 0) * CFrame.new(0, -0.1, -0.85)
	piece(c, "HHead", {size = V(1.0, 1.05, 1.9), at = hcf, color = HORSE, name = "HorseHead"})
	piece(c, "HHead", {size = V(0.9, 0.85, 0.8), at = hcf * CFrame.new(0, -0.15, -1.2), color = HORSE2})
	for s = -1, 1, 2 do
		piece(c, "HHead", {size = V(0.12, 0.22, 0.32), at = hcf * CFrame.new(s * 0.52, 0.2, -0.35), color = C(255, 40, 30), neon = true, shadow = false, name = "Eye"})
		piece(c, "HHead", {size = V(0.18, 0.18, 0.05), at = hcf * CFrame.new(s * 0.22, -0.2, -1.62), color = C(255, 80, 30), neon = true, shadow = false})
		piece(c, "HHead", {wedge = true, size = V(0.22, 0.55, 0.35), at = hcf * CFrame.new(s * 0.32, 0.75, 0.55) * R(90, 0, 0), color = HORSE})
		piece(c, "HHead", {size = V(0.06, 0.12, 1.6), at = hcf * CFrame.new(s * 0.53, -0.1, -0.5), color = C(150, 30, 30), shadow = false})
	end
	-- patas: las de delante van con el cuerpo, las de detrás se quedan en el suelo
	for _, lg in {{"FL", -0.62, -1.55, "Body"}, {"FR", 0.62, -1.55, "Body"}, {"BL", -0.62, 1.5, "Root"}, {"BR", 0.62, 1.5, "Root"}} do
		local n, x, zz = lg[1], lg[2], lg[3]
		joint(c, n, V(x, 3.0, zz), lg[4])
		piece(c, n, {size = V(0.62, 1.7, 0.8), at = V(x, 2.2, zz), color = HORSE})
		piece(c, n, {size = V(0.48, 1.3, 0.55), at = V(x, 0.85, zz), color = HORSE2})
		piece(c, n, {size = V(0.64, 0.32, 0.72), at = V(x, 0.16, zz - 0.06), color = HOOF})
		piece(c, n, {size = V(0.66, 0.12, 0.74), at = V(x, 0.38, zz - 0.06), color = FIREC, neon = true, shadow = false})
	end
	-- cola de fuego
	joint(c, "Tail", V(0, 4.5, 2.2), "Body", V(20, 0, 0))
	for k = 0, 3 do
		piece(c, "Tail", {size = V(0.5 - k * 0.07, 0.5 - k * 0.07, 0.9), at = CFrame.new(0, 4.5, 2.2) * R(-40 - k * 12, 0, 0) * CFrame.new(0, 0, 0.45 + k * 0.75), color = k == 0 and HORSE or FIREC, neon = k > 0, shadow = false, name = "Flame"})
	end
	-- el jinete (cuelga del caballo)
	joint(c, "RTorso", V(0, 5.15, -0.2), "Body", V(-6, 0, 0))
	piece(c, "RTorso", {size = V(1.9, 2.1, 1.0), at = V(0, 6.2, -0.2), color = COAT, name = "Rider"})
	piece(c, "RTorso", {size = V(0.6, 1.4, 0.06), at = V(0, 6.6, -0.73), color = SHIRT, shadow = false})
	piece(c, "RTorso", {size = V(0.5, 0.4, 0.15), at = V(0, 7.0, -0.78), color = SHIRT, shadow = false})
	piece(c, "RTorso", {size = V(1.95, 0.3, 1.05), at = V(0, 5.5, -0.2), color = C(70, 50, 30)})
	piece(c, "RTorso", {size = V(0.3, 0.3, 0.08), at = V(0, 5.5, -0.75), color = C(230, 190, 80), mat = M.Metal, shadow = false})
	piece(c, "RTorso", {size = V(1.3, 0.4, 0.9), at = V(0, 7.35, -0.2), color = SHIRT})
	piece(c, "RTorso", {size = V(0.8, 0.12, 0.6), at = V(0, 7.6, -0.2), color = C(110, 10, 20), shadow = false})
	for s = -1, 1, 2 do
		piece(c, "RTorso", {size = V(0.85, 0.35, 1.1), at = V(s * 0.95, 7.15, -0.2), color = COAT2})
	end
	local stump = anchor(m, "Stump", V(0, 7.7, -0.2), c, "RTorso")
	flame(stump, C(255, 120, 30), 1.1, "NeckFire")
	light(stump, C(255, 120, 30), 9, 1.5, true, "NeckLight")
	joint(c, "RCape", V(0, 7.25, 0.35), "RTorso", V(-38, 0, 0))
	piece(c, "RCape", {size = V(2.1, 3.1, 0.14), at = V(0, 5.75, 0.45), color = COAT2, name = "Cape"})
	for k = -2, 2 do
		piece(c, "RCape", {size = V(0.36, 0.4 + (k % 2) * 0.3, 0.14), at = V(k * 0.42, 4.05 - (k % 2) * 0.15, 0.45), color = COAT2, shadow = false})
	end
	joint(c, "RArmL", V(-1.35, 7.0, -0.2), "RTorso", V(55, 0, -4))
	joint(c, "RArmR", V(1.35, 7.0, -0.2), "RTorso", V(160, 0, 14))
	for s = -1, 1, 2 do
		local an = s < 0 and "RArmL" or "RArmR"
		piece(c, an, {size = V(0.8, 1.8, 0.8), at = V(s * 1.35, 6.2, -0.2), color = COAT})
		piece(c, an, {size = V(0.86, 0.3, 0.86), at = V(s * 1.35, 5.35, -0.2), color = SHIRT, shadow = false})
		piece(c, an, {size = V(0.74, 0.55, 0.74), at = V(s * 1.35, 4.95, -0.2), color = GLOVE})
	end
	joint(c, "RLegL", V(-0.5, 5.25, -0.2), "Body", V(55, 0, -32))
	joint(c, "RLegR", V(0.5, 5.25, -0.2), "Body", V(55, 0, 32))
	for s = -1, 1, 2 do
		local ln = s < 0 and "RLegL" or "RLegR"
		piece(c, ln, {size = V(0.85, 1.7, 0.85), at = V(s * 0.5, 4.4, -0.2), color = PANTS})
		piece(c, ln, {size = V(0.92, 0.9, 0.92), at = V(s * 0.5, 3.2, -0.2), color = C(26, 22, 24)})
		piece(c, ln, {size = V(0.95, 0.35, 1.3), at = V(s * 0.5, 2.9, -0.4), color = C(26, 22, 24)})
	end
	-- la calabaza en llamas, en alto en la mano derecha
	local hand = (idleWorld(c, "RArmR") * CFrame.new(1.35, 4.6, -0.2)).Position
	pumpkin(c, "RArmR", CFrame.new(hand + V(0, 0.45, 0)), 1.0, true, "Ammo", true)
	local pk = piece(c, "RArmR", {size = V(0.2, 0.2, 0.2), at = CFrame.new(hand + V(0, 0.45, 0)), posed = true, name = "Head", shadow = false})
	pk.Transparency = 1
	pk.CanQuery = false
	light(pk, C(255, 120, 30), 14, 2.2)
	flame(pk, C(255, 120, 30), 1)
	burst(pk, C(255, 150, 50), "Launch", 0.7, 9)
	local eyes = anchor(m, "HorseEyes", (hcf * CFrame.new(0, 0.2, -0.3)).Position, c, "HHead")
	light(eyes, C(255, 40, 40), 6, 1.2)
	local mane = anchor(m, "Mane", (CFrame.new(0, 4.6, -1.8) * R(-32, 0, 0) * CFrame.new(0, 1.3, 0.75)).Position, c, "Neck")
	flame(mane, FIREC, 0.9, "ManeFire")
	local tail = anchor(m, "TailFire", V(0, 3.4, 3.6), c, "Tail")
	flame(tail, FIREC, 0.8, "TailFlame")
	burst(anchor(m, "Hooves", V(0, 0.4, -1.5), c, "Body"), C(255, 130, 40), "Sparks", 0.5, 12)
	return finish(m, "Jinete", {c}, 1.12)
end

-- DRAGÓN DE HUESO: esqueleto de dragón con cuello largo, cráneo con cuernos, costillas con un fuego fantasmal dentro,
-- alas plegadas de hueso y membrana rota y cola enroscada. Al asustar despliega las alas, ruge y escupe fuego verde.
function BUILD.Dragon()
	local m = model("Dragon")
	local B1, B2, B3, DARK, GLOW, MEM = C(206, 196, 172), C(172, 162, 138), C(146, 136, 114), C(46, 42, 40), C(110, 255, 140), C(40, 58, 54)
	local c = newRig()
	joint(c, "Body", V(0, 2.8, 1.3), "Root", V(-4, 0, 0))
	-- pelvis, columna con púas, costillas y esternón
	piece(c, "Body", {size = V(1.7, 0.85, 1.2), at = V(0, 2.9, 1.4), color = B2, name = "Pelvis"})
	for k = 0, 5 do
		local zz = 1.2 - k * 0.55
		local y = 3.75 + math.sin(k / 5 * math.pi) * 0.25
		piece(c, "Body", {size = V(0.6, 0.5, 0.48), at = V(0, y, zz), color = k % 2 == 0 and B1 or B2})
		piece(c, "Body", {wedge = true, size = V(0.18, 0.55, 0.45), at = CFrame.new(0, y + 0.5, zz) * R(90, 0, 0) * R(0, 0, 0), color = B3, shadow = false})
	end
	for k = 0, 4 do
		local zz = 0.95 - k * 0.55
		for s = -1, 1, 2 do
			piece(c, "Body", {size = V(0.32, 1.3, 0.32), at = CFrame.new(s * 0.6, 3.25, zz) * R(0, 0, s * 42), color = B1})
			piece(c, "Body", {size = V(0.3, 1.05, 0.3), at = CFrame.new(s * 0.95, 2.42, zz) * R(0, 0, s * -18), color = B2})
		end
	end
	piece(c, "Body", {size = V(0.6, 0.35, 2.7), at = V(0, 2.0, -0.15), color = B2})
	piece(c, "Body", {shape = "Ball", size = V(1.4, 1.4, 1.4), at = V(0, 3.0, -0.15), color = GLOW, neon = true, t = 0.55, name = "CoreBall", shadow = false})
	-- cuello en tres partes y cabeza
	joint(c, "Neck1", V(0, 3.9, -1.75), "Body", V(-34, 0, 0))
	joint(c, "Neck2", V(0, 4.95, -1.75), "Neck1", V(-10, 0, 0))
	joint(c, "Neck3", V(0, 6.0, -1.75), "Neck2", V(18, 0, 0))
	joint(c, "Head", V(0, 7.0, -1.75), "Neck3", V(30, 0, 0))
	for k, n in {"Neck1", "Neck2", "Neck3"} do
		local y = 3.9 + (k - 1) * 1.05
		piece(c, n, {size = V(0.72 - k * 0.06, 0.85, 0.72 - k * 0.06), at = V(0, y + 0.5, -1.75), color = k % 2 == 0 and B2 or B1, name = "Neck"})
		piece(c, n, {wedge = true, size = V(0.16, 0.42, 0.4), at = CFrame.new(0, y + 0.5, -1.35) * R(0, 180, 0) * R(90, 0, 0), color = B3, shadow = false})
	end
	local hc = V(0, 7.55, -1.95)
	piece(c, "Head", {size = V(1.7, 1.35, 1.7), at = hc, color = B1, name = "Skull"})
	piece(c, "Head", {size = V(1.15, 0.82, 1.85), at = hc + V(0, -0.15, -1.6), color = B1, name = "Snout"})
	piece(c, "Head", {size = V(1.8, 0.3, 0.75), at = hc + V(0, 0.55, -0.6), color = B2})
	piece(c, "Head", {wedge = true, size = V(0.25, 0.5, 1.2), at = CFrame.new(hc + V(0, 0.85, 0.3)) * R(0, 180, 0), color = B3})
	for s = -1, 1, 2 do
		piece(c, "Head", {size = V(0.08, 0.4, 0.45), at = hc + V(s * 0.73, 0.1, -0.45), color = DARK, shadow = false})
		piece(c, "Head", {size = V(0.09, 0.2, 0.22), at = hc + V(s * 0.74, 0.1, -0.45), color = GLOW, neon = true, shadow = false, name = "Eye"})
		piece(c, "Head", {size = V(0.18, 0.12, 0.06), at = hc + V(s * 0.2, -0.05, -2.36), color = DARK, shadow = false})
		local hcf = CFrame.new(hc + V(s * 0.5, 0.45, 0.45))
		for k = 0, 2 do
			hcf = hcf * R(-35 + k * 5, s * 10, 0) * CFrame.new(0, 0.38, 0)
			piece(c, "Head", {size = V(0.32 - k * 0.07, 0.6, 0.32 - k * 0.07), at = hcf, color = k == 2 and B3 or B2})
			hcf = hcf * CFrame.new(0, 0.3, 0)
		end
		for k = 0, 3 do
			piece(c, "Head", {wedge = true, size = V(0.12, 0.3, 0.14), at = CFrame.new(hc + V(s * 0.42, -0.62, -0.95 - k * 0.38)) * R(-90, 0, 0), color = C(250, 248, 236), shadow = false})
		end
	end
	joint(c, "Jaw", hc + V(0, -0.45, -0.25), "Head", V(-6, 0, 0))
	piece(c, "Jaw", {size = V(0.9, 0.32, 2.1), at = hc + V(0, -0.72, -1.25), color = B2, name = "Jaw"})
	for s = -1, 1, 2 do
		for k = 0, 3 do
			piece(c, "Jaw", {wedge = true, size = V(0.11, 0.26, 0.13), at = CFrame.new(hc + V(s * 0.36, -0.46, -0.85 - k * 0.38)) * R(90, 0, 0), color = C(250, 248, 236), shadow = false})
		end
	end
	-- alas: WingL/R (húmero) y WingL2/R2 (antebrazo con los dedos y la membrana)
	for s = -1, 1, 2 do
		local w1, w2 = s < 0 and "WingL" or "WingR", s < 0 and "WingL2" or "WingR2"
		local sh = V(s * 0.55, 3.95, -0.7)
		joint(c, w1, sh, "Body", V(0, s * -30, s * 58))
		joint(c, w2, sh + V(s * 2.6, 0, 0), w1, V(0, s * -20, s * -125))
		piece(c, w1, {size = V(2.7, 0.3, 0.3), at = sh + V(s * 1.3, 0, 0), color = B1, name = "WingBone"})
		piece(c, w1, {size = V(2.5, 0.08, 1.7), at = sh + V(s * 1.35, -0.05, 0.95), color = MEM, t = 0.12, name = "Membrane"})
		local wr = sh + V(s * 2.6, 0, 0)
		piece(c, w2, {size = V(2.3, 0.26, 0.26), at = wr + V(s * 1.15, 0, 0), color = B2, name = "WingBone"})
		piece(c, w2, {shape = "Ball", size = V(0.45, 0.45, 0.45), at = wr, color = B3})
		for f, d in {{0.35, 2.6}, {0.9, 2.3}, {1.6, 1.9}} do
			local a0 = wr + V(s * 2.3, 0, 0)
			local a1 = wr + V(s * (2.3 + d[1] * 0.4), 0, d[2])
			beam(c, w2, a0, a1, 0.14, B1)
		end
		piece(c, w2, {size = V(2.4, 0.08, 2.2), at = wr + V(s * 1.45, -0.05, 1.1), color = MEM, t = 0.12, name = "Membrane"})
		for k, d in {{1.9, 1.7, 0.6}, {0.9, 2.05, 0.45}, {2.5, 0.9, 0.35}} do
			piece(c, w2, {size = V(d[3], 0.09, d[3]), at = wr + V(s * d[1], -0.05, d[2]), color = C(20, 18, 22), t = 0.4, shadow = false})
		end
		for k = 0, 2 do
			piece(c, w1, {size = V(0.06, 0.1, 1.5), at = sh + V(s * (0.7 + k * 0.7), -0.03, 0.9), color = C(90, 200, 120), neon = true, t = 0.6, shadow = false})
		end
		piece(c, w2, {wedge = true, size = V(0.14, 0.18, 0.45), at = CFrame.new(wr + V(s * 2.35, 0.1, -0.15)) * R(0, s * 90, 0), color = B3, shadow = false})
	end
	-- patas (las de delante, con el cuerpo)
	for _, lg in {{"FL", -0.9, -1.25, "Body"}, {"FR", 0.9, -1.25, "Body"}, {"BL", -0.95, 1.45, "Root"}, {"BR", 0.95, 1.45, "Root"}} do
		local n, x, zz = lg[1], lg[2], lg[3]
		joint(c, n, V(x, 2.9, zz), lg[4], V(zz < 0 and 10 or -8, 0, 0))
		piece(c, n, {shape = "Ball", size = V(0.8, 0.8, 0.8), at = V(x, 2.9, zz), color = B2})
		piece(c, n, {size = V(0.62, 1.5, 0.62), at = CFrame.new(x, 2.15, zz) * R(zz < 0 and 12 or -14, 0, 0), color = B1})
		piece(c, n, {shape = "Ball", size = V(0.6, 0.6, 0.6), at = V(x, 1.45, zz + (zz < 0 and -0.15 or 0.2)), color = B2})
		piece(c, n, {size = V(0.5, 1.3, 0.5), at = CFrame.new(x, 0.85, zz + (zz < 0 and -0.12 or 0.18)) * R(zz < 0 and -10 or 12, 0, 0), color = B2})
		piece(c, n, {size = V(1.0, 0.3, 0.95), at = V(x, 0.15, zz - 0.2), color = B3})
		for d = -1, 1 do
			piece(c, n, {wedge = true, size = V(0.18, 0.28, 0.5), at = V(x + d * 0.32, 0.14, zz - 0.88), color = C(60, 56, 52), shadow = false})
		end
	end
	-- cola enroscada (tres partes y la punta en hoja)
	joint(c, "Tail1", V(0, 2.95, 2.0), "Body", V(22, 25, 0))
	joint(c, "Tail2", V(0, 2.95, 3.05), "Tail1", V(8, 35, 0))
	joint(c, "Tail3", V(0, 2.95, 4.0), "Tail2", V(-6, 45, 0))
	for k, n in {"Tail1", "Tail2", "Tail3"} do
		local z0 = 2.0 + (k - 1) * 1.0
		for j = 0, 1 do
			local sz = 0.7 - k * 0.12 - j * 0.05
			piece(c, n, {size = V(sz, sz, 0.42), at = V(0, 2.95, z0 + 0.25 + j * 0.5), color = j == 0 and B1 or B2})
		end
		piece(c, n, {wedge = true, size = V(0.12, 0.35, 0.35), at = CFrame.new(0, 3.2 - k * 0.05, z0 + 0.5) * R(90, 0, 0), color = B3, shadow = false})
	end
	piece(c, "Tail3", {wedge = true, size = V(0.12, 0.9, 1.0), at = CFrame.new(0, 2.95, 5.25) * R(90, 0, 0) * R(0, 0, 0), color = B3})
	local core = anchor(m, "Core", V(0, 3.0, -0.15), c, "Body")
	light(core, GLOW, 10, 0.9)
	flame(core, GLOW, 0.8)
	local mouth = anchor(m, "Mouth", hc + V(0, -0.45, -2.5), c, "Head")
	local eyes = anchor(m, "Eyes", hc + V(0, 0.1, -0.6), c, "Head")
	light(eyes, GLOW, 5, 0.6)
	mist(anchor(m, "Fog", V(0, 0.3, 0)), C(110, 220, 140), 4, "Fog")
	burst(mouth, GLOW, "Roar", 1.2, 10).Texture = SMOKE
	return finish(m, "Dragon", {c}, 1.35)
end

--@@CRIATURAS@@

function B.build(t)
	local m = BUILD[t]()
	-- la pose de reposo se aplica ya en el mundo (BulkMoveTo)
	m.Parent = workspace
	for _, c in m:GetChildren() do
		if c:IsA("Model") and c.PrimaryPart and c.PrimaryPart.Name == "Root" then
			Rig.setPose(c, Rig.idlePose(c))
		end
		for _, d in c:GetDescendants() do
			if d:IsA("Model") and d.PrimaryPart and d.PrimaryPart.Name == "Root" then
				Rig.setPose(d, Rig.idlePose(d))
			end
		end
	end
	local old = RS.Assets.Scares:FindFirstChild(t)
	if old then
		old:Destroy()
	end
	m.Parent = RS.Assets.Scares
	return m
end

function B.all()
	local done = {}
	for t in BUILD do
		local ok, err = pcall(B.build, t)
		table.insert(done, t .. (ok and "" or (" ERROR " .. tostring(err))))
	end
	return done
end

return B
