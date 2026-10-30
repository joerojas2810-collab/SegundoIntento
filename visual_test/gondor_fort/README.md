# Gondor Fort → Mineclonia: prueba visual de estructura

**Estado:** paquete de prueba preparado y validado a nivel de datos. **No hay capturas reales de Luanti en este entorno.** Las imágenes de `evidence/` son previsualizaciones técnicas, no capturas de juego. Falta la inspección manual en un cliente Luanti 5.17 + Mineclonia.

**Alcance:** solo estructura. No se implementa el motor narrativo, las regiones definitivas ni la campaña. No se toca el mundo principal ni ningún otro sistema. El mundo de prueba es desechable.

---

## 1. Qué se entrega

| Archivo | Qué es |
|---|---|
| `gondor_fort_ruined.mts` | Asset final de la prueba: 19×30×20, 3.015 nodos sólidos, adaptación moderada a ruina medieval. |
| `gondor_fort_clean.mts` | Mismo mapeo sin la pasada de ruina, para comparar. 19×32×20. |
| `test_world/` | Mundo temporal `singlenode` con plataforma, colocación automática y vistas fijas. |
| `convert_gondor_fort.py` | Conversor `.we` → `.mts`, mapeo y pasada de ruina. Sin dependencias externas. |
| `preview_technical.py` | Genera las previsualizaciones técnicas desde el `.mts`. |
| `audit_structure.py` | Auditoría geométrica: dimensiones, puerta, rutas, escaleras, escaleras de mano, antorchas. |
| `mapping_report.json` | Trazabilidad completa nodo por nodo y verificación round-trip del `.mts`. |
| `audit.json` | Resultados de la auditoría geométrica. |
| `evidence/` | 8 PNG técnicos + aviso (incluye `00_front_clean` antes/después). **No son capturas.** |
| `LICENSE-STRUCTURE.txt` | Atribución CC BY-SA 3.0, cambios y estado legal. |

No se incluye el `.we` original de LOTT: el conversor recibe la ruta del archivo fuente y el asset derivado conserva la atribución.

---

## 2. Limitación principal: no hay capturas reales

No pude producir capturas de Luanti en este entorno. Verifiqué y descarté:

- no hay binario Linux de Luanti 5.17 publicado en GitHub Releases; los AppImage dependen de `release-assets.githubusercontent.com`, inaccesible desde aquí;
- no hay paquete de servidor/cliente Luanti en npm ni PyPI;
- no hay `libGL`, `libEGL`, `libOSMesa` ni GPU; `apt-get` está bloqueado;
- no hay `cmake`, `ninja`, `meson`, `bison`, `flex` ni `m4` para compilar Mesa/Luanti;
- las librerías EGL/GLES de `@sparticuz/chromium` son stubs sin símbolos GL utilizables;
- los wheels de VTK/PyPI no traen Mesa/OSMesa.

Por eso **no presento renders como capturas**. Las imágenes de `evidence/` sirven para revisar geometría, materiales, huecos y proporciones; no prueban iluminación, colisiones, escaleras, escaleras de mano, camas ni comportamiento en juego. El punto de capturas reales queda explícitamente pendiente.

---

## 3. Cómo hacer la inspección manual (Luanti 5.17 + Mineclonia)

### 3.1 Preparar el juego y el mundo

En Linux, con el repositorio en `/home/user/SegundoIntento`:

```bash
mkdir -p ~/.minetest/games
ln -sfn /home/user/SegundoIntento ~/.minetest/games/everforge

rm -rf ~/.minetest/worlds/gondor_fort_test
cp -r /home/user/SegundoIntento/visual_test/gondor_fort/test_world \
      ~/.minetest/worlds/gondor_fort_test
```

El `world.mt` ya apunta a `gameid = everforge`. Si tu carpeta de datos es `~/.local/share/luanti`, usá esa ruta en lugar de `~/.minetest`.

### 3.2 Abrir

```bash
luanti --gameid everforge --world ~/.minetest/worlds/gondor_fort_test
# en versiones antiguas el binario se llama minetest
```

Al entrar, el mod del mundo construye una plataforma de piedra en `y=65`, coloca el esquema con origen `(0,63,0)` y te lleva a la vista frontal. Esperá 2–3 segundos antes de la primera captura.

### 3.3 Vistas y capturas

Comandos:

```text
/ruins_view front
/ruins_view side
/ruins_view back
/ruins_view gate
/ruins_view courtyard
/ruins_view interior
/ruins_view top
/ruins_pos
```

- `F12` guarda la captura (tecla `screenshot` por defecto).
- `F1` oculta el HUD para una captura limpia.
- `K` activa/desactiva volar; el mundo de prueba te da `fly`, `fast`, `noclip` y `creative`.
- Para la vista superior, `/ruins_view top` te deja a `y=96`; volá o usá `noclip` para no caer.
- Las capturas van a `~/.minetest/screenshots/` (o `~/.local/share/luanti/screenshots/`).

### 3.4 Qué comprobar

**Entrada**
- La puerta norte es un hueco de **3×3** en `x=8..10`, `y=4..6`, `z=4`; el pasillo de aproximación está en `z=0..3`.
- Hay un **escalón de 1 bloque** en el umbral (`z=4`, suelo en `y=3`). Comprobar si se sube con salto normal o si hace falta una escalera/rampa.
- Verificar que no hay bloques flotantes sobre el dintel y que la silueta de la puerta se lee desde la vista frontal.
- Recorrer a pie: plataforma → hueco → patio → sala del torreón. Si algo bloquea, anotar coordenadas con `/ruins_pos`.

**Interiores**
- Salas del torreón, camas (azules/rojas), cofres vacíos, mesa de pociones, caldero, horno y pozo.
- Techos, forjados y muros: buscar huecos no intencionales, bloques flotantes y filtraciones de luz.
- Circulación vertical: 37 escaleras, 1 losa y 35 escaleras de mano.

**Escaleras y escaleras de mano**
- Las 37 `mcl_stairs:stair_stonebrick` conservan el `param2` de LOTT (la API `stairs` de LOTT y `mcl_stairs` comparten convención 0–3/20–23). Confirmar orientación, colisión y continuidad.
- Las 35 `mcl_core:ladder` se convirtieron de `facedir` (LOTT) a `wallmounted` (Mineclonia). **5 son autoportantes en el hueco del torreón** (`x=11`, `y=20..24`, `z=15`): en el origen no tienen pared de apoyo. Confirmar que se pueden trepar y que no se ven flotando de forma inaceptable.
- Las escaleras de mano del patio/oeste (`x=5`, `z=3/15`) y las del postigo sur (`x=10`, `z=15`) deben probarse una por una.

**Proporciones**
- Caja sólida: **19×30×20**; altura de la corona central ≈ 27–29 bloques sobre la base; torres delanteras ≈ 19–21.
- Puerta 3×3; salas con 3–4 bloques de altura libre; patio central de 5 bloques de ancho. Verificar escala humana y que la silueta no se vea “de juguete” ni desproporcionada.

**Iluminación**
- 46 antorchas de pared. La auditoría geométrica da una mediana de 6 bloques Manhattan y 91% de las celdas de planta a ≤8 de una antorcha, pero **eso no prueba luz real**.
- Revisar con `/time 12:00` y también de noche; buscar salas con rincones negros y antorchas que hayan quedado dentro de bloques.

**Accesibilidad**
- Ruta geométrica encontrada: 16 pasos desde fuera hasta el nivel del torreón, con un salto de 1 bloque en el umbral. **No está probada con colisiones reales.**
- Revisar si las escaleras de mano invaden vanos, si las camas/cofres bloquean puertas y si las vallas de 39 bloques cierran pasos.

### 3.5 Checklist de aprobación

- [ ] La puerta se ve y se cruza a pie.
- [ ] Patio y al menos una sala del torreón son accesibles sin volar.
- [ ] Escaleras: orientación, colisión y continuidad aceptables.
- [ ] Escaleras de mano: trepables, incluidas las 5 autoportantes.
- [ ] Camas y cofres se ven correctos (orientación/top-bottom).
- [ ] Iluminación suficiente en interiores; sin antorchas dentro de bloques.
- [ ] Proporciones y silueta aceptables desde frente, lado y arriba.
- [ ] Ningún hueco/despegue no intencional.
- [ ] Capturas reales guardadas (frente, lado, interior, superior).
- [ ] Decisión: continuar con revisión legal o buscar otro build externo.

---

## 4. Mapeo de bloques

El conversor **falla** si encuentra un nombre no mapeado; no hay descartes silenciosos. Todos los nombres destino existen en Mineclonia y aparecen en `mods/ITEMS/mcl_maps/colors.json` (verificado estáticamente).

| Origen LOTT | Destino Mineclonia | Nodos |
|---|---|---:|
| `lottblocks:marble_brick` | `mcl_core:stonebrick` | 1880 |
| `lottother:air` | `air` | 992 |
| `lottother:dirt` | `mcl_core:dirt` | 813 |
| `lottmapgen:gondor_grass` | `mcl_core:dirt_with_grass` | 162 |
| `default:torch_wall` | `mcl_torches:torch_wall` | 47 |
| `default:fence_wood` | `mcl_fences:oak_fence` | 39 |
| `stairs:stair_marble_brick` | `mcl_stairs:stair_stonebrick` | 37 |
| `default:ladder` | `mcl_core:ladder` | 35 |
| `default:wood` | `mcl_trees:wood_oak` | 18 |
| `lottmapgen:gondor_chest_spawner` | `mcl_chests:chest_small` | 10 → 4 vacíos |
| `lottother:gondorms_off` | `air` | 10 |
| `lottblocks:alder_chair` | `air` | 4 |
| `lottblocks:bed_bottom_blue` | `mcl_beds:bed_blue_bottom` | 4 |
| `lottblocks:bed_top_blue` | `mcl_beds:bed_blue_top` | 4 |
| `lottblocks:alder_table` | `air` | 2 |
| `lottblocks:bed_bottom_red` | `mcl_beds:bed_red_bottom` | 2 |
| `lottblocks:bed_top_red` | `mcl_beds:bed_red_top` | 2 |
| `lottpotion:brewer` | `mcl_brewing:stand_000` | 2 |
| `default:furnace` | `mcl_furnaces:furnace` | 1 |
| `default:water_source` | `mcl_core:water_source` | 1 |
| `lottpotion:cauldron_full` | `mcl_cauldrons:cauldron` | 1 |
| `stairs:slab_marble_brick` | `mcl_stairs:slab_stonebrick` | 1 |

Notas:
- Se conservan los 10 spawners de cofre solo como **4 cofres vacíos** decorativos; los otros 6 se retiran para no llenar las salas de cofres. No hay loot ni lógica de misión.
- Había 47 antorchas en el origen; quedan **46** porque la antorcha de la corona en `(11,29,13)` se retiró junto con el tercio superior de `y=29`.
- Se eliminan los spawners de mobs (`gondorms_off`) y los muebles sin equivalente (`alder_chair`, `alder_table`). No se inventan muebles.
- `default:ladder` requiere conversión de `param2`: LOTT usa `facedir` 0–3 apuntando hacia la pared; Mineclonia usa `wallmounted` 2–5. Se convirtieron 16 valores; 5 escaleras quedan autoportantes porque el origen tampoco tiene pared.
- `default:torch_wall` y las camas se mantienen con su `param2`; **su semántica exacta no está verificada en juego**.
- Las escaleras/losas usan la misma API de escaleras que LOTT; se asume la misma convención de `param2`, **pendiente de confirmar visualmente**.

---

## 5. Adaptación a ruina (moderada)

Aplicada solo a `gondor_fort_ruined.mts`:

- base de terreno sustituida por un zócalo de `mcl_core:stonebrick` (`y<=2`);
- variación coherente de piedra: 338 mossy + 264 cracked + 22 carved (≈22% del total de piedra), no ruido aleatorio puro;
- **apertura de accesibilidad**: 9 bloques retirados para abrir la puerta norte 3×3 (el origen tenía un nicho ciego);
- 10 bloques retirados en 3 brechas pequeñas (torres delanteras y muro sur);
- 9 bloques retirados de coronas/almenas para romper la silueta;
- corona central (`y>=30`) eliminada y un tercio de `y=29`, para que el torreón se lea roto;
- 6 bloques de escombro fuera de la puerta, en los flancos (no bloquean el paso);
- 27 bloques de musgo en la base húmeda.

No se añadieron murallas, torres ni volúmenes nuevos: la planta y la silueta siguen siendo las del build original. No se usó código procedural para generar una fortaleza genérica.

---

## 6. Costo de conversión y problemas encontrados

### Costo

- **Datos:** trivial. 4.067 nodos de origen, 3.075 sólidos, `.mts` de ~2,2 KB; la conversión corre en menos de un segundo.
- **Ingeniería:** el conversor + validador + auditoría + previsualizaciones es de unas pocas horas; lo caro no es parsear, es **verificar en juego y decidir**.
- **En juego:** colocar un esquema de 11.400 celdas es despreciable; el costo real es el QA visual y la revisión legal.
- **Legal:** CC BY-SA 3.0 exige atribución, indicar cambios y ShareAlike. Everforge/Mineclonia es GPL-3.0; la compatibilidad CC BY-SA 3.0 ↔ GPLv3 **debe revisarse antes de distribuir**. Por eso el asset queda en evaluación, fuera de la distribución pública.

### Problemas concretos

1. **Puerta norte ciega en el origen.** El hueco entre las torres era un nicho de 2 bloques de profundidad, cerrado por el muro de `z=4`. Sin la apertura 3×3, el patio no era accesible a pie. Es una corrección funcional mínima, no un rediseño.
2. **Escalón en el umbral.** El suelo exterior y el de la puerta no están al mismo nivel; hay un salto de 1 bloque. Puede requerir salto o una rampa/escalera adicional. **No verificado con colisiones.**
3. **Escaleras de mano autoportantes.** 5 de las 35 no tienen pared de apoyo en el origen (`x=11`, `y=20..24`, `z=15`). Se conservan; pueden verse flotando o comportarse distinto en Mineclonia.
4. **Semántica de `param2`.** Escaleras, losas, camas y antorchas se mantuvieron; la convención parece compartida, pero **no está probada**. Es el punto más probable de error visual.
5. **Muebles sin equivalente.** Sillas y mesas de aliso se retiraron; el interior queda más vacío. Los 10 spawners de cofre se redujeron a 4 cofres vacíos.
6. **Sin puerta física.** El fuerte no tiene puerta ni rastrillo; el acceso queda abierto. Para una ruina es aceptable, pero no hay cierre defensivo.
7. **Iluminación.** 46 antorchas; la cobertura geométrica es razonable, pero puede haber rincones oscuros. No se puede afirmar sin capturas.
8. **Texturas.** El mármol de LOTT se reemplazó por ladrillo de piedra de Mineclonia; la lectura cambia de “mármol élfico” a “ruina de piedra”. Es una decisión visual deliberada y reversible.
9. **Base.** El `.mts` lleva un zócalo de 3 bloques; en producción habría que integrarlo con el terreno o recortarlo, no dejarlo como plataforma flotante.
10. **Licencia.** El asset no puede entrar aún a la distribución pública; falta la revisión de compatibilidad y la fila en `THIRD_PARTY.md`.

---

## 7. Verificado vs. no verificado

**Verificado (datos):**
- `.mts` con firma `MTSM`, versión 4, tamaño 19×30×20, paleta y round-trip leídos por un parser independiente.
- 3.015 nodos sólidos; todos los nombres destino existen en `colors.json`.
- Dimensiones, conteos, puerta, rutas geométricas, escaleras, escaleras de mano y antorchas (`audit.json`).
- Atribución y licencia del origen; pin de LOTT.

**No verificado (juego):**
- que Luanti 5.17 cargue el `.mts` sin errores;
- colisiones, escalones, escaleras, escaleras de mano y camas;
- iluminación, sombras y apariencia real de las texturas;
- rendimiento y placement en un mundo real;
- compatibilidad legal definitiva.

---

## 8. Próximo paso

1. Ejecutar la inspección manual de la sección 3 y guardar las capturas reales.
2. Si la puerta, escaleras y escaleras de mano pasan: revisar licencia y, solo entonces, evaluar integración.
3. Si no pasan: corregir la accesibilidad/`param2` antes de buscar otro build. Si el build no alcanza el nivel visual, buscar otra estructura externa con licencia clara **antes** de caer a piezas de woodland mansion.

No se commiteó ni se pusheó nada. El mundo principal no se tocó.
