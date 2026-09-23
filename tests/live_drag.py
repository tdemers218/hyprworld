"""Real pointer motion must update local and remote outlines faster than polling."""
from live_helpers import *
import os
shell=sys.argv[2]
apps=[]
def gesture():
 return json.loads(subprocess.check_output(['qs','-p',shell,'ipc','call','previewTest','gesture'],text=True,timeout=3))
def preview():return json.loads(ctl('repl','return __hyprworld_preview()'))
def wait_for(predicate):
 deadline=time.monotonic()+.6
 while time.monotonic()<deadline:
  value=gesture()
  if predicate(value):return value
  time.sleep(.02)
 raise AssertionError(('drag frame did not arrive within 600ms',gesture()))
try:
 for name,position in [('WAYLAND-1','0x0'),('HWTEST','1440x0')]:
  ctl('eval','hl.monitor({output="'+name+'",mode="1440x960@60",position="'+position+'",scale=1})')
 for index,name in enumerate(('WAYLAND-1','HWTEST')):
  dispatch('hl.dsp.focus({monitor="'+name+'"})');dispatch('hl.dsp.focus({workspace="'+str(91+index)+'"})')
  apps.append(subprocess.Popen(['kitty','--config','NONE','--class','hyprworld-drag-test','--title','雪 long window title '*100,'-e','sleep','60'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL))
  deadline=time.monotonic()+5
  while time.monotonic()<deadline:
   if any(c['workspace']['id']==91+index and c['class']=='hyprworld-drag-test' for c in json.loads(ctl('-j','clients'))):break
   time.sleep(.05)
 for source,dest in [('WAYLAND-1','HWTEST'),('HWTEST','WAYLAND-1')]:
  if source=='HWTEST':
   ctl('eval','hl.monitor({output="HWTEST",mode="1600x900@60",position="-1280x-100",scale=1.25})')
   time.sleep(.15)
  dispatch('hl.dsp.focus({monitor="'+source+'"})');time.sleep(.1)
  snap=preview();tile=next(t for t in snap['tiles'] if t['active']);box=tile['box']
  x,y=box['x']+box['w']/2,box['y']+box['h']/2
  dispatch('hl.dsp.cursor.move({x='+str(x)+',y='+str(y)+'})')
  dispatch('hl.dsp.layout("gesture-move")')
  positions=[]
  for index in range(1,7):
   dispatch('hl.dsp.cursor.move({x='+str(x+index*12)+',y='+str(y)+'})')
   expected=box['x']+index*12
   frame=wait_for(lambda f: abs(f.get('gesture',{}).get('ghost',{}).get('x',-1e9)-expected)<1)
   positions.append(frame['gesture']['ghost']['x'])
  layers=json.loads(ctl('-j','layers'))
  assert any(l['namespace']=='hyprworld-transfer-preview' for l in layers[source]['levels']['3'])
  time.sleep(.05)
  subprocess.run(['grim','-o',source,'/tmp/hyprworld-drag-'+source+'-local.png'],check=True,timeout=5)
  destination=monitors()[dest]
  for index in range(1,7):
   target=destination['x']+300+index*12
   dispatch('hl.dsp.cursor.move({x='+str(target)+',y='+str(destination['y']+350)+'})')
   expected=box['x']+target-x
   frame=wait_for(lambda f: abs(f.get('gesture',{}).get('ghost',{}).get('x',-1e9)-expected)<1 and f.get('gesture',{}).get('drop',{}).get('monitor')==dest)
   positions.append(frame['gesture']['ghost']['x'])
  assert len(set(positions))==12
  layers=json.loads(ctl('-j','layers'))
  assert any(l['namespace']=='hyprworld-transfer-preview' for l in layers[dest]['levels']['3'])
  time.sleep(.05)
  subprocess.run(['grim','-o',dest,'/tmp/hyprworld-drag-'+source+'-remote.png'],check=True,timeout=5)
  ctl('eval','__hyprworld_end_gesture()')
  wait_for(lambda f:not f.get('gesture'))
  print('PASS: continuous local and remote outline updates from '+source+', immediate cancellation',flush=True)
finally:
 ctl('eval','__hyprworld_end_gesture()')
 for app in apps:
  app.terminate()
  try:app.wait(timeout=3)
  except subprocess.TimeoutExpired:app.kill();app.wait(timeout=3)
