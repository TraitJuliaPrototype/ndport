#!/usr/bin/env bash
# R5 (E-246): the workload's variant for the ports (NDW_API=ports) in fresh sessions, in setting PT or its reference U′.
#     scripts/r5_workload.sh <name> <PT|UP> [runs=1]      logs: logs/r5/<name>-<setting>-<run>.log
# PT: env_r5 (NetworkDynamics `ports` on TDE `w34`, GraphMakie `ports` over MakieCompat and TraitMakie), depot-ports
#     (depot-ports-strict with NDW_STRICT=1). UP (U′): env_upstream (upstream NetworkDynamics, SciML, GraphMakie,
#     CairoMakie), the default depot. Both: product setting, one thread, offline, never precompiling; through the
#     machine's slots (experiments/tools/jl, its own depot stacked first). NDW_TIGHT=1: the solver tolerances 1e-12
#     (the tie-break run of the plan §5). NDW_TSTOPS=1: the steps end at TIMES too (no interpolation for the saved values). Not a measurement: the times are printed, not compared.
set -uo pipefail
cd "$(dirname "$0")/.."
ND=$PWD; R=$(cd .. && pwd)
name=$1; setting=$2; runs=${3:-1}
J=$R/julia-1.13/julia
case $setting in
  PT) ENVD=env_r5; STACK=ports; DEPOT="$ND/depot-ports:$HOME/.julia:"
      [ "${NDW_STRICT:-0}" = 1 ] && DEPOT="$ND/depot-ports-strict:$HOME/.julia:" ;;
  UP) ENVD=env_upstream; STACK=upstream; DEPOT="$HOME/.julia:" ;;
  *) echo "unknown setting $setting"; exit 2 ;;
esac
export OPENBLAS_NUM_THREADS=1 JULIA_PKG_OFFLINE=true JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_NUM_THREADS=1 JULIA_DEPOT_PATH=$DEPOT
export NDW_API=ports NDW_STACK=$STACK NDW_PASSES=${NDW_PASSES:-first,again,params,changed,graphtype}
unset JULIA_COMPILE_BY_FACTS
if [ "${NDW_STRICT:-0}" = 1 ]; then export JULIA_TW_STRICT=1; STRICT=on; else unset JULIA_TW_STRICT; STRICT=off; fi
mkdir -p logs/r5
dirty() { [ -z "$(git -C $1 status --porcelain --untracked-files=no)" ] || echo '*'; }
for i in $(seq 1 "$runs"); do
  f=logs/r5/$name-$setting-$i.log
  {
    echo "# setting=$setting api=ports stack=$STACK env=$ENVD depot=$DEPOT strict=$STRICT tight=${NDW_TIGHT:-0} tstops=${NDW_TSTOPS:-0} passes=$NDW_PASSES"
    echo "# julia-1.13 $(git -C $R/julia-1.13 log -1 --format=%h) TraitWorld $(git -C $R/TraitWorld log -1 --format=%h)$(dirty $R/TraitWorld) TDE $(git -C $R/TraitDifferentialEquations log -1 --format=%h)$(dirty $R/TraitDifferentialEquations) TraitMakie $(git -C $R/TraitMakie log -1 --format=%h)$(dirty $R/TraitMakie) ND-ports $(git -C pkgs/NetworkDynamics-ports log -1 --format=%h)$(dirty pkgs/NetworkDynamics-ports) GraphMakie-ports $(git -C pkgs/GraphMakie-ports log -1 --format=%h)$(dirty pkgs/GraphMakie-ports) ndport $(git log -1 --format=%h)$(dirty .)"
    echo "# date $(date -Is) load-before $(cut -d' ' -f1 /proc/loadavg)"
  } > "$f"
  $R/experiments/tools/jl --name ndr5 timeout -s KILL 1500 "$J" --startup-file=no --threads=1 --project=$ENVD scripts/workload.jl >> "$f" 2>&1; rc=$?
  echo "# rc=$rc load-after $(cut -d' ' -f1 /proc/loadavg)" >> "$f"
  grep -q "Precompiling" "$f" && echo "# NOTE: the run precompiled" >> "$f"
  echo "$setting-$i rc=$rc $(grep '^W total' "$f") $(grep -c '^D ' "$f") digests $(grep -c '^P ' "$f") plot lines $(grep -q 'precompiled' "$f" && echo PRECOMPILED)"
done
