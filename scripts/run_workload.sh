#!/usr/bin/env bash
# Run the workload in fresh sessions (the P1 plan §3): one Julia job at a time through the shared
# lock, niced, offline, never precompiling. Logs to logs/<tag>/<setting>-<run>.log.
#     scripts/run_workload.sh <tag> <setting: U|P0|A0|S> [runs=1]
# NDW_DIAG=1 adds the attribution run's instrument (diagnostic, not timed).
set -uo pipefail
cd "$(dirname "$0")/.."
ND=$PWD; R=$(cd .. && pwd)
tag=$1; setting=$2; runs=${3:-1}
J=$R/julia-1.13/julia; JF=(); DEPOT=""; ENVD=env_upstream; TW=0
case $setting in
  U)  ;;
  P0) ENVD=env_port; TW=1 ;;
  A0) ENVD=env_port; TW=1; JF=(-J "$R/julia-1.13/usr/lib/julia/facts/sys.so"); DEPOT="$ND/depot-facts:$HOME/.julia:" ;;
  S)  J=$HOME/.julia/juliaup/julia-1.13.2+0.x64.linux.gnu/bin/julia; DEPOT="$ND/depot-stock:$HOME/.julia:" ;;
  *) echo "unknown setting $setting"; exit 2 ;;
esac
export OPENBLAS_NUM_THREADS=1 JULIA_PKG_OFFLINE=true JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_NUM_PRECOMPILE_TASKS=4
unset JULIA_TW_STRICT JULIA_COMPILE_BY_FACTS
[ -n "$DEPOT" ] && export JULIA_DEPOT_PATH=$DEPOT || unset JULIA_DEPOT_PATH
L=$ND/logs/$tag; mkdir -p "$L"
jl() { flock /tmp/claude-1000/julia-review.lock nice -n 19 timeout 900 "$J" "${JF[@]}" --startup-file=no --threads=1 --project=$ENVD "$@"; }
# every direct dependency precompiled in this setting, or the run is skipped
miss=$(jl -e 'using Pkg; for (n, u) in Pkg.project().dependencies; Base.isprecompiled(Base.PkgId(u, n)) || print(n, " "); end')
if [ -n "$miss" ]; then echo "$setting: not precompiled: $miss -- skipped"; exit 3; fi
for i in $(seq 1 "$runs"); do
  f=$L/$setting-$i.log
  for attempt in 1 2; do
    {
      echo "# setting=$setting env=$ENVD julia=$J ${JF[*]} depot=${JULIA_DEPOT_PATH:-default} strict=off diag=${NDW_DIAG:-0}"
      echo "# julia-1.13 $(git -C $R/julia-1.13 log -1 --format=%h) TraitWorld $(git -C $R/TraitWorld log -1 --format=%h) dirty=$(git -C $R/TraitWorld status --porcelain --untracked-files=no | wc -l)"
      echo "# clones $(for d in pkgs/*/; do printf '%s:%s%s ' $(basename $d) $(git -C $d log -1 --format=%h) $([ -z "$(git -C $d status --porcelain --untracked-files=no)" ] || echo '*'); done)"
      echo "# date $(date -Is) load-before $(cut -d' ' -f1 /proc/loadavg)"
    } > "$f"
    NDW_TRAITWORLD=$TW jl scripts/workload.jl >> "$f" 2>&1; rc=$?
    lb=$(cut -d' ' -f1 /proc/loadavg); echo "# rc=$rc load-after $lb" >> "$f"
    grep -q "Precompiling" "$f" && echo "# INVALID: the run precompiled" >> "$f"
    awk -v l="$lb" 'BEGIN{exit !(l > 4)}' && [ $attempt = 1 ] && { mv "$f" "$f.loaded"; continue; }
    break
  done
  echo "$setting-$i rc=$rc $(grep '^W total' "$f") $(grep -c '^D ' "$f") digests $(grep -q INVALID "$f" && echo INVALID)"
done
