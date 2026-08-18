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

    def initialize(
      @after : Time::Span = 30.seconds,
      @log : Log = Log.for("quartz.timeout"),
    )
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
        # The request fiber keeps running after the deadline; drain its
        # outcome so a late exception is logged instead of disappearing
        # into the buffered channel with no receiver.
        spawn do
          case payload = channel.receive
          when Quartz::Response
            @log.info &.emit(
              "request completed after the timeout; response discarded",
              request_id: ctx.request_id,
              status: payload.status,
            )
          when Exception
            @log.warn &.emit(
              "request raised after the timeout: #{payload.message}",
              request_id: ctx.request_id,
            )
          end
        end

        raise Quartz::HTTPError.new(
          504, "https://quartz.dev/errors/timeout", "Gateway Timeout",
          "Request exceeded #{format_deadline(@after)}"
        )
      end
    end

    # Renders the deadline for the 504 message. `total_seconds.to_i`
    # would truncate a sub-second deadline to "0s", so anything under one
    # second is rendered in milliseconds; whole seconds drop the decimal
    # point.
    private def format_deadline(span : Time::Span) : String
      if span.total_milliseconds < 1000
        "#{span.total_milliseconds.to_i}ms"
      elsif span.total_seconds == span.total_seconds.to_i
        "#{span.total_seconds.to_i}s"
      else
        "#{span.total_seconds}s"
      end
    end
  end
end
