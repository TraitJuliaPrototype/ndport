#!/usr/bin/env python3
"""P6 (E-155): one line per workload log of setting I: checks L, F, T and S, with T against a reference (I0).
    scripts/p6_summary.py <log> [<I0 log>]"""
import re, sys
def read(p):
    T = {}; L = {}; strict = None; pir = []; w = None; hdr = ""
    for l in open(p, errors="replace"):
        if l.startswith("# julia-1.13"): hdr = l.strip()
        m = re.match(r"T (\w+) (\w) ([\d.]+) compile ([\d.]+)", l)
        if m: T[(m[1], m[2])] = (float(m[3]), float(m[4]))
        m = re.match(r"L (\S+) ([\d.]+)", l)
        if m: L[m[1]] = float(m[2])
        if l.startswith("STRICT "): strict = l.split()[1]
        if "PirateError:" in l: pir.append(l.strip()[:160])
        if l.startswith("W total"): w = float(l.split()[2])
    return T, L, strict, pir, w, hdr
T, L, strict, pir, w, hdr = read(sys.argv[1])
first = sum(T[("first", s)][0] for s in "abcde" if ("first", s) in T) / 1000
print(f"{sys.argv[1]}: {hdr}")
print("  L " + " ".join(f"{k}={v}" for k, v in L.items()))
print(f"  F first a-e {first:.1f} s; c {T[('first','c')][0]/1000:.1f} d {T[('first','d')][0]/1000:.1f} e {T[('first','e')][0]/1000:.1f} f {T[('first','f')][0]/1000:.1f} s; session {w} s")
print("  T again " + " ".join(f"{s}={T[('again', s)][0]}" for s in "cdefg") + " ms")
print(f"  S strict={strict} PirateErrors={len(pir)}"); [print("    " + x) for x in pir]
if len(sys.argv) > 2:
    R = read(sys.argv[2])[0]
    for s in "cde":
        a, r = T[("again", s)][0], R[("again", s)][0]
        print(f"  T {s}: {a} vs I0 {r} ms -> {'ok' if a <= 1.1 * r + 5 else 'OUTSIDE 10% + 5 ms'}")
