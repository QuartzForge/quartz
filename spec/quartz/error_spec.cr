require "../spec_helper"

# Every error the framework emits carries an RFC 9457 problem type URI —
# the stable identifier clients branch on. Pinning them here makes any
# change to one of them a failing test, because they are a wire-format
# contract, not a label.
describe Quartz::HTTPError do
  it "pins the problem type URI and status of every HTTP error" do
    {
      Quartz::BadRequest.new          => {400, "https://quartzforge.org/errors/bad-request"},
      Quartz::Unauthorized.new        => {401, "https://quartzforge.org/errors/unauthorized"},
      Quartz::Forbidden.new           => {403, "https://quartzforge.org/errors/forbidden"},
      Quartz::NotFound.new            => {404, "https://quartzforge.org/errors/not-found"},
      Quartz::Conflict.new            => {409, "https://quartzforge.org/errors/conflict"},
      Quartz::UnprocessableEntity.new => {422, "https://quartzforge.org/errors/unprocessable-entity"},
    }.each do |error, (status, type)|
      error.status.should eq(status)
      error.problem_type.should eq(type)
    end
  end
end
