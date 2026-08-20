require "./spec_helper"

describe Quartz do
  it "exposes the shard version" do
    Quartz::VERSION.should eq("1.0.0")
  end
end
