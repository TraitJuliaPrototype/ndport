# R7 (E-249): the census of pirates in setting PT, one session, after the workload's `first` pass (a–g) and the
# `usertype` pass's steps a–e, so that methods TraitWorld generates at first use are counted too.
#     R1_STRICT=1 NDW_LOGDIR=logs/r7 NDW_JLNAME=ndr7s scripts/r5_run.sh census-1 scripts/r7_census.jl
# Per loaded package (root modules; extensions as `CX`): `CP <pkg> wrapped=<0|1> methods=<n> pirates=<k> joint=<j>`,
# where a pirate is a method TraitWorld.owned_method refuses (strict mode's rule 3, joint owners counted).
# One `CPIRATE <pkg> <sig> <file:line> | fowner=… towners=…` per pirate. P6's census (p6_census.jl) without its control
# and profile. The census reads TraitWorld's internals (`_sig_alternatives`, `_extension_parent`, `_joint_names`):
# a harness, not the port.
ENV["NDW_API"] = "ports"; ENV["NDW_STACK"] = "ports"
using TraitWorld, Graphs, NetworkDynamics, TraitDifferentialEquations, SymbolicIndexingInterface
using MakieCompat, GraphMakie, Observables
println("STRICT ", TraitWorld.STRICT[] ? "on" : "off")
include(joinpath(@__DIR__, "workload_steps.jl"))
Base.include(NDW, joinpath(@__DIR__, "workload_plot.jl"))
mkpath(NDW.OUT)
untimed(name, f) = Base.invokelatest(f)
Base.invokelatest(NDW.run_pass, untimed, "first", :swing)
Base.invokelatest(NDW.run_sim, untimed, "usertype", :swing_type)

const TW = TraitWorld
ownername(o) = o isa Module ? string(nameof(o)) : string(o)
function fowner(m::Method)
    ft = Base.unwrap_unionall(m.sig)
    ft isa DataType && !isempty(ft.parameters) || return "?"
    f = ft.parameters[1]
    f isa DataType ? ownername(TW.owner(f.name.module)) : "?"
end
towners(m::Method) = join(sort!(unique!([ownername(o) for o in TW.sig_owners(Tuple{Base.unwrap_unionall(m.sig).parameters[2:end]...})])), ",")
"rule 3 without joint owners: the definer itself owns the function or a type in every alternative"
function owned_alone(m::Method)
    definer = TW.owner(m.module)
    for s in TW._sig_alternatives(m.sig)
        any(o -> o === definer, TW.sig_owners(s)) || return false
    end
    return true
end
struct Row; methods::Int; pirates::Vector{String}; joint::Int; end
rows = Dict{Module,Row}()
Base.visit(Core.methodtable) do m
    m isa Method || return
    r = Base.moduleroot(m.module)
    (r === Base || r === Core || r === Main || TW.owner(r) === :Julia) && return
    row = get!(() -> Row(0, String[], 0), rows, r)
    own = TW.owned_method(m)
    pir = own ? String[] : ["$(m.sig) $(m.file):$(m.line) | fowner=$(fowner(m)) towners=$(try towners(m) catch; "?" end)"]
    rows[r] = Row(row.methods + 1, append!(row.pirates, pir), row.joint + (own && !owned_alone(m)))
end
isext(r) = TW._extension_parent(r) !== nothing
wrapped(r) = TW.is_trait_world(r) ? 1 : 0
pkgs = sort!(collect(keys(rows)); by = r -> (isext(r), string(nameof(r))))
for r in pkgs
    row = rows[r]
    head = isext(r) ? "CX $(nameof(r)) parent=$(nameof(TW._extension_parent(r)))" : "CP $(nameof(r))"
    println(head, " wrapped=", wrapped(r), " methods=", row.methods, " pirates=", length(row.pirates), " joint=", row.joint)
end
println("C wrapped: ", join([string(nameof(r)) for r in pkgs if wrapped(r) == 1 && !isext(r)], " "))
println("C pirates in wrapped packages: ", sum((length(rows[r].pirates) for r in pkgs if wrapped(r) == 1 || (isext(r) && TW.is_trait_world(TW._extension_parent(r)))); init = 0))
println("C joint owners declared: ", join(["$(nameof(r)) => $(TW._joint_names(r))" for r in pkgs if !isempty(TW._joint_names(r))], "; "))
for r in pkgs, s in sort(rows[r].pirates); println("CPIRATE ", nameof(r), " ", s); end
exit(0)
