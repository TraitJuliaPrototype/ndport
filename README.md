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

The workload and its harness are part P1 of the meta plan (`../writeup/plans/2026-10-21-ndport-workload.md`).

## Results

None yet.
