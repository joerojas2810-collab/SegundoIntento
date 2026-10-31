#!/bin/bash
# Double-click in Finder to open the prepared "El sello de las ruinas" world.
# It only links this checkout as the Everforge game and copies the prepared
# world on first run. Existing progress in the copied world is preserved.
set -u

REPO="$(cd "$(dirname "$0")" && pwd)"
WORLD_SRC="$REPO/playtest/el_sello_de_las_ruinas"

say() { printf '%s\n' "$*"; }
fail() { say "ERROR: $*"; say ""; read -r -p "Pulsa Intro para cerrar." _; exit 1; }

[ -f "$REPO/game.conf" ] || fail "No encuentro game.conf. Mantén este archivo dentro del repositorio Everforge."
[ -f "$WORLD_SRC/world.mt" ] || fail "Falta playtest/el_sello_de_las_ruinas/world.mt."

BIN=""
for candidate in \
	"$REPO/Luanti.app/Contents/MacOS/luanti" \
	"$REPO/luanti.app/Contents/MacOS/luanti" \
	"$HOME/Applications/Luanti.app/Contents/MacOS/luanti" \
	"$HOME/Downloads/luanti.app/Contents/MacOS/luanti" \
	"/Applications/Luanti.app/Contents/MacOS/luanti" \
	"/Applications/Minetest.app/Contents/MacOS/minetest" \
	"/Applications/MineTest.app/Contents/MacOS/minetest"; do
	if [ -x "$candidate" ]; then BIN="$candidate"; break; fi
done
if [ -z "$BIN" ]; then
	BIN="$(command -v luanti 2>/dev/null || true)"
fi
if [ -z "$BIN" ]; then
	BIN="$(command -v minetest 2>/dev/null || true)"
fi
if [ -z "$BIN" ]; then
	fail "No encuentro Luanti. Instala Luanti 5.17 (luanti.org) y vuelve a abrir este archivo."
fi


# Locate the Luanti/Minettest data directory used by the macOS app.
DATA=""
for candidate in \
	"$HOME/Library/Application Support/minetest" \
	"$HOME/Library/Application Support/luanti" \
	"$HOME/.minetest"; do
	if [ -d "$candidate" ]; then DATA="$candidate"; break; fi
done
if [ -z "$DATA" ]; then
	DATA="$HOME/Library/Application Support/minetest"
fi
mkdir -p "$DATA/games" "$DATA/worlds" || fail "No puedo crear $DATA/games."

# Expose this checkout as the game named "everforge".
if [ -L "$DATA/games/everforge" ]; then
	ln -sfn "$REPO" "$DATA/games/everforge"
elif [ -e "$DATA/games/everforge" ]; then
	fail "$DATA/games/everforge ya existe y no es un enlace. Muévelo o renómbralo y vuelve a intentarlo."
else
	ln -s "$REPO" "$DATA/games/everforge"
fi

# Copy on first run; later runs refresh the worldmod but keep map.sqlite and
# player data, so progress survives restarts.
WORLD="$DATA/worlds/sello_de_las_ruinas"
if [ ! -f "$WORLD/world.mt" ]; then
	cp -R "$WORLD_SRC" "$WORLD" || fail "No puedo copiar el mundo preparado."
	say "Mundo preparado creado en: $WORLD"
elif command -v rsync >/dev/null 2>&1; then
	rsync -a --exclude 'world.mt' --exclude 'map.sqlite' --exclude '*.sqlite' \
		"$WORLD_SRC/" "$WORLD/" || fail "No puedo actualizar los mods del mundo."
else
	cp -R "$WORLD_SRC/worldmods" "$WORLD/" 2>/dev/null || true
fi


VERSION="$("$BIN" --version 2>/dev/null | head -n 1 || true)"
say "Everforge: $REPO"
say "Mundo:    $WORLD"
say "Motor:    ${VERSION:-desconocido}"
say ""
say "Cuando entres: habla con la Maestra junto a la hoguera, acepta la misión"
say "y usa la piedra de viaje azul a un lado del campamento."
say ""
CONFIG="$WORLD/playtest.conf"
if [ ! -f "$CONFIG" ]; then
	printf '%s\n' 'language = es' 'enable_server = false' 'server_announce = false' 'everforge_start_region = false' > "$CONFIG"
fi
exec "$BIN" --config "$CONFIG" --gameid everforge --world "$WORLD" --go
