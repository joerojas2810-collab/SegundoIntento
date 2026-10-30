# Expediciones cooperativas: validación en Luanti 5.17

Fecha: 30/10/2026. Resultado funcional: correcto tras dos correcciones. La apariencia visual permanece pendiente.

## Entorno y preservación

- Se integró `origin/arena/41899ad0-segundointento` (`e2ab2ce68`) sobre `main` (`8a2563fd8`) mediante merge sin commit. No se hizo push. El árbol de trabajo estaba limpio antes de integrar.
- Servidor y dos procesos cliente nativos Luanti 5.17.0, protocolo 53, nombres `ExpeditionAlice` y `ExpeditionBob`, conectados por localhost:57563. Los logs del servidor registran versiones, conexiones y desconexiones; los logs independientes de los clientes registran conexión y chat.
- Mundo desechable `/private/tmp/everforge-expedition-20261030/world`, copiado de un mundo de QA anterior con campamento listo. Nunca se abrió ni modificó el mundo principal ni se cambió la instalación del motor.
- El mod verificador solo se instaló como worldmod del mundo temporal. Los procesos temporales se cerraron al terminar.

## Qué se verificó realmente

| Comprobación | Resultado y alcance |
|---|---|
| Maestra en el campamento | Entidad real de `mcl_mobs`, posición junto al campamento, exactamente una tras activar el área y después de cada reinicio. Su `on_rightclick` recibe un jugador real y envía el formulario. No se verificó clic físico ni apariencia. |
| Crear e invitar | El líder crea la expedición y el formulario enumera al segundo jugador conectado. La invitación y su formulario se envían a su sesión real. |
| Recibir y aceptar | Se comprueban invitación persistida y formulario enviado; el segundo cliente se desconecta y reconecta antes de aceptar. La aceptación actualiza la pertenencia compartida y ambos HUD. |
| Obtener y entregar espada | La receta nativa y los callbacks producen una espada de hierro que entra en el inventario real de Alice. El escaneo periódico detecta la espada. La entrega consume esa única espada, completa la misión para ambos miembros, envía los dos formularios de confirmación y retira los HUD. |
| Desconexiones | Se desconectan y reconectan realmente Bob y Alice, manteniendo invitación, pertenencia, progreso y HUD. En una segunda expedición Bob está realmente desconectado durante la entrega. |
| Reinicios | El estado activo y la espada del inventario se recuperan desde SQLite tras reiniciar. La segunda entrega deja pendiente la confirmación de Bob; otro reinicio y su conexión envían la confirmación y guardan la marca. Un reinicio adicional conserva ambas expediciones completadas y sus marcas, sin repetir avisos ya enviados. |
| Formularios/HUD | Formularios construidos por producción y enviados por el servidor a los dos clientes; HUD real consultado con `hud_get_all` (uno activo, cero al completar). Cinco formularios capturados de producción, 17 widgets con dimensiones, pasan el comprobador de geometría. No hay evidencia visual fiable. |

**Límite de la automatización:** las conexiones, jugadores, entidades, inventarios, almacenamiento, escaneo periódico y reinicios son reales. El verificador llama al callback del NPC y a los callbacks registrados de formularios usando los ObjectRefs reales; los botones no se pulsaron mediante la interfaz de los clientes. No se afirma una prueba manual de extremo a extremo ni se presentan los jugadores simulados del test de modelo como multijugador real.

## Errores y correcciones, solo expediciones

1. **Maestra duplicada al reiniciar.** La recuperación creaba otra entidad antes de activarse la guardada en el mapblock. Se añadió una comprobación diferida de activación que conserva una sola Maestra y elimina el duplicado al activarse. La repetición encontró una sola en todos los reinicios.
2. **Estado rechazado al recargar.** `core.write_json` guarda tablas vacías como `null`; desaparecían `invites` y `notified` al analizar sin marcador. Se restaura exclusivamente el `null` explícito de las colecciones conocidas. Los campos ausentes o inválidos siguen deshabilitando acciones sin sobrescribir el dato. Se recuperó el mismo mundo de prueba, sin borrar su progreso.
3. Se sustituyó `hud_elem_type` por `type` en el HUD de expediciones para eliminar el aviso de API obsoleta de Luanti 5.17.

Se añadieron regresiones para activación tardía de la entidad y lectura de colecciones vacías. La prueba de modelo pasa y se identifica como simulación. Pasan también las seis pruebas existentes de interfaces y la sintaxis Lua 5.1 de los dos módulos.

## Pendiente

- Inspección visual del NPC, texturas, tipografía, contraste y posibles solapamientos con el resto del HUD, en distintas resoluciones.
- Clic derecho y botones enviados por un usuario desde cada cliente; la prueba actual automatiza el lado servidor.
- No se certifica rendimiento: los logs muestran picos de lag y avisos de movimiento. Los clientes intentaron contextos OpenGL y registraron errores antes de conectarse; la captura de pantalla del entorno falló. Eso impide dar por aprobada la presentación gráfica, aunque las sesiones de red y las pruebas funcionales terminaron correctamente.

## Evidencia

Carpeta: [evidence/expeditions-20261030](evidence/expeditions-20261030). Se quitaron únicamente espacios al final de línea de las copias de logs; los originales permanecen en el directorio temporal.

- `initial-real-clients.log`: flujo inicial, invitación y reconexiones reales.
- `failure-duplicate-npc.log` y `failure-storage-reload.log`: fallos reproducidos antes de sus correcciones.
- `fixed-delivery.log`: recuperación del estado, entrega con ambos conectados y segunda entrega con Bob desconectado; proceso termina con código 0.
- `fixed-offline-confirmation.log`: entrega de confirmación pendiente después del reinicio; código 0.
- `fixed-confirmation-restart.log`: reinicio adicional y ausencia de avisos duplicados; código 0.
- `stage*-Alice-client.log` y `stage*-Bob-client.log`: logs de procesos cliente independientes.
- `model-regression.log`: prueba sin motor, identificada como tal.
- `runtime-verifier.lua`, `run-local-qa.py`: copia exacta del verificador y orquestador usados, con rutas de esta sesión. No forman parte de los mods del juego y no son un instalador reutilizable. El orquestador requiere el mundo/configuraciones temporales y el worldmod ya preparados; el mundo quedó en fase `verified`.
- `source-hashes.json`: hashes de las fuentes verificadas.

No se añadieron mecánicas, regiones, misiones ni enemigos.
