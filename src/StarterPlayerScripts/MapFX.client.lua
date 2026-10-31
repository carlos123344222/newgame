-- Mapas del Tower Defense (cliente): lo que se mueve en los mapas (atracciones, barcos, cristales, focos...).
-- Cada pieza animada lleva la etiqueta "MapFX" (un Model o una BasePart) y estos atributos:
--   FX = "spin"  gira sin parar: FXSpeed (rad/s), FXAxis (eje, en el marco de FXHub; por defecto Y)
--   FX = "swing" péndulo: FXAmp (grados), FXSpeed (rad/s de la oscilación), FXAxis
--   FX = "bob"   flota arriba y abajo: FXAmp (studs), FXSpeed
--   FX = "orbit" (góndolas de la noria) da vueltas alrededor de FXHub sobre FXAxis sin girar sobre sí misma
--   FX = "sweep" (focos) barre a un lado y a otro: FXAmp (grados), FXSpeed, FXAxis
-- FXHub (CFrame, mundo): el eje; si falta, el pivote. FXPhase (s): desfase para que no vayan todos a la vez.
-- Las piezas están ancladas en el servidor: solo se mueven en tu pantalla, y solo si están cerca de la cámara.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local FAR = 700 -- más lejos de la cámara no se anima
local RATE = 1 / 40

local rotors = {} -- [instancia] = estado

local function partsOf(inst)
	if inst:IsA("BasePart") then
		return {inst}
	end
	local list = {}
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

local function add(inst)
	if rotors[inst] or not (inst:IsA("Model") or inst:IsA("BasePart")) then
		return
	end
	-- el mapa llega al cliente por partes: se espera a que el modelo tenga todas sus piezas (deja de crecer)
	local parts, last = partsOf(inst), -1
	for _ = 1, 30 do
		if #parts > 0 and #parts == last then
			break
		end
		last = #parts
		task.wait(0.4)
		if not inst.Parent then
			return
		end
		parts = partsOf(inst)
	end
	if #parts == 0 or rotors[inst] then
		return
	end
	local pivot = inst:GetPivot()
	local hub = inst:GetAttribute("FXHub") or pivot
	local r = {
		inst = inst, kind = inst:GetAttribute("FX"), hub = hub, parts = parts, offsets = {}, cfs = table.create(#parts),
		speed = inst:GetAttribute("FXSpeed") or 0.5, amp = inst:GetAttribute("FXAmp") or 20,
		axis = (inst:GetAttribute("FXAxis") or Vector3.yAxis).Unit, phase = inst:GetAttribute("FXPhase") or math.random() * 10,
	}
	if r.kind == "orbit" then
		-- la góndola: su pivote da vueltas, sus piezas guardan la orientación
		r.arm = hub:PointToObjectSpace(pivot.Position)
		r.rot = pivot.Rotation
		for i, p in parts do
			r.offsets[i] = pivot:ToObjectSpace(p.CFrame)
		end
	else
		for i, p in parts do
			r.offsets[i] = hub:ToObjectSpace(p.CFrame)
		end
	end
	rotors[inst] = r
end

local function transform(r, t)
	local k = r.kind
	local tt = t + r.phase
	if k == "spin" or k == "orbit" then
		return CFrame.fromAxisAngle(r.axis, tt * r.speed)
	elseif k == "swing" or k == "sweep" then
		return CFrame.fromAxisAngle(r.axis, math.rad(r.amp) * math.sin(tt * r.speed))
	elseif k == "bob" then
		return CFrame.new(r.axis * r.amp * math.sin(tt * r.speed))
	end
	return CFrame.identity
end

for _, inst in CollectionService:GetTagged("MapFX") do
	task.spawn(add, inst)
end
CollectionService:GetInstanceAddedSignal("MapFX"):Connect(function(inst)
	task.defer(add, inst) -- (que lleguen antes sus piezas)
end)
CollectionService:GetInstanceRemovedSignal("MapFX"):Connect(function(inst)
	rotors[inst] = nil
end)

local acc = 0
RunService.RenderStepped:Connect(function(dt)
	acc += dt
	if acc < RATE then
		return
	end
	acc = 0
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local t = os.clock()
	local parts, cfs = {}, {}
	for inst, r in rotors do
		if not inst.Parent then
			rotors[inst] = nil
			continue
		end
		if (r.hub.Position - camPos).Magnitude > FAR then
			continue
		end
		local m = transform(r, t)
		if r.kind == "orbit" then
			local pos = r.hub * (m * r.arm)
			local base = CFrame.new(pos) * r.rot
			for i, p in r.parts do
				table.insert(parts, p)
				table.insert(cfs, base * r.offsets[i])
			end
		else
			local base = r.hub * m
			for i, p in r.parts do
				table.insert(parts, p)
				table.insert(cfs, base * r.offsets[i])
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
