-- Mapa del Tower Defense "Voidcore Rift" (roster void, el más difícil: lo mejor de cada gremio de cazadores).
-- Una isla de roca negra flotando sobre el vacío: el camino, con bordes de neón, sale de un portal (noroeste) y da
-- vueltas en espiral hasta el Corazón del Vacío, en el centro: la casa a defender. Grietas que brillan, cristales,
-- runas en el suelo e islotes flotando en el cielo.
-- Uso: require(game.ServerStorage.MapaVoidcoreRift).build() y luego MapasNuevosLib.store("VoidcoreRift")
local L = require(game.ServerStorage.MapasNuevosLib)
local V, CF, ANG = L.V, L.CF, L.ANG
local rad = math.rad
local M = Enum.Material
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local VOID = rgb(170, 70, 255)
local PINK = rgb(255, 80, 220)
local DARK = rgb(40, 32, 56)
local ROCK = rgb(58, 50, 74)

local M_ = {}

function M_.build()
	local B = L.new("VoidcoreRift", CFrame.new(4100, 2, 0), {seed = 97, width = 8})
	local rng = B.rng

	---------- Terreno: la isla flotante ----------
	B:fillBlock(0, 40, 0, 1000, 300, 900, M.Air)
	task.wait()
	B:fillCyl(0, -14, 0, 24, 250, M.Basalt)
	task.wait()
	-- la panza de la isla: rocas colgando hacia el vacío
	for k = 0, 23 do
		local a = k / 24 * math.pi * 2
		local r = rng:NextNumber(150, 240)
		B:fillBall(math.cos(a) * r, -36 - rng:NextNumber(0, 20), math.sin(a) * r, rng:NextNumber(26, 40), M.Basalt)
	end
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		B:fillBall(math.cos(a) * 80, -60, math.sin(a) * 80, 46, M.Basalt)
	end
	B:fillBall(0, -90, 0, 60, M.Basalt)
	task.wait()
	-- manchas de pizarra y roca
	for _ = 1, 30 do
		B:paint(rng:NextNumber(-180, 180), rng:NextNumber(-130, 130), rng:NextNumber(8, 18), M.Basalt, rng:NextNumber() < 0.5 and M.Slate or M.Rock)
	end
	-- crestas de roca en el borde de la isla (fuera de los límites)
	for k = 0, 27 do
		local a = k / 28 * math.pi * 2
		local r = rng:NextNumber(222, 246)
		B:hill(math.cos(a) * r, math.sin(a) * r, rng:NextNumber(14, 24), rng:NextNumber(10, 30), M.Basalt, M.Slate)
	end
	task.wait()

	-- el vacío: un resplandor morado muy abajo
	B:deco({Name = "Vacio", Size = V(2048, 1, 2048), CFrame = B:cf(0, -160, 0), Material = M.Neon, Color = rgb(34, 8, 66), Transparency = 0.2, CastShadow = false}, B.F.TDS)
	B:deco({Name = "Bruma", Size = V(2048, 1, 2048), CFrame = B:cf(0, -110, 0), Material = M.Neon, Color = rgb(110, 30, 180), Transparency = 0.93, CastShadow = false}, B.F.TDS)

	---------- Camino en espiral ----------
	local ctrl = {
		{-178, -96}, {-100, -100}, {0, -102}, {100, -98}, {146, -70}, {152, -10}, {140, 50}, {100, 74}, {20, 76}, {-60, 74},
		{-120, 62}, {-146, 20}, {-140, -40}, {-104, -66}, {-40, -70}, {40, -68}, {96, -50}, {110, -6}, {90, 36}, {30, 46},
		{-40, 44}, {-96, 24}, {-104, -16}, {-74, -40}, {-20, -38}, {40, -30}, {60, 0}, {36, 18}, {-6, 16}, {-28, 2}, {-14, -10},
	}
	B:path(ctrl, {flat = true, mat = M.Slate, color = rgb(64, 54, 86), edgeMat = M.Neon, edgeColor = rgb(120, 50, 210), edge = 1.4, under = M.Slate})
	B:arrows(8, PINK)
	B:flush()

	---------- Llegada ----------
	B:arrival(40, 106, 0, "Voidcore Rift")
	B:bounds(-172, -122, 172, 122)

	---------- El Corazón del Vacío (la casa a defender) ----------
	local hx, hz = 6, -14
	local heart = B:kit("VoidHeart", hx, hz, 140, 1.02, B.F.Arq, 0)
	-- la gema del corazón, flotando sobre el altar (un cubo de neón de canto, dentro de otro de cristal)
	local gem = B:cf(hx, 21, hz) * ANG(rad(45), rad(20), rad(35))
	B:deco({Name = "Gema", Size = V(7, 7, 7), CFrame = gem, Material = M.Neon, Color = VOID, CastShadow = false})
	B:deco({Name = "Gema", Size = V(9, 9, 9), CFrame = gem, Material = M.Glass, Color = PINK, Transparency = 0.55, CastShadow = false})
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		B:deco({Name = "Esquirla", Size = V(1.6, 3.4, 1.6), CFrame = B:cf(hx + math.cos(a) * 9, 18 + k * 2, hz + math.sin(a) * 9) * ANG(rad(30), a, rad(20)), Material = M.Neon, Color = PINK, CastShadow = false})
	end
	local core = B:deco({Name = "Nucleo", Size = V(4, 4, 4), CFrame = B:cf(hx, 21, hz), Transparency = 1})
	B:light(core, VOID, 60, 3.2)
	B:emitter(core, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(VOID, PINK), Rate = 22, Lifetime = NumberRange.new(1.5, 3),
		Speed = NumberRange.new(2, 6), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.8, 0), LightEmission = 1,
	})
	-- anillo de runas alrededor
	B:deco({Name = "Runas", Shape = Enum.PartType.Cylinder, Size = V(0.2, 32, 32), CFrame = B:cf(hx, 0.25, hz, 0, 0, 90), Material = M.Neon, Color = VOID, Transparency = 0.55, CastShadow = false})
	B:deco({Name = "Runas", Shape = Enum.PartType.Cylinder, Size = V(0.22, 28, 28), CFrame = B:cf(hx, 0.26, hz, 0, 0, 90), Material = M.Slate, Color = DARK, CastShadow = false})
	table.insert(B.avoid, {hx, hz, 20})
	B:flush()

	---------- El portal de los cazadores (de donde salen) ----------
	local function portal(x, z, yaw, r)
		local base = B:cf(x, r + 1, z, yaw)
		for k = 0, 23 do
			local a = k / 24 * math.pi * 2
			B:deco({Name = "Aro", Size = V(2.2, 2.2, r * 2 * math.pi / 24 + 0.3), CFrame = base * CF(math.cos(a) * r, math.sin(a) * r, 0) * ANG(0, rad(90), 0) * ANG(-a, 0, 0), Material = M.Slate, Color = DARK})
			if k % 2 == 0 then
				B:deco({Name = "Runa", Size = V(0.6, 0.6, 0.6), CFrame = base * CF(math.cos(a) * r, math.sin(a) * r, 1.2), Material = M.Neon, Color = PINK})
			end
		end
		local disc = B:deco({Name = "Remolino", Shape = Enum.PartType.Cylinder, Size = V(0.3, r * 2 - 1, r * 2 - 1), CFrame = base * ANG(0, rad(90), 0), Material = M.Neon, Color = VOID, Transparency = 0.45, CastShadow = false})
		B:light(disc, VOID, 40, 3)
		B:emitter(disc, {
			Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(PINK, VOID), Rate = 30, Lifetime = NumberRange.new(1, 2),
			Speed = NumberRange.new(4, 8), SpreadAngle = Vector2.new(30, 30), Size = NumberSequence.new(0.6, 0), LightEmission = 1,
		})
		B:deco({Name = "Base", Size = V(r * 2 + 6, 1.4, 6), CFrame = B:cf(x, -0.4, z, yaw), Material = M.Slate, Color = DARK})
	end
	portal(-176, -96, 90, 9)
	table.insert(B.avoid, {-176, -96, 14})
	B:flush()

	---------- Grietas que brillan (sin suelo: ahí no se puede colocar) ----------
	local function rift(x, z, len, yaw)
		local n = math.floor(len / 6)
		for k = 0, n do
			local t = k / n - 0.5
			local off = math.sin(k * 1.3) * 2.5
			local cx = x + math.cos(rad(yaw)) * t * len + math.sin(rad(yaw)) * off
			local cz = z - math.sin(rad(yaw)) * t * len + math.cos(rad(yaw)) * off
			local w = 4 + 3 * math.cos(t * math.pi)
			B:fillBall(cx, -4, cz, w, M.Air)
		end
		local glow = B:deco({Name = "Grieta", Size = V(len, 0.4, 9), CFrame = B:cf(x, -9, z, yaw), Material = M.Neon, Color = PINK, Transparency = 0.1, CanQuery = true, CastShadow = false}, B.F.TDS)
		B:light(glow, PINK, 24, 2)
		B:emitter(glow, {
			Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(PINK, VOID), Rate = 8, Lifetime = NumberRange.new(2, 3),
			Speed = NumberRange.new(3, 6), SpreadAngle = Vector2.new(10, 10), EmissionDirection = Enum.NormalId.Top, Size = NumberSequence.new(0.5, 0), LightEmission = 1,
		})
		table.insert(B.avoid, {x, z, len / 2 + 4})
	end
	local function riftFree(x, z, len)
		return B:distToPath(x, z) > len / 2 + B.width / 2 + 6
	end
	for _, r in {{-160, 102, 30, 20}, {160, -112, 28, -30}, {124, 104, 26, 10}, {-164, -60, 26, 80}} do
		if riftFree(r[1], r[2], r[3]) then
			rift(r[1], r[2], r[3], r[4])
		end
	end
	task.wait()

	---------- Cristales, pilares y runas ----------
	local lights = 0
	local function crystal(x, z, s)
		local m = B:kit("VoidCrystals", x, z, rng:NextNumber(0, 360), s, nil, nil, {sink = 0.4})
		if not m then
			-- (sin el modelo: unos prismas de neón)
			for k = 1, rng:NextInteger(3, 5) do
				local h = rng:NextNumber(4, 10) * s
				local tilt = ANG(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6.28), rng:NextNumber(-0.4, 0.4))
				local p = B:part({Name = "Cristal", Size = V(1.4 * s, h, 1.4 * s), CFrame = B:cf(x + rng:NextNumber(-2, 2), 0, z + rng:NextNumber(-2, 2)) * tilt * CF(0, h / 2, 0), Material = M.Neon, Color = k % 2 == 0 and PINK or VOID, Transparency = 0.15})
				m = m or p
			end
		end
		if lights < 18 then
			lights += 1
			local l = B:deco({Name = "Brillo", Size = V(1, 1, 1), CFrame = B:cf(x, 4 * s, z), Transparency = 1})
			B:light(l, rng:NextNumber() < 0.5 and VOID or PINK, 16, 1.6)
		end
		table.insert(B.avoid, {x, z, 4 * s})
	end
	local placed = 0
	for _ = 1, 600 do
		if placed >= 34 then
			break
		end
		local x, z = rng:NextNumber(-166, 166), rng:NextNumber(-116, 116)
		local s = rng:NextNumber(0.9, 1.6)
		if not (x > 0 and x < 90 and z > 70) and B:free(x, z, 3 + 6 * s) then
			crystal(x, z, s)
			placed += 1
		end
	end
	-- cristales grandes en el borde, fuera de los límites
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2
		local x, z = math.cos(a) * 205, math.sin(a) * 160
		local s = rng:NextNumber(2.4, 3.6)
		if B:free(x, z, 6 * s) then
			crystal(x, z, s)
		end
	end
	B:flush()
	-- pilares rotos con una franja de neón
	for _ = 1, 14 do
		local x, z = rng:NextNumber(-166, 166), rng:NextNumber(-116, 116)
		if B:free(x, z, 5) then
			local h = rng:NextNumber(8, 18)
			local base = B:cf(x, 0, z, rng:NextNumber(0, 90)) * ANG(rng:NextNumber(-0.12, 0.12), 0, rng:NextNumber(-0.12, 0.12))
			B:part({Name = "Pilar", Size = V(3, h, 3), CFrame = base * CF(0, h / 2, 0), Material = M.Slate, Color = DARK})
			B:deco({Name = "Franja", Size = V(3.1, 0.5, 3.1), CFrame = base * CF(0, h * 0.7, 0), Material = M.Neon, Color = VOID})
			B:part({Name = "Capitel", Size = V(4, 1, 4), CFrame = base * CF(0, h + 0.5, 0), Material = M.Slate, Color = ROCK})
			table.insert(B.avoid, {x, z, 5})
		end
	end
	-- círculos de runas en el suelo (decoración plana: no estorban)
	for _ = 1, 10 do
		local x, z = rng:NextNumber(-160, 160), rng:NextNumber(-110, 110)
		if B:free(x, z, 7) then
			local r = rng:NextNumber(6, 10)
			B:deco({Name = "Circulo", Shape = Enum.PartType.Cylinder, Size = V(0.12, r * 2, r * 2), CFrame = B:cf(x, 0.12, z, 0, 0, 90), Material = M.Neon, Color = PINK, Transparency = 0.6, CastShadow = false})
			B:deco({Name = "Circulo", Shape = Enum.PartType.Cylinder, Size = V(0.14, r * 2 - 1.2, r * 2 - 1.2), CFrame = B:cf(x, 0.13, z, 0, 0, 90), Material = M.Slate, Color = DARK, CastShadow = false})
			for k = 0, 5 do
				local a = k / 6 * math.pi * 2
				B:deco({Name = "Runa", Size = V(1.2, 0.15, 1.2), CFrame = B:cf(x + math.cos(a) * (r - 2), 0.16, z + math.sin(a) * (r - 2), math.deg(a) + 45), Material = M.Neon, Color = VOID, Transparency = 0.3, CastShadow = false})
			end
		end
	end
	-- islotes y rocas flotando en el cielo (mallas de roca, sin colisión)
	local function floating(x, z, y, s)
		local m = B:kit(rng:NextNumber() < 0.6 and "RockB" or "RockA", x, z, rng:NextNumber(0, 360), s, nil, y, {noCollide = true, color = ROCK})
		if m then
			m:PivotTo(m:GetPivot() * ANG(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3)))
		end
	end
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local r = rng:NextNumber(280, 400)
		floating(math.cos(a) * r, math.sin(a) * r, rng:NextNumber(10, 80), rng:NextNumber(3, 6))
	end
	for _ = 1, 22 do
		floating(rng:NextNumber(-200, 200), rng:NextNumber(-150, 150), rng:NextNumber(30, 70), rng:NextNumber(0.4, 1))
	end
	local SMALL = {"RockA", "RockB", "RockC", "BonePile", "Mound"}
	placed = 0
	for _ = 1, 400 do
		if placed >= 40 then
			break
		end
		local x, z = rng:NextNumber(-168, 168), rng:NextNumber(-118, 118)
		if B:free(x, z, 3) then
			B:kit(SMALL[rng:NextInteger(1, #SMALL)], x, z, rng:NextNumber(0, 360), rng:NextNumber(0.8, 1.6), nil, nil, {noCollide = true, color = ROCK})
			placed += 1
		end
	end
	B:flush()

	---------- Ambiente ----------
	B:ambience(340, 244, rgb(140, 80, 200), PINK, 8, 14)
	return B:finish()
end

return M_
