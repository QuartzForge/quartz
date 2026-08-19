# Quartz

Quartz is an HTTP framework for APIs in Crystal. Routes are declared with
annotations on plain controller classes, dependencies are wired at compile
time, every error is an [RFC 9457](https://www.rfc-editor.org/rfc/rfc9457)
problem document, and an OpenAPI 3.1 document is generated from the
annotations you already wrote.

It is deliberately small. The framework compiles to a single pass that
collects routes (`Quartz::ROUTES`), a router, a binder, five middlewares,
and a thin adapter onto the standard library's `HTTP::Server`. Everything
else comes from the stdlib and the ecosystem.

## What Quartz is not

Quartz is an API framework, not a full-stack framework. It ships no
templates, no asset pipeline, and no ORM, and it does not plan to. The
pieces around it are separate projects, and — to be clear — **none of them
exist yet**:

| Project | Role |
|---|---|
| Obsidian | ORM |
| Facet | validation |
| Forge | migrations |
| Pulse | background jobs |
| Vault | authentication |
| Gem | templates |

Treat them as planned, not available. Today Quartz composes with the
standard library and with plain Crystal code: `HTTP::CompressHandler`,
`HTTP::StaticFileHandler`, and your own `HTTP::Handler`s run outside the
framework.

## Installation

Add the dependency to your `shard.yml`:

```yaml
dependencies:
  quartz:
    github: QuartzForge/quartz
```

Then:

```bash
shards install
```

and `require "quartz"` in your entry point.

## A complete working example

This is `examples/hello/` in this repository — it compiles and runs
as-is. The only difference from the file on disk is the `require` line:
your app requires the installed shard (`"quartz"`), the in-repo example
requires the sources relatively.

```crystal
require "quartz"

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

Quartz.configure do |config|
  config.port = 3000
  config.openapi.title = "Hello API"
end

Quartz.run
```

Build it and run it:

```bash
crystal build examples/hello/src/app.cr -o /tmp/quartz-hello
/tmp/quartz-hello &
sleep 2
curl -s localhost:3000/greetings/Ana
curl -s localhost:3000/openapi.json | head -c 200
curl -s -o /dev/null -w "%{http_code}\n" localhost:3000/greetings
kill %1
```

What you get back:

```text
{"message":"Hello, Ana!"}
{"openapi":"3.1.0","info":{"title":"Hello API","version":"1.0.0"},"paths":{"/greetings/{name}":{"get":{"operationId":"GreetingsController.show","parameters":[{"name":"name","in":"path","required":true
404
```

Three things are happening here. `@[Quartz::Controller]` and
`@[Quartz::Get]` declare the route; the `:name` segment in the path is
matched and bound to the `name` argument. `@[Quartz::Service]` registers
the service with the compile-time container, which injects it into the
controller's `initialize` — and if a controller asks for a service that is
not registered, **the program does not compile**. The route's return value
is serialized to JSON with the status the annotation declared (200 by
default).

`Quartz.configure` tunes the server before `Quartz.run` starts it. Config
changes must go through `Quartz.configure` — it drops the memoized
application so the next request is built from the new values.

## Dependencies

`@[Quartz::Service]` registers a class with the compile-time container,
which injects it into any controller or service that asks for it in
`initialize`. Wiring is checked at compile time: a controller that asks
for a class that was never registered does not compile, with an
`undefined local variable or method` error naming the missing
dependency.

Only annotated services can be injected directly. Anything external — a
database handle, an HTTP client, a configuration object read from the
environment — is not annotated, so it cannot be injected. Wrap it in a
small annotated provider that constructs it, and inject the provider:

```crystal
@[Quartz::Service]
class Db
  getter handle : DB::Database

  def initialize
    @handle = DB.open(ENV.fetch("DATABASE_URL", "postgres://localhost/quartz"))
  end
end

@[Quartz::Service]
class PostRepo
  def initialize(@db : Db)
  end

  def latest : Post
    @db.handle.query_one("SELECT ...", as: Post)
  end
end
```

`PostRepo` takes `Db`, not `DB::Database` — the container only knows the
types it registered, so injecting the raw handle directly would not
compile. The provider behaves like any other service: one shared
instance per process, and its own constructor arguments are resolved
from the same container.

## How arguments become request parameters

The binder reads one value per argument, and the argument's name and
annotation decide where it comes from:

| Declaration | Source |
|---|---|
| Named like a `:segment` in the route path | Path segment |
| Named `body` | Request body, JSON-deserialized into the declared type |
| Annotated `@[Quartz::Header]` | Request header |
| Anything else | Query string |

Examples:

```crystal
@[Quartz::Get("/users/:id")]
def show(id : Int64) : User
  # id comes from the path: /users/7 -> 7
end

@[Quartz::Get("/users")]
def index(page : Int32 = 1, @[Quartz::Header] user_agent : String = "anon") : Array(User)
  # page comes from the query string, user_agent from a header
end

@[Quartz::Post("/users", status: 201)]
def create(body : CreateUserPayload) : User
  # body is JSON-deserialized into CreateUserPayload
end
```

An argument is **required** unless it has a default value or a nilable
type; a missing or unparseable required argument is a 400 listing every
failed field. Query, header, and path values are converted by declared
type — `String`, `Int32`, `Int64`, `Float64`, `Bool`, `UUID`, and `Time`
(RFC 3339). Any other type on a non-body argument fails at bind time as
a 400: the converter knows exactly the seven types above. A header
argument binds by its exact name, matched case-insensitively —
`@[Quartz::Header] user_agent` reads a header spelled `user_agent`.

Routes support static segments, `:named` parameters, and a trailing
`*wildcard` that captures the rest of the path. At each position, a static
segment wins over a named parameter, which wins over the wildcard.

## The canonical middleware pipeline

Every request runs through a fixed pipeline, outermost first:

| # | Middleware | Job |
|---|---|---|
| 1 | `RequestId` | Assigns `x-request-id` (keeps a client-supplied one), echoed back on the response |
| 2 | `Logger` | One log entry per request: method, path, status, duration, request id |
| 3 | `CORS` | CORS headers and preflight handling |
| 4 | `ErrorHandler` | Turns every exception into a problem+json response |
| 5 | `Timeout` | 504 when a request runs past its deadline |
| 6 | Your middlewares (`config.middlewares`) | Innermost, just outside the router |
| 7 | — | Router and controller dispatch |

Order is a contract, not a suggestion. The pipeline is an onion: a
middleware listed earlier wraps those after it, entering the request first
and seeing the response last. That is why `CORS` sits **outside**
`ErrorHandler`. If the order were reversed, a controller exception would
unwind past CORS before the error handler rebuilt the response — the error
response would leave the pipeline without CORS headers, and a browser
would report a network error instead of rendering a readable 409. The
onion also explains the rest: the request id exists before anything logs,
the logger sees the final status even on errors, and your middlewares run
inside every built-in.

## Errors: RFC 9457

Every client-facing failure is a single format, `application/problem+json`
([RFC 9457](https://www.rfc-editor.org/rfc/rfc9457)). Raise the built-in
`Quartz::HTTPError` subclasses — `BadRequest`, `Unauthorized`, `Forbidden`,
`NotFound`, `Conflict`, `UnprocessableEntity` — and the error handler
renders them. Binding failures are 400s that list every failed field.
Anything else is a 500 whose body reveals nothing about the exception;
the stack trace goes to the log with the request id so you can correlate
it.

A real response from the example above, with no route matching
`GET /greetings`:

```text
HTTP/1.1 404 Not Found
content-type: application/problem+json
access-control-allow-origin: *
x-request-id: ohFY6ZKTyyz7-YtJ
```

```json
{
  "type": "https://quartzforge.org/errors/not-found",
  "title": "Not Found",
  "status": 404,
  "detail": "No route matches GET /greetings",
  "instance": "/greetings",
  "request_id": "ohFY6ZKTyyz7-YtJ"
}
```

`type`, `title`, and `status` are always present; `detail`, `instance`,
`request_id`, and `errors` appear only when they have values. The request
id is generated per request, so it varies — send your own `x-request-id`
to keep it stable across services.

## OpenAPI

Quartz generates an OpenAPI 3.1.0 document from the collected annotations:
one path entry per route, parameters with their sources and types, request
bodies, and the declared success status plus the 400/404/500 problem
responses. The document is served at `config.openapi.path` (default
`/openapi.json`) and is rebuilt per request, so changing the title or
version is reflected immediately. The spec suite pins the document to a
golden file and asserts conformance to the 3.1 structure.

One honest caveat: a request body of a user-defined type — the
`CreateUserPayload` from the parameter examples above — is referenced
by name under `components/schemas` with an **empty placeholder schema**
(`{}`). The references always resolve, but 0.1.0 has no hook to supply
the real schema; expect that gap to close in a later version. Return
types get an inline empty schema on the success response instead.

## Configuration

```crystal
Quartz.configure do |config|
  config.host = "127.0.0.1"
  config.port = 3000
  config.cors_origins = ["https://app.example.com"]
  config.request_timeout = 5.seconds
  config.middlewares = [MyMiddleware.new]
  config.openapi.title = "My API"
  config.openapi.version = "2.0.0"
  config.openapi.path = "/docs/openapi.json"
end
```

Everything is optional; the defaults are host `0.0.0.0`, port `3000`,
CORS open (`["*"]`), timeout 30 seconds, no user middlewares, and the
OpenAPI settings above. Mutate config only through `Quartz.configure` —
editing `Quartz.config` directly leaves a memoized application serving
stale values.

## Known limitations

Quartz is honest about its edges. All four below are real; read them
before you build on this version.

**`Timeout` does not shed load.** Crystal cannot cancel a running fiber,
so when the deadline fires the client receives the 504 but the handler
keeps running to completion. The middleware protects the client, not the
server: the work is not shed, and slow endpoints can still pile up
fibers. Revisit when Crystal gains fiber cancellation.

**An annotated overload with a default argument can silently vanish.**
Crystal generates an implicit method definition for a defaulted argument
that replaces an explicit definition of the same signature. If the
annotation sits on such a method, it disappears with no error, the
collector never sees it, and the route is simply absent. This is compiler
behavior, not something Quartz can intercept — if a route is missing and
the class compiles cleanly, check for a same-signature overload with a
default argument.

**A repeated query key binds only the first value.** `?tag=a&tag=b` yields
`"a"`. No route can declare an array parameter in this version.

**Method doc comments are not collected into the OpenAPI `summary`
field.** The plumbing exists — every route and operation carries a
`summary` — but the collector never populates it, so operations in the
generated document have none. The field is optional in OpenAPI, so
validators accept its absence; doc-comment collection is planned for a
later version.

## Development

```bash
./scripts/setup
```

This runs `shards install` and installs the **Crystalline** language
server. Crystalline is not a shard — it is a system binary installed by
the script, which is why it does not appear in `shard.yml`.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow, the compile-time
guarantee, and how the OpenAPI golden file is treated.

## License

MIT.
