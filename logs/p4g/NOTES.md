# P4 step 2 (E-154): the graph trait, running notes

The plan: `writeup/plans/2026-10-21-ndport-graph.md` (adopted after its review). Worktrees: `pkgs/Graphs-p4`
(branch `trait-port-p4`, from Graphs' `upstream` tag dffc7a64), `pkgs/NetworkDynamics-p4` (branch `trait-port`,
from c9339fd). julia-1.13 6d480d0753, TraitWorld 3bebf13 (not edited), strict mode off. Working notes for the
coordinator, not normative.

## Environments

- `env_p4/Project.toml` and `env_ndtest_p4/Project.toml`: `[sources]` Graphs → `../pkgs/Graphs-p4` (was
  `../pkgs/Graphs.jl`), resolved offline (G1). The manifests' Graphs entry gains `TraitWorld` in its deps and
  the new path; nothing else changes (`env_ndtest_p4/Manifest.toml` diff: those lines and the project hash).
  `env_p4/Manifest.toml` is not tracked in the ndport repository.
- The P4 scripts take `P4LOGDIR=<dir>` (default `logs/p4`) and record the Graphs source and commit in their
  headers (`p4_precompile.sh`, `rhs_p4.sh`, `nd_tests.sh`). New: `graph_probe.jl` (+ `graph_probe_u.jl`,
  `graph_probe_p4.jl`), `graph_check.jl`, `graph_check.sh`.

## G0: probes before any change

`logs/p4g/g0-U.log` (env_upstream, default depot), `g0-P4.log`, `g0-P4-2.log`, `g0-P4-3.log` (env_p4, depot-p4,
Graphs at `upstream`, ND c9339fd). `g0-P4-3.log` is the valid run of (b); `g0-P4-2.log` holds (c) (identical in
`-3`); `g0-P4.log` is the first run, where the probe was called from top level (see (b)).

**(a) Upstream on other graph types** (tier S's models):
- `SimpleGraph{Int64}`, `SimpleDiGraph{Int64}` build.
- `GenericGraph`, `GenericDiGraph`, `SimpleGraph{Int32}` fail in the index manager:
  `MethodError: Cannot convert … GenericEdge{Int64}` (`SimpleEdge{Int32}`) `to … SimpleEdge{Int64}`, raised in
  `new` at `network_structure.jl:39` (the field `edgevec::Vector{SimpleEdge{Int64}}`), from `IndexManager`
  (`:32`) in `Network` (`construction.jl:127`).
- The feed-forward network (`rhs_check.jl`'s `ff`) on a `GenericDiGraph` fails earlier, in the feed-forward
  check: `NotImplementedError: method == not implemented` at `construction.jl:86`
  (`SimpleEdge(src, dst) ∈ simpleedges` compares a `SimpleEdge` with a `GenericEdge`; Graphs'
  `==(::AbstractEdge, ::AbstractEdge)` fallback, `interface.jl:108`). `e.src` (`:93`) would fail next.

**(d) GraphMakie on a `GenericGraph`, upstream:** `graphplot` with step f's attributes and `graphplot!` into an
`Axis` (step g's form) render (`colorbuffer`, not saved) on `SimpleGraph`, `GenericGraph` and `GenericDiGraph`,
with the same `node_pos` (Spring, seed 1). `digest_b`'s reads on a `GenericGraph`: nv 20, ne 40,
`is_connected` true, the edge pairs equal to the `SimpleGraph`'s. **So GraphMakie and NetworkLayout handle a
`GenericGraph` upstream: G5–G6 stay deferred** (plan §2.6, §4.3). The `graphtype` pass should fail only at b in U.

**(b) The member table through a bounded probe** (the declaration of §2.2 in a plain scratch module `GDecl`,
the probe in a scratch trait module): all seven types conform at their first use, and the probe's results
equal the plain reads (`nv`, `ne`, `is_directed`, `has_edge(g, 1, 2)`, `degree(g, 1)`, the edge pairs, the
neighbours of 1). V is `Int32` for `SimpleGraph{Int32}`, `Int64` for the others. First calls 0.12–0.49 s.
`WrongNv` is refused at its first use and again at a second call: `ImplementError: WrongNv is a member of a
family implementation of Main.GDecl.GraphInterface, but does not conform: `nv` at Tuple{WrongNv} returns
`Int64`, declared `Int32``, raised in `_check_member` (`implement.jl:859`) from `_conf_family`; no other
operation named. **Criterion 1's gate holds at G0.**
- The spelling of §2.2 works as written: `@trait GraphInterface{V <: Integer}`, `V = eltype(Self)`, operations
  with `g::GraphInterface{V}` and qualified names, the family line.
- In the first run (`g0-P4.log`) the probe was called from a top-level `for` loop over a tuple of graph types:
  the caller holds `x` at an abstract type, so by the first-seen rule (traits §6.2) the graph entered `Dynamic`.
  Every conforming type then failed with the `TypeError` of (c); `WrongNv` was refused by the member check as
  above (the member check runs before the operation). The valid runs call through a function compiled for the
  graph's type (`bcall(x) = GProbe.probe(x)`): `Compiled`.

**(c) Traits §5.2, a `Dynamic` trait object of `GraphInterface`** (`with_dynamic(g)` at the bound):
- **`edge_list` fails on a `Dynamic` trait object, at every bound** (`g::GraphInterface`,
  `g::GraphInterface{V} where {V}`, `g::GraphInterface{Int}`), for `SimpleGraph{Int64}` and `{Int32}`:
  `TypeError: in SimpleEdge, in T, expected T<:Integer, got Type{TraitWorld.OpenParam}`. Frames:
  `op_ret` (`trait.jl:341`) < the operation's method on a held value (`trait.jl:383`) < `_erased_op`
  (`attributes.jl:95`) < `opcall` (`core.jl:1057`). The same call on `compiled_for(g)` gives the results.
  - By reading (not probed further): `_erased_op` calls the operation on `Dynamic{X}` with `X` the bare trait
    (`GraphInterface`), whose erased key leaves `V` open (`_erased_key_of`, `core.jl:933`–`:939`). The operation's
    method on a held value computes its declared result at that key, `op_ret(…, ErasedKey{Tuple{OpenParam}})`,
    which substitutes `OpenParam` for `V`. `Vector{V}` takes it (`Vector{OpenParam}`, then `_erased_ft` gives
    `Any`); `SimpleEdge{V}` does not, since `SimpleEdge{T <: Integer}` bounds its parameter, so the type cannot
    be formed and `TypeError` is raised before the call.
- Without `edge_list` (`nv`, `ne`, `degree`, `all_neighbor_list`): the `Dynamic` results equal the `Compiled`
  ones and are typed at `V` (`Tuple{Int32, Int64, Int32, Int64}` for `SimpleGraph{Int32}`). `fully_typed` on
  the probe at the `WithDynamic` argument reports 3 run-time sites, all in the entry's machinery
  (`_enter_erased`, `entry.jl:217`; `_like_return` and `checked_call`, `trait_module.jl:976`), none on the
  arithmetic after the operations. So §5.2 ("the same results") holds for those operations, typed at `V`.
- **Criterion 6: negative for operations whose declared result applies a parameter-bounded type constructor
  to the trait's parameter.** Per the plan: a T- deviation row proposed to the reference's owner (below,
  "For the coordinator"); not a gate, nothing in this step changes. The step's callers pass `Compiled` graphs
  (no default attribute; the first-seen rule at typed callers), so the port's path does not meet it.

## P4G-0: the before (two runs, before G1)

`logs/p4g/P4G-0/P4-{1,2}.log`: setting P4, ND c9339fd, Graphs main clone at `upstream` (dffc7a64),
TraitWorld 3bebf13 clean, julia-1.13 6d480d0753, strict off, default order, load 0.97–1.0 before and after.
E-152's post-48 runs (`logs/p4-issue48/`) were at TraitWorld a373e30 with 6 dirty files, so not "exactly these
commits"; two new runs were made. Both: 25 digests, **0 exact differences against U** (`logs/p1/U-1.log`).
W total 69.4 and 69.8 s. (Per-step table: below, with P4G-1.)

## G1: the trait in Graphs (Graphs-p4 54632125)

- `src/interface_trait.jl` (new) as the plan's §2.2; included after the aliases (`const Edge = …`), before
  `degeneracy.jl`; `TraitWorld` in `Project.toml` `[deps]` (no compat entry, as NetworkDynamics-p4 has it).
- **Public, not exported** (decided at G1, per §2.2): `public GraphInterface, edge_list, all_neighbor_list`
  under `@static if VERSION >= v"1.11.0-DEV.469"` (Graphs' compat is julia 1.10, which has no `public`).
  Reason: `edge_list` is a global variable name in ND's own tests (`diffusion_test.jl:72`,
  `inhomogeneous_test.jl`, `massmatrix_test.jl`) and examples, all under `using Graphs`; an export would put the
  function's name in their scope. Consumers write `using Graphs: GraphInterface, edge_list, …`.
- P (`logs/p4g/precompile-g1.log`): Graphs 3.8 s, its SharedArrays extension, NetworkLayout's Graphs extension,
  GraphMakie 7.1 s, NetworkDynamics 24.7 s; nothing refused; `using NetworkDynamics` 2.8 s.
- C (`logs/p4g/check-g1.log`): the member table as at G0 (b), now with `Graphs.GraphInterface`: seven conform,
  equal to the plain reads; `WrongNv` refused naming `nv` only, `Int64` and `Int32`. The `N` lines are the before
  of G2: `SimpleGraph{Int32}`, `GenericGraph`, `GenericDiGraph` and `WrongNv` fail as in G0 (a) (the conversion
  at `network_structure.jl:39`); `ff` on `GenericDiGraph` fails at `construction.jl:86`.
- **The plan's reference for `ReverseView(d)` is not usable:** `reverse(d)` has the same edges in another order
  (a `SimpleDiGraph` sorts them), so `edgevec` and `du` differ. `ReverseView` builds at c9339fd (its edges are
  `SimpleEdge`s), so its reference is the same graph before G2: `check-g1.log`'s line (du 682eb66c20c959c,
  edgevec hash b1d20d1c5f9f9eec). `UndirectedView(d)`'s edge order equals `SimpleGraph(d)`'s (checked).

## G2: the index manager through `graph_index` (NetworkDynamics-p4 92fa4fe)

- `graph_index(g::GraphInterface{V}) where {V} = (; nv = Int(nv(g)), ne = ne(g), edges = SimpleEdge{Int}.(edge_list(g)))`
  in `src/network_structure.jl`, before `IndexManager`; the inner constructor calls it first and reads `gi.nv`,
  `gi.ne`, `gi.edges` instead of `nv(g)`, `ne(g)`, `collect(edges(g))`. `GraphInterface` and `edge_list` added to
  ND's `using Graphs: …` line. As planned; nothing beyond the plan.
- P (`precompile-g2.log`): ND 24.1 s, nothing refused.
- C (`check-g2.log`): every conforming type builds a network, and each equals its reference: nv, ne, `edgevec`
  and the bits of `du` (`SimpleGraph{Int32}(g)` and `GenericGraph(g)` against `g`; `GenericDiGraph(d)` against
  `d`; `UndirectedView(d)` against `SimpleGraph(d)`; `ReverseView(d)` against itself before G2: du
  682eb66c20c959c and edgevec hash b1d20d1c5f9f9eec in both `check-g1.log` and `check-g2.log`).
  `SimpleGraph{Int32}` builds and runs: no failure later on `Int32` ranges in tier S (the plan's caveat did
  not bite here; not claimed beyond tier S's right-hand side).
- `WrongNv` through `Network`: refused with the same `ImplementError` (naming `nv`, `WrongNv`, `Int64`,
  `Int32`), raised at `graph_index(g)` in `IndexManager` (`network_structure.jl:41`, through the entry's
  `_enter_compiled` → `_conf_family` → `_check_member`; `check-final.log`). Upstream builds no network on it
  either, but for another reason (the `SimpleEdge{Int32}` conversion).
- R (`rhs-g2.log`): R/J lines equal to U; `sametype=true`.
- W (`logs/p4g/g2/P4-1.log`, one run): 25 digests, 0 exact differences against U.

## G3: the feed-forward check — stopped, reverted (6044c0c, reverted by 19c2045)

- The plan's form: the block of `construction.jl:66`–`:96` moved into
  `check_feedforward_leaves(g::GraphInterface{V}, vertexm, edgem) where {V}`, with `all_neighbor_list(g, V(i))`,
  `edge_list(g)[eidx]`, `Graphs.src(e)` (ND does not import `src`; inside the `do (src, dst)` closure the names
  are local) and `SimpleEdge{V}(src, dst)` (upstream's `SimpleEdge(src, dst)` needs both of one type; `src` is an
  `Int` from `findall`, `dst` a `V`). P passed (ND 23.0 s, nothing refused at definition).
- **At its first call it raises `FieldError: type UnionAll has no field parameters`**, from the entry inlined
  into the caller (no TraitWorld frame in the trace; the frame is the call site, `construction.jl:68`). R: every
  `ff` row an `E` line, `R/J: DIFFER from U` (`rhs-g3.log`); C: `check-g3.log` stops at `ffnet()`.
- **Narrowed** (`scripts/graph_g3_probe.jl`, `logs/p4g/g3-probe.log`; minimal: `scripts/graph_g3_min.jl`,
  `logs/p4g/g3-min.log`): a closure inside a **bounded** function that **captures a variable whose type is not
  inferred** fails so at the call. In the minimal file, with `x = Base.inferencebarrier([5, 6])`:
  - `b1(g::GraphInterface, a) = (x = …; all(zip(a, a)) do (s, d); s ∈ x end)`: FieldError;
  - `b2(g::GraphInterface, a) = (x = …; all(t -> t[1] ∈ x, zip(a, a)))`: FieldError (no destructuring);
  - `b3`, the same with `x = [5, 6]` (typed): works;
  - the same closure in a trait module's unbounded function, or in a plain module: works.
  - In G3 the untyped variable is `simpleedges = edge_list(g)[eidx]`: `eidx = findall(is_loopback, edgem)` infers
    `Vector` (a `UnionAll`; `is_loopback` reads an abstract field, so its result is not inferred `Bool`), so the
    indexing is a run-time site and `simpleedges` is `Any`; the `do (src, dst)` closure captures it.
  - A closure capturing only the trait object or `V` (typed) works (`f3`, `m1`–`m7`, `n11` in the probe).
- **Reading:** traits §5.3 allows a closure passed to Base, checked like the function; a variable of a type not
  inferred is allowed in trait code ("their uses dispatch when they run"). So this is TraitWorld failing on
  allowed code: a candidate T- deviation row (below). TraitWorld is pinned and not edited.
- **Not worked around.** A typed `eidx` (`findall(…)::Vector{Int}`) or a loop instead of the closure would avoid
  it, but only to dodge the failure; the rule for this step is to stop and record. G3 is reverted, so the ND
  head (19c2045) has G2's code exactly (`git diff 92fa4fe 19c2045` is empty). Consequences:
  - the feed-forward network on a `GenericDiGraph` still fails as upstream does (`construction.jl:86`,
    `check-final.log`); tier S has no feed-forward vertex, so criterion 2 is not affected;
  - criterion 5's T run is at G2's code.
- **G4 (optional): not done.** It fixes nothing upstream gets wrong (plan §3), and after G3 it would add a
  bounded function for no gain in this step.

## G7: the harness's `graphtype` pass (ndport f256b65, fixed by 029de9b)

- As planned: `NDW_PASSES` naming `graphtype` runs a pass a–g (`swing!`) on `Graphs.Test.generic_graph` of the same
  Watts–Strogatz graph; a step that throws prints `D graphtype <step> error=<type>` and ends the pass. The pass
  includes step a (the models; 1.6 ms, nothing compiled), so the pass is a–g rather than the plan's b–g.
  `compare_digests.py` gained `--passes=…` and `--as=X:Y` (it did not tolerate the extra pass: a key missing in
  the reference counts as a failure).
- **My first version cost 5 s in the default passes' step b**: with `graph = :simple` as a `Symbol` keyword,
  step b's code inferred both branches, and in setting P4 the first `b` compiled the `GenericGraph` network too
  (5.7–5.9 s against 0.55 s; first c fell by the same amount; `logs/p4g/superseded/`). Fixed by dispatching on
  `Val(:simple)` / `Val(:generic)` beside the unchanged `step_b(r)` (029de9b, a second commit). After it, P4's
  first b is 0.55 s again. In U the same mistake had cost only ~0.1 s (1.49 → 1.61 s).
- Identity (`logs/p4g/U-graphtype/U-1.log`, after the fix): one U run with `graphtype` added; the common passes'
  `D` lines byte-identical to E-151's `logs/p1/U-1.log`, the other non-timing lines the same set. U's
  `graphtype` pass: a runs, **b fails with `MethodError`** (the conversion of G0 (a)).
- The P6 agent committed between my two commits (4d14253); the harness files were not touched by it.

## E-154's runs (P4G-1) and the criteria

Builds: julia-1.13 6d480d0753, TraitWorld 3bebf13 (clean), Graphs-p4 54632125, NetworkDynamics-p4 19c2045 (= G2's
code), the harness at 029de9b; setting P4, strict off, the default load order; load 1.1–2.3 before, 1.0–1.2 after.
Logs: `logs/p4g/P4G-1/P4-{1,2}.log` (default passes), `P4G-1-confirm/P4-1.log` (criterion 3's confirmation),
`P4G-1-graphtype/P4-1.log`, `P4G-1-diag/P4-1.log` (attribution, with `graphtype`), `rhs-final.log`,
`check-final.log`, `ndtest-final.log`. Measures library trait code reading plain graph types (interop).

| # | Criterion | Result | Pass |
|---|---|---|---|
| 0 | results | every P4G-1 log (5): the common passes 0 exact differences against U (25 digests); `rhs-final.log` R/J equal to U | **yes** |
| 1 | the contract | seven types conform at a bounded probe, results equal to the plain reads; `WrongNv` refused with `ImplementError` naming `nv` only, `WrongNv`, `Int64`, `Int32`. Through `Network`, the same error, raised at `graph_index` | **yes** |
| 2 | a graph type upstream refuses | U: b fails (`MethodError`). P4G-1: the `graphtype` pass runs a–g; its 7 digests equal the same session's `first` exactly (`--as=graphtype:first`), in both runs that had the pass | **yes** |
| 3 | no cost | "again", min of 3 runs against P4G-0's min of 2 (bound 1.10 × + 5 ms): a 1.6 (1.7), b 0.5 (0.5), c 4.6 (4.9), d 33.1 (33.4), e 0.8 (0.8), f 38.9 (37.6; bound 46.4), g 158.2 (144.5; bound 164.0). First b 546.5–555.1 ms (P4G-0 547.0–556.3). The common passes 56.96–58.16 s (P4G-0 58.26–58.38) | **yes** (f: the first two runs 62.9 and 65.5 ms, each with a 26–27 ms GC pause in the step; the third run 38.9 ms, no GC) |
| 4 | what a new graph type compiles | the `graphtype` pass 18.0 s, 17.7 s compiling: b 0.92, c 3.58, d 8.44, e 2.43, f 2.15, g 0.51 s (U's `changed` pass 16.4 s). New CodeInstances (attribution run): b 262 (Base 121, Graphs 63, TraitWorld 36, NetworkDynamics 34), c 1,622 (SciMLBase 262, NonlinearSolveBase 230, ND 171, …), d 2,810 (OrdinaryDiffEqCore 563, SciMLBase 468, …), e 957, f 944 (Makie 177, ComputePipeline 136, GraphMakie 39), g 59. `graph_index` and the member check are inside b's 0.9–1.2 s (not isolated further); the rest is the stack recompiled for the `Network`'s new type parameter (plan §3.1) | reported |
| 5 | tests | as at c9339fd (S6): massmatrix 6, doctor 26, diffusion 111 + 1 fail, inhomogeneous 43 + 2 fail; the three failures are P4-1's allocation assertions (`diffusion_test.jl:111` 288 B; `inhomogeneous_test.jl:59` 7; `:93` 103 vs 403) | **yes** |
| 6 | traits §5.2 | `Dynamic` results typed at `V` and equal to `Compiled` for `nv`, `ne`, `degree`, `all_neighbor_list`; **`edge_list` on a `Dynamic` trait object raises `TypeError` (`SimpleEdge{OpenParam}`)** | **no** for `edge_list`: a T- row proposed (not a gate) |

- Allocations per right-hand side in tier S (`rhs-final.log`, reported): 208 B, 1.8 µs sequential; unchanged by
  this step (the graph is read at construction only).

## For the coordinator (candidate deviation rows; nothing here edits writeup/)

**T-? (traits §5.2, §3.4): an operation whose declared result applies a parameter-bounded type constructor to the
trait's parameter fails on a `Dynamic` trait object.**
- Spelling: `@trait GraphInterface{V <: Integer} … Graphs.edge_list(g::GraphInterface{V})::Vector{SimpleEdge{V}}`
  (`SimpleEdge{T <: Integer}`); called on `with_dynamic(g)` at any bound (`GraphInterface`, `GraphInterface{V}
  where {V}`, `GraphInterface{Int}`).
- Behaviour: `TypeError: in SimpleEdge, in T, expected T<:Integer, got Type{TraitWorld.OpenParam}`, where the
  `Compiled` call gives the result. The reference: "Both offer the same operations and fields, with the same
  results".
- Where (from the frames, by reading): `_erased_op` (`attributes.jl:95`) calls the operation on `Dynamic{X}` with `X`
  the bare trait, whose erased key leaves `V` open; the held value's method (`trait.jl:383`) forms the declared
  result at that key (`op_ret`, `trait.jl:341`), substituting `OpenParam` for `V`.
- Probe: `scripts/graph_probe_p4.jl` (`pc1`–`pc3`), `logs/p4g/g0-P4-2.log`.

**T-? (traits §5.3): a closure in a bounded function that captures a variable whose type is not inferred fails at
the call** with `FieldError: type UnionAll has no field parameters`.
- Minimal: `scripts/graph_g3_min.jl`, `logs/p4g/g3-min.log` (`b1`, `b2` fail; the same closure with a typed
  variable, in an unbounded function of a trait module, or in plain code works).
- It blocks G3 in its plan's form (upstream's feed-forward check moved into a bounded function unchanged).
  Whether G3 runs again after a TraitWorld fix, or in a typed form now, is for the coordinator/the user.

**Pushback entries (the log's shape), as the plan's §6 expected:**

- **P4-3. An informal interface whose functions return open iterators.** Confirmed as the plan states it:
  `Graphs.Test.GenericGraph` returns generators from `edges` and `all_neighbors`, so the trait declares
  `edge_list` and `all_neighbor_list` with concrete results (a copy each, at construction). Blocks: no. What the
  port did: the two functions in Graphs (G1); ND's index manager reads `edge_list` (G2).
  - New, for this entry: the concrete result `Vector{SimpleEdge{V}}` also meets the first deviation above on a
    `Dynamic` trait object; an associated item type would meet the same.
- **P4-4. The owner of an informal interface cannot put the trait in an extension.** As the plan states it; nothing
  measured changes it. Graphs gained TraitWorld as a hard dependency; precompiling Graphs and its dependents
  took 29 s in `depot-p4` (Graphs 3.8 s, GraphMakie 7.1 s, ND 24.7 s; `precompile-g1.log`).
- **P4-5:** not written (G5–G6 deferred by G0 (d)).
- **Not pushback, for the guideline:** the name `Graph` (plan §6, last line) — avoided by `GraphInterface`; no probe.

## Lessons for the guideline (B5), as they stand

- Check the trait's name against the package's exports (`Graphs.Graph` is `SimpleGraph`): `GraphInterface`.
- Declare an informal interface's trait in its owner, as plain code; only the consumers' bounded functions are
  trait code. In Graphs this was one file (40 lines), an include and a `[deps]` line; nothing in Graphs is
  compiled by facts. Make the names `public` rather than exported where they are common words (`edge_list` is a
  variable name in ND's own tests).
- Test the declaration against the package's own generic test types (`Graphs.Test.GenericGraph`) and a type
  whose methods exist but return the wrong type: the first shows which results are open; the second is the case
  the trait adds over the package's own `NotImplementedError` (missing methods).
- Declare concrete argument types (`v::V`) so the member check infers each operation; callers convert.
- Bound the readers, not the front end, where the front end stores the user's object: `Network(g::AbstractGraph, …)`
  keeps its type and calls `graph_index(g)`. A bounded reader that converts at its result (`SimpleEdge{Int}` from
  `edge_list`) fixed the upstream failure (`SimpleEdge{Int32}`, `GenericEdge`) without touching the stored types.
- Call a bounded function from a function compiled for the value's type when you test it: a call from a
  top-level loop over mixed types passes `Dynamic` values (the first-seen rule), which take another path.
- Before moving a block of untyped code into a bounded function, check that the variables its closures capture
  are inferred (`findall` with a predicate that is not inferred `Bool` gives `Vector`, a `UnionAll`): today a
  closure capturing such a variable fails at the call (the second deviation above).
- In a shared harness, a new variant selected by a keyword `Symbol` makes the default path infer the variant's
  code too; select it by `Val` (G7's 5 s lesson).

## Anything needing the user

- The two candidate deviation rows above (the reference's owner). The second blocks G3 in its plan's form.
- G3's way forward: wait for a TraitWorld fix, or allow a typed form (`eidx = findall(is_loopback, edgem)::Vector{Int}`)
  as principled rather than a workaround.

## G3 again (2026-10-22, E-154's open part, under E-165)

NetworkDynamics `trait-port` 324bcb7 (6044c0c's change cherry-picked onto the revert 19c2045; tagged `p4-s2`);
Graphs-p4 54632125; TraitWorld c655dde (the worktree `TraitWorld-port`; T-59 fixed in f06b82d); julia-1.13 build
2943086604 (libjulia-internal built 2026-10-21 20:43); `env_p4_pin` and `env_ndtest_p4pin` (copies of `env_p4`,
`env_ndtest_p4` whose TraitWorld path is `../../TraitWorld-port`), depot `depot-p4pin` (fresh); strict mode off.

| Check | Log | Result |
|---|---|---|
| P | `precompile-g3-pin.log` | builds: 450 packages in 329 s (a fresh depot: everything above TraitWorld), `using NetworkDynamics` 3.1 s |
| C | `check-g3-pin.log` | the member table and `WrongNv` as in `check-final.log`; **the `ff` network on a `GenericDiGraph` builds** (`du` equal to the `SimpleDiGraph`'s; at 19c2045 it failed with Graphs' `NotImplementedError` for `==` on `GenericEdge`); the refusals on both graph types the same `ArgumentError` |
| R | `rhs-g3-pin.log` | R/J lines equal to U's; `sametype=true`; the `ff` network passes the check; one right-hand side 208 B, 1.7 µs sequential (as `rhs-final.log`); the two `KAExecution` errors on `ff` are upstream's (also in `logs/p4/rhs-U.log`) |
| T | `ndtest-g3-pin.log` | as at c9339fd and 19c2045: massmatrix 6, doctor 26, diffusion 111 + 1 fail, inhomogeneous 43 + 2 fail (P4-1's three allocation assertions) |
| T-59's reproducer | `g3-min-pin.log` | all six forms `true` (b1, b2 failed on 3bebf13) |
| W | `../merge/p4-pin/P4P-{1,2}.log` | 25 digests, 0 exact differences against U (two runs) |

G3 holds in its plan's form: upstream's block moved unchanged into `check_feedforward_leaves(g::GraphInterface{V}, …)`,
no typed form needed.
