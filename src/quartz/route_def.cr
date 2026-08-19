module Quartz
  # Where a request parameter is read from in the wire format.
  enum ParamSource
    Path
    Query
    Header
    Body

    # The member as it appears on the wire: `"path"`, `"query"`,
    # `"header"`, or `"body"`. Used by the binder, RFC 9457 error
    # payloads, and OpenAPI documents.
    def to_wire : String
      to_s.downcase
    end
  end

  # What a route executes. Receives the request `Context` and the
  # already-converted `Bound` parameters, and returns the `Response`.
  alias Action = Proc(Quartz::Context, Quartz::Bound, Quartz::Response)

  # A parameter declared by a route, such as `:id` in `/users/:id`.
  #
  # The collector emits these from the annotations of a controller action;
  # `type_name` is the Crystal type the binder converts the value to.
  struct ParamDef
    getter name : String
    getter type_name : String
    getter source : ParamSource
    getter? required : Bool

    def initialize(
      @name : String,
      @type_name : String,
      @source : ParamSource,
      @required : Bool = true,
    )
    end
  end

  # Metadata of a single route.
  #
  # The collector emits these at compile time. The Router consumes them for
  # matching and the OpenAPI builder for documentation, and the two never
  # know about each other.
  struct RouteDef
    getter verb : String
    getter path : String
    getter params : Array(ParamDef)
    getter status : Int32
    getter operation_id : String
    getter summary : String?
    getter action : Action

    def initialize(
      @verb : String,
      @path : String,
      @params : Array(ParamDef),
      @status : Int32,
      @operation_id : String,
      @action : Action,
      @summary : String? = nil,
    )
    end

    # The path as its `/`-separated parts, with empty segments removed.
    # Empty segments arise from leading, trailing, or doubled slashes:
    # `/users//posts/` becomes `["users", "posts"]`.
    def segments : Array(String)
      @path.split('/').reject(&.empty?)
    end
  end
end
