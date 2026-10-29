# R1 (E-237), part 2b: the workload's two GraphMakie calls (steps f and g) with the scratch GraphMakie over MakieCompat
# (env_r1plot). Prints `R1 gm <what> ok|FAIL <exception>: <message> @ <frames in GraphMakie/MakieCompat/TraitMakie>`.
#     julia --project=env_r1plot scripts/r1_gm_run.jl <out dir>
using TraitMakie, MakieCompat, GraphMakie, Graphs, NetworkLayout, Observables
const OUT = isempty(ARGS) ? joinpath(@__DIR__, "..", "out", "r1") : ARGS[1]; mkpath(OUT)
function frames(bt)
    out = String[]
    for fr in stacktrace(bt)
        f = string(fr.file)
        any(k -> occursin(k, f), ("GraphMakie-r1", "MakieCompat", "TraitMakie/src", "r1_gm_run")) || continue
        push!(out, string(fr.func, "@", basename(f), ":", fr.line))
        length(out) >= 5 && break
    end
    join(out, " < ")
end
function attempt(what, f)
    try
        v = Base.invokelatest(f)
        println("R1 gm ", what, " ok"); flush(stdout)
        return v
    catch err
        msg = first(split(sprint(showerror, err), '\n'))
        println("R1 gm ", what, " FAIL ", nameof(typeof(err)), ": ", first(msg, 260), " @ ", frames(catch_backtrace())); flush(stdout)
        return nothing
    end
end
g = watts_strogatz(20, 4, 0.2; seed = 42)
ω = collect(range(-2.0, 2.0; length = 20)); P = rand(ne(g))
attempt("graphplot(g)", () -> graphplot(g))
r = attempt("graphplot(g; layout, node_color, node_size, edge_color, edge_width, node_attr) (step f)", () ->
    graphplot(g; layout = Spring(seed = 1), node_color = ω, node_size = 14, edge_color = P, edge_width = 2,
              node_attr = (; colorrange = (-3.0, 3.0), colormap = :balance)))
fig = Figure(size = (900, 400)); ax1 = Axis(fig[1, 1])
attempt("graphplot!(ax, g; node_color = Observable) (step g)", () ->
    graphplot!(ax1, g; layout = Spring(seed = 1), node_color = Observable(ω), node_size = 14,
               node_attr = (; colorrange = (-3.0, 3.0), colormap = :balance)))
