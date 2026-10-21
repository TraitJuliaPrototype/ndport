#!/usr/bin/env bash
# P6 (E-155): a step's two sessions through the harness (setting I, strict on): C+H (the census and the profile,
# logs/p6-s<k>-census/) and R (the workload, logs/p6-s<k>/); then the summaries against I0 (S0).
#     scripts/p6_step.sh <k> [extra env for the C+H session, e.g. NDW_FOLD=1]
set -uo pipefail
cd "$(dirname "$0")/.."
k=$1; shift
env NDW_STRICT=1 JULIA_FACTS_DISPATCH_PROFILE=1 NDW_SCRIPT=scripts/p6_census.jl "$@" scripts/run_workload.sh p6-s$k-census I 1 2>&1 | tail -1
NDW_STRICT=1 scripts/run_workload.sh p6-s$k I 1
python3 scripts/compare_digests.py logs/p1/U-1.log logs/p6-s$k/I-1.log --exact | tail -1
python3 scripts/p6_summary.py logs/p6-s$k/I-1.log logs/p6-s0/I-1.log
grep -E "^STRICT|^C |PirateError" logs/p6-s$k-census/I-1.log
python3 scripts/p6_profile_summary.py logs/p6-s$k-census/I-1.log logs/p6-s0-census/I-1.log
python3 scripts/p6_census_filter.py logs/p6-s$k-census/I-1.log | grep "^F [A-Z]"
