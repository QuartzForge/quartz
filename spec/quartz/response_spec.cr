require "../spec_helper"

describe Quartz::Response do
  it "builds a JSON response with a content-type header" do
    response = Quartz::Response.json(%({"id":1}), 201)

    response.status.should eq(201)
    response.body.should eq(%({"id":1}))
    response.headers["content-type"].should eq("application/json")
  end

  it "builds a 204 with an empty body" do
    response = Quartz::Response.no_content

    response.status.should eq(204)
    response.body.should be_empty
  end
end
