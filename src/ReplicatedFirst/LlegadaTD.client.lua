-- Llegada de un viaje del Tower Defense: la pantalla de viaje (LobbyUI, TeleportService:SetTeleportGui) se queda
-- en vez de la de carga de Roblox hasta que el jugador está en su mapa (partida) o en la calle (vuelta al lobby).
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local gui = TeleportService:GetArrivingTeleportGui()
if not gui then
	return
end
ReplicatedFirst:RemoveDefaultLoadingScreen()
local player = Players.LocalPlayer
gui.Parent = player:WaitForChild("PlayerGui")

-- a la partida: hasta entrar en el mapa; de vuelta: hasta tener personaje (y un momento para que cargue la calle)
local toMatch = gui:GetAttribute("To") == "match"
local t0 = os.clock()
while os.clock() - t0 < 30 do
	if toMatch and player:GetAttribute("Mode") == "td" then
		break
	end
	if not toMatch and player.Character and game:IsLoaded() then
		task.wait(1.5)
		break
	end
	task.wait(0.1)
end
local root = gui:FindFirstChild("Raiz")
if root and root:IsA("CanvasGroup") then
	TweenService:Create(root, TweenInfo.new(0.8), {GroupTransparency = 1}):Play()
	task.wait(0.85)
end
gui:Destroy()
