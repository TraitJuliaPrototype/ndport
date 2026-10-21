#!/usr/bin/env bash
# E-151, the baselines (the P1 plan §3.2): U and P0 twice, A0 once; stock precompiled into its own
# depot, then S once; the attribution run in U. Logs in logs/p1/.
cd "$(dirname "$0")/.."
S=scripts/run_workload.sh
cp env_port/Manifest.toml logs/p1-env_port-Manifest.toml 2>/dev/null
python3 -I scripts/check_env.py > logs/p1-check_env.log
$S p1 U 2; $S p1 P0 2; $S p1 A0 1
SJ=$HOME/.julia/juliaup/julia-1.13.2+0.x64.linux.gnu/bin/julia
mkdir -p depot-stock
( export JULIA_DEPOT_PATH=$PWD/depot-stock:$HOME/.julia: JULIA_PKG_OFFLINE=true JULIA_NUM_PRECOMPILE_TASKS=4 OPENBLAS_NUM_THREADS=1
  echo "# stock: $($SJ --version)"
  flock /tmp/claude-1000/julia-review.lock nice -n 19 $SJ --project=env_upstream -e 'using Pkg; t=@elapsed Pkg.precompile(); println("precompile s=", round(t,digits=1))' ) > logs/setup/precompile-stock.log 2>&1
tail -1 logs/setup/precompile-stock.log
$S p1 S 1
NDW_DIAG=1 $S p1-diag U 1
echo e151 done
