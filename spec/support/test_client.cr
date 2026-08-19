module Quartz::Spec
  # In-memory HTTP client for specs: drives an `Application` directly
  # without opening a socket. Internal to the spec suite, not public API
  # in v1 — no compatibility guarantees.
  class TestClient
    def initialize(@app : Quartz::Application)
    end

    {% for verb in %w[get post put patch delete] %}
      def {{ verb.id }}(
        path : String,
        body : String? = nil,
        headers : HTTP::Headers = HTTP::Headers.new,
      ) : Quartz::Response
        request({{ verb.upcase }}, path, body, headers)
      end
    {% end %}

    def request(
      method : String,
      path : String,
      body : String?,
      headers : HTTP::Headers,
    ) : Quartz::Response
      uri = URI.parse(path)

      @app.handle(
        Quartz::Request.new(
          method: method,
          path: uri.path,
          query: HTTP::Params.parse(uri.query || ""),
          headers: headers,
          body: body,
        )
      )
    end
  end
end

class Quartz::Response
  # Spec convenience: parses the response body as JSON.
  def json : JSON::Any
    JSON.parse(@body)
  end
end
