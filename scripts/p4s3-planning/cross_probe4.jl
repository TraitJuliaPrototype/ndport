# Diagnostic for the step-3 plan: the declared types of a bounded function's ordinary arguments against the
# cost of a crossing from a kept value (compiled_for, the table).
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
function la(ks, bs, du, u); args = Ref((Seq(), Val(:f), du, u)); for k in eachindex(ks); ra(compiled_for(ks[k]), bs, k, args); end; nothing; end
function lb(ks, bs, du, u); args = Ref((Seq(), Val(:f), du, u)); for k in eachindex(ks); rb(compiled_for(ks[k]), bs, k, args); end; nothing; end
function lc(ks, bs, du, u); args = Ref((Seq(), Val(:f), du, u)); for k in eachindex(ks); rc(compiled_for(ks[k]), bs, k, args); end; nothing; end
function ld(ks, bs, du, u); args = Ref((Seq(), Val(:f), du, u)); for k in eachindex(ks); rd(compiled_for(ks[k]), bs, k, args); end; nothing; end
le(ks, bs, du, u) = (for k in eachindex(ks); re(compiled_for(ks[k]), bs, k, du, u); end; nothing)
lf(ks, bs, du, u) = (for k in eachindex(ks); rf(compiled_for(ks[k]), bs, k, du, u); end; nothing)
lg(ks, bs, du, u) = (for k in eachindex(ks); rg(compiled_for(ks[k]), bs, k, du, u); end; nothing)
rh(m::VD, bs, k, args) = ((ex, fg, du, u) = args[]; body(m, bs[k], du, u))
function lh(ks, bs, du, u); args = Ref((Seq(), Val(:f), du, u)); for k in eachindex(ks); rh(compiled_for(ks[k]), bs, k, args); end; nothing; end
ri(m::VD, bs, k, ex, fg, inbufs, du, u, t) = body(m, bs[k], du, u)
li(ks, bs, du, u) = (for k in eachindex(ks); ri(compiled_for(ks[k]), bs, k, Seq(), Val(:f), (du, nothing), du, u, 0.3); end; nothing)
struct Fam{F}; f::F; end
f1!(m::Fam, du, u) = (m.f(du, u); nothing)
@implement VD M where {M <: Fam}
end
userf!(du, u) = (du[1] += u[1]; nothing)
function tm(f, n = 200_000)
    f(); f(); t0 = time_ns(); for _ in 1:n; f(); end; (time_ns() - t0) / n
end
du, u = zeros(4), ones(4)
ks = [Kept{CR.VD}(CR.Fam(userf!))]
bs = [CR.Batch(0)]
for (name, l) in (("bs::Vector, args::RefValue", CR.la), ("bs::Vector{Batch}, args::RefValue", CR.lb),
                  ("bs::Vector{Batch}, args::RefValue{AT}", CR.lc), ("bs::Vector{Batch}, args::RefValue{A} where A", CR.ld),
                  ("bs::Vector{Batch}, du::Vector{Float64}, u::Vector{Float64}", CR.le), ("bs::Vector{Batch}, du, u (untyped)", CR.lf),
                  ("all ordinary untyped", CR.lg), ("untyped bs, k, args (a Ref)", CR.lh),
                  ("untyped, the pass's arguments one by one (a tuple, a Float64)", CR.li))
    f() = l(ks, bs, du, u)
    @printf("%-58s empty batch ns=%.0f allocs=%d\n", name, tm(f), @allocations(f()))
end
