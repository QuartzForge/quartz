# Probes for collector behaviors the spec suite cannot exercise
# in-process: annotated controllers here would change the global
# `Quartz::ROUTES` that collector_spec asserts exactly. Each probe
# dispatches a request through the application seam and raises on any
# mismatch, so the spec needs only a clean exit.
require "../../../src/quartz"

@[Quartz::Controller]
class ProbeController
  @[Quartz::Get("/ping")]
  def ping : String
    "pong"
  end

  @[Quartz::Get("/greet")]
  def greet(name : String?) : String
    name || "nobody"
  end

  @[Quartz::Get("/hello")]
  def hello(@[Quartz::Header] user_agent : String) : String
    "hello #{user_agent}"
  end
end

@[Quartz::Controller(prefix: "welcome")]
class WelcomeController
  @[Quartz::Get("/home")]
  def home : String
    "home"
  end
end

app = Quartz::Application.new(
  Quartz::Router.new(Quartz::ROUTES),
  Quartz::Pipeline.new([] of Quartz::Middleware),
)

def dispatch(app : Quartz::Application, method : String, path : String, headers : HTTP::Headers = HTTP::Headers.new) : Quartz::Response
  uri = URI.parse(path)
  app.handle(
    Quartz::Request.new(
      method: method,
      path: uri.path,
      query: HTTP::Params.parse(uri.query || ""),
      headers: headers,
      body: nil,
    )
  )
end

paths = Quartz::ROUTES.map(&.path).sort
raise "expected normalized paths, got #{paths}" unless paths == ["/greet", "/hello", "/ping", "/welcome/home"]

ping = Quartz::ROUTES.find { |r| r.path == "/ping" }.not_nil!
raise "expected a parameterless route to collect no params" unless ping.params.empty?

ids = Quartz::ROUTES.map(&.operation_id)
raise "expected unique operation ids, got #{ids}" unless ids.uniq.size == ids.size

raise "expected no-prefix route to be served, got #{dispatch(app, "GET", "/ping").body}" unless dispatch(app, "GET", "/ping").body == %("pong")
raise "expected a nilable param to default to nil, got #{dispatch(app, "GET", "/greet").body}" unless dispatch(app, "GET", "/greet").body == %("nobody")
raise "expected a nilable param to bind when present, got #{dispatch(app, "GET", "/greet?name=bob").body}" unless dispatch(app, "GET", "/greet?name=bob").body == %("bob")

headers = HTTP::Headers.new
headers["user_agent"] = "probe"
hello = dispatch(app, "GET", "/hello", headers)
raise "expected a header param to be read, got #{hello.body}" unless hello.body == %("hello probe")

home = dispatch(app, "GET", "/welcome/home")
raise "expected a prefix without leading slash to be normalized, got #{home.body}" unless home.body == %("home")
