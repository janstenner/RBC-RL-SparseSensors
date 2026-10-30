using Dates
using JLD2

include(joinpath(@__DIR__, "GOSensitivityStudy.jl"))
using .GOSensitivityStudy

function prepare_manifest_usage(io::IO = stdout)
    println(io, "Usage: julia --project=. prepare_study_manifest.jl --output PATH [--protocol all|fixed|varying] [--results-dir PATH]")
end

function parse_arguments(arguments)
    values = Dict("output" => nothing, "protocol" => "all", "results_dir" => joinpath(@__DIR__, "results", "study"))
    index = 1
    while index <= length(arguments)
        argument = arguments[index]
        argument == "--help" && (prepare_manifest_usage(); return nothing)
        startswith(argument, "--") || error("Unknown argument '$argument'.")
        index == length(arguments) && error("Missing value after $argument.")
        key = replace(argument[3:end], "-" => "_")
        haskey(values, key) || error("Unknown option '$argument'.")
        values[key] = arguments[index + 1]
        index += 2
    end
    isnothing(values["output"]) && error("--output is required.")
    protocol = Symbol(lowercase(values["protocol"]))
    protocol in (:all, :fixed, :varying) || error("--protocol must be all, fixed, or varying.")
    return (output = abspath(values["output"]), protocol, results_root = abspath(values["results_dir"]))
end

function prepare_study_manifest(options)
    jobs = study_jobs(options.protocol)
    analyses = analysis_jobs(options.protocol)
    length(unique(job.id for job in jobs)) == length(jobs) || error("Duplicate training run IDs.")
    length(unique(job.relative_path for job in jobs)) == length(jobs) || error("Duplicate training paths.")
    all(short_path_components, jobs) || error("A training path contains a long component.")
    atomic_save(
        options.output;
        schema_version = GO_SENSITIVITY_SCHEMA_VERSION,
        experiment = :go_sensitivity_sc,
        scientific_scope = :go_sensitivity,
        grouping = :separate_channels,
        group_channels = false,
        master_seed = GO_SENSITIVITY_MASTER_SEED,
        seed_plan = [seed_plan(replicate) for replicate in GO_SENSITIVITY_REPLICATES],
        strengths = Dict(protocol => collect(values) for (protocol, values) in GO_SENSITIVITY_STRENGTHS),
        gr_strengths = copy(GO_SENSITIVITY_GR_STRENGTH),
        quality_thresholds = copy(GO_SENSITIVITY_QUALITY_THRESHOLDS),
        jobs,
        analysis_jobs = analyses,
        results_root = options.results_root,
        created_at = string(Dates.now()),
    )
    return (jobs, analyses)
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    options = parse_arguments(ARGS)
    if !isnothing(options)
        jobs, analyses = prepare_study_manifest(options)
        println("Wrote $(length(jobs)) training jobs and $(length(analyses)) analysis jobs to $(options.output)")
    end
end
