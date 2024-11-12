using CooperativeTasks
using Documenter

DocMeta.setdocmeta!(CooperativeTasks, :DocTestSetup, :(using CooperativeTasks); recursive=true)

makedocs(;
    modules=[CooperativeTasks],
    authors="Cédric BELMANT",
    repo="https://github.com/serenity4/CooperativeTasks.jl/blob/{commit}{path}#{line}",
    sitename="CooperativeTasks.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://serenity4.github.io/CooperativeTasks.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Examples" => "examples.md",
        "API" => "api.md",
    ],
    checkdocs=:exports,
)

deploydocs(;
    repo="github.com/serenity4/CooperativeTasks.jl",
    devbranch="main",
)
