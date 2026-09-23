"""Verify automatic settled checkpoints restore real windows across Lua resets."""
from live_helpers import *
import os
from pathlib import Path
apps=[]
preferences=Path.home()/'.config/omarchy/hyprworld.json'
original=preferences.read_text()
path=Path(os.environ['XDG_STATE_HOME'])/'hyprworld/layout.json'
def checkpoint():return json.loads(ctl('repl','return __hyprworld_checkpoint()'))
try:
 data=json.loads(original);data.setdefault('workflow',{})['keepConnected']=False
 preferences.write_text(json.dumps(data))
 dispatch('hl.dsp.focus({monitor="WAYLAND-1"})');dispatch('hl.dsp.focus({workspace="81"})')
 for index in range(3):
  apps.append(subprocess.Popen(['kitty','--config','NONE','--class','checkpoint-'+str(index),'-e','sleep','60'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL))
 deadline=time.monotonic()+6
 while time.monotonic()<deadline:
  clients=[c for c in json.loads(ctl('-j','clients')) if c['class'].startswith('checkpoint-')]
  if len(clients)==3:break
  time.sleep(.05)
 assert len(clients)==3
 clients.sort(key=lambda c:c['class'])
 for index,c in enumerate(clients):
  dispatch('hl.dsp.focus({window="address:'+c['address']+'"})')
  dispatch('hl.dsp.layout("move-to '+('-2 1' if index<2 else '3 -1')+'")')
 dispatch('hl.dsp.layout("resize width grow")')
 dispatch('hl.dsp.layout("zoom in")')
 expected=checkpoint()['workspaces']['workspace:81']
 assert len(expected['windows'])==3
 dispatch('hl.dsp.focus({workspace="82"})')
 apps.append(subprocess.Popen(['kitty','--config','NONE','--class','checkpoint-inactive','-e','sleep','60'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL))
 deadline=time.monotonic()+6
 while time.monotonic()<deadline:
  if any(c['class']=='checkpoint-inactive' for c in json.loads(ctl('-j','clients'))):break
  time.sleep(.05)
 dispatch('hl.dsp.layout("move-to 2 2")')
 inactive=checkpoint()['workspaces']['workspace:82']
 dispatch('hl.dsp.focus({workspace="81"})')
 deadline=time.monotonic()+8
 while time.monotonic()<deadline:
  if path.exists():
   saved=json.loads(path.read_text()).get('workspaces',{})
   if saved.get('workspace:81')==expected and saved.get('workspace:82')==inactive:break
  time.sleep(.1)
 else:raise AssertionError('settled state was not automatically checkpointed')
 stamp=path.stat().st_mtime_ns
 for _ in range(3):
  assert ctl('reload').strip()=='ok'
  deadline=time.monotonic()+5
  while time.monotonic()<deadline:
   if ctl('repl','return __hyprworld_plugin_loaded').strip()=='true':break
   time.sleep(.05)
  actual=checkpoint()['workspaces']
  assert actual['workspace:81']==expected,(expected,actual)
  assert actual['workspace:82']==inactive,(inactive,actual)
 dispatch('hl.dsp.focus({workspace="82"})')
 assert checkpoint()['workspaces']['workspace:82']==inactive
 time.sleep(2)
 assert path.stat().st_mtime_ns==stamp,'unchanged layout was rewritten after reload'
 print('PASS: settled layout auto-saved; real groups, sizes, zoom and camera survived three full Lua resets without idle rewrites',flush=True)
finally:
 preferences.write_text(original)
 for app in apps:
  app.terminate()
  try:app.wait(timeout=3)
  except subprocess.TimeoutExpired:app.kill();app.wait(timeout=3)
