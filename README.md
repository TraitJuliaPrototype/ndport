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
- The settings: U (`env_upstream`, patched build), P0 (`env_port`, TraitWorld loaded, product setting), A0 (`env_port` under `all`, depot `depot-facts/`), S (stock 1.13.2, depot `depot-stock/`).

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
