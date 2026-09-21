from live_helpers import *

ctl('eval','hl.monitor({output="HWTEST",mode="1280x720@60",position="1280x0",scale=1})')
dispatch('hl.dsp.focus({monitor="WAYLAND-1"})')
dispatch('hl.dsp.focus({workspace="1"})')
dispatch('hl.dsp.focus({monitor="HWTEST"})')
dispatch('hl.dsp.focus({workspace="2"})')
state(1,2,'HWTEST')
dispatch('hl.dsp.focus({workspace="1"})')
state(2,1,'HWTEST')
# Rapid requests hit the same native action.
for _ in range(12):
 dispatch('hl.dsp.focus({workspace="2"})'); state(1,2,'HWTEST')
 dispatch('hl.dsp.focus({workspace="1"})'); state(2,1,'HWTEST')
# Monitor focus must not swap.
dispatch('hl.dsp.focus({monitor="WAYLAND-1"})'); state(2,1,'WAYLAND-1')
# Vertical + negative placement, then direct workspace request.
ctl('eval','hl.monitor({output="HWTEST",mode="1280x720@60",position="-100x-800",scale=1})')
dispatch('hl.dsp.focus({workspace="1"})'); state(1,2,'WAYLAND-1')
# Non-visible workspace from the other monitor is brought here, not swapped.
dispatch('hl.dsp.focus({monitor="HWTEST"})')
dispatch('hl.dsp.focus({workspace="20"})')
dispatch('hl.dsp.focus({workspace="21"})')
dispatch('hl.dsp.focus({monitor="WAYLAND-1"})')
dispatch('hl.dsp.focus({workspace="20"})'); state(20,21,'WAYLAND-1')
print('PASS: numeric swaps, rapid reversal, monitor focus, vertical/negative positions, remote inactive workspace, unbounded IDs')

for position in ['1280x0','-1280x0','0x800','0x-800','-1280x-800']:
 ctl('eval','hl.monitor({output="WAYLAND-1",mode="preferred",position="0x0",scale=1}); hl.monitor({output="HWTEST",mode="1280x720@60",position="'+position+'",scale=1})')
 time.sleep(.15)
 dispatch('hl.dsp.focus({monitor="WAYLAND-1"})')
 time.sleep(.8)
 m=monitors(); a=m['WAYLAND-1']; b=m['HWTEST']
 dx=b['x']-a['x']; dy=b['y']-a['y']
 target=b['activeWorkspace']['id']
 command='hl.dispatch(hl.dsp.focus({workspace="'+str(target)+'"})); local s=hl.plugin.hyprworld_shared.inspect(); '
 command+=f'assert(math.abs(s["WAYLAND-1"].x-({dx}))<1 and math.abs(s["WAYLAND-1"].y-({dy}))<1,"incoming vector"); '
 command+=f'assert(math.abs(s["HWTEST"].x-({-dx}))<1 and math.abs(s["HWTEST"].y-({-dy}))<1,"outgoing vector"); '
 command+='assert(s["WAYLAND-1"].goal_x==0 and s["WAYLAND-1"].goal_y==0)'
 out=ctl('eval',command)
 assert out.strip()=='ok',out
 time.sleep(.8)
 out=ctl('eval','local s=hl.plugin.hyprworld_shared.inspect(); assert(math.abs(s["WAYLAND-1"].x)<1 and math.abs(s["WAYLAND-1"].y)<1,"animation did not settle")')
 assert out.strip()=='ok',out
print('PASS: real native animation vectors and completion for right, left, below, above and diagonal monitors')

# Disabling the shell plugin restores native workspace request semantics.
ctl('eval','hl.plugin.hyprworld_shared.set_enabled(false)')
dispatch('hl.dsp.focus({monitor="WAYLAND-1"})')
dispatch('hl.dsp.focus({workspace="71"})')
dispatch('hl.dsp.focus({monitor="HWTEST"})')
dispatch('hl.dsp.focus({workspace="72"})')
dispatch('hl.dsp.focus({workspace="71"})')
assert monitors()['WAYLAND-1']['activeWorkspace']['id']==71
ctl('eval','hl.plugin.hyprworld_shared.set_enabled(true)')
print('PASS: disabled helper restores native workspace request behavior')
