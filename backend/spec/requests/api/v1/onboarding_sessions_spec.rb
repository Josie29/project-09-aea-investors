require "rails_helper"

RSpec.describe "Onboarding sessions" do
  before { stub_clerk_jwks }

  # Distinct Clerk subjects, so each request authenticates as a genuinely different
  # person rather than sharing one local user row.
  def headers_for(clerk_id)
    auth_headers(clerk_token({ "sub" => clerk_id }))
  end

  describe "GET /api/v1/onboarding_session" do
    it "starts a session at the first step on first contact" do
      get "/api/v1/onboarding_session", headers: headers_for("user_alice")

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["state"]).to eq("consent")
    end

    # Resumability is the product's whole premise: a user who closes the tab mid-flow
    # must not restart from step one.
    it "returns the same session at the step the user left off" do
      get "/api/v1/onboarding_session", headers: headers_for("user_alice")
      patch "/api/v1/onboarding_session", params: { state: "assessment" }, headers: headers_for("user_alice")

      get "/api/v1/onboarding_session", headers: headers_for("user_alice")

      expect(response.parsed_body["state"]).to eq("assessment")
    end

    it "requires authentication" do
      get "/api/v1/onboarding_session"

      expect(response).to have_http_status(:unauthorized)
    end

    # The singular route has no id, so two users hitting the identical URL must get
    # their own records. If this ever returned a shared session, every patient would
    # see the last one's intake.
    it "gives each user their own session from the same URL" do
      get "/api/v1/onboarding_session", headers: headers_for("user_alice")
      alice = response.parsed_body["id"]

      get "/api/v1/onboarding_session", headers: headers_for("user_bob")

      expect(response.parsed_body["id"]).not_to eq(alice)
    end
  end

  describe "PATCH /api/v1/onboarding_session" do
    it "advances one step" do
      patch "/api/v1/onboarding_session", params: { state: "assessment" }, headers: headers_for("user_alice")

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["state"]).to eq("assessment")
    end

    it "refuses to skip a step" do
      patch "/api/v1/onboarding_session", params: { state: "schedule" }, headers: headers_for("user_alice")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to eq("invalid_transition")
    end

    # A retried or double-submitted request must not advance twice.
    it "rejects a replay of a transition already applied" do
      patch "/api/v1/onboarding_session", params: { state: "assessment" }, headers: headers_for("user_alice")
      patch "/api/v1/onboarding_session", params: { state: "assessment" }, headers: headers_for("user_alice")

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /api/v1/onboarding_sessions/:id" do
    it "returns the caller's own session" do
      get "/api/v1/onboarding_session", headers: headers_for("user_alice")
      id = response.parsed_body["id"]

      get "/api/v1/onboarding_sessions/#{id}", headers: headers_for("user_alice")

      expect(response).to have_http_status(:ok)
    end

    # The requirement the brief states outright: a user can only access their own
    # onboarding record.
    it "does not let one user read another's session" do
      get "/api/v1/onboarding_session", headers: headers_for("user_alice")
      alice_id = response.parsed_body["id"]

      get "/api/v1/onboarding_sessions/#{alice_id}", headers: headers_for("user_bob")

      expect(response).to have_http_status(:not_found)
    end

    # 404 and not 403: a 403 confirms the id belongs to a real session, which hands an
    # attacker enumerating ids a map of which ones exist.
    it "is indistinguishable from a session that does not exist" do
      get "/api/v1/onboarding_session", headers: headers_for("user_alice")
      forbidden = fetch_as_bob("/api/v1/onboarding_sessions/#{response.parsed_body['id']}")

      expect(fetch_as_bob("/api/v1/onboarding_sessions/999999")).to eq(forbidden)
    end

    # Returns the pair a caller could distinguish records by.
    def fetch_as_bob(path)
      get path, headers: headers_for("user_bob")
      [ response.status, response.parsed_body ]
    end
  end

  # The response is built field by field, so a column added later is omitted by
  # default rather than published by accident.
  it "returns only the fields the serializer names" do
    get "/api/v1/onboarding_session", headers: headers_for("user_alice")

    expect(response.parsed_body.keys)
      .to match_array(%w[id state next_state complete states updated_at])
  end
end
