import subprocess, os, time
import sys, json, tempfile, shutil
from pathlib import Path
instance=sys.argv[1]
assert 'HWTEST' in subprocess.check_output(['hyprctl','-i',instance,'-j','monitors'],text=True)
instances=json.loads(subprocess.check_output(['hyprctl','instances','-j'],text=True))
socket=next(i['wl_socket'] for i in instances if i['instance']==instance)
staging=tempfile.TemporaryDirectory(prefix='hyprworld-overlay-')
root=Path(__file__).resolve().parent.parent
shutil.copy2(root/'OverlayState.qml',Path(staging.name)/'OverlayState.qml')
(Path(staging.name)/'shell.qml').write_text((root/'tests/live_overlay.qml').read_text().replace('import ".." as Plugin','import "." as Plugin'))
env=dict(os.environ,WAYLAND_DISPLAY=socket,HYPRLAND_INSTANCE_SIGNATURE=instance)
log=open('/tmp/hyprworld-overlay-test.log','w')
qs=subprocess.Popen(['qs','-p',staging.name],env=env,stdout=log,stderr=log)
windows=[]
def active():
 r=subprocess.run(['qs','-p',staging.name,'ipc','call','overlayTest','active'],capture_output=True,text=True,env=env)
 return r.stdout.strip()
def wait_for(value):
 for _ in range(40):
  if active()==value: return
  time.sleep(.1)
 raise AssertionError((value,active(),open('/tmp/hyprworld-overlay-test.log').read()))
try:
 wait_for('false')
 for _ in range(2):
  windows.append(subprocess.Popen(['kitty','--config','NONE','--class','org.omarchy.screensaver','-e','sleep','60'],env=env,stdout=log,stderr=log))
 wait_for('true')
 windows.pop().terminate()
 time.sleep(.25)
 wait_for('true')
 windows.pop().terminate()
 wait_for('false')
 print('PASS: real screensaver windows hide overlays; closing one of two keeps them hidden; closing last restores visibility')
finally:
 for p in windows: p.terminate()
 qs.terminate(); qs.wait(timeout=5)
 staging.cleanup()
