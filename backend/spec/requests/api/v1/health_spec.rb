require "rails_helper"

RSpec.describe "GET /api/v1/health" do
  subject(:body) { response.parsed_body }

  context "when every dependency is reachable" do
    before { get "/api/v1/health" }

    # The uptime monitor treats any non-2xx as downtime. If this breaks, a healthy
    # deployment starts reporting as an outage and the >=99% uptime target fails.
    it "returns 200" do
      expect(response).to have_http_status(:ok)
    end

    it "reports the database as reachable with a latency reading" do
      expect(body.dig("checks", "database", "status")).to eq("ok")
      expect(body.dig("checks", "database", "latency_ms")).to be_a(Numeric)
    end

    # Dependencies that do not exist yet must still appear, so wiring them up later
    # is a value change rather than a response-shape change that breaks consumers.
    it "reports not-yet-built dependencies as not_configured" do
      expect(body.dig("checks", "ocr", "status")).to eq("not_configured")
      expect(body.dig("checks", "llm", "status")).to eq("not_configured")
    end
  end

  context "when the database is unreachable" do
    before do
      allow(ActiveRecord::Base.connection)
        .to receive(:select_value)
        .and_raise(ActiveRecord::ConnectionNotEstablished, "could not connect to server")

      get "/api/v1/health"
    end

    # A 200 while the database is down would let a broken deploy sit undetected for
    # the whole review window, since nothing else polls the app.
    it "returns 503 so the monitor registers the outage" do
      expect(response).to have_http_status(:service_unavailable)
      expect(body["status"]).to eq("unavailable")
    end

    # This endpoint is unauthenticated. Postgres adapter errors routinely embed the
    # full connection string, so echoing the exception message here would publish
    # database credentials to anyone who curls it.
    it "reports only the exception class, never the message" do
      expect(body.dig("checks", "database", "error")).to eq("ActiveRecord::ConnectionNotEstablished")
      expect(response.body).not_to include("could not connect to server")
    end
  end

  # Catches an auth before_action being added to the base controller and silently
  # locking out the uptime probe -- which would look identical to a real outage.
  it "requires no authentication" do
    get "/api/v1/health", headers: { "Authorization" => nil }

    expect(response).to have_http_status(:ok)
  end
end
