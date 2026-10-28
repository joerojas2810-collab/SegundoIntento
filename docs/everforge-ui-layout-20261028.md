# Everforge: distribución, localización y navegación — 28 de octubre de 2026

## Cambios

- Hub `/everforge`: siete accesos repartidos en dos páginas, con cuatro filas como máximo. Cada fila tiene icono, título completo, descripción y botón ancho. Los subtítulos y el contador son etiquetas, sin scrollbars.
- Fabricación básica: se conservan las 13 fichas y la consulta de recetas registradas. Categorías arriba, lista a la izquierda y objeto seleccionado a la derecha. **Descripción** y **Receta** tienen paneles separados; la receta muestra materiales, cuadrícula, resultado, selector de material/color/madera y navegación entre alternativas. Solo el texto de una sección puede desplazarse cuando realmente excede su área. Los controles permanecen fuera de ella.
- Cuadrículas: fondos e iconos usan el mismo paso de 0,86 unidades y casillas de 0,74. Ya no se mezcla una cuadrícula compacta con los fondos de inventario de paso 1,25. Las cuadrículas 2×2 y 3×3 tienen cuatro y nueve casillas completas, respectivamente, y muestran las cantidades de ingredientes/resultados del registro.
- Diez tarjetas: texto con tamaño normal del cliente, icono dentro de la cabecera y navegación separada. Se acortaron las tarjetas extensas. La invitación final de bienvenida tiene área propia y no invade su botón.
- Tarjeta 1: enseña **Inventario (I) → pestaña Everforge → Guía de Everforge → Fabricación básica**, menciona materiales, hachas, picos, palas, espadas y antorchas y añade **Ver recetas básicas**. **Volver al tutorial** recupera la tarjeta original y permite continuar; no registra su finalización. La tarjeta 5 recuerda esa ruta y deja `/everforge` como alternativa.
- Inventario de supervivencia, añadido tras la indicación del usuario: tema grafito/cobre/marfil, pestañas dentro de la ventana, casillas e iconos de equipo con contraste. La pestaña Everforge separa progreso y habilidades. El nivel de cada disciplina se muestra de forma compacta y su XP exacta está en el tooltip. No se modifican la compra de habilidades, sus requisitos ni sus efectos.

## Causas de localización

El texto original de «Conoce tus herramientas» contiene `Settings > Change keys`. El código escapaba `>` antes de resolver la cadena traducible, convirtiéndolo en `&gt;` dentro de la clave de traducción. El cliente ya no encontraba la entrada española, aunque estaba presente en el PO. Ahora se resuelve primero el idioma del jugador y se aplica después `core.hypertext_escape()` y, finalmente, `core.formspec_escape()`.

También faltaban claves parametrizadas como `Recipe @1 of @2` y `Materials: @1`, y una cadena de instrucciones de palos. La auditoría anterior reconocía solo llamadas sin argumentos y sin espacios antes del cierre. La prueba nueva comprueba las claves exactas, incluidas llamadas parametrizadas, saltos de línea y los veinte textos/títulos de las diez tarjetas. Se actualizan el PO español y el POT.

Luanti incluye el valor del dropdown en otros envíos del mismo formulario. Se procesa como cambio de variante solo cuando su valor difiere del guardado; así no consume los botones de navegar o volver. Hay regresión específica para este caso.

## Dimensiones y compatibilidad

Se contrastó la [API oficial de Luanti 5.17.0](https://github.com/luanti-org/luanti/blob/5.17.0/doc/lua_api.md), especialmente coordenadas reales, `size`, etiquetas de área, hypertext, textarea, dropdown y tamaños relativos de fuente. No se fijan tamaños físicos ni se aumenta la ventana para resolver el desbordamiento: hub y tarjetas siguen en 12×7,5; fabricación, en 12×8,2; el inventario, en 11,75×10,9; progreso independiente, en 11,5×8. Se mantiene el ajuste del motor al tamaño de pantalla y se usan fuentes relativas donde es necesario.

El tema del inventario se aplica mediante una opción de presentación `mcl_inventory.survival_inventory_theme`. Conserva el constructor original como alternativa si no hay tema. No cambia `mcl_vars`, el prepend global, los índices de inventario, el ancho real de fabricación ni los handlers de sus acciones. Los archivos del logo oficial y los iconos originales se conservan.

## Pruebas automatizadas

Todas pasan:

| Prueba | Cobertura |
|---|---|
| `test_everforge_onboarding.py` | 14 pruebas de contenido, traducción, rutas y persistencia |
| `test_everforge_interfaces.py` | 5 regresiones de interfaces y actualización de máquinas |
| `test_everforge_crafting_registry.py` | 4 contrastes contra registros reales del código del juego |
| `test_translation_regression.py` | 3 regresiones de traducción y HUD |
| `test_everforge_help_translations.py` | 1 auditoría: 50 cadenas de controles y 22 de comandos |
| `test_everforge_crafting_guide.cjs` | 13 fichas, variantes y alternativas; 74 formularios, 1.798 elementos comprobados |
| `test_everforge_onboarding.cjs` | 34 formularios, navegación y retorno; límites y superposiciones |
| `test_everforge_inventory_guide.cjs` | Ruta nativa, tema y alternativa original; mismas listas, índices y campos de acciones; geometría de progreso |
| `check_everforge_ui.cjs` | Sintaxis Lua 5.1, interfaces de máquina y recetas de fundición sin cambios |

`check_formspec_layout.cjs` comprueba límites y cruces entre controles, texto, iconos y etiquetas de área; permite únicamente que el icono de un ingrediente esté contenido en su casilla y exige cuadrículas con 0, 4 o 9 casillas. Estos controles no pretenden medir los glifos de una fuente: se complementan con inspección gráfica.

## Validación gráfica real

Se ejecutó **Luanti 5.17.0 para macOS ARM64**, en un mundo de prueba aislado, con idioma español. Las capturas se obtuvieron de la aplicación nativa; no son maquetas HTML ni reconstrucciones de los formularios. Están en [la carpeta de evidencias](evidence/ui-layout-20261028/README.md). Los PNG incluyen la barra de título de macOS; las resoluciones indicadas corresponden al área del juego. Se documentan las distintas pasadas y la revisión final en 1024×720.

- **1280×800, GUI 1:** revisión de las diez tarjetas, ambas páginas del hub, ruta desde inventario, acceso directo a recetas y retorno a la primera tarjeta seguido de la segunda. Cuadrículas 2×2/3×3, materiales, cambio a cobre y paso de receta 1 a 2 del hacha comprobados en el motor.
- **1920×1080, GUI 1,25:** inventario, pestaña Everforge, hub, descripción y receta 3×3 revisados. Se comprobó el cierre al juego.
- **1024×720, GUI 1:** revisión del inventario, hub, tutorial y fabricación. Esta pasada detectó rótulos y datos que aún necesitaban compactación; se ajustaron y se repitió la comprobación final.

El lanzador de desarrollo acepta `--resolution ANCHO ALTO` y `--gui-scale FACTOR` para repetir la matriz. `--ui-preview` desactiva daño y aparición de enemigos únicamente en el mundo desechable de QA para que el combate no interrumpa la inspección. No modifica los ajustes del juego distribuido ni los mundos del usuario.

No se afirma haber probado todas las fuentes, pantallas o valores extremos de GUI posibles. Los textos descriptivos excepcionalmente largos pueden desplazarse dentro de su panel, sin mover los botones ni las cuadrículas. No se ejecutó una nueva prueba multijugador de mecánicas: esta entrega modifica presentación y navegación.

## Menú de Esc

Se conserva intacto. Es una interfaz local de confianza construida por el motor y no hay una API mantenible de mod de servidor para reemplazarla. El tema del inventario no lo altera. Se mantiene [la investigación y limitación de pausa](everforge-crafting-and-pause-menu.md#personalización-del-menú-de-pausa-en-luanti-5170), sin parches de binarios, CSM ni sustituciones de `builtin`.

## Alcance de Git

Se revisaron las tres ramas del repositorio SegundoIntento. Una rama auxiliar ya estaba integrada; la otra se fusionó conservando sus cambios y los del logo de `main`. Se eliminaron ambas después de comprobar su ascendencia. La entrega continúa en `main`, sin crear ramas auxiliares nuevas. La carpeta de Linde abierta al comenzar y sus modificaciones locales no se tocaron.
