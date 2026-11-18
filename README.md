# NetworkDynamics with traits

NetworkDynamics.jl ported to traits, over the ODE library TraitDifferentialEquations, with Graphs and GraphMakie ported beside it, and a workload that runs a user's session against the unmodified upstream packages. It is the large-scale test of the design: a real package of the SciML ecosystem, moved a function at a time.

## The port

The ported packages are clones under `pkgs/`, each its own git repository (ignored here), on branch `unified`:
- **`pkgs/NetworkDynamics-unified`:** a trait module (`@trait_module`). The component dynamics are traits (`src/component_dynamics.jl`):
  - `@trait ComponentDynamics`: `hasf`, `fftype`, `pdim`, `extdim`;
  - `@trait VertexDynamics <: ComponentDynamics`: `vertexf!`, `vertexg!`;
  - `@trait EdgeDynamics <: ComponentDynamics`: `edgef!`, `edgeg!`.
  NetworkDynamics' own typed component is a member; a user's own types join by a membership. The solver is TraitDifferentialEquations, in the place of upstream SciML.
- **`pkgs/Graphs-unified`:** Graphs stays plain code, with `@trait GraphInterface{V}`, of which every `AbstractGraph{V}` is a member by a family (`src/interface_trait.jl`).
- **`pkgs/GraphMakie-unified`:** GraphMakie over TraitMakie, with `using Makie` read as MakieCompat (`../TraitMakie/compat/MakieCompat`).
- `git -C pkgs/<repo> diff upstream` is the port. `pkgs-bundles/` carries the clones' branches to another machine: `make.sh` writes the bundles, `restore.sh` recreates `pkgs/`.

## How it uses the design

- `ComponentDynamics`, `VertexDynamics` and `EdgeDynamics` erase by default (`@default_dynamic`): a batch's model is boxed where it is passed plainly, so the network's code is compiled once for every component type.
- The core loop calls each batch's kernel with the wrapper, `compiled_for(batch.model)` (`src/coreloop.jl`), so the kernel is compiled per model type. The name is bound from `TraitWorld.ByType` (`src/NetworkDynamics.jl`).
- Not yet on the design's one way to erase: the trait module writes the module option `first_seen = false` (`src/NetworkDynamics.jl`). This is recorded as deviation T-127 of the traits reference.

## Running

From the workspace root, `source env.sh` first; then, in `ndport/`:

- **The test subset** of NetworkDynamics' suite: `../julia-next/julia -t 2 --project=env_unified scripts/r3_nd_tests.jl`.
- **The workload** (`scripts/workload.jl`, its steps in `scripts/workload_steps.jl`), with GraphMakie's plots: `NDW_API=ports NDW_STACK=ports NDW_PASSES=first,again,params,changed,graphtype ../julia-next/julia --threads=1 --project=env_unified_r5 scripts/workload.jl`. Each step prints its time (`T` lines) and a digest of its results (`D` lines).
- `scripts/u_workload.sh <name> [runs]` runs the workload in fresh sessions with a header and logs in `logs/unified/`; its Julia is fixed to the tree `julia-unified/`. `NDW_TRACE=<file>` traces the compiles; `NDW_MARK=1` marks each step, for `scripts/trace_by_step.jl`. `scripts/e313_probe.jl` splits step d.
- `scripts/compare_digests.py <ref.log> <log> [--exact]` compares two runs' digests. The baseline is the same workload over upstream's packages, `env_upstream/`.
- Precompile an environment first: `../julia-next/julia --project=env_unified_r5 -e 'using Pkg; Pkg.precompile()'`.
- The other environments (`env_p*`, `env_r*`, `env_merged`, `env_w96`, …) and scripts belong to the runs recorded in `HISTORY.md`.

## Results

The current numbers, each against plain Julia or Python, are in the design repository's `writeup/design/evidence.md`. The suites' last results are in its `writeup/state.md` §3. Every run's log is committed in `logs/`.

| Date | Build | Result | Log |
|---|---|---|---|
| 2026-11-15 | `unified` 7b374f39ce, TraitWorld 6f86b4e, TDE 813808a, NetworkDynamics 946c0dc (W-151, stage 1: the batch's model boxed by the trait's default with `@erasing`, the kernel called with `compiled_for` of it, the wrapper; `first_seen = false`), against the tag `prototype-2026-11` the same day (E-403) | the workload, a warm-up and 2 runs each: the session 43.5 s (43.3–43.7), the steady state 181.3–181.4 ms (199.1–202.5), new equations 510.7–516.0 ms (513.2–516.8), the digests equal; the test subset as on 2026-11-14 | `../experiments/implementation/w151/nd/logs/e403c-*.log`, `../experiments/implementation/w151/logs/e406-nd-tests.log` |
| 2026-11-14 | `unified` 86deee2f98, TraitWorld baadf9f, TDE f8c6765, NetworkDynamics 6310040 (E-373, phase 4: `@unbounded` for `@open`; the cast `compiled_for` imported, since its name is bound) | the test subset as on 2026-11-08: massmatrix 6 pass; doctor 26 pass; diffusion 108 pass, 1 fail, 1 error, 24 broken; inhomogeneous 39 pass, 1 error, 12 broken; the check that no cast is without effect passes | `../experiments/implementation/w104/logs/nd.log` |
| 2026-11-09 | `unified` 427760d9e9, TraitWorld c20f9f4, TDE 52a45b6, NetworkDynamics d8c9c49 (E-320: C-29, C-75) | the probe (`scripts/e313_probe.jl`): step d 224–273 ms, the first call 4.14 s; the test subset as before, and its check that no cast is without effect passes; the load prints no ambiguity warning (before: `_run_batch!`, `_kept_model`) | `logs/unified/e320-probe-w320.log`, `e320-ndtest-w320.log` |
| 2026-11-09 | `unified` 523214899f, TraitWorld 6b342e9, TDE fcee973, NetworkDynamics 7e8997d (E-314): the kernel types the batch's model by the trait | the workload, a warm-up and 2 runs (`scripts/u_workload.sh e314-typed 2`): the session 60.4–60.9 s, new equations 0.59–0.66 s, the steady state 228–257 ms; step d alone 229–281 ms (`scripts/e313_probe.jl`, three solves after the `again` pass); the digests equal E-310 (a)'s | `logs/unified/e314-typed-*.log`, `e314-probe-typed.log` |
| 2026-11-09 | `unified` b61e326170, TraitWorld 6b342e9, NetworkDynamics c0d115f (E-314) | the batch call's cast at an untyped parameter: step d 422–457 ms, the workload's steady state 436 ms, new equations 0.80 s | `logs/unified/e314-w314-*.log`, `e314-probe-w314.log` |
| 2026-11-09 | `unified` 9a902e14ed (`bisect-noc74`), NetworkDynamics c0d115f (E-313) | the steady state 473 ms, new equations 0.88 s; step d profiled | `logs/unified/e313-*.log` |
| 2026-11-08 | `unified` dde5f9f5dc, NetworkDynamics c0d115f: a batch keeps its model with the trait's default, open issue 161 (a) (E-310 (b)) | new equations 0.79–0.82 s, the steady state 451–475 ms | `logs/unified/e310b-*.log` |
| 2026-11-08 | `unified` 24c8d4db60, NetworkDynamics fc25b89 with the model stored as `Dynamic{…}` by hand (E-310 (a)) | new equations 0.59–0.62 s, the steady state 182–213 ms | `logs/unified/e310a-*.log` |
| 2026-11-08 | `unified` 24c8d4db60, TraitWorld 24a5fcd, TDE fcee973, NetworkDynamics fc25b89 (E-309) | the workload, a warm-up and 2 runs (`scripts/u_workload.sh e309 2`): the session 71.0–72.1 s, new equations (`changed` b–e) 6.6–6.7 s, the steady state 189–230 ms; the digests equal the earlier build's. A session traced with `NDW_MARK=1` and split by step (`scripts/trace_by_step.jl`): the network's type names the user's functions through the batches' models | `logs/unified/e309-*.log`, `e309-trace-by-step.txt` |
| 2026-11-08 | the same, TraitMakie 499af5d (MakieCompat), GraphMakie `unified` | **the workload** (passes first, again, params, changed, graphtype): its 32 digests equal the earlier build's PT run (`logs/r7/run-PT-1.log`: 0 differences), and differ from upstream's where that run's do (13 exact differences each); one run, 100.4 s in all (loads of Graphs and NetworkDynamics 13.0 s; step c of the first pass 13.1 s), against the earlier build's session of 31 s (E-250): not a registered measurement, a pointer for W-121 | `logs/unified/workload-PT-1.log` |
| 2026-11-08 | `unified` 350c5b1c59, TraitWorld d897223, TDE 41837ed, NetworkDynamics fc25b89, Graphs dbcb7c70 | massmatrix 6 pass; doctor 26 pass; diffusion 108 pass, 1 fail (an allocation), 1 error (a mass matrix refused), 24 broken; inhomogeneous 39 pass, 1 error (a mass matrix refused), 12 broken: as on the earlier build (`logs/r7/ndtest-1.log`) | `logs/unified/ndtest-2.log` |

## The design

- The design: the design repository's `writeup/reference/` (traits, facts, compiler, lowering).
- The lessons of the ports: `writeup/intro/porting.md`.
