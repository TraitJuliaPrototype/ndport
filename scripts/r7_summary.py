#!/usr/bin/env python3
"""R7 (E-250): the measured sessions' table, per setting the counted runs' range (run 0, the warm-up, left out).
    r7_summary.py logs/r7/time/*.log
Columns, in seconds unless marked: the session (process start to exit, `# wall`), the loads (the `L` lines' sum), the
first simulation (`first` a–e), the first plot (`first` f), the Observables figure (`first` g), new equations
(`changed` b–e, and its compile time), the steady state (`again` d, ms), the passes `again` a–g (ms)."""
import sys, re, collections
runs = collections.defaultdict(list)
for path in sys.argv[1:]:
    m = re.match(r'(.+)-(\d+)\.log$', path.split('/')[-1])
    if not m or m.group(2) == '0': continue
    txt = open(path).read()
    if 'INVALID' in txt or '# rc=0' not in txt: print(f'# skipped {path}'); continue
    T = {}; C = {}; L = 0.0; wall = None
    for line in txt.splitlines():
        f = line.split()
        if line.startswith('T '): T[(f[1], f[2])] = float(f[3]); C[(f[1], f[2])] = float(f[5])
        elif line.startswith('L '): L += float(f[-1])
        elif line.startswith('# wall'): wall = float(f[2])
    s = lambda p, steps: sum(T[(p, k)] for k in steps) / 1000
    runs[m.group(1)].append(dict(
        session=wall, loads=L, first_ae=s('first', 'abcde'), f=T[('first', 'f')] / 1000, g=T[('first', 'g')] / 1000,
        changed_be=s('changed', 'bcde'), changed_be_c=sum(C[('changed', k)] for k in 'bcde') / 1000,
        again_d=T[('again', 'd')], again_ag=s('again', 'abcdefg') * 1000))
cols = [('session', 's', 1), ('loads', 's', 2), ('first_ae', 's', 1), ('f', 's', 1), ('g', 's', 1),
        ('changed_be', 's', 2), ('changed_be_c', 's', 2), ('again_d', 'ms', 1), ('again_ag', 'ms', 0)]
def rng(v, d):
    lo, hi = min(v), max(v)
    return f'{lo:.{d}f}' if f'{lo:.{d}f}' == f'{hi:.{d}f}' else f'{lo:.{d}f}–{hi:.{d}f}'
print('| setting | n | ' + ' | '.join(f'{c} ({u})' for c, u, _ in cols) + ' |')
print('|' + '---|' * (len(cols) + 2))
for st in ['PT', 'UP', 'U', 'S', 'M']:
    if st not in runs: continue
    v = runs[st]
    print(f'| {st} | {len(v)} | ' + ' | '.join(rng([r[c] for r in v], d) for c, _, d in cols) + ' |')
