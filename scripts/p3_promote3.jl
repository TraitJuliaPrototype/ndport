# P3 diagnostic: the return types of Static.jl's promotion under plain inference, facts inference with
# the default owner (as under `all`) and facts inference with the facts owner (as a trait module's).
using TraitWorld, NetworkDynamics
const Static = NetworkDynamics.Static
const C = Base.Compiler
SI = Static.StaticInt{2}
interps = [("plain", C.NativeInterpreter(; facts = false)),
           ("facts/nothing", C.NativeInterpreter(; facts = true)),
           ("facts/:facts", C.NativeInterpreter(; facts = true, owner = C.FACTS_OWNER))]
calls = [("promote_rule(SI, Int)", Base.promote_rule, (Type{SI}, Type{Int})),
         ("promote_rule(Int, SI)", Base.promote_rule, (Type{Int}, Type{SI})),
         ("promote_type(Int, SI)", Base.promote_type, (Type{Int}, Type{SI})),
         ("typejoin(Int, SI)", Base.typejoin, (Type{Int}, Type{SI})),
         ("*(Int, SI)", *, (Int, SI))]
for (cname, f, tt) in calls, (iname, interp) in interps
    rt = try Base.return_types(f, tt; interp)[1] catch e; sprint(showerror, e)[1:min(end, 80)] end
    println(rpad(cname, 24), rpad(iname, 16), rt)
end
