# Everforge — auditoría y guía de pruebas de la segunda fase

Alcance: integración de Everforge con Luanti 5.17.0 y Mineclonia 0.124.1 en esta rama. Esta revisión es estática del código y de las definiciones de mods disponibles en el repositorio; **no equivale a una sesión de juego**. No se alteran mundos existentes ni el motor.

## Resultado por pilar

| Pilar | Estado en código | Dependencias e integración | Pendiente de validar en juego |
|---|---|---|---|
| Progresión RPG | Clases persistentes, selección permanente, puntos de habilidad por cada cinco niveles de XP y cuatro habilidades con rangos. Física vía `playerphysics`; bonificación defensiva vía `mcl_damage`; bonus de XP cerca de guardianes. | `mcl_experience`, `mcl_player`, `playerphysics`, `mcl_damage`, `mcl_mobs`. | Persistencia tras reconectar/reiniciar; efectos, interfaz, costes y límites de rango en multijugador. |
| Forja modular | Se conserva la implementación previa: cabezales, uniones, mangos, catalizadores/calidad, estadísticas generadas y Alloy Melter. **Esta fase no rehace la forja.** El bonus de fundición toma el mayor bonus personal entre jugadores próximos, en vez de sumar los bonos de todos. | `mcl_tools`, `mcl_armor`, `mcl_enchanting`, `mcl_autogroup`, `toolranks`, `mcl_raw_ores`, `moreores`, `adamantine`, `mcl_furnaces`, `mcl_formspec`; integración del Melter con tolvas Mineclonia. | Fabricación de las combinaciones, persistencia de metadata/calidad al usar, encantar y reparar; combustible, tolvas, protección y reinicio del Melter. |
| Minerales y equipo | More Ores mantiene estaño, plata y mitrilo en bandas configuradas; Adamantina conserva su generación profunda. Las guías consultan la configuración activa, los grupos de minería, drops, recetas de cocción y materiales registrados. Se conserva el fallback `register_ore` junto a Mineclonia levelgen. Cobre de More Ores se omite si Mineclonia lo registra; estaño de More Ores se omite si ya existe `default:tin_ingot`. | `moreores`, `adamantine`, `mcl_levelgen`, `mcl_core`, `mcl_deepslate`, `mcl_raw_ores`. | Hallazgos reales en chunks nuevos y comportamiento con levelgen activado/desactivado; probar herramientas, silk touch, fortune, fundición y recetas. Los datos de frecuencia son estimaciones de colocación configurada, no conteos garantizados de nodos. |
| Mazmorras y recompensas | Funciones de colocación de estructuras de superficie, generadores y alijos. Los alijos permiten retirar recompensas, rechazan inserciones/movimientos, respetan protección y no se excavan mientras contienen objetos. La LBM refresca el texto/interfaz de alijos existentes sin borrar su inventario. | `mcl_levelgen`, `mcl_biomes`, `mcl_mobs`, `mcl_torches`; `mcl_loot` y `mcl_sounds` son opcionales. | Aparición por bioma, integridad estructural, loot, guardianes, protección, tolvas y comportamiento de alijos en mapas viejos y nuevos. |
| Escalado de dificultad | El escalado aplica solo a monstruos `mobs_mc:*` marcados como `type = "monster"`, cerca de jugadores, y únicamente en el supramundo. Se excluyen Nether/End/void para no convertir sus coordenadas negativas en dificultad extrema. Salud y daño se escalan por profundidad y marca de mazmorra. | `mcl_mobs`, `mcl_worlds`; selección del objetivo/dimensión con APIs Mineclonia. | Verificar límites efectivos, dificultad por profundidad, guardianes y que Nether/End no reciban el escalado de Everforge. Mods de mobs externos quedan fuera de este escalado. |

## Auditoría de More Ores y Adamantina

### More Ores

- En Mineclonia, los rangos activos de `_config.txt` son: estaño y plata en Y `0..-10`, `-11..-57` y `-58..-128`; mitrilo en `0..-20`, `-21..-57` y `-58..-128`.
- La guía in-game lee los valores cargados de `moreores` para las tres bandas, el tamaño de grupo y el número de minerales configurado. El cálculo de frecuencia coincide con la fórmula usada al registrar levelgen: `((rango_Y * 256 / chunk_size³) * ore_per_chunk / 8)`. Es una expectativa de colocaciones configuradas, no una promesa de nodos extraíbles.
- La ruta Mineclonia registra funciones de colocación de mineral en la etapa de menas; la ruta alternativa conserva `minetest.register_ore`. Ambas actúan en terreno generado posteriormente; no convierten bloques de chunks existentes.
- Los nodos dejan la pepita registrada y las recetas de cocción producen lingotes; el Alloy Melter también acepta pepitas de estaño, plata y mitrilo. Los grupos `pickaxey` de las menas indican estaño 3, plata 4 y mitrilo 5; WAILA solo presenta nivel cuando lee `pickaxey` real.
- Defecto de idioma localizado durante la auditoría: la traducción española no contenía `@1 Hoe` ni `Deepslate @1 Ore`. Se añadieron ambos patrones. El cobre existente de Mineclonia sigue siendo la fuente prioritaria y no se registra una segunda variante.

### Adamantina

- Los límites publicados por `adamantine.generation` proceden del registro activo: Y mínimo de Mineclonia (normalmente `-128`) a `-64`, tamaño de grupo `2`, filtro de rareza `4`; se registran variantes para piedra y pizarra profunda.
- Se conserva el fallback `register_ore` y el feature de Mineclonia levelgen. Por ello, la frecuencia que muestra la guía se expresa como un intento de feature cada cuatro chunks, no como un número garantizado de menas.
- El mineral requiere el nivel de pico derivado del grupo `pickaxey` real del pico de diamante (reserva de código `5` si la herramienta no expusiera el grupo). La mena deja `adamantine:lump`; la cocción da `adamantine:ingot`; herramientas/equipo y bloques son usos registrados.
- Los nombres y descripciones visibles del mod se pasan por el traductor `adamantine`; se añadió catálogo español sin cambiar identificadores, recetas ni nombres internos.

## WAILA y guía in-game

- WAILA usa `mcl_util.get_pointed_thing`, HUD de texto y consulta con intervalo configurable. `everforge_waila_enabled` permite el interruptor global y `/everforge_waila on|off` la preferencia individual; un jugador no puede saltarse un apagado global.
- Presenta nombre localizado, tipo cuando se identifica, herramienta sugerida y requisito solo para `pickaxey`. `axey`, `shovely`, `hoey`, `swordy` y `shearsy` describen herramienta/grupo, no un nivel inventado. También consulta infotext/estado de máquinas y etapa de cultivos cuando los metadatos o grupos del nodo lo permiten.
- La categoría **Minerals** reutiliza `doc` y su constructor de galería; reúne estaño, plata, mitrilo y adamantina con icono/nombre, dimensión, biomas registrados, generación activa, profundidad/frecuencia, requisito, drop, procesamiento y usos disponibles. Comando: `/everforge_minerals`.
- `doc` y `mcl_worlds` se declaran como dependencias directas de Everforge para no depender del orden accidental de carga.

## Idiomas y cobertura

- Los textos de Everforge están en el textdomain `everforge`, con catálogo inglés (`locale/template.pot`) y español (`locale/everforge.es.po`). Se incluyen RPG, chat, WAILA, guía, máquina, objetos/componentes, estadísticas y mazmorras.
- Adamantina usa `locale/adamantine.es.tr` y su `template.pot`; More Ores conserva sus traducciones y ahora cubre sus patrones de azada y mena de pizarra profunda.
- Los nombres de nodos/ítems, recetas y claves de metadata no se traducen. El formato estático `settingtypes.txt` no ofrece traducción por jugador; los nombres/descripciones de esos dos ajustes siguen siendo metadatos en inglés, aunque las opciones en juego sí pasan por el traductor.

## Dependencias y compatibilidad

Dependencias directas de Everforge: `mcl_init`, `mcl_experience`, `mcl_player`, `playerphysics`, `mcl_tools`, `mcl_armor`, `mcl_mobs`, `mcl_biomes`, `mcl_levelgen`, `mcl_core`, `mcl_chests`, `mcl_furnaces`, `mcl_formspec`, `mcl_util`, `mcl_worlds`, `doc`, `mcl_enchanting`, `mcl_autogroup`, `toolranks`, `mcl_damage`, `mcl_raw_ores`, `mcl_torches`, `moreores` y `adamantine`. Opcionales: `mcl_loot` y `mcl_sounds`.

No se añade ninguna dependencia remota ni se requiere que el jugador instale mods externos a los ya integrados en Mineclonia y el paquete. No se toca el motor ni se modifica/elimina contenido de mundos guardados. El único refresco de mundo existente es la LBM de interfaz de Alloy Melter/alijo, que conserva inventarios y metadata de recompensas.

## Verificación y pruebas pendientes

Comprobaciones estáticas ejecutadas tras las últimas ediciones: parser Lua para los cuatro archivos modificados; igualdad de las 142 cadenas de Everforge entre fuente, POT y PO español, incluidos placeholders; cobertura completa de cadenas fuente en los catálogos TR de Adamantina (33) y More Ores; y `git diff --check` sin errores. `msgfmt` no está instalado, así que el PO se revisó mediante validación propia de claves y placeholders, no con el compilador GNU. **No se lanzó Luanti en este entorno**, así que ninguna prueba descrita abajo debe interpretarse como prueba in-game completada.

1. Abrir un mundo de prueba Mineclonia nuevo en inglés y español; inspeccionar los formularios `/everforge` y `/everforge_minerals`, descripciones de ítems y nombres de menas. Confirmar que los identificadores/recetas siguen siendo los mismos.
2. Apuntar a piedra, menas, cultivos, cofres y máquinas con WAILA. Comparar requisito de pico con el grupo `pickaxey`; verificar que otros grupos no se presentan como niveles. Probar `/everforge_waila off`, `on`, preferencia por jugador y ajuste global desactivado.
3. Generar chunks nuevos y explorar las bandas indicadas; comparar piedra/pizarra profunda, biomas, frecuencia observada, drops, silk touch/fortune y procesamiento en horno y Alloy Melter. Repetir con Mineclonia levelgen desactivado para el fallback.
4. Fabricar herramientas modulares de varias calidades, usar/encantar/reparar y reiniciar; verificar límites de estadísticas y persistencia. Probar el Alloy Melter con cada pepita, combustible, tolvas, inventario y protección.
5. En un mundo de prueba, localizar ambas estructuras, abrir alijos, comprobar que no admiten insertar objetos, que la protección se respeta y que un alijo con contenido no se excava. Confirmar que la LBM no cambia loot guardado.
6. Comparar monstruos del supramundo a distintas profundidades; comprobar que el escalado solo afecta `mobs_mc` y no se aplica en Nether/End/void. Revisar multijugador para progresión y bonificaciones de fundición.
