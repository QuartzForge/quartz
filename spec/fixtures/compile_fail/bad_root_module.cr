# A root module that is not annotated with @[Quartz::Module]: the run
# macro must refuse it at expansion time, naming the offending type.
require "../../../src/quartz"

class NotAModule
end

Quartz.run(NotAModule)
