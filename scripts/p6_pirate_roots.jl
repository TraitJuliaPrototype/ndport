# P6 check X at S7 (E-155): strict mode names only the first fact a pirate would win at. Which trait code holds
# facts at `sin(::Dual{…, Float64, N})`, the pirate of p3_pirate.jl? After the first Rodas5P solve (as p3_pirate.jl),
# every valid caller of a `sin` specialization on duals that is trait-world code, by its trait root's module
# (TraitWorld._trait_root: the first caller up the backedges that is a method of a trait module).
# Prints `XR <module> <n callers>` and `XR roots: <module.name> …`.
using TraitWorld, Graphs, NetworkDynamics, OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock, DiffEqCallbacks, SymbolicIndexingInterface
const ForwardDiff = NetworkDynamics.ForwardDiff
include(joinpath(@__DIR__, "workload_steps.jl"))
a = NDW.step_a(:swing); nw = NDW.step_b(a); c = NDW.step_c(nw); d1 = NDW.step_d(nw, c.s)
roots = Dict{String,Int}(); mods = Dict{Symbol,Int}()
for m in methods(sin), mi in Base.specializations(m)
    mi isa Core.MethodInstance || continue
    occursin("Dual", string(mi.specTypes)) || continue
    isdefined(mi, :backedges) || continue
    be = mi.backedges; i = 1
    while i <= length(be)
        x = be[i]
        caller = x isa Type ? be[i+1] : x
        i += x isa Type ? 2 : 1
        caller isa Core.CodeInstance && caller.max_world == typemax(UInt) || continue
        TraitWorld._trait_world_code(caller) || continue
        r = TraitWorld._trait_root(caller)
        r === nothing && continue
        k = r.def isa Method ? "$(nameof(Base.moduleroot(r.def.module))).$(r.def.name)" : string(r)
        roots[k] = get(roots, k, 0) + 1
        mm = r.def isa Method ? nameof(Base.moduleroot(r.def.module)) : :none
        mods[mm] = get(mods, mm, 0) + 1
    end
end
for (k, v) in sort!(collect(mods); by = x -> -last(x)); println("XR ", k, " ", v); end
println("XR roots: ", join(["$k=$v" for (k, v) in sort!(collect(roots); by = x -> -last(x))], " "))
