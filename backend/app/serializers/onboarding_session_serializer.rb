# Shapes an OnboardingSession for the API.
#
# Fields are listed explicitly rather than serialising the model. As this record grows
# to hold extracted identity fields and the intake summary, a column added later is
# omitted by default instead of being published by accident — the difference between
# a new field and a PII leak is exactly this list.
class OnboardingSessionSerializer
  def initialize(session)
    @session = session
  end

  # @return [Hash] the session as a plain hash, ready to render as JSON
  def as_json
    {
      id: @session.id,
      state: @session.state,
      next_state: @session.next_state,
      complete: @session.complete?,
      # The client renders the progress rail from this, so it does not have to keep
      # its own copy of the flow order and drift from the server's.
      states: Onboarding::StateMachine::STATES,
      updated_at: @session.updated_at.iso8601
    }
  end
end
