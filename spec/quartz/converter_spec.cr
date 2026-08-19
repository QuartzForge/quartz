require "../spec_helper"

describe Quartz::Converter do
  it "converts the supported scalar types" do
    Quartz::Converter.convert("abc", "String").should eq("abc")
    Quartz::Converter.convert("42", "Int32").should eq(42)
    Quartz::Converter.convert("9999999999", "Int64").should eq(9_999_999_999_i64)
    Quartz::Converter.convert("1.5", "Float64").should eq(1.5)
    Quartz::Converter.convert("true", "Bool").should be_true
    Quartz::Converter.convert("false", "Bool").should be_false
  end

  it "accepts the numeric boundaries" do
    Quartz::Converter.convert("2147483647", "Int32").should eq(Int32::MAX)
    Quartz::Converter.convert("9223372036854775807", "Int64").should eq(Int64::MAX)
    Quartz::Converter.convert("1e308", "Float64").should eq(1e308)
  end

  it "rejects values past the numeric boundaries" do
    expect_raises(Quartz::Converter::Error, /expected Int32/) do
      Quartz::Converter.convert("2147483648", "Int32")
    end
    expect_raises(Quartz::Converter::Error, /expected Int64/) do
      Quartz::Converter.convert("9223372036854775808", "Int64")
    end
    expect_raises(Quartz::Converter::Error, /expected Float64/) do
      Quartz::Converter.convert("1e400", "Float64")
    end
  end

  it "accepts the boolean literals" do
    Quartz::Converter.convert("1", "Bool").should be_true
    Quartz::Converter.convert("0", "Bool").should be_false
    Quartz::Converter.convert("TRUE", "Bool").should be_true
  end

  it "converts UUID and RFC 3339 Time" do
    Quartz::Converter.convert("2f8a1f6e-0f3e-4c1a-9c1e-2b6a5d4e3f21", "UUID")
      .should be_a(UUID)
    Quartz::Converter.convert("2026-08-18T10:00:00Z", "Time")
      .should eq(Time.utc(2026, 8, 18, 10, 0, 0))
  end

  it "rejects an unconvertible value with a message citing type and input" do
    expect_raises(Quartz::Converter::Error, %(expected Int64, got "abc")) do
      Quartz::Converter.convert("abc", "Int64")
    end
  end

  it "rejects malformed UUID and Time" do
    expect_raises(Quartz::Converter::Error, %(expected UUID, got "not-a-uuid")) do
      Quartz::Converter.convert("not-a-uuid", "UUID")
    end
    expect_raises(Quartz::Converter::Error, /expected Time/) do
      Quartz::Converter.convert("2026-08-18", "Time")
    end
  end

  it "rejects a value that parses for one type but not another" do
    Quartz::Converter.convert("42", "Int32").should eq(42)
    expect_raises(Quartz::Converter::Error, %(expected Bool, got "42")) do
      Quartz::Converter.convert("42", "Bool")
    end
  end

  it "rejects an unsupported type" do
    expect_raises(Quartz::Converter::Error, /unsupported parameter type 'Regex'/) do
      Quartz::Converter.convert("x", "Regex")
    end
  end
end
