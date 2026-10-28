# Investigación de recursos visuales reutilizables para Everforge

- **Corte:** 28 de octubre de 2026
- **Objetivo:** Luanti 5.17.0 + Mineclonia 0.124.1
- **Tipo de entrega:** evaluación documental; no instalación ni transformación del juego.

## Alcance, límites y escala de evidencia

Se contrastaron recursos de ContentDB con repositorios de sus autores y con la composición del checkout. **No se descargó ni instaló ningún mod o pack, no se editó el mundo ni el código funcional, y no se ejecutó una partida.** El contenido del checkout y las auditorías existentes muestran una base Mineclonia extensa y mayormente 16 px; Everforge ya reutiliza modelos, nodos, mobs, clima, menús e interfaces de Mineclonia.

Durante esta revisión, las páginas individuales de ContentDB que se abrieron mostraron el aviso de mantenimiento por el incidente de seguridad del 22–26 de octubre. Por ello, los datos de ContentDB de este informe provienen del índice y de los fragmentos de búsqueda disponibles; cuando fue posible se contrastaron con repositorios fuente. No se usó un mirror no oficial como sustituto del repositorio oficial. Tampoco hay binario `luanti`/`minetest` en este entorno ni una partida de prueba configurada: no fue viable hacer una comprobación runtime aislada. La prueba queda como paso recomendado, no como resultado.

**Niveles de evidencia** (no equivalen entre sí):

- **Declarado:** la ficha, README o `texture_pack.conf` anuncia Mineclonia/VoxeLibre.
- **Inspección estática:** además se leyó código/manifiestos o el código actual de Mineclonia y se cotejaron nombres/API.
- **Runtime exacto:** cargar y observar con Luanti 5.17.0 + Mineclonia 0.124.1. **Ningún recurso de terceros alcanzó este nivel en esta investigación.**

**Clasificaciones**: *directo* = diseñado/declarado para Mineclonia, sujeto a prueba exacta; *adaptable* = requiere cambiar nombres/API/configuración; *parcial* = interesante como media/modelo/técnica, no como mod completo; *no recomendado* = el conflicto, licencia, impacto jugable o riesgo supera la ventaja para el objetivo actual.

## Base actual que condiciona la recomendación

- La auditoría local contabilizó **3.292 PNG, 85 B3D, 88 OBJ y 447 OGG** en `mods/`; 1.887 PNG revisados eran 16×16. Ya existen texturas, entidades animadas, modelos de armadura, API de mobs, partículas, efectos de clima, estructuras, skins, sonidos y herramientas.
- La identidad Everforge está principalmente en sus formularios; el mundo mantiene la escala pixel/voxel de Mineclonia. Esta investigación no toca el logo, el icono ni la paleta de interfaces.
- El árbol de Mineclonia registra hojas con IDs `mcl_trees:leaves_…`; los hongos pequeños actuales son `plantlike` (sprites planos). Son los dos puntos donde una sustitución visual geométrica acotada podría cambiar la lectura del mundo sin cambiar recetas o reglas.
- `mcl_weather` ya establece cielo y niebla submarina mediante `player:set_sky`; por tanto, un mod que también prometa niebla de agua se solapa con una función existente.
- La organización/repositorio actual de Mineclonia ya mantiene una integración propia de árboles y recursos procedentes de More Trees. Instalar el mod completo de More Trees duplicaría parte de la vegetación y de la generación.
- La auditoría artística existente es la referencia para recursos, licencias internas y partes de Everforge ya implementadas: [`docs/everforge-art-audit.md`](everforge-art-audit.md).

## A) Mejores candidatos

### 1. Packs de textura: probar alternativas, no mezclarlas

1. **[Pixel ImPerfection — ContentDB](https://content.luanti.org/packages/bramaudi/pixel_imperfection/) / [repositorio oficial actual](https://codeberg.org/mineclonia/pixel_imperfection)**. Opción más prudente para el primer A/B: es un pack parcial de 16 px derivado de Pixel Perfection, hecho específicamente para Mineclonia; actualiza texturas de bloques, criaturas e ítems. La rama oficial tuvo actividad el 26-09-2026 y se incorporó a Mineclonia parte de sus correcciones. Esto reduce el trabajo, pero también puede significar que algunos cambios ya estén en 0.124.1: hay que comparar nombres/hash antes de medir el beneficio. No cambia mecánicas ni el mapa guardado. **CC BY-SA 4.0 para el pack; no contiene código de juego.** Mantenimiento activo en la fuente, compatibilidad Mineclonia declarada; no prueba runtime de este checkout.

2. **[REFI Textures — ContentDB](https://content.luanti.org/packages/MysticTempest/refi_textures/) / [GitHub](https://github.com/MysticTempest/REFI_Textures)**. Alternativa más amplia, de 16 px, con texturas de Mineclonia/MTG, opciones visuales, themes GUI y plantillas de skin. La fuente contiene `texture_pack.conf`, soporte declarado para Mineclonia y actividad visible hasta julio de 2026. Buena comparación si se busca más legibilidad/contraste; al ser un cambio más amplio, revisar cómo convive con los materiales Everforge y excluir cualquier sustitución de branding/menu no autorizada. **CC BY-SA 4.0, sin código de juego.** No combinar con otro pack global.

3. **[Bauniclonia — ContentDB](https://content.luanti.org/packages/Mirtilo/bauniclonia/) / [Codeberg](https://codeberg.org/mirtilo/Bauniclonia)**. Pack de 16 px pensado exclusivamente para Mineclonia, derivado de Baunilha; aporta una dirección visual más uniforme y recientes texturas de naturaleza/cuevas. Su README lo marca WIP y rechaza soporte explícito a VoxeLibre. Buen tercer punto de comparación, pero es un cambio global de apariencia, no un complemento a REFI o Pixel ImPerfection. **CC BY-SA 4.0 confirmado en `LICENSE.txt`; sin código.** Fuente activa hasta julio de 2026; soporte declarado, no runtime 0.124.1.

4. **[Craft & Ruin Texture Pack — ficha](https://content.luanti.org/packages/GamingAssociation39/craft_and_ruin/) / [GitHub](https://github.com/Gerold55/craft_ruin_texture_pack)**. Pack parcial de 16 px dirigido a Mineclonia/VoxeLibre, con carpetas observadas para entidades, `mcl_core` y lana. Puede servir para tomar un subconjunto bien acotado, no como pack completo. `texture_pack.conf` anuncia GPLv3; la licencia del repositorio exige conservar crédito y compartir derivados bajo GPLv3. **La licencia del medio es GPLv3, no asumir CC BY-SA.** La cobertura parece parcial y el último cambio visible del repo consultado fue de 2026; compatibilidad declarada, no runtime. La procedencia por archivo debe auditarse antes de extraer.

5. **[Faithful-Clone — GitHub](https://github.com/Zormein/Faithful-Clone)** es la opción encontrada de resolución 32×32. Se presenta como port de Faithful/Minecraft y menciona texturas de varias versiones. No se encontró una licencia verificable que autorice redistribuir de forma clara los medios derivados; la propia conversación de publicación explica que hubo problemas para subirlo a ContentDB por la licencia de Faithful. **No recomendado para Everforge hasta obtener permiso/licencia de los titulares por los assets concretos.** Además, 32 px multiplica aproximadamente por cuatro los texels frente a 16 px y puede chocar con el pixel grid nativo. No se encontró una opción 32 px, de estilo moderado y con compatibilidad/licencias mejor verificadas que supere a las alternativas 16 px.

### 2. Vegetación, rocas y geometría de entorno

6. **[Bushy Leaves (fork) — ContentDB](https://content.luanti.org/packages/EmoryNB/bushy_leaves/) / [Codeberg](https://codeberg.org/EmoryNB/bushy_leaves)**. Mejor candidato geométrico para una prueba muy pequeña: cambia hojas cúbicas por mallas y ofrece malla `cheap` frente a `full`; no añade recetas ni fauna. La fuente inspeccionada busca nombres que incluyan `leaves` o `needles` (excepto `with_leaves`) y aplica `core.override_item` al cargar los mods. Los IDs generados por la API local `mcl_trees` cumplen el patrón `mcl_trees:leaves_…`; hay por tanto **coincidencia estática del patrón**, no una prueba de visualización. La búsqueda por nombre, en vez de por grupo `leaves`, podría incluir nodos decorativos que no sean copas. La fuente dice que no cambia `collision_box` y su README recomienda `cheap` en multijugador/dispositivos lentos. **Código AGPL-3.0-or-later; modelos `models/license.txt`: AGPL-3.0; medios/code revisados a nivel de fuente, no runtime.** No exige dependencias, reconoce opcionales `mcl_core`, `default`, etc.; mantenimiento-only, última actualización visible enero de 2025. Recomiendo adaptar una whitelist de hojas MCL antes de habilitarlo globalmente.

7. **[Natural Habitat — ContentDB](https://content.luanti.org/packages/Mish7913/natural_habitat/) / [GitLab](https://gitlab.com/Mish7913/natural_habitat)**. Fuente de ideas/recursos para rubble, sticks, boulders, hongos 3D, flores, árboles y una bioma nueva; el repo contiene esquemas explícitos para Mineclonia. La ficha declara Mineclonia/MTG y el `mod.conf` leído requiere **`m7a`**; `mcl_core`, `mcl_trees`, `mcl_biomes` y otros son opcionales. Integrarlo entero agrega registro de plantas/biomas/decoración y ocupa mapgen; no es sólo un paquete de modelos. Reutilizar únicamente un boulder/rubble/familia vegetal implicaría inspeccionar cada textura/esquema, sus nombres y dependencias. **Código GPL-2.0-or-later según ficha/`LICENSE`; licencia de medios por archivo no quedó verificada**, así que no extraerlos aún. WIP, release 1.0.4 de marzo de 2026. Compatibilidad declarada + esquemas MCL inspeccionados; no prueba de la versión objetivo. Dificultad alta para una selección parcial.

8. **[Rocks — ContentDB](https://content.luanti.org/packages/Just_Visiting/rocks/)**. Ocho modelos y cinco formas/skins de roca deliberadamente no cúbicas para cuevas, ríos o construcción. Es el recurso con mejor correspondencia directa con “terreno menos rígido” sin que el mod completo sea necesario. La ficha requiere `default`, ofrece recetas MTG y no anuncia juego compatible; no hay prueba Mineclonia. **Código MIT según ficha; licencia independiente de los modelos/texturas no quedó confirmada** en el material accesible. Mod de 2020, mantenimiento desconocido. Clasificación **parcial/adaptable**: adaptar registro de nodos/tiles a `mcl_core` y omitir recetas MTG; no distribuir modelos hasta resolver licencia y crédito.

9. **[Loose Rocks — ContentDB](https://content.luanti.org/packages/eduardomezencio/loose_rocks/) / [GitHub](https://github.com/eduardomezencio/loose_rocks)**. Rocas pequeñas generadas en superficie/desiertos; el código además define receta de 4 rocas por cobble y retorno. **Código GPL-3.0-or-later; modelos/texturas CC BY-SA 3.0**, con atribución del icono de inventario a Voxelgarden. Dependencia obligatoria `default`, sin soporte MCL declarado; fuente observada muy antigua/as-is. **No usar el mod completo** porque worldgen/receta tocan superficie y progresión. Los modelos/texturas serían candidatos parciales una vez adaptados y con todos sus créditos.

10. **[Hollow Logs for Mineclonia — ContentDB](https://content.luanti.org/packages/dougsouza26/jds_hollow_logs/)**. Añade variantes huecas de troncos/tallos Mineclonia para las familias arbóreas del juego: buen recurso decorativo para construcciones y bosques. La ficha declara compatibilidad por el propio paquete y lista numerosas dependencias (`mcl_trees`, `mcl_core`, `mcl_cherry_blossom`, `mcl_mangrove`, `mcl_pale_oak`, `mcl_structures`, `mobs_mc`, `screwdriver`, entre otras). **Código MIT; media CC BY-SA 3.0.** Maintenance-only; release visible agosto de 2026. No consta si genera de forma natural o sólo permite decoración/craft, así que no atribuyo generación ni compatibilidad exacta. Antes de integración, comprobar nodos disponibles en 0.124.1, dependencias y recetas; clasificar como adaptable/declarado, dificultad media.

11. **[More Trees! — ContentDB](https://content.luanti.org/packages/mt-mods/moretrees/) / [GitHub](https://github.com/mt-mods/moretrees)**. Aporta muchas especies, formas L-system, frutos y cobertura vegetal; código reciente y licencia clara: **LGPL-3.0-only para código, CC BY-SA 4.0 para medios**, `xcompat` requerido. Sin soporte Mineclonia específico en la ficha. Es adaptable, pero la propia Mineclonia ya mantiene una integración de árboles/recursos de More Trees en sus biomas y el checkout tiene su sistema `mcl_trees`/`mcl_levelgen`. Añadirlo entero duplicaría flora, madera y generación; usarlo sólo como referencia o comparar assets que falten. Mantenimiento en ContentDB figura desconocido, aunque el repo tuvo cambios en agosto de 2026. Dificultad alta si se adopta fuera de la integración ya presente.

12. **[Flower Beds — ContentDB](https://content.luanti.org/packages/ZenonSeth/flowerbeds/)**. Decoración para jardines/aldeas construidos por jugadores, sin necesidad de sustituir toda la flora procedural. La ficha anuncia dependencias opcionales MCL (`mcl_core`, `mcl_trees`, `mcl_sounds`) y soporte Mineclonia; requiere comprobar los nodos concretos en 0.124.1. **Código LGPL-2.1-or-later; medios CC BY-SA 3.0.** Mantenimiento-only, versión 2.1.1 de enero de 2026. Compatible declarado, no runtime; impacto pequeño y dificultad baja-media. Candidato secundario para construcción, no para mapgen.

13. **[Mcl Mushrooms 3D — ContentDB](https://content.luanti.org/packages/erlehmann/mcl_mushrooms_3d/) / [repositorio Mesehub](https://git.minetest.land/erle/mcl_mushrooms_3d)**. Una intervención visual pequeña sobre las dos variedades de hongos pequeños (`mcl_mushrooms:mushroom_brown/red`), que hoy son sprites `plantlike` en el checkout. Su autor declara haberlo probado con Mineclonia; esa declaración no identifica versión y el repo listado tiene una única importación de 2022. Requiere `mcl_mushrooms`. **Ficha: AGPL-3.0-or-later; la licencia separada de media/modelo no se pudo comprobar y el contenido fuente no fue descargado.** Candidato de prueba aislada, no de adopción automática; primero leer el código/modelo y verificar licencia, compatibilidad de API y rendimiento.

### 3. Agua, luz y técnicas de ambiente

14. **[Water Overhaul — ContentDB](https://content.luanti.org/packages/TomCon/water_overhaul/)**. Permite ajustar sonidos de pasos/entrada/burbujas y niebla bajo el agua. Release 1.0.3 declara compatibilidad Mineclonia/VoxeLibre y especifica que, si el juego ya tiene niebla, usa la del juego y limita el cambio a sonidos. Esto coincide con el `mcl_weather` actual, que ya pinta niebla de agua; por eso la parte visual probablemente sea redundante y hay que probar sonidos sin duplicarlos. **Código MIT; medios CC0-1.0** (ficha/atribución del paquete). Activo según ficha, última actualización diciembre de 2025. Dependencias y código exactos no se inspeccionaron. Directo declarado, impacto visual pequeño, posible utilidad sonora.

15. **[NV Relight — GitHub](https://github.com/sjhari7112-dev/nv-relight)**. El autor declara pruebas con Mineclonia y Luanti 5.17.0, lo que lo hace interesante para un prototipo posterior, no una prueba nuestra. Cambia la iluminación de mapblocks antiguos y conserva un índice en `mod_storage`. **Código GPL-3.0-or-later; no se identificó media propia.** Riesgos publicados: iluminación artificial puede filtrar a la superficie/noches, almacenamiento que crece con exploración y falta de afinado para servidores grandes; puede alterar lectura de oscuridad/spawning. Muy reciente (octubre de 2026), pocos commits. **No recomendado** en la combinación base.

16. **[K Ambient Light — ContentDB](https://content.luanti.org/packages/ketwaroo/k_ambient_light/)**. Ficha declara pruebas Mineclonia y código GPL-3.0-or-later; actúa sobre la luz de nodos. No se descargó ni inspeccionó la implementación ni medios por separado. Puede alterar contraste de cuevas, noches, spawns y bloques de iluminación. **No combinar con NV Relight** ni adoptarlo sin experimento de rendimiento/comportamiento.

### 4. Modelos de NPC, mob, equipo y estructuras

17. **[Armor Stand with Arms — ContentDB](https://content.luanti.org/packages/nandology/armor_stand_arms/)**. Extiende el modelo/icono de armor stand MCL para exhibir armadura, arma y escudo; sirve a construcciones y talleres sin sustituir las entidades ni la armadura de jugador. Usa la API/modelo de `mcl_armor_stand` que viene en Mineclonia/VoxeLibre; requiere `mcl_armor`, `mcl_armor_stand`, `mcl_core`, `mcl_sounds`, `mcl_stairs` y `screwdriver`. **Código LGPL-2.1-or-later; modelos/texturas CC BY-SA 3.0**, derivaciones declaradas del arte base. Beta, release visible julio de 2026. Compatibilidad Mineclonia declarada, no runtime. Buena opción decorativa opcional, dificultad baja-media; revisar la receta nueva si se intenta conservar estrictamente el catálogo actual.

18. **[Mobs Andes — ContentDB](https://content.luanti.org/packages/ronrob-lu/mobs_andes/) / [GitHub](https://github.com/ronrob-lu/mobs_andes)**. Paquete reciente de modelos/texturas de animales andinos; declara Mineclonia/VoxeLibre y tiene arte licenciada por separado. **Código MIT; gráficos CC BY-SA 4.0.** Pero requiere `mobs` (Mobs Redo), mientras que Everforge usa `mobs_mc`/`mcl_mobs`; además registra nuevos animales y comportamiento. Clasificar como **parcial/adaptable** para arte, no instalar entero si se quiere conservar fauna, NPC y ecología. Convertir rigs/animaciones al sistema MCL puede costar más que reutilizar modelos ya incluidos.

19. **[Animalia — ContentDB](https://content.luanti.org/packages/ElCeejo/animalia/)**. Biblioteca visual atractiva de animales y animaciones; requiere `creatura` y aporta fauna/ecología nueva. La ficha indica MIT para el paquete, pero no separa claramente la licencia de todos los medios en la metadata consultada: **verificar archivo por archivo antes de extraer modelos/texturas**. Compatibilidad general, no Mineclonia específica. Útil como inspiración/estudio, no como mod completo: duplicaría criaturas y añadiría comportamiento.

20. **[Extra Structures for Mineclonia/VoxeLibre — ContentDB](https://content.luanti.org/packages/mt-mods/mcl_extra_structures/)**. Release 1.5.0 porta estructuras a `mcl_levelgen` (Mineclonia 0.116+), con dependencias `mcl_enchanting`, `mcl_init`, `mcl_loot` y opcionales de estructuras/generación. **Código GPL-3.0-or-later; licencia de medios/esquemas por autor no se pudo confirmar.** Contiene, entre otras, cementerio y torre de hielo, que se solapan directamente con estructuras Everforge existentes. No integrar entero; como máximo estudiar un esquema independiente después de auditar su procedencia. Activo según ficha, última actualización diciembre de 2025; compatibilidad declarada, no runtime.

21. **[3D Armor — ContentDB](https://content.luanti.org/packages/stu/3d_armor/)**. **Código LGPL-2.1-only; medios CC BY-SA 3.0**. Es una fuente histórica de modelos visibles de armadura para otros juegos, pero Mineclonia ya trae `mcl_armor` y modelos B3D/OBJ propios. Integrarlo como sistema duplicaría la representación del jugador y APIs; no recomendado. Si falta un componente concreto, usar las APIs/modelos nativos antes que migrar player models.

## B) Matriz comparativa resumida

Esfuerzos en **días-persona de revisión/adaptación/QA**, no en descarga. Los rangos suponen una sola persona familiarizada con Lua/Mineclonia y no incluyen arte original adicional.

| Candidato | Compatibilidad/evidencia | Qué conservar / cambios y solapamientos | Impacto | Dificultad | Esfuerzo | Código / medios | Mantenimiento y riesgo |
|---|---|---|---:|---:|---:|---|---|
| Pixel ImPerfection | Directo declarado; repo activo inspeccionado; sin runtime | Pack parcial; comparar con texturas ya integradas en MCL; instalar como perfil cliente | Medio | 1/10 | 0.5–1 d | Sin código / CC BY-SA 4.0 | Activo; pack parcial, buena reversibilidad |
| REFI Textures | Directo declarado en `texture_pack.conf`; sin runtime | Pack amplio; no apilar con otros; excluir branding Everforge | Medio-alto | 1/10 | 1–2 d | Sin código / CC BY-SA 4.0 | Activo; cambios más globales y posibles reemplazos GUI/menu |
| Bauniclonia | Mineclonia-only declarado; sin runtime | Pack global alternativo; no mezclar con REFI/PIP | Medio-alto | 1/10 | 0.5–1 d | Sin código / CC BY-SA 4.0 | WIP; compatibilidad MCL específica, VoxeLibre no soportado |
| Craft & Ruin pack | MCL/VoxeLibre declarado; repo y manifiesto inspeccionados | Reutilizar sólo archivos que falten; mantener GPLv3/créditos | Bajo-medio | 2/10 | 1–2 d | Sin código / GPLv3 en medios | Cobertura parcial; procedencia individual por confirmar |
| Faithful-Clone 32px | Port declarado; licencia de assets no clara | Ningún uso hasta autorización; no es base segura | Alto aparente | 2/10 | No estimable | Sin código / medios sin autorización confirmada | Riesgo legal alto; descartado por licencia, no por resolución |
| Bushy Leaves | MCL IDs coinciden con selector por inspección estática; sin runtime | Reemplazar búsqueda por nombre por whitelist `group:leaves`/IDs MCL; `cheap`; probar en clientes | Alto en bosques | 4/10 | 1–3 d | AGPL-3+ / mallas AGPL-3 | Maintenance-only; selector amplio y coste de malla |
| Natural Habitat | MCL declarado + esquemas MCL inspeccionados; sin runtime | Extraer sólo decoración; convertir nombres/APIs; `m7a`; evitar nuevas biomas al comienzo | Alto en zonas nuevas | 7/10 | 4–10 d | GPL-2+ / medios sin separar | WIP; dependencia y worldgen elevan mantenimiento |
| Rocks | Sin compatibilidad MCL declarada; ficha MTG (`default`); sin runtime | Adaptar registros/tiles; quitar recetas MTG; revisar licencia de cada modelo | Medio | 5/10 | 2–5 d | MIT declarado / media no verificada | Paquete de 2020; adaptación/licencia pendiente |
| Loose Rocks | No MCL declarado; código MTG observado; sin runtime | Sólo media; reescribir nodo/API; excluir receta y generación | Bajo-medio | 5/10 | 2–4 d | GPL-3+ / CC BY-SA 3.0 | As-is, código antiguo; riesgo de progresión/mapgen |
| Hollow Logs | Mineclonia en nombre y dependencias MCL; no runtime | Validar cada dependencia, recipes y disponibilidad de especies | Medio | 3/10 | 1–3 d | MIT / CC BY-SA 3.0 | Maintenance-only; lista de dependencias extensa |
| More Trees! | Juego agnóstico con `xcompat`; MCL ya integra recursos similares | No instalar entero; comparar con árboles MCL actuales; usar sólo si falta algo concreto | Alto si fuera nuevo | 7/10 | 5–12 d | LGPL-3-only / CC BY-SA 4.0 | Último repo activo, ficha sin estado; solapamiento de worldgen |
| Flower Beds | Mineclonia declarado; sin runtime | MCL nodes opcionales; acotado a construcción/jardinería, revisar recetas | Bajo | 2/10 | 0.5–1 d | LGPL-2.1+ / CC BY-SA 3.0 | Maintenance-only; no resuelve vegetación natural |
| Mcl Mushrooms 3D | Autor declara prueba Mineclonia; API/version no verificada | Cambiar sólo dos nodos pequeños; inspeccionar fuente/licencia de modelo primero | Bajo | 2/10 | 0.5–1 d | AGPL-3+ / media no confirmada | Una importación 2022; obsoleto posible |
| Water Overhaul | Mineclonia declarado; fog local confirmado por inspección; no runtime | Probar únicamente audio; conservar `mcl_weather` como dueño de niebla | Bajo | 2/10 | 0.5–1.5 d | MIT / CC0-1.0 | Activo; conflicto de sonido/niebla comprobable en test |
| NV Relight | Autor declara MCL + Luanti 5.17; no runtime propio | Aislar en mundo nuevo/copia; revisar spawn, DB y noches | Medio-alto | 8/10 | 4–8 d | GPL-3+ / sin media propia identificada | Muy reciente; almacenamiento/performance y balance lumínico |
| K Ambient Light | Mineclonia declarado; fuente no inspeccionada | Probar separado de NV Relight; medir light/spawns | Medio | 6/10 | 2–5 d | GPL-3+ / sin media identificada | Posible alteración de gameplay por luz |
| Armor Stand with Arms | MCL/VoxeLibre declarado; modelo base MCL reutilizado | Opcional para display en construcciones; confirmar receta/UX | Bajo | 2/10 | 0.5–1.5 d | LGPL-2.1+ / CC BY-SA 3.0 | Beta; buen ajuste decorativo, no toca mobs |
| Mobs Andes | MCL declarado, pero requiere `mobs` Redo; no runtime | Sólo modelos/texturas tras adaptar `mobs_mc`; no incluir fauna nueva | Alto visual | 7/10 | 5–12 d | MIT / CC BY-SA 4.0 | Activo, pero API/rig diferente y agrega comportamiento |
| Animalia | Juego agnóstico; dependencia `creatura`; sin runtime | Extraer arte sólo con licencia por archivo y conversión de rig | Alto visual | 8/10 | 6–15 d | MIT ficha / medias sin separar | Beta; crea fauna, overlaps y mantiene API distinta |
| Extra Structures | MCL/VoxeLibre declarado; release usa `mcl_levelgen`; sin runtime | No instalar; cementerio/ice tower duplican Everforge; esquemas requieren clearance | Medio | 7/10 | 4–10 d | GPL-3+ / media por autor no confirmada | Activo; mundo/loot/dependencias y duplicados |
| 3D Armor | MTG genérico; duplica `mcl_armor`; sin runtime | No migrar player model; usar modelos MCL del checkout | Bajo para Everforge | 8/10 | No justificado | LGPL-2.1-only / CC BY-SA 3.0 | Sistema redundante y riesgo de conflicto visual |

### Dependencias y riesgos que afectan la matriz

- **No apilar texturas globales.** REFI, Bauniclonia y Pixel ImPerfection actúan sobre nombres de recursos que pueden coincidir; se comparan uno por uno. Pixel ImPerfection es el más parcial; REFI y Bauniclonia son alternativas globales de estilo/cobertura.
- **No añadir More Trees entero.** More Trees ya tiene una integración propia en la distribución MCL y comparte propósito con `mcl_trees`/`mcl_levelgen` del checkout.
- **No sumar `Natural Habitat` + `Rocks` + `Loose Rocks` completos.** Compiten por suelo/decoración; al menos dos cambian mapgen y los loose rocks cambian receta/progresión.
- **No sumar `mcl_extra_structures` a Everforge.** Sus temas de cementerio y torre de hielo repiten la identidad de las estructuras que ya existen.
- **No combinar `NV Relight` y `K Ambient Light`.** Ambos trabajan en lectura de luz; podrían solaparse con el clima/luces MCL y cambiar visibilidad de cuevas, spawns y noches.
- **No dejar que Water Overhaul gobierne la niebla.** Mineclonia ya llama `player:set_sky` con color/niebla submarina; probar sólo audio si no duplica sonidos existentes.
- **Todo mesh/mod servidor tiene coste distinto de un texturepack:** debe estar instalado/servido de forma coherente a clientes y validado con hardware modesto; un texturepack suele ser cliente y reversible.

## C) Tres combinaciones posibles

| Nivel | Composición | Solapamientos/ventajas | Riesgo y uso recomendado |
|---|---|---|---|
| **Conservadora** | Mineclonia actual + **un solo** pack: primero Pixel ImPerfection; si su delta ya está en 0.124.1, comparar REFI o Bauniclonia, uno a la vez. | No toca código, recetas, worldgen, combate, NPC ni guardado. Permite comparar paleta y cobertura de bloques/ítems/mobs con las pantallas Everforge actuales. | Mejor primer paso. El impacto depende de cuántos cambios del pack sigan ausentes en 0.124.1. Branding/logo/icono se mantienen fuera del test. |
| **Equilibrada** | Pack único elegido en el paso conservador + Bushy Leaves `cheap` con whitelist MCL; opcionalmente 3D small mushrooms tras inspección de fuente/licencia. Water Overhaul sólo en audio si la prueba confirma que no duplica sonidos. | Cambia textura y silueta vegetal; los hongos son sólo dos nodos. No exige introducir biomas, animales, recetas o estructura. Cada componente se puede revertir por separado. | Requiere test client/server y medición de hojas en bosques densos. Es la mejor relación cambio/alcance si el resultado visual no se siente demasiado exuberante y se acepta AGPL. |
| **Ambiciosa (laboratorio, no baseline)** | REFI **o** Bauniclonia como pack completo + Bushy Leaves `cheap` + un único origen de decoración no cúbica (selección de Natural Habitat **o** Rocks) + opcional Hollow Logs en construcciones. Ambiente/agua se prueba aparte; no añadir los dos relighters. | Más variedad en copas, rocas y construcciones; permite estudiar recursos de proyectos MCL/MTG sin sustituir el sistema base. | Suma licencias y solapamientos, puede cambiar chunks nuevos y/o añadir muchos nodos/deps. Mantener en mundo desechable; no fusionar assets ni mapgen a Everforge sin auditoría de licencias y aprobación posterior. Excluir More Trees completo, Loose Rocks completo y Extra Structures. |

## D) Combinación recomendada para Everforge

**Recomendación escalonada, reversible y moderada:**

1. **Perfil visual cliente: probar Pixel ImPerfection primero**, comparando el pack con Mineclonia 0.124.1 y descontando las texturas ya incorporadas en el juego. Si su delta no basta, elegir como alternativa REFI (mayor amplitud/contraste) o Bauniclonia (pack exclusivo de Mineclonia); no apilar.
2. **Sólo si el A/B de textura queda bien: probar Bushy Leaves con malla `cheap`, limitada mediante whitelist a `mcl_trees:leaves_…`/grupos de hojas pertinentes.** No copiar sin revisar la licencia AGPL de sus modelos y código. Mantener la hitbox/colisión original y dejar fuera litter, ramas u hojas de objetos que no deban volverse malla.
3. **No adoptar todavía `Natural Habitat`, iluminación global, árboles completos, fauna extra, ni estructuras.** Son mucho más invasivos o duplican subsistemas; sus medios/licencias o rendimiento requieren trabajo adicional.
4. **Mcl Mushrooms 3D queda como microprueba opcional, no como requisito de la recomendación:** el efecto sería pequeño y su fuente/licencia exacta no quedó auditada.
5. **No instalar Water Overhaul por la niebla**; la niebla de Mineclonia ya existe. Si se quiere mejor feedback de agua, evaluar sus sonidos en aislamiento.
6. **Armor Stand with Arms** es el mejor candidato opcional para mejorar displays de herramientas/armas en construcciones, sin reemplazar mobs ni player armor. No es necesario para la primera fase.

Esto conserva el pixel art/escala voxel de Mineclonia y la marca Everforge; la mejora se concentra en un pack de texturas y, si supera prueba, una sola geometría de hojas. La recomendación se basa en licencias, composición y evidencia estática, **no en una preferencia visual demostrada en cliente**.

## E) Plan incremental ejecutable por Codex

Estas son instrucciones para una fase futura aprobada; **no se ejecutaron**.

### Fase 0 — congelar baseline y preparar entorno limpio

1. No tocar esta partida, los archivos funcionales del checkout ni el PR. Crear una copia de prueba nueva/fácil de borrar, con Mineclonia 0.124.1 y Luanti 5.17.0, o un perfil/instancia aparte.
2. Guardar seed/config, resolución, distancia de visión, shaders, jugador/posición y mods activos. Capturar cuatro planos: bosque con cada especie, cueva, agua, y objetos Everforge en hotbar/GUI. Añadir menú sólo para comprobar que el logo/icono permanecen intactos.
3. Registrar hash/version del paquete y sus licencias por archivo; mientras ContentDB siga en mantenimiento, no sustituir el repositorio oficial por descargas de mirrors no verificados.
4. Fijar una baseline de FPS/frametime, RAM cliente/servidor y carga del servidor. Si no se puede medir con estabilidad, no activar mallas ni relighting en multijugador.

### Fase 1 — comparación de textura

1. Instalar **un** pack en un perfil cliente temporal; no añadirlo a las texturas del repo ni al directorio de una save.
2. Probar primero Pixel ImPerfection y comparar su árbol de archivos con las texturas del Mineclonia actual; registrar cuántos assets son realmente distintos/nuevos.
3. Repetir, tras quitar el anterior, con REFI; luego con Bauniclonia sólo si el estilo necesita una alternativa. No combinar packs.
4. Revisar colores/lectura de diamante/adamantine, menas More Ores, iconos de herramientas tintadas, mobs, cuevas, nieve, vegetación e interfaz Everforge. Cualquier alteración de header/icono invalida ese perfil para el propósito del proyecto.
5. Aceptar un pack sólo con decisión visual expresa y evidencia comparativa; si no mejora el conjunto, volver al baseline sin coste de mundo.

### Fase 2 — microprueba de hojas, separada del mapa

1. Leer el source y aviso de AGPL del fork elegido; fijar commit y conservar atribución/licencias.
2. Cambiar la selección amplia por whitelist de nodos MCL comprobados. Mantener `cheap`, no tocar `collision_box`, grupos, desgaste, drops ni ABMs.
3. Cargar sólo en mundo de prueba nuevo y hacer comparación `normal`/`cheap` con bosque representativo, hojas huérfanas, hojas nevadas, bambú, litter y biomas diversos.
4. Verificar join de cliente limpio, errores de carga, malla, alpha/olas, FPS y uso en servidor local. No declarar compatibilidad hasta realizar esta prueba exacta.
5. Revertir si el mesh rompe coherencia de copa, genera artefactos, perjudica low-end o afecta nodos que no son copas.

### Fase 3 — candidato de alcance pequeño opcional

1. Inspeccionar `mcl_mushrooms_3d` y su media antes de decidir; revisar nombres/registro de los dos hongos en Mineclonia 0.124.1.
2. Probar sólo los dos nodos existentes, sin cambiar su drop, generación, hitbox/selection box o registros de mapgen.
3. Mantener Water Overhaul fuera hasta cerrar esta prueba; si se evalúa, desactivar opciones de niebla y comprobar sonidos de agua existentes para evitar dobles reproducciones.
4. Probar Armor Stand with Arms sólo en un mundo creativo desechable, verificando receta y colocación; no requiere un cambio de entidades NPC.

### Fase 4 — alternativas de worldgen, fuera de la recomendación actual

1. Sólo con aprobación separada, elegir **un** paquete de decoración: una familia concreta de Natural Habitat, Rocks o Hollow Logs, no todos.
2. Auditar licencias de schem/modelo/textura y compatibilidad de IDs/deps; excluir recetas y cambios de progresión no necesarios.
3. Hacerlo en seed/mundo nuevo, porque las decoraciones de mapgen suelen afectar sólo chunks generados a partir de la activación. Comparar densidad, biomas, solapamiento con estructuras Everforge/MCL y costo en servidor.
4. No activar hasta que el impacto en rendimiento, distribución de assets y migración de mundos esté aprobado.

### Fase 5 — salida y actualización

1. Crear un manifiesto de recursos, commit fuente, versión de Mineclonia, licencia de código/medios, créditos y pruebas por candidato aprobado.
2. Probar la siguiente actualización Mineclonia sin perder la opción de desactivar el addon; revalidar nombres de nodos, mesh/materiales y texturas reemplazadas.
3. Ningún candidato pasa a la partida o branch principal por el solo hecho de estar en ContentDB o por compatibilidad declarada.

## F) Ahorro de trabajo frente a desarrollarlo desde cero

Estimaciones de planificación, **no mediciones**. No se inventa cuántos archivos modifica cada pack: antes de usar la fórmula hay que contar el delta real contra Mineclonia 0.124.1. Supuestos: una persona competente en pixel art/Blender/Lua; una imagen de bloque/ítem de 16 px lleva **0,5–1,5 h** entre dibujo, consistencia y revisión; un test de pack exige **4–8 h**; una malla compartida simple requiere **4–8 h** entre geometría/ajuste y prueba.

| Trabajo reutilizado | Supuesto explícito | Trabajo original evitado (bruto) | Revisión/adaptación | Ahorro neto ilustrativo |
|---|---|---:|---:|---:|
| Pack de textura elegido | Ejemplo, no conteo verificado: 50 PNG aceptados que sí difieren del juego | 25–75 h (50 × 0,5–1,5 h) | 4–8 h de comparación, licencia y QA | 17–71 h, aprox. 2–9 días-persona |
| Una malla de hoja reutilizada | 8–12 variantes MCL pueden compartir la misma malla/material | 12–24 h para diseñar y mapear desde cero | 8–20 h para whitelist, adaptación y QA multijugador | 0–16 h, aprox. 0–2 días; puede ser neutral si aparecen conflictos |
| Hongos 3D / decoraciones | Sólo si la licencia y el código ya están claros | 4–12 h para dos variantes simples | 4–12 h para revisar fuente, dependencias y nodos | 0–8 h; no contar como ahorro hasta ver el modelo real |
| Sonidos de agua | Reutilizar los CC0 existentes en vez de buscar/grabar/editar sonidos nuevos | 4–12 h de selección/edición básica | 2–6 h para conflictos y prueba | 0–10 h; beneficio bajo y condicionado a que los sonidos hagan falta |
| Mobs/NPC/herramientas | Mineclonia ya aporta B3D/OBJ, rigs, animaciones y sprites | Evita rehacer el catálogo base entero | 0 h de adopción si se conserva el sistema nativo | El ahorro más seguro: no abrir un proyecto nuevo de modelos/rigs sin necesidad |

**Escenario combinado recomendado:** con 50 texturas útiles que falten en el juego y una malla simple que no exija excepciones, el ahorro orientativo es de **2–11 días-persona** (neto de la primera validación). Si el pack casi coincide con la versión actual, o la malla obliga a excepciones, el ahorro puede caer a cero; si las licencias, el port de assets o el costo multijugador requieren refactor, puede ser negativo frente a dibujar una solución mínima propia. No contar como “ahorro” la instalación: el costo real está en detectar el delta, atribuir correctamente los assets, probar visualmente y mantenerlos frente a Mineclonia.

## Conclusión

La secuencia con mejor relación riesgo/beneficio es **A/B de un solo texture pack**, luego —sólo si el resultado lo merece— una prueba controlada de **hojas con mesh `cheap` y whitelist Mineclonia**. Natural Habitat, rocks, iluminación y fauna son opciones válidas para investigar/adaptar, pero elevan riesgos de licencia, worldgen, comportamiento o multijugador y no son necesarios para una mejora visual moderada. El mundo, mecánicas, recetas, combate, NPC, generación y recursos de marca quedan sin cambios en esta investigación.

**Estado de la prueba:** no realizada. No hay binario Luanti disponible en el entorno de investigación y ContentDB mostraba mantenimiento; se hizo inspección documental/estática solamente. **No se afirma compatibilidad runtime.**

## Fuentes principales

- [Pixel ImPerfection en ContentDB](https://content.luanti.org/packages/bramaudi/pixel_imperfection/) · [repositorio Mineclonia](https://codeberg.org/mineclonia/pixel_imperfection)
- [REFI Textures en ContentDB](https://content.luanti.org/packages/MysticTempest/refi_textures/) · [GitHub](https://github.com/MysticTempest/REFI_Textures)
- [Bauniclonia en ContentDB](https://content.luanti.org/packages/Mirtilo/bauniclonia/) · [Codeberg](https://codeberg.org/mirtilo/Bauniclonia)
- [Craft & Ruin Texture Pack](https://content.luanti.org/packages/GamingAssociation39/craft_and_ruin/) · [GitHub y licencia](https://github.com/Gerold55/craft_ruin_texture_pack)
- [Faithful-Clone](https://github.com/Zormein/Faithful-Clone)
- [Bushy Leaves fork](https://content.luanti.org/packages/EmoryNB/bushy_leaves/) · [Codeberg/source y `models/license.txt`](https://codeberg.org/EmoryNB/bushy_leaves)
- [Natural Habitat](https://content.luanti.org/packages/Mish7913/natural_habitat/) · [GitLab/source](https://gitlab.com/Mish7913/natural_habitat)
- [Rocks](https://content.luanti.org/packages/Just_Visiting/rocks/) · [Loose Rocks](https://content.luanti.org/packages/eduardomezencio/loose_rocks/) · [source](https://github.com/eduardomezencio/loose_rocks)
- [Hollow Logs for Mineclonia](https://content.luanti.org/packages/dougsouza26/jds_hollow_logs/) · [More Trees!](https://content.luanti.org/packages/mt-mods/moretrees/) · [GitHub](https://github.com/mt-mods/moretrees)
- [Flower Beds](https://content.luanti.org/packages/ZenonSeth/flowerbeds/) · [Mcl Mushrooms 3D](https://content.luanti.org/packages/erlehmann/mcl_mushrooms_3d/) · [Mesehub source listing](https://git.minetest.land/erle/mcl_mushrooms_3d)
- [Water Overhaul](https://content.luanti.org/packages/TomCon/water_overhaul/) · [NV Relight](https://github.com/sjhari7112-dev/nv-relight) · [K Ambient Light](https://content.luanti.org/packages/ketwaroo/k_ambient_light/)
- [Armor Stand with Arms](https://content.luanti.org/packages/nandology/armor_stand_arms/) · [Mobs Andes](https://content.luanti.org/packages/ronrob-lu/mobs_andes/) · [Animalia](https://content.luanti.org/packages/ElCeejo/animalia/)
- [Extra Structures for Mineclonia/VoxeLibre](https://content.luanti.org/packages/mt-mods/mcl_extra_structures/) · [3D Armor](https://content.luanti.org/packages/stu/3d_armor/)
- [Aviso de mantenimiento de ContentDB](https://blog.luanti.org/2026/10/27/contentdb-security-incident/)
