#!/usr/bin/env bash
# R7 (E-249): the finish round's comparisons, from logs/r7 (run-PT-1, -2; strict-PT-1, -2; run-UP-1) and R5's U′
# (logs/r5/run-UP-1). Writes logs/r7/compare-run.txt.
#     scripts/r7_compare.sh
set -uo pipefail
cd "$(dirname "$0")/.."
L=logs/r7; C=scripts/compare_digests.py; PL=scripts/r5_compare_plots.py
plines() { grep '^P ' "$1"; }
ptext() { # the P lines of two logs textually equal (optionally one pass of the second against the first's)
  if [ $# = 2 ]; then cmp -s <(plines $1) <(plines $2) && echo "P lines identical ($(plines $1 | wc -l))" || echo "P lines DIFFER"
  else cmp -s <(grep "^P $3 " $1 | sed "s/^P $3 /P X /") <(grep "^P $4 " $1 | sed "s/^P $4 /P X /") && echo "P lines $3 = $4 textually ($(grep -c "^P $3 " $1))" || echo "P lines $3 DIFFER from $4"; fi
}
{
echo "# R7 (E-249): the finish round's comparisons; $(date -Is)"
for f in run-PT-1 run-PT-2 strict-PT-1 strict-PT-2 run-UP-1; do echo "# $f: $(sed -n 2p $L/$f.log | cut -c1-200) | $(grep -c '^D ' $L/$f.log) digests, $(grep -c '^P ' $L/$f.log) plot lines, $(grep '^# rc' $L/$f.log)"; done
for f in run-PT-2 strict-PT-1 strict-PT-2; do
  echo "== $f vs run-PT-1 (exact)"; python3 $C $L/run-PT-1.log $L/$f.log --exact; ptext $L/run-PT-1.log $L/$f.log
done
for f in run-PT-1 run-PT-2 strict-PT-1 strict-PT-2; do
  for p in graphtype usertype; do
    echo "== $f $p vs first (exact)"; python3 $C $L/$f.log $L/$f.log --exact --as=$p:first; ptext $L/$f.log $L/$f.log $p first
  done
done
echo "== the network's type (N lines), per log"
for f in run-PT-1 run-PT-2 strict-PT-1 strict-PT-2; do echo "$f: $(grep '^N ' $L/$f.log | awk '{printf "%s %s; ", $2, $4}')"; done
echo "== strict mode: refusals, pirates, warnings in the strict logs"
for f in strict-PT-1 strict-PT-2; do echo "$f: STRICT env $(sed -n 1p $L/$f.log | grep -o 'strict=[a-z]*'); $(grep -c -E 'PirateError|OwnershipError|TraitUseError|refus' $L/$f.log) refusal lines, $(grep -c -E '^┌ Warning|^Warning' $L/$f.log) warnings"; done
echo "== U′ today vs R5's U′ (exact)"; python3 $C logs/r5/run-UP-1.log $L/run-UP-1.log --exact; ptext logs/r5/run-UP-1.log $L/run-UP-1.log
echo "== U′ vs PT (tolerance; passes first, again, params, changed: U′ refuses the graph type at b)"
python3 $C $L/run-UP-1.log $L/run-PT-1.log --passes=first,again,params,changed
echo "== plots U′ vs PT"; python3 $PL $L/run-UP-1.log $L/run-PT-1.log --passes=first,again,params,changed
echo "== U′'s graphtype pass"; grep '^D graphtype' $L/run-UP-1.log
} > $L/compare-run.txt 2>&1
cat $L/compare-run.txt
