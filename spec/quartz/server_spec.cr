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
  it "builds the canonical pipeline and a handler usable by the stdlib server" do
    Quartz.configure do |config|
      config.host = "127.0.0.1"
      config.port = 0
    end

    Quartz.application.pipeline.should be_a(Quartz::Pipeline)
    Quartz.handler.should be_a(HTTP::Handler)
  end
end
