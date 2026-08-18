module Quartz
  # Converts a controller's return value into the response sent to the
  # client.
  #
  # A `Response` the controller built is passed through unchanged; `nil`
  # becomes 204 No Content unless the route declared another status; every
  # other value is serialized to JSON with the status the route declared.
  module Serializer
    # Passes a `Response` the controller built through unchanged, so its
    # headers and body reach the client exactly as written.
    def self.call(value : Quartz::Response, status : Int32) : Quartz::Response
      value
    end

    # Turns `nil` into 204 No Content; a route that declared a non-default
    # status keeps it.
    def self.call(value : Nil, status : Int32) : Quartz::Response
      Quartz::Response.new(status == 200 ? 204 : status, "")
    end

    # Serializes the value to JSON with the route's declared status.
    def self.call(value, status : Int32) : Quartz::Response
      Quartz::Response.json(value.to_json, status)
    end
  end
end
