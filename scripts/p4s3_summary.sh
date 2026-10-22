#!/usr/bin/env bash
# E-166: one line per workload log: digests against U (exact), again c/d/e, changed b–e, first a–e, ND load, session, refusals.
cd "$(dirname "$0")/.."
for f in "$@"; do
  d=$(python3 scripts/compare_digests.py logs/p1/U-1.log "$f" --exact 2>&1 | tail -1)
  awk -v f="$f" -v d="$d" '
    $1=="T" && $2=="again" && ($3=="c"||$3=="d"||$3=="e") {ag=ag $4 " / "}
    $1=="T" && $2=="changed" && $3>="b" && $3<="e" {ch+=$4}
    $1=="T" && $2=="first" && $3>="a" && $3<="e" {fi+=$4}
    $1=="L" && $2=="Graphs,NetworkDynamics" {ld=$3}
    $1=="W" && $2=="total" {w=$3}
    /STRICT/ {st=$0}
    /PirateError|refus/ {nr++}
    END {printf "%s | %s | again c/d/e %s| changed b-e %.2f s | first a-e %.1f s | load ND %s | session %s | %s | refusal-lines %d\n", f, d, ag, ch/1000, fi/1000, ld, w, st, nr}' "$f"
done
