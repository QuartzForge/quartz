module Quartz
  # A trie of registered routes that resolves a verb and path to a
  # route and its path parameters.
  #
  # A path prefix mounts every route under it: `Router.new(routes,
  # prefix: "/api/v1")` matches `/api/v1/...` only. The prefix is
  # applied to the trie at construction time, so `route.path` and the
  # OpenAPI document stay canonical and only the router knows the
  # prefix exists.
  #
  # Segment matching precedence at each depth is static, then named
  # param (`:id`), then wildcard (`*rest`). Ambiguous route tables
  # raise `ConfigError` at construction time: a verb and path declared
  # twice, two placeholder names at the same position, a path that
  # repeats a placeholder name or has segments after its wildcard, or
  # a wildcard shadowing a plain route of the same verb.
  class Router
    # The result of a successful match: the matched route and the
    # path parameters extracted from the request path.
    struct Match
      getter route : Quartz::RouteDef
      getter path_params : Hash(String, String)

      def initialize(@route : Quartz::RouteDef, @path_params : Hash(String, String))
      end
    end

    private class Node
      property statics = {} of String => Node
      property param_name : String?
      property param_node : Node?
      property wildcard_name : String?
      property wildcard_verbs = Set(String).new
      property leaves = {} of String => Quartz::RouteDef
    end

    @root = Node.new
    @prefix : String

    def initialize(routes : Array(Quartz::RouteDef), prefix : String = "/")
      validate_prefix(prefix)
      @prefix = prefix
      routes.each { |route| insert(route) }
    end

    # The prefix may only be static: a placeholder would have no
    # `ParamDef` to bind its captured value, and a wildcard would blur
    # where the router's own segments begin.
    private def validate_prefix(prefix : String) : Nil
      raise Quartz::ConfigError.new("path prefix must start with '/'") unless prefix.starts_with?('/')
      if prefix.split('/').reject(&.empty?).any? { |segment| kind = segment[0]?; kind == ':' || kind == '*' }
        raise Quartz::ConfigError.new("path prefix may only contain static segments")
      end
    end

    # A route path may not repeat a placeholder name, since the later
    # occurrence could never bind its own value; and a wildcard must
    # be the last segment, since it captures everything after it.
    private def check_placeholders(verb : String, path : String, segments : Array(String)) : Nil
      seen = Set(String).new
      segments.each_with_index do |segment, index|
        kind = segment[0]?
        next unless kind == ':' || kind == '*'
        name = segment[1..]
        if seen.includes?(name)
          raise Quartz::ConfigError.new(
            "route conflict: #{verb} '#{path}' declares " \
            "'#{segment}' more than once"
          )
        end
        if kind == '*' && index != segments.size - 1
          raise Quartz::ConfigError.new(
            "route conflict: #{verb} '#{path}' has " \
            "segments after wildcard"
          )
        end
        seen.add(name)
      end
    end

    # Whether the route declares a wildcard as its last segment.
    private def wildcard?(route : Quartz::RouteDef) : Bool
      last = route.segments.last?
      last ? last.starts_with?('*') : false
    end

    private def insert(route : Quartz::RouteDef) : Nil
      effective = Quartz.join_paths(@prefix, route.path)
      segments = effective.split('/').reject(&.empty?)
      check_placeholders(route.verb, effective, segments)
      node = @root

      segments.each do |segment|
        case segment[0]?
        when ':'
          name = segment[1..]
          if existing = node.param_name
            unless existing == name
              raise Quartz::ConfigError.new(
                "route conflict: #{route.verb} '#{effective}' declares ':#{name}' " \
                "where ':#{existing}' is already defined at the same position"
              )
            end
          else
            node.param_name = name
          end
          node = node.param_node ||= Node.new
        when '*'
          name = segment[1..]
          if existing = node.wildcard_name
            unless existing == name
              raise Quartz::ConfigError.new(
                "route conflict: #{route.verb} '#{effective}' declares '*#{name}' " \
                "where '*#{existing}' is already defined at the same position"
              )
            end
          else
            node.wildcard_name = name
          end
          node.wildcard_verbs.add(route.verb)
          break
        else
          node = (node.statics[segment] ||= Node.new)
        end
      end

      if existing = node.leaves[route.verb]?
        route_is_wild = wildcard?(route)
        if route_is_wild != wildcard?(existing)
          wildcard_path = Quartz.join_paths(@prefix, (route_is_wild ? route : existing).path)
          shadowed = route_is_wild ? existing : route
          raise Quartz::ConfigError.new(
            "route conflict: #{route.verb} '#{Quartz.join_paths(@prefix, shadowed.path)}' is shadowed " \
            "by wildcard '#{wildcard_path}'"
          )
        end
        raise Quartz::ConfigError.new("route conflict: #{route.verb} #{effective}")
      end
      node.leaves[route.verb] = route
    end

    # Resolves a request verb and path to its route. A trailing slash
    # on `path` is ignored. Returns `nil` when no route matches.
    def match(verb : String, path : String) : Match?
      segments = path.split('/').reject(&.empty?)
      params = {} of String => String

      node = descend(@root, segments, 0, params, verb)
      return unless node

      route = node.leaves[verb]?
      return unless route

      Match.new(route, params)
    end

    # Walks the trie one segment at a time, trying the static branch
    # first and backtracking to param, then wildcard, when a branch
    # cannot match the remaining path. A wildcard route matches only
    # through the wildcard branch, which requires at least one
    # remaining segment.
    private def descend(
      node : Node,
      segments : Array(String),
      index : Int32,
      params : Hash(String, String),
      verb : String,
    ) : Node?
      if index == segments.size
        return node if node.leaves.has_key?(verb) && !node.wildcard_verbs.includes?(verb)
        return
      end

      segment = segments[index]

      if child = node.statics[segment]?
        if result = descend(child, segments, index + 1, params, verb)
          return result
        end
      end

      if (name = node.param_name) && (child = node.param_node)
        params[name] = segment
        if result = descend(child, segments, index + 1, params, verb)
          return result
        end
        params.delete(name)
      end

      if (name = node.wildcard_name) && node.wildcard_verbs.includes?(verb)
        params[name] = segments[index..].join('/')
        return node
      end

      nil
    end
  end
end
