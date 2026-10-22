#!/usr/bin/env bash
# rhs_check.jl in setting P4 (env_p4, depot-p4), two threads, through the shared lock.
#     scripts/rhs_p4.sh <tag>     -> logs/p4/rhs-<tag>.log, then the diff of R/J lines against U
set -uo pipefail
cd "$(dirname "$0")/.."
tag=$1
export JULIA_DEPOT_PATH=$PWD/${P4DEPOT:-depot-p4}:$HOME/.julia: JULIA_PKG_OFFLINE=true OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_NUM_PRECOMPILE_TASKS=4
unset JULIA_COMPILE_BY_FACTS JULIA_TW_STRICT
f=${P4LOGDIR:-logs/p4}/rhs-$tag.log
{ echo "# P4 $(git -C pkgs/NetworkDynamics-p4 log -1 --format=%h) dirty=$(git -C pkgs/NetworkDynamics-p4 status --porcelain --untracked-files=no | wc -l) graphs=$(grep -o "pkgs/Graphs[^\"]*" ${P4ENV:-env_p4}/Project.toml):$(git -C pkgs/Graphs-p4 log -1 --format=%h) dirty=$(git -C pkgs/Graphs-p4 status --porcelain --untracked-files=no | wc -l) TraitWorld(${TWDIR:-TraitWorld}) $(git -C ../${TWDIR:-TraitWorld} log -1 --format=%h) date $(date -Is) load $(cut -d' ' -f1 /proc/loadavg)"; } > $f
flock /tmp/claude-1000/julia-review.lock nice -n 19 timeout 900 ../julia-1.13/julia --startup-file=no -t 2 --project=${P4ENV:-env_p4} scripts/rhs_check.jl "${@:2}" >> $f 2>&1
echo "rc=$?"
grep -E '^(E|S1|sametype|A) ' $f; grep '^sametype' $f
if diff <(grep -E '^(R|J) ' logs/p4/rhs-U.log) <(grep -E '^(R|J) ' $f); then echo "R/J: equal to U"; else echo "R/J: DIFFER from U"; fi
