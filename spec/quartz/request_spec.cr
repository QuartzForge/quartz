require "../spec_helper"

describe Quartz::Request do
  it "exposes parsed query parameters" do
    request = Quartz::Request.new(
      method: "GET",
      path: "/users",
      query: HTTP::Params.parse("page=2&per_page=50"),
    )

    request.query["page"].should eq("2")
    request.query["per_page"].should eq("50")
  end

  it "treats a missing body as nil" do
    Quartz::Request.new(method: "GET", path: "/users").body.should be_nil
  end
end
