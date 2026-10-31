-- Criaturas de bloques articuladas (las usan ScareBehaviors en el servidor y ScareIdle en el cliente).
-- Cada criatura es un Model con una pieza Root invisible (PrimaryPart) y piezas con los atributos Limb (a qué
-- articulación va) y Rest (su sitio en pose neutra respecto a Root). La criatura guarda cada articulación como J_<nombre>
-- (pivote en reposo, respecto a Root), su pose de reposo P_<nombre> (grados) y, si no es una de las de siempre, su
-- padre Par_<nombre>. Las de siempre: Torso y piernas cuelgan de Root; cabeza y brazos, del torso.
-- Una pose es {<articulación> = Vector3 en grados} más Root (desplazamiento en studs) y RootR (giro de todo el cuerpo).
-- Grados como CFrame.Angles: X+ levanta brazo o pierna hacia delante y echa torso o cabeza hacia atrás; Y gira; Z+
-- inclina hacia la izquierda de la criatura (brazo izquierdo hacia fuera = Z negativo, derecho = Z positivo).
local RunService = game:GetService("RunService")

local Rig = {}

local V0 = Vector3.zero
local PARENT = {Torso = "Root", Head = "Torso", ArmL = "Torso", ArmR = "Torso", LegL = "Root", LegR = "Root"}

local function ang(v)
	return CFrame.Angles(math.rad(v.X), math.rad(v.Y), math.rad(v.Z))
end

-- Datos de la criatura (se leen una vez): articulaciones, padres, pivotes, reposo y sus piezas
local cache = setmetatable({}, {__mode = "k"})
function Rig.info(c)
	local i = cache[c]
	if i then
		return i
	end
	i = {limbs = {"Root", "RootR"}, joints = {}, parent = {}, idle = {}, parts = {}}
	for k, v in c:GetAttributes() do
		local name = k:match("^J_(.+)$")
		if name then
			i.joints[name] = v
			table.insert(i.limbs, name)
		end
	end
	for name in i.joints do
		i.parent[name] = c:GetAttribute("Par_" .. name) or PARENT[name] or "Root"
	end
	for _, l in i.limbs do
		i.idle[l] = c:GetAttribute("P_" .. l) or V0
	end
	for _, p in c:GetDescendants() do
		if p:IsA("BasePart") and p:GetAttribute("Rest") then
			table.insert(i.parts, p)
		end
	end
	cache[c] = i
	return i
end

function Rig.idlePose(c)
	return table.clone(Rig.info(c).idle)
end

-- pose completa: lo que no diga 'partial' se queda como en reposo
function Rig.full(c, partial)
	local p = Rig.idlePose(c)
	for l, v in partial do
		p[l] = v
	end
	return p
end

function Rig.setPose(c, pose)
	local root = c.PrimaryPart
	if not root then
		return
	end
	local i = Rig.info(c)
	local sc = c:GetScale()
	local W = {Root = root.CFrame * CFrame.new((pose.Root or V0) * sc) * ang(pose.RootR or V0)}
	local function get(l)
		local w = W[l]
		if not w then
			local j = (i.joints[l] or V0) * sc
			w = get(i.parent[l] or "Root") * CFrame.new(j) * ang(pose[l] or V0) * CFrame.new(-j)
			W[l] = w
		end
		return w
	end
	local parts, cfs = {}, {}
	for _, p in i.parts do
		if p.Parent then
			local rest = p:GetAttribute("Rest")
			table.insert(parts, p)
			table.insert(cfs, get(p:GetAttribute("Limb")) * (rest.Rotation + rest.Position * sc))
		end
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	i.last = pose
end

-- La última pose que se le puso (o la de reposo)
function Rig.current(c)
	return table.clone(Rig.info(c).last or Rig.idlePose(c))
end

Rig.EASE = {
	out = function(a)
		return 1 - (1 - a) ^ 3
	end,
	["in"] = function(a)
		return a * a * a
	end,
	back = function(a) -- se pasa un poco y vuelve
		a -= 1
		return 1 + a * a * (2.7 * a + 1.7)
	end,
	elastic = function(a)
		if a <= 0 or a >= 1 then
			return a
		end
		return 2 ^ (-10 * a) * math.sin((a * 10 - 0.75) * (2 * math.pi) / 3) + 1
	end,
	linear = function(a)
		return a
	end,
}
local EASE = Rig.EASE

-- claves {t, pose parcial, curva?}: la curva es la de llegada a esa clave (por defecto, suave)
function Rig.sample(c, keys, t)
	if t <= keys[1][1] then
		return Rig.full(c, keys[1][2])
	end
	for n = 2, #keys do
		local k0, k1 = keys[n - 1], keys[n]
		if t <= k1[1] then
			local a = (t - k0[1]) / (k1[1] - k0[1])
			local e = EASE[k1[3]]
			a = e and e(a) or a * a * (3 - 2 * a)
			local p0, p1, p = Rig.full(c, k0[2]), Rig.full(c, k1[2]), {}
			for _, l in Rig.info(c).limbs do
				p[l] = p0[l]:Lerp(p1[l], a)
			end
			return p
		end
	end
	return Rig.full(c, keys[#keys][2])
end

-- reproduce las claves; extra(pose, t) puede retocar la pose de cada frame (temblores, ondulaciones...)
-- stop(): si devuelve true, se corta
function Rig.play(c, keys, extra, stop)
	local dur = keys[#keys][1]
	local t0 = os.clock()
	repeat
		local t = math.min(os.clock() - t0, dur)
		local p = Rig.sample(c, keys, t)
		if extra then
			extra(p, t)
		end
		Rig.setPose(c, p)
		RunService.Heartbeat:Wait()
	until t >= dur or not c.Parent or (stop and stop())
end

-- Pasa suave de la pose actual a 'to' (parcial: lo demás, a reposo) en 'time' segundos; con 'home', también devuelve
-- la criatura a ese sitio (si se había girado)
function Rig.blend(c, to, time, ease, home)
	local from, target = Rig.current(c), Rig.full(c, to or {})
	local pv0 = c:GetPivot()
	local e = EASE[ease] or function(a)
		return a * a * (3 - 2 * a)
	end
	local t0 = os.clock()
	repeat
		local a = math.min(1, (os.clock() - t0) / time)
		local k = e(a)
		local p = {}
		for _, l in Rig.info(c).limbs do
			p[l] = (from[l] or Vector3.zero):Lerp(target[l], k)
		end
		if home then
			c:PivotTo(pv0:Lerp(home, k))
		end
		Rig.setPose(c, p)
		RunService.Heartbeat:Wait()
	until a >= 1 or not c.Parent
end

-- temblor nervioso (grados) en las articulaciones indicadas
function Rig.jitter(p, t, amount, seed, limbs)
	for n, l in limbs do
		local k = seed + n * 7
		p[l] = (p[l] or V0) + Vector3.new(math.noise(t * 11, k), math.noise(t * 11, k + 50), math.noise(t * 11, k + 100)) * amount
	end
end

return Rig
