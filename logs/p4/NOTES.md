# P4 step 1 (E-152): running notes

The traits plan: `writeup/plans/2026-10-21-ndport-traits.md` §2 (steps S0–S8), §3 (criteria). The worktree
`pkgs/NetworkDynamics-p4`, branch `trait-port`, from `p3-wrap` (e5425fd). Julia 1.13 patched, TraitWorld e9f4bfe.
These notes are working notes for the coordinator: what changed, each check's result, surprises, candidate
pushback entries, lessons for the guideline (B5). Not normative.

## S0: environments, references

- `env_p4` resolved offline, precompiled into `depot-p4` (17 packages: Static's dependents and ND; 100 s;
  `s0-precompile.log`).
- `scripts/rhs_check.jl` (new), `scripts/rhs_p4.sh` (P4 setting, diff of R/J lines against U).
  - Networks: tier S with `swing!` and `swing2!` (the workload's components, `dealias = true`); `ff`, a
    six-vertex network built for the review's finding 7: hubs with NoFeedForward, PureStateMap, pdim 0 and an
    external input; injectors with FeedForward and PureFeedForward (dim 0) on loopback edges; edges
    PureFeedForward (static), FeedForward, NoFeedForward, PureStateMap with an external input.
  - Styles: Sequential, Threaded, Polyester, KA, each buffered and not; two threads.
  - U: `rhs-U.log` (env_upstream, the registry's ND 1.3.0). P at S0: `rhs-s0.log`. **R/J equal to U.**
- **Upstream's own failures, seen in U and P alike** (not port bugs; the rows carry them as they are):
  - `get_buffers` under `KAExecution` fails (`get_backend(nothing)`, `coreloop.jl:103–109` passes `du = nothing`);
    rhs_check prints `o=error:MethodError` for those rows.
  - `KAExecution` on any network with a feed-forward edge fails: `compkernel_fg!` names its argument
    `inbuf` and uses `inbufs` (`coreloop.jl:160–165`), an `UndefVarError`. The `ff` rows of KA are `E` lines.
- `sametype=false` at S0, as expected.
- Allocations and time at S0 (`A` lines): Sequential 0 allocs, 0.52 µs per call (U 0.50–0.56 µs).
  **Threaded in the wrapped package: 5,200 allocs and 43.8 µs per call, against 2,848 and 9.2 µs in U.**
  The wrapped package (facts mode) makes `Threads.@threads` four to five times slower than upstream. Not the
  port's subject; threads are untested in the facts mode (evidence §5). A candidate for P3's record.
- ND test subset: `scripts/nd_tests.jl` (driver), `scripts/nd_testutils.jl` (upstream's `testutils.jl` without
  CUDA), `scripts/nd_tests.sh <u|p4> <tag>`; environments `env_ndtest_u` (env_port + OrdinaryDiffEqNonlinearSolve
  2.9.9, Test, …; default depot) and `env_ndtest_p4` (env_p4 + the same; depot-p4).
  - At `upstream` (`ndtest-upstream.log`): massmatrix 6 pass; doctor 26; diffusion 112 pass, 24 broken;
    inhomogeneous 45 pass, 12 broken. The broken ones are upstream's `@test_broken` for KA (`Base.elsize`).
  - The P4 worktree at S0 (the wrap, `ndtest-p4-s0.log`): the same counts.
