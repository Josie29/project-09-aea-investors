require "rails_helper"

RSpec.describe "Consent" do
  before { stub_clerk_jwks }

  def headers_for(clerk_id = "user_alice")
    auth_headers(clerk_token({ "sub" => clerk_id }))
  end

  describe "GET /api/v1/consent" do
    it "reports no consent before it is given" do
      get "/api/v1/consent", headers: headers_for

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["granted"]).to be(false)
    end
  end

  describe "POST /api/v1/consent" do
    it "records consent with a timestamp and the policy version" do
      post "/api/v1/consent", headers: headers_for

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["granted"]).to be(true)
      expect(response.parsed_body["granted_at"]).to be_present
    end

    # Without this, a stored consent tells you someone agreed but not to what — which
    # makes the record useless the first time the privacy notice changes.
    it "records which version of the notice was agreed to" do
      post "/api/v1/consent", headers: headers_for

      expect(response.parsed_body["policy_version"]).to eq(Consent::CURRENT_POLICY_VERSION)
    end

    it "keeps one consent record per user rather than accumulating them" do
      post "/api/v1/consent", headers: headers_for

      expect { post "/api/v1/consent", headers: headers_for }.not_to change(Consent, :count)
    end
  end

  describe "DELETE /api/v1/consent" do
    it "records the withdrawal with a timestamp" do
      post "/api/v1/consent", headers: headers_for

      delete "/api/v1/consent", headers: headers_for

      expect(response.parsed_body["granted"]).to be(false)
      expect(response.parsed_body["withdrawn_at"]).to be_present
    end

    # Returning an error for "you never consented" would be pedantic at the exact
    # moment someone is trying to stop processing.
    it "succeeds even when there was no consent on file" do
      delete "/api/v1/consent", headers: headers_for

      expect(response).to have_http_status(:ok)
    end

    # Someone who withdraws and changes their mind should be able to continue, not be
    # locked out of a service they came to use.
    it "allows consent to be given again after withdrawal" do
      post "/api/v1/consent", headers: headers_for
      delete "/api/v1/consent", headers: headers_for

      post "/api/v1/consent", headers: headers_for

      expect(response.parsed_body["granted"]).to be(true)
      expect(response.parsed_body["withdrawn_at"]).to be_nil
    end
  end

  # The brief requires consent BEFORE any document is uploaded or processed. These are
  # the tests that make that structural rather than a checkbox the frontend is trusted
  # to have rendered.
  describe "the consent gate on the flow" do
    it "refuses to advance past the consent step without consent" do
      patch "/api/v1/onboarding_session", params: { state: "assessment" }, headers: headers_for

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body["error"]).to eq("consent_required")
    end

    it "allows the flow to continue once consent is given" do
      post "/api/v1/consent", headers: headers_for

      patch "/api/v1/onboarding_session", params: { state: "assessment" }, headers: headers_for

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["state"]).to eq("assessment")
    end

    it "requires authentication" do
      post "/api/v1/consent"

      expect(response).to have_http_status(:unauthorized)
    end

    it "does not let one user's consent unlock another's flow" do
      post "/api/v1/consent", headers: headers_for("user_alice")

      patch "/api/v1/onboarding_session", params: { state: "assessment" }, headers: headers_for("user_bob")

      expect(response).to have_http_status(:forbidden)
    end
  end
end
