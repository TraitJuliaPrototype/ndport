#!/usr/bin/env bash
# R7 (E-249, E-250): precompile one setting through the machine's slots (experiments/tools/jl, its own depot
# /tmp/claude-1000/depots/<slot name> stacked first); log to logs/r7/pc-<setting>.log
#     scripts/r7_pc.sh <PT|PTs|U|M|S>
# PT: env_r5 over depot-ports (slot depot ndr7); PTs: the same with strict mode on, over depot-ports-strict (ndr7s);
# U: env_upstream over ~/.julia (ndr7u; U and U′ share it); M: env_merged over depot-merged (ndr7m; strict mode on,
# as E-235's rebuild); S: stock 1.13.2, env_upstream over depot-stock (ndr7S).
# r7_time.sh stacks the same slot depot first, so the exclusive runs read these caches.
set -uo pipefail
cd "$(dirname "$0")/.."
ND=$PWD; setting=$1
J=../julia-1.13/julia
export JULIA_PKG_OFFLINE=true JULIA_PKG_PRECOMPILE_AUTO=0 OPENBLAS_NUM_THREADS=1
unset JULIA_TW_STRICT JULIA_COMPILE_BY_FACTS
case $setting in
  PT)  ENVD=env_r5; JLN=ndr7; export JULIA_DEPOT_PATH=$ND/depot-ports:$HOME/.julia: ;;
  PTs) ENVD=env_r5; JLN=ndr7s; export JULIA_DEPOT_PATH=$ND/depot-ports-strict:$HOME/.julia: JULIA_TW_STRICT=1 ;;
  U)   ENVD=env_upstream; JLN=ndr7u; export JULIA_DEPOT_PATH=$HOME/.julia: ;;
  M)   ENVD=env_merged; JLN=ndr7m; export JULIA_DEPOT_PATH=$ND/depot-merged:$HOME/.julia: JULIA_TW_STRICT=1 ;;
  S)   ENVD=env_upstream; JLN=ndr7S; J=$HOME/.julia/juliaup/julia-1.13.2+0.x64.linux.gnu/bin/julia; export JULIA_DEPOT_PATH=$ND/depot-stock:$HOME/.julia: ;;
  *) echo "unknown setting $setting"; exit 2 ;;
esac
mkdir -p logs/r7; f=logs/r7/pc-$setting.log
dirty() { [ -z "$(git -C $1 status --porcelain --untracked-files=no)" ] || echo '*'; }
echo "# setting=$setting env=$ENVD julia=$J depot=$JULIA_DEPOT_PATH strict=${JULIA_TW_STRICT:-0} $(date -Is) julia-1.13 $(git -C ../julia-1.13 log -1 --format=%h) TraitWorld $(git -C ../TraitWorld log -1 --format=%h)$(dirty ../TraitWorld) TDE $(git -C ../TraitDifferentialEquations log -1 --format=%h)$(dirty ../TraitDifferentialEquations) TraitMakie $(git -C ../TraitMakie log -1 --format=%h)$(dirty ../TraitMakie) ND-ports $(git -C pkgs/NetworkDynamics-ports log -1 --format=%h)$(dirty pkgs/NetworkDynamics-ports) GraphMakie-ports $(git -C pkgs/GraphMakie-ports log -1 --format=%h)$(dirty pkgs/GraphMakie-ports)" > $f
t0=$(date +%s)
../experiments/tools/jl --name $JLN timeout -s KILL 3000 $J --startup-file=no --project=$ENVD -e 'using Pkg; t = @elapsed Pkg.precompile(); println("precompile s=", round(t; digits = 1))' >> $f 2>&1
rc=$?; echo "# rc=$rc wall=$(( $(date +%s) - t0 ))s" >> $f
grep -m1 -B2 -A20 'ERROR' $f | cut -c1-400 || tail -3 $f
exit $rc
