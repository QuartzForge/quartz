require "../spec_helper"

private record UserPayload, id : Int64, name : String do
  include JSON::Serializable
end

describe Quartz::Serializer do
  it "serializes an object to JSON with the requested status" do
    response = Quartz::Serializer.call(UserPayload.new(1_i64, "Ana"), 201)

    response.status.should eq(201)
    response.headers["content-type"].should eq("application/json")
    JSON.parse(response.body)["name"].should eq("Ana")
  end

  it "serializes an array" do
    response = Quartz::Serializer.call([UserPayload.new(1_i64, "Ana")], 200)

    JSON.parse(response.body).as_a.size.should eq(1)
  end

  it "turns a nil return into 204 when the status is the default" do
    response = Quartz::Serializer.call(nil, 200)

    response.status.should eq(204)
    response.body.should eq("")
    response.headers.has_key?("content-type").should be_false
  end

  it "keeps an explicitly declared status even with a nil return" do
    Quartz::Serializer.call(nil, 202).status.should eq(202)
    Quartz::Serializer.call(nil, 204).status.should eq(204)
  end

  it "passes a hand-built Response through unchanged" do
    original = Quartz::Response.new(418, "teapot")

    passed = Quartz::Serializer.call(original, 200)

    passed.should be(original)
    passed.status.should eq(418)
  end

  it "preserves custom headers on a passed-through Response" do
    original = Quartz::Response.new(418, "teapot")
    original.headers["x-correlation"] = "abc-123"

    Quartz::Serializer.call(original, 200).headers["x-correlation"].should eq("abc-123")
  end

  it "serializes primitives to JSON" do
    bool = Quartz::Serializer.call(true, 200)
    bool.status.should eq(200)
    JSON.parse(bool.body).as_bool.should be_true

    number = Quartz::Serializer.call(42, 200)
    number.status.should eq(200)
    JSON.parse(number.body).should eq(42)
  end

  it "serializes an empty array as JSON rather than treating it as nil" do
    response = Quartz::Serializer.call([] of Int32, 200)

    response.status.should eq(200)
    JSON.parse(response.body).as_a.should be_empty
  end
end
