"""Fresh-package smoke test. Starts its own isolated compositor and temporary home."""
import subprocess,json,os,time,tempfile,shutil
from pathlib import Path
source=Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='hyprworld-package-') as temp:
 home=Path(temp);plugin=home/'.config/omarchy/plugins/io.github.tdemers218.hyprworld'
 shutil.copytree(source,plugin,ignore=shutil.ignore_patterns('.git','__pycache__'))
 shell=home/'.config/omarchy'
 (shell/'Commons').symlink_to('/usr/share/omarchy/shell/Commons');(shell/'Ui').symlink_to('/usr/share/omarchy/shell/Ui')
 (shell/'shell.qml').write_text('import QtQuick\nimport Quickshell\nimport "plugins/io.github.tdemers218.hyprworld" as Plugin\nShellRoot { Plugin.Service {} }\n')
 config=home/'hyprland.lua';config.write_text('hl.monitor({output="",mode="1440x960@60",position="0x0",scale=1})\nhl.config({misc={disable_hyprland_logo=true,disable_splash_rendering=true}})\no={bind=function(k,d,a,opts) if type(a)=="string" then a=hl.dsp.exec_cmd(a) end;return hl.bind(k,a,opts or {description=d}) end}\n')
 env=dict(os.environ,HOME=str(home),XDG_CONFIG_HOME=str(home/'.config'),AQ_BACKEND='headless')
 log=open('/tmp/hyprworld-fresh-package.log','w');compositor=subprocess.Popen(['Hyprland','--config',str(config)],env=env,stdout=log,stderr=log);qs=None
 try:
  instance=None
  for _ in range(70):
   instance=next((i for i in json.loads(subprocess.check_output(['hyprctl','instances','-j'],text=True)) if i['pid']==compositor.pid),None)
   if instance:break
   time.sleep(.1)
  assert instance
  env.update(WAYLAND_DISPLAY=instance['wl_socket'],HYPRLAND_INSTANCE_SIGNATURE=instance['instance'])
  def ctl(*args):return subprocess.check_output(['hyprctl','-i',instance['instance'],*args],text=True).strip()
  qs=subprocess.Popen(['qs','-p',str(shell)],env=env,stdout=log,stderr=log)
  for _ in range(50):
   if ctl('repl','return __hyprworld_plugin_loaded == true')=='true':break
   time.sleep(.1)
  assert ctl('repl','return __hyprworld_plugin_loaded == true')=='true'
  assert ctl('repl','return type(__hyprworld_preview)')=='function'
  assert not ctl('configerrors'),ctl('configerrors')
  assert ctl('repl','return type(hl.plugin.hyprworld_shared)')=='table'
  subprocess.run(['qs','-p',str(shell),'ipc','call','hyprworld','openCustomizer'],env=env,check=True,capture_output=True)
  time.sleep(.4)
  layers=ctl('-j','layers');assert 'hyprworld-customizer' in layers,layers
  prefs=home/'.config/omarchy/hyprworld.json';assert json.loads(prefs.read_text())=={}
  print('PASS: fresh public-ID package boots full Service, Lua layout, preferences and settings',flush=True)
  prefs.write_text('{"plugin":{"enabled":false}}');ctl('reload');time.sleep(.8)
  assert ctl('repl','return __hyprworld_enabled')=='false'
  prefs.write_text('{}');ctl('reload');time.sleep(.8)
  assert ctl('repl','return __hyprworld_enabled')=='true'
  assert ctl('repl','return type(hl.plugin.hyprworld_shared)')=='table'
  print('PASS: fresh package disables and re-enables across config reload',flush=True)
  print('native plugins before removal:',ctl('plugin','list'),flush=True)
  print('native API:',ctl('repl','return type(hl.plugin.hyprworld_shared)'),flush=True)
  qs.terminate();qs.wait(timeout=5);qs=None
  result=ctl('plugin','unload',str(plugin/'native/build/shared-workspaces.so'));print('unload:',result,flush=True)
  assert 'not loaded' not in result.lower(),result
  assert ctl('repl','return type(hl.plugin.hyprworld_shared)')=='nil'
  ctl('reload');time.sleep(.2)
  assert ctl('repl','return type(__hyprworld_preview)')=='nil'
  print('PASS: native unload and config reload remove integration',flush=True)
 finally:
  if qs:qs.terminate();qs.wait(timeout=5)
  compositor.terminate();compositor.wait(timeout=10)
