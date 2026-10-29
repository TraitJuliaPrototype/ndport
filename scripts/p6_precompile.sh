#!/usr/bin/env bash
# Check (P) of the inside-out plan (E-155, writeup/plans/2026-10-21-ndport-inside-out.md §3.1): env_p6 precompiles
# into depot-p6 with strict mode on (JULIA_TW_STRICT=1, which the precompile workers inherit), through the shared lock.
#     scripts/p6_precompile.sh <tag> [resolve]   -> logs/p6/precompile-<tag>.log
# `resolve`: Pkg.resolve() first (offline), after the project's sources changed.
# NDP_TASKS (default 1) precompile tasks, NDP_CPUS (default 0-1) the cores; P6ENV, P6DEPOT, P6LOGDIR, TWDIR choose the setting.
set -uo pipefail
cd "$(dirname "$0")/.."
tag=$1; res=${2:-}
export JULIA_DEPOT_PATH=$PWD/${P6DEPOT:-depot-p6}:$HOME/.julia: JULIA_PKG_OFFLINE=true OPENBLAS_NUM_THREADS=1 JULIA_NUM_PRECOMPILE_TASKS=${NDP_TASKS:-1} JULIA_NUM_THREADS=1 JULIA_TW_STRICT=1
unset JULIA_COMPILE_BY_FACTS
L=${P6LOGDIR:-logs/p6}; mkdir -p $L; f=$L/precompile-$tag.log
{
  echo "# P6 precompile ${P6ENV:-env_p6} ${P6DEPOT:-depot-p6} $tag date $(date -Is) load $(cut -d' ' -f1 /proc/loadavg)"
  echo "# julia-1.13 $(git -C ../julia-1.13 log -1 --format=%h) TraitWorld $(git -C ../${TWDIR:-TraitWorld} log -1 --format=%h) dirty=$(git -C ../${TWDIR:-TraitWorld} status --porcelain --untracked-files=no | wc -l)"
  echo "# trees $(for d in pkgs/*-p6 pkgs/*-p6-ros pkgs/NetworkDynamics-p4 pkgs/Graphs-p4; do printf '%s:%s%s ' $(basename $d) $(git -C $d log -1 --format=%h) $([ -z "$(git -C $d status --porcelain --untracked-files=no)" ] || echo '*'); done)"
} > $f
t0=$(date +%s)
flock /tmp/claude-1000/julia-review.lock taskset -c ${NDP_CPUS:-0-1} ionice -c3 nice -n 19 timeout -s KILL 3600 ../julia-1.13/julia --startup-file=no --project=${P6ENV:-env_p6} -e '
  using Pkg
  "resolve" in ARGS && Pkg.resolve()
  t = @elapsed Pkg.precompile()
  println("precompile s=", round(t; digits = 1))
  using TraitWorld
  println("strict TraitWorld.STRICT[]=", TraitWorld.STRICT[])
  t = @elapsed using NetworkDynamics, OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock
  println("using s=", round(t; digits = 1))
' $res >> $f 2>&1
rc=$?
echo "# rc=$rc wall=$(( $(date +%s) - t0 ))s" >> $f
echo "rc=$rc"; grep -v "^\s*$" $f | grep -v "could not download\|exception = RequestError\|@ Pkg.Registry\|^┌ Warning\|^└" | tail -30
