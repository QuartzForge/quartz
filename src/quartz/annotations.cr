module Quartz
  # Marks a plain class as a controller. There is deliberately no base
  # class: `annotation Quartz::Controller` and `class Quartz::Controller`
  # cannot coexist in Crystal, and the annotation alone is enough for
  # discovery.
  annotation Controller; end

  # Registers the class with the compile-time dependency injection
  # container.
  annotation Service; end

  # Marks an argument as coming from a header instead of the query
  # string.
  annotation Header; end

  # Marks a method as a `GET` route.
  annotation Get; end

  # Marks a method as a `POST` route.
  annotation Post; end

  # Marks a method as a `PUT` route.
  annotation Put; end

  # Marks a method as a `PATCH` route.
  annotation Patch; end

  # Marks a method as a `DELETE` route.
  annotation Delete; end

  # Groups controllers and providers into a feature boundary. The class
  # is a plain carrier: imports, controllers and providers are read at
  # compile time by the collector, and the app is composed from the root
  # module passed to `Quartz.run`.
  annotation Module; end
end
