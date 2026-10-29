# R1 (E-237), part 1: the names of upstream Makie (and its packages: GeometryBasics, Observables, ComputePipeline,
# Colors, …) that GraphMakie 0.6.6 uses, read from GraphMakie's sources against the loaded modules.
#     julia --project=env_upstream scripts/r1_gm_names.jl <out.tsv>
# Writes `name<TAB>owner module<TAB>occurrences<TAB>files` for every global GraphMakie's code names whose binding is
# owned by none of GraphMakie, Base, Core, the stdlibs, Graphs, NetworkLayout, DataStructures, SimpleTraits,
# StaticArrays, PolynomialRoots; and every `Makie.x` qualified name.
using GraphMakie
const Makie = GraphMakie.Makie
const GM = GraphMakie
const SKIP = Set(["GraphMakie", "Base", "Core", "Graphs", "NetworkLayout", "DataStructures", "SimpleTraits", "StaticArrays",
                  "PolynomialRoots", "LinearAlgebra", "SparseArrays", "Random", "Statistics", "Printf", "InteractiveUtils"])
counts = Dict{Tuple{Symbol,String},Int}()
files = Dict{Tuple{Symbol,String},Set{String}}()
function note!(s::Symbol, owner::String, file)
    k = (s, owner)
    counts[k] = get(counts, k, 0) + 1
    push!(get!(files, k, Set{String}()), file)
end
owner(m::Module, s::Symbol) = try string(nameof(Base.moduleroot(which(m, s)))) catch; "?" end
function walk(ex, file)
    if ex isa Symbol
        isdefined(GM, ex) || return
        o = owner(GM, ex)
        o in SKIP && return
        note!(ex, o, file)
    elseif ex isa Expr
        if ex.head === :. && length(ex.args) == 2 && ex.args[1] === :Makie && ex.args[2] isa QuoteNode
            s = ex.args[2].value
            note!(s, isdefined(Makie, s) ? owner(Makie, s) : "Makie(undefined)", file)
            return
        end
        ex.head === :macrocall && ex.args[1] isa Symbol && walk(Symbol(string(ex.args[1])), file)
        for a in ex.args
            walk(a, file)
        end
    end
end
src = joinpath(pkgdir(GM), "src")
for f in sort(readdir(src))
    endswith(f, ".jl") || continue
    walk(Meta.parseall(read(joinpath(src, f), String); filename = f), f)
end
open(ARGS[1], "w") do io
    for ((s, o), n) in sort(collect(counts); by = x -> (x[1][2], -x[2], string(x[1][1])))
        println(io, s, '\t', o, '\t', n, '\t', join(sort(collect(files[(s, o)])), ","))
    end
end
println("R1 names ", length(counts), " owners ", join(sort(unique(last.(keys(counts)))), ","))
