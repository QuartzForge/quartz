module Quartz
  # Socket-free seam: `handle` is a pure function from `Request` to
  # `Response`, which is what makes the in-memory test client possible.
  class Application
    getter router : Quartz::Router
    getter pipeline : Quartz::Pipeline

    def initialize(@router : Quartz::Router, @pipeline : Quartz::Pipeline)
    end

    def handle(request : Quartz::Request) : Quartz::Response
      ctx = Quartz::Context.new(request)
      @pipeline.call(ctx, ->(c : Quartz::Context) { dispatch(c) })
    end

    private def dispatch(ctx : Quartz::Context) : Quartz::Response
      match = @router.match(ctx.request.method, ctx.request.path)

      raise Quartz::NotFound.new(
        "No route matches #{ctx.request.method} #{ctx.request.path}"
      ) if match.nil?

      ctx.path_params = match.path_params
      ctx.route = match.route

      bound = Quartz::Binder.call(match.route.params, ctx)
      match.route.action.call(ctx, bound)
    end
  end
end
