module Quartz
  # A single field that failed validation, rendered under the `errors`
  # key of a problem+json payload.
  struct FieldError
    include JSON::Serializable

    getter field : String

    # The wire key is `in`, as RFC 9457 consumers expect; `in` is a
    # reserved word in Crystal, so the internal name is `source`.
    @[JSON::Field(key: "in")]
    getter source : String

    getter message : String

    def initialize(@field : String, @source : String, @message : String)
    end
  end

  # A request that failed validation, carrying every field error at once
  # so the client can fix them in a single round trip.
  class BindError < Error
    getter failures : Array(Quartz::FieldError)

    def initialize(@failures : Array(Quartz::FieldError))
      super("#{@failures.size} parameters failed validation")
    end
  end

  # The framework's single error format, RFC 9457 problem+json. Every
  # client-facing failure is rendered through this shape.
  struct Problem
    include JSON::Serializable

    getter type : String
    getter title : String
    getter status : Int32

    @[JSON::Field(emit_null: false)]
    getter detail : String?

    @[JSON::Field(emit_null: false)]
    getter instance : String?

    @[JSON::Field(emit_null: false)]
    getter request_id : String?

    @[JSON::Field(emit_null: false)]
    getter errors : Array(Quartz::FieldError)?

    def initialize(
      @type : String,
      @title : String,
      @status : Int32,
      @detail : String? = nil,
      @instance : String? = nil,
      @request_id : String? = nil,
      @errors : Array(Quartz::FieldError)? = nil,
    )
    end

    # Builds the problem payload for a bind failure, listing every field
    # that failed validation.
    def self.from(error : Quartz::BindError, instance : String, request_id : String) : Problem
      new(
        type: "https://quartzforge.org/errors/bind-error",
        title: "Invalid request parameters",
        status: 400,
        detail: error.message,
        instance: instance,
        request_id: request_id,
        errors: error.failures,
      )
    end

    # Builds the problem payload for an HTTP error, carrying its status,
    # problem type, and title through unchanged.
    def self.from(error : Quartz::HTTPError, instance : String, request_id : String) : Problem
      new(
        type: error.problem_type,
        title: error.title,
        status: error.status,
        detail: error.detail,
        instance: instance,
        request_id: request_id,
      )
    end

    # Renders the problem as an HTTP response with the
    # `application/problem+json` content type.
    def to_response : Quartz::Response
      response = Quartz::Response.new(@status, to_json)
      response.headers["content-type"] = "application/problem+json"
      response
    end
  end
end
