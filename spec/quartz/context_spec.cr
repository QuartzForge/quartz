require "../spec_helper"

record CreateUser, name : String, email : String do
  include JSON::Serializable
end

record CreateAccount, balance : Float64 do
  include JSON::Serializable
end

describe Quartz::Context do
  it "deserializes the body into the requested type" do
    context = Quartz::Context.new(
      Quartz::Request.new(
        method: "POST",
        path: "/users",
        body: %({"name":"Ana","email":"ana@example.com"}),
      )
    )

    body = context.body_as(CreateUser)

    body.name.should eq("Ana")
    body.email.should eq("ana@example.com")
  end

  it "raises a BindError when the body is absent or empty" do
    {nil, ""}.each do |body|
      context = Quartz::Context.new(
        Quartz::Request.new(method: "POST", path: "/users", body: body)
      )

      expect_raises(Quartz::BindError) do
        context.body_as(CreateUser)
      end
    end
  end

  it "reports the body as the single failing field when required" do
    context = Quartz::Context.new(
      Quartz::Request.new(method: "POST", path: "/users")
    )

    error = expect_raises(Quartz::BindError) do
      context.body_as(CreateUser)
    end

    error.failures.size.should eq(1)
    error.failures.first.field.should eq("body")
    error.failures.first.source.should eq("body")
    error.failures.first.message.should eq("request body is required")
  end

  it "turns malformed JSON into a BindError, never a ParseException" do
    context = Quartz::Context.new(
      Quartz::Request.new(method: "POST", path: "/users", body: "{not json")
    )

    expect_raises(Quartz::BindError) do
      context.body_as(CreateUser)
    end
  end

  it "raises a BindError, not an escaping exception, for a wrong-typed float field" do
    context = Quartz::Context.new(
      Quartz::Request.new(method: "POST", path: "/accounts", body: %({"balance":"abc"}))
    )

    expect_raises(Quartz::BindError) do
      context.body_as(CreateAccount)
    end
  end
end
