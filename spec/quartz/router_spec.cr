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

  it "allows the same param name in different routes" do
    router = Quartz::Router.new([
      route("GET", "/users/:id", "byId"),
      route("GET", "/posts/:id", "byPostId"),
    ])

    match = router.match("GET", "/users/7").should_not be_nil
    match.route.operation_id.should eq("byId")
    match = router.match("GET", "/posts/9").should_not be_nil
    match.route.operation_id.should eq("byPostId")
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

  it "requires at least one segment for a wildcard" do
    router = Quartz::Router.new([route("GET", "/files/*rest")])

    router.match("GET", "/files").should be_nil
  end

  it "backtracks past a wildcard that does not serve the verb" do
    router = Quartz::Router.new([
      route("POST", "/a/*rest", "postWild"),
      route("GET", "/:x/b", "getParam"),
    ])

    match = router.match("GET", "/a/b").should_not be_nil
    match.route.operation_id.should eq("getParam")
    match.path_params["x"].should eq("a")
  end

  it "limits a wildcard to the verbs that declare it" do
    router = Quartz::Router.new([
      route("GET", "/:x", "byX"),
      route("POST", "/:x/*rest", "postWild"),
    ])

    router.match("GET", "/a/b").should be_nil
    match = router.match("POST", "/a/b").should_not be_nil
    match.route.operation_id.should eq("postWild")
    match.path_params["rest"].should eq("b")
  end

  it "serves the same wildcard name under several verbs" do
    router = Quartz::Router.new([
      route("GET", "/f/*rest", "byGet"),
      route("POST", "/f/*rest", "byPost"),
    ])

    match = router.match("GET", "/f/x/y").should_not be_nil
    match.route.operation_id.should eq("byGet")
    match.path_params["rest"].should eq("x/y")
    match = router.match("POST", "/f/x/y").should_not be_nil
    match.route.operation_id.should eq("byPost")
    match.path_params["rest"].should eq("x/y")
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

  it "matches a route under the configured prefix" do
    router = Quartz::Router.new([route("GET", "/health")], prefix: "/api/v1")

    match = router.match("GET", "/api/v1/health").should_not be_nil
    match.route.operation_id.should eq("get/health")
    router.match("GET", "/health").should be_nil
  end

  it "extracts path params under a prefix" do
    router = Quartz::Router.new([route("GET", "/users/:id")], prefix: "/api/v1")

    match = router.match("GET", "/api/v1/users/42").should_not be_nil
    match.path_params["id"].should eq("42")
  end

  it "matches a wildcard route under a prefix" do
    router = Quartz::Router.new([route("GET", "/files/*rest")], prefix: "/api")

    match = router.match("GET", "/api/files/a/b.txt").should_not be_nil
    match.path_params["rest"].should eq("a/b.txt")
  end

  it "normalizes a trailing slash on the prefix" do
    router = Quartz::Router.new([route("GET", "/health")], prefix: "/api/v1/")

    router.match("GET", "/api/v1/health").should_not be_nil
  end

  it "refuses a prefix that does not start with a slash" do
    expect_raises(Quartz::ConfigError, /start with/) do
      Quartz::Router.new([route("GET", "/health")], prefix: "api/v1")
    end
  end

  it "refuses a prefix with a placeholder segment" do
    expect_raises(Quartz::ConfigError, /static segments/) do
      Quartz::Router.new([route("GET", "/health")], prefix: "/api/:version")
    end
  end

  it "reports conflicts with the effective prefixed path" do
    expect_raises(Quartz::ConfigError, /route conflict: GET \/api\/v1\/users/) do
      Quartz::Router.new(
        [route("GET", "/users"), route("GET", "/users")],
        prefix: "/api/v1",
      )
    end
  end

  it "refuses two identical routes" do
    expect_raises(Quartz::ConfigError, /route conflict: GET \/users/) do
      Quartz::Router.new([route("GET", "/users"), route("GET", "/users")])
    end
  end

  it "refuses a path that repeats a param name" do
    expect_raises(Quartz::ConfigError, /GET .*:id.*:id/) do
      Quartz::Router.new([
        route("GET", "/users/:id/posts/:id", "dup"),
        route("GET", "/users/:id/posts/*rest", "wild"),
      ])
    end
  end

  it "refuses two different param names in the same position" do
    expect_raises(Quartz::ConfigError, /GET .*:uid.*:id/) do
      Quartz::Router.new([route("GET", "/users/:id"), route("GET", "/users/:uid")])
    end
  end

  it "refuses two different wildcard names in the same position" do
    expect_raises(Quartz::ConfigError, /(GET|POST) .*\*other.*\*path/) do
      Quartz::Router.new([
        route("GET", "/f/*path", "byPath"),
        route("POST", "/f/*other", "byOther"),
      ])
    end
  end

  it "refuses a path with segments after a wildcard" do
    expect_raises(Quartz::ConfigError, /after wildcard/) do
      Quartz::Router.new([route("GET", "/files/*rest/extra", "bad")])
    end
  end

  it "reports when a wildcard shadows a plain route" do
    expect_raises(Quartz::ConfigError, /shadowed by wildcard/) do
      Quartz::Router.new([
        route("GET", "/f", "plain"),
        route("GET", "/f/*rest", "wild"),
      ])
    end
  end
end
