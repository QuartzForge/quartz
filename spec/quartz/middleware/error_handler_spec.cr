require "../../spec_helper"

private def raising_route(error : Exception)
  Quartz::RouteDef.new(
    verb: "GET", path: "/boom", params: [] of Quartz::ParamDef,
    status: 200, operation_id: "boom",
    action: ->(_c : Quartz::Context, _b : Quartz::Bound) : Quartz::Response { raise error },
  )
end

private def handled_client(error : Exception)
  test_client_for([raising_route(error)], [
    Quartz::Middleware::RequestId.new.as(Quartz::Middleware),
    Quartz::Middleware::ErrorHandler.new.as(Quartz::Middleware),
  ])
end

describe Quartz::Middleware::ErrorHandler do
  it "converts an HTTPError into problem+json" do
    response = handled_client(Quartz::Conflict.new("Email já cadastrado")).get("/boom")

    response.status.should eq(409)
    response.headers["content-type"].should eq("application/problem+json")
    response.json["detail"].should eq("Email já cadastrado")
  end

  it "converts a BindError into a 400 with the list of fields" do
    error = Quartz::BindError.new([Quartz::FieldError.new("id", "path", "expected Int64")])

    response = handled_client(error).get("/boom")

    response.status.should eq(400)
    response.json["errors"].as_a.size.should eq(1)
  end

  it "converts an unknown exception into a 500 without leaking the internal message" do
    response = handled_client(Exception.new("senha do banco no stack trace")).get("/boom")

    response.status.should eq(500)
    response.json["type"].should eq("https://quartzforge.org/errors/internal")
    response.body.should_not contain("senha do banco")
    response.json["detail"].should eq("An unexpected error occurred")
  end

  it "includes the request_id in the error response" do
    response = handled_client(Quartz::NotFound.new).get("/boom")

    response.json["request_id"].as_s.should_not be_empty
  end
end
