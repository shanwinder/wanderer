import pathlib,subprocess,tempfile,json,tarfile,io,time,sys,hashlib,os,signal
ROOT=pathlib.Path('/Applications/wanderer');BASE='295dac9211486a4c2d3c5c5fa43baf065398e6a7';REFERENCE='1728c5e678c5065278d1251d50449a8820eb5dae';BIN='/Applications/Godot.app/Contents/MacOS/Godot';OUT=pathlib.Path(tempfile.mkdtemp(prefix='wanderer-b1-r05-F-',dir='/private/tmp'))
def archived_source(name,sha):
 src=OUT/name;src.mkdir();data=subprocess.check_output(['git','archive',sha],cwd=ROOT)
 with tarfile.open(fileobj=io.BytesIO(data)) as t:t.extractall(src)
 subprocess.run(['git','init','--quiet',str(src)],check=True)
 manifest={str(p.relative_to(src)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(src.rglob('*')) if p.is_file() and '.git' not in p.relative_to(src).parts}
 (OUT/(name+'-sha256.json')).write_text(json.dumps({'commit':sha,'files':manifest},indent=2)+'\n');return src
REF_SRC=archived_source('reference-source',REFERENCE);BASE_SRC=archived_source('canonical-source',BASE)
COMMON=['--npc-proof','--actor-proof','--ownership-proof','--party-foundation-proof','--party-turn-proof','--party-playable-proof','--presentation-proof','--autonomous-main-proof']
EXTRA=['--guidance-data-proof','--guidance-decision-proof','--guidance-main-proof','--m4-data-proof','--m4-atomic-clock-proof','--m4-queue-foundation-proof','--m4-retreat-transaction-proof','--m4-outcome-summary-proof','--m4-autonomous-decision-proof','--main-cutover-proof','--cutover-baseline',str(OUT/'reference44')]
records=[]
def run(name,source,sha,flags,expected):
 dest=OUT/name;cmd=['python3',str(source/'tests/combat/verify.py'),'--godot',BIN,'--output',str(dest),*flags]
 with (OUT/(name+'.stdout.log')).open('w') as stdout,(OUT/(name+'.stderr.log')).open('w') as stderr:
  p=subprocess.Popen(cmd,cwd=source,stdout=stdout,stderr=stderr,start_new_session=True)
  while p.poll() is None:
   results=dest/'results.json'
   if results.exists():
    try:r=json.loads(results.read_text())
    except json.JSONDecodeError:r=[]
    if any(x['status']!='PASS' for x in r):os.killpg(p.pid,signal.SIGTERM);break
   time.sleep(.25)
  code=p.wait()
 r=json.loads((dest/'results.json').read_text()) if (dest/'results.json').exists() else []
 ok=code==0 and len(r)==expected and all(x['status']=='PASS' for x in r)
 records.append({'stage':name,'command':cmd,'cwd':str(source),'source_commit':sha,'binary':BIN,'binary_sha256':hashlib.sha256(pathlib.Path(BIN).read_bytes()).hexdigest(),'exit':code,'stages':len(r),'expected_stages':expected,'status':'PASS' if ok else 'FAIL','results':str(dest/'results.json')})
 (OUT/'run-record.json').write_text(json.dumps(records,indent=2)+'\n');print(json.dumps(records[-1]),flush=True)
 if not ok:sys.exit(1)
print('OUTPUT',OUT,flush=True)
run('reference44',REF_SRC,REFERENCE,COMMON,44)
run('canonical94',BASE_SRC,BASE,COMMON+EXTRA,94)
run('candidate94',ROOT,subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()+' plus B1 manifest',COMMON+EXTRA,94)
base=json.loads((OUT/'canonical94/presentation-traces.json').read_text());candidate=json.loads((OUT/'candidate94/presentation-traces.json').read_text());assert base['traces']==candidate['traces']
(OUT/'current-canonical-comparison.json').write_text(json.dumps({'result':'PASS','cases':len(base['traces']),'frames':sum(len(x['frames']) for x in base['traces']),'expected':'Exact candidate/current canonical Legacy trace equality; separate from historical cutover reference'},indent=2)+'\n')
print('COMPLETE',OUT,flush=True)
