# P3 diagnostic: does a direct promotion rule for StaticInt (no fall back to typejoin) make Static.jl's
# arithmetic fully typed in a trait module? (A diagnosis only: the rule is defined here, not in Static.)
using TraitWorld, NetworkDynamics
const Static = NetworkDynamics.Static
const C = Base.Compiler
const SI = Static.StaticInt{2}
fo = C.NativeInterpreter(; facts = true, owner = C.FACTS_OWNER)
println("before: promote_type ", Base.return_types(promote_type, (Type{Int}, Type{SI}); interp = fo)[1],
        ", * ", Base.return_types(*, (Int, SI); interp = fo)[1])
Base.promote_rule(::Type{<:Static.StaticInt}, ::Type{Int}) = Int
println("after:  promote_type ", Base.return_types(promote_type, (Type{Int}, Type{SI}); interp = fo)[1],
        ", * ", Base.return_types(*, (Int, SI); interp = fo)[1], ", + ", Base.return_types(+, (Int, SI); interp = fo)[1],
        "; plain * ", Base.return_types(*, (Int, SI))[1], "; value ", 3 * SI())
@trait_module module PT2
using ..Static: StaticInt
mulS(x::Int) = x * StaticInt(2)
end
r = TraitWorld.fully_typed(PT2.mulS, (Int,)); PT2.mulS(1)
t = @elapsed for i in 1:10^5; PT2.mulS(i); end
println("trait mulS: ", TraitWorld.isfullytyped(r) ? "fully typed" : "$(length(r.sites)) sites", ", ", round(t * 1e4, digits = 1), " ns per call")
