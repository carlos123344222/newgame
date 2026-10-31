-- Mapa del Tower Defense "Cursed Castle" (roster castle: aldeanos, caballeros, paladines, el Caballero Negro y el rey).
-- Oeste: la aldea asediadora (casas de entramado, campamento con tiendas, empalizada y la puerta del pueblo, donde
-- salen los enemigos). Centro: el río con su puente de piedra y el viejo cementerio con su cripta y la capilla.
-- Este: el castillo encantado (la casa a defender): murallas almenadas, torres, el cuerpo de guardia con el rastrillo
-- y la torre del homenaje con ventanas que brillan. Uso: require(game.ServerStorage.MapaCursedCastle).build()
local L = require(game.ServerStorage.MapasNuevosLib)
local V, CF, ANG = L.V, L.CF, L.ANG
local rad = math.rad
local M = Enum.Material
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local STONE = rgb(108, 102, 132)
local STONE_D = rgb(78, 72, 98)
local ROOF = rgb(46, 40, 82)
local WOOD = rgb(86, 58, 38)
local PURPLE = rgb(190, 110, 255)
local WARM = rgb(255, 170, 70)

local M_ = {}

function M_.build()
	local B = L.new("CursedCastle", CFrame.new(2300, 2, 0), {seed = 11, width = 8})
	local rng = B.rng

	---------- Terreno ----------
	-- (borra el terreno de una versión anterior)
	B:fillBlock(0, 70, 0, 1000, 220, 900, M.Air)
	task.wait()
	B:ground(980, 860, M.Grass, 24)
	-- el río (de norte a sur por x = -40): cauce y lecho (el agua es una pieza, como el estanque de Pumpkin Hollow)
	B:fillBlock(-40, -3, 0, 24, 12, 560, M.Air)
	B:fillBlock(-40, -8, 0, 24, 2, 560, M.Mud)
	for z = -270, 270, 12 do
		for s = -1, 1, 2 do
			B:fillBall(-40 + s * 13, -2.5, z, 3.6, M.Mud)
		end
	end
	local water = B:part({Name = "Agua", Size = V(24, 0.4, 560), CFrame = B:cf(-40, -1.6, 0), Material = M.SmoothPlastic, Color = rgb(52, 50, 118), Transparency = 0.12, Reflectance = 0.3, CanCollide = false, CastShadow = false}, B.F.TDS)
	B:light(water, rgb(110, 100, 220), 30, 0.6)
	task.wait()
	-- colinas alrededor de la zona de juego, con rocas
	for i = 0, 15 do
		local x = -200 + i * 27
		B:hill(x + rng:NextNumber(-8, 8), -150 + rng:NextNumber(-10, 6), rng:NextNumber(26, 36), rng:NextNumber(18, 34), M.Rock, M.Grass)
		B:hill(x + rng:NextNumber(-8, 8), 155 + rng:NextNumber(-6, 10), rng:NextNumber(26, 36), rng:NextNumber(16, 30), M.Rock, M.Grass)
	end
	for i = 0, 9 do
		local z = -130 + i * 29
		B:hill(-205 + rng:NextNumber(-8, 8), z, rng:NextNumber(28, 38), rng:NextNumber(20, 36), M.Rock, M.Grass)
	end
	task.wait()
	-- montañas altas más allá (tapan el horizonte y el final del río)
	for i = 0, 13 do
		local x = -330 + i * 52
		B:hill(x + rng:NextNumber(-12, 12), -240 + rng:NextNumber(-20, 10), rng:NextNumber(55, 75), rng:NextNumber(60, 95), M.Rock, M.Slate)
		B:hill(x + rng:NextNumber(-12, 12), 245 + rng:NextNumber(-10, 20), rng:NextNumber(55, 75), rng:NextNumber(55, 90), M.Rock, M.Slate)
		task.wait()
	end
	for i = 0, 8 do
		local z = -220 + i * 55
		B:hill(-330 + rng:NextNumber(-12, 12), z, rng:NextNumber(60, 80), rng:NextNumber(60, 95), M.Rock, M.Slate)
		B:hill(320 + rng:NextNumber(-12, 12), z, rng:NextNumber(60, 80), rng:NextNumber(50, 80), M.Rock, M.Slate)
		task.wait()
	end
	-- manchas de hierba alta, barro en la aldea y tierra en el patio del castillo
	for _ = 1, 26 do
		B:paint(rng:NextNumber(-170, 170), rng:NextNumber(-115, 120), rng:NextNumber(8, 16), M.Grass, M.LeafyGrass)
	end
	for _, p in {{-150, -90}, {-130, -95}, {-145, 0}, {-140, 50}, {-125, 95}, {-90, -55}} do
		B:paint(p[1], p[2], 14, M.Grass, M.Mud)
	end
	B:paint(150, 46, 40, M.Grass, M.Ground)
	task.wait()

	---------- Puente de piedra (antes del camino: el camino se apoya en él) ----------
	local bz = 10
	local deck = B:part({Name = "Puente", Size = V(38, 1.2, 13), CFrame = B:cf(-40, -0.3, bz), Material = M.Cobblestone, Color = STONE}, B.F.Suelo)
	for s = -1, 1, 2 do
		-- pretiles con postes y faroles
		B:part({Name = "Pretil", Size = V(38, 2.4, 1.2), CFrame = B:cf(-40, 1.2, bz + s * 7), Material = M.Cobblestone, Color = STONE_D})
		B:part({Name = "Remate", Size = V(38.6, 0.5, 1.6), CFrame = B:cf(-40, 2.6, bz + s * 7), Material = M.Slate, Color = STONE})
		for k = -2, 2 do
			B:part({Name = "Poste", Size = V(1.8, 3.6, 1.8), CFrame = B:cf(-40 + k * 9, 1.8, bz + s * 7), Material = M.Cobblestone, Color = STONE})
		end
		for k = -1, 1, 2 do
			local pole = B:part({Name = "Farol", Size = V(0.5, 5, 0.5), CFrame = B:cf(-40 + k * 18, 6, bz + s * 7), Material = M.Metal, Color = rgb(40, 36, 46)})
			local lamp = B:deco({Name = "Luz", Size = V(1.1, 1.4, 1.1), CFrame = B:cf(-40 + k * 18, 9, bz + s * 7), Material = M.Neon, Color = WARM})
			B:light(lamp, WARM, 20, 1.6)
		end
	end
	-- arcos por debajo (bajan hasta el agua)
	for k = -1, 1 do
		B:part({Name = "Pila", Size = V(4, 8, 13), CFrame = B:cf(-40 + k * 11, -4.5, bz), Material = M.Cobblestone, Color = STONE_D})
	end
	for k = -1, 1, 2 do
		for j = 0, 3 do
			local a = rad(15 + j * 20)
			B:part({Name = "Arco", Size = V(2.2, 1.2, 13), CFrame = B:cf(-40 + k * 5.5 + k * -math.cos(a) * 3, -1.3 - math.sin(a) * 2, bz) * ANG(0, 0, k * a), Material = M.Cobblestone, Color = STONE_D})
		end
	end
	B:flush()

	---------- Camino ----------
	local ctrl = {
		{-168, -62}, {-128, -62}, {-114, -22}, {-95, 14}, {-101, 55}, {-76, 82}, {-56, 62}, {-60, 30}, {-62, 10},
		{-40, 10}, {-18, 10}, {0, -5}, {5, -45}, {30, -80}, {65, -86}, {86, -56}, {80, -15}, {56, 10}, {45, 36}, {40, 66},
		{66, 86}, {96, 80}, {106, 58}, {114, 47},
	}
	B:path(ctrl, {mat = M.Cobblestone, color = rgb(132, 120, 110), edgeMat = M.Slate, edgeColor = rgb(70, 64, 86), edge = 2})
	B:arrows(7, rgb(255, 176, 70))
	B:flush()

	---------- Llegada de los jugadores ----------
	B:arrival(-6, 100, 0, "Cursed Castle")
	B:bounds(-172, -118, 172, 122)

	---------- Castillo (este) ----------
	local castle = Instance.new("Folder")
	castle.Name = "Castillo"
	B:add(castle, B.F.Arq)
	B:flush()
	-- patio empedrado
	B:part({Name = "Patio", Size = V(70, 1, 150), CFrame = B:cf(155, -0.45, 40), Material = M.Cobblestone, Color = rgb(96, 90, 110)}, B.F.Suelo)
	-- cuerpo de guardia con el arco de entrada (mira al oeste)
	local gx, gz = 123, 46
	for s = -1, 1, 2 do
		B:part({Name = "Guardia", Size = V(14, 24, 7), CFrame = B:cf(gx, 12, gz + s * 8.5), Material = M.Cobblestone, Color = STONE}, castle)
	end
	B:part({Name = "Dintel", Size = V(14, 9, 10), CFrame = B:cf(gx, 19.5, gz), Material = M.Cobblestone, Color = STONE}, castle)
	-- arco apuntado sobre la entrada
	for j = 0, 4 do
		local a = rad(j * 18)
		for s = -1, 1, 2 do
			B:part({Name = "Arco", Size = V(14.4, 1.1, 1.6), CFrame = B:cf(gx - 0.2, 12 + math.sin(a) * 3, gz + s * (5 - math.cos(a) * 1.4 - j * 0.4)) * ANG(s * a, 0, 0), Material = M.Slate, Color = STONE_D}, castle)
		end
	end
	B:part({Name = "Cornisa", Size = V(15, 1, 25), CFrame = B:cf(gx, 24.5, gz), Material = M.Slate, Color = STONE_D}, castle)
	for k = -5, 5 do
		if k % 2 == 0 then
			B:part({Name = "Almena", Size = V(1.2, 2.2, 2), CFrame = B:cf(gx - 7, 26, gz + k * 2.2), Material = M.Cobblestone, Color = STONE}, castle)
		end
	end
	-- rastrillo levantado (rejilla) y oscuridad del pasadizo
	B:deco({Name = "Pasadizo", Size = V(12, 13, 9.6), CFrame = B:cf(gx + 1, 6.5, gz), Material = M.SmoothPlastic, Color = rgb(14, 10, 20)}, castle)
	local glow = B:deco({Name = "Resplandor", Size = V(0.4, 11, 8), CFrame = B:cf(gx + 6.6, 5.5, gz), Material = M.Neon, Color = PURPLE, Transparency = 0.35}, castle)
	B:light(glow, PURPLE, 24, 2.5)
	for k = -3, 3 do
		B:deco({Name = "Reja", Size = V(0.35, 6, 0.35), CFrame = B:cf(gx - 6.2, 13.5, gz + k * 1.4), Material = M.Metal, Color = rgb(40, 38, 46)}, castle)
		B:deco({Name = "Punta", Size = V(0.35, 0.8, 0.35), CFrame = B:cf(gx - 6.2, 10.2, gz + k * 1.4) * ANG(0, 0, rad(45)), Material = M.Metal, Color = rgb(40, 38, 46)}, castle)
	end
	for k = 0, 2 do
		B:deco({Name = "Reja", Size = V(0.35, 0.35, 9.6), CFrame = B:cf(gx - 6.2, 11.5 + k * 2.2, gz), Material = M.Metal, Color = rgb(40, 38, 46)}, castle)
	end
	-- estandartes a los lados del arco y antorchas
	for s = -1, 1, 2 do
		B:banner(B:cf(gx - 7.2, 22, gz + s * 8.5, -90), 4, 9, rgb(120, 30, 160), rgb(255, 210, 80))
		B:torch(B:cf(gx - 7.3, 9, gz + s * 6.4, -90))
	end
	-- torres que flanquean la puerta y las de las esquinas
	B:tower(118, 31, 7, 30, {flag = rgb(140, 40, 200), windowYaw = -90, parent = castle})
	B:tower(118, 61, 7, 30, {flag = rgb(140, 40, 200), windowYaw = -90, parent = castle})
	B:tower(119, 112, 8.5, 34, {flag = rgb(140, 40, 200), windowYaw = -90, window = PURPLE, parent = castle})
	B:tower(119, -24, 8.5, 32, {flag = rgb(140, 40, 200), windowYaw = -90, window = PURPLE, parent = castle})
	B:flush()
	-- murallas
	B:wall({118, 68}, {118, 104}, 20, 6, M.Cobblestone, STONE, {torches = 12, side = -1, parent = castle})
	B:wall({118, 24}, {118, -16}, 20, 6, M.Cobblestone, STONE, {torches = 12, side = 1, parent = castle})
	B:wall({126, 112}, {178, 112}, 20, 6, M.Cobblestone, STONE, {parent = castle})
	B:wall({126, -24}, {178, -24}, 20, 6, M.Cobblestone, STONE, {parent = castle})
	B:flush()
	-- la torre del homenaje: la casa encantada
	local kx, kz, kw, kh = 152, 46, 30, 52
	B:part({Name = "Homenaje", Size = V(kw, kh, kw), CFrame = B:cf(kx, kh / 2, kz), Material = M.Cobblestone, Color = STONE}, castle)
	B:part({Name = "Base", Size = V(kw + 3, 4, kw + 3), CFrame = B:cf(kx, 2, kz), Material = M.Cobblestone, Color = STONE_D}, castle)
	for _, by in {kh * 0.33, kh * 0.66, kh - 0.5} do
		B:part({Name = "Imposta", Size = V(kw + 1.2, 1, kw + 1.2), CFrame = B:cf(kx, by, kz), Material = M.Slate, Color = STONE_D}, castle)
	end
	-- contrafuertes
	for _, c in {{-1, -1}, {1, -1}, {-1, 1}, {1, 1}} do
		B:part({Name = "Contrafuerte", Size = V(4, kh, 4), CFrame = B:cf(kx + c[1] * (kw / 2 + 0.5), kh / 2, kz + c[2] * (kw / 2 + 0.5)), Material = M.Cobblestone, Color = STONE_D}, castle)
		B:tower(kx + c[1] * (kw / 2 + 0.5), kz + c[2] * (kw / 2 + 0.5), 3.4, 11, {y = kh, windows = 2, roofH = 9, window = PURPLE, parent = castle})
	end
	-- almenas
	for side = 0, 3 do
		local yaw = side * 90
		for k = -6, 6 do
			if k % 2 == 0 then
				local o = CFrame.Angles(0, rad(yaw), 0) * CF(k * 2.1, 0, kw / 2)
				B:part({Name = "Almena", Size = V(2, 2.4, 1.2), CFrame = B:cf(kx, kh + 1.2, kz) * o, Material = M.Cobblestone, Color = STONE}, castle)
			end
		end
	end
	-- tejado piramidal escalonado con aguja
	for k = 0, 8 do
		local s = (kw - 4) * (1 - k / 9)
		B:part({Name = "Tejado", Size = V(s, 2.4, s), CFrame = B:cf(kx, kh + 1.2 + k * 2.3, kz) * ANG(0, rad(45), 0), Material = M.Slate, Color = ROOF}, castle)
	end
	B:part({Name = "Aguja", Size = V(0.8, 9, 0.8), CFrame = B:cf(kx, kh + 26, kz), Material = M.Metal, Color = rgb(60, 56, 70)}, castle)
	local orb = B:deco({Name = "Orbe", Shape = Enum.PartType.Ball, Size = V(2.6, 2.6, 2.6), CFrame = B:cf(kx, kh + 31, kz), Material = M.Neon, Color = PURPLE}, castle)
	B:light(orb, PURPLE, 60, 3)
	B:emitter(orb, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(PURPLE), Rate = 8, Lifetime = NumberRange.new(1.5, 3),
		Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.6, 0), LightEmission = 1,
	})
	-- ventanales góticos que brillan (fachada oeste y laterales) y un gran rosetón
	for face = 0, 2 do
		local yaw = ({-90, 0, 180})[face + 1]
		for k = -1, 1 do
			for _, wy in {kh * 0.2, kh * 0.48} do
				local win = B:deco({Name = "Ventanal", Size = V(2.6, 6, 0.4), CFrame = B:cf(kx, wy, kz) * ANG(0, rad(yaw), 0) * CF(k * 8, 0, -kw / 2 - 0.15), Material = M.Neon, Color = k == 0 and PURPLE or WARM}, castle)
				B:deco({Name = "Remate", Size = V(1.9, 1.9, 0.42), CFrame = win.CFrame * CF(0, 3, 0) * ANG(0, 0, rad(45)), Material = M.Neon, Color = win.Color}, castle)
				if k == 0 then
					B:light(win, win.Color, 18, 1.4)
				end
			end
		end
	end
	local rose = B:deco({Name = "Roseton", Shape = Enum.PartType.Cylinder, Size = V(0.5, 8, 8), CFrame = B:cf(kx - kw / 2 - 0.2, kh * 0.78, kz), Material = M.Neon, Color = PURPLE}, castle)
	B:light(rose, PURPLE, 30, 2)
	for k = 0, 7 do
		B:deco({Name = "Tracería", Size = V(0.6, 8.2, 0.5), CFrame = rose.CFrame * ANG(rad(k * 22.5), 0, 0), Material = M.Slate, Color = STONE_D}, castle)
	end
	for s = -1, 1, 2 do
		B:banner(B:cf(kx - kw / 2 - 0.3, kh * 0.62, kz + s * 9, -90), 4.5, 12, rgb(110, 26, 150), rgb(255, 200, 80))
	end
	-- fantasmas que rondan la torre (partículas)
	local ghosts = B:deco({Name = "Fantasmas", Size = V(kw + 10, 20, kw + 10), CFrame = B:cf(kx, kh * 0.7, kz), Transparency = 1}, castle)
	B:emitter(ghosts, {
		Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(rgb(180, 140, 255)), Rate = 3, Lifetime = NumberRange.new(4, 6),
		Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180), LightEmission = 0.8,
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.6), NumberSequenceKeypoint.new(1, 1)}),
	})
	-- otras dos torres dentro del recinto
	B:tower(152, 92, 9, 40, {flag = rgb(140, 40, 200), windowYaw = -90, window = PURPLE, parent = castle})
	B:tower(152, 2, 9, 36, {flag = rgb(140, 40, 200), windowYaw = -90, parent = castle})
	table.insert(B.avoid, {150, 46, 70})
	B:flush()

	---------- Aldea (oeste) ----------
	local village = {
		{-150, -96, 0, 12, 10, 8}, {-124, -100, 15, 10, 9, 7}, {-150, -16, 90, 11, 10, 8}, {-146, 22, 80, 12, 9, 7},
		{-142, 92, -150, 12, 10, 8}, {-114, 104, 180, 10, 9, 7}, {-84, -62, -90, 11, 9, 7}, {-96, -96, 20, 10, 9, 7},
	}
	local ROOFS = {rgb(110, 50, 44), rgb(70, 60, 90), rgb(96, 64, 40), rgb(60, 70, 84)}
	for i, h in village do
		if B:free(h[1], h[2], 9) then
			B:cottage(h[1], h[2], h[3], h[4], h[5], h[6], {roof = ROOFS[i % #ROOFS + 1]})
			table.insert(B.avoid, {h[1], h[2], 13})
		end
		B:flush()
	end
	-- puerta del pueblo (donde salen los enemigos): dos torres de troncos y un travesaño con estandarte
	local px, pz = -160, -62
	for s = -1, 1, 2 do
		for k = 0, 3 do
			local a = k / 4 * math.pi * 2
			B:part({Name = "Tronco", Shape = Enum.PartType.Cylinder, Size = V(16, 1.6, 1.6), CFrame = B:cf(px + math.cos(a) * 1.4, 8, pz + s * 8 + math.sin(a) * 1.4) * ANG(0, 0, rad(90)), Material = M.Wood, Color = WOOD})
		end
		B:part({Name = "Plataforma", Size = V(5, 0.6, 5), CFrame = B:cf(px, 13, pz + s * 8), Material = M.WoodPlanks, Color = rgb(110, 76, 50)})
		local f = B:deco({Name = "Brasero", Size = V(1.2, 1.2, 1.2), CFrame = B:cf(px, 14, pz + s * 8), Material = M.Neon, Color = WARM, Transparency = 0.4})
		B:fire(f, 4)
		B:light(f, WARM, 22, 2):AddTag("Flicker")
	end
	B:part({Name = "Travesaño", Size = V(1.6, 1.6, 18), CFrame = B:cf(px, 12, pz), Material = M.Wood, Color = WOOD})
	B:banner(B:cf(px + 1, 11.2, pz, 90), 6, 5, rgb(170, 40, 40), rgb(255, 210, 80))
	-- empalizada a ambos lados de la puerta
	for s = -1, 1, 2 do
		for k = 0, 18 do
			local z = pz + s * (11 + k * 2.3)
			local hgt = 9 + rng:NextNumber(-0.8, 0.8)
			B:part({Name = "Estaca", Shape = Enum.PartType.Cylinder, Size = V(hgt, 2.2, 2.2), CFrame = B:cf(px - 2, hgt / 2, z) * ANG(0, 0, rad(90)), Material = M.Wood, Color = WOOD:Lerp(rgb(60, 40, 26), rng:NextNumber())})
			B:part({Name = "Punta", Size = V(1.5, 1.5, 1.5), CFrame = B:cf(px - 2, hgt + 0.3, z) * ANG(0, rad(45), rad(45)), Material = M.Wood, Color = WOOD})
		end
	end
	B:flush()
	-- campamento: tiendas, hoguera, carros y balas de paja
	B:tent(-138, 42, 90, 8, 10, 6, rgb(200, 60, 60), rgb(240, 230, 210))
	B:tent(-128, 66, 60, 7, 9, 5.5, rgb(60, 90, 190), rgb(240, 230, 210))
	B:tent(-152, 64, 110, 7, 9, 5.5, rgb(200, 160, 50), rgb(240, 230, 210))
	B:campfire(-140, 54)
	for _, a in {{-140, 54, 15}} do
		table.insert(B.avoid, {a[1], a[2], a[3]})
	end
	local function prop(name, x, z, yaw, scale, gap)
		if B:free(x, z, gap or 3) then
			return B:kit(name, x, z, yaw or rng:NextNumber(0, 360), scale)
		end
	end
	prop("Cart", -124, 30, 30)
	prop("Cart", -136, -40, 110)
	for _, p in {{-132, 26}, {-136, 24}, {-138, -50}, {-156, 38}, {-108, -84}, {-160, 8}} do
		prop("HayBale", p[1], p[2])
	end
	prop("NoticeBoard", -140, -48, 70)
	prop("Signpost", -118, -78, 0)
	-- huertos con calabazas y maíz, un espantapájaros y vallas junto a las casas
	for _, f in {{-150, -78}, {-128, 116}, {-158, 40}} do
		for k = 0, 9 do
			local x, z = f[1] + (k % 5) * 3.2 - 6, f[2] + (k // 5) * 4 - 2
			prop(k % 3 == 0 and "CornStalks" or (k % 2 == 0 and "PumpkinRound" or "PumpkinTall"), x, z, nil, 1.2, 2)
		end
		prop("WoodFence", f[1], f[2] - 5, 0, 1, 2)
	end
	prop("Scarecrow", -142, -78, 160, 1)
	B:flush()

	---------- Cementerio (dentro del lazo del camino) y capilla ----------
	local cx, cz, cr = 46, -36, 17
	B:kit("Crypt", cx, cz, -90, 1.1)
	for k = 0, 23 do
		local a = k / 24 * math.pi * 2
		if k ~= 6 then
			B:kit("IronFence", cx + math.cos(a) * cr, cz + math.sin(a) * cr, -math.deg(a) + 90, 0.62, nil, nil, {noCollide = true})
		end
	end
	B:kit("CemeteryGate", cx + math.cos(rad(90)) * cr, cz + math.sin(rad(90)) * cr, 0, 0.9)
	local graves = {"GraveCross", "GraveRound", "GraveObelisk", "GraveSlab", "GraveTomb"}
	for k = 1, 22 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(8, cr - 2.5)
		B:kit(graves[rng:NextInteger(1, #graves)], cx + math.cos(a) * r, cz + math.sin(a) * r, rng:NextNumber(-15, 15) + 90, rng:NextNumber(0.9, 1.15))
	end
	B:kit("Statue", cx - 9, cz - 9, 45, 1.2)
	B:kit("Statue", cx + 9, cz + 9, -135, 1.2)
	B:kit("DeadTreeB", cx + 10, cz - 10, 30, 0.9)
	table.insert(B.avoid, {cx, cz, cr + 3})
	B:kit("Chapel", -10, -98, 0, 0.85)
	table.insert(B.avoid, {-10, -98, 26})
	B:flush()

	---------- Ruinas: trozos de muralla rotos aquí y allá ----------
	for _, r in {{-20, 55, 20, 8}, {72, 40, 15, 6}, {-6, -40, 60, 5}, {92, -96, 0, 7}, {20, 100, 90, 6}} do
		if B:free(r[1], r[2], 8) then
			local len = rng:NextNumber(10, 16)
			local look = B:cf(r[1], 0, r[2], r[3])
			for k = 0, 3 do
				local hh = r[4] * (1 - k * 0.22) + rng:NextNumber(-1, 1)
				B:part({Name = "Ruina", Size = V(len / 4, hh, 3), CFrame = look * CF(-len / 2 + (k + 0.5) * len / 4, hh / 2, 0), Material = M.Cobblestone, Color = STONE:Lerp(STONE_D, rng:NextNumber())})
			end
			B:kit("RockA", r[1] + 3, r[2] + 3, rng:NextNumber(0, 360), 0.6)
			table.insert(B.avoid, {r[1], r[2], 10})
		end
	end
	B:flush()

	---------- Luces a lo largo del camino ----------
	local pts = B.pathPts
	for i = 4, #pts - 3, 4 do
		local p, q = pts[i], pts[i + 1]
		local dir = (q - p).Unit
		local side = Vector2.new(-dir.Y, dir.X) * ((i // 4) % 2 == 0 and 1 or -1)
		local at = p + side * (B.width / 2 + 2.2)
		if B:free(at.X, at.Y, -B.width / 2 + 1) then
			B:kit(i % 3 == 0 and "LampPost" or "PathLantern", at.X, at.Y, math.deg(math.atan2(dir.X, dir.Y)))
		end
	end
	B:flush()

	---------- Bosque y decoración ----------
	-- línea de árboles en los bordes
	local TREES = {"PineA", "PineB", "PineA", "DeadTreeA", "CypressA", "PineB", "DeadTreeC"}
	local function edgeTree(x, z)
		B:kit(TREES[rng:NextInteger(1, #TREES)], x, z, rng:NextNumber(0, 360), rng:NextNumber(0.8, 1.25))
	end
	for x = -180, 110, 16 do
		edgeTree(x + rng:NextNumber(-5, 5), -128 + rng:NextNumber(-8, 4))
		edgeTree(x + rng:NextNumber(-5, 5), 132 + rng:NextNumber(-4, 8))
	end
	for z = -120, 125, 15 do
		edgeTree(-184 + rng:NextNumber(-6, 4), z + rng:NextNumber(-5, 5))
	end
	B:flush()
	-- árboles, arbustos, rocas y setas por el interior (lejos del camino, para que quepan las tropas)
	local INNER = {"DeadTreeA", "DeadTreeB", "CypressB", "PineA", "DeadTreeC", "CypressA"}
	local placed = 0
	for _ = 1, 400 do
		if placed >= 30 then
			break
		end
		local x, z = rng:NextNumber(-165, 105), rng:NextNumber(-112, 116)
		-- (ni en el río ni delante de la plataforma de llegada, para que se vea el mapa)
		local inView = x > -40 and x < 30 and z > 30
		if math.abs(x + 40) > 18 and not inView and B:free(x, z, 16) then
			B:kit(INNER[rng:NextInteger(1, #INNER)], x, z, rng:NextNumber(0, 360), rng:NextNumber(0.7, 1))
			table.insert(B.avoid, {x, z, 9})
			placed += 1
		end
	end
	local SMALL = {"BushA", "BushB", "RockA", "RockC", "Mushrooms", "Pumpkin", "JackOLantern", "BushA", "RockB"}
	placed = 0
	for _ = 1, 600 do
		if placed >= 90 then
			break
		end
		local x, z = rng:NextNumber(-168, 108), rng:NextNumber(-114, 118)
		if math.abs(x + 40) > 15 and B:free(x, z, 3) then
			B:kit(SMALL[rng:NextInteger(1, #SMALL)], x, z, rng:NextNumber(0, 360), rng:NextNumber(0.7, 1.2), nil, nil, {noCollide = true})
			placed += 1
		end
	end
	-- rocas en las orillas del río
	for z = -115, 118, 9 do
		if math.abs(z - 10) > 12 then
			for s = -1, 1, 2 do
				if rng:NextNumber() < 0.6 then
					B:kit(rng:NextNumber() < 0.5 and "RockA" or "RockC", -40 + s * rng:NextNumber(11, 14), z + rng:NextNumber(-3, 3), rng:NextNumber(0, 360), rng:NextNumber(0.6, 1.1), B.F.Rocas, -1.5)
				end
			end
		end
	end
	B:flush()

	---------- Ambiente ----------
	B:ambience(340, 240, rgb(150, 140, 200), rgb(210, 190, 255), 5, 5)
	-- niebla sobre el río
	local mist = B:deco({Name = "NieblaRio", Size = V(20, 1, 240), CFrame = B:cf(-40, 0.5, 0), Transparency = 1}, B.F.TDS)
	B:emitter(mist, {
		Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(rgb(170, 190, 230)), Rate = 6,
		Lifetime = NumberRange.new(6, 10), Speed = NumberRange.new(0.3, 1), SpreadAngle = Vector2.new(180, 5), LightEmission = 0.2,
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 10)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.75), NumberSequenceKeypoint.new(1, 1)}),
	})
	return B:finish()
end

return M_
