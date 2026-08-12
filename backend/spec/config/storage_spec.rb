require "rails_helper"

# Configuration tests rather than behaviour tests. These exist because the failure
# they guard against is silent and catastrophic: a storage service that turns public,
# or a production environment quietly writing ID photographs to a container's
# ephemeral disk. Neither shows up as a failing feature — the app keeps working right
# up until the documents are either exposed or gone.
RSpec.describe "Active Storage configuration", :aggregate_failures do # rubocop:disable RSpec/DescribeClass
  # Parsed straight from the file. `config_for` expects environment-keyed YAML and
  # storage.yml is keyed by service name, so it returns nil here — and a spec reading
  # nil would pass every assertion it makes about a missing key.
  let(:config) do
    raw = ERB.new(Rails.root.join("config/storage.yml").read).result
    YAML.safe_load(raw, aliases: true, permitted_classes: [ Symbol ]).deep_symbolize_keys
  end

  describe "the B2 service" do
    subject(:b2) { config[:b2] }

    # The whole point of the service. Public means permanent URLs to photographs of
    # government IDs, which outlive the record being deleted.
    it "is not public" do
      expect(b2[:public]).to be(false)
    end

    it "encrypts objects at rest on upload" do
      expect(b2.dig(:upload, :server_side_encryption)).to eq("AES256")
    end

    # B2's S3 endpoint rejects virtual-host-style URLs, so without this every upload
    # fails with an error that points at the bucket name rather than the setting.
    it "addresses the bucket by path" do
      expect(b2[:force_path_style]).to be(true)
    end

    it "takes every credential from the environment" do
      raw = Rails.root.join("config/storage.yml").read

      expect(raw).to include('ENV["B2_KEY_ID"]', 'ENV["B2_APPLICATION_KEY"]')
      expect(raw).not_to match(/access_key_id:\s*["']?00[0-9a-f]{20}/)
    end
  end

  describe "environment wiring" do
    # Railway's filesystem is ephemeral. Disk storage in production means a container
    # restart destroys documents mid-flow, and a deletion request has nothing to purge
    # while the user is told their data is gone.
    it "never uses disk storage in production" do
      production = Rails.root.join("config/environments/production.rb").read

      expect(production).to match(/active_storage\.service\s*=\s*:b2/)
      expect(production).not_to match(/active_storage\.service\s*=\s*:local/)
    end

    # A signed URL is a bearer credential for the document. Minutes, not hours.
    it "expires signed URLs in minutes" do
      production = Rails.root.join("config/environments/production.rb").read

      expect(production).to match(/urls_expire_in\s*=\s*\d+\.minutes/)
    end

    it "keeps the test suite off any real bucket" do
      expect(config[:test][:service]).to eq("Disk")
    end
  end
end
