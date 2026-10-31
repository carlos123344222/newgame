-- Monedas que sueltan los visitantes asustados. Todas giran y flotan un poco (solo en tu pantalla); las de TU casa,
-- cuando estás dentro y a menos de COIN_MAGNET, vuelan hacia ti y se recogen (el servidor comprueba y paga).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(RS:WaitForChild("Config"))
local Remote = RS:WaitForChild("Remote")
local player = Players.LocalPlayer
local Houses = workspace:WaitForChild("Casas")

local Monedas = {total = 0, onCollect = nil, paused = false} -- paused: el tutorial las deja en el suelo mientras enseña la escena

local SETTLE = 0.8 -- lo que tarda en caer (lo anima el servidor); después gira aquí
local seen = setmetatable({}, {__mode = "k"}) -- [moneda] = {t = cuando la vimos, base = posición en el suelo, phase}
local flying = setmetatable({}, {__mode = "k"}) -- [moneda] = true mientras vuela hacia ti

-- El servidor confirma una moneda recogida (Cliente lo llama al recibir "Coin")
function Monedas.collected(value)
	Monedas.total += value
	if Monedas.onCollect then
		task.spawn(Monedas.onCollect, value)
	end
end

local function myHouse()
	local plot = player:GetAttribute("Plot")
	return plot and Houses:FindFirstChild("Casa" .. plot)
end

local function attract(c, root)
	flying[c] = true
	local id = c:GetAttribute("Id")
	local t0 = os.clock()
	local from = c.Position
	task.spawn(function()
		while c.Parent and root.Parent and os.clock() - t0 < 0.28 do
			local a = (os.clock() - t0) / 0.28
			local to = root.Position + Vector3.new(0, 1, 0)
			c.CFrame = CFrame.new(from:Lerp(to, a * a) + Vector3.new(0, math.sin(a * math.pi) * 1.5, 0)) * CFrame.Angles(0, os.clock() * 20, 0)
			RunService.RenderStepped:Wait()
		end
		Remote:FireServer("Collect", id)
		task.wait(1.5)
		-- si el servidor no la ha aceptado, vuelve a su sitio
		if c.Parent then
			flying[c] = nil
			local s = seen[c]
			if s then
				c.CFrame = CFrame.new(s.base)
			end
		end
	end)
end

-- Con la Aspiradora de almas (servidor: atributo Sucked) la moneda sale disparada hacia la boca de la aspiradora del
-- jardín, girando y encogiéndose, y desaparece dentro (el servidor la borra y la paga)
local function suck(c, h)
	flying[c] = true
	local vac = h:FindFirstChild("Aspiradora")
	local mouth = vac and vac:FindFirstChild("Mouth", true)
	if not mouth then
		return
	end
	local t0 = os.clock()
	local from = c.Position
	local size = c.Size
	local dur = 0.42 + math.random() * 0.12
	task.spawn(function()
		while c.Parent and os.clock() - t0 < dur do
			local a = (os.clock() - t0) / dur
			local e = a * a
			local to = mouth.WorldPosition
			c.CFrame = CFrame.new(from:Lerp(to, e) + Vector3.new(0, math.sin(a * math.pi) * 3, 0)) * CFrame.Angles(0, os.clock() * 25, 0)
			c.Size = size * (1 - 0.7 * e)
			RunService.RenderStepped:Wait()
		end
		if c.Parent then
			c.Transparency = 1
		end
	end)
end

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	local camPos = workspace.CurrentCamera.CFrame.Position
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local mine = myHouse()
	local atHome = player:GetAttribute("Mode") == "home" and not Monedas.paused
	local parts, cframes = {}, {}
	for _, h in Houses:GetChildren() do
		local folder = h:FindFirstChild("Coins")
		if not folder then
			continue
		end
		for _, c in folder:GetChildren() do
			if flying[c] then
				continue
			end
			local s = seen[c]
			if not s then
				s = {t = t, phase = math.random() * 6.28}
				seen[c] = s
				c.Destroying:Once(function()
					seen[c] = nil
					flying[c] = nil
				end)
			end
			if t - s.t < SETTLE then
				continue -- todavía la está tirando el servidor
			end
			s.base = s.base or c.Position
			if c:GetAttribute("Sucked") then
				suck(c, h)
			elseif h == mine and atHome and root and (s.base - root.Position).Magnitude < Config.COIN_MAGNET then
				attract(c, root)
			elseif (s.base - camPos).Magnitude < 140 then
				table.insert(parts, c)
				table.insert(cframes, CFrame.new(s.base + Vector3.new(0, math.sin(t * 3 + s.phase) * 0.15, 0)) * CFrame.Angles(0, t * 2.4 + s.phase, 0))
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)

return Monedas
