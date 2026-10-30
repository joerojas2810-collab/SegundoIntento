# Everforge World Visuals: implementación y prueba

## Apariencia elegida

Una sola dirección: **fantasía natural estilizada con la paleta voxel de Mineclonia**. El submod `mods/MISC/everforge_world_visuals` retexturiza follaje y algunas superficies naturales con una selección auditada de REFI Textures; muestra copas cruzadas menos cúbicas; reutiliza los arbustos, hierbas y hojarasca de Mineclonia; y añade tres conjuntos pétreos pequeños y no interactivos en zonas de colinas/montaña y bosque.

No se instaló REFI como paquete completo: se redistribuyen únicamente 19 texturas del mundo, sin importar temas GUI, launcher, logos o iconos. La fuente y las licencias se anotan en [`CREDITS.md`](../mods/MISC/everforge_world_visuals/CREDITS.md), con hashes reproducibles en [`ASSET_MANIFEST.json`](../mods/MISC/everforge_world_visuals/ASSET_MANIFEST.json). La geometría de follaje se adapta bajo AGPL-3.0-or-later de Bushy Leaves; el efecto se limita a IDs de hoja de Mineclonia y usa tres planos, no los nueve del original, para reducir la geometría por bloque.

## Alcance de mundo y compatibilidad de datos

- Los nodos y esquemas de árboles originales mantienen sus IDs, grupos, paletas, crecimiento, drops y recetas. La caja visual de follaje cambia, pero las cajas completas de colisión y selección se mantienen.
- Los grupos de piedras son nodos decorativos ocultos, no apuntables, no caminables, no minables, sin drops ni recetas; usan texturas y bloques base existentes.
- Las decoraciones nuevas se registran por dos rutas: `mcl_levelgen` para la generación propia de Mineclonia (incluido su uso habitual de `singlenode`) y `core.register_decoration` como compatibilidad con mapgens clásicos. La ruta de Mineclonia filtra los puntos para exigir suelo natural original y usa densidad baja. El motor solo genera decoraciones al crear terreno nuevo; el mod no recorre, regenera ni escribe mapblocks guardados, ni reemplaza construcciones.
- Las asignaciones de textura se ven también en bloques existentes, pero no cambian sus nombres ni guardado; se limitan a follaje, hierba, arbusto, hojarasca, césped y podzol no nevados.
- No se altera `mg_name`, semilla, `singlenode`, `v7`, terreno principal, ni se reemplaza la interfaz. El submod depende exclusivamente de módulos internos de Mineclonia ya incluidos.

## Validación disponible

En este entorno no hay ejecutable Luanti ni pantalla gráfica. Por eso no hay capturas de cliente, comparación de mundo antes/después ni medidas de FPS/tiempo de carga, y no se declara comprobado el rendimiento multijugador o la compatibilidad runtime exacta con Luanti 5.17.0 + Mineclonia 0.124.1. La validación estática comprueba syntax Lua, APIs y nodos de referencia, IDs de biomas, baja densidad, preservación de propiedades y hashes/dimensiones de las texturas. La prueba gráfica en un Mac sigue pendiente.

**Sobre `singlenode`:** no se cambia el mapgen. Mineclonia suele activar `mcl_levelgen` sobre el mapgen base `singlenode`; por eso el juego puede generar su terreno y biomas habituales sin sustituirlo por `v7`. Everforge registra arbustos y piedras también en la API `mcl_levelgen`, antes de `mcl_levelgen:freeze_top_layer`, y conserva los registros Core para otros mapgens. La prueba solicitada debe hacerse en mundo nuevo con semilla `12345`, `singlenode` y el `mcl_levelgen` de Mineclonia activado como en su configuración normal. Si el terreno propio de Mineclonia está desactivado, `singlenode` sí será vacío; no se debe cambiar a `v7` para compensarlo.

## Prueba local recomendada en macOS

1. Cerrar el juego/servidor y hacer una copia de seguridad de la carpeta `worlds/` y de la instalación actual.
2. Actualizar a la revisión del PR o copiar el directorio `mods/MISC/everforge_world_visuals` junto con los cambios de esta rama. No borrar, renombrar ni regenerar el mundo.
3. Reiniciar el servidor y todos los clientes de la partida; los PNG se entregan como medios del mod en multijugador. Confirmar al inicio que no haya advertencias de dependencias o texturas ausentes.
4. Abrir primero una copia de un mundo existente para revisar construcciones y árboles ya guardados. El cambio de follaje/texturas debe aparecer sin alterar posiciones, inventarios ni bloques; las piedras/arbustos nuevos deben limitarse a mapblocks que aún no se habían generado.
5. Para paisaje, crear un mundo temporal con semilla `12345`, mapgen `singlenode` y la configuración normal de Mineclonia con `mcl_levelgen` activo; no sustituirlo por `v7`. Verificar al inicio que Mineclonia no haya desactivado su generación de terreno.
6. Capturar bosques, pradera, ladera rocosa, varios biomas, campamento inicial y una construcción propia. Repetir en una zona nueva después de reiniciar y en sesión multijugador con otro cliente actualizado.
7. Medir inicio/carga, FPS o frametime en un bosque denso, uso de memoria, tiempo de generación y entrega de medios. Comparar capturas y el mismo recorrido con la versión anterior; registrar plataforma, resolución, distancia de visión y configuración. Si las copas cuestan demasiado, parar antes de activar en el servidor habitual y revisar el número de caras y densidad.

No se adjuntan capturas simuladas. Las evidencias visuales y de rendimiento deben proceder de una partida real en el Mac.
