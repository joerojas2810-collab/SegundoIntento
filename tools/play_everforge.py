#!/usr/bin/env python3
"""Isolated Everforge playtest. Python stdlib only; never opens normal Luanti saves."""
from __future__ import annotations
import argparse
import hashlib
import os
from pathlib import Path
import platform
import shutil
import subprocess
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
SHA256 = "0ba118b537d3cc6fd07cd2268fef25e515fc6d87c27ad69b476144a8e28dba3c"
URL = "https://github.com/luanti-org/luanti/releases/download/5.17.0/luanti_5.17.0_macos12.3_arm64.zip"
p = argparse.ArgumentParser(description=__doc__)
p.add_argument("--luanti", type=Path, help="Luanti executable (5.17.0)")
p.add_argument("--data-dir", type=Path, default=ROOT / ".everforge-dev")
p.add_argument("--install", action="store_true", help="Clean, SHA256-verified macOS ARM64 install into the isolated directory")
p.add_argument("--archive", type=Path, help="Reuse the official archive instead of downloading")
p.add_argument("--new", action="store_true", help="Create a fresh development world; keep earlier worlds")
p.add_argument("--server", action="store_true")
p.add_argument("--port", type=int, default=49177)
p.add_argument("--test-stage", choices=["bootstrap", "restart", "players", "verify_players", "mechanics", "solo"])
p.add_argument("--name", default="Forjador")
p.add_argument("--client", help="Connect a separately isolated test client to localhost (e.g. ForgeAlice)")
a = p.parse_args()
data = a.data_dir.expanduser().resolve()
data.mkdir(parents=True, exist_ok=True)
marker = data / ".everforge-development"
if not marker.exists() and any(data.iterdir()):
    raise SystemExit("Refusing a non-empty directory without an Everforge development marker")
marker.write_text("Everforge disposable development data v1\n")
if a.install:
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        raise SystemExit("Automatic install supports macOS ARM64; elsewhere supply --luanti /path/to/luanti")
    archive = a.archive or data / "luanti-5.17.0.zip"
    if not archive.exists():
        urllib.request.urlretrieve(URL, archive)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != SHA256:
        raise SystemExit("Official Luanti archive SHA256 mismatch")
    runtime = data / "runtime"
    if runtime.exists():
        raise SystemExit("Clean runtime already exists; use another --data-dir")
    runtime.mkdir()
    subprocess.run(["ditto", "-xk", str(archive), str(runtime)], check=True)
installed = data / "runtime/luanti.app/Contents/MacOS/luanti"
engine = a.luanti or (installed if installed.exists() else None)
if not engine:
    found = shutil.which("luanti") or shutil.which("minetest")
    candidate = Path.home() / "Downloads/luanti.app/Contents/MacOS/luanti"
    engine = Path(found) if found else candidate
if not engine.is_file():
    raise SystemExit("Luanti not found. Use --install or --luanti /path/to/executable")
version = subprocess.check_output([str(engine), "--version"], text=True)
if "Luanti 5.17.0" not in version:
    raise SystemExit("This prototype is tested with Luanti 5.17.0; supply that version")
print(version, flush=True)
if a.client:
    import re
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,20}", a.client):
        raise SystemExit("Use a simple development player name")
    client = data / "clients" / a.client
    client.mkdir(parents=True, exist_ok=True)
    conf = client / "client.conf"
    conf.write_text("enable_sound = false\nlanguage = es\nscreen_w = 1280\nscreen_h = 800\n")
    client_env = os.environ.copy()
    client_env["LUANTI_USER_PATH"] = str(client)
    raise SystemExit(subprocess.call([str(engine), "--go", "--address", "127.0.0.1", "--port", str(a.port),
        "--name", a.client, "--password", "everforge-test", "--config", str(conf), "--logfile", str(client / "client.log")], env=client_env))
user = data / "user"
games = user / "games"
games.mkdir(parents=True, exist_ok=True)
link = games / "everforge"
if link.is_symlink():
    if link.resolve() != ROOT:
        raise SystemExit("Game link points at another checkout")
elif link.exists():
    raise SystemExit("Refusing to overwrite an existing game installation")
else:
    link.symlink_to(ROOT, target_is_directory=True)
active = data / "active-world.txt"
if a.new or not active.exists():
    world = data / ("world-" + str(time.time_ns()))
    world.mkdir()
    active.write_text(str(world))
else:
    world = Path(active.read_text().strip()).resolve()
    if world.parent != data or not world.name.startswith("world-"):
        raise SystemExit("Invalid development world path")
testmod = world / "worldmods/everforge_runtime_test"
if a.test_stage:
    testmod.parent.mkdir(exist_ok=True)
    if not testmod.exists():
        testmod.symlink_to(ROOT / "tools/everforge_runtime_test", target_is_directory=True)
elif testmod.is_symlink():
    testmod.unlink()  # Never ship the testing mod into normal play.
config = data / "playtest.conf"
config.write_text("\n".join([
    "mg_name = singlenode", "fixed_map_seed = 12345", "num_emerge_threads = 2",
    "server_announce = false", "bind_address = 127.0.0.1", f"port = {a.port}",
    "enable_ipv6 = false", "creative_mode = false", "enable_damage = true",
    "mcl_levelgen_use_ffi = false", "enable_sound = false", "screen_w = 1280", "screen_h = 800",
    "language = es", "everforge_start_region = true",
    f"everforge_test_stage = {a.test_stage or ''}",
]) + "\n")
env = os.environ.copy()
env["LUANTI_USER_PATH"] = str(user)
args = [str(engine), "--gameid", "everforge", "--world", str(world), "--config", str(config),
        "--logfile", str(data / "server.log")]
args += ["--server"] if a.server or (a.test_stage and a.test_stage != "solo") else ["--go", "--name", a.name]
print(f"World: {world}\nLog: {data / 'server.log'}", flush=True)
raise SystemExit(subprocess.call(args, env=env))
