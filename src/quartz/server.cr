require "http/server"

module Quartz
  # OpenAPI document configuration: the title and version reported in
  # the document's `info` section, and the path the document is served
  # at.
  #
  # The path is read when the application is built, the title and
  # version per request, so any change must go through `Quartz.configure`
  # to take effect: mutating `Quartz.config.openapi` directly leaves the
  # memoized application serving the old path.
  class OpenAPIConfig
    property title : String = "Quartz API"
    property version : String = "1.0.0"
    property path : String = "/openapi.json"
  end

  # Runtime server configuration, tuned through `Quartz.configure` before
  # the application is built.
  class Config
    property host : String = "0.0.0.0"
    property port : Int32 = 3000
    property middlewares : Array(Quartz::Middleware) = [] of Quartz::Middleware
    property cors_origins : Array(String) = ["*"]
    property request_timeout : Time::Span = 30.seconds
    property path_prefix : String = "/"
    getter openapi : OpenAPIConfig = OpenAPIConfig.new
  end

  @@config = Quartz::Config.new
  @@application : Quartz::Application?

  # The current server configuration.
  def self.config : Quartz::Config
    @@config
  end

  # Yields the server configuration for mutation, then drops the memoized
  # application so the next access rebuilds it from the new values.
  def self.configure(&) : Nil
    yield @@config
    @@application = nil
  end

  # The route serving the OpenAPI document at `config.openapi.path`,
  # mounted under the configured path prefix like every other route.
  # The document is built at request time, so reconfiguring the title
  # or version is reflected without a rebuild. The route is appended to
  # the collected routes, never collected itself, so the document only
  # ever describes application routes.
  def self.openapi_route : Quartz::RouteDef
    Quartz::RouteDef.new(
      verb: "GET",
      path: @@config.openapi.path,
      params: [] of Quartz::ParamDef,
      status: 200,
      operation_id: "quartz.openapi",
      action: ->(_ctx : Quartz::Context, _bound : Quartz::Bound) {
        Quartz::Response.json(
          Quartz::OpenAPI::Builder.build(
            Quartz::ROUTES,
            Quartz::OpenAPI::Info.new(@@config.openapi.title, @@config.openapi.version),
            prefix: @@config.path_prefix,
          ).to_json
        )
      },
    )
  end

  # The application wired to the collected routes, the embedded OpenAPI
  # route, and the canonical pipeline, memoized until `configure` runs
  # again.
  def self.application : Quartz::Application
    @@application ||= Quartz::Application.new(
      Quartz::Router.new(Quartz::ROUTES + [openapi_route], prefix: @@config.path_prefix),
      build_pipeline,
    )
  end

  # A terminal handler executing `application` against an incoming
  # `HTTP::Server::Context`. Stdlib handlers (`HTTP::CompressHandler`,
  # `HTTP::StaticFileHandler`, `HTTP::LogHandler`) compose around it.
  def self.handler : Quartz::Server
    Quartz::Server.new(application)
  end

  # Binds the handler to the configured host and port and serves requests
  # until the process is interrupted.
  def self.run : Nil
    server = HTTP::Server.new([handler])
    address = server.bind_tcp(@@config.host, @@config.port)

    Log.for("quartz").info { "listening on http://#{address}" }
    server.listen
  end

  # The canonical pipeline. RequestId runs outermost so every middleware
  # sees the id, the logger records the final status, and CORS sits
  # outside the error handler so error responses pass back through it on
  # the way out. Timeout is the innermost built-in; user middleware runs
  # inside it.
  private def self.build_pipeline : Quartz::Pipeline
    Quartz::Pipeline.new(
      [
        Quartz::Middleware::RequestId.new,
        Quartz::Middleware::Logger.new,
        Quartz::Middleware::CORS.new(origins: @@config.cors_origins),
        Quartz::Middleware::ErrorHandler.new,
        Quartz::Middleware::Timeout.new(after: @@config.request_timeout),
      ] of Quartz::Middleware + @@config.middlewares
    )
  end

  # Terminal `HTTP::Handler` for the framework: converts the stdlib
  # context into a `Quartz::Request`, runs the application, and writes the
  # response back. Handlers from the stdlib stack outside it, and Quartz
  # reimplements none of them.
  class Server
    include HTTP::Handler

    def initialize(@app : Quartz::Application)
    end

    def call(context : HTTP::Server::Context) : Nil
      Quartz::Server.write(@app.handle(Quartz::Server.to_quartz_request(context)), context.response)
    end

    # Converts a stdlib context into a `Quartz::Request`. The path stays
    # exactly as sent, percent-encoding included; query components are
    # decoded into parameters. The body is consumed exactly once.
    def self.to_quartz_request(context : HTTP::Server::Context) : Quartz::Request
      request = context.request
      uri = URI.parse(request.resource)

      Quartz::Request.new(
        method: request.method,
        path: uri.path,
        query: HTTP::Params.parse(uri.query || ""),
        headers: request.headers,
        body: request.body.try(&.gets_to_end),
      )
    end

    # Renders a `Quartz::Response` onto a stdlib response. Status and
    # headers are committed first: the stdlib response freezes them on the
    # first write of body bytes.
    def self.write(response : Quartz::Response, target : HTTP::Server::Response) : Nil
      target.status_code = response.status
      response.headers.each { |name, values| target.headers[name] = values }
      target.print(response.body) unless response.body.empty?
    end
  end
end
