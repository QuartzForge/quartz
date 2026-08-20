# The single macro pass of the framework. It only collects: it reads the
# annotations and emits `Quartz::ROUTES`, a plain array of `RouteDef`
# values. No routing, binding, or serialization logic lives here — all of
# that is ordinary Crystal code with its own specs.
module Quartz
  # Emitted at the end of the program, when every annotated type is
  # known. The constant is declared bare so it lands in this module's
  # scope: a `finished` expansion that reopens `module Quartz` makes the
  # compiler re-visit its body, where deferred constant lookups fail.
  macro finished
    {% if Quartz::Bootstrap.has_constant?("ROOT") %}
      {% root = Quartz::Bootstrap::ROOT.resolve %}
    {% else %}
      {% raise "Quartz.run(AppModule) is required: no root module" %}
    {% end %}

    {% all_mods = [] of Nil %}
    {% for type in Object.all_subclasses %}
      {% if type.annotation(Quartz::Module) %}{% all_mods << type %}{% end %}
    {% end %}

    # Imports must be modules: validate every edge while building the
    # adjacency map, before any traversal can assume it.
    {% imports_of = {} of Nil => Nil %}
    {% for m in all_mods %}
      {% ann = m.annotation(Quartz::Module) %}
      {% imps = [] of Nil %}
      {% for p in (ann[:imports] || [] of Nil) %}
        {% imp = p.resolve %}
        {% if imp.annotation(Quartz::Module) %}
          {% imps << imp %}
        {% else %}
          {% raise "imports must be modules: #{imp.name} is not annotated with @[Quartz::Module]" %}
        {% end %}
      {% end %}
      {% imports_of[m.name] = imps %}
    {% end %}

    # Module cycles are detected by draining the import graph with
    # Kahn's algorithm, as N bounded passes (the macro language has no
    # while); whatever never settles is in a cycle, named in the error.
    {% settled = [] of Nil %}
    {% for _pass in (0...all_mods.size) %}
      {% for m in all_mods %}
        {% unless settled.includes?(m) %}
          {% pending = imports_of[m.name].reject { |i| settled.includes?(i) } %}
          {% if pending.empty? %}{% settled << m %}{% end %}
        {% end %}
      {% end %}
    {% end %}
    {% unresolved = all_mods.reject { |mod| settled.includes?(mod) } %}
    {% if unresolved.size > 0 %}
      {% raise "import cycle detected among modules: #{unresolved.map(&.name).join(", ").id}" %}
    {% end %}

    # Everything annotated must be reachable from the root: an unimported
    # module is a wiring mistake, not a dormant feature.
    {% seen = [root] %}
    {% for _pass in (0...all_mods.size + 1) %}
      {% for m in seen %}
        {% for imp in imports_of[m.name] %}
          {% unless seen.includes?(imp) %}{% seen << imp %}{% end %}
        {% end %}
      {% end %}
    {% end %}
    {% unreachable = all_mods.reject { |mod| seen.includes?(mod) } %}
    {% if unreachable.size > 0 %}
      {% raise "module #{unreachable[0].name} is not reachable from root module #{root.name}" %}
    {% end %}

    {% operation_ids = [] of Nil %}

    ROUTES = [
      {% for type in Object.all_subclasses %}
        {% controller = type.annotation(Quartz::Controller) %}
        {% if controller %}
          {% prefix = (controller[:prefix] || "").id.stringify %}

          {% for method in type.methods %}
            {% verb = nil %}
            {% route = nil %}
            {% if found = method.annotation(Quartz::Get) %}
              {% verb = "GET" %}{% route = found %}
            {% elsif found = method.annotation(Quartz::Post) %}
              {% verb = "POST" %}{% route = found %}
            {% elsif found = method.annotation(Quartz::Put) %}
              {% verb = "PUT" %}{% route = found %}
            {% elsif found = method.annotation(Quartz::Patch) %}
              {% verb = "PATCH" %}{% route = found %}
            {% elsif found = method.annotation(Quartz::Delete) %}
              {% verb = "DELETE" %}{% route = found %}
            {% end %}

            {% if verb %}
              {% operation_id = "#{type.name}.#{method.name}" %}
              {% if operation_ids.includes?(operation_id) %}
                {% raise "duplicate operation id: #{operation_id} is emitted by more than one annotated method" %}
              {% end %}
              {% operation_ids << operation_id %}

              {% suffix = route[0] || "" %}
              {% joined = prefix + suffix %}
              {% path = joined.gsub(/\/+/, "/") %}
              {% path = path.size > 1 && path.ends_with?("/") ? path[0..-2] : path %}
              {% path = path.empty? ? "/" : (path.starts_with?("/") ? path : "/" + path) %}
              {% path_segments = path.split("/") %}
              {% status = route[:status] || 200 %}

              Quartz::RouteDef.new(
                verb: {{ verb }},
                path: {{ path }},
                status: {{ status }},
                operation_id: {{ operation_id }},
                params: [
                  {% for arg in method.args %}
                    {% name = arg.name.stringify %}
                    {% source = if path_segments.includes?(":" + name) ||
                                   path_segments.includes?("*" + name)
                                  "Quartz::ParamSource::Path"
                                elsif arg.name.stringify == "body"
                                  "Quartz::ParamSource::Body"
                                elsif arg.annotation(Quartz::Header)
                                  "Quartz::ParamSource::Header"
                                else
                                  "Quartz::ParamSource::Query"
                                end %}
                    {% has_default = !arg.default_value.is_a?(Nop) %}
                    {% resolved = arg.restriction.resolve %}
                    {% nilable = resolved.nilable? %}
                    {% type_name = (nilable ? resolved.union_types.reject { |candidate| candidate.name.stringify == "Nil" }.first : resolved).name.stringify %}

                    Quartz::ParamDef.new(
                      name: {{ arg.name.stringify }},
                      type_name: {{ type_name }},
                      source: {{ source.id }},
                      required: {{ !has_default && !nilable }},
                    ),
                  {% end %}
                ] of Quartz::ParamDef,
                action: ->(ctx : Quartz::Context, bound : Quartz::Bound) : Quartz::Response {
                  # The cast keeps the proc body's static type non-NoReturn.
                  # The compiler's cleanup pass replaces any proc literal
                  # whose body is an untyped NoReturn expression with a
                  # runtime raise: a call with a NoReturn-typed argument —
                  # like the controller call below — stays untyped, while a
                  # bare `raise` body receives a type and is safe. The body
                  # shape, not where the literal came from, is what decides;
                  # without the cast every exception a controller raises
                  # would surface as a generic 500 instead of the error the
                  # framework's own handler would render.
                  Quartz::Serializer.call(
                    Quartz.container.{{ type.name.gsub(/::/, "_").underscore.id }}.{{ method.name }}(
                      {% for arg in method.args %}
                        {% if arg.name.stringify == "body" %}
                          {{ arg.name }}: ctx.body_as({{ arg.restriction }}),
                        {% elsif !arg.default_value.is_a?(Nop) %}
                          {{ arg.name }}: bound.fetch?({{ arg.name.stringify }}, {{ arg.restriction }}) || {{ arg.default_value }},
                        {% elsif arg.restriction.resolve.nilable? %}
                          {{ arg.name }}: bound.fetch?({{ arg.name.stringify }}, {{ arg.restriction }}),
                        {% else %}
                          {{ arg.name }}: bound.fetch({{ arg.name.stringify }}, {{ arg.restriction }}),
                        {% end %}
                      {% end %}
                    ),
                    {{ status }},
                  ).as(Quartz::Response)
                },
              ),
            {% end %}
          {% end %}
        {% end %}
      {% end %}
    ] of Quartz::RouteDef
  end
end
