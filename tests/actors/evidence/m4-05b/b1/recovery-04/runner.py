import pathlib,subprocess,hashlib,json,shutil,tempfile,platform,zipfile,re,sys,os
ROOT=pathlib.Path('/Applications/wanderer'); E=ROOT/'tests/actors/evidence/m4-05b/b1/recovery-04'; E.mkdir(exist_ok=True)
mode=sys.argv[1]; OUT=pathlib.Path(tempfile.mkdtemp(prefix='wanderer-b1-r04-'+mode+'-',dir='/private/tmp')); SNAP=OUT/'snapshot'; BIN='/Applications/Godot.app/Contents/MacOS/Godot'
shutil.copytree(ROOT,SNAP,ignore=shutil.ignore_patterns('.git','.godot','evidence','.DS_Store'))
records=[]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
context={'binary':BIN,'binary_sha256':sha(pathlib.Path(BIN)),'platform':platform.platform(),'machine':platform.machine(),'execution':'require_escalated exec, headless; not GUI Terminal','cwd':str(ROOT),'snapshot':str(SNAP),'output':str(OUT),'tested_base_sha':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'source_state':'uncommitted B1 drafts; exact bytes in manifest and archive'}
sources={str(p.relative_to(SNAP)):sha(p) for p in sorted(SNAP.rglob('*')) if p.is_file()}
(OUT/'source-sha256.json').write_text(json.dumps(sources,indent=2)+'\n');(OUT/'context.json').write_text(json.dumps(context,indent=2)+'\n')
with zipfile.ZipFile(OUT/'tested-source.zip','w',zipfile.ZIP_DEFLATED) as z:
 for p in list(SNAP.glob('scripts/m4/playable*.gd'))+[SNAP/'tests/actors/m4_05_playable_authority_proof.gd']:z.write(p,str(p.relative_to(SNAP)))
def save():
 (OUT/'results.json').write_text(json.dumps(records,indent=2)+'\n')
 dest=E/mode;dest.mkdir(exist_ok=True)
 for p in OUT.iterdir():
  if p.is_file():shutil.copy2(p,dest/p.name)
def run(name,args,expected_checks=None):
 cmd=[BIN,'--headless','--path',str(SNAP),'--log-file',str(OUT/(name+'.engine.log'))]+args
 try:
  p=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=180);code=p.returncode;stdout=p.stdout;stderr=p.stderr
 except subprocess.TimeoutExpired as ex:code=124;stdout=str(ex.stdout or '');stderr=str(ex.stderr or '')
 (OUT/(name+'.stdout.log')).write_text(stdout);(OUT/(name+'.stderr.log')).write_text(stderr);(OUT/(name+'.exit')).write_text(str(code)+'\n')
 eng=OUT/(name+'.engine.log');logs=stdout+'\n'+stderr+'\n'+(eng.read_text() if eng.exists() else '')
 errors=[line for line in logs.splitlines() if re.search(r'(SCRIPT ERROR|ERROR:|Parse Error|Assertion failed|Leaked instance|ObjectDB instances leaked)',line)]
 actual={};ok=code==0 and not errors
 if name=='version':ok=ok and stdout.strip()=='4.7.2.stable.official.ed1daf0bf'
 if expected_checks is not None:
  report=json.loads((OUT/(name+'-report.json')).read_text());actual={'checks':len(report['checks']),'failed':sum(not x['passed'] for x in report['checks']),'status':report['status']};ok=ok and actual['failed']==0 and actual['status']=='PASS' and (expected_checks<0 or actual['checks']==expected_checks)
 records.append({'gate':mode,'stage':name,'command':cmd,'exit':code,'expected':{'exit':0,'unexpected_errors':0,'checks':expected_checks},'actual':actual,'errors':errors,'status':'PASS' if ok else 'FAIL'})
 save();print(name,records[-1]['status'],code,actual,errors[:5],flush=True)
 if not ok:sys.exit(1)
run('version',['--version'])
run('import',['--editor','--import'])
for p in sorted(SNAP.glob('scripts/m4/playable*.gd')):run(p.stem,['--check-only','--script','res://'+str(p.relative_to(SNAP))])
if mode.startswith('ABC'):
 harness=SNAP/'tests/actors/m4_05_playable_authority_proof.gd';original=harness.read_bytes()
 with zipfile.ZipFile(ROOT/'tests/actors/evidence/m4-05b/b1/recovery-01/tested-source.zip') as z:harness.write_bytes(z.read('tests/actors/m4_05_playable_authority_proof.gd'))
 (OUT/'smoke-harness-sha256.txt').write_text(sha(harness)+'\n')
 run('B-original-smoke',['--script','res://tests/actors/m4_05_playable_authority_proof.gd','--','--report='+str(OUT/'B-original-smoke-report.json')],86)
 harness.write_bytes(original)
 run('C-original-expanded',['--script','res://tests/actors/m4_05_playable_authority_proof.gd','--','--report='+str(OUT/'C-original-expanded-report.json')],97)
else:
 run(mode,['--script','res://tests/actors/m4_05_playable_authority_proof.gd','--','--gate='+mode,'--report='+str(OUT/(mode+'-report.json'))],-1)
print('EVIDENCE',OUT,flush=True)
