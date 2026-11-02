"""Safety checks for destructive release retention, using isolated fixtures."""
import json
import importlib.util
from pathlib import Path
import tempfile
import unittest
spec = importlib.util.spec_from_file_location('retention', Path(__file__).with_name('prune-kinderparadies-releases.py'))
retention = importlib.util.module_from_spec(spec)
spec.loader.exec_module(retention)
plan, prune = retention.plan, retention.prune


class RetentionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'kinderparadies'
        self.releases = self.root / 'releases'
        self.releases.mkdir(parents=True)
        self.old = self.release('1.0.0', '1' * 12)
        self.previous = self.release('3.8.0', '2' * 12)
        self.current = self.release('3.8.3', '3' * 12)
        for name in ('web', 'downloads'):
            (self.root / name).symlink_to(self.current / name, target_is_directory=True)

    def release(self, number, digest):
        path = self.releases / f'v{number}-{digest}'
        (path / 'downloads').mkdir(parents=True)
        (path / 'web').mkdir()
        (path / 'downloads/release.json').write_text(json.dumps({'version': number}))
        return path

    def test_dry_run_keeps_everything(self):
        result = prune(self.root)
        self.assertEqual(result['remove_count'], 1)
        self.assertTrue(self.old.exists())

    def test_apply_keeps_current_previous_unknown_and_future(self):
        future = self.release('4.0.0', '4' * 12)
        unknown = self.releases / 'personal-backup'
        unknown.mkdir()
        prune(self.root, apply=True)
        self.assertFalse(self.old.exists())
        self.assertTrue(all(p.exists() for p in (self.previous, self.current, future, unknown)))

    def test_linked_file_refuses_all_deletion(self):
        (self.old / 'outside').symlink_to(self.root, target_is_directory=True)
        with self.assertRaises(ValueError):
            prune(self.root, apply=True)
        self.assertTrue(self.old.exists())

    def test_mismatched_live_links_refused(self):
        (self.root / 'downloads').unlink()
        (self.root / 'downloads').symlink_to(self.previous / 'downloads', target_is_directory=True)
        with self.assertRaises(ValueError):
            plan(self.root)

    def test_live_link_outside_release_root_refused(self):
        (self.root / 'web').unlink()
        (self.root / 'web').symlink_to(self.root / 'downloads', target_is_directory=True)
        with self.assertRaises(ValueError):
            plan(self.root)

    def test_kept_manifest_mismatch_refused(self):
        (self.previous / 'downloads/release.json').write_text('{"version":"9.9.9"}')
        with self.assertRaises(ValueError):
            prune(self.root, apply=True)
        self.assertTrue(self.old.exists())


if __name__ == '__main__':
    unittest.main()
