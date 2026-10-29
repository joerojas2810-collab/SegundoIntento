# Everforge World Visuals: implementación y prueba

## Apariencia elegida

Una sola dirección: **fantasía natural estilizada con la paleta voxel de Mineclonia**. El submod `mods/MISC/everforge_world_visuals` retexturiza follaje y algunas superficies naturales con una selección auditada de REFI Textures; muestra copas cruzadas menos cúbicas; reutiliza los arbustos, hierbas y hojarasca de Mineclonia; y añade tres conjuntos pétreos pequeños y no interactivos en zonas de colinas/montaña y bosque.

No se instaló REFI como paquete completo: se redistribuyen únicamente 19 texturas del mundo, sin importar temas GUI, launcher, logos o iconos. La fuente y las licencias se anotan en [`CREDITS.md`](../mods/MISC/everforge_world_visuals/CREDITS.md), con hashes reproducibles en [`ASSET_MANIFEST.json`](../mods/MISC/everforge_world_visuals/ASSET_MANIFEST.json). La geometría de follaje se adapta bajo AGPL-3.0-or-later de Bushy Leaves; el efecto se limita a IDs de hoja de Mineclonia y usa tres planos, no los nueve del original, para reducir la geometría por bloque.

## Alcance de mundo y compatibilidad de datos

- Los nodos y esquemas de árboles originales mantienen sus IDs, grupos, paletas, crecimiento, drops y recetas. La caja visual de follaje cambia, pero las cajas completas de colisión y selección se mantienen.
- Los grupos de piedras son nodos decorativos ocultos, no apuntables, no caminables, no minables, sin drops ni recetas; usan texturas y bloques base existentes.
- Las decoraciones nuevas se registran únicamente por `mcl_levelgen`, con `singlenode` recomendado. Se retiró la ruta Core de mapgens clásicos porque no ejecutaba el mismo filtro posterior a árboles y estructuras. Los mundos clásicos siguen cargando el mod y sus texturas, sin añadir estos detalles nuevos. La ruta de Mineclonia exige suelo natural en el heightmap original y aire libre en un volumen de 3×2×3; no sustituye plantas, árboles, agua, nieve ni nodos de construcciones. Mantiene densidad baja (2 intentos por chunk, con probabilidad 1/4 en bosque y 1/3 en montaña, antes de los filtros). El motor solo genera decoraciones al crear terreno nuevo; el mod no recorre, regenera ni escribe mapblocks guardados, ni reemplaza construcciones.
- Las asignaciones de textura se ven también en bloques existentes, pero no cambian sus nombres ni guardado; se limitan a follaje, hierba, arbusto, hojarasca, césped y podzol no nevados.
- No se altera `mg_name`, semilla, `singlenode`, `v7`, terreno principal, ni se reemplaza la interfaz. El submod depende exclusivamente de módulos internos de Mineclonia ya incluidos.

## Validación disponible

La revisión del 29/10/2026 usa Luanti 5.17.0 sin ventana, mundos desechables y pruebas de Lua. **No hay validación gráfica ni medición de FPS.** Los resultados técnicos y comandos reproducibles se registran en `docs/everforge-world-visuals-validation.md`. No se afirma compatibilidad universal con todos los mundos, versiones del motor o configuraciones.

Se corrigieron tres defectos de la rama original: índice 12 inexistente (la etapa superficial real es la 11), ausencia de césped en los apoyos de piedras de bosque y textura `mcl_core_stone.png` inexistente (se usa `default_stone.png`). Las pruebas ejecutan las tablas reales de biomas y el registro nativo para detectar regresiones de etapa; también comprueban obstáculos y conservación de propiedades funcionales de hojas.

**Sobre `singlenode`:** no se cambia el mapgen. Mineclonia suele activar `mcl_levelgen` sobre el mapgen base `singlenode`; por eso el juego puede generar su terreno y biomas habituales sin sustituirlo por `v7`. Everforge registra arbustos y piedras también en la API `mcl_levelgen`, antes de `mcl_levelgen:freeze_top_layer`, en la etapa 11 de esta versión; los mapgens clásicos conservan la carga visual, sin registros Core nuevos. Se admite cualquier semilla válida, incluidas semillas aleatorias; `12345` solo reproduce la prueba de referencia. Se mantiene `singlenode` con `mcl_levelgen` activo. La revisión multisemilla y sus resultados están en [validación de generación](everforge-worldgen-seeds.md). Si el terreno propio de Mineclonia está desactivado, `singlenode` sí será vacío; no se debe cambiar a `v7` para compensarlo.

## Prueba local recomendada en macOS

1. Cerrar el juego/servidor y hacer una copia de seguridad de la carpeta `worlds/` y de la instalación actual.
2. Actualizar `main` con `git pull --ff-only origin main` desde la carpeta del repositorio Everforge. No borrar, renombrar ni regenerar el mundo.
3. Reiniciar el servidor y todos los clientes de la partida; los PNG se entregan como medios del mod en multijugador. Confirmar al inicio que no haya advertencias de dependencias o texturas ausentes.
4. Abrir primero una copia de un mundo existente para revisar construcciones y árboles ya guardados. El cambio de follaje/texturas debe aparecer sin alterar posiciones, inventarios ni bloques; las piedras/arbustos nuevos deben limitarse a mapblocks que aún no se habían generado.
5. Para paisaje, crear un mundo temporal con semilla libre o aleatoria (`12345` solo para comparar con la referencia), mapgen `singlenode` y la configuración normal de Mineclonia con `mcl_levelgen` activo; no sustituirlo por `v7`. Verificar al inicio que Mineclonia no haya desactivado su generación de terreno.
6. Capturar bosques, pradera, ladera rocosa, varios biomas, campamento inicial y una construcción propia. Repetir en una zona nueva después de reiniciar y en sesión multijugador con otro cliente actualizado.
7. Medir inicio/carga, FPS o frametime en un bosque denso, uso de memoria, tiempo de generación y entrega de medios. Comparar capturas y el mismo recorrido con la versión anterior; registrar plataforma, resolución, distancia de visión y configuración. Si las copas cuestan demasiado, parar antes de activar en el servidor habitual y revisar el número de caras y densidad.

No se adjuntan capturas simuladas. Las evidencias visuales y de rendimiento deben proceder de una partida real en el Mac.
