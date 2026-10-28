# Auditoría de progresión de Everforge sobre Mineclonia

**Corte de inspección:** 28 de octubre de 2026

**Objetivo declarado:** Luanti 5.17.0 / Mineclonia 0.124.1

**Alcance:** inspección estática del checkout de `SegundoIntento`; no se instalaron mods y no se modificó código funcional.

## 1. Resumen ejecutivo

Everforge no parte de una base vacía: el juego empaqueta sistemas aprovechables de experiencia, avances, eventos, dimensiones, aldeas/comercio, desafíos de combate, recompensas, equipo, efectos y generación. El principal vacío no es la falta de mecánicas, sino la falta de una capa que registre y conecte de forma duradera las tres progresiones —personaje, mundo e historia— con semánticas claras y sin acoplarlas entre sí.

- **Personaje — IMPLEMENTADO, parcialmente.** Mineclonia ya guarda XP/nivel del jugador y la integra con combate, minería de ciertos nodos, hornos, pesca, crianza y comercio. Everforge agrega puntos/habilidades y elección de clase. No se encontró una progresión general de disciplinas por práctica, ni una capa de desbloqueos de recetas/planos por jugador. El código actual de clases es un sistema heredado que debe distinguirse del objetivo acordado: no diseñar clases nuevas ni convertirlas en restricciones de uso.
- **Mundo — PARCIAL.** Hay cambios físicos persistentes, dimensiones, generación, dificultad regional, aldeas, raids, asedios, trials y vaults. Parte de estos son sistemas de juego reales y reutilizables, pero no constituyen un registro común de hitos o capítulos del mundo. Las instancias de `mcl_events` son temporales; las raids guardan su estado activo, no un historial general de victorias.
- **Narrativa — PARCIAL en avances; INEXISTENTE como gestor de misiones/campaña integrado.** `awards`/`mcl_achievements` ofrecen UI, triggers, progreso personal, persistencia y callbacks. Mineclonia registra avances de supervivencia, pero las definiciones inspeccionadas no emplean los campos disponibles `requires`/`prizes`; no hay una cadena de misiones, diario, objetivos compuestos, sistema de diálogos narrativos ni seguimiento de capítulos compartido con Everforge.
- **Reutilización primero.** La base aconsejable es conservar los sistemas Minecraft/Mineclonia, conectar sus callbacks/APIs y agregar, solo cuando haga falta, un adaptador de progresión persistente. No se recomienda instalar ahora un framework externo ni alterar recetas, balance, generación o NPC.
- **Estado de validación.** Todo lo descrito como implementado está confirmado por lectura de código, no por una partida de prueba. El repositorio identifica Mineclonia 0.124.1; `game.conf` declara una versión mínima de Luanti 5.10, lo que no certifica por sí mismo Luanti 5.17.0. No hay `world.mt`, por tanto la activación/configuración efectiva de mods en una partida concreta es **NO VERIFICADO**.

### Recomendación central

Separar tres dominios de estado y enlazarlos mediante eventos idempotentes:

1. **Personaje (personal):** XP vanilla de Mineclonia y metadatos personales para futuras disciplinas/hitos. Mantener el actual pool de puntos generales si se decide reutilizarlo, pero no usar clase permanente como llave de acceso. No mezclar la XP que puede perderse al morir con un registro duradero de práctica sin una decisión explícita.
2. **Mundo (compartido):** hechos de mundo en `mod_storage` —por ejemplo, hitos de raid o estado de capítulo si luego se aprueba— distintos del estado temporal de `mcl_events` y del dato físico de nodos. Decidir expresamente si un hito es global o individual.
3. **Narrativa (por jugador, con lecturas opcionales del mundo):** reutilizar avances/triggers como registro de logros y señales de objetivos; incorporar persistencia compuesta solo si se necesita una campaña/diario. La narrativa nunca debería bloquear el avance normal de Minecraft salvo decisión posterior.

Este es un esquema técnico de conexión, no un diseño de historia, clases, habilidades o misiones.

## 2. Método, etiquetas y límites

La auditoría leyó definiciones, dependencias, APIs, callbacks y persistencia en el repositorio. Las categorías tienen estos significados:

- **IMPLEMENTADO:** aparece código para esa capacidad en el bundle revisado. No implica prueba en runtime.
- **PARCIAL:** existe una parte, pero no la capacidad completa descrita en la fila.
- **DISPONIBLE SIN UTILIZAR:** hay una API/campo/callback reutilizable que las definiciones actuales inspeccionadas no usan para ese propósito.
- **PROPUESTO:** recomendación de arquitectura futura, no código presente.
- **INEXISTENTE:** no se encontró ese sistema en el alcance inspeccionado. Es una conclusión acotada al checkout, no una afirmación sobre todos los mods externos posibles.
- **NO VERIFICADO:** requiere comprobar configuración o comportamiento en un mundo/servidor real.

**Separación de evidencias:**

- **Código:** inspección estática de las rutas citadas abajo.
- **Runtime:** no ejecutado; no se inició Luanti ni se creó/cargó un mundo.
- **Pendiente de prueba:** activación por mundo, progresión real, reinicios/crashes, comportamiento multijugador y compatibilidad efectiva con Luanti 5.17.0.

## 3. Mapa de sistemas incluidos y estado de integración

El juego base contiene muchos mods; el inventario aquí se limita a los sistemas relevantes para las tres progresiones, no es un listado de todos los mods del repositorio. Las dependencias en `mod.conf` prueban relación declarada, no que cada mod esté habilitado en una save específica.

| Dominio | Sistema/mod del bundle | Qué aporta hoy | Integración con Everforge | Persistencia/alcance | Evidencia principal |
|---|---|---|---|---|---|
| Personaje | `mcl_experience` | XP, niveles, obtención y pérdida/derrame al morir; `get_xp`, `set_xp`, `add_xp`, callbacks de adición | Everforge usa un callback para ajustar XP bajo ciertas condiciones; no existe progresión de disciplinas | XP personal en player metadata | `mods/HUD/mcl_experience/init.lua`, API y callback `register_on_add_xp`; `mods/MISC/everforge/init.lua` |
| Personaje | `everforge` | Clases, habilidades/puntos, forja/equipo, contenido de mazmorra y escalado | Integración directa con XP, física, daño, equipo, mobs, mapas/niveles y UI declarada en `mod.conf` | Datos de jugador y metadata de nodos/entidades según subsistema | `mods/MISC/everforge/init.lua`, `mods/MISC/everforge/mod.conf` |
| Personaje | `playerphysics` | Factores combinables para movimiento/FOV y API de alta/baja/consulta | Extensible por ID; no es un árbol de talentos | Serializa factores en metadata del jugador | `mods/PLAYER/playerphysics/init.lua`, `add_physics_factor`/`remove_physics_factor` |
| Personaje | `mcl_damage` | Modificadores y callbacks de daño | Punto de extensión para efectos/stat modifiers; no contiene builds de personaje | Atributos/effects del juego | `mods/CORE/mcl_damage/` |
| Personaje | armadura, herramientas, encantamiento, pociones, yunque, smithing | Equipo y mejoras vanilla/Mineclonia; efectos temporales | Reutilizable como catálogo y motor; no se encontró una regla general que impida equipar por clase/nivel | Ítems/inventarios/nodos; efectos con hooks de ciclo de vida | `mods/ITEMS/mcl_armor/`, `mcl_enchanting/`, `mcl_potions/`, `mcl_anvils/`, `mcl_smithing_table/`, `mcl_tools/` |
| Personaje | `toolranks` | Cuenta bloques minados y muestra rango en el ItemStack | Métrica de uso de herramienta, no XP de disciplina ni bonus | Metadata del ItemStack | `mods/ITEMS/toolranks/init.lua`, `rank_stack`, `new_afteruse` |
| Narrativa | `awards` + `mcl_achievements` | Avances, triggers, seguimiento/UI, callbacks, progreso y persistencia personal | Buen sustrato de logros y señales; no lo usa Everforge como campaña | Registro de jugador | `mods/HUD/awards/`, `mods/HUD/mcl_achievements/init.lua` |
| Mundo | `mcl_worlds` | Overworld/Nether/End/void, detección de dimensión y dificultad regional | Callback de cambio de dimensión cada segundo puede señalar exploración | Dimensión previa en tabla temporal; tiempo habitado por chunk y tiempo de mundo | `mods/CORE/mcl_worlds/` |
| Mundo | `mcl_levelgen`, estructuras, biomas, aldeas | Mapgen, estructuras, pueblos y puntos de interés | Everforge registra contenido en el pipeline de niveles; aldeas dan eventos de POI | Bloques/mapgen y datos de aldeas/POI; mapgen afecta chunks aún no generados | `mods/MAPGEN/mcl_levelgen/`, `mcl_structures/`, `mcl_biomes/`, `mcl_villages/` |
| Mundo | `mcl_events` | Eventos con condiciones, progreso/etapas, finalización y bossbars | Marco útil para encuentro temporal, no como diario global | Instancias activas en memoria; se limpian al no haber jugadores próximos | `mods/CORE/mcl_events/init.lua`, `API.md` |
| Mundo | raids / zombie sieges | Raids con estado activo serializado; asedios disparados desde `mcl_events` por condiciones/POI | Mecanismos de actividad que pueden disparar futuros triggers | Raid activa se guarda; asedio usa el estado temporal de evento; no hay historial global común | `mods/ENVIRONMENT/mcl_raids/init.lua`, `mcl_zombie_sieges/init.lua` |
| Mundo | trial spawners / vaults | Oleadas, cooldown, llaves/loot, vault con recompensa individual | Encuentros y recompensas reusables sin crear otro sistema de combate | Metadata de nodo; ObjectRefs de mobs de trial viven en memoria; vault mantiene una lista acotada | `mods/ITEMS/mcl_trial_spawners/init.lua`, `mcl_vaults/api.lua`, `mcl_vaults/init.lua` |
| Mundo/personaje | aldeanos y trades | Profesiones, nivel de oficio, inventario de trades, gossip/reputación individual y precios | Callbacks de spawn/comercio y registro de profesiones; no son API de misión ni facción | Gossip/reputación por jugador se guarda como datos del aldeano; datos de aldeas en mod storage | `mods/ENTITIES/mobs_mc/villager.lua`, `mods/MAPGEN/mcl_villages/api.lua`, `utils.lua` |
| Narrativa/presentación | libros, mapas, señales, `doc`, formspec/HUD | Herramientas de presentación e información | Posibles contenedores de lore/ayuda; sin seguimiento de capítulo común | Según objeto/juego | `mods/ITEMS/mcl_books/`, `mcl_maps/`; `mods/CORE/doc/`, `mods/HUD/mcl_inventory/` |
| Externo | `TeTpaAka/quests` | Framework de quests con API, HUD/formspec y guardado propio | Candidato de evaluación únicamente; no está instalado ni integrado | Su repositorio describe guardado de activas/completadas/fallidas al apagar | [Repositorio](https://github.com/TeTpaAka/quests), [README](https://github.com/TeTpaAka/quests/blob/master/README), [core.lua](https://github.com/TeTpaAka/quests/blob/master/core.lua) |

### Dependencias relevantes

- `everforge/mod.conf` declara `mcl_experience`, `mcl_player`, `playerphysics`, `mcl_tools`, `mcl_armor`, `mcl_mobs`, `mcl_biomes`, `mcl_levelgen`, `mcl_worlds`, `doc`, `mcl_inventory`, `mcl_enchanting`, `toolranks`, `mcl_damage`, `moreores`, `adamantine` y otras dependencias; `mcl_loot`, `mcl_sounds` y `mcl_bossbars` aparecen como opcionales.
- `mcl_achievements` depende de `awards` y `mcl_levelgen`; `mcl_events` depende de `mcl_mobs`, `mcl_bossbars` y `mcl_info`; `mcl_villages` depende de `mcl_structures`, `mcl_levelgen`, `mobs_mc` y sistemas de bloques/loot.
- No hay `world.mt` en el checkout. Por ello no se puede distinguir el bundle/declaración de dependencias del conjunto activado en un mundo concreto, ni verificar settings de mapgen/eventos.
- `README.md` identifica Mineclonia 0.124.1; `game.conf` fija mínimo Luanti 5.10. La ejecución exacta en 5.17.0 queda **NO VERIFICADA**.

## 4. Progresión del personaje

### XP y niveles

**IMPLEMENTADO en Mineclonia.** `mods/HUD/mcl_experience/init.lua` expone lecturas/escrituras/adición de XP y niveles; la XP del jugador usa metadata `xp`. La API permite registrar callbacks de adición con prioridad, un punto apropiado para observar/adaptar ganancias sin reemplazar el sistema. Everforge ya registra uno para aplicar su ajuste contextual.

Fuentes encontradas en código: mobs hostiles, bloques con grupo `xp`, recogida de XP de hornos, pesca, crianza, comercio de aldeanos y premios de ciertos avances/loot. No se confirmó que toda fabricación general o la mera exploración conceda XP vanilla al jugador. Al morir sin `mcl_keepInventory`, Mineclonia pone la XP actual a cero y la suelta en orbes. Eso hace que el XP vanilla no sea necesariamente un registro histórico duradero de práctica.

**DISPONIBLE SIN UTILIZAR para progresión por práctica:** callbacks de acciones (dignode, crafting, trades, muertes) y callbacks de XP podrían alimentar contadores separados por actividad. La inspección no encontró en Everforge una tabla de dominio que mantenga niveles de práctica independientes (p. ej. minería vs. combate) ni un modelo de “XP de disciplina”.

### Clases, skills y puntos

**IMPLEMENTADO en Everforge, pero no equivale al modelo de progresión objetivo.** `mods/MISC/everforge/init.lua` contiene selección/estado de clase, skills/puntos y efectos asociados. Los puntos se obtienen por escalones de nivel de XP y se asignan al sistema existente. Hay modificadores asociados a clase que afectan stats/combate/movimiento y/o interacción con forja/mazmorra; los valores y condiciones concretos están en ese archivo.

La pauta acordada para el futuro es diferente: **sin clase permanente ni restricciones de clase**, con disciplinas que progresan por práctica y puntos generales compartidos. Por tanto:

- No se deben añadir clases nuevas ni nuevas puertas de acceso de clase.
- No se debe describir la selección actual como progresión por práctica: el nivel base proviene de XP global.
- El pool de puntos actual es una pieza potencialmente reutilizable, pero su convivencia con la selección de clase requiere decisión/migración futura; esta auditoría no cambia su estado ni balance.
- No se encontró una biblioteca de habilidades activas, árbol de habilidades por profesión, o sistema general de desbloqueo por jugador para recetas/planos.

### Equipo, requisitos, encantamientos, pociones y forja

**IMPLEMENTADO como progresión de equipo Minecraft, no como desbloqueo de build.** Mineclonia aporta materiales/tier, durabilidad, diggroups, armadura, encantamientos, pociones, yunque, smithing y recetas. La mesa de encantamiento comprueba nivel de XP y lapislázuli (`mcl_enchanting/engine.lua`, comprobación de `level_requirement` y descuento de niveles); el yunque calcula y cobra niveles por operación (`mcl_anvils/init.lua`). Esos costes son requisitos de operación, no un sistema de clase.

`mcl_armor.register_set`, `mcl_potions.register_effect`, las APIs de `playerphysics` y `mcl_damage` son puntos de extensión para atributos/efectos. **No** son un árbol de talentos ni un sistema de recetas investigadas.

**Toolranks** es especialmente importante para no sobreinterpretar: `mods/ITEMS/toolranks/init.lua` declara que la adaptación solo guarda y muestra rango/conteo en el ItemStack y deja intactos diggroups, daño y desgaste; por eso sirve como telemetría de herramienta, no como bonus de minería o XP de personaje.

**Vacío confirmado en el alcance:** no se encontró un gate genérico de equipamiento por nivel/clase, ni una investigación que desbloquee recetas por jugador. Las limitaciones de tier normales de Mineclonia y requisitos de mesa/anvil no son equivalentes a eso.

## 5. Progresión del mundo

### Generación, dimensiones y dificultad

**IMPLEMENTADO/PARCIAL.** Mineclonia genera mundo, biomas, estructuras y dimensiones. El callback de `mcl_worlds` puede detectar cambio de dimensión y, por tanto, es reutilizable para una señal personal de exploración. No es un diario: la dimensión anterior está en memoria y la detección periódica no reconstruye entradas ocurridas mientras el jugador estaba desconectado.

`mcl_worlds.get_regional_difficulty(pos)` combina tiempo de mundo y tiempo habitado por chunk; es progresión ambiental de dificultad, no una campaña. Everforge aplica escalado contextual a mobs nativos Mineclonia del Overworld según profundidad/proximidad y guarda marcas/multiplicadores en entidad. No se encontró en esto un contador global de zonas despejadas o historia.

Everforge registra elementos de mazmorra en `mcl_levelgen` y sus spawners/cache mantienen marcas en metadata de nodo (`everforge:spawned`, `everforge:initialized` según los bloques correspondientes). Son estados locales persistibles, no registro de mundo/progreso por jugador. La generación afecta principalmente chunks futuros; no se debe asumir que el contenido aparece retroactivamente en un mundo ya generado. Condiciones/settings y generación efectiva quedan pendientes de prueba.

### Eventos, raids, asedios y trials

- **`mcl_events`: PARCIAL/DISPONIBLE.** API de evento con condiciones, etapas, progreso y bossbars; instancias activas en memoria y descarte al no haber jugadores próximos. No es almacén histórico persistente de eventos mundiales.
- **Raids: IMPLEMENTADO.** La lista de raids activas se serializa en mod storage en apagado y se restaura al cargar. Eso permite reanudar actividad activa; no conserva un registro general de “esta aldea/servidor ya venció X raids”.
- **Zombie sieges: IMPLEMENTADO como evento temporal.** Se conectan a `mcl_events`, con condiciones de hora/seed y heat de POIs de aldea; no añaden estado histórico global.
- **Trial spawners: IMPLEMENTADO como reto local.** Oleadas, límite, cooldown (30 minutos), lista de participantes y recompensas/llaves. Estado de nodo persiste, pero colección de ObjectRefs de mobs se mantiene en memoria; reanudación completa después de reinicio/cierre abrupto **NO VERIFICADA**.
- **Vaults: IMPLEMENTADO como recompensa individual en bloque.** Loot y lista de jugadores se guardan en metadata. `mcl_vaults_looter_list_length` tiene default 128 y máximo 1024: no es “una vez por jugador para siempre” si el ringbuffer puede sobrescribir entradas antiguas.

Son componentes de buen valor de reutilización para encuentros/retos, pero no equivalen a una estructura de capítulo, objetivo compuesto o campaña compartida.

### Aldeas, reputación, NPC y economía

**IMPLEMENTADO parcialmente, local y personal.** `mcl_villages` conserva datos de aldeas/POI en mod storage y expone callbacks como `register_on_village_placed`/`register_on_villager_spawned`. `mobs_mc.register_villager` admite profesiones, trades y regalos. Los aldeanos guardan gossip y reputación por nombre de jugador; comerciar incrementa experiencia/tier del aldeano y registra gossip, y la reputación repercute en precios/relación comercial.

No se encontró reputación global por facción, control territorial, economía de servidor o API NPC de quests/diálogo. Los aldeanos tienen comercio y estados propios: no asumir que ya son NPC narrativos. No se propone modificarlos en esta fase.

### Estado global compartido

**INEXISTENTE como capa transversal en el código revisado.** El mundo guarda sus datos físicos; aldeas y raids tienen sus propios almacenamientos; cada jugador tiene avances/reputación personal; Everforge conserva estados de bloques/entidades. No se encontró un registro unificado de descubrimientos, jefes vencidos, hitos de mundo, historia global o consecuencias encadenadas que conecte esos subsistemas.

## 6. Progresión narrativa y opciones A/B/C

### Avances y mecanismos de registro

`mods/HUD/awards/` proporciona registro de logros, triggers y seguimiento/persistencia de jugador. `mcl_achievements` registra 63 avances base; además hay 6 definiciones en una sección opcional para no-PC, desactivada por defecto en el código (`non_pc_achievements = false`). Hay tres avances Mineclonia con premio explícito de XP (50, 100, 50).

Los triggers inspeccionados cubren categorías como chat, entrar, matar, cavar/colocar, fabricar, comer y estructuras. Tres avances Mineclonia otorgan XP explícita: 50, 100 y 50. El código framework admite `requires`, `prizes` y callbacks, pero las definiciones de Mineclonia revisadas no usan `requires` ni `prizes`; por consiguiente, **DISPONIBLE SIN UTILIZAR** para secuencias/premios en ese catálogo, no una cadena que ya esté activa.

La progresión normal de Minecraft/Mineclonia está presente como juego —logros vanilla, equipo/recursos, Nether/End, bosses y exploración— pero sus avances no forman un guion de Everforge. Los objetos de libros/mapas/documentación y los formspec/HUD podrían presentar información, pero no hay diálogo de historia ni objetivo compuesto integrado con ellos. No se encontró diario de misiones, seguimiento/capítulos, mapa narrativo con objetivos, o quest giver funcional.

### Comparación neutral de alternativas

| Opción | Qué significaría técnicamente (sin diseñar contenido) | Reutilización actual | Brecha principal | Ajuste al alcance |
|---|---|---|---|---|
| **A. Campaña opcional** | Hitos/cadena narrativa voluntaria en paralelo al survival | `awards` triggers/callbacks; libros, estructuras, dimensiones; estado personal | Representar objetivos encadenados/compuestos y UI de seguimiento; definir persistencia | **Mejor encaje inicial** si se quiere añadir historia sin cambiar ritmo ni bloquear progresión vanilla |
| **B. Narrativa guiada** | Secuencia clara de objetivos, registro y presentación al jugador | `awards` como milestones y triggers existentes; eventos y contenido vanilla | Diario/quest state, requisitos multiobjetivo, UI/presentación y posiblemente callbacks narrativos | Viable, pero requiere más capa de seguimiento; no implica imponer gates al contenido normal |
| **C. Narrativa emergente** | Resultados nacen de eventos de mundo, reputación, descubrimientos y actividad de jugadores | `mcl_events`, raids/sieges, dimensión, aldeas/gossip, trials/vaults | Historial duradero, resolución de eventos a estado narrativo, diálogo/ramificaciones; separar estado por jugador y mundial | Reutiliza más sistemas existentes, pero es la mayor brecha de persistencia y orquestación |

No se escoge una campaña ni se propone texto/personajes/misiones: esa decisión y el diseño narrativo quedan fuera de esta auditoría.

## 7. Integraciones posibles (prioridad a APIs existentes)

| Señal existente | Consumidor técnico posible | Uso potencial (no implementado) | Límite que debe respetarse |
|---|---|---|---|
| `mcl_experience.register_on_add_xp` y callbacks de acciones | Capa de progresión de personaje | Observar XP; contar práctica separada por actividad cuando la acción esté confirmada | No confundir nivel vanilla con disciplina ni con el pool de puntos; la XP puede perderse al morir |
| Awards/triggers + callbacks | Adaptador de hitos o narrativa | Registrar milestones personales y notificar a otros sistemas | Estado actual es principalmente por jugador; no resuelve estado mundial compartido |
| `mcl_worlds.register_on_dimension_change` | Descubrimiento/exploración | Emitir evento al entrar en dimensión | Se actualiza periódicamente y usa estado temporal; requiere evitar duplicados |
| `mcl_events` | Encuentros/eventos | Presentación en vivo, etapas y progreso de evento | Mantener aparte una copia persistente si el hecho debe sobrevivir/reanudarse |
| callbacks de raids, aldeas y comercio | Estado de mundo/relación | Detectar inicio/resultado de actividad o relación comercial | La API examinada no ofrece historial de capítulo; la reputación es por aldeano/jugador |
| Trial spawner y vault | Retos/recompensas | Encadenar evidencia de encuentro/loot a un achievement | Definir semántica de participación individual/grupal y probar recuperación |
| `playerphysics`, `mcl_damage`, `mcl_potions`, `mcl_armor` | Efectos de stats y equipo | Aplicar efectos de una progresión que se defina posteriormente | No crear balance/skills nuevos en esta fase; integrar sin duplicar efectos vanilla |
| libros, `doc`, HUD/formspec, `mcl_inventory` | Presentación | Mostrar hitos/estado/ayuda | El repositorio no contiene una UI de campaña integrada |

**Patrón recomendado:** adaptadores pequeños que conviertan callbacks nativos en eventos identificables; suscriptores independientes para el estado personal, el estado del mundo y los avances. Guardar cada transición de forma idempotente para no duplicar progreso por callbacks repetidos. Evitar depender de un `globalstep` de sondeo si ya hay callback de acción.

## 8. Brechas y prioridad

| Brecha | Categoría | Qué existe ya | Qué falta | Prioridad sugerida |
|---|---|---|---|---|
| Confirmación de mods/settings en una save real | NO VERIFICADO | Bundle y dependencias declaradas | `world.mt`, settings, logs de carga y runtime objetivo | P0 — antes de planificar integración |
| Separación de XP base, práctica y puntos | PARCIAL | XP vanilla, callback; puntos/skills Everforge | Contrato de datos, semántica de muerte, migración; sin clase como gate | P1 |
| Reconocimiento persistente de acciones | PARCIAL | Triggers de awards y callbacks nativos | Adaptadores/eventos tipados e idempotencia | P1 |
| Registro transversal del estado del mundo | INEXISTENTE | Persistencias locales por mod | Esquema mundial durable y política personal/compartida | P1 para B/C; P2 para A |
| Seguimiento de objetivos compuestos | INEXISTENTE | Avances individuales y eventos con etapas | Diario/estado de quest si el producto lo requiere | P1 para B; P2 para A/C |
| Diálogo/ramificación narrativa NPC | INEXISTENTE | Profesiones, trades, gossip y hooks de aldeano | Presentación/estado narrativo; cambios NPC requieren aprobación separada | No iniciar sin decisión de alcance |
| Desbloqueo de recetas/planos por jugador | INEXISTENTE | Recetas, crafting y equipo estándar | Registro y UI de unlocks | No priorizar: no pedido para esta fase |
| Historial seguro de eventos tras reinicio | PARCIAL | Algunas persistencias (raids, bloques, vault) | Pruebas de crash/restart; persistir resultado si se necesita | P1 |
| UI de personaje/narrativa unificada | INEXISTENTE | HUD/formspec de mods individuales | Presentación integrada con `mcl_inventory` | P2, luego del modelo de estado |

## 9. Riesgos y asuntos pendientes de prueba

1. **Configuración del mundo:** sin `world.mt`, puede haber mods desactivados o settings que impidan mapgen/eventos. La presencia en el repositorio no prueba activación.
2. **Versión runtime:** `game.conf` no certifica Luanti 5.17.0; hay que ejecutar en la versión objetivo.
3. **Persistencia:** probar salida normal, reinicio, caída abrupta, descarga/carga de chunks, reconexión y reinicio durante trial/raid/vault. Las colecciones de ObjectRefs no son persistencia durable.
4. **XP y muerte:** XP base se puede derramar; una disciplina persistente no debería derivarse sin más de ese total.
5. **Multijugador:** distinguir progreso personal de evento compartido; probar varias personas participando/ausentes y callbacks duplicados.
6. **Identidad:** gossip usa nombres de jugador. Si la capa futura usa claves personales, definir compatibilidad con cambios de nombre/identidad del servidor.
7. **Mapgen:** confirmar mundo nuevo frente a mundo ya generado y settings de `mcl_levelgen`; mapgen no reescribe automáticamente chunks explorados.
8. **Vault:** la lista por jugador usa ringbuffer de longitud configurable, no un historial infinito.
9. **Código heredado de clase:** el sistema actual existe; no borrarlo ni migrarlo sin especificación. La auditoría no cambia clases, stats, recetas, NPC ni balance.
10. **Framework externo:** el repositorio `TeTpaAka/quests` describe quests 1.2, API y persistencia al apagado, licencia MIT para código y dependencias de integración opcionales como `unified_inventory`, `inventory_plus` y `central_message`. En la página consultada, el último commit visible era del 22 de marzo de 2025 (7 estrellas y 11 forks al momento de inspección). El mantenimiento/compatibilidad con Mineclonia 0.124.1, Luanti 5.17.0, `mcl_inventory`, cierres abruptos y contenido multimedia **NO VERIFICADOS**. No instalar ni adoptar sin auditoría/licencia/experimento separado.

## 10. Fases de trabajo sugeridas (sin ejecutarlas en esta fase)

1. **P0 — baseline reproducible:** preparar una copia de prueba/world, registrar `world.mt`, settings, versiones, mods realmente cargados y logs. Ejecutar pruebas manuales de las capacidades ya existentes antes de tocar integración.
2. **P1 — mapa de eventos y contrato de persistencia:** documentar triggers nativos y decidir qué hechos son personales, del mundo o narrativos. Probar guardado/reinicio de awards, raids, aldeas, trials y objetos locales.
3. **P1 — adaptador fino:** si se aprueba, conectar callbacks existentes con un registro tipado, sin cambiar recompensas, recetas, generación ni NPC. Mantener XP vanilla aparte de cualquier contador de práctica.
4. **P2 — objetivos/UI solo tras decidir A/B/C:** reutilizar awards para hitos; añadir capa de seguimiento compuesta solo si la opción seleccionada la necesita. Evaluar `mcl_inventory`/formspec antes de introducir un framework externo.
5. **P3 — contenido y balance en una fase distinta:** definir historia, objetivos, desbloqueos y recompensas con aprobación expresa. No forma parte de la auditoría ni de este cambio documental.

## 11. Tabla final de funcionalidades

| Funcionalidad | Mod/sistema | Estado encontrado | Reutilización potencial | Desarrollo faltante | Prioridad |
|---|---|---|---|---|---|
| XP/niveles del jugador y persistencia personal | `mcl_experience` | IMPLEMENTADO | API de lectura/escritura/adición y callback | Verificar runtime y precisar fuentes reales en partida | P0 |
| Ajuste Everforge de XP por contexto | Everforge + `mcl_experience` | IMPLEMENTADO | Callback existente | Prueba runtime; no confundir con tracks de práctica | P0 |
| XP/disciplinas independientes por práctica | Everforge/Mineclonia | INEXISTENTE | Callbacks de acción y XP | Estado personal, reglas de incrementos y persistencia (sin diseñar clases) | P1 |
| Pool de puntos/skills heredado | Everforge | IMPLEMENTADO | Evaluar si el pool general sirve al modelo futuro | Decidir compatibilidad/migración fuera de esta auditoría | P1 |
| Clases con efectos actuales | Everforge | IMPLEMENTADO | Código actual como referencia de integración | No añadir nuevas clases; decidir futuro sin restringir equipamiento | No modificar ahora |
| Equipo, armaduras y tiers vanilla | Mineclonia | IMPLEMENTADO | Reutilizar objetos, `register_set`, diggroups y smithing | No se halló gate general por clase/nivel | P0 |
| Encantamiento y coste de niveles | `mcl_enchanting`, `mcl_anvils` | IMPLEMENTADO | Sistemas vanilla y APIs de efecto/ítem | No equivale a árbol de unlocks | P0 |
| Efectos/stat modifiers | `playerphysics`, `mcl_damage`, `mcl_potions` | DISPONIBLE SIN UTILIZAR como progresión nueva | API de factores, modificadores y lifecycle | Integración futura solo si se define una recompensa/efecto | P2 |
| Rango de herramienta por bloques minados | `toolranks` | IMPLEMENTADO | Métrica local en ItemStack | No otorga bonus ni XP de personaje | P2 |
| Desbloqueo personal de recetas/planos | Mineclonia/Everforge | INEXISTENTE | Recetas existentes como catálogo | Sistema de unlock/player-state y UI; fuera de alcance actual | No priorizar |
| Avances y triggers personales | `awards`, `mcl_achievements` | IMPLEMENTADO | API, callbacks, triggers y UI | Conectar con Everforge si se elige; confirmar runtime | P0 |
| Prerequisitos/premios de avance | `awards` | DISPONIBLE SIN UTILIZAR en definiciones revisadas | `requires`, `prizes`, callbacks | Definiciones que los usen, si se aprueba | P1 |
| Cadena de objetivos/diario | Everforge/Mineclonia | INEXISTENTE | Awards como milestones; eventos como señal | Capa de objetivos compuestos/estado/UI | P1 para narrativa guiada |
| Presentación con libros/doc/HUD | Mineclonia | PARCIAL | Objetos y UI ya existentes | Integración de estado narrativo | P2 |
| Descubrimiento de dimensiones | `mcl_worlds` | IMPLEMENTADO como callback; DISPONIBLE SIN UTILIZAR como narrativa general | Señal personal de exploración | Persistencia/anti-duplicados e historial offline | P1 |
| Dificultad regional por tiempo | `mcl_worlds` | IMPLEMENTADO | Mecánica vanilla | No registra progresión narrativa | P0 |
| Mapgen/estructuras Everforge | Everforge + `mcl_levelgen` | PARCIAL | Pipeline de estructuras | Validar settings/chunks/mundo real | P0 |
| Escalado de mobs por profundidad | Everforge | IMPLEMENTADO | Metadata de entidad y reglas actuales | Prueba de compatibilidad/balance en runtime | P0 |
| Evento temporal con stages/bossbar | `mcl_events` | IMPLEMENTADO | API reutilizable | Persistir resultado aparte si debe ser histórico | P1 |
| Raids activas | `mcl_raids` | IMPLEMENTADO | Estado activo serializado | Historial global de raids completadas no encontrado | P1 |
| Asedios a aldeas | `mcl_zombie_sieges` + `mcl_events` | IMPLEMENTADO como evento temporal | Condiciones/POI y framework de eventos | Registro histórico durable no encontrado | P2 |
| Trials y vaults | `mcl_trial_spawners`, `mcl_vaults` | IMPLEMENTADO | Retos, recompensas y loot por jugador | Probar reinicio; vault usa ringbuffer acotado | P1 |
| Aldeas/POI y datos de pueblo | `mcl_villages` | IMPLEMENTADO | API de lookup y callbacks | Integración a estado global si se requiere | P2 |
| Trade, nivel de aldeano y reputación local | `mobs_mc` villager | IMPLEMENTADO | Profesiones/trades/gossip/callback de transacción | No hay reputación de facción ni sistema quest NPC | P2 |
| Facciones/territorio/economía global | Mineclonia/Everforge | INEXISTENTE en alcance revisado | Datos de aldeas no equivalen a esto | Sistema nuevo (no desarrollar en esta auditoría) | No priorizar |
| Registro global durable de capítulos/hechos | Everforge/Mineclonia | INEXISTENTE | Mod storage y APIs de eventos existentes | Contrato de mundo compartido + pruebas de recuperación | P1 para B/C |
| Campaña/quests externo | `TeTpaAka/quests` | NO VERIFICADO (externo; no instalado) | Candidato con API/UI propia | Auditoría de compatibilidad, persistencia y UI | No adoptar ahora |
| Activación y funcionamiento en save concreta | `world.mt`/runtime | NO VERIFICADO | Inspección estática de dependencias | World config y pruebas Luanti 5.17.0 | P0 |

## 12. Rutas principales inspeccionadas

- `README.md`, `game.conf`
- `mods/MISC/everforge/init.lua`, `mods/MISC/everforge/mod.conf`
- `mods/HUD/mcl_experience/init.lua`
- `mods/HUD/mcl_achievements/init.lua`, `mods/HUD/awards/`
- `mods/CORE/mcl_events/init.lua`, `mods/CORE/mcl_events/API.md`, `mods/CORE/mcl_worlds/`
- `mods/ENVIRONMENT/mcl_raids/init.lua`, `mods/ENVIRONMENT/mcl_zombie_sieges/init.lua`
- `mods/ITEMS/mcl_trial_spawners/init.lua`, `mods/ITEMS/mcl_vaults/api.lua`, `mods/ITEMS/mcl_vaults/init.lua`
- `mods/MAPGEN/mcl_villages/api.lua`, `mods/MAPGEN/mcl_villages/utils.lua`, `mods/ENTITIES/mobs_mc/villager.lua`
- `mods/PLAYER/playerphysics/init.lua`, `mods/CORE/mcl_damage/`
- `mods/ITEMS/mcl_armor/`, `mcl_enchanting/`, `mcl_potions/`, `mcl_anvils/`, `mcl_smithing_table/`, `mcl_tools/`, `toolranks/init.lua`
- `mods/ITEMS/mcl_books/`, `mcl_maps/`, `mods/CORE/doc/`, `mods/HUD/mcl_inventory/`

### Localizadores de código para los hallazgos centrales

Los números son del checkout auditado y pueden cambiar en commits posteriores.

- Everforge: `init.lua:44–105` define clases/skills y asignación de puntos; `:107–117` integra el callback de XP; `:139–222` muestra la selección permanente y compra de ranks; `:293–294` aplica el bonus de forja; `:1517–1537` inicializa metadata de caché; `:1641–1659` limita spawner a tres apariciones.
- XP: `mcl_experience/init.lua:89–109` API básica; `:223` registro de callbacks; `:240` inicio del manejo de muerte.
- Awards: `mcl_achievements/init.lua:21–23` premio XP; definiciones con `reward_xp` en `:261`, `:601`, `:619`. `awards/src/api_awards.lua:4` registra avances, `:15–20` procesa prerequisitos y `:75–77` premios `prizes`.
- Dimensiones: `mcl_worlds/init.lua:48` `pos_to_dimension`, `:103` `register_on_dimension_change`, `:129–137` detección periódica, `:232` dificultad regional.
- Eventos/raids: `mcl_events/init.lua:6–7` tabla en memoria, `:23–49` registro/inicio, `:63–75` limpieza; `mcl_raids/init.lua:159–165` serialización/restauración de raids activas.
- Aldeanos: `villager.lua:167–201` definición de trade, `:386–404` completar transacción/XP/gossip, `:1173–1187` registro de profesión, `:1989–1999` XP/tier y gossip, `:2495–2555` reputación/gossip; `mcl_villages/utils.lua:262–303` lectura/escritura de datos de aldea.
- Trials/vaults: `mcl_trial_spawners/init.lua:252–289` condiciones de waves, `:291–335` completar/recompensar, `:395–405` cooldown/estado; `mcl_vaults/api.lua:7–18` ringbuffer por jugador y `:33–65` loot en metadata.
- Toolranks: `toolranks/init.lua:1–5` declara explícitamente que no cambia diggroups/daño/desgaste; `:27–36` calcula y muestra rank; `:39–58` cuenta bloques por ItemStack.
