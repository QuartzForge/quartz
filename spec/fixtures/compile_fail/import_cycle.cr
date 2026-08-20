# Two modules importing each other: the collector must refuse the cycle
# at compile time, naming the participants.
require "../../../src/quartz"

@[Quartz::Module(imports: [CycleModuleB])]
class CycleModuleA
end

@[Quartz::Module(imports: [CycleModuleA])]
class CycleModuleB
end

class Quartz::Bootstrap
  ROOT = CycleModuleA
end
