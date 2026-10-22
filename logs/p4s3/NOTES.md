# E-166: P4 step 3, part 3a (2026-10-22)

The step-3 plan `writeup/plans/2026-10-22-ndport-step3.md` (adopted, revised by its review), part 3a: S3-0 to S3-3
and M-3a. One agent, one pass. Part 3b (S3-4, a user's own types) is not done here.

**Build and setting.** julia-1.13 build 2943086604 (libjulia-internal built 2026-10-21 20:43; the headers print the
checkout's head fa4e7f5798, not built); setting M (`env_merged`, `depot-merged`); product setting; P1's load order;
every job on two cores (`taskset -c 0-1`), idle I/O class, one precompile task, niced, through the shared lock.
The headers name the TraitWorld commit: c655dde for S3-0, `w49` from S3-1 on.

## S3-0: the before (TraitWorld c655dde, NetworkDynamics 324bcb7)

Scripts (from the planning probes `scripts/p4s3-planning/`): `scripts/p4s3_cross_shapes.jl` (probe A),
`scripts/p4s3_rhs_split.jl` (X), `scripts/p4s3_supertrait.jl` (S3-0 (c)). Each timing the minimum of three of
2·10⁵ calls; one run; load 0.9–1.0.

### (a) Probe A (`s0-cross/M-1.log`): one crossing into an empty batch, by the ordinary arguments' annotations

| Row | Annotations | ns | allocations |
|---|---|---|---|
| A1 | `bs::Vector, k::Int, args::RefValue` (ND's shape) | 217 | 1 |
| A2 | `bs::Vector{Batch}, args::RefValue` | 74 | 1 |
| A3 | `args::RefValue{AT}` (concrete) | 53 | 1 |
| A4 | `args::RefValue{A} where A` | 294 | 3 |
| A5 | `du::Vector{Float64}, u::Vector{Float64}` | 50 | 0 |
| A6 | `bs::Vector{Batch}, du, u` | 68 | 0 |
| A7 | all untyped | 68 | 0 |
| A8 | `bs, k, args` (untyped, a `Ref`) | 74 | 1 |
| A9, A10 | nine arguments, untyped or annotated | `MethodError` (`_UWrap`) | — |

### (b) The split (`s0-split/M-1.log`, tier S)

- The right-hand side 1,834 ns, 5 allocations; typed batches (Polyester's serial path) 623 ns, 0.
- Per pass, the crossing: vertex `:g` empty 182 / full 196 ns; edge `:fg` 165 / 813 ns; vertex `:f` 181 / 386 ns.
  The work alone at the held `FunctionDynamics` (typed): 14, 619, 187 ns.
- `process_batches!` per pass: 210 (2 allocations), 856 (1), 418 (2) ns: 14–43 ns above its crossing into the full
  batch (the `Ref`, the filter).
- So of the 1,211 ns excess: the three crossings about 530 ns; the `Ref`s and filters about 100 ns; the passes without
  batches and the rest about 350 ns (the right-hand side less the three `process_batches!`). The first version of the
  split timed closures over globals (`M-1.log` was overwritten by the corrected script, the same commit).

### (c) The supertrait with families (`s0-supertrait/M-1.log`)

- §3.1's three traits in a scratch trait module, a family of all three over a stand-in `FD{F,G}`, `Swing` from a
  plain module by two one-line implementations: `probe(m::VertexDynamics, …)` reads `hasf`, `pdim`, `extdim` (the
  default) and calls `vertexf!` correctly from the table (`compiled_for` of a `Kept{VertexDynamics}`, an `Any` vector
  and a typed vector) and from a typed caller; same results for `FD` and `Swing`.
- **A member whose supertrait family is missing** (`@implement VertexDynamics D where {D <: GD}`, no
  `ComponentDynamics` family): the declaration is accepted; `conforms(GD{…}, VertexDynamics)` answers `true`; the first
  `Kept{VertexDynamics}(x)`, table call or typed call raises `TraitBoundError: GD{…} forwards VertexDynamics to GD{…},
  which does not implement ComponentDynamics`. A candidate T- row (the family's declaration skips the supertraits:
  `TraitWorld/src/implement.jl:536`–`542`; the message names the member as forwarding to itself).
- The six-argument crossing (`m`, four buffers, `t::Float64`) costs 107–130 ns and 4–5 allocations: through the
  pointer every argument is boxed (the `Ref`'s reason, plan §2.3).

## S3-1 (TraitWorld): W-49 on the branch `w49`, NetworkDynamics unchanged (324bcb7)

TraitWorld `w49` 3ae361c (from c655dde; on main as 4410407): the table's pattern method asserts only a concrete
declared type of an ordinary argument (L-39); an entry whose ordinary argument names a `where` variable is tabled
(L-40); the pointer's wrapper and `checked_call` take sixteen arguments by fixed arities, a tabled entry with more
is called by a dispatch on its builder (L-41). Tests: `TraitWorld/test/untyped.jl`, the W-49 testset (12 tests; on
c655dde 2 fail and 3 error). TraitWorld's suite passes on `w49` and on main (`experiments/checks/logs/w49/`).

| Check | Log | Result |
|---|---|---|
| **P** | `precompile-s1-w49.log` | the merged stack rebuilt: 749 s with one precompile task on two cores (E-165: 368 s with four); strict on; no `OwnershipError`, no `PirateError`; the extension warnings identical to E-165's (DiffEqBaseForwardDiffExt 35, PreallocationToolsForwardDiffExt 19, SciMLBaseForwardDiffExt 12, NonlinearSolveBaseSparseMatrixColoringsExt 3); `using` 8.7 s |
| **probe A** | `s1-cross/M-1.log` | A1 (ND's shape) **217 → 84 ns**; A2 78; A8 74 (A1, A2 within 10 ns of A8: pass); A3 56, A5 49 (concrete: unchanged); A4 (`where {A}`) **294 → 72 ns, 3 → 1 allocation** (tabled: pass); A9 82 ns, A10 86 ns (nine arguments: run; pass) |
| **X** | `s1-split/M-1.log` | the right-hand side **1,834 → 1,177 ns**, 5 allocations; typed batches 571 ns. The crossing into an empty batch: vertex `:g` 39, edge `:fg` 37, vertex `:f` 48 ns (before 165–182): **criterion 2 (≤ 90 ns) passes**. `process_batches!` 59 / 662 / 267 ns |
| **R** | `rhs-s1.log` | every R/J line equal to U's; `sametype=true`; S1 lines all true; the two `E` lines (`KAExecution`, `inbufs` undefined in `compkernel_fg!`) as in U. Tier S sequential 1,211–1,238 ns, 208 bytes (U 502–543 ns, 0). Threaded 701–708 µs (U 9.1 µs; E-152's P4 43 µs): reported, not a criterion; two threads on two cores at nice 19 |
| **W** | `s1-W/M-1.log` | 25 digests, 0 exact differences against U; again c / d / e **4.8 / 28.8 / 1.0 ms** (M-0 5.2 / 34.7 / 1.0); changed b–e 0.54 s; first a–e 31.6 s; load Graphs+ND 3.02 s; session 67.5 s; load 1.5 |

The baseline for S3-2 on.
