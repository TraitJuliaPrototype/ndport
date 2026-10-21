#!/usr/bin/env python3
"""Compare the digests of two workload logs (the P1 plan §4).
    compare_digests.py <ref.log> <log> [--exact] [--passes=p1,p2,...] [--as=X:Y]
--passes: only these passes, in both logs. --as=X:Y: the log's pass X against the ref's pass Y (the graph
plan's criterion 2: `--as=graphtype:first` with one log as both arguments).
Exact fields must be equal (reported; an error with --exact); tolerance fields must hold;
reported fields are only printed. Trips closer than 0.05 in time are compared as unordered groups."""
import sys, math
EXACT = {'vdim', 'vpdim', 'edim', 'epdim', 'nv', 'ne', 'connected', 'edges', 'dim', 'pdim', 'u', 'p', 'fix',
         'retcode', 'rretcode', 'sol', 'rsol', 'line', 'listeners', 'frames', 'pixels'}
REPORTED = {'nsteps', 'rnsteps', 'pngbytes'}
TRIPS = {'trips': 'ttrips', 'rtrips': 'trtrips'}
ATOL = {'ttrips': 1e-6, 'trtrips': 1e-6, 'pos': 1e-4}

def digests(path):
    out = {}
    for line in open(path):
        if line.startswith('D '):
            parts = line.split()
            out[(parts[1], parts[2])] = dict(f.split('=', 1) for f in parts[3:])
    return out

def floats(s): return [float(x) for x in s.split(',')] if s else []

def close(a, b, key):
    xa, xb = floats(a), floats(b)
    if len(xa) != len(xb): return False
    atol, rtol = ATOL.get(key, 1e-7), 1e-5
    return all(abs(x - y) <= atol + rtol * max(abs(x), abs(y)) for x, y in zip(xa, xb))

def groups(lines, times):
    """the trips as a list of sets, successive trips closer than 0.05 in one set"""
    ls, ts, gs = lines.split(',') if lines else [], floats(times), []
    for i, (l, t) in enumerate(zip(ls, ts)):
        if i and t - ts[i - 1] < 0.05: gs[-1].add(l)
        else: gs.append({l})
    return gs

def main():
    ref, new, exact = digests(sys.argv[1]), digests(sys.argv[2]), '--exact' in sys.argv
    opts = dict(a[2:].split('=', 1) for a in sys.argv[3:] if a.startswith('--') and '=' in a)
    if 'as' in opts:
        x, y = opts['as'].split(':')
        new = {(y, k[1]): v for k, v in new.items() if k[0] == x}
        ref = {k: v for k, v in ref.items() if k[0] == y}
    if 'passes' in opts:
        ps = set(opts['passes'].split(','))
        ref = {k: v for k, v in ref.items() if k[0] in ps}
        new = {k: v for k, v in new.items() if k[0] in ps}
    bad_exact = bad_tol = 0
    for k in sorted(set(ref) | set(new)):
        if k not in ref or k not in new:
            print(f'{k}: missing in {"ref" if k not in ref else "log"}'); bad_tol += 1; continue
        a, b = ref[k], new[k]
        for f in sorted(set(a) | set(b)):
            va, vb = a.get(f), b.get(f)
            if va == vb or f in REPORTED: continue
            if va is None or vb is None:
                print(f'{k} {f}: missing'); bad_tol += 1
            elif f in TRIPS:
                tf = TRIPS[f]
                if groups(va, a.get(tf, '')) == groups(vb, b.get(tf, '')):
                    print(f'{k} {f}: order differs within close trips (ok)')
                else:
                    print(f'{k} {f}: differs: {va} | {vb}'); bad_tol += 1
            elif f in EXACT:
                print(f'{k} {f}: exact field differs: {va} | {vb}'); bad_exact += 1
            elif close(va, vb, f):
                print(f'{k} {f}: within tolerance')
            else:
                print(f'{k} {f}: OUT OF TOLERANCE: {va} | {vb}'); bad_tol += 1
    print(f'compared {len(ref)} digests: {bad_exact} exact differences, {bad_tol} failures')
    sys.exit(1 if bad_tol or (exact and bad_exact) else 0)

main()
