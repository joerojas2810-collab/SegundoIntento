#!/usr/bin/env python3
"""Bounded Luanti seed matrix in disposable directories; never personal worlds."""
import argparse
import concurrent.futures
import json
import os
from pathlib import Path
import signal
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--output', type=Path, required=True, help='New empty QA directory')
p.add_argument('--cases', type=Path, required=True, help='JSON array: label, seed (null=random), optional spawn [x,z]')
p.add_argument('--jobs', type=int, default=2, choices=[1,2])
p.add_argument('--port', type=int, default=49330)
p.add_argument('--timeout', type=int, default=240)
a = p.parse_args()
a.output.mkdir(parents=True,exist_ok=True)
if any(a.output.iterdir()):
    p.error('Output must be empty; earlier evidence is never overwritten')
cases = json.loads(a.cases.read_text())
(a.output/'cases.json').write_text(json.dumps(cases,indent=2))
def execute(cmd, logfile):
    with logfile.open('w') as f:
        proc = subprocess.Popen(cmd,cwd=ROOT,stdout=f,stderr=subprocess.STDOUT,start_new_session=True)
        try:
            code = proc.wait(timeout=a.timeout)
        except subprocess.TimeoutExpired:
            os.killpg(proc.pid, signal.SIGTERM)
            try: proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(proc.pid, signal.SIGKILL); proc.wait()
            code = 'timeout'
    text = logfile.read_text()
    records = [json.loads(line.split('EVERFORGE_SEED_RESULT ',1)[1])
               for line in text.splitlines() if 'EVERFORGE_SEED_RESULT ' in line]
    return {'exit':code, 'records':records, 'log':logfile.name,
            'passed':code==0 and len(records)==1 and 'EVERFORGE_TEST_FAIL' not in text and 'ERROR[' not in text}
def run(item):
    index,case = item
    label=case['label']
    if not label or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789-' for c in label):
        raise ValueError('Unsafe case label')
    data=a.output/label
    common=['python3',str(ROOT/'tools/play_everforge.py'),'--data-dir',str(data),'--port',str(a.port+index)]
    if case.get('spawn') is not None: common+=['--spawn',*map(str,case['spawn'])]
    create=common+['--new','--test-stage','seedtest']
    if case.get('seed') is not None: create+=['--seed',str(case['seed'])]
    started=time.monotonic()
    result={'case':case,'bootstrap':execute(create,a.output/(label+'-create.log'))}
    if result['bootstrap']['passed']:
        result['restart']=execute(common+['--test-stage','seedrestart'],a.output/(label+'-restart.log'))
    result['seconds']=round(time.monotonic()-started,2)
    result['passed']=result['bootstrap']['passed'] and result.get('restart',{}).get('passed',False)
    (a.output/(label+'.json')).write_text(json.dumps(result,indent=2))
    print(json.dumps(result),flush=True)
    return result
with concurrent.futures.ThreadPoolExecutor(max_workers=a.jobs) as pool:
    results=list(pool.map(run,enumerate(cases)))
(a.output/'results.json').write_text(json.dumps(results,indent=2))
for case in cases:
    if 'repeat_of' in case:
        actual=next(r for r in results if r['case']['label']==case['label'])
        expected=next(r for r in results if r['case']['label']==case['repeat_of'])
        ar=actual['bootstrap']['records']; er=expected['bootstrap']['records']
        same=actual['passed'] and expected['passed'] and bool(ar and er) and all(ar[0][k]==er[0][k] for k in ['seed','center','arrival','digest','terrain_digest'])
        print('DETERMINISM '+case['label']+'='+str(same),flush=True)
        if not same: raise SystemExit(1)
raise SystemExit(0 if all(r['passed'] for r in results) else 1)
