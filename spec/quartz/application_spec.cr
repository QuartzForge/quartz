require "../spec_helper"

describe Quartz::Application do
  it "matches a route, binds params and returns the serialized result" do
    route = Quartz::RouteDef.new(
      verb: "GET",
      path: "/users/:id",
      params: [Quartz::ParamDef.new("id", "Int64", :path)],
      status: 200,
      operation_id: "showUser",
      action: ->(_ctx : Quartz::Context, bound : Quartz::Bound) {
        Quartz::Serializer.call({id: bound.fetch("id", Int64)}, 200)
      },
    )
    client = test_client_for([route])

    response = client.get("/users/42")

    response.status.should eq(200)
    response.json["id"].should eq(42)
  end

  it "raises NotFound when no route matches" do
    client = test_client_for([] of Quartz::RouteDef)

    expect_raises(Quartz::NotFound) { client.get("/nope") }
  end

  it "raises BindError before calling the controller" do
    called = false
    route = Quartz::RouteDef.new(
      verb: "GET",
      path: "/users/:id",
      params: [Quartz::ParamDef.new("id", "Int64", :path)],
      status: 200,
      operation_id: "showUser",
      action: ->(_ctx : Quartz::Context, _b : Quartz::Bound) {
        called = true
        Quartz::Response.new(200)
      },
    )
    client = test_client_for([route])

    expect_raises(Quartz::BindError) { client.get("/users/abc") }
    called.should be_false
  end

  it "populates route and path params on the context before the action runs" do
    seen_path : String? = nil
    seen_params : Hash(String, String)? = nil
    route = Quartz::RouteDef.new(
      verb: "GET",
      path: "/users/:id",
      params: [Quartz::ParamDef.new("id", "Int64", :path)],
      status: 200,
      operation_id: "showUser",
      action: ->(ctx : Quartz::Context, _b : Quartz::Bound) {
        seen_path = ctx.route.try(&.path)
        seen_params = ctx.path_params
        Quartz::Response.new(200)
      },
    )
    client = test_client_for([route])

    client.get("/users/42")

    seen_path.should eq("/users/:id")
    seen_params.should eq({"id" => "42"})
  end
end
