require "../../spec_helper"

private def echo_route
  Quartz::RouteDef.new(
    verb: "GET", path: "/echo", params: [] of Quartz::ParamDef,
    status: 200, operation_id: "echo",
    action: ->(ctx : Quartz::Context, _b : Quartz::Bound) {
      Quartz::Serializer.call({request_id: ctx.request_id}, 200)
    },
  )
end

describe Quartz::Middleware::RequestId do
  it "generates an id when the client does not send one" do
    client = test_client_for([echo_route], [Quartz::Middleware::RequestId.new.as(Quartz::Middleware)])

    response = client.get("/echo")

    response.json["request_id"].as_s.should_not be_empty
    response.headers["x-request-id"].should eq(response.json["request_id"].as_s)
  end

  it "preserves the id sent by the client" do
    client = test_client_for([echo_route], [Quartz::Middleware::RequestId.new.as(Quartz::Middleware)])
    headers = HTTP::Headers{"x-request-id" => "trace-123"}

    client.get("/echo", headers: headers).json["request_id"].should eq("trace-123")
  end
end
