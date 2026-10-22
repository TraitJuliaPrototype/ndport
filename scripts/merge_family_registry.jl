# E-165, the merge's census: TraitWorld's own family-registry methods counted as pirates. A family implementation
# (`@implement` over an abstract type) generates `TraitWorld._family_registry(::Val{gensym}, ::Val{module name})`
# in the declaring module (TraitWorld-port src/implement.jl:796): TraitWorld's function on Julia's types.
# Prints, per such method, its module and whether TraitWorld.owned_method (strict mode's rule 3, as the census
# reads it) accepts it. In env_p4_pin: Graphs (plain, the GraphInterface family) and NetworkDynamics (P4).
using TraitWorld, Graphs, NetworkDynamics
for m in methods(TraitWorld._family_registry)
    println("FR ", m.module, " ", m.sig, " owned_method=", TraitWorld.owned_method(m), " ", m.file, ":", m.line)
end
println("STRICT ", TraitWorld.STRICT[])
