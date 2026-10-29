#!/usr/bin/env bash
# Run the workload in fresh sessions (the P1 plan §3): one Julia job at a time through the shared
# lock, niced, offline, never precompiling. Logs to logs/<tag>/<setting>-<run>.log.
#     scripts/run_workload.sh <tag> <setting: U|P0|A0|S|N|W|P4|I|P4P|IP|M> [runs=1]
# NDW_DIAG=1 adds the attribution run's instrument (diagnostic, not timed). NDW_STRICT=1: strict mode on. NDW_SCRIPT=<path>: another script in the same harness. NDW_ORDER=simfirst: P3's order B.
set -uo pipefail
cd "$(dirname "$0")/.."
ND=$PWD; R=$(cd .. && pwd)
tag=$1; setting=$2; runs=${3:-1}
J=$R/julia-1.13/julia; JF=(); DEPOT=""; ENVD=env_upstream; TW=0; WMOD=0; DEFSCRIPT=scripts/workload.jl; TWDIR=TraitWorld
case $setting in
  U)  ;;
  P0) ENVD=env_port; TW=1 ;;
  A0) ENVD=env_port; TW=1; JF=(-J "$R/julia-1.13/usr/lib/julia/facts/sys.so"); DEPOT="$ND/depot-facts:$HOME/.julia:" ;;
  N)  ENVD=env_p3; TW=1; DEPOT="$ND/depot-p3:$HOME/.julia:" ;;   # P3: NetworkDynamics wrapped (pkgs/NetworkDynamics-p3wrap)
  W)  ENVD=env_p3; TW=1; WMOD=1; DEPOT="$ND/depot-p3:$HOME/.julia:" ;;   # P3: N plus the workload's module a trait module
  P4) ENVD=env_p4; TW=1; DEPOT="$ND/depot-p4:$HOME/.julia:" ;;   # P4: the port (pkgs/NetworkDynamics-p4, branch trait-port)
  I)  ENVD=env_p6; TW=1; DEPOT="$ND/depot-p6:$HOME/.julia:"; DEFSCRIPT=scripts/p6_workload.jl ;;   # P6 (E-155): the core wrapped inside out (pkgs/*-p6), NetworkDynamics as in N; prints STRICT
  P4P) ENVD=env_p4_pin; TW=1; TWDIR=TraitWorld-port; DEPOT="$ND/depot-p4pin:$HOME/.julia:" ;;   # P4 on the pinned TraitWorld (E-165: the steady-state reference)
  IP) ENVD=env_p6_pin; TW=1; TWDIR=TraitWorld-port; DEPOT="$ND/depot-p6pin:$HOME/.julia:"; DEFSCRIPT=scripts/p6_workload.jl ;;   # P6's last step (S7) on the pinned TraitWorld (E-165)
  M)  ENVD=env_merged; TW=1; TWDIR=TraitWorld; DEPOT="$ND/depot-merged:$HOME/.julia:"; DEFSCRIPT=scripts/p6_workload.jl ;;   # the merge (E-165): P4's NetworkDynamics and Graphs on P6's core, branches `port`; prints STRICT; TraitWorld main from 2026-10-29 (E-235; before: TraitWorld-port)
  S)  J=$HOME/.julia/juliaup/julia-1.13.2+0.x64.linux.gnu/bin/julia; DEPOT="$ND/depot-stock:$HOME/.julia:" ;;
  *) echo "unknown setting $setting"; exit 2 ;;
esac
export OPENBLAS_NUM_THREADS=1 JULIA_PKG_OFFLINE=true JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_NUM_PRECOMPILE_TASKS=1 JULIA_NUM_THREADS=1
unset JULIA_COMPILE_BY_FACTS
if [ "${NDW_STRICT:-0}" = 1 ]; then export JULIA_TW_STRICT=1; STRICT=on; else unset JULIA_TW_STRICT; STRICT=off; fi
[ -n "$DEPOT" ] && export JULIA_DEPOT_PATH=$DEPOT || unset JULIA_DEPOT_PATH
L=$ND/logs/$tag; mkdir -p "$L"
jl() { flock /tmp/claude-1000/julia-review.lock taskset -c 0-1 ionice -c3 nice -n 19 timeout -s KILL 900 "$J" "${JF[@]}" --startup-file=no --threads=1 --project=$ENVD "$@"; }
# every direct dependency precompiled in this setting, or the run is skipped
miss=$(jl -e 'using Pkg; for (n, u) in Pkg.project().dependencies; Base.isprecompiled(Base.PkgId(u, n)) || print(n, " "); end')
if [ -n "$miss" ]; then echo "$setting: not precompiled: $miss -- skipped"; exit 3; fi
for i in $(seq 1 "$runs"); do
  f=$L/$setting-$i.log
  for attempt in 1 2; do
    {
      echo "# setting=$setting order=${NDW_ORDER:-default} script=${NDW_SCRIPT:-$DEFSCRIPT} env=$ENVD julia=$J ${JF[*]} depot=${JULIA_DEPOT_PATH:-default} strict=$STRICT diag=${NDW_DIAG:-0} cpus=0-1(taskset) ionice=idle"
      echo "# julia-1.13 $(git -C $R/julia-1.13 log -1 --format=%h) lib-built $(stat -c %y $R/julia-1.13/usr/lib/libjulia-internal.so.1.13.2 | cut -c1-16) TraitWorld($TWDIR) $(git -C $R/$TWDIR log -1 --format=%h) dirty=$(git -C $R/$TWDIR status --porcelain --untracked-files=no | wc -l)"
      echo "# clones $(for d in pkgs/*/; do printf '%s:%s%s ' $(basename $d) $(git -C $d log -1 --format=%h) $([ -z "$(git -C $d status --porcelain --untracked-files=no)" ] || echo '*'); done)"
      echo "# date $(date -Is) load-before $(cut -d' ' -f1 /proc/loadavg)"
    } > "$f"
    NDW_TRAITWORLD=$TW NDW_W=$WMOD jl ${NDW_SCRIPT:-$DEFSCRIPT} >> "$f" 2>&1; rc=$?
    lb=$(cut -d' ' -f1 /proc/loadavg); echo "# rc=$rc load-after $lb" >> "$f"
    grep -q "Precompiling" "$f" && echo "# INVALID: the run precompiled" >> "$f"
    awk -v l="$lb" 'BEGIN{exit !(l > 4)}' && [ $attempt = 1 ] && { mv "$f" "$f.loaded"; continue; }
    break
  done
  echo "$setting-$i rc=$rc $(grep '^W total' "$f") $(grep -c '^D ' "$f") digests $(grep -q INVALID "$f" && echo INVALID)"
done
