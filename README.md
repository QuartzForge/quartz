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
pieces around it are separate projects:

| Project | Role | Status |
|---|---|---|
| Facet | validation | released |
| Obsidian | ORM | planned |
| Forge | migrations | planned |
| Pulse | background jobs | planned |
| Vault | authentication | planned |
| Gem | templates | planned |

Only Facet (0.1.0) exists today. The others are planned, not available —
nothing in the list above is a dependency of Quartz, and Quartz works
fine without any of them. Today Quartz composes with the standard library
and with plain Crystal code: `HTTP::CompressHandler`,
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

@[Quartz::Module(controllers: [GreetingsController])]
class GreetingsModule; end

@[Quartz::Module(imports: [GreetingsModule])]
class AppModule; end

Quartz.configure do |config|
  config.port = 3000
  config.openapi.title = "Hello API"
end

Quartz.run(AppModule)
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

The controllers are grouped into modules. `@[Quartz::Module(controllers:
[GreetingsController])]` makes `GreetingsModule` own
`GreetingsController`, and `AppModule` imports `GreetingsModule`.
`Quartz.run(AppModule)` captures the root module at compile time and
composes the application from its import graph: the collector walks the
graph, collects the routes of every reachable module, and wires them into
the app.

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

## Modules

A module is a feature boundary: a plain class annotated with
`@[Quartz::Module]` that names the controllers it owns and the other
modules it composes.

```crystal
@[Quartz::Module(
  imports: [...],      # the modules this one composes
  controllers: [...],  # the controllers it owns
  providers: [...],    # the services it depends on, checked at compile time
)]
class FeatureModule; end
```

### The module graph

The root module — the one passed to `Quartz.run` — composes the whole
application. The collector walks its import graph, and every reachable
module contributes its controllers to the route table:

```text
AppModule (passed to Quartz.run)
├── imports GreetingsModule
│   └── controllers: GreetingsController
└── imports UsersModule
    └── controllers: UsersController
```

The mount order is deterministic: modules contribute their routes in
graph order, the root first and then each import in declaration order,
so the boot log lists the same sequence on every run.

Business modules do not import each other — only the root composes. A
feature module owns its controllers and depends on services; wiring the
features together is the root module's only job.

### Membership

Every controller must be listed in **exactly one reachable module**. A
controller listed nowhere fails the build as an orphan; one listed in
two modules is collected twice, which fails the build as a duplicate
operation id. Controllers that do not warrant a feature module of their
own can live directly on the root module.

Services stay global. `@[Quartz::Service]` registers into a single
container shared by every module — a module does not restrict what its
controllers can inject. The module graph governs which routes exist, not
which services exist.

`providers:` is documentation that the compiler validates. Every entry
must be a `@[Quartz::Service]` class — listing a service does not
register it (the annotation does), but it documents what the module
depends on, and a wrong entry is a compile error instead of a surprise
at runtime.

### No exports

There is deliberately no `exports:` entry. The container is global by
design: every service is visible to every controller. Strict visibility
was considered and left out — an `exports:` entry would narrow nothing
but the set of valid listings, which is dead API. The module boundary
organizes routes and documents dependencies; it does not hide services.

### Wiring errors

Wiring mistakes fail the build, each with a message naming the type and
what it is missing — the fix is the line the message points at:

| Mistake | Compile error |
|---|---|
| No `Quartz.run` call | `Quartz.run(AppModule) is required: no root module` |
| Root not annotated as a module | `Quartz.run expects a module annotated with @[Quartz::Module], got AppModule` |
| An `imports` entry that is not a module | `imports must be modules: UserRepo is not annotated with @[Quartz::Module]` |
| Two modules importing each other | `import cycle detected among modules: UsersModule, AuthModule` |
| A module nothing imports | `module UsersModule is not reachable from root module AppModule` |
| A controller listed in no module | `controller UsersController is not listed in any module` |
| A `controllers` entry that is not a controller | `controller UserRepo is not a controller: not annotated with @[Quartz::Controller]` |
| A `providers` entry that is not a service | `provider UserRepo is not a service: not annotated with @[Quartz::Service]` |

### Boot log

At boot, `Quartz.run` logs one line per route, naming the module that
owns it, followed by the address the server bound:

```text
route GET /greetings/:name → GreetingsController.show (GreetingsModule)
route GET /users/:id → UsersController.show (UsersModule)
listening on http://0.0.0.0:3000
```

The parenthesized name is the module whose `controllers:` entry lists
the route's controller. The table prints once at startup — one INFO line
per route, on stdout, before the server binds — so a fresh developer
can see every route the app actually serves.

## Migrating from 0.1

Version 1.0.0 requires the module system, and 0.1 code does not compile
until it is in place. The migration is three steps, and the compiler
guides it — each error names the missing piece:

1. **Create the root module.** Declare `@[Quartz::Module] class
   AppModule; end` with an `imports:` list naming your feature modules.
   A module with an empty list is fine if you would rather start from
   the root.
2. **List each controller in a module.** Put every
   `@[Quartz::Controller]` class in exactly one module's `controllers:`
   entry — its own feature module, or the root if the feature does not
   warrant one.
3. **Pass the root to `Quartz.run`.** `Quartz.run` becomes
   `Quartz.run(AppModule)`.

Nothing else changes. `@[Quartz::Service]` registration and injection,
the path prefix, middlewares, `Quartz.configure`, the RFC 9457 errors,
and the OpenAPI document all work exactly as in 0.1 — a successful
migration touches only the three lines above. If something else fails to
compile, the error is one of the wiring errors in the previous section.

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
(`{}`). The references always resolve, but 1.0.0 has no hook to supply
the real schema; expect that gap to close in a later version. Return
types get an inline empty schema on the success response instead.

## Configuration

```crystal
Quartz.configure do |config|
  config.host = "127.0.0.1"
  config.port = 3000
  config.path_prefix = "/api/v1"
  config.cors_origins = ["https://app.example.com"]
  config.request_timeout = 5.seconds
  config.middlewares = [MyMiddleware.new]
  config.openapi.title = "My API"
  config.openapi.version = "2.0.0"
  config.openapi.path = "/docs/openapi.json"
end
```

Everything is optional; the defaults are host `0.0.0.0`, port `3000`,
no path prefix (every route lives at its declared path), CORS open
(`["*"]`), timeout 30 seconds, no user middlewares, and the OpenAPI
settings above. Mutate config only through `Quartz.configure` — editing
`Quartz.config` directly leaves a memoized application serving stale
values.

`path_prefix` mounts every route — application routes and the OpenAPI
document — under a static prefix, and the OpenAPI document reports the
prefixed paths:

```crystal
Quartz.configure do |config|
  config.path_prefix = "/api/v1"
end
# GET /api/v1/users/:id  →  ExampleController#show
# GET /api/v1/openapi.json → the document, whose paths start with /api/v1
```

The prefix must start with `/` and contain only static segments — a
placeholder there would have no parameter to bind. Setting it invalid
raises `Quartz::ConfigError` when the application is built.

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
