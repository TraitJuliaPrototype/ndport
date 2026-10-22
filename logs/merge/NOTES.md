# E-165: the two tracks merged (2026-10-22)

The inside-out plan §4 (`writeup/plans/2026-10-21-ndport-inside-out.md`), its checks §3.1. One agent, one pass.

**Build and setting.** julia-1.13 build 2943086604 (libjulia-internal built 2026-10-21 20:43; the checkout's head is
fa4e7f5798, not built; the binary reports `6d480d0753*`); TraitWorld c655dde in the worktree `TraitWorld-port`
(never edited); product setting; P1's load order; one run per check (confirming runs named). The machine shared:
load before each run 1.2–3.3, except IP-1 (4.96, rerun). From 13:34 on (`strict1-pair`, `p6-pin-confirm`,
`family-registry.log`), every job ran on two cores, idle I/O class, one precompile task (`cpus=0-1(taskset)` in the
header), at the coordinator's request; the runs before it did not.

## The trees

| Tree | Branch `port` from | Commit |
|---|---|---|
| `pkgs/NetworkDynamics-p4` | tag `p4-s2` (new: P4 step 2 with G3) | 324bcb7 |
| `pkgs/Graphs-p4` | tag `p4-s2` (new: E-154's G1) | 54632125 |
| `pkgs/SymbolicIndexingInterface-p6`, `RecursiveArrayTools-p6` | `p6-s1` | dcc3b12, f29eae0 |
| `pkgs/SciMLBase-p6` | `p6-s2` | b50f4684 |
| `pkgs/NonlinearSolveBase-p6`, `BracketingNonlinearSolve-p6`, `SciMLJacobianOperators-p6` | `p6-s3` | 293712e, 7433e0b, 3840f8a |
| `pkgs/NonlinearSolve-p6`, `…FirstOrder-p6`, `…QuasiNewton-p6`, `…SpectralMethods-p6`, `SimpleNonlinearSolve-p6` | `p6-s4` | 697c987, 30c42a6, afc14ed, 6ef8fa9, f95ae0e |
| `pkgs/OrdinaryDiffEq-p6` (DiffEqBase, OrdinaryDiffEqCore, Tsit5), `DiffEqCallbacks-p6` | `p6-s6` | 1dcb9dd04, 0b6042d |
| `pkgs/OrdinaryDiffEq-p6-ros` (Rosenbrock) | `p6-s7-ros`, branch **`port-ros`** (git refuses one branch in two worktrees of a repository) | effcc0f08 |
| GraphMakie, Makie, NetworkLayout, Observables | the main clones at `upstream` (no `GraphMakie-p4` exists: E-154 deferred G5–G6) | as `VERSIONS.tsv` |
| Static | `pkgs/Static.jl`, branch `trait-port` | c34adbb |

The tracks' branches (`trait-port`, `trait-port-p4`, `p6-inside-out`, `p6-inside-out-ros`) stay at these commits as
records. The worktrees are now on `port`; `env_p4`, `env_p6` read the same files.

## The environments

- `env_p4_pin`, `env_ndtest_p4pin`, `env_p6_pin`: copies of `env_p4`, `env_ndtest_p4`, `env_p6` whose TraitWorld path
  is `../../TraitWorld-port`; depots `depot-p4pin` (shared by the two P4 environments), `depot-p6pin`, fresh.
- `env_merged`: `env_p6`'s project with NetworkDynamics at `pkgs/NetworkDynamics-p4`, Graphs at `pkgs/Graphs-p4`,
  TraitWorld at `../../TraitWorld-port`; the manifest edited the same way (Graphs gains TraitWorld), then
  `Pkg.resolve()` offline (only the project hash changed). Depot `depot-merged`, fresh.
- Harness settings: `P4P` (`env_p4_pin`), `IP` (`env_p6_pin`), `M` (`env_merged`) in `scripts/run_workload.sh`; its
  header names the TraitWorld tree it reads.

## The tracks' last steps on the pinned commit

- **P4** (step 2 with G3; `p4-pin/P4P-{1,2}.log`, strict off): digests 0 exact differences (two runs). Again c / d /
  e **5.0–5.1 / 34.4–35.0 / 0.9 ms**, f 42.0–47.5, g 167.8–169.4. First a–e 39.1 s; session 70.2 s; changed b–e
  0.54–0.63 s. Loads ND 3.06–3.12 s. This is the steady-state reference (P4 after open issue 48, 3bebf13:
  d 33.1–41.2 ms). G3's checks: `../p4g/NOTES.md`, "G3 again".
- **P6** (S7; `precompile-p6-pin.log`, `p6-pin/IP-1.log`, `p6-pin-confirm/IP-1.log`, strict on): 450 packages,
  370 s; no `OwnershipError`, no `PirateError` at image load; the extension warnings as at S7 (P6-2). Digests 0
  exact differences. Again c / d / e 3.7 / 16.8 / 0.9 ms (the confirming run; IP-1 ran at load 5.0: 5.7 / 18.4 /
  1.1); S7 on 3bebf13 3.6 / 16.2 / 0.7: within 10 % + 5 ms. First a–e 30.2–31.6 s (S7 28.9). The one refusal as at
  S7: OffsetArrays' `reshape` at the plotting load.

## The merge's checks

| Check | Log | Result |
|---|---|---|
| **P** | `precompile-merged.log` | 450 packages in 368 s (strict on); no `OwnershipError`, no `PirateError` at image load; `using` 8.4 s; the extension warnings identical to P6's pinned build (DiffEqBaseForwardDiffExt 35, PreallocationToolsForwardDiffExt 19, SciMLBaseForwardDiffExt 12, NonlinearSolveBaseSparseMatrixColoringsExt 3) |
| **R**, strict off | `R-strict0/M-1.log` | 25 digests, **0 exact differences** against U (`logs/p1/U-1.log`) |
| **R**, strict on | `R-strict1/M-1.log`, `R-strict1-confirm/M-1.log`, `strict1-pair/M-1.log` | 0 exact differences (three runs) |
| **S** | the same | `STRICT on`; **one refusal, OffsetArrays' `reshape`** at the plotting load, at the same call as P6's (`reshape(::Vector{Dict{Symbol,Any}}, ::Tuple{Vararg{OneTo{Int64}}})`, Base's own code), also refused in P4's environment with strict on (`strict1-pair/P4P-1.log`). **No refusal in P4's code or in SciML's.** The five extension warnings as P6's (P6-2). GraphMakie's two pirates (G13): no refusal or warning names GraphMakie (it is plain, and no `GraphMakie-p4` trait submodule exists) |
| **C** | `CH/M-1.log` | 18 wrapped packages (P6's 16, NetworkDynamics, TraitWorld); pirates in wrapped packages: **NetworkDynamics 1**, every other 0; joint as at S7 (BracketingNonlinearSolve 4, DiffEqBase 28, NonlinearSolve 10, NonlinearSolveBase 12, NonlinearSolveFirstOrder 5, OrdinaryDiffEqCore 3). The one: `TraitWorld._family_registry(::Val{gensym}, ::Val{:NetworkDynamics})`, generated by TraitWorld's family `@implement` (`TraitWorld-port/src/implement.jl:796`); Graphs (plain) has the same one. `family-registry.log`: `owned_method` false for both, true for TraitWorld.BaseTraits' own. A census finding about TraitWorld's generated code, not a pirate of the port; strict mode refuses nothing there (the signature is unique) |
| **H** | `CH/M-1.log` (`scripts/p6_profile_summary.py`) | steps c–e again: 75,847 dynamic calls in the top 40, 75,842 from trait code, **5 from plain code** (S7: 40,259; 5). New against S7: **TraitWorld 35,290, all `checked_call`** (`checks.jl:313`), from `tw_untyped_run_vertex_batch!` 22,299 and `tw_untyped_run_edge_batch!` 12,991: P4's crossings into the batch functions (P4-1, open issue 48's path). The rest as at S7 (Base 25,356, ForwardDiff and PreallocationToolsForwardDiffExt 5,824 each, NetworkDynamics 2,020, DiffEqBase 906, SymbolicIndexingInterface 420) |
| **F** | the R logs | first a–e **31.1 s** strict off, 31.0–32.7 s strict on (c 14.3–14.7, d 12.0–13.3 s). P4 pinned 39.1 s, P6 pinned 30.2–31.6 s, U 21.5 s (E-151). Changed b–e **0.56 s** strict off, 0.63 s strict on (P6 pinned 15.7 s, P4 pinned 0.54–0.63 s) |
| **T** | the R logs | again c / d / e: strict off **5.2 / 34.7 / 1.0 ms**; strict on 5.3 / 37.8 / 1.2, 5.2 / 36.6 / 1.3, 5.1 / 35.9 / 1.0 (the last on two cores). Against P4's reference 5.0–5.1 / 34.4–35.0 / 0.9: strict off within its spread; strict on 0.9–2.8 ms above it, within 10 % + 5 ms. In the same conditions (two cores, strict on) P4 alone gives d 35.1 against the merge's 35.9 (`strict1-pair/`): the strict-on excess is run-to-run spread and strict mode, not P6's wrap |
| **L** | the R logs | strict off: TraitWorld 0.11, Graphs+NetworkDynamics **2.94**, solvers 0.42, plotting 2.62 s; strict on: 0.11–0.12, **7.88–8.13**, 0.46–0.53, 6.46–6.59 s (P6 S7: 8.19 s; P4 pinned 3.06–3.12 s strict off, 5.65 s strict on on two cores) |

Sessions: 65.9 s strict off (the lowest of any setting so far: U 69.9–70.7, P4 pinned 70.2), 75.2–78.6 s strict on.

## E-165's criteria

1. **Results equal to upstream's:** yes, every merged log (four) 0 exact differences.
2. **A refusal under strict mode in P4's code:** none. The only refusal is OffsetArrays' `reshape` in Base's own code,
   present since P6's I0 and in P4's environment alike. The census counts one "pirate" in NetworkDynamics: TraitWorld's
   own family registry method (above; a candidate deviation row, not the port's).
3. **The merged steady state worse than P4's reference beyond its spread:** strict off no (d 34.7 in 34.4–35.0); strict
   on d 35.9–37.8, up to 2.8 ms above the spread, within 10 % + 5 ms, and equal to P4's own strict-on run in the same
   conditions (35.1 against 35.9). Not a cost of P6's wrap. The merged steady state is P4's (d 34–38 ms), not P6's
   (16.8 ms): P4's crossings per right-hand side (P4-1) are untouched by the wrap.
4. **A TraitWorld failure:** none that stops a check. The family-registry ownership finding is reported (candidate
   row). Known deviations met: none newly hit.

## What the merge shows

- Both effects in one session: P4's network type independent of the equations (changed b–e 0.56 s, against 15.7 s
  with P6's core alone) and P6's facts code in SciML's images (first a–e 31 s, against P4's 39 s alone).
- The steady state is P4's; P6's 16.8 ms is the target once P4's crossings are fewer.
- Strict mode costs the ND load ~5 s (2.9 → 7.9–8.1 s), as in P6.
