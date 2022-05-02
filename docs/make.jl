using ConcurrencyGraph
using Documenter

DocMeta.setdocmeta!(ConcurrencyGraph, :DocTestSetup, :(using ConcurrencyGraph); recursive=true)

makedocs(;
    modules=[ConcurrencyGraph],
    authors="Cédric BELMANT",
    repo="https://github.com/serenity4/ConcurrencyGraph.jl/blob/{commit}{path}#{line}",
    sitename="ConcurrencyGraph.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://serenity4.github.io/ConcurrencyGraph.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/serenity4/ConcurrencyGraph.jl",
    devbranch="main",
)
