-- Cursed Carnival (cliente): las atracciones se mueven mientras estás en el mapa. Gira lo que se llama "spin_..."
-- (noria, tiovivo, sillas voladoras), las cabinas de la noria cuelgan siempre derechas y el anillo de la torre de caída
-- ("car_...") sube despacio y cae de golpe. Las piezas están ancladas: solo se mueven en tu pantalla.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
-- (el mapa solo se carga en las partidas que lo juegan)
local map = workspace:FindFirstChild("CursedCarnival")
while not map do
	local c = workspace.ChildAdded:Wait()
	map = c.Name == "CursedCarnival" and c or nil
end
local rides = map:WaitForChild("Atracciones", 30)
if not rides then
	return
end
-- (el mapa llega por partes: se espera a que dejen de llegar piezas)
local count = -1
for _ = 1, 30 do
	local n = #rides:GetDescendants()
	if n > 0 and n == count then
		break
	end
	count = n
	task.wait(0.4)
end

-- velocidad (rad/s) y eje de giro de cada atracción, relativo a su pivote
local SPIN = {
	FerrisWheel = {speed = 0.12, hub = Vector3.new(0, 30, 0), axis = "Z", radius = 24},
	Carousel = {speed = 0.55, hub = Vector3.zero, axis = "Y"},
	SwingRide = {speed = 1.1, hub = Vector3.zero, axis = "Y"},
}

local anims = {}
for _, m in rides:GetChildren() do
	local kind = m:GetAttribute("Asset")
	local cfg = SPIN[kind]
	local pivot = m:GetPivot()
	if cfg then
		local hub = pivot * CFrame.new(cfg.hub)
		local a = {cfg = cfg, hub = hub, parts = {}, cabs = {}, phase = math.random() * 6}
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") and p.Name:sub(1, 5) == "spin_" then
				a.parts[p] = hub:ToObjectSpace(p.CFrame)
			end
		end
		for _, c in m:GetChildren() do
			if c:IsA("Model") and c:GetAttribute("Cab") then
				table.insert(a.cabs, {model = c, k = c:GetAttribute("Cab"), n = c:GetAttribute("Cabs")})
			end
		end
		table.insert(anims, a)
	elseif kind == "DropTower" then
		local a = {drop = true, base = pivot, parts = {}, phase = math.random() * 10}
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") and p.Name:sub(1, 4) == "car_" then
				a.parts[p] = pivot:ToObjectSpace(p.CFrame)
			end
		end
		table.insert(anims, a)
	end
end

-- Torre: 7 s subiendo, 2 s arriba, caída en 0.9 s, 2 s abajo
local function dropHeight(t)
	t %= 11.9
	if t < 7 then
		return 40 * (t / 7) ^ 1.3
	elseif t < 9 then
		return 40
	elseif t < 9.9 then
		local k = (t - 9) / 0.9
		return 40 * (1 - k * k)
	end
	return 0
end

local function active()
	if player:GetAttribute("TDMap") == map.Name then
		return true
	end
	local cam = workspace.CurrentCamera
	return cam and (cam.CFrame.Position - map:GetAttribute("Origin").Position).Magnitude < 450
end

local acc = 0
RunService.RenderStepped:Connect(function(dt)
	acc += dt
	if acc < 1 / 30 then -- 30 veces por segundo basta
		return
	end
	acc = 0
	if not active() then
		return
	end
	local t = os.clock()
	for _, a in anims do
		if a.drop then
			local up = CFrame.new(0, dropHeight(t + a.phase), 0)
			for p, off in a.parts do
				p.CFrame = a.base * up * off
			end
		else
			local ang = (t + a.phase) * a.cfg.speed
			local rot = a.cfg.axis == "Z" and CFrame.Angles(0, 0, ang) or CFrame.Angles(0, ang, 0)
			local cf = a.hub * rot
			for p, off in a.parts do
				p.CFrame = cf * off
			end
			for _, c in a.cabs do
				local th = ang + c.k / c.n * math.pi * 2
				local pos = (a.hub * CFrame.new(math.cos(th) * a.cfg.radius, math.sin(th) * a.cfg.radius, 0)).Position
				c.model:PivotTo(CFrame.new(pos) * a.hub.Rotation)
			end
		end
	end
end)
