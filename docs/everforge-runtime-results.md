# Resultados de la primera versión jugable — 28/10/2026

Motor identificado y ejecutado: **Luanti 5.17.0 OSX ARM64, LuaJIT 2.1.1764270282**, obtenido mediante extracción limpia del ZIP oficial. SHA256 comprobado contra `digest` del release oficial de GitHub; coincide con el fijado en el launcher. Juego: checkout de PR #2, Mineclonia 0.124.1 con los cambios de esta entrega. Sin mundos ni perfiles reales y sin migraciones.

## Comprobado ejecutando el juego

| Prueba | Resultado |
|---|---|
| Arranque desde instalación limpia y mundo vacío | PASS; servidor escuchando solo en localhost |
| Generación procedural singlenode, seed 12345 | PASS; campamento único en `(103,81,26)`, radio 6 |
| Crear y entrar directamente en partida local | PASS; jugador espera la preparación y llega a la región con perfil y comando UI |
| Reinicio de ese mundo | PASS; mismo centro, bloque añadido y metadata conservados |
| Modelo ejecutado dentro de LuaJIT del motor | PASS; serialización, curva, puntos, compra, no sobregasto, deduplicación y límite de historial |
| Dos conexiones reales, ForgeAlice y ForgeBob | PASS; misma región y progreso personal independiente |
| Minería | PASS; `core.node_dig` real con jugador y herramienta nativa |
| Artesanía | PASS del adaptador mediante despacho de callbacks de fabricación completada; no prueba manual de la rejilla con ratón |
| Forja | PASS; inventario real, entrada/fuel, timer del fundidor, output aceptado y XP del proveedor |
| Combate | PASS; monstruo nativo instanciado y muerto mediante daño atribuido al jugador |
| Exploración | PASS del registro/deduplicación por celda y polling activo; no recorrido manual de varios biomas |
| Independencia de XP | PASS; las operaciones Everforge no modificaron la XP vanilla. Los orbes del monstruo siguen dando XP vanilla normalmente |
| Reconexión y reinicio de personaje real | PASS; XP por disciplina, Dominio, habilidad comprada y modificación del mundo permanecen |
| Muerte/reaparición real | PASS; XP vanilla perdida y XP Everforge conservada; fallback en campamento |
| Compra de las cuatro habilidades | PASS del handler de formspec; rangos/puntos actualizados, sin selector de clase |
| Efectos de Explorador y Guardia | PASS; factor de velocidad 1.04 y multiplicador de daño 0.9 en el pipeline real |
| Cama fuera de la región | PASS; selector nativo conserva su prioridad |
| Ancla cargada | PASS; posición nativa y consumo de carga 2→1; se probó la resolución, no una visita manual al Nether |
| Región totalmente obstruida | PASS; búsqueda devuelve ausencia de llegada segura, sin fallback exterior; bloques del fixture restaurados |
| Regresiones de UI previas | PASS; 5 pruebas Python |

El cliente recibió el formspec y los mensajes de compra. Esto comprueba el circuito de datos y callbacks, no una inspección visual del diseño.

## Límites explícitos

- **OpenGL/ventana:** el entorno automatizado mostró `Irrlicht: Could not create window and context!` al probar contextos gráficos y aun así estableció las conexiones de cliente y ejecutó las pruebas. No pude inspeccionar visualmente la ventana con las herramientas disponibles. No se da por aprobada la experiencia gráfica, DPI, controles manuales ni legibilidad; debe probarse desde los accesos del escritorio en una sesión gráfica normal.
- Curvas, tabla de actividad, antifarming, tamaño y contenido del campamento son provisionales. Seed/mapgen alternativos, latencia de varios usuarios remotos, muerte en Nether, crash abrupto y durabilidad ante cortes quedan pendientes. La generación inicial tuvo picos de lag de alrededor de 2 segundos; no se midió rendimiento de producción.
- Menor desgaste y reducción de tiempo de Forjador usan el código existente conectado al rango nuevo; hay prueba de compra y del timer de Forja, pero no una comparación exhaustiva de durabilidad y tiempos para los tres rangos.
- Las suites JavaScript anteriores requieren `luaparse`, ausente de esta copia; no se instalaron dependencias para ellas. Las pruebas Lua nuevas sí se ejecutaron en el motor real.
- No se cambió el icono del yunque, el logo, la XP nativa, recetas base, costes de yunque/encantamiento ni pérdida vanilla al morir. No hay tests manuales exhaustivos de reparación/encantamiento en esta entrega.

Las pruebas detectaron y permitieron corregir errores de ejecución que la revisión estática no había encontrado: registro de features en el entorno incorrecto, nombres de límites de placement, firma real `place(self, ...)`, nodos de estaciones que requerían vectores nativos y serialización de tablas vacías. Los archivos nuevos usan serialización segura de Lua para perfiles. El extracto de evidencia conserva resultados de ejecuciones correctas; no representa todos los intentos intermedios.

Comandos y procedimiento: `docs/everforge-playable.md`. PR #2 sigue abierto y no se fusiona automáticamente.
