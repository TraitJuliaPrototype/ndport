#!/usr/bin/env bash
# ND's test subset: scripts/nd_tests.sh <u|p4> <tag>  -> logs/p4/ndtest-<tag>.log
set -uo pipefail
cd "$(dirname "$0")/.."
which=$1; tag=$2
export JULIA_PKG_OFFLINE=true OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_NUM_PRECOMPILE_TASKS=4
unset JULIA_COMPILE_BY_FACTS JULIA_TW_STRICT
if [ "$which" = p4 ]; then export JULIA_DEPOT_PATH=$PWD/${P4DEPOT:-depot-p4}:$HOME/.julia:; nd=pkgs/NetworkDynamics-p4; else unset JULIA_DEPOT_PATH; nd=pkgs/NetworkDynamics.jl; fi
f=${P4LOGDIR:-logs/p4}/ndtest-$tag.log
echo "# ${NDTENV:-env_ndtest_$which} nd=$nd $(git -C $nd log -1 --format=%h) graphs=$(grep -o "pkgs/Graphs[^\"]*" ${NDTENV:-env_ndtest_$which}/Project.toml):$(git -C pkgs/Graphs-p4 log -1 --format=%h) TraitWorld(${TWDIR:-TraitWorld}) $(git -C ../${TWDIR:-TraitWorld} log -1 --format=%h) date $(date -Is) load $(cut -d" " -f1 /proc/loadavg)" > $f
flock /tmp/claude-1000/julia-review.lock nice -n 19 timeout 1800 ../julia-1.13/julia --startup-file=no -t 2 --project=${NDTENV:-env_ndtest_$which} scripts/nd_tests.jl >> $f 2>&1
echo "rc=$?"; grep -E '^(TEST|# .*s=)' $f
