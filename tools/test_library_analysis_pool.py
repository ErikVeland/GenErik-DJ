import json
import pathlib
import tempfile
import unittest
from run_library_analysis_pool import make_plan, publish_result, run


class PoolTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        self.output = self.root / 'output'
        (self.output / 'results').mkdir(parents=True)
        self.manifest = self.root / 'manifest.json'
        self.manifest.write_text(json.dumps(dict(items=[dict(id=str(i), paths=['source']) for i in range(9)])))

    def test_workers_get_disjoint_items_and_resume_the_frozen_plan(self):
        profile = dict(generation=14, decisionPolicy=14)
        (self.output / 'results/0.json').write_text(json.dumps(dict(id='0', profile=profile, revisionID='saved')))
        (self.output / 'results/1.json').write_text(json.dumps(dict(id='1', profile=profile, error='identity mismatch')))
        (self.output / 'results/2.json').write_text(json.dumps(dict(id='2', profile=profile)))
        plan = make_plan(self.manifest, self.output, 4)
        assigned = [identifier for shard in plan['shards'] for identifier in shard['ids']]
        self.assertEqual(sorted(assigned), [str(i) for i in range(2, 9)])
        self.assertEqual(len(assigned), len(set(assigned)))
        self.assertEqual(make_plan(self.manifest, self.output, 4), plan)
        with self.assertRaises(RuntimeError):
            make_plan(self.manifest, self.output, 3)

    def test_partial_or_failed_worker_cannot_replace_a_successful_recovery(self):
        work = self.root / 'worker'
        (work / 'results').mkdir(parents=True)
        path = work / 'results/7.json'
        path.write_text(json.dumps(dict(id='7')))
        self.assertFalse(publish_result(work, self.output, path))
        good = dict(id='7', revisionID='verified')
        (self.output / 'results/7.json').write_text(json.dumps(good))
        path.write_text(json.dumps(dict(id='7', error='old failure')))
        self.assertTrue(publish_result(work, self.output, path))
        self.assertEqual(json.loads((self.output / 'results/7.json').read_text()), good)

    def test_changed_inventory_is_rejected_on_resume(self):
        make_plan(self.manifest, self.output, 2)
        self.manifest.write_text(json.dumps(dict(items=[dict(id='different', paths=['source'])])))
        with self.assertRaises(RuntimeError):
            make_plan(self.manifest, self.output, 2)

    def test_parallel_processes_publish_every_item_and_resume_without_rerunning(self):
        app = self.root / 'analyser'
        app.write_text('''#!/usr/bin/env python3
import json,pathlib,sys
items=json.loads(pathlib.Path(sys.argv[2]).read_text())['items']
root=pathlib.Path(sys.argv[3]);(root/'results').mkdir(parents=True,exist_ok=True)
for index,item in enumerate(items):
 (root/'results'/(item['id']+'.json')).write_text(json.dumps(dict(id=item['id'],error='Test source is unavailable.')))
 print('2026-11-10T00:00:00Z '+str(index+1)+'/'+str(len(items))+' Test track',flush=True)
(root/'finished.txt').write_text('done')
''')
        app.chmod(0o755)
        run(str(app), self.manifest, self.output, 3)
        self.assertEqual(len(list((self.output / 'results').glob('*.json'))), 9)
        logs = {p:p.read_bytes() for p in (self.output / 'pool').glob('worker-*/run.log')}
        run(str(app), self.manifest, self.output, 3)
        self.assertEqual(logs, {p:p.read_bytes() for p in logs})


if __name__ == '__main__':
    unittest.main()
