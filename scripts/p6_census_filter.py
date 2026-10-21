#!/usr/bin/env python3
"""P6 check C (E-155): from p6_census.jl's log, the pirates (CPIRATE lines) whose function or a type belongs to a
package P6 wraps (now or later), by definer: the rule of the plan §2.4 (classified before the step that wraps the
owner). Also the pirates of wrapped packages.   scripts/p6_census_filter.py <log> [--all]"""
import re, sys
from collections import defaultdict
P6 = {"SymbolicIndexingInterface", "RecursiveArrayTools", "SciMLBase", "NonlinearSolveBase", "BracketingNonlinearSolve",
      "SciMLJacobianOperators", "NonlinearSolve", "NonlinearSolveFirstOrder", "NonlinearSolveQuasiNewton",
      "NonlinearSolveSpectralMethods", "SimpleNonlinearSolve", "DiffEqBase", "OrdinaryDiffEqCore", "OrdinaryDiffEqTsit5",
      "DiffEqCallbacks", "OrdinaryDiffEqRosenbrock"}
by = defaultdict(list)
for l in open(sys.argv[1], errors="replace"):
    if not l.startswith("CPIRATE "): continue
    m = re.match(r"CPIRATE (\S+) (.*) \| fowner=(\S+) towners=(\S*)", l.rstrip())
    if not m: print("?", l); continue
    d, sig, fo, to = m[1], m[2], m[3], set(m[4].split(",")) - {""}
    hit = ({fo} | to) & P6
    if hit or "--all" in sys.argv: by[d].append((sorted(hit), fo, sig))
for d, xs in sorted(by.items()):
    print(f"F {d}: {len(xs)} pirates on P6's packages")
    for hit, fo, sig in xs: print(f"F   {d} [{','.join(hit)}] f={fo} {sig}")
