module Quartz
  # Converts a raw wire value to the type declared on a `ParamDef`.
  #
  # The binder calls `convert` once per parameter it reads, keyed by the
  # type name written in the route definition. Failures raise
  # `Converter::Error` so the binder can turn them into `FieldError`s.
  module Converter
    # Raised when a raw value does not parse as the declared type, or
    # when the type name is not one the converter supports.
    class Error < Quartz::Error; end

    # Converts `raw` to the type named by `type_name`, one of `"String"`,
    # `"Int32"`, `"Int64"`, `"Float64"`, `"Bool"`, `"UUID"`, or `"Time"`.
    #
    # Raises `Converter::Error` when the value does not parse or the
    # type name is unsupported.
    def self.convert(raw : String, type_name : String) : Quartz::Bound::Value
      case type_name
      when "String"  then raw
      when "Int32"   then raw.to_i32? || invalid(raw, type_name)
      when "Int64"   then raw.to_i64? || invalid(raw, type_name)
      when "Float64" then raw.to_f64? || invalid(raw, type_name)
      when "Bool"    then to_bool(raw)
      when "UUID"    then to_uuid(raw)
      when "Time"    then to_time(raw)
      else                invalid_type(type_name)
      end
    end

    private def self.to_bool(raw : String) : Bool
      case raw.downcase
      when "true", "1"  then true
      when "false", "0" then false
      else                   invalid(raw, "Bool")
      end
    end

    private def self.to_uuid(raw : String) : UUID
      UUID.new(raw)
    rescue ArgumentError
      invalid(raw, "UUID")
    end

    private def self.to_time(raw : String) : Time
      Time.parse_rfc3339(raw)
    rescue Time::Format::Error
      invalid(raw, "Time")
    end

    private def self.invalid(raw : String, type_name : String) : NoReturn
      raise Error.new(%(expected #{type_name}, got "#{raw}"))
    end

    private def self.invalid_type(type_name : String) : NoReturn
      raise Error.new("unsupported parameter type '#{type_name}'")
    end
  end
end
