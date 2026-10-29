#!/usr/bin/env python3
"""W-96 (E-248): the largest absolute difference from U′ per numeric field of steps d and e, for a PT log on TDE `w96`
and R5's PT log (the cubic Hermite polynomial); the saved states (nsteps, rnsteps) and the trips' order.
    w96_deltas.py <U′ log> <PT log, w96> <PT log, R5>"""
import sys
def digests(path):
    out = {}
    for line in open(path):
        if line.startswith('D '):
            p = line.split(); out[(p[1], p[2])] = dict(f.split('=', 1) for f in p[3:])
    return out
def fl(s): return [float(x) for x in s.split(',')] if s else []
U, W, O = (digests(p) for p in sys.argv[1:4])
for (ps, st) in sorted(set(U) & set(W) & set(O)):
    if st not in ('d', 'e'): continue
    u, w, o = U[(ps, st)], W[(ps, st)], O[(ps, st)]
    for k in sorted(set(u) & set(w)):
        if k in ('nsteps', 'rnsteps'):
            print(f'{ps:8} {st} {k:7} U′ {u[k]:>4}  w96 {w[k]:>4}  R5 {o.get(k, "-"):>4}')
        elif k in ('trips', 'rtrips'):
            print(f'{ps:8} {st} {k:7} order equal to U′: w96 {u[k] == w[k]}  R5 {u[k] == o.get(k)}')
        elif k in ('ttrips', 'trtrips', 'ω2', 'ω2r', 'ωsum', 'P2', 'P3', 'K3', 'Pend'):
            a, b, c = fl(u[k]), fl(w[k]), fl(o.get(k, ''))
            if k in ('ttrips', 'trtrips'): a, b, c = sorted(a), sorted(b), sorted(c)
            d1 = max((abs(x - y) for x, y in zip(a, b)), default=0.0)
            d2 = max((abs(x - y) for x, y in zip(a, c)), default=0.0) if c else float('nan')
            print(f'{ps:8} {st} {k:7} max |PT - U′|  w96 {d1:.2e}  R5 {d2:.2e}')
