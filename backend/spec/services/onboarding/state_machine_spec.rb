require "rails_helper"

RSpec.describe Onboarding::StateMachine do
  describe ".next_after" do
    it "returns the following state" do
      expect(described_class.next_after("consent")).to eq("assessment")
    end

    it "returns nil at the end of the flow" do
      expect(described_class.next_after("done")).to be_nil
    end

    it "returns nil for a state that does not exist" do
      expect(described_class.next_after("nonsense")).to be_nil
    end
  end

  describe ".can_transition?" do
    it "allows a single step forward" do
      expect(described_class.can_transition?(from: "document", to: "confirm")).to be(true)
    end

    # Every step is a precondition for the next. Skipping to confirmation before a
    # document exists would render a form with nothing to confirm, which reads to the
    # user as a broken product rather than a fast one.
    it "rejects skipping a step" do
      expect(described_class.can_transition?(from: "consent", to: "document")).to be(false)
    end

    # Backwards is not a state change: reopening step 2 must not discard what steps 3
    # and 4 already established. Revisiting is a read.
    it "rejects moving backwards" do
      expect(described_class.can_transition?(from: "schedule", to: "document")).to be(false)
    end

    it "rejects staying put" do
      expect(described_class.can_transition?(from: "consent", to: "consent")).to be(false)
    end

    it "rejects unknown states on either side" do
      expect(described_class.can_transition?(from: "consent", to: "nope")).to be(false)
      expect(described_class.can_transition?(from: "nope", to: "assessment")).to be(false)
    end
  end

  describe ".validate_transition!" do
    it "names both states so the failure is diagnosable from a log line alone" do
      expect { described_class.validate_transition!(from: "consent", to: "schedule") }
        .to raise_error(described_class::InvalidTransition, /"consent".*"schedule"/)
    end
  end

  describe ".reached?" do
    it "is true for the current state and everything behind it" do
      expect(described_class.reached?("confirm", "document")).to be(true)
      expect(described_class.reached?("confirm", "confirm")).to be(true)
    end

    it "is false for states not yet arrived at" do
      expect(described_class.reached?("document", "schedule")).to be(false)
    end
  end

  # The frontend's step ids drive routing and the progress rail. If these drift apart,
  # the UI and the API disagree about what step the user is on and the bug surfaces as
  # a wrong-looking wizard rather than an error.
  it "matches the step ids the frontend routes on" do
    expect(described_class::STATES)
      .to eq(%w[consent assessment document confirm schedule done])
  end
end
