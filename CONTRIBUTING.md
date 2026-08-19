# Contributing

## Setup

```bash
./scripts/setup
```

This runs `shards install` and installs the **Crystalline** language
server. Crystalline is not a shard — it is a system binary installed by
the script, which is why it does not appear in `shard.yml`.

## Before opening a PR

All three must pass:

```bash
crystal tool format
./bin/ameba
crystal spec
```

The suite runs the unit specs, the compile-failure fixtures, and the
OpenAPI golden-file comparison. A PR that changes behavior is expected
to add or update specs with it.

## Compile-failure tests

`spec/fixtures/compile_fail/` contains programs that **must** fail to
compile. They cover the framework's central promise: wrong wiring is a
compile error, not a production error. When you add a compile-time check,
add the corresponding fixture — a check without a fixture has no test.

Note that `crystal build --no-codegen` catches macro and type errors but
never executes top-level code, so a fixture whose failure is a runtime
raise — such as the duplicate-route conflict, which `Router.new` raises —
would compile cleanly under it. The spec suite runs those with
`crystal run` in a subprocess.

## OpenAPI golden file

`spec/fixtures/openapi/example_app.json` is the contract of the generated
document. Changes to it appear as a diff in the PR and need a
justification — the document is a public API of the framework, and
silently changing it breaks consumers.

## Commit messages

Follow the conventional-commit style used in the history (`feat:`,
`fix:`, `test:`, `docs:`). No `Co-Authored-By` trailers.
