require "../spec_helper"

describe Quartz::RouteTable do
  it "pairs each route with the module that declared it" do
    routes = [
      Quartz::RouteDef.new(
        verb: "GET",
        path: "/users/:id",
        params: [] of Quartz::ParamDef,
        status: 200,
        operation_id: "UsersController.show",
        action: ->(_ctx : Quartz::Context, _bound : Quartz::Bound) { Quartz::Response.new(200) },
      ),
      Quartz::RouteDef.new(
        verb: "GET",
        path: "/files/*rest",
        params: [] of Quartz::ParamDef,
        status: 200,
        operation_id: "FilesController.download",
        action: ->(_ctx : Quartz::Context, _bound : Quartz::Bound) { Quartz::Response.new(200) },
      ),
    ]
    modules = [
      Quartz::ModuleInfo.new("UsersModule", ["UsersController"]),
      Quartz::ModuleInfo.new("FilesModule", ["FilesController"]),
    ]

    Quartz::RouteTable.lines(routes, modules).should eq([
      "route GET /users/:id → UsersController.show (UsersModule)",
      "route GET /files/*rest → FilesController.download (FilesModule)",
    ])
  end

  it "reports a question mark for a route whose controller is not in any module" do
    routes = [
      Quartz::RouteDef.new(
        verb: "GET",
        path: "/mystery",
        params: [] of Quartz::ParamDef,
        status: 200,
        operation_id: "MysteryController.x",
        action: ->(_ctx : Quartz::Context, _bound : Quartz::Bound) { Quartz::Response.new(200) },
      ),
    ]

    Quartz::RouteTable.lines(routes, [] of Quartz::ModuleInfo).should eq([
      "route GET /mystery → MysteryController.x (?)",
    ])
  end

  it "reports the effective path under a configured prefix" do
    routes = [
      Quartz::RouteDef.new(
        verb: "GET",
        path: "/users",
        params: [] of Quartz::ParamDef,
        status: 200,
        operation_id: "UsersController.index",
        action: ->(_ctx : Quartz::Context, _bound : Quartz::Bound) { Quartz::Response.new(200) },
      ),
    ]

    Quartz::RouteTable.lines(routes, [] of Quartz::ModuleInfo, "/api/v1").should eq([
      "route GET /api/v1/users → UsersController.index (?)",
    ])
  end

  it "renders a root route under a prefix without a double slash" do
    routes = [
      Quartz::RouteDef.new(
        verb: "GET",
        path: "/",
        params: [] of Quartz::ParamDef,
        status: 200,
        operation_id: "HomeController.index",
        action: ->(_ctx : Quartz::Context, _bound : Quartz::Bound) { Quartz::Response.new(200) },
      ),
    ]

    Quartz::RouteTable.lines(routes, [] of Quartz::ModuleInfo, "/api/v1").should eq([
      "route GET /api/v1 → HomeController.index (?)",
    ])
  end
end
