module Quartz
  # A normalized HTTP response, decoupled from any socket.
  #
  # It is what `Quartz::Application#handle` returns, and the framework
  # renders it to the client. Prefer the `.json` and `.no_content`
  # convenience constructors over building one by hand.
  class Response
    property status : Int32
    property body : String
    property headers : HTTP::Headers

    def initialize(
      @status : Int32 = 200,
      @body : String = "",
      @headers : HTTP::Headers = HTTP::Headers.new,
    )
    end

    def self.json(body : String, status : Int32 = 200) : Response
      response = new(status, body)
      response.headers["content-type"] = "application/json"
      response
    end

    def self.no_content : Response
      new(204, "")
    end
  end
end
