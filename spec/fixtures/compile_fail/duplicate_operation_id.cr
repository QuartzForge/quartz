# Two annotated overloads of the same method: both would emit the same
# operation id, which the collector must refuse at collect time.
require "../../../src/quartz"

@[Quartz::Controller(prefix: "/dup")]
class DuplicateOperationIdController
  # NOTE: no default argument on the second overload. A default would
  # generate an implicit `show(id)` that shadows (replaces) the first
  # overload in the compiler's method table, hiding the duplicate.
  @[Quartz::Get("/:id")]
  def show(id : Int64) : String
    "a"
  end

  @[Quartz::Get("/:id/:page")]
  def show(id : Int64, page : Int32) : String
    "b"
  end
end

@[Quartz::Module(controllers: [DuplicateOperationIdController])]
class FixtureModule
end

class Quartz::Bootstrap
  ROOT = FixtureModule
end
