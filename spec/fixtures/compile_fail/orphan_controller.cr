# A controller annotated but not listed in any module: the collector
# must refuse it, since membership is mandatory in 1.0.
require "../../../src/quartz"

@[Quartz::Controller]
class OrphanController
  @[Quartz::Get("/")]
  def index : String
    "x"
  end
end

@[Quartz::Module]
class EmptyModule
end

class Quartz::Bootstrap
  ROOT = EmptyModule
end
