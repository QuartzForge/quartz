# spec/quartz/response_spec.cr
require "../spec_helper"

describe Quartz::Response do
  it "constrói resposta JSON com content-type" do
    response = Quartz::Response.json(%({"id":1}), 201)

    response.status.should eq(201)
    response.body.should eq(%({"id":1}))
    response.headers["content-type"].should eq("application/json")
  end

  it "constrói 204 sem corpo" do
    response = Quartz::Response.no_content

    response.status.should eq(204)
    response.body.should be_empty
  end
end
