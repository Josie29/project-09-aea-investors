module Chat
  # Handles one turn of the assessment conversation.
  #
  # Records what the user said, asks the model for a reply plus any fields it learned,
  # updates the summary, and records the answer. Degrades rather than failing: the
  # brief requires the chatbot to offer a clear "try again or continue manually" path
  # when the provider is unreachable, and never to hang or hallucinate a commitment.
  class Respond
    # Said when the provider is unavailable. Deliberately makes no promise and offers
    # the path that still works, because the alternative is a spinner and a dead end.
    FALLBACK_REPLY = <<~TEXT.strip
      Sorry — I'm having trouble responding just now. You can try again in a moment,
      or skip ahead and answer a few short questions instead. Nothing you've told me
      is lost.
    TEXT

    Result = Struct.new(:user_message, :assistant_message, :assessment, :degraded, keyword_init: true) do
      def degraded? = degraded
    end

    def initialize(session, client: Llm::Client.new)
      @session = session
      @client = client
    end

    # @param content [String] what the user typed
    # @return [Result]
    def call(content)
      assessment = Assessment.for(@session)
      user_message = record(role: "user", content: content)

      answer = generate(assessment)

      if answer.nil?
        assistant = record(role: "assistant", content: FALLBACK_REPLY)
        return Result.new(user_message: user_message, assistant_message: assistant,
                          assessment: assessment, degraded: true)
      end

      user_message.update!(intent: answer[:intent])
      assessment.merge_extracted!(answer[:extracted])
      assistant = record(role: "assistant", content: answer[:reply])

      Result.new(user_message: user_message, assistant_message: assistant,
                 assessment: assessment.reload, degraded: false)
    end

    private

    # @return [Hash, nil] parsed answer, or nil when the provider could not be used
    def generate(assessment)
      history = @session.chat_messages.chronological.to_a
      raw = @client.complete(
        messages: Prompt.new(session: @session, assessment: assessment, history: history).messages,
        json: true
      )

      parse(raw)
    rescue Llm::Client::Timeout, Llm::Client::Unavailable => e
      # Class and reason only. The request carried the user's own account of their
      # mental health, and an error log that echoes it is the worst possible leak.
      Rails.logger.warn("llm turn failed for session #{@session.id}: #{e.class} #{e.message}")
      nil
    end

    def parse(raw)
      payload = JSON.parse(raw)
      reply = payload["reply"].presence
      return nil if reply.nil?

      {
        reply: reply,
        # An unrecognised intent is coerced to out_of_scope rather than stored raw:
        # the column is constrained, and a model that invents a label should not be
        # able to fail the write and lose the user's turn.
        intent: ChatMessage::INTENTS.include?(payload["intent"]) ? payload["intent"] : "out_of_scope",
        extracted: payload["extracted"].is_a?(Hash) ? payload["extracted"] : {}
      }
    rescue JSON::ParserError
      Rails.logger.warn("llm returned unparseable json for session #{@session.id}")
      nil
    end

    def record(role:, content:)
      @session.chat_messages.create!(role: role, content: content)
    end
  end
end
