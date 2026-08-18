# Compile-time dependency injection: `Quartz::Container` gains one lazy
# getter per annotated service and controller, so wiring mistakes fail
# the build instead of the first request. Getters resolve their
# dependencies through the sibling getters; an argument whose service was
# never registered has no getter, which compiles to an `undefined local
# variable or method` error naming it.
#
# A dependency cycle would turn lazy getters into infinite recursion at
# boot, so it is detected here, at compile time, by draining the
# dependency graph with Kahn's algorithm. The macro language has no
# `while`, so the drain runs N bounded passes, N being the service count
# — enough for any DAG — and whatever remains unsettled is in a cycle,
# named in the error.
module Quartz
  class Container; end

  @@container : Quartz::Container?

  # Returns the process-wide singleton container.
  def self.container : Quartz::Container
    @@container ||= Quartz::Container.new
  end

  macro finished
    class Quartz::Container
      {% registered = {} of Nil => Nil %}
      {% for type in Object.all_subclasses %}
        {% if type.annotation(Quartz::Service) || type.annotation(Quartz::Controller) %}
          {% registered[type.name.stringify] = type %}
        {% end %}
      {% end %}

      {% deps = {} of Nil => Nil %}
      {% for name, type in registered %}
        {% init = type.methods.find(&.name.stringify.==("initialize")) %}
        {% edges = [] of Nil %}
        {% if init %}
          {% for arg in init.args %}
            {% dep = arg.restriction.resolve.name.stringify %}
            {% if registered[dep] %}{% edges << dep %}{% end %}
          {% end %}
        {% end %}
        {% deps[name] = edges %}
      {% end %}

      {% settled = [] of Nil %}
      {% for _pass in (0...registered.size) %}
        {% for name, edges in deps %}
          {% unless settled.includes?(name) %}
            {% pending = edges.reject { |e| settled.includes?(e) } %}
            {% if pending.empty? %}{% settled << name %}{% end %}
          {% end %}
        {% end %}
      {% end %}

      {% unresolved = deps.keys.reject { |k| settled.includes?(k) } %}
      {% if unresolved.size > 0 %}
        {% raise "dependency cycle detected among services: #{unresolved.join(", ").id}" %}
      {% end %}

      {% for name, type in registered %}
        {% init = type.methods.find(&.name.stringify.==("initialize")) %}
        getter {{ type.name.gsub(/::/, "_").underscore.id }} : {{ type.name.id }} do
          {{ type.name.id }}.new(
            {% if init %}
              {% for arg in init.args %}
                {{ arg.name }}: {{ arg.restriction.resolve.name.gsub(/::/, "_").underscore.id }},
              {% end %}
            {% end %}
          )
        end
      {% end %}
    end
  end
end
