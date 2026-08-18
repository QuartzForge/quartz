module Quartz
  # Mutable per-request state, carried through the entire pipeline.
  #
  # Wraps the normalized `request` and holds framework-managed values such
  # as `request_id`, `path_params`, and the matched `route`, which handlers
  # can read and set.
  class Context
    getter request : Quartz::Request
    property request_id : String = ""
    property path_params : Hash(String, String) = {} of String => String
    # The route that matched this request, set by the application once a
    # route matches. `nil` before routing.
    property route : Quartz::RouteDef?

    def initialize(@request : Quartz::Request)
    end
  end
end
