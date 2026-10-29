# Everforge: semillas libres y región inicial segura

Revisión del 29/10/2026 sobre `main`. Se conservan **Luanti 5.17.0, Mineclonia 0.124.1 y `singlenode`**. La apariencia visual sigue siendo una sola.

## Semillas

No hay una condición para `12345` en el campamento, la región o las decoraciones. Era una constante de `tools/play_everforge.py`; ahora esa herramienta acepta `--seed NUMERO_O_TEXTO` y, si se omite, deja que el motor elija una semilla aleatoria. No convierte semillas de 64 bits a números Lua/Python de coma flotante. Las semillas negativas y textuales se normalizan por el motor; el valor efectivo se registra en la evidencia. Las aleatorias A/B se muestrearon una vez con `secrets.randbits(63)` y se fijaron para repetirlas; el caso sin semilla deja una elección nueva al motor.

En el menú normal se puede dejar la semilla vacía o introducir cualquier semilla válida. `12345` solo sirve para reproducir la referencia; no se sustituye `singlenode` por `v7`.

## Cambios de generación

- **Huella completa antes de construir.** `camp_site.lua` examina el recinto de 12×16 columnas, el volumen libre hasta 10 bloques por encima y los apoyos por debajo de la capa que sustituirá el suelo del campamento. Exige terreno natural seco, desnivel máximo de 3 nodos y apoyo real dentro de los 3 nodos bajo cada cimentación. Se rechazan agua, hielo, lava, nieve en polvo, barrancos, techos finos sobre cuevas, metadatos, protección y piezas de estructuras nativas. Hojas, troncos y plantas se atraviesan al buscar suelo, sin confundirlos con él.
- **Construcción acotada.** Se eliminan los pilares de hasta 16 bloques. Bancos y faroles también reciben apoyo. El preflight ocurre antes de la primera escritura y los constructores nativos se ejecutan en orden estable. La forma del campamento se conserva; los nuevos campamentos registran revisión 3. Los campamentos ya guardados conservan su revisión y sus bloques.
- **Búsqueda determinista.** Anillos ordenados cada 4 nodos, radios 4/12/28/60, como máximo 961 candidatos por ancla. Primero se prepara solo el área necesaria para la huella cercana; la zona se amplía si no alcanza. Si el ancla configurada resulta oceánica o se agota, puede probarse una sola vez el ancla terrestre que calcula Mineclonia para **esa misma semilla**, con un máximo total de 1922 candidatos. No se cambia la semilla ni se fabrica suelo sobre el océano.
- **Lecturas fiables.** Se vuelven a cargar las columnas y el recinto antes de usarlos. `ignore` no se guarda como un rechazo permanente: se resuelve el mismo candidato mediante emergencia, con dos intentos como máximo, antes de considerar el siguiente. Si sigue sin estar disponible, se detiene con un error claro. Esto evita que presión de memoria o descarga de bloques cambien el resultado de la búsqueda.
- **Finalización nativa real.** El callback de `generate_area` admite estados `LOCKED_GENERATED`. Se espera además que `is_generated` confirme todos los bloques desbloqueados, antes de cada lote de candidatos, dentro del mismo presupuesto de 180 segundos. No se rechaza una ubicación por una protección temporal ni se leen escrituras nativas pendientes.
- **Llegada conectada.** Se busca una ruta de posiciones secas, con espacio para el jugador y sin protección, desde el interior del campamento. Se prefiere el patio a 7 nodos del centro. La búsqueda queda dentro del radio 10 y visita como máximo 441 columnas. No se escogen copas, techos altos ni salientes desconectados. Mientras se construye hay una espera por conexión; desconectar y volver a entrar no reutiliza una espera antigua.
- **Presupuesto y fallos.** La creación dispone de 180 segundos desde que terminan de cargar los mods, comprobados también antes de cada lote y de colocar el campamento. Los registros `REGION_SEARCH`, `REGION_LOAD`, `REGION_RELOCATE`, `REGION_READY` y `REGION_FAILED` incluyen semilla, candidatos, causas y tiempo. Un fallo o interrupción queda en `needs_review`: no hay reintentos ni reconstrucción automática al cargar.

### Preparación nativa de fortalezas en macOS

Las pruebas detectaron una demora de varios minutos antes del primer paso del servidor, durante la preparación de fortalezas; también ocurrió con `12345`. Interpretar solo el bucle exterior no bastó, y desactivar JIT para toda esa fase introdujo una regresión de rendimiento. Un monitor temporal por sí solo tampoco bastó: su traza de fallo identificó la búsqueda recursiva `rtree_index_1` en `biomes.lua`.

En Luanti 5.17.0/macOS ARM64 se aplica `jit.off` a esa función **solo en el coordinador**. Se conserva el código de búsqueda, su orden, comparaciones y RNG. Los trabajadores de generación conservan JIT. Las pruebas ejecutan el recorrido real, comprueban el orden de los empates y que los trabajadores no reciben esta desactivación. También se comparan hashes de caché nativa de fortalezas y de muestras del terreno.

`worldgen_compat.lua` mantiene además un monitor temporal durante la preparación nativa, con diagnóstico y traza al superar 90 segundos. El primer límite experimental de 30 segundos era demasiado corto bajo carga de QA. El monitor se retira al terminar, también ante error; un hook de depuración ya existente se conserva. No sustituye el algoritmo, las posiciones ni la caché de fortalezas. Es una mitigación comprobada en el entorno indicado, no una reparación del compilador LuaJIT ni una garantía de interrupción de código C bloqueado.

### Estalactitas y estalagmitas en ARM

La semilla aleatoria efectiva `5022212097447892020` produjo un error nativo en `get_block` desde `generate_large_dripstone`. Se aplica `jit.off` únicamente a ese bucle en ARM, siguiendo la mitigación que Mineclonia ya usa en su generador antiguo de estalactitas. El [problema de LuaJIT en ARM está documentado en Luanti](https://github.com/luanti-org/luanti/issues/15983). No se omite la formación ni se cambia su geometría/RNG; no se toca terreno ya guardado. La misma semilla se conserva como regresión y se vuelve a crear y reiniciar. La suite ejecuta el bucle real en ambos sentidos y comprueba que la mitigación apunta a esa función.

## Mundos existentes

La creación se ejecuta solo si no hay manifiesto y el mundo es nuevo. Un mundo anterior sin manifiesto no recibe campamento. Un manifiesto listo no entra en la búsqueda ni en la construcción; un manifiesto inválido se conserva y se registra el problema. Un manifiesto interrumpido no se reanuda automáticamente.

Se mantienen `start_region:v1`, IDs de nodos, inventarios y perfiles. No se añade una migración de terreno. Las decoraciones siguen en el pipeline `mcl_levelgen`, sin ABM/LBM ni recorrido retroactivo. La simulación nativa puede mover agua, retirar plantas o cambiar hojas; eso no es regeneración del terreno. No se considera una prueba de determinismo comparar una captura de la simulación tomada tras tiempos distintos.

No existe una transacción única entre mapa y mod storage frente a un corte eléctrico. Se evita reconstruir silenciosamente una creación interrumpida. Las pruebas de reinicio limpio no certifican cualquier corrupción histórica o combinación de mods externos.

## Ensayos reales y evidencia

<!-- SEED_RESULTS -->

Configuración real: Luanti 5.17.0 oficial macOS ARM64, LuaJIT 2.1.1764270282, Mineclonia 0.124.1, `singlenode`, `mcl_levelgen_use_ffi=false` (valor nativo predeterminado), dos hilos de emergencia. No se ha probado FFI activado ni otras arquitecturas.

Los ensayos se ejecutan sin cliente gráfico, en mundos desechables y sin abrir mundos personales. Las duraciones son medidas del entorno local, con hasta dos procesos de QA en paralelo; no son un benchmark de carga de la instalación del usuario. Los avisos nativos de lag y `StaticObjectList` se conservan en los logs.

### Determinismo comprobado

- Posición del campamento, llegada y hash de todos los nodos finales del plano, incluidos sus `param2`.
- Hash de 169 muestras de los heightmaps originales y biomas guardados, que no depende del estado de agua/plantas de una sesión posterior.
- Reinicio de cada mundo: mismos nodos del campamento, marcador de construcción y metadatos conservados; mismo hash original de terreno.
- Mundos gemelos con la misma semilla/configuración, incluidos los casos difíciles de montaña y océano.
- Hash de la caché nativa de posiciones de fortalezas antes/después de la compatibilidad de arranque.

No se comparó byte por byte todo el subsuelo de los mundos. Tampoco se promete una decoración en cada chunk: Plains y otros biomas no seleccionados pueden tener cero. Se verifican las listas reales de biomas y filtros en las pruebas ejecutables, y se registran los tipos decorativos encontrados por el motor en varias semillas.

### Fallos encontrados y correcciones

1. Ancla en océano (`12345`, X/Z `0,-1`): 961 candidatos con agua, sin campamento. Corregido con una única reubicación al ancla terrestre de la misma semilla; nunca se sustituye la semilla.
2. Repetición de montaña: bloques descargados devueltos como `ignore` cambiaban los rechazos y podían agotar la búsqueda. Corregido recargando cada columna y resolviendo el mismo candidato antes de continuar.
3. Demora de fortalezas: afectó tanto a la semilla textual como a `12345` y `-1`. La mitigación mantiene el código nativo y interpreta la búsqueda recursiva del coordinador y conserva el monitor de límite descrito arriba. Los ensayos de alternativas descartadas se conservan como fallos, no se cuentan como aprobados.
4. Preflight anterior: mirar una sola columna y rellenar hasta 16 bloques podía ocultar pendientes, agua o apoyos inadecuados. La nueva suite cubre todos los puntos de la huella, cuevas bajo capas finas, nieve, estructuras y fallos antes de escribir.
5. Preparar toda la zona inicial de una vez podía agotar 180 segundos antes de examinar candidatos, como ocurrió con `10643281652235288712` bajo carga de QA. Se redujo el área inicial y se amplía por etapas. La misma semilla pasó después en un ensayo aislado; las medidas no se presentan como un benchmark comparable.
6. La semilla aleatoria `5022212097447892020` falló al generar estalactitas con LuaJIT/ARM. La mitigación específica se describe arriba; la semilla no se retiró de la matriz.
7. La comparación gemela detectó que una protección temporal `LOCKED_GENERATED` podía mover el campamento de `12345` de Z=26 a Z=34. Se corrige esperando el desbloqueo nativo antes de seleccionar, sin ignorar protecciones reales.
8. El arnés ahora considera un error Lua como fallo aunque Fengari devuelva código de salida 0, y conserva el ancla estática tanto al crear como al reiniciar los mundos de estrés.

### Repetir las pruebas

```sh
npm install --prefix /tmp/everforge-validation luaparse fengari-node-cli
export NODE_PATH=/tmp/everforge-validation/node_modules
export PATH=/tmp/everforge-validation/node_modules/.bin:$PATH
node tools/test_everforge_worldgen.cjs
node tools/test_everforge_world_visuals.cjs
python3 tools/test_everforge_seeds.py \
  --output /tmp/everforge-seed-matrix-new \
  --cases docs/evidence/worldgen-seeds/matrix/cases.json
```

El directorio de salida debe estar vacío. El ejecutor no borra evidencia anterior, usa puertos locales distintos y apaga sus propios procesos al agotar el límite de ejecución. `seedtest`/`seedrestart` se instalan únicamente como worldmod de QA. Las etapas de inspección/anclas no son instrucciones de inicio para jugar.

## Validación gráfica pendiente

**No se declara visualmente validado.** Pendiente en Luanti con cliente:

- Crear mundos con semilla libre y aleatoria; comprobar la llegada de un jugador real y el tiempo de carga y ausencia de espera indefinida al entrar, desconectar y reconectar durante la preparación.
- Fotografiar suelo, cimentaciones, bancos, faroles, entrada y patio: ningún apoyo al aire, campamento enterrado, copa como suelo ni colisión con estructuras.
- Caminar del punto de llegada a fogata, mesa y horno; revisar pendientes, agua, nieve y montañas cercanas.
- Revisar arbustos y piedras en bosque, taiga y costa/montaña generados después de actualizar. Confirmar densidad y aspecto; cero en una zona no elegible no es un error de semilla.
- Abrir una copia de un mundo existente y comprobar construcciones, inventarios, posiciones y campamento; las texturas pueden actualizarse, el terreno guardado no se reconstruye.

La cantidad finita de semillas ensayadas no certifica las 2^64 posibilidades ni perfiles especiales sin terreno seco. Si se agota la búsqueda, se conserva el diagnóstico para corregir ese caso, sin recomendar usar siempre `12345`.
