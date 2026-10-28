# Everforge: primera iteración jugable

Estado: desarrollo inicial; sin migraciones de personajes. Mineclonia del repositorio (0.124.1), Luanti **5.17.0**. Esta entrega sustituye el bloqueo por fases del plan maestro por implementación y pruebas en mundos desechables.

## Abrir y jugar

En macOS, ejecutar `Iniciar-Everforge.command`. `Nuevo-Mundo-Everforge.command` crea otro mundo sin eliminar el anterior. Los datos están aislados en `.everforge-dev/`; no se usan los mundos normales de Luanti. Por defecto se reconoce el ejecutable de Luanti en Descargas o en PATH.

Instalación limpia reproducible en macOS ARM64 (Python 3, sin paquetes adicionales):

```sh
python3 tools/play_everforge.py --install --new
```

El instalador descarga el ZIP oficial de Luanti 5.17.0 y verifica SHA256 `0ba118b537d3cc6fd07cd2268fef25e515fc6d87c27ad69b476144a8e28dba3c` antes de extraerlo en `.everforge-dev/runtime/`. `--archive /ruta/al/zip` reutiliza una descarga con la misma verificación. En otras plataformas usar `--luanti /ruta/al/ejecutable`; la instalación automática de esas plataformas queda pendiente. El launcher requiere la versión objetivo y enlaza este checkout como juego, sin instalar mods externos.

```sh
python3 tools/play_everforge.py --new --name Forjador
python3 tools/play_everforge.py --server --port 49177
```

El segundo comando sirve el mundo en `127.0.0.1:49177`. Dos clientes locales con nombres distintos pueden conectarse desde «Unirse». La exposición a una LAN no está habilitada por defecto.

Al crear un mundo se prepara terreno singlenode de Mineclonia, con seed 12345 para reproducibilidad; la primera carga tarda más que un reinicio. El campamento tiene un pequeño sendero de piedra, mesa de trabajo y horno nativos; no incluye equipo, recompensas, edificios nuevos ni NPC. Minar y fabricar sigue el survival normal. Abrir `/everforge` para consultar progreso y comprar habilidades. La pestaña Everforge ofrece la misma información.

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

La región usa un manifiesto mundial `start_region:v1`, radio de llegada 6 nodos, ancla del spawn procedural. Se coloca una vez en un mundo nuevo y no se restaura al cargarlo. Camas/anclas mantienen su selección y validación nativas; solo el fallback mundial y jugadores nuevos usan el proveedor compartido. Las alternativas seguras se buscan dentro de la misma región, leyendo nodos actuales. Si no existe llegada segura, se registra el error administrativo y se rechaza la llegada con explicación; no se rompen construcciones ni se envía al jugador fuera de la región. El intento se vuelve a resolver al reconectar.

Un reinicio con creación incompleta deja `needs_review`: revisar o crear otro mundo de desarrollo. Nunca se repone automáticamente la plantilla. No hay transacción conjunta entre mapa, jugador y mod storage; estos tests comprueban reinicio limpio, no durabilidad ante cualquier corte eléctrico. Mundos previos sin manifiesto no reciben una región por defecto. `everforge_start_region=false` permite comparar con spawn nativo.

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

Solo los mundos de integración cargan el mod de pruebas. Ese mod prepara perfiles/objetos desechables, comprueba aserciones y apaga el servidor. No usar esos nombres ni fixtures como una partida de juego normal. El launcher retira el enlace al mod de pruebas al abrir normalmente el mundo. Cada etapa informa `EVERFORGE_TEST_PASS` o falla con error; el límite de ejecución es 180 segundos.

Evidencia de la ejecución y límites concretos: `docs/everforge-runtime-results.md`.

## Límites de esta iteración

- Balance y protección contra farming son provisionales: deduplicación reciente por posición minada y límite de 0,5 s por actividad no impiden todas las granjas. Minar nodos colocados puede dar XP fuera de la ventana reciente; los IDs no son un historial infinito.
- Forja acredita al último proveedor manual del input, conectado y cercano; no recompensa automatización, suministro anónimo ni jugadores desconectados. Mezclar proveedores en un mismo lote no reparte crédito.
- Una fabricación múltiple dentro de 0,5 s se limita a una concesión; no hay recompensa por unidades de output ni craft predictivo. Combate exige daño atribuible al jugador; bajas ambientales sin esa fuente no cuentan.
- El prototipo está probado con singlenode/seed 12345. No hay garantía para todos los seeds/mapgens; si el centro no tiene suelo seco, se informa y se pide otro mundo de desarrollo. No se aplana el bioma.
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
