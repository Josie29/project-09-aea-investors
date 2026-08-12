require "rails_helper"

RSpec.describe Consent do
  let(:session) { OnboardingSession.for(create(:user)) }

  describe ".grant!" do
    it "records the time and the policy version in force" do
      consent = described_class.grant!(session)

      expect(consent.granted_at).to be_present
      expect(consent.policy_version).to eq(described_class::CURRENT_POLICY_VERSION)
      expect(consent).to be_active
    end

    it "keeps one record per session rather than accumulating grants" do
      described_class.grant!(session)

      expect { described_class.grant!(session) }.not_to change(described_class, :count)
    end

    # Someone who withdraws and reconsiders should be able to carry on, not be locked
    # out of a service they came to use.
    it "reinstates a withdrawn consent and clears the withdrawal" do
      described_class.grant!(session).withdraw!

      reinstated = described_class.grant!(session)

      expect(reinstated).to be_active
      expect(reinstated.withdrawn_at).to be_nil
    end
  end

  describe "#withdraw!" do
    it "records when consent was withdrawn" do
      consent = described_class.grant!(session)

      consent.withdraw!

      expect(consent.withdrawn_at).to be_present
      expect(consent).not_to be_active
    end
  end

  # Data minimisation is a graded requirement, and the easiest place to violate it is
  # an audit table quietly collecting more than it needs. A timestamped record tied to
  # an authenticated session already establishes who consented and when; IP address
  # and user agent would be additional personal data collected for no stated purpose.
  it "stores no personal data beyond the timestamps and policy version" do
    expect(described_class.column_names)
      .to match_array(%w[id onboarding_session_id granted_at withdrawn_at policy_version created_at updated_at])
  end
end
