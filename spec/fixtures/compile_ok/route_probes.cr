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

@[Quartz::Controller(prefix: "/u")]
class SegmentProbeController
  @[Quartz::Get("/:identifier")]
  def show(identifier : Int64, id : String = "PADRAO") : String
    "ident=#{identifier} id=#{id}"
  end
end

@[Quartz::Controller]
class RaisingController
  @[Quartz::Get("/conflict")]
  def conflict : String
    raise Quartz::Conflict.new("email taken")
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
raise "expected normalized paths, got #{paths}" unless paths == ["/conflict", "/greet", "/hello", "/ping", "/u/:identifier", "/welcome/home"]

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

segment_route = Quartz::ROUTES.find { |r| r.path == "/u/:identifier" }.not_nil!
identifier = segment_route.params.find { |p| p.name == "identifier" }.not_nil!
id = segment_route.params.find { |p| p.name == "id" }.not_nil!
raise "expected a full-segment placeholder to classify as a path param" unless identifier.source.path?
raise "expected a param merely containing a placeholder name to classify as a query param" unless id.source.query?

segment = dispatch(app, "GET", "/u/42?id=DAQUERY")
raise "expected the query value to reach the method, got #{segment.body}" unless segment.body == %("ident=42 id=DAQUERY")

# A controller method that always raises must propagate its own exception
# through the generated action: the compiler replaces an expanded proc
# literal whose body is an untyped NoReturn expression with a runtime
# raise, which would otherwise turn this Conflict into a generic 500.
conflict = begin
  dispatch(app, "GET", "/conflict")
  nil
rescue ex : Exception
  ex
end
raise "expected Quartz::Conflict to propagate, got #{conflict.class}: #{conflict}" unless conflict.is_a?(Quartz::Conflict)
raise "expected the controller's message, got #{conflict.message}" unless conflict.message == "email taken"
