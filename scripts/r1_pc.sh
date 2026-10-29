#!/usr/bin/env bash
# R1 (E-236): precompile setting PT (env_ports, depot-ports) and load NetworkDynamics; log to logs/r1/<name>.log
set -uo pipefail
cd "$(dirname "$0")/.."
name=$1; envd=${2:-env_ports}
export JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4 JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_DEPOT_PATH=$PWD/depot-ports:$HOME/.julia:
unset JULIA_TW_STRICT JULIA_COMPILE_BY_FACTS
f=logs/r1/$name.log
echo "# $(date -Is) env=$envd julia-1.13 $(git -C ../julia-1.13 log -1 --format=%h) TraitWorld $(git -C ../TraitWorld log -1 --format=%h) TDE $(git -C ../TraitDifferentialEquations log -1 --format=%h) TraitMakie $(git -C ../TraitMakie log -1 --format=%h) ND-ports $(git -C pkgs/NetworkDynamics-ports log -1 --format=%h)$([ -z "$(git -C pkgs/NetworkDynamics-ports status --porcelain --untracked-files=no)" ] || echo '*')" > $f
flock /tmp/claude-1000/julia-review.lock nice -n 19 timeout -s KILL 1500 ../julia-1.13/julia --startup-file=no --project=$envd -e 'using Pkg; Pkg.precompile()' >> $f 2>&1
rc=$?; echo "# rc=$rc" >> $f
grep -m1 -B2 -A12 '^ERROR' $f | cut -c1-400 || tail -5 $f
exit $rc
