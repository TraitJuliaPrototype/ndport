# A compile trace (`--trace-compile=<file> --trace-compile-timing`) of a workload run with NDW_MARK=1,
# split by step: each step's compile time and its largest entries, grouped by the called function.
#   julia scripts/trace_by_step.jl <trace> [step regex, default "changed"] [entries per step, default 25]
trace = ARGS[1]; pat = Regex(get(ARGS, 2, "changed")); top = parse(Int, get(ARGS, 3, "25"))
steps = Dict{String, Vector{Tuple{Float64, String, Bool}}}(); order = String[]; cur = "load"
push!(order, cur); steps[cur] = []
for line in eachline(trace)
    m = match(r"ndw_mark\), (?:Base\.)?Val\{:var\"([^\"]+)\"\}", line)
    if m !== nothing
        global cur = m[1]; cur in order || (push!(order, cur); steps[cur] = []); continue
    end
    t = match(r"^#=\s*([0-9.]+) ms =# precompile\((.*)\)( # recompile)?$", line)
    t === nothing && continue
    push!(steps[cur], (parse(Float64, t[1]), t[2], t[3] !== nothing))
end
fname(sig) = (m = match(r"^Tuple\{([^,{}]+(\{[^}]*\})?)", sig); m === nothing ? sig[1:min(end, 60)] : m[1])
for s in order
    es = steps[s]; tot = sum(first, es; init = 0.0); rec = sum(e -> e[3] ? e[1] : 0.0, es; init = 0.0)
    println(rpad(s, 22), lpad(string(round(tot; digits = 1)), 9), " ms in ", length(es), " compiles (", round(rec; digits = 1), " ms recompiled)")
end
for s in order
    occursin(pat, s) || continue
    es = steps[s]
    println("\n== ", s, ": by function")
    byf = Dict{String, Tuple{Float64, Int}}()
    for (t, sig, _) in es
        k = fname(sig); a = get(byf, k, (0.0, 0)); byf[k] = (a[1] + t, a[2] + 1)
    end
    for (k, (t, n)) in first(sort(collect(byf); by = x -> -x[2][1]), top)
        println(lpad(string(round(t; digits = 1)), 9), " ms ", lpad(string(n), 4), "  ", k[1:min(end, 160)])
    end
    println("== ", s, ": largest")
    for (t, sig, r) in first(sort(es; by = x -> -x[1]), top)
        println(lpad(string(round(t; digits = 1)), 9), " ms ", r ? "R " : "  ", sig[1:min(end, 260)])
    end
end
