#!/usr/bin/env bash
# The workload's variant for the ports (NDW_API=ports) on Julia's unified build, setting PT, in fresh sessions.
#     scripts/u_workload.sh <name> [runs=1]          logs: logs/unified/<name>-<run>.log
# The environment env_unified_r5 (NetworkDynamics, Graphs and GraphMakie `unified` worktrees, TDE, TraitMakie and
# TraitWorld `-unified`), the workspace's depot (env.sh), one thread, offline, never precompiling, niced, one job at a
# time. Run `JULIA_PKG_OFFLINE=true ../julia-unified/julia --project=env_unified_r5 -e 'using Pkg; Pkg.precompile()'`
# after a build first. NDW_TRACE=<file> adds --trace-compile=<file> --trace-compile-timing to the run.
set -uo pipefail
cd "$(dirname "$0")/.."
ND=$PWD; R=$(cd .. && pwd)
source "$R/env.sh" >/dev/null 2>&1
name=$1; runs=${2:-1}
J=$R/julia-unified/julia; ENVD=env_unified_r5
export OPENBLAS_NUM_THREADS=1 JULIA_PKG_OFFLINE=true JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_NUM_THREADS=1
export NDW_API=ports NDW_STACK=ports NDW_PASSES=${NDW_PASSES:-first,again,params,changed,graphtype}
unset JULIA_COMPILE_BY_FACTS JULIA_TW_STRICT
TRACE=(); [ -n "${NDW_TRACE:-}" ] && TRACE=(--trace-compile="$NDW_TRACE" --trace-compile-timing)
LOGDIR=logs/unified; mkdir -p $LOGDIR
rev() { echo "$(git -C $1 log -1 --format=%h)$([ -z "$(git -C $1 status --porcelain --untracked-files=no)" ] || echo '*')"; }
for i in $(seq 1 "$runs"); do
  f=$LOGDIR/$name-$i.log
  {
    echo "# setting=PT(unified) env=$ENVD depot=$JULIA_DEPOT_PATH strict=off passes=$NDW_PASSES trace=${NDW_TRACE:-none}"
    echo "# unified $(rev $R/julia-unified) TraitWorld $(rev $R/TraitWorld-unified) TDE $(rev $R/TraitDifferentialEquations-unified) TraitMakie $(rev $R/TraitMakie-unified) ND $(rev pkgs/NetworkDynamics-unified) GraphMakie $(rev pkgs/GraphMakie-unified) Graphs $(rev pkgs/Graphs-unified) ndport $(rev .)"
    echo "# date $(date -Is) load-before $(cut -d' ' -f1 /proc/loadavg)"
  } > "$f"
  t0=$(date +%s.%N)
  nice -n 10 timeout -s KILL 1500 "$J" --startup-file=no --threads=1 "${TRACE[@]}" --project=$ENVD scripts/workload.jl >> "$f" 2>&1; rc=$?
  t1=$(date +%s.%N)
  echo "# rc=$rc session $(echo "$t1 - $t0" | bc) load-after $(cut -d' ' -f1 /proc/loadavg)" >> "$f"
  grep -q "Precompiling" "$f" && echo "# NOTE: the run precompiled" >> "$f"
  echo "run $i rc=$rc session $(echo "$t1 - $t0" | bc) $(grep '^W total' "$f") $(grep -c '^D ' "$f") digests"
done
