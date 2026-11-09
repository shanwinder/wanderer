from pathlib import Path
import ctypes,hashlib,json,platform,subprocess,sys
out=Path(sys.argv[1]); out.mkdir(parents=True,exist_ok=True)
minimal=out.parent/'minimal';minimal.mkdir(exist_ok=True)
(minimal/'project.godot').write_text('config_version=5\n[application]\nconfig/name="B1 environment probe"\n')
(minimal/'probe.gd').write_text('extends SceneTree\nfunc _initialize() -> void:\n\tprint("MINIMAL_PROBE_OK")\n\tquit(0)\n')
security=ctypes.CDLL('/System/Library/Frameworks/Security.framework/Security')
cf=ctypes.CDLL('/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation')
security.SecTrustCopyAnchorCertificates.argtypes=[ctypes.POINTER(ctypes.c_void_p)];security.SecTrustCopyAnchorCertificates.restype=ctypes.c_int32
anchors=ctypes.c_void_p(); status=security.SecTrustCopyAnchorCertificates(ctypes.byref(anchors))
count=None
if status==0 and anchors:
 cf.CFArrayGetCount.argtypes=[ctypes.c_void_p];cf.CFArrayGetCount.restype=ctypes.c_long
 count=cf.CFArrayGetCount(anchors);cf.CFRelease.argtypes=[ctypes.c_void_p];cf.CFRelease(anchors)
binary='/Applications/Godot.app/Contents/MacOS/Godot'
cmd=[binary,'--headless','--path',str(minimal),'--log-file',str(out/'minimal.engine.log'),'--script','res://probe.gd']
p=subprocess.run(cmd,capture_output=True,text=True,timeout=30)
(out/'minimal.stdout.log').write_text(p.stdout);(out/'minimal.stderr.log').write_text(p.stderr)
record={'context':sys.argv[2],'macOS':platform.mac_ver()[0],'architecture':platform.machine(),'binary':binary,'binary_sha256':hashlib.sha256(Path(binary).read_bytes()).hexdigest(),'command':cmd,'exit':p.returncode,'SecTrustCopyAnchorCertificates_OSStatus':status,'anchor_count_only':count,'stdout':p.stdout,'stderr':p.stderr,'privacy':'No certificate contents, private keys, passwords, or environment variables collected.'}
(out/'results.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps(record,indent=2))
