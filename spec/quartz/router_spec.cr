require "../spec_helper"

private def route(verb, path, id = nil)
  Quartz::RouteDef.new(
    verb: verb,
    path: path,
    params: [] of Quartz::ParamDef,
    status: 200,
    operation_id: id || "#{verb.downcase}#{path}",
    action: ->(_c : Quartz::Context, _b : Quartz::Bound) { Quartz::Response.new },
  )
end

describe Quartz::Router do
  it "matches a static route" do
    router = Quartz::Router.new([route("GET", "/health")])

    match = router.match("GET", "/health").should_not be_nil
    match.route.operation_id.should eq("get/health")
  end

  it "extracts a path param" do
    router = Quartz::Router.new([route("GET", "/users/:id")])

    match = router.match("GET", "/users/42").should_not be_nil
    match.path_params["id"].should eq("42")
  end

  it "prefers a static segment over a param" do
    router = Quartz::Router.new([
      route("GET", "/users/:id", "byId"),
      route("GET", "/users/me", "me"),
    ])

    match = router.match("GET", "/users/me").should_not be_nil
    match.route.operation_id.should eq("me")
    match = router.match("GET", "/users/7").should_not be_nil
    match.route.operation_id.should eq("byId")
  end

  it "matches a wildcard and returns the rest of the path" do
    router = Quartz::Router.new([route("GET", "/files/*rest")])

    match = router.match("GET", "/files/a/b/c.txt").should_not be_nil
    match.path_params["rest"].should eq("a/b/c.txt")
  end

  it "returns nil when no path matches" do
    router = Quartz::Router.new([route("GET", "/users/:id")])

    router.match("GET", "/posts/1").should be_nil
  end

  it "returns nil when the path matches but the verb does not" do
    router = Quartz::Router.new([route("GET", "/users/:id")])

    router.match("DELETE", "/users/1").should be_nil
  end

  it "ignores a trailing slash" do
    router = Quartz::Router.new([route("GET", "/users")])

    router.match("GET", "/users/").should_not be_nil
  end

  it "refuses two identical routes" do
    expect_raises(Quartz::ConfigError, /route conflict: GET \/users/) do
      Quartz::Router.new([route("GET", "/users"), route("GET", "/users")])
    end
  end

  it "refuses two different param names in the same position" do
    expect_raises(Quartz::ConfigError, /:uid.*:id/) do
      Quartz::Router.new([route("GET", "/users/:id"), route("GET", "/users/:uid")])
    end
  end
end
