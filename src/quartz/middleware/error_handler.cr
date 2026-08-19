module Quartz::Middleware
  # Turns every exception raised downstream into an RFC 9457 problem+json
  # response, so no error escapes the pipeline as a raw 500. A `BindError`
  # becomes a 400 listing the failed fields, an `HTTPError` keeps its
  # status, and anything else becomes a generic 500.
  #
  # The exception message never reaches the client on the 500 path — it
  # routinely carries connection strings, file paths, or query fragments.
  # The stack trace goes only to the log, together with the request id so
  # the trace can be correlated. The 500 body is the same for every
  # failure.
  class ErrorHandler
    include Quartz::Middleware

    def initialize(@log : Log = Log.for("quartz.error"))
    end

    def call(ctx : Quartz::Context, forward : Proc(Quartz::Context, Quartz::Response)) : Quartz::Response
      forward.call(ctx)
    rescue ex : Quartz::BindError
      Quartz::Problem.from(ex, ctx.request.path, ctx.request_id).to_response
    rescue ex : Quartz::HTTPError
      Quartz::Problem.from(ex, ctx.request.path, ctx.request_id).to_response
    rescue ex : Exception
      @log.error(exception: ex) { "unhandled exception request_id=#{ctx.request_id}" }

      Quartz::Problem.new(
        type: "https://quartzforge.org/errors/internal",
        title: "Internal Server Error",
        status: 500,
        detail: "An unexpected error occurred",
        instance: ctx.request.path,
        request_id: ctx.request_id,
      ).to_response
    end
  end
end
