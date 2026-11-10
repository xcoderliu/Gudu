#!/usr/bin/env python3
"""Reject oversized files and generated/private artifacts in the public tree."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
LIMIT = 5 * 1024 * 1024
FORBIDDEN_DIRS = {'.build', '.swiftpm', '.local', 'build', 'dist', 'DerivedData', 'xcuserdata', '.aws'}
FORBIDDEN_SUFFIXES = {'.zip', '.dmg', '.pkg', '.ipa', '.log', '.p12', '.pfx', '.pem', '.key', '.mobileprovision', '.provisionprofile', '.xcuserstate'}

names = subprocess.check_output(['git', 'ls-files', '-co', '--exclude-standard', '-z'], cwd=ROOT).decode().split('\0')
failures = []
files = []
for name in sorted(set(names)):
    if not name:
        continue
    path = ROOT / name
    if not path.is_file():
        continue
    files.append((path.stat().st_size, name))
    if set(Path(name).parts) & FORBIDDEN_DIRS or path.suffix.lower() in FORBIDDEN_SUFFIXES:
        failures.append(f'Generated/private artifact: {name}')
    if path.stat().st_size > LIMIT:
        failures.append(f'File exceeds 5 MiB: {name}')
    if path.name == '.env' or (path.name.startswith('.env.') and path.name != '.env.example'):
        failures.append(f'Environment secret file: {name}')
if failures:
    print('\n'.join(failures), file=sys.stderr)
    raise SystemExit(1)
print(f'PASS: {len(files)} public files; {sum(n for n, _ in files) / 1024 / 1024:.2f} MiB total; no files over 5 MiB or generated/private artifacts')
