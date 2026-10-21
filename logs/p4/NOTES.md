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

## S1: `ComponentDynamics`, `FunctionDynamics` (a38c925)

- `src/component_dynamics.jl` as the plan's §1.2, included after `component_functions.jl`. ND precompiles
  (18 s), nothing refused (`precompile-s1.log`).
- Check (`rhs-s1.log`): R/J equal to U. `S1` lines: for every component of the three networks,
  `compf!`/`compg!` on a `Kept{ComponentDynamics}` called from plain code give `apply_compf`/`apply_compg`'s
  bits; `hasf`, `fftype`, `pdim`, `extdim` agree with the component's. All true.
- Spelling as the references give it; no surprise.

## S2: Int strides (ac1baa0)

- `_dynamic(bs)` and `_range(bs::BatchStride{<:Union{StaticInt,Int}}, i)` as planned.
- **Added beyond the plan:** a method `_sum_upto_dim(t::NTuple{N,Int}, idx::Int)` (a loop). Upstream's
  `sum(t[1:idx-1], init=0)` slices a tuple by a run-time range: with static strides the types fold; with Int
  strides the slice is `Tuple{Vararg{Int}}`, which in the facts mode is a run-time site on the edge's
  `out_range(batch, i, :src)`. The method keeps it fully typed (`fully_typed(_range, …)` true for both forms,
  `rhs-s2.log`).
- Check: R/J equal to U; every range of every batch equal between static and Int strides.
- **Lesson (B5):** code that relies on static values folding (tuples sliced by computed ranges) needs a typed
  path when the values become run-time values; `fully_typed` on the helper finds it.

## S3: `ComponentBatch` kept and erased (e69ee00)

- Field and parameter `M`, keywords `kept`, `erased` as planned. `constructorof` takes the ten fields (the model
  last, ignored) and rebuilds with the batch's kind (`kept = M !== Nothing`, `erased = F === Any`), so
  `@set batch.compf = …` rebuilds the model. `_dynamic(::BatchStride{Int}) = bs` added for a rebuild of an
  erased batch.
- Check: R/J equal to U. `S3` lines: every typed batch rebuilt kept and erased; `@set` keeps the type; ranges
  and the model's static facts agree; **the erased vertex batches of `swing!` and `swing2!` have one type**,
  `ComponentBatch{VertexModel, Any, Any, FeedForwardType, Int64, Int64, Int64, Int64, Int64, Vector{Int64},
  Kept{ComponentDynamics}}`.

## S4: the batch functions; the workload (9751cbc)

- `_evalf`, `_evalg`, `run_vertex_batch!`, `run_edge_batch!`, `_vertex!`, `_edge!` as §2.3, in `coreloop.jl`
  before `apply_compf`. `@compile_workload` → `TraitWorld.@workload` (PrecompileTools stays in ND's `[deps]`,
  now used only through TraitWorld: Aqua's stale-deps test would flag it; not in the subset).
- The definition check accepts `Threads.@threads` over the trait object in the bounded functions (§5.3's
  "closure passed to Base"): ND precompiles, nothing refused (`precompile-s4.log`).
- Check: R/J equal to U. `S4` lines: the bounded functions called from plain code on an erased batch (as a
  one-element vector) give `apply_comp!`'s bits for every batch, every pass (`:f`, `:g`, `:fg`), sequential and
  threaded: all true.

## S5: erased batches for the sequential and threaded styles (a2a5762)

- `VertexBatch`/`EdgeBatch` take `erased`; the constructor sets it for `SequentialExecution` and
  `ThreadedExecution`, and keeps those containers as a `Vector` (never a tuple).
- Check (`rhs-s5.log`): **`sametype=true`**; R/J equal to U. Through upstream's `apply_comp!`, as the plan
  expected slow: 17 µs and 16,992 bytes per call (sequential).
- The first `using NetworkDynamics` after this precompile took 51 s: TraitWorld moved to a373e30 (joint
  owners) between the precompile and the run, so TraitWorld and ND recompiled once (the coordinator's notice).
  Not a timing of the port.

## S6: the core loop through the bounded functions (c9339fd)

- `process_batches!` methods for `SequentialExecution` and `ThreadedExecution` at `Vector{B<:KeptBatch}`,
  both calling one internal `_process_kept!` (a single method on `Union{Sequential, Threaded}` would be
  ambiguous with upstream's per-style methods). `dispatchT(batch)` instead of the plan's `dispatchT(B)`
  (`dispatchT` has instance methods only).
- **Added beyond the plan:** `any(filt, batches) || return nothing` before the `Ref`, so a pass none of whose
  batches passes the filter allocates nothing (tier S: 3 of 6 passes run batches).
- Check (`rhs-s6.log`): R/J equal to U, `sametype=true`. Tier S, sequential: **3.1 µs and 848 bytes per call**
  (U 0.50 µs, 0; N 0.52 µs, 0). Threaded: 48 µs, 6,304 bytes (U 9.2 µs, 2,848; N 43.8 µs, 5,200).
- **W** (`logs/p4-s6/P4-1.log`, one run): 25 digests, **0 exact differences against U and against N.**
  "changed" b–e compile 79 + 222 + 129 + 0 = **430 ms** (N 77 + 3,626 + 8,702 + 2,565 ms). Steady state
  ("again"): a 1.7, b 0.5, c 6.2, **d 46.8**, e 1.0, f 38.9, g 164.7 ms; N: 1.7, 0.5, 3.7, 15.3, 0.6, 39.1,
  165.9. **Step d exceeds criterion 4's margin (1.10 × 15.3 + 5 = 21.8 ms)**; c is inside (9.1). To be
  confirmed by the S8 runs.
- **T** (`ndtest-p4-s6.log`): massmatrix 6/6, doctor 26/26, diffusion 111 pass + 1 fail (24 broken as
  upstream), inhomogeneous 43 pass + 2 fail (12 broken as upstream). The three failures are the allocation
  assertions PB-4 predicts, and nothing else:
  - `diffusion_test.jl:111` `@allocated(rhs) == 0`: 1,728 bytes;
  - `inhomogeneous_test.jl:59` `@allocations(rhs) == 0`: 61;
  - `inhomogeneous_test.jl:93` `rhs_allocs(small) == rhs_allocs(large) ≤ 4`: 1,306 and 5,206 (50 and 400
    batches): about 13 allocations per crossing, growing with the number of batches.

### The barrier's cost, measured (`scripts/p4_barrier.jl`, `logs/p4/barrier-s6.log`; candidate data for PB-4)

- One right-hand side of tier S: **32 allocations** (848 bytes), 3 `Ref`s and 3 crossings.
- One vertex pass through `process_batches!` (one batch of 20): 16 allocations, about 1.0 µs.
- **The crossing costs about 13 allocations and 0.7–0.8 µs when the caller is facts code** (ND's
  `_process_kept!`), **and 2 allocations and 0.28 µs when the same call is made from plain code** (`Main`):
  measured by defining the same three-line caller in `Main` and, by `Core.eval`, in ND (`scripts/p4_barrier_facts.jl`, `barrier-facts-s6.log`; first
  numbers: facts `compiled_for` 115 ns/2 allocs; facts call with `m::Any` 771 ns/12; facts `compiled_for`+call
  798 ns/13; the same with `::Kept{ComponentDynamics}` asserted 722 ns/13; plain `compiled_for`+call 276 ns/2).
- `fully_typed(run_vertex_batch!, (Kept{ComponentDynamics}, …))`: 27 run-time sites, all in the machinery
  (`untyped.jl:230–244` `_pmiss`, `entry.jl:259` `_assemble(TraitList{…}, Any)`, `PEntry(…)`, Base's task
  code from `Threads.@threads`). `fully_typed(_process_kept!, …)`: one site, the crossing itself, because
  `compiled_for(::Kept{ComponentDynamics})` infers `Any` in facts code (`Base.return_types` gives `Any`).
- Reading: a family member takes the entry's generic path (lowering §9.3); the machinery is facts code when
  trait code calls it (lowering §2, L-17), and its generic path has run-time sites. So the per-crossing cost
  from inside a trait module is about 3× the time and 6× the allocations of the same crossing from plain code.
  The port can not change this within the language: it is TraitWorld's (the table for family members, PB-4;
  `compiled_for`'s inferred result). **For PB-4 and open issues §4 item 35.**
- Candidate alternative (not taken, the plan's shape kept): store the model `Compiled` at construction
  (`Kept{ComponentDynamics}(compiled_for(fd))`) and drop the per-crossing `compiled_for`: would save about
  2 of the 13 allocations per crossing.

## S7: Polyester (no code change)

- `Polyester.@batch`'s expansion (`scripts/p4_polyester_expand.jl`, `s7-polyester-expand.log`): the loop body
  becomes a closure that captures nothing; every variable, the trait object included, is passed bare through
  `Polyester.wrap_type(m)` and then as an argument of `Polyester.batch(closure, …, wrap_type(m), …)`.
- So it is not §5.3's "closure over a trait object passed to Base": it passes the trait object bare to two
  ordinary functions of another package. Confirmed by a five-line trait module
  (`scripts/p4_polyester_check.jl`, `s7-polyester-check.log`): the definition check refuses it,
  `TraitUseError`, "a trait object … is passed to `wrap_type`, an ordinary function" and the same for `batch`.
- **Outcome: `PolyesterExecution` keeps typed batches** (the plan's alternative); S5 already erases only the
  sequential and threaded styles. Nothing to commit. **For PB-7:** the answer is "refused: bare, not a closure".
  The idiomatic form (the same loop over the trait object, parallel) needs either Polyester's loop over an
  operation the trait declares, or a rule for trait objects passed through a package's macro machinery.

## S8: E-152's runs

- Two runs in P4 (`logs/p4-1/P4-{1,2}.log`), one attribution run (`logs/p4-1-diag/P4-1.log`); the code is
  c9339fd, as at S6's T run (`ndtest-p4-s6.log`), so that T run is S8's (TraitWorld a373e30 in both).

| # | Criterion | Result | Pass |
|---|---|---|---|
| 0 | tier S's two networks of one type | `sametype=true` (S5 on; `rhs-s5.log`, `rhs-s6.log`) | **yes** |
| 1 | digests exact against U; again = first; rhs_check hashes = U | 0 exact differences in 25 digests, both runs (also against N); every R/J line equal to U | **yes** |
| 2 | "changed" b–e new CodeInstances of SciML packages and SII ≤ 50 | **0**. b–e create 207 CodeInstances in all (b 91, c 82, d 34, e 0), all `:facts`, of Base, TraitWorld, NetworkDynamics, ForwardDiff (3), Static (2), Core, Main (U: c 2,737, d 2,734, e 1,065) | **yes** |
| 3 | "changed" b–e compile ≤ 2,000 ms, both runs | **426 and 493 ms** (b 80–81, c 220–228, d 127–185, e 0); N 14,970; P0 14,977–15,220. a–g: a 54–56, f 0, g 0 compile | **yes** |
| 4 | steady state ≤ 1.10 × N + 5 ms per step (min of 2 runs) | a 1.6 (N 1.7), b 0.5 (0.5), c 6.1 (3.7; bound 9.1), **d 46.8 (15.3; bound 21.8)**, e 1.0 (0.6), f 36.8 (39.1), g 139.5 (165.9). d is 46.8, 46.8, 47.1 in three runs (with S6's) | **no, at step d (confirmed)** |
| 5 | first session (reported) | first pass a–g 54.9–55.6 s (N 56.5, P0 39.9–40.0); loads 5.9–6.0 s (N 6.1, P0 6.2–6.3); session 67.5–68.4 s (N 86.9, P0 71.1–71.3) | — |
| 6 | allocations per rhs ≤ passes with batches + crossings (tier S: 3 + 3) | **32 allocations**, 848 bytes; 3.1 µs (U 0.50 µs, 0; N 0.52 µs, 0). The 3 `Ref`s are the passes'; about 9–10 more per crossing come from the entry's generic path compiled by facts (S6's notes) | **no**; not the Ref pattern: TraitWorld's (PB-4) |
| 7 | ND's test subset as at `upstream`, except PB-4's allocation assertions | the same passes; fails only `diffusion_test.jl:111` (1,728 B), `inhomogeneous_test.jl:59` (61), `:93` (1,306 vs 5,206 for 50 vs 400 batches) | **yes** |

- **Step d attributed** (`scripts/p4_stepd_ab.jl`, `logs/p4/stepd-ab-s8.log`, one session, one thread): erased
  batches 46.3–48.1 ms; the same network with typed batches 15.1–15.6 ms. So the 31 ms are the barrier, about
  2.6 µs more per right-hand side, so roughly 12,000 right-hand-side calls in step d (Tsit5, Rodas5P at duals,
  the callbacks' conditions through `get_buffers`); a reading, not counted.
- Step c's steady state also grows (3.7 → 6.1 ms), within the margin.
- Per the plan (§3, "What a failure changes"): **criterion 4 failing, confirmed → the port stops before step 2;
  the numbers go to open issues §4 item 35 and PB-4; the user decides.** I stopped here.

## Candidate pushback entries (the log's shape), for the coordinator

**PB-4 (amend with numbers): the barrier per batch costs about 13 allocations and 0.8 µs from trait code.**
- The code: `_process_kept!` (`coreloop.jl`), `run_vertex_batch!(compiled_for(batch.model), batches, k, args)`,
  per batch per pass; tier S: 3 crossings per right-hand side.
- Measured: 32 allocations and 3.1 µs per right-hand side (U 0, 0.50 µs). Per crossing from ND's facts code
  about 13 allocations and 0.8 µs; the same call from plain code 2 allocations and 0.28 µs. ND's allocation
  tests fail by construction (counts above). Step d's steady state 46.8 against N's 15.3 ms.
- Why (by `fully_typed`, not by reading TraitWorld further): a family member takes the generic path
  (lowering §9.3); the machinery on that path is facts code when trait code calls it (lowering §2, L-17) and has
  run-time sites (`_pmiss`, `_assemble(TraitList{…}, Any)`, `PEntry(…)`); and `compiled_for(::Kept{X})` infers
  `Any` in facts code, so the crossing is a dynamic call even where the kept value's type is known
  (asserting `::Kept{ComponentDynamics}` does not change the cost).
- The idiomatic form: a library's own family opened by `compiled_for` at a loop over its data (A12) costs a
  plain function barrier: one dynamic call, no allocation per batch.
- The reference: §6.8 says a `Compiled` value of unknown type selects its code once per call; nothing on its
  cost or allocations. Open issues §4 item 35.
- Blocks: **yes for criterion 4** (the plan's rule pauses the port). For the user: whether serving family
  members in the entry's table, and a typed generic path when the caller is facts code, become work items.
- What the port did: kept the plan's shape; recorded the numbers; stopped before step 2.

**PB-7 (answer): Polyester's `@batch` passes the trait object bare.** See S7: refused by the definition check
(`wrap_type`, `batch`). Polyester keeps typed batches. A question for the user only if Polyester should join the
erased path: then a rule for trait objects passed through another package's loop machinery is needed.

**New, small: a tuple sliced by a run-time range (S2).** Not a design pushback: the facts mode does what facts §3
says (a non-concrete `Tuple{Vararg{Int}}` argument is a run-time site). Upstream relied on static values to
fold `sum(t[1:idx-1])`; the port added a typed loop for Int strides. A guideline lesson (below), not a log entry.

**Observation for P3's record (not P4's): threads in the facts mode.** The wrapped package without traits (S0):
`ThreadedExecution` 43.8 µs and 5,200 bytes per right-hand side against U's 9.2 µs and 2,848 bytes. After S6
48 µs. Evidence §5 lists threads as untested in the facts mode.

## Lessons for the guideline (B5), as they stand after this step

- A trait at a library's internal calling convention can come first; one trait and one family serve the core
  loop's vertex and edge batches alike.
- A library's own implementation as a family over its own parametric type (`FunctionDynamics{F, G, FF, PDIM,
  EXTDIM}`) keeps the user's functions typed inside the key and out of every other type: the network's type is
  the same for both equations, and changing the equations compiles 0.4–0.5 s instead of 15 s, with no new code
  in SciML or SymbolicIndexingInterface.
- Values that decide types in hot code (dimensions zero or not) go in the key as type parameters of the
  implementing type.
- **The crossing has a cost per call that a library must budget for:** from trait code, about 13 allocations and
  0.8 µs per crossing for a family member (this build). A per-batch barrier inside a right-hand side called
  thousands of times per solve shows in the steady state (3× in step d). Put the crossing where the work behind
  it is large, or measure it first with a one-session A/B against the typed path.
- At a barrier, the other arguments travel as heap objects: one `Ref` per pass, built only when a batch runs,
  the container and an index.
- Code that leans on static values folding (a tuple sliced by a computed range) needs a typed path once those
  values become run-time values; `fully_typed` on the helper finds it.
- In a wrapped package the package's `@compile_workload` becomes `TraitWorld.@workload` with the first bounded
  function (PrecompileTools then remains a dependency only through TraitWorld).
- A package's macro that hands loop variables to its own functions (`Polyester.@batch`) is not a closure passed
  to Base: the definition check refuses a trait object there. Read the expansion first.
- A one-method helper on `Union{StyleA, StyleB}` beside upstream's per-style methods is ambiguous; define one
  method per style that calls a shared internal function.

## Upstream bugs met (not the port's)

- `KAExecution`: `get_buffers` fails (`get_backend(nothing)`); `compkernel_fg!` names its argument `inbuf` and
  uses `inbufs` (an `UndefVarError` on any network with a feed-forward edge).
