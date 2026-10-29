-- SPDX-License-Identifier: GPL-3.0-or-later
-- On Luanti 5.17.0 macOS ARM64, biomes.lua interprets the coordinator tree
-- walk implicated in pathological recursive traces. This temporary count hook
-- additionally bounds native stronghold startup work. Preserve any pre-existing debugger
-- hook, restore on success/failure, and leave RNG / placement algorithms intact.
if core.global_exists("jit") and jit.os=="OSX" and jit.arch=="arm64"
 and (core.get_version().string or ""):match("^5%.17%.0")
 and type(mcl_levelgen.prime_concentric_placement)=="function" then
 local prepare=mcl_levelgen.prime_concentric_placement
 mcl_levelgen.prime_concentric_placement=function(...)
  local previous,mask,count=debug.gethook()
  local started=core.get_us_time()
  if not previous then
   debug.sethook(function()
    if core.get_us_time()-started>90000000 then
     core.log("error", debug.traceback("[Everforge] STRONGHOLD_TIMEOUT seed="..tostring(core.get_mapgen_setting("seed"))))
     error("Everforge: native stronghold preparation exceeded 90s; see server log (seed="..tostring(core.get_mapgen_setting("seed"))..")",0)
    end
   end,"",100000)
  end
  local result={pcall(prepare,...)}
  if not previous then debug.sethook(previous,mask,count) end
  if not result[1] then error(result[2],0) end
  return unpack(result,2)
 end
 core.log("action","[Everforge] WORLDGEN_COMPAT: bounded native stronghold preparation on Luanti 5.17.0 macOS ARM64; temporary execution hook, unchanged RNG")
end
