require "./spec_helper"

# The collector behaviors that cannot be asserted in the spec program
# itself are asserted by probe programs compiled in a subprocess; each
# probe raises on any mismatch, so a clean exit is the expected outcome.
private def run_probe(fixture : String) : {status: Process::Status, output: String}
  stdout = IO::Memory.new
  status = Process.run(
    "crystal",
    ["run", "spec/fixtures/compile_ok/#{fixture}"],
    output: stdout,
    error: stdout,
  )
  {status: status, output: stdout.to_s}
end

describe "route collector probes" do
  it "serves routes from no-prefix and no-leading-slash controllers, with nilable and header params" do
    result = run_probe("route_probes.cr")

    result[:status].success?.should be_true
    result[:output].should be_empty
  end
end
