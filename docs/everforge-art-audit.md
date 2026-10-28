# EVERFORGE — Auditoría artística y visual integral

**Fecha de corte:** 28 de octubre de 2026

**Base inspeccionada:** checkout de `SegundoIntento`; Mineclonia 0.124.1 como objetivo y Luanti 5.17.0 como objetivo de runtime.

**Alcance:** inspección estática de medios, referencias desde Lua, formas, modelos, sonidos, licencias y documentación. No se cambiaron recursos ni código del juego; no se instalaron mods/paquetes ni se ejecutó una partida.

## 1. Resumen ejecutivo

Mineclonia ya trae un inventario visual muy amplio y coherente con el lenguaje voxel/pixel-art: **3.292 PNG, 85 modelos B3D, 88 OBJ, 447 OGG y 186 esquemas `.mts`** bajo `mods/`. La mayor parte de las texturas de los mods son PNG de 16×16 (1.887 archivos en el recuento); hay atlases, sprites de interfaz, texturas de skin, animación de texturas y assets mayores. El juego ya proporciona criaturas animadas, aldeanos, armadura visible, personalización de jugador, HUD/formspec, partículas, clima y sonido. Por tanto, la prioridad visual debe ser elegir/conectar estos recursos, no crear reemplazos globales.

Everforge tiene una identidad de interfaz reconocible —grafito/hierro oscuro, acento cobre y marfil— limitada a sus formspecs. Conserva en `menu/header.png` el logo de Everforge seleccionado por el usuario; el icono del menú continúa siendo el bloque de césped de Mineclonia. Las interfaces actuales ya usan paneles, botones y slots propios, y también conservan recursos visuales nativos para fuego/progreso del horno.

La parte de mundo reutiliza deliberadamente la estética base: More Ores proporciona menas/metales pixel-art de 16×16; Adamantine recolorea texturas de diamante/netherita; las estructuras se forman con nodos Mineclonia colocados por código; los guardianes son esqueletos, stray y zombis nativos. Esto es compatible y económico, pero Everforge no tiene actualmente modelos, texturas de enemigos, animaciones, partículas, audio ni música propios.

**Brechas de mayor impacto visual:**

1. El logo del menú y el icono de césped no comparten identidad; los seis fondos de menú son paisajes desenfocados generales, no arte de Everforge.
2. El formulario RPG es un panel de texto/botones y ranks, no un árbol visual: no hay iconografía de skills ni diagramas. Esto describe la UI actual; no propone nuevas clases ni requisitos.
3. La calidad de las herramientas se ve sobre todo en el texto/tooltip de color y en las estadísticas, no mediante un icono, borde, modelo o efecto distinto en el objeto.
4. Los componentes modulares emplean seis siluetas de Melterns (16×16) y las herramientas emplean iconos nativos tintados. Los materiales son separables por color y descripción, pero no por una señal geométrica adicional.
5. El Cementerio/Torre de Hielo son generados con geometría de bloques sencilla y materiales vanilla; el “guardián” no tiene apariencia singular. La Torre sí se reconoce por su paleta de packed/blue ice.
6. El relic, alijo y spawner reutilizan iconos/tiles tintados o superpuestos, útiles pero visualmente provisionales frente al tratamiento más pulido de los elementos nativos.
7. El registro no identifica sonidos o música dedicados de Everforge: las herramientas y máquinas toman audio estándar de Mineclonia.

**Recomendación:** mantener el mundo en el lenguaje visual Mineclonia, preservar el logo, conservar la paleta Everforge solo dentro de UI propia y mejorar primero contraste/identificación usando icons, texturas, modelos, partículas y audio ya existentes. Crear arte nuevo solo si una prueba visual concreta demuestra un vacío que no resuelve la reutilización.

## 2. Inventario visual del repositorio

### 2.1 Recuento y formatos

Recuento por extensión en `mods/` (conteo de archivos, no de recursos únicos ni del consumo final de memoria):

| Tipo | Cantidad observada | Usos/observaciones |
|---|---:|---|
| `.png` | 3.292 | Bloques, objetos, atlas, skins, HUD, iconos, partículas, texturas animadas y fondos |
| `.b3d` | 85 | Modelos 3D de entidades/personajes/vehículos, varios con huesos y frames de animación |
| `.obj` | 88 | Modelos de objetos/armaduras/entidades y piezas de skin |
| `.ogg` | 447 | Efectos de bloques, herramientas, entidades, música de jukebox, etc. |
| `.mts` | 186 | Esquemas de estructuras de `mcl_levelgen` y otros mods de mapgen |

No aparecen archivos de audio `.wav`/`.mp3` ni modelos `.gltf`/`.glb` en el recuento por extensiones revisadas. PNG sigue siendo el principal formato visual. De los PNG, 1.887 son 16×16; hay además sprites de skin 64×32/64×64, sprites más grandes, atlases y paneles. La combinación de dimensiones obedece a usos diferentes; no son todos tiles del mundo.

**Paquetes:** no se encontró un `texture_pack.conf`, ni un archivo `.zip`/`.mtz` de paquete de texturas en el checkout. Los medios están incluidos en carpetas `textures/`, `models/` y `sounds/` de los mods y en `menu/`. Los `modpack.conf` de `mods/` son agrupaciones de mods, no texture packs.

### 2.2 Bloques, minerales y materiales

- **Mineclonia base:** `mods/ITEMS/mcl_core/textures/`, `mcl_deepslate/`, `mcl_copper/`, `mcl_nether/`, `mcl_end/`, `mcl_blackstone/`, `mcl_amethyst/` y otras carpetas entregan un amplio conjunto de bloques, ores, variantes, iluminación y materiales. La estética general es textura pixelada repetible y escala de bloque.
- **More Ores:** `mods/ITEMS/moreores/textures/` contiene 26 PNG auditados, todos 16×16. Incluye menas de estaño/plata/mithril, lumps, lingotes, bloques, herramientas de plata/mithril y tramos/conectores de rail de cobre. La forma/escala coincide con el resto del inventario.
- **Adamantine:** no mantiene una carpeta de PNG propia. `mods/ITEMS/adamantine/init.lua` define las imágenes como texturas Mineclonia existentes con modificadores `^[colorize:`: lingote de hierro, lump/raw iron o diamante, herramientas/armadura de diamante; para bloques y ores copia los tiles de bloques/menas de diamante y los tiñe. Reutiliza así iconografía y licencia de fuente, con riesgo de que la mena se perciba como diamante recoloreado si el color no se distingue en baja resolución.
- **Partes Everforge:** seis iconos PNG 16×16 en `mods/MISC/everforge/textures/everforge_part_*.png`: cabeza genérica y variantes hacha/pala, binding, handle y espada. Son siluetas reutilizadas de Melterns y tintadas por material en `init.lua`; no existe textura propia por cada combinación de siete metales.
- **Raridad/materiales y quality:** `forge_materials` y `quality_defs` en `mods/MISC/everforge/init.lua` asignan colores a siete materiales y colores de common/uncommon/rare/epic/legendary. Ese color se muestra en descripción/tooltip; la herramienta modular mantiene el icono de herramienta Mineclonia con tint del material. La calidad **no** agrega actualmente un overlay gráfico, textura, modelo, brillo o partícula de objeto. El color visible sí cambia entre calidades en las etiquetas.

### 2.3 Jugador, NPC, criaturas, modelos y animación

- **Jugador:** `mods/PLAYER/mcl_player/` incluye `animations.lua`, `textures/character.png` y comportamiento/API de player. Las skins se combinan en runtime.
- **Personalización:** `mods/PLAYER/mcl_skins/` proporciona comando `/skin`, formspec y registro API para skin base, pelo, ojos, boca, headwear, top, brazos, bottom y calzado. Guarda la selección en metadata personal. El README señala como extensión opcional `mcl_custom_skins`, no incluida. Esto es reutilizable como sistema de apariencia del jugador, pero Everforge no registra vestimenta/skin/clase específica propia.
- **Modelos de armadura:** `mods/ITEMS/mcl_armor/models/` tiene modelos B3D de personaje con armadura femenina/masculina y OBJ de Elytra; las texturas de armadura se aplican al modelo nativo.
- **NPC/mobs:** `mods/ENTITIES/mobs_mc/models/`, `textures/`, `sounds/` y Lua de criaturas. Ejemplos de modelos B3D incluyen creeper, esqueleto, dragón, guardian, zombis, aldeanos y animales; hay múltiples skins/variantes y animaciones definidas en Lua (por ejemplo `mobs_mc/creeper.lua`, `guardian.lua`, `skeleton.lua`). `mcl_mobs` aporta API de animación/efectos y gestión de criaturas.
- **Everforge:** `mob_names` en `mods/MISC/everforge/init.lua` usa `mobs_mc:skeleton`, `mobs_mc:stray` y `mobs_mc:zombie`; la entidad marcada `everforge_dungeon` recibe escalado lógico, no un mesh/texture set distinto. No se encontró registro de modelo/animación Everforge.
- **Animación:** el repositorio contiene modelos B3D y scripts de animación Mineclonia. En Everforge no se encontró una animación nueva de skill/arma, ataque de guardián o idle específico.

### 2.4 Herramientas, armas, armaduras e ítems

- `mods/ITEMS/mcl_tools/textures/`, `mcl_armor/textures/`, `mcl_bows/`, `mcl_shields/`, `mcl_tridents/`, `mcl_enchanting/` y `mcl_smithing_table/` ya proveen iconos/modelos de armas y armaduras estándar y sus estados.
- Las herramientas modulares usan la imagen base de pico/hacha/pala/espada de acero (`default_tool_steel*.png`) como `inventory_image` y `wield_image`; `colorize` denota material. La pieza de mano se presenta como sprite normal, no como un modelo 3D propio por parte.
- Los items legacy como `everforge:tool_head` y `everforge:tool_binding` reutilizan ingot/stick colorizados; los componentes nuevos usan las siluetas Melterns. El `everforge:relic` usa `default_gold_ingot.png` tintado púrpura. El bloque de alijo combina textura de chest con ingot dorado, y el spawner tiñe stone brick púrpura (`init.lua`, definiciones cercanas a los bloques de mazmorra). Son composición procedural/sprite de bajo coste y deben considerarse visualmente provisionales, no arte original acabado.
- Adamantine reutiliza textura de herramienta/armadura de diamante con tint. El equipo conserva las animaciones, geometría y lenguaje base de Mineclonia.
- La diferencia material está implementada principalmente como color/tinte más nombre/rareza en tooltip. La calidad tiene nombre y color de texto, pero no icono de calidad. Para accesibilidad y legibilidad, el color nunca debería ser la única señal.

### 2.5 Estructuras, aldeas y decoraciones

- **Estructuras nativas reutilizables:** `mods/MAPGEN/mcl_levelgen/schematics/` contiene 186 `.mts`; además aldeas, outposts, portales en ruinas, mansiones, fortificaciones del Nether y otras estructuras tienen assets/lógica nativos en `mods/MAPGEN/`.
- **Cementerio Everforge:** `register_structure_feature` en `mods/MISC/everforge/init.lua` lo compone por código con muros bajos de cobble, cuatro tumbas de stonebrick/mossy, centro de stonebrick cracked, reward cache y torch. No hay esquema `.mts`, tiles, modelo o decoración Everforge exclusiva.
- **Torre de Hielo:** estructura procedural estrecha/tapered, hueca, de alrededor de 14 bloques de alto; alterna blue ice/packed ice y contiene alijo/spawner. Usa tiles nativos del hielo; no tiene iluminación/partículas propias.
- **Aldeas y decoración:** `mcl_villages`, banners, cadenas, barras, lanterns, candles, fences, cobwebs, skulls/heads, lecterns, pots, etc. son una biblioteca de bloques lista para composición. Everforge no está usando ese repertorio completo en su Cementerio/Torre.
- **Coherencia:** reutilizar los nodos mantiene pixel-art, escala y sombreado Mineclonia. Lo que diferencia las estructuras actuales es su silueta/función, no un vocabulario de materiales Everforge propio. La baja variedad de bloques y geometría simple puede leer como “ruina de Minecraft” más que como dungeon de identidad particular.

### 2.6 Interfaces, iconos, HUD y formularios

- **Mineclonia:** `mods/HUD/mcl_formspec/textures/`, `mcl_inventory/textures/`, `mcl_experience/textures/`, `mcl_achievements/textures/`, `mcl_bossbars/textures/`, `mcl_hbarmor/textures/`, `mcl_offhand/textures/` y `mods/HELP/doc/` contienen recursos UI/HUD, iconos y presentación nativa.
- **Everforge:** `textures/everforge_ui_panel.png` 64×64; botones normal/hover/pressed y slot 32×32; `everforge_waila_panel.png` 256×256; seis iconos de partes 16×16. `forge_theme()` (`init.lua:120–135`) declara fondo grafito, panel 9-slice, marfil/cobre y slot estilo propio.
- **Menú RPG:** `rpg_content()` (`init.lua:137–186`) es modal 11.75×6.2 con título, resumen, botones de clase y cuatro filas de skill/rank con tooltips y botón Learn. En inventario usa una variante más larga. No hay imagen/portrait de clase, icono por skill, diagrama de nodos, conectores, barra de progresión independiente o árbol visual.
- **Alloy Melter:** `build_forge_formspec()` (`init.lua:301–391`) tiene estado, porcentaje de fuel/progreso, input, combustible, 4×2 productos, inventory y hotbar. Reutiliza overlays de fuego y flecha del horno nativo, integra el panel/slot Everforge. Es visualmente la pantalla más completa y funcional de la identidad propia.
- **Guía de minerales:** categoría `doc` con galería y textura real del nodo/item del mineral; cambia panel de texto a fondo oscuro y añade un acento cobre. Reutiliza builder nativo, no crea viewer duplicado.
- **WAILA:** HUD contextual en `init.lua` con panel PNG propio y texto de bloque/categoría/herramienta. Es utilidad, no sistema de iconos o progresión. El overlay debe evaluarse como contexto de mundo para asegurar que el panel no opaque el juego.
- **No aprovechado todavía:** iconografía de awards/achievements, barras de boss y efectos de estados pueden funcionar como referencia visual o interfaz existente, pero Everforge no los usa como identidad de sus skills/rarezas.

### 2.7 Partículas, iluminación, clima, sonido y música

- **Efectos existentes:** `mods/PLAYER/mcl_criticals/` tiene críticos con textura de partícula y tint; `mods/ENTITIES/mcl_mobs/effects.lua` y la API de `mcl_mobs` cubren poof/daño/partículas por entidad; `mods/CORE/mcl_explosions/` genera partículas de humo; pociones, encantamientos y mobs ya tienen efectos propios. Son alternativas de bajo coste frente a crear un motor de VFX.
- **Ambiente:** `mods/ENVIRONMENT/mcl_weather/`, `mcl_moon/`, `mcl_lightning/` y efectos de niebla/día-noche/clima aportan base ambiental. La luz normal viene de nodos/fuentes y el cliente Luanti. No se identificó un mod de iluminación global tipo shader dentro de Everforge ni un postproceso específico de campaña.
- **Everforge:** no tiene archivo de sonidos/loops/música, ni llamadas propias de `add_particlespawner` en el mod. Herramientas usan sonido estándar de rotura (`default_tool_breaks`); bloques/armadura llaman grupos/sonidos de piedra, metal y equipamiento; los guardianes conservan el audio nativo de `mobs_mc`. Cementerio solo coloca una antorcha normal; la Torre no incorpora efecto de escarcha visual o sonoro propio.
- **Audio general:** 447 OGG están empaquetados; ejemplos `mods/CORE/mcl_sounds/sounds/`, `mods/ENTITIES/mobs_mc/sounds/` y ocho pistas del jukebox en `mods/ITEMS/mcl_jukebox/sounds/`. Esto basta para una ambientación survival completa, pero no implica música de fondo dinámica en gameplay ni una banda sonora Everforge.

## 3. Estado visual de Everforge por elemento

| Elemento | Estado | Recurso/implementación real | Lectura artística |
|---|---|---|---|
| Logo Everforge | IMPLEMENTADO | `menu/header.png` 2172×724; cambio documentado en `mods/MISC/everforge/AUDIT.md` | Logo metálico con hierro/cobre; debe conservarse. No rehacer ni sustituir. Procedencia descrita como logo original elegido por el usuario y copiado sin retoque. |
| Icono del menú | REUTILIZADO | `menu/icon.png` 128×128 | Aún es bloque de césped de Mineclonia; marca principal y launcher no coinciden visualmente. No cambiar sin autorización del usuario. |
| Fondos de menú | REUTILIZADO | `menu/overlay*.png`, seis PNG 800×600 | Paisaje/bosque/mar desenfocado, CC0 según `LEGAL.md`; son neutrales, no cuentan historia ni fijan paleta fantástica. |
| Paleta de UI propia | IMPLEMENTADO | `forge_theme`, `#08090B`, `#17191C`, `#c27a4a`, `#F2E8D9` | Consistente en panel RPG/Melter/guía; debe permanecer local a esas pantallas, no teñir biomas ni UI vanilla global. |
| Skill tree RPG | PARCIAL / pendiente visual | Modal actual de filas, rangos, tooltips y botones | No hay árbol gráfico ni iconos individuales. No definir ahora nuevas clases/habilidades; la futura UI puede reutilizar el layout y arte Mineclonia. |
| Fundidor | IMPLEMENTADO | Panel/slots Everforge más fuego/flecha de horno Mineclonia; estados de texto/colores | Coherente y legible por jerarquía; la inspección de código no valida DPI, resolución ni apariencia final en cliente. |
| WAILA | IMPLEMENTADO | Panel 256×256 y HUD textual | Integrado al juego; evitar sobrecarga visual y probar contraste/escala contra distintos escenarios. |
| Guía mineral | IMPLEMENTADO | `doc` + galería de item/node nativo | Reutilización óptima; paleta cálida es acento, no reemplazo de la identidad de `doc` en todo el juego. |
| Menas More Ores | IMPLEMENTADO | 26 PNG 16×16, `mods/ITEMS/moreores/textures/` | Conjunto de origen dedicado, encaja con las menas del juego. |
| Mena/equipo Adamantine | IMPLEMENTADO por tintado | `mods/ITEMS/adamantine/init.lua` reutiliza diamante/netherita vía `colorize` | Económico y compatible, aunque visualmente recuerda a recolor de diamante. Contraste a tamaño 16×16 pendiente de prueba. |
| Piezas modulares | IMPLEMENTADO por reutilización | Siluetas Melterns 16×16 con tint | Coherencia de escala; siluetas no enseñan la rareza/material por forma. |
| Calidades de herramientas | PARCIAL | Nombre/rango y texto coloreado; icono base de herramienta tintado por material | No existe una apariencia propia por calidad. Material + quality no deben confundirse; ambas son dimensiones distintas en datos. |
| Cementerio | IMPLEMENTADO en mapgen | Geometría procedural con cobble/stonebrick/mossy/cracked, pecho y spawner | Reconocible en paleta vanilla, pero poco decorado y sin assets propios. |
| Torre de Hielo | IMPLEMENTADO en mapgen | Packed ice/blue ice, silueta cuadrada y hueca | La paleta comunica hielo; falta solo si el objetivo futuro solicita una identidad más singular, no es un error funcional. |
| Guardianes | IMPLEMENTADO con mobs vanilla | Skeleton, stray, zombie nativos marcados por Everforge | Legibles y animados, pero no hay modelo/texture/animación/audio de jefe Everforge. |
| Ambientación Everforge | PARCIAL | Música/sonidos clima/MCL mobs y nodos nativos | No hay audio, partículas ni iluminación específica. Reusar primero los efectos de Mineclonia. |

## 4. Licencias y procedencia

| Recurso | Procedencia conocida en repositorio | Licencia indicada | Nota de reutilización/distribución |
|---|---|---|---|
| Texturas Mineclonia | `LEGAL.md`, bases Pixel Perfection y Pixel Perfection Legacy | CC BY-SA 4.0, salvo excepciones locales | Mantener atribución y compatibilidad ShareAlike en derivados donde aplique. `mods/ITEMS/mcl_core/README.md` detalla recursos concretos. |
| Menú Mineclonia | `LEGAL.md` | CC0 para imágenes de menú generales | El logo Everforge particular se documenta en `mods/MISC/everforge/AUDIT.md` como imagen del usuario copiada byte por byte; conservar la procedencia y no asumir autorización para usos fuera del juego. |
| `menu/header.png` | Logo original Everforge elegido por el usuario | `LEGAL.md` declara CC0 para imágenes generales del menú, pero el origen/licencia específica de este logo elegido por el usuario no está documentado por separado | Preservar intacto. Si se distribuye fuera del contexto de este juego, confirmar autorización/licencia de la fuente original. |
| UI Everforge (panel/botones/slots/WAILA) | `mods/MISC/everforge/textures/`; sin nota individual de procedencia para esos seis PNG | `LEGAL.md` da CC BY-SA 3.0 por defecto a otros archivos salvo excepción; la autoría/derivación por archivo no está atribuida | No mezclarlos en un texturepack público hasta confirmar atribución y que el default general cubre estos archivos. |
| Siluetas de componentes Melterns | Seis PNG 16×16; `THIRD_PARTY.md` y `textures/LICENSE-MELTERNS.txt` | MIT; commit upstream `0091c21443b045ec04b62b240c4eee746af6bc42` | Atribución/licencia ya retenidas. No son código Melterns. |
| More Ores | `THIRD_PARTY.md`, `mods/ITEMS/moreores/` | Código upstream zlib; medios sujetos a atribución/`LEGAL.md` y licencias locales | No incorporar sus iconos a otros packs sin conservar créditos aplicables. |
| Adamantine | `THIRD_PARTY.md`, `mods/ITEMS/adamantine/` | Código GPL-3.0-or-later; texturas derivadas de Mineclonia | Sus imágenes de material se generan a partir de texturas existentes, no de un asset independiente. |
| MCL Skins | `mods/PLAYER/mcl_skins/LICENSE.txt`, `media_credits.txt` | Código MIT; medios con créditos CC BY-SA 4.0/3.0 por grupo/archivo | No asumir que la licencia del código cubre todos los skins; revisar créditos por textura. |
| REFI Textures (opcional externa) | `MysticTempest/REFI_Textures`, README y `texture_pack.conf` | CC BY-SA 4.0 | Requiere atribución/ShareAlike. La compatibilidad publicada es con Mineclonia en general, no validación runtime exacta con este checkout 0.124.1. |
| Goanna / NV Relight / Glowshrooms | Repositorios externos, detalle en §7 | LGPL-2.1-or-later/medios individuales; GPL-3.0; MIT + CC BY-SA 4.0 respectivamente | No descargados ni incorporados. Aplicar licencia de código y de medios por separado. |

## 5. Recursos del bundle disponibles para reutilizar

| Capacidad | Recurso incluido | Aprovechamiento sin crear arte nuevo | Condición/limitación |
|---|---|---|---|
| Textura pixel-art coherente | `mcl_core`, `mcl_deepslate`, `mcl_tools`, `mcl_armor`, More Ores | Usar sprites/tile existentes, tintes y overlays discretos | Confirmar cómo se ven materiales y tintes a resolución nativa; no cambiar textura global |
| Player appearance | `mcl_skins`, `mcl_player` | Añadir registraciones de skin/cosmética a una futura UI de avatar | Eso sí añade opciones de apariencia; no está integrado en Everforge y requiere aprobación de contenido/licencias |
| Animación de mob | B3D + tablas Lua de `mobs_mc` y `mcl_mobs` | Usar variantes/animaciones vanilla y funciones de animación de entidad | Un guardián de diseño propio requeriría nueva entidad/art/animación; no se modifica ahora |
| Visual de equipo | `mcl_armor`, trims, `mcl_tools` | Aprovechar iconos/armadura/trim existentes como base de lectura | La tintura de Adamantine y Everforge requiere QA de contraste y mezcla de tintes |
| Iconos de objetivos | `awards`, `mcl_achievements`, `mcl_experience` | Referenciar o mostrar hitos con visuales del juego en una UI futura | No existe icono por skill Everforge; no tomar atlas de forma que desatienda atribución |
| Efectos de combate | `mcl_criticals`, `mcl_mobs/effects.lua`, partículas de pociones | Usar effect APIs y textura de partícula existente, limitar cantidad/vida | No aplicar globalstep de partículas por cada frame ni usar color como única telemetría |
| Ambiente | `mcl_weather`, `mcl_moon`, `mcl_lightning`, fuentes de luz y sonidos del bloque | Permitir que la bioma/tiempo/Mineclonia aporten el tono general | No aplicar la paleta grafito/cobre al mundo entero; evitar cambiar regla de iluminación/spawn |
| UI/slots | `mcl_formspec`, `mcl_inventory`, `doc`, HUD bars | Mantener slots y layout nativo, componer solo paneles locales | Formspecs/HUD cambian entre versiones y DPI: test visual obligatorio |
| Decoración | Banners, lanterns, candles, fences/bars, cobweb, heads, chains, pots | Reusar bloques en futuras extensiones aprobadas de estructura | Las estructuras actuales ya están en mundos/mapgen; no cambiar en esta auditoría |
| Sonido de metal/hielo/stone | `mcl_sounds` + sonido nativo de mob/herramienta | Reasignar sonidos existentes sólo en objetos nuevos/aprobados | No se observó un catálogo `everforge:sound`; no reutilizar grabaciones sin verificar licencia |

## 6. Evaluación de coherencia y problemas actuales

### Lo que ya se siente coherente

- Los sprites de menas, herramientas y bloques usan escala de 16px; los iconos Everforge están también en esa cuadrícula.
- More Ores aporta imágenes propias; Adamantine reutiliza las bases ya comprendidas por el jugador. Ambos encajan en el mundo de Mineclonia sin introducir modelos fuera de estilo.
- La paleta de UI no tiñe los biomas: el cobre y marfil están limitados a texto, bordes, paneles y botones Everforge.
- Fundidor, WAILA y guía retienen slots/galería/iconos nativos, lo que reduce costes de coherencia y de mantenimiento.
- La construcción procedural de dungeon no añade paquetes de textura ni dependencias externas y conserva la escala de un nodo.

### Fricciones o riesgos de lectura

1. **Logo frente a icono:** header metálico de Everforge arriba, icono del juego aún césped. Branding incongruente en el launcher, aunque el icono no debe cambiarse sin instrucción.
2. **UI RPG textual:** clases y skills se distinguen por nombres/ranks, pero no por símbolo. Un jugador que espere un árbol podría no interpretar la relación ni los efectos; la solución futura puede ser UI sobre APIs/assets ya incluidos antes de dibujar iconos.
3. **Calidad sólo textual:** los cinco colores de rareza transmiten una semántica conocida, pero los objetos no se distinguen por forma o borde. El color no es accesible por sí solo; reutilizarse la misma imagen base reduce la lectura rápida de tier.
4. **Doble eje color:** material y calidad son datos independientes; los tintes de materiales y colores de calidad pueden producir una apariencia confusa si se compusieran. Actualmente calidad se refleja en tooltip, no en el sprite.
5. **Asset provisional:** relic = lingote dorado púrpura; caché = pecho con ingot; spawner = stonebrick violeta; varias partes heredan siluetas. Son identificadores reconocibles pero no un vocabulario de iconos propio y terminado.
6. **Estructuras de bloque simple:** se leen como composiciones pequeñas de nodos vanilla; el Cementerio tiene poca variedad de props, la Torre es repetición de hielo. No hay “firma” visual de guardianes o recompensa más allá de tint/overlay.
7. **Audio/VFX ausentes como diferenciación:** los ataques/encuentros de Everforge no tienen stinger, partículas de calidad, efecto de habilidad ni ambiente propio. Las señales dependen de SFX y mobs base.
8. **Riesgo de mezclas de tintes:** el icono Adamantine se basa en diamond y Everforge tiñe herramientas por material; tintes fuertes/similares deben probarse en slots, hotbar, mano, fondo oscuro/claro y variaciones de daltonismo.
9. **Riesgo de rendimiento:** futuros modelos detallados, capas de partículas o relighting pueden impactar cliente y mapa. La escala pixel art actual es liviana; mantenerlo como baseline.
10. **Licencia/procedencia desigual:** el icono Melterns sí tiene licencia local; los seis gráficos de UI Everforge y el logo no presentan archivo/licencia individual. Completar provenance antes de exportarlos como pack.

## 7. Alternativas externas de código abierto (investigación, no instaladas)

| Proyecto | Qué aporta | Compatibilidad/estado declarado | Licencia | Coste y evaluación |
|---|---|---|---|---|
| [REFI Textures](https://github.com/MysticTempest/REFI_Textures) | Pack 16px, alternativas de bloques/ítems, carpeta de GUI themes y plantillas de skins | README y `texture_pack.conf` incluyen soporte Mineclonia; último commit visible consultado 3-jul-2026. No afirma prueba exacta con este checkout 0.124.1 | CC BY-SA 4.0 | **Bajo coste de prueba** en perfil cliente separado; revisar cambios del pack, licencia, contraste y que las texturas Everforge mantengan su nombre/forma. No reemplazar logo/menu sin aprobación. Es la alternativa más pertinente para comparar legibilidad antes de arte original. [1](https://github.com/MysticTempest/REFI_Textures) |
| [Glowshrooms](https://github.com/culmat/glowshroom) | Nodo/decoración luminosa con arte original y generación/propagación de cuevas | README reporta tests headless en Mineclonia, engine 5.10 y 5.17; fuente consultada 11-oct-2026 | Código MIT; medios CC BY-SA 4.0; lista disclosure de asistencia IA para arte/code | **Bajo/moderado coste técnico**, alto coste de decisión de contenido: introduce bloque, mapa y luz nuevos. No es necesario para la identidad actual; solo evaluar en mundo de prueba si luego se aprueba nueva decoración de cuevas. [5](https://github.com/culmat/glowshroom) |
| [NV Relight](https://github.com/sjhari7112-dev/nv-relight) | Luz ambiente mínima por nodo y relighting de mapblocks viejos | Autor afirma Mineclonia + Luanti 5.17.0 y spawn-safe; repositorio consultado tenía 3 commits, release/commit inicial 25-oct-2026 | GPL-3.0 | **Bajo coste de código, riesgo alto de diseño/compatibilidad:** hace que cuevas/noche se vean distintas, agrega almacenamiento por mapblock y toca la semántica que consulta spawning artificial light (incluso con spawn-safe). Muy reciente; no recomendado como default ni para integrar sin experimento/consentimiento. [1](https://github.com/sjhari7112-dev/nv-relight) |
| [Goanna](https://github.com/p0ss/Goanna) | Cliente/renderizador alternativo con iluminación, sombras, materiales y posibilidad de packs PBR | Mineclonia es uno de los juegos probados; repo declara el cliente alpha y conserva Luanti cliente como referencia. La cobertura de formas de nodos, animaciones, partículas, HUD/formspec es incompleta | Código LGPL-2.1-or-later; media de paquetes PBR sigue licencias individuales | **Coste alto:** no es mod ni pack que se copie al juego, requiere cliente alternativo/build y QA aparte. Opción opcional para experimento visual, no baseline ni requisito del proyecto. [3](https://github.com/p0ss/Goanna) |

**Recomendación externa:** de estos candidatos, solo REFI merece una comparación visual de bajo riesgo en un perfil/cliente aparte; no integrarlo ahora. Glowshrooms y NV Relight cambian el mundo/luz; Goanna cambia el renderer/cliente. Ninguno se instaló, reemplazó ni se usó para alterar archivos del repositorio.

## 8. Propuesta de dirección artística

La guía siguiente es criterio de coherencia para futuras decisiones; no es una orden de rehacer contenido ni de diseñar clases/skills/monstruos.

### Identidad y paleta

- **Marca:** conservar el logo original de Everforge intacto. No cambiar el logo de Mineclonia, ni incorporar branding Everforge en menús globales no pedidos. Tratar launcher icon como decisión separada.
- **Interfaz Everforge:** mantener grafito/hierro oscuro (`#08090B`, `#17191C`), cobre (`#C27A4A`) y marfil cálido (`#F2E8D9`) para paneles, bordes, headings y acciones. Mantener slots y componentes de formspec MCL.
- **Mundo:** no aplicar la paleta UI a texturas de suelo, minerales, animales, clima o estructuras globalmente. Que cada bioma siga teniendo su temperatura, color y contraste Mineclonia.
- **Estados:** además del color, comunicar estado mediante texto/forma/posición; conservar labels “working/ready/output full” y no depender solo verde/rojo.

### Texturas, modelos y escala

- **Texturas:** apuntar a pixel art tileable compatible con el atlas base. Como referencia, 16×16 para ítems/bloques equivalentes; usar resoluciones mayores solo cuando el asset fuente equivalente ya lo haga (player skin/UI/fondo). Evitar remuestreo borroso, ruido fotográfico y bordes antialias que rompan el pixel grid.
- **Modelos:** proporción Minecraft/Mineclonia, bloques de un nodo, siluetas simples y materiales identificables desde distancia. Usar B3D/OBJ/modelos que ya usa el juego antes de crear formatos nuevos; las estructuras generadas por nodos deben mantener alineación y colisión.
- **Minerales/materiales:** aprovechar More Ores y colorize de Adamantine/Everforge. Si el contraste se queda corto, priorizar una marca geométrica o contorno reutilizable por encima de añadir una textura completa distinta para cada combinación.
- **Herramientas/calidades:** separar visualmente “material” de “calidad” en el dato/interfaz; el color de calidad no debería ocultar la forma/tool type. Si se agrega una señal por rareza, que sea pequeña, legible en 16px y redundante con nombre/tooltip. Reutilizar iconografía nativa primero.
- **Enemigos:** silueta, ojos/arma y postura deben leerse a distancia; reusar variantes y animaciones de mobs base. No inventar ni diseñar enemigo nuevo en esta auditoría.

### UI, efectos, estructuras y audio

- **Futuro árbol de skills:** mantener como ventana propia el panel y lenguaje visual existente; reutilizar `doc`, `mcl_inventory`, hitos/íconos de `mcl_achievements` como referencias. Un diagrama con conectores e iconos nuevos exigiría diseño original y validación, pero no requiere modificar HUD global. Las clases actuales son solo estado preexistente; no fijar por arte nuevas clases, restricciones o habilidades.
- **VFX:** preferir tipos, texturas, colores y lifecycle de partículas/status effects nativos; hacer partículas cortas, de baja cantidad y no bloqueantes. Reservar efectos distintos para eventos puntuales que sean aprobados. No generar partículas por cada tick.
- **Biomas/estructuras:** usar materiales que ya aparecen en el bioma (hielo en regiones frías, piedra/cobble para ruina) y decoración ya existente. El cobre de la interfaz no implica que una torre de hielo deba teñirse de cobre.
- **Audio:** primero sonidos nativos de metal/piedra/hielo y mobs existentes. Una música/stinger de campaña sería audio original separado, con licencia y volumen configurables; no poner BGM global por defecto.
- **Rendimiento:** conservar 16px donde corresponde, compartir texturas/sprites y materiales, limitar partículas/entidades y evitar generación de objetos por frame. Probar low/medium/high-end client, distancias de visión y multijugador antes de subir resolución o conteo de efectos.

## 9. Plan de mejoras por prioridad, coste e impacto

Solo plan; no se ejecutó ninguno de estos cambios en esta fase.

| Prioridad | Mejora a evaluar | Reutiliza existente | Arte original requerido | Dificultad | Impacto esperado | Riesgo/validación |
|---|---|---|---|---|---|---|
| P0 | Capturar baseline real de UI, materiales, estructuras, skins y audio en Mineclonia 0.124.1/Luanti 5.17.0; escalas y contraste | Sí, contenido actual | No | Baja, necesita cliente y mundos de prueba | Alto para descubrir defectos reales | No hay `world.mt` ni cliente probado en esta auditoría; confirmar resolución, DPI, traducción, shaders y mod load |
| P0 | Aclarar la licencia/procedencia de seis texturas UI Everforge y del logo/header antes de distribuir el juego/pack | Metadatos actuales y `LEGAL.md` | No | Baja | Alto para release/compliance | El logo se documenta elegido por usuario; las texturas UI no tienen nota por archivo |
| P1 | Alinear launcher/header solo si el usuario aprueba cambiar `menu/icon.png`; mantener el header exacto | Imagen de logo/header existente | Posiblemente una miniatura derivada, solo con autorización | Baja | Medio/alto para marca | No modificar durante esta auditoría; licencia/procedencia y recorte deben aprobarse |
| P1 | QA de legibilidad de More Ores/Adamantine/tintes de herramientas y labels de rareza, incluyendo daltonismo | Texturas 16px, descripciones y color actual | No al comienzo | Baja | Alto en inventario/feedback | Si falla contraste, decidir solución con usuario antes de añadir overlay o nuevos sprites |
| P1 | Pulir jerarquía y espaciado de formularios actuales con componentes existentes | Everforge UI panel/button/slot, MCL formspec | No, salvo que falten iconos | Baja/media | Medio/alto | Validar formspec 7, DPI, traducciones y no alterar lógica/listas |
| P2 | Prototipar visualización no funcional de skills con iconos nativos/objetos del juego dentro de la ventana actual | Awards/HUD/inventory icons e imágenes de item existentes | Posible si faltan símbolos legibles | Media | Alto para comunicar la progresión | No establecer mecánicas, clase ni skill nuevos; requiere aprobación antes de cualquier cambio |
| P2 | Mejorar señales de material/calidad con redundancia gráfica en inventario/tooltip | Íconos nativos, texturas/tintes actuales y etiquetas | Puede evitarse; un set iconográfico único sería original | Media | Medio/alto | Probar sprites a 16×16, compatibilidad con `toolranks`, contrastes y no confundir rarity material vs manufactura |
| P2 | Probar REFI como perfil visual de alternativa, sin reemplazar logo | Pack externo cliente | No | Baja | Medio, informativo | Compatibilidad declarada, no verificada en el mundo/branch objetivo; revisar licencia y cobertura de nombres Everforge |
| P3 | Una presentación más elaborada para Cementerio/Torre con decoraciones MCL existentes | Banners, lanterns, chains, heads, cobwebs, blocks y nodes del bioma | No necesariamente | Media, incluye mapgen/world tests | Alto en exploración | Afecta nuevas estructuras/chunks; requiere scope y aprobación, no tocar ahora |
| P3 | VFX/audio exclusivos para guardianes/skills | `mcl_mobs`, `mcl_criticals`, potions, MCL sounds | Sí, si la biblioteca existente no cubre el objetivo | Alta | Alto en combate/identidad | Rendimiento, legibilidad, licencias, accesibilidad y diseño de combate; no diseñar ahora |
| P3 | Modelo/skin/animación propia de guardianes si en una fase futura se requiere boss identity | Mobs/animaciones B3D existentes como plantilla | Sí, arte y animación originales | Alta | Muy alto pero costoso | QA de hitbox, rig, escala, animación, memoria, licencias y balance; fuera de alcance actual |

## 10. Tabla final de funcionalidades

| Recurso/funcionalidad | Sistema/mod | Estado | Reutilización | ¿Requiere arte original? | Prioridad |
|---|---|---|---|---|---|
| Logo y cabecera de Everforge | `menu/header.png` | IMPLEMENTADO | Conservar exactamente | No | P0 — preservar |
| Icono del juego | `menu/icon.png` | REUTILIZADO (Mineclonia) | Posible reuso de logo solo con aprobación | No necesariamente | P1 decisión |
| Texturepack alternativo | No incluido | INEXISTENTE en repo | REFI como test externo | No, pack existente | P2 |
| Texturas base/biomas/bloques | Mineclonia | IMPLEMENTADO | Vocabulario de referencia | No | P0 |
| NPC/mobs animados | `mobs_mc`, `mcl_mobs` | IMPLEMENTADO | Modelos, texturas, animaciones y SFX | No para mobs nativos | P0 |
| Personalización de jugador | `mcl_skins` | IMPLEMENTADO en juego; no integrado a Everforge | API/command `/skin` y base formspec | Opcional para items/cosmética nuevos | P2 |
| Ores More Ores | `moreores` | IMPLEMENTADO | 26 imágenes 16×16 | No | P0 |
| Adamantine | `adamantine` | IMPLEMENTADO mediante tintes de assets MCL | Texturas de diamante/netherita, armor/tools | No | P0; QA de contraste |
| Partes de herramientas | Everforge + Melterns art | IMPLEMENTADO mediante siluetas 16px | Seis icons tintados | No para el set actual | P1 QA |
| Calidad visual de tools | Everforge | PARCIAL | Nombres, colores de tooltip, sprite base | Iconos/overlay si se pide diferenciación | P2 |
| UI RPG/skill tree | Everforge + `mcl_inventory`/`mcl_formspec` | PARCIAL: modal actual, sin árbol | Paneles, botones, slots, icons MCL | No necesariamente; depende del nivel de singularidad | P2 |
| Alloy Melter UI | Everforge + furnace textures | IMPLEMENTADO | Panel propio + fuego/flecha nativos | No | P0 QA runtime |
| Guía de minerales | `doc` + Everforge | IMPLEMENTADO | Gallery nativa y node icons | No | P0 |
| WAILA/HUD | Everforge | IMPLEMENTADO | HUD APIs y panel 256px propio | No | P1 QA visual |
| Cementerio/Torre | Everforge + `mcl_levelgen` | IMPLEMENTADO con nodos vanilla | Decoraciones, bloques, esquemas MCL | No para pulido básico; sí para modelos/arte singular | P3 |
| Guardianes con apariencia única | Everforge | INEXISTENTE | Modelos/variantes MCL disponibles | Sí si se exige identidad propia | P3 / no diseñar ahora |
| Partículas/animaciones de skills Everforge | Everforge | INEXISTENTE como VFX propios | `mcl_criticals`, `mcl_mobs`, efectos y potions | Solo si se requiere efecto distinto | P3 |
| Audio/música Everforge | Everforge | INEXISTENTE como recursos propios | 447 OGG base, grupos de sonidos, mob/jukebox | Sí para composición/sound effects inéditos | P3 |
| Luz global mejorada | Mineclonia/Luanti | SIN MOD específico en bundle auditado | Opciones render del cliente/clima/fuentes de luz | No para test de cliente; el mod externo cambia sistema | P3, no default |
| Skin/texturepack externa | REFI Textures / `mcl_custom_skins` referenciado por MCL Skins README | CANDIDATO externo, no instalado | Pack cliente o API de skin | No en REFI; sí assets opcionales para skins | P2, validar versiones/licencias |

## 11. Verificación y límites

- **Inspeccionado:** nombres, dimensiones PNG desde cabecera, extensiones, carpetas de assets, texto/código que referencia iconos/sonidos/modelos, licencias locales, `LEGAL.md`, `THIRD_PARTY.md`, `README.md` y `mods/MISC/everforge/AUDIT.md`.
- **No validado visualmente en juego:** rendering de formas, gamma, filtrado, rotación del icono en mano, colores en distintas resoluciones, clipping de UI, shaders, modelo animado, rendimiento, resolución de partículas/sonidos y mapa generado.
- **No probado:** configuración/activación real de mods en una save, debido a que no hay `world.mt`; comportamiento exacto de 0.124.1 en cliente Luanti 5.17.0 debe confirmarse con runtime.
- **Terceros:** las características, licencias y fechas indicadas en la sección 7 son las publicadas por repositorios consultados; no equivalen a prueba de compatibilidad o recomendación de adopción.
- No se tocó `menu/`, texturas, modelos, traducciones, mods, recetas, generación o mundo. Esta entrega es exclusivamente documental.

## 12. Rutas de referencia

- Identidad y visual de Everforge: `menu/header.png`, `menu/icon.png`, `menu/overlay*.png`; `mods/MISC/everforge/AUDIT.md:69–80`; `mods/MISC/everforge/textures/`.
- UI: `mods/MISC/everforge/init.lua:120–186` (`forge_theme`, `rpg_content`); `:301–391` (`build_forge_formspec`, `update_melter_interface`); `:1125–1204` (WAILA panel/HUD); `:1352–1381` (doc category minerals); `:1473–1537` (cache formspec).
- Material/quality/tool icon: `mods/MISC/everforge/init.lua:633–773` (`forge_materials`, `quality_defs`, `build_modular_description`, `register_modular_tool`); `:801–858` (component registration/tint); `:867–948` (per-stack properties).
- Estructuras/guardianes: `mods/MISC/everforge/init.lua:1390–1448` (`register_structure_feature`); `:1548–1666` (`mob_names`, scale, spawn marker); `:1680–1692` (registers structures). `mods/MISC/everforge/README.md` describes intended content and mapgen condition.
- Adamantine tints: `mods/ITEMS/adamantine/init.lua:1–93` (texture lookup/tint helpers/TEX/tiles); `:197–234` (ore/block tiles); `:442–478` (armor set/textures).
- Textures/tracks/models: `mods/ITEMS/moreores/textures/`; `mods/ENTITIES/mobs_mc/models/`, `textures/`, `sounds/`; `mods/PLAYER/mcl_player/animations.lua`; `mods/ITEMS/mcl_armor/models/`; `mods/PLAYER/mcl_skins/README.md`, `edit_skin.lua`, `LICENSE.txt`, `media_credits.txt`.
- Effects/ambient/audio: `mods/PLAYER/mcl_criticals/init.lua`; `mods/ENTITIES/mcl_mobs/effects.lua`; `mods/ENVIRONMENT/mcl_weather/`, `mcl_moon/`, `mcl_lightning/`; `mods/CORE/mcl_sounds/sounds/`; `mods/ITEMS/mcl_jukebox/sounds/`.
- World structures/resources/licenses: `mods/MAPGEN/mcl_levelgen/schematics/`; `LEGAL.md`; `THIRD_PARTY.md`; `mods/MISC/everforge/textures/LICENSE-MELTERNS.txt`.
