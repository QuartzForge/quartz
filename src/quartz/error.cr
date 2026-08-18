module Quartz
  # The root of every exception the framework raises.
  class Error < Exception; end

  # A boot-time configuration failure that aborts the process; it
  # never becomes an HTTP response.
  class ConfigError < Error; end
end
