# src/quartz/context.cr
module Quartz
  # Mutable per-request state, carried through the entire pipeline.
  #
  # Wraps the normalized `request` and holds framework-managed values such
  # as `request_id` and `path_params`, which handlers can read and set.
  class Context
    getter request : Quartz::Request
    property request_id : String = ""
    property path_params : Hash(String, String) = {} of String => String

    def initialize(@request : Quartz::Request)
    end
  end
end
