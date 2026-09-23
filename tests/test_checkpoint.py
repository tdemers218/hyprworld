import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('checkpoint',Path(__file__).resolve().parents[1]/'checkpoint.py')
checkpoint=importlib.util.module_from_spec(spec);spec.loader.exec_module(checkpoint)

class CheckpointTest(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.path=Path(self.temp.name)/'layout.json'
    def state(self,value):
        return {'version':1,'scope':'session','workspaces':{'workspace:1':{'camera':[value,0,0,0],'windows':[]}}}
    def test_atomic_history_and_idle_deduplication(self):
        for value in (1,2,3,4):self.assertTrue(checkpoint.save(self.path,self.state(value)))
        before=self.path.stat().st_mtime_ns
        self.assertFalse(checkpoint.save(self.path,self.state(4)))
        self.assertEqual(self.path.stat().st_mtime_ns,before)
        for suffix,value in (('',4),('.1',3),('.2',2)):
            self.assertEqual(json.loads(Path(str(self.path)+suffix).read_text()),self.state(value))
        self.assertEqual(self.path.stat().st_mode&0o777,0o600)
    def test_failed_replace_preserves_previous_checkpoint(self):
        checkpoint.save(self.path,self.state(1));previous=self.path.read_bytes()
        with patch.object(checkpoint.os,'replace',side_effect=OSError('disk error')):
            with self.assertRaises(OSError):checkpoint.save(self.path,self.state(2))
        self.assertEqual(self.path.read_bytes(),previous)
        self.assertEqual(list(self.path.parent.glob('.checkpoint-*')),[])
    def test_corrupt_latest_does_not_replace_good_history(self):
        checkpoint.save(self.path,self.state(1));checkpoint.save(self.path,self.state(2))
        self.path.write_text('broken')
        checkpoint.save(self.path,self.state(3))
        self.assertEqual(json.loads(Path(str(self.path)+'.1').read_text()),self.state(1))
    def test_invalid_and_oversized_state_is_rejected(self):
        with self.assertRaises(ValueError):checkpoint.save(self.path,{'version':2})
        data=self.state(1);data['padding']='x'*(1024*1024)
        with self.assertRaises(ValueError):checkpoint.save(self.path,data)
        self.assertFalse(self.path.exists())
