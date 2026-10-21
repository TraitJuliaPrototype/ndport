#!/usr/bin/env bash
# P6 check Q (E-155): scripts/p6_tests.sh <p6|u> <group s2|s6> <tag> [resolve]  -> logs/p6/tests-<tag>.log
# p6: env_p6test (the P6 trees); u: env_p6test_u (the registry's releases, the baseline). Depot depot-p6 first.
# Strict mode on for p6 (as every P6 check), off for the baseline.
set -uo pipefail
cd "$(dirname "$0")/.."
which=$1; group=$2; tag=$3; res=${4:-}
export JULIA_DEPOT_PATH=$PWD/depot-p6:$HOME/.julia: JULIA_PKG_OFFLINE=true OPENBLAS_NUM_THREADS=1 JULIA_NUM_PRECOMPILE_TASKS=4 JULIA_PKG_PRECOMPILE_AUTO=0
unset JULIA_COMPILE_BY_FACTS
if [ "$which" = p6 ]; then env=env_p6test; export JULIA_TW_STRICT=1; else env=env_p6test_u; unset JULIA_TW_STRICT; fi
f=logs/p6/tests-$tag.log
echo "# $env group=$group strict=${JULIA_TW_STRICT:-0} TraitWorld $(git -C ../TraitWorld log -1 --format=%h) date $(date -Is) load $(cut -d' ' -f1 /proc/loadavg)" > $f
flock /tmp/claude-1000/julia-review.lock nice -n 19 timeout 1800 ../julia-1.13/julia --startup-file=no --project=$env \
  -e 'using Pkg; "resolve" in ARGS && Pkg.resolve(); t = @elapsed Pkg.precompile(); println("# precompile s=", round(t; digits = 1))' $res >> $f 2>&1
flock /tmp/claude-1000/julia-review.lock nice -n 19 timeout 1800 ../julia-1.13/julia --startup-file=no --project=$env scripts/p6_tests.jl $group >> $f 2>&1
echo "rc=$?"; grep -E '^(TEST|# .*s=|# p6_tests)' $f
