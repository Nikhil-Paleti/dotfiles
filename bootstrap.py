#!/usr/bin/env python3
"""Explicit, copy-only installer. Dry run by default; never overwrites."""
import argparse
import os
from pathlib import Path
import shutil
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--home', type=Path, default=Path.home())
    parser.add_argument('--apply', action='store_true', help='copy missing configuration after preflight')
    parser.add_argument('--dry-run', action='store_true', help='preview (the default)')
    parser.add_argument('--components', nargs='+', choices=['nvim', 'tmux', 'shell'], default=['nvim', 'tmux', 'shell'])
    args = parser.parse_args()
    if args.apply and args.dry_run:
        parser.error('--apply and --dry-run are mutually exclusive')
    if os.name == 'nt':
        parser.error('Use WSL for this installer; native Windows installation is manual.')
    home = args.home.expanduser().absolute()
    if not home.is_dir() or home.is_symlink():
        parser.error('--home must be an existing real directory')
    root = Path(__file__).resolve().parent
    mapping = {'nvim': [('config/nvim', '.config/nvim')],
               'tmux': [('tmux.conf', '.tmux.conf')],
               'shell': [('shell/zshrc', '.zshrc'), ('shell/zprofile', '.zprofile')]}
    plan = [(root / src, home / dst) for c in dict.fromkeys(args.components) for src, dst in mapping[c]]
    errors = []
    for src, dst in plan:
        if dst.exists() or dst.is_symlink():
            errors.append('Collision: ' + str(dst))
        parent = dst.parent
        while parent != home:
            if parent.is_symlink() or (parent.exists() and not parent.is_dir()):
                errors.append('Unsafe parent: ' + str(parent))
            parent = parent.parent
        if not src.exists() or src.is_symlink() or (src.is_dir() and any(p.is_symlink() for p in src.rglob('*'))):
            errors.append('Missing or symlinked source: ' + str(src))
    for src, dst in plan:
        print(('COPY' if args.apply else 'WOULD COPY') + f' {src.relative_to(root)} -> {dst}')
    if errors:
        print('\n'.join(errors) + '\nNothing copied. Move conflicts aside yourself after reviewing/backing them up.', file=sys.stderr)
        return 1
    if args.apply:
        for src, dst in plan:
            dst.parent.mkdir(parents=True, exist_ok=True)
            if src.is_dir():
                shutil.copytree(src, dst)
            else:
                with src.open('rb') as source, dst.open('xb') as target:
                    shutil.copyfileobj(source, target)
    return 0


if __name__ == '__main__':
    sys.exit(main())
