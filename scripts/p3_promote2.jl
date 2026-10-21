# P3 diagnostic: which step of Static.jl's promotion is a run-time site in a trait module.
using TraitWorld, NetworkDynamics
const Static = NetworkDynamics.Static
@trait_module module PT
using ..Static: StaticInt, StaticNumber
pt() = promote_type(Int, StaticInt{2})
pr() = Base.promote_rule(StaticInt{2}, Int)
el() = eltype(StaticInt{2})
cv(x::StaticInt{2}) = convert(Int, x)
pm(x::Int) = Base.promote(x, StaticInt(2))
nospec(@nospecialize(T::Type{<:StaticNumber})) = eltype(T)
callns() = nospec(StaticInt{2})
end
for f in (PT.pt, PT.pr, PT.el, PT.cv, PT.pm, PT.callns)
    args = f === PT.cv ? (Static.StaticInt{2},) : f === PT.pm ? (Int,) : ()
    r = TraitWorld.fully_typed(f, args)
    println(rpad(string(nameof(f)), 8), TraitWorld.isfullytyped(r) ? "fully typed" : "$(length(r.sites)) sites")
    for h in first(r.sites, 3); println("    ", h.kind, " ", h.line, " ", h.callee, " ", h.argtypes, " in ", h.caller); end
end
