#!/usr/bin/env python3
"""P6 (E-155): the wrap of the plan §1.4, as P3's: TraitWorld in [deps]; after `module <Name>`, the line
`using TraitWorld: TraitWorld, @trait_module[, @joint_owners]` and `@trait_module begin` (plus `@joint_owners …` if
given); `end # @trait_module` before the module's last `end`.
    scripts/p6_wrap.py <package dir> [JointOwner ...]"""
import re, sys, os, tomllib
d = sys.argv[1]; joint = sys.argv[2:]
proj = os.path.join(d, "Project.toml")
name = tomllib.load(open(proj, "rb"))["name"]
p = open(proj).read()
TW = 'TraitWorld = "7a3c1e52-9b4d-4f6e-8a21-5d0c3b9e7f14"\n'
if TW not in p:
    m = re.search(r"^\[deps\]\n", p, re.M)
    # insert in sorted position within [deps]
    start = m.end(); end = p.find("\n[", start); end = len(p) if end < 0 else end + 1
    lines = p[start:end].splitlines(keepends=True)
    entries = [l for l in lines if l.strip()]
    i = 0
    while i < len(entries) and entries[i].split("=")[0].strip() < "TraitWorld": i += 1
    entries.insert(i, TW)
    tail = "".join(l for l in lines if not l.strip())
    p = p[:start] + "".join(entries) + tail + p[end:]
    open(proj, "w").write(p)
src = os.path.join(d, "src", name + ".jl")
s = open(src).read()
m = re.search(rf"^module {name}\s*\n", s, re.M)
assert m, "module line"
use = "using TraitWorld: TraitWorld, @trait_module" + (", @joint_owners" if joint else "")
head = use + "\n@trait_module begin\n" + (("@joint_owners " + " ".join(joint) + "\n") if joint else "")
s = s[:m.end()] + head + s[m.end():]
k = s.rstrip().rfind("\nend")
assert k > 0
s = s[:k] + "\nend # @trait_module" + s[k:]
open(src, "w").write(s)
print(name, "wrapped", "joint:", joint)
