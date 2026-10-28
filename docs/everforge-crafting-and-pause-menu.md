# Everforge: guía de fabricación y límites del menú de pausa

## Fabricación básica y recetario general

`/everforge` ofrece una guía breve para troncos, tablones, palos, mesa de fabricación, herramientas/armas y objetos iniciales de supervivencia. También se puede abrir desde el botón **Ayuda** del inventario de supervivencia y desde la pestaña Everforge del inventario.

La guía no registra recetas nuevas. Consulta `core.get_all_craft_recipes()` en el momento de mostrar cada ficha y representa únicamente recetas normales que Mineclonia tiene registradas en ese mundo. Por ello recoge recetas alternativas y variaciones de materiales existentes, y muestra un aviso si un objeto o variante no tiene una receta de cuadrícula registrada. Las cuadrículas e iconos se generan con los ingredientes/objetos registrados y los recursos visuales ya instalados. Los troncos se explican como material recogido del mundo, no como objeto fabricable.

El recetario completo sigue siendo `mcl_craftguide`; desde la guía básica el botón **Abrir el recetario general** llama a su API existente. El acceso Everforge anterior no fallaba por un nombre o una ruta distintos: llamaba a la misma función que el botón nativo. La causa de la vista vacía para un jugador nuevo es el filtro progresivo de `mcl_craftguide`, activado por defecto en Mineclonia 0.124.1. Mientras el jugador no haya tenido ciertos ingredientes en su inventario, el catálogo puede decir «Recoge objetos para revelar más recetas» y no listar recetas. La guía nueva presenta solo recetas iniciales seleccionadas sin quitar ese filtro, desbloquear entradas ni escribir progreso de jugadores.

Las recetas de las fichas se basan en el registro de Mineclonia; no se copió una tabla de Minecraft ni se promete paridad con una edición concreta. Los grupos de materiales compatibles y las condiciones de descanso/reaparición de las camas dependen de las definiciones y ajustes del servidor. Por ejemplo, los datos de camas de Mineclonia consultan `enable_bed_respawn` y `enable_bed_night_skip`; la guía evita afirmar que estén activos y describe la dependencia.

El código fuente usado para contrastar recetas está en `mods/ITEMS/mcl_core/crafting.lua`, `mcl_trees/api.lua`, `mcl_crafting_table/init.lua`, `mcl_tools/init.lua` y `mcl_tools/register.lua`, `mcl_farming/hoes.lua`, `mcl_torches/register.lua`, `mcl_furnaces/init.lua`, `mcl_chests/init.lua` y `mcl_beds/beds.lua` / `mcl_beds/api.lua`. La interfaz sigue consultando el registro del juego para no quedar desfasada si la configuración del mundo añade o retira una receta.

## Personalización del menú de pausa en Luanti 5.17.0

No se implementó ningún cambio al menú nativo. La paleta grafito/cobre/marfil y el nombre/logo Everforge se mantienen en los formularios del mod, donde sí se pueden diseñar con formspecs y recursos de Mineclonia/Everforge.

La inspección del código fuente Luanti 5.17.0 encontró estos límites:

- `src/client/game_formspec.cpp`, en `GameFormSpec::showPauseMenuFormSpec`, construye/abre el formulario como interfaz local de confianza y pasa una cadena de prepend vacía; el propio comentario indica que se ignora el formspec prepend. Por eso `player:set_formspec_prepend()` no puede estilizar ni añadir el logo de Everforge a esa pantalla.
- El formulario principal de pausa se arma en C++ en `GameFormSpec::showPauseMenu()`: incluye Continuar, contraseña cuando corresponde, Ajustes, volumen/salida y datos del servidor. El nombre del proyecto proviene de una constante de compilación del cliente, no de la definición del mundo o de un mod.
- `src/script/scripting_pause_menu.cpp` inicializa un entorno aislado y `PauseMenuScripting::loadBuiltin()` carga el `builtin/init.lua` del cliente. El servidor y los mods del mundo no reciben una API para reemplazar sus controles o su formulario.

Por lo tanto, un mod del servidor no dispone de una API oficial compatible para cambiar esos colores, mostrar una marca por mundo o reemplazar los botones. No se creó un menú falso ni se interceptaron Escape, ajustes, salida, contraseña o estado multijugador.

### Alternativas y consecuencias

1. **Opción adoptada:** conservar el menú nativo sin cambios y usar el estilo/logo existente únicamente en pantallas propias de Everforge. No exige descargas ni altera mundos o personajes.
2. **Tema o paquete de recursos local del cliente:** solo sería una preferencia del usuario, no una identidad garantizada para la partida; requeriría instalación/configuración por cada participante, podría afectar otras interfaces y no se asume compatible con todas las versiones.
3. **Parche o bifurcación del motor:** requeriría modificar y reconstruir Luanti para cada plataforma, mantener el parche frente a futuras versiones y distribuir esos clientes a los usuarios. El servidor no puede obligar a los clientes multijugador a usar esa interfaz. Esta solución afecta a la distribución y compatibilidad del cliente, así que no se realizó.

No se intentaron hacks de client-side mods, sobrescrituras de `builtin` ni edición binaria: son mecanismos frágiles o del lado del cliente y no ofrecen la personalización por mundo, mantenible y compatible que se pidió.

## Verificación y pendiente

Las pruebas automatizadas ejercitan los formularios, navegación, recetas devueltas por un registro simulado y nombres visibles; las revisiones estáticas contrastan las definiciones de Mineclonia y las rutas del botón. No hay un cliente gráfico Luanti disponible en este entorno, así que queda pendiente abrir el mundo y comprobar rendering real, descubrimiento progresivo después de recoger ingredientes, persistencia tras reinicio y uso simultáneo en multijugador. No se afirman esas pruebas de runtime.
