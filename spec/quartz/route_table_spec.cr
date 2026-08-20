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
end
