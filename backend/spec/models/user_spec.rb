require "rails_helper"

RSpec.describe User do
  describe ".from_clerk_claims!" do
    let(:claims) { { "sub" => "user_2abcdef" } }

    it "creates the user on first contact" do
      expect { described_class.from_clerk_claims!(claims) }.to change(described_class, :count).by(1)
    end

    it "returns the existing user on subsequent contact" do
      first = described_class.from_clerk_claims!(claims)

      expect(described_class.from_clerk_claims!(claims)).to eq(first)
      expect(described_class.count).to eq(1)
    end

    # The onboarding wizard fires several requests the moment it mounts, so two can
    # reach this simultaneously on a user's very first visit. Without the rescue the
    # loser of that race raises RecordNotUnique and a first-time user sees a 500 —
    # on the very first screen, which is the worst possible place to lose someone.
    it "survives a concurrent insert racing between the lookup and the create" do
      allow(described_class).to receive(:find_or_create_by!) do
        described_class.create!(clerk_id: claims["sub"])
        raise ActiveRecord::RecordNotUnique, "duplicate key value violates unique constraint"
      end

      expect(described_class.from_clerk_claims!(claims).clerk_id).to eq("user_2abcdef")
    end

    it "raises when the token carried no subject" do
      expect { described_class.from_clerk_claims!({}) }.to raise_error(KeyError)
    end
  end
end
