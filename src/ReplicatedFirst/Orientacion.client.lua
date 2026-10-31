-- En móvil y tablet el juego va en horizontal (girando según cómo se sujete), desde el primer momento.
-- (StarterGui.ScreenOrientation solo se copia al PlayerGui al entrar; aquí se fija en el propio PlayerGui)
local Players = game:GetService("Players")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
