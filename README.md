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
- From 2026-10-29 (R1, E-236): PT (`env_ports`, `depot-ports`; strict mode on in `depot-ports-strict`): NetworkDynamics from the worktree `pkgs/NetworkDynamics-ports` (branch `ports`) on TraitDifferentialEquations `w34`'s packages, upstream SciML stubbed (`src/r1_stubs.jl`, places marked `# R1:`); `env_r1plot`: the scratch GraphMakie (`pkgs/GraphMakie-r1`, branch `r1-scratch`) over MakieCompat and TraitMakie. Scripts `scripts/r1_*` (`r1_pc.sh <log> [env]` precompiles, `r1_run.sh <log> <script> [env]` runs; `R1_STRICT=1`).
- From 2026-10-29 (R5, E-245, E-246): `env_r5`: `env_ports` with GraphMakie's branch `ports`, MakieCompat and TraitMakie (setting PT for the whole workload; depot `depot-ports`, `depot-ports-strict` with strict mode). The workload's variant for the ports: `NDW_API=ports` (Rodas5 for Rodas5P, the values at `TIMES` by `saveat`, `getu` for `SII.getu`, the network's type per pass as `N` lines, the fixed point's angles centred (`δc`), the graph plots' digests of E-240 as `P` lines), on either stack (`NDW_STACK=ports` or upstream's); `NDW_TIGHT=1` (tolerances 1e-12), `NDW_TSTOPS=1` (the steps end at `TIMES`). `scripts/r5_workload.sh <name> <PT|UP> [runs]` (UP: U′, `env_upstream`); `scripts/r5_compare_plots.py`, `scripts/r5_nearer.py` (the tie-break); `scripts/r5_run.sh`, `scripts/r5_check.jl` (open issue 118's check), `scripts/r5_probe_tsit5.jl`.
- From 2026-10-29 (R2, E-240): `env_r2plot`: GraphMakie's branch `ports` (`pkgs/GraphMakie-ports`, a worktree; upstream 0.6.6 with `Makie` read as MakieCompat, lines marked `# ports`) over MakieCompat and TraitMakie. `scripts/r2_plot_digest.jl <M|PT> <out dir>` draws steps f and g's graph plots with fixed inputs and prints digests (positions, colours as handed to the drawing, line data), in `env_merged` (setting M) or `env_r2plot`; `scripts/r2_leaves_probe.jl` tries GraphMakie's other features.
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
| first a–e | 30.8–31.4 s | 26.0 s | 33.0 s | 25.4 s |
| first plot (f) | 15.3–15.4 s | 15.0 s | 20.7 s | 14.8 s |
| changed b–e | 0.55–0.56 s | 0.47 s | 1.02 s | 0.47 s |
| again c / d / e | 4.4 / 29.5–33.6 / 0.9 ms | 4.5 / 29.6 / 0.8 ms | 5.0 / 34.6 / 1.3 ms | 4.5 / 29.1 / 0.8 ms |
| load Graphs+ND | 2.89–2.95 s | 2.55 s | 7.8 s | 5.31 s |
| session | 65.2–66.1 s | 59.6 s | 83.8 s | 62.0 s |

- Nothing broke: the stack precompiles (370 packages rebuilt, 388 s) and runs; no `OwnershipError`, no `PirateError`. The precompile log's extension warnings: 59 (E-166's rebuild: 69); new among them LinearSolveForwardDiffExt and NonlinearSolveBaseForwardDiffExt.
- Step d is back at E-166's 29 ms: E-162's 267.7 ms (julia-1.13 0c589fd385, open issue 66) does not recur on bfca89decc (W-57's part 1).
- The strict-mode refusal of OffsetArrays' `reshape` (pushback P6-2) no longer occurs; not attributed.
- From 2026-10-29 setting M loads TraitWorld from main (`../TraitWorld`); `TraitWorld-port` stays at `w49` for P4P and IP.

### 2026-10-29: the census of the ports' gaps (E-236, E-237, step R1)

julia-1.13 bfca89decc, TraitWorld main ca92f22, TDE `w34` 3a51d95, TraitMakie 2c70583; settings PT and `env_r1plot`; strict mode off (one workload run also on: the same lines, no refusals); `logs/r1/`. Not a measurement. The items and their order: [the census](../writeup/plans/2026-10-29-ndport-r1-census.md).

| | PT |
|---|---|
| NetworkDynamics loads on TDE's packages | yes, with stubs for 32 upstream names |
| steps a–e, passes `first`, `again`, `params`, `changed`, `graphtype` | run, with marked stand-ins (`run-4.log`: 52 failures listed) |
| the cascade (Tsit5, one TDE callback per component callback) | upstream's 16 trips, same order, times equal to four digits |
| `find_fixpoint`; Rodas5 with continuous callbacks; `sol(t; idxs)`, `NWState(sol, t)`; `init`/`step!` | not on the ports |
| the test subset (`ndtest-4.log`, stand-ins on) | as E-166's, except diffusion `:129` (a mass matrix ignored) |
| GraphMakie over MakieCompat (`gm-run-9.log`) | loads with stand-ins; `graphplot` stops at its first old-API `scatter!` leaf |

### 2026-10-29: GraphMakie's plots on the ports (E-240, step R2, the Makie side)

julia-1.13 bfca89decc, TraitWorld main ca92f22, TraitMakie b68d97a, GraphMakie `ports` 498be7c; `env_r2plot` against setting M (`env_merged`, depot `depot-merged`); product setting, strict mode off; `logs/r2-makie/`. Not a measurement. Steps f and g's plots drawn with the same fixed inputs (not the simulation's: the plots are compared, not the solver).

| | PT (`env_r2plot`) against M |
|---|---|
| GraphMakie on the ports | upstream's 0.6.6, its imports only changed (6 lines, marked); R1's stand-ins gone |
| step f: `fig, ax, p = graphplot(…)`, `hidedecorations!`, `save` | runs; the 13 digest lines equal M's (`digest-M-1.log`, `digest-PT-1.log`) |
| node positions (20), edge line data (120 points, 40 NaN breaks) | equal to 4 digits |
| node colours (`:balance`, range −3..3), edge colours (`:viridis`, automatic range) | equal as RGBA × 255 |
| step g: an `Observable` colour vector into `graphplot!`, a `lift`ed line into `lines!`, `limits!`; 10 frames, 4 saved | runs; colours at each saved frame, the line (11 points) and the listeners (10) equal M's |
| the PNGs | the same figures, not the same pixels (TraitMakie's axis layout and fonts; a `:circle` of markersize 14 is 14 px wide, CairoMakie's about 10) |
| other features (`leaves-probe-1.log`) | node and edge labels, per-edge widths, named markers, a layout as points, attributes changed after the plot, curved edges: draw. Not on the ports: inner labels (text bounding boxes), directed graphs (arrow markers are rotated glyphs), dashed edges |


### 2026-10-29: NetworkDynamics on TDE's R2 items (E-239, step R2, the SciML side)

julia-1.13 bfca89decc, TraitWorld main ca92f22, TDE `w34` f0a79ae, NetworkDynamics `ports` 756c09e; setting PT; product setting, strict mode off; `logs/r2-tde/` (`run-2.log`, `ndtest-2.log`; `r1run-1.log` is R1's script as it is, whose stand-ins call helpers R2 removed). Scripts `scripts/r2_workload.jl`, `r2_nd_tests.jl`, `r2_run.sh`, `r2_pc.sh`. Not a measurement. The items: [the census](../writeup/plans/2026-10-29-ndport-r1-census.md) §3, column R2.

| | PT |
|---|---|
| stubs left | 15 upstream names (the fixed point, `remake`, a DAE's initialization, `ArrayPartition`); 32 in R1 |
| the problem from a network | TDE's `ODEProblem(nw, s0, tspan)`, keeping the network's callbacks; reused across solves |
| the cascade, Tsit5 and Rodas5 | both upstream's 16 trips (15 in `changed`), the same order and times to four digits |
| `NWState(sol, t)`, `extract_nw(sol)`; `K` at t = 3 from the saved parameters | run |
| step g: `init`, `step!(integ, 0.6, true)`, `NWState(integ)` | run |
| failures listed (`run-2.log`) | 24 (R1: 52): `find_fixpoint` (item 11), `remake` (S7), the solution's `idxs` forms and `SII.getu` (open issues 117, 118), each in 4 passes |
| the test subset (`ndtest-2.log`) | massmatrix 6, doctor 26 as before; diffusion 108 pass, 1 fail (`:111`, allocations, as E-166), 1 error; inhomogeneous 39 pass, 1 error. Each error is TDE refusing a DAE network (an algebraic edge; a constraint vertex) that R1 solved as an ODE (open issue 119); the files stop there |
| a callback's `NWState(ctx.integrator)` | refused with a message: the bounded form is blocked by TraitWorld's encoding (E-239) |

### 2026-10-29: NetworkDynamics on TDE's R3 items (E-242, steps R3–R5)

julia-1.13 bfca89decc, TraitWorld main d22ec7b, TDE `w34` e4eeed9 and 388cb33, NetworkDynamics `ports` e0f5664; setting PT; product setting, strict mode off; `logs/r3-tde/` (`pc-1.log`, `run-3.log`, `ndtest-1.log` on e4eeed9; `pc-2.log`, `run-4.log`, `ndtest-2.log` on 388cb33, the same lines; `run-1`, `run-2` show a fault in the script's own dense check, fixed in `run-3`). Scripts `scripts/r3_workload.jl`, `r3_nd_tests.jl`, `r3_run.sh`, `r3_pc.sh`. Not a measurement.

| | PT |
|---|---|
| stubs left | 10 upstream names (a component's and a DAE's initialization: `solve`, `successful_retcode`, `build_solution`, `BrownFullBasicInit`, NonlinearSolve's 4, `QRFactorization`; `ArrayPartition`); 15 in R2 |
| `find_fixpoint(nw)` | TraitNonlinearSolve's `SteadyStateProblem` and default polyalgorithm; the network at a fixed time carries `HasSystem` and `HasJacobianPrototype`; the fixed point equals the relaxation's to 8.4e-10–9.6e-10 (line flows and frequencies; the angles are fixed up to a common shift) |
| `remake(prob; p)` | TDE's; the workload's `fresh()` as upstream's |
| the cascade, Tsit5 and Rodas5 | as in R2 |
| `sol(TIMES; idxs = VIndex(2, :ω))`, `vidxs(nw, :, :ω)`, `EIndex(2, :P)` | run, by NetworkDynamics' own indexing (methods on TDE's solution for `SymbolicIndex`); equal to `NWState(sol, t)[idx]` |
| dense output | the solve without `saveat`, read at `TIMES`: equal to the `saveat` values (difference 0.0) |
| failures listed (`run-3.log`, `run-4.log`) | 4 (R2: 24): `SII.getu(sol, eidxs(nw, :, :P))` in each pass (open issue 118) |
| the test subset (`ndtest-1.log`) | as R2's counts, with the `idxs` and `ODEFunction` stand-ins gone: diffusion's in-place function ends with `nothing` at the source (open issue 120, `# ports`); left `:111` (allocations) and TDE refusing the two DAE networks; `Rodas4` still read as `Rodas5` |

### 2026-10-29: open issue 118 and the ported workload against U′ (E-245, E-246, steps R3–R5)

julia-1.13 bfca89decc, TraitWorld main 4579236, TDE `w34` 282edb3, TraitMakie c0d5c36, NetworkDynamics `ports` ddf7259, GraphMakie `ports` 498be7c, ndport 38692c1 (the runs); product setting; one thread; `logs/r5/`. Not a measurement: the times are printed, not compared (the runs shared the machine).

Open issue 118 (E-245; TDE's side: `../experiments/w34-sciml/README.md`, section E-245): the network implements TraitIndexing's `IndexProvider{NWIndex}`; TDE's solution, integrator and a callback's view read its indices through `getu`.

| | PT |
|---|---|
| the R3 script with `getu` for `SII.getu` (`check-3.log`) | 0 failures (E-242: 4); `getu(sol, eidxs(nw, :, :P))(sol)` and three more index forms exactly NetworkDynamics' own reading over `NWState`; from a callback's view and the integrator too |
| the test subset (`ndtest-1.log`) | as E-242's: massmatrix 6, doctor 26, diffusion 108 pass, `:111` fails (allocations), a DAE refused; inhomogeneous 39 pass, a DAE refused |

The ported workload (E-246), passes `first`, `again`, `params`, `changed`, `graphtype`; PT 2 runs (`run-PT-1`, `-2`), 1 run with strict mode on (`strict-PT-1`); U′ 2 runs (`run-UP-1`, `-2`); the tie-break at tolerances 1e-12 (`tight-*`); the supplement with the steps ending at `TIMES` (`tstops-*`). Comparisons: `compare-run.txt`, `nearer-run.txt`, `compare-tstops.txt`.

| Check | Result |
|---|---|
| PT runs: all passes, every step | 32 digests and 50 plot lines per run |
| PT's runs against each other; strict mode on against off | **exactly equal** (32 digests, 50 plot lines); strict mode refuses nothing |
| `graphtype` against `first` (PT) | **exactly equal** (7 digests, 10 plot lines); upstream refuses the graph type at b |
| the network's type, swing and swing2 | **the same** in PT (`N` lines); two types upstream |
| U′'s runs against each other | exactly equal |
| PT against U′, by tolerance (states `rtol = 1e-5`, `atol = 1e-7`, trips as groups) | a–d and f, g within tolerance (the cascade's lines and order equal; ω, the trips' times, `λmax`, the centred angles); **11 failures, all step e's line flows** (`P2`, `P3`, `Pend`), by up to 7.6e-6 |
| the tie-break: which is nearer the run at 1e-12 (PT's and U′'s tight runs agree within tolerance) | **U′** for every Tsit5 value (U′ 1e-8–1e-7 from it, PT 1e-6–8e-6); PT for Rodas5's (`ω2r`) |
| why | TDE's Tsit5 takes the same steps as upstream's (160 accepted, 0 rejected; `probe-tsit5-*.log`) but reads values between steps by a cubic Hermite polynomial: at `TIMES` 1.8e-6 from the tight run, upstream's own interpolant 1.3e-7; with the steps ending at `TIMES` both 9.7e-8. Events are located on the same interpolant, so the trips' times are 5e-7–2.5e-6 off in PT (U′: 4e-8), and the flows after them differ; with `tstops` (`compare-tstops.txt`) step d is within tolerance and step e's flows still are not |
| the graph plots from the simulation (positions, colours as drawn, line data), PT against U′ | **within tolerance** (40 plot lines: positions equal to 4 digits, colours within 1 of 255 per channel) |
| reported, not compared | the solutions' hashes; the fixed point's hash (the angles 1.3e-4 apart by a common shift); the PNG's size (CairoMakie 1200 × 900, TraitMakie 600 × 450); saved states (U′ 38: `TIMES` and before and after each event; PT 7: `TIMES`) |

