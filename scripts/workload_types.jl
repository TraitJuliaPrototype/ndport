# The `usertype` pass's components (the step-3 plan §3.3, part 3b; R6, E-247): a user's own types implementing
# NetworkDynamics' traits `VertexDynamics` and `EdgeDynamics`, with the arithmetic of `swing!` and `line!` under
# `AntiSymmetric` (workload_steps.jl), passed to the records by `dynamics = x`. Idiomatic trait code from the plain
# module NDW, for its own types. Included into NDW on the ports only (NDW_STACK=ports): upstream has no traits.
import NetworkDynamics as ND
using NetworkDynamics: PureStateMap, PureFeedForward
using TraitWorld: @implement

"The swing equations of `swing!` as a type: states δ, ω; parameters P, I, γ; the output δ."
struct Swing end
ND.hasf(::Swing) = true
ND.fftype(::Swing) = PureStateMap()                    # the output is the first state, as g = 1
ND.pdim(::Swing) = 3
function ND.vertexf!(::Swing, dv, v, ins, p, t)
    P, I, γ = p
    dv[1] = v[2]
    dv[2] = (P - γ * v[2] + ins[1][1]) / I
    nothing
end
ND.vertexg!(::Swing, out, v, ins, p, t) = (out[1] = v[1]; nothing)
@implement ND.ComponentDynamics Swing
@implement ND.VertexDynamics Swing

"The static line of `line!` under `AntiSymmetric` as a type: parameters K, limit; the flow at each end."
struct Line end
ND.hasf(::Line) = false                                # a static edge
ND.fftype(::Line) = PureFeedForward()
ND.pdim(::Line) = 2
ND.edgef!(::Line, du, u, ins, p, t) = nothing
function ND.edgeg!(::Line, osrc, odst, u, ins, p, t)
    odst[1] = p[1] * sin(ins[1][1] - ins[2][1])        # line!: K * sin(v_s[1] - v_d[1])
    osrc[1] = -odst[1]                                 # AntiSymmetric
    nothing
end
@implement ND.ComponentDynamics Line
@implement ND.EdgeDynamics Line

# the function model's output symbols (src and dst), so that every symbolic index of steps c–g names the same output
const OUTSYM_OF_ANTISYMMETRIC = EdgeModel(g = AntiSymmetric(line!), outsym = :P, psym = [:K => 6.0, :limit => 1.0]).outsym

"Step a of the `usertype` pass: the records of `Swing` and `Line`."
function usertype_models()
    vertex = VertexModel(dynamics = Swing(), sym = [:δ, :ω], outsym = [:δ], psym = [:P_ref, :I => 1, :γ => 0.1],
                         allow_output_sym_clash = true)   # the output names a state, as a StateMask's does implicitly
    edge = EdgeModel(dynamics = Line(), outsym = OUTSYM_OF_ANTISYMMETRIC, psym = [:K => 6.0, :limit => 1.0])
    (; vertex, edge)
end
