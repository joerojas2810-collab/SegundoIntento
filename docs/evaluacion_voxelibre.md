# Evaluación: paisajes de VoxeLibre vs. Mineclonia (Everforge)

> Investigación únicamente. No se ha modificado ningún mod ni archivo de `mods/`.

## Resumen ejecutivo

Mineclonia (lo que usa Everforge) **no es un motor distinto a VoxeLibre: es un fork directo de VoxeLibre/MineClone2** con el mismo árbol de mods de mapgen (`mcl_biomes`, `mcl_mapgen_core`, `mcl_terrain_features`, `mcl_structures`, `mcl_dungeons`, `mcl_villages`, `mcl_strongholds`, `mcl_nether_fortresses`, `mcl_end_island`, `tsm_railcorridors` — los mismos nombres de mod existen en ambos proyectos). La comparación, por tanto, no es "dos juegos de generación de terreno distintos", sino **versiones divergentes del mismo linaje de código**, que se separaron en algún punto y evolucionaron con parches propios.

Verificado en este repo: `mods/MAPGEN/mcl_biomes/init.lua` ya registra **131 entradas de `register_biome`** (variantes de océano/playa/nieve incluidas), y entre ellas ya están `CherryGrove`, `PaleGarden`, `Grove`, `SnowySlopes`, `FrozenPeaks`, `JaggedPeaks`, `StonyPeaks`, `SunflowerPlains` — biomas de las actualizaciones 1.17–1.19 de Minecraft que VoxeLibre también implementa. Esto indica que **la rama de Mineclonia usada aquí ya está razonablemente actualizada** respecto al conjunto de biomas "moderno" de VoxeLibre; no hay un salto generacional claro que justifique traer todo el generador de VoxeLibre.

Conclusión: **no conviene reemplazar ni mezclar el motor de mapgen**. El margen de mejora real y de bajo riesgo está en **texturas puntuales, paletas de color y detalles de decoración** que VoxeLibre pueda haber refinado después de la bifurcación — no en biomas nuevos ni en el generador en sí.

## Diferencias visuales reales

No se pudo clonar ni diffear el código fuente línea por línea de VoxeLibre en esta pasada (el repositorio oficial en git.minetest.land está detrás de un bloqueo anti-bot "Anubis"; el mirror de GitHub no permite navegar el árbol de archivos vía fetch sin un cliente de git). Lo que sigue se basa en las páginas públicas del proyecto, su documentación (`LEGAL.md`, `TEXTURES.md`) y en la estructura de mods confirmada:

- **Biomas**: la propia página de VoxeLibre se anuncia con "28 biomas + 5 biomas del Nether". Este repo ya tiene más entradas de bioma registradas (131, aunque muchas son variantes de playa/océano/altura del mismo bioma base). No hay evidencia de que VoxeLibre tenga biomas *visualmente* ausentes aquí; el fork Mineclonia-propiamente-dicho (que es la base de este repo, no VoxeLibre) afirma en su propia documentación llegar a 58 biomas de Overworld con su generador Lua a medida, compatible con semillas de Minecraft — es decir, ya superior en variedad a VoxeLibre "vanilla".
- **Árboles y vegetación**: VoxeLibre documenta texturas de cerezo (cherry wood/particles) añadidas y refinadas por colaboradores (Nova_Wostra, EmoryNB) después de separarse de Mineclonia. Este repo ya tiene el bioma `CherryGrove` registrado, pero no se pudo confirmar sin clonar el repo si usa exactamente las mismas texturas de corteza/hoja o una versión anterior/distinta.
- **Agua y texturas**: no se encontró documentación pública que describa un sistema de agua distinto (shaders, animación) entre ambos; ambos corren sobre el mismo motor Luanti y las mismas capacidades de nodo líquido, así que cualquier diferencia visible sería de **textura** (paleta de color, animación de frames), no de mecanismo.
- **Conclusión de esta sección**: las diferencias reales más probables son de **afinado de texturas y paletas** en biomas compartidos (p. ej. terracota vidriada, bloque de carbón, cerezo), no de biomas, árboles o generación de agua estructuralmente distintos.

## Qué puede reutilizarse sin reemplazar Mineclonia

Bajo riesgo, posible beneficio visual:

- **Texturas puntuales** citadas en la documentación de VoxeLibre como mejoras sobre la base Pixel-Perfection: terracota vidriada (`MysticTempest`), bloque de carbón (`blitzdoughnuts`), partículas y madera de cerezo (`Nova_Wostra`/`EmoryNB`). Si estas texturas no están ya en `mods/ITEMS/mcl_core` o `mods/ITEMS/mcl_trees` de este repo, se podrían importar como *overrides* de textura (mismo nombre de archivo PNG) sin tocar ni una línea de Lua de mapgen.
- **Paletas de color de bioma** (si VoxeLibre ajustó el tinte de hoja/pasto de algún bioma): esto vive en PNGs de paleta, no en código; es un reemplazo de asset, cero riesgo para la lógica de mapgen.
- **Detalles de decoración aislados** (una nueva variante de roca, una flor, un arbusto) si están implementados como `register_decoration` independiente: se pueden portar como mod opcional aparte, sin modificar `mcl_biomes` ni `mcl_mapgen_core`.

## Qué exigiría tocar `mcl_levelgen` o el núcleo de mapgen

- **Nada de lo evaluado aquí lo exige**, siempre que el objetivo sea solo textura/paleta/decoración puntual. `mcl_levelgen` es el sistema de *structure blocks* / jigsaw usado para estructuras pre-fabricadas (mansiones, etc.), no para biomas ni vegetación de terreno — no debería tocarse para un cambio puramente visual de paisaje.
- Tocar `mcl_mapgen_core` o `mcl_biomes` sería necesario únicamente si se quisiera: (a) añadir un bioma que no existe aquí, (b) cambiar las curvas de ruido/alturas de terreno, o (c) cambiar las reglas de qué decoración aparece en qué bioma con qué densidad. Ninguno de estos casos parece necesario dado que el repo ya iguala o supera la variedad de biomas de VoxeLibre.

## Licencias y dependencias

- **Este repo**: `LICENSE.txt` en la raíz es **GPL-3.0** (confirmado). `mods/MAPGEN/mcl_biomes/LICENSE` es **MIT** para el código de ese mod puntual (confirmado leyendo el archivo).
- **VoxeLibre**: código bajo **GPL-3.0** (algunos mods empaquetados tienen licencia propia y son de doble licencia GPLv3/la suya). Medios (texturas, modelos, sonidos): por defecto **CC BY-SA 3.0 Unported**; excepciones puntuales en **CC BY-SA 4.0** (terracota vidriada, carbón, cerezo), **CC BY 4.0** (modelos de armor trim) y **CC0** (imágenes de menú). La base de la mayoría de texturas es el pack *Pixel Perfection* de XSSheep.
- **Compatibilidad**: GPL-3.0 (código) es compatible con el GPL-3.0 de este repo. CC BY-SA (texturas) es compatible en la práctica con proyectos GPL para *assets* (no es código), siempre que se mantenga la atribución exigida por CC BY-SA al importar esos archivos puntuales — basta documentar el autor original en el changelog o un `CREDITS`/`README` del mod que reciba la textura.
- **Dependencias**: al tratarse del mismo linaje de mods, no se detectó ninguna dependencia nueva de motor (ambos corren en Luanti/Minetest). Importar una textura aislada no añade dependencias; importar un mod de decoración completo podría requerir revisar sus `depends.txt` por si referencia mods que no están en este repo.

## Recomendaciones priorizadas (impacto / riesgo)

1. **Alto impacto, riesgo mínimo**: diffear únicamente las texturas PNG de `CherryGrove`/madera de cerezo, terracota vidriada y carbón entre este repo y VoxeLibre (requiere clonar VoxeLibre una vez, fuera de este repo, y comparar carpetas `textures/`). Si hay diferencias visibles, copiar solo esos PNG como overrides, respetando la atribución CC BY-SA.
2. **Impacto medio, riesgo bajo**: revisar si existe alguna decoración de bioma (roca, arbusto, variante de hierba) registrada en VoxeLibre y ausente aquí vía `register_decoration`; portarla como mod aparte sin tocar `mcl_biomes`.
3. **Impacto bajo, riesgo bajo**: ninguna acción sobre `mcl_mapgen_core`/`mcl_levelgen` — el generador actual ya es competitivo en variedad de biomas; cualquier cambio ahí tiene riesgo de romper la integración ya hecha con la aventura "El sello de las ruinas" (que depende de altura de terreno y biomas concretos) para un beneficio visual incierto.
4. **No recomendado**: sustituir o fusionar el generador de mapgen de VoxeLibre sobre el de Mineclonia — confirma lo que ya pedía el usuario ("no sustituyas Mineclonia"): ambos proyectos son el mismo linaje, así que el "upgrade" real está en assets sueltos, no en el motor.

## Limitaciones de esta evaluación

No fue posible clonar el repositorio de VoxeLibre en esta pasada (bloqueo anti-bot del host oficial, y el mirror de GitHub no se pudo navegar archivo por archivo sin `git clone`). Las afirmaciones sobre conteo de biomas, autores de textura y licencias de medios se basan en las páginas públicas y documentación (`LEGAL.md`, descripciones de proyecto) citadas, no en una comparación binaria de PNG. Antes de portar cualquier textura, se recomienda clonar `https://github.com/VoxeLibre/VoxeLibre` (mirror) en una carpeta fuera de este repo y comparar directamente los archivos de `textures/` mencionados arriba.
