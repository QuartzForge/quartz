require "../spec_helper"

describe Quartz::Bound do
  it "fetches a value cast to the requested type" do
    bound = Quartz::Bound.new({"id" => 42} of String => Quartz::Bound::Value)

    bound.fetch("id", Int32).should eq(42)
  end

  it "returns nil when fetching an absent key" do
    bound = Quartz::Bound.new

    bound.fetch?("missing", String).should be_nil
  end

  it "returns the value when fetching a present key" do
    bound = Quartz::Bound.new({"name" => "ada"} of String => Quartz::Bound::Value)

    bound.fetch?("name", String).should eq("ada")
  end
end
