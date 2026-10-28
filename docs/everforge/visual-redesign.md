# Everforge: identidad de interfaces

## Inspección y propuesta

Inspección sobre PR #2, commit e442c9a69. El logo oficial ya estaba instalado en
`menu/header.png`: SHA-256 b7828a191f862ff9c0090b8319b993f14ab3f4314d8a60fb5b109d4e3e72da47,
idéntico al archivo original adjunto. Se conserva sin modificaciones.

Dirección: paneles de hierro #17191C, cavidades #111214, cobre #C27A4A,
encabezados #E8B17D y texto marfil #F2E8D9. Textura discreta, bordes finos,
remaches y botones con estados normal, resaltado y pulsado. La tipografía
continúa siendo la del cliente para conservar legibilidad, idiomas y escala.

Problemas encontrados: texto heredado de Mineclonia demasiado oscuro sobre
paneles oscuros; salida del fundidor contra el límite derecho; alijo de 7 unidades
de alto con inventario hasta 8.2 y solapamiento entre ambas listas.

## Implementación

- **Menú principal:** se conserva el original `menu/header.png`, mediante el
  mecanismo de imágenes del juego seleccionado. No se modifica el motor.
- **RPG y pestaña propia:** tema local, encabezados con más espacio, filas
  separadas del encabezado, botones coherentes y clase elegida resaltada.
  Se mantienen los identificadores, tooltips, acciones y traducciones existentes.
- **Fundidor:** tema, texto claro y casillas oscuras; salida desplazada medio
  espacio hacia la izquierda para reservar margen. Misma entrada, combustible,
  salida, índices y listrings. Se conservan fuego/flecha y sus porcentajes.
- **Guía de minerales:** texto marfil, fondo de hierro y acento de cobre en el
  contenido de esta categoría. Se conservan galería, desplazamiento y navegación.
- **Alijo de mazmorra:** panel ampliado y listas separadas, manteniendo las 16
  casillas del alijo y la misma lista de 8×3 del jugador. No cambia su contenido,
  permisos ni inicialización. La LBM existente actualiza el formulario al cargar.
- **WAILA:** panel de hierro y borde de cobre fino. La textura pasa de 16 a 256
  píxeles; la escala compensa exactamente el cambio y conserva las dimensiones
  visibles redondeadas a múltiplos de 16. Posición, anclaje, texto, fuente,
  intervalo, traducción y desplazamiento por barras de jefe se conservan.

Recursos nuevos: `everforge_ui_panel.png`, `everforge_ui_slot.png` y tres
estados `everforge_ui_button*.png`. Se reemplaza `everforge_waila_panel.png`.
Son texturas geométricas propias, sin IA, reproducibles con
`tools/generate_everforge_ui.py` (Pillow); misma licencia GPL-3.0-or-later.
El generador no accede al logo.

## Alcance y límites

No se cambian globals de Mineclonia, sus archivos, progresión, recetas,
combustible, tiempos, mundo, NPC ni callbacks funcionales. El inventario general,
pestañas nativas y marco de navegación de la enciclopedia se mantienen para
conservar su integración. El tema se aplica solamente al contenido Everforge.
Las casillas nativas de la pestaña de inventario conservan su textura original.

El mecanismo del menú permite imágenes por juego, pero no rediseñar los botones,
la distribución ni la fuente del menú del motor desde un mod. Los formspecs y HUD
usan la fuente configurada por el cliente; no se impone una fuente decorativa.
Se usan APIs existentes en [Luanti 5.17.0](https://github.com/luanti-org/luanti/blob/5.17.0/doc/lua_api.md)
y los constructores de inventario/documentación de esta copia de Mineclonia.

## Verificación realizada y pendiente

- Sintaxis Lua 5.1 validada con luaparse.
- Constructores ejecutados con Fengari y dobles mínimos de las APIs: RPG,
  pestaña, alijo y fundidor vacío, material no admitido, trabajando y salida llena.
- 57 elementos con dimensiones explícitas dentro del panel, respetando el paso
  real de casilla de 1.25. Conservación del tamaño visible de WAILA comprobada.
- Comparación estructural del Lua contra e442c9a69: todos los elementos ajenos
  a presentación coinciden. La comparación excluye únicamente los constructores
  visuales, tema, escala visual y asignaciones de formspec.
- Logo original idéntico por SHA-256; `git diff --check` sin errores.

Para repetir la comprobación sin instalar dependencias en el juego:

```
npm install --prefix /tmp/everforge-qa luaparse fengari-node-cli
NODE_PATH=/tmp/everforge-qa/node_modules PATH=/tmp/everforge-qa/node_modules/.bin:$PATH node tools/check_everforge_ui.cjs
```

**No se ejecutó Luanti:** estas comprobaciones no equivalen a capturas reales ni
certifican el ancho del texto traducido. Queda pendiente abrir Luanti 5.17.0 con
Mineclonia 0.124.1, en español e inglés, a 1280×720 y 1920×1080 y dos escalas de
GUI; revisar logo completo, textos, tooltips, filas y selección RPG, todos los
estados del fundidor, guía con scroll, alijo existente y WAILA con barras de jefe.
Comprobar arrastre de objetos y navegación. PR #2 debe permanecer abierto contra
main, sin fusionar.
