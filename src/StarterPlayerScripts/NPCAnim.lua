-- Animaciones de los visitantes bot: capas de pose procedurales encima del walk/run del Animate.
-- Diseño: tablero "NPC Animation Storyboard" (Claude Design): sneak, startle, nervous, cheer, faint y panic.
-- El servidor solo marca el estado en el bot (etiqueta "Visitor"; atributos Anim, AnimAt y Fear) y cada cliente
-- mueve las articulaciones (.Transform) en PreSimulation, justo después de que el Animator ponga la pose del walk.
-- Ángulos en grados: + levanta la extremidad hacia delante, dobla el codo o la cadera; las rodillas, la cintura
-- y el cuello usan el signo contrario (por eso -x en esas).
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local rad, sin, clamp, noise = math.rad, math.sin, math.clamp, math.noise
local TAU = math.pi * 2
local BLEND = 0.25 -- fundido entre capas (s)
local FAR = 120 -- más lejos de la cámara no se anima la capa
local JOINTS = {"Root", "Waist", "Neck", "LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow", "RightWrist", "LeftWrist", "LeftHip", "RightHip", "LeftKnee", "RightKnee"}
local ONE_SHOT = {startle = 1, faint = 1.4, cheer = 1.6} -- duración; al acabar startle vuelve a sneak, las otras se quedan quietas

local function ang(pitch, yaw, roll)
	return CFrame.Angles(rad(pitch), rad(yaw or 0), rad(roll or 0))
end

-- Curva por claves {t, valor, ease?}: "out" frena al llegar, "in" acelera; por defecto suave
local function curve(keys, t)
	if t <= keys[1][1] then
		return keys[1][2]
	end
	for i = 2, #keys do
		local k0, k1 = keys[i - 1], keys[i]
		if t <= k1[1] then
			local a = (t - k0[1]) / (k1[1] - k0[1])
			if k1[3] == "out" then
				a = 1 - (1 - a) ^ 2
			elseif k1[3] == "in" then
				a = a * a
			else
				a = a * a * (3 - 2 * a)
			end
			return k0[2] + (k1[2] - k0[2]) * a
		end
	end
	return keys[#keys][2]
end

local GLANCE = {{0, 0}, {0.2, 1, "out"}, {0.6, 1}, {0.9, 0}}
local LOOK_BACK = {{0, 0}, {0.62, 0}, {0.72, 1, "out"}, {0.9, 1}, {0.98, 0}}

-- Cada capa devuelve {articulación = {CFrame, reemplazo}}: reemplazo 0 = se suma al walk, 1 = lo sustituye
local Layers = {}

-- 01 Sneak (+ 03 Nervous a partir de miedo 40): agachado, linterna delante y la cabeza barriendo la sala
function Layers.sneak(t, b)
	local w, f = b.nervW, b.nervF
	local scan = sin(t * TAU / 2.4) * (1 - 0.6 * w)
	local amp = (1.5 + 3 * f) * w
	local function shake(k)
		return noise(t * 12, b.seed + k) * amp * 2
	end
	local g = b.glance * b.gSide
	local torch = 72 - 14 * w + shake(4)
	return {
		Root = {CFrame.new(0, -0.12 - 0.06 * w, 0), 0},
		Waist = {ang(-(10 + (8 + 10 * f) * w) + shake(1), 35 * g, shake(2)), 0},
		Neck = {ang(-(5 + 12 * w) + shake(3), 35 * scan + 80 * g), 0},
		RightShoulder = {ang(torch, 17 * scan), 0.85},
		RightElbow = {ang(8), 0.85},
		-- la linterna va soldada a la mano: la muñeca la endereza para que alumbre hacia delante y un poco abajo
		RightWrist = {ang(-(torch + 8) - 12), 1},
		LeftShoulder = {ang(38 + 24 * w), 0.85},
		LeftElbow = {ang(78 + 40 * w), 0.85},
		LeftHip = {ang(14 - 4 * w), 0},
		RightHip = {ang(14 - 4 * w), 0},
		LeftKnee = {ang(-26 + 6 * w), 0},
		RightKnee = {ang(-26 + 6 * w), 0},
	}
end

-- 07 March (jefes del Tower Defense): erguidos y amenazantes, pecho fuera, a paso firme; la derecha en alto con lo que
-- lleve (el báculo, la lanza) y la izquierda delante (el libro, el detector). Las muñecas enderezan lo que llevan.
function Layers.march(t, b)
	local step = sin(t * TAU / 1.25)
	local sway = sin(t * TAU / 2.5)
	return {
		Root = {CFrame.new(0, 0.05 * math.abs(step), 0) * ang(0, 4 * sway, 0), 0},
		Waist = {ang(5, -6 * sway, 2 * step), 0},
		Neck = {ang(-8 + 3 * math.abs(step), 10 * sway), 0},
		RightShoulder = {ang(34 + 3 * step, 0, -6), 0.9},
		RightElbow = {ang(46), 0.9},
		RightWrist = {ang(-80), 1},
		-- (a la altura del pecho: más arriba, el libro le tapaba la cara)
		LeftShoulder = {ang(20 - 3 * step, 0, 10), 0.9},
		LeftElbow = {ang(30), 0.9},
		LeftWrist = {ang(-50), 1},
	}
end

-- 02 Startle: respingo, salto atrás con las manos a la cara y guardia temblando
local ST = {
	rootY = {{0, 0}, {0.1, -0.15}, {0.28, 0.7, "out"}, {0.45, -0.1, "in"}, {0.6, -0.05}},
	rootZ = {{0, 0}, {0.1, 0}, {0.28, 0.8, "out"}},
	waist = {{0, 0}, {0.1, 8}, {0.28, -18}, {0.45, -6}, {1, -2.5}},
	neck = {{0, 0}, {0.1, 10}, {0.28, -16}, {0.45, -6}, {1, -4}},
	shR = {{0, 0}, {0.1, 20}, {0.28, 150}, {0.45, 110}, {0.6, 97}, {1, 96}},
	shL = {{0, 0}, {0.1, 16}, {0.28, 140}, {0.45, 104}, {1, 92}},
	elbow = {{0, 0}, {0.28, 60}, {0.45, 95}, {1, 100}},
	hipR = {{0, 0}, {0.1, 14}, {0.28, 30}, {0.45, 26}, {1, 12}},
	hipL = {{0, 0}, {0.1, 10}, {0.28, 8}, {0.45, 20}, {1, 8}},
	knee = {{0, 0}, {0.1, 26}, {0.28, 50}, {0.45, 48}, {1, 20}},
}
function Layers.startle(t, b)
	local tr = t > 0.45 and noise(t * 12, b.seed) * 3 * (1 - clamp((t - 0.45) / 0.55, 0, 1)) or 0
	local el, knee = curve(ST.elbow, t), curve(ST.knee, t)
	return {
		Root = {CFrame.new(0, curve(ST.rootY, t), curve(ST.rootZ, t)), 1},
		Waist = {ang(-(curve(ST.waist, t) + tr)), 1},
		Neck = {ang(-curve(ST.neck, t) + tr), 1},
		RightShoulder = {ang(curve(ST.shR, t) + tr, 0, -10), 1},
		LeftShoulder = {ang(curve(ST.shL, t) - tr, 0, 10), 1},
		RightElbow = {ang(el), 1},
		LeftElbow = {ang(el), 1},
		RightHip = {ang(curve(ST.hipR, t)), 1},
		LeftHip = {ang(curve(ST.hipL, t)), 1},
		RightKnee = {ang(-knee), 1},
		LeftKnee = {ang(-knee * 0.8), 1},
	}
end

-- 04 Cheer: salto con los brazos arriba, dos puñetazos al aire y mano en la cadera
local CH = {
	rootY = {{0, 0}, {0.15, -0.3}, {0.55, 1.4, "out"}, {0.72, -0.2, "in"}, {0.86, 0, "out"}},
	hip = {{0, 0}, {0.15, 36}, {0.34, 14}, {0.55, 42}, {0.72, 30}, {0.96, 4}},
	knee = {{0, 0}, {0.15, 70}, {0.34, 16}, {0.55, 78}, {0.72, 58}, {0.96, 8}},
	waist = {{0, 0}, {0.15, 14}, {0.55, -10}, {0.72, 6}, {0.96, 0}},
	neck = {{0, 0}, {0.15, 6}, {0.55, -18}, {0.96, -6}, {1.08, 6}, {1.25, -6}, {1.42, 6}, {1.6, -4}},
	shR = {{0, 0}, {0.15, -30}, {0.55, 170}, {0.72, 160}, {0.96, 148}, {1.18, 176}, {1.4, 148}, {1.6, 176}},
	rollR = {{0, 0}, {0.55, 20}, {0.96, 10}},
	elR = {{0, 0}, {0.72, 18}, {0.96, 100}, {1.18, 14}, {1.4, 100}, {1.6, 14}},
	shL = {{0, 0}, {0.15, -30}, {0.55, 170}, {0.72, 165}, {0.96, -12}},
	rollL = {{0, 0}, {0.55, -20}, {0.72, -20}, {0.96, -45}},
	elL = {{0, 0}, {0.72, 0}, {0.96, 100}},
}
function Layers.cheer(t, b)
	local hip, knee = curve(CH.hip, t), curve(CH.knee, t)
	return {
		Root = {CFrame.new(0, curve(CH.rootY, t), 0), 1},
		Waist = {ang(-curve(CH.waist, t)), 1},
		Neck = {ang(-curve(CH.neck, t)), 1},
		RightShoulder = {ang(curve(CH.shR, t), 0, curve(CH.rollR, t)), 1},
		RightElbow = {ang(curve(CH.elR, t)), 1},
		LeftShoulder = {ang(curve(CH.shL, t), 0, curve(CH.rollL, t)), 1},
		LeftElbow = {ang(0, 0, curve(CH.elL, t)), 1},
		RightHip = {ang(hip), 1},
		LeftHip = {ang(hip), 1},
		RightKnee = {ang(-knee), 1},
		LeftKnee = {ang(-knee), 1},
	}
end

-- 05 Faint: se le doblan las rodillas, cae de espaldas girando sobre los pies, rebota y se queda tumbado
local FA = {
	a = {{0, 0}, {0.25, 0}, {0.85, 90, "in"}, {1, 80, "out"}, {1.1, 89, "in"}, {1.4, 88}},
	lift = {{0, 0}, {0.25, -0.25}, {0.85, 0.45, "in"}, {1, 0.6}, {1.1, 0.48}, {1.4, 0.5}},
	hip = {{0, 0}, {0.25, 26}, {0.85, 8}, {1.4, 4}},
	knee = {{0, 0}, {0.25, 52}, {0.85, 14}, {1.4, 8}},
	waist = {{0, 0}, {0.25, 12}, {0.85, -10}, {1.1, -4}, {1.4, 0}},
	neck = {{0, 0}, {0.25, 18}, {0.85, -24}, {1, 10}, {1.4, 6}},
	roll = {{0, 0}, {1, 0}, {1.4, 1}},
	sh = {{0, 0}, {0.25, 8}, {0.85, 130}, {1, 150}, {1.4, 122}},
	elbow = {{0, 0}, {0.85, 20}, {1.4, 12}},
}
function Layers.faint(t, b)
	local fy, roll = b.feetY, curve(FA.roll, t)
	local sh, el, hip, knee = curve(FA.sh, t), curve(FA.elbow, t), curve(FA.hip, t), curve(FA.knee, t)
	return {
		Root = {CFrame.new(0, curve(FA.lift, t) + fy, 0) * ang(curve(FA.a, t)) * CFrame.new(0, -fy, 0), 1},
		Waist = {ang(-curve(FA.waist, t)), 1},
		Neck = {ang(-curve(FA.neck, t), 0, 25 * roll * b.side), 1},
		RightShoulder = {ang(sh, 0, 20 * roll), 1},
		LeftShoulder = {ang(sh, 0, -20 * roll), 1},
		RightElbow = {ang(el), 1},
		LeftElbow = {ang(el), 1},
		RightHip = {ang(hip), 1},
		LeftHip = {ang(hip * 0.8), 1},
		RightKnee = {ang(-knee), 1},
		LeftKnee = {ang(-knee * 0.9), 1},
	}
end

-- 06 Panic run: brazos agitándose por encima de la cabeza, inclinado y mirando atrás cada 1.2 s
function Layers.panic(t, b)
	local p = sin(t * TAU / 0.5)
	local look = curve(LOOK_BACK, t % 1.2)
	return {
		Waist = {ang(-20), 0},
		Neck = {ang(8, 70 * look * b.side), 0},
		RightShoulder = {ang(177 + 27 * p, 0, 15), 1},
		LeftShoulder = {ang(177 - 27 * p, 0, -15), 1},
		RightElbow = {ang(25 + 15 * p), 1},
		LeftElbow = {ang(25 - 15 * p), 1},
	}
end

---------- Bots ----------
local bots = {} -- [modelo] = estado de animación

local function addBot(model)
	task.spawn(function()
		local root = model:WaitForChild("HumanoidRootPart", 10)
		local hum = model:WaitForChild("Humanoid", 10)
		if not (root and hum and model.Parent) then
			return
		end
		local b = {
			root = root, joints = {}, base = {}, seed = math.random() * 100, side = math.random() < 0.5 and -1 or 1,
			nervW = 0, nervF = 0, glance = 0, gSide = 1, glanceAt = os.clock() + 2 + math.random() * 3,
		}
		-- con el "avatar joint upgrade" el rig lleva Motor6D y AnimationConstraint con el mismo nombre: la pose
		-- la mandan los Motor6D (escribir en el AnimationConstraint no mueve nada). El modelo llega al cliente
		-- por partes: se buscan hasta tenerlas todas (o 5 s).
		local t0 = os.clock()
		repeat
			local n = 0
			for _, d in model:GetDescendants() do
				if d:IsA("Motor6D") and table.find(JOINTS, d.Name) then
					b.joints[d.Name] = d
					n += 1
				end
			end
			if n >= #JOINTS then
				break
			end
			task.wait(0.2)
		until os.clock() - t0 > 5 or not model.Parent
		-- altura de los pies en el marco de la articulación Root (para caer girando sobre ellos)
		local rj = b.joints.Root
		local y0 = rj and rj.C0.Position.Y or 0
		b.feetY = -(root.Size.Y / 2 + hum.HipHeight) - y0
		bots[model] = b
	end)
end
for _, m in CollectionService:GetTagged("Visitor") do
	addBot(m)
end
CollectionService:GetInstanceAddedSignal("Visitor"):Connect(addBot)
CollectionService:GetInstanceRemovedSignal("Visitor"):Connect(function(m)
	bots[m] = nil
end)

local function poseOf(state, t, b)
	local layer = state and Layers[state]
	return layer and layer(math.min(t, ONE_SHOT[state] or t), b)
end

-- pose final de una articulación: sobre lo que puso el Animator (base), sumada o sustituida
local function apply(base, p)
	if not p then
		return base
	end
	return (p[2] > 0 and base:Lerp(CFrame.identity, p[2]) or base) * p[1]
end

-- Antes de que el Animator ponga la pose de este frame se quita la capa del anterior: si una articulación no la
-- anima nadie (bot quieto sin animaciones) el valor se quedaría y las capas aditivas se irían sumando.
RunService.PreAnimation:Connect(function()
	for _, b in bots do
		for name, base in b.base do
			local j = b.joints[name]
			if j then
				j.Transform = base
			end
		end
	end
end)

RunService.PreSimulation:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local now = workspace:GetServerTimeNow()
	local clock = os.clock()
	for model, b in bots do
		if not model.Parent then
			bots[model] = nil
			continue
		end
		-- estado que marca el servidor; un susto acabado vuelve solo a sneak
		local state, at = model:GetAttribute("Anim"), model:GetAttribute("AnimAt") or now
		if state == "startle" and now - at > ONE_SHOT.startle then
			state, at = model:GetAttribute("Walk") or "sneak", at + ONE_SHOT.startle
		end
		if state ~= b.state or (ONE_SHOT[state] and at ~= b.at) then
			b.prev, b.prevAt, b.blendAt = b.state, b.at, clock
			b.state, b.at = state, at
		end
		if (b.root.Position - camPos).Magnitude > FAR then
			table.clear(b.base)
			continue
		end
		-- miedo: la capa nerviosa entra poco a poco a partir de 40
		local fear = model:GetAttribute("Fear") or 0
		local k = math.min(1, dt * 3)
		b.nervW += ((fear >= 40 and 1 or 0) - b.nervW) * k
		b.nervF += (clamp((fear - 40) / 60, 0, 1) - b.nervF) * k
		-- con miedo, de vez en cuando mira atrás por encima del hombro
		if b.gStart then
			local g = clock - b.gStart
			b.glance = curve(GLANCE, g)
			if g > 0.9 then
				b.gStart, b.glance = nil, 0
				b.glanceAt = clock + 3 + math.random() * 2
			end
		elseif b.nervW > 0.5 and b.state == "sneak" and clock > b.glanceAt then
			b.gStart, b.gSide = clock, math.random() < 0.5 and -1 or 1
		end
		-- fundido entre la capa anterior y la actual
		local w = b.blendAt and clamp((clock - b.blendAt) / BLEND, 0, 1) or 1
		w = w * w * (3 - 2 * w)
		local cur = poseOf(b.state, now - (b.at or now), b)
		local prev = w < 1 and poseOf(b.prev, now - (b.prevAt or now), b) or nil
		if w >= 1 then
			b.prev, b.blendAt = nil, nil
		end
		if not cur and not prev then
			table.clear(b.base)
			continue
		end
		for name, joint in b.joints do
			local pc, pp = cur and cur[name], prev and prev[name]
			if not pc and not pp then
				b.base[name] = nil
				continue
			end
			local base = joint.Transform -- la pose del Animator de este frame (o la base restaurada)
			local out = apply(base, pc)
			if prev then
				out = apply(base, pp):Lerp(out, w)
			end
			joint.Transform = out
			b.base[name] = base
		end
	end
end)

return {}
