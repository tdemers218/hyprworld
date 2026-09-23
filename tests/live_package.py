"""Fresh-package smoke test. Starts its own isolated compositor and temporary home."""
import subprocess,json,os,time,tempfile,shutil
from pathlib import Path
source=Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='hyprworld-package-') as temp:
 home=Path(temp);plugin=home/'.config/omarchy/plugins/io.github.tdemers218.hyprworld'
 shutil.copytree(source,plugin,ignore=shutil.ignore_patterns('.git','__pycache__'))
 shell=home/'.config/omarchy'
 (shell/'Commons').symlink_to('/usr/share/omarchy/shell/Commons');(shell/'Ui').symlink_to('/usr/share/omarchy/shell/Ui')
 (shell/'shell.qml').write_text('import QtQuick\nimport Quickshell\nimport Quickshell.Io\nimport "plugins/io.github.tdemers218.hyprworld" as Plugin\nShellRoot { Plugin.Service { id: service } IpcHandler { target: "previewTest"; function snapshot(): string { return JSON.stringify(service.children[0].snapshot) } function gesture(): string { return JSON.stringify(service.children[0].gestureFrame) } } }\n')
 config=home/'hyprland.lua';config.write_text('hl.monitor({output="",mode="1440x960@60",position="0x0",scale=1})\nhl.config({misc={disable_hyprland_logo=true,disable_splash_rendering=true}})\no={bind=function(k,d,a,opts) if type(a)=="string" then a=hl.dsp.exec_cmd(a) end;return hl.bind(k,a,opts or {description=d}) end}\n')
 env=dict(os.environ,HOME=str(home),XDG_CONFIG_HOME=str(home/'.config'),XDG_CACHE_HOME=str(home/'.cache'),XDG_STATE_HOME=str(home/'.local/state'),AQ_BACKEND='headless')
 log=open('/tmp/hyprworld-fresh-package.log','w');compositor=subprocess.Popen(['Hyprland','--config',str(config)],env=env,stdout=log,stderr=log);qs=None
 try:
  instance=None
  for _ in range(70):
   instance=next((i for i in json.loads(subprocess.check_output(['hyprctl','instances','-j'],text=True,timeout=5)) if i['pid']==compositor.pid),None)
   if instance:break
   time.sleep(.1)
  assert instance
  env.update(WAYLAND_DISPLAY=instance['wl_socket'],HYPRLAND_INSTANCE_SIGNATURE=instance['instance'])
  def ctl(*args):return subprocess.check_output(['hyprctl','-i',instance['instance'],*args],text=True,timeout=5).strip()
  def wait_loaded():
   deadline=time.monotonic()+140
   while time.monotonic()<deadline:
    if ctl('repl','return __hyprworld_plugin_loaded == true')=='true':return
    assert compositor.poll() is None and qs.poll() is None, 'test process exited; inspect /tmp/hyprworld-fresh-package.log'
    time.sleep(.1)
   raise AssertionError('bootstrap did not finish; inspect /tmp/hyprworld-fresh-package.log')
  qs=subprocess.Popen(['qs','-p',str(shell)],env=env,stdout=log,stderr=log)
  wait_loaded()
  assert ctl('repl','return __hyprworld_plugin_loaded == true')=='true'
  assert ctl('repl','return type(__hyprworld_preview)')=='function'
  assert not ctl('configerrors'),ctl('configerrors')
  assert ctl('repl','return type(hl.plugin.hyprworld_shared)')=='table'
  # Send actual large Lua-produced frames through the real (1024-byte-limited)
  # event socket and verify that the Service's QML receiver reassembles them.
  fixture=subprocess.check_output(['lua','tests/with-preferences.lua','tests/hyprland_adapter.lua'],cwd=source,
      env=dict(env,HYPRWORLD_TEST_PREVIEW_EVENTS='1'),text=True,timeout=10)
  messages=[line for line in fixture.splitlines() if line.startswith('hyprworld-preview-part,')]
  first_key=messages[0].split(',')[2]
  frame=[message for message in messages if message.split(',')[2]==first_key]
  # Bootstrap completion can precede the shell's event socket connection.
  deadline=time.monotonic()+5
  while True:
   assert ctl('eval','for _,message in ipairs({'+','.join(json.dumps(m,ensure_ascii=False) for m in frame)+'}) do hl.dispatch(hl.dsp.event(message)) end')=='ok'
   time.sleep(.05)
   received=json.loads(subprocess.check_output(['qs','-p',str(shell),'ipc','call','previewTest','snapshot'],env=env,text=True,timeout=5))
   if any(t.get('address')=='0xA' for t in received.get('tiles',[])):break
   assert time.monotonic()<deadline, received
  assert next(t for t in received['tiles'] if t['address']=='0xA')['title']=='雪😀, title '*220
  print('PASS: large Unicode preview reassembled through real Hyprland events into QML',flush=True)
  subprocess.run(['qs','-p',str(shell),'ipc','call','hyprworld','openCustomizer'],env=env,check=True,capture_output=True,timeout=5)
  time.sleep(.4)
  layers=ctl('-j','layers');assert 'hyprworld-customizer' in layers,layers
  subprocess.run(['qs','-p',str(shell),'ipc','call','hyprworld','closeCustomizer'],env=env,check=True,capture_output=True,timeout=5)
  prefs=home/'.config/omarchy/hyprworld.json';assert json.loads(prefs.read_text())=={}
  print('PASS: fresh public-ID package boots full Service, Lua layout, preferences and settings',flush=True)
  prefs.write_text('{"plugin":{"enabled":false}}');ctl('reload');wait_loaded()
  assert ctl('repl','return __hyprworld_enabled')=='false'
  prefs.write_text('{}');ctl('reload');wait_loaded()
  assert ctl('repl','return __hyprworld_enabled')=='true'
  assert ctl('repl','return type(hl.plugin.hyprworld_shared)')=='table'
  print('PASS: fresh package disables and re-enables across config reload',flush=True)
  # Exercise the user's manual config loader as well as Service-only startup.
  # Its declaration must keep the same native handle across every reload.
  native_path=ctl('repl','return __hyprworld_native_path')
  config.write_text(config.read_text()+'\n__hyprworld_native_path='+json.dumps(native_path)+'; dofile('+json.dumps(str(plugin/'integration/plugin.lua'))+')\n')
  assert ctl('reload')=='ok';wait_loaded()
  native_handle=json.loads(ctl('-j','plugin','list'))[0]['handle']
  reload_times=[]
  for _ in range(12):
   start=time.monotonic();assert ctl('reload')=='ok';wait_loaded()
   assert ctl('repl','return type(hl.plugin.hyprworld_shared.set_enabled)')=='function'
   assert not ctl('configerrors'),ctl('configerrors')
   assert json.loads(ctl('-j','plugin','list'))[0]['handle']==native_handle,'reload unloaded and reloaded the native hook'
   reload_times.append(time.monotonic()-start)
  print('PASS: 12 repeated reloads; worst recovery %.3fs'%max(reload_times),flush=True)
  ctl('output','create','headless','HWTEST')
  subprocess.run(['python3',str(source/'tests/live_checkpoint.py'),instance['instance']],env=env,check=True,timeout=60)
  subprocess.run(['python3',str(source/'tests/live_drag.py'),instance['instance'],str(shell)],env=env,check=True,timeout=60)
  for test in ('live_workspace_swap.py','live_workspace_windows.py','live_overlay.py'):
   subprocess.run(['python3',str(source/'tests'/test),instance['instance']],env=env,check=True,timeout=100)
  print('native plugins before removal:',ctl('plugin','list'),flush=True)
  print('native API:',ctl('repl','return type(hl.plugin.hyprworld_shared)'),flush=True)
  qs.terminate();qs.wait(timeout=5);qs=None
  config.write_text(config.read_text().split('\n__hyprworld_native_path=')[0])
  ctl('reload')
  result=ctl('plugin','unload',native_path);print('unload:',result,flush=True)
  assert 'not loaded' not in result.lower(),result
  assert ctl('repl','return type(hl.plugin.hyprworld_shared)')=='nil'
  ctl('reload');time.sleep(.2)
  assert ctl('repl','return type(__hyprworld_preview)')=='nil'
  print('PASS: native unload and config reload remove integration',flush=True)
 finally:
  if qs:qs.terminate();qs.wait(timeout=5)
  compositor.terminate();compositor.wait(timeout=10)
