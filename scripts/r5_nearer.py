#!/usr/bin/env python3
"""R5 (E-246): the tie-break of the plan §5. For each numeric field that two default-tolerance logs (PT, U′) disagree on,
the largest absolute difference of each from a tight-tolerance reference: which is nearer.
    r5_nearer.py <tight ref.log> <U′ log> <PT log> [--passes=p1,...]"""
import sys
def digests(path):
    out = {}
    for line in open(path):
        if line.startswith('D '):
            parts = line.split()
            out[(parts[1], parts[2])] = dict(f.split('=', 1) for f in parts[3:])
    return out
def floats(s):
    try: return [float(x) for x in s.split(',')] if s else []
    except ValueError: return None
ref, up, pt = (digests(p) for p in sys.argv[1:4])
opts = dict(a[2:].split('=', 1) for a in sys.argv[4:] if a.startswith('--') and '=' in a)
ps = set(opts['passes'].split(',')) if 'passes' in opts else None
SKIP = {'ttrips', 'trtrips'}
for k in sorted(set(ref) & set(up) & set(pt)):
    if ps and k[0] not in ps: continue
    for f in sorted(ref[k]):
        if f in SKIP or f not in up[k] or f not in pt[k] or up[k][f] == pt[k][f]: continue
        r, u, p = floats(ref[k][f]), floats(up[k][f]), floats(pt[k][f])
        if r is None or u is None or p is None or not (len(r) == len(u) == len(p)) or not r: continue
        du = max(abs(a - b) for a, b in zip(u, r)); dp = max(abs(a - b) for a, b in zip(p, r))
        print(f'{k[0]:8s} {k[1]} {f:6s} |U′-tight| {du:.3e}  |PT-tight| {dp:.3e}  nearer: {"PT" if dp < du else "U′" if du < dp else "equal"}')
