#!/usr/bin/env python3
"""R5 (E-246): compare the graph plots' digests (`P <pass> <step> <what> <value>` lines, E-240's) of two workload logs.
    r5_compare_plots.py <ref.log> <log> [--as=X:Y] [--passes=p1,p2,...]
Points (positions, edge points, the line's last point) within 1e-4 (they are printed to 4 digits); colours (RGBA × 255)
within 1 per channel (the colours come from simulated values equal within the workload's tolerances); counts exactly.
--as=X:Y: the log's pass X against the ref's pass Y."""
import sys, re
def plines(path):
    out = {}
    for line in open(path):
        if line.startswith('P '):
            parts = line.rstrip('\n').split(' ', 4)
            out[(parts[1], parts[2], parts[3])] = parts[4] if len(parts) > 4 else ''
    return out
NUM = re.compile(r'-?(?:\d+\.?\d*(?:e-?\d+)?|NaN)')
def nums(s): return [float(x) for x in NUM.findall(s)]
def close(a, b, tol):
    xa, xb = nums(a), nums(b)
    if len(xa) != len(xb): return False, float('inf')
    d = 0.0
    for x, y in zip(xa, xb):
        if x != x and y != y: continue
        if (x != x) != (y != y): return False, float('inf')
        d = max(d, abs(x - y))
    return d <= tol, d
def main():
    ref, new = plines(sys.argv[1]), plines(sys.argv[2])
    opts = dict(a[2:].split('=', 1) for a in sys.argv[3:] if a.startswith('--') and '=' in a)
    if 'as' in opts:
        x, y = opts['as'].split(':')
        new = {(y,) + k[1:]: v for k, v in new.items() if k[0] == x}
        ref = {k: v for k, v in ref.items() if k[0] == y}
    if 'passes' in opts:
        ps = set(opts['passes'].split(','))
        ref = {k: v for k, v in ref.items() if k[0] in ps}
        new = {k: v for k, v in new.items() if k[0] in ps}
    bad = 0; worst = {}
    for k in sorted(set(ref) | set(new)):
        if k not in ref or k not in new:
            print(f'{k}: missing in {"ref" if k not in ref else "log"}'); bad += 1; continue
        a, b = ref[k], new[k]
        if a == b: continue
        tol = 1.0 if 'colors' in k[2] else 1e-4
        ok, d = close(a, b, tol)
        worst[k[2]] = max(worst.get(k[2], 0.0), d)
        if not ok:
            print(f'{k}: DIFFERS (max {d}): {a[:160]} | {b[:160]}'); bad += 1
    print('largest differences by kind:', {w: round(d, 6) for w, d in sorted(worst.items())})
    print(f'compared {len(ref)} plot lines: {bad} failures')
    sys.exit(1 if bad else 0)
main()
