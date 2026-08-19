module Quartz::Middleware
  # Adds CORS headers to responses and answers preflight `OPTIONS`
  # requests itself, with 204 and the allowed methods, headers, and max
  # age. A preflight always carries an `Origin` header, so only an
  # `OPTIONS` request with one is short-circuited; an `OPTIONS` request
  # without one is forwarded to the router as a normal request.
  #
  # Only an origin on the configured list receives an
  # `access-control-allow-origin` header; a disallowed origin gets none,
  # so a foreign page cannot read the response. The default of `["*"]` is
  # permissive on purpose for development. With a specific origin the
  # header echoes that origin and `Vary` is extended with `origin`; with
  # `*` the header is `*`.
  #
  # The pipeline composes it outside the error handler, so error
  # responses — problem documents included — carry the CORS headers on
  # the way out. A browser would otherwise hide an error body it cannot
  # read cross-origin.
  class CORS
    include Quartz::Middleware

    def initialize(
      @origins : Array(String) = ["*"],
      @methods : Array(String) = %w[GET POST PUT PATCH DELETE OPTIONS],
      @headers : Array(String) = %w[content-type authorization],
      @max_age : Int32 = 86_400,
    )
    end

    def call(ctx : Quartz::Context, forward : Proc(Quartz::Context, Quartz::Response)) : Quartz::Response
      origin = ctx.request.headers["origin"]?

      if origin && ctx.request.method == "OPTIONS"
        response = Quartz::Response.new(204)
        apply(response, origin)
        response.headers["access-control-allow-methods"] = @methods.join(", ")
        response.headers["access-control-allow-headers"] = @headers.join(", ")
        response.headers["access-control-max-age"] = @max_age.to_s
        return response
      end

      response = forward.call(ctx)
      apply(response, origin)
      response
    end

    private def apply(response : Quartz::Response, origin : String?) : Nil
      return if origin.nil?
      return unless @origins.includes?("*") || @origins.includes?(origin)

      response.headers["access-control-allow-origin"] =
        @origins.includes?("*") ? "*" : origin
      response.headers.add("vary", "origin")
    end
  end
end
