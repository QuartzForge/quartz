# Two routes declaring the same verb and path: the collector emits both,
# and the conflict surfaces when the Router is built.
require "../../../src/quartz"

@[Quartz::Controller(prefix: "/dup")]
class DuplicateRoutesController
  @[Quartz::Get("/:id")]
  def first(id : Int64) : String
    "a"
  end

  @[Quartz::Get("/:id")]
  def second(id : Int64) : String
    "b"
  end
end

# The conflict is only detected when the Router is built.
Quartz::Router.new(Quartz::ROUTES)
