require "../../spec_helper"

private def ok_route(verb = "GET", path = "/items")
  Quartz::RouteDef.new(
    verb: verb, path: path, params: [] of Quartz::ParamDef,
    status: 200, operation_id: "#{verb}#{path}",
    action: ->(_c : Quartz::Context, _b : Quartz::Bound) { Quartz::Response.new(200, "[]") },
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
end
