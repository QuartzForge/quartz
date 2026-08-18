require "./spec_helper"

describe Quartz do
  it "expõe a versão da shard" do
    Quartz::VERSION.should eq("0.1.0")
  end
end
