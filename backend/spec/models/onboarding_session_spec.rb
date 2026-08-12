require "rails_helper"

RSpec.describe OnboardingSession do
  let(:user) { User.create!(clerk_id: "user_#{SecureRandom.hex(4)}") }

  describe ".for" do
    it "starts a new session at the first step" do
      expect(described_class.for(user).state).to eq("consent")
    end

    # Onboarding must survive closing the tab. If this breaks, a user who steps away
    # mid-flow restarts from step one, which is exactly the abandonment the product
    # exists to prevent.
    it "returns the same session on a later visit, at the step they left off" do
      started = described_class.for(user)
      Consent.grant!(started)
      started.advance_to!("assessment")

      resumed = described_class.for(user.reload)

      expect(resumed.state).to eq("assessment")
      expect(described_class.count).to eq(1)
    end

    # Concurrent first requests race on the unique index; the loser must recover
    # rather than showing a first-time user a 500 on the very first screen.
    it "survives a concurrent insert between the lookup and the create" do
      allow(described_class).to receive(:find_or_create_by!) do
        described_class.create!(user: user)
        raise ActiveRecord::RecordNotUnique, "duplicate key value violates unique constraint"
      end

      expect(described_class.for(user).user_id).to eq(user.id)
    end
  end

  describe "#advance_to!" do
    subject(:session) { described_class.for(user) }

    # Consent gates the very first transition, so every test about ordering needs it
    # on file first. That the gate exists is covered in the consent specs.
    before { Consent.grant!(session) }

    it "moves forward one step and persists it" do
      session.advance_to!("assessment")

      expect(session.reload.state).to eq("assessment")
    end

    it "refuses to skip a step" do
      expect { session.advance_to!("confirm") }
        .to raise_error(Onboarding::StateMachine::InvalidTransition)
    end

    it "refuses to move backwards" do
      session.advance_to!("assessment")

      expect { session.advance_to!("consent") }
        .to raise_error(Onboarding::StateMachine::InvalidTransition)
    end

    # A double-submitted request must not silently advance twice. The caller states
    # the state it expects, so a repeat of the same request fails loudly instead.
    it "rejects a replayed request that already applied" do
      session.advance_to!("assessment")

      expect { session.advance_to!("assessment") }
        .to raise_error(Onboarding::StateMachine::InvalidTransition)
    end

    it "leaves the stored state untouched when a transition is rejected" do
      expect { session.advance_to!("done") }.to raise_error(Onboarding::StateMachine::InvalidTransition)
      expect(session.reload.state).to eq("consent")
    end
  end

  describe "progress helpers" do
    subject(:session) { described_class.for(user) }

    before { Consent.grant!(session) }

    it "reports the next state while the flow is unfinished" do
      expect(session.next_state).to eq("assessment")
      expect(session).not_to be_complete
    end

    it "reports completion once every step has been walked" do
      Onboarding::StateMachine::STATES.drop(1).each { |state| session.advance_to!(state) }

      expect(session).to be_complete
      expect(session.next_state).to be_nil
    end
  end

  describe "validations" do
    it "rejects a state outside the flow" do
      session = described_class.new(user: user, state: "elsewhere")

      expect(session).not_to be_valid
    end

    # Two sessions for one user would make "the current user's session" ambiguous and
    # let two browser tabs advance independent copies of the same onboarding.
    it "allows only one session per user" do
      described_class.create!(user: user)

      expect { described_class.create!(user: user) }
        .to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
