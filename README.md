# quartz

HTTP framework for robust APIs in Crystal.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     quartz:
       github: QuartzForge/quartz
   ```

2. Run `shards install`

## Usage

```crystal
require "quartz"
```

TODO: Write usage instructions here

## Development

Compile-failure fixtures under `spec/fixtures/compile_fail/` are run with
`crystal run` in a subprocess. `crystal build --no-codegen` catches macro
and type errors but never executes top-level code, so a fixture whose
failure is a runtime raise — such as the duplicate-route conflict, which
`Router.new` raises — would compile cleanly under it.

## Contributing

1. Fork it (<https://github.com/QuartzForge/quartz/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Max Aguiar](https://github.com/Aguiiiar) - creator and maintainer
