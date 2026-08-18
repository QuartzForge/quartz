module Quartz
  # The root of every exception the framework raises.
  class Error < Exception; end

  # A boot-time configuration failure that aborts the process; it
  # never becomes an HTTP response.
  class ConfigError < Error; end

  # An error that maps to an HTTP response, carrying the status code,
  # RFC 9457 problem type URI, and title that shape the error payload.
  class HTTPError < Error
    getter status : Int32
    getter problem_type : String
    getter title : String

    def initialize(@status : Int32, @problem_type : String, @title : String, detail : String? = nil)
      super(detail || @title)
    end

    # The human-readable detail of the failure, falling back to the
    # title when no detail was given.
    def detail : String
      message || @title
    end
  end

  # 400 Bad Request — the request is malformed or its input invalid.
  class BadRequest < HTTPError
    def initialize(detail : String? = nil)
      super(400, "https://quartz.dev/errors/bad-request", "Bad Request", detail)
    end
  end

  # 401 Unauthorized — the client is not authenticated.
  class Unauthorized < HTTPError
    def initialize(detail : String? = nil)
      super(401, "https://quartz.dev/errors/unauthorized", "Unauthorized", detail)
    end
  end

  # 403 Forbidden — the client is authenticated but not allowed.
  class Forbidden < HTTPError
    def initialize(detail : String? = nil)
      super(403, "https://quartz.dev/errors/forbidden", "Forbidden", detail)
    end
  end

  # 404 Not Found — the requested resource does not exist.
  class NotFound < HTTPError
    def initialize(detail : String? = nil)
      super(404, "https://quartz.dev/errors/not-found", "Not Found", detail)
    end
  end

  # 409 Conflict — the request clashes with the current state of the
  # resource.
  class Conflict < HTTPError
    def initialize(detail : String? = nil)
      super(409, "https://quartz.dev/errors/conflict", "Conflict", detail)
    end
  end

  # 422 Unprocessable Entity — the request is well-formed but cannot be
  # processed as given.
  class UnprocessableEntity < HTTPError
    def initialize(detail : String? = nil)
      super(422, "https://quartz.dev/errors/unprocessable-entity", "Unprocessable Entity", detail)
    end
  end
end
