# A controller depending on a class that was never registered as a
# service: the container must fail to compile with a getter error naming
# the missing dependency.
require "../../../src/quartz"

class UnregisteredRepo
end

@[Quartz::Controller(prefix: "/x")]
class NeedsMissingController
  def initialize(@repo : UnregisteredRepo)
  end

  @[Quartz::Get("/")]
  def index : String
    "x"
  end
end

@[Quartz::Module(controllers: [NeedsMissingController])]
class FixtureModule
end

class Quartz::Bootstrap
  ROOT = FixtureModule
end

# In a real application the collector resolves every controller at boot;
# resolving this one must fail the build with a getter error.
Quartz.container.needs_missing_controller
