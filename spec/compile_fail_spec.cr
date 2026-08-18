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
end
