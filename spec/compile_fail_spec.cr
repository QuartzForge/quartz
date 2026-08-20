require "./spec_helper"

# The core promise of Quartz — wrong wiring fails the build, not the
# first request — cannot be asserted from inside a normal spec, because
# the spec itself would not compile. So each fixture is compiled in a
# subprocess and the failure is asserted on its output.
private def compile(fixture : String) : {status: Process::Status, output: String}
  stdout = IO::Memory.new
  status = Process.run(
    "crystal",
    ["run", "--error-on-warnings", "spec/fixtures/compile_fail/#{fixture}"],
    output: stdout,
    error: stdout,
  )
  {status: status, output: stdout.to_s}
end

describe "compile-time failures" do
  it "refuses a dependency that was never registered as a service" do
    result = compile("missing_service.cr")

    result[:status].success?.should be_false
    result[:output].should contain("unregistered_repo")
  end

  it "refuses a dependency cycle, naming the participants" do
    result = compile("dependency_cycle.cr")

    result[:status].success?.should be_false
    result[:output].should contain("dependency cycle")
    result[:output].should contain("CycleA")
    result[:output].should contain("CycleB")
  end

  it "refuses two services whose getter names collide, naming both types" do
    result = compile("getter_name_collision.cr")

    result[:status].success?.should be_false
    result[:output].should contain("App::UserRepo")
    result[:output].should contain("AppUserRepo")
    result[:output].should contain("app_user_repo")
  end

  it "refuses two routes with the same verb and path" do
    result = compile("duplicate_route.cr")

    result[:status].success?.should be_false
    result[:output].should contain("route conflict")
  end

  it "refuses annotated overloads that would emit the same operation id" do
    result = compile("duplicate_operation_id.cr")

    result[:status].success?.should be_false
    result[:output].should contain("duplicate operation id")
    result[:output].should contain("DuplicateOperationIdController.show")
  end

  it "refuses a root module that is not annotated" do
    result = compile("bad_root_module.cr")

    result[:status].success?.should be_false
    result[:output].should contain("Quartz.run expects a module annotated with @[Quartz::Module]")
  end

  it "refuses a program without a root module" do
    result = compile("no_root_module.cr")

    result[:status].success?.should be_false
    result[:output].should contain("Quartz.run(AppModule) is required")
  end

  it "refuses an import that is not a module" do
    result = compile("bad_import.cr")

    result[:status].success?.should be_false
    result[:output].should contain("imports must be modules")
    result[:output].should contain("NotAModule")
  end

  it "refuses an import cycle among modules, naming the participants" do
    result = compile("import_cycle.cr")

    result[:status].success?.should be_false
    result[:output].should contain("import cycle")
    result[:output].should contain("CycleModuleA")
    result[:output].should contain("CycleModuleB")
  end

  it "refuses a module outside the reachable graph" do
    result = compile("unreachable_module.cr")

    result[:status].success?.should be_false
    result[:output].should contain("not reachable")
    result[:output].should contain("OrphanModule")
  end

  it "refuses a controller that is not listed in any module" do
    result = compile("orphan_controller.cr")

    result[:status].success?.should be_false
    result[:output].should contain("not listed in any module")
    result[:output].should contain("OrphanController")
  end

  it "refuses a non-controller listed in controllers" do
    result = compile("bad_controller_entry.cr")

    result[:status].success?.should be_false
    result[:output].should contain("not a controller")
    result[:output].should contain("SomeService")
  end

  it "refuses a non-service listed in providers" do
    result = compile("bad_provider_entry.cr")

    result[:status].success?.should be_false
    result[:output].should contain("not a service")
    result[:output].should contain("SomeController")
  end
end
