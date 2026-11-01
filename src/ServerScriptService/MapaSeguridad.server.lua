-- Red de seguridad del mapa: si alguien cae al barranco o se sale de los límites (un empujón raro, un fallo de física),
-- vuelve a un sitio seguro en vez de quedarse atrapado. Los límites son los del mapa nuevo (workspace.Mapa).
local Players = game:GetService("Players")
local TDMaps = require(script.Parent.TDMaps) -- los mapas del Tower Defense tienen su propia red

local BRIDGE = CFrame.lookAt(Vector3.new(150, 3.5, 0), Vector3.new(178, 3.5, 0))
local PLAZA = CFrame.lookAt(Vector3.new(-162, 3.5, 0), Vector3.new(-128, 3.5, 0))

local function inside(p)
	if p.Y < -12 then
		return false
	end
	local x, z = p.X, math.abs(p.Z)
	return (x >= -300 and x <= -96 and z <= 142) or (x > -100 and x <= 129 and z <= 128) or (x > 129 and x < 171 and z <= 7)
		or (x >= 171 and x <= 355 and z <= 102)
end

-- Paredes invisibles de encima de las vallas entre casas (workspace.Mapa.Calle.Cierres.Tapas): se quitan para que se
-- pueda saltar la valla y pasar entre las casas. (Las vallas que se ven, los WallFence, se quedan.)
local cierres = workspace:FindFirstChild("Mapa") and workspace.Mapa:FindFirstChild("Calle") and workspace.Mapa.Calle:FindFirstChild("Cierres")
local tapas = cierres and cierres:FindFirstChild("Tapas")
if tapas then
	tapas:Destroy()
end

while true do
	task.wait(0.5)
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local td = TDMaps.of(plr)
		if root and hum and hum.Health > 0 and td then
			if not td.contains(root.Position) then
				td.rescue(plr)
				root.AssemblyLinearVelocity = Vector3.zero
			end
		elseif root and hum and hum.Health > 0 and not inside(root.Position) then
			-- en el barranco: al puente; en cualquier otro sitio: a la plaza
			local x = root.Position.X
			char:PivotTo((x > 118 and x < 182) and BRIDGE or PLAZA)
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end
