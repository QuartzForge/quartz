module Quartz
  # Request parameters after conversion from the wire format, keyed by name.
  #
  # The binder produces one of these for each request and hands it to the
  # route action, which reads values back with `#fetch` and `#fetch?`.
  struct Bound
    alias Value = String | Int32 | Int64 | Float64 | Bool | UUID | Time | Array(String)

    getter values : Hash(String, Value)

    def initialize(@values : Hash(String, Value) = {} of String => Value)
    end

    # Returns the value for `name` cast to `type`.
    #
    # Raises `KeyError` when the key is absent and `TypeCastError` when the
    # stored value is not of the requested type.
    def fetch(name : String, type : T.class) : T forall T
      @values[name].as(T)
    end

    # Returns the value for `name` cast to `type`, or `nil` when the key is
    # absent.
    def fetch?(name : String, type : T.class) : T? forall T
      @values[name]?.try(&.as(T))
    end
  end
end
