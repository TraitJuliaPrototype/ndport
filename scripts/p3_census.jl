# P3, run 1 (the census): for each package of the stack, its methods, the pirates by the letter
# (TraitWorld.owned_method: the definer is a stakeholder of every alternative of the signature) and
# its generated methods. Prints `P <pkg> methods=<n> pirates=<k> generated=<g>` and one
# `PIRATE <pkg> <signature> <file:line>` per pirate.
#     julia --project=env_port scripts/p3_census.jl          (P0)
using TraitWorld, Graphs, NetworkDynamics, OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock, DiffEqCallbacks, SymbolicIndexingInterface
using CairoMakie, GraphMakie, Observables
const PKGS = [:NetworkDynamics, :SciMLBase, :DiffEqBase, :OrdinaryDiffEqCore, :OrdinaryDiffEqTsit5, :OrdinaryDiffEqRosenbrock,
              :DiffEqCallbacks, :SymbolicIndexingInterface, :RecursiveArrayTools, :NonlinearSolve, :NonlinearSolveBase,
              :Graphs, :NetworkLayout, :GraphMakie, :Makie, :Observables, :Static]
mods = Dict(nameof(m) => m for m in values(Base.loaded_modules))
counts = Dict(p => [0, 0, 0] for p in PKGS)
pirates = Dict(p => String[] for p in PKGS)
Base.visit(Core.methodtable) do m
    m isa Method || return
    r = nameof(Base.moduleroot(m.module))
    haskey(counts, r) || return
    c = counts[r]; c[1] += 1
    isdefined(m, :generator) && (c[3] += 1)
    if !TraitWorld.owned_method(m)
        c[2] += 1
        push!(pirates[r], "$(m.sig) $(m.file):$(m.line)")
    end
end
for p in PKGS
    haskey(mods, p) || (println("P $p not loaded"); continue)
    c = counts[p]; println("P $p methods=$(c[1]) pirates=$(c[2]) generated=$(c[3])")
end
for p in PKGS, s in sort(pirates[p]); println("PIRATE $p $s"); end
