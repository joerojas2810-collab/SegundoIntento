from pathlib import Path
import subprocess,os,time,json
base=Path('/private/tmp/everforge-expedition-20261030')
engine='/Users/josephrojas/Downloads/luanti.app/Contents/MacOS/luanti'
clients={}; handles=[]
def client(who,stage,attempt):
 env=os.environ.copy();env['LUANTI_USER_PATH']=str(base/who)
 f=(base/f'{stage}-{who}-{attempt}-output.log').open('w');handles.append(f)
 return subprocess.Popen([engine,'--go','--address','127.0.0.1','--port','57563','--name','Expedition'+who,'--password','expedition-qa-local','--config',str(base/who/'client.conf'),'--logfile',str(base/f'{stage}-{who}-{attempt}.log')],env=env,stdout=f,stderr=subprocess.STDOUT)
try:
 for stage in ['stage1','stage2','stage3']:
  env=os.environ.copy();env['LUANTI_USER_PATH']=str(base/'user')
  out=base/f'{stage}-server-output.log';f=out.open('w');handles.append(f)
  server=subprocess.Popen([engine,'--server','--gameid','everforge','--world',str(base/'world'),'--config',str(base/'test.conf'),'--logfile',str(base/f'{stage}-server.log')],env=env,stdout=f,stderr=subprocess.STDOUT)
  start=time.monotonic();launched=False;reconnected=set();attempts={'Alice':0,'Bob':0}
  while server.poll() is None and time.monotonic()-start<170:
   log=out.read_text(errors='replace')
   if 'listening on' in log and not launched:
    for who in ['Alice','Bob']: clients[who]=client(who,stage,0)
    launched=True;print(stage+' launched two native clients',flush=True)
   for who,p in list(clients.items()):
    if p.poll() is not None and who not in reconnected and ('EXPEDITION_QA_RECONNECT '+who) in log:
     reconnected.add(who);attempts[who]+=1;clients[who]=client(who,stage,attempts[who]);print('reconnected '+who,flush=True)
   if launched and all(p.poll() is not None for p in clients.values()) and 'EXPEDITION_QA_JOIN ' not in log:
    print('Native clients exited without joining; inspect logs',flush=True);server.terminate();break
   time.sleep(.5)
  if server.poll() is None:
   server.terminate()
  try: code=server.wait(timeout=10)
  except subprocess.TimeoutExpired:server.kill();code=server.wait()
  for p in clients.values():
   if p.poll() is None:p.terminate()
  for p in clients.values():
   try:p.wait(timeout=5)
   except subprocess.TimeoutExpired:p.kill();p.wait()
  clients.clear()
  log=out.read_text(errors='replace')
  print(stage+' exit='+str(code),flush=True)
  if code or 'EXPEDITION_QA_PHASE_PASS' not in log: raise SystemExit(1)
 print('ALL_THREE_REAL_MULTIPLAYER_STAGES_PASS',flush=True)
finally:
 for p in clients.values():
  if p.poll() is None:p.terminate()
 if 'server' in globals() and server.poll() is None:server.terminate()
 for f in handles:f.close()
