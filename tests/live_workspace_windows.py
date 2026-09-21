from live_helpers import *
from pathlib import Path
ROOT=str(Path(__file__).resolve().parent.parent)
import os
log=open('/tmp/hyprworld-window-test.log','w')
instances=json.loads(subprocess.check_output(['hyprctl','instances','-j'],text=True))
socket=next(i['wl_socket'] for i in instances if i['instance']==INSTANCE)
env=dict(os.environ,WAYLAND_DISPLAY=socket,HYPRLAND_INSTANCE_SIGNATURE=INSTANCE)
windows=[]
def clients(): return json.loads(ctl('-j','clients'))
try:
 ctl('eval','dofile("'+ROOT+'/layout/init.lua"); __testnav=dofile("'+ROOT+'/integration/workspaces.lua").install(hl,{bind=function(k,d,a) hl.bind(k,a,{description=d}) end})')
 for name,workspace in [('WAYLAND-1',31),('HWTEST',32)]:
  dispatch('hl.dsp.focus({monitor="'+name+'"})')
  dispatch('hl.dsp.focus({workspace="'+str(workspace)+'"})')
  windows.append(subprocess.Popen(['kitty','--config','NONE','--class','hyprworld-swap-test-'+str(workspace),'-e','sleep','90'],env=env,stdout=log,stderr=log))
  for _ in range(30):
   if any(c['class']=='hyprworld-swap-test-'+str(workspace) for c in clients()): break
   time.sleep(.1)
 time.sleep(.5)
 for w in json.loads(ctl('-j','workspaces')):
  if w['id'] in (31,32): assert w['tiledLayout']=='lua:hyprworld',w
 before={c['address']:c['workspace']['id'] for c in clients()}
 ctl('eval','__testnav.step(-1)')
 state(32,31,'HWTEST')
 time.sleep(.8)
 after=clients()
 assert {c['address']:c['workspace']['id'] for c in after}==before,(before,after)
 for c in after:
  if c['class'].startswith('hyprworld-swap-test-'):
   monitor=next(m for m in monitors().values() if m['id']==c['monitor'])
   assert c['workspace']['id']==monitor['activeWorkspace']['id'],c
   x,y=c['at'];w,h=c['size']
   assert x+w>monitor['x'] and x<monitor['x']+monitor['width']/monitor['scale'],c
   assert y+h>monitor['y'] and y<monitor['y']+monitor['height']/monitor['scale'],c
 print('PASS: actual terminal windows retain workspace identity, swap monitors and remain onscreen using the modded layout and navigation')
finally:
 for p in windows: p.terminate()
 for p in windows: p.wait(timeout=5)
