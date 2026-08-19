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
                    {% source = if path_segments.includes?(":" + arg.name.stringify)
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
                  # The cast keeps the proc body's static type non-NoReturn:
                  # the compiler's cleanup pass replaces an expanded proc
                  # literal whose body is an untyped NoReturn expression
                  # with a runtime raise, which would turn every exception
                  # a controller raises into a generic 500 instead of the
                  # error the framework's own handler would render.
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
