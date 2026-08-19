module Quartz::Middleware
  # Gives every request a trace id, exposed to the pipeline as
  # `Context#request_id` and echoed back to the client in a response
  # header. A non-empty id the client supplies is preserved — that is what
  # keeps a trace alive across services — and a random one is generated
  # only when the client sent none. Runs outermost in the pipeline so the
  # id is available to every middleware that runs after it.
  class RequestId
    include Quartz::Middleware

    def initialize(@header : String = "x-request-id")
    end

    def call(ctx : Quartz::Context, forward : Proc(Quartz::Context, Quartz::Response)) : Quartz::Response
      id = ctx.request.headers[@header]?
      id = Random::Secure.urlsafe_base64(12) if id.nil? || id.empty?
      ctx.request_id = id

      response = forward.call(ctx)
      response.headers[@header] = id
      response
    end
  end
end
