module Quartz::OpenAPI
  # Builds the document from `Quartz::ROUTES` at request time: the
  # embedded OpenAPI route calls `build` on every request, so a change
  # to the configured title or version is reflected without a rebuild.
  # It knows neither Router, Binder, nor Server — it only reads route
  # metadata.
  module Builder
    PROBLEM_SCHEMA = {
      "$ref" => JSON::Any.new("#/components/schemas/Problem"),
    } of String => JSON::Any

    # The RFC 9457 problem document, as `Quartz::Problem` renders it:
    # the guaranteed error shape behind the 400, 404, and 500 responses.
    # `type`, `title`, and `status` are rendered unconditionally; the
    # remaining keys are emitted only when set.
    PROBLEM_DEFINITION = JSON.parse(<<-JSON).as_h
      {
        "type": "object",
        "required": ["type", "title", "status"],
        "properties": {
          "type": { "type": "string" },
          "title": { "type": "string" },
          "status": { "type": "integer" },
          "detail": { "type": "string" },
          "instance": { "type": "string" },
          "request_id": { "type": "string" },
          "errors": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "field": { "type": "string" },
                "in": { "type": "string" },
                "message": { "type": "string" }
              }
            }
          }
        }
      }
      JSON

    def self.build(
      routes : Array(Quartz::RouteDef),
      info : Info,
      prefix : String = "/",
    ) : Document
      paths = {} of String => Hash(String, Operation)

      routes.each do |route|
        path = to_openapi_path(Quartz.join_paths(prefix, route.path))
        paths[path] ||= {} of String => Operation
        paths[path][route.verb.downcase] = to_operation(route)
      end

      schemas = {"Problem" => PROBLEM_DEFINITION}
      referenced_types(routes).each { |name| schemas[name] = {} of String => JSON::Any }

      Document.new(info: info, paths: paths, components: {"schemas" => schemas})
    end

    # "/users/:id" and "/files/*rest" -> "/users/{id}" and "/files/{rest}"
    def self.to_openapi_path(path : String) : String
      path.split('/').map do |segment|
        case segment[0]?
        when ':', '*' then "{#{segment[1..]}}"
        else               segment
        end
      end.join('/')
    end

    # Parameter types the builder cannot describe are referenced by
    # name; each receives an open placeholder under `components` so the
    # references always resolve, and the developer can replace it with
    # the real schema.
    private def self.referenced_types(routes : Array(Quartz::RouteDef)) : Array(String)
      routes.flat_map { |route| route.params.map(&.type_name) }
        .uniq!
        .select { |name| to_schema(name).has_key?("$ref") }
    end

    private def self.to_operation(route : Quartz::RouteDef) : Operation
      scalars = route.params.reject(&.source.body?)
      body = route.params.find(&.source.body?)

      Operation.new(
        operation_id: route.operation_id,
        summary: route.summary,
        parameters: scalars.empty? ? nil : scalars.map { |param| to_parameter(param) },
        request_body: body.try { |param| to_request_body(param) },
        responses: build_responses(route),
      )
    end

    private def self.to_parameter(param : Quartz::ParamDef) : Parameter
      Parameter.new(
        name: param.name,
        in: param.source.to_wire,
        required: param.required?,
        schema: to_schema(param.type_name),
      )
    end

    private def self.to_request_body(param : Quartz::ParamDef) : RequestBody
      RequestBody.new(
        required: param.required?,
        content: {"application/json" => MediaType.new(to_schema(param.type_name))},
      )
    end

    private def self.build_responses(route : Quartz::RouteDef) : Hash(String, ResponseObject)
      responses = {} of String => ResponseObject

      responses[route.status.to_s] =
        if route.status == 204
          ResponseObject.new("No Content")
        else
          ResponseObject.new(
            "Success",
            {"application/json" => MediaType.new({} of String => JSON::Any)},
          )
        end

      problem = {"application/problem+json" => MediaType.new(PROBLEM_SCHEMA)}
      responses["400"] = ResponseObject.new("Invalid request parameters", problem)
      responses["404"] = ResponseObject.new("Not Found", problem)
      responses["500"] = ResponseObject.new("Internal Server Error", problem)

      responses
    end

    # Maps a `ParamDef.type_name` to its JSON Schema. Types the
    # framework cannot describe — user payloads and other named types —
    # become `$ref`s to the placeholder `Builder` declares for them.
    def self.to_schema(type_name : String) : Schema
      case type_name
      when "Int32", "Int64"
        {"type" => JSON::Any.new("integer")}
      when "Float64"
        {"type" => JSON::Any.new("number")}
      when "Bool"
        {"type" => JSON::Any.new("boolean")}
      when "UUID"
        {"type" => JSON::Any.new("string"), "format" => JSON::Any.new("uuid")}
      when "Time"
        {"type" => JSON::Any.new("string"), "format" => JSON::Any.new("date-time")}
      when "String"
        {"type" => JSON::Any.new("string")}
      else
        {"$ref" => JSON::Any.new("#/components/schemas/#{type_name}")}
      end
    end
  end
end
