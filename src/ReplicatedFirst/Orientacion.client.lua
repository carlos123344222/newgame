-- En móvil y tablet el juego va en horizontal (girando según cómo se sujete), desde el primer momento.
-- Roblox copia StarterGui.ScreenOrientation (en este juego "Sensor": también vertical) al PlayerGui al entrar, a
-- veces después de que arranque este script: por eso se vuelve a poner cada vez que cambie.
local Players = game:GetService("Players")

local WANT = Enum.ScreenOrientation.LandscapeSensor
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local function apply()
	if playerGui.ScreenOrientation ~= WANT then
		playerGui.ScreenOrientation = WANT
	end
end
playerGui:GetPropertyChangedSignal("ScreenOrientation"):Connect(apply)
apply()
if not game:IsLoaded() then
	game.Loaded:Wait()
end
apply()
