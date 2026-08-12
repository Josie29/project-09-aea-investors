require "rails_helper"

RSpec.describe ExtractedField do
  let(:document) { Document.create!(onboarding_session: OnboardingSession.for(create(:user))) }

  def field(value:, confidence:)
    described_class.create!(document: document, name: "name", value: value, confidence: confidence)
  end

  # These three states are what the confirm screen renders, and getting them wrong is
  # how a machine guess ends up presented to a user as fact.
  describe "#state" do
    it "is read when confidence is high" do
      expect(field(value: "Marisol A. Reyes", confidence: 0.95).state).to eq(:read)
    end

    it "is check_this below the attention threshold" do
      expect(field(value: "142O W Fultcn St", confidence: 0.61).state).to eq(:check_this)
    end

    it "is not_found when nothing was read" do
      expect(field(value: nil, confidence: 0.0).state).to eq(:not_found)
    end
  end

  describe "#display_value" do
    # The rule that matters most: below the pre-fill threshold the user gets an empty
    # box, not a guess. A wrong value in a filled field invites approval by reflex;
    # an empty one asks a question.
    it "shows nothing when confidence is below the pre-fill threshold" do
      expect(field(value: "D4?1-88O2", confidence: 0.22).display_value).to be_nil
    end

    it "shows the read value when confidence clears the threshold" do
      expect(field(value: "1991-03-14", confidence: 0.94).display_value).to eq("1991-03-14")
    end

    # A user's correction outranks the machine, including on a re-read.
    it "prefers what the user confirmed over what OCR read" do
      record = field(value: "142O W Fultcn St", confidence: 0.61)
      record.update!(confirmed_value: "1420 W Fulton St", confirmed_at: Time.current)

      expect(record.display_value).to eq("1420 W Fulton St")
    end
  end

  # Feeds the OCR correction-rate metric the brief asks for, without storing anything
  # extra: the original read and the confirmed value are both already here.
  describe "#corrected?" do
    it "is true when the user changed the value" do
      record = field(value: "142O W Fultcn St", confidence: 0.61)
      record.update!(confirmed_value: "1420 W Fulton St", confirmed_at: Time.current)

      expect(record).to be_corrected
    end

    it "is false when the user accepted what was read" do
      record = field(value: "1420 W Fulton St", confidence: 0.93)
      record.update!(confirmed_value: "1420 W Fulton St", confirmed_at: Time.current)

      expect(record).not_to be_corrected
    end

    it "is false before the user has confirmed anything" do
      expect(field(value: "1420 W Fulton St", confidence: 0.93)).not_to be_corrected
    end
  end

  it "allows only one row per field per document" do
    field(value: "First", confidence: 0.9)

    expect { described_class.create!(document: document, name: "name", value: "Second", confidence: 0.9) }
      .to raise_error(ActiveRecord::RecordInvalid)
  end
end
