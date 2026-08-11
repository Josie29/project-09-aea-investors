require "rails_helper"

RSpec.describe "GET /api/v1/me" do
  before { stub_clerk_jwks }

  context "with a valid Clerk token" do
    it "returns the user's own record" do
      get "/api/v1/me", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["clerk_id"]).to eq("user_2abcdef")
    end

    # The whole point of sync-on-first-request: a user who has never hit the API
    # before must not need a separate provisioning step before onboarding works.
    it "creates the local user row on first contact" do
      expect { get "/api/v1/me", headers: auth_headers }.to change(User, :count).by(1)
    end

    it "reuses the existing row on subsequent requests" do
      get "/api/v1/me", headers: auth_headers

      expect { get "/api/v1/me", headers: auth_headers }.not_to change(User, :count)
    end
  end

  # If any of these returned 200, every onboarding record in the system would be
  # reachable without credentials.
  context "without a usable token" do
    it "rejects a missing Authorization header" do
      get "/api/v1/me"

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects a token signed by an unknown key" do
      get "/api/v1/me", headers: auth_headers(clerk_token({}, key: ClerkTokenHelper.foreign_key))

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects an expired token" do
      get "/api/v1/me", headers: auth_headers(clerk_token({ "exp" => 5.minutes.ago.to_i }))

      expect(response).to have_http_status(:unauthorized)
    end

    # The rejection reason describes the token, never the user, and must never echo
    # the token itself -- it is a bearer credential and would land in logs.
    it "returns no detail beyond 'unauthorized'" do
      token = clerk_token({ "exp" => 5.minutes.ago.to_i })

      get "/api/v1/me", headers: auth_headers(token)

      expect(response.parsed_body).to eq({ "error" => "unauthorized" })
      expect(response.body).not_to include(token)
    end
  end
end
