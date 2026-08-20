# A module annotated but not reachable from the root: the collector must
# refuse it, naming the module and the root it cannot reach.
require "../../../src/quartz"

@[Quartz::Module]
class ReachableModule
end

@[Quartz::Module]
class OrphanModule
end

class Quartz::Bootstrap
  ROOT = ReachableModule
end
