require "rails_helper"

RSpec.describe OnboardingSessionPolicy do
  let(:owner) { create(:user) }
  let(:stranger) { create(:user) }
  let(:session) { create(:onboarding_session, user: owner) }

  # This record accumulates identity fields read off a government ID and a clinical
  # intake summary. These four examples are the whole of what stops one patient
  # reading another's.
  it "lets the owner read and change their own session" do
    policy = described_class.new(owner, session)

    expect(policy.show?).to be(true)
    expect(policy.update?).to be(true)
  end

  it "denies another signed-in user" do
    policy = described_class.new(stranger, session)

    expect(policy.show?).to be(false)
    expect(policy.update?).to be(false)
  end

  it "denies an unauthenticated caller" do
    policy = described_class.new(nil, session)

    expect(policy.show?).to be(false)
  end

  # Inherited from ApplicationPolicy: anything not explicitly granted is denied, so a
  # policy that forgets an action fails closed.
  it "denies actions the policy never granted" do
    expect(described_class.new(owner, session).destroy?).to be(false)
  end
end
