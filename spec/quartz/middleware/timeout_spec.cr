require "../../spec_helper"
require "log/memory_backend"

private def slow_route(delay : Time::Span)
  Quartz::RouteDef.new(
    verb: "GET", path: "/slow", params: [] of Quartz::ParamDef,
    status: 200, operation_id: "slow",
    action: ->(_c : Quartz::Context, _b : Quartz::Bound) : Quartz::Response {
      sleep delay
      Quartz::Response.new(200, "[]")
    },
  )
end

private def late_raising_route
  Quartz::RouteDef.new(
    verb: "GET", path: "/late", params: [] of Quartz::ParamDef,
    status: 200, operation_id: "late",
    action: ->(_c : Quartz::Context, _b : Quartz::Bound) : Quartz::Response {
      sleep 200.milliseconds
      raise "late boom"
    },
  )
end

describe Quartz::Middleware::Timeout do
  # The error handler sits outside the timeout so the 504 it raises is
  # rendered as a problem document.
  it "renders a sub-second deadline without truncating to 0 seconds" do
    client = test_client_for([slow_route(500.milliseconds)], [
      Quartz::Middleware::ErrorHandler.new.as(Quartz::Middleware),
      Quartz::Middleware::Timeout.new(after: 20.milliseconds).as(Quartz::Middleware),
    ])

    response = client.get("/slow")

    response.status.should eq(504)
    response.body.should contain("Request exceeded 20ms")
  end

  it "renders a whole-second deadline without a decimal point" do
    client = test_client_for([slow_route(2.seconds)], [
      Quartz::Middleware::ErrorHandler.new.as(Quartz::Middleware),
      Quartz::Middleware::Timeout.new(after: 1.seconds).as(Quartz::Middleware),
    ])

    response = client.get("/slow")

    response.status.should eq(504)
    response.body.should contain("Request exceeded 1s")
  end

  it "logs an exception the request raises after the deadline fired" do
    backend = Log::MemoryBackend.new
    client = test_client_for([late_raising_route], [
      Quartz::Middleware::ErrorHandler.new.as(Quartz::Middleware),
      Quartz::Middleware::Timeout.new(
        after: 20.milliseconds,
        log: Log.new("quartz.timeout.spec", backend, Log::Severity::Trace),
      ).as(Quartz::Middleware),
    ])

    response = client.get("/late")

    response.status.should eq(504)
    sleep 250.milliseconds
    backend.entries.map(&.message).should contain("request raised after the timeout: late boom")
  end
end
