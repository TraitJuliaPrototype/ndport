# The attribution run (the P1 plan §3.3; E-141's instrument, experiments/loadcosts/tde_diag.jl, cut
# down): for each step, the CodeInstances it created, by the root module of their method and by owner,
# and how many replace an invalidated CodeInstance ("again"). Diagnostic: the snapshots cost time,
# so its times are not measurements. Included by workload.jl when NDW_DIAG=1.
module NDWDiag
function snapshot()
    valid = Set{Core.CodeInstance}(); invalid = Set{Tuple{Core.MethodInstance,Any}}()
    Base.visit(Core.methodtable) do m
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance || continue
            isdefined(mi, :cache) || continue
            ci = mi.cache
            while true
                ci.max_world == typemax(UInt) ? push!(valid, ci) : push!(invalid, (mi, ci.owner))
                isdefined(ci, :next) || break; ci = ci.next
            end
        end
    end
    valid, invalid
end
mi_of(ci) = (d = ci.def; d isa Core.MethodInstance ? d : d.def)
root(ci) = (m = mi_of(ci).def; m isa Method ? nameof(Base.moduleroot(m.module)) : :toplevel)
tally(f, xs) = (d = Dict{Any,Int}(); for x in xs; k = f(x); d[k] = get(d, k, 0) + 1; end; sort!(collect(d); by = x -> -last(x)))
fmt(ps; n = 14) = join(["$(k)=$(v)" for (k, v) in ps[1:min(end, n)]], " ")
snapshot()
"The CodeInstances of `v0` no longer valid, by owner and by the root module of their method."
function lost(v0)
    gone = [ci for ci in v0 if ci.max_world != typemax(UInt)]
    (; n = length(gone), of = length(v0),
       owners = fmt(tally(ci -> ci.owner === nothing ? "nothing" : repr(ci.owner), gone)),
       modules = fmt(tally(root, gone)))
end
"Wrap `timed`: the step's new CodeInstances, printed as `C <pass> <step> ...`."
function wrap(timed, pass)
    (name, f) -> begin
        v0, _ = snapshot()
        r = timed(name, f)
        v1, inv1 = snapshot()
        new = setdiff(v1, v0)
        again = count(ci -> (mi_of(ci), ci.owner) in inv1, new)
        println("C ", pass[], " ", name, " new=", length(new), " again=", again,
                " owners: ", fmt(tally(ci -> ci.owner === nothing ? "nothing" : repr(ci.owner), new)),
                " | modules: ", fmt(tally(root, new)))
        r
    end
end
end
