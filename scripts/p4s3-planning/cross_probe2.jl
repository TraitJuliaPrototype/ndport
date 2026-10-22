# Diagnostic for the step-3 plan: which part of NetworkDynamics' batch function's shape makes its crossing
# cost ~165 ns where a minimal bounded function crosses in ~40 ns.
using TraitWorld, Printf
@trait_module module CQ
using TraitWorld
@trait VD begin
    @default_with_dynamic_self
    f1!(m::VD, du::Vector{Float64}, u::Vector{Float64})::Nothing
end
struct Batch; n::Int; end
struct Seq end; struct Thr end
# (1) minimal; (2) ND's arguments: vector of batches, index, Ref of the pass's arguments; (3) plus a Threads branch
run1!(m::VD, du::Vector{Float64}, u::Vector{Float64}, n::Int) = (for i in 1:n; f1!(m, du, u); end; nothing)
function run2!(m::VD, bs::Vector, k::Int, args::Base.RefValue)
    (ex, fg, du, u) = args[]
    b = bs[k]
    for i in 1:b.n; f1!(m, du, u); end
    nothing
end
function run3!(m::VD, bs::Vector, k::Int, args::Base.RefValue)
    (ex, fg, du, u) = args[]
    b = bs[k]
    if ex isa Thr
        Threads.@threads for i in 1:b.n; f1!(m, du, u); end
    else
        for i in 1:b.n; f1!(m, du, u); end
    end
    nothing
end
l1!(ks, du, u, n) = (for k in ks; run1!(compiled_for(k), du, u, n); end; nothing)
function l2!(ks, bs, du, u)
    args = Ref((Seq(), Val(:f), du, u))
    for k in eachindex(ks); run2!(compiled_for(ks[k]), bs, k, args); end; nothing
end
function l3!(ks, bs, du, u)
    args = Ref((Seq(), Val(:f), du, u))
    for k in eachindex(ks); run3!(compiled_for(ks[k]), bs, k, args); end; nothing
end
struct Fam{F}; f::F; end
f1!(m::Fam, du, u) = (m.f(du, u); nothing)
@implement VD M where {M <: Fam}
end
userf!(du, u) = (du[1] += u[1]; nothing)
function tm(f, n = 200_000)
    f(); f(); t0 = time_ns(); for _ in 1:n; f(); end; (time_ns() - t0) / n
end
du, u = zeros(4), ones(4)
ks = [Kept{CQ.VD}(CQ.Fam(userf!))]
bs0, bs20 = [CQ.Batch(0)], [CQ.Batch(20)]
for (n, bs) in ((0, bs0), (20, bs20))
    a() = CQ.l1!(ks, du, u, n); b() = CQ.l2!(ks, bs, du, u); c() = CQ.l3!(ks, bs, du, u)
    @printf("n=%2d minimal ns=%.0f allocs=%d | ND's arguments ns=%.0f allocs=%d | plus Threads branch ns=%.0f allocs=%d\n",
            n, tm(a), @allocations(a()), tm(b), @allocations(b()), tm(c), @allocations(c()))
end
