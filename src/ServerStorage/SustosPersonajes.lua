-- Personajes nuevos con el estilo de siempre (piezas y funciones de SustosBloques): Hombre Calabaza, Esqueleto,
-- Frankenstein, Demonio y Rey Calabaza. Todos se quedan en su sitio: solo se animan y lanzan cosas.
-- Uso (barra de comandos): require(game.ServerStorage.SustosPersonajes).all()  ó  .build("Esqueleto")
local B = require(script.Parent.SustosBloques)

local V, C, R = B.V, B.C, B.R
local M = Enum.Material
local newRig, joint, piece, face, humanoid, prop = B.newRig, B.joint, B.piece, B.face, B.humanoid, B.prop
local light, emitter, mist, sparkles, flame, burst, anchor, tuft = B.light, B.emitter, B.mist, B.sparkles, B.flame, B.burst, B.anchor, B.tuft
local model, finish, pumpkin = B.model, B.finish, B.pumpkin
local SPARK, SMOKE = B.SPARK, B.SMOKE

local P = {}
local BUILD = B.BUILD
local NAMES = {"HombreCalabaza", "Esqueleto", "Frankenstein", "Demonio", "ReyCalabaza"}

local STRAW = {C(240, 204, 92), C(214, 168, 64), C(250, 222, 120)}
local LEAVES = {C(214, 96, 34), C(178, 60, 30), C(236, 160, 40), C(120, 70, 36)}
local INK = C(28, 18, 14)
local BONE, BONE_D = C(226, 216, 192), C(188, 176, 150)

-- Dónde queda la articulación 'limb' en la pose de reposo, respecto a Root (como en SustosBloques)
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

-- Barra de a a b (huesos, cables, varillas): nunca del todo vertical
local function bar(c, limb, a, b, t, color, o)
	local opts = o and table.clone(o) or {}
	opts.size = V(t, t, (b - a).Magnitude)
	opts.at = CFrame.lookAt((a + b) / 2, b)
	opts.color = color
	if c then
		return piece(c, limb, opts)
	end
	return opts
end

-- Marca todas las piezas de esas articulaciones con un grupo (lo que se lanza y vuelve: la calavera)
local function tag(c, limbs, groupName)
	for _, p in c.m:GetChildren() do
		if p:IsA("BasePart") and table.find(limbs, p:GetAttribute("Limb")) then
			p:SetAttribute("Group", groupName)
		end
	end
end

---------- HOMBRE CALABAZA ----------
-- Desplomado sobre un montón de hojas secas, con su abrigo remendado, enredaderas por los brazos y paja saliendo de
-- las mangas. Al asustar: la cara se le enciende en llamas, se yergue y te lanza sus enredaderas a los tobillos.
function BUILD.HombreCalabaza()
	local m = model("HombreCalabaza")
	-- (sin base: como el resto de sustos, va directamente sobre el suelo)
	pumpkin(m, nil, CFrame.new(-1.0, 0.42, -0.8) * R(0, 30, 0), 0.6, false)
	pumpkin(m, nil, CFrame.new(1.05, 0.36, -0.6) * R(0, -20, 0), 0.5, false)
	-- horca clavada detrás
	local pole = CFrame.new(1.15, 1.85, 0.85) * R(0, 0, -7)
	prop(m, {size = V(0.16, 3.7, 0.16), at = pole, color = C(116, 78, 46), mat = M.Wood})
	prop(m, {size = V(0.7, 0.12, 0.12), at = pole * CFrame.new(0, 1.9, 0), color = C(70, 70, 76), mat = M.Metal})
	for d = -1, 1 do
		prop(m, {size = V(0.08, 0.6, 0.08), at = pole * CFrame.new(d * 0.3, 2.2, 0), color = C(70, 70, 76), mat = M.Metal, shadow = false})
	end

	local c = newRig()
	local COAT, COAT_D, PANTS, GLOVE, VINE, LEAF = C(74, 108, 58), C(52, 78, 42), C(96, 66, 42), C(70, 50, 34), C(56, 120, 44), C(96, 168, 62)
	local h = humanoid(c, {hip = 2.0, torso = V(1.8, 1.9, 1.0), head = V(1.6, 1.4, 1.5), arm = V(0.85, 1.9, 0.85), leg = V(0.9, 2.0, 0.95),
		shirt = COAT, pants = PANTS, hands = GLOVE, handH = 0.5, mat = M.Fabric, noHead = true,
		idle = {Torso = V(-12, 0, 4), Head = V(-26, 0, 16), ArmL = V(6, 0, -10), ArmR = V(12, 0, 12), LegL = V(5, 0, -3), LegR = V(-4, 0, 4)}})
	local top = h.top
	local tc = V(0, h.hip + 0.95, 0)
	-- abrigo: solapas, remiendo, botones y una bufanda roja
	for s = -1, 1, 2 do
		piece(c, "Torso", {wedge = true, size = V(0.08, 0.9, 0.45), at = CFrame.new(s * 0.3, top - 0.55, -0.53) * R(0, s * 90, 0), color = COAT_D, mat = M.Fabric, shadow = false})
	end
	piece(c, "Torso", {size = V(0.55, 0.5, 0.06), at = CFrame.new(-0.45, tc.Y - 0.35, -0.52) * R(0, 0, 10), color = C(150, 120, 70), mat = M.Fabric})
	for k = 0, 2 do
		piece(c, "Torso", {size = V(0.16, 0.16, 0.06), at = V(0.15, top - 0.7 - k * 0.42, -0.52), color = C(60, 40, 26), shadow = false})
	end
	piece(c, "Torso", {size = V(1.9, 0.32, 1.1), at = V(0, top - 0.12, 0), color = C(160, 42, 40), mat = M.Fabric})
	piece(c, "Torso", {size = V(0.35, 0.9, 0.12), at = CFrame.new(0.45, top - 0.65, -0.56) * R(0, 0, -12), color = C(160, 42, 40), mat = M.Fabric})
	piece(c, "Torso", {size = V(1.86, 0.2, 1.06), at = V(0, h.hip + 0.12, 0), color = C(204, 170, 104), mat = M.Fabric})
	tuft(c, "Torso", V(0, top - 0.1, 0.1), 6, 0.55, V(0, 0.5, 0.3).Unit, STRAW, 0.4)
	-- enredaderas por el cuerpo y los brazos, con hojas
	for k = 0, 1 do
		piece(c, "Torso", {size = V(2.0, 0.12, 0.14), at = CFrame.new(0, tc.Y - 0.3 + k * 0.6, -0.5) * R(0, 0, k == 0 and 28 or -22), color = VINE, shadow = false})
	end
	for s = -1, 1, 2 do
		local an, ln = s < 0 and "ArmL" or "ArmR", s < 0 and "LegL" or "LegR"
		local ax = s * h.ax
		for k = 1, 3 do
			piece(c, an, {size = V(0.95, 0.12, 0.95), at = CFrame.new(ax, top - 0.25 - k * 0.42, 0) * R(0, 0, s * (16 + k * 6)), color = VINE, shadow = false})
			if k == 2 then
				piece(c, an, {size = V(0.3, 0.06, 0.22), at = CFrame.new(ax + s * 0.3, top - 0.3 - k * 0.42, -0.5) * R(0, 0, s * 30), color = LEAF, shadow = false})
			end
		end
		tuft(c, an, V(ax, top - h.A.Y - 0.02, 0), 6, 0.24, V(0, -1, 0), STRAW, 0.45)
		tuft(c, ln, V(s * 0.45, 0.12, 0), 5, 0.26, V(0, -0.4, -1).Unit, STRAW, 0.4)
		piece(c, ln, {size = V(0.95, 0.35, 1.25), at = V(s * 0.45, 0.17, -0.15), color = C(60, 40, 28)})
	end
	-- cabeza de calabaza (la cara está apagada hasta el susto) con su tallo y dos hojas
	pumpkin(c, "Head", CFrame.new(0, top + 0.82, 0), 1.45, false)
	piece(c, "Head", {shape = "Cyl", size = V(0.75, 0.22, 0.75), at = V(0, top + 0.08, 0), color = C(64, 120, 46)})
	for s = -1, 1, 2 do
		piece(c, "Head", {size = V(0.55, 0.06, 0.35), at = CFrame.new(s * 0.32, top + 1.72, 0.05) * R(0, s * 30, s * -25), color = LEAF, shadow = false})
	end
	local glow = anchor(m, "FaceGlow", V(0, top + 0.8, -0.3), c, "Head")
	light(glow, C(255, 140, 30), 12, 2.4, false, "FaceLight")
	local fire = flame(anchor(m, "Crown", V(0, top + 1.6, 0), c, "Head"), C(255, 130, 30), 1.0, "HeadFire")
	fire.Rate = 0
	burst(glow, C(255, 170, 60), "Embers", 0.4, 7)
	burst(anchor(m, "Leaves", V(0, 0.4, 0)), LEAVES[1], "LeafBurst", 0.45, 7)
	return finish(m, "HombreCalabaza", {c})
end

---------- ESQUELETO ----------
-- Apoyado en su lápida, con la calavera caída y un sombrero de copa abollado. Al asustar se recompone de golpe, se ríe
-- castañeteando la mandíbula y te lanza su propia calavera en llamas (que vuelve a su sitio).
function BUILD.Esqueleto()
	local m = model("Esqueleto")
	local STONE, STONE_D, MOSS = C(120, 118, 128), C(82, 80, 90), C(76, 116, 62)
	local z = 1.1
	prop(m, {size = V(2.3, 2.9, 0.45), at = V(0, 1.65, z), color = STONE, mat = M.Slate, name = "Tomb"})
	prop(m, {shape = "Cyl", axis = "Z", size = V(2.3, 2.3, 0.45), at = V(0, 3.1, z), color = STONE, mat = M.Slate})
	prop(m, {size = V(2.7, 0.3, 0.75), at = V(0, 0.15, z), color = STONE_D, mat = M.Slate})
	prop(m, {size = V(0.18, 1.2, 0.06), at = V(0, 3.4, z - 0.25), color = STONE_D, shadow = false})
	prop(m, {size = V(0.75, 0.18, 0.06), at = V(0, 3.65, z - 0.25), color = STONE_D, shadow = false})
	prop(m, {size = V(0.06, 0.9, 0.06), at = CFrame.new(0.75, 2.2, z - 0.25) * R(0, 0, 25), color = C(50, 48, 56), shadow = false})
	for k = 1, 4 do
		prop(m, {size = V(0.5, 0.18, 0.5), at = CFrame.new(-1.0 + k * 0.45, 4.15 - math.abs(k - 2.5) * 0.25, z) * R(0, k * 40, (k - 2.5) * 12), color = MOSS, mat = M.Grass, shadow = false})
	end
	-- huesos sueltos y una vela (sin base de tierra)
	for k = 1, 3 do
		prop(m, {size = V(0.14, 0.14, 0.7), at = CFrame.new(-1.0 + k * 0.55, 0.3, -1.0 + (k % 2) * 0.25) * R(0, k * 55, 0), color = BONE_D, shadow = false})
	end
	prop(m, {shape = "Cyl", size = V(0.3, 0.7, 0.3), at = V(-1.15, 0.55, -0.85), color = C(236, 228, 200)})
	local wick = anchor(m, "Candle", V(-1.15, 1.0, -0.85))
	flame(wick, C(140, 255, 160), 0.35, "CandleFire")
	light(wick, C(140, 255, 160), 7, 1, true, "CandleLight")

	-- el esqueleto
	local c = newRig()
	local hip = 2.5
	local sh = hip + 1.85
	joint(c, "Torso", V(0, hip, 0), nil, V(8, 0, -4))
	joint(c, "Head", V(0, hip + 2.05, 0), nil, V(-30, 12, 18))
	joint(c, "ArmL", V(-0.95, sh, 0), nil, V(-4, 0, -12))
	joint(c, "ArmR", V(0.95, sh, 0), nil, V(8, 0, 16))
	joint(c, "LegL", V(-0.4, hip, 0), nil, V(4, 0, -4))
	joint(c, "LegR", V(0.4, hip, 0), nil, V(-3, 0, 5))
	-- pelvis y taparrabos hecho jirones
	piece(c, "Root", {size = V(1.2, 0.45, 0.65), at = V(0, hip, 0), color = BONE_D, name = "Pelvis"})
	for k = -2, 2 do
		piece(c, "Root", {size = V(0.3, 0.6 + (k % 2) * 0.25, 0.08), at = V(k * 0.24, hip - 0.45 - (k % 2) * 0.12, -0.36), color = C(70, 40, 90), mat = M.Fabric, shadow = false})
	end
	-- piernas
	for s = -1, 1, 2 do
		local ln = s < 0 and "LegL" or "LegR"
		local x = s * 0.4
		piece(c, ln, {size = V(0.26, 1.15, 0.26), at = V(x, hip - 0.65, 0), color = BONE})
		piece(c, ln, {shape = "Ball", size = V(0.38, 0.38, 0.38), at = V(x, hip - 1.3, 0), color = BONE_D})
		piece(c, ln, {size = V(0.24, 1.05, 0.24), at = V(x, hip - 1.85, 0), color = BONE})
		piece(c, ln, {size = V(0.42, 0.2, 0.75), at = V(x, 0.1, -0.18), color = BONE_D})
		for d = -1, 1 do
			piece(c, ln, {size = V(0.08, 0.1, 0.25), at = V(x + d * 0.13, 0.06, -0.62), color = BONE, shadow = false})
		end
	end
	-- columna, costillas y esternón
	for k = 0, 6 do
		piece(c, "Torso", {size = V(0.3, 0.2, 0.3), at = V(0, hip + 0.3 + k * 0.25, 0.22), color = k % 2 == 0 and BONE or BONE_D})
	end
	for k = 0, 3 do
		local y = hip + 0.8 + k * 0.3
		local w = 0.5 + math.sin((k + 1) / 5 * math.pi) * 0.12
		for s = -1, 1, 2 do
			piece(c, "Torso", {size = V(0.12, 0.12, 0.7), at = V(s * w, y, -0.02), color = BONE, shadow = false})
			piece(c, "Torso", {size = V(w - 0.1, 0.12, 0.12), at = V(s * (w / 2 + 0.07), y, -0.36), color = BONE, shadow = false})
			piece(c, "Torso", {size = V(w, 0.12, 0.12), at = V(s * w / 2, y, 0.3), color = BONE_D, shadow = false})
		end
	end
	piece(c, "Torso", {size = V(0.18, 1.05, 0.12), at = V(0, hip + 1.25, -0.38), color = BONE_D})
	piece(c, "Torso", {size = V(1.75, 0.16, 0.2), at = V(0, sh, -0.05), color = BONE})
	piece(c, "Torso", {size = V(0.22, 0.3, 0.22), at = V(0, hip + 1.98, 0.05), color = BONE_D})
	-- brazos
	for s = -1, 1, 2 do
		local an = s < 0 and "ArmL" or "ArmR"
		local x = s * 0.95
		piece(c, an, {shape = "Ball", size = V(0.36, 0.36, 0.36), at = V(x, sh, 0), color = BONE_D})
		piece(c, an, {size = V(0.24, 1.0, 0.24), at = V(x, sh - 0.55, 0), color = BONE})
		piece(c, an, {shape = "Ball", size = V(0.3, 0.3, 0.3), at = V(x, sh - 1.1, 0), color = BONE_D})
		piece(c, an, {size = V(0.22, 0.95, 0.22), at = V(x, sh - 1.62, 0), color = BONE})
		piece(c, an, {size = V(0.36, 0.3, 0.2), at = V(x, sh - 2.22, 0), color = BONE_D, name = an .. "Hand"})
		for d = -1, 1 do
			piece(c, an, {size = V(0.07, 0.32, 0.07), at = CFrame.new(x + d * 0.11, sh - 2.5, -0.02) * R(0, 0, d * 8), color = BONE, shadow = false})
		end
	end
	-- calavera: cráneo, pómulos, cuencas oscuras con un punto rojo, dientes y mandíbula que castañetea
	local hc = V(0, hip + 2.85, -0.02)
	local hs = V(1.25, 1.05, 1.2)
	piece(c, "Head", {size = V(0.22, 0.35, 0.22), at = V(0, hip + 2.15, 0.05), color = BONE_D})
	piece(c, "Head", {size = hs, at = hc, color = BONE, name = "Skull"})
	piece(c, "Head", {size = V(1.0, 0.36, 1.0), at = hc + V(0, -0.62, -0.08), color = BONE})
	face(c, "Head", hc, hs, {
		{-0.29, -0.02, 0.36, 0.36, INK, {name = "Socket"}}, {0.29, -0.02, 0.36, 0.36, INK, {name = "Socket"}},
		{-0.29, -0.02, 0.11, 0.11, C(255, 60, 50), {neon = true, out = 0.01, name = "Eye"}}, {0.29, -0.02, 0.11, 0.11, C(255, 60, 50), {neon = true, out = 0.01, name = "Eye"}},
		{0, -0.33, 0.16, 0.18, INK, {rot = R(0, 0, 45)}},
		{-0.42, 0.34, 0.08, 0.28, C(160, 150, 126), {rot = R(0, 0, -30)}},
	})
	for k = -2, 2 do
		piece(c, "Head", {size = V(0.13, 0.17, 0.08), at = hc + V(k * 0.15, -0.72, -0.58), color = C(250, 246, 230), shadow = false})
	end
	joint(c, "Jaw", hc + V(0, -0.65, 0.25), "Head", V(-4, 0, 0))
	piece(c, "Jaw", {size = V(0.92, 0.24, 0.95), at = hc + V(0, -0.95, -0.08), color = BONE_D, name = "Jaw"})
	for k = -2, 2 do
		piece(c, "Jaw", {size = V(0.12, 0.15, 0.08), at = hc + V(k * 0.15, -0.8, -0.55), color = C(250, 246, 230), shadow = false})
	end
	-- sombrero de copa abollado
	local hy = hc.Y + 0.55
	piece(c, "Head", {shape = "Cyl", size = V(1.6, 0.1, 1.6), at = CFrame.new(0.05, hy, 0) * R(0, 0, -8), color = C(34, 28, 40)})
	piece(c, "Head", {size = V(0.95, 0.85, 0.95), at = CFrame.new(0.1, hy + 0.45, 0) * R(-4, 0, -10), color = C(34, 28, 40)})
	piece(c, "Head", {size = V(1.0, 0.18, 1.0), at = CFrame.new(0.08, hy + 0.15, 0) * R(0, 0, -9), color = C(110, 40, 140), shadow = false})
	tag(c, {"Head", "Jaw"}, "Skull")
	local eyes = anchor(m, "Eyes", hc + V(0, 0, -0.5), c, "Head")
	light(eyes, C(255, 60, 50), 6, 1.2)
	burst(anchor(m, "Rattle", V(0, hip + 1.2, 0), c, "Torso"), BONE, "BoneDust", 0.45, 7).Texture = SMOKE
	burst(anchor(m, "Dirt", V(0, 0.3, -0.3)), C(110, 80, 56), "DirtBurst", 0.9, 6).Texture = SMOKE
	mist(anchor(m, "Fog", V(0, 0.3, 0)), C(120, 220, 150), 2, "Fog")
	return finish(m, "Esqueleto", {c})
end

---------- FRANKENSTEIN ----------
-- Atado con correas a una mesa de laboratorio inclinada, entre dos bobinas de Tesla. Al asustar cae un rayo, revienta
-- las correas, ruge con los brazos por delante y las bobinas te lanzan descargas.
function BUILD.Frankenstein()
	local m = model("Frankenstein")
	local METAL, METAL_D, COPPER, WOODT, LEATHER = C(110, 114, 124), C(58, 60, 68), C(204, 118, 58), C(96, 74, 56), C(92, 58, 36)
	local tz = 1.15
	local tcf = CFrame.new(0, 3.45, tz) * R(8, 0, 0)
	prop(m, {size = V(3.0, 6.7, 0.35), at = tcf, color = WOODT, mat = M.Wood, name = "Table"})
	for s = -1, 1, 2 do
		prop(m, {size = V(0.24, 6.9, 0.5), at = tcf * CFrame.new(s * 1.55, 0, 0), color = METAL_D, mat = M.Metal})
	end
	prop(m, {size = V(3.3, 0.3, 0.55), at = tcf * CFrame.new(0, 3.45, 0), color = METAL_D, mat = M.Metal})
	prop(m, {size = V(1.1, 2.2, 0.9), at = V(0, 1.1, tz + 0.55), color = METAL_D, mat = M.Metal})
	-- correas por delante del monstruo (revientan al despertar) con sus hebillas
	for _, y in {1.5, 3.0, 4.45} do
		local zz = y > 4 and -0.78 or -0.72
		local strap = prop(m, {size = V(3.05, 0.32, 0.1), at = V(0, y, zz), color = LEATHER, mat = M.Fabric, name = "Strap"})
		strap:SetAttribute("Group", "Straps")
		local buckle = prop(m, {size = V(0.36, 0.42, 0.06), at = V(0.6, y, zz - 0.06), color = C(200, 180, 110), mat = M.Metal, shadow = false})
		buckle:SetAttribute("Group", "Straps")
		for s = -1, 1, 2 do
			local side = prop(m, {size = V(0.1, 0.32, tz - zz), at = V(s * 1.5, y, (tz + zz) / 2), color = LEATHER, mat = M.Fabric, shadow = false})
			side:SetAttribute("Group", "Straps")
		end
	end
	-- bobinas de Tesla a los lados
	for s = -1, 1, 2 do
		local x, z = s * 1.85, 0.35
		prop(m, {shape = "Cyl", size = V(0.95, 0.45, 0.95), at = V(x, 0.22, z), color = METAL_D, mat = M.Metal})
		prop(m, {shape = "Cyl", size = V(0.42, 2.8, 0.42), at = V(x, 1.85, z), color = C(40, 40, 46), mat = M.Metal})
		for k = 0, 6 do
			prop(m, {shape = "Cyl", size = V(0.72, 0.13, 0.72), at = V(x, 0.95 + k * 0.32, z), color = COPPER, mat = M.Metal, shadow = false})
		end
		prop(m, {shape = "Ball", size = V(1.0, 1.0, 1.0), at = V(x, 3.65, z), color = METAL, mat = M.Metal, refl = 0.25, name = "CoilTop"})
		local a = anchor(m, s < 0 and "CoilL" or "CoilR", V(x, 3.65, z))
		light(a, C(140, 190, 255), 8, 1, true, "CoilLight")
		sparkles(a, C(150, 200, 255), 3, "Static")
		burst(a, C(170, 210, 255), "Zap", 0.5, 10)
		prop(m, bar(nil, nil, V(x, 0.12, z + 0.3), V(s * 0.45, 0.12, tz + 0.15), 0.12, C(26, 26, 30)))
	end

	-- el monstruo
	local c = newRig()
	local SKIN, SKIN_D, JACKET, PANTS, BOOT, HAIR = C(134, 180, 110), C(100, 142, 84), C(44, 40, 52), C(62, 58, 72), C(26, 24, 30), C(22, 22, 26)
	local h = humanoid(c, {hip = 2.8, torso = V(2.6, 2.6, 1.3), head = V(1.7, 1.9, 1.6), arm = V(1.0, 2.9, 1.0), leg = V(1.15, 2.8, 1.2),
		shirt = JACKET, arms = JACKET, pants = PANTS, skin = SKIN, hands = SKIN, handH = 0.95, mat = M.Fabric, headMat = M.Plastic, handMat = M.Plastic,
		idle = {Torso = V(6, 0, 0), Head = V(-22, 0, 10), ArmL = V(2, 0, -6), ArmR = V(2, 0, 6), LegL = V(0, 0, -2), LegR = V(0, 0, 2)}})
	local top = h.top
	local tc = V(0, h.hip + 1.3, 0)
	-- camisa rota, solapas, cinturón y pecho con costuras
	piece(c, "Torso", {size = V(1.1, 1.8, 0.06), at = V(0, tc.Y + 0.2, -0.66), color = C(170, 168, 160), mat = M.Fabric})
	piece(c, "Torso", {wedge = true, size = V(0.06, 0.6, 1.1), at = CFrame.new(0, top - 0.32, -0.69) * R(0, 90, 180), color = SKIN})
	for s = -1, 1, 2 do
		piece(c, "Torso", {wedge = true, size = V(0.08, 1.4, 0.55), at = CFrame.new(s * 0.5, top - 0.75, -0.68) * R(0, s * 90, 0), color = C(30, 28, 36), mat = M.Fabric, shadow = false})
	end
	for k = 0, 2 do
		piece(c, "Torso", {size = V(0.35, 0.06, 0.08), at = CFrame.new(-0.2, tc.Y + 0.1 - k * 0.3, -0.7) * R(0, 0, 15), color = INK, shadow = false})
	end
	piece(c, "Torso", {size = V(2.66, 0.3, 1.36), at = V(0, h.hip + 0.2, 0), color = C(30, 24, 22)})
	piece(c, "Torso", {size = V(0.4, 0.34, 0.08), at = V(0, h.hip + 0.2, -0.7), color = C(150, 150, 160), mat = M.Metal, shadow = false})
	-- tornillos del cuello
	for s = -1, 1, 2 do
		piece(c, "Head", {shape = "Cyl", axis = "X", size = V(0.5, 0.32, 0.32), at = V(s * 0.95, top + 0.25, 0.05), color = C(150, 152, 160), mat = M.Metal})
		piece(c, "Head", {shape = "Cyl", axis = "X", size = V(0.12, 0.44, 0.44), at = V(s * 1.2, top + 0.25, 0.05), color = C(110, 112, 120), mat = M.Metal})
	end
	-- manos: costuras en las muñecas; botas enormes
	for s = -1, 1, 2 do
		local an, ln = s < 0 and "ArmL" or "ArmR", s < 0 and "LegL" or "LegR"
		piece(c, an, {size = V(1.04, 0.08, 1.04), at = V(s * h.ax, top - h.A.Y + 0.95, 0), color = INK, shadow = false})
		piece(c, an, {size = V(1.06, 0.3, 1.06), at = V(s * h.ax, top - h.A.Y + 1.1, 0), color = C(30, 28, 36), mat = M.Fabric})
		piece(c, ln, {size = V(1.35, 0.7, 1.65), at = V(s * 0.575, 0.35, -0.18), color = BOOT})
		piece(c, ln, {size = V(1.3, 0.15, 1.6), at = V(s * 0.575, 0.78, -0.16), color = C(50, 46, 54)})
	end
	-- cabeza: pelo plano con flequillo, cejas pesadas, cicatriz con puntos, ojos amarillentos
	local hc, hs = h.hc, h.hs
	piece(c, "Head", {size = V(1.8, 0.4, 1.7), at = hc + V(0, 0.85, 0.02), color = HAIR})
	for k = -2, 2 do
		piece(c, "Head", {size = V(0.36, 0.3 + (k % 2) * 0.12, 0.1), at = hc + V(k * 0.34, 0.58 - (k % 2) * 0.06, -0.82), color = HAIR, shadow = false})
	end
	piece(c, "Head", {size = V(1.7, 0.28, 0.25), at = hc + V(0, 0.22, -0.82), color = SKIN_D})
	face(c, "Head", hc, hs, {
		{-0.4, 0.0, 0.36, 0.2, C(240, 236, 150), {name = "Eye"}}, {0.4, 0.0, 0.36, 0.2, C(240, 236, 150), {name = "Eye"}},
		{-0.4, 0.0, 0.1, 0.16, INK, {out = 0.01}}, {0.4, 0.0, 0.1, 0.16, INK, {out = 0.01}},
		{0, -0.55, 0.8, 0.08, INK, {name = "Mouth"}},
		{0.25, 0.43, 0.9, 0.05, INK, {out = 0.08}},
		{-0.05, 0.43, 0.04, 0.2, INK, {out = 0.08}}, {0.15, 0.43, 0.04, 0.2, INK, {out = 0.08}}, {0.35, 0.43, 0.04, 0.2, INK, {out = 0.08}}, {0.55, 0.43, 0.04, 0.2, INK, {out = 0.08}},
		{-0.6, -0.35, 0.04, 0.4, INK, {rot = R(0, 0, 20)}},
	})
	piece(c, "Head", {size = V(0.3, 0.42, 0.25), at = hc + V(0, -0.15, -0.9), color = SKIN_D})
	local eyes = anchor(m, "Eyes", hc + V(0, 0, -0.85), c, "Head")
	light(eyes, C(220, 255, 120), 7, 1.4, false)
	burst(anchor(m, "Chest", tc, c, "Torso"), C(160, 210, 255), "Sparks", 0.4, 12)
	burst(anchor(m, "Snap", V(0, 3, -0.8)), C(130, 90, 60), "StrapBurst", 0.5, 9).Texture = SMOKE
	mist(anchor(m, "Fog", V(0, 0.3, 0)), C(150, 200, 255), 2, "Fog")
	return finish(m, "Frankenstein", {c})
end

---------- DEMONIO ----------
-- Agazapado en el centro de un pentagrama que arde, con cuernos retorcidos, alas de murciélago plegadas, cola de punta
-- y pezuñas. Al asustar: el pentagrama estalla en llamas, se yergue, abre las alas, ruge y te lanza un orbe de fuego.
function BUILD.Demonio()
	local m = model("Demonio")
	local SKIN, SKIN_D, SKIN_L, HORN, HOOF, WING, CLAW = C(176, 40, 44), C(116, 24, 32), C(214, 86, 72), C(42, 34, 38), C(30, 24, 26), C(86, 20, 30), C(250, 236, 200)
	local LAVA = C(255, 110, 30)
	-- velas en las puntas de un pentagrama invisible (sin base: el círculo, las runas y las grietas se quitaron)
	local cz = 0.2
	local pts = {}
	for k = 0, 4 do
		local a = math.rad(-90 + k * 72)
		pts[k + 1] = V(math.cos(a) * 2.15, 0.09, cz + math.sin(a) * 2.15)
	end
	for k = 1, 5 do
		local p = pts[k]
		prop(m, {shape = "Cyl", size = V(0.26, 0.5, 0.26), at = V(p.X * 1.12, 0.3, cz + (p.Z - cz) * 1.12), color = C(40, 30, 34)})
		flame(anchor(m, "Candle", V(p.X * 1.12, 0.65, cz + (p.Z - cz) * 1.12)), LAVA, 0.3, "CandleFire")
	end
	local pent = anchor(m, "Pentagram", V(0, 0.4, cz))
	light(pent, LAVA, 14, 1.2, true, "PentLight")
	emitter(pent, {
		Name = "Embers", Texture = SPARK, Color = ColorSequence.new(C(255, 160, 50), C(255, 60, 20)), Rate = 6, Lifetime = NumberRange.new(1.2, 2),
		Speed = NumberRange.new(1, 2.5), SpreadAngle = Vector2.new(60, 60), LightEmission = 1, Acceleration = V(0, 1, 0),
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0)}), EmissionDirection = Enum.NormalId.Top,
	})
	burst(pent, LAVA, "Hellfire", 1.6, 12).Texture = B.FIRE

	-- el demonio
	local c = newRig()
	local h = humanoid(c, {hip = 3.0, torso = V(3.0, 2.8, 1.6), head = V(1.9, 1.8, 1.8), arm = V(1.25, 3.2, 1.25), leg = V(1.3, 3.0, 1.35),
		shirt = SKIN, arms = SKIN, pants = SKIN_D, skin = SKIN, hands = SKIN_D, handH = 0.75,
		idle = {Torso = V(-16, 0, 0), Head = V(14, 0, 0), ArmL = V(28, 0, -14), ArmR = V(32, 0, 14), LegL = V(16, 0, -4), LegR = V(-8, 0, 4)}})
	local top = h.top
	-- músculos: pectorales y abdominales
	for s = -1, 1, 2 do
		piece(c, "Torso", {size = V(1.25, 0.8, 0.12), at = V(s * 0.68, top - 0.6, -0.82), color = SKIN_L})
		for k = 0, 2 do
			piece(c, "Torso", {size = V(0.55, 0.4, 0.1), at = V(s * 0.32, top - 1.35 - k * 0.45, -0.82), color = SKIN_L})
		end
		piece(c, "Torso", {wedge = true, size = V(0.5, 0.8, 0.6), at = CFrame.new(s * 1.45, top + 0.2, 0) * R(0, 0, s * -20), color = HORN})
	end
	-- taparrabos negro con hebilla de calavera dorada
	piece(c, "Torso", {size = V(3.06, 0.4, 1.66), at = V(0, h.hip + 0.2, 0), color = C(30, 24, 26)})
	piece(c, "Root", {size = V(1.0, 1.2, 0.1), at = V(0, h.hip - 0.5, -0.82), color = C(40, 30, 34), mat = M.Fabric})
	piece(c, "Torso", {size = V(0.5, 0.45, 0.1), at = V(0, h.hip + 0.2, -0.86), color = C(240, 190, 70), mat = M.Metal})
	-- patas peludas con pezuñas
	for s = -1, 1, 2 do
		local ln = s < 0 and "LegL" or "LegR"
		piece(c, ln, {size = V(1.4, 0.55, 1.5), at = V(s * 0.65, 0.27, -0.1), color = HOOF})
		piece(c, ln, {size = V(0.14, 0.5, 0.3), at = V(s * 0.65, 0.27, -0.85), color = C(60, 50, 52), shadow = false})
		tuft(c, ln, V(s * 0.65, 0.65, 0), 7, 0.55, V(0, -0.5, 0), {SKIN_D, C(80, 18, 24)}, 0.5, 0.2)
		local an = s < 0 and "ArmL" or "ArmR"
		for d = -1, 1 do
			piece(c, an, {wedge = true, size = V(0.2, 0.6, 0.32), at = CFrame.new(s * h.ax + d * 0.4, top - h.A.Y - 0.25, -0.35) * R(-90, 0, 0), color = CLAW, shadow = false})
		end
		piece(c, an, {size = V(1.3, 0.3, 1.3), at = V(s * h.ax, top - h.A.Y + 0.85, 0), color = C(40, 30, 34)})
	end
	-- cabeza: cejas, ojos amarillos, nariz, mandíbula con colmillos, orejas puntiagudas y cuernos retorcidos
	local hc, hs = h.hc, h.hs
	piece(c, "Head", {size = V(1.95, 0.32, 0.3), at = hc + V(0, 0.32, -0.9), color = SKIN_D})
	piece(c, "Head", {size = V(0.45, 0.45, 0.3), at = hc + V(0, -0.05, -1.0), color = SKIN_D})
	face(c, "Head", hc, hs, {
		{-0.48, 0.1, 0.45, 0.2, C(255, 220, 40), {neon = true, name = "Eye", rot = R(0, 0, -14), out = 0.02}}, {0.48, 0.1, 0.45, 0.2, C(255, 220, 40), {neon = true, name = "Eye", rot = R(0, 0, 14), out = 0.02}},
		{0, -0.5, 1.2, 0.14, INK, {name = "Mouth"}},
	})
	joint(c, "Jaw", hc + V(0, -0.6, -0.4), "Head")
	piece(c, "Jaw", {size = V(1.5, 0.4, 1.1), at = hc + V(0, -1.0, -0.4), color = SKIN, name = "Jaw"})
	piece(c, "Jaw", {wedge = true, size = V(0.8, 0.3, 0.5), at = CFrame.new(hc + V(0, -1.3, -0.75)) * R(180, 0, 0), color = SKIN_D})
	for s = -1, 1, 2 do
		piece(c, "Head", {wedge = true, size = V(0.18, 0.4, 0.2), at = CFrame.new(hc + V(s * 0.38, -0.78, -0.95)) * R(-90, 0, 0), color = CLAW, shadow = false})
		piece(c, "Jaw", {wedge = true, size = V(0.16, 0.32, 0.18), at = CFrame.new(hc + V(s * 0.55, -0.68, -0.92)) * R(90, 0, 0), color = CLAW, shadow = false})
		piece(c, "Head", {wedge = true, size = V(0.15, 0.8, 0.5), at = CFrame.new(hc + V(s * 1.05, 0.2, 0.1)) * R(0, s * -90, s * -40), color = SKIN})
		local hcf = CFrame.new(hc + V(s * 0.75, 0.8, 0.1)) * R(0, 0, s * -75)
		for k = 0, 3 do
			local w = 0.48 - k * 0.09
			hcf = hcf * CFrame.new(0, 0.25, 0)
			piece(c, "Head", {size = V(w, 0.52, w), at = hcf, color = k % 2 == 0 and HORN or C(66, 54, 58)})
			hcf = hcf * CFrame.new(0, 0.25, 0) * R(-10, 0, s * 20)
		end
		piece(c, "Head", {wedge = true, size = V(0.14, 0.45, 0.2), at = hcf * CFrame.new(0, 0.18, 0), color = C(230, 220, 200)})
	end
	-- alas (en reposo, plegadas a la espalda): hueso del brazo, dedos y membrana
	for s = -1, 1, 2 do
		local w = s < 0 and "WingL" or "WingR"
		local p0 = V(s * 0.7, top - 0.45, 0.85)
		joint(c, w, p0, "Torso", V(0, s * -70, s * 12))
		local p1 = p0 + V(s * 2.6, 1.4, 0.2)
		local p2 = p1 + V(s * 1.7, -0.5, 0.1)
		bar(c, w, p0, p1, 0.3, SKIN_D)
		bar(c, w, p1, p2, 0.24, SKIN_D)
		piece(c, w, {shape = "Ball", size = V(0.42, 0.42, 0.42), at = p1, color = HORN})
		piece(c, w, {wedge = true, size = V(0.14, 0.5, 0.28), at = CFrame.new(p1 + V(0, 0.35, 0)), color = CLAW, shadow = false})
		local tips = {p1 + V(s * 0.4, -2.9, 0.15), p1 + V(s * 1.5, -2.5, 0.15), p2 + V(s * 0.2, -1.7, 0.1)}
		for _, t in tips do
			bar(c, w, p1, t, 0.14, SKIN_D)
		end
		-- membrana: paneles entre los dedos (el borde de abajo con picos)
		local panels = {{p0, p1, tips[1]}, {p1, tips[1], tips[2]}, {p1, tips[2], tips[3]}, {p1, tips[3], p2}}
		for k, tri in panels do
			local a, b2, cc = tri[1], tri[2], tri[3]
			local mid = (a + b2 + cc) / 3
			local wdt = math.max((b2 - cc).Magnitude, (a - b2).Magnitude * 0.6)
			local hgt = ((a + b2) / 2 - cc).Magnitude
			piece(c, w, {size = V(wdt * 0.85, hgt * 0.9, 0.08), at = CFrame.lookAt(mid, mid + V(0, 0, 1)) * R(0, 0, s * (k * 6 - 8)), color = WING, t = 0.08, name = "Membrane", shadow = false})
		end
	end
	-- cola con punta de pica
	joint(c, "Tail", V(0, h.hip + 0.3, 0.75), "Torso", V(-30, 15, 0))
	local tp = V(0, h.hip + 0.3, 0.75)
	local prev = tp
	for k = 1, 4 do
		local nx = tp + V(math.sin(k * 0.6) * 0.3, -k * 0.35, k * 0.75)
		bar(c, "Tail", prev, nx, 0.32 - k * 0.04, SKIN)
		prev = nx
	end
	for s = -1, 1, 2 do
		piece(c, "Tail", {wedge = true, size = V(0.1, 0.5, 0.45), at = CFrame.new(prev + V(s * 0.2, 0, 0.2)) * R(90, 0, s * 60), color = SKIN_D})
	end
	-- fuego en las manos y en los ojos
	for s = -1, 1, 2 do
		local an = s < 0 and "ArmL" or "ArmR"
		local hand = anchor(m, an .. "Fire", V(s * h.ax, top - h.A.Y - 0.1, 0), c, an)
		local f = flame(hand, LAVA, 0.6, "HandFire")
		f.Rate = 10
	end
	local eyes = anchor(m, "Eyes", hc + V(0, 0.1, -0.9), c, "Head")
	light(eyes, C(255, 200, 60), 8, 1.4)
	burst(anchor(m, "Breath", hc + V(0, -0.9, -1.1), c, "Head"), C(255, 120, 40), "Roar", 1.1, 9).Texture = SMOKE
	mist(anchor(m, "Smoke", V(0, 0.3, cz)), C(90, 40, 40), 4, "Smoke")
	return finish(m, "Demonio", {c}, 1.08)
end

---------- REY CALABAZA ----------
-- La versión jefe del alcalde Calabaza: de pie ante su trono, con levita morada y dorada, capa real, cetro con una
-- calabacita y una corona de fuego sobre su calabaza (que sonríe malvada). A sus pies, tres calabazas encendidas que te
-- lanza una tras otra.
function BUILD.ReyCalabaza()
	local m = model("ReyCalabaza")
	local COAT, COAT_D, TROUSERS, SHOES, GOLD, WHITE = C(104, 50, 158), C(72, 32, 112), C(46, 28, 64), C(30, 22, 30), C(240, 190, 70), C(244, 240, 230)
	local CAPE, CAPE_L, VELVET, GREEN = C(70, 22, 104), C(140, 66, 196), C(120, 30, 60), C(70, 176, 60)
	-- trono
	local tz = 1.35
	prop(m, {size = V(3.1, 0.6, 1.3), at = V(0, 1.4, tz), color = VELVET, mat = M.Fabric})
	prop(m, {size = V(3.3, 4.6, 0.4), at = V(0, 3.4, tz + 0.5), color = COAT_D, mat = M.Fabric, name = "Throne"})
	for s = -1, 1, 2 do
		prop(m, {size = V(0.3, 5.0, 0.5), at = V(s * 1.6, 3.4, tz + 0.5), color = GOLD, mat = M.Metal})
		prop(m, {size = V(0.4, 1.1, 1.3), at = V(s * 1.55, 1.95, tz), color = GOLD, mat = M.Metal})
		prop(m, {size = V(0.3, 1.1, 0.3), at = V(s * 1.4, 0.55, tz - 0.5), color = GOLD, mat = M.Metal})
		local fin = pumpkin(m, nil, CFrame.new(s * 1.6, 6.25, tz + 0.5), 0.55, true)
		fin.Name = "Finial"
	end
	prop(m, {size = V(3.3, 0.3, 0.5), at = V(0, 5.75, tz + 0.5), color = GOLD, mat = M.Metal})
	prop(m, {wedge = true, size = V(0.3, 0.8, 1.2), at = CFrame.new(0, 6.3, tz + 0.5) * R(0, 90, 0), color = GOLD, mat = M.Metal})
	-- tres calabazas encendidas a sus pies (las lanza)
	for k, at in {CFrame.new(-1.75, 0.45, -1.3) * R(0, 25, 0), CFrame.new(1.8, 0.45, -1.15) * R(0, -20, 0), CFrame.new(-1.85, 0.42, 0.35) * R(0, 60, 0)} do
		local body = pumpkin(m, nil, at, 0.72, true, "Lantern" .. k)
		light(body, C(255, 150, 40), 6, 1.2, true, "LanternLight")
	end

	-- el rey
	local c = newRig()
	local h = humanoid(c, {hip = 2.7, torso = V(2.4, 2.6, 1.3), head = V(1.6, 1.6, 1.6), arm = V(1.0, 2.6, 1.0), leg = V(1.05, 2.7, 1.1),
		shirt = COAT, pants = TROUSERS, hands = WHITE, handH = 0.6, mat = M.Fabric, noHead = true,
		idle = {Torso = V(4, 0, 0), Head = V(4, 0, 0), ArmL = V(12, 0, -26), ArmR = V(18, 0, 20), LegL = V(2, 0, -4), LegR = V(-2, 0, 4)}})
	local top = h.top
	local tc = V(0, h.hip + 1.3, 0)
	-- pechera blanca, botones dorados, banda y charreteras con flecos
	piece(c, "Torso", {size = V(0.85, 1.9, 0.06), at = V(0, tc.Y + 0.25, -0.66), color = WHITE, mat = M.Fabric})
	for k = 0, 3 do
		piece(c, "Torso", {shape = "Ball", size = V(0.16, 0.16, 0.16), at = V(0, top - 0.5 - k * 0.42, -0.7), color = GOLD, mat = M.Metal, shadow = false})
	end
	piece(c, "Torso", {size = V(0.45, 3.3, 0.08), at = CFrame.new(0, tc.Y, -0.7) * R(0, 0, 38), color = C(200, 40, 60), mat = M.Fabric})
	piece(c, "Torso", {size = V(2.46, 0.3, 1.36), at = V(0, h.hip + 0.25, 0), color = C(30, 22, 30)})
	piece(c, "Torso", {size = V(0.45, 0.4, 0.08), at = V(0, h.hip + 0.25, -0.7), color = GOLD, mat = M.Metal})
	for s = -1, 1, 2 do
		piece(c, "Torso", {size = V(1.0, 0.3, 1.2), at = V(s * 1.25, top + 0.05, 0), color = GOLD, mat = M.Metal})
		for k = -1, 1 do
			piece(c, "Torso", {size = V(0.1, 0.4, 0.1), at = V(s * 1.7, top - 0.25, k * 0.4), color = GOLD, shadow = false})
		end
		piece(c, "Torso", {wedge = true, size = V(0.08, 1.2, 0.5), at = CFrame.new(s * 0.45, top - 0.6, -0.68) * R(0, s * 90, 0), color = COAT_D, mat = M.Fabric, shadow = false})
		local an, ln = s < 0 and "ArmL" or "ArmR", s < 0 and "LegL" or "LegR"
		piece(c, an, {size = V(1.06, 0.35, 1.06), at = V(s * h.ax, top - h.A.Y + 0.75, 0), color = GOLD, mat = M.Metal})
		piece(c, ln, {size = V(1.12, 0.9, 1.4), at = V(s * 0.525, 0.45, -0.12), color = SHOES})
		piece(c, ln, {size = V(0.45, 0.3, 0.08), at = V(s * 0.525, 0.6, -0.84), color = GOLD, mat = M.Metal, shadow = false})
	end
	-- cuello alto con hojas (como el alcalde) y capa real
	for k = -2, 2 do
		piece(c, "Torso", {wedge = true, size = V(0.45, 0.7, 0.3), at = CFrame.new(k * 0.42, top + 0.3, 0.45 - math.abs(k) * 0.12) * R(-15, k * 18, 0), color = k % 2 == 0 and GREEN or C(58, 140, 52)})
	end
	joint(c, "Cape", V(0, top - 0.1, 0.7), "Torso", V(-6, 0, 0))
	piece(c, "Cape", {size = V(3.0, 5.0, 0.16), at = V(0, top - 2.55, 0.8), color = CAPE, mat = M.Fabric, name = "Cape"})
	piece(c, "Cape", {size = V(2.8, 4.8, 0.06), at = V(0, top - 2.5, 0.7), color = CAPE_L, mat = M.Fabric})
	for s = -1, 1, 2 do
		piece(c, "Cape", {size = V(0.2, 5.0, 0.2), at = V(s * 1.5, top - 2.55, 0.8), color = GOLD, shadow = false})
	end
	piece(c, "Cape", {size = V(3.0, 0.22, 0.2), at = V(0, top - 5.0, 0.8), color = GOLD, shadow = false})
	-- cabeza: gran calabaza con cara malvada encendida y la corona de fuego
	pumpkin(c, "Head", CFrame.new(0, top + 1.05, 0), 1.85, true)
	local cy = top + 1.05 + 0.95
	for _, side in {{V(0, 0, -0.62), V(1.5, 0.45, 0.16)}, {V(0, 0, 0.62), V(1.5, 0.45, 0.16)}, {V(-0.67, 0, 0), V(0.16, 0.45, 1.4)}, {V(0.67, 0, 0), V(0.16, 0.45, 1.4)}} do
		piece(c, "Head", {size = side[2], at = V(0, cy, 0) + side[1], color = GOLD, mat = M.Metal})
	end
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		piece(c, "Head", {wedge = true, size = V(0.12, 0.55, 0.36), at = CFrame.new(math.cos(a) * 0.68, cy + 0.45, math.sin(a) * 0.62) * R(0, -math.deg(a) + 90, 0), color = GOLD, mat = M.Metal, shadow = false})
	end
	for k, col in {C(255, 40, 80), C(80, 230, 120), C(80, 160, 255)} do
		piece(c, "Head", {size = V(0.22, 0.22, 0.08), at = V((k - 2) * 0.48, cy, -0.72), color = col, neon = true, shadow = false})
	end
	local crown = anchor(m, "Crown", V(0, cy + 0.45, 0), c, "Head")
	local cf = flame(crown, C(255, 120, 30), 1.1, "CrownFire")
	cf.Rate = 18
	cf.SpreadAngle = Vector2.new(30, 30)
	light(crown, C(255, 130, 40), 10, 1.4, true, "CrownLight")
	burst(crown, C(255, 170, 60), "Flare", 0.9, 10)
	local faceL = anchor(m, "FaceGlow", V(0, top + 1.05, -0.6), c, "Head")
	light(faceL, C(255, 170, 60), 9, 1.4, true, "FaceLight")
	-- cetro con una calabacita encendida
	local handR = (idleWorld(c, "ArmR") * CFrame.new(h.ax, top - h.A.Y + 0.3, 0)).Position
	piece(c, "ArmR", {size = V(0.2, 4.4, 0.2), at = CFrame.new(handR + V(0, 0.9, -0.1)), color = GOLD, mat = M.Metal, posed = true, name = "Scepter"})
	piece(c, "ArmR", {shape = "Ball", size = V(0.4, 0.4, 0.4), at = CFrame.new(handR + V(0, 3.1, -0.1)), color = GOLD, mat = M.Metal, posed = true})
	pumpkin(c, "ArmR", CFrame.new(handR + V(0, 3.55, -0.1)), 0.55, true, nil, true)
	local orb = piece(c, "ArmR", {size = V(0.2, 0.2, 0.2), at = CFrame.new(handR + V(0, 3.55, -0.1)), posed = true, name = "Orb", shadow = false})
	orb.Transparency = 1
	orb.CanQuery = false
	light(orb, C(255, 150, 40), 8, 1.2, true, "OrbLight")
	sparkles(orb, C(255, 190, 80), 4, "OrbSparkles")
	mist(anchor(m, "Fog", V(0, 0.3, 0)), C(150, 80, 200), 3, "Fog")
	return finish(m, "ReyCalabaza", {c}, 1.05)
end

function P.build(t)
	return B.build(t)
end

function P.all()
	local done = {}
	for _, t in NAMES do
		local ok, err = pcall(B.build, t)
		table.insert(done, t .. (ok and " ok" or (" ERROR " .. tostring(err))))
	end
	return done
end

return P
