# A module listing a non-service in providers: the collector must refuse
# the entry at compile time, naming the type.
require "../../../src/quartz"

@[Quartz::Controller]
class SomeController
  @[Quartz::Get("/")]
  def index : String
    "x"
  end
end

@[Quartz::Module(providers: [SomeController])]
class RootModule
end

class Quartz::Bootstrap
  ROOT = RootModule
end
