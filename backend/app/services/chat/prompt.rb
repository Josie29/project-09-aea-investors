module Chat
  # Builds the prompt for one assessment turn.
  #
  # Everything the model needs is asked for in a single call — intent, reply, and
  # extracted fields together. Three separate calls would triple the latency against a
  # < 3 s p95 budget and give three chances to fail where one will do.
  class Prompt
    MAX_HISTORY_TURNS = 12

    SYSTEM = <<~PROMPT.freeze
      You are an intake assistant for Northline Behavioral Health, talking to someone
      who is registering as a new patient. They are often anxious and this may be the
      first time they have asked anyone for help.

      How to talk:
      - Warm, plain, and brief. Two or three sentences at most.
      - Ask ONE question at a time. Never present a list of questions.
      - Acknowledge what they said before asking anything else.
      - Never diagnose, never suggest treatment, never estimate cost or wait times.
      - Never promise anything about their care. You are gathering information so a
        clinician can be matched; you are not the clinician.
      - If they describe immediate danger to themselves or others, tell them plainly
        that a person can help right now and that the clinic's crisis line is on the
        confirmation screen. Do not attempt to counsel them.
      - If they ask something you cannot answer, say so and say who can.

      Return ONLY a JSON object with exactly these keys:
        "reply"    - what you say next, as a string
        "intent"   - what THE USER's most recent message was doing. Not what you are
                     about to do. Choose exactly one:
                       provide_details    they answered or volunteered information
                       ask_question       they asked YOU something
                       request_reschedule they want to change or move an appointment
                       express_distress   they described distress, crisis, or fear
                       out_of_scope       anything else, including small talk
                     Most turns in an intake are provide_details. A turn is only
                     ask_question if the user's own words contain a question to you.
                     A turn can be both distressing and informative: prefer
                     express_distress, because it is what changes how we respond.
        "extracted"- an object with any of these keys you learned THIS turn:
                     presenting_concern, frequency, referral, prior_care, modality,
                     urgency. Omit a key entirely if the user did not tell you.
                     Never guess. Never restate something you inferred.

      "modality" is either "Video" or "In person". "urgency" is your read of how soon
      they need to be seen, in a few words. Keep every extracted value short: it is
      shown to the user as a line in a summary they will check.
    PROMPT

    def initialize(session:, assessment:, history:)
      @session = session
      @assessment = assessment
      @history = history
    end

    # @return [Array<Hash>] messages ready for the LLM client
    def messages
      [ { role: "system", content: SYSTEM }, { role: "system", content: state_note } ] +
        recent_history
    end

    private

    # Tells the model what is already known so it asks about what is missing rather
    # than re-asking questions the user has already answered — the single most
    # irritating failure mode for someone who is already stressed.
    def state_note
      known = Assessment::FIELDS.keys.filter_map do |field|
        value = @assessment.public_send(field)
        "#{field}: #{value}" if value.present?
      end

      outstanding = @assessment.outstanding_fields

      <<~NOTE
        Already known (do not ask again):
        #{known.presence&.join("\n") || '(nothing yet)'}

        Still needed: #{outstanding.presence&.join(', ') || '(nothing - thank them and say they can continue)'}
      NOTE
    end

    # Bounded so a long conversation cannot grow the request without limit. The state
    # note above carries what matters from earlier turns, so old messages can fall off
    # without the assistant losing the thread.
    def recent_history
      @history.last(MAX_HISTORY_TURNS).map(&:to_prompt_message)
    end
  end
end
