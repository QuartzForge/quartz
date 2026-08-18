require "../spec_helper"

describe Quartz::Container do
  it "resolves an annotated service" do
    Quartz.container.example_repo.should be_a(ExampleRepo)
  end

  it "resolves a controller, injecting its dependencies" do
    Quartz.container.example_controller.should be_a(ExampleController)
  end

  it "returns the same instance on every access (singleton scope)" do
    Quartz.container.example_repo.should be(Quartz.container.example_repo)
  end
end
