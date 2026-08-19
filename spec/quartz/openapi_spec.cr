require "../spec_helper"

private def built_document
  Quartz::OpenAPI::Builder.build(
    Quartz::ROUTES,
    Quartz::OpenAPI::Info.new(title: "Example API", version: "1.0.0"),
  )
end

# The fixtures below guarantee a parameter and a content map exist, so
# the non-nil accessors are asserted before they are used.
private def first_parameter(operation : Quartz::OpenAPI::Operation) : Quartz::OpenAPI::Parameter
  parameters = operation.parameters
  parameters.should_not be_nil
  parameters.as(Array(Quartz::OpenAPI::Parameter)).first
end

private def content_of(response : Quartz::OpenAPI::ResponseObject) : Hash(String, Quartz::OpenAPI::MediaType)
  content = response.content
  content.should_not be_nil
  content.as(Hash(String, Quartz::OpenAPI::MediaType))
end

describe Quartz::OpenAPI::Builder do
  it "declares OpenAPI 3.1.0" do
    built_document.openapi.should eq("3.1.0")
  end

  it "creates one path entry per route, grouping by verb" do
    paths = built_document.paths

    paths.keys.sort!.should eq(["/users", "/users/{id}"])
    paths["/users/{id}"].keys.sort!.should eq(["delete", "get"])
  end

  it "converts a Quartz :id path segment to OpenAPI {id}" do
    built_document.paths.keys.should contain("/users/{id}")
  end

  it "documents path and query params with the right schema" do
    operation = built_document.paths["/users/{id}"]["get"]
    parameter = first_parameter(operation)

    parameter.name.should eq("id")
    parameter.in.should eq("path")
    parameter.required?.should be_true
    parameter.schema["type"].should eq("integer")
  end

  it "marks a query param with a default as optional" do
    parameter = first_parameter(built_document.paths["/users"]["get"])

    parameter.in.should eq("query")
    parameter.required?.should be_false
  end

  it "uses the collected operation id" do
    built_document.paths["/users/{id}"]["get"].operation_id.should eq("ExampleController.show")
  end

  it "documents the response with the route's declared status" do
    built_document.paths["/users"]["post"].responses.keys.should contain("201")
  end

  it "documents error responses as problem+json" do
    responses = built_document.paths["/users/{id}"]["get"].responses

    responses.keys.should contain("400")
    content_of(responses["400"]).keys.should contain("application/problem+json")
  end

  it "declares the problem schema the error responses reference" do
    schemas = built_document.components["schemas"]

    schemas.keys.should contain("Problem")
    schemas["Problem"]["type"].should eq("object")
  end

  it "declares a placeholder for payload types it cannot describe" do
    schemas = built_document.components["schemas"]

    schemas.keys.should contain("CreateUserPayload")
  end
end

describe "golden file" do
  it "matches the versioned document" do
    expected = File.read("spec/fixtures/openapi/example_app.json").strip
    actual = built_document.to_pretty_json.strip

    if actual != expected
      File.write("spec/fixtures/openapi/example_app.actual.json", actual)
    end

    actual.should eq(expected)
  end
end

describe "embedded OpenAPI route" do
  it "serves the document at the configured path" do
    response = test_client_for(Quartz::ROUTES).get("/openapi.json")

    response.status.should eq(200)
    response.json["openapi"].should eq("3.1.0")
  end
end
