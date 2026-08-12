module Onboarding
  # The onboarding flow's ordering rules, kept out of the model so they can be
  # reasoned about and tested on their own.
  #
  # State names match the frontend's step ids in `lib/onboarding/steps.ts` exactly.
  # One vocabulary across the stack means a state in a log line, a URL, and a database
  # row all read the same, and there is no translation layer to drift.
  class StateMachine
    class InvalidTransition < StandardError; end

    # Ordered. Position in this array IS the flow order — there is no separate
    # ordering constant that could disagree with it.
    STATES = %w[consent assessment document confirm schedule done].freeze

    INITIAL = STATES.first
    TERMINAL = STATES.last

    class << self
      # @param state [String]
      # @return [String, nil] the state that follows, or nil at the end of the flow
      def next_after(state)
        index = STATES.index(state)
        return nil if index.nil? || index >= STATES.length - 1

        STATES[index + 1]
      end

      # Forward by exactly one step is the only legal move.
      #
      # Skipping ahead is rejected because every step is a precondition for the next:
      # confirming extracted fields before uploading anything would present a form with
      # nothing in it. Moving backwards is rejected because revisiting a completed step
      # is a read, not a state change — the user can reopen step 2 without the session
      # regressing and discarding what steps 3 and 4 already established.
      #
      # @return [Boolean]
      def can_transition?(from:, to:)
        return false unless STATES.include?(from) && STATES.include?(to)

        next_after(from) == to
      end

      # @raise [InvalidTransition] with a message naming both states, since "invalid
      #   transition" alone is useless in a log
      def validate_transition!(from:, to:)
        return if can_transition?(from: from, to: to)

        raise InvalidTransition, "cannot move from #{from.inspect} to #{to.inspect}"
      end

      # @return [Boolean] whether `state` comes at or before `other` in the flow
      def reached?(state, other)
        return false unless STATES.include?(state) && STATES.include?(other)

        STATES.index(state) >= STATES.index(other)
      end
    end
  end
end
