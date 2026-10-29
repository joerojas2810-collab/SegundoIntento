# Validación técnica de la apariencia única de Everforge — 29/10/2026

Base integrada: rama remota `arena/77e5e496-segundointento`, commit `041600f46`, sobre `c2571110b`. Trabajo consolidado en `main`, sin crear otra rama ni alternativas visuales.

## Correcciones

- La etapa superficial de las tablas reales de Mineclonia es la **11**, no la 12. El índice anterior producía listas vacías sin colocar decoraciones.
- Piedras de bosque: se admite `mcl_core:dirt_with_grass`; se corrige la textura a `default_stone.png`, existente en el juego.
- Colocación sobre el heightmap original `motion_blocking_wg`, con lista explícita de apoyos naturales y un volumen de aire libre de 3×2×3. Se rechazan hojas, troncos, nieve, líquidos, bloques construidos y espacio ocupado. `simple_block` escribe mediante `mcl_levelgen.set_block`, que respeta las máscaras de estructuras del generador. No se invocan APIs de escritura directa al mundo desde el mod.
- Se retira la ruta Core de decoraciones clásicas, que no compartía esos filtros. No cambia la configuración de mundos clásicos; los nodos/texturas siguen disponibles al cargarlos.
- Arbustos y piedras: sin selección, minería, colisión, drops ni recetas; reemplazables y desplazables por líquido. Las hojas conservan IDs, grupos, paletas, callbacks, drops y cajas completas de colisión/selección.
- No hay LBM/ABM, callback de carga o migración que añada decoraciones a bloques guardados. Las texturas y geometría visual sí se actualizan en hojas/suelos existentes. Las decoraciones nuevas requieren generación pendiente/nueva; no se debe forzar regeneración en un mundo habitado.

## Pruebas automatizadas

Comandos desde la raíz del repositorio (Node, Python 3 y dependencias de QA en una carpeta temporal):

```sh
npm install --prefix /tmp/everforge-validation luaparse fengari-node-cli
export NODE_PATH=/tmp/everforge-validation/node_modules
export PATH=/tmp/everforge-validation/node_modules/.bin:$PATH
for test in tools/test_everforge_*.cjs; do node "$test" || exit 1; done
for test in tools/test_everforge_*.py tools/test_translation_regression.py; do python3 "$test" || exit 1; done
git diff --check
```

Pasaron los cinco tests estáticos de assets/licencias/registro y **124 comprobaciones ejecutables** sobre las tablas reales de biomas, la función nativa `generate_feature`, los filtros de ocupación y la conservación de propiedades. Se comprueba registro en 11 biomas de arbustos, 10 de piedras de bosque y 5 de montaña, y ausencia en biomas excluidos. Pasaron también las suites existentes de inventario, guía, HUD, onboarding, recetas e idiomas, la sintaxis Lua 5.1 y las referencias de texturas pétreas. Estas pruebas no equivalen a un cliente gráfico.

## Prueba de motor aislada

Luanti **5.17.0**, Mineclonia **0.124.1**, macOS ARM64, `singlenode`, semilla `12345`, `mcl_levelgen_use_ffi=false`, servidor local sin ventana. No se abrieron mundos personales.

```sh
python3 tools/play_everforge.py --data-dir /tmp/everforge-world-visuals-release --new --test-stage bootstrap --port 49281
python3 tools/play_everforge.py --data-dir /tmp/everforge-world-visuals-release --test-stage restart --port 49281
```

Resultado final: **2 arbustos y 2 conjuntos de piedras de bosque** generados en la zona inspeccionada, centrada en `(-256, -257)` (X/Z Luanti), radio horizontal 64. Al reiniciar se conservan exactamente sus posiciones y tipos; también el campamento, dos bloques de construcción de prueba y sus metadatos. No hubo errores Lua en las tres ejecuciones finales. Las variantes pétreas de montaña y la pertenencia a todos los biomas se comprobaron con la prueba ejecutable; no se hizo una inspección gráfica ni un muestreo runtime exhaustivo de cada bioma.

Evidencias completas: [bootstrap](evidence/world-visuals/bootstrap.log), [reinicio](evidence/world-visuals/restart.log), [mundo anterior](evidence/world-visuals/legacy.log). La generación registró avisos del motor sobre pico de lag y `StaticObjectList`/desactivación de entidades, conservados en la evidencia; estas pruebas no certifican rendimiento ni ausencia de avisos nativos. La ejecución de reinicio y la carga legacy terminaron correctamente.

La prueba genera primero el campamento y después localiza un bioma elegible y genera un área adicional. Comprueba nodos decorativos reales, apoyos y posiciones persistidas al reiniciar. El buscador usa coordenadas Minecraft: el test convierte `z` a `-z-1` antes de generar en coordenadas Luanti. Un ensayo inicial sin esta conversión buscaba la zona opuesta y falló; no se contó como aprobado.

Para la prueba `legacy` se usa exclusivamente una **fixture desechable** de bootstrap anterior a incorporar `everforge_world_visuals`, con marcadores y metadatos de construcción guardados. No ejecutar esta etapa sobre mundos personales:

```sh
python3 tools/play_everforge.py --data-dir /tmp/everforge-scenery-qa --test-stage legacy --port 49282
```

Resultado legacy: carga correcta, campamento original conservado, modificaciones de jugador y metadatos conservados; sin decoraciones nuevas en el área previamente guardada. No prueba todas las versiones o combinaciones históricas de mods.

## Validación gráfica pendiente — obligatoria

**La apariencia no está visualmente validada.** La prueba sin ventana no comprueba calidad estética, transparencias, caras cruzadas, tintes, parpadeo, suavidad de animación ni rendimiento del cliente.

En el Mac, después de actualizar y reiniciar Luanti:

1. Abrir una copia de un mundo existente: construcciones e inventarios intactos, hojas con sus nuevas texturas y ausencia de decoraciones retroactivas.
2. Abrir un mundo temporal `singlenode`, semilla `12345`; revisar el campamento, entrada, fogata, mesa, horno y acceso sin obstáculos.
3. Capturar bosque, taiga, pradera elegible y montaña/costa rocosa en terreno nuevo. Revisar arbustos y piedras al nivel del suelo, sin agua, copas ni estructuras debajo. No se prometen decoraciones en todos los chunks: la densidad y los filtros son deliberadamente restrictivos.
4. Comparar cerca/lejos y día/noche: formas de árboles, volumen de follaje, repetición de rocas, texturas, tintes y coherencia de la única apariencia elegida.
5. Verificar caminar, apuntar/minar el bloque detrás de una decoración, construir sobre ella, líquidos y acceso al campamento; reiniciar y volver a la misma zona.
6. Anotar resolución, distancia de visión, opciones de hojas, FPS/frametime y tiempo de carga en bosque denso; probar también cliente multijugador actualizado.

Enviar capturas reales de estos puntos antes de decidir si esta mejora basta o se continúa trabajando árboles, follaje, rocas y texturas. No hay capturas simuladas ni certificación de FPS.
