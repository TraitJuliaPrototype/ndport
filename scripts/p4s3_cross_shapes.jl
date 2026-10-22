# E-166, S3-0 (probe A): the declared types of a bounded function's ordinary arguments against the cost of a
# crossing from a kept value (`compiled_for` from an untyped loop: the table's path). From the planning probe
# `p4s3-planning/cross_probe4.jl`; each line the minimum of three timings of 2·10⁵ calls, an empty batch.
# Run in setting M (NDW_SCRIPT=scripts/p4s3_cross_shapes.jl scripts/run_workload.sh <tag> M).
using TraitWorld, Printf
@trait_module module CR
using TraitWorld
@trait VD begin
    @default_with_dynamic_self
    f1!(m::VD, du::Vector{Float64}, u::Vector{Float64})::Nothing
end
struct Batch; n::Int; end
struct Seq end
const AT = Tuple{Seq, Val{:f}, Vector{Float64}, Vector{Float64}}
body(m, b, du, u) = (for i in 1:b.n; f1!(m, du, u); end; nothing)
ra(m::VD, bs::Vector, k::Int, args::Base.RefValue) = ((ex, fg, du, u) = args[]; body(m, bs[k], du, u))
rb(m::VD, bs::Vector{Batch}, k::Int, args::Base.RefValue) = ((ex, fg, du, u) = args[]; body(m, bs[k], du, u))
rc(m::VD, bs::Vector{Batch}, k::Int, args::Base.RefValue{AT}) = ((ex, fg, du, u) = args[]; body(m, bs[k], du, u))
rd(m::VD, bs::Vector{Batch}, k::Int, args::Base.RefValue{A}) where {A} = ((ex, fg, du, u) = args[]; body(m, bs[k], du, u))
re(m::VD, bs::Vector{Batch}, k::Int, du::Vector{Float64}, u::Vector{Float64}) = body(m, bs[k], du, u)
rf(m::VD, bs::Vector{Batch}, k::Int, du, u) = body(m, bs[k], du, u)
rg(m::VD, bs, k, du, u) = body(m, bs[k], du, u)
rh(m::VD, bs, k, args) = ((ex, fg, du, u) = args[]; body(m, bs[k], du, u))
ri(m::VD, bs, k, ex, fg, inbufs, du, u, t) = body(m, bs[k], du, u)
rj(m::VD, bs::Vector, k::Int, ex, fg, inbufs, du::Vector, u::Vector, t::Real) = body(m, bs[k], du, u)
function la(ks, bs, du, u); args = Ref((Seq(), Val(:f), du, u)); for k in eachindex(ks); ra(compiled_for(ks[k]), bs, k, args); end; nothing; end
function lb(ks, bs, du, u); args = Ref((Seq(), Val(:f), du, u)); for k in eachindex(ks); rb(compiled_for(ks[k]), bs, k, args); end; nothing; end
function lc(ks, bs, du, u); args = Ref((Seq(), Val(:f), du, u)); for k in eachindex(ks); rc(compiled_for(ks[k]), bs, k, args); end; nothing; end
function ld(ks, bs, du, u); args = Ref((Seq(), Val(:f), du, u)); for k in eachindex(ks); rd(compiled_for(ks[k]), bs, k, args); end; nothing; end
le(ks, bs, du, u) = (for k in eachindex(ks); re(compiled_for(ks[k]), bs, k, du, u); end; nothing)
lf(ks, bs, du, u) = (for k in eachindex(ks); rf(compiled_for(ks[k]), bs, k, du, u); end; nothing)
lg(ks, bs, du, u) = (for k in eachindex(ks); rg(compiled_for(ks[k]), bs, k, du, u); end; nothing)
function lh(ks, bs, du, u); args = Ref((Seq(), Val(:f), du, u)); for k in eachindex(ks); rh(compiled_for(ks[k]), bs, k, args); end; nothing; end
li(ks, bs, du, u) = (for k in eachindex(ks); ri(compiled_for(ks[k]), bs, k, Seq(), Val(:f), (du, nothing), du, u, 0.3); end; nothing)
lj(ks, bs, du, u) = (for k in eachindex(ks); rj(compiled_for(ks[k]), bs, k, Seq(), Val(:f), (du, nothing), du, u, 0.3); end; nothing)
struct Fam{F}; f::F; end
f1!(m::Fam, du, u) = (m.f(du, u); nothing)
@implement VD M where {M <: Fam}
end
userf!(du, u) = (du[1] += u[1]; nothing)
function tm(f, n = 200_000)
    f(); f(); t0 = time_ns(); for _ in 1:n; f(); end; (time_ns() - t0) / n
end
println("TraitWorld ", pkgversion(TraitWorld), " ", pathof(TraitWorld))
du, u = zeros(4), ones(4)
ks = [Kept{CR.VD}(CR.Fam(userf!))]
bs = [CR.Batch(0)]
for (name, l) in (("A1 bs::Vector, k::Int, args::RefValue (ND's shape)", CR.la), ("A2 bs::Vector{Batch}, args::RefValue", CR.lb),
                  ("A3 bs::Vector{Batch}, args::RefValue{AT} (concrete)", CR.lc), ("A4 bs::Vector{Batch}, args::RefValue{A} where A", CR.ld),
                  ("A5 bs::Vector{Batch}, du::Vector{Float64}, u::Vector{Float64}", CR.le), ("A6 bs::Vector{Batch}, du, u", CR.lf),
                  ("A7 bs, k, du, u (all untyped)", CR.lg), ("A8 bs, k, args (untyped, a Ref)", CR.lh),
                  ("A9 nine arguments, untyped", CR.li), ("A10 nine arguments, abstract annotations", CR.lj))
    f() = l(ks, bs, du, u)
    try
        @printf("%-62s empty batch ns=%.1f allocs=%d\n", name, minimum(tm(f) for _ in 1:3), @allocations(f()))
    catch err
        @printf("%-62s error %s\n", name, sprint(showerror, err)[1:min(end, 160)])
    end
end
