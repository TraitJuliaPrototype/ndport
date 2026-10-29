#!/usr/bin/env bash
# R6 (E-247): precompile setting PT (env_r5, depot-ports; strict mode on: depot-ports-strict) through the machine's
# slots (experiments/tools/jl, its own depot ndr6 or ndr6s stacked first); log to logs/r6/<name>.log
#     scripts/r6_pc.sh <name>          NDW_STRICT=1: strict mode on
set -uo pipefail
cd "$(dirname "$0")/.."
name=$1
export JULIA_PKG_OFFLINE=true JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_DEPOT_PATH=$PWD/depot-ports:$HOME/.julia:
unset JULIA_TW_STRICT JULIA_COMPILE_BY_FACTS; JLN=ndr6
if [ "${NDW_STRICT:-0}" = 1 ]; then export JULIA_TW_STRICT=1 JULIA_DEPOT_PATH=$PWD/depot-ports-strict:$HOME/.julia:; JLN=ndr6s; fi
mkdir -p logs/r6; f=logs/r6/$name.log
dirty() { [ -z "$(git -C $1 status --porcelain --untracked-files=no)" ] || echo '*'; }
echo "# strict=${NDW_STRICT:-0} $(date -Is) env=env_r5 julia-1.13 $(git -C ../julia-1.13 log -1 --format=%h) TraitWorld $(git -C ../TraitWorld log -1 --format=%h)$(dirty ../TraitWorld) TDE $(git -C ../TraitDifferentialEquations log -1 --format=%h)$(dirty ../TraitDifferentialEquations) TraitMakie $(git -C ../TraitMakie log -1 --format=%h)$(dirty ../TraitMakie) ND-ports $(git -C pkgs/NetworkDynamics-ports log -1 --format=%h)$(dirty pkgs/NetworkDynamics-ports) GraphMakie-ports $(git -C pkgs/GraphMakie-ports log -1 --format=%h)$(dirty pkgs/GraphMakie-ports)" > $f
../experiments/tools/jl --name $JLN timeout -s KILL 2400 ../julia-1.13/julia --startup-file=no --project=env_r5 -e 'using Pkg; Pkg.precompile()' >> $f 2>&1
rc=$?; echo "# rc=$rc" >> $f
grep -m1 -B2 -A20 'ERROR' $f | cut -c1-400 || tail -4 $f
exit $rc
