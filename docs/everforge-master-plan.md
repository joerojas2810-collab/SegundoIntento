# EVERFORGE — Plan maestro de evolución, migración y dirección artística

**Estado:** Fase 0 autorizada y documentada; validación estática realizada, validación en runtime pendiente. Fase 1 y cualquier implementación funcional siguen sin autorización.

**Fecha:** 28 de octubre de 2026.

**Base:** `docs/everforge-progression-audit.md`, `docs/everforge-art-audit.md` y lectura de los archivos actuales del checkout.

**Objetivo de compatibilidad:** Mineclonia 0.124.1 / Luanti 5.17.0.

**Alcance de esta entrega:** Fase 0 de investigación y validación técnica; documento exclusivamente. Resultados y límites en §18–21. No se cambió código, balance, recursos, generación, configuración de una partida ni comportamiento de NPC; no se instalaron mods.

## 1. Resumen ejecutivo

Everforge debe evolucionar añadiendo una **capa pequeña de progreso personal y hechos de mundo** a Mineclonia, no sustituyendo sus sistemas. La arquitectura recomendada conserva por separado la XP vanilla, un Dominio general persistente, cinco contadores de disciplina, hechos compartidos del mundo y objetivos narrativos opcionales. Adaptadores de eventos traducen acciones confirmadas a señales que esos subsistemas pueden consumir una sola vez.

La dirección funcional aprobada en la solicitud es: cinco disciplinas (Minería, Forja, Combate, Exploración y Artesanía), todas abiertas a cada personaje; puntos de especialización generales compartidos; historia opcional; y libertad de survival/construcción. La dirección visual aprobada es mantener el pixel-art/escala de Mineclonia, limitar la paleta grafito-cobre-marfil a las interfaces propias, proponer un árbol real de skills y diferenciar la calidad de equipo sin depender solo del color.

**Recomendación de orden:**

1. Validar Luanti/Mineclonia y configuración real de una copia de mundo.
2. Definir contratos de eventos/persistencia y ejecutar una migración **aditiva y reversible** de perfiles en una copia.
3. Implementar el núcleo de XP de Dominio/disciplinas sin alterar `mcl_experience` y sin efectos nuevos.
4. Validar una especialización piloto usando, tras aprobación de mapeo, un efecto ya existente.
5. Diseñar e implementar el árbol visual conectado a datos reales.
6. Registrar hitos persistentes y logros narrativos opcionales.
7. Pulir señales de calidad/estructura solo después de probar reutilización y de aprobar el mecanismo de iconos.

No se fijan tasas, curvas, cantidad de puntos, requisitos definitivos, efectos nuevos, ramas completas ni una campaña. Las 45 habilidades discutidas se consideran material de diseño no aprobado: en el sistema solo se crearían identificadores/esquemas cuando se apruebe contenido concreto.

## 2. Registro de decisiones

### 2.1 Aprobado explícitamente por el usuario

| Decisión | Implicación para este plan |
|---|---|
| Mundo abierto, construcción y progreso Minecraft/Mineclonia permanecen como base. | Ninguna historia ni skill debe bloquear recetas, dimensiones, construcción o survival normal. |
| Evolución hacia cinco disciplinas: Minería, Forja, Combate, Exploración y Artesanía. | Las cinco son tracks personales; todavía no hay curvas ni tasas definitivas. |
| Todas las disciplinas están disponibles para todos los jugadores. | No habrá clase permanente, exclusividad de profesión ni restricción de equipamiento por build. |
| Especializaciones gastan puntos generales compartidos. | No hay saldos de puntos separados por disciplina. |
| Mantener XP vanilla, costes de encantamiento/yunque y pérdida de XP al morir. | XP de Mineclonia queda independiente de Dominio y disciplinas. |
| Dominio y disciplinas son persistentes al morir. | Se guardan como progreso Everforge personal; no se derivan del saldo temporal de XP vanilla. |
| Habilidades pasivas y activas caben en el modelo. | Solo se diseña el contrato de datos; no se inventan habilidades/efectos ni controles en este plan. |
| Historia opcional integrada; futuros eventos emergentes posibles. | Un capítulo no es prerrequisito del juego base. |
| Paleta de UI Everforge grafito/hierro oscuro, cobre e marfil cálido. | Acento limitado a interfaces Everforge; no teñir biomas o Mineclonia globalmente. |
| Árbol visual conectado a requisitos reales. | La UI se construye a partir de la definición funcional de los nodos, no de líneas decorativas. |
| Señales de calidad además de texto/color, manteniendo material y calidad separados. | Debe analizarse la representación en stack/hotbar; no tocar estadísticas, materiales ni probabilidades. |
| No cambiar ahora archivos funcionales o artísticos, no instalar mods, no balancear y no alterar NPC/mundo. | Las fases siguientes son una propuesta condicionada a aprobación; no son trabajo ejecutado. |
| Una región inicial única y compartida por todos los jugadores de cada mundo. | Generación única integrada con el terreno procedural; cambios de jugadores persistentes; entrada de jugadores nuevos; camas/anclas conservan prioridad. Implementación mínima propuesta en §19, todavía no autorizada. |
| El yunque es el icono propio de Everforge, separado del logo de cabecera. | Identidad confirmada; integración pendiente y fuera de Fase 0. |
| Autorizar únicamente Fase 0 de validación técnica. | Sin cambios funcionales, migraciones ni escrituras en partidas existentes; Fase 1 requiere nueva autorización. |
| Mantener PR #2 abierto contra `main`. | Solo entregar documentación en la rama existente; no fusionar ni force-push. |

### 2.2 Recomendaciones técnicas de este plan (requieren aprobación antes de programar)

- Un router de eventos interno a Everforge, con adaptadores pequeños para callbacks existentes; no un framework global genérico.
- Un crédito de Dominio por acción válida, como máximo una vez por evento, incluso si una acción avanza más de una disciplina.
- Metadatos personales del jugador para XP/niveles/habilidades y `mod_storage` propio de Everforge para hechos realmente compartidos.
- `awards` como interfaz de logros/milestones personales; no como base única de Dominio, misiones compuestas o estado global.
- Migración en dos tiempos: primero snapshot aditivo, después conversión/cutover solo con una política de efectos heredados aprobada.
- Piloto técnico candidato: la habilidad actual `deep_miner` dentro del track Minería, conservando su efecto actual sobre herramientas Everforge, sin introducir un efecto ni cambiar el valor. Es un candidato, no una selección aprobada.

### 2.3 Pendiente de decisión del usuario

1. Conversión de las cuatro bonificaciones de clase heredadas y de ranks actuales a los cinco tracks/nodos.
2. Fuente exacta y curva de XP de Dominio/disciplina, umbrales y calendario de puntos.
3. Si una misma acción (por ejemplo, crear una herramienta modular) puede avanzar más de una disciplina; el Dominio global seguirá computándose una sola vez por acción.
4. Si planes/conocimientos, desafíos o futuros maestros serán fuentes de unlocks, y qué datos persistentes necesitarían.
5. Catálogo de ramas/habilidades y sus efectos; 45 habilidades siguen sin estar aprobadas como contenido.
6. Política de gasto/reembolso de puntos y de requisitos de habilidades activas.
7. Qué hechos son globales de mundo, cuáles personales y cómo una narración personal puede reaccionar a ambos.
8. Integración futura del yunque en `menu/icon.png` y condiciones de empaquetado/distribución. Su identidad como icono propio, distinta del logo, ya está confirmada; no se vuelve a consultar.
9. Cómo se mostrará una calidad distinta en el icono del objeto dentro del inventario/hotbar, no solo en un formulario o tooltip.
10. Si se aprueba contenido artístico original cuando la biblioteca actual no ofrezca un recurso adecuado.

## 3. Hallazgo de marca: icono, logo y menú

La auditoría artística anterior describió correctamente el checkout de ese momento: `menu/icon.png` era el bloque de césped de Mineclonia y `menu/header.png` era el logo Everforge. La imagen adjunta en esta solicitud aporta información nueva y debe corregirse en este plan:

- **Icono suministrado:** `Everforge Icono.png`, adjunto por el usuario, es una ilustración cuadrada de un yunque de metal oscuro con grietas incandescentes de cobre; es visualmente distinta del wordmark/logo. El archivo es PNG RGBA de 8 bits, **1254×1254**, con transparencia fuera del objeto; SHA-256 `7c402eaf3da2a397b8584d018cbde48262cf9f1be9d29fc73c7a75294e5cf8b4`.
- **Estado en repositorio:** no está en el árbol actual, no aparece en los PNG rastreados ni como el mismo blob en las referencias Git disponibles. Tampoco hay un recurso Everforge con ese contenido bajo otro nombre. No hay rama remota adicional en el checkout fuera de `main` y la rama del PR. Es un recurso facilitado como adjunto, aún **no integrado**.
- **Icono realmente usado por el checkout:** `menu/icon.png`, 128×128, sigue siendo el icono de césped de Mineclonia (SHA-256 `b080a06e478c3a48e9c5b86495b727513b6979c0f15714c67679c6cf8b6ea86f`).
- **Logo/cabecera:** `menu/header.png`, 2172×724, contiene el wordmark Everforge ya elegido y documentado en `mods/MISC/everforge/AUDIT.md` (SHA-256 `b7828a191f862ff9c0090b8319b993f14ab3f4314d8a60fb5b109d4e3e72da47`). No es el icono adjunto.
- **Historial:** las versiones históricas disponibles de `menu/icon.png` inspeccionadas también son iconos de césped; no localicé el yunque en la historia de los paths/ref actuales. Por tanto, la frase “Everforge ya tiene icono propio” queda identificada por el adjunto del usuario, no por un archivo actualmente instalado.

**Conclusión de planificación:** conservar el logo en el header y reconocer el yunque como icono independiente suministrado. Una futura integración debe colocar el recurso suministrado en la ruta de icono del juego, sin usar una miniatura del logo ni volver al icono de césped. No se copia, escala, recomprime, redibuja ni reemplaza nada ahora. El usuario confirma el yunque como icono propio y deja su integración pendiente. Antes de la fase artística se resolverá el empaquetado; la fuente/licencia externa no se deduce de los píxeles.

## 4. Situación técnica actual y archivos de referencia

### 4.1 Personaje y sistema heredado

`mods/MISC/everforge/init.lua` contiene actualmente cuatro clases y cuatro skills:

| Estado heredado | Dato/efecto que debe preservar el plan | Ruta/identificador |
|---|---|---|
| Clase permanente, selección una vez | `vanguard`, `ranger`, `arcanist`, `smith` en player metadata | `everforge:class`, selección y comprobación de inmutabilidad en `init.lua` |
| Defensa | Vanguard reduce daño de mob/player melee por el modificador global de `mcl_damage` | `mcl_damage.register_modifier`; consulta `everforge:class` |
| Movimiento/gravedad | Ranger aplica speed/jump; Arcanist ajusta gravity | `apply_class()` y `playerphysics.add_physics_factor` |
| Bonus XP | Arcanist suma una unidad de rank efectivo al bonus de `dungeoneer` cerca de spawner; el callback actual puede alterar XP vanilla | `mcl_experience.register_on_add_xp` y metadata de clase/skill |
| Bonus de Forja | Smith añade 2 unidades al bonus de cercanía del fundidor; `forgemaster` suma su rank | `forge_bonus_at()` |
| Skills | `trailblazer`, `deep_miner`, `dungeoneer`, `forgemaster`; cada uno tiene máximo 3 en el código actual | `everforge:skill:<id>` |
| Puntos | `earned` es el máximo histórico guardado/derivado del nivel vanilla; `spent` acumula los puntos gastados; saldo = `max(0, earned-spent)` | `everforge:earned`, `everforge:spent`, `earned_points()`/`get_points()` |
| Datos auxiliares | Los factores de física Everforge se serializan con `playerphysics` por IDs `everforge:class`/`everforge:skill`; otros mods pueden compartir la misma tabla de physics | `playerphysics:physics` en player metadata; retirar factores Everforge individualmente, nunca borrar toda la tabla |
| Habilidades y equipo | Deep Miner modifica el desgaste solo de herramientas Everforge; el sistema modular guarda materiales/quality/capacidades por ItemStack | `perk_wear_multiplier`, `after_use`, `apply_modular_stack()` |

El módulo declara dependencias directas de XP, playerphysics, damage, mobs, inventory, levelgen y mundos, entre otras (`mods/MISC/everforge/mod.conf`). **No** declara `awards` o `mcl_achievements`; tampoco existe ahora una API transversal de progreso.

### 4.2 Mundo y narrativa

- `mcl_worlds.register_on_dimension_change()` es una señal reutilizable, pero se calcula periódicamente y conserva la dimensión anterior en memoria; no recompone transiciones ocurridas desconectado.
- `mcl_events` controla actividades en tiempo real, pero sus instancias activas son temporales. Raids guardan estado activo; eso no crea historia global de raids completadas. Trials conservan metadata del nodo pero tienen ObjectRefs de mobs en memoria; la restauración completa está **NO VERIFICADA**. Vault looter list es un ringbuffer finito.
- `mcl_villages` guarda datos de aldeas/POI; gossip/reputación del aldeano es personal y no un sistema de facciones global.
- `awards`/`mcl_achievements` tienen triggers, UI y progreso personal persistente, pero no constituyen una misión compuesta ni un journal. El API `requires` está disponible; las definiciones de Mineclonia inspeccionadas no lo usan. No modificar los logros base.
- Everforge genera Cementerio/Torre de Hielo mediante `mcl_levelgen`, usa recompensas/caches locales y mobs nativos. `mcl_levelgen` solo afecta chunks elegibles nuevos; no hay historial de descubrimiento/limpieza integrado.

### 4.3 Recursos y UI

- UI actual de RPG, fundidor, WAILA y guía usa paneles `everforge_ui_*`, `everforge_waila_panel.png`, el builder de `doc` y slots/overlays de Mineclonia. La ventana RPG actual presenta filas de cuatro skills, no un árbol de cinco disciplinas.
- Las herramientas modulares almacenan calidad como metadata de ItemStack pero registran una definición visual por herramienta/material; la imagen de `inventory_image`/`wield_image` procede de la herramienta base tintada por material. Por eso una insignia de calidad por **stack** no se resuelve con una etiqueta global de item.
- Las seis partes 16×16 son siluetas Melterns con licencia MIT; More Ores tiene sprites 16×16; Adamantine usa colorize de texturas de diamante. El inventario general bajo `mods/` incluye sprites, modelos, animación, partículas, UI y audio descritos en `docs/everforge-art-audit.md`.
- La dirección gráfica aprobada no autoriza cambiar esas texturas: propone primero reuso y prototipos de composición en UI.

## 5. Arquitectura propuesta: tres progresiones, un flujo de eventos

### 5.1 Componentes mínimos

```text
Mineclonia callbacks ─┐
Everforge callbacks ──┼─> adaptadores ─> router local y deduplicación ─┬─> Estado personal
mcl_events resultado ─┘                                               ├─> Hechos del mundo
                                                                      ├─> awards (adapter opcional)
                                                                      └─> Objetivos narrativos opcionales
```

1. **Adaptadores de origen:** escuchan una sola vez los hooks disponibles de `core`, Mineclonia, Everforge o un callback público de un mod. No interceptan ni sustituyen mecánicas nativas.
2. **Evento Everforge normalizado:** convierte los datos de callback a campos Lua simples. No conserva ObjectRefs ni copia tablas mutables de otras APIs.
3. **Router pequeño:** entrega el mismo evento a los consumidores personales, mundiales y narrativos. La concesión de progreso y el registro mundial no vuelven a observar el mismo callback por separado.
4. **Servicios personales:** XP del Dominio, cinco XP de disciplina, niveles derivados, puntos generales, unlocks/skill ranks y estado de objetivos personales.
5. **Servicio mundial:** hechos compartidos mínimos y versionados, separados de los objetos/mapblocks y de `mcl_events` en vivo.
6. **Adaptadores de presentación:** `awards`, formspec/HUD, `doc`, libros/mapas o inventario. La presentación no es la fuente de verdad del progreso.

Mantenerlo dentro de Everforge, no como un nuevo mod independiente en primera fase. Solo declarar dependencias opcionales nuevas si el adaptador realmente las necesita; si `awards`/`mcl_events` no están disponibles, juego, XP y datos personales siguen funcionando sin esa integración.

### 5.2 Contrato conceptual de evento

Un evento es una notificación de una acción/resultante confirmada, no un comando para cambiar balance:

```lua
{
  id = "origen:identificador-estable-o-secuencia-local",
  type = "player.node_dug", -- catálogo final por aprobar
  actor = "nombre_del_jugador",
  source = "core.register_on_dignode",
  dimension = "overworld",
  position = {x = ..., y = ..., z = ...}, -- solo si el consumidor lo necesita
  subject = "mcl_core:stone",             -- nodo/item/mob, si corresponde
  result = "success",
  context = { ... }                         -- solo primitivos acotados
}
```

Tipos de evento como `player.node_dug`, `player.craft_completed`, `everforge.melter_output`, `player.mob_kill_confirmed`, `player.dimension_entered`, `world.trial_completed` o `world.raid_resolved` son **nombres de integración conceptuales**, no contenido ni valores aprobados.

Reglas:

- Cada adaptador tiene ownership de su callback. Un hook predictivo, como `register_craft_predict`, no concede progreso; solo la operación de craft completada podría hacerlo.
- Cada callback se publica una vez por acción. IDs de origen de estructuras/desafíos son estables cuando existan; acciones del jugador pueden recibir una secuencia local monotónica para evitar doble despacho dentro de la sesión. No se promete re-ejecutar callbacks tras un crash.
- El consumidor es idempotente: volver a procesar el mismo `id` no vuelve a otorgar puntos ni a registrar el mismo hecho. Guardar un hecho condensado por fuente/objetivo; no almacenar un diario infinito de cada bloque roto.
- Los callbacks de acción de mundo no otorgan automáticamente XP vanilla ni escriben recetas, inventarios, nodos o metadata de NPC.
- Payload mínimo: actor, fuente, resultado y el contexto esencial. No guardar posiciones/datos personales que no consumirá ninguna capa.

### 5.3 Separación de datos

| Dominio | Fuente de verdad propuesta | Guarda | No debe guardar/alterar |
|---|---|---|---|
| XP vanilla de Mineclonia | `mcl_experience` / player metadata nativa | La XP/nivel vanilla con las reglas actuales | No usar como historial de disciplina; no cancelar coste de encantamiento/anvil; no evitar la pérdida vanilla al morir |
| Dominio general | player metadata personal Everforge | `mastery_xp` acumulada, nivel derivado y contadores totales de puntos | No se deriva del saldo de XP vanilla ni de sumar cinco veces una acción multidisciplinar |
| Disciplinas | player metadata Everforge | `discipline_xp:<id>` y nivel derivado por disciplina | No crea puntos exclusivos de esa disciplina ni gates de contenido vanilla |
| Especialización | player metadata Everforge | puntos generales ganados/gastados y unlocks/ranks por ID | No presupone el catálogo de 45; los datos deben corresponder a definiciones aprobadas |
| Objetivos/awards | APIs/almacenamiento personal existentes + estado Everforge personal mínimo | Hitos del jugador, objetivo actual y progreso compuesto que no modela `awards` | No editar/eliminar awards base ni duplicar el mismo milestone en varias fuentes |
| Hechos del mundo | `core.get_mod_storage()` de Everforge, schema versionada | Hechos compartidos duraderos y claves de deduplicación compactas | No copiar ahí todos los metadatos de jugadores ni confiar en memoria de `mcl_events` |
| Mundo físico | Almacenamiento normal de mapa de Luanti/Mineclonia | Bloques, nodos, inventarios y metadata de sus propios nodos | No crear un índice global redundante de cada bloque/estructura |
| Evento en vivo | `mcl_events`, raids, trial/vault según su API | Progreso/estado operativo de su subsistema | No confundir “activo” con “completado global e histórico” |

**Persistencia de Dominio/disciplina:** se mantiene al morir, desconectarse y reiniciarse; el `on_dieplayer` que suelta XP vanilla no debe borrar esos campos. La durabilidad real se valida con reinicio/cierre abrupto en copias. La escritura debe limitarse a transiciones/cambios de progreso, no a cada frame.

### 5.4 Cálculo sin doble recompensa ni sesgo artificial

No fijar cuantías en esta fase. Para cuando se apruebe balance:

1. Cada actividad confirmada recibe un único **crédito base de Dominio** a determinar mediante pruebas de juego; el router lo procesa una sola vez.
2. Puede asignarse crédito a una o varias disciplinas, según política de actividad; sumar varios contadores disciplinares **no** multiplica automáticamente el Dominio ni el punto compartido.
3. El Dominio acumula un contador monotónico y calcula nivel por una tabla/función de umbrales versionada. Los puntos generales se conceden en hitos del Dominio, con calendario/importe pendiente de aprobación.
4. Cada disciplina mantiene su propio XP y nivel, derivados de su práctica válida; no concede puntos separados.
5. Las fuentes se agrupan por oportunidad real de acción, no por número de callbacks: forja terminada, craft concluido, mob derrotado con atribución válida, nodo efectivamente minado o descubrimiento único/definido.
6. Antes de fijar valores se miden rutas típicas de juego (minería, crafteo, combate, exploración), se detectan acciones repetibles triviales, y se comparan tiempo/ruta hasta hitos. Balance no se ajusta por intuición ni en esta etapa.
7. Filtros antifarm deben ser por fuente/semántica (resultado confirmado, objeto elegible, descubrimiento de una vez cuando corresponda), no una batería arbitraria de cooldowns. Se documenta qué acciones de repetición legítima siguen progresando.

El progreso de una actividad también puede marcar un premio de `awards` o objetivo narrativo, pero cada efecto se configura como consumidor independiente del mismo evento; no se debe llamar una segunda vez a la misma fuente para “recontar” la acción.

## 6. Cinco disciplinas: fuentes candidatas y validación

Estos son puntos de integración para investigar/validar, no reglas definitivas de XP ni balance:

| Disciplina | Fuente/callback candidato en el bundle | Clasificación recomendada para evitar doble conteo | Prueba necesaria |
|---|---|---|---|
| **Minería** | `core.register_on_dignode`; toolranks ya observa bloques minados, pero cuenta por ItemStack y no por jugador como disciplina | Acreditar solo bloque realmente excavado por jugador y definido como actividad de minería. No elevar cada `after_use` y el callback de dug como dos acciones | Supervivencia/creativo, explosiones, nodos reemplazados, minería con herramientas de otros mods, reinicio y no repetición |
| **Forja** | salida completada del Alloy Melter; `core.register_on_craft` para ensamblaje modular confirmado | Separar “procesado/forjado” del craft ordinario; no acreditar `register_craft_predict`; un mismo ensamblaje es un solo evento | Fuel, input inválido, output full, hopper, protecciones, cancelación y reinicio del timer |
| **Combate** | `mcl_damage.register_on_death`; API de mobs y triggers de muerte de `awards` | Solo muerte/resultado, no cada golpe; atribución de killer y mob/entorno debe probarse. Evitar doblar `mcl_mobs` y `awards` como dos rewards | Asistencias, daño de varios jugadores, caída/fuego/entorno, mobs que reaparecen, mobs de trial y desconexión |
| **Exploración** | `mcl_worlds.register_on_dimension_change`; callbacks/hitos de estructuras existentes y primera interacción relevante | Una entrada de dimensión por transición observada, no por cada segundo en dimensión; no inferir historial offline. Descubrimiento global y personal se separan | Teleporte, portal, reconexión en otra dimensión, estructuras existentes/nuevas y callbacks ausentes de mapgen |
| **Artesanía** | `core.register_on_craft` y triggers de craft de `awards` | Solo resultado fabricado; excluir del track general de artesanía recetas etiquetadas como Forja si se decide la taxonomía anterior | Recetas repetibles, `craft_predict`, craft grid, output modificado, tool/item stack metadata y compatibilidad multijugador |

**Incertidumbre explícita:** las APIs disponibles no garantizan que cada acción tenga una atribución/resultado apropiada. La Fase 0 debe inspeccionar los contratos de `mcl_damage`, `mcl_mobs`, fundidores, `mcl_levelgen` y eventos. Si no hay callback seguro, primero buscar uno público o un pequeño hook del lado de Everforge; no hacer polling por `globalstep`, no parchear la lógica de combate/generación sin aprobación.

## 7. Modelo de Dominio, puntos y habilidades

### 7.1 Modelo de datos conceptual

Campos sugeridos; los nombres son esquema de planificación, no metadata añadida en esta entrega:

```text
player metadata:
  everforge:progression_schema
  everforge:mastery_xp
  everforge:discipline_xp:mining
  everforge:discipline_xp:forging
  everforge:discipline_xp:combat
  everforge:discipline_xp:exploration
  everforge:discipline_xp:crafting
  everforge:points:legacy_earned
  everforge:points:legacy_spent
  everforge:points:earned
  everforge:points:spent
  everforge:unlocks:<skill_id>
  everforge:narrative:<objective_id>
  everforge:migration:<version>

Everforge mod storage (mundo):
  everforge:world_schema
  everforge:world_fact:<stable_fact_id>
  everforge:world_event:<source_id>  -- solo estado condensado/dedupe necesario
```

XP es el registro acumulado; el nivel general y cada nivel de disciplina se **derivan** de una función/tabla de umbrales versionada. Así no hay niveles desincronizados si la curva se cambia con una migración futura. El nivel nunca se resta por muerte. Si se requiere snapshot de nivel para debug/UI, se recalcula y no es la fuente de verdad.

El balance de puntos se calcula de forma auditable: total legado disponible + puntos nuevos ganados − puntos nuevos gastados, sin sumar un rango legacy ya migrado como si fuera otra vez puntos disponibles. El esquema definitivo de legacy, niveles y umbrales se confirma antes de la fase que escriba datos.

### 7.2 Modelo de definición de habilidad

Cada definición aprobada debería especificar al menos:

- ID estable y texto de nombre/descripción traducible.
- Disciplina que da contexto, no exclusividad de acceso.
- Tipo `passive` o `active`.
- Rango máximo solo cuando esté aprobado.
- Requisitos tipados: nivel mínimo de disciplina, puntos generales requeridos, descubrimiento, plano/conocimiento, desafío completado e interacción con maestro únicamente si esta última se aprueba.
- Dependencias/IDs prerequisito reales para que cada arista del árbol tenga semántica.
- Efecto registrado por ID/callback de implementación, con owner, compatibilidad y versión; no serializar funciones en metadata.
- Para activas: entrada/trigger, validación de estado, coste/cooldown solo si se decide, y efectos sincronizados/replicados con Mineclonia. Estos campos no autorizan diseñar una activa ahora.
- UI/icono y criterio no basado solo en color.

Un validator previo al registro debe detectar IDs duplicados, prerequisitos inexistentes/ciclos, track desconocido, rank incoherente y efecto no registrado. La app/tree se genera desde ese grafo; no se dibujan conexiones sin requisitos.

### 7.3 Skills actuales que pueden alimentar un piloto

| Skill heredada | Efecto que existe hoy (sin cambiarlo) | Destino candidato, no decisión final |
|---|---|---|
| `deep_miner` | Reduce desgaste de herramientas Everforge mediante su callback/`after_use` | Minería; es el piloto técnico más directo para action-to-discipline y preservar un efecto existente |
| `forgemaster` | Acelera el Alloy Melter local según el cálculo actual | Forja; alternativa de piloto de muy bajo alcance si se elige el callback de salida correcta |
| `trailblazer` | Añade speed por `playerphysics` | Exploración podría ser contexto, pero el efecto actual no demuestra por sí mismo una fuente de práctica; no asignarlo automáticamente |
| `dungeoneer` | Añade bonificación de XP cerca del spawner | No migrar directamente al Dominio: actualmente modifica XP vanilla; requiere decisión explícita para cumplir XP vanilla sin modificación |

La clasificación no aprueba que estos cuatro formen el nuevo catálogo ni resuelve los efectos de clase. No hay un skill activo en el código actual; la primera integración no debe inventar uno para demostrar el router.

## 8. Migración versionada del sistema heredado

### 8.1 Inventario que debe exportarse por perfil

Antes de tocar datos, guardar en una copia de prueba un snapshot lógico con: `everforge:class`, `everforge:earned`, `everforge:spent`, cada `everforge:skill:<id>`, nivel/XP vanilla solo para diagnóstico, metadata de factores `playerphysics:physics` y estado de herramientas/items que dependan de componentes. No guardar el inventario completo en una tabla duplicada si una copia del mundo ya lo protege.

### 8.2 Migraciones propuestas

| Versión/etapa | Operación | Idempotencia, rollback y compatibilidad |
|---|---|---|
| **V0 — auditoría** | Documentar perfiles de prueba nuevos y existentes; respaldar save de prueba; comparar campo por campo | No escribe ni modifica perfil. No usar el mundo vivo como banco de migración. |
| **V1 — snapshot aditivo** | En primer join de cada jugador, copiar los campos heredados a un namespace `legacy_snapshot` versionado; leer pero no borrar originales ni cambiar efectos/UI | Si la copia de estado queda marcada `running`, reintentar por clave. Escribir `complete` al final. Ejecutarlo dos veces no duplica crédito. Efecto de juego 100% igual al baseline. |
| **V2 — traducción en entorno clonado** | Aplicar una tabla aprobada para mapear ranks/unlocks existentes; convertir puntos no gastados y registrar los ya gastados; acordar compensación de bonificaciones de clase no ligadas a un rank | Snapshot original queda intacto. Migración se prueba con copia de personajes de cada clase y múltiples ranks; no avanzar si una bonificación se pierde o duplica. |
| **V3 — cutover habilitado** | Nuevos personajes comienzan sin selector permanente; lectores nuevos consumen datos versionados; compatibilidad heredada se desactiva de forma explícita por estado de migración | Por perfil, solo tras snapshot y validación. Mantener campos/versiones antiguas durante ventana de rollback. No se eliminan funciones en este plan. |
| **V4 — limpieza eventual** | Solo después de releases, partidas migradas verificadas y autorización explícita, evaluar retirar código/metadata obsoleto | Fuera de esta propuesta y no antes de documentar recuperación. No borrar clase/rank legacy aquí. |

### 8.3 Política de conversión recomendada

- El nivel vanilla actual no puede reconstruir experiencia histórica: Mineclonia pierde XP al morir. No usarlo como XP inicial de Dominio ni disciplina.
- `everforge:earned` es un high-water mark guardado por el Everforge actual; `everforge:spent` y ranks documentan puntos gastados. Preservar ambos valores, no recalcular el legado desde XP vanilla actual.
- Los ranks antiguos que se traduzcan a una especialización son compras **ya pagadas**; no deben cobrarse de nuevo ni producir una segunda copia de los mismos puntos. Los puntos antiguos libres se conservan como crédito legado auditable; cómo convivirán con la nueva ganancia se aprueba antes de V2.
- Las bonificaciones de clase no tienen un equivalente 1:1 definido. Antes del cutover debe elegirse, por habilidad/efecto, entre una conversión a una habilidad de disciplina aprobada, una compensación de puntos aprobada, o una conservación temporal durante una ventana de transición. No afirmar que cualquier opción conserva el balance por sí sola.
- Debe conservarse el progreso actual de las skills donde sea posible, sin convertir las cinco disciplinas en nuevas clases ni bloquear el uso de ítems.
- Al desactivar las clases, retirar solo los factores `everforge:class`/`everforge:skill` mediante `playerphysics.remove_physics_factor`; no limpiar la tabla completa de physics, que puede contener factores de otros mods.
- El modificador de daño de Vanguard es global y consulta `everforge:class`; el bonus de arcanista/dungeoneer modifica la XP vanilla; el bonus de Smith se combina con `forgemaster`. Cada uno requiere gate de compatibilidad para evitar doble aplicación. El ajuste de XP vanilla es el conflicto más importante con el requisito “Mineclonia XP intacta” y requiere autorización de migración.
- Perfiles existentes se migran al iniciar sesión; jugadores offline no se recorren ni editan. V1 debe ser repetible tras reinicio/crash y proporcionar un reporte por versión sin exponer datos personales en chat global.

## 9. Estado persistente del mundo

### 9.1 Límites y responsabilidades

1. **Físico:** bloques, cofres, cache y metadata del nodo pertenecen al mapa/owner del mod. Una estructura generada no significa que haya sido descubierta/despejada.
2. **Runtime:** `mcl_events` indica evento en vivo; no es historia global. Las raids guardan raids activas; no el historial de finalización. No inferir una victoria de un estado “no activo”.
3. **Personal:** awards, puntos, XP, objetivos y descubrimientos personales viven en el perfil/almacenamiento del jugador.
4. **Compartido:** Everforge `mod_storage` guarda únicamente hitos globales semánticos decididos (por ejemplo, que un encuentro concreto terminó, si ese hecho global se aprueba), no toda la actividad de cada jugador.

### 9.2 Instrumentación recomendada

- `mcl_worlds`: emitir un evento personal de cambio de dimensión al callback; guardar una transición solo para acciones observadas, sin recuperar transiciones offline.
- `mcl_raids`/`mcl_zombie_sieges`: usar resultado explícito. Si la API no expone un callback público de finalización, documentar el gap y proponer un hook mínimo en el mod dueño solo tras aprobar; no sondear su tabla de memoria.
- `mcl_trial_spawners`/`mcl_vaults`: distinguir activar, participar, completar y reclamar reward; evitar leer ObjectRefs almacenados temporalmente como prueba duradera. El ringbuffer del vault no se usa como journal global.
- Aldeas/trades: separar reputación local por jugador/aldeano del hecho compartido de aldea; no ampliar reputación, NPC, economía ni precios.
- Everforge cache/spawner: si el evento de descubrimiento/desafío es aprobado, emitirlo desde los callbacks existentes de interacción/resultado, no desde cada carga de mapblock. No alterar el contenido/recompensa.
- Cada hecho mundial obtiene un ID estable de la fuente cuando sea posible y un estado compacto (por ejemplo `seen/started/completed` solo si el concepto está aprobado); al reiniciar no debe otorgar/repetir ni olvidar progreso por depender de una tabla en memoria.

## 10. Narrativa opcional

### 10.1 Roles

- **Avances Mineclonia:** continúan representando logros survival normales; no se renombran ni reordenan.
- **Eventos vivos:** `mcl_events` se encarga del encuentro temporal y su progress UI/bossbar; Everforge podría escuchar resultado sin tomar ownership del combate.
- **Narrativa Everforge:** objetivos opcionales por jugador y/o capítulos personales que pueden referenciar hechos globales; se almacena un estado compuesto mínimo porque `awards` no es un journal de misiones.
- **Presentación:** reutilizar `awards`, `doc`, libro/mapa, la pestaña de inventario y formspecs existentes. No instalar framework externo.

### 10.2 Semántica de misiones sin escribir una historia

Un objetivo puede representar uno o varios **tipos de condición técnica** (milestone, recuento de evento, descubrimiento, resultado de evento o requisito de avance) y guardar ID/progreso/estado. Se distinguen:

- Objetivo disponible/aceptado/opcional/completado/archivado como estados técnicos a validar.
- Logro Mineclonia existente (`mcl:*`) frente a milestone Everforge (`everforge:*`) y objetivo/capítulo (namespace separado).
- Progreso del jugador frente a hecho del mundo. Completar un objetivo personal no declara que todos los jugadores lo completaron.

No se aprueba una campaña, NPC narrativo, texto, recompensa, diálogo ni gate. La historia se puede dejar completamente inactiva en las preferencias de juego sin que falte ningún recurso del modo survival normal.

## 11. Especificación visual preliminar

### 11.1 Árbol RPG

**Objetivo aprobado:** una UI de árbol cuyos enlaces representan requisitos reales. Propuesta de layout, pendiente de mockup y aprobación:

1. **Cabecera común:** Dominio nivel/avance, puntos generales libres y estado de migración si corresponde (solo depuración, no pantalla normal).
2. **Navegación de cinco disciplinas:** pestañas/botones de Minería, Forja, Combate, Exploración y Artesanía; todas disponibles para todos. Seleccionar una muestra su XP/nivel y su grafo.
3. **Área de grafo:** nodos por ID/posición generados de metadata; conectores solo entre prerequisitos declarados. Estados bloqueado, disponible, desbloqueado o max rank se indican por texto, contorno/símbolo y contraste, no solo color.
4. **Panel de detalle:** nombre, disciplina, rango, descripción, requisitos faltantes, puntos generales necesarios y texto de efecto aprobado. Compra solo si el nodo de datos permite comprarlo; no delegar la lógica a la UI.
5. **Acceso al inventario:** conservar la pestaña Everforge existente (`mcl_inventory`); para resoluciones pequeñas usar navegación/páginas por disciplina si pan/scroll no es consistente en 5.17.0.
6. **Diseño adaptativo:** primero validar proporciones con formspec 7 en varias escalas/resoluciones y traducciones largas. El formulario modal actual no se cambia hasta que el árbol esté validado con el modelo.

**Visual reutilizable:** `forge_theme()`/panel/botones/slots Everforge, marfil/cobre, galerías `doc`, iconos de items y referencias de `mcl_achievements`. No hay icono de skill dedicado confirmado. Si la lectura de nodos no puede lograrse con assets existentes, se presenta un requerimiento de arte original 16×16 separado y se espera aprobación.

### 11.2 Indicadores de calidad de equipo

**Diseño funcional aprobado:** mantener material y calidad como atributos independientes; además de descripción/tooltip, indicar calidad mediante símbolo, contorno o badge discreto, incluso si el usuario no distingue colores. Mantener texto legible y `toolranks` compatible.

**Restricción técnica a resolver antes de codificar:** la calidad actual se encuentra en metadata del stack y el icono (`inventory_image`/`wield_image`) es propiedad de la definición registrada, compartida por stacks del mismo nombre. Por ello, un tint/borde de formspec por sí solo no garantiza una marca visible en los slots estándar/hotbar. El plan no presupone que `ItemStackMetaRef` pueda cambiar la textura de una copia individual.

Opciones a prototipar en Luanti 5.17, sin alterar stats:

- Badge/composición en la UI propia del fundidor/árbol y tooltip, como prueba de concepto visual.
- Confirmar si el renderer de inventario ofrece una API de overlay por stack realmente estable.
- Solo si se requiere en hotbar nativa y no hay API: evaluar variantes de item registradas por calidad. Esto puede multiplicar definiciones, cambiar IDs guardados, interactuar con encantamientos/autogroup/toolranks/recetas y migrar ítems; es una opción de **alto riesgo**, no recomendación inicial.

El indicador debe ser pequeño y legible a 16×16, redundante con nombre/texto, claramente separado de tintes del material y no tocar stats, catalyst ni odds. No se crea textura nueva sin aprobación. La decisión de mecanismo técnico queda pendiente de prototipo en un mundo aislado.

### 11.3 Ambientación

- Conservar tiles/sprites/escala y sombreado de Mineclonia como base.
- Cementerio y Torre de Hielo pueden evaluarse con bloques decorativos/variantes ya existentes si se aprueba posteriormente; no se modifican mapgen ni estructuras en el plan.
- Guardianes actuales siguen siendo skeleton/stray/zombie. Priorizar animaciones/sonidos/partículas ya disponibles; arte/entidad original solo si una revisión futura lo solicita.
- El yunque adjunto se trata como icono; el logo/header permanece separado. La paleta de UI no se impone a biomas.

## 12. Plan por fases

La tabla contiene los nueve campos solicitados (objetivo, reutilización, rutas, trabajo nuevo, migración, validación, dependencias y riesgo), además de la fase. Solo la Fase 0 está autorizada; su parte estática se entrega en §18–21 y su parte runtime sigue pendiente. Las fases funcionales requieren aprobación nueva. La región inicial se añade como trabajo separado posterior a esta validación, sin implementarla en Fase 1 por defecto.

| Fase | Objetivo | Sistemas reutilizados | Archivos/rutas previstas | Desarrollo nuevo | Migración | Validación / aceptación | Dependencias | Riesgo |
|---|---|---|---|---|---|---|---|---|
| **0 — Validación real** | Confirmar baseline del juego/servidor y apariencia real antes de elegir hooks | `game.conf`, `mod.conf`, APIs de XP, worlds, damage, awards; UI Everforge y assets MCL | Ningún archivo de gameplay; usar copia aislada de mundo y reporte de prueba | Ninguno; recopilar `world.mt`, settings, mods activos, logs, versión, pantallas | Respaldar copia de personajes existentes; lectura del estado heredado sin guardarlo/modificarlo | Luanti 5.17.0 + Mineclonia 0.124.1; mods/levelgen activos; test XP/death/encantamiento/anvil/clase/skills; UI en varios DPI; icono adjunto frente a `menu/icon.png` en el launcher | Runtime objetivo disponible y mundo desechable con copia, pues no hay `world.mt` en checkout | Medio (solo entorno de prueba; alto si se usa save real) |
| **1 — Contrato y núcleo de progresión** | Separar datos y normalizar eventos; sin skills nuevas ni cambio a XP vanilla | `player:get_meta`, `core.get_mod_storage`, `mcl_experience` solo lectura de contexto, `core` dig/craft callbacks, `mcl_damage`, `mcl_worlds` | Nuevos módulos propuestos `mods/MISC/everforge/progression/state.lua`, `events.lua`, `actions.lua`, `schema.lua`; loader en `init.lua`; pruebas bajo `tools/` | Estado persistente, niveles derivados por funciones configurables aún sin curva aprobada, router e interfaces de consulta; `mcl_experience` no se modifica | V1 snapshot aditivo descrito en §8; esquema versionado; perfil nuevo vs viejo detectado | Unit/static tests de serialización, repetición del mismo ID sin duplicar, death/rejoin/restart, XP vanilla exactamente igual al baseline | Fase 0; confirmar ownership y salida de cada callback; no definir tasas | Alto (persistencia/compatibilidad) |
| **2 — Disciplina piloto y migración de rangos** | Probar práctica→disciplina→puntos compartidos con una sola especialización basada en efecto existente | Hook minado o salida del melter, `deep_miner` o `forgemaster`, `toolranks` como referencia de contador item-level | `progression/actions.lua`, nuevo `disciplines.lua`/`skills.lua`, ajustes mínimos en `init.lua`; tests estáticos/runtime | Crédito de disciplina y Dominio una vez por acción; primer nodo únicamente tras aprobar mapeo; no inventar efecto/valor | V2 en copias: créditos legacy/puntos/rank transferidos exactamente una vez, clase heredada todavía disponible para rollback; definir qué efecto sigue leyendo datos nuevos | Pilot route repetible y no farmable por duplicación; dos jugadores; puntos generales compartidos; la habilidad conserva su efecto existente y misma magnitud; vanilla XP intacta | Fase 1, definición aprobada de una disciplina/nodo y política de crédito legacy | Alto (balance/migración aunque se conserve efecto) |
| **3 — UI RPG y árbol visual** | Representar Dominio, cinco tracks, punto global, grafo/requisitos y estados reales | `mcl_inventory` tab, `mcl_formspec`, `forge_theme`, `doc` galleries y assets MCL existentes | Separar presentación en `mods/MISC/everforge/progression/ui.lua` o equivalente; translations `locale/template.pot`, `locale/everforge.es.po`; `init.lua` solo registra tab/callback | Grafo dibujado desde definición validada; detalle/requisitos; ninguna rama visual ficticia ni movimiento de mecánica por el UI | Perfiles deben mostrar rangos/unlocks realmente migrados; no reescribir la ficha para forzar arte | Smoke tests de formularios, estado bloqueado/disponible, strings largos, resoluciones/DPI, traducciones; ningún click da compra duplicada | Fases 1–2; catálogo/requisitos reales aprobados; resultado visual probado sin afectar UI global | Medio-alto (formspec, datos y resoluciones) |
| **4 — Hechos de mundo y narrativa opcional** | Registrar resultados mundiales y objetivos personales compuestos, sin introducir historia/gates | callbacks de `mcl_worlds`, `mcl_events`, raids, villages, trials/vaults; `awards`/`mcl_achievements`, libros/mapas/doc | `progression/world.lua`, `narrative.lua`, adaptadores en `init.lua`; quizá `mod.conf` para dependencias opcionales `awards`/`mcl_events` si se confirma uso | Almacén compacto de hechos, dedupe, objetivo compuesto opcional y adapter de milestones | Versionar facts; no reescribir logros vanilla; world facts no migran como hechos completados sin evidencia | Reinicio/crash con evento activo/finalizado, multiplayer global vs personal, awards deshabilitado/ausente, no gating; pruebas específicas de APIs/hook | Fases 0–1; confirmar callbacks de completado de fuente, definir qué es global; narrativa opcional aprobada | Alto (eventos en memoria, identidad y scope mundial) |
| **5 — Pulido visual aprobado** | Implementar icono calidades/árbol y pequeñas mejoras de presentación solo tras QA | UI Everforge/Mineclonia, iconos nativos, decoraciones/partículas/sonidos existentes | Posible futuro `menu/icon.png` con el attachment exacto aprobado; `textures/` solo si falta recurso y licencia; item UI/init solo si el mecanismo es viable | Badge/contorno simbólico, no stats; prototipo de marcas en GUI y luego quizá inventario/hotbar; reuso de bloques/mobs/FX primero | No cambiar nombres de ítems sin plan de alias/migración; calidad en metadata debe sobrevivir save/load/enchant/repair/toolranks | 16×16, escala del inventario/hotbar/tooltip, daltonismo, contraste, atributos idénticos, toolranks, encantamiento, guardado, cliente low/high end | Aprobación del icono/licencia, especificación gráfica, y resultado técnico de calidad por stack | Medio-alto; alto si variantes de item o arte nuevo |

### Secuencia y control de cambio

- Fase 0 no cambia archivos del juego ni la partida; la auditoría solo informa compatibilidad estática. No concluir mods activos sin revisar la save.
- Fase 1 aún no altera `mcl_experience` ni otorga beneficios: primero se valida el contrato/event router en una rama de implementación aprobada.
- Fase 2 requiere que el usuario apruebe nodo piloto, mapeo legacy y prevención de farming. No cambia el efecto o la magnitud del skill heredado.
- Fase 3 depende del grafo real de Fase 2; no dibujar un árbol de las 45 habilidades no aprobadas.
- Fase 4 no debe iniciar hasta que se decida global vs personal y existan callbacks comprobados; no crear historia ni misión aquí.
- Fase 5 se puede probar en copia de UI/recursos, no en un mundo que el usuario usa. La integración del icono anvil requiere aprobación de empaquetado/licencia; no sustituye el logo.

## 13. Pruebas de aceptación por etapa

### Fase 0 — baseline y configuración

1. Reportar versión efectiva del server y client, Mineclonia, listado de mods cargados, settings de mapgen y `world.mt` de una copia. Distinguir ese mundo de lo declarado en el checkout.
2. Probar `mcl_experience` al minar, combatir, recoger XP, morir, reconectar; encantar y usar yunque. Registrar valores antes/después. No ejecutar en producción.
3. Crear perfiles de copia para cada clase con cero, uno o varios ranks y con puntos libres; confirmar `everforge:class`, `earned`, `spent`, `skill:*`, factores de física, bonus de daño, XP contextual y forja.
4. Mantener dos copias de assets: menú actual `menu/icon.png` grass + `menu/header.png` wordmark; adjunto anvil como referencia. Verificar que el path activo del launcher es realmente `menu/icon.png` en este juego. No sustituir archivos en este test.
5. Ver fundidor, WAILA, guía y tab actual en varias resoluciones/DPI e idiomas; guardar capturas, sin ajustar código.

### Fases 1–2 — estado, eventos y migración

1. Una acción con dos callbacks acoplados produce como máximo una entrega por ID de evento.
2. Procesar un mismo evento dos veces no suma XP/points/facts dos veces; acciones independientes repetidas válidas siguen la política aprobada.
3. XP vanilla, niveles actuales, pérdidas al morir, costes de encantamiento/anvil y fuentes nativas coinciden con baseline.
4. Dominio/disciplina no disminuyen al morir; reaparecen tras leave/join, shutdown normal y restart; probar parada abrupta en una copia.
5. Un personaje nuevo no recibe clase permanente en la versión ya aprobada; el personaje antiguo conserva su snapshot/rollback y no recibe bonus de clase+skill duplicado.
6. Migración V1 ejecutada dos veces es idéntica; migración interrumpida se reanuda; perfiles con clase vacía/desconocida y metadata parcial no fallan.
7. Puntos heredados libres, gastados y ranks migrados se reconcilian con informe exacto; no se suman de nuevo al estado nuevo.
8. Ningún craft predictivo da progreso; resultado sin output, craft fallido, daño no atribuible o nodo colocado por mod no cuentan salvo regla aprobada.
9. Perfil multijugador: cada actor conserva su progreso, un hecho global se registra una sola vez y no otorga automáticamente recompensa individual a todos.
10. Al menos una ruta de prueba por disciplina, con registros de eventos observados y revisión antifarm; las tasas/curvas siguen deshabilitadas o de configuración experimental hasta autorización.

### Fases 3–5 — UI, mundo, narrativa y arte

1. Cada arista del árbol corresponde a un `requires` validado; no hay nodos sin efecto/descripción aprobados o links decorativos.
2. Nivel general, niveles de disciplina, puntos libres, puntos gastados, rango y requisitos de UI reflejan datos de la fuente de verdad; comprar una habilidad no duplica estado.
3. En formularios con awards/`mcl_events` opcionalmente ausentes, el survival y la progresión personal funcionan; historia apagada no bloquea ninguna acción vanilla.
4. Hecho global se conserva en reinicio; evento aún activo se interpreta según el API propietario, no como completado por ausencia en memoria.
5. Comprobar reinicio/crash, offline/online, 2+ jugadores y world storage en una copia desechable.
6. Indicador de calidad se distingue de material a 16×16, en tooltip/inventario/hotbar según el mecanismo finalmente aprobado; conserva stats/recipe/materiales y metadata al encantar, reparar, mover, soltar, comerciar, guardar y recargar.
7. Si el mecanismo exige variantes de item, probar alias/ID y carga de ítems antiguos antes de cualquier migración; abortar fase visual si cambia drop, capabilities o persistencia.
8. Icono anvil, logo y fondos se verifican como archivos distintos; icono no se convierte en logo y el logo no se vuelve a dibujar. Toda alteración/copia al path activo se autoriza antes.

## 14. Riesgos y mitigaciones

| Riesgo | Severidad inicial | Mitigación propuesta |
|---|---|---|
| No existe `world.mt`; no se sabe qué mods/settings están activos en una partida | Alta | Fase 0 en copia real y reporte del servidor; no asumir el bundle equivale a mundo activo |
| El nivel vanilla actual no representa progreso histórico por pérdida de XP al morir | Alta | No inicializar Dominio desde `get_level()`; usar solo datos `earned/spent` para crédito legado, con política aprobada |
| El callback de Everforge modifica XP vanilla cerca de spawner (`arcanist`/`dungeoneer`) | Alta | Hallazgo de compatibilidad: para dejar XP Mineclonia intacta hay que decidir cómo retirar/convertir ese efecto; no cambiarlo en fase documental |
| Efectos de clase + ranks pueden duplicarse si se mapean de forma ingenua | Alta | Snapshot + tabla migración + modo de compatibilidad; pruebas por clase/rank y cutover atómico |
| `playerphysics:physics` contiene contribuciones de varios mods | Alta | Eliminar solo IDs Everforge por API; nunca borrar meta serializada completa |
| `mcl_events` y dimensión previa usan runtime/in-memory; trials guardan ObjectRefs en memoria | Alta | Consumir resultado explícito, persistir solo facts aprobados y probar reinicio; no reconstruir “completado” por inferencia |
| Combate/forja/crafting sin ID estable o atribución de actor | Media-alta | Fase 0 inspecciona API; limitar adapter y no hacer polling; separar resultado y crédito |
| Doble progreso por `awards` + evento Everforge o por varias callbacks | Media-alta | Una única publicación/ID y consumidores sin recompensa duplicada |
| Favorecer una actividad/repetición trivial | Alta | Datos medidos, general credit por acción y no por número de tracks, política antifarm por source; ningún número hasta aprobación |
| Un árbol UI puede mostrar grafo falso o enorme | Media | Modelo de nodos primero; tabs/páginas por disciplina; validators de ciclos/requisitos; no codificar 45 skills de propuesta |
| Indicador calidad por stack no existe como asset del item actual | Alta | Prototipar renderer/GUI en 5.17; preferir badge en UI propia; no saltar a múltiples IDs sin análisis de migración |
| Icono aprobado está adjunto pero no empaquetado/licencia no especificada | Media | Preservar attachment, preguntar autorización/uso; resolver path y test de launcher en fase 0; no alterar ahora |
| Cambiar nombres de item o skill metadata puede romper herramientas, toolranks o saves | Alta | IDs estables, mantener aliases/legacy fields, tests de save+enchant+repair+toolranks |
| Nueva narrativa puede volverse obligatoria indirectamente | Media | Flags/objetivos opcionales; no modificar gates ni premios del juego base |

## 15. Decisiones que requieren aprobación antes de cada fase

### Validación runtime pendiente de Fase 0 (investigación ya autorizada)

- Qué copia de mundo/servidor se puede usar y si se puede compartir su `world.mt`/settings redactados.
- Confirmación de cliente/servidor objetivo exacto; no afirmar prueba visual hasta ejecutarla.
- La identidad del icono ya está confirmada. Integración y empaquetado siguen pendientes; no bloquean investigar las APIs ni entregar Fase 0.

### Antes de Fase 1

- Nombres definitivos de los cinco tracks/IDs internos y si “Dominio” es el término visible o solo técnico.
- Aprobación del contrato de eventos y la política: general XP una vez por acción, disciplina por tracks; normalización cuantitativa queda pendiente.
- Política de guardado y recuperación si una instancia se detiene abruptamente.

### Antes de Fase 2 / V2 migration

- Skill piloto (recomendado técnicamente: `deep_miner`, alternativa `forgemaster`).
- Mapeo de clase y cada rank actual; tratamiento del bonus de XP contextual para mantener XP vanilla.
- Regla de conservación/compensación de los beneficios de clase y crédito de puntos no gastados.
- Confirmación de que se permite introducir progresión por callbacks de actividades elegibles sin valores/efectos adicionales.

### Antes de Fase 3

- Qué contenido exacto se considera aprobado para las primeras ramas; relaciones reales y descripciones/efectos.
- Si los activos entran en primera versión o se conserva solo soporte pasivo hasta que haya controls/efectos aprobados.
- Aceptación de esquema visual y prueba de tamaño/scroll/páginas.

### Antes de Fase 4

- Lista de hechos personales vs globales y reglas de campaña opcional.
- Si objetivos se inician explícitamente o solo se registran como milestones; no crear narración hasta approval.
- Qué mods se consideran disponibilidad obligatoria u opcional por el mundo real.

### Antes de Fase 5

- Aprobación del mecanismo de calidad por stack y migración de IDs, si hiciera falta.
- Confirmación final del icono adjunto y derechos de distribución; el wordmark permanece separado.
- Cualquier pieza de arte original, modelos, FX, sonido o cambios a estructura/bioma se aprueba como contenido independiente.

## 16. Archivos del repositorio y futuros entregables

### Documentación existente usada

- `docs/everforge-progression-audit.md`
- `docs/everforge-art-audit.md`
- `mods/MISC/everforge/AUDIT.md`
- `mods/MISC/everforge/README.md`
- `mods/MISC/everforge/mod.conf`
- `mods/MISC/everforge/init.lua`
- `mods/HUD/mcl_experience/init.lua`
- `mods/HUD/awards/`, `mods/HUD/mcl_achievements/init.lua`
- `mods/CORE/mcl_worlds/`, `mods/CORE/mcl_events/`, `mods/CORE/mcl_damage/`
- `mods/ENVIRONMENT/mcl_raids/`, `mods/ENVIRONMENT/mcl_zombie_sieges/`
- `mods/ITEMS/mcl_trial_spawners/`, `mods/ITEMS/mcl_vaults/`
- `mods/MAPGEN/mcl_villages/`, `mods/ENTITIES/mobs_mc/villager.lua`
- `mods/PLAYER/playerphysics/`, `mods/ITEMS/toolranks/`
- `mods/ITEMS/mcl_armor/`, `mcl_enchanting/`, `mcl_potions/`, `mcl_anvils/`, `mcl_tools/`
- Recursos visuales: `menu/icon.png`, `menu/header.png`, `mods/MISC/everforge/textures/`, `mods/HUD/mcl_inventory/`, `mods/PLAYER/mcl_skins/`.

### Archivos previstos por fases futuras (no creados en esta entrega)

- Núcleo/progreso: módulos Lua bajo `mods/MISC/everforge/progression/`; el nombre/partición final se decide al aprobar Fase 1.
- Migración: módulo/versiones y tests de copia; nunca sobrescribir/eliminar los metadatos legacy hasta la aprobación de cutover.
- UI: módulo separado de formspec y traducciones Everforge; solo después del contrato de nodos.
- Integraciones: adapters `awards`/`mcl_events` opcionales y actualización de `mod.conf` solo cuando se confirme dependencia real.
- Tests: agregar pruebas estáticas/repetibles bajo `tools/` para esquema, dedupe y migración; usar pruebas de juego en copia para persistencia, hooks y UI.
- Recursos: ningún asset nuevo se crea en el plan. El icono adjunto queda externo al repo hasta autorización e integración futura.

## 17. Recomendación final

Fase 0 está autorizada: se entrega la validación estática y se distingue la verificación runtime todavía pendiente (§18). El yunque queda reconocido como icono propio, separado del header, con integración pendiente. Antes de Fase 1 deben resolverse los puntos de §21, incluido el alcance de la copia de prueba. La política de efectos heredados se propone en §20 sin ejecutarla. Solo entonces desarrollar el núcleo, preferiblemente probando una habilidad pasiva heredada como piloto sin tocar su valor.

La arquitectura recomendada conserva Minecraft/Mineclonia, hace que eventos confirmados alimenten tres salidas independientes, guarda progreso personal y mundial por separado, y deja la historia optativa. El árbol y la diferenciación de calidades se dibujan a partir de datos aprobados; la UI y los efectos actuales se reutilizan antes de pedir arte nuevo.

**No se inicia ninguna fase funcional hasta que el usuario apruebe este plan y las decisiones pendientes correspondientes.**


## 18. Fase 0 — resultados y alcance comprobado (28/10/2026)

### 18.1 Evidencia y resultado

Base inspeccionada: commit `bc6264e93b7d439dc2dd0d567067e31b003bfe57`, cabeza remota de PR #2 al iniciar esta revisión (`arena/b11c7209-segundointento`). GitHub reportó `state=open`, `merged=false`. Se trabajó en una copia aislada; la carpeta de este chat pertenece a otro repositorio y la copia local de Everforge estaba atrasada. No se usaron ni abrieron bases de datos de partidas.

| Comprobación | Resultado | Límite |
|---|---|---|
| Versión de juego y motor | README declara Mineclonia 0.124.1; `game.conf` exige como mínimo 5.10; se consultó el API oficial del tag Luanti 5.17.0 | No confirma versión efectiva de cliente/servidor |
| Baseline de XP | `mcl_experience.add_xp` encadena transformadores; `set_xp` escribe metadata `xp`; muerte pone XP en cero salvo `mcl_keepInventory` | Inspección de código, no prueba de muerte/encantamiento/yunque |
| Legado Everforge | Callback contextual altera XP vanilla; `earned_points` vincula puntos a niveles vanilla y actualiza el máximo guardado, también desde globalstep | Abrir la UI o ejecutar el juego actual puede escribir puntos; por eso no se abrió un perfil existente para «solo mirar» |
| Región inicial compartida | Hay centro mundial, búsqueda de aparición, preparación asíncrona de terreno y respawn con camas/anclas | No existe todavía una región Everforge única ni un proveedor público de región/spawn listo para usar |
| Persistencia | Mapa/nodos y `StorageRef` por mod/mundo disponibles | No hay transacción única mapa + mod storage + perfil |
| Hooks para Fase 1 | `core.register_on_dignode(pos, oldnode, digger)`, `core.register_on_craft(itemstack, player, old_craft_grid, craft_inv)` y `mcl_worlds.register_on_dimension_change(player, dimension, last_dimension)` | Callback de dig no prueba origen natural; craft repetido válido requiere reglas antifarm; dimensión se observa periódicamente |
| Combate y Forja | `mcl_mobs/physics.lua` invoca `self:on_die(pos, mcl_reason)`; melter Everforge confirma salida al aceptar `inv:add_item("output", out)` | No se verificó un bus universal de bajas; se necesita atribución del atacante. Timer del melter no identifica al autor: recoger un output no equivale automáticamente a haberlo fabricado |
| Mundo y mods activos | Dependencias declaradas inspeccionadas | No se dispone de una copia de mundo designada ni settings efectivos. `tools/generate_translation_strings/world/world.mt` es fixture de traducciones, no la partida del usuario |
| UI y marca | Paths separados `menu/icon.png`/`menu/header.png`; yunque confirmado como icono Everforge | No se cambió asset; no se verificó launcher, DPI, hotbar ni UI dentro del juego |

No se encontró un ejecutable `luanti`/`minetest` en PATH ni una app con esos nombres en `/Applications`; `motor/` no aporta el binario. Esto no prueba que no exista otro launcher. No se inició servidor, no se creó mundo, no se aplicó migración y no se ejecutó el juego sobre una partida existente. Las pruebas dinámicas de §13 permanecen **PENDIENTES**, no aprobadas por inferencia.

**Resultado de Fase 0:** viabilidad estática condicionada; no certificación de runtime. Hay APIs suficientes para diseñar una integración pequeña, con dos puntos a resolver: preparación/publicación segura de la región y conversión de XP heredada. No se declara completada la validación dinámica ni se habilita Fase 1 automáticamente.

### 18.2 Fuentes verificables

Fuentes de Mineclonia fijadas al commit inspeccionado (las referencias de línea describen esa versión):

- [Spawn y camas/anclas](https://github.com/joerojas2810-collab/SegundoIntento/blob/bc6264e93b7d439dc2dd0d567067e31b003bfe57/mods/PLAYER/mcl_spawn/init.lua): `get_world_spawn_pos` L69, `get_player_spawn_pos` L152, `spawn` L209, callback de respawn L240.
- [Centro mundial y aparición nueva](https://github.com/joerojas2810-collab/SegundoIntento/blob/bc6264e93b7d439dc2dd0d567067e31b003bfe57/mods/MAPGEN/mcl_biome_dispatch/init.lua): `get_spawn_point_2d` L467, `next_respawn_position` L559, generación inicial L626 y `register_on_newplayer` L648.
- [Preparación del terreno y heightmap](https://github.com/joerojas2810-collab/SegundoIntento/blob/bc6264e93b7d439dc2dd0d567067e31b003bfe57/mods/MAPGEN/mcl_levelgen/post_processing.lua): `map_index_heightmap` L2751, `is_area_fully_regenerated` L3342 y `generate_area` L3478.
- [Scripts de levelgen](https://github.com/joerojas2810-collab/SegundoIntento/blob/bc6264e93b7d439dc2dd0d567067e31b003bfe57/mods/MAPGEN/mcl_levelgen/scripting.lua), [API de features](https://github.com/joerojas2810-collab/SegundoIntento/blob/bc6264e93b7d439dc2dd0d567067e31b003bfe57/mods/MAPGEN/mcl_levelgen/API.txt) y [registro de entornos](https://github.com/joerojas2810-collab/SegundoIntento/blob/bc6264e93b7d439dc2dd0d567067e31b003bfe57/mods/MAPGEN/mcl_levelgen/register.lua).
- [XP nativa](https://github.com/joerojas2810-collab/SegundoIntento/blob/bc6264e93b7d439dc2dd0d567067e31b003bfe57/mods/HUD/mcl_experience/init.lua) y [bonos/puntos Everforge](https://github.com/joerojas2810-collab/SegundoIntento/blob/bc6264e93b7d439dc2dd0d567067e31b003bfe57/mods/MISC/everforge/init.lua): puntos L72–84, física L87–100, bonus XP L107–119 y sondeo de puntos L1619.
- [API oficial Luanti 5.17.0](https://github.com/luanti-org/luanti/blob/5.17.0/doc/lua_api.md): secciones «Environment access», «Registration functions», «Mapgen environment», «Schematic specifier», «Storage API» y «StorageRef». Se utilizó el tag objetivo y no solo la documentación web de la última versión.

## 19. Región inicial única — decisión aprobada y propuesta mínima

### 19.1 Contrato de mundo

Cada mundo tendrá **una sola región inicial física**, compartida por todos sus jugadores. Se crea una vez sobre el terreno procedural de ese mundo; no es una instancia por jugador, un lobby separado ni una plantilla que se restaura. Su terreno, construcciones, destrucciones, cofres y metadata persisten mediante el mapa normal. El hecho de que falten bloques o se destruya un marcador no autoriza regenerar la región. No habrá reparación automática al entrar, morir o reiniciar.

Un centro y un área de llegada pueden contener varios puntos seguros dentro de la misma región. «Compartida» no obliga a superponer a todos en un único nodo. Nuevos jugadores aparecen allí. Jugadores que vuelven conservan su posición; camas y anclas siguen las reglas normales de reaparición. La política recomendada es que el fallback mundial, cuando no hay cama/ancla válida, use esa misma región, sin alterar las comprobaciones ni los consumos nativos del ancla.

### 19.2 APIs concretas y sus límites

| API / punto de integración | Uso mínimo propuesto | Precaución comprobada |
|---|---|---|
| `core.get_mod_storage()` → `StorageRef:get_string/set_string` | Un manifiesto Everforge por mundo, obtenido al cargar el mod | No es un singleton de proceso compartido con los threads mapgen ni una transacción del mapa |
| `mcl_biome_dispatch.get_spawn_point_2d()` | Tomar el centro procedural nativo como ancla inicial, evitando otra búsqueda global | Captura `static_spawnpoint` al cargar el módulo; cambiar settings después no actualiza esa variable local |
| `mcl_levelgen.get_dimension("mcl_levelgen:overworld")` | Dimensión y límites verticales para preparar el área | No hardcodear Y=0 como suelo ni mezclar coordenadas de levelgen con coordenadas Luanti |
| `mcl_levelgen.generate_area(x1,y1,z1,x2,y2,z2,cb_progress,data1,data2)` | Preparar el terreno del área durante creación controlada de un mundo nuevo | Callback de progreso puede repetirse; no es un único callback «terminado». Debe comprobarse la disponibilidad real del área |
| `mcl_levelgen.is_area_fully_regenerated(dim,x1,y1,z1,x2,y2,z2)` | Barrera antes de colocar cualquier estructura | El nombre se refiere al pipeline propio de Mineclonia. No sustituye validar nodos/suelo ni permite reescribir una zona habitada |
| `mcl_levelgen.map_index_heightmap(dim,x,z,false)` + lectura de nodos | Elegir apoyo y altura de una huella compacta, siguiendo la superficie natural | El heightmap es un índice de generación; tras ediciones no basta para certificar seguridad. Usar convenciones de `move_respawn_position`, incluyendo `dim.y_global`, y comprobar suelo/cabeza reales |
| `core.emerge_area(pos1,pos2,callback,param)` | Cargar/generar bloques con el motor; comprobar acciones y `calls_remaining` | En levelgen no certifica por sí sola la terminación de su postprocesado. `EMERGE_CANCELLED` y `EMERGE_ERRORED` no son éxito; `core.load_area` solo carga |
| `core.place_schematic` o `core.place_schematic_on_vmanip` | Colocar una única pieza compacta, ajustada al terreno ya preparado | No usar una estructura que aplaste todo el relieve; `force_placement=false` no garantiza por sí solo respetar construcciones. VoxelManip exige volumen completo, luz/líquidos y metadata inicializados de forma explícita |
| `core.register_on_newplayer(player)` | Punto nativo de primera entrada | Mineclonia ya registra uno y puede dejar un teleport asíncrono pendiente. Añadir otro `set_pos` al final puede perder la carrera; no se recomienda |
| `mcl_spawn.get_player_spawn_pos` / `mcl_spawn.spawn` | Conservar selección y validación de cama/ancla y fallback mundial | En levelgen el fallback retorna segundo valor `0`, que en Lua es verdadero. No convertirlo ingenuamente a `false` ni interceptar todo respawn |
| `mcl_spawn.set_spawn_pos(player,pos,message)` | **No usar para definir la región** | Guarda `mcl_beds:spawn` y toca propiedad de cama; no es un setter del centro mundial |

Las funciones de levelgen/spawn citadas son APIs concretas del checkout. Algunas están implementadas sin contrato público formal en `API.txt`; deben fijarse a esta versión y cubrirse con pruebas de integración. La ausencia de un setter/proveedor público de centro mundial listo para Everforge es una limitación real.

### 19.3 Implementación mínima recomendada, todavía no implementada

1. **Alcance inicial: mundos nuevos explícitamente habilitados**, con acceso de jugadores cerrado durante el bootstrap. La falta de un manifiesto no demuestra que un mundo sea nuevo: si ya existe mapa/perfiles, no colocar nada ni cambiar su spawn por defecto. La incorporación a un mundo existente requerirá otro procedimiento aprobado. No cambiar `chunksize`, mapgen o semilla de una partida.
2. Un módulo propuesto `mods/MISC/everforge/start_region.lua` coordina desde el entorno servidor la única creación. `mod_storage` mantiene un manifiesto serializado/versionado: `schema`, `region_id`, semilla como texto, versión del generador/plantilla, centro, límites, puntos de llegada y `state=planned/building/ready/needs_review`. Se fija el ancla nativa una sola vez; reinicios leen el manifiesto, no buscan otra región.
3. Preparar únicamente el volumen necesario y el margen de llegada con el pipeline de Mineclonia, esperar que termine, cargar los bloques y revisar pendientes, agua/lava, estructuras nativas y espacio libre. Elegir una huella pequeña con apoyos adaptados al suelo; si no cabe, detener con diagnóstico. No inventar aquí edificios, NPC, recompensas o un bioma completo. «Integrada» significa asentada en el terreno natural, no reemplazarlo por una plataforma plana. Tamaño/estética quedan por decidir.
4. Registrar `building` antes de escribir; colocar la pieza aprobada una vez, inicializar sus nodos y validar la llegada. Verificar el resultado antes de publicar `ready`. Toda la preparación ocurre sin acceso de jugadores; ninguna rutina de join, respawn, ABM o LBM vuelve a colocarla.
5. Proponer un **hook pequeño en el propietario `mcl_biome_dispatch`** para resolver una llegada mundial Everforge solo cuando el manifiesto está `ready`; el camino nativo permanece como alternativa cuando no se habilita esta función. Tanto la primera entrada (`next_respawn_position`) como el fallback de `mcl_spawn` deben consultar ese mismo proveedor. Una llamada pendiente al resolver debe volver a verificar disponibilidad y jugador conectado; nunca dejar un teleport nativo tardío que lo saque de la región. Declarar la dependencia de spawn/dispatch si se usa desde Everforge. No reemplazar funciones mediante monkey-patch ni registrar un segundo respawn que anule camas/anclas.
6. Buscar posiciones seguras dentro de los límites persistidos, leyendo los nodos actuales: suelo válido, altura suficiente, sin líquidos dañinos/portales, respetando protecciones y colisión. Si todos los puntos quedan bloqueados por cambios de jugadores, no reconstruir ni borrar bloques: detener la llegada con un mecanismo de espera/error y aviso administrativo. Este caso necesita una política de producto aprobada. Tampoco devolver un punto peligroso ni mandar silenciosamente a otra región.
7. Con `ready`, la región se carga como cualquier mapa. No se recalcula por jugador o por actualización de plantilla. Una actualización visual futura no implica volver a colocarla. Mantener el volumen pequeño; nada de forceload permanente por defecto.

**Por qué no usar el registro de features aleatorias actual:** `register_feature` + `register_configured_feature` + `register_placed_feature` sirven para estructuras repetidas, no garantizan unicidad mundial. Mineclonia carga scripts con `register_levelgen_script` y el motor usa entornos mapgen separados; una bandera Lua local no coordina todos los workers. Si en el futuro se exige una región extensa generada dentro del pipeline, será otra integración: ID/posición deterministas, escrituras limitadas por chunk y notificaciones (`notify_generated`/`register_notification_handler` o `save_gen_notify`) al servidor; mayor alcance que el bootstrap mínimo.

**Durabilidad e interrupciones:** se puede garantizar que la aplicación no reprograme una región publicada, pero no prometer «exactamente una vez» ante cualquier corte entre bases independientes. Si aparece `building` tras reinicio o `ready` no concuerda con el mapa, pasar a revisión sin recolocar automáticamente. Antes de publicar el mundo, validar tras guardado y reinicio limpio y respaldar mapa + mod storage conjuntamente. Para el mínimo, es preferible abortar/revisar un bootstrap interrumpido a sobrescribir la posible obra del jugador. No utilizar `delete_area` ni restaurar la plantilla para recuperarse.

### 19.4 Pruebas requeridas al autorizar su implementación

- Dos jugadores nuevos, entradas simultáneas y reinicio: mismo `region_id`, una sola colocación, llegadas dentro del área; reconexión de un jugador existente no lo mueve.
- Construir, excavar y vaciar un cofre; descargar/cargar chunks, cerrar y reiniciar: todos los cambios permanecen y ningún objeto/recurso reaparece por cargar.
- Morir con cama válida, cama destruida/bloqueada, ancla cargada/agotada y sin spawn personal: prioridad y consumo de Mineclonia intactos, fallback dentro de la región según política aprobada.
- Múltiples seeds, pendientes, agua, límites de chunk, threads mapgen y spawn radius; ninguna segunda región ni cortes de estructura.
- Interrumpir en `planned`, `building` y publicación: no reponer plantilla sobre modificaciones; error controlado, revisión o restauración conjunta desde backup.
- Abrir una copia de mundo anterior sin manifiesto: cero generación Everforge y cero reubicación. Destruir marcadores o bloquear todos los puntos de llegada: cero reparación automática.

## 20. XP heredada — análisis y transición propuesta, sin cambios

### 20.1 Efecto exacto observado

El callback L107–119 calcula `floor(xp * (1 + 0.05 * (rank_dungeoneer + clase_arcanist)))` para XP positiva si encuentra al menos un `everforge:dungeon_spawner` en una **caja** de ±18 nodos en cada eje. Arcanist aporta 1, Dungeoneer 0–3: entre 5% y 20% nominal; el redondeo puede anular el bono en entregas pequeñas (1 XP con rango efectivo 4 sigue siendo 1; 10 XP se vuelven 12). El radio no prueba una baja, participación ni finalización: puede afectar cualquier XP que llegue por `add_xp` allí, incluso fuentes ajenas a la mazmorra. No es un bonus directo a Dominio/disciplina.

Arcanist también tiene gravedad `0.96` por `playerphysics`; retirar su bonus de XP no debe retirar silenciosamente ese otro beneficio. `earned_points` usa `max(everforge:earned, floor(nivel_vanilla/5))`, guarda el máximo y se invoca también cada cuatro segundos. Por tanto, independizar el futuro sistema exige resolver **dos** dependencias: multiplicador de XP y concesión de puntos por niveles. Crear nuevos contadores sin retirar ambos en el cutover mantendría el acoplamiento.

### 20.2 Opciones para decidir

| Alternativa | Conservación de progreso | Riesgo / condición |
|---|---|---|
| Retirar el multiplicador y reembolsar Dungeoneer una sola vez | Archivar rank y compra; liberar exactamente sus puntos pagados como crédito general, conservar XP vanilla y demás compras | Se pierde el beneficio contextual futuro, con compensación explícita; valorar aparte Arcanist, que no pagó un punto por su bono |
| Transformar el rank en una especialización contextual aprobada | Compra ya pagada y rango se conservan en el nuevo nodo; sin reembolso simultáneo | Efecto, magnitud y elegibilidad nuevos requieren aprobación. No trasladar el 5–20% a Dominio automáticamente |
| Conservar el bono vanilla de forma temporal | Mantiene el comportamiento actual mientras no haya cutover | Solo transición: no satisface la separación final acordada y no debe presentarse como solución permanente |

**Recomendación:** retirada del multiplicador en el futuro cutover, devolución única de los puntos de Dungeoneer como crédito legado y snapshot del rank original. Para Arcanist, conservar constancia de clase/beneficios y decidir compensación de su bono de XP por separado; el valor no se inventa en Fase 0. Mantener la gravedad heredada solo durante una compatibilidad explícita o convertirla a un efecto aprobado, nunca dejar dos lectores aplicándola. No habrá clases permanentes nuevas. Esta recomendación no autoriza su ejecución.

### 20.3 Contabilidad y prevención de duplicaciones

- Snapshot inmutable de clase, `earned`, `spent`, cuatro ranks, factores Everforge y XP/nivel vanilla de diagnóstico. No restar XP histórica del perfil: no existe un historial con el que separar el bono de XP legítima. Tampoco compensar en XP vanilla ni convertir el nivel actual en Dominio/disciplina.
- Para un perfil consistente, `E=earned` guardado, `S=spent`, `U=max(0,E-S)`, `r=rank_dungeoneer`. Si se elige reembolso, se conserva `E`, el gasto reconocido pasa a `S-r` y el saldo a `U+r`; no aumentar `E` además de reducir gasto. Ejemplo: E=10, S=7, r=2 → gasto reconocido 5, saldo 5; **no** saldo 7. Si se convierte al nuevo nodo, gasto y rank siguen reconocidos y el saldo no recibe esos `r` otra vez.
- La fórmula exige validar `0<=r<=3`, `E>=S>=r` y coherencia entre gasto y todos los ranks. Un perfil parcial/corrupto/desconocido no se «arregla» inventando progreso; conservar valores, informar discrepancia y revisar. Si el nivel actual sugiere puntos no guardados, reportar diferencia para una decisión separada; no derivar automáticamente nuevo crédito de vanilla.
- Registrar decisión/versionado y resultado absoluto por perfil, no ejecutar `saldo += r` en cada join. El snapshot y el campo de crédito no pueden ser simultáneamente dos fuentes gastables. Un reintento debe reconstruir el mismo resultado y no volver a reembolsar. Compensación de clase, si se aprueba, tendrá su propio ID y se concede una sola vez, nunca inferida como «otro rank pagado».
- En el futuro cutover, un único modo persistido selecciona los lectores: `legacy` o `new`. El lector de XP heredada devuelve la entrada sin modificar para perfiles convertidos; el nuevo sistema escucha acciones confirmadas, nunca usa el delta de `add_xp` como práctica. Mientras esté en modo legacy no se activa su sustituto. No intentar cancelar el bono con otro callback inverso: el redondeo y el orden de callbacks hacen que no sea equivalente.
- El antiguo generador de puntos deja de escribir para un perfil convertido, tanto desde UI como desde globalstep; los lectores nuevos no invocan `earned_points`. Los beneficios nuevos y los de compatibilidad no se suman sobre la misma fuente. Eliminar factores por ID con API `playerphysics`, conservando factores de otros mods.
- La tabla de callbacks XP registra funciones y prioridades, pero no ofrece API pública para desregistrar un callback por ID. Cambiar su registro/gate requiere una modificación futura del código Everforge y reinicio; no manipular a ciegas `mcl_experience.on_add_xp` durante la partida.
- Rollback requiere versión de código compatible y snapshot/copia conjunta de datos. Cambiar de modo no puede repetir recompensas ya consumidas. Ninguna migración ni compensación se aplica durante Fase 0.

### 20.4 Evidencia pendiente de runtime

Matriz: clase Arcanist/otra, ranks 0–3, caja dentro/fuera y límites, XP 0/negativa/positiva pequeña/grande, sin spawner, muerte/encantamiento/yunque, callbacks adicionales y recolección de XP. Comparar valores vanilla exactos antes/después del cutover; ensayar doble login, doble migración, interrupción y reanudación. Confirmar que XP vanilla ya obtenida y puntos/ranks históricos no disminuyen, y que ningún punto ni efecto se concede dos veces. Esto exige perfiles desechables o una copia autorizada, no editar personajes reales.

## 21. Decisiones y condiciones antes de Fase 1

Fase 1 **no empieza con esta entrega**. Su alcance mínimo propuesto es esquema/contratos/router en modo de observación y pruebas aisladas, sin recompensas nuevas, sin activar la región y sin migrar perfiles existentes. Esto restringe la fila de Fase 1 de §12: V1 snapshot será una entrega separada autorizada, no se ejecutará por defecto al crear el núcleo.

1. **Entorno de validación:** indicar launcher/binario y versiones reales, y designar un mundo desechable o copia autorizada con configuración redactada. La autorización de Fase 0 no autoriza iniciar el juego sobre la partida original. Sin esta verificación no se certificará compatibilidad de runtime.
2. **Alcance de Fase 1:** aprobar o ajustar el núcleo en observación, sin migración ni otorgamiento de XP/puntos. Propuesta de IDs: `mining`, `forging`, `combat`, `exploration`, `crafting`; «Dominio» visible y `mastery` interno. Aprobar que un evento dé como máximo un crédito de Dominio y pueda alimentar varios tracks solo según una tabla futura.
3. **Legado XP:** elegir reembolso de Dungeoneer o conversión a nodo; decidir compensación del bono de Arcanist y destino de su gravedad. Estas políticas pueden permanecer pendientes si Fase 1 es solo observación, pero bloquean el cutover y toda prueba de conversión. No se necesita volver a decidir la independencia de XP: ya está aprobada.
4. **Región inicial:** aprobar el mínimo solo para mundos nuevos, anclado al spawn procedural nativo, con bootstrap cerrado a jugadores y hook en el dueño del spawn. Confirmar dimensiones aproximadas/contenido de la región y política ante llegada totalmente bloqueada (recomendación: esperar y avisar, sin reparar el mapa). El fallback mundial a esta región sigue la semántica nativa de cama/ancla; confirmar ese alcance. La creación de la región no forma parte automática de Fase 1.
5. **Durabilidad:** aceptar revisión manual/restauración conjunta para bootstrap interrumpido y aprobar cómo se probará el guardado/reinicio en copia. No se puede ofrecer una transacción global que estas APIs no tienen.

No bloquea Fase 1: elegir arte nuevo, volver a confirmar la identidad del yunque, integrar el icono, redactar historia o definir las 45 habilidades. Todos siguen fuera del alcance. PR #2 permanece abierto; ninguna fase documental autoriza fusionarlo.
