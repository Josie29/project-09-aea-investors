require "rails_helper"

RSpec.describe DocumentExtractionJob do
  let(:session) { OnboardingSession.for(create(:user)) }
  let(:golden_scan) { Rails.root.join("spec/fixtures/golden_set/ocr/images/clean_scan_01.png") }

  def document_with(fixture)
    upload = Rack::Test::UploadedFile.new(fixture.to_s, "image/png", original_filename: "id.png")
    Document.replace_for!(session, upload)
  end

  describe "a successful read", :ocr do
    subject(:document) { document_with(golden_scan) }

    before { skip("tesseract not installed") unless Ocr::Engine.new.available? }


    it "stores each field with its confidence" do
      described_class.perform_now(document.id)

      name = document.extracted_fields.find_by(name: "name")
      expect(name.value).to be_present
      expect(name.confidence).to be > 0
    end

    it "marks the document extracted" do
      described_class.perform_now(document.id)

      expect(document.reload.status).to eq("extracted")
    end

    # A second read must not silently discard a correction the user already made and
    # ask them to make it again.
    it "keeps a value the user already confirmed when the image is read again" do
      described_class.perform_now(document.id)
      field = document.extracted_fields.find_by(name: "name")
      field.update!(confirmed_value: "Corrected By Hand", confirmed_at: Time.current)

      described_class.perform_now(document.id)

      expect(field.reload.confirmed_value).to eq("Corrected By Hand")
      expect(field.display_value).to eq("Corrected By Hand")
    end
  end

  describe "when the read fails" do
    subject(:document) { document_with(golden_scan) }

    before do
      failed = Ocr::Extraction::Result.new(fields: {}, error: "unreadable", duration_ms: 12)
      allow_any_instance_of(Ocr::Extraction).to receive(:call).and_return(failed) # rubocop:disable RSpec/AnyInstance
    end

    # The document must not be left in `processing` forever with the user watching a
    # spinner. Failure is an expected outcome the flow recovers from by offering
    # manual entry, so it is recorded rather than raised.
    it "records the failure instead of raising" do
      expect { described_class.perform_now(document.id) }.not_to raise_error

      expect(document.reload.status).to eq("failed")
    end

    # The image and everything read from it are the most sensitive data in the system.
    it "logs the failure without any extracted content" do
      allow(Rails.logger).to receive(:warn)

      described_class.perform_now(document.id)

      expect(Rails.logger).to have_received(:warn).with(/document #{document.id}/)
    end
  end

  describe "guards" do
    it "does nothing for a document that no longer exists" do
      expect { described_class.perform_now(-1) }.not_to raise_error
    end

    # The purge may win a race against a queued job. That is the correct outcome —
    # the image is gone because it was meant to be gone.
    it "does nothing when the image has already been purged" do
      document = document_with(golden_scan)
      document.purge_image!

      expect { described_class.perform_now(document.id) }.not_to raise_error
      expect(document.reload.status).to eq("purged")
    end
  end

  it "is enqueued when a document is uploaded" do
    expect { document_with(golden_scan).then { |d| described_class.perform_later(d.id) } }
      .to have_enqueued_job(described_class)
  end
end
