#!/usr/bin/env bash
# Check (P) of the traits plan §2.4: NetworkDynamics and its extensions precompile in env_p4 (depot-p4),
# which runs the trait module's definition checks. scripts/p4_precompile.sh <tag> -> logs/p4/precompile-<tag>.log
# P4LOGDIR=<dir>: the log directory instead of logs/p4.
set -uo pipefail
cd "$(dirname "$0")/.."
tag=$1
export JULIA_DEPOT_PATH=$PWD/depot-p4:$HOME/.julia: JULIA_PKG_OFFLINE=true OPENBLAS_NUM_THREADS=1 JULIA_NUM_PRECOMPILE_TASKS=4
unset JULIA_COMPILE_BY_FACTS JULIA_TW_STRICT
f=${P4LOGDIR:-logs/p4}/precompile-$tag.log
echo "# P4 $(git -C pkgs/NetworkDynamics-p4 log -1 --format=%h) dirty=$(git -C pkgs/NetworkDynamics-p4 status --porcelain --untracked-files=no | wc -l) graphs=$(grep -o "pkgs/Graphs[^\"]*" env_p4/Project.toml):$(git -C pkgs/Graphs-p4 log -1 --format=%h) dirty=$(git -C pkgs/Graphs-p4 status --porcelain --untracked-files=no | wc -l) date $(date -Is)" > $f
flock /tmp/claude-1000/julia-review.lock nice -n 19 timeout 1800 ../julia-1.13/julia --startup-file=no --project=env_p4 \
  -e 'using Pkg; Pkg.precompile(); t = @elapsed using NetworkDynamics; println("using s=", round(t; digits = 1))' >> $f 2>&1
echo "rc=$?"; grep -v "^\s*$" $f | grep -v "could not download\|exception = RequestError\|@ Pkg.Registry\|^┌ Warning\|^└" | tail -25
