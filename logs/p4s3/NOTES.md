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

## S3-2: the traits per kind (NetworkDynamics 4df44d4)

`ComponentDynamics` keeps `hasf`, `fftype`, `pdim`, `extdim` (default 0) and, through S3-2 only, `compf!`/`compg!`
(the review's blocker 1); `VertexDynamics <: ComponentDynamics` (`vertexf!`, `vertexg!`) and `EdgeDynamics <:
ComponentDynamics` (`edgef!`, `edgeg!`); `FunctionDynamics` implements all three as families. Not exported or
`public` yet (3b, when users name them).

| Check | Log | Result |
|---|---|---|
| **P** | `precompile-s2.log` | ND and its dependents 53 s; strict on; no `OwnershipError`, no `PirateError`; the 15 extension warnings ND's own precompilation prints as before |
| **R** | `rhs-s2.log` | R/J equal to U; `sametype=true`; the kind's operations on a `Kept{VertexDynamics}`/`Kept{EdgeDynamics}` give `apply_compf`/`apply_compg`'s bits for every component of the check networks: 15 of 15 lines (labelled `S3 … vertex|edge` in this log, `K` from S3-3 on) |

**Found:** a supertrait's operation called from plain code on a kept value of the subtrait is refused:
`hasf(Kept{VertexDynamics}(x))` raises `MethodError: no method matching hasf(::Kept{VertexDynamics})`, also after
`compiled_for`, for a family member and for a one-line `Swing` alike; the subtrait's own operations work
(`vertexf!(Kept{VertexDynamics}(x), …)`). Minimal reproducer: `scripts/p4s3_supertrait.jl`, the lines `plain code:`
(`s3-supertrait/M-1.log`, TraitWorld `w49`). Inside bounded code (`m::VertexDynamics`) the supertrait's operations
work (S3-0 (c)), so the core loop is not affected. Traits §3.6 says "`@trait B <: A` makes `A`'s operations available
through a `B` bound"; a kept value of `B` at `A`'s operation from plain code is not said. A candidate T- row or an open
question for the coordinator. The check scripts read the static facts through `Kept{ComponentDynamics}(held object)`
(`rhs_check.jl`, `cdview`).

## S3-3: the batches per kind (NetworkDynamics 4e5f5a2)

`ComponentBatch` keeps `_kept_model(dT, FunctionDynamics(…))`: `Kept{VertexDynamics}` or `Kept{EdgeDynamics}`;
`_process_kept!` calls `_run_batch!(dispatchT(batch), compiled_for(batch.model), batches, k, args)`, a dispatch on
the batch vector's kind (a constant); `run_vertex_batch!(m::VertexDynamics, batches::Vector, k::Int,
args::Base.RefValue)` and `run_edge_batch!(m::EdgeDynamics, …)` keep upstream's annotations; `_vertex!`/`_edge!`
call the kind's operations; `compf!`/`compg!` are `FunctionDynamics`' own helpers. `_dynamics` (the `conforms` test
for a user's value) is left to 3b with the adaptors: no record holds a user's value before S3-4.

| Check | Log | Result |
|---|---|---|
| **P** | `precompile-s3.log` | 54 s; strict on; no `OwnershipError`, no `PirateError`; the extension warnings as at S3-2 |
| **R** | `rhs-s3.log` | R/J equal to U; `sametype=true` (the erased vertex batch type `ComponentBatch{VertexModel, Any, …, Kept{VertexDynamics}}` for `swing!` and `swing2!`); `K` lines 15 of 15 true; step 1's `S3` lines ok. Tier S sequential 1,234–1,249 ns, 240 bytes (S3-1 1,211–1,238 ns, 208 bytes) |
| **X** | `s3-split/M-1.log` | the right-hand side 1,238 ns, 5 allocations (S3-1 1,177); the crossing into an empty batch 39 / 36 / 47 ns (S3-1 39 / 37 / 48): **the S3-3 mark (≤ S3-1's + 15 ns) passes** |
| **Y** | `rhs-s3.log` | the typed batches on function models: R's `PolyesterExecution{true,false}` and `KAExecution` lines equal to U's (the KA `E` lines as U's). `scripts/p4_polyester_check.jl` is PB-7's definition-check probe, untouched by this step, not rerun |
| **W** | `s3-W/M-1.log`, `s3-W2/M-1.log` | 0 exact differences (both); again c / d / e 4.4 / 33.6 / 0.9 and 4.4 / **29.5** / 0.9 ms (load 1.2–1.6; the first d is spread, the second run confirms); changed b–e 0.55–0.56 s; first a–e 30.8–31.4 s; session 65.2–66.1 s. Against S3-1 (28.8): 29.5 within 5 % + 0.5 ms |

## M-3a: E-166's runs at NetworkDynamics 4e5f5a2, TraitWorld `w49` 3ae361c

Strict off: `s3-W/`, `s3-W2/` (above). Strict on: `m3a-strict1/`, `m3a-strict1-confirm/`. Census and dispatch
profile (strict on, `JULIA_FACTS_DISPATCH_PROFILE=1`): `m3a-CH/M-1.log` (`M-1-noprofile.log`: the same census
without the profile, the first attempt). X with bytes: `m3a-split/`. `fully_typed` at the entries:
`m3a-fully-typed/`. T: `ndtest-s3.log` (after `precompile-ndtest-s3.log`, `env_ndtest_p4pin` rebuilt on `w49`).
Load 1.2–3.1; the machine shared (the user's own jobs).

| | M-0 (E-165) | S3-1 | M-3a strict off (2 runs) | M-3a strict on (2 runs) |
|---|---|---|---|---|
| digests against U, exact | 0 | 0 | 0, 0 | 0, 0 |
| refusals | — | — | — | OffsetArrays' `reshape` only; the extension warnings as E-165's (15 lines) |
| crossing into an empty batch | 165–182 ns (S3-0) | 37–48 ns | 36–47 ns | — |
| one right-hand side, tier S (X) | 1,834 ns, 5 allocations | 1,177 ns | 1,238–1,312 ns, 5 allocations, 240 bytes | — |
| again c / d / e | 5.2 / 34.7 / 1.0 ms | 4.8 / 28.8 / 1.0 | 4.4 / 29.5–33.6 / 0.9 | 5.0–5.4 / 33.4–34.6 / 1.1–1.3 |
| changed b–e | 0.56 s | 0.54 s | 0.55–0.56 s | 0.73–1.02 s (E-165: 0.63) |
| first a–e | 31.1 s | 31.6 s | 30.8–31.4 s | 33.0–37.4 s |
| load Graphs+ND | 2.94 s | 3.02 s | 2.89–2.95 s | 7.8–9.4 s |
| session | 65.9 s | 67.5 s | 65.2–66.1 s | 83.8–91.1 s |

- **Census (C):** NetworkDynamics 3 "pirates": the three `TraitWorld._family_registry(::Val{…}, ::Val{:NetworkDynamics})`
  methods of its three families (L-38), every other wrapped package as E-165 (joint as at S7); total 67.
- **Profile (H), steps c–e again:** 75,977 dynamic calls in the top 40, 5 from plain code; TraitWorld 35,290, all
  `checked_call` from the crossings (as E-165: the worker's call stays a run-time site for non-concrete arguments,
  plan §2.1); NetworkDynamics 1,840 (E-165 2,020).
- **`fully_typed`** at `_process_kept!` and at `run_vertex_batch!`/`run_edge_batch!`'s entries: 26–27 run-time sites,
  all in TraitWorld's table machinery (`_pmiss`, `_assemble`, `_enter_compiled`) and Base's task code; none in
  NetworkDynamics' source. The entry assembles `TraitList{Tuple{ComponentDynamics, VertexDynamics}}`: the trait object
  carries the supertrait's view too.
- **Bytes:** a right-hand side allocates 240 bytes at S3-3 against 208 at S3-1 (R's `A` lines; ND's test
  `diffusion_test.jl:111` 352 against 288 bytes): 32 bytes more per right-hand side with the traits per kind, the same
  allocation count, the crossing's time unchanged. Not attributed further (the two-trait object, above, is the
  candidate).
- **T:** massmatrix 6, doctor 26, diffusion 111 + 1 fail, inhomogeneous 43 + 2 fail: as before. The three allocation
  assertions: `diffusion_test.jl:111` 352 bytes (before 288), `inhomogeneous_test.jl:59` 7 allocations (7),
  `:93` 103 == 403 (the same).
- **Threaded style** (R's `A` lines, two threads on two cores at nice 19): 698–708 µs per right-hand side against U's
  9.1 µs in the same conditions; reported, not a criterion; the same at S3-1.

## E-166's questions (part 3a)

0. **Results exactly equal to U, strict off and on:** yes; every workload log 0 exact differences (two strict off,
   two strict on), every R/J line of `rhs_check.jl` equal to U's at S3-1, S3-2, S3-3. Gate passed.
1. **The network's type the same for `swing!` and `swing2!`:** yes (`sametype=true`; the erased vertex batch type
   holds `Kept{VertexDynamics}`). Gate passed.
2. **A crossing at most 90 ns (before 162–172):** 36–48 ns from S3-1 on (S3-0: 165–182 ns); at S3-3 within S3-1's
   + 15 ns. Pass.
3. **Step d at most 32.0 ms strict off:** 29.5 ms, the minimum of two runs at S3-3 (33.6 and 29.5; S3-1 28.8;
   M-0 34.7; P6 16.8; U 15.3). c 4.4, e 0.9 ms within 1.10 × M-0's + 0.5 ms. Pass.
4. **Changed b–e at most 1.0 s:** 0.55–0.56 s strict off. Pass. Strict on 0.73–1.02 s (reported; E-165 0.63 s).
   Strict on d 33.4–34.6 ms, within 1.10 × strict off's + 5 ms (37.5).
5. **Strict mode refuses nothing in the port's code; the census counts only L-38's methods:** yes; the one refusal is
   OffsetArrays' `reshape` in Base's code (as M-0); the census counts NetworkDynamics' three family registry methods.
   Pass.
6. **ND's test subset as before:** yes (the same passes and the same three allocation assertions).

## Findings for the coordinator

- **W-49 retires L-39, L-40, L-41** on `w49` and on TraitWorld main (4410407).
- **Candidate T- row (S3-0 (c)):** a family implementing a subtrait, without the supertrait's family, is accepted at
  `@implement`, and `conforms(T, Sub)` answers `true` for its member; the first use raises `TraitBoundError` with a
  message naming the member as forwarding to itself (`scripts/p4s3_supertrait.jl`, "no supertrait family").
- **Candidate T- row or open question (S3-2):** a supertrait's operation from plain code on a kept value of the
  subtrait: `hasf(Kept{VertexDynamics}(x))` raises `MethodError` (`scripts/p4s3_supertrait.jl`, "plain code").
- **Choices made here:** the traits not exported or `public` in 3a; `_dynamics` (the `conforms` test) deferred to 3b
  with the adaptors; the batch function selected by `_run_batch!(dispatchT(batch), …)` (a dispatch on the vector's
  kind) rather than the `===` test of S3-0's code, so that no call passes a vertex model to the edge bound.
