gameid = everforge
backend = sqlite3
player_backend = sqlite3
auth_backend = sqlite3
mod_storage_backend = sqlite3

mg_name = v7
seed = 11
water_level = 1
world_name = El sello de las ruinas

# This world has its own hand-authored fortress/crypt schematic and never
# uses vanilla strongholds, mansions or other mcl_levelgen jigsaw structures.
mcl_levelgen_enable_ersatz = false

# Natural adventure world: Everforge's normal Mineclonia terrain/biome
# generation (v7 + mcl_biomes), not singlenode. zz_sello_ruins grounds the
# fortress and camp on the real terrain instead of building a flat plaza.
everforge_start_region = false

# Only the scripted guardians of the ruins spawn here.
mobs_spawn = false
