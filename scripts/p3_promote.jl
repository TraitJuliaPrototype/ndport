# P3 diagnostic: Base's promotion with Static.jl's StaticInt, in a trait module (product setting) and
# in plain code; `fully_typed` and the time of a loop.
#     julia --project=env_p3 scripts/p3_promote.jl          (product setting)
#     julia -J …/facts/sys.so --project=env_p3 scripts/p3_promote.jl   (all)
using TraitWorld, NetworkDynamics
const Static = NetworkDynamics.Static
@trait_module module PromoT
using ..Static: StaticInt
mulS(x::Int) = x * StaticInt(2)
addS(x::Int) = x + StaticInt(2)
struct MyN <: Number; v::Int; end
Base.promote_rule(::Type{MyN}, ::Type{Int}) = MyN
Base.convert(::Type{MyN}, x::Int) = MyN(x)
Base.:*(a::MyN, b::MyN) = MyN(a.v * b.v)
mulM(x::Int) = x * MyN(2)
loop(f, n) = (s = 0; for i in 1:n; s += Int(f(i)) ; end; s)
end
module PromoP
using ..Static: StaticInt
mulS(x::Int) = x * StaticInt(2)
end
Base.Int(m::PromoT.MyN) = m.v
for (name, f, T) in [("trait mulS", PromoT.mulS, Int), ("trait addS", PromoT.addS, Int), ("trait mulM", PromoT.mulM, Int), ("plain mulS", PromoP.mulS, Int)]
    r = TraitWorld.fully_typed(f, (T,))
    f(1); t = @elapsed for i in 1:10^5; f(i); end
    println(rpad(name, 12), " fully typed: ", TraitWorld.isfullytyped(r), " (", length(r.sites), " sites)  ", round(t * 1e4, digits = 2), " µs per call; ", Base.return_types(f, (T,)))
    for h in first(r.sites, 4); println("    ", h.line, " ", h.callee, " ", h.argtypes, " in ", h.caller); end
end
