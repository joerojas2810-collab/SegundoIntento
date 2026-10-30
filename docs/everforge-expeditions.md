# Everforge — prototipo de expediciones cooperativas

Estado: primer prototipo funcional. No incluye campaña, regiones nuevas, castillos, jefes ni escalado de dificultad. No modifica combate, forja probabilística ni el inventario existente.

## Qué se implementó

- **NPC en el campamento:** «Maestra de expediciones», entidad `everforge:expedition_npc` registrada con `mcl_mobs`. Se coloca una sola vez junto al campamento inicial; si el mundo ya tenía campamento, se recupera o reaparece en la primera conexión.
- **Inicio:** al hacer clic derecho en el NPC, el jugador sin expedición activa pulsa «Iniciar expedición».
- **Invitaciones:** solo el líder puede invitar. La lista muestra únicamente jugadores conectados que no participan en otra expedición. El invitado recibe un formulario y debe pulsar «Aceptar»; «Rechazar» elimina la invitación. Las invitaciones caducan a los 5 minutos.
- **Misión compartida:** conseguir cualquier objeto con el grupo de objeto `sword` y entregarlo al NPC. El estado del grupo registra `sword_found` y la entrega. Cualquier miembro puede entregar una espada por el grupo; se consume exactamente una.
- **Confirmación:** al completar, todos los participantes conectados reciben chat y formulario de confirmación. Un participante desconectado la recibe al volver a entrar.
- **Persistencia:** el estado se guarda en `core.get_mod_storage()` bajo `everforge:expeditions:v1`. No usa `awards`, `mcl_achievements` ni la XP vanilla. La pertenencia se guarda por nombre de jugador, por lo que desconectarse no elimina el progreso del grupo.
- **HUD propio:** línea discreta con el identificador de expedición y el estado de espada/entrega. Se retira al desconectarse o completar.

## Cómo probarlo

1. Crear un mundo nuevo con Everforge y esperar a que termine la región inicial.
2. Buscar a la **Maestra de expediciones** junto al campamento (normalmente a un lado del camino).
3. Clic derecho → **Iniciar expedición**.
4. Con otro jugador conectado, el líder pulsa **Invitar a …** en el formulario del NPC.
5. El invitado acepta en la ventana que recibe.
6. Conseguir una espada (nativa o modular de Everforge) en el inventario principal. El progreso compartido se actualiza en unos segundos.
7. Cualquier miembro pulsa **Entregar espada** en el NPC. Se descuenta una espada y todos ven la confirmación.
8. Repetir con un participante desconectado antes de la entrega: al reconectar recibe la confirmación pendiente.

## Límites del prototipo

- Máximo 8 miembros por expedición y 64 expediciones almacenadas (las completadas más antiguas se podan).
- Una invitación pendiente por jugador; caduca a los 300 s.
- El NPC es una entidad persistente e invulnerable a golpes de jugador, sin IA de combate.
- No hay cancelación de expedición ni recompensas económicas: el objetivo es verificar el flujo compartido.
- La detección de espada revisa el inventario `main`; no altera ninguna receta ni probabilidad de forja.

## Verificación realizada

El 30/10/2026 se validó el flujo funcional en un servidor real Luanti 5.17.0 con dos clientes nativos, mundo temporal, desconexiones y reinicios. Se corrigieron la duplicación del NPC al activar entidades guardadas y la lectura de colecciones JSON vacías; también se actualizó la clave del HUD a la API vigente.

La prueba automatiza callbacks del servidor sobre jugadores reales: no equivale a pulsar botones desde cada cliente. La inspección visual del NPC, formularios y HUD permanece pendiente por las limitaciones gráficas del entorno. Las pruebas de modelo se mantienen identificadas como simulaciones.

El alcance exacto, los resultados, los errores originales y los registros están en [validación de expediciones](everforge-expeditions-validation.md).
