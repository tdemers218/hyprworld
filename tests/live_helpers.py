import subprocess, json, time
import sys
INSTANCE=sys.argv[1]
# Run only against an isolated compositor with this test monitor.
assert 'HWTEST' in subprocess.check_output(['hyprctl','-i',INSTANCE,'-j','monitors'],text=True,timeout=5)
def ctl(*args):
 r=subprocess.run(['hyprctl','-i',INSTANCE,*args],capture_output=True,text=True,check=True,timeout=5)
 if 'error' in r.stdout.lower(): raise RuntimeError(r.stdout)
 return r.stdout
def dispatch(expr): return ctl('dispatch',expr)
def monitors(): return {m['name']:m for m in json.loads(ctl('-j','monitors'))}
def state(a,b,focused):
 m=monitors()
 assert m['WAYLAND-1']['activeWorkspace']['id']==a,m
 assert m['HWTEST']['activeWorkspace']['id']==b,m
 assert m[focused]['focused'],m
