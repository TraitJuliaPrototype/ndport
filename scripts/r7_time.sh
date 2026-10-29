#!/usr/bin/env bash
# R7 (E-250): the measured sessions. Fresh sessions one at a time under `experiments/tools/jl --exclusive` (all cores,
# niced, one Julia thread, offline, never precompiling); each session timed from process start to exit by
# /usr/bin/time (`# wall <s>`). Logs: logs/r7/time/<setting>-<run>.log (run 0: the warm-up, not counted).
#     scripts/r7_time.sh <PT|UP|U|S|M> [runs=2]
# PT: env_r5, NDW_API=ports (as r5_workload.sh); UP (U′): env_upstream, NDW_API=ports; U: env_upstream, P1's workload;
# S: stock 1.13.2, depot-stock, P1's workload; M: env_merged, depot-merged, P1's workload (p6_workload.jl, TraitWorld
# loaded first, as run_workload.sh). The passes first, again, params, changed; strict mode off; P1's load order.
# The slot depot r7_pc.sh precompiled into (/tmp/claude-1000/depots/ndr7*) is stacked first.
set -uo pipefail
cd "$(dirname "$0")/.."
ND=$PWD; R=$(cd .. && pwd); setting=$1; runs=${2:-2}
J=$R/julia-1.13/julia; D=/tmp/claude-1000/depots; SCRIPT=scripts/workload.jl
unset JULIA_TW_STRICT JULIA_COMPILE_BY_FACTS NDW_API NDW_STACK NDW_TRAITWORLD
case $setting in
  PT) ENVD=env_r5; export JULIA_DEPOT_PATH=$D/ndr7:$ND/depot-ports:$HOME/.julia: NDW_API=ports NDW_STACK=ports ;;
  UP) ENVD=env_upstream; export JULIA_DEPOT_PATH=$D/ndr7u:$HOME/.julia: NDW_API=ports NDW_STACK=upstream ;;
  U)  ENVD=env_upstream; export JULIA_DEPOT_PATH=$D/ndr7u:$HOME/.julia: ;;
  S)  ENVD=env_upstream; J=$HOME/.julia/juliaup/julia-1.13.2+0.x64.linux.gnu/bin/julia; export JULIA_DEPOT_PATH=$D/ndr7S:$ND/depot-stock:$HOME/.julia: ;;
  M)  ENVD=env_merged; SCRIPT=scripts/p6_workload.jl; export JULIA_DEPOT_PATH=$D/ndr7m:$ND/depot-merged:$HOME/.julia: NDW_TRAITWORLD=1 ;;
  *) echo "unknown setting $setting"; exit 2 ;;
esac
export OPENBLAS_NUM_THREADS=1 JULIA_PKG_OFFLINE=true JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_NUM_THREADS=1 NDW_PASSES=first,again,params,changed
L=logs/r7/time; mkdir -p $L
dirty() { [ -z "$(git -C $1 status --porcelain --untracked-files=no)" ] || echo '*'; }
for i in $(seq 0 "$runs"); do
  f=$L/$setting-$i.log
  {
    echo "# setting=$setting env=$ENVD julia=$J depot=$JULIA_DEPOT_PATH api=${NDW_API:-upstream} script=$SCRIPT strict=off passes=$NDW_PASSES run=$i$([ $i = 0 ] && echo ' (warm-up)') jl --exclusive (all cores, nice 19), one thread"
    echo "# julia-1.13 $(git -C $R/julia-1.13 log -1 --format=%h) TraitWorld $(git -C $R/TraitWorld log -1 --format=%h)$(dirty $R/TraitWorld) TDE $(git -C $R/TraitDifferentialEquations log -1 --format=%h)$(dirty $R/TraitDifferentialEquations) TraitMakie $(git -C $R/TraitMakie log -1 --format=%h)$(dirty $R/TraitMakie) ND-ports $(git -C pkgs/NetworkDynamics-ports log -1 --format=%h)$(dirty pkgs/NetworkDynamics-ports) GraphMakie-ports $(git -C pkgs/GraphMakie-ports log -1 --format=%h)$(dirty pkgs/GraphMakie-ports) ND-port $(git -C pkgs/NetworkDynamics-p4 log -1 --format=%h 2>/dev/null) ndport $(git log -1 --format=%h)$(dirty .)"
    echo "# queued $(date -Is)"
  } > "$f"
  $R/experiments/tools/jl --exclusive bash -c 'echo "# start $(date -Is) load-before $(cut -d" " -f1 /proc/loadavg)"; exec timeout -s KILL 1500 /usr/bin/time -f "# wall %e s maxrss %M kB" "$@"' _ \
      "$J" --startup-file=no --threads=1 --project=$ENVD $SCRIPT >> "$f" 2>&1; rc=$?
  echo "# rc=$rc load-after $(cut -d' ' -f1 /proc/loadavg)" >> "$f"
  grep -q "Precompiling" "$f" && echo "# INVALID: the run precompiled" >> "$f"
  echo "$setting-$i rc=$rc $(grep '^# wall' "$f") $(grep '^W total' "$f") $(grep -c '^D ' "$f") digests $(grep -q INVALID "$f" && echo INVALID)"
done
