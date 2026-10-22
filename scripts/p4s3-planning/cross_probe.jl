# Diagnostic for the step-3 plan: a per-batch crossing from trait code into (a) a family member and (b) a
# declared type, by compiled_for + a bounded function, and by an operation (with a default) on the kept value.
using TraitWorld, Printf
@trait_module module CP
using TraitWorld
@trait VD begin
    @default_with_dynamic_self
    f1!(m::VD, du::Vector{Float64}, u::Vector{Float64})::Nothing
    runb!(m::VD, du::Vector{Float64}, u::Vector{Float64}, n::Int)::Nothing = (for i in 1:n; f1!(m, du, u); end; nothing)
end
runc!(m::VD, du::Vector{Float64}, u::Vector{Float64}, n::Int) = (for i in 1:n; f1!(m, du, u); end; nothing)
loop_cf!(ks, du, u, n) = (for k in ks; runc!(compiled_for(k), du, u, n); end; nothing)
loop_op!(ks, du, u, n) = (for k in ks; runb!(k, du, u, n); end; nothing)
struct Fam{F}; f::F; end
f1!(m::Fam, du, u) = (m.f(du, u); nothing)
@implement VD M where {M <: Fam}
end
struct Decl end
CP.f1!(m::Decl, du, u) = (du[1] += u[1]; nothing)
@implement CP.VD Decl
userf!(du, u) = (du[1] += u[1]; nothing)
function tm(f, n = 200_000)
    f(); f(); t0 = time_ns(); for _ in 1:n; f(); end; (time_ns() - t0) / n
end
du, u = zeros(4), ones(4)
for (name, x) in (("family member", CP.Fam(userf!)), ("declared type", Decl()))
    ks = [Kept{CP.VD}(x)]
    for n in (0, 20)
        a() = CP.loop_cf!(ks, du, u, n); b() = CP.loop_op!(ks, du, u, n)
        @printf("%-14s n=%2d  compiled_for+bounded ns=%.0f allocs=%d | operation on the kept value ns=%.0f allocs=%d\n",
                name, n, tm(a), @allocations(a()), tm(b), @allocations(b()))
    end
end
