require "../spec_helper"

describe "Quartz::ROUTES" do
  it "collects one route per annotated method" do
    Quartz::ROUTES.size.should eq(7)
  end

  it "joins the controller prefix with the method path" do
    Quartz::ROUTES.map(&.path).sort!.should eq(
      ["/files/*rest", "/users", "/users", "/users/:id", "/users/:id", "/users/:id", "/users/:id"]
    )
  end

  it "normalizes a root method path without a double slash" do
    Quartz::ROUTES.map(&.path).should_not contain("//")
  end

  it "records the verb of each annotation" do
    Quartz::ROUTES.map(&.verb).sort!.should eq(["DELETE", "GET", "GET", "GET", "PATCH", "POST", "PUT"])
  end

  it "honors the status declared in the annotation" do
    Quartz::ROUTES.find! { |item| item.verb == "POST" }.status.should eq(201)
  end

  it "classifies a param appearing in the path as :path" do
    route = Quartz::ROUTES.find! { |item| item.path == "/users/:id" && item.verb == "GET" }

    route.params.first.source.should eq(Quartz::ParamSource::Path)
    route.params.first.type_name.should eq("Int64")
  end

  it "classifies a param outside the path as :query, optional when defaulted" do
    route = Quartz::ROUTES.find! { |item| item.path == "/users" && item.verb == "GET" }

    route.params.first.name.should eq("page")
    route.params.first.source.should eq(Quartz::ParamSource::Query)
    route.params.first.required?.should be_false
  end

  it "classifies a wildcard param as :path" do
    route = Quartz::ROUTES.find! { |item| item.path == "/files/*rest" }

    route.params.first.source.should eq(Quartz::ParamSource::Path)
    route.params.first.required?.should be_true
    route.params.first.type_name.should eq("String")
  end

  it "classifies an argument named body as :body" do
    route = Quartz::ROUTES.find! { |item| item.verb == "POST" }

    route.params.first.source.should eq(Quartz::ParamSource::Body)
  end

  it "derives an operation_id from controller and method" do
    Quartz::ROUTES.map(&.operation_id).should contain("ExampleController.show")
  end
end

describe "collected routes, end to end" do
  it "serves a GET with a path param" do
    response = test_client_for(Quartz::ROUTES).get("/users/7")

    response.status.should eq(200)
    response.json["id"].should eq(7)
    response.json["name"].should eq("User 7")
  end

  it "serves a GET with an optional query using its default" do
    test_client_for(Quartz::ROUTES).get("/users").json[0]["name"].should eq("page 1")
  end

  it "serves a GET with an explicit query" do
    test_client_for(Quartz::ROUTES).get("/users?page=5").json[0]["name"].should eq("page 5")
  end

  it "serves a POST with a deserialized body and status 201" do
    response = test_client_for(Quartz::ROUTES).post("/users", body: %({"name":"Ana"}))

    response.status.should eq(201)
    response.json["name"].should eq("Ana")
  end

  it "serves a DELETE returning 204 without a body" do
    response = test_client_for(Quartz::ROUTES).delete("/users/1")

    response.status.should eq(204)
    response.body.should be_empty
  end

  it "serves a GET with a wildcard capturing the rest of the path" do
    response = test_client_for(Quartz::ROUTES).get("/files/a/b/c.txt")

    response.status.should eq(200)
    response.json.should eq("downloading:a/b/c.txt")
  end

  it "serves a PUT with a body and a path param" do
    response = test_client_for(Quartz::ROUTES).put("/users/7", body: %({"name":"Renamed"}))

    response.status.should eq(200)
    response.json["id"].should eq(7)
    response.json["name"].should eq("Renamed")
  end

  it "serves a PATCH with a path param" do
    response = test_client_for(Quartz::ROUTES).patch("/users/7")

    response.status.should eq(200)
    response.json["id"].should eq(7)
    response.json["name"].should eq("patched 7")
  end
end
