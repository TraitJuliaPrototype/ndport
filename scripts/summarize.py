#!/usr/bin/env python3
"""A table per setting, pass and step: minimum and median over runs (the P1 plan §3.1).
    summarize.py logs/<tag>/*.log"""
import sys, re, statistics, collections
rows = collections.defaultdict(list)
for path in sys.argv[1:]:
    if 'INVALID' in open(path).read(): continue
    setting = re.sub(r'-\d+\.log$', '', path.split('/')[-1])
    for line in open(path):
        f = line.split()
        if line.startswith('T '): rows[(setting, f[1], f[2])].append((float(f[3]), float(f[5])))
        elif line.startswith('L '): rows[(setting, 'load', ' '.join(f[1:-1]))].append((1000 * float(f[-1]), 0.0))   # a label may hold spaces
        elif line.startswith('W total'): rows[(setting, 'total', '-')].append((1000 * float(f[2]), 0.0))
print(f'{"setting":8} {"pass":8} {"step":34} {"n":>2} {"min ms":>9} {"median ms":>9} {"compile":>9}')
for (s, ps, st), v in sorted(rows.items(), key=lambda kv: kv[0][0]):
    t = [x[0] for x in v]; c = [x[1] for x in v]
    print(f'{s:8} {ps:8} {st:34} {len(v):>2} {min(t):>9.1f} {statistics.median(t):>9.1f} {statistics.median(c):>9.1f}')
