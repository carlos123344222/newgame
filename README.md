# Tu Casa Encantada

Juego de Roblox. Los scripts se sincronizan con Roblox Studio mediante [Rojo](https://rojo.space/) 7.

## Qué controla Rojo

Solo los **79 scripts** de `src/`. Todo lo demás (mapas, modelos, `Assets`, interfaz, sonidos...) sigue
viviendo en el archivo de Studio y Rojo no lo toca (`$ignoreUnknownInstances` en todos los servicios).

| Carpeta | En Studio |
| --- | --- |
| `src/ReplicatedFirst` | ReplicatedFirst |
| `src/ReplicatedStorage` | ReplicatedStorage |
| `src/ServerScriptService` | ServerScriptService |
| `src/ServerStorage` | ServerStorage |
| `src/StarterPlayerScripts` | StarterPlayer → StarterPlayerScripts |
| `src/StarterCharacterScripts` | StarterPlayer → StarterCharacterScripts |

Los scripts metidos dentro de modelos (`ServerStorage/Bot/Animate` y los `HauntServer` / `HauntClient` de cada
`Casa*`) **no** están en Rojo: se editan en Studio.

Extensiones: `.server.lua` = Script, `.client.lua` = LocalScript, `.lua` = ModuleScript.

## Cómo conectarlo

1. `git pull`
2. `rojo serve` (en esta carpeta)
3. En Studio, con **este** juego abierto: Plugins → Rojo → **Connect**.

Importante: con Rojo conectado, los cambios a esos 79 scripts se hacen en los archivos de `src/`. Si los
editas a mano en Studio, se pierden en la siguiente sincronización.

`roblox copia.rbxl` es una copia del juego completo (del 31/10/2026), por si hace falta recuperar algo.

## Herramientas

`tools/Limpieza.lua`: borra de `ServerStorage` las copias viejas e importaciones que ya no usa nada. Se pega en la
barra de comandos de Studio (se puede deshacer con Ctrl+Z).
