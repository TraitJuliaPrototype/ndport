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

## S2: SciMLBase wrapped, its joint owners named — STOPPED at check T

Commit: `SciMLBase-p6` b50f4684 (tag `p6-s2`): the wrap with
`@joint_owners DiffEqBase NonlinearSolveBase NonlinearSolve BracketingNonlinearSolve NonlinearSolveFirstOrder LinearSolve SteadyStateDiffEq OrdinaryDiffEqCore`.

- **P** (`logs/p6/precompile-s2.log`): 48 rebuilt (the plan's 19 + 29), 196 s (wall 221 s). No `OwnershipError`
  (SciMLBase wraps whole under `@trait_module`'s statement-by-statement treatment: porting 0.1a's open question
  answered yes for SciMLBase, 3,282 methods, `@max_methods` through `@eval`, `@reexport`, RuntimeGeneratedFunctions).
  Strict mode's extension warnings (allowed by check S; "followed as its parent's change; that trait code compiles
  again"), each in several precompile workers:
  - `PreallocationToolsForwardDiffExt` defines `forwarddiff_compat_chunk_size(::Int64)`, which wins at that fact of
    SciMLBase's keyword body `var"#_#466"` (PreallocationTools is plain; its extension acts for its parent);
  - `SciMLBaseForwardDiffExt` defines `anyeltypedual(::Number|::NamedTuple|::Any, ::Type{Val{counter}})`, which wins
    at facts of `SciMLBase.promote_u0(::Vector{Float64}, …)`: SciMLBase's own extension changing SciMLBase's facts code.
  The same warnings appear at every load of the stack (ForwardDiff is always loaded by NetworkDynamics).
- **C** (`logs/p6-s2-census/I-1.log`): wrapped NetworkDynamics, RecursiveArrayTools, SciMLBase,
  SymbolicIndexingInterface; pirates in wrapped packages 0. Methods resting on SciMLBase's declaration (`joint=`):
  DiffEqBase 28, NonlinearSolveBase 12, NonlinearSolve 10, BracketingNonlinearSolve 4, NonlinearSolveFirstOrder 5,
  LinearSolve 16, SteadyStateDiffEq 2, OrdinaryDiffEqCore 3; extensions DiffEqBaseForwardDiffExt 7,
  DiffEqBaseUnitfulExt 4, LinearSolveChainRulesCoreExt 8, LinearSolveEnzymeExt 10, LinearSolveForwardDiffExt 4,
  NonlinearSolveBaseForwardDiffExt 4: **117**, all pirates by the letter at S0, none left. The only remaining pirates
  on P6's packages are OrdinaryDiffEqDifferentiation's 10 (OrdinaryDiffEqCore's line, S6).
- **S+** (`scripts/p6_strict_probe.jl`, `logs/p6-s2-strictprobe/I-1.log`): **pass.** Of 53,466 callees of facts
  code, 7,900 are held by SciMLBase's facts code alone. Main defined the shortest such pirate, `<(::Int64)` (Base's
  curried `<(x)`, `invoke`-forwarding): refused with `PirateError`, the refusal's caller root
  `SciMLBase.#isinplace#14`.
- **R**: 0 exact differences (25 digests). **S**: `STRICT on`; only I0's OffsetArrays refusal; the warnings above.
- **T: FAILS.** Again c 3.7 (ok), **d 29.2 ms against I0's 15.0** (outside 10 % + 5 ms), e 0.7 (ok).
- **H** (`logs/p6-s2-census/I-1.log`): 125,096 dynamic calls in the top 40 against I0's 35,248; the new ones are
  from **plain code** (default owner 100,501): DiffEqBase's callback root finding (`get_condition`,
  `check_event_occurrence_upto`, `findall_events!`, `callbacks.jl:150–171`, `:565–580`), OrdinaryDiffEqCore's
  interpolation (`ode_interpolant!`, `current_interpolant!`), Tsit5's and Rosenbrock's `_ode_addsteps!`,
  Rosenbrock's `perform_step!` (`→ SciMLBase.ODEFunction`), LinearSolve's `_default_lu_solve_with_fallback`
  (`→ SciMLBase.build_linear_solution`), FastBroadcast, Base arithmetic and `setproperty!`.
- **The cause** (`scripts/p6_constprop_probe.jl`, `logs/p6-diag/constprop-s2.log`): SciMLBase overloads
  `getproperty` on its abstract types: `DEIntegrator` (`integrator_interface.jl:833`), `AbstractSolution`
  (`solution_interface.jl:72`), `AbstractSciMLProblem` (`problem_interface.jl:1`), `AbstractSciMLFunction`
  (`scimlfunctions.jl:6190`), each a `sym === :x ? … : getfield(A, sym)` switch. Plain packages' concrete types inherit
  them (`ODEIntegrator <: DEIntegrator`, `ODESolution`, `ODEProblem`, `ODEFunction`). With SciMLBase a trait module
  these are facts methods. A plain caller infers a facts method in an inference of its own, and **no constant
  propagation crosses the modes** ([facts §6.3](../../../attic/writeup/reference/facts.md#calls-between-the-modes); inlining
  crosses, but "the inlined code is not inferred again"). So `integrator.sol`, `sol.stats`, `prob.p`, `f.f` in plain
  code infer to the union of all the struct's field types (the probe: every field of `ODEIntegrator`, `ODESolution`,
  `ODEProblem`, `ODEFunction` WIDER than `getfield`), and everything after them dispatches at run time. Plain Julia
  relies on constant propagation of the field's `Symbol` here, exactly as P3-1 relied on Base's folding.
- **Not the owner's bug**: the `getproperty` switch is idiomatic, and correct. The principled fix is not a one-line
  change in SciMLBase; per the rules **P6 stops at S2** (no workaround, no edit in SciML beyond the wrap).
- **F**: first a–e 52.4 s against I0's 36.4 (c 17.1 ↓ from 21.0, **d 30.9 ↑ from 11.1**, e 3.3). Session 138.0 s.
  "changed" d 8.6 s.
- **L**: Graphs+NetworkDynamics 8.64 s (I0 6.11), **solvers 4.32 s (I0 0.33)**. One load session each way
  (`logs/p6-diag/load-strict-s2.log`): strict off ND 3.74 s, solvers 4.13 s; strict on ND 8.69 s, solvers 4.28 s
  (strict's own counters: 61,739 methods checked, 929 walked, 1.25 s). So the solvers' extra ~3.8 s is not strict
  mode; it is what the solvers' load does to SciMLBase's image (the extension wins above recompile SciMLBase's facts
  code; J would measure it, due at S4). Strict mode adds ~5 s to the NetworkDynamics load, ~1.25 s of it in its check.
- Not run at S2, because the step stopped: Q (the packages' quick tests), and S3 onward.

### For the coordinator and the user (S2)

- **The question for the user:** in an inside-out order, every step leaves plain callers above the newly wrapped
  package. Wherever they read fields through the wrapped package's `getproperty` overloads (and, generally, wherever
  plain code relies on constant propagation into the wrapped package's methods), they lose types. SciMLBase's are on
  every hot path of the solvers (plain until S5–S7), and of LinearSolve, OrdinaryDiffEqDifferentiation and
  SteadyStateDiffEq (plain in P6 throughout), and of users' plain code (`sol.u`, `prob.p`). Options I see (none taken):
  1. continue S3–S7 accepting T's failure until the callers are wrapped, judging T at S6/S7 (a plan change; the
     solver's packages would recover inside facts code, where constant propagation works at fact signatures, facts
     §4.1; LinearSolve's and the users' plain calls would not);
  2. a design change: constant propagation across the modes for a plain caller of a facts method (facts §6.3), at
     least for a constant `Symbol` argument (a design change, the user's);
  3. a highly orthogonal feature for the port: a per-method mark in the owning package that compiles a method in its
     caller's mode (as TraitWorld's boundary methods already are, facts §6.1), put on SciMLBase's `getproperty`
     overloads (an edit in SciML beyond the wrap; the coordinator/user to decide whether it is "highly orthogonal");
  4. a different order: wrap the hot plain callers (DiffEqBase, OrdinaryDiffEqCore, the solvers) in the same step as
     SciMLBase (S2+S5+S6+S7 as one step), so that no plain caller on the workload's per-step path is left above it.
     LinearSolve's `build_linear_solution` (Rosenbrock's linear solves) would stay a plain caller.

## Candidate pushback entries (the log's shape; IDs P6-n assigned by the coordinator)

**P6-a. Plain callers lose constant propagation into a wrapped package's `getproperty` overloads** (met at S2;
blocks the track).
- *The code:* SciMLBase's `Base.getproperty(A::DEIntegrator, sym::Symbol)` (`integrator_interface.jl:833`),
  `(A::AbstractSolution, sym)` (`solution_interface.jl:72`), `(prob::AbstractSciMLProblem, sym)`
  (`problem_interface.jl:1`), `(x::AbstractSciMLFunction, sym)` (`scimlfunctions.jl:6190`); their plain callers in
  DiffEqBase (`callbacks.jl:150–171`, `integrator.sol.stats.ncondition += 1`), OrdinaryDiffEqCore, Tsit5, Rosenbrock,
  LinearSolve.
- *The idiomatic form:* an interface package overloads `getproperty` on its abstract types with a `Symbol` switch;
  implementers' concrete subtypes inherit it; callers write `x.field` and get the field's type by constant propagation.
- *The reference:* [facts §6.3](../../../attic/writeup/reference/facts.md#calls-between-the-modes): "No constant propagation
  crosses the modes." (and §6.2: a facts method reached from the default owner is still compiled by facts).
- *What it costs:* results bit for bit the same; every such field read in plain code infers to the union of the
  struct's field types; the steady-state solve (step d) 29.2 against 15.0 ms; the first simulation's step d 30.9
  against 11.1 s. Nothing warns.
- *Blocks:* P6 past S2 under the plan's check T.
- *What the port did:* stopped at S2 and recorded it (options above).

**P6-b. Strict mode refuses a plotting package's `reshape` pirate to protect Base's own code** (I0; does not block).
- *The code:* OffsetArrays' `Base.reshape(A::AbstractArray, inds::Tuple{Vararg{Union{Colon,Integer,AbstractUnitRange}}})`,
  loaded by Makie; Base's `reshape(::Vector{Dict{Symbol,Any}}, ::Val)` holds the fact
  `reshape(…, ::Tuple{Vararg{OneTo{Int}}})`.
- *The idiomatic form:* a package that extends Base's array API for all arrays (a pirate by the letter, long accepted).
- *The reference:* [facts §10.2](../../../attic/writeup/reference/facts.md#strict-mode), [traits §10.3](../../../attic/writeup/reference/traits.md#103-strict-mode);
  TraitWorld's `is_trait_world(Base) = true`, so Base's compiled code is protected.
- *What it costs:* the method stays inactive in strict sessions that load Makie; digests unchanged. Every strict run
  of the full workload logs the refusal.
- *Blocks:* no. It is not P6's: present at I0, before any SciML package is wrapped.

**P6-c. A plain package's extension rewrites a wrapped core's facts at every load** (S2; does not block).
- *The code:* `PreallocationToolsForwardDiffExt`'s `forwarddiff_compat_chunk_size(::Int)` wins at a fact of
  SciMLBase's keyword body; `SciMLBaseForwardDiffExt`'s `anyeltypedual` methods win at facts of `promote_u0`.
- *The idiomatic form:* extensions that refine a function for a trigger's types, loaded whenever the trigger is.
- *The reference:* [traits §10.3](../../../attic/writeup/reference/traits.md#103-strict-mode) (the extension's warning: a
  stakeholder's change, followed); [facts §2.2](../../../attic/writeup/reference/facts.md#g2) (the exception).
- *What it costs:* the warnings at every load; SciMLBase's facts code at those sites compiles again; plausibly part of
  the solvers' load rising from 0.33 to 4.3 s at S2 (not attributed; J was due at S4).
- *Blocks:* no. The plan's expected P6-7, met earlier than order B.

## Lessons for the guideline's B5

- After wrapping a package that **other plain packages call on their hot paths**, profile the steady state of the
  **callers** too: the dispatch profiler's "default owner" columns show plain code that lost types. P3-1's lesson
  (profile after wrapping) holds, but the run-time sites can appear in the plain callers, not in the wrapped code.
- `getproperty` overloads on abstract types (and any method whose callers rely on constant propagation of an
  argument) in a package to be wrapped: a plain caller's `x.field` then infers to the union of all fields. Check with
  `Base.return_types(x -> x.field, (T,))` against `getfield` (`scripts/p6_constprop_probe.jl`).
- In an inside-out order, wrap a core package together with its hot plain callers, or expect the steady state of the
  intermediate steps to fall.
- `@joint_owners` inside the wrap's `@trait_module begin … end` works (the probe); the census after loading is the
  check that the list is complete (SciMLBase's eight names held all 117).
- A full workload run with strict mode on and Makie loaded logs OffsetArrays' `reshape` refusal (Base's code
  protected): expected, not a regression.

## The coordinator's decision (choice 37; open issue 50 for the user)

Continue with option 1: S3–S7 as planned with every check; T is recorded at each step and judged at S6 and S7; H
reports per step the dynamic calls in plain callers against trait code (the profile's owner columns). The candidates
are pushback **P6-1** (getproperty, constant propagation), **P6-2** (OffsetArrays' `reshape`), **P6-3** (extensions).
The solvers' load increase is attributed at J (S4).

## S2, continued: Q (the packages' quick tests)

`scripts/p6_tests.jl` (group `s2`), `scripts/p6_tests.sh`; environments `env_p6test` (env_p6's project and the test
dependencies already in its manifest; nothing new built) and `env_p6test_u` (env_upstream's project, the registry's
releases: the baseline), both with `depot-p6` first. Files whose dependencies are not in the stack's manifest
(SafeTestsets, SciMLTesting, AllocCheck, Zygote, Measurements, the shorthand sublibrary) are left out.

| File | upstream (`logs/p6/tests-u-s2.log`) | P6 S2 (`logs/p6/tests-p6-s2.log`, strict on) |
|---|---|---|
| SII: example, fallback, parameter_timeseries_collection, problem_state, symbol_cache, trait, type_grouped_indexes, batched_interface, remake | 721 pass | 721 pass |
| RAT: partitions_and_static_arrays | 1 error | 1 error (the same: `convert(::Type{AP}, ::Vector{Float32})`; the file needs the shorthand sublibrary) |
| RAT: copy_static_array, named_array_partition, scimlstructures, tabletraits | 579 pass | 579 pass |
| SciMLBase: interpolation_tests | 427 pass | **423 pass, 4 fail** |
| SciMLBase: solution_interface | 116 pass | **116 pass, 1 error** |
| SciMLBase: integrator, callback_constructors, convert, function_wrappers, problem_building | 255 pass | 255 pass |

**The 5 differences are inference assertions, not results** (`scripts/p6_q_sites.jl`, `logs/p6-diag/q-sites-s2.log`):
- `interpolation_tests.jl:157–158` (twice each, `idxs` `Nothing` and `Int`): `Base.return_types(basic_dense, (Vector{Float64}, …))`
  `<: AbstractDiffEqArray` is `Any`. Reflection shows facts inference for a facts method (facts §7.2). `fully_typed`
  finds the cause: RAT's `DiffEqArray` constructor at a type with an uninferred parameter (`vector_of_array.jl:328`,
  `DiffEqArray{…, _A, …} where _A`) and SII's `SymbolCache` likewise (`symbol_cache.jl:71`) are run-time sites, whose
  result is `Any` (facts §4.2: no result type from the one method that matches); plain inference gives the
  `UnionAll`. The test's own comment says the two parameters are not inferred upstream either. Values unchanged.
- `solution_interface.jl` "solution_new_original_retcode type inference": `@inferred bvde_like(odesol, nlsol)`, a
  plain test function reading `n.resid` through SciMLBase's `getproperty(::AbstractSolution, ::Symbol)`: P6-1
  (`n.resid` infers to `Any`, `getfield` to `Vector{Float64}`). The direct call
  `solution_new_original_retcode(…)` is fully typed under facts.
- Not a G1 failure (no value differs), not a bug; P6 continues. Candidate pushback **P6-4** (below): packages'
  own inference tests (`@inferred`, `return_types`) fail where facts inference is wider by design.

## S3: NonlinearSolveBase, BracketingNonlinearSolve, SciMLJacobianOperators wrapped

Commits (tag `p6-s3`): `NonlinearSolveBase-p6` 293712e, `BracketingNonlinearSolve-p6` 7433e0b,
`SciMLJacobianOperators-p6` 3840f8a. No declaration (the plan §1.4: NonlinearSolve's methods of NonlinearSolveBase's
functions name SciMLBase's types).

- **P** (`logs/p6/precompile-s3.log`): 35 rebuilt (the plan's 17 + 18), 176 s (wall 267 s). No `OwnershipError`
  (BracketingNonlinearSolve's plain-definition front ends pass the wrap's check: SciMLBase's line names it).
  One new extension warning (P6-3): `NonlinearSolveBaseSparseMatrixColoringsExt` defines
  `NonlinearSolveBase.Utils.is_extension_loaded(…)`, which wins at a fact of NonlinearSolveBase's own facts code: the
  package's own extension, followed.
- **C**: wrapped + BracketingNonlinearSolve, NonlinearSolveBase, SciMLJacobianOperators; pirates in wrapped
  packages 0; only Differentiation's 10 remain on P6's packages.
- **R**: 0 exact differences. **S**: `STRICT on`; only P6-2.
- **T** (recorded; judged at S6/S7): c 3.8, d **28.6** (P6-1), e 0.8 ms. Step f again 389 ms, of which GC 348 ms
  (a full collection landed there; params f 43 ms).
- **H** (top 40): trait code 24,994, plain code 98,419 (S2: 24,595 / 100,501). No site in the newly wrapped modules.
- **F**: first a–e 49.3 s (S2 52.4; I0 36.4): **c 8.1 s** (S2 17.1, I0 21.0: the fixed point's path now in
  images compiled by facts), d 31.2 s, e 3.3 s.
- **L**: Graphs+ND 8.19 s, solvers 4.28 s, plotting 6.59 s.

## S4 (milestone): the NonlinearSolve family wrapped

Commits (tag `p6-s4`): `NonlinearSolve-p6` 697c987, `NonlinearSolveFirstOrder-p6` 30c42a6,
`NonlinearSolveQuasiNewton-p6` afc14ed, `NonlinearSolveSpectralMethods-p6` 6ef8fa9, `SimpleNonlinearSolve-p6` f95ae0e.

- **P** (`logs/p6/precompile-s4.log`): 9 rebuilt (the plan's 6 + 3), 101 s. No error; P6-3's warnings as before.
- **C**: 13 packages wrapped (with ND and TraitWorld); pirates in wrapped packages 0.
- **R**: 0 exact differences. **S**: `STRICT on`; only P6-2.
- **T** (recorded): c 3.7, d **29.7** (P6-1), e 0.7 ms.
- **H**: trait code 24,994, plain code 98,419 (as S3: the newly wrapped modules add no site).
- **F**: first a–e 49.1 s: **c 13.5 s** (S3 8.1, S2 17.1, I0 21.0), d 31.2, e 3.3 s. Wrapping NonlinearSolve itself
  raised step c by 5 s against S3; the attribution below shows why in part (`:facts_plain_return_type`).
- **L**: Graphs+ND 8.12, solvers 4.23, plotting 6.57 s.

**The attribution** (`NDW_DIAG=1`, strict on, `logs/p6-s4-diag/I-1.log`; against U, `logs/p1-diag/U-1.log`):
- c: 7,598 new CodeInstances (U 5,276): `:facts` 5,306, **`:facts_plain_return_type` 2,094**, plain 198. By module
  Base 5,596, NetworkDynamics 575, SciMLBase 260, NonlinearSolveBase 247.
- d: 14,625 new (U 6,262): plain 9,615, `:facts` 4,829, `:facts_plain_return_type` 181. OrdinaryDiffEqCore 1,805
  (U 561), DiffEqBase 314 (U 201): the plain solver's code compiled again in the session, rather than taken from
  the images (J below).
- e: 4,575 new: **`:facts_plain_return_type` 2,925**, `:facts` 1,390, plain 260.
- So the session spends a share of c and e computing plain inference's answers behind `return_type` at run time
  (facts §7.1 rule 3), for facts code of NonlinearSolve's path and of the access. Candidate entry for P6-1's family
  or its own (**P6-5 candidate**, below); not a stop (no regression of the steady state, no result differs).

**J** (`scripts/p6_loadinv.jl`, strict off, `logs/p6-s4-J/I-1.log`; the same loads under U, `logs/p6-s4-J/U-1.log`):

| Load | S4 s | U s | Images' CodeInstances rejected at S4 (U) | of the facts owner at S4, by module |
|---|---|---|---|---|
| Graphs, NetworkDynamics (loads SciMLBase, NonlinearSolve, DiffEqBase, the joint owners) | 2.84 | 2.67 | 5,295 (8,556) | 183: ConstructionBase 147, FunctionWrappers 16, SciMLBase 9, NonlinearSolveBase 8, Base 3 |
| OrdinaryDiffEqTsit5 | **1.20** | 0.05 | **864** (80): OrdinaryDiffEqCore 454, Base 179, DiffEqBase 114 | 19: ConstructionBase 8, FunctionWrappers 6, SciMLBase 3 |
| OrdinaryDiffEqRosenbrock | **3.07** | 0.08 | **1,885** (82): OrdinaryDiffEqCore 895, Base 373, DiffEqBase 199, Differentiation 55 | 30: FunctionWrappers 17, ConstructionBase 10 |
| DiffEqCallbacks, SII | 0 | — | 0 | 0 |
| the plotting packages | 2.55 | — | 6,916, all plain | 0 (invalidated: 15 `:facts_plain_return_type`) |

- **Joint owners' loads discard little trait code:** 183 + 19 + 30 CodeInstances of the facts owner, mostly neutral
  packages' code compiled by facts (ConstructionBase, FunctionWrappers); SciMLBase 12, NonlinearSolveBase 8. No
  valid facts CodeInstance invalidated by a load (`invalidated-facts n=0` for every load before the plotting one).
  The plan's P6-2 (a declaration widening the exception in another package's code) does not show at a measurable
  size. (The plan's "P6-2" is now the coordinator's OffsetArrays entry; this one stays unnumbered.)
- **The solvers' load increase (0.33 → ~4.2 s) is attributed:** the Tsit5 and Rosenbrock images' **plain**
  CodeInstances of OrdinaryDiffEqCore and DiffEqBase are rejected at load (864 and 1,885 against U's 80 and 82),
  with no compilation in the load (compile 0): the time is validation. The rejecting methods are of packages that
  add methods to generic functions (CommonWorldInvalidations 244/472, ChainRulesCore, Static, StaticArrays,
  FillArrays, SparseConnectivityTracer) and P6-3's extensions (DiffEqBaseForwardDiffExt 60, SciMLBaseForwardDiffExt
  47 at Tsit5). The likely mechanism: P6-1. The plain solver code, compiled in those images, calls SciMLBase's facts
  `getproperty` and gets wide types, so its edges are at abstract signatures that any new method of a generic
  function breaks. Under U (and at I0) the same code is concretely typed. This also explains why step d's first call
  recompiles the plain solver (attribution, d). Expected to recede when DiffEqBase, OrdinaryDiffEqCore and the
  solvers are trait code (S5–S7).

**B** (order B, strict off, `logs/p6-s4-orderB/I-1.log`): digests 0 exact differences.
- The plotting load takes 3,033 of 345,857 CodeInstances: plain 2,798, `:facts_plain_return_type` 235, **`:facts` 0**
  (G2 holds for trait code). By module Base 1,337, Compiler 678, LLVM 255, Pkg 118, **DiffEqBase 92**, NetworkDynamics 53
  (`:facts_plain_return_type` or plain), **OrdinaryDiffEqCore 50**. N lost NonlinearSolveBase 175 and SciMLBase 27
  plain CodeInstances (E-153): those are now facts code, and none is lost.
- `:facts_plain_return_type` 235 (N 15): plain inference's answers behind `return_type` (facts §7.1), which change
  when plain Julia's do: explained by that route.
- **"After" fails the plan's bound:** the next pass's step d recompiles **5.37 s** (N 0.04 s; U 4.7 s). What is
  recompiled is plain code (DiffEqBase, OrdinaryDiffEqCore), as in U: the same cause as the load increase (P6-1's
  wide plain solver code is invalidated by Makie's methods). Recorded under P6-1; judged at S7 with T, per the
  coordinator's decision.

## S5: DiffEqBase wrapped

Commit: `OrdinaryDiffEq-p6` 45bf77e85 (tag `p6-s5`).

- **P** (`logs/p6/precompile-s5.log`): 15 rebuilt (the plan's 8 + 7), 68 s. No `OwnershipError`: DiffEqBase's 28
  front-end pirates are held by SciMLBase's line. New P6-3 warnings: `DiffEqBaseForwardDiffExt` defines
  `DiffEqBase.hasdualpromote(…)` and `SciMLBase.wrapfun_iip(…)`, which win at facts of DiffEqBase's own code (its own
  extension, followed).
- **C**: DiffEqBase wrapped; pirates in wrapped packages 0.
- **R**: 0 exact differences. **S**: `STRICT on`; only P6-2.
- **T: back within I0's margin:** c 3.6, **d 16.0** (I0 15.0), e 0.7 ms.
- **H** (top 40): **trait code 40,254, plain code 5** (S4: 24,994 / 98,419). P6-1's cost is gone already at S5:
  the workload's `solve` now enters DiffEqBase's trait code, which reaches OrdinaryDiffEqCore's, Tsit5's and
  Rosenbrock's methods; those are neutral methods reached from the facts owner, so they are compiled by facts
  (facts §6.2), where constant propagation works at fact signatures (facts §4.1) and SciMLBase's `getproperty`
  folds again. (The plan expected this at S6.)
  - **New sites in the newly wrapped DiffEqBase** (906 in the top 40), each explained: the type-erased loops over
    a callback vector (`continuous_callbacks isa AbstractVector`): `find_first_continuous_callback`'s
    `any(callback -> callback isa VectorContinuousCallback, callbacks)` (`callbacks.jl:290`, 302 calls),
    `Base.invokelatest(_find_callback_time_erased, …)` (`:275`, 302; upstream calls it dynamically on purpose, per its
    comment), `apply_discrete_callback!` over the vector (`:759`, 302), and OrdinaryDiffEqCore's `handle_callbacks!`
    destructuring their results (`integrator_utils.jl:1112`, `:1145`, about 160 each). Calls at an abstract element
    type are run-time sites under the facts mode (facts §4.2: no `max_methods` speculation; the result `Any`), where
    plain Julia infers them from the one closure or splits them. About 1–2 µs per integration step; T within margin.
    Not the owner's bug (the vector is type-erased by design), so not fixed. Base's facts calls grew 19,602 → 25,058
    by these (`indexed_iterate`, `!`, `ismissing`, `getindex(::Tuple)`).
- **F**: **first a–e 29.5 s** (I0 36.4, N 37.8, U 21.5): c 13.5, **d 11.4** (S4 31.2), e 3.5 s. Session 90.3 s.
- **L**: Graphs+ND 8.35, **solvers 0.46 s** (S4 4.23): the solvers' images are valid again, consistent with J's
  attribution to P6-1.

## S6: OrdinaryDiffEqCore (with its joint owner), OrdinaryDiffEqTsit5, DiffEqCallbacks wrapped

Commits (tag `p6-s6`): `OrdinaryDiffEq-p6` 1dcb9dd04 (OrdinaryDiffEqCore with
`@joint_owners OrdinaryDiffEqDifferentiation`, OrdinaryDiffEqTsit5), `DiffEqCallbacks-p6` 0b6042d.

- **P** (`logs/p6/precompile-s6.log`): 10 rebuilt (the plan's 7 + 3), 62 s. No `OwnershipError`; no new warning.
- **C**: 17 wrapped; pirates in wrapped packages 0; **no pirate left on any P6 package** (Differentiation's 10 are
  held by OrdinaryDiffEqCore's line; the filtered list is empty). Joint lines: SciMLBase (8 names), OrdinaryDiffEqCore
  (1).
- **R**: 0 exact differences. **S**: `STRICT on`; only P6-2. No refusal from Differentiation's other 25 pirates.
- **T (judged here):** c 3.8, d 16.0, e 0.7 ms against I0's 3.6 / 15.0 / 0.6: **pass.**
- **H**: trait code 40,254, plain code 5 (as S5). No new site in OrdinaryDiffEqCore, Tsit5 or DiffEqCallbacks
  beyond S5's explained callback loops (OrdinaryDiffEqCore's `handle_callbacks!` was already compiled by facts at S5).
- **The fold check** (risk 2, `scripts/p6_fold.jl`, in the C+H session): Tsit5's `perform_step!` for the
  workload's `Tsit5Cache` is a facts method; its typed code (facts inference, as reflection shows) has 947 calls and
  **no construction of `Tsit5ConstantCacheActual`**; likewise `_ode_addsteps!` (681 calls, 0). The `@fold` tableau
  folds under the facts owner. P6-8 (plan) not met.
- **The callbacks' path** (risk 3): the workload's integrator holds `continuous_callbacks::Vector{Any}` and
  `discrete_callbacks::Vector{Any}`: NetworkDynamics' callbacks reach the type-erased vector path (S5's explained
  sites). T within margin, so no visible cost of `_condition_return_type`.
- **F**: **first a–e 28.9 s** (I0 36.4, N 37.8, U 21.5): c 13.5, d 11.0, e 3.3 s. The plan's "may rise at step 6"
  (P6-6 of the plan) did not happen: S5 already moved the solver's driver into facts code, and S6 adds its images.
- **L**: Graphs+ND 8.27, solvers 0.47, plotting 6.31 s.
- **Q** (`logs/p6/tests-u-s6.log`, `logs/p6/tests-p6-s6.log`): DiffEqBase's callbacks (35), internal_euler,
  problem_creation (8 + 7 broken), norm (3), ode_default_unstable_check (19), remake (31 + 4 broken),
  diffeqfunction (12), utils (21), despecialized_p (67): **identical at upstream and at S6.** OrdinaryDiffEqTsit5 has
  no tests outside its QA group (JET, Aqua, AllocCheck, not in the stack's manifest), so none ran for it.
  (The runner's test modules were renamed `T_<file>` after `callbacks.jl` defined a global named like its module;
  both runs repeated with the fix.)
- **The merge's precondition on P6's side holds:** S6 passed with its checks.

## S7 (milestone): OrdinaryDiffEqRosenbrock wrapped

Commit: `OrdinaryDiffEq-p6-ros` effcc0f08 (branch `p6-inside-out-ros`, tag `p6-s7-ros`).

- **P** (`logs/p6/precompile-s7.log`): 1 rebuilt (the plan's 1 + 0), 46 s.
- **C**: 18 wrapped (with ND and TraitWorld); pirates in wrapped packages 0; none left on P6's packages.
- **R**: 0 exact differences. **S**: `STRICT on`; only P6-2.
- **T (judged here):** c 3.6, d 16.2, e 0.7 ms against I0's 3.6 / 15.0 / 0.6: **pass** (d +8 %).
- **H**: trait code 40,254, plain code 5. Nothing new in Rosenbrock.
- **F**: first a–e **28.9 s** (I0 36.4, N 37.8, U 21.5). It falls by S7, as the plan asked; it does not reach U
  (the plan expected that: NetworkDynamics' own workload is P4's lever).
- **L**: Graphs+ND 8.19, solvers 0.43, plotting 6.27 s.
- **The attribution** (`logs/p6-s7-diag/I-1.log`): c 7,549 new (`:facts` 5,257, `:facts_plain_return_type` 2,094);
  **d 5,481 new** (S4 14,625; U 6,262): `:facts` 4,878, plain 294; OrdinaryDiffEqCore 340 (U 561, S4 1,805): the
  solver's code now comes from the images. e 4,590 (`:facts_plain_return_type` 2,903).
- **B** (order B, strict off, `logs/p6-s7-orderB/I-1.log`): digests equal. The plotting load takes 2,657: plain 2,422,
  `:facts_plain_return_type` 235, **`:facts` 0**. No SciML module among the losses any more (S4: DiffEqBase 92,
  OrdinaryDiffEqCore 50; N: NonlinearSolveBase 175, SciMLBase 27). **The next pass recompiles nothing** (step d
  compile 0, 17.3 ms; N 0.04 s; U 4.7 s). Every lost CodeInstance of a facts owner is `:facts_plain_return_type`:
  plain inference's answers behind `return_type` (facts §7.1), which change exactly when plain Julia's do.
- **J** (strict off, `logs/p6-s7-J/I-1.log`): Tsit5's load 0.07 s (S4 1.20), Rosenbrock's 0.23 s (S4 3.07); images'
  rejected CodeInstances 49 and 353 (S4 864, 1,885). Of the facts owner: ND's load 188 (ConstructionBase 149,
  FunctionWrappers 16, SciMLBase 9, NonlinearSolveBase 8, Base 4, DiffEqBase 2), Tsit5 21, Rosenbrock 31; no valid
  facts CodeInstance invalidated by a load before the plotting one, which invalidates 15 `:facts_plain_return_type`.
  Joint owners' loads discard no measurable share of the wrapped packages' trait code.
- **X** (the pirate `sin(::Dual)` of `p3_pirate.jl`; `logs/p6-s7-pirate-strict1/`, `-strict0/`):
  - strict on: refused (`PirateError`), 0 lost, digests equal; the refusal names `NetworkDynamics.AntiSymmetric`, as
    in N. `scripts/p6_pirate_roots.jl` (`logs/p6-s7-pirate-roots/`): the only direct trait-code callers of
    `sin` on duals are NetworkDynamics' line function (5 callers, all `AntiSymmetric`); SciML's code holds no direct
    fact there. So the plan's "the refusal's caller also names SciML code" does not hold, and cannot: strict mode names
    the first fact, and every fact at `sin(::Dual)` is NetworkDynamics'. SciML's trait code is protected
    transitively: with strict off, the pirate takes 84 CodeInstances, `:facts` 81 (NetworkDynamics 56, SciMLBase 9,
    FunctionWrappers 9, ForwardDiff 5, Main 5; N: 84, `:facts` 75).
  - strict off: accepted, 84 lost, digests equal.
- **Q** (`logs/p6/ndtest-p6-s7.log`, `env_ndtest_p6`, strict on): NetworkDynamics' test subset `nd_tests.jl`:
  massmatrix 6, doctor 26, diffusion 112 + 24 broken, inhomogeneous 45 + 12 broken: **identical to upstream**
  (`logs/p4/ndtest-upstream.log`), the allocation assertions included.

## E-155 in brief (S0–S7)

| Step | Build (pkgs, s) | First a–e (s) | Again c / d / e (ms) | H: dyn. calls trait / plain (top 40) | Loads ND / solvers (s) | Digests |
|---|---|---|---|---|---|---|
| S0 (I0) | 74, 137 | 36.4 | 3.6 / 15.0 / 0.6 | 34,601 / 647 | 6.11 / 0.33 | 0 diff |
| S1 SII, RAT | 59, 147 | 36.8 | 3.5 / 15.1 / 0.7 | 34,605 / 644 | 6.15 / 0.36 | 0 diff |
| S2 SciMLBase | 48, 196 | 52.4 | 3.7 / **29.2** / 0.7 | 24,595 / **100,501** | 8.64 / **4.32** | 0 diff |
| S3 NLSBase, Bracketing, SJO | 35, 176 | 49.3 | 3.8 / 28.6 / 0.8 | 24,994 / 98,419 | 8.19 / 4.28 | 0 diff |
| S4 NonlinearSolve family | 9, 101 | 49.1 | 3.7 / 29.7 / 0.7 | 24,994 / 98,419 | 8.12 / 4.23 | 0 diff |
| S5 DiffEqBase | 15, 68 | 29.5 | 3.6 / 16.0 / 0.7 | 40,254 / 5 | 8.35 / 0.46 | 0 diff |
| S6 ODECore, Tsit5, DiffEqCallbacks | 10, 62 | 28.9 | 3.8 / 16.0 / 0.7 | 40,254 / 5 | 8.27 / 0.47 | 0 diff |
| S7 Rosenbrock | 1, 46 | 28.9 | 3.6 / 16.2 / 0.7 | 40,254 / 5 | 8.19 / 0.43 | 0 diff |

Builds total 397 packages, 932 s of precompilation (the plan's estimate 15–25 min). One run each, strict on, P1's
load order, load average 0.9–1.7. Measures upstream's code with the declarations of the plan's §2.4, compiled by
facts as trait modules (no trait code: neither interop nor idiomatic).

- **The ND load with strict on** rises 6.1 → ~8.2 s from S2 on; with strict off it is 2.9 s (J). Strict mode's
  image check grows with the trait code it protects (S2: 61,739 methods checked, 929 walked, 1.25 s in its own
  counters; the rest not attributed). Candidate for P5's measurement round, not a stop.
- **`:facts_plain_return_type`** answers are computed in the session in quantity (S4/S7: 2,094 in step c, ~2,900 in
  step e), and the plotting load discards 235 of them in order B (N 15). Candidate **P6-4** (below).

## Candidate pushback, continued (IDs for the coordinator)

**P6-4 (candidate). Packages' own inference tests fail under the facts mode by design** (S2 Q).
- *The code:* SciMLBase's `test/interpolation_tests.jl:157–158` (`Base.return_types(…) <: AbstractDiffEqArray`) and
  `test/solution_interface.jl:355–396` (`@inferred bvde_like(…)`).
- *The idiomatic form:* a package pins inference precision with `@inferred` and `return_types`.
- *The reference:* facts §7.2 (reflection shows facts inference for a facts method), §4.2 (a run-time site's result is
  `Any`, no result type from the one matching method); P6-1 for the second.
- *What it costs:* 5 assertions of 1,555 in S2's subset; no result differs.
- *Blocks:* no.

**P6-5 (candidate). Run-time `return_type` answers are a large share of the session's new code** (S4, S7 attribution).
- *The code:* facts code of NonlinearSolve's path (step c) and of the access (step e) calling `return_type`
  (`collect`, `map`, broadcasting) where rule 1 and 2 of facts §7.1 do not fold.
- *The idiomatic form:* `map`/`collect`/broadcast over values whose element type comes from inference.
- *The reference:* facts §7.1 rule 3 (computed at run time by plain inference, under an owner of its own).
- *What it costs:* 2,094 + 2,903 CodeInstances of `:facts_plain_return_type` in the first simulation; part of step c's
  13.5 s (S3 8.1 s, before NonlinearSolve was wrapped). Not measured apart.
- *Blocks:* no.

## Lessons for the guideline's B5, continued

- Inside-out, the cost of a wrapped core under plain callers (P6-1) lasted only until the package whose trait code
  calls the plain callers was wrapped (DiffEqBase at S5), not until each plain caller was: plain packages reached
  from trait code are compiled by facts (facts §6.2). Wrap the entry point of a call chain early.
- Profile the steady state by owner (the profiler's `:facts` and default columns) at each step; the plain column
  shows the plain callers that lost types.
- A milestone's order B and J are the cheapest way to see invalidation cost; the image rejections at load (J) explain
  load-time rises with no compilation in them.
- Strict mode's refusal names the first fact only; to see whose code a pirate would change, list the trait roots of
  its callee's backedges (`scripts/p6_pirate_roots.jl`) or run it strict off and count losses by module.
