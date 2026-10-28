# Diagnóstico: infotext duplicado y Tadamantine

Base investigada: PR #2, `28a73c847` (incluye refresco de formularios y ajustes
posteriores a `d47a1595f`). Se preservan esos cambios.

## 1. El texto a la izquierda

Cadena concreta:

1. `update_melter_interface` en Everforge escribía `meta.infotext` con el nombre
   y estado del fundidor.
2. [Luanti 5.17.0, game.cpp](https://github.com/luanti-org/luanti/blob/5.17.0/src/client/game.cpp#L2955)
   lee ese campo del nodo apuntado y lo pasa a `m_game_ui->setInfoText`.
3. [gameui.cpp](https://github.com/luanti-org/luanti/blob/5.17.0/src/client/gameui.cpp#L57)
   crea ese texto **a la izquierda, debajo del chat**, sin un identificador de HUD
   del servidor. El cliente lo oculta mientras hay un menú modal abierto.
4. WAILA es otro productor: dos HUDs de Everforge, centrados arriba. Mineclonia
   también tiene `mcl_info`, pero es un HUD de depuración en x=0.0073, y=0.889,
   con coordenadas/bioma, no el estado de la máquina.

Se elimina exclusivamente la publicación de `infotext` del fundidor Everforge.
Su mensaje completo se guarda en `everforge:machine_infotext`; WAILA lee ese
campo para este nodo, y el formulario sigue mostrando el estado. Otras máquinas
siguen leyendo/escribiendo su `infotext` original. No se altera chat, `mcl_info`,
ni ninguna bandera de HUD global. La LBM existente actualiza fundidores guardados
al cargar; los refrescos normales también eliminan el valor antiguo.

Con WAILA apagado, el estado del fundidor sigue disponible al abrir su formulario;
no se reactiva la etiqueta lateral. Se preserva la supresión temporal de WAILA
al abrir el fundidor que ya existía en `28a73c847`, y su restauración al cerrar.
La ubicación exacta del texto observado por el usuario se confirma visualmente
en el cliente; el productor de la etiqueta nativa queda demostrado en las fuentes.

## 2. Llamada real que genera la traducción inválida

El origen no era la unión de líneas WAILA:

- `mods/ITEMS/adamantine/init.lua:443`: `mcl_armor.register_set` recibía
  `description = S("Adamantine")`.
- `mods/ITEMS/mcl_armor/api.lua:234`: el camino de compatibilidad del campo
  obsoleto ejecuta `S(def.description .. " " .. element.description)`.
- La segunda traducción recibe una marca de dominio dentro de su **plantilla**,
  en lugar de dentro de un argumento `@1`.

Prueba ejecutada **antes de corregir**: se extrajeron del código real el sitio de
registro, `mcl_armor.elements`, `get_armor_texture` y `register_set`. Se ejecutaron
con Fengari y las funciones originales `translate`, `translate_n`, `get_translator`
de `builtin/common/misc_helpers.lua` de Luanti 5.17.0. Solo se sustituyeron las
APIs de registro de ítems/recetas por capturas y se instrumentó la entrada de
`core.translate` para registrar plantilla y pila. El traductor original sigue
siendo el que serializa. WAILA **no se carga** en esta prueba.

Captura real, abreviada:

```
OFFENDING_TEMPLATE "\27(T@adamantine)Adamantine\27E Helmet"
REAL CALL STACK
    mods/ITEMS/mcl_armor/api.lua:234: in field 'register_set'
    mods/ITEMS/adamantine/init.lua:443: in local 'register_site'
REGISTERED adamantine:helmet_adamantine
    "\27(T@adamantine)\27(Tadamantine)Adamantine\27E Helmet\27E"
RESULT bad_templates=4 armor_pieces=4 crafts=4
```

También se capturaron Chestplate, Leggings y Boots. El traductor consume el `@`
de la marca interior; la descripción registrada ya contiene `Tadamantine`.
[El parser real del cliente](https://github.com/luanti-org/luanti/blob/5.17.0/src/util/string.cpp#L730)
rechaza esa marca interior y emite el aviso indicado. No se ejecutó aquí ese
parser C++ ni un cliente completo: se verificó su rama de error en la fuente y
se capturó la entrada dañada producida por las funciones Lua originales.

Corrección: Adamantina usa `descriptions = {head=S("Adamantine Helmet"), ...}`,
la API actual de Mineclonia, con cuatro nombres completos y entradas españolas.
No se modifica `mcl_armor`. Resultado sobre la misma ruta real:

```
RESULT bad_templates=0 armor_pieces=4 crafts=4
```

Los cuatro registros de armadura y las cuatro recetas emitidas tienen firmas
idénticas antes/después al excluir únicamente `description`. Las constantes del
entorno (texturas/encantabilidad) son dobles comunes a ambas ejecuciones; esta
prueba verifica la ruta de registro, no sustituye un arranque del mod completo.

## Revisión de otras rutas

Se buscaron llamadas `S`, `FS`, traductores dinámicos, `translate`,
`get_translated_string` y usos de `description`/`infotext` en todo `mods/`, y se
siguieron los consumidores relacionados con Adamantina:

- Los tres Lua de Adamantina usan plantillas literales para menas, pepita,
  lingote, bloques, herramientas, puertas, barrotes y escalera. El campo obsoleto
  de armadura era la entrada que llegaba a la segunda traducción inválida.
- Everforge usa argumentos `@1`/`@2` para descripciones de componentes,
  herramientas, mineral, procesamiento y estado. La traducción por línea de
  WAILA se conserva; no se añade otra corrección defensiva a esa ruta.
- `mcl_stairs` compone nombres mediante argumentos, no reinterpretando una
  descripción traducida como plantilla. Los datos enviados a las puertas se
  conservan. `mcl_tools` no vuelve a traducir el nombre de estas herramientas.
- `doc` tiene un envoltorio `F` que traduce y escapa; sus llamadas son constantes
  de navegación. `doc_items` usa plantillas de drops con argumentos.
- `moreores` recibe nombres fuente planos de sus tablas y utiliza argumentos
  para sus nombres compuestos. No se cambia.
- Inventario creativo y guía consultan `get_translated_string` sobre descripciones
  registradas; pueden ser consumidores del nombre dañado de armadura incluso
  con WAILA apagado. Los ítems caídos también usan `def.description` como infotext.
- `tt` puede guardar una descripción generada en metadata del ItemStack; un
  objeto antiguo puede conservar el dato dañado aunque su definición nueva sea
  correcta. No se vacían metadatos ni se alteran nombres personalizados,
  encantamientos o contenedores por una migración indiscriminada.

## Instrumentación para el mundo real

`/everforge_ui_probe` (privilegio `server`) es una sonda explícita de solo lectura.
Registra en `debug.txt`/log del servidor:

- Estado WAILA y su supresión temporal; preferencia `mcl_info_show`.
- IDs/textos de HUDs del servidor. El infotext nativo no tiene ID en esa lista.
- Nodo apuntado, infotext nativo y estado privado del fundidor.
- Ubicación exacta y cadena escapada de campos con `Tadamantine`: definiciones
  registradas, inventarios del jugador (incluida armadura) y nodo apuntado, además
  de metadatos del nodo. Detecta también descripciones antiguas guardadas.

No llama a un traductor, no modifica inventarios, no oculta errores y no instala
wrappers globales. No examina otros jugadores ni cofres descargados. Si persiste
un aviso, ejecutar la sonda sobre el objeto/contenedor implicado permite separar
un dato antiguo de una llamada nueva; conservar el log antes de modificarlo.
La instrumentación del traductor solo existe en el proceso de pruebas temporal.

## Verificación y reproducción

Dependencias temporales: `luaparse` y `fengari-node-cli`.

```
npm install --prefix /tmp/everforge-qa luaparse fengari-node-cli
export NODE_PATH=/tmp/everforge-qa/node_modules
export PATH=/tmp/everforge-qa/node_modules/.bin:$PATH
curl --fail -L https://raw.githubusercontent.com/luanti-org/luanti/5.17.0/builtin/common/misc_helpers.lua -o /tmp/luanti-517-misc_helpers.lua
BASELINE_REF=28a73c847 node tools/test_adamantine_translation.cjs /tmp/luanti-517-misc_helpers.lua
node tools/test_adamantine_translation.cjs /tmp/luanti-517-misc_helpers.lua
node tools/test_everforge_hud_provenance.cjs
node tools/check_everforge_ui.cjs
python3 tools/test_everforge_interfaces.py
python3 tools/test_translation_regression.py
```

La prueba verifica el SHA-256 del archivo oficial:
`d83916589500178cce8ccf1f1012861d421b9f94f0b675ecbc2f3460af9019e3`.
La regresión anterior en Python se mantiene como modelo complementario; **no es
la evidencia de atribución de esta investigación**.

Automático: traza antes/después de las llamadas reales, sintaxis Lua 5.1,
conservación de registros/recetas de armadura, 58 límites de elementos de UI,
cinco regresiones de interfaces previas, tres del modelo previo y ejecución de
los productores reales de metadata/WAILA. La sonda fue probada con datos antiguos
y WAILA apagado, prohibiendo escrituras y llamadas de traducción en sus dobles.

Pendiente en Luanti 5.17.0 / Mineclonia 0.124.1: reiniciar y comprobar arranque,
activar/desactivar WAILA, abrir/cerrar el fundidor, todos sus estados y otro horno,
verificar que la etiqueta lateral desaparece y el WAILA principal se restaura.
Revisar nombres españoles/ingleses de las cuatro piezas en creativo, armadura,
suelo y guía; probar objetos nuevos y guardados. Si hay un aviso residual, capturar
la sonda apuntando al contenedor implicado y con el objeto en inventario. No se
asegura que el mundo existente carezca de strings antiguos sin esa prueba real.
