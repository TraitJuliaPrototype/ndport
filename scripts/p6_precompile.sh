#!/usr/bin/env bash
# Check (P) of the inside-out plan (E-155, writeup/plans/2026-10-21-ndport-inside-out.md §3.1): env_p6 precompiles
# into depot-p6 with strict mode on (JULIA_TW_STRICT=1, which the precompile workers inherit), through the shared lock.
#     scripts/p6_precompile.sh <tag> [resolve]   -> logs/p6/precompile-<tag>.log
# `resolve`: Pkg.resolve() first (offline), after the project's sources changed.
set -uo pipefail
cd "$(dirname "$0")/.."
tag=$1; res=${2:-}
export JULIA_DEPOT_PATH=$PWD/depot-p6:$HOME/.julia: JULIA_PKG_OFFLINE=true OPENBLAS_NUM_THREADS=1 JULIA_NUM_PRECOMPILE_TASKS=4 JULIA_TW_STRICT=1
unset JULIA_COMPILE_BY_FACTS
mkdir -p logs/p6; f=logs/p6/precompile-$tag.log
{
  echo "# P6 precompile $tag date $(date -Is) load $(cut -d' ' -f1 /proc/loadavg)"
  echo "# julia-1.13 $(git -C ../julia-1.13 log -1 --format=%h) TraitWorld $(git -C ../TraitWorld log -1 --format=%h) dirty=$(git -C ../TraitWorld status --porcelain --untracked-files=no | wc -l)"
  echo "# trees $(for d in pkgs/*-p6 pkgs/*-p6-ros; do printf '%s:%s%s ' $(basename $d) $(git -C $d log -1 --format=%h) $([ -z "$(git -C $d status --porcelain --untracked-files=no)" ] || echo '*'); done)"
} > $f
t0=$(date +%s)
flock /tmp/claude-1000/julia-review.lock nice -n 19 timeout 1800 ../julia-1.13/julia --startup-file=no --project=env_p6 -e '
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
