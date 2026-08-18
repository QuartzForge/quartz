require "../../spec_helper"

private def ok_route(verb = "GET", path = "/items")
  Quartz::RouteDef.new(
    verb: verb, path: path, params: [] of Quartz::ParamDef,
    status: 200, operation_id: "#{verb}#{path}",
    action: ->(_c : Quartz::Context, _b : Quartz::Bound) { Quartz::Response.new(200, "[]") },
  )
end

private def raising_route
  Quartz::RouteDef.new(
    verb: "GET", path: "/boom", params: [] of Quartz::ParamDef,
    status: 200, operation_id: "boom",
    action: ->(_c : Quartz::Context, _b : Quartz::Bound) : Quartz::Response {
      raise Quartz::Conflict.new("email already registered")
    },
  )
end

private def cors_client(origins)
  test_client_for([ok_route], [
    Quartz::Middleware::CORS.new(origins: origins).as(Quartz::Middleware),
  ])
end

describe Quartz::Middleware::CORS do
  it "echoes an allowed origin" do
    response = cors_client(["https://app.example.com"]).get(
      "/items", headers: HTTP::Headers{"origin" => "https://app.example.com"}
    )

    response.headers["access-control-allow-origin"].should eq("https://app.example.com")
  end

  it "adds no header for a disallowed origin" do
    response = cors_client(["https://app.example.com"]).get(
      "/items", headers: HTTP::Headers{"origin" => "https://evil.example.com"}
    )

    response.headers["access-control-allow-origin"]?.should be_nil
  end

  it "answers the OPTIONS preflight with 204 without reaching the router" do
    response = cors_client(["*"]).request(
      "OPTIONS", "/items", nil, HTTP::Headers{"origin" => "https://qualquer.com"}
    )

    response.status.should eq(204)
    response.headers["access-control-allow-methods"].should contain("GET")
  end

  # CORS wraps the error handler so error responses also carry CORS
  # headers; a browser would otherwise hide the error body cross-origin.
  it "applies CORS headers to error responses" do
    client = test_client_for([raising_route], [
      Quartz::Middleware::CORS.new(origins: ["https://app.example.com"]).as(Quartz::Middleware),
      Quartz::Middleware::ErrorHandler.new.as(Quartz::Middleware),
    ])

    response = client.get("/boom", headers: HTTP::Headers{"origin" => "https://app.example.com"})

    response.status.should eq(409)
    response.headers["access-control-allow-origin"].should eq("https://app.example.com")
  end
end
