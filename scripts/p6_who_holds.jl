# P6 diagnostic: which trait-world code holds a fact at `reshape(::Vector{Dict{Symbol,Any}}, ::Tuple{Vararg{OneTo{Int}}})`,
# the call at which strict mode refused OffsetArrays' `reshape` pirate when the plotting packages loaded (I0, S0).
# Loads the stack without the plotting packages, then walks the backedges of the callee's CodeInstances.
using TraitWorld, Graphs, NetworkDynamics, OrdinaryDiffEqTsit5, OrdinaryDiffEqRosenbrock, DiffEqCallbacks, SymbolicIndexingInterface
const SIG = Tuple{typeof(reshape), Vector{Dict{Symbol,Any}}, Tuple{Vararg{Base.OneTo{Int}}}}
for m in methods(reshape), mi in Base.specializations(m)
    mi isa Core.MethodInstance && isdefined(mi, :backedges) || continue
    be = mi.backedges; i = 1
    while i <= length(be)
        x = be[i]
        if x isa Type
            sig, caller = x, be[i+1]; i += 2
        else
            sig, caller = mi.specTypes, x; i += 1
        end
        occursin("Dict{Symbol, Any}", string(sig)) || continue
        caller isa Core.CodeInstance || continue
        tw = TraitWorld._trait_world_code(caller)
        d = caller.def isa Core.MethodInstance ? caller.def : caller.def.def
        println("EDGE ", sig, " <- ", d.specTypes, " owner=", caller.owner === nothing ? "nothing" : caller.owner, " trait_world=", tw,
                " valid=", caller.max_world == typemax(UInt))
        if tw
            r = TraitWorld._trait_root(caller)
            println("  root ", r === nothing ? "none" : r, " method ", d.def isa Method ? "$(d.def.module) $(d.def.file):$(d.def.line)" : "")
        end
    end
end
