module Quartz
  # A normalized HTTP request, decoupled from any socket.
  #
  # `Quartz::Application#handle` consumes this type directly, which is what
  # allows the request pipeline to be exercised without binding a port.
  class Request
    getter method : String
    getter path : String
    getter query : HTTP::Params
    getter headers : HTTP::Headers
    getter body : String?

    def initialize(
      @method : String,
      @path : String,
      @query : HTTP::Params = HTTP::Params.parse(""),
      @headers : HTTP::Headers = HTTP::Headers.new,
      @body : String? = nil,
    )
    end
  end
end
