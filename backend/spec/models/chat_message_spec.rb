require "rails_helper"

RSpec.describe ChatMessage do
  let(:session) { OnboardingSession.for(create(:user)) }

  it "covers exactly the intent list the brief defines, plus the graceful fallback" do
    expect(described_class::INTENTS)
      .to match_array(%w[provide_details ask_question request_reschedule express_distress out_of_scope])
  end

  it "rejects an intent outside that list" do
    message = described_class.new(onboarding_session: session, role: "user", content: "hi", intent: "vibes")

    expect(message).not_to be_valid
  end

  # Assistant turns carry no intent: the label describes what the USER's message was
  # doing, and attaching one to our own replies would corrupt the intent-coverage
  # measurement.
  it "allows a message with no intent" do
    message = described_class.new(onboarding_session: session, role: "assistant", content: "Hello")

    expect(message).to be_valid
  end

  it "orders a conversation by when it was said" do
    first = session.chat_messages.create!(role: "user", content: "one")
    second = session.chat_messages.create!(role: "assistant", content: "two")

    expect(session.chat_messages.chronological.to_a).to eq([ first, second ])
  end
end
