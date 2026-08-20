# A module listing a non-controller in controllers: the collector must
# refuse the entry at compile time, naming the type.
require "../../../src/quartz"

@[Quartz::Service]
class SomeService
end

@[Quartz::Module(controllers: [SomeService])]
class RootModule
end

class Quartz::Bootstrap
  ROOT = RootModule
end
