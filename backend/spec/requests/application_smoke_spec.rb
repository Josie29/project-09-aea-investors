require "rails_helper"

# Smoke coverage for the scaffold itself. If an example here fails the app is
# mis-wired, not merely buggy:
#   - the health check proves routing and the API middleware stack boot end to end,
#     and it is the endpoint the host polls to decide whether a deploy is live;
#   - the Solid Queue examples prove background jobs land in the *primary* database.
#     A regression there (a stray `connects_to`, or a `queue:` tier reappearing in
#     database.yml) would only surface in production, where there is no second
#     database to connect to.
RSpec.describe "Application smoke", type: :request do
  describe "GET /up" do
    it "reports the application as healthy" do
      get "/up"

      expect(response).to have_http_status(:ok)
    end
  end

  describe "Solid Queue" do
    # Rails forces the :test adapter in the test environment. Swap the real one in so
    # these examples exercise the configuration production actually runs.
    around do |example|
      previous_adapter = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :solid_queue
      example.run
    ensure
      ActiveJob::Base.queue_adapter = previous_adapter
    end

    it "keeps its tables on the primary connection" do
      expect(SolidQueue::Job.connection_db_config.name).to eq("primary")
    end

    it "writes an enqueued job to the database" do
      expect { SmokeTestJob.perform_later }.to change(SolidQueue::Job, :count).by(1)
    end
  end
end
