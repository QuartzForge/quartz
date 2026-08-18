require "../spec_helper"

describe Quartz::RouteDef do
  it "splits the path into segments, ignoring empty bars" do
    route = Quartz::RouteDef.new(
      verb: "GET",
      path: "/users/:id/posts",
      params: [Quartz::ParamDef.new("id", "Int64", :path)],
      status: 200,
      operation_id: "showUserPosts",
      action: ->(_ctx : Quartz::Context, _bound : Quartz::Bound) { Quartz::Response.new },
    )

    route.segments.should eq(["users", ":id", "posts"])
  end

  it "treats the root path as an empty list of segments" do
    route = Quartz::RouteDef.new(
      verb: "GET",
      path: "/",
      params: [] of Quartz::ParamDef,
      status: 200,
      operation_id: "root",
      action: ->(_ctx : Quartz::Context, _bound : Quartz::Bound) { Quartz::Response.new },
    )

    route.segments.should be_empty
  end
end

describe Quartz::ParamDef do
  it "is required by default" do
    Quartz::ParamDef.new("id", "Int64", :path).required?.should be_true
  end
end

describe Quartz::ParamSource do
  it "serializes every member to its wire name" do
    Quartz::ParamSource::Path.to_wire.should eq("path")
    Quartz::ParamSource::Query.to_wire.should eq("query")
    Quartz::ParamSource::Header.to_wire.should eq("header")
    Quartz::ParamSource::Body.to_wire.should eq("body")
  end
end
