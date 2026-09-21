import importlib.util, unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('startup',Path(__file__).resolve().parent.parent/'startup.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class StartupTests(unittest.TestCase):
 def test_reuses_existing_and_launches_missing(self):
  calls=[]
  def ctl(*args):
   calls.append(args)
   return '[]' if args==('-j','monitors') else 'ok'
  m.ctl=ctl
  template={'workspace':3,'apps':[{'class':'kitty','command':'kitty'},{'class':'browser','command':'browser'}]}
  clients=[{'class':'kitty','address':'0x123','workspace':{'id':1}}]
  self.assertEqual(m.launch(template,clients),1)
  self.assertTrue(any('window.move' in c[-1] and '0x123' in c[-1] for c in calls))
  self.assertTrue(any('exec_cmd' in c[-1] and '3 silent' in c[-1] for c in calls))
  self.assertFalse(any('exec_cmd("kitty"' in c[-1] for c in calls))
 def test_repeated_app_slots_reuse_distinct_windows(self):
  calls=[];m.ctl=lambda *args: calls.append(args) or ('[]' if args==('-j','monitors') else 'ok')
  template={'workspace':1,'apps':[{'class':'kitty','command':'kitty'},{'class':'kitty','command':'kitty'}]}
  clients=[{'class':'kitty','address':'0x1','workspace':{'id':1}}]
  self.assertEqual(m.launch(template,clients),1)
 def test_prefers_existing_destination_window(self):
  calls=[];m.ctl=lambda *args:calls.append(args) or ('[]' if args==('-j','monitors') else 'ok')
  clients=[{'class':'kitty','address':'0x1','workspace':{'id':1}}, {'class':'kitty','address':'0x2','workspace':{'id':3}}]
  self.assertEqual(m.launch({'workspace':3,'apps':[{'class':'kitty','command':'kitty'}]},clients),0)
  self.assertFalse(any('window.move' in c[-1] for c in calls))
 def test_capture_never_guesses_commands(self):
  m.snapshot=lambda:{'workspaceId':1,'tiles':[{'class':'terminal','col':2,'row':0}]}
  self.assertEqual(m.capture()['apps'][0]['command'],'')
 def test_quote_cannot_escape_lua_string(self):
  self.assertEqual(m.quote('"\\\n'), '"\\034\\092\\010"')
  self.assertNotIn('";os.execute',m.quote('";os.execute("test")'))
if __name__=='__main__':unittest.main()
