class OnboardingSession < ApplicationRecord
  belongs_to :user

  validates :state, presence: true, inclusion: { in: Onboarding::StateMachine::STATES }
  validates :user_id, uniqueness: true

  # Returns the user's session, creating it on first contact.
  #
  # Onboarding is something a user is always in the middle of or has finished, so
  # there is no meaningful "no session yet" state to represent in the API. The unique
  # index means concurrent first requests race; the loser rescues and re-reads, the
  # same pattern as User.from_clerk_claims!.
  #
  # @param user [User]
  # @return [OnboardingSession]
  def self.for(user)
    find_or_create_by!(user: user)
  rescue ActiveRecord::RecordNotUnique
    find_by!(user: user)
  end

  # Moves the session forward exactly one step.
  #
  # @param to [String] the expected next state, supplied by the caller so a
  #   double-submitted request cannot silently skip a step it did not intend
  # @return [self]
  # @raise [Onboarding::StateMachine::InvalidTransition]
  def advance_to!(to)
    Onboarding::StateMachine.validate_transition!(from: state, to: to)
    update!(state: to)
    self
  end

  # @return [String, nil] the next state, or nil when onboarding is finished
  def next_state
    Onboarding::StateMachine.next_after(state)
  end

  def complete?
    state == Onboarding::StateMachine::TERMINAL
  end

  # @return [Boolean] whether the user has got at least as far as `other`
  def reached?(other)
    Onboarding::StateMachine.reached?(state, other)
  end
end
