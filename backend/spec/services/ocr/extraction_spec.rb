require "rails_helper"

RSpec.describe Ocr::Extraction do
  let(:golden_set) { Rails.root.join("spec/fixtures/golden_set/ocr/images") }

  # These run the real binary. Kept to two documents: engine accuracy across the whole
  # corpus is the eval harness's job (`rake ai:ocr`), not the unit suite's.
  describe "against a real document", :ocr do
    before { skip("tesseract not installed") unless Ocr::Engine.new.available? }

    it "reads the identity fields off a clean scan" do
      result = described_class.new.call(golden_set.join("clean_scan_01.png").to_s)

      expect(result).not_to be_failed
      expect(result.fields[:dob].value).to match(/\d{4}-\d{2}-\d{2}/)
      expect(result.fields[:name].value).to be_present
    end

    it "records the engine version, since an accuracy figure without one is unfalsifiable" do
      result = described_class.new.call(golden_set.join("clean_scan_01.png").to_s)

      expect(result.engine_version).to match(/\A\d+\.\d+/)
    end
  end

  # OCR failure is an expected outcome the flow recovers from by offering manual
  # entry, not an exception for a controller to rescue. If this ever raises, the
  # upload path returns a 500 and the user dead-ends -- the exact failure mode the
  # brief calls out.
  describe "failure handling" do
    it "returns a failed result rather than raising when the file is missing" do
      result = described_class.new.call("/tmp/definitely-not-here.png")

      expect(result).to be_failed
      expect(result.error).to be_present
    end

    it "returns empty fields on failure so callers need no special case" do
      result = described_class.new.call("/tmp/definitely-not-here.png")

      expect(result.fields.keys).to include(:name, :dob, :address)
      expect(result.fields[:name].value).to be_nil
    end

    it "survives the OCR engine itself failing" do
      engine = instance_double(Ocr::Engine)
      allow(engine).to receive(:lines).and_raise(Ocr::Engine::OcrFailed, "binary vanished")
      allow(engine).to receive(:version).and_return("5.5.3")

      result = described_class.new(engine: engine).call(golden_set.join("clean_scan_01.png").to_s)

      expect(result).to be_failed
      expect(result.error).to include("binary vanished")
    end
  end

  # A preprocessed copy of someone's ID is the same sensitive data as the original.
  # Leaving it in the system temp directory would be a quiet, durable PII leak.
  it "leaves no derived image behind after preprocessing" do
    seen = nil

    Ocr::Preprocessor.new.with_prepared(golden_set.join("clean_scan_01.png").to_s) do |prepared|
      seen = prepared
      expect(File).to exist(seen)
    end

    expect(File).not_to exist(seen)
  end
end
