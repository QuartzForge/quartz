# A controller without any root module: the collector must refuse the
# whole program, since modules are mandatory in 1.0.
require "../../../src/quartz"

@[Quartz::Controller]
class RootlessController
  @[Quartz::Get("/")]
  def index : String
    "x"
  end
end

@[Quartz::Module(controllers: [RootlessController])]
class RootlessModule
end
