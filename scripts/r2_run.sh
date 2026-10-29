#!/usr/bin/env bash
# R2 (E-239): run a script in setting PT (env_ports, depot-ports), product setting, strict mode off,
# through the shared lock, niced; never precompiling. Log: logs/r2-tde/<name>.log
#     scripts/r2_run.sh <name> <script> [env]
set -uo pipefail
cd "$(dirname "$0")/.."
name=$1; script=$2; envd=${3:-env_ports}
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4 JULIA_PKG_PRECOMPILE_AUTO=0 OPENBLAS_NUM_THREADS=1 JULIA_DEPOT_PATH=$PWD/depot-ports:$HOME/.julia:
unset JULIA_TW_STRICT JULIA_COMPILE_BY_FACTS
if [ "${R1_STRICT:-0}" = 1 ]; then export JULIA_TW_STRICT=1 JULIA_DEPOT_PATH=$PWD/depot-ports-strict:$HOME/.julia:; fi   # strict mode on, its own depot
mkdir -p logs/r2-tde; f=logs/r2-tde/$name.log
dirty() { [ -z "$(git -C $1 status --porcelain --untracked-files=no)" ] || echo '*'; }
echo "# strict=${R1_STRICT:-0} $(date -Is) script=$script env=$envd julia-1.13 $(git -C ../julia-1.13 log -1 --format=%h) TraitWorld $(git -C ../TraitWorld log -1 --format=%h)$(dirty ../TraitWorld) TDE $(git -C ../TraitDifferentialEquations log -1 --format=%h)$(dirty ../TraitDifferentialEquations) TraitMakie $(git -C ../TraitMakie log -1 --format=%h)$(dirty ../TraitMakie) ND-ports $(git -C pkgs/NetworkDynamics-ports log -1 --format=%h)$(dirty pkgs/NetworkDynamics-ports) GraphMakie $(git -C pkgs/GraphMakie.jl log -1 --format=%h)$(dirty pkgs/GraphMakie.jl) load $(cut -d' ' -f1 /proc/loadavg)" > $f
../experiments/tools/jl --name r2-tde timeout -s KILL 1200 ../julia-1.13/julia --startup-file=no ${R1_JFLAGS:-} --project=$envd "$script" >> $f 2>&1
echo "# rc=$?" >> $f
grep -c Precompiling $f >/dev/null && grep -q Precompiling $f && echo "# NOTE: the run precompiled" >> $f
grep -E '^(R1|# rc|ERROR)' $f | cut -c1-330
