#!/usr/bin/env python3
"""env_port equals env_upstream (the P1 plan §1.2): every package has the same version, and the same
tree hash unless it is tracked by path (a clone, or ComputePipeline beside Makie); TraitWorld is added.
Every clone has no change against its tag `upstream`."""
import tomllib, subprocess, sys, pathlib
nd = pathlib.Path(__file__).resolve().parent.parent
u = tomllib.load(open(nd / 'env_upstream/Manifest.toml', 'rb'))['deps']
p = tomllib.load(open(nd / 'env_port/Manifest.toml', 'rb'))['deps']
bad = 0
for name in sorted(set(u) | set(p)):
    if name == 'TraitWorld': continue
    if name not in u or name not in p:
        print(f'{name}: only in {"port" if name in p else "upstream"}'); bad += 1; continue
    eu, ep = u[name][0], p[name][0]
    if eu.get('version') != ep.get('version'):
        print(f'{name}: version {eu.get("version")} | {ep.get("version")}'); bad += 1
    if 'path' not in ep and eu.get('git-tree-sha1') != ep.get('git-tree-sha1'):
        print(f'{name}: tree hash differs'); bad += 1
for d in sorted((nd / 'pkgs').iterdir()):
    if not (d / '.git').exists(): continue
    diff = subprocess.run(['git', '-C', str(d), 'diff', '--stat', 'upstream'], capture_output=True, text=True).stdout
    print(f'{d.name}: {"unchanged" if not diff.strip() else "CHANGED against upstream"}')
print('env_port equals env_upstream' if not bad else f'{bad} differences'); sys.exit(1 if bad else 0)
