module Quartz::OpenAPI
  # A JSON Schema fragment, represented as a plain hash of JSON values.
  alias Schema = Hash(String, JSON::Any)

  # The document's `info` section: the API title and version.
  struct Info
    include JSON::Serializable

    getter title : String
    getter version : String

    def initialize(@title : String, @version : String)
    end
  end

  # One parameter of an operation. The location is serialized under the
  # wire key `in`, as the OpenAPI specification requires.
  struct Parameter
    include JSON::Serializable

    getter name : String

    @[JSON::Field(key: "in")]
    getter in : String

    getter? required : Bool
    getter schema : Schema

    def initialize(@name : String, @in : String, @required : Bool, @schema : Schema)
    end
  end

  # The schema a response or request body carries for one content type.
  struct MediaType
    include JSON::Serializable

    getter schema : Schema

    def initialize(@schema : Schema)
    end
  end

  # One response of an operation. Content is omitted entirely when the
  # response carries no body, such as a 204.
  struct ResponseObject
    include JSON::Serializable

    getter description : String

    @[JSON::Field(emit_null: false)]
    getter content : Hash(String, MediaType)?

    def initialize(@description : String, @content : Hash(String, MediaType)? = nil)
    end
  end

  # The body a request carries, described per content type.
  struct RequestBody
    include JSON::Serializable

    getter? required : Bool
    getter content : Hash(String, MediaType)

    def initialize(@required : Bool, @content : Hash(String, MediaType))
    end
  end

  # A single route as it appears in the document: its id, summary,
  # parameters, body, and responses.
  struct Operation
    include JSON::Serializable

    @[JSON::Field(key: "operationId")]
    getter operation_id : String

    @[JSON::Field(emit_null: false)]
    getter summary : String?

    @[JSON::Field(emit_null: false)]
    getter parameters : Array(Parameter)?

    @[JSON::Field(key: "requestBody", emit_null: false)]
    getter request_body : RequestBody?

    getter responses : Hash(String, ResponseObject)

    def initialize(
      @operation_id : String,
      @responses : Hash(String, ResponseObject),
      @summary : String? = nil,
      @parameters : Array(Parameter)? = nil,
      @request_body : RequestBody? = nil,
    )
    end
  end

  # The generated OpenAPI document: the specification version, the
  # info section, one entry per path with its operations, and the
  # reusable schemas those operations reference.
  struct Document
    include JSON::Serializable

    getter openapi : String
    getter info : Info
    getter paths : Hash(String, Hash(String, Operation))
    getter components : Hash(String, Hash(String, Schema))

    def initialize(
      @info : Info,
      @paths : Hash(String, Hash(String, Operation)),
      @components : Hash(String, Hash(String, Schema)),
      @openapi : String = "3.1.0",
    )
    end
  end
end
