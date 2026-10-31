-- Qué hace cada susto cuando salta. Cada función recibe el susto (s), la casa (h) y el visitante que lo activó (v).
-- Mientras se ejecuta, ese susto no vuelve a saltar. Para añadir uno nuevo: plantilla en Assets.Scares,
-- datos en Config.Scares y una función aquí con el mismo nombre.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Config = require(RS.Config)

local api -- lo rellena el script principal (addFear, endVisit, fx, visitsIn, alive, toRoomStart, sound)

local B = {}

function B.init(a)
	api = a
end

local V = Vector3.new
local V0 = Vector3.zero

local function flatDist(a, b)
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local function tween(obj, t, goal, style)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad), goal)
	tw:Play()
	return tw
end

local function setVisible(model, visible, hidden)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "Hitbox" and p.Name ~= "Root" and p.Name ~= "Solid" then
			p.Transparency = visible and (p:GetAttribute("T") or 0) or (hidden or 1)
		elseif p:IsA("ParticleEmitter") or p:IsA("Light") then
			p.Enabled = visible
		end
	end
end

-- como setVisible, pero fundiendo la transparencia en t segundos
local function fade(model, visible, t, hidden)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "Hitbox" and p.Name ~= "Root" and p.Name ~= "Solid" then
			tween(p, t, {Transparency = visible and (p:GetAttribute("T") or 0) or (hidden or 1)})
		elseif p:IsA("ParticleEmitter") or p:IsA("Light") then
			p.Enabled = visible
		end
	end
end

---------- Criaturas de bloques ----------
-- Cada criatura es un robloxiano (o un bicho) de bloques con articulaciones: formato y funciones en ReplicatedStorage.Rig
local Rig = require(RS.Rig)
local idlePose, full, setPose, play, jitter, EASE = Rig.idlePose, Rig.full, Rig.setPose, Rig.play, Rig.jitter, Rig.EASE

-- La criatura se queda en su sitio girándose (suave) hacia el visitante durante un tiempo, animada por poseAt(t).
-- onTouch(visita) decide qué pasa si alguien se le acerca demasiado; si devuelve true, se acaba.
local function hold(s, h, v, creature, duration, onTouch, poseAt)
	local home = creature:GetPivot()
	local t0 = os.clock()
	while os.clock() - t0 < duration and s.model.Parent and api.alive(v) do
		local target = v.root.Position
		local want = CFrame.lookAt(home.Position, Vector3.new(target.X, home.Position.Y, target.Z))
		creature:PivotTo(creature:GetPivot():Lerp(want, 0.18))
		if poseAt then
			setPose(creature, poseAt(os.clock() - t0))
		end
		for _, o in api.visitsIn(h) do
			if flatDist(o.root.Position, home.Position) < 3.2 and onTouch(o) then
				return home
			end
		end
		RunService.Heartbeat:Wait()
	end
	return home
end

-- Lo atrapa a medias: un susto fuerte (su miedo × 1.5, como mucho GRAB_MAX); solo se desmaya ("caught") si con eso
-- llega a 100. Ningún susto tumba a nadie de un toque: hay que asustarlo antes (con él o con otros)
local GRAB_MAX = 60
local function grab(o, s)
	local amount = math.min(s.def.fear * 1.5, GRAB_MAX)
	if o.fear + amount * (o.courage or 1) >= 100 then
		api.endVisit(o, "caught")
	else
		api.addFear(o, amount)
		api.fx(o, "scare", 1.4, Color3.fromRGB(200, 220, 255))
	end
	return true
end

---------- Básicos ----------
function B.Armario(s, h, v)
	local m = s.model
	local doors = {}
	for _, d in {m:FindFirstChild("DoorL"), m:FindFirstChild("DoorR")} do
		table.insert(doors, {part = d, closed = d.CFrame, side = d:GetAttribute("Side")})
	end
	local function swing(open, t)
		for _, d in doors do
			local hinge = d.side * d.part.Size.X / 2
			local goal = open and d.closed * CFrame.new(hinge, 0, 0) * CFrame.Angles(0, -d.side * math.rad(115), 0) * CFrame.new(-hinge, 0, 0) or d.closed
			tween(d.part, t, {CFrame = goal}, open and Enum.EasingStyle.Back or Enum.EasingStyle.Quad)
		end
	end
	local lurker = m:FindFirstChild("Lurker")
	local CROUCH = {Root = V(0, -0.5, 0.3), Torso = V(-38, 0, 0), Head = V(-22, 0, 0), ArmL = V(18, 0, -4), ArmR = V(18, 0, 4), LegL = V(40, 0, 0), LegR = V(34, 0, 0)}
	local LUNGE = {Root = V(0, 0, -0.6), Torso = V(-16, 0, 0), Head = V(8, 0, -20), ArmL = V(84, 10, -10), ArmR = V(80, -10, 10), LegL = V(18, 0, 0), LegR = V(-4, 0, 0)}
	api.sound("Slam", m.Hitbox)
	api.sound("Sting", m.Hitbox)
	swing(true, 0.18)
	if lurker then
		setPose(lurker, full(lurker, CROUCH))
		setVisible(lurker, true)
	end
	api.addFear(v, s.def.fear)
	api.fx(v, "scare", 1.2, Color3.new(1, 1, 1))
	if lurker then
		-- se abalanza fuera del armario con las garras por delante, abre y cierra las manos y le dan tirones a la cabeza
		play(lurker, {
			{0, CROUCH},
			{0.14, {Root = V(0, 0.1, -0.8), Torso = V(-8, 0, 0), Head = V(16, 0, -24), ArmL = V(112, 14, -20), ArmR = V(106, -14, 20), LegL = V(24, 0, 0), LegR = V(-8, 0, 0)}, "back"},
			{0.5, LUNGE},
			{1.9, LUNGE},
			{2.3, CROUCH, "in"},
		}, function(p, t)
			if t > 0.4 and t < 1.95 then
				p.ArmL += V(16 * math.sin(t * 17), 0, 0)
				p.ArmR += V(16 * math.sin(t * 17 + math.pi), 0, 0)
				jitter(p, t, 14, 3, {"Head"})
			end
		end)
	else
		task.wait(2.3)
	end
	swing(false, 0.9)
	if lurker then
		setVisible(lurker, false)
		setPose(lurker, idlePose(lurker))
	end
	task.wait(1.5)
end

function B.Luz(s, h, v)
	local bulb = s.model:FindFirstChild("Bulb", true)
	local light = bulb:FindFirstChildWhichIsA("Light")
	local function set(on)
		light.Enabled = on
		bulb.Material = on and Enum.Material.Neon or Enum.Material.Glass
		bulb.Color = on and Color3.fromRGB(255, 205, 130) or Color3.fromRGB(50, 45, 40)
	end
	api.sound("Flicker", bulb)
	api.addFear(v, s.def.fear)
	for _ = 1, 18 do
		set(not light.Enabled)
		task.wait(0.03 + math.random() * 0.11)
	end
	set(false) -- se queda a oscuras
	api.fx(v, "scare", 0.4, Color3.new(0, 0, 0))
	task.wait(6)
	set(true)
	task.wait(1)
end

function B.Gramofono(s, h, v)
	local body = s.model:FindFirstChild("Body")
	local music = body:FindFirstChild("MusicBox")
	local notes = body:FindFirstChildWhichIsA("ParticleEmitter")
	music.Volume = 1
	music.TimePosition = 0
	music:Play()
	if notes then
		notes.Enabled = true
	end
	api.fx(v, "scare", 0.3, Color3.fromRGB(120, 60, 160))
	-- cuanto más tiempo cerca, más miedo
	for _ = 1, 12 do
		for _, o in api.visitsIn(h) do
			if flatDist(o.root.Position, s.pos) < s.def.radius + 4 then
				api.addFear(o, s.def.fear / 8)
			end
		end
		task.wait(0.5)
	end
	if notes then
		notes.Enabled = false
	end
	tween(music, 1.5, {Volume = 0}).Completed:Wait()
	music:Stop()
	task.wait(3)
end

---------- Criaturas ----------
function B.Fantasma(s, h, v)
	local ghost = s.model.Creature
	local base = s.model:GetPivot()
	-- sube desde abajo, encogido, y abre los brazos de golpe: ¡BU!
	setPose(ghost, full(ghost, {Root = V(0, -1.6, 0.6)}))
	fade(ghost, true, 0.3)
	api.sound("Wail", ghost.Torso)
	api.sound("Whoosh", ghost.Torso)
	api.addFear(v, s.def.fear)
	api.fx(v, "scare", 0.8, Color3.fromRGB(200, 220, 255))
	play(ghost, {
		{0, {Root = V(0, -1.6, 0.6), Torso = V(-35, 0, 0), Head = V(-25, 0, 0), ArmL = V(-5, 0, -8), ArmR = V(-5, 0, 8), LegL = V(-50, 0, 0), LegR = V(-55, 0, 0)}},
		{0.28, {Root = V(0, 0.5, 0), Torso = V(14, 0, 0), Head = V(22, 0, 0), ArmL = V(170, 0, -35), ArmR = V(170, 0, 35), LegL = V(-8, 0, 6), LegR = V(-12, 0, -6)}, "back"},
		{0.55, {Root = V(0, 0.3, -0.5), Torso = V(-16, 0, 0), Head = V(-12, 0, 0), ArmL = V(100, 0, -14), ArmR = V(100, 0, 14)}, "out"},
		{0.85, {}},
	})
	-- flota en su sitio mirándote, ondulando brazos y estela; si alguien pasa pegado a él, le atraviesa con un susto
	-- enorme y se esfuma (solo se desmaya si ya iba muy asustado: grab)
	hold(s, h, v, ghost, 3.6, function(o)
		api.sound("Wail", ghost.Torso)
		return grab(o, s)
	end, function(t)
		local p = idlePose(ghost)
		p.Root = V(0, 0.25 * math.sin(t * 2.4), 0)
		p.Torso += V(4 * math.sin(t * 2.4 + 0.6), 0, 0)
		p.Head += V(0, 0, 9 * math.sin(t * 1.4))
		p.ArmL += V(12 * math.sin(t * 3.2), 0, 0)
		p.ArmR += V(12 * math.sin(t * 3.2 + 1.3), 0, 0)
		p.LegL += V(14 * math.sin(t * 2.6), 0, 0)
		p.LegR += V(14 * math.sin(t * 2.6 + 1), 0, 0)
		return p
	end)
	-- se esfuma girando hacia arriba
	fade(ghost, false, 0.4, 0.82)
	play(ghost, {
		{0, {}},
		{0.4, {Root = V(0, 2.2, 0), RootR = V(0, 200, 0), Torso = V(10, 0, 0), ArmL = V(160, 0, -20), ArmR = V(160, 0, 20), LegL = V(-60, 0, 0), LegR = V(-60, 0, 0)}, "in"},
	})
	ghost:PivotTo(base * CFrame.new(0, 4.2, 0))
	setPose(ghost, idlePose(ghost))
	setVisible(ghost, false, 0.82)
	task.wait(1)
end

function B.Muneca(s, h, v)
	local doll = s.model.Creature
	local home = doll:GetPivot()
	api.sound("Giggle", doll.Head)
	-- gira la cabeza a tirones (de 30 en 30 grados, tic, tic) para seguirte con la mirada; puede darle la vuelta entera
	local yaw, t0 = 0, os.clock()
	while os.clock() - t0 < 1.8 and api.alive(v) do
		local rel = home:PointToObjectSpace(v.root.Position)
		local want = math.round(math.deg(math.atan2(-rel.X, -rel.Z)) / 30) * 30
		want = yaw + ((want - yaw + 180) % 360 - 180)
		yaw += (want - yaw) * 0.35
		local p = idlePose(doll)
		p.Head = V(p.Head.X, yaw, p.Head.Z + 6 * math.sin((os.clock() - t0) * 3))
		setPose(doll, p)
		RunService.Heartbeat:Wait()
	end
	if api.alive(v) then
		-- ... y de golpe se gira, crece, abre los brazos y te grita temblando
		local target = v.root.Position
		doll:PivotTo(CFrame.lookAt(home.Position, Vector3.new(target.X, home.Position.Y, target.Z)))
		doll:ScaleTo(1.75)
		api.sound("DollScream", doll.Torso)
		api.addFear(v, s.def.fear)
		api.fx(v, "scare", 1.8, Color3.fromRGB(255, 40, 40))
		local shrunk = false
		play(doll, {
			{0, {Head = V(-4, 0, 12)}},
			{0.1, {Torso = V(12, 0, 0), Head = V(20, 0, 0), ArmL = V(150, 0, -40), ArmR = V(150, 0, 40), LegL = V(0, 0, -10), LegR = V(0, 0, 10)}, "back"},
			{0.9, {Torso = V(-14, 0, 0), Head = V(-10, 0, 0), ArmL = V(105, 0, -15), ArmR = V(105, 0, 15)}},
		}, function(p, t)
			if t > 0.12 and not shrunk then
				shrunk = true
				doll:ScaleTo(1.6)
			end
			jitter(p, t, 12, 1, {"Head", "ArmL", "ArmR"})
		end)
	end
	doll:ScaleTo(1)
	doll:PivotTo(home)
	setPose(doll, idlePose(doll))
	task.wait(2)
end

function B.Sombra(s, h, v)
	local shadow = s.model.Creature
	local home = shadow:GetPivot()
	local RISE = {Torso = V(-40, 0, 0), Head = V(-30, 0, 0), ArmL = V(175, 0, -20), ArmR = V(175, 0, 20)}
	-- sale del suelo encorvada, con las garras por delante...
	setPose(shadow, full(shadow, {Root = V(0, -7, 0)}))
	setVisible(shadow, true)
	api.sound("Growl", s.model.Hitbox)
	play(shadow, {{0, RISE}, {0.5, RISE}}, function(p, t)
		p.Root = V(0, -7 + 7 * EASE.out(t / 0.5), 0)
	end)
	-- ... y se yergue de golpe abriendo los brazos
	api.addFear(v, s.def.fear)
	api.fx(v, "scare", 0.6, Color3.fromRGB(40, 0, 60))
	play(shadow, {
		{0, RISE},
		{0.18, {Torso = V(10, 0, 0), Head = V(20, 0, -10), ArmL = V(70, 0, -75), ArmR = V(70, 0, 75)}, "back"},
		{0.5, {}},
	})
	-- se balancea mirándote, con tirones de cabeza; si te acercas, se abalanza
	hold(s, h, v, shadow, 5, function(o)
		play(shadow, {
			{0, {}},
			{0.12, {Root = V(0, 0, -1.2), Torso = V(-25, 0, 0), Head = V(-5, 0, 0), ArmL = V(110, 0, -10), ArmR = V(110, 0, 10)}, "out"},
			{0.45, {}},
		})
		api.addFear(o, 50)
		api.fx(o, "scare", 1.5, Color3.fromRGB(20, 0, 30))
		return true
	end, function(t)
		local p = idlePose(shadow)
		p.Torso += V(0, 0, 5 * math.sin(t * 1.3))
		p.Head += V(0, 0, 18 * math.sin(t * 0.8))
		p.ArmL += V(8 * math.sin(t * 2.1), 0, 0)
		p.ArmR += V(8 * math.sin(t * 2.1 + 2), 0, 0)
		if t % 1.7 < 0.18 then
			jitter(p, t * 4, 30, 9, {"Head"})
		end
		return p
	end)
	-- se hunde con los brazos arriba
	play(shadow, {
		{0, {}},
		{0.45, {Root = V(0, -7, 0), Torso = V(-30, 0, 0), Head = V(25, 0, 0), ArmL = V(170, 0, -15), ArmR = V(170, 0, 15)}, "in"},
	})
	setVisible(shadow, false)
	shadow:PivotTo(home)
	setPose(shadow, idlePose(shadow))
	task.wait(4)
end

---------- Trampas ----------
function B.Trampilla(s, h, v)
	local flaps = {}
	for _, name in {"FlapL", "FlapR"} do
		local f = s.model:FindFirstChild(name)
		table.insert(flaps, {part = f, closed = f.CFrame, side = f:GetAttribute("Side")})
	end
	for _, f in flaps do
		local hinge = f.side * f.part.Size.X / 2
		tween(f.part, 0.15, {CFrame = f.closed * CFrame.new(hinge, 0, 0) * CFrame.Angles(0, 0, f.side * math.rad(95)) * CFrame.new(-hinge, 0, 0)})
	end
	api.sound("WoodBreak", s.model.Hitbox)
	api.addFear(v, s.def.fear)
	api.fx(v, "fall")
	task.wait(0.4)
	if api.alive(v) then
		api.toRoomStart(v)
	end
	task.wait(3)
	for _, f in flaps do
		tween(f.part, 0.6, {CFrame = f.closed})
	end
	task.wait(1)
end

function B.Ataud(s, h, v)
	local m = s.model
	local lid = m:FindFirstChild("Lid")
	local skel = m:FindFirstChild("Creature")
	local closed = lid.CFrame
	local eyes = skel:FindFirstChildWhichIsA("Light", true)
	-- toc, toc... desde dentro
	for _ = 1, 2 do
		api.sound("Knock", m.Hitbox)
		task.wait(0.3)
	end
	task.wait(0.25)
	-- la tapa revienta y el esqueleto se lanza a por ti: se asoma, intenta agarrarte y le tiembla la calavera
	local hinge = lid:GetAttribute("Side") * lid.Size.X / 2
	tween(lid, 0.16, {CFrame = closed * CFrame.new(hinge, 0, 0) * CFrame.Angles(0, math.rad(105), 0) * CFrame.new(-hinge, 0, 0)}, Enum.EasingStyle.Back)
	api.sound("Slam", m.Hitbox)
	api.sound("Sting", m.Hitbox)
	if eyes then
		eyes.Enabled = true
	end
	api.addFear(v, s.def.fear)
	api.fx(v, "scare", 1.4, Color3.fromRGB(255, 240, 210))
	local OUT = {Root = V(0, 0.15, -0.5), RootR = V(-12, 0, 0), Torso = V(-10, 0, 0), Head = V(-8, 0, 10), ArmL = V(90, 6, -8), ArmR = V(90, -6, 8)}
	play(skel, {
		{0, {}},
		{0.14, {Root = V(0, 0.15, -0.5), RootR = V(-12, 0, 0), Torso = V(-14, 0, 0), Head = V(-18, 0, -14), ArmL = V(100, 10, -12), ArmR = V(100, -10, 12)}, "back"},
		{1.6, OUT},
		{1.95, {}},
	}, function(p, t)
		if t > 0.14 and t < 1.6 then
			p.ArmL += V(16 * math.sin(t * 15), 0, 0)
			p.ArmR += V(16 * math.sin(t * 15 + math.pi), 0, 0)
			jitter(p, t, 9, 7, {"Head"})
		end
	end)
	if eyes then
		eyes.Enabled = false
	end
	tween(lid, 0.8, {CFrame = closed})
	task.wait(2.5)
end

---------- Criatura del techo ----------
function B.Arana(s, h, v)
	local spider = s.model.Creature
	local thread = s.model:FindFirstChild("Thread")
	local home = spider:GetPivot() -- en reposo cuelga boca abajo del techo
	local ceilY = h.cf.Position.Y + h.roomH - 0.05
	local FLIP = CFrame.Angles(0, 0, math.pi)
	local function setThread(p)
		local top = Vector3.new(p.X, ceilY, p.Z)
		local len = math.max(0.1, ceilY - p.Y)
		thread.Size = Vector3.new(0.08, len, 0.08)
		thread.CFrame = CFrame.new(top - Vector3.new(0, len / 2, 0))
	end
	local function eye()
		return v.root.Position + Vector3.new(0, 1.5, 0)
	end
	api.sound("Whoosh", s.model.Hitbox)
	-- se deja caer colgando de su hilo, justo debajo de su telaraña, hasta la altura de tu cara
	if api.alive(v) then
		thread.Transparency = 0.25
		api.sound("Sting", s.model.Hitbox)
		api.sound("Growl", s.model.Hitbox)
		local top = home.Position
		local t0 = os.clock()
		local feared = false
		while os.clock() - t0 < 1.9 and api.alive(v) do
			local t = os.clock() - t0
			local fall = math.clamp(t / 0.22, 0, 1)
			local e = eye()
			local low = e.Y + 0.4 + math.sin(t * 9) * 0.25 * math.exp(-t * 2)
			local p = Vector3.new(top.X, top.Y + (low - top.Y) * fall, top.Z)
			-- mientras cae se da la vuelta: de boca abajo en el techo a mirarte a la cara
			local ceiling = (CFrame.lookAt(p, Vector3.new(e.X, p.Y, e.Z)) * FLIP).Rotation
			local face = CFrame.lookAt(p, e).Rotation
			spider:PivotTo(CFrame.new(p) * ceiling:Lerp(face, fall) * CFrame.Angles(0, 0, math.sin(t * 3) * 0.2))
			setThread(p)
			if fall >= 1 and not feared then
				feared = true
				api.addFear(v, s.def.fear)
				api.fx(v, "scare", 1.5, Color3.fromRGB(40, 60, 20))
			end
			RunService.Heartbeat:Wait()
		end
	end
	-- sube por el hilo y vuelve a su telaraña
	local at = spider:GetPivot()
	for i = 1, 10 do
		local cf = at:Lerp(home, i / 10)
		spider:PivotTo(cf)
		setThread(cf.Position)
		task.wait(0.03)
	end
	thread.Transparency = 1
	spider:PivotTo(home)
	task.wait(3)
end

---------- Legendario ----------
function B.Payaso(s, h, v)
	local clown = s.model.Creature
	local eyes = clown:FindFirstChildWhichIsA("Light", true)
	api.sound("Laugh", clown.Head)
	if eyes then
		eyes.Enabled = true
	end
	api.addFear(v, s.def.fear)
	api.fx(v, "scare", 1, Color3.fromRGB(255, 60, 60))
	-- se agacha y salta con los brazos abiertos: ¡tachán!
	play(clown, {
		{0, {}},
		{0.18, {Root = V(0, -0.5, 0), Torso = V(-22, 0, 0), Head = V(-10, 0, 0), LegL = V(35, 0, 0), LegR = V(35, 0, 0), ArmL = V(150, 0, -10), ArmR = V(10, 0, 10)}},
		{0.42, {Root = V(0, 1.8, 0), Torso = V(8, 0, 0), Head = V(14, 0, -12), ArmL = V(150, 0, -55), ArmR = V(90, 0, 85), LegL = V(-15, 0, -12), LegR = V(-15, 0, 12)}, "out"},
		{0.62, {Root = V(0, -0.35, 0), Torso = V(-12, 0, 0), ArmL = V(150, 0, -40), ArmR = V(60, 0, 70), LegL = V(25, 0, 0), LegR = V(25, 0, 0)}, "in"},
		{0.9, {}},
	})
	-- se queda mirándote y se parte de risa a ratos (con la mano en la tripa); si te chocas con él, te atrapa
	local BELLY = V(40, 0, -25)
	local home = hold(s, h, v, clown, 7, function(o)
		play(clown, {
			{0, {}},
			{0.15, {Torso = V(-20, 0, 0), Head = V(-10, 0, 0), ArmL = V(100, 0, -20), ArmR = V(100, 0, 20), Root = V(0, 0, -0.6)}, "out"},
		})
		grab(o, s)
		return true
	end, function(t)
		local p = idlePose(clown)
		local lw = math.clamp(math.sin(t * 2.4) * 2 + 0.6, 0, 1) -- cuánto se ríe ahora
		local b = lw * math.abs(math.sin(t * 13))
		p.Root = V(0, 0.18 * b, 0)
		p.Torso += V(10 * b, 0, 0)
		p.Head += V(18 * lw, 0, 12 * math.sin(t * 1.1))
		p.ArmR = p.ArmR:Lerp(BELLY, lw) + V(8 * b, 0, 0)
		p.ArmL += V(8 * math.sin(t * 1.7), 0, 0) -- el globo se balancea
		return p
	end)
	api.sound("Laugh", clown.Head)
	local poof = clown:FindFirstChild("Poof", true)
	if poof then
		poof:Emit(40)
	end
	task.wait(0.3)
	clown:PivotTo(home)
	setPose(clown, idlePose(clown))
	if eyes then
		eyes.Enabled = false
	end
	task.wait(5)
end

function B.Parca(s, h, v)
	local reaper = s.model.Creature
	local home = reaper:GetPivot()
	local skull = reaper:FindFirstChild("Head")
	-- cada vez que reaparece está en otra postura
	local POSES = {
		{Torso = V(6, 0, 0), Head = V(14, 0, 0), ArmR = V(175, 0, -10), ArmL = V(95, 0, 0)}, -- guadaña en alto y te señala
		{Root = V(0, 0.3, -0.6), Torso = V(-22, 0, 0), Head = V(-10, 0, 18), ArmL = V(80, 0, -60), ArmR = V(70, 0, 55)}, -- se inclina hacia ti
		{Torso = V(-6, 35, 0), Head = V(0, -25, 0), ArmR = V(140, 40, 40), ArmL = V(60, 0, -20)}, -- prepara el tajo
	}
	api.sound("Wail", s.model.Hitbox)
	api.addFear(v, s.def.fear)
	api.fx(v, "scare", 0.7, Color3.fromRGB(20, 0, 10))
	-- se esfuma y reaparece en su sitio, una y otra vez
	for i = 1, 3 do
		task.wait(0.75)
		if not api.alive(v) then
			break
		end
		setVisible(reaper, false)
		api.sound("Whoosh", s.model.Hitbox)
		task.wait(0.35)
		if not api.alive(v) then
			break
		end
		setPose(reaper, full(reaper, POSES[i]))
		setVisible(reaper, true)
		api.sound("Sting", skull)
		api.addFear(v, 12)
		api.fx(v, "scare", 0.8 + i * 0.4, Color3.fromRGB(40, 0, 0))
	end
	-- ...y te espera flotando y llamándote con el dedo: si te acercas, tajo con la guadaña y se acabó
	if api.alive(v) then
		api.sound("Deep", skull)
		hold(s, h, v, reaper, 4.5, function(o)
			play(reaper, {
				{0, POSES[3]},
				{0.18, {Torso = V(-14, -30, 0), Head = V(-10, 10, 0), ArmR = V(40, -50, -20), ArmL = V(40, 0, -30)}, "out"},
				{0.4, {Torso = V(-14, -30, 0), Head = V(-10, 10, 0), ArmR = V(40, -50, -20), ArmL = V(40, 0, -30)}},
			})
			grab(o, s)
			return true
		end, function(t)
			local p = full(reaper, POSES[3])
			p.Root += V(0, 0.15 * math.sin(t * 1.8), 0)
			p.ArmL = V(85 + 14 * math.sin(t * 5), 0, -10)
			p.Head += V(0, 0, 8 * math.sin(t * 0.9))
			return p
		end)
	end
	setVisible(reaper, false)
	task.wait(0.4)
	reaper:PivotTo(home)
	setPose(reaper, idlePose(reaper))
	setVisible(reaper, true)
	task.wait(6)
end

-- Está de pie en su sitio, encorvado y con los brazos por delante. Al saltar, da un tirón de cabeza, ruge con los
-- brazos en alto y se queda en su sitio siguiéndote con la mirada. Si alguien se le acerca, le muerde y se acabó.
function B.Zombie(s, h, v)
	local m = s.model
	local zombie = m.Creature
	local home = zombie:GetPivot()
	-- 1) se despierta: tirones de cabeza mientras se gira hacia ti...
	api.sound("ZombieGroan3", zombie.Head)
	local t0 = os.clock()
	while os.clock() - t0 < 0.5 and api.alive(v) do
		local target = v.root.Position
		local want = CFrame.lookAt(home.Position, Vector3.new(target.X, home.Position.Y, target.Z))
		zombie:PivotTo(zombie:GetPivot():Lerp(want, 0.2))
		local p = idlePose(zombie)
		jitter(p, os.clock() - t0, 22, 4, {"Head"})
		setPose(zombie, p)
		RunService.Heartbeat:Wait()
	end
	-- 2) ...y ruge con los brazos en alto: ¡GRAAAH!
	api.sound("ZombieGroan", zombie.Head)
	api.sound("Sting", m.Hitbox)
	api.addFear(v, s.def.fear)
	api.fx(v, "scare", 1.3, Color3.fromRGB(120, 255, 60))
	play(zombie, {
		{0, {}},
		{0.16, {Root = V(0, 0.2, 0), Torso = V(12, 0, 0), Head = V(26, 0, 12), ArmL = V(150, 0, -34), ArmR = V(150, 0, 34), LegL = V(6, 0, -6), LegR = V(-6, 0, 6)}, "back"},
		{0.85, {Root = V(0, 0.2, 0), Torso = V(8, 0, 0), Head = V(20, 0, -10), ArmL = V(140, 0, -28), ArmR = V(140, 0, 28), LegL = V(6, 0, -6), LegR = V(-6, 0, 6)}},
		{1.15, {Torso = V(-16, 0, 0), Head = V(-6, 0, 10), ArmL = V(95, 0, -6), ArmR = V(90, 0, 8)}, "out"},
	}, function(p, t)
		if t > 0.12 and t < 0.9 then
			jitter(p, t, 14, 4, {"Head", "ArmL", "ArmR"})
		end
	end)
	-- 3) se queda en su sitio gruñendo y girándose hacia ti; si te acercas, te muerde
	local pos = home.Position
	local t0 = os.clock()
	local groan = t0 + 1.5
	while os.clock() - t0 < 3 and m.Parent and api.alive(v) do
		RunService.Heartbeat:Wait()
		local t = os.clock() - t0
		local target = v.root.Position
		local dir = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
		local look = dir.Magnitude > 0.1 and dir.Unit or home.LookVector
		local rot = zombie:GetPivot().Rotation:Lerp(CFrame.lookAt(Vector3.zero, look).Rotation, 0.12)
		zombie:PivotTo(CFrame.new(pos) * rot)
		local p = idlePose(zombie)
		jitter(p, t, 8, 3, {"Head", "ArmL", "ArmR"})
		setPose(zombie, p)
		if os.clock() > groan then
			groan = os.clock() + 1.8 + math.random()
			api.sound(math.random() < 0.5 and "ZombieGroan2" or "ZombieGroan3", zombie.Head)
		end
		local bitten
		for _, o in api.visitsIn(h) do
			if flatDist(o.root.Position, pos) < 3 then
				bitten = o
				break
			end
		end
		if bitten then
			api.sound("ZombieGroan", zombie.Head)
			play(zombie, {
				{0, {}},
				{0.14, {Root = V(0, 0, -0.9), Torso = V(-30, 0, 0), Head = V(-14, 0, 0), ArmL = V(115, 0, -6), ArmR = V(115, 0, 6)}, "out"},
				{0.45, {Root = V(0, 0, -0.9), Torso = V(-30, 0, 0), Head = V(-24, 0, 8), ArmL = V(100, 0, 4), ArmR = V(100, 0, -4)}},
			})
			grab(bitten, s)
			break
		end
	end
	-- 4) se gira a su postura de antes
	local from = zombie:GetPivot()
	for i = 1, 15 do
		zombie:PivotTo(from:Lerp(home, i / 15))
		setPose(zombie, idlePose(zombie))
		task.wait(0.03)
	end
	zombie:PivotTo(home)
	setPose(zombie, idlePose(zombie))
	task.wait(3)
end

---------- Sustos nuevos: criaturas de bloques que se quedan en su sitio ----------
-- (solo giran hacia ti y mueven sus articulaciones; lo que vuela son los murciélagos, las almas y los proyectiles)

-- Al colocar un susto en una casa: guarda cómo están sus luces y, si hace falta, lo deja en su estado de reposo
-- (las manos, hundidas en la tierra). Lo llama Juego (spawnScare).
B.setup = {}
function B.prepare(m, t)
	for _, l in m:GetDescendants() do
		if l:IsA("Light") then
			l:SetAttribute("B0", l.Brightness)
			l:SetAttribute("R0", l.Range)
			l:SetAttribute("C0", l.Color)
			l:SetAttribute("E0", l.Enabled)
		end
	end
	if B.setup[t] then
		B.setup[t](m)
	end
end

local function rigOf(s, name)
	return s.model:FindFirstChild(name or "Creature")
end

local function find(s, name)
	return s.model:FindFirstChild(name, true)
end

local function emit(s, anchorName, emitterName, n)
	local a = find(s, anchorName)
	local e = a and a:FindFirstChild(emitterName)
	if e then
		e:Emit(n or 20)
	end
end

local function lightIn(s, anchorName)
	local a = find(s, anchorName)
	return a and a:FindFirstChildWhichIsA("Light"), a
end

-- La luz sube de golpe (flare) y luego vuelve a como estaba al colocarlo (unflare). Los valores de cada susto se
-- escribieron con luces más fuertes: se atenúan aquí igual que las luces de las plantillas (Assets.Scares), para que
-- las piezas cercanas a la luz (sin sombras) no se quemen en blanco dentro de las casas. Con tope: la luz suele ir
-- dentro del propio susto (la cara de la calabaza, los ojos) y por encima de FLARE_MAX lo quema entero (y a las skins
-- claras, como la helada, las deja blancas); lo que se ve brillar es la cara o los ojos en neón, no la luz.
local FLARE_DIM, FLARE_RANGE, FLARE_MAX = 0.3, 0.7, 1.5
local function flare(l, bright, range, time, color)
	if not l then
		return
	end
	l.Enabled = true
	if color then
		l.Color = color
	end
	tween(l, time or 0.15, {Brightness = math.min(bright * FLARE_DIM, FLARE_MAX), Range = range * FLARE_RANGE})
end

local function unflare(l, time)
	if not (l and l:GetAttribute("B0")) then
		return
	end
	tween(l, time or 0.6, {Brightness = l:GetAttribute("B0"), Range = l:GetAttribute("R0"), Color = l:GetAttribute("C0")})
	if not l:GetAttribute("E0") then
		task.delay(time or 0.6, function()
			l.Enabled = false
		end)
	end
end

-- Un sonido en un punto fijo (para lo que desaparece enseguida)
local function soundAt(name, pos)
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = workspace.Terrain
	api.sound(name, a)
	task.delay(6, a.Destroy, a)
end

-- Esfera de luz que crece y se apaga (estallidos, ondas)
local function wave(pos, color, size, time, from)
	local w = Instance.new("Part")
	w.Shape = Enum.PartType.Ball
	w.Material = Enum.Material.Neon
	w.Color = color
	w.Transparency = from or 0.45
	w.Anchored, w.CanCollide, w.CanQuery, w.CanTouch, w.CastShadow = true, false, false, false, false
	w.Size = Vector3.one
	w.CFrame = CFrame.new(pos)
	w.Parent = workspace
	tween(w, time or 0.6, {Size = Vector3.one * size, Transparency = 1})
	task.delay((time or 0.6) + 0.05, w.Destroy, w)
end

-- Gira la criatura hacia el visitante sin moverla de su sitio (como mucho maxYaw grados desde donde mira)
local function aim(c, home, v, alpha, maxYaw)
	if not (c and c.Parent and api.alive(v)) then
		return
	end
	local p = home.Position
	local t = v.root.Position
	if Vector2.new(t.X - p.X, t.Z - p.Z).Magnitude < 0.1 then
		return
	end
	local want = CFrame.lookAt(p, Vector3.new(t.X, p.Y, t.Z))
	if maxYaw then
		local _, yaw = home:ToObjectSpace(want):ToOrientation()
		want = home * CFrame.Angles(0, math.clamp(yaw, -math.rad(maxYaw), math.rad(maxYaw)), 0)
	end
	c:PivotTo(c:GetPivot():Lerp(want, alpha or 0.2))
end

-- Durante dur segundos se gira hacia el visitante y se anima con poseAt(t); si alguien se acerca a menos de reach del
-- susto, onTouch(visita) y se acaba. Devuelve a quién ha atrapado.
local function stalk(s, h, v, c, home, dur, reach, onTouch, poseAt, maxYaw)
	local t0 = os.clock()
	while os.clock() - t0 < dur and s.model.Parent do
		aim(c, home, v, 0.12, maxYaw)
		if poseAt then
			setPose(c, poseAt(os.clock() - t0))
		end
		if onTouch then
			for _, o in api.visitsIn(h) do
				if flatDist(o.root.Position, s.pos) < reach then
					onTouch(o)
					return o
				end
			end
		end
		RunService.Heartbeat:Wait()
	end
	return nil
end

-- Lo sujeta en su sitio unos segundos (manos del suelo, vendas)
local function pin(v, time)
	if not api.alive(v) then
		return
	end
	if v.bot then
		v.root.Anchored = true
		task.delay(time, function()
			if v.root.Parent and api.alive(v) then
				v.root.Anchored = false
			end
		end)
	elseif v.hum then
		local speed = v.hum.WalkSpeed
		v.hum.WalkSpeed = 0
		task.delay(time, function()
			if v.hum.Parent and api.alive(v) then
				v.hum.WalkSpeed = speed > 0 and speed or Config.VISIT_SPEED
			end
		end)
	end
end

-- Piezas de un grupo (atributo Group: la calabaza del cazo, la de la mano del jinete)
local function group(s, name)
	local list = {}
	for _, p in s.model:GetDescendants() do
		if p:IsA("BasePart") and p:GetAttribute("Group") == name then
			table.insert(list, p)
		end
	end
	return list
end

local function showParts(list, on, time)
	for _, p in list do
		local goal = on and (p:GetAttribute("T") or 0) or 1
		if time then
			tween(p, time, {Transparency = goal})
		else
			p.Transparency = goal
		end
		for _, d in p:GetChildren() do
			if d:IsA("Light") then
				d.Enabled = on
			end
		end
	end
end

-- Muestra u oculta (fundiendo) una criatura que está escondida hasta el susto (todas sus piezas llevan T)
local function reveal(model, on, time)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p:GetAttribute("T") then
			local goal = on and p:GetAttribute("T") or 1
			if time and time > 0 then
				tween(p, time, {Transparency = goal})
			else
				p.Transparency = goal
			end
		end
	end
end

-- Lanza algo en parábola hasta el visitante y revienta: una copia de 'parts' (la calabaza, el frasco) o una bola
local function hurl(s, v, from, color, size, parts, time)
	local proj = Instance.new("Model")
	local main
	if parts and #parts > 0 then
		local center = Vector3.zero
		for _, p in parts do
			center += p.Position
		end
		center /= #parts
		local base = CFrame.new(center)
		for _, p in parts do
			local c = p:Clone()
			for _, d in c:GetChildren() do
				d:Destroy()
			end
			c.Transparency = p:GetAttribute("T") or 0
			c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch = true, false, false, false
			c.CFrame = CFrame.new(from) * base:ToObjectSpace(p.CFrame)
			c.Parent = proj
			if not main or c.Size.Magnitude > main.Size.Magnitude then
				main = c
			end
		end
	else
		main = Instance.new("Part")
		main.Shape = Enum.PartType.Ball
		main.Size = Vector3.one * (size or 1.4)
		main.Color = color
		main.Material = Enum.Material.Neon
		main.Anchored, main.CanCollide, main.CanQuery, main.CanTouch = true, false, false, false
		main.CFrame = CFrame.new(from)
		main.Parent = proj
	end
	proj.PrimaryPart = main
	local f = Instance.new("Fire")
	f.Size, f.Heat, f.Color, f.SecondaryColor = 4, 9, color, Color3.fromRGB(255, 240, 160)
	f.Parent = main
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = color, 10, 1
	l.Parent = main
	proj.Parent = workspace
	local to = api.alive(v) and v.root.Position + V(0, 1.5, 0) or from + V(0, -2, -6)
	local t0, dur = os.clock(), time or 0.6
	local peak = math.max(3, (to - from).Magnitude * 0.3)
	while os.clock() - t0 < dur do
		local k = (os.clock() - t0) / dur
		if api.alive(v) then
			to = v.root.Position + V(0, 1.5, 0)
		end
		proj:PivotTo(CFrame.new(from:Lerp(to, k) + V(0, peak * 4 * k * (1 - k), 0)) * CFrame.Angles(k * 7, k * 5, 0))
		RunService.Heartbeat:Wait()
	end
	soundAt("Boom", to)
	wave(to, color, 8, 0.3, 0.2)
	proj:Destroy()
end

-- Venda (o látigo) que sale de 'from' hasta el visitante, lo sujeta un momento y se recoge
local function lash(v, from, color, holdTime)
	if not api.alive(v) then
		return
	end
	local p = Instance.new("Part")
	p.Material = Enum.Material.Fabric
	p.Color = color
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Size = Vector3.new(0.4, 0.07, 0.1)
	p.Parent = workspace
	local function stretch(k)
		local to = (v.root.Parent and v.root.Position or from) + V(0, 0.4, 0)
		local tip = from:Lerp(to, k)
		local len = math.max(0.1, (tip - from).Magnitude)
		p.Size = Vector3.new(0.4, 0.07, len)
		p.CFrame = CFrame.lookAt(from, tip) * CFrame.new(0, 0, -len / 2)
	end
	local t0 = os.clock()
	while os.clock() - t0 < 0.16 do
		stretch((os.clock() - t0) / 0.16)
		RunService.Heartbeat:Wait()
	end
	t0 = os.clock()
	while os.clock() - t0 < (holdTime or 1) do
		stretch(1)
		RunService.Heartbeat:Wait()
	end
	t0 = os.clock()
	while os.clock() - t0 < 0.2 do
		stretch(1 - (os.clock() - t0) / 0.2)
		RunService.Heartbeat:Wait()
	end
	p:Destroy()
end

---------- Básicos nuevos ----------
function B.Velas(s, h, v)
	local m = s.model
	local spirit = rigOf(s, "Spirit")
	local glow = lightIn(s, "Flames")
	local sl = lightIn(s, "SpiritGlow")
	local flames, wicks = {}, {}
	for _, p in m:GetChildren() do
		if p.Name == "Flame" then
			table.insert(flames, {part = p, size = p.Size, color = p.Color})
		elseif p.Name == "Wick" then
			table.insert(wicks, p)
		end
	end
	local home = spirit:GetPivot()
	-- 1) las llamas titilan como si soplara una corriente
	api.sound("Flicker", m.Hitbox)
	for k = 1, 8 do
		for _, f in flames do
			f.part.Color = k % 2 == 0 and Color3.fromRGB(120, 60, 20) or f.color
		end
		if glow then
			glow.Brightness = k % 2 == 0 and 0.4 or (glow:GetAttribute("B0") or 2)
		end
		task.wait(0.06)
	end
	-- 2) se vuelven verdes y crecen rugiendo
	for _, f in flames do
		f.part.Color = Color3.fromRGB(120, 255, 140)
		tween(f.part, 0.25, {Size = f.size * Vector3.new(1.6, 2.8, 1.6)}, Enum.EasingStyle.Back)
	end
	for _, w in wicks do
		w.Fire.Enabled = false
		w.CurseFire.Enabled = true
	end
	flare(glow, 6, 22, 0.25, Color3.fromRGB(110, 255, 130))
	api.sound("Whoosh", m.Hitbox)
	task.wait(0.25)
	-- 3) de la llama del centro sale una calavera de humo verde que grita castanyeteando los dientes
	local LOW = {Root = V(0, -2.4, 0), Head = V(30, 0, 0), ArmL = V(-20, 0, -10), ArmR = V(-20, 0, 10)}
	setPose(spirit, full(spirit, LOW))
	reveal(spirit, true, 0.3)
	flare(sl, 3, 16, 0.3)
	api.sound("Wail", m.Hitbox)
	api.sound("Sting", m.Hitbox)
	local feared = false
	play(spirit, {
		{0, LOW},
		{0.35, {Root = V(0, 0.5, 0), Head = V(-20, 0, 0), Jaw = V(-45, 0, 0), ArmL = V(60, 0, -60), ArmR = V(60, 0, 60), Wisp = V(30, 0, 0)}, "back"},
		{1.7, {Root = V(0, 0.3, 0), Head = V(-10, 0, 0), Jaw = V(-40, 0, 0), ArmL = V(90, 0, -30), ArmR = V(90, 0, 30), Wisp = V(-10, 0, 0)}},
	}, function(p, t)
		aim(spirit, home, v, 0.2)
		if t > 0.3 then
			if not feared then
				feared = true
				api.addFear(v, s.def.fear)
				api.fx(v, "scare", 1.3, Color3.fromRGB(110, 255, 140))
				emit(s, "SpiritGlow", "Wail", 30)
			end
			p.Jaw += V(18 * math.sin(t * 40), 0, 0)
			jitter(p, t, 10, 2, {"Head", "ArmL", "ArmR"})
			p.ArmL += V(20 * math.sin(t * 14), 0, 0)
			p.ArmR += V(20 * math.sin(t * 14 + 2), 0, 0)
		end
		p.Wisp += V(0, 0, 14 * math.sin(t * 6))
	end)
	-- 4) se mete otra vez en la vela y las llamas vuelven a ser naranjas
	reveal(spirit, false, 0.4)
	unflare(sl, 0.4)
	Rig.blend(spirit, LOW, 0.45, "in", home)
	setPose(spirit, idlePose(spirit))
	for _, f in flames do
		f.part.Color = f.color
		tween(f.part, 0.5, {Size = f.size})
	end
	for _, w in wicks do
		w.Fire.Enabled = true
		w.CurseFire.Enabled = false
	end
	unflare(glow, 1)
	task.wait(2.5)
end

-- Murciélagos que vuelan en espiral alrededor de 'face' (o vuelven a 'home'): e = 0 en casa, 1 en el enjambre
local function swarm(bats, face, t, e, radius, folded)
	for i, b in bats do
		local a = t * 5.5 + i * 1.3 + b.phase
		local r = radius + (b.r or 0)
		local orbit = face + V(math.cos(a) * r, (b.h or 0) + math.sin(t * 7 + i) * 0.5, math.sin(a) * r)
		local ahead = face + V(math.cos(a + 0.35) * r, b.h or 0, math.sin(a + 0.35) * r)
		local pos = b.home.Position:Lerp(orbit, e)
		local fly = CFrame.lookAt(pos, b.home.Position:Lerp(ahead, e) + V(0, 0.001, 0))
		b.rig:PivotTo(CFrame.new(pos) * b.home.Rotation:Lerp(fly.Rotation, math.min(1, e * 1.5)))
		local flap = math.sin(t * 32 + b.phase) * 55
		local wing = flap * math.min(1, e * 2) + folded * (1 - math.min(1, e * 2))
		setPose(b.rig, {Head = V(0, 0, 0), WingL = V(0, 0, wing), WingR = V(0, 0, -wing)})
	end
end

function B.Murcielagos(s, h, v)
	local m = s.model
	local bats = {}
	for _, b in m:GetChildren() do
		if b.Name == "Bat" and b:IsA("Model") then
			table.insert(bats, {rig = b, home = b:GetPivot(), phase = math.random() * 6, r = math.random() * 1.2, h = math.random() * 1.6 - 0.4})
		end
	end
	local moon = lightIn(s, "Moon")
	-- 1) despiertan: tiemblan colgados y se les encienden los ojos
	api.sound("Swoosh", m.Hitbox)
	flare(moon, 3, 14, 0.2, Color3.fromRGB(255, 80, 120))
	local t0 = os.clock()
	while os.clock() - t0 < 0.5 do
		for _, b in bats do
			local p = idlePose(b.rig)
			jitter(p, os.clock() - t0 + b.phase, 25, 3, {"WingL", "WingR", "Head"})
			setPose(b.rig, p)
		end
		RunService.Heartbeat:Wait()
	end
	-- 2) se sueltan y vuelan en enjambre alrededor de tu cara chillando; luego vuelven al perchero
	emit(s, "Swarm", "Screech", 25)
	api.sound("Giggle", m.Hitbox)
	api.sound("Whoosh", m.Hitbox)
	local feared = false
	t0 = os.clock()
	local dur = 2.6
	while os.clock() - t0 < dur and m.Parent do
		local t = os.clock() - t0
		local face = api.alive(v) and (v.root.Position + V(0, 1.6, 0)) or (s.pos + V(0, 4, 0))
		local e = EASE.out(math.clamp(t / 0.5, 0, 1)) * (1 - EASE["in"](math.clamp((t - dur + 0.6) / 0.6, 0, 1)))
		swarm(bats, face, t, e, 1.6, 88)
		if t > 0.5 and not feared then
			feared = true
			api.addFear(v, s.def.fear)
			api.fx(v, "scare", 1.1, Color3.fromRGB(70, 30, 90))
			api.sound("Swoosh", m.Hitbox)
		end
		RunService.Heartbeat:Wait()
	end
	for _, b in bats do
		b.rig:PivotTo(b.home)
		setPose(b.rig, idlePose(b.rig))
	end
	unflare(moon, 0.8)
	task.wait(3)
end

function B.Cuervo(s, h, v)
	local c = rigOf(s)
	local home = c:GetPivot()
	local eyes = lightIn(s, "Eyes")
	-- 1) te sigue con la mirada a tirones
	api.sound("Sting", s.model.Hitbox)
	flare(eyes, 4, 12, 0.2)
	local t0 = os.clock()
	local yaw = 0
	while os.clock() - t0 < 0.9 and api.alive(v) do
		local rel = home:PointToObjectSpace(v.root.Position)
		local want = math.clamp(math.round(math.deg(math.atan2(-rel.X, -rel.Z)) / 20) * 20, -80, 80)
		yaw += (want - yaw) * 0.4
		local p = idlePose(c)
		p.Head = V(p.Head.X, yaw, 6 * math.sin((os.clock() - t0) * 9))
		setPose(c, p)
		RunService.Heartbeat:Wait()
	end
	-- 2) abre las alas de golpe, grazna y picotea hacia ti batiendo las alas (sin moverse del tocón)
	emit(s, "Feathers", "Feathers", 30)
	api.sound("Swoosh", s.model.Hitbox)
	api.sound("Scream2", s.model.Hitbox)
	api.addFear(v, s.def.fear)
	api.fx(v, "scare", 1.2, Color3.fromRGB(60, 10, 20))
	local OPEN = {Body = V(-26, yaw * 0.5, 0), Head = V(-10, yaw * 0.5, 0), Beak = V(-40, 0, 0), WingL = V(0, -20, -110), WingR = V(0, 20, 110), Tail = V(-30, 0, 0)}
	play(c, {
		{0, {Head = V(0, yaw, 0)}},
		{0.14, OPEN, "back"},
		{1.6, OPEN},
	}, function(p, t)
		if t > 0.14 then
			local f = math.sin(t * 26)
			p.WingL += V(0, 0, 35 * f)
			p.WingR -= V(0, 0, 35 * f)
			local peck = math.max(0, math.sin(t * 9)) ^ 3
			p.Head += V(-35 * peck, 0, 0)
			p.Body += V(-10 * peck, 0, 0)
			p.Beak = V(-40 + 30 * math.abs(math.sin(t * 18)), 0, 0)
		end
	end)
	Rig.blend(c, {}, 0.5)
	unflare(eyes, 0.6)
	task.wait(2.5)
end

function B.Calabaza(s, h, v)
	local c = rigOf(s)
	local ammo = group(s, "Ammo")
	local pk = lightIn(s, "Pumpkin")
	-- 1) tensa el brazo: cruje y tiembla
	api.sound("Creak", s.model.Hitbox)
	flare(pk, 4, 14, 0.4)
	play(c, {{0, {}}, {0.55, {Arm = V(46, 0, 0)}}}, function(p, t)
		p.Arm += V(math.sin(t * 50) * 2, 0, 0)
	end)
	if api.alive(v) then
		-- 2) ¡zas! el brazo choca contra el tope y la calabaza sale volando riendo hacia ti
		api.sound("Slam", s.model.Hitbox)
		api.sound("Laugh", s.model.Hitbox)
		play(c, {{0, {Arm = V(46, 0, 0)}}, {0.13, {Arm = V(-100, 0, 0)}, "in"}})
		local from = ammo[1] and ammo[1].Position or (s.pos + V(0, 5, 0))
		showParts(ammo, false)
		emit(s, "Pumpkin", "Launch", 25)
		task.spawn(hurl, s, v, from, Color3.fromRGB(255, 140, 30), 1.6, ammo, 0.6)
		play(c, {{0, {Arm = V(-100, 0, 0)}}, {0.35, {Arm = V(-78, 0, 0)}, "back"}})
		task.wait(0.25)
		api.addFear(v, s.def.fear)
		api.fx(v, "scare", 1.3, Color3.fromRGB(255, 140, 30))
	end
	-- 3) vuelve a armarse despacio y aparece otra calabaza en el cazo
	Rig.blend(c, {}, 1.0, "out")
	showParts(ammo, true, 0.3)
	emit(s, "Pumpkin", "Launch", 10)
	unflare(pk, 0.5)
	task.wait(2.5)
end

---------- Criaturas nuevas ----------
function B.Espantapajaros(s, h, v)
	local c = rigOf(s)
	local home = c:GetPivot()
	local eyeLight = c:FindFirstChild("EyeLight", true)
	local eyes = {}
	for _, p in c:GetChildren() do
		if p.Name == "Eye" then
			table.insert(eyes, {part = p, color = p.Color, mat = p.Material})
		end
	end
	-- 1) la cabeza gira hacia ti a tirones (cric, cric) mientras el cuervo grazna
	api.sound("Creak", s.model.Hitbox)
	local t0 = os.clock()
	local yaw, tick = 0, 0
	while os.clock() - t0 < 1.1 and api.alive(v) do
		local t = os.clock() - t0
		local rel = home:PointToObjectSpace(v.root.Position)
		local want = math.clamp(math.deg(math.atan2(-rel.X, -rel.Z)), -70, 70)
		if t > tick then
			tick = t + 0.22
			yaw += (want - yaw) * 0.5
		end
		local p = idlePose(c)
		p.Head = V(p.Head.X, yaw, p.Head.Z * (1 - t))
		p.CrowHead = V(0, 30 * math.sin(t * 12), 0)
		p.CrowBeak = V(-30 * math.abs(math.sin(t * 10)), 0, 0)
		setPose(c, p)
		RunService.Heartbeat:Wait()
	end
	-- 2) le arden los ojos y se arranca del poste agitando los brazos
	for _, e in eyes do
		e.part.Material = Enum.Material.Neon
		e.part.Color = Color3.fromRGB(255, 140, 30)
	end
	flare(eyeLight, 6, 14, 0.15)
	emit(s, "Eyes", "Embers", 30)
	emit(s, "Straw", "StrawBurst", 40)
	api.sound("Growl", s.model.Hitbox)
	api.sound("Sting", s.model.Hitbox)
	api.addFear(v, s.def.fear)
	api.fx(v, "scare", 1.3, Color3.fromRGB(255, 120, 30))
	local LUNGE = {Torso = V(-26, yaw * 0.4, 0), Head = V(10, yaw * 0.6, -16), ArmL = V(120, 10, -30), ArmR = V(110, -10, 30), LegL = V(30, 0, -10), LegR = V(-20, 0, 10),
		CrowWingL = V(0, 0, -100), CrowWingR = V(0, 0, 100), CrowBeak = V(-35, 0, 0)}
	play(c, {
		{0, {Head = V(-4, yaw, 0)}},
		{0.16, LUNGE, "back"},
		{1.7, LUNGE},
	}, function(p, t)
		if t > 0.16 then
			p.ArmL += V(30 * math.sin(t * 16), 0, 0)
			p.ArmR += V(30 * math.sin(t * 16 + math.pi), 0, 0)
			p.LegL += V(20 * math.sin(t * 12), 0, 0)
			p.LegR += V(20 * math.sin(t * 12 + 2), 0, 0)
			jitter(p, t, 14, 5, {"Head", "Torso"})
			local f = math.sin(t * 30)
			p.CrowWingL += V(0, 0, 40 * f)
			p.CrowWingR -= V(0, 0, 40 * f)
		end
	end)
	-- 3) vuelve a quedarse colgado, como si nada
	Rig.blend(c, {}, 0.8, "out")
	for _, e in eyes do
		e.part.Material = e.mat
		e.part.Color = e.color
	end
	unflare(eyeLight, 0.8)
	task.wait(3)
end

function B.Momia(s, h, v)
	local c = rigOf(s)
	local home = c:GetPivot()
	local eye = lightIn(s, "Eye")
	-- 1) se despierta: el ojo se enciende, tirón de cabeza y alza los brazos soltando polvo
	api.sound("ZombieGroan2", s.model.Hitbox)
	flare(eye, 5, 14, 0.2)
	emit(s, "Dust", "DustBurst", 25)
	api.sound("Sting", s.model.Hitbox)
	local REACH = {Torso = V(-16, 0, 0), Head = V(-8, 0, 6), ArmL = V(100, 8, -10), ArmR = V(96, -8, 10), LegL = V(14, 0, 0), LegR = V(-10, 0, 0)}
	play(c, {
		{0, {}},
		{0.12, {Head = V(-24, 0, 18), Torso = V(-4, 0, 0)}, "out"},
		{0.42, REACH, "back"},
	}, function()
		aim(c, home, v, 0.2, 55)
	end)
	api.addFear(v, s.def.fear)
	api.fx(v, "scare", 1.0, Color3.fromRGB(220, 200, 150))
	-- 2) te lanza una venda desde la mano: si te alcanza, te sujeta un momento
	if api.alive(v) then
		local arm = c:FindFirstChild("ArmR")
		local from = arm and (arm.CFrame * CFrame.new(0, -arm.Size.Y / 2, 0)).Position or s.pos + V(0, 3, 0)
		api.sound("Whoosh", s.model.Hitbox)
		task.spawn(lash, v, from, Color3.fromRGB(222, 206, 166), 1.1)
		if flatDist(v.root.Position, s.pos) < s.def.radius + 1 then
			pin(v, 1.2)
		end
	end
	-- 3) se queda gruñendo y abriendo y cerrando las manos; si te acercas, te atrapa
	stalk(s, h, v, c, home, 3.0, 3, function(o)
		api.sound("ZombieGroan", s.model.Hitbox)
		play(c, {{0, REACH}, {0.15, {Torso = V(-30, 0, 0), Head = V(-14, 0, 0), ArmL = V(110, 0, 6), ArmR = V(110, 0, -6)}, "out"}})
		grab(o, s)
	end, function(t)
		local p = full(c, REACH)
		local grab = math.max(0, math.sin(t * 5)) ^ 2
		p.ArmL += V(0, 0, 16 * grab)
		p.ArmR -= V(0, 0, 16 * grab)
		p.Torso += V(3 * math.sin(t * 2), 0, 0)
		jitter(p, t, 6, 3, {"Head"})
		return p
	end, 55)
	-- 4) vuelve a su postura
	Rig.blend(c, {}, 0.9, nil, home)
	unflare(eye, 0.8)
	task.wait(3)
end

function B.Bruja(s, h, v)
	local c = rigOf(s)
	local brewL, pot = lightIn(s, "Potion")
	local bubbles = pot and pot:FindFirstChild("Bubbles")
	local flask = {}
	for _, p in c:GetChildren() do
		if p.Name == "Flask" or p.Name == "FlaskNeck" then
			table.insert(flask, p)
		end
	end
	-- 1) carcajada: echa la cabeza atrás, remueve como loca y el caldero hierve
	api.sound("Laugh", s.model.Hitbox)
	flare(brewL, 5, 18, 0.3)
	if bubbles then
		bubbles.Rate = 45
	end
	emit(s, "Potion", "Splash", 20)
	local CACKLE = {Torso = V(6, 0, 0), Head = V(28, 0, 0), ArmL = V(150, 0, -20)}
	play(c, {{0, {}}, {0.3, CACKLE}, {1.0, CACKLE}}, function(p, t)
		local b = math.abs(math.sin(t * 16))
		p.Torso += V(4 * b, 0, 0)
		p.Head += V(8 * b, 0, 6 * math.sin(t * 5))
		p.ArmR += V(10 * math.sin(t * 10), 0, 10 * math.cos(t * 10))
	end)
	-- 2) te lanza la poción burbujeante
	if api.alive(v) then
		play(c, {{0, CACKLE}, {0.12, {Torso = V(-14, 0, 0), Head = V(-6, 0, 0), ArmL = V(70, 0, -10)}, "in"}})
		local from = flask[1] and flask[1].Position or (s.pos + V(0, 4, 0))
		showParts(flask, false)
		task.spawn(hurl, s, v, from, Color3.fromRGB(110, 255, 80), 1.0, flask, 0.5)
		api.sound("Whoosh", s.model.Hitbox)
		task.wait(0.45)
		api.addFear(v, s.def.fear)
		api.fx(v, "scare", 1.3, Color3.fromRGB(110, 255, 80))
		api.sound("Laugh", s.model.Hitbox)
	end
	-- 3) vuelve a remover tan tranquila y le aparece otro frasco en la mano
	Rig.blend(c, {}, 0.7)
	showParts(flask, true, 0.3)
	if bubbles then
		bubbles.Rate = 8
	end
	unflare(brewL, 0.8)
	task.wait(3)
end

function B.Poltergeist(s, h, v)
	local m = s.model
	local ghost = rigOf(s, "Ghost")
	local gl = lightIn(s, "Ghost")
	local drawers, floats = {}, {}
	for _, p in m:GetChildren() do
		if p.Name == "Drawer" then
			table.insert(drawers, {part = p, home = p.CFrame, k = p:GetAttribute("D") or 1})
		elseif p.Name == "Float" then
			table.insert(floats, {part = p, home = p.CFrame})
		end
	end
	local dir = m:GetPivot().LookVector
	-- 1) la cómoda da golpes y los cajones traquetean
	for _ = 1, 3 do
		api.sound("Knock", m.Hitbox)
		local t0 = os.clock()
		while os.clock() - t0 < 0.22 do
			for _, d in drawers do
				d.part.CFrame = d.home + dir * (math.abs(math.noise(os.clock() * 30, d.k)) * 0.35)
			end
			for _, f in floats do
				f.part.CFrame = f.home * CFrame.Angles(math.noise(os.clock() * 20, 1) * 0.3, 0, math.noise(os.clock() * 20, 2) * 0.3)
			end
			RunService.Heartbeat:Wait()
		end
		task.wait(0.08)
	end
	-- 2) los cajones revientan hacia fuera y de dentro sale arrastrándose la niña fantasma
	api.sound("Slam", m.Hitbox)
	api.sound("WoodBreak", m.Hitbox)
	emit(s, "Crash", "Splinters", 30)
	for _, d in drawers do
		tween(d.part, 0.18 + d.k * 0.04, {CFrame = d.home + dir * (0.9 + d.k * 0.1)}, Enum.EasingStyle.Back)
	end
	local home = ghost:GetPivot()
	local LOW = {Root = V(0, -0.5, 0), Torso = V(-60, 0, 0), Head = V(-30, 0, 0)}
	setPose(ghost, full(ghost, LOW))
	reveal(ghost, true, 0.25)
	flare(gl, 4, 16, 0.2)
	api.sound("DollScream", m.Hitbox)
	local RISE = {Root = V(0, 2.4, -0.6), Torso = V(-10, 0, 0), Head = V(-10, 0, 40), ArmL = V(110, 0, -20), ArmR = V(120, 0, 20), Tail = V(30, 0, 0)}
	play(ghost, {{0, LOW}, {0.45, RISE, "back"}}, function(p, t)
		aim(ghost, home, v, 0.2, 60)
		jitter(p, t, 12, 7, {"Head"})
	end)
	-- 3) todo lo que flotaba sale volando hacia ti
	api.sound("Whoosh", m.Hitbox)
	if api.alive(v) then
		local to = v.root.Position + V(0, 1.5, 0)
		for i, f in floats do
			tween(f.part, 0.3, {CFrame = CFrame.new(to + V(math.cos(i * 1.6) * 1.2, math.sin(i) * 0.8, math.sin(i * 1.6) * 1.2)) * CFrame.Angles(i, i * 2, 0)})
		end
		task.wait(0.3)
		api.addFear(v, s.def.fear)
		api.fx(v, "scare", 1.4, Color3.fromRGB(190, 110, 255))
	end
	-- se queda mirándote con la cabeza torcida, a tirones
	stalk(s, h, v, ghost, home, 1.3, 0, nil, function(t)
		local p = full(ghost, RISE)
		if t % 0.5 < 0.1 then
			jitter(p, t * 3, 30, 9, {"Head"})
		end
		p.Root += V(0, 0.15 * math.sin(t * 3), 0)
		return p
	end, 60)
	-- 4) se mete en la cómoda, los cajones se cierran de golpe y todo vuelve a su sitio
	reveal(ghost, false, 0.35)
	Rig.blend(ghost, LOW, 0.4, "in", home)
	setPose(ghost, idlePose(ghost))
	unflare(gl, 0.4)
	for _, f in floats do
		tween(f.part, 0.8, {CFrame = f.home})
	end
	for k = 3, 1, -1 do
		for _, d in drawers do
			if d.k == k then
				tween(d.part, 0.12, {CFrame = d.home}, Enum.EasingStyle.Quad)
			end
		end
		api.sound("Slam", m.Hitbox)
		task.wait(0.18)
	end
	task.wait(2.5)
end

function B.Banshee(s, h, v)
	local c = rigOf(s)
	local home = c:GetPivot()
	local wisp = lightIn(s, "Wisp")
	local mouth = c:FindFirstChild("Mouth")
	local m0 = mouth and mouth.Size
	-- 1) se eleva despacio y se gira hacia ti
	flare(wisp, 3, 16, 0.4)
	api.sound("Whoosh", s.model.Hitbox)
	local UP = {Root = V(0, 1.3, 0), Torso = V(10, 0, 0), Head = V(20, 0, 0), ArmL = V(-10, 0, -30), ArmR = V(-10, 0, 30), Tail1 = V(20, 0, 0), Tail2 = V(25, 0, 0), Hair = V(20, 0, 0)}
	play(c, {{0, {}}, {0.6, UP}}, function()
		aim(c, home, v, 0.15)
	end)
	-- 2) coge aire... y suelta un lamento que te empuja hacia atrás
	if api.alive(v) then
		api.sound("Wail", s.model.Hitbox)
		api.sound("Scream2", s.model.Hitbox)
		if mouth then
			tween(mouth, 0.15, {Size = m0 * Vector3.new(1.4, 3.4, 1)})
		end
		flare(wisp, 4, 22, 0.12)
		emit(s, "Scream", "Scream", 40)
		local at = (c:FindFirstChild("Head") or s.model.Hitbox).Position
		for k = 0, 2 do
			task.delay(k * 0.22, wave, at, Color3.fromRGB(170, 230, 255), 14 + k * 6, 0.6)
		end
		for _, o in api.visitsIn(h) do
			if flatDist(o.root.Position, s.pos) < s.def.radius + 2 then
				api.addFear(o, o == v and s.def.fear or s.def.fear / 2)
				api.fx(o, "scare", 1.6, Color3.fromRGB(170, 230, 255))
			end
		end
		-- los bots retroceden unos pasos del susto
		if v.bot and api.alive(v) then
			local back = (v.root.Position - s.pos) * Vector3.new(1, 0, 1)
			if back.Magnitude > 0.1 then
				v.bot:PivotTo(v.bot:GetPivot() + back.Unit * 3)
			end
		end
		local WAIL = {Root = V(0, 1.5, 0), Torso = V(-14, 0, 0), Head = V(-22, 0, 0), Jaw = V(-30, 0, 0), ArmL = V(60, 0, -95), ArmR = V(60, 0, 95), Tail1 = V(35, 0, 0), Tail2 = V(40, 0, 0), Hair = V(-70, 0, 0)}
		play(c, {{0, UP}, {0.15, WAIL, "back"}, {1.5, WAIL}}, function(p, t)
			aim(c, home, v, 0.1)
			jitter(p, t, 6, 2, {"Head", "ArmL", "ArmR"})
			p.Hair += V(15 * math.sin(t * 20), 0, 8 * math.sin(t * 13))
			p.Tail1 += V(10 * math.sin(t * 11), 0, 0)
			p.Tail2 += V(12 * math.sin(t * 11 + 1), 0, 0)
		end)
		if mouth then
			tween(mouth, 0.4, {Size = m0})
		end
	end
	-- 3) baja otra vez despacio
	Rig.blend(c, {}, 1.0, nil, home)
	unflare(wisp, 0.8)
	task.wait(3)
end

---------- Trampas nuevas ----------
local HANDS_DOWN = V(0, -3.15, 0)
B.setup.Manos = function(m)
	local c = m:FindFirstChild("Hands")
	if c then
		setPose(c, full(c, {Root = HANDS_DOWN}))
	end
end

function B.Manos(s, h, v)
	local c = rigOf(s, "Hands")
	-- 1) los dedos asoman y se retuercen
	api.sound("Rubble", s.model.Hitbox)
	play(c, {{0, {Root = HANDS_DOWN}}, {0.3, {Root = HANDS_DOWN + V(0, 0.4, 0)}}}, function(p, t)
		for i = 1, 4 do
			p["F" .. i] += V(30 * math.sin(t * 25 + i), 0, 0)
		end
	end)
	-- 2) revientan del suelo y te agarran los tobillos
	api.sound("DirtBurst", s.model.Hitbox)
	api.sound("Sting", s.model.Hitbox)
	emit(s, "Dirt", "DirtBurst", 40)
	local UP, GRAB = {Root = V(0, 0.1, 0)}, {Root = V(0, 0.1, 0)}
	for i = 1, 4 do
		UP["F" .. i] = V(10, 0, 0)
		GRAB["F" .. i] = V(-95, 0, 0)
		GRAB["H" .. i] = V(-40, 0, 0)
	end
	play(c, {{0, {Root = HANDS_DOWN + V(0, 0.4, 0)}}, {0.14, UP, "back"}, {0.34, GRAB, "out"}})
	api.addFear(v, s.def.fear)
	api.fx(v, "scare", 1.2, Color3.fromRGB(110, 170, 90))
	pin(v, 2)
	-- 3) aprietan y tiran
	play(c, {{0, GRAB}, {1.9, GRAB}}, function(p, t)
		for i = 1, 4 do
			p["A" .. i] += V(12 * math.sin(t * 14 + i), 0, 10 * math.cos(t * 11 + i))
			p["F" .. i] += V(15 * math.sin(t * 9 + i * 2), 0, 0)
		end
	end)
	-- 4) se hunden otra vez
	api.sound("Rubble", s.model.Hitbox)
	Rig.blend(c, {Root = HANDS_DOWN}, 0.6, "in")
	task.wait(3)
end

function B.Pozo(s, h, v)
	local m = s.model
	local l, a = lightIn(s, "Souls")
	local souls = a and a:FindFirstChild("Souls")
	local pool = m:FindFirstChild("SoulPool")
	local bucket = rigOf(s, "Bucket")
	local list = {}
	for _, r in m:GetChildren() do
		if r.Name == "Soul" and r:IsA("Model") then
			table.insert(list, {rig = r, home = r:GetPivot(), ph = r:GetAttribute("Phase") or 1})
		end
	end
	-- 1) el pozo se ilumina y gime; las almas suben en espiral
	api.sound("Wail", m.Hitbox)
	api.sound("Deep", m.Hitbox)
	flare(l, 6, 22, 0.3)
	if souls then
		souls:Emit(30)
		souls.Rate = 25
	end
	if pool then
		tween(pool, 0.3, {Transparency = 0})
	end
	for _, sl in list do
		reveal(sl.rig, true, 0.4)
	end
	api.fx(v, "scare", 0.7, Color3.fromRGB(170, 100, 255))
	local t0 = os.clock()
	local dur = 3.4
	local paid, nextFear = false, 0
	while os.clock() - t0 < dur and m.Parent do
		local t = os.clock() - t0
		local out = EASE.out(math.clamp(t / 0.8, 0, 1)) * (1 - EASE["in"](math.clamp((t - dur + 0.7) / 0.7, 0, 1)))
		for _, sl in list do
			local ang = t * 2.2 + sl.ph * 2.1
			local r = 0.8 + 2.4 * out
			local pos = s.pos + V(math.cos(ang) * r, 1.3 + (2.2 + math.sin(t * 3 + sl.ph) * 0.6) * out, math.sin(ang) * r)
			local look = pos + V(-math.sin(ang), 0, math.cos(ang))
			if api.alive(v) and t % 2 < 1 then
				look = v.root.Position
			end
			sl.rig:PivotTo(CFrame.lookAt(pos, Vector3.new(look.X, pos.Y, look.Z) + V(0, 0, 0.001)))
			local p = idlePose(sl.rig)
			p.Wisp = V(20 + 15 * math.sin(t * 6 + sl.ph), 0, 20 * math.sin(t * 4 + sl.ph))
			p.ArmL = V(60 + 40 * math.sin(t * 5 + sl.ph), 0, -60)
			p.ArmR = V(60 + 40 * math.sin(t * 5 + sl.ph + 1), 0, 60)
			setPose(sl.rig, p)
		end
		if bucket then
			setPose(bucket, {Rope = V(18 * math.sin(t * 4), 0, 12 * math.cos(t * 3))})
		end
		-- cuanto más cerca del pozo, más miedo
		if t > nextFear then
			nextFear = t + 0.4
			for _, o in api.visitsIn(h) do
				if flatDist(o.root.Position, s.pos) < s.def.radius + 3 then
					api.addFear(o, s.def.fear / 5)
				end
			end
		end
		-- las almas traen monedas de más
		if not paid and t > 1.2 then
			paid = true
			emit(s, "Souls", "Gold", 30)
			api.sound("Coins", m.Hitbox)
			api.coins(v, s.pos + V(0, 2, 0), s.def.bonus or 0)
		end
		RunService.Heartbeat:Wait()
	end
	for _, sl in list do
		reveal(sl.rig, false, 0.3)
	end
	task.wait(0.3)
	for _, sl in list do
		sl.rig:PivotTo(sl.home)
		setPose(sl.rig, idlePose(sl.rig))
	end
	if bucket then
		Rig.blend(bucket, {}, 0.6)
	end
	if souls then
		souls.Rate = 4
	end
	if pool then
		tween(pool, 0.6, {Transparency = pool:GetAttribute("T") or 0.15})
	end
	unflare(l, 1)
	task.wait(3)
end

function B.Espejo(s, h, v)
	local m = s.model
	local c = rigOf(s, "Reflection")
	local home = c:GetPivot()
	local l = lightIn(s, "Glass")
	local glow = m:FindFirstChild("GlassGlow")
	local cracks = {}
	for _, p in m:GetChildren() do
		if p.Name == "Crack" then
			table.insert(cracks, p)
		end
	end
	local function cleanup()
		reveal(c, false, 0.5)
		Rig.blend(c, {}, 0.5, nil, home)
		for _, p in cracks do
			tween(p, 0.8, {Transparency = 1})
		end
		if glow then
			tween(glow, 0.8, {Transparency = glow:GetAttribute("T") or 0.75})
		end
		unflare(l, 0.8)
	end
	-- 1) tu reflejo aparece despacio y ladea la cabeza
	api.sound("Giggle", m.Hitbox)
	flare(l, 3, 14, 0.6)
	reveal(c, true, 0.8)
	play(c, {{0, {}}, {0.9, {Head = V(0, 0, 28)}}}, function()
		aim(c, home, v, 0.1, 10)
	end)
	if not api.alive(v) then
		cleanup()
		return task.wait(2)
	end
	-- 2) pega las manos al cristal y da dos golpes
	local PRESS = {Head = V(-6, 0, 18), ArmL = V(85, 0, -10), ArmR = V(85, 0, 10), Torso = V(-6, 0, 0)}
	play(c, {{0, {Head = V(0, 0, 28)}}, {0.3, PRESS}})
	for _ = 1, 2 do
		api.sound("Knock", m.Hitbox)
		play(c, {{0, PRESS}, {0.08, {Head = V(-6, 0, 18), ArmL = V(70, 0, -10), ArmR = V(70, 0, 10), Torso = V(4, 0, 0)}}, {0.18, PRESS, "in"}})
		task.wait(0.15)
	end
	-- 3) ¡CRAC! el cristal se raja y sus brazos lo atraviesan
	api.sound("WoodBreak", m.Hitbox)
	api.sound("Sting", m.Hitbox)
	api.sound("DollScream", m.Hitbox)
	for _, p in cracks do
		p.Transparency = 0
	end
	emit(s, "Glass", "Shatter", 50)
	flare(l, 10, 26, 0.08, Color3.fromRGB(240, 220, 255))
	if glow then
		glow.Transparency = 0.2
	end
	api.addFear(v, s.def.fear)
	api.fx(v, "scare", 1.7, Color3.fromRGB(230, 200, 255))
	local BURST = {Root = V(0, 0, -0.5), Torso = V(-18, 0, 0), Head = V(-12, 0, 0), ArmL = V(100, 15, -12), ArmR = V(100, -15, 12)}
	play(c, {{0, PRESS}, {0.12, BURST, "back"}, {1.3, BURST}}, function(p, t)
		if t > 0.12 then
			p.ArmL += V(20 * math.sin(t * 18), 0, 0)
			p.ArmR += V(20 * math.sin(t * 18 + math.pi), 0, 0)
			jitter(p, t, 10, 4, {"Head"})
		end
	end)
	-- 4) se desvanece y el espejo se recompone
	cleanup()
	task.wait(3)
end

---------- Legendarios nuevos (los más raros: más grandes y con el susto más espectacular) ----------
function B.HombreLobo(s, h, v)
	local c = rigOf(s)
	local home = c:GetPivot()
	local eyes = lightIn(s, "Eyes")
	-- 1) se gira hacia ti y aúlla con la cabeza hacia arriba
	api.sound("Growl", s.model.Hitbox)
	flare(eyes, 5, 14, 0.2)
	local HOWL = {Torso = V(8, 0, 0), Head = V(50, 0, 0), Jaw = V(-30, 0, 0), ArmL = V(20, 0, -45), ArmR = V(20, 0, 45), Tail = V(10, 0, 0)}
	play(c, {{0, {}}, {0.4, HOWL}, {1.2, HOWL}}, function(p, t)
		aim(c, home, v, 0.15, 70)
		if t > 0.4 then
			jitter(p, t, 4, 1, {"Head", "Jaw"})
		end
	end)
	emit(s, "Howl", "Breath", 20)
	api.sound("ZombieGroan", s.model.Hitbox)
	-- 2) ruge con las garras en alto y lanza dos zarpazos (sin moverse de su sitio)
	local ROAR = {Torso = V(-30, 0, 0), Head = V(10, 0, 0), Jaw = V(-38, 0, 0), ArmL = V(165, 0, -25), ArmR = V(165, 0, 25), LegL = V(25, 0, -5), LegR = V(-12, 0, 5), Tail = V(-40, 0, 0)}
	api.sound("Sting", s.model.Hitbox)
	play(c, {{0, HOWL}, {0.18, ROAR, "back"}})
	api.addFear(v, s.def.fear)
	api.fx(v, "scare", 1.6, Color3.fromRGB(150, 30, 30))
	api.fx(v, "legend", s.def.name, Color3.fromRGB(255, 200, 60))
	emit(s, "Eyes", "Fur", 30)
	for k = 1, 2 do
		local swipe = table.clone(ROAR)
		swipe[k == 1 and "ArmR" or "ArmL"] = V(40, 0, k == 1 and -10 or 10)
		swipe.Torso = V(-38, k == 1 and -20 or 20, 0)
		api.sound("Swoosh", s.model.Hitbox)
		play(c, {{0, ROAR}, {0.12, swipe, "in"}, {0.35, ROAR, "out"}}, function()
			aim(c, home, v, 0.2, 70)
		end)
	end
	-- 3) gruñe jadeando; si te acercas, se acabó
	stalk(s, h, v, c, home, 3, 3.4, function(o)
		api.sound("Growl", s.model.Hitbox)
		play(c, {{0, ROAR}, {0.12, {Torso = V(-45, 0, 0), Head = V(-10, 0, 0), Jaw = V(-40, 0, 0), ArmL = V(100, 0, -10), ArmR = V(100, 0, 10)}, "out"}})
		grab(o, s)
	end, function(t)
		local p = full(c, {Torso = V(-22, 0, 0), Head = V(18, 0, 0), ArmL = V(60, 0, -22), ArmR = V(60, 0, 22), Jaw = V(-12, 0, 0)})
		local b = math.sin(t * 7)
		p.Torso += V(4 * b, 0, 0)
		p.Jaw += V(-8 * math.abs(b), 0, 0)
		p.ArmL += V(0, 0, -10 * math.abs(math.sin(t * 3)))
		p.Tail += V(0, 25 * math.sin(t * 5), 0)
		return p
	end, 70)
	Rig.blend(c, {}, 0.8, nil, home)
	unflare(eyes, 0.8)
	task.wait(3.5)
end

function B.Vampiro(s, h, v)
	local m = s.model
	local c = rigOf(s)
	local home = c:GetPivot()
	local eyes = lightIn(s, "Eyes")
	local bats = {}
	for _, b in m:GetChildren() do
		if b.Name == "Bat" and b:IsA("Model") then
			table.insert(bats, {rig = b, home = b:GetPivot(), phase = math.random() * 6, r = math.random() * 0.8, h = math.random() * 1.2 - 0.3})
		end
	end
	-- 1) se ríe, se gira hacia ti y abre la capa como unas alas
	api.sound("Laugh", m.Hitbox)
	flare(eyes, 4, 14, 0.2)
	local OPEN = {Torso = V(6, 0, 0), Head = V(14, 0, 0), ArmL = V(40, 0, -80), ArmR = V(40, 0, 80), CapeL = V(-25, 30, -75), CapeR = V(-25, -30, 75)}
	play(c, {{0, {}}, {0.35, OPEN, "back"}}, function()
		aim(c, home, v, 0.15, 60)
	end)
	-- 2) una nube de murciélagos sale de la capa y te rodea mientras sisea enseñando los colmillos
	emit(s, "Poof", "Poof", 40)
	api.sound("Swoosh", m.Hitbox)
	api.sound("Sting", m.Hitbox)
	api.sound("Deep", m.Hitbox)
	api.addFear(v, s.def.fear)
	api.fx(v, "scare", 1.6, Color3.fromRGB(150, 0, 30))
	api.fx(v, "legend", s.def.name, Color3.fromRGB(255, 40, 70))
	for _, b in bats do
		reveal(b.rig, true, 0.1)
	end
	local t0 = os.clock()
	local dur = 1.9
	while os.clock() - t0 < dur and m.Parent do
		local t = os.clock() - t0
		local face = api.alive(v) and v.root.Position + V(0, 1.8, 0) or s.pos + V(0, 4, 0)
		local e = EASE.out(math.clamp(t / 0.5, 0, 1)) * (1 - EASE["in"](math.clamp((t - dur + 0.5) / 0.5, 0, 1)))
		swarm(bats, face, t, e, 2.2, 0)
		local p = full(c, OPEN)
		jitter(p, t, 5, 3, {"Head"})
		p.CapeL += V(0, 0, 8 * math.sin(t * 9))
		p.CapeR -= V(0, 0, 8 * math.sin(t * 9))
		aim(c, home, v, 0.1, 60)
		setPose(c, p)
		RunService.Heartbeat:Wait()
	end
	for _, b in bats do
		reveal(b.rig, false, 0.15)
	end
	task.delay(0.2, function()
		for _, b in bats do
			b.rig:PivotTo(b.home)
			setPose(b.rig, idlePose(b.rig))
		end
	end)
	-- 3) se abalanza en su sitio con las garras por delante; si te acercas, te atrapa
	local LUNGE = {Torso = V(-22, 0, 0), Head = V(-6, 0, 0), ArmL = V(100, 10, -20), ArmR = V(100, -10, 20), CapeL = V(-40, 20, -60), CapeR = V(-40, -20, 60)}
	api.sound("Whoosh", m.Hitbox)
	play(c, {{0, OPEN}, {0.15, LUNGE, "back"}})
	stalk(s, h, v, c, home, 2.6, 3.2, function(o)
		api.sound("Deep", m.Hitbox)
		grab(o, s)
	end, function(t)
		local p = full(c, LUNGE)
		local g = math.max(0, math.sin(t * 6))
		p.ArmL += V(0, 0, 15 * g)
		p.ArmR -= V(0, 0, 15 * g)
		p.CapeL += V(0, 0, 6 * math.sin(t * 4))
		p.CapeR -= V(0, 0, 6 * math.sin(t * 4))
		return p
	end, 60)
	Rig.blend(c, {}, 0.8, nil, home)
	unflare(eyes, 0.8)
	task.wait(4)
end

function B.Jinete(s, h, v)
	local m = s.model
	local c = rigOf(s)
	local home = c:GetPivot()
	local ammo = group(s, "Ammo")
	local head = lightIn(s, "Head")
	local eyes = lightIn(s, "HorseEyes")
	local mane = find(s, "Mane")
	local maneFire = mane and mane:FindFirstChild("ManeFire")
	-- 1) truenos: al caballo se le encienden los ojos y la crin arde más fuerte
	api.sound("Thunder", m.Hitbox)
	api.fx(v, "flash", Color3.fromRGB(220, 230, 255))
	flare(eyes, 5, 12, 0.15)
	flare(head, 5, 20, 0.3)
	if maneFire then
		maneFire.Rate = 60
	end
	-- 2) se encabrita pateando el aire y el jinete alza la calabaza
	local REAR = {Body = V(32, 0, 0), Neck = V(15, 0, 0), HHead = V(-20, 0, 0), FL = V(-60, 0, 0), FR = V(-30, 0, 0), BL = V(-25, 0, 0), BR = V(-25, 0, 0),
		Tail = V(-10, 0, 0), RTorso = V(-28, 0, 0), RArmR = V(175, 0, 10), RArmL = V(80, 0, -6), RCape = V(-20, 0, 0)}
	api.sound("Growl", m.Hitbox)
	play(c, {{0, {}}, {0.45, REAR, "back"}, {0.95, REAR}}, function(p, t)
		aim(c, home, v, 0.08, 35)
		if t > 0.3 then
			p.FL += V(30 * math.sin(t * 14), 0, 0)
			p.FR += V(30 * math.sin(t * 14 + 2), 0, 0)
		end
	end)
	-- 3) te lanza la calabaza en llamas
	if api.alive(v) then
		local THROW = table.clone(REAR)
		THROW.RArmR = V(40, 0, 10)
		THROW.RTorso = V(-45, 0, 0)
		api.sound("Laugh", m.Hitbox)
		play(c, {{0, REAR}, {0.14, THROW, "in"}})
		local from = ammo[1] and ammo[1].Position or (s.pos + V(0, 9, 0))
		showParts(ammo, false)
		emit(s, "Head", "Launch", 30)
		task.spawn(hurl, s, v, from, Color3.fromRGB(255, 110, 20), 1.8, ammo, 0.6)
		task.wait(0.5)
		api.addFear(v, s.def.fear)
		api.fx(v, "scare", 1.8, Color3.fromRGB(255, 110, 20))
		api.fx(v, "legend", s.def.name, Color3.fromRGB(255, 130, 30))
	end
	-- 4) cae de golpe sobre las patas: chispas y temblor
	play(c, {{0, Rig.current(c)}, {0.22, {Body = V(-4, 0, 0), RTorso = V(-10, 0, 0), RArmR = V(60, 0, 10), HHead = V(10, 0, 0)}, "in"}})
	api.sound("Boom", m.Hitbox)
	api.sound("Thud", m.Hitbox)
	emit(s, "Hooves", "Sparks", 40)
	wave(s.pos + V(0, 0.5, 0), Color3.fromRGB(255, 140, 40), 12, 0.4, 0.5)
	-- se enciende otra calabaza en su mano
	showParts(ammo, true, 0.3)
	flare(head, 3, 16, 0.3)
	-- 5) piafa vigilándote; si te acercas, te arrolla
	stalk(s, h, v, c, home, 3, 4, function(o)
		api.sound("Boom", m.Hitbox)
		play(c, {{0, Rig.current(c)}, {0.15, {Body = V(18, 0, 0), FL = V(-70, 0, 0), FR = V(-50, 0, 0)}, "out"}, {0.3, {Body = V(-6, 0, 0)}, "in"}})
		grab(o, s)
	end, function(t)
		local p = full(c, {RArmR = V(150, 0, 14)})
		p.FL = V(-40 * math.max(0, math.sin(t * 6)), 0, 0)
		p.HHead = V(10 * math.sin(t * 3), 12 * math.sin(t * 1.7), 0)
		p.Tail = V(20, 20 * math.sin(t * 4), 0)
		return p
	end, 35)
	Rig.blend(c, {}, 0.8, nil, home)
	unflare(eyes, 0.8)
	unflare(head, 0.8)
	if maneFire then
		maneFire.Rate = 22
	end
	task.wait(4)
end

function B.Dragon(s, h, v)
	local m = s.model
	local c = rigOf(s)
	local home = c:GetPivot()
	local core = lightIn(s, "Core")
	local eyes = lightIn(s, "Eyes")
	local mouth = find(s, "Mouth")
	-- gira el cuello (no el cuerpo) hacia el visitante, como mucho 50°
	local function look(p, k)
		if not api.alive(v) then
			return
		end
		local rel = home:PointToObjectSpace(v.root.Position)
		local yaw = math.clamp(math.deg(math.atan2(-rel.X, -rel.Z)), -50, 50) * k
		p.Neck1 += V(0, yaw * 0.4, 0)
		p.Neck2 += V(0, yaw * 0.3, 0)
		p.Head += V(0, yaw * 0.3, 0)
	end
	-- 1) despierta: el fuego del pecho arde, se yergue y alza el cuello buscando
	api.sound("Growl", m.Hitbox)
	api.sound("Deep", m.Hitbox)
	flare(core, 2, 16, 0.4)
	flare(eyes, 2, 10, 0.2)
	local RISE = {Body = V(18, 0, 0), Neck1 = V(-10, 0, 0), Neck2 = V(-5, 0, 0), Neck3 = V(10, 0, 0), Head = V(30, 0, 0), FL = V(-35, 0, 0), FR = V(-20, 0, 0),
		WingL = V(0, 15, -35), WingL2 = V(0, 10, 60), WingR = V(0, -15, 35), WingR2 = V(0, -10, -60), Tail1 = V(10, 0, 0), Tail2 = V(5, 20, 0), Tail3 = V(0, 30, 0)}
	play(c, {{0, {}}, {0.6, RISE, "back"}}, function(p, t)
		look(p, math.min(1, t / 0.6))
	end)
	-- 2) despliega las alas del todo, las bate y ruge
	local ROAR = table.clone(RISE)
	ROAR.Jaw = V(-42, 0, 0)
	ROAR.Head = V(-15, 0, 0)
	ROAR.WingL, ROAR.WingL2, ROAR.WingR, ROAR.WingR2 = V(0, 5, -15), V(0, 0, -10), V(0, -5, 15), V(0, 0, 10)
	api.sound("Boom", m.Hitbox)
	api.sound("Growl", m.Hitbox)
	emit(s, "Mouth", "Roar", 40)
	api.addFear(v, s.def.fear)
	api.fx(v, "scare", 2, Color3.fromRGB(110, 255, 140))
	api.fx(v, "legend", s.def.name, Color3.fromRGB(110, 255, 140))
	wave((c:FindFirstChild("Skull") or m.Hitbox).Position, Color3.fromRGB(110, 255, 140), 18, 0.5, 0.6)
	play(c, {{0, RISE}, {0.25, ROAR, "back"}, {1.2, ROAR}}, function(p, t)
		look(p, 1)
		local f = math.sin(t * 9)
		p.WingL += V(0, 0, 22 * f)
		p.WingR -= V(0, 0, 22 * f)
		p.WingL2 += V(0, 0, 14 * f)
		p.WingR2 -= V(0, 0, 14 * f)
		jitter(p, t, 5, 6, {"Head", "Jaw"})
	end)
	-- 3) escupe fuego fantasmal hacia ti
	if api.alive(v) and mouth then
		local a = Instance.new("Attachment")
		a.Parent = workspace.Terrain
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/fire_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(110, 255, 140), Color3.fromRGB(220, 255, 220))
		e.LightEmission = 1
		e.Size = NumberSequence.new(1.4, 4.5)
		e.Transparency = NumberSequence.new(0.1, 1)
		e.Lifetime = NumberRange.new(0.4, 0.5)
		e.SpreadAngle = Vector2.new(10, 10)
		e.EmissionDirection = Enum.NormalId.Front
		e.Rate = 180
		e.Enabled = false
		e.Parent = a
		api.sound("Whoosh", m.Hitbox)
		api.sound("Deep", m.Hitbox)
		local BREATH = table.clone(ROAR)
		BREATH.Head, BREATH.Neck3, BREATH.Jaw = V(-10, 0, 0), V(-5, 0, 0), V(-38, 0, 0)
		play(c, {{0, ROAR}, {0.15, BREATH}, {1.3, BREATH}}, function(p, t)
			look(p, 1)
			p.Neck2 += V(0, 8 * math.sin(t * 5), 0)
			local from = mouth.Position
			local to = api.alive(v) and v.root.Position + V(0, 1, 0) or from + mouth.CFrame.LookVector * 10
			a.WorldCFrame = CFrame.lookAt(from, to)
			e.Speed = NumberRange.new((to - from).Magnitude * 2.4)
			if t > 0.15 and not e.Enabled then
				e.Enabled = true
			end
		end)
		e.Enabled = false
		task.delay(1, a.Destroy, a)
		api.addFear(v, 15)
	end
	-- 4) se queda en guardia balanceando la cola; si alguien pasa bajo sus alas, se acabó
	stalk(s, h, v, c, home, 3, 4.5, function(o)
		api.sound("Growl", m.Hitbox)
		play(c, {{0, Rig.current(c)}, {0.15, {Body = V(4, 0, 0), Neck1 = V(-40, 0, 0), Neck2 = V(-20, 0, 0), Head = V(10, 0, 0), Jaw = V(-40, 0, 0)}, "out"}})
		grab(o, s)
	end, function(t)
		local p = full(c, {Body = V(6, 0, 0), Jaw = V(-14, 0, 0), WingL = V(0, 20, -40), WingR = V(0, -20, 40), WingL2 = V(0, 10, 40), WingR2 = V(0, -10, -40)})
		look(p, 1)
		p.Tail1 += V(0, 20 * math.sin(t * 2.5), 0)
		p.Tail2 += V(0, 25 * math.sin(t * 2.5 - 0.6), 0)
		p.Tail3 += V(0, 30 * math.sin(t * 2.5 - 1.2), 0)
		p.Body += V(2 * math.sin(t * 3), 0, 0)
		return p
	end, 0)
	Rig.blend(c, {}, 1.0, nil, home)
	unflare(core, 1)
	unflare(eyes, 1)
	task.wait(4)
end

---------- Personajes nuevos (se quedan en su sitio: animaciones y proyectiles) ----------
-- Rayo en zigzag de 'from' a 'to': piezas de neón que se apagan enseguida
local function bolt(from, to, color, time)
	local parts = {}
	local n = 7
	local prev = from
	for k = 1, n do
		local p = k == n and to or from:Lerp(to, k / n) + V(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 1.4
		local len = (p - prev).Magnitude
		if len > 0.05 then
			local seg = Instance.new("Part")
			seg.Material = Enum.Material.Neon
			seg.Color = color
			seg.Anchored, seg.CanCollide, seg.CanQuery, seg.CanTouch, seg.CastShadow = true, false, false, false, false
			seg.Size = V(0.18, 0.18, len)
			seg.CFrame = CFrame.lookAt((prev + p) / 2, p)
			seg.Parent = workspace
			table.insert(parts, seg)
		end
		prev = p
	end
	task.delay(time or 0.18, function()
		for _, q in parts do
			q:Destroy()
		end
	end)
end

-- El color de la skin que lleva el susto de esta pieza (Config.SkinThemes: accent), si lleva
local function skinAccent(p)
	local m = p:FindFirstAncestorWhichIsA("Model")
	while m and m.Parent and m.Parent:IsA("Model") do
		m = m.Parent
	end
	local def = m and Config.Scares[m:GetAttribute("Skin") or ""]
	local th = def and def.theme and Config.SkinThemes[def.theme]
	return th and th.accent
end

-- Pone material y color a unas piezas (y devuelve cómo estaban, para restore). Lo que se enciende en neón toma el
-- color de la skin si lleva (la cara de la calabaza helada arde azul hielo, no naranja)
local function paint(parts, mat, color)
	local before = {}
	color = mat == Enum.Material.Neon and parts[1] and skinAccent(parts[1]) or color
	for _, p in parts do
		before[p] = {p.Material, p.Color}
		p.Material, p.Color = mat, color
	end
	return before
end
local function restore(before)
	for p, b in before do
		p.Material, p.Color = b[1], b[2]
	end
end

-- HOMBRE CALABAZA: levanta la cabeza a tirones, se le enciende la cara en llamas, se yergue riendo y te lanza sus
-- enredaderas a los tobillos (te sujetan un momento)
function B.HombreCalabaza(s, h, v)
	local c = rigOf(s)
	local home = c:GetPivot()
	local glow = lightIn(s, "FaceGlow")
	local fire = find(s, "HeadFire")
	local faces = {}
	for _, p in c:GetChildren() do
		if p.Name == "Face" then
			table.insert(faces, p)
		end
	end
	-- 1) crujido de hojas y la cabeza se levanta hacia ti
	api.sound("Creak", s.model.Hitbox)
	emit(s, "Leaves", "LeafBurst", 20)
	play(c, {{0, {}}, {0.25, {Head = V(-12, 0, 8), Torso = V(-8, 0, 2)}, "out"}, {0.55, {Head = V(-6, 0, -6), Torso = V(-4, 0, 0)}, "out"}}, function()
		aim(c, home, v, 0.15, 60)
	end)
	-- 2) la cara se le enciende en llamas y se yergue con los brazos abiertos
	local before = paint(faces, Enum.Material.Neon, Color3.fromRGB(255, 190, 50))
	flare(glow, 6, 16, 0.15)
	if fire then
		fire.Rate = 40
	end
	emit(s, "FaceGlow", "Embers", 30)
	api.sound("Laugh", s.model.Hitbox)
	api.sound("Sting", s.model.Hitbox)
	api.addFear(v, s.def.fear)
	api.fx(v, "scare", 1.2, Color3.fromRGB(255, 150, 30))
	local RISE = {Torso = V(6, 0, 0), Head = V(8, 0, 0), ArmL = V(60, 0, -50), ArmR = V(60, 0, 50), LegL = V(-4, 0, -4), LegR = V(4, 0, 4)}
	play(c, {{0, Rig.current(c)}, {0.25, RISE, "back"}}, function()
		aim(c, home, v, 0.2, 60)
	end)
	-- 3) sus enredaderas salen disparadas de las manos y te atrapan los tobillos un momento
	if api.alive(v) then
		api.sound("Whoosh", s.model.Hitbox)
		for _, name in {"ArmLHand", "ArmRHand"} do
			local hand = c:FindFirstChild(name)
			if hand then
				task.spawn(lash, v, hand.Position, Color3.fromRGB(70, 140, 50), 0.9)
			end
		end
		if flatDist(v.root.Position, s.pos) < s.def.radius + 1 then
			pin(v, 0.7)
		end
	end
	-- 4) se ríe con los brazos en alto y vuelve a desplomarse
	play(c, {{0, RISE}, {1.4, RISE}}, function(p, t)
		aim(c, home, v, 0.12, 60)
		p.Head += V(10 * math.abs(math.sin(t * 12)), 0, 6 * math.sin(t * 6))
		p.ArmL += V(15 * math.sin(t * 9), 0, 0)
		p.ArmR += V(15 * math.sin(t * 9 + 2), 0, 0)
	end)
	if fire then
		fire.Rate = 0
	end
	Rig.blend(c, {}, 0.9, "out", home)
	restore(before)
	unflare(glow, 0.8)
	task.wait(3)
end

-- ESQUELETO: traquetea, se recompone de golpe, se ríe castañeteando la mandíbula y te lanza su calavera en llamas
-- verdes; sin cabeza tantea el aire hasta que la calavera vuelve a su sitio
function B.Esqueleto(s, h, v)
	local c = rigOf(s)
	local home = c:GetPivot()
	local eyes = lightIn(s, "Eyes")
	local skull = group(s, "Skull")
	local GREEN = Color3.fromRGB(120, 255, 140)
	-- 1) los huesos tiemblan...
	api.sound("Rubble", s.model.Hitbox)
	emit(s, "Rattle", "BoneDust", 20)
	emit(s, "Dirt", "DirtBurst", 15)
	play(c, {{0, {}}, {0.6, {}}}, function(p, t)
		jitter(p, t, 10, 2, {"Torso", "Head", "ArmL", "ArmR", "LegL", "LegR", "Jaw"})
	end)
	-- ...y se recompone de un tirón, mirándote
	local UP = {Torso = V(-4, 0, 0), Head = V(6, 0, 0), ArmL = V(20, 0, -30), ArmR = V(20, 0, 30), LegL = V(0, 0, -3), LegR = V(0, 0, 3), Jaw = V(-30, 0, 0)}
	flare(eyes, 5, 12, 0.15)
	api.sound("Sting", s.model.Hitbox)
	play(c, {{0, Rig.current(c)}, {0.2, UP, "back"}}, function()
		aim(c, home, v, 0.25, 70)
	end)
	api.addFear(v, s.def.fear * 0.5)
	api.fx(v, "scare", 1.0, Color3.fromRGB(230, 220, 200))
	-- 2) carcajada castañeteando la mandíbula
	api.sound("Laugh", s.model.Hitbox)
	play(c, {{0, UP}, {0.9, UP}}, function(p, t)
		aim(c, home, v, 0.15, 70)
		p.Jaw = V(-30 * math.abs(math.sin(t * 14)), 0, 0)
		p.Head += V(10 * math.abs(math.sin(t * 7)), 0, 0)
		p.Torso += V(5 * math.abs(math.sin(t * 7)), 0, 0)
	end)
	-- 3) se arranca la calavera y te la lanza
	if api.alive(v) and #skull > 0 then
		local THROW = table.clone(UP)
		THROW.ArmR, THROW.Torso = V(170, 0, 10), V(10, 0, 0)
		play(c, {{0, UP}, {0.18, THROW, "out"}})
		local THROWN = table.clone(UP)
		THROWN.ArmR, THROWN.Torso = V(60, 0, 10), V(-18, 0, 0)
		play(c, {{0, THROW}, {0.12, THROWN, "in"}})
		local from = (find(s, "Skull") or s.model.Hitbox).Position
		showParts(skull, false)
		api.sound("Whoosh", s.model.Hitbox)
		task.spawn(hurl, s, v, from, GREEN, 1.2, skull, 0.55)
		task.wait(0.5)
		api.addFear(v, s.def.fear * 0.5)
		api.fx(v, "scare", 1.3, GREEN)
		-- 4) sin cabeza, tantea el aire... y la calavera vuelve a aparecer
		play(c, {{0, THROWN}, {1.2, THROWN}}, function(p, t)
			p.ArmL = V(60 + 20 * math.sin(t * 6), 0, -20)
			p.ArmR = V(60 + 20 * math.sin(t * 6 + 2), 0, 20)
		end)
		showParts(skull, true, 0.4)
		emit(s, "Rattle", "BoneDust", 15)
		api.sound("Poof", s.model.Hitbox)
	end
	Rig.blend(c, {}, 0.8, "out", home)
	unflare(eyes, 0.8)
	task.wait(3)
end

-- FRANKENSTEIN: las bobinas descargan sobre él y se convulsiona; abre los ojos, revienta las correas y ruge con los
-- brazos por delante; las bobinas te lanzan tres descargas. Pisa fuerte en su sitio: si te acercas, te agarra.
function B.Frankenstein(s, h, v)
	local m = s.model
	local c = rigOf(s)
	local home = c:GetPivot()
	local eyes = lightIn(s, "Eyes")
	local straps = group(s, "Straps")
	local chest = find(s, "Chest")
	local coils = {}
	for _, n in {"CoilL", "CoilR"} do
		local a = find(s, n)
		if a then
			table.insert(coils, a)
		end
	end
	local BLUE = Color3.fromRGB(150, 200, 255)
	local function zap(a, to)
		bolt(a.Position, to, BLUE, 0.15)
		local e = a:FindFirstChild("Zap")
		if e then
			e:Emit(15)
		end
		flare(a:FindFirstChildWhichIsA("Light"), 5, 16, 0.05)
	end
	-- 1) cae un rayo y las bobinas descargan sobre el monstruo dormido, que se convulsiona
	api.sound("Thunder", m.Hitbox)
	api.sound("Flicker", m.Hitbox)
	api.fx(v, "flash", Color3.fromRGB(200, 220, 255))
	local t0, nextZap = os.clock(), 0
	while os.clock() - t0 < 1.0 and m.Parent do
		local t = os.clock() - t0
		if t >= nextZap and chest then
			nextZap = t + 0.2
			for _, a in coils do
				zap(a, chest.Position + V(math.random() - 0.5, math.random() * 2 - 1, -0.3))
			end
			emit(s, "Chest", "Sparks", 10)
		end
		local p = idlePose(c)
		jitter(p, t, 14, 7, {"Torso", "Head", "ArmL", "ArmR"})
		setPose(c, p)
		RunService.Heartbeat:Wait()
	end
	-- 2) abre los ojos, revienta las correas y ruge con los brazos por delante
	flare(eyes, 4, 12, 0.1)
	api.sound("Snap", m.Hitbox)
	api.sound("WoodBreak", m.Hitbox)
	showParts(straps, false)
	emit(s, "Snap", "StrapBurst", 30)
	local ROAR = {Torso = V(-8, 0, 0), Head = V(10, 0, 0), ArmL = V(90, 0, -4), ArmR = V(90, 0, 4), LegL = V(0, 0, -6), LegR = V(0, 0, 6)}
	api.sound("ZombieGroan3", m.Hitbox)
	play(c, {{0, Rig.current(c)}, {0.3, ROAR, "back"}}, function()
		aim(c, home, v, 0.15, 45)
	end)
	api.addFear(v, s.def.fear * 0.6)
	api.fx(v, "scare", 1.6, Color3.fromRGB(140, 200, 110))
	api.fx(v, "legend", s.def.name, Color3.fromRGB(150, 220, 120))
	-- 3) las bobinas te lanzan tres descargas
	for k = 1, 3 do
		if not api.alive(v) or #coils == 0 then
			break
		end
		zap(coils[(k - 1) % #coils + 1], v.root.Position + V(0, 1, 0))
		api.sound("Flicker", m.Hitbox)
		api.addFear(v, s.def.fear * 0.14)
		play(c, {{0, ROAR}, {0.35, ROAR}}, function(p, t)
			aim(c, home, v, 0.15, 45)
			jitter(p, t, 5, k, {"Head"})
		end)
	end
	-- 4) pisa fuerte en su sitio con los brazos estirados; si te acercas, te agarra
	stalk(s, h, v, c, home, 3, 3.6, function(o)
		api.sound("ZombieGroan", m.Hitbox)
		play(c, {{0, Rig.current(c)}, {0.15, {Torso = V(-25, 0, 0), ArmL = V(110, 0, 10), ArmR = V(110, 0, -10)}, "out"}})
		grab(o, s)
	end, function(t)
		local p = full(c, ROAR)
		local step = math.sin(t * 4)
		p.LegL += V(20 * math.max(0, step), 0, 0)
		p.LegR += V(20 * math.max(0, -step), 0, 0)
		p.Torso += V(0, 6 * step, 3 * step)
		p.ArmL += V(6 * math.sin(t * 4 + 1), 0, 0)
		p.ArmR += V(6 * math.sin(t * 4 + 2), 0, 0)
		return p
	end, 45)
	Rig.blend(c, {}, 1.0, nil, home)
	showParts(straps, true, 0.5)
	unflare(eyes, 0.8)
	for _, a in coils do
		unflare(a:FindFirstChildWhichIsA("Light"), 0.6)
	end
	task.wait(4)
end

-- DEMONIO: el pentagrama arde, se yergue abriendo las alas, ruge y te lanza un orbe de fuego infernal. Se queda en
-- guardia con las alas abiertas: si te acercas, te atrapa con sus garras.
function B.Demonio(s, h, v)
	local m = s.model
	local c = rigOf(s)
	local home = c:GetPivot()
	local eyes = lightIn(s, "Eyes")
	local pent = lightIn(s, "Pentagram")
	local runes = {}
	for _, p in m:GetChildren() do
		if p.Name == "Rune" then
			table.insert(runes, {part = p, color = p.Color, size = p.Size})
		end
	end
	local FIRE = Color3.fromRGB(255, 110, 30)
	-- 1) el pentagrama arde: las runas se avivan y sale fuego del suelo
	api.sound("Deep", m.Hitbox)
	api.sound("Rubble", m.Hitbox)
	flare(pent, 4, 22, 0.3)
	for _, r in runes do
		tween(r.part, 0.3, {Color = Color3.fromRGB(255, 230, 120), Size = r.size + V(0.12, 0.08, 0)})
	end
	emit(s, "Pentagram", "Hellfire", 50)
	wave(s.pos + V(0, 0.5, 0), FIRE, 14, 0.5, 0.4)
	-- 2) se yergue, abre las alas de golpe y ruge
	local RISE = {Torso = V(6, 0, 0), Head = V(18, 0, 0), Jaw = V(-30, 0, 0), ArmL = V(40, 0, -60), ArmR = V(40, 0, 60), LegL = V(0, 0, -6), LegR = V(0, 0, 6),
		WingL = V(0, 15, -15), WingR = V(0, -15, 15), Tail = V(10, 0, 0)}
	api.sound("Growl", m.Hitbox)
	flare(eyes, 6, 16, 0.15)
	play(c, {{0, {}}, {0.35, RISE, "back"}}, function()
		aim(c, home, v, 0.15, 60)
	end)
	emit(s, "Breath", "Roar", 40)
	api.sound("Boom", m.Hitbox)
	api.addFear(v, s.def.fear * 0.6)
	api.fx(v, "scare", 1.8, FIRE)
	api.fx(v, "legend", s.def.name, Color3.fromRGB(255, 60, 40))
	play(c, {{0, RISE}, {1.0, RISE}}, function(p, t)
		aim(c, home, v, 0.12, 60)
		local f = math.sin(t * 10)
		p.WingL += V(0, 8 * f, -12 * f)
		p.WingR += V(0, -8 * f, 12 * f)
		jitter(p, t, 5, 4, {"Head", "Jaw"})
	end)
	-- 3) junta las manos, crea un orbe de fuego y te lo lanza
	if api.alive(v) then
		local CAST = table.clone(RISE)
		CAST.ArmL, CAST.ArmR, CAST.Jaw = V(80, -30, -10), V(80, 30, 10), V(-10, 0, 0)
		play(c, {{0, RISE}, {0.3, CAST}}, function()
			aim(c, home, v, 0.15, 60)
		end)
		local hl, hr = find(s, "ArmLFire"), find(s, "ArmRFire")
		local from = hl and hr and (hl.Position + hr.Position) / 2 or s.pos + V(0, 5, 0)
		local orb = Instance.new("Part")
		orb.Shape = Enum.PartType.Ball
		orb.Material = Enum.Material.Neon
		orb.Color = FIRE
		orb.Anchored, orb.CanCollide, orb.CanQuery, orb.CanTouch = true, false, false, false
		orb.Size = Vector3.one * 0.3
		orb.CFrame = CFrame.new(from)
		orb.Parent = workspace
		api.sound("Deep", m.Hitbox)
		tween(orb, 0.45, {Size = Vector3.one * 2})
		task.wait(0.45)
		orb:Destroy()
		local THROW = table.clone(RISE)
		THROW.ArmL, THROW.ArmR, THROW.Torso = V(110, 0, -20), V(110, 0, 20), V(-20, 0, 0)
		play(c, {{0, CAST}, {0.15, THROW, "in"}})
		api.sound("Whoosh", m.Hitbox)
		task.spawn(hurl, s, v, from, FIRE, 2.2, nil, 0.55)
		task.wait(0.5)
		api.addFear(v, s.def.fear * 0.4)
		api.fx(v, "scare", 1.6, FIRE)
	end
	-- 4) en guardia con las alas abiertas; si te acercas, te atrapa
	stalk(s, h, v, c, home, 3, 3.8, function(o)
		api.sound("Growl", m.Hitbox)
		play(c, {{0, Rig.current(c)}, {0.14, {Torso = V(-35, 0, 0), ArmL = V(100, 0, -10), ArmR = V(100, 0, 10), Jaw = V(-35, 0, 0), WingL = V(0, -20, -30), WingR = V(0, 20, 30)}, "out"}})
		grab(o, s)
	end, function(t)
		local p = full(c, RISE)
		p.Jaw = V(-8 - 8 * math.abs(math.sin(t * 3)), 0, 0)
		p.WingL += V(0, 0, -6 * math.sin(t * 2))
		p.WingR += V(0, 0, 6 * math.sin(t * 2))
		p.Tail += V(0, 30 * math.sin(t * 3), 0)
		p.Torso += V(3 * math.sin(t * 4), 0, 0)
		return p
	end, 60)
	Rig.blend(c, {}, 1.0, nil, home)
	for _, r in runes do
		tween(r.part, 0.8, {Color = r.color, Size = r.size})
	end
	unflare(pent, 1)
	unflare(eyes, 1)
	task.wait(4)
end

-- REY CALABAZA: carcajada con la corona en llamas, alza el cetro (onda de fuego) y te lanza sus tres calabazas una
-- tras otra. Te vigila desde lo alto: si te acercas, te atrapa.
function B.ReyCalabaza(s, h, v)
	local m = s.model
	local c = rigOf(s)
	local home = c:GetPivot()
	local crownL, crown = lightIn(s, "Crown")
	local fire = crown and crown:FindFirstChild("CrownFire")
	local faceL = lightIn(s, "FaceGlow")
	local ORANGE = Color3.fromRGB(255, 130, 30)
	-- 1) carcajada: la corona estalla en llamas
	api.sound("Laugh", m.Hitbox)
	flare(crownL, 5, 22, 0.2)
	flare(faceL, 4, 16, 0.2)
	if fire then
		fire.Rate = 70
	end
	emit(s, "Crown", "Flare", 40)
	local LAUGH = {Torso = V(10, 0, 0), Head = V(22, 0, 0), ArmL = V(30, 0, -60), ArmR = V(30, 0, 30), Cape = V(-20, 0, 0)}
	play(c, {{0, {}}, {0.3, LAUGH}, {1.0, LAUGH}}, function(p, t)
		aim(c, home, v, 0.12, 50)
		local b = math.abs(math.sin(t * 14))
		p.Torso += V(4 * b, 0, 0)
		p.Head += V(8 * b, 0, 0)
	end)
	-- 2) alza el cetro: onda de fuego...
	local RAISE = {Torso = V(-6, 0, 0), Head = V(-4, 0, 0), ArmR = V(170, 0, 10), ArmL = V(40, 0, -40), Cape = V(-30, 0, 0)}
	play(c, {{0, LAUGH}, {0.25, RAISE, "back"}}, function()
		aim(c, home, v, 0.2, 50)
	end)
	api.sound("Boom", m.Hitbox)
	wave(s.pos + V(0, 1, 0), ORANGE, 16, 0.5, 0.35)
	api.addFear(v, s.def.fear * 0.4)
	api.fx(v, "scare", 1.6, ORANGE)
	api.fx(v, "legend", s.def.name, Color3.fromRGB(255, 160, 40))
	-- ...y te lanza sus tres calabazas, una tras otra
	for k = 1, 3 do
		if not api.alive(v) then
			break
		end
		local lantern = group(s, "Lantern" .. k)
		local body = find(s, "Lantern" .. k)
		if #lantern > 0 and body then
			showParts(lantern, false)
			api.sound("Whoosh", m.Hitbox)
			task.spawn(hurl, s, v, body.Position + V(0, 1, 0), ORANGE, 1.4, lantern, 0.5)
			play(c, {{0, RAISE}, {0.12, {ArmR = V(120, 0, 10), Torso = V(-14, 0, 0), Cape = V(-10, 0, 0)}, "in"}, {0.3, RAISE, "out"}}, function()
				aim(c, home, v, 0.2, 50)
			end)
			task.wait(0.2)
			api.addFear(v, s.def.fear * 0.2)
		end
	end
	-- 3) te vigila desde lo alto; si te acercas, te atrapa
	stalk(s, h, v, c, home, 3, 3.6, function(o)
		api.sound("Laugh", m.Hitbox)
		play(c, {{0, Rig.current(c)}, {0.15, {Torso = V(-30, 0, 0), ArmL = V(100, 0, -10), ArmR = V(100, 0, 10), Cape = V(-40, 0, 0)}, "out"}})
		grab(o, s)
	end, function(t)
		local p = full(c, RAISE)
		p.ArmR += V(10 * math.sin(t * 3), 0, 0)
		p.Cape += V(6 * math.sin(t * 2.5), 0, 0)
		p.Head += V(0, 10 * math.sin(t * 1.5), 0)
		return p
	end, 50)
	Rig.blend(c, {}, 0.9, nil, home)
	for k = 1, 3 do
		showParts(group(s, "Lantern" .. k), true, 0.4)
	end
	if fire then
		fire.Rate = 18
	end
	unflare(crownL, 0.8)
	unflare(faceL, 0.8)
	task.wait(4)
end

-- los sustos especiales (Config: base = ...) hacen lo mismo que el susto en el que se basan
for t, def in Config.Scares do
	if def.base then
		B[t] = B[def.base]
	end
end

return B
