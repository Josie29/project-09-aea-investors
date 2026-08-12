require "rails_helper"

RSpec.describe Document do
  let(:session) { OnboardingSession.for(create(:user)) }
  let(:image) do
    Rack::Test::UploadedFile.new(
      Rails.root.join("spec/fixtures/golden_set/ocr/images/clean_scan_01.png").to_s,
      "image/png", original_filename: "id.png"
    )
  end

  describe ".replace_for!" do
    it "attaches the image and starts in the pending state" do
      document = described_class.replace_for!(session, image)

      expect(document.status).to eq("pending")
      expect(document).to be_image_available
    end

    it "clears a previous purge timestamp when a new image arrives" do
      document = described_class.replace_for!(session, image)
      document.purge_image!

      described_class.replace_for!(session, image)

      expect(document.reload.image_purged_at).to be_nil
      expect(document.status).to eq("pending")
    end
  end

  describe "#purge_image!" do
    subject(:document) { described_class.replace_for!(session, image) }

    it "destroys the image and records when" do
      document.purge_image!

      expect(document).not_to be_image_available
      expect(document.image_purged_at).to be_present
      expect(document.status).to eq("purged")
    end

    # Both confirmation and an explicit deletion request reach this, and a user can
    # request deletion after confirmation has already purged. "Already deleted" is
    # the desired end state, so a second call must not raise.
    it "is safe to call twice" do
      document.purge_image!
      first_purge = document.image_purged_at

      expect { document.purge_image! }.not_to raise_error
      expect(document.reload.image_purged_at).to eq(first_purge)
    end

    # The record survives as evidence the image existed and was removed. Destroying
    # it outright would leave nothing to show a user asking whether their document
    # was really deleted.
    it "keeps the record after the image is gone" do
      document.purge_image!

      expect(described_class.find_by(onboarding_session: session)).to be_present
    end
  end
end
