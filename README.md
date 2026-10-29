# NetworkDynamics in the trait world (the large-scale test, W-32)

NetworkDynamics.jl, the SciML packages under it, GraphMakie with Makie, and Observables, moved into the trait world a function at a time, against the unmodified upstream packages. The meta plan, with the parts and their plans: [`../writeup/plans/2026-10-21-networkdynamics-port.md`](../writeup/plans/2026-10-21-networkdynamics-port.md). Current numbers belong in the design's [`../writeup/design/evidence.md`](../writeup/design/evidence.md); this file keeps dated tables of its own results.

## Layout

- `pkgs/`: the clones, each its own git repository (ignored here). Each is on branch `trait-port`, started at the resolved release and tagged `upstream`; `git -C pkgs/<repo> diff upstream` is the port. `scripts/clone.sh` makes them and writes `VERSIONS.tsv` (name, version, repository, subdirectory, commit, tree-hash check).
- `env_upstream/`: the registry's packages, unchanged (the baseline).
- `env_port/`: the clones through `[sources]`, with TraitWorld.
- `scripts/`: the workload and the harness.
- `logs/<tag>/`: every run's log, committed.

## How to run

All runs use the patched Julia, one job at a time through the shared lock, niced:

```
JULIA_PKG_OFFLINE=true flock /tmp/claude-1000/julia-review.lock nice -n 19 ../julia-1.13/julia --project=env_upstream ...
```

The workload is part P1 of the meta plan ([`../writeup/plans/2026-10-21-ndport-workload.md`](../writeup/plans/2026-10-21-ndport-workload.md)):

- `scripts/workload.jl` (the driver) and `scripts/workload_steps.jl` (the steps a–g): the loads timed in groups, then four passes in one session: `first`, `again`, `params` (the problem remade with new parameters: no new types), `changed` (a new component function). Each step prints `T <pass> <step> <ms> compile <ms> recompile <ms> gc <ms>` and a digest `D <pass> <step> …`, the digest outside the timed window.
- `scripts/run_workload.sh <tag> <U|P0|A0|S> [runs]`: fresh sessions through the lock; refuses to run where a dependency is not precompiled; marks a run that precompiled INVALID. `NDW_DIAG=1` adds the attribution (`scripts/diag.jl`: new CodeInstances per step by module; its times are not measurements).
- `scripts/compare_digests.py <ref.log> <log> [--exact]`, `scripts/summarize.py <logs>`, `scripts/check_env.py`.
- The settings: U (`env_upstream`, patched build), P0 (`env_port`, TraitWorld loaded, product setting), A0 (`env_port` under `all`, depot `depot-facts/`), S (stock 1.13.2, depot `depot-stock/`); N (NetworkDynamics wrapped whole, `pkgs/NetworkDynamics-p3wrap`, `env_p3`, `depot-p3`), W (N plus the workload's own module a trait module), P4 (the port, `pkgs/NetworkDynamics-p4`, `env_p4`, `depot-p4`), I (P6, E-155: the SciML core wrapped inside out, `pkgs/*-p6`, `env_p6`, `depot-p6`, NetworkDynamics as in N; its default script `p6_workload.jl` prints strict mode's state). From E-165: P4P (`env_p4_pin`, `depot-p4pin`), IP (`env_p6_pin`, `depot-p6pin`): the tracks' last steps on TraitWorld c655dde (the worktree `TraitWorld-port`); M (`env_merged`, `depot-merged`): the merge, the trees on branches `port` (`logs/merge/NOTES.md`). Since 2026-10-22 13:34 every run is on two cores (`taskset -c 0-1`), idle I/O class, one precompile task; the header says so.
- `NDW_ORDER=simfirst`: the plotting packages load after the first simulation (P3's order B), with the CodeInstances the load discards counted (`G` line). `NDW_STRICT=1`: strict mode. `NDW_SCRIPT=<path>`: another script in the harness (`p3_census.jl`, `p3_pirate.jl`).

## Results

Current numbers: the design's [evidence §3](../writeup/design/evidence.md#3-first-calls-and-sessions).

### 2026-10-21: the baselines (E-151)

julia-1.13 6d480d0753, TraitWorld e9f4bfe, clones at `upstream`; strict mode off; load 1–3; U and P0 2 runs, A0 and S 1 run; `logs/p1/`. Seconds per pass (sum of its steps' first calls, timed whole).

| Setting | Loads | first | again | params | changed (compiling) | session |
|---|---|---|---|---|---|---|
| U | 5.4–5.6 | 39.7–40.4 | 0.2 | 0.7 | 15.9–16.3 (15.6–16.0) | 69.9–70.7 |
| P0 | 6.2–6.3 | 39.9–40.0 | 0.2 | 0.7–0.8 | 16.0–16.2 (15.8–15.9) | 71.1–71.3 |
| A0 | 11.9 | 34.5 | 0.3 | 0.6 | 15.1 (14.8) | 72.7 |
| S | 5.7 | 39.0 | 0.2 | 0.6 | 16.1 (15.8) | 69.6 |

- All 25 digests equal bit for bit across the settings.
- Precompilation: upstream 320 s; `env_port` 175 s (72 packages); under `all` 354 s (476 packages); stock 289 s (`logs/setup/`).
- The attribution (`logs/p1-diag/U-1.log`): `changed` creates 6,810 CodeInstances; fixed point ~2,700, solves ~2,700, access ~1,070, Makie almost none.

### 2026-10-21: the facts mode first (E-153)

Same builds; NetworkDynamics p3-wrap e5425fd; Static.jl c34adbb (the promotion fix); one run each; `logs/p3/`, `logs/p3-orderB/`, `logs/p3-pirate/`, `logs/p3-dev/`.

| | U / P0 | N (ND wrapped) | W (N + the workload a trait module) | A0 (`all`) |
|---|---|---|---|---|
| session, P1's order | 70 s | 87 s | — | 73 s |
| a Tsit5 + Rodas5P solve, steady state | 19.7 ms | 15.3 ms | 17.1 ms | 15.3 ms |
| first simulation (a–e) | 21.5 s | 37.8 s | 41.9 s | 23.6 s |
| first plot (f) | 16.0 s | 15.4 s | 48.5 s | 10.6 s |
| order B: lost to the plotting load | 4,062 | 2,884 (0 of `:facts`) | 3,017 (0 of `:facts`) | 1,198 |
| order B: the next simulation pass recompiles | 4.7 s | 0.04 s | 0 s | 0 s |

- Without Static's fix, N's steady state was 30.2 s per solve (the dispatch profile: `logs/p3-dev/hot-N.log`).
- The pirate: N strict off accepted (84 lost, 75 `:facts`); N strict on refused; P0 strict on accepted (81 lost).
- The census (`logs/p3/census-P0.log`): pirates by the letter: NetworkDynamics 0, DiffEqBase 28, NonlinearSolveBase 12, NonlinearSolve 10, Makie 8, OrdinaryDiffEqCore 3, GraphMakie 2, the others 0.


### 2026-10-21: the component dynamics behind a trait (E-152, P4 step 1)

julia-1.13 6d480d0753, TraitWorld a373e30; NetworkDynamics `trait-port` c9339fd (`pkgs/NetworkDynamics-p4`); Static.jl c34adbb; setting P4 (`env_p4`, `depot-p4`); strict mode off; P1's load order; two runs (`logs/p4-1/`), one attribution run (`logs/p4-1-diag/`); N is E-153's one run (`logs/p3/N-1.log`). Measures ND's own trait code (the batch functions) calling the user's plain component functions: interop.

| | U | N | P4 (2 runs) |
|---|---|---|---|
| tier S's two networks of one type (`rhs_check.jl`) | no | no | **yes** |
| digests against U, exact | — | 0 differences | 0 differences |
| "changed" b–e compile | 15.6–16.0 s (E-151) | 14.97 s | **0.43–0.49 s** |
| "changed" b–e new CodeInstances of SciML and SII (attribution) | ~2,300 of 6,536 (c–e) | — | **0** of 207 |
| steady state step c / **d** (a Tsit5 + Rodas5P solve) | 3.0 / 19.8 ms | 3.7 / 15.3 ms | 6.1 / **46.8–47.1 ms** |
| steady state f / g | 35.4 / 158.2 ms | 39.1 / 165.9 ms | 36.8–37.7 / 139.5–184.7 ms |
| one right-hand side, tier S, sequential (`rhs_check.jl`, two threads) | 0.50 µs, 0 B | 0.52 µs, 0 B | 3.1 µs, 848 B (32 allocations) |
| first pass a–g | 39.7 s | 56.5 s | 54.9–55.6 s |
| session | 69.9 s | 86.9 s | 67.5–68.4 s |

- Step d attributed in one session (`scripts/p4_stepd_ab.jl`, `logs/p4/stepd-ab-s8.log`): erased batches 46.3–48.1 ms, the same network with typed batches (Polyester's serial path) 15.1–15.6 ms. The difference is the barrier: about 13 allocations and 0.8 µs per batch crossing from ND's facts-compiled core loop, against 2 allocations and 0.28 µs for the same call from plain code (`logs/p4/barrier-s6.log`, `barrier-facts-s6.log`).
- ND's test subset (`scripts/nd_tests.jl`, `logs/p4/ndtest-*.log`): as at `upstream`, except the three allocation assertions (`diffusion_test.jl:111`, `inhomogeneous_test.jl:59`, `:93`).
- Running notes, per sub-step: `logs/p4/NOTES.md`.

### 2026-10-21: the graph trait (E-154, P4 step 2)

julia-1.13 6d480d0753, TraitWorld 3bebf13; Graphs `trait-port-p4` 54632125 (`pkgs/Graphs-p4`: `Graphs.GraphInterface{V}`, declared as plain code, a family over `AbstractGraph`); NetworkDynamics `trait-port` 19c2045 (`graph_index` bounded by it; the feed-forward check's move, G3, reverted: see the notes); setting P4 with Graphs at the worktree; strict mode off; P1's load order; the harness at 029de9b. P4G-0: ND c9339fd, Graphs at `upstream`, two runs (`logs/p4g/P4G-0/`). P4G-1: two runs, one confirming run, one with `graphtype`, one attribution run (`logs/p4g/P4G-1*/`). Interop: ND's bounded functions reading plain graph types.

| | U | P4G-0 | P4G-1 |
|---|---|---|---|
| digests against U, exact (common passes) | — | 0 differences | 0 differences (5 logs) |
| a network on `GenericGraph` / `GenericDiGraph` / `SimpleGraph{Int32}` | fails (`MethodError`, the index manager's conversion) | fails | **builds; results equal to the `SimpleGraph{Int64}`'s** |
| the `graphtype` pass (a–g on a `GenericGraph`) | fails at b | — | runs; 7 digests equal to `first`; 18.0 s (17.7 s compiling) |
| a graph type whose `nv` returns the wrong type (`WrongNv`) | fails (conversion) | fails (conversion) | refused: `ImplementError` naming `nv`, `Int64`, `Int32` |
| first step b | 1.4–1.6 s | 0.55–0.56 s | 0.55–0.56 s |
| steady state c / d / f / g (min of runs) | — | 4.9 / 33.4 / 37.6 / 144.5 ms | 4.6 / 33.1 / 38.9 / 158.2 ms |
| the common passes, per session | — | 58.3–58.4 s | 57.0–58.2 s |

- The member table (`scripts/graph_check.jl`, `logs/p4g/check-*.log`): `SimpleGraph{Int64}`, `SimpleDiGraph`, `SimpleGraph{Int32}`, `GenericGraph`, `GenericDiGraph`, `ReverseView`, `UndirectedView` conform at their first use.
- ND's test subset (`logs/p4g/ndtest-final.log`): as at c9339fd.
- Two TraitWorld failures found (candidate deviation rows): `edge_list` on a `Dynamic` trait object (`TypeError`, `SimpleEdge{OpenParam}`; `logs/p4g/g0-P4-2.log`); a closure in a bounded function capturing a variable of a type not inferred (`FieldError`; `scripts/graph_g3_min.jl`, `logs/p4g/g3-min.log`), which stopped G3.
- Running notes, per sub-step: `logs/p4g/NOTES.md`.

### 2026-10-21: the SciML core wrapped inside out, under strict mode (E-155, P6)

julia-1.13 6d480d0753, TraitWorld 3bebf13; NetworkDynamics p3-wrap e5425fd; Static.jl c34adbb; setting I (`env_p6`, `depot-p6`); strict mode on; P1's load order; one run per step; load 0.9–1.7; `logs/p6-s<k>/`, `logs/p6-s<k>-census/`, running notes `logs/p6/NOTES.md`. Measures upstream's code with the plan's two `@joint_owners` lines, compiled by facts as trait modules: no trait code (neither interop nor idiomatic). Steps: S1 SymbolicIndexingInterface, RecursiveArrayTools; S2 SciMLBase (joint owners: eight packages); S3 NonlinearSolveBase, BracketingNonlinearSolve, SciMLJacobianOperators; S4 the NonlinearSolve family; S5 DiffEqBase; S6 OrdinaryDiffEqCore (joint owner OrdinaryDiffEqDifferentiation), Tsit5, DiffEqCallbacks; S7 OrdinaryDiffEqRosenbrock.

| Step | Rebuilt, precompile | First a–e | Again c / d / e | Dynamic calls (top 40) trait / plain | Loads ND / solvers |
|---|---|---|---|---|---|
| S0 (I0) | 74, 137 s | 36.4 s | 3.6 / 15.0 / 0.6 ms | 34,601 / 647 | 6.11 / 0.33 s |
| S1 | 59, 147 s | 36.8 s | 3.5 / 15.1 / 0.7 ms | 34,605 / 644 | 6.15 / 0.36 s |
| S2 | 48, 196 s | 52.4 s | 3.7 / 29.2 / 0.7 ms | 24,595 / 100,501 | 8.64 / 4.32 s |
| S3 | 35, 176 s | 49.3 s | 3.8 / 28.6 / 0.8 ms | 24,994 / 98,419 | 8.19 / 4.28 s |
| S4 | 9, 101 s | 49.1 s | 3.7 / 29.7 / 0.7 ms | 24,994 / 98,419 | 8.12 / 4.23 s |
| S5 | 15, 68 s | 29.5 s | 3.6 / 16.0 / 0.7 ms | 40,254 / 5 | 8.35 / 0.46 s |
| S6 | 10, 62 s | 28.9 s | 3.8 / 16.0 / 0.7 ms | 40,254 / 5 | 8.27 / 0.47 s |
| S7 | 1, 46 s | 28.9 s | 3.6 / 16.2 / 0.7 ms | 40,254 / 5 | 8.19 / 0.43 s |

- Every step: 25 digests equal to U's bit for bit; no pirate in a wrapped package; the only refusal OffsetArrays' `reshape` at the plotting load (Base's own code protected; present at I0).
- S2–S4: plain callers lose constant propagation into SciMLBase's `getproperty` overloads (step d 29 ms; the solvers' images rejected at load). Gone from S5, when the solver's code is reached from DiffEqBase's trait code.
- Order B at S7: the plotting load takes no CodeInstance of `:facts`, and the next pass recompiles nothing (S4: 5.4 s; N 0.04 s; U 4.7 s).
- Packages' quick tests (`scripts/p6_tests.jl`): as at upstream, except 5 inference assertions in SciMLBase's at S2 (facts inference by design); ND's subset at S7 identical to upstream.

### 2026-10-22: the two tracks merged (E-165), and G3

julia-1.13 build 2943086604; TraitWorld c655dde (`TraitWorld-port`); NetworkDynamics `port` 324bcb7 (tag `p4-s2`: step 2 with G3), Graphs `port` 54632125; the P6 trees on `port` from their `p6-s<k>` tags (Rosenbrock `port-ros`); P1's load order; one run per check, confirming runs named; load 1.2–3.3; `logs/merge/`, G3 in `logs/p4g/` ("G3 again"). P4P and M measure P4's trait code (ND's bounded functions calling the user's plain functions: interop) on plain or wrapped SciML; IP measures upstream's code compiled by facts (no trait code).

| | P4P (strict off, 2 runs) | IP (strict on) | M strict off | M strict on (3 runs) |
|---|---|---|---|---|
| digests against U, exact | 0 differences | 0 differences | 0 differences | 0 differences |
| refusals | — | OffsetArrays' `reshape` (Base's code) | — | the same one only |
| first a–e | 39.1 s | 30.2–31.6 s | 31.1 s | 31.0–32.7 s |
| changed b–e | 0.54–0.63 s | 15.7 s | 0.56 s | 0.63 s |
| again c / d / e | 5.0–5.1 / 34.4–35.0 / 0.9 ms | 3.7 / 16.8 / 0.9 ms | 5.2 / 34.7 / 1.0 ms | 5.1–5.3 / 35.9–37.8 / 1.0–1.3 ms |
| load Graphs+ND | 3.1 s | 7.6–7.9 s | 2.9 s | 7.9–8.1 s |
| session | 70.2 s | 91.2–95.7 s | 65.9 s | 75.2–78.6 s |

- G3 (the feed-forward check in `check_feedforward_leaves(g::GraphInterface{V}, …)`, upstream's block unchanged): P, C (the `ff` network now builds on a `GenericDiGraph`), R (equal to U), T (as at c9339fd) pass on c655dde; T-59's reproducer passes.
- P builds: P4P 450 packages 329 s; IP 450, 370 s; M 450, 368 s (fresh depots, strict on for IP and M).
- C (strict on): pirates in wrapped packages 0, except one in NetworkDynamics that TraitWorld generates for a family implementation (`_family_registry`, `logs/merge/family-registry.log`). H: plain dynamic calls 5; P4's crossings add 35,290 `checked_call`s from trait code.
- In the same conditions (strict on, two cores; `strict1-pair/`) step d is 35.1 ms in P4 alone and 35.9 ms in the merge: the merge's strict-on runs above P4's strict-off reference are spread and strict mode, not P6's wrap.

### 2026-10-22: the batches' crossings and the traits per kind (E-166, P4 step 3, part 3a)

julia-1.13 build 2943086604; TraitWorld `w49` 3ae361c (`TraitWorld-port`: c655dde plus W-49, which retires lowering L-39–L-41; on TraitWorld main as 4410407); NetworkDynamics `port` 4e5f5a2 (`VertexDynamics`, `EdgeDynamics` subtraits of `ComponentDynamics`, the batches per kind; upstream's annotations kept); setting M; P1's load order; two cores, idle I/O, one precompile task; load 1.2–3.1; `logs/p4s3/` (notes: `logs/p4s3/NOTES.md`). Interop: ND's bounded functions calling the user's plain functions. The step-3 plan: [`../writeup/plans/2026-10-22-ndport-step3.md`](../writeup/plans/2026-10-22-ndport-step3.md).

| | M-0 (E-165) | S3-1 (W-49 only) | M-3a strict off (2 runs) | M-3a strict on (2 runs) |
|---|---|---|---|---|
| digests against U, exact | 0 differences | 0 | 0 | 0 |
| crossing into an empty batch | 165–182 ns | 37–48 ns | 36–47 ns | — |
| one right-hand side, tier S | 1,834 ns, 5 allocations | 1,177 ns | 1,238–1,312 ns, 5 allocations | — |
| again c / d / e | 5.2 / 34.7 / 1.0 ms | 4.8 / 28.8 / 1.0 | 4.4 / 29.5–33.6 / 0.9 | 5.0–5.4 / 33.4–34.6 / 1.1–1.3 |
| changed b–e | 0.56 s | 0.54 s | 0.55–0.56 s | 0.73–1.02 s |
| first a–e | 31.1 s | 31.6 s | 30.8–31.4 s | 33.0–37.4 s |
| session | 65.9 s | 67.5 s | 65.2–66.1 s | 83.8–91.1 s |

- Probe A (`scripts/p4s3_cross_shapes.jl`): ND's shape (`bs::Vector, k::Int, args::RefValue`) 217 → 84 ns; `where {A}` 294 → 72 ns (tabled); nine arguments raise `MethodError` before, run after.
- Strict on: the one refusal OffsetArrays' `reshape` (Base's code), the extension warnings as E-165's. The census: NetworkDynamics' three family registry methods (L-38), every other package as E-165. ND's test subset as before.
- A right-hand side allocates 240 bytes after the traits per kind (208 with W-49 alone): the trait object carries the supertrait's view too; not attributed further.


### 2026-10-29: the merged port revived on the current builds (E-235)

julia-1.13 bfca89decc, TraitWorld main ca92f22 (before: julia-1.13 2943086604, TraitWorld `w49` 3ae361c); setting M (`env_merged`, `depot-merged`; NetworkDynamics `port` 4e5f5a2, Graphs `port` 54632125, P6's trees on `port`); `env_merged` resolved offline with TraitWorld from main (the manifest's only change), rebuilt with strict mode on (`scripts/p6_precompile.sh`, four tasks on four cores: `logs/revive/precompile-merged-bfca89decc.log`); P1's load order; two cores; one run strict off (`logs/revive/`), one strict on (`logs/revive-strict1/`); load 1.3–2.9. Interop: ND's bounded functions calling the user's plain functions, upstream SciML compiled by facts.

| | M-3a strict off (E-166, 2 runs) | revived, strict off | M-3a strict on (E-166) | revived, strict on |
|---|---|---|---|---|
| digests against U (E-151) and E-166, exact | 0 differences | 0, 0 | 0 | 0, 0 |
| refusals under strict mode | — | — | OffsetArrays' `reshape` | **none** |
| extension warnings (precompile) | 69 | — | — | 59 (new: LinearSolveForwardDiffExt, NonlinearSolveBaseForwardDiffExt) |
| first a–e | 30.8–31.4 s | 26.0 s | 33.0 s | 25.4 s |
| first plot (f) | 15.3–15.4 s | 15.0 s | 20.7 s | 14.8 s |
| changed b–e | 0.55–0.56 s | 0.47 s | 1.02 s | 0.47 s |
| again c / d / e | 4.4 / 29.5–33.6 / 0.9 ms | 4.5 / 29.6 / 0.8 ms | 5.0 / 34.6 / 1.3 ms | 4.5 / 29.1 / 0.8 ms |
| load Graphs+ND | 2.89–2.95 s | 2.55 s | 7.8 s | 5.31 s |
| session | 65.2–66.1 s | 59.6 s | 83.8 s | 62.0 s |

- Nothing broke: the stack precompiles (370 packages rebuilt, 388 s) and runs; no `OwnershipError`, no `PirateError`.
- Step d is back at E-166's 29 ms: E-162's 267.7 ms (julia-1.13 0c589fd385, open issue 66) does not recur on bfca89decc (W-57's part 1).
- The strict-mode refusal of OffsetArrays' `reshape` (pushback P6-2) no longer occurs; not attributed.
- From 2026-10-29 setting M loads TraitWorld from main (`../TraitWorld`); `TraitWorld-port` stays at `w49` for P4P and IP.
