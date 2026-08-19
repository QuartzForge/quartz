require "../spec_helper"

describe Quartz::Server do
  it "converts an HTTP::Server::Context into a Quartz::Request" do
    io = IO::Memory.new
    http_request = HTTP::Request.new("GET", "/users/5?page=2")
    http_request.headers["x-tenant"] = "acme"
    context = HTTP::Server::Context.new(http_request, HTTP::Server::Response.new(io))

    request = Quartz::Server.to_quartz_request(context)

    request.method.should eq("GET")
    request.path.should eq("/users/5")
    request.query["page"].should eq("2")
    request.headers["x-tenant"].should eq("acme")
  end

  it "writes status, headers and body back onto the HTTP::Server::Response" do
    io = IO::Memory.new
    http_response = HTTP::Server::Response.new(io)

    Quartz::Server.write(Quartz::Response.json(%({"ok":true}), 201), http_response)
    http_response.close

    io.to_s.should contain("201")
    io.to_s.should contain("application/json")
    io.to_s.should contain(%({"ok":true}))
  end
end

describe Quartz do
  # These examples mutate the global config; snapshot every field the
  # suite can touch — host, port, pipeline inputs, and the openapi
  # settings — and restore them afterwards so later spec files read
  # pristine values. Restoring through `configure` also drops the
  # memoized application, so each example starts from a pipeline built
  # with default config.
  around_each do |spec|
    host = Quartz.config.host
    port = Quartz.config.port
    middlewares = Quartz.config.middlewares
    cors_origins = Quartz.config.cors_origins
    request_timeout = Quartz.config.request_timeout
    openapi_title = Quartz.config.openapi.title
    openapi_version = Quartz.config.openapi.version
    openapi_path = Quartz.config.openapi.path

    spec.run

    Quartz.configure do |config|
      config.host = host
      config.port = port
      config.middlewares = middlewares
      config.cors_origins = cors_origins
      config.request_timeout = request_timeout
      config.openapi.title = openapi_title
      config.openapi.version = openapi_version
      config.openapi.path = openapi_path
    end
  end

  it "builds the canonical pipeline and a handler usable by the stdlib server" do
    Quartz.configure do |config|
      config.host = "127.0.0.1"
      config.port = 0
    end

    Quartz.application.pipeline.should be_a(Quartz::Pipeline)
    Quartz.handler.should be_a(HTTP::Handler)
  end

  it "pins the canonical middleware order" do
    Quartz.application.pipeline.middlewares.map(&.class).should eq([
      Quartz::Middleware::RequestId,
      Quartz::Middleware::Logger,
      Quartz::Middleware::CORS,
      Quartz::Middleware::ErrorHandler,
      Quartz::Middleware::Timeout,
    ])
  end

  it "serves error responses with CORS headers through the canonical pipeline" do
    request = Quartz::Request.new(method: "GET", path: "/no-such-route")
    request.headers["origin"] = "https://example.test"

    response = Quartz.application.handle(request)

    response.status.should eq(404)
    response.headers["content-type"].should eq("application/problem+json")
    response.headers["access-control-allow-origin"].should eq("*")
  end
end
