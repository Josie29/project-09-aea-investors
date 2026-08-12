require "rails_helper"

RSpec.describe Chat::Respond do
  subject(:respond) { described_class.new(session, client: client) }

  let(:session) { OnboardingSession.for(create(:user)) }
  let(:client) { instance_double(Llm::Client) }

  def answer(reply:, intent: "provide_details", extracted: {})
    JSON.generate("reply" => reply, "intent" => intent, "extracted" => extracted)
  end

  describe "a normal turn" do
    before do
      allow(client).to receive(:complete).and_return(
        answer(reply: "That sounds exhausting. Have you seen anyone about this before?",
               extracted: { "presenting_concern" => "Panic attacks", "frequency" => "2-3 per week" })
      )
    end

    it "records both turns of the conversation" do
      result = respond.call("I've been having panic attacks at work")

      expect(result.user_message.content).to eq("I've been having panic attacks at work")
      expect(result.assistant_message.role).to eq("assistant")
    end

    # The summary sidebar is built from these, and it is the thing the user checks
    # before a clinician ever sees it.
    it "fills the summary from what the user said" do
      result = respond.call("I've been having panic attacks at work, two or three a week")

      expect(result.assessment.presenting_concern).to eq("Panic attacks")
      expect(result.assessment.frequency).to eq("2-3 per week")
    end

    it "classifies the user's intent" do
      result = respond.call("I've been having panic attacks")

      expect(result.user_message.intent).to eq("provide_details")
    end
  end

  # The model re-reads the whole conversation each turn and may return nothing for a
  # field it filled earlier. A blank must never overwrite a real answer, or the
  # sidebar visibly forgets things the user already told it.
  it "never lets a later blank erase something already known" do
    allow(client).to receive(:complete).and_return(
      answer(reply: "Noted.", extracted: { "presenting_concern" => "Panic attacks" }),
      answer(reply: "And how often?", extracted: {})
    )

    respond.call("panic attacks")
    result = respond.call("hello again")

    expect(result.assessment.presenting_concern).to eq("Panic attacks")
  end

  # A constrained column plus a model that invents a label would fail the write and
  # lose the user's turn entirely.
  it "coerces an intent it does not recognise rather than failing the write" do
    allow(client).to receive(:complete).and_return(answer(reply: "Hm.", intent: "vibes"))

    result = respond.call("something unusual")

    expect(result.user_message.intent).to eq("out_of_scope")
  end

  # The brief: when the provider times out or is unreachable, the chatbot degrades
  # gracefully with a clear try-again-or-continue path -- never a hang, an unhandled
  # error, or a hallucinated commitment.
  describe "when the provider is unavailable" do
    it "answers with a fallback rather than raising on a timeout" do
      allow(client).to receive(:complete).and_raise(Llm::Client::Timeout)

      result = respond.call("are you there?")

      expect(result).to be_degraded
      expect(result.assistant_message.content).to include("try again")
    end

    it "answers with a fallback when the provider errors" do
      allow(client).to receive(:complete).and_raise(Llm::Client::Unavailable)

      expect(respond.call("hello")).to be_degraded
    end

    it "handles unparseable output without losing the user's message" do
      allow(client).to receive(:complete).and_return("not json at all")

      result = respond.call("hello")

      expect(result).to be_degraded
      expect(session.chat_messages.where(role: "user").count).to eq(1)
    end

    # Nothing the user has already told us may be lost because one turn failed --
    # that is what makes a degraded turn recoverable rather than a restart.
    it "keeps the summary intact through a failed turn" do
      allow(client).to receive(:complete).and_return(
        answer(reply: "Noted.", extracted: { "presenting_concern" => "Panic attacks" })
      )
      respond.call("panic attacks")

      allow(client).to receive(:complete).and_raise(Llm::Client::Timeout)
      result = respond.call("still there?")

      expect(result.assessment.presenting_concern).to eq("Panic attacks")
    end

    # The request carried the user's own account of their mental health.
    it "logs the failure without the user's words" do
      allow(client).to receive(:complete).and_raise(Llm::Client::Timeout)
      allow(Rails.logger).to receive(:warn)

      respond.call("I have been feeling hopeless since March")

      expect(Rails.logger).not_to have_received(:warn).with(/hopeless/)
    end
  end
end
