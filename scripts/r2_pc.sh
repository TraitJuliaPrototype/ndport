#!/usr/bin/env bash
# R2 (E-239): precompile setting PT (env_ports, depot-ports) and load NetworkDynamics; log to logs/r2-tde/<name>.log
set -uo pipefail
cd "$(dirname "$0")/.."
name=$1; envd=${2:-env_ports}; pre=${R1_PRE:-}
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4 JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_DEPOT_PATH=$PWD/depot-ports:$HOME/.julia:
unset JULIA_TW_STRICT JULIA_COMPILE_BY_FACTS
if [ "${R1_STRICT:-0}" = 1 ]; then export JULIA_TW_STRICT=1 JULIA_DEPOT_PATH=$PWD/depot-ports-strict:$HOME/.julia:; fi   # strict mode on, its own depot
mkdir -p logs/r2-tde; f=logs/r2-tde/$name.log
echo "# strict=${R1_STRICT:-0} $(date -Is) env=$envd julia-1.13 $(git -C ../julia-1.13 log -1 --format=%h) TraitWorld $(git -C ../TraitWorld log -1 --format=%h) TDE $(git -C ../TraitDifferentialEquations log -1 --format=%h) TraitMakie $(git -C ../TraitMakie log -1 --format=%h) ND-ports $(git -C pkgs/NetworkDynamics-ports log -1 --format=%h)$([ -z "$(git -C pkgs/NetworkDynamics-ports status --porcelain --untracked-files=no)" ] || echo '*')" > $f
../experiments/tools/jl --name r2-tde timeout -s KILL 1500 ../julia-1.13/julia --startup-file=no --project=$envd -e "using Pkg; $pre Pkg.precompile()" >> $f 2>&1
rc=$?; echo "# rc=$rc" >> $f
grep -m1 -B2 -A12 '^ERROR' $f | cut -c1-400 || tail -5 $f
exit $rc
