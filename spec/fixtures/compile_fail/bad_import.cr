# A module importing a type that is not a module: the collector must
# refuse the import at compile time, naming the offending type.
require "../../../src/quartz"

class NotAModule
end

@[Quartz::Module(imports: [NotAModule])]
class RootModule
end

class Quartz::Bootstrap
  ROOT = RootModule
end
