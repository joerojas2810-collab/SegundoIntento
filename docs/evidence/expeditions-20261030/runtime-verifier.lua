local E=everforge.expedition
local store=core.get_mod_storage()
local checks,forms,joins,leaves=0,{}, {},{}
local function check(ok,msg) checks=checks+1;assert(ok,'EXPEDITION_QA_FAIL '..msg);core.log('action','EXPEDITION_QA_OK '..msg) end
local show=core.show_formspec
core.show_formspec=function(name,form,fs)
 if form:find('everforge:expedition_',1,true)==1 then
  forms[name]=forms[name] or {};forms[name][form]=fs
  core.safe_file_write(core.get_worldpath()..'/form-'..name..'-'..form:gsub(':','-')..'.txt',fs)
  core.log('action','EXPEDITION_QA_FORM '..name..' '..form)
 end
 return show(name,form,fs)
end
local function connected() return core.get_player_by_name('ExpeditionAlice'),core.get_player_by_name('ExpeditionBob') end
local function dispatch(player,form,fields)
 check(player and player:is_player() and player:is_valid(),'real player ObjectRef '..player:get_player_name())
 for _,cb in ipairs(core.registered_on_player_receive_fields) do if cb(player,form,fields) then return end end
end
local function objects()
 local r=everforge.start_region.get();local list={}
 core.load_area(vector.offset(r.center,-12,-6,-12),vector.offset(r.center,12,8,15))
 for _,o in ipairs(core.get_objects_inside_radius(r.center,20)) do
  local en=o:get_luaentity();if en and en.name==E.npc_name then list[#list+1]=o end
 end
 return list
end
local function npc(player)
 local list=objects();check(#list==1,'exactly one camp expedition NPC (actual='..#list..')')
 local obj=list[1];local ent=obj:get_luaentity()
 check(obj:get_pos()~=nil and ent.on_rightclick~=nil,'NPC instantiated and interactable')
 ent:on_rightclick(player)
 check(forms[player:get_player_name()] and forms[player:get_player_name()]['everforge:expedition_npc'],'NPC interaction sends real formspec')
 return obj
end
local function hud(player,wanted)
 local found=0
 for _,def in pairs(player:hud_get_all()) do if def.text and def.text:find('Expedición #',1,true) then found=found+1;core.log('action','EXPEDITION_QA_HUD '..player:get_player_name()..' '..def.text) end end
 check(found==(wanted and 1 or 0),'expedition HUD '..player:get_player_name()..' count='..found)
end
local function exp(id) return E.get_state().expeditions[tostring(id)] end
local function sword(player)
 local grid={ItemStack('mcl_core:iron_ingot'),ItemStack(''),ItemStack(''),ItemStack('mcl_core:iron_ingot'),ItemStack(''),ItemStack(''),ItemStack('mcl_core:stick'),ItemStack(''),ItemStack('')}
 local result=core.get_craft_result({method='normal',width=3,items=grid})
 check(core.get_item_group(result.item:get_name(),'sword')>0,'engine recipe produces a sword')
 local item=core.on_craft(result.item,player,grid,player:get_inventory())
 check(player:get_inventory():add_item('main',item):is_empty(),'crafted sword fits real inventory')
end
local function complete(a,b,id)
 local before=a:get_inventory():contains_item('main','mcl_tools:sword_iron')
 check(before,'leader owns sword before delivery')
 dispatch(a,'everforge:expedition_npc',{deliver=true})
 local e=exp(id)
 check(e.status=='completed' and e.members.ExpeditionAlice and e.members.ExpeditionBob and e.progress.delivered_by=='ExpeditionAlice','shared completion for both members')
 check(not a:get_inventory():contains_item('main','mcl_tools:sword_iron'),'exactly one single sword consumed')
 hud(a,false);if b then hud(b,false) end
end
local function stop(phase)
 store:set_string('phase',phase)
 core.log('action','EXPEDITION_QA_PHASE_PASS '..phase..' checks='..checks)
 core.after(1,function() core.request_shutdown('Expedition QA stage complete',false,0) end)
end
local busy=false
local function waitfor(fn) core.after(1,fn) end
local function run()
 if busy then return end
 local a,b=connected();if not a or not b then return end
 busy=true
 core.after(5,function()
  npc(a)
  local phase=store:get_string('phase')
  if phase=='' then
   dispatch(a,'everforge:expedition_npc',{start=true})
   local e=E.model.find_active_for(E.get_state(),'ExpeditionAlice');check(e and e.leader=='ExpeditionAlice','leader creates expedition')
   store:set_int('first',e.id);hud(a,true)
   dispatch(a,'everforge:expedition_npc',{invite_1=true})
   check(e.invites.ExpeditionBob and forms.ExpeditionBob and forms.ExpeditionBob['everforge:expedition_invite'],'second player receives invitation')
   store:set_string('subphase','invite-reconnect');core.kick_player('ExpeditionBob','QA invitation reconnect')
   core.log('action','EXPEDITION_QA_RECONNECT Bob')
   local function joined()
    local x,y=connected();if not y then waitfor(joined);return end
    core.after(4,function()
     check((joins.ExpeditionBob or 0)>=2 and (leaves.ExpeditionBob or 0)>=1,'real disconnect and reconnect before invitation acceptance')
     check(forms.ExpeditionBob['everforge:expedition_invite']~=nil,'pending invitation presented after reconnect')
     dispatch(y,'everforge:expedition_invite',{['accept_'..e.id]=true})
     check(e.members.ExpeditionBob and not e.invites.ExpeditionBob,'second player accepts invitation')
     hud(x,true);hud(y,true);sword(x)
     core.after(5,function()
      check(e.progress.sword_found and not e.progress.delivered,'sword acquisition updates shared progress')
      core.kick_player('ExpeditionAlice','QA leader reconnect');core.log('action','EXPEDITION_QA_RECONNECT Alice')
      local function leader()
       local aa,bb=connected();if not aa then waitfor(leader);return end
       core.after(3,function()
        check((joins.ExpeditionAlice or 0)>=2 and (leaves.ExpeditionAlice or 0)>=1,'leader disconnect and reconnect are real')
        check(E.model.find_active_for(E.get_state(),'ExpeditionAlice').id==e.id and e.progress.sword_found,'shared progress survives leader reconnect')
        hud(aa,true);hud(bb,true);stop('active-saved')
       end)
      end
      waitfor(leader)
     end)
    end)
   end
   waitfor(joined)
  elseif phase=='active-saved' then
   local e=exp(store:get_int('first'));check(e.status=='active' and e.progress.sword_found and e.members.ExpeditionBob,'active progress and membership survive server restart')
   check(a:get_inventory():contains_item('main','mcl_tools:sword_iron'),'real player sword inventory survives restart')
   hud(a,true);hud(b,true);complete(a,b,e.id)
   check(e.notified.ExpeditionAlice and e.notified.ExpeditionBob,'both online confirmations recorded')
   check(forms.ExpeditionAlice['everforge:expedition_complete'] and forms.ExpeditionBob['everforge:expedition_complete'],'completion forms sent to both clients')
   npc(a);dispatch(a,'everforge:expedition_npc',{start=true})
   local second=E.model.find_active_for(E.get_state(),'ExpeditionAlice');store:set_int('second',second.id)
   dispatch(a,'everforge:expedition_npc',{invite_1=true});dispatch(b,'everforge:expedition_invite',{['accept_'..second.id]=true})
   sword(a)
   core.after(5,function()
    check(second.progress.sword_found,'second shared sword found')
    core.kick_player('ExpeditionBob','QA offline completion')
    core.after(2,function()
     check(not core.get_player_by_name('ExpeditionBob'),'member really offline during delivery')
     complete(a,nil,second.id)
     check(second.notified.ExpeditionAlice and not second.notified.ExpeditionBob,'offline confirmation remains pending')
     stop('offline-completed')
    end)
   end)
  elseif phase=='offline-completed' then
   local first,second=exp(store:get_int('first')),exp(store:get_int('second'))
   check(first.status=='completed' and first.notified.ExpeditionAlice and first.notified.ExpeditionBob,'completed state and both previous notices survive restart')
   check(second.status=='completed' and second.notified.ExpeditionAlice and second.notified.ExpeditionBob,'pending confirmation delivered and saved on real rejoin')
   check(forms.ExpeditionBob and forms.ExpeditionBob['everforge:expedition_complete'],'offline participant receives completion form after restart')
   hud(a,false);hud(b,false)
   stop('verified')
  elseif phase=='verified' then
   local first,second=exp(store:get_int('first')),exp(store:get_int('second'))
   check(first.status=='completed' and second.status=='completed','both completed expeditions survive additional restart')
   check(first.notified.ExpeditionAlice and first.notified.ExpeditionBob and second.notified.ExpeditionAlice and second.notified.ExpeditionBob,'all confirmation flags survive additional restart')
   check(not (forms.ExpeditionAlice and forms.ExpeditionAlice['everforge:expedition_complete']) and not (forms.ExpeditionBob and forms.ExpeditionBob['everforge:expedition_complete']),'acknowledged completion notices are not resent')
   hud(a,false);hud(b,false);stop('verified')
  else error('Unexpected QA phase '..phase) end
 end)
end
core.register_on_joinplayer(function(p)
 local n=p:get_player_name();joins[n]=(joins[n] or 0)+1
 core.log('action','EXPEDITION_QA_JOIN '..n..' peer='..core.write_json(core.get_player_information(n)))
 core.after(2,run)
end)
core.register_on_leaveplayer(function(p) local n=p:get_player_name();leaves[n]=(leaves[n] or 0)+1;core.log('action','EXPEDITION_QA_LEAVE '..n) end)
core.after(150,function() error('EXPEDITION_QA_FAIL real two-client timeout') end)
