-- Movimiento suave al estilo del lobby de Ultimate Tower Defense: andas despacio y esprintas (Shift, L3 en mando o el
-- botón Run en móvil) a toda velocidad desde el primer instante, el cuerpo gira
-- suave hacia donde vas, al soltar frenas deslizando un poco, te inclinas al correr y en las curvas, la cámara se echa
-- atrás y abre el FOV al correr, y doble salto con voltereta. Para que se sienta bien: el cuerpo y la cámara rebotan
-- con un muelle al saltar y al caer, y sale polvo de los pies al arrancar, al correr, al saltar y al aterrizar.
-- Poses en el aire (como en UTD): al saltar, brazos en cruz y una rodilla arriba; en el doble salto, hecho bola hasta
-- tocar el suelo.
-- No pelea con quien fija WalkSpeed (bloqueos, visitas, servidor): ese valor es la "base" y aquí solo se multiplica.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local char = script.Parent
local hum = char:WaitForChild("Humanoid")
local root = char:WaitForChild("HumanoidRootPart")
local lower = char:FindFirstChild("LowerTorso")
local joint = lower and lower:WaitForChild("Root") or root:WaitForChild("RootJoint") -- R15 / R6
-- rig nuevo (AnimationConstraint): se gira su Attachment0; rig clásico (Motor6D): su C0
local holder, prop = joint, "C0"
if joint:IsA("AnimationConstraint") then
	holder, prop = joint.Attachment0, "CFrame"
end
local rest = holder[prop]

local WALK = 0.8 -- andar = base × WALK
local SPEED = 1.5 -- esprintar = base × SPEED, al instante (en las visitas, la base tal cual y sin esprint)
local TURN = 18 -- rapidez con la que el cuerpo gira hacia donde vas (más alto = más brusco)
local SLIDE = 0.2 -- segundos que sigues deslizando al soltar
local LEAN = math.rad(9) -- inclinación hacia delante a toda carrera
local BANK = math.rad(12) -- inclinación en las curvas
local FOV_KICK = 8 -- grados de FOV extra a toda carrera
local PULL = 5 -- studs que la cámara se echa atrás a toda carrera
local DJ_HEIGHT = 7 -- studs que sube el doble salto
local FLOAT = 0.3 -- parte de la gravedad que se anula tras el doble salto (más alto = más lento en el aire)
local FLIP_TIME = 0.5 -- segundos que dura la voltereta del doble salto
local SPRING, DAMP = 260, 16 -- muelle del rebote al saltar y caer (DAMP más bajo = rebota más)

-- Poses por articulación (giro del Transform; ejes del personaje: X derecha, Y arriba, -Z delante).
-- Hombro: +Z abre el brazo derecho (-Z el izquierdo), +X lo lleva adelante. Cadera: +X sube la pierna. Rodilla: -X la
-- dobla. Codo: +X lo dobla. Cintura y cuello: -X hacia delante.
local r = math.rad
local POSES = {
	jump = { -- brazos en cruz, rodilla derecha arriba, la otra pierna un poco atrás
		RightShoulder = CFrame.Angles(r(-10), 0, r(78)),
		LeftShoulder = CFrame.Angles(r(-10), 0, r(-78)),
		RightElbow = CFrame.Angles(r(8), 0, 0),
		LeftElbow = CFrame.Angles(r(8), 0, 0),
		RightHip = CFrame.Angles(r(80), 0, 0),
		RightKnee = CFrame.Angles(r(-95), 0, 0),
		LeftHip = CFrame.Angles(r(-12), 0, 0),
		LeftKnee = CFrame.Angles(r(-35), 0, 0),
	},
	tuck = { -- hecho bola: rodillas al pecho, brazos abrazando las piernas, cabeza metida
		RightShoulder = CFrame.Angles(r(75), 0, r(-10)),
		LeftShoulder = CFrame.Angles(r(75), 0, r(10)),
		RightElbow = CFrame.Angles(r(75), 0, 0),
		LeftElbow = CFrame.Angles(r(75), 0, 0),
		RightHip = CFrame.Angles(r(115), 0, 0),
		RightKnee = CFrame.Angles(r(-135), 0, 0),
		LeftHip = CFrame.Angles(r(115), 0, 0),
		LeftKnee = CFrame.Angles(r(-135), 0, 0),
		Waist = CFrame.Angles(r(-30), 0, 0),
		Neck = CFrame.Angles(r(-25), 0, 0),
	},
}
local joints = {}
for _, pose in POSES do
	for name in pose do
		joints[name] = joints[name] or char:FindFirstChild(name, true)
	end
end

local base = hum.WalkSpeed
local mine = base -- lo último que escribimos; si WalkSpeed cambia a otra cosa, alguien fijó una base nueva
local slide, lean, bank, kick, pull = 0, 0, 0, 0, 0
local jumped, flipT = false, nil
local lastLook = root.CFrame.LookVector
local dir = lastLook -- hacia dónde vas (horizontal)
local sq, sqVel = 0, 0 -- rebote en studs: + estirado (salto), - aplastado (caída)
local fall, puff = 0, 0
local UI = require(player:WaitForChild("PlayerScripts"):WaitForChild("UI")) -- UI.sound: sonidos del juego con su mezcla

-- el cuerpo se orienta con física (giro suave) en vez del giro instantáneo del Humanoid
local att = root:WaitForChild("RootAttachment")
local align = Instance.new("AlignOrientation")
align.Mode = Enum.OrientationAlignmentMode.OneAttachment
align.Attachment0 = att
align.Responsiveness = TURN
align.MaxTorque = math.huge
align.Enabled = false
align.Parent = root
-- tras el doble salto, una fuerza hacia arriba anula parte de la gravedad: subes y caes despacio
local float = Instance.new("VectorForce")
float.Attachment0 = att
float.RelativeTo = Enum.ActuatorRelativeTo.World
float.ApplyAtCenterOfMass = true
float.Enabled = false
float.Parent = root
-- polvo en los pies
local feet = Instance.new("Attachment")
feet.Position = Vector3.new(0, -(root.Size.Y / 2 + hum.HipHeight) + 0.2, 0)
feet.Parent = root
local dust = Instance.new("ParticleEmitter")
dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
dust.Color = ColorSequence.new(Color3.fromRGB(205, 195, 180))
dust.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1)})
dust.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 2.2)})
dust.Lifetime = NumberRange.new(0.35, 0.6)
dust.Speed = NumberRange.new(4, 8)
dust.SpreadAngle = Vector2.new(85, 85)
dust.Drag = 6
dust.Rotation = NumberRange.new(0, 360)
dust.RotSpeed = NumberRange.new(-120, 120)
dust.LightInfluence = 0.6
dust.Enabled = false
dust.Parent = feet

local function bounce(v)
	sqVel += v
end

local function setKick(k)
	workspace.CurrentCamera.FieldOfView += k - kick -- como delta: no pisa los golpes de FOV de las visitas
	kick = k
end

-- doble salto: un segundo salto en el aire (no en las visitas ni con el salto bloqueado), con voltereta
local AIR = {[Enum.HumanoidStateType.Jumping] = true, [Enum.HumanoidStateType.Freefall] = true}
hum.StateChanged:Connect(function(_, new)
	if new == Enum.HumanoidStateType.Jumping then
		bounce(5)
		dust:Emit(6)
	elseif new == Enum.HumanoidStateType.Landed then
		-- cuanto más rápido caes, más se aplasta, más polvo y (si es fuerte o tras el doble salto) un golpe sordo
		local hard = math.clamp(fall / 60, 0, 1)
		bounce(-3 - 8 * hard)
		dust:Emit(4 + math.floor(14 * hard))
		if jumped or hard > 0.6 then
			UI.sound("Thud", 0.25 + 0.4 * hard, 1.25)
		end
	end
	if not AIR[new] then
		jumped, flipT = false, nil
		float.Enabled = false
	end
end)
-- JumpRequest se repite mientras mantienes el botón: el segundo salto pide haberlo soltado antes
local released = true
UIS.InputEnded:Connect(function(input)
	local key = input.KeyCode
	if key == Enum.KeyCode.Space or key == Enum.KeyCode.ButtonA or input.UserInputType == Enum.UserInputType.Touch then
		released = true
	end
end)
UIS.JumpRequest:Connect(function()
	local fresh = released
	released = false
	if not fresh or jumped or not AIR[hum:GetState()] or hum.JumpHeight <= 0 or player:GetAttribute("Mode") == "visit" then
		return
	end
	jumped, flipT = true, 0
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, math.sqrt(2 * workspace.Gravity * (1 - FLOAT) * DJ_HEIGHT), v.Z)
	float.Force = Vector3.new(0, root.AssemblyMass * workspace.Gravity * FLOAT, 0)
	float.Enabled = true
	bounce(7)
	dust:Emit(14)
	UI.sound("Swoosh", 0.9, 1.15)
end)

-- poses en el aire: se escriben después de las animaciones (PreSimulation) y se mezclan con ellas según el peso
local wJump, wTuck = 0, 0
local poseConn = RunService.PreSimulation:Connect(function(dt)
	local inAir = AIR[hum:GetState()] == true
	local k = 1 - math.exp(-16 * dt)
	wTuck += ((inAir and jumped and 1 or 0) - wTuck) * k -- tras el doble salto, hecho bola hasta tocar el suelo
	wJump += ((inAir and not jumped and 1 or 0) - wJump) * k
	if wJump < 0.01 and wTuck < 0.01 then
		return
	end
	for name, j in joints do
		local t = j.Transform
		local a, b = POSES.jump[name], POSES.tuck[name]
		if a then
			t = t:Lerp(a, wJump)
		end
		if b then
			t = t:Lerp(b, wTuck)
		end
		j.Transform = t
	end
end)

-- esprint: mantener Shift o L3; en móvil, el botón Run lo enciende y lo apaga. Pass: Shift sigue valiendo para el shift lock
-- (nombres únicos: el personaje viejo no suelta los del nuevo)
local BIND = "Movimiento" .. tostring({})
local SPRINT = "Sprint" .. BIND
local sprinting = false
CAS:BindAction(SPRINT, function(_, state, input)
	if input.UserInputType == Enum.UserInputType.Touch then
		if state == Enum.UserInputState.Begin then
			sprinting = not sprinting
		end
	else
		sprinting = state == Enum.UserInputState.Begin
	end
	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
CAS:SetTitle(SPRINT, "Run")

-- después de la cámara por defecto, para poder echarla atrás
RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, function(dt)
	if hum.WalkSpeed ~= mine then
		base = hum.WalkSpeed
	end
	local canRun = player:GetAttribute("Mode") ~= "visit" -- en las visitas se va despacio a propósito
	local walk = canRun and base * WALK or base
	local top = canRun and sprinting and base * SPEED or walk
	-- a esta altura del frame MoveDirection es la entrada del jugador: el motor la vuelve a poner cada frame
	local input = hum.MoveDirection
	local grounded = hum.FloorMaterial ~= Enum.Material.Air
	if input.Magnitude > 0.1 and base > 0 then
		if slide <= 0 and grounded then
			dust:Emit(5) -- arrancas de golpe: un soplo de polvo
		end
		dir = Vector3.new(input.X, 0, input.Z).Unit
		slide = SLIDE
		hum.WalkSpeed = top
	elseif slide > 0 then
		-- al soltar sigues un poco en la misma dirección mientras frenas (sin teclas, nuestro Move no se pisa)
		slide -= dt
		if slide > 0 and base > 0 then
			hum.WalkSpeed = top * (slide / SLIDE) ^ 2
			hum:Move(dir, false)
		else
			slide = 0
			hum.WalkSpeed = top
			hum:Move(Vector3.zero, false)
		end
	else
		hum.WalkSpeed = top
	end
	mine = hum.WalkSpeed -- leído de vuelta: WalkSpeed se guarda en float32

	-- giro suave hacia donde vas; con shift lock o en primera persona gira la cámara, como siempre
	align.Enabled = slide > 0 and UIS.MouseBehavior ~= Enum.MouseBehavior.LockCenter
	if align.Enabled then
		hum.AutoRotate = false
		align.CFrame = CFrame.lookAt(Vector3.zero, dir)
	end

	-- inclinación: hacia delante según lo que corres, de lado según lo rápido que giras
	local v = root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	fall = grounded and 0 or math.max(-v.Y, 0) -- lo usa el aterrizaje
	-- polvo al esprintar
	puff -= dt
	if grounded and speed > walk + 4 and puff <= 0 then
		dust:Emit(1)
		puff = 0.08
	end
	-- muelle del rebote
	local sdt = math.min(dt, 1 / 30)
	sqVel += (-SPRING * sq - DAMP * sqVel) * sdt
	sq += sqVel * sdt
	local run = canRun and math.clamp((speed - walk) / math.max(base * SPEED - walk, 1), 0, 1) or 0 -- 0 andando, 1 esprintando
	local look = root.CFrame.LookVector
	local turn = math.atan2(lastLook:Cross(look).Y, lastLook:Dot(look)) / math.max(dt, 1 / 240) -- rad/s, + = izquierda
	lastLook = look
	local k = 1 - math.exp(-7 * dt)
	lean += (run * LEAN - lean) * k
	bank += (math.clamp(turn * 0.12, -1, 1) * BANK * math.min(speed / 16, 1) - bank) * k
	local flip = 0
	if flipT then
		flipT += dt
		flip = math.pi * (1 - math.cos(math.pi * math.min(flipT / FLIP_TIME, 1))) -- una vuelta hacia delante, suave al empezar y al acabar
		if flipT >= FLIP_TIME then
			flipT = nil
		end
	end
	-- al caer el cuerpo baja y se dobla hacia delante; al saltar se estira un poco
	holder[prop] = CFrame.new(0, sq * 0.5, 0) * CFrame.Angles(-lean - flip + math.min(sq, 0) * 0.4, 0, bank) * rest

	setKick(kick + (run * FOV_KICK - kick) * k)
	-- la cámara se aleja algo más despacio que el resto, para que se note al arrancar a correr (no en primera persona)
	pull += (run * PULL - pull) * (1 - math.exp(-3 * dt))
	local cam = workspace.CurrentCamera
	if cam.CameraType == Enum.CameraType.Custom and (cam.CFrame.Position - cam.Focus.Position).Magnitude > 2 then
		cam.CFrame *= CFrame.new(0, sq * 0.5, pull) -- y la cámara acompaña el rebote
	end
end)

-- al morir o al quitar el personaje, el FOV vuelve a su sitio
local function stop()
	RunService:UnbindFromRenderStep(BIND)
	poseConn:Disconnect()
	CAS:UnbindAction(SPRINT)
	float.Enabled = false
	setKick(0)
end
hum.Died:Connect(stop)
script.Destroying:Connect(stop)
