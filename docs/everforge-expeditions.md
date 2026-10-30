# Everforge — El sello de las ruinas

Aventura cooperativa de 15–20 minutos para **Luanti 5.17 + Everforge** (Mineclonia).
No usa mods externos, dimensiones de End/Nether ni logros de Minecraft. El
combate, la forja probabilística, las habilidades y el inventario existentes no
se modifican.

## Recorrido

1. La **Maestra de expediciones** está junto a la hoguera del campamento. Al
   aceptar, la expedición queda armada para el líder y hasta 3 acompañantes.
2. El grupo se prepara en el cofre del campamento (espada de piedra, antorchas,
   pan y piedra) y viaja con la **piedra de viaje azul** al sendero de la ruina.
   El sendero está a 26 bloques de la puerta, como pide el diseño.
3. La fortaleza tiene patio, muralla almenada, dos torres de puerta, torreón con
   salón, biblioteca, armería y solar, y una **cripta subterránea** con cinco
   salas: entrada, salón de los ecos, barracones, cisterna y cámara del sello.
4. Tres encuentros controlados (entrada, salón y cámara final) usan esqueletos
   y zombis nativos. Solo aparecen una vez; no hay respawns infinitos.
   Dificultad: 1 guardián por sala en solitario y 1 extra por sala con dos
   jugadores; la cámara final añade otro.
5. El **Sello de las Ruinas** se toma del pedestal de la cámara final. El
   portador vuelve por una piedra de viaje y lo entrega a la Maestra.
6. La recompensa (8 hierro, 3 oro y 6 panes) se entrega **una sola vez por
   participante**, incluso si estaba desconectado al terminar.

## Persistencia y seguridad

- El estado vive en `core.get_mod_storage()` (`everforge:ruins_quest:v1`), no en
  logros. La pertenencia se guarda por nombre de jugador.
- El sitio se construye una sola vez (`everforge:ruins_site:v1`). Al reabrir el
  mundo no se regenera ni se pisa lo que el jugador haya cambiado.
- El sello es único: un portador, un objeto de pila máxima 1 y una bandera de
  entrega. Un miembro desconectado conserva su pertenencia, su HUD y su
  recompensa pendiente.
- Si el portador pierde el sello, solo él puede recuperarlo del pedestal; nadie
  más puede duplicarlo.

## Archivos

| Ruta | Función |
| --- | --- |
| `mods/MISC/everforge/ruins_quest.lua` | Estado, formularios, waystones, encuentros, pedestal y recompensa |
| `mods/MISC/everforge/expedition.lua` | NPC Maestra, invitaciones y misiones compartidas |
| `mods/MISC/everforge/expedition_model.lua` | Modelo persistente y validación |
| `mods/MISC/everforge/schematics/sello_ruinas.{mts,json}` | Fortaleza original y manifiesto de salas/spawns |
| `tools/build_sello_ruins.py` | Constructor determinista + autoverificación |
| `playtest/el_sello_de_las_ruinas/` | Mundo preparado (singlenode) y worldmod de montaje |
| `Jugar El Sello de las Ruinas.command` | Lanzador macOS |

## Verificación

Comprobado en este entorno:

- Sintaxis Lua 5.1 de los módulos y del worldmod con un parser independiente.
- `tools/test_everforge_expedition.lua`: 59 comprobaciones del sistema de
  expediciones (formularios, invitaciones, desconexión/reconexión, persistencia).
- `tools/test_everforge_ruins_quest.lua`: 35 comprobaciones del flujo completo
  (inicio, kit, viaje, tres encuentros sin respawn, sello único, entrega,
  recompensa única, miembro desconectado y estado corrupto).
- `tools/build_sello_ruins.py`: autoverificación del `.mts` (conectividad a pie,
  puertas, antorchas, marcadores, spawns y pila del pedestal) sin errores.
- Simulación del worldmod con un `core` mínimo: 68.368 nodos de plataforma y
  camino, llamadas de campamento/sitio, y kit inicial que no se duplica.
- Pruebas existentes de selección de sitio, onboarding e interfaces.

**No verificado:** no hay binario de Luanti en este entorno ni pantalla, por lo
que no se ejecutó una partida gráfica real, no se probaron dos clientes y no hay
capturas de juego auténticas. La primera partida en el Mac debe considerarse la
validación gráfica pendiente. Si algo falla, el diagnóstico `/sello` solo lee el
estado y la posición; no concede privilegios ni completa la misión.

## Legal

La estructura y los módulos de esta aventura son originales (GPL-3.0-or-later,
igual que Everforge). `visual_test/gondor_fort/` es material CC BY-SA 3.0 de
Lord of the Test usado solo como referencia local de evaluación; **no forma
parte** del mundo preparado y no debe distribuirse sin revisión legal.
