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

    # Deserializes the request body into the requested type. JSON failures
    # become a `BindError` so the client gets a 400-shaped problem, never
    # a 500.
    def body_as(type : T.class) : T forall T
      raw = @request.body
      if raw.nil? || raw.empty?
        raise Quartz::BindError.new([
          Quartz::FieldError.new("body", "body", "request body is required"),
        ])
      end
      T.from_json(raw)
    rescue ex : JSON::ParseException | JSON::SerializableError
      # Serializer messages can carry a multi-line parse trace; the first
      # line names the offending attribute, which is all a client needs.
      message = ex.message.to_s.lines.first?
      raise Quartz::BindError.new([
        Quartz::FieldError.new("body", "body", message || "invalid JSON body"),
      ])
    end
  end
end
