#!/usr/bin/env python3
"""P6 check H (E-155): the dispatch profile of steps c-e of an "again" pass (p6_census.jl's `== H` block), grouped by
the callee method's module (the profiler prints the top 40 methods). Per module: dynamic calls in all, from code of
the facts owner, from code of the default owner.
    scripts/p6_profile_summary.py <log> [<reference log>]
With a reference (I0's log), also the modules whose facts-owner calls are new or grew."""
import re, sys
from collections import defaultdict

LINE = re.compile(r"^\s*(\d+)\s+([A-Za-z_][\w!#]*)\.(\S+)\s+(\S+)\s+:facts (\d+)/(\d+)/(\d+)/(\d+) \| default (\d+)/(\d+)/(\d+)/(\d+)")

def parse(path):
    mods = defaultdict(lambda: [0, 0, 0]); meths = []
    inside = False; section = 0
    for l in open(path, errors="replace"):
        if l.startswith("== H:"): inside = True; continue
        if l.startswith("== H end"): break
        if not inside: continue
        if l.startswith("-- dynamic calls by"): section += 1; continue
        if section != 1: continue
        m = LINE.match(l)
        if not m: continue
        n = int(m[1]); f = sum(int(m[i]) for i in range(5, 9)); d = sum(int(m[i]) for i in range(9, 13))
        mods[m[2]][0] += n; mods[m[2]][1] += f; mods[m[2]][2] += d
        meths.append((n, f, d, f"{m[2]}.{m[3]}", m[4]))
    return mods, meths

mods, meths = parse(sys.argv[1])
print(f"H {sys.argv[1]}: {sum(v[0] for v in mods.values())} dynamic calls in the top 40 methods, {sum(v[1] for v in mods.values())} from facts code")
for k, v in sorted(mods.items(), key=lambda kv: -kv[1][0]):
    print(f"H module {k:32s} all={v[0]:>10d} facts={v[1]:>10d} default={v[2]:>10d}")
if len(sys.argv) > 2:
    ref, _ = parse(sys.argv[2])
    for k, v in sorted(mods.items(), key=lambda kv: -kv[1][1]):
        r = ref.get(k, [0, 0, 0])
        if v[1] > 1.1 * r[1] + 100:
            print(f"H NEW-OR-GREW {k}: facts {r[1]} -> {v[1]}")
    for n, f, d, name, loc in meths:
        if f > 100: print(f"H facts-site {f:>10d} {name} {loc}")
