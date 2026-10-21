#!/usr/bin/env bash
# graph_check.jl in setting P4 (env_p4, depot-p4), through the shared lock. scripts/graph_check.sh <tag> -> logs/p4g/check-<tag>.log
set -uo pipefail
cd "$(dirname "$0")/.."
tag=$1
export JULIA_DEPOT_PATH=$PWD/depot-p4:$HOME/.julia: JULIA_PKG_OFFLINE=true OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_NUM_PRECOMPILE_TASKS=4
unset JULIA_COMPILE_BY_FACTS JULIA_TW_STRICT
f=logs/p4g/check-$tag.log
echo "# P4 nd=$(git -C pkgs/NetworkDynamics-p4 log -1 --format=%h) dirty=$(git -C pkgs/NetworkDynamics-p4 status --porcelain --untracked-files=no | wc -l) graphs=$(grep -o "pkgs/Graphs[^\"]*" env_p4/Project.toml):$(git -C pkgs/Graphs-p4 log -1 --format=%h) TraitWorld $(git -C ../TraitWorld log -1 --format=%h) date $(date -Is) load $(cut -d' ' -f1 /proc/loadavg)" > $f
flock /tmp/claude-1000/julia-review.lock nice -n 19 timeout 900 ../julia-1.13/julia --startup-file=no --project=env_p4 scripts/graph_check.jl >> $f 2>&1
echo "# rc=$? load-after $(cut -d' ' -f1 /proc/loadavg)" >> $f
grep -E '^(#|M|N|W) ' $f
