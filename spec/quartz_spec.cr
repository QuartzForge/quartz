require "./spec_helper"

describe Quartz do
  it "exposes the shard version" do
    Quartz::VERSION.should eq("0.1.0")
  end
end
