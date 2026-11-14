# NetworkDynamics in the trait world (the large-scale test, W-32)

NetworkDynamics.jl, the SciML packages under it, GraphMakie with Makie, and Observables, moved into the trait world a function at a time, against the unmodified upstream packages. The meta plan, with the parts and their plans: [`../writeup/plans/2026-10-21-networkdynamics-port.md`](../writeup/plans/2026-10-21-networkdynamics-port.md). Current numbers belong in the design's [`../writeup/design/evidence.md`](../writeup/design/evidence.md); this file keeps dated tables of its own results.

## On the unified build (W-104, slice 3)

NetworkDynamics' port and Graphs' on Julia's unified build (`julia-unified`, branch `unified`) with TraitWorld's and TraitDifferentialEquations' branches `unified`: the worktrees `pkgs/NetworkDynamics-unified` and `pkgs/Graphs-unified` (branches `unified`, from `ports` and `port`), the environment `env_unified/` (setting PT without the plotting packages).

- **How to run:** `JULIA_PKG_OFFLINE=true ../julia-unified/julia -t 2 --project=env_unified scripts/r3_nd_tests.jl` (the test subset).
- **What changed:** `@trait_module` before the module's first method; a batch keeps its model as the value itself, and the cast `compiled_for` at the batch call decides; the threaded batch functions are `@unbounded` (their task captures the model); Graphs' `GraphInterface{V}` joins `AbstractGraph{V}` as a family, with its own `directed` where Graphs' `is_directed` takes any receiver (open issue 150).
- **The workload:** `scripts/u_workload.sh <name> [runs]` (logs in `logs/unified/`; `NDW_TRACE=<file>` traces the compiles, `NDW_MARK=1` marks each step in the trace for `scripts/trace_by_step.jl`). `env_unified_r5` adds GraphMakie's port (`pkgs/GraphMakie-unified`, branch `unified` from `ports`, unchanged) over MakieCompat and TraitMakie (`../TraitMakie-unified`). Run as `scripts/r5_workload.sh` does, with `../julia-unified/julia --threads=1 --project=env_unified_r5 scripts/workload.jl` and `NDW_API=ports NDW_STACK=ports NDW_PASSES=first,again,params,changed,graphtype`.

| Date | Build | Result | Log |
|---|---|---|---|
| 2026-11-14 | `unified` 86deee2f98, TraitWorld baadf9f, TDE f8c6765, NetworkDynamics 6310040 (E-373, phase 4: `@unbounded` for `@open`; the cast `compiled_for` imported, since its name is bound) | the test subset as on 2026-11-08: massmatrix 6 pass; doctor 26 pass; diffusion 108 pass, 1 fail, 1 error, 24 broken; inhomogeneous 39 pass, 1 error, 12 broken; the check that no cast is without effect passes | `../experiments/unification/w104/logs/nd.log` |
| 2026-11-09 | `unified` 427760d9e9, TraitWorld c20f9f4, TDE 52a45b6, NetworkDynamics d8c9c49 (E-320: C-29, C-75) | the probe (`scripts/e313_probe.jl`): step d 224–273 ms, the first call 4.14 s; the test subset as before, and its check that no cast is without effect passes; the load prints no ambiguity warning (before: `_run_batch!`, `_kept_model`) | `logs/unified/e320-probe-w320.log`, `e320-ndtest-w320.log` |
| 2026-11-09 | `unified` 523214899f, TraitWorld 6b342e9, TDE fcee973, NetworkDynamics 7e8997d (E-314): the kernel types the batch's model by the trait | the workload, a warm-up and 2 runs (`scripts/u_workload.sh e314-typed 2`): the session 60.4–60.9 s, new equations 0.59–0.66 s, the steady state 228–257 ms; step d alone 229–281 ms (`scripts/e313_probe.jl`, three solves after the `again` pass); the digests equal E-310 (a)'s | `logs/unified/e314-typed-*.log`, `e314-probe-typed.log` |
| 2026-11-09 | `unified` b61e326170, TraitWorld 6b342e9, NetworkDynamics c0d115f (E-314) | the batch call's cast at an untyped parameter: step d 422–457 ms, the workload's steady state 436 ms, new equations 0.80 s | `logs/unified/e314-w314-*.log`, `e314-probe-w314.log` |
| 2026-11-09 | `unified` 9a902e14ed (`bisect-noc74`), NetworkDynamics c0d115f (E-313) | the steady state 473 ms, new equations 0.88 s; step d profiled | `logs/unified/e313-*.log` |
| 2026-11-08 | `unified` dde5f9f5dc, NetworkDynamics c0d115f: a batch keeps its model with the trait's default, open issue 161 (a) (E-310 (b)) | new equations 0.79–0.82 s, the steady state 451–475 ms | `logs/unified/e310b-*.log` |
| 2026-11-08 | `unified` 24c8d4db60, NetworkDynamics fc25b89 with the model stored as `Dynamic{…}` by hand (E-310 (a)) | new equations 0.59–0.62 s, the steady state 182–213 ms | `logs/unified/e310a-*.log` |
| 2026-11-08 | `unified` 24c8d4db60, TraitWorld 24a5fcd, TDE fcee973, NetworkDynamics fc25b89 (E-309) | the workload, a warm-up and 2 runs (`scripts/u_workload.sh e309 2`): the session 71.0–72.1 s, new equations (`changed` b–e) 6.6–6.7 s, the steady state 189–230 ms; the digests equal the earlier build's. A session traced with `NDW_MARK=1` and split by step (`scripts/trace_by_step.jl`): the network's type names the user's functions through the batches' models | `logs/unified/e309-*.log`, `e309-trace-by-step.txt` |
| 2026-11-08 | the same, TraitMakie 499af5d (MakieCompat), GraphMakie `unified` | **the workload** (passes first, again, params, changed, graphtype): its 32 digests equal the earlier build's PT run (`logs/r7/run-PT-1.log`: 0 differences), and differ from upstream's where that run's do (13 exact differences each); one run, 100.4 s in all (loads of Graphs and NetworkDynamics 13.0 s; step c of the first pass 13.1 s), against the earlier build's session of 31 s (E-250): not a registered measurement, a pointer for W-121 | `logs/unified/workload-PT-1.log` |
| 2026-11-08 | `unified` 350c5b1c59, TraitWorld d897223, TDE 41837ed, NetworkDynamics fc25b89, Graphs dbcb7c70 | massmatrix 6 pass; doctor 26 pass; diffusion 108 pass, 1 fail (an allocation), 1 error (a mass matrix refused), 24 broken; inhomogeneous 39 pass, 1 error (a mass matrix refused), 12 broken: as on the earlier build (`logs/r7/ndtest-1.log`) | `logs/unified/ndtest-2.log` |

## Layout

- `pkgs/`: the clones, each its own git repository (ignored here). Each is on branch `trait-port`, started at the resolved release and tagged `upstream`; `git -C pkgs/<repo> diff upstream` is the port. `scripts/clone.sh` makes them and writes `VERSIONS.tsv` (name, version, repository, subdirectory, commit, tree-hash check).
- `pkgs-bundles/`: how the clones' work reaches another machine. `make.sh` writes the bundles and `MANIFEST.tsv` from `pkgs/` (rerun it and commit after changing a clone); `restore.sh` recreates `pkgs/`, with branches, stage tags and worktrees.
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
- From 2026-10-29 (R6, E-247): the pass `usertype` (`NDW_PASSES` names it; setting PT only): steps a–g with a user's own types `Swing` and `Line` (`scripts/workload_types.jl`, in `NDW`), implementing `VertexDynamics` and `EdgeDynamics` and passed by `VertexModel(dynamics = x)`, `EdgeModel(dynamics = x)`; a step that throws prints `D usertype <step> error=<type>`. `scripts/r6_check.jl` (the records, the adaptors, the execution styles, linearization, initialization, the refusals; run by `r5_run.sh`), `scripts/r6_pc.sh <name>` (precompiles PT; `NDW_STRICT=1`). `r5_run.sh` and `r5_workload.sh` take `NDW_LOGDIR` and `NDW_JLNAME` (R6: `logs/r6`, `ndr6`, `ndr6s` strict).
- From 2026-10-29 (W-96, E-248): `env_w96`: `env_r5` with TDE's packages from its branch `w96` (the worktree `../TraitDifferentialEquations-w96`), over `depot-ports` (`depot-ports-strict`) below the slot's own depot `w96` (`w96s`). `scripts/w96_pc.sh <name>` precompiles it; `scripts/r5_workload.sh` runs it with `NDW_ENV=env_w96 NDW_TDE=TraitDifferentialEquations-w96 NDW_LOGDIR=logs/w96 NDW_JLNAME=w96`; `scripts/w96_deltas.py <U′ log> <PT log> <R5's PT log>`: the largest difference from U′ per field of steps d and e.
- From 2026-10-29 (R7, E-249, E-250): `scripts/r7_pc.sh <PT|PTs|U|M|S>` precompiles a setting into its slot depot (`ndr7`, `ndr7s`, `ndr7u`, `ndr7m`, `ndr7S`; on 2026-10-29 under `/tmp/claude-1000/depots`, which `r7_time.sh` names). The finish round: `NDW_PASSES=first,again,params,changed,graphtype,usertype NDW_LOGDIR=logs/r7 scripts/r5_workload.sh <name> <PT|UP> [runs]` (`NDW_JLNAME=ndr7`, `ndr7s` with `NDW_STRICT=1`, `ndr7u` for U′), `scripts/r7_compare.sh` (writes `logs/r7/compare-run.txt`), `scripts/r7_census.jl` (pirates per package after the `first` and `usertype` passes; `R1_STRICT=1 … scripts/r5_run.sh census-1 scripts/r7_census.jl`), the test subset by `scripts/r5_run.sh ndtest-1 scripts/r3_nd_tests.jl`. The measured sessions: `scripts/r7_time.sh <PT|UP|U|S|M> [runs]` (fresh sessions under `jl --exclusive`, the session timed by `/usr/bin/time`, run 0 a warm-up), `scripts/r7_summary.py logs/r7/time/*.log`. `scripts/r7_probe_d.jl` splits step d's steady state (`NDW_STACK=ports` for PT).
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

### 2026-10-29: a user's own component types on the ports (E-247, step R6, part 3b)

julia-1.13 bfca89decc, TraitWorld main f270262, TDE `w34` 282edb3, TraitMakie c0d5c36, NetworkDynamics `ports` dfc6663, GraphMakie `ports` 498be7c, ndport d987e61; setting PT (`env_r5`); product setting; one thread; `logs/r6/`. `run-PT-1`, `run2-PT-1` and `strict-PT-1` ran on dfc6663's sources before the commit (headers `ddf7259*`); `run3-PT-1`, `check-3` and `ndtest-1` on the commit. Not a measurement: the times are printed, not compared (load 2–4.5).

Part 3b as built ([the step-3 plan](../writeup/plans/2026-10-22-ndport-step3.md) §3.3): `VertexModel(dynamics = x)` and `EdgeModel(dynamics = x)` take a value whose type implements `VertexDynamics` or `EdgeDynamics`. The record's `f` and `g` are adaptors at upstream's calling convention (`VertexF`, `VertexG{X, FF}`, `EdgeF`, `EdgeG{X, FF}`), which reach `x` through bounded functions; `ff = fftype(x)`; no `f` for a static component; `pdim` and `extdim` read through the trait and checked against `psym` and `extin`. The erased batch keeps `x` itself.

| Check | Result |
|---|---|
| PT runs with `usertype`: all six passes, every step | 39 digests and 60 plot lines per run (`run-PT-1`, `run2-PT-1`, `run3-PT-1`, `strict-PT-1`) |
| `usertype` against `first`, each run | **exactly equal** (7 digests, 10 plot lines, textually) |
| the network's type (`N` lines) | **the same** for `Swing`/`Line` as for `swing!`/`swing2!` in each session; `graphtype`'s differs (its graph type) |
| the runs against each other; strict mode on against off | **exactly equal** (39 digests, 60 plot lines); strict mode refuses nothing, no warnings |
| the passes of E-246 against its `run-PT-1` (TraitWorld 4579236) | **exactly equal** (32 digests, 50 plot lines) |
| the records (`check-3`) | every field equal to the function models' but `f` and `g` |
| the adaptors at upstream's convention (`compfg`), the doctor | bitwise equal to `swing!` and `AntiSymmetric(line!)`'s on the same inputs; the doctor runs without warnings |
| the right-hand side, sequential, threaded, Polyester | bitwise equal to the function models'; the same network type in the erased styles (Polyester's typed batches carry the functions' types) |
| `linearize_component` on the vertex with an input named | A, B, C, D bitwise equal |
| `initialize_component` | stops at the same R1 stand-in for both (`LinearSolve.QRFactorization`): a gap of the ports, not of 3b |
| refusals | a type implementing the other kind, a plain `Float64`, a `pdim` that does not match `psym`, `dynamics` with `f`: each an `ArgumentError` naming the cause |
| the test subset (`ndtest-1`) | as E-245's: massmatrix 6, doctor 26, diffusion 108 (`:111` fails, a DAE refused), inhomogeneous 39 (a DAE refused) |
| reported, not compared | `usertype` a–e 2.1–2.2 s (a 0.6 s, c 0.45 s, d 1.0 s) against `changed`'s 1.3–1.4 s: step a compiles the records' path for `dynamics` (0.59–0.64 s) |

### 2026-10-29: Tsit5's own interpolant and the states saved at events (E-248, W-96)

julia-1.13 bfca89decc, TraitWorld main f270262, TDE `w96` 5862baa (a worktree; from `w34` 282edb3), TraitMakie c0d5c36, NetworkDynamics `ports` dfc6663, GraphMakie `ports` 498be7c; setting PT (`env_w96`); product setting; one thread; `logs/w96/`. PT 2 runs (`run-PT-1`, `-2`), 1 with strict mode on (`strict-PT-1`); U′ and the tight runs are R5's (`logs/r5/run-UP-1`, `tight-UP-1`). Not a measurement. TDE's side: `../experiments/w34-sciml/README.md`, section E-248.

TDE's Tsit5 reads between its steps by its own interpolant (the free fourth-order one, OrdinaryDiffEqTsit5's `Tsit5Interp`) for dense output, `saveat` and event location, and the solution saves the state before and after each event (SciML's `save_positions` defaults).

| Check | Result |
|---|---|
| PT runs: all passes, every step; against each other; strict mode on against off | 32 digests and 50 plot lines per run; **exactly equal**; strict mode refuses nothing |
| `graphtype` against `first` (PT) | **exactly equal** (7 digests, 10 plot lines) |
| the network's type (`N` lines) | the same for `first`, `again`, `changed`; `graphtype`'s differs (its graph type) |
| PT against U′, by tolerance (`compare-run.txt`; passes `first`, `again`, `params`, `changed`) | **0 failures** (R5: 11, all step e's flows); the exact differences as R5's: the solutions' and the fixed point's hashes, the PNG's size |
| the largest difference from U′ (`deltas-run.txt`) | step e's flows `P2`, `P3`, `Pend` 9.5e-9–6.6e-8 (R5: 1.3e-6–7.7e-6); `ω2` 2.0e-8–2.3e-8 (R5: 2.0e-6–4.0e-6); the trips' times 2.6e-8 (R5: 4.1e-6–4.6e-6), the same lines in the same order; Rodas5's values unchanged |
| the saved states (`nsteps`, `rnsteps`) | **38** in `first` and `again`, 36 in `changed`, as U′ (R5: 7) |
| the graph plots from the simulation, PT against U′ | **within tolerance** (40 plot lines; no colour differs now, R5: by 1 of 255) |
| the tie-break (`nearer-run.txt`): distance from the tight U′ run | PT 1e-9–1.2e-7, U′ 3e-9–9.7e-8 (`ωsum` and `λmax` 1e-14 both); U′ nearer on most of steps d and e, PT on Rodas5's `ω2r`, `ωend` and `params`' flows (R5: PT up to 7.6e-6) |

### 2026-10-29: the finish round on the ports (E-249, step R7)

julia-1.13 bfca89decc, TraitWorld main 4961de8, TDE `w34` e9e07ed (W-96 merged), TraitMakie c0d5c36, NetworkDynamics `ports` dfc6663, GraphMakie `ports` 498be7c, ndport a1b82aa (the runs' scripts); setting PT (`env_r5`); product setting; one thread; slots of 4 cores, the machine shared (load 1–11); `logs/r7/`. Not a measurement. The finish line: [the reactivation plan](../writeup/plans/2026-10-29-ndport-reactivated.md) §5.

| Criterion | Result |
|---|---|
| tier S in PT, the six passes, fresh sessions, strict mode off (`run-PT-1`, `-2`) and on (`strict-PT-1`, `-2`) | every step runs: 39 digests and 60 plot lines per run |
| PT against U′ (`run-UP-1`; states `rtol = 1e-5`, `atol = 1e-7`, trips as groups; `compare-run.txt`) | **0 failures** in 25 digests and 40 plot lines; the 13 exact differences E-248's (the solutions' and the fixed point's hashes, the PNG's size) |
| U′ today against R5's U′ (`logs/r5/run-UP-1`) | exactly equal (27 digests, 40 plot lines) |
| PT's runs against each other; strict mode on against off | **exactly equal** (39 digests, 60 plot lines) |
| `graphtype` and `usertype` against `first`, each of the 4 runs | **exactly equal** (7 digests, 10 plot lines each) |
| PT against E-248's PT run (`logs/w96/run-PT-1`, its 5 passes) | exactly equal (32 digests, 50 plot lines) |
| the network's type (`N` lines) | **one type** in each session for `swing!`, `swing2!` and `Swing`/`Line`; `graphtype`'s its own (its graph type) |
| strict mode | refuses nothing; no warnings |
| the census (`census-1.log`, strict mode on, after the `first` pass and `usertype`'s a–e) | NetworkDynamics 10 pirates by the letter: 9 family registry methods (`_family_registry`, lowering L-38) and 1 member record (`_member_record` for `GraphInterface` on `SimpleGraph{Int64}`, lowering L-45), all TraitWorld's generated methods. The ports' other packages the same kinds only (ODECore 26, TraitNonlinearSolve 9, TraitRodas 4, TraitDifferentialEquations 12, TraitArrayTools, TraitMakie, MakieCompat, Graphs) |
| reads of TraitWorld's internals (a grep for `TraitWorld._`, `TraitWorld.CompiledFor`, `WithDynamic`, imports of `_` names) | **none** in NetworkDynamics `ports`, TDE `w34`, GraphMakie `ports`; the names used are exported (`Kept`, `compiled_for`, `conforms`, `@trait_module`, `@workload`, `Callable`, `Compiled`, `Dynamic`, `ImplementError`, `solve!`) |
| NetworkDynamics' test subset (`ndtest-1.log`) | massmatrix 6 pass; doctor 26 pass; diffusion 108 pass, 1 fail, 1 error, 24 broken; inhomogeneous 39 pass, 1 error, 12 broken. Each traced below |

The test subset's failures, by gap:

| Test | Gap | Recorded |
|---|---|---|
| diffusion `:111` fails | an allocation assertion: a crossing into a family member allocates (as since E-152) | pushback P4-1; the traits plan's PB-4 |
| diffusion, inhomogeneous: one error each, the file stops | a DAE network (a mass matrix other than the identity): TDE refuses it, having no solver that takes mass matrices | the plan §4 S10; pushback W34-9; open issue 119 (the refusal) |
| `Rodas4` in the tests | read as `Rodas5` (a stand-in, `R1T STANDIN`): TDE has no `Rodas4` | [the census](../writeup/plans/2026-10-29-ndport-r1-census.md) item 17 |

### 2026-10-29: the measured sessions (E-250, step R7)

The builds of E-249; one at a time under `experiments/tools/jl --exclusive` (all 16 cores, nice 19, one Julia thread), offline, never precompiling; P1's load order; strict mode off; the passes `first`, `again`, `params`, `changed`; a warm-up and 2 runs per setting (the range of the 2); load 1.0–2.4; `logs/r7/time/` (`summary.md`, `compare.txt`). Every timed session's digests exactly equal its reference: PT and U′ E-249's runs, U, S and M E-151's U. PT and U′ run the ported workload (`NDW_API=ports`: Rodas5, `saveat`); U, S and M P1's (Rodas5P). NetworkDynamics' workload has no Python reference. Interop where NetworkDynamics' bounded functions call the user's plain component functions; idiomatic trait code from the batches down into TDE's core.

| Setting | session | loads | first a–e | first f | first g | changed b–e (compiling) | again d (steady state) | again a–g |
|---|---|---|---|---|---|---|---|---|
| PT (the ports) | **31.0–31.5 s** | 2.75–2.83 s | 14.5–14.7 s | 2.9–3.0 s | 1.2–1.3 s | **1.10–1.11 s** (0.32–0.33) | **776–780 ms** | 1,234–1,242 ms |
| U′ (upstream, ported workload) | 79.3–80.7 s | 5.59–5.67 s | 23.7–24.1 s | 15.3–15.5 s | 4.9 s | 15.65–16.00 s (15.58–15.93) | 22.3–22.6 ms | 232–252 ms |
| U (upstream, patched build) | 72.8–73.9 s | 5.49–5.79 s | 23.6–24.1 s | 15.0–15.1 s | 2.6–2.8 s | 15.25–15.29 s (15.18–15.23) | 20.1–20.5 ms | 204–228 ms |
| S (stock 1.13.2) | 70.8–71.3 s | 5.58–5.70 s | 22.6–22.8 s | 14.4 s | 2.5 s | 15.20–15.63 s (15.14–15.57) | 19.5–20.1 ms | 223–224 ms |
| M (the control) | 58.9–59.5 s | 5.55–5.67 s | 25.4–26.0 s | 14.7–14.9 s | 2.4–2.6 s | 0.47 s (0.43) | 29.1–30.8 ms | 245–260 ms |

- The session in PT is 2.5 times shorter than U′'s; the first plot 5 times (TraitMakie's drawing against CairoMakie's); new equations 14 times (the network's type stays; TDE's code is not compiled again).
- **The steady state is 35 times U′'s** (step d, a Tsit5 and a Rodas5 solve with the cascade). `probe-d-PT.log`, `probe-d-UP.log` (`scripts/r7_probe_d.jl`, one session each in a slot, the minimum of 3): without callbacks PT's solves are U′'s (Tsit5 0.06 against 0.02 ms, Rodas5 0.43 against 0.55 ms); with the workload's 40 continuous component callbacks Tsit5 takes 377 ms and allocates 200 MB in 159 steps (U′: 2.3 ms, 0.17 MB, 162 steps), Rodas5 469 ms and 241 MB in 196 steps (U′: 20.7 ms, 1.4 MB, 164 steps). The cost is in the events: one TDE `EventCallback` per component callback (R1's form), about 1.25 MB per step. Reported, not optimised.

