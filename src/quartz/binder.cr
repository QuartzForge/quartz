module Quartz
  # Converts every parameter of a request into a `Bound` value before the
  # controller runs.
  #
  # All failures are collected and raised as a single `BindError`, so the
  # client can fix every parameter in one round trip. Parameters sourced
  # from the body are skipped: deserialization needs the static type, so
  # `Context#body_as` handles them instead.
  module Binder
    # Converts all of `params` from `ctx` into a `Bound`.
    #
    # Raises `BindError` when a required parameter is missing or a value
    # fails to convert, carrying every failure in declaration order.
    def self.call(params : Array(Quartz::ParamDef), ctx : Quartz::Context) : Quartz::Bound
      values = {} of String => Quartz::Bound::Value
      failures = [] of Quartz::FieldError

      params.each do |param|
        next if param.source.body?

        raw = raw_value(param, ctx)

        if raw.nil? || raw.empty?
          if param.required?
            failures << Quartz::FieldError.new(
              param.name, param.source.to_wire, "missing required parameter"
            )
          end
          next
        end

        begin
          values[param.name] = Quartz::Converter.convert(raw, param.type_name)
        rescue ex : Quartz::Converter::Error
          failures << Quartz::FieldError.new(
            param.name, param.source.to_wire, ex.message.to_s
          )
        end
      end

      raise Quartz::BindError.new(failures) unless failures.empty?

      Quartz::Bound.new(values)
    end

    private def self.raw_value(param : Quartz::ParamDef, ctx : Quartz::Context) : String?
      case param.source
      in .path?   then ctx.path_params[param.name]?
      in .query?  then ctx.request.query[param.name]?
      in .header? then ctx.request.headers[param.name]?
      in .body?   then nil
      end
    end
  end
end
