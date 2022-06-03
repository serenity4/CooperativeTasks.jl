# Execute any of the following during interactive debugging.

ConcurrencyGraph.init()
ConcurrencyGraph.manage_messages()

ENV["JULIA_DEBUG"] = "ConcurrencyGraph"
ENV["JULIA_DEBUG"] = ""
