# Everforge: primera iteración jugable

Estado: desarrollo inicial; sin migraciones de personajes. Mineclonia del repositorio (0.124.1), Luanti **5.17.0**. Esta entrega sustituye el bloqueo por fases del plan maestro por implementación y pruebas en mundos desechables.

## Abrir y jugar: launcher nativo de Luanti

Abrir **Luanti.app** normalmente, desde Finder/Dock o desde el enlace local `Luanti.app` de la carpeta Everforge. No se ejecuta ningún shell ni se mantiene Terminal abierto. Los antiguos `Iniciar-Everforge.command` y `Nuevo-Mundo-Everforge.command` se retiraron porque usaban `--go` y evitaban el menú nativo.

En esta instalación macOS, el juego ya está enlazado desde `~/Library/Application Support/minetest/games/mineclonia` a la carpeta del repositorio. **Everforge** es el nombre visible de `game.conf`; `mineclonia` es el identificador histórico de la instalación normal y se conserva para que los mundos previos sigan abriendo. No se duplica el juego con otro identificador. La cabecera Everforge y el icono siguen siendo archivos distintos; no se ha sustituido uno por el otro.

- **Individual:** seleccionar Everforge, pestaña **Start Game / Iniciar juego**, seleccionar el mundo y dejar **Host Server / Hospedar servidor** desmarcado. Pulsar **Play Game / Jugar**.
- **Crear:** en esa misma pestaña, **New / Nuevo**, escribir un nombre y elegir **singlenode** para la generación procedural propia de Mineclonia. Puede dejarse la semilla vacía para usar una aleatoria, o introducir cualquier semilla válida. `12345` sirve únicamente para reproducir la prueba de referencia. Confirmar crea solo ese mundo; abrir Luanti o pulsar Jugar no crea otros.
- **Continuar:** seleccionar el mismo mundo. Construcciones y perfiles se guardan en él; cerrar y volver a abrir el launcher no lo reinicia.
- **Hospedar con amigos:** seleccionar el mismo mundo, marcar **Host Server**, escribir el nombre del anfitrión y la contraseña de su propio personaje, mantener **Announce Server** desmarcado si no se desea publicar en la lista, y usar puerto **30000**. Pulsar **Host Game / Hospedar partida**. El anfitrión juega en su propia computadora; al salir se detiene esa sesión y el mundo queda guardado.
- **Desde otra computadora en la misma red:** abrir Luanti 5.17.0 → **Join Game / Unirse**, dirección IP local del anfitrión (por ejemplo `192.168.1.50`), puerto `30000`, nombre propio y su propia contraseña (se registra al primer ingreso). No usar `127.0.0.1`, que apunta a la computadora de cada jugador. El servidor envía los mods y recursos del juego; el invitado no necesita instalar otro launcher ni copiar el mundo.
- **Redes diferentes:** hospedar en casa no atraviesa automáticamente el router. Se necesita una red privada compartida o redirección **UDP 30000** al anfitrión y su dirección pública; CGNAT puede impedir esa conexión. No se configuró el router ni se publicó un servidor permanente. Permitir el tráfico de Luanti en el firewall de la red utilizada si el sistema lo solicita.

El modo individual usa el personaje nativo `singleplayer`; al hospedar se usa el nombre escrito. El progreso pertenece a cada personaje: para continuar un personaje del anterior acceso de desarrollo, hospedar con el mismo nombre que se usaba entonces. Cambiar de nombre no borra el perfil anterior. La contraseña del anfitrión no es una contraseña compartida del mundo.

Los mundos del launcher normal y `.everforge-dev/` son directorios distintos. Esta última carpeta queda para pruebas de desarrollo. En la instalación local se conserva el mundo original de desarrollo y se incorpora una copia al listado nativo para poder continuarlo; solo la copia adapta su identificador de juego a `mineclonia`, sin convertir perfiles ni bases de datos.

## Herramientas de desarrollo (no son el inicio recomendado)

`tools/play_everforge.py` queda como herramienta CLI de pruebas aisladas y extracción verificada de Luanti 5.17.0; no ofrece una interfaz de inicio propia. Sus parámetros `--new`, `--server` y `--client` se usan en los tests descritos abajo. No cambian el flujo del launcher normal ni exponen un servidor a la LAN por defecto. La instalación automática macOS ARM64 verifica el ZIP oficial con SHA256 `0ba118b537d3cc6fd07cd2268fef25e515fc6d87c27ad69b476144a8e28dba3c`.

## Balance provisional y acciones

Todos los niveles empiezan en 0. XP total para nivel N = `base × N²`; base de Dominio 50, base por disciplina 25. Cada nivel de Dominio concede un punto general. Cada rango de habilidad cuesta un punto y exige al menos ese nivel en su disciplina. Las cinco disciplinas están abiertas a todos; no hay clase permanente ni restricciones nuevas de equipo.

| Actividad confirmada | Disciplina | XP de disciplina y de Dominio |
|---|---|---:|
| Romper un nodo | `mining` / Minería | 1 |
| Salida aceptada por el fundidor Everforge, con proveedor manual conectado a ≤16 nodos | `forging` / Forja | 6 |
| Muerte de monstruo nativo con jugador como fuente del daño | `combat` / Combate | 15 |
| Entrar en una celda horizontal nueva de 128 nodos, separada por dimensión | `exploration` / Exploración | 8 |
| Callback de fabricación completada | `crafting` / Artesanía | 4 |

Tabla inicial: una disciplina por actividad y una única concesión de Dominio; no se suman disciplinas para calcular Dominio. No se observa ni se transforma `mcl_experience`. Las cantidades son `everforge_xp_<disciplina>`; curvas `everforge_mastery_base` / `everforge_discipline_base`, documentadas en `settingtypes.txt`. Reiniciar tras cambiar configuración. Cambiar curvas puede cambiar niveles/puntos disponibles; no revoca rangos comprados.

Primeras habilidades: Minería cuidadosa (−4% desgaste por rango, solo herramientas Everforge, 3 rangos), Forjador (−1 s por rango en fundidor cercano, mínimo 3 s, 3 rangos), Explorador (+4% velocidad por rango, 3 rangos) y Guardia (−10% daño melee de mobs/jugadores, 1 rango). Reutilizan los motores de desgaste, fundición, `playerphysics` y `mcl_damage` existentes. El árbol definitivo y una habilidad propia de Artesanía quedan para otra iteración.

## Persistencia y región

Progreso en `everforge:progression:v1` de player metadata, serialización segura de Lua, un solo registro por actualización. Se conserva al morir y al reiniciar. Un perfil inválido no se reemplaza silenciosamente. Últimos 128 IDs evitan duplicados inmediatos y se guardan con el progreso. Descubrimientos de exploración persisten hasta 4096 celdas por personaje; al alcanzar el límite se detiene ese crédito.

El campamento revisado incluye pabellón de roble con techo, fogata nativa, bancos, caminos, faroles, mesa y horno. En la primera colocación despeja vegetación natural del pequeño recinto; nunca vuelve a despejarlo al cargar. Los manifiestos antiguos ya completados conservan su campamento original: crear un mundo nuevo para ver el diseño revisado.

La región usa un manifiesto mundial `start_region:v1`, radio de llegada 10 nodos en el prototipo revisado, ancla del spawn procedural. Se coloca una vez en un mundo nuevo y no se restaura al cargarlo. Camas/anclas mantienen su selección y validación nativas; solo el fallback mundial y jugadores nuevos usan el proveedor compartido. Las alternativas seguras se buscan dentro de la misma región, leyendo nodos actuales. Si no existe llegada segura, se registra el error administrativo y se rechaza la llegada con explicación; no se rompen construcciones ni se envía al jugador fuera de la región. El intento se vuelve a resolver al reconectar.

Un reinicio con creación incompleta deja `needs_review`: detener y revisar el registro y las copias de seguridad; no se reintenta ni reconstruye automáticamente. Nunca se repone automáticamente la plantilla. No hay transacción conjunta entre mapa, jugador y mod storage; estos tests comprueban reinicio limpio, no durabilidad ante cualquier corte eléctrico. Mundos previos sin manifiesto no reciben una región por defecto. `everforge_start_region=false` permite comparar con spawn nativo.

## Pruebas reproducibles

```sh
python3 tools/test_everforge_interfaces.py
python3 tools/play_everforge.py --new --test-stage bootstrap --port 49179
python3 tools/play_everforge.py --test-stage restart --port 49179
python3 tools/play_everforge.py --test-stage players --port 49179
# Conectar dos clientes: ForgeAlice y ForgeBob, contraseña de prueba everforge-test.
python3 tools/play_everforge.py --test-stage verify_players --port 49179
# Reconectar ForgeAlice.
```

Solo los mundos de integración cargan el mod de pruebas. Ese mod prepara perfiles/objetos desechables, comprueba aserciones y apaga el servidor. No usar esos nombres ni fixtures como una partida de juego normal. El launcher retira el enlace al mod de pruebas al abrir normalmente el mundo. Cada etapa informa `EVERFORGE_TEST_PASS` o falla con error; el límite del arnés de integración es 360 segundos; la creación del campamento tiene un plazo de 180 segundos y búsquedas acotadas.

Evidencia de la ejecución y límites concretos: `docs/everforge-runtime-results.md`.

## Límites de esta iteración

- Balance y protección contra farming son provisionales: deduplicación reciente por posición minada y límite de 0,5 s por actividad no impiden todas las granjas. Minar nodos colocados puede dar XP fuera de la ventana reciente; los IDs no son un historial infinito.
- Forja acredita al último proveedor manual del input, conectado y cercano; no recompensa automatización, suministro anónimo ni jugadores desconectados. Mezclar proveedores en un mismo lote no reparte crédito.
- Una fabricación múltiple dentro de 0,5 s se limita a una concesión; no hay recompensa por unidades de output ni craft predictivo. Combate exige daño atribuible al jugador; bajas ambientales sin esa fuente no cuentan.
- Se mantiene `singlenode`, con semillas libres o aleatorias. El campamento valida su huella antes de construir y busca posiciones alternativas; si un ancla está en océano, puede usar una vez el ancla terrestre nativa de la misma semilla. Si se agota el presupuesto, se registra el motivo y no se reintenta al cargar. Semillas y límites realmente comprobados: [validación multisemilla](everforge-worldgen-seeds.md). No se aplana el bioma.
- Interfaz funcional inicial, español; faltan traducciones completas, revisión gráfica en distintas resoluciones y el árbol definitivo. Icono de yunque y logo de cabecera no se modificaron.

Pruebas adicionales:

```sh
python3 tools/play_everforge.py --test-stage mechanics --port 49179
python3 tools/play_everforge.py --client ForgeAlice --port 49179
# En otra terminal, para la etapa multijugador:
python3 tools/play_everforge.py --client ForgeBob --port 49179
# Crear y entrar directamente en una partida local nueva:
python3 tools/play_everforge.py --new --test-stage solo --name ForgeSolo
```
