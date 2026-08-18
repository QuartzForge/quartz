module Quartz
  # A trie of registered routes that resolves a verb and path to a
  # route and its path parameters.
  #
  # Segment matching precedence at each depth is static, then named
  # param (`:id`), then wildcard (`*rest`). Duplicate routes raise
  # `ConfigError` at construction time: the same verb and path, two
  # different param names at the same position, or two different
  # wildcard names at the same position.
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

    def initialize(routes : Array(Quartz::RouteDef))
      routes.each { |route| insert(route) }
    end

    private def insert(route : Quartz::RouteDef) : Nil
      node = @root

      route.segments.each do |segment|
        case segment[0]?
        when ':'
          name = segment[1..]
          if existing = node.param_name
            unless existing == name
              raise Quartz::ConfigError.new(
                "route conflict: '#{route.path}' declares ':#{name}' " \
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
                "route conflict: '#{route.path}' declares '*#{name}' " \
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

      if node.leaves.has_key?(route.verb)
        raise Quartz::ConfigError.new("route conflict: #{route.verb} #{route.path}")
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
    # cannot match the remaining path.
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
