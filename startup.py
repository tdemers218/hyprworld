#!/usr/bin/env python3
"""Launch saved workspace templates; capture never guesses executable commands."""
import argparse, fcntl, hashlib, json, os, re, subprocess, sys
from pathlib import Path

def quote(value):
    return '"' + ''.join(chr(b) if 32 <= b < 127 and b not in (34,92) else '\\%03d'%b for b in str(value).encode()) + '"'

def ctl(*args):
    p=subprocess.run(['hyprctl',*args],capture_output=True,text=True,timeout=10,check=True)
    if p.stdout.strip().lower().startswith(('error', 'warning:')): raise RuntimeError(p.stdout.strip())
    return p.stdout

def snapshot(): return json.loads(ctl('repl','return __hyprworld_preview and __hyprworld_preview() or "{}"'))

def capture():
    snap=snapshot();ws=snap.get('workspaceId',1)
    apps=[{'class':t.get('class',''),'command':'','col':t.get('col',0),'row':t.get('row',0)} for t in snap.get('tiles',[])]
    return {'name':'Workspace '+str(ws),'workspace':ws,'monitor':snap.get('monitor',''),'zoom':snap.get('zoom',1),'enabled':False,'apps':apps}

def launch(template,clients,used=None):
    workspace=int(template['workspace'])
    if not 1<=workspace<=10000: raise ValueError('Workspace must be a positive number')
    monitor=template.get('monitor','')
    monitors=json.loads(ctl('-j','monitors'))
    if monitor and any(m['name']==monitor for m in monitors):
        ctl('eval','hl.workspace_rule({workspace='+quote(workspace)+',monitor='+quote(monitor)+'})')
    used=set() if used is None else used;launched=0
    for app in template.get('apps',[]):
        cls=app.get('class','').strip();command=app.get('command','').strip()
        if not cls: raise ValueError('Every startup app needs an exact app class for duplicate detection')
        candidates=[c for c in clients if c.get('class')==cls and c['address'] not in used and c.get('mapped',True)]
        existing=next((c for c in candidates if c['workspace']['id']==workspace),next(iter(candidates),None))
        if existing:
            used.add(existing['address'])
            if existing['workspace']['id']!=workspace:
                ctl('dispatch','hl.dsp.window.move({window='+quote('address:'+existing['address'])+',workspace='+quote(workspace)+',follow=false})')
        elif command:
            ctl('dispatch','hl.dsp.exec_cmd('+quote(command)+',{workspace='+quote(str(workspace)+' silent')+'})')
            launched+=1
        else: raise ValueError('Add a launch command for '+cls+' or open it before launching this template')
    return launched

def main():
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['capture','launch','autostart']);parser.add_argument('--settings',default=str(Path.home()/'.config/omarchy/hyprworld.json'));parser.add_argument('--index',type=int,default=0)
    args=parser.parse_args()
    if args.action=='capture': print(json.dumps(capture()));return
    settings=json.loads(Path(args.settings).read_text());startup=settings.get('startup',{})
    if args.action=='autostart' and (not startup.get('enabled') or not settings.get('plugin',{}).get('enabled',True)): return
    templates=startup.get('templates',[])
    if args.action=='launch': templates=[templates[args.index]]
    runtime=Path(os.environ.get('XDG_RUNTIME_DIR','/tmp'))/('hyprworld-startup-'+str(os.getuid()))
    runtime.mkdir(mode=0o700,exist_ok=True)
    with (runtime/'lock').open('w') as lock:
        try: fcntl.flock(lock,fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            if args.action=='autostart': return
            raise RuntimeError("Another startup template is still being applied; retry shortly")
        signature=os.environ.get('HYPRLAND_INSTANCE_SIGNATURE','session')
        safe_signature=signature if re.fullmatch(r'[A-Za-z0-9_.-]{1,240}',signature) else hashlib.sha256(signature.encode()).hexdigest()
        marker=runtime/(safe_signature+'.done')
        if args.action=='autostart' and marker.exists():return
        clients=json.loads(ctl('-j','clients'));total=0;used=set()
        for template in templates:
            if args.action=='launch' or template.get('enabled',True): total+=launch(template,clients,used)
        if args.action=='autostart': marker.touch()
    print(json.dumps({'ok':True,'launched':total}))

if __name__=='__main__':
    try: main()
    except Exception as error:
        print(json.dumps({'ok':False,'error':str(error)}));sys.exit(1)
