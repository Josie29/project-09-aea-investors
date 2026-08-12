# Test-only job. Lives in spec/support rather than app/jobs so it never ships in the
# eager-loaded application, but is a real named class so Active Job can serialise it.
class SmokeTestJob < ApplicationJob
  def perform; end
end
