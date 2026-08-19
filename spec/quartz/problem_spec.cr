require "../spec_helper"

describe Quartz::Problem do
  it "converts an HTTPError into a problem+json response" do
    problem = Quartz::Problem.from(
      Quartz::NotFound.new("User 42 does not exist"),
      instance: "/users/42",
      request_id: "req-1",
    )
    response = problem.to_response

    response.status.should eq(404)
    response.headers["content-type"].should eq("application/problem+json")

    body = JSON.parse(response.body)
    body["title"].should eq("Not Found")
    body["status"].should eq(404)
    body["detail"].should eq("User 42 does not exist")
    body["instance"].should eq("/users/42")
    body["request_id"].should eq("req-1")
  end

  it "converts a BindError listing each field that failed" do
    error = Quartz::BindError.new([
      Quartz::FieldError.new("id", "path", %(expected Int64, got "abc")),
      Quartz::FieldError.new("page", "query", %(expected Int32, got "x")),
    ])

    body = JSON.parse(
      Quartz::Problem.from(error, instance: "/users/abc", request_id: "req-2").to_response.body
    )

    body["status"].should eq(400)
    body["type"].should eq("https://quartzforge.org/errors/bind-error")
    body["title"].should eq("Invalid request parameters")
    body["detail"].should eq("2 parameters failed validation")
    body["errors"].as_a.size.should eq(2)
    body["errors"][0]["field"].should eq("id")
    body["errors"][0]["in"].should eq("path")
  end

  it "omits null keys from the JSON" do
    body = JSON.parse(
      Quartz::Problem.from(
        Quartz::BadRequest.new, instance: "/x", request_id: "req-3"
      ).to_response.body
    ).as_h

    body.has_key?("errors").should be_false

    bare = JSON.parse(
      Quartz::Problem.new(
        type: "https://quartzforge.org/errors/bad-request",
        title: "Bad Request",
        status: 400,
      ).to_response.body
    ).as_h

    bare.has_key?("detail").should be_false
    bare.has_key?("errors").should be_false
  end
end
