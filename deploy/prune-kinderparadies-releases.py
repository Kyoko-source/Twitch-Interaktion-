"""Retain the live After Play release and one rollback release. Dry run by default."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path('/opt/twitch-interaktion/game-releases/kinderparadies')
RELEASE = re.compile(r'v(\d+)\.(\d+)\.(\d+)-[a-f0-9]{12}')


def version(path):
    match = RELEASE.fullmatch(path.name)
    if not match:
        raise ValueError(f'Not a generated release: {path}')
    return tuple(map(int, match.groups()))


def validate_tree(path, parent):
    if path.is_symlink() or path.parent != parent or path.resolve() != path:
        raise ValueError(f'Unsafe release path: {path}')
    if not path.is_dir():
        raise ValueError(f'Missing release directory: {path}')
    size = 0
    for directory, directories, files in os.walk(path, followlinks=False):
        for name in directories + files:
            item = Path(directory) / name
            if item.is_symlink():
                raise ValueError(f'Linked entry in release: {item}')
        size += sum((Path(directory) / name).stat().st_size for name in files)
    return size


def live_release(root):
    parent = root / 'releases'
    if root.resolve() != root or parent.resolve() != parent:
        raise ValueError('Release root must not be linked')
    paths = []
    for name in ('web', 'downloads'):
        link = root / name
        if not link.is_symlink():
            raise ValueError(f'Expected a live symlink: {link}')
        target = link.resolve(strict=True)
        if target.name != name or target.parent.parent != parent:
            raise ValueError(f'Live link leaves release root: {link}')
        paths.append(target.parent)
    if paths[0] != paths[1]:
        raise ValueError('Live web and downloads belong to different releases')
    return paths[0]


def plan(root=ROOT):
    root = Path(root).absolute()
    current = live_release(root)
    parent = root / 'releases'
    current_version = version(current)
    candidates = [p for p in parent.iterdir() if RELEASE.fullmatch(p.name)]
    # Ignore newer, possibly still uploading releases.
    older = [p for p in candidates if version(p) < current_version]
    previous = max(older, key=lambda p: (version(p), p.stat().st_mtime_ns), default=None)
    keep = {current} | ({previous} if previous else set())
    for path in keep:
        validate_tree(path, parent)
        manifest = json.loads((path / 'downloads/release.json').read_text('utf-8-sig'))
        if manifest['version'] != '.'.join(map(str, version(path))):
            raise ValueError(f'Release manifest mismatch: {path}')
    remove = []
    for path in sorted(candidates):
        if path not in keep and version(path) <= current_version:
            remove.append((path, validate_tree(path, parent)))
    return current, keep, remove


def prune(root=ROOT, apply=False):
    root = Path(root).absolute()
    current, keep, remove = plan(root)
    result = {'apply': apply, 'keep': sorted(p.name for p in keep),
              'remove_count': len(remove), 'bytes': sum(size for _, size in remove)}
    print(json.dumps(result), flush=True)
    if apply:
        for path, _ in remove:
            if live_release(root) != current:
                raise ValueError('Live release changed during cleanup')
            validate_tree(path, root / 'releases')
            shutil.rmtree(path)
    return result


def prune_images(keep_tag, apply):
    if not re.fullmatch(r'aviary-frontend:before-kinderparadies-[a-f0-9]{7,40}', keep_tag):
        raise ValueError('Invalid rollback image tag')
    inspect = lambda *args: subprocess.check_output(['docker', *args], text=True).strip()
    inspect('image', 'inspect', keep_tag)  # Verify the rollback image exists first.
    containers = inspect('ps', '-aq').splitlines()
    used = set(inspect('inspect', '--format', '{{.Image}}', *containers).splitlines()) if containers else set()
    rows = inspect('image', 'ls', '--no-trunc', 'aviary-frontend', '--format', '{{.Repository}}:{{.Tag}} {{.ID}}').splitlines()
    remove = []
    for row in rows:
        tag, image_id = row.split()
        if (re.fullmatch(r'aviary-frontend:before-kinderparadies-[a-f0-9]{7,40}', tag)
                and tag != keep_tag and image_id not in used):
            remove.append(tag)
    print(json.dumps({'rollback_image': keep_tag, 'old_image_tags': len(remove), 'apply': apply}), flush=True)
    if apply and remove:
        subprocess.run(['docker', 'image', 'rm', *remove], check=True, stdout=subprocess.DEVNULL)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--keep-image')
    args = parser.parse_args()
    prune(apply=args.apply)
    if args.keep_image:
        prune_images(args.keep_image, args.apply)
