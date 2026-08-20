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

  it "resolves namespaced services sharing a leaf name as distinct instances" do
    app_repo = Quartz.container.app_user_repo
    admin_repo = Quartz.container.admin_user_repo
    controller = Quartz.container.both_user_repos_controller

    app_repo.should be_a(App::UserRepo)
    admin_repo.should be_a(Admin::UserRepo)
    app_repo.should_not be(admin_repo)
    controller.app_repo.should be(app_repo)
    controller.admin_repo.should be(admin_repo)
  end
end
