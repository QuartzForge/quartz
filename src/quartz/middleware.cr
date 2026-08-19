module Quartz
  # The middleware contract for Quartz. Middleware operates on
  # `Quartz::Context`, a surface richer than `HTTP::Server::Context`;
  # stdlib handlers run outside the framework (see `Quartz::Server`).
  #
  # A middleware either calls `forward` to continue down the chain, or
  # returns a response of its own to short-circuit it.
  module Middleware
    abstract def call(
      ctx : Quartz::Context,
      forward : Proc(Quartz::Context, Quartz::Response),
    ) : Quartz::Response
  end

  # A chain of middlewares wrapping a terminal handler. Middlewares run
  # in onion order: the first in the list enters the request first and
  # leaves the response last.
  class Pipeline
    getter middlewares : Array(Quartz::Middleware)

    def initialize(@middlewares : Array(Quartz::Middleware))
    end

    def call(
      ctx : Quartz::Context,
      terminal : Proc(Quartz::Context, Quartz::Response),
    ) : Quartz::Response
      chain = terminal

      @middlewares.reverse_each do |middleware|
        inner = chain
        chain = ->(c : Quartz::Context) { middleware.call(c, inner) }
      end

      chain.call(ctx)
    end
  end
end
