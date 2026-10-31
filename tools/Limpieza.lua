-- Limpieza de ServerStorage: borra copias viejas e importaciones que ya no usa ningún script.
-- Uso: copia todo este archivo, pégalo en la barra de comandos de Studio (abajo) y pulsa Enter. Se puede deshacer
-- con Ctrl+Z. Lo borrado sigue en "roblox copia.rbxl" (31/10/2026) por si hiciera falta algo.
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local BASURA = {
	-- versiones anteriores
	"ScaresAntiguos", "ScaresAntesRoblox", "ScaresAntesBloques", "LobbyArea_Antes", "CalabazasAntes",
	-- importaciones ya montadas en los mapas
	"ImportacionBlender", "ImportacionCalabazas", "ImportacionCalabazasNuevas", "ImportacionLobbyPlaza",
	"ImportacionMapaZombie", "ImportacionZombie", "ImportacionCarnaval",
	-- modelos sueltos sin usar
	"ModelosBlender", "ModelosCriaturas", "ModelosRobloxianos", "ModelosGenerados",
	-- herramientas muertas (localhost / workspace.ZombieHollow, que ya no existe)
	"_TowerGearBuilder", "ImportadorBlenderTD",
}

local id = ChangeHistoryService:TryBeginRecording("Limpieza")
local borrados = 0
for _, nombre in BASURA do
	local obj = ServerStorage:FindFirstChild(nombre)
	if obj then
		obj:Destroy()
		borrados += 1
	end
end
if id then
	ChangeHistoryService:FinishRecording(id, Enum.FinishRecordingOperation.Commit)
end
print(("Limpieza: %d de %d borrados"):format(borrados, #BASURA))
