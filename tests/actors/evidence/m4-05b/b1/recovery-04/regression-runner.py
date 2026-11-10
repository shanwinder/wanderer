import pathlib,subprocess,tempfile,json,shutil,tarfile,io,time,sys,hashlib
ROOT=pathlib.Path('/Applications/wanderer');BASE='295dac9211486a4c2d3c5c5fa43baf065398e6a7';BIN='/Applications/Godot.app/Contents/MacOS/Godot';OUT=pathlib.Path(tempfile.mkdtemp(prefix='wanderer-b1-r04-F-',dir='/private/tmp'));SRC=OUT/'canonical';SRC.mkdir()
archive=subprocess.check_output(['git','archive',BASE],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(archive)) as t:t.extractall(SRC)
subprocess.run(['git','init','--quiet',str(SRC)],check=True)
COMMON=['--npc-proof','--actor-proof','--ownership-proof','--party-foundation-proof','--party-turn-proof','--party-playable-proof','--presentation-proof','--autonomous-main-proof']
EXTRA=['--guidance-data-proof','--guidance-decision-proof','--guidance-main-proof','--m4-data-proof','--m4-atomic-clock-proof','--m4-queue-foundation-proof','--m4-retreat-transaction-proof','--m4-outcome-summary-proof','--m4-autonomous-decision-proof']
records=[]
def run(name,source,flags):
 dest=OUT/name;cmd=['python3',str(source/'tests/combat/verify.py'),'--godot',BIN,'--output',str(dest),*flags]
 with (OUT/(name+'.stdout.log')).open('w') as stdout,(OUT/(name+'.stderr.log')).open('w') as stderr:
  p=subprocess.Popen(cmd,cwd=source,stdout=stdout,stderr=stderr)
  while p.poll() is None:
   results=dest/'results.json'
   if results.exists():
    try:r=json.loads(results.read_text())
    except json.JSONDecodeError:r=[]
    if any(x['status']!='PASS' for x in r):p.terminate();break
   time.sleep(.25)
  code=p.wait()
 r=json.loads((dest/'results.json').read_text()) if (dest/'results.json').exists() else []
 ok=code==0 and r and all(x['status']=='PASS' for x in r)
 records.append({'stage':name,'command':cmd,'cwd':str(source),'tested_base_sha':BASE,'exit':code,'stages':len(r),'status':'PASS' if ok else 'FAIL','results':str(dest/'results.json')})
 (OUT/'run-record.json').write_text(json.dumps(records,indent=2)+'\n')
 print(records[-1],flush=True)
 if not ok:sys.exit(1)
print('OUTPUT',OUT,flush=True)
run('canonical44',SRC,COMMON)
run('candidate94',ROOT,COMMON+EXTRA+['--main-cutover-proof','--cutover-baseline',str(OUT/'canonical44')])
print('COMPLETE',OUT,flush=True)
