# The smallest form of G3's failure (the graph plan, G3; E-154): a do-block whose argument is destructured,
# capturing a variable whose type is not inferred, in a trait module. In env_p4 (TraitWorld 3bebf13).
using TraitWorld, Graphs
@trait_module module Q
using TraitWorld, Graphs
using Graphs: GraphInterface
b1(g::GraphInterface, a) = (x = Base.inferencebarrier([5, 6]); all(zip(a, a)) do (s, d); s ∈ x end)    # bound, destructured, x::Any
b2(g::GraphInterface, a) = (x = Base.inferencebarrier([5, 6]); all(t -> t[1] ∈ x, zip(a, a)))          # bound, not destructured
b3(g::GraphInterface, a) = (x = [5, 6]; all(zip(a, a)) do (s, d); s ∈ x end)                            # bound, destructured, x typed
u1(a) = (x = Base.inferencebarrier([5, 6]); all(zip(a, a)) do (s, d); s ∈ x end)                       # no bound, destructured, x::Any
u2(a) = (x = Base.inferencebarrier([5, 6]); all(((s, d),) -> s ∈ x, zip(a, a)))                         # the same as a lambda
end
module P   # the same in plain code
p1(a) = (x = Base.inferencebarrier([5, 6]); all(zip(a, a)) do (s, d); s ∈ x end)
end
g = watts_strogatz(20, 4, 0.2; seed = 42)
call(f, args...) = f(args...)
for (name, f, args) in (("b1 bound, destructured, captured Any", Q.b1, (g, [5, 6])), ("b2 bound, not destructured, captured Any", Q.b2, (g, [5, 6])),
                        ("b3 bound, destructured, captured typed", Q.b3, (g, [5, 6])), ("u1 trait module, no bound, destructured, captured Any", Q.u1, ([5, 6],)),
                        ("u2 the same as a lambda ((s, d),) -> …", Q.u2, ([5, 6],)), ("p1 plain module, destructured, captured Any", P.p1, ([5, 6],)))
    r = try string(call(f, args...)) catch err; string("FAILS ", nameof(typeof(err)), ": ", first(sprint(showerror, err), 90)) end
    println("G3min ", name, ": ", r)
end
