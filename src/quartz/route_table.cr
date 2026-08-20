# Compile-time artifact describing one module of the application graph:
# its name and the controllers it declares. Emitted by the collector as
# `Quartz::MODULES`; consumed at boot by `Quartz::RouteTable`.
record Quartz::ModuleInfo, name : String, controllers : Array(String)
