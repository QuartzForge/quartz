module Quartz::Middleware
  # Logs one entry per completed request with the method, path, status,
  # duration in milliseconds, and the request id assigned by
  # `RequestId`. Runs outside the error handler so error responses are
  # logged with their final status too.
  class Logger
    include Quartz::Middleware

    def initialize(@log : Log = Log.for("quartz.request"))
    end

    def call(ctx : Quartz::Context, forward : Proc(Quartz::Context, Quartz::Response)) : Quartz::Response
      started = Time.instant
      response = forward.call(ctx)
      elapsed = Time.instant - started

      @log.info &.emit(
        "request",
        method: ctx.request.method,
        path: ctx.request.path,
        status: response.status,
        duration_ms: elapsed.total_milliseconds.round(2),
        request_id: ctx.request_id,
      )

      response
    end
  end
end
