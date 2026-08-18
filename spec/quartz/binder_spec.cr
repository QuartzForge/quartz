require "../spec_helper"

private def context(path = "/users/42", query = "", headers = HTTP::Headers.new)
  ctx = Quartz::Context.new(
    Quartz::Request.new(
      method: "GET", path: path, query: HTTP::Params.parse(query), headers: headers,
    )
  )
  ctx.path_params = {"id" => "42"}
  ctx
end

describe Quartz::Binder do
  it "converts path and query params" do
    bound = Quartz::Binder.call(
      [
        Quartz::ParamDef.new("id", "Int64", :path),
        Quartz::ParamDef.new("page", "Int32", :query),
      ],
      context(query: "page=3"),
    )

    bound.fetch("id", Int64).should eq(42_i64)
    bound.fetch("page", Int32).should eq(3)
  end

  it "reads a header param" do
    headers = HTTP::Headers.new
    headers["x-tenant"] = "acme"

    bound = Quartz::Binder.call(
      [Quartz::ParamDef.new("x-tenant", "String", :header)],
      context(headers: headers),
    )

    bound.fetch("x-tenant", String).should eq("acme")
  end

  it "matches a header param case-insensitively" do
    headers = HTTP::Headers.new
    headers["X-Tenant"] = "acme"

    bound = Quartz::Binder.call(
      [Quartz::ParamDef.new("x-tenant", "String", :header)],
      context(headers: headers),
    )

    bound.fetch("x-tenant", String).should eq("acme")
  end

  it "skips body params — Context#body_as handles those" do
    bound = Quartz::Binder.call(
      [Quartz::ParamDef.new("body", "CreateUser", :body)],
      context,
    )

    bound.values.should be_empty
  end

  it "accepts a missing optional param" do
    bound = Quartz::Binder.call(
      [Quartz::ParamDef.new("page", "Int32", :query, required: false)],
      context,
    )

    bound.fetch?("page", Int32).should be_nil
  end

  it "treats an empty value as missing" do
    required = expect_raises(Quartz::BindError) do
      Quartz::Binder.call(
        [Quartz::ParamDef.new("name", "String", :query)],
        context(query: "name="),
      )
    end
    required.failures.first.message.should eq("missing required parameter")

    optional = Quartz::Binder.call(
      [Quartz::ParamDef.new("name", "String", :query, required: false)],
      context(query: "name="),
    )
    optional.fetch?("name", String).should be_nil
  end

  it "accumulates ALL failures in a single BindError" do
    error = expect_raises(Quartz::BindError) do
      ctx = context(query: "page=x&limit=y")
      ctx.path_params = {"id" => "abc"}
      Quartz::Binder.call(
        [
          Quartz::ParamDef.new("id", "Int64", :path),
          Quartz::ParamDef.new("page", "Int32", :query),
          Quartz::ParamDef.new("limit", "Int32", :query),
        ],
        ctx,
      )
    end

    error.failures.size.should eq(3)
    error.failures.map(&.field).should eq(["id", "page", "limit"])
    error.failures.map(&.source).should eq(["path", "query", "query"])
  end

  it "keeps failures in declaration order across mixed sources" do
    headers = HTTP::Headers.new
    headers["x-tenant"] = "acme"

    error = expect_raises(Quartz::BindError) do
      ctx = context(query: "page=x")
      ctx.path_params = {"id" => "abc"}
      Quartz::Binder.call(
        [
          Quartz::ParamDef.new("id", "Int64", :path),
          Quartz::ParamDef.new("x-tenant", "Int32", :header),
          Quartz::ParamDef.new("page", "Int32", :query),
        ],
        ctx,
      )
    end

    error.failures.map(&.field).should eq(["id", "x-tenant", "page"])
    error.failures.map(&.source).should eq(["path", "header", "query"])
  end

  it "reports a missing required param" do
    error = expect_raises(Quartz::BindError) do
      Quartz::Binder.call([Quartz::ParamDef.new("page", "Int32", :query)], context)
    end

    error.failures.first.message.should eq("missing required parameter")
  end
end
