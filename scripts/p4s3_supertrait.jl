# E-166, S3-0 (c): the plan's three traits in a scratch trait module (a supertrait without parameters, two subtraits),
# a family of all three over a stand-in for FunctionDynamics, a one-line `Swing` of two traits from a plain module,
# and the supertrait's operations (`hasf`, `pdim`, `extdim`'s default) reached through a `VertexDynamics` bound:
# from an untyped caller via `compiled_for(Kept{VertexDynamics}(member))` (the table) and from a typed caller.
# Then a member whose supertrait family is missing: what is refused, and where.
using TraitWorld, Printf
@trait_module module CDp
using TraitWorld
@trait ComponentDynamics begin
    @default_with_dynamic_self
    hasf(m::ComponentDynamics)::Bool
    pdim(m::ComponentDynamics)::Int
    extdim(m::ComponentDynamics)::Int = 0
end
@trait VertexDynamics <: ComponentDynamics begin
    @default_with_dynamic_self
    vertexf!(m::VertexDynamics, du, u, ins, p, t)::Nothing
    vertexg!(m::VertexDynamics, out, u, ins, p, t)::Nothing
end
@trait EdgeDynamics <: ComponentDynamics begin
    @default_with_dynamic_self
    edgef!(m::EdgeDynamics, du, u, ins, p, t)::Nothing
    edgeg!(m::EdgeDynamics, osrc, odst, u, ins, p, t)::Nothing
end
struct FD{F,G}; f::F; g::G; pd::Int; end            # the stand-in for FunctionDynamics
hasf(d::FD) = d.f !== nothing
pdim(d::FD) = d.pd
vertexf!(d::FD, du, u, ins, p, t) = (d.f(du, u, ins..., p, t); nothing)
vertexg!(d::FD, out, u, ins, p, t) = (d.g(out, u, ins..., p, t); nothing)
edgef!(d::FD, du, u, ins, p, t) = (d.f(du, u, ins..., p, t); nothing)
edgeg!(d::FD, osrc, odst, u, ins, p, t) = (d.g(osrc, odst, u, ins..., p, t); nothing)
@implement ComponentDynamics D where {D <: FD}
@implement VertexDynamics D where {D <: FD}
@implement EdgeDynamics D where {D <: FD}
# a member whose ComponentDynamics family is missing
struct GD{F}; f::F; end
vertexf!(d::GD, du, u, ins, p, t) = (d.f(du, u, ins..., p, t); nothing)
vertexg!(d::GD, out, u, ins, p, t) = nothing
probe(m::VertexDynamics, du, u, ins, p, t) = (vertexf!(m, du, u, ins, p, t); (hasf(m), pdim(m), extdim(m)))
cross(ks, du, u, ins, p, t) = (r = nothing; for k in ks; r = probe(compiled_for(k), du, u, ins, p, t); end; r)
end
module Plain
import ..CDp
using TraitWorld: @implement
struct Swing end
CDp.hasf(::Swing) = true
CDp.pdim(::Swing) = 3
CDp.vertexf!(::Swing, dv, v, ins, p, t) = (dv[1] = v[2]; dv[2] = (p[1] - p[3] * v[2] + ins[1][1]) / p[2]; nothing)
CDp.vertexg!(::Swing, out, v, ins, p, t) = (out[1] = v[1]; nothing)
@implement CDp.ComponentDynamics Swing
@implement CDp.VertexDynamics Swing
end
swingf!(dv, v, e, p, t) = (dv[1] = v[2]; dv[2] = (p[1] - p[3] * v[2] + e[1]) / p[2]; nothing)
du, u, ins, p = zeros(2), [0.1, 0.2], ([0.5],), (1.0, 1.0, 0.1)
show1(name, f) = try
    r = f(); println("C ", name, " => ", r, "  du=", du)
catch err
    println("C ", name, " ERROR ", typeof(err), ": ", first(sprint(showerror, err), 400))
end
fdm = CDp.FD(swingf!, nothing, 3)
show1("member conforms to VertexDynamics", () -> conforms(typeof(fdm), CDp.VertexDynamics))
show1("member conforms to ComponentDynamics", () -> conforms(typeof(fdm), CDp.ComponentDynamics))
show1("family member, untyped caller (table)", () -> CDp.cross(Any[Kept{CDp.VertexDynamics}(fdm)], du, u, ins, p, 0.0))
show1("family member, Kept vector (table)", () -> CDp.cross([Kept{CDp.VertexDynamics}(fdm)], du, u, ins, p, 0.0))
show1("family member, typed caller", () -> CDp.probe(fdm, du, u, ins, p, 0.0))
show1("Swing (plain module, one-line), table", () -> CDp.cross([Kept{CDp.VertexDynamics}(Plain.Swing())], du, u, ins, p, 0.0))
show1("Swing, typed caller", () -> CDp.probe(Plain.Swing(), du, u, ins, p, 0.0))
show1("Swing conforms to VertexDynamics", () -> conforms(Plain.Swing, CDp.VertexDynamics))
gdm = CDp.GD(swingf!)
show1("no supertrait family: @implement VertexDynamics D where D<:GD", () -> (Core.eval(CDp, :(@implement VertexDynamics D where {D <: GD})); :declared))
show1("no supertrait family: conforms", () -> Base.invokelatest(conforms, typeof(gdm), CDp.VertexDynamics))
show1("no supertrait family: Kept", () -> Base.invokelatest(() -> Kept{CDp.VertexDynamics}(gdm)))
show1("no supertrait family: table", () -> Base.invokelatest(() -> CDp.cross([Kept{CDp.VertexDynamics}(gdm)], du, u, ins, p, 0.0)))
show1("no supertrait family: typed caller", () -> Base.invokelatest(() -> CDp.probe(gdm, du, u, ins, p, 0.0)))
kk = [Kept{CDp.VertexDynamics}(fdm)]; ks = [Kept{CDp.VertexDynamics}(Plain.Swing())]
tm(f, n = 200_000) = (f(); f(); t0 = time_ns(); for _ in 1:n; f(); end; (time_ns() - t0) / n)
@printf("C crossing, family member ns=%.1f allocs=%d\n", minimum(tm(() -> CDp.cross(kk, du, u, ins, p, 0.0)) for _ in 1:3), @allocations(CDp.cross(kk, du, u, ins, p, 0.0)))
@printf("C crossing, Swing ns=%.1f allocs=%d\n", minimum(tm(() -> CDp.cross(ks, du, u, ins, p, 0.0)) for _ in 1:3), @allocations(CDp.cross(ks, du, u, ins, p, 0.0)))
