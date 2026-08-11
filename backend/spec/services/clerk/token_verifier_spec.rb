require "rails_helper"

RSpec.describe Clerk::TokenVerifier do
  subject(:verify) { described_class.call(token) }

  before { stub_clerk_jwks }

  context "with a valid token" do
    let(:token) { clerk_token }

    it "returns the claims" do
      expect(verify["sub"]).to eq("user_2abcdef")
    end
  end

  # Each of these is a way an attacker gets in if verification is wrong. They are the
  # reason this is tested against real crypto rather than a stubbed verifier.
  describe "rejections" do
    def expect_rejection(message = nil)
      expect { verify }.to raise_error(described_class::InvalidToken, message)
    end

    context "when signed by a key Clerk never published" do
      let(:token) { clerk_token({}, key: ClerkTokenHelper.foreign_key) }

      it { expect_rejection }
    end

    context "when the token is unsigned (alg: none)" do
      let(:token) { JWT.encode({ "sub" => "user_2abcdef" }, nil, "none") }

      it { expect_rejection }
    end

    context "when it has expired" do
      # Beyond the 30s clock-skew leeway, which must not become a loophole.
      let(:token) { clerk_token({ "exp" => 5.minutes.ago.to_i }) }

      it { expect_rejection(/expired/) }
    end

    context "when issued by a different Clerk instance" do
      let(:token) { clerk_token({ "iss" => "https://someone-elses-app.clerk.accounts.dev" }) }

      it { expect_rejection }
    end

    context "when azp names an origin we do not serve" do
      let(:token) { clerk_token({ "azp" => "https://evil.example.com" }) }

      it { expect_rejection(/unauthorized party/) }
    end

    context "when the token is missing" do
      let(:token) { nil }

      it { expect_rejection(/missing bearer token/) }
    end
  end

  # Server-rendered calls mint tokens with no Origin, so Clerk may omit azp entirely.
  # Rejecting those would break every Server Component call; this documents that the
  # permissive path is deliberate rather than an oversight.
  context "when azp is absent, as on server-minted tokens" do
    let(:token) { clerk_token({ "azp" => nil }) }

    it "is accepted on the strength of signature, issuer, and expiry" do
      expect(verify["sub"]).to eq("user_2abcdef")
    end
  end

  describe "JWKS caching" do
    let(:token) { clerk_token }

    # An uncached JWKS adds an outbound HTTPS round trip to every authenticated
    # request, which alone would put the <3s p95 target at risk.
    it "fetches the key set only once across repeated verifications" do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)

      3.times { described_class.call(token) }

      expect(Net::HTTP).to have_received(:get_response).once
    end
  end
end
