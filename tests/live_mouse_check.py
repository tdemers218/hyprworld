import json, subprocess, time

def ctl(*args):
    p = subprocess.run(['hyprctl', *args], capture_output=True, text=True)
    if p.returncode: raise RuntimeError(p.stdout + p.stderr)
    return p.stdout

def ev(code): return ctl('eval', code)
def active(): return json.loads(ctl('-j', 'activewindow'))
def move(x,y): ev(f'hl.dispatch(hl.dsp.cursor.move({{x={x},y={y}}}))')
def option(): return ctl('getoption', 'input:follow_mouse').splitlines()[0]
def focus(address): ev('hl.dispatch(hl.dsp.focus({window="address:'+address+'"})); hl.dispatch(hl.dsp.layout("center"))')
def neighbor():
    a=active(); m=next(m for m in json.loads(ctl('-j','monitors')) if m['id']==a['monitor'])
    for c in json.loads(ctl('-j','clients')):
        if c['address']==a['address'] or c['workspace']['id']!=a['workspace']['id']: continue
        x0=max(c['at'][0]+8,m['x']+8); x1=min(c['at'][0]+c['size'][0]-8,m['x']+m['width']/m['scale']-8)
        y0=max(c['at'][1]+8,m['y']+40); y1=min(c['at'][1]+c['size'][1]-8,m['y']+m['height']/m['scale']-8)
        if x1>x0 and y1>y0:return c,(x0+x1)/2,(y0+y1)/2
    raise RuntimeError('No visible neighboring tile')

original=active()['address']; pos=json.loads(ctl('-j','cursorpos'))
try:
    time.sleep(.7)
    c,x,y=neighbor(); before=active()['address']; move(x,y)
    first=active()['address']; print('first hover changed focus:',first!=before,'mode:',option(),flush=True)
    assert first!=before and option()=='int: 2'
    time.sleep(.2)
    c,x,y=neighbor();move(x,y)
    assert active()['address']==first, 'hover escaped cooldown'
    print('second hover suppressed',flush=True)
    ev('hl.dispatch(hl.dsp.layout("focus right"))')
    a=active();m=next(m for m in json.loads(ctl('-j','monitors')) if m['focused']);assert a['monitor']==m['id']
    time.sleep(.65)
    assert option()=='int: 1'
    print('hover mode restored after expiry; keyboard monitor consistent',flush=True)
finally:
    time.sleep(.6)
    move(pos['x'],pos['y']);focus(original)
print('config errors:',ctl('configerrors').strip())
