# A root module hand-declared as Quartz::Bootstrap::ROOT without the
# @[Quartz::Module] annotation: the collector must refuse it at
# expansion time, naming the offending type.
require "../../../src/quartz"

class NotAModule
end

class Quartz::Bootstrap
  ROOT = NotAModule
end
