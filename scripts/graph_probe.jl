# G0 of the graph plan (writeup/plans/2026-10-21-ndport-graph.md §3), E-154. No change to any package. Parts in graph_probe_u.jl and graph_probe_p4.jl.
#     julia --project=env_upstream scripts/graph_probe.jl U     (a) and (d): upstream on other graph types
#     julia --project=env_p4       scripts/graph_probe.jl P4    (b) and (c): the trait in a scratch module
# (a) `Network` on GenericGraph, GenericDiGraph, SimpleGraph{Int32} with tier S's models: the error and its frame.
# (d) GraphMakie on a GenericGraph (step f's attributes, rendered, not saved); digest_b's reads.
# (b) the declaration of §2.2 in a plain scratch module, the member table of §2.5 through a bounded probe.
# (c) traits §5.2: a bounded probe called with `with_dynamic(g)`: results typed at the caller's `V`?
using Graphs, Printf
using Graphs.Test: GenericGraph, GenericDiGraph, generic_graph
const SETTING = ARGS[1]

g = watts_strogatz(20, 4, 0.2; seed = 42)
d = SimpleDiGraph(collect(edges(g)))           # the same 40 edges, each from the smaller vertex
pairs_of(x) = [(Int(src(e)), Int(dst(e))) for e in edges(x)]
short(err) = (s = sprint(showerror, err); replace(s[1:min(end, 400)], '\n' => " | "))
function frames(bt; n = 4)
    fs = [f for f in Base.StackTraces.stacktrace(bt) if occursin(r"NetworkDynamics|Graphs|GraphMakie|NetworkLayout|TraitWorld", string(f.file))]
    join((string(f.func, "@", basename(string(f.file)), ":", f.line) for f in first(fs, n)), " < ")
end

include(joinpath(@__DIR__, SETTING == "U" ? "graph_probe_u.jl" : "graph_probe_p4.jl"))
