module Quartz::Middleware
  # Answers a request that runs past its deadline with 504 Gateway
  # Timeout, raising an `HTTPError` for the error handler to render.
  #
  # KNOWN LIMITATION: Crystal cannot cancel a running fiber, so when the
  # deadline fires the client receives the 504 but the fiber executing
  # the request keeps running to completion. This protects the client,
  # not the server: the work is not shed, and slow endpoints can still
  # pile up fibers. Revisit when Crystal gains fiber cancellation.
  class Timeout
    include Quartz::Middleware

    def initialize(@after : Time::Span = 30.seconds)
    end

    def call(ctx : Quartz::Context, forward : Proc(Quartz::Context, Quartz::Response)) : Quartz::Response
      channel = Channel(Quartz::Response | Exception).new(1)

      spawn do
        channel.send(forward.call(ctx))
      rescue ex : Exception
        channel.send(ex)
      end

      select
      when result = channel.receive
        result.is_a?(Exception) ? raise(result) : result
      when timeout(@after)
        raise Quartz::HTTPError.new(
          504, "https://quartz.dev/errors/timeout", "Gateway Timeout",
          "Request exceeded #{@after.total_seconds.to_i}s"
        )
      end
    end
  end
end
