# P6 (E-155): running notes

The inside-out track of W-32: the SciML core under NetworkDynamics wrapped as trait modules from the bottom up, under
strict mode. The plan: `writeup/plans/2026-10-21-ndport-inside-out.md` (adopted; its review folded in). These notes
are the record for the coordinator: per step what changed (commits), each check's result, surprises, candidate
pushback entries, lessons for the guideline's B5, and anything for the user. Not edited into `writeup/` by P6.

Fixed for the whole track: julia-1.13 6d480d0753; TraitWorld 3bebf13 (pinned; checked in each log header);
NetworkDynamics `pkgs/NetworkDynamics-p3wrap` e5425fd (read only); Static `pkgs/Static.jl` c34adbb (read only).
Environment `env_p6` (manifest committed per step), depot `depot-p6`. Harness setting `I` (`scripts/run_workload.sh`;
the default script for I is `scripts/p6_workload.jl`, which includes `workload.jl` unchanged and prints `STRICT`).
P6 does not edit `workload.jl` or `workload_steps.jl` (the Graph step edits them; nothing to merge from P6).

## Workspace (S0)

- Worktrees of P0's clones, branch `p6-inside-out` from `upstream`: `pkgs/SymbolicIndexingInterface-p6`,
  `RecursiveArrayTools-p6`, `SciMLBase-p6`, `DiffEqCallbacks-p6`, `OrdinaryDiffEq-p6` (53e7d1d: DiffEqBase,
  OrdinaryDiffEqCore, OrdinaryDiffEqTsit5).
- `pkgs/OrdinaryDiffEq-p6-ros`: a second worktree of the monorepo at 14f664a, branch `p6-inside-out-ros`, tag
  `upstream-ros` (OrdinaryDiffEqRosenbrock; tree 4d635452 = the manifest's). The clone is partial
  (`--filter=blob:none`): the checkout fetched the missing blobs from github.com (the only network use of P6).
- From the depot (`scripts/clone.sh --from-depot p6 …`; no network), each its own repository, tagged `upstream`, on
  branch `p6-inside-out`, tree hash equal to the manifest's: NonlinearSolve 4.32.0, NonlinearSolveBase 2.55.0,
  BracketingNonlinearSolve 1.12.8, NonlinearSolveFirstOrder 2.10.0, NonlinearSolveQuasiNewton 1.15.3,
  NonlinearSolveSpectralMethods 1.8.3, SimpleNonlinearSolve 2.14.6, SciMLJacobianOperators 0.1.20 (`VERSIONS.tsv`).
- OrdinaryDiffEqDifferentiation, LinearSolve, SteadyStateDiffEq: from the registry, as the manifest has them.

## S0: the P6 trees at `upstream` (I0)

No tree changes. ndport commit: the workspace, scripts, `env_p6`, logs (this commit).

- **P** (`logs/p6/precompile-s0.log`): `env_p6` resolved offline, same versions as `env_p3` (checked: no package
  differs). 74 packages rebuilt into `depot-p6` in 137 s (wall 163 s, strict on); `STRICT[]=true` in the session.
- **Joint-owner probe** (`scripts/p6_joint_probe.jl`, `logs/p6/joint-probe-s0.log`): `@joint_owners` inside a
  package's `@trait_module begin … end` block declares (`_joint_names` right, the owner is a trait module); the named
  package's methods are accepted and owned; a stranger's is refused with `OwnershipError`. All pass.
- **C** (`logs/p6-s0-census/I-1.log`, setting I, strict on): the control reproduces P0's 63 on P0's 17 packages
  (DiffEqBase 28, NonlinearSolveBase 12, NonlinearSolve 10, Makie 8, OrdinaryDiffEqCore 3, GraphMakie 2). Static has
  505 methods against P0's 504: P3's promotion fix, one method. Wrapped: NetworkDynamics (and TraitWorld); pirates in
  wrapped packages 0.
  - The extended census, filtered to pirates on a function or type of a package P6 wraps
    (`scripts/p6_census_filter.py`): BracketingNonlinearSolve 4, DiffEqBase 28 (+ DiffEqBaseForwardDiffExt 7,
    DiffEqBaseUnitfulExt 4), LinearSolve 16 (+ ChainRulesCoreExt 8, EnzymeExt 10, ForwardDiffExt 4), NonlinearSolve 10,
    NonlinearSolveBase 12 (+ ForwardDiffExt 4), NonlinearSolveFirstOrder 5, OrdinaryDiffEqCore 3,
    OrdinaryDiffEqDifferentiation 10, SteadyStateDiffEq 2. Every one is held by the plan's two lines (§2.4): the
    SciMLBase-owned ones by SciMLBase's line (extensions count as their parents, all named); Differentiation's 10 are
    OrdinaryDiffEqCore's functions or DiffEqBase's `prepare_alg` on OrdinaryDiffEqCore's algorithm types, held by
    OrdinaryDiffEqCore's line from S6. No name to add. (The review's reading is confirmed; LinearSolve has also
    `solve(::LinearProblem, …)` and its `SMatrix` variant, `common.jl:960`, `:964`: front ends, same class.)
  - Differentiation's other 25 pirates name no P6 package (ForwardDiff, LinearSolve, Base); they matter only if one
    wins at a fact of trait code, which strict mode would show in R.
- **H** (same log, `scripts/p6_profile_summary.py`): steps c–e of an "again" pass, 34,601 dynamic calls from facts
  code in the top 40 methods: Base 19,602, ForwardDiff 5,824 and PreallocationToolsForwardDiffExt 5,824 (all from
  NetworkDynamics' `get_output_cache`, `network_structure.jl:157–158`, the Jacobian of step c), NetworkDynamics
  2,560, SymbolicIndexingInterface 420 (NetworkDynamics' `setindex!` calling `ParameterHookWrapper`), Core 191,
  Iterators 180. DiffEqBase 604 from plain code. This is the reference for H.
  - Note: with `JULIA_FACTS_DISPATCH_PROFILE=1` exported to the harness, its precompile check's session prints a
    profile at exit at the top of the harness's output (not in the log). Harmless.
- **R** (`logs/p6-s0/I-1.log`): 25 digests, 0 exact differences against U (`logs/p1/U-1.log`).
- **S**: `STRICT on`. **One refusal, at the plotting load:** strict mode left OffsetArrays'
  `reshape(::AbstractArray, ::Tuple{Vararg{Union{Colon, Integer, AbstractUnitRange}}})` inactive (a true pirate:
  Base's function, Base's types). The fact it would change is held by **Base's own code**, not by NetworkDynamics:
  Base's `reshape(::Vector{Dict{Symbol,Any}}, ::Val)` calls `reshape(…, ::Tuple{Vararg{OneTo{Int}}})`
  (`scripts/p6_who_holds.jl`, `logs/p6-diag/who-holds-reshape-s0.log`). `is_trait_world(Base)` is true: strict mode
  protects Julia's own compiled code from pirates. Digests are unchanged. E-153 never ran the full workload with
  strict on (its strict runs were `p3_pirate.jl`, without the plotting packages), so this is new but not P6's.
  **The pass rule used from S1 on: no refusal other than this one.** Candidate pushback below (P6-a).
- **F** (I0): first simulation a–e 36.4 s (c 21.0, d 11.1, e 3.2 s); N 37.8 s, U 21.5 s (E-153). First plot (f)
  14.6 s. Session 89.8 s.
- **T** (I0, the reference): again c 3.6, d 15.0, e 0.6 ms (f 39.0, g 442.2). N: d 15.3 ms.
- **L**: TraitWorld 0.11 s, Graphs+NetworkDynamics 6.11 s, solvers 0.33 s, plotting 6.3 s.

## S1: SymbolicIndexingInterface and RecursiveArrayTools wrapped

Commits: `SymbolicIndexingInterface-p6` dcc3b12, `RecursiveArrayTools-p6` f29eae0 (tag `p6-s1`), made by
`scripts/p6_wrap.py` (the wrap's three lines and TraitWorld in `[deps]`).

- **P** (`logs/p6/precompile-s1.log`): 59 rebuilt (the plan's 21 + 38), 147 s (wall 164 s). No `OwnershipError`,
  no warning. SII 1.6 s, RAT 7.4 s themselves.
- **C** (`logs/p6-s1-census/I-1.log`): wrapped NetworkDynamics, RecursiveArrayTools, SymbolicIndexingInterface;
  pirates in wrapped packages 0. The filtered list is unchanged from S0.
- **H**: no site in RAT; SII's 420 are its `ParameterHookWrapper` constructor called from NetworkDynamics'
  `setindex!` (`symbolicindexing.jl:372–373`), as at I0. Iterators 180 → 360 is the top-40 cut (a second method of
  180 calls from NetworkDynamics' `init_formulas.jl` enters the list); no new site in the newly wrapped modules.
- **R**: 0 exact differences (25 digests). **S**: `STRICT on`; only I0's OffsetArrays refusal.
- **F**: first a–e 36.8 s (I0 36.4); c 21.2, d 11.2, e 3.2 s. **T**: c 3.5, d 15.1, e 0.7 ms: within I0's margin.
- **L**: TraitWorld 0.11, Graphs+NetworkDynamics 6.15, solvers 0.36, plotting 6.53 s.
- Calibration (the plan §1.3): S1's build 147 s; S2–S4 estimated about the same.
