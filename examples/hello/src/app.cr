require "../../../src/quartz"

record Greeting, message : String do
  include JSON::Serializable
end

@[Quartz::Service]
class GreetingService
  def greet(name : String) : Greeting
    Greeting.new("Hello, #{name}!")
  end
end

@[Quartz::Controller(prefix: "/greetings")]
class GreetingsController
  def initialize(@service : GreetingService)
  end

  @[Quartz::Get("/:name")]
  def show(name : String) : Greeting
    @service.greet(name)
  end
end

@[Quartz::Module(controllers: [GreetingsController])]
class GreetingsModule; end

@[Quartz::Module(imports: [GreetingsModule])]
class AppModule; end

Quartz.configure do |config|
  config.port = 3000
  config.openapi.title = "Hello API"
end

Quartz.run(AppModule)
