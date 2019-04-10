using Pkg
Pkg.add("Documenter")

using Documenter, Caching

# Make src directory available
push!(LOAD_PATH,"../src/")

# Make documentation
makedocs(
    modules = [Caching],
    format = :html,
    sitename = "Caching.jl",
    authors = "Corneliu Cofaru, 0x0α Research",
    clean = true,
    debug = true,
    pages = [
        "Introduction" => "index.md",
        "Usage examples" => "examples.md",
        "API Reference" => "api.md",
    ]
)

# Deploy documentation
deploydocs(
    repo = "github.com/zgornel/Caching.jl.git",
    target = "build",
    deps = nothing,
    make = nothing
)
