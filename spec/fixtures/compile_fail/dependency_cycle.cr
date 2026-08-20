# Two services depending on each other: the container must fail to
# compile, naming the participants of the cycle.
require "../../../src/quartz"

@[Quartz::Service]
class CycleA
  def initialize(@b : CycleB)
  end
end

@[Quartz::Service]
class CycleB
  def initialize(@a : CycleA)
  end
end

@[Quartz::Module]
class FixtureModule
end

class Quartz::Bootstrap
  ROOT = FixtureModule
end
