require "../spec_helper"

private class Tagger
  include Quartz::Middleware

  def initialize(@tag : String, @trace : Array(String))
  end

  def call(ctx : Quartz::Context, forward : Proc(Quartz::Context, Quartz::Response)) : Quartz::Response
    @trace << "#{@tag}:in"
    response = forward.call(ctx)
    @trace << "#{@tag}:out"
    response
  end
end

private class ShortCircuit
  include Quartz::Middleware

  def call(ctx : Quartz::Context, forward : Proc(Quartz::Context, Quartz::Response)) : Quartz::Response
    Quartz::Response.new(403, "blocked")
  end
end

private class Exploder
  include Quartz::Middleware

  def call(ctx : Quartz::Context, forward : Proc(Quartz::Context, Quartz::Response)) : Quartz::Response
    raise "boom"
  end
end

private def bare_context
  Quartz::Context.new(Quartz::Request.new(method: "GET", path: "/"))
end

describe Quartz::Pipeline do
  it "runs middlewares in order, nesting the exit" do
    trace = [] of String
    pipeline = Quartz::Pipeline.new([
      Tagger.new("a", trace).as(Quartz::Middleware),
      Tagger.new("b", trace).as(Quartz::Middleware),
    ])

    pipeline.call(bare_context, ->(_c : Quartz::Context) {
      trace << "terminal"
      Quartz::Response.new(200)
    })

    trace.should eq(["a:in", "b:in", "terminal", "b:out", "a:out"])
  end

  it "keeps the declared order with more than two middlewares" do
    trace = [] of String
    pipeline = Quartz::Pipeline.new([
      Tagger.new("a", trace).as(Quartz::Middleware),
      Tagger.new("b", trace).as(Quartz::Middleware),
      Tagger.new("c", trace).as(Quartz::Middleware),
    ])

    pipeline.call(bare_context, ->(_c : Quartz::Context) {
      trace << "terminal"
      Quartz::Response.new(200)
    })

    trace.should eq(["a:in", "b:in", "c:in", "terminal", "c:out", "b:out", "a:out"])
  end

  it "short-circuits without reaching the terminal" do
    reached = false
    pipeline = Quartz::Pipeline.new([ShortCircuit.new.as(Quartz::Middleware)])

    response = pipeline.call(bare_context, ->(_c : Quartz::Context) {
      reached = true
      Quartz::Response.new(200)
    })

    response.status.should eq(403)
    reached.should be_false
  end

  it "propagates exceptions raised by a middleware" do
    pipeline = Quartz::Pipeline.new([Exploder.new.as(Quartz::Middleware)])

    expect_raises(Exception, "boom") do
      pipeline.call(bare_context, ->(_c : Quartz::Context) { Quartz::Response.new(200) })
    end
  end

  it "calls the terminal directly when there is no middleware" do
    pipeline = Quartz::Pipeline.new([] of Quartz::Middleware)

    pipeline.call(bare_context, ->(_c : Quartz::Context) { Quartz::Response.new(204) })
      .status.should eq(204)
  end
end
