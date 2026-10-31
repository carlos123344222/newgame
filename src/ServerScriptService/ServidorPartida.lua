-- ¿Es este el servidor de una partida del Tower Defense? Antes se deducía de "servidor privado sin dueño", pero
-- en el juego publicado hay jugadores que entran normalmente a servidores así, se tomaban por partida y se quedaban
-- atrapados en la pantalla "Heading back to the lobby". Ahora el servidor de lobbies apunta en MemoryStore cada servidor que reserva
-- para una partida (M.register) y aquí solo se cree partida el que esté apuntado.
-- En Studio, el atributo de Workspace "TestPartida" simula un servidor de partida (TDMaps).
local RunService = game:GetService("RunService")
local MemoryStoreService = game:GetService("MemoryStoreService")

local EXPIRA = 3600 -- segundos que dura el apunte (de sobra para que lleguen los jugadores)

local ok, partidas = pcall(MemoryStoreService.GetSortedMap, MemoryStoreService, "PartidasTD")
if not ok then
	partidas = nil
end

local M = {}

local function consultar()
	if RunService:IsStudio() then
		return workspace:GetAttribute("TestPartida") ~= nil
	end
	if game.PrivateServerId == "" or game.PrivateServerOwnerId ~= 0 or not partidas then
		return false
	end
	for intento = 1, 4 do
		local okGet, valor = pcall(partidas.GetAsync, partidas, game.PrivateServerId)
		if okGet then
			return valor ~= nil
		end
		warn("ServidorPartida: no se pudo consultar MemoryStore: " .. tostring(valor))
		task.wait(intento)
	end
	return false -- (sin respuesta: mejor un servidor normal que dejar a nadie atrapado)
end

M.isMatchServer = consultar()

-- Servidor de lobbies: apunta el servidor reservado (2º valor de ReserveServer) antes de mandar al grupo
function M.register(privateServerId)
	if not partidas then
		return false
	end
	local okSet, err = pcall(partidas.SetAsync, partidas, privateServerId, true, EXPIRA)
	if not okSet then
		warn("ServidorPartida: no se pudo apuntar la partida: " .. tostring(err))
	end
	return okSet
end

return M
