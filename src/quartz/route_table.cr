# Compile-time artifact describing one module of the application graph:
# its name and the controllers it declares. Emitted by the collector as
# `Quartz::MODULES`; consumed at boot by `Quartz::RouteTable`.
record Quartz::ModuleInfo, name : String, controllers : Array(String)

module Quartz
  # Formats the collected routes for the boot-time log, pairing each
  # route with the module that declared it. A route whose controller is
  # not part of any module reports "?" instead of a module name.
  #
  # The path is reported as served: the configured prefix is joined to
  # the route's canonical path, so the log matches the router, the
  # conflict messages, and the OpenAPI document. The default prefix "/"
  # leaves the canonical path untouched.
  class RouteTable
    def self.lines(routes : Array(Quartz::RouteDef), modules : Array(Quartz::ModuleInfo), prefix : String = "/") : Array(String)
      base = prefix == "/" ? "" : prefix.chomp('/')
      routes.map do |route|
        owner = modules.find { |mod| mod.controllers.any? { |controller| route.operation_id.starts_with?(controller + ".") } }
        path = route.path == "/" ? (base.empty? ? "/" : base) : base + route.path
        "route #{route.verb} #{path} → #{route.operation_id} (#{owner.try(&.name) || "?"})"
      end
    end
  end
end
