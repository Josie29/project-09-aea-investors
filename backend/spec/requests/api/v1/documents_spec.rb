require "rails_helper"

RSpec.describe "Document upload" do
  before { stub_clerk_jwks }

  def headers_for(clerk_id = "user_alice")
    auth_headers(clerk_token({ "sub" => clerk_id }))
  end

  def consent!(clerk_id = "user_alice")
    post "/api/v1/consent", headers: headers_for(clerk_id)
  end

  def upload(io, filename, type)
    Rack::Test::UploadedFile.new(io, type, original_filename: filename)
  end

  let(:golden_scan) { Rails.root.join("spec/fixtures/golden_set/ocr/images/clean_scan_01.png") }
  let(:valid_image) { upload(golden_scan.to_s, "id.png", "image/png") }

  describe "the consent gate" do
    # The requirement this endpoint exists to satisfy: no document is uploaded or
    # processed before consent is logged. Enforced server-side, so a client that
    # skips the consent screen is refused rather than trusted.
    it "refuses an upload when consent has not been given" do
      post "/api/v1/document", params: { image: valid_image }, headers: headers_for

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body["error"]).to eq("consent_required")
    end

    it "refuses an upload after consent is withdrawn" do
      consent!
      delete "/api/v1/consent", headers: headers_for

      post "/api/v1/document", params: { image: valid_image }, headers: headers_for

      expect(response).to have_http_status(:forbidden)
    end

    it "stores nothing when the gate refuses" do
      expect { post "/api/v1/document", params: { image: valid_image }, headers: headers_for }
        .not_to change(ActiveStorage::Blob, :count)
    end

    it "accepts the upload once consent is on file" do
      consent!

      post "/api/v1/document", params: { image: valid_image }, headers: headers_for

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["image_available"]).to be(true)
    end
  end

  describe "server-side validation" do
    before { consent! }

    it "rejects a file that is not an image" do
      text = upload(StringIO.new("this is not a picture"), "notes.txt", "text/plain")

      post "/api/v1/document", params: { image: text }, headers: headers_for

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to eq("invalid_upload")
    end

    # Declared Content-Type and filename are both attacker-controlled. Renaming a
    # payload to id.png and declaring image/png costs nothing, so the validator
    # sniffs the actual bytes -- a check that trusts the label is decorative.
    it "rejects a non-image disguised with an image name and content type" do
      disguised = upload(StringIO.new("MZ\x90\x00 not really a png"), "id.png", "image/png")

      post "/api/v1/document", params: { image: disguised }, headers: headers_for

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects a file over the size limit" do
      oversized = upload(StringIO.new("x" * (DocumentImageValidator::MAX_BYTES + 1)), "big.png", "image/png")

      post "/api/v1/document", params: { image: oversized }, headers: headers_for

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["detail"]).to match(/under/i)
    end

    it "rejects a request with no file at all" do
      post "/api/v1/document", headers: headers_for

      expect(response).to have_http_status(:unprocessable_content)
    end

    # A rejected upload must never dead-end the user: the message is shown verbatim
    # and the manual-entry path stays open. An unhandled 500 here is the exact
    # failure the brief calls out.
    it "explains the problem in words a user can act on" do
      text = upload(StringIO.new("nope"), "notes.txt", "text/plain")

      post "/api/v1/document", params: { image: text }, headers: headers_for

      expect(response.parsed_body["detail"]).to include('JPG or PNG')
    end
  end

  describe "re-uploading" do
    before { consent! }

    # Common: the first photo is blurry, or OCR failed and the user tries again. Each
    # attempt must destroy the previous image rather than leaving copies of someone's
    # ID accumulating in the bucket.
    it "replaces the previous image rather than keeping both" do
      post "/api/v1/document", params: { image: valid_image }, headers: headers_for

      expect { post "/api/v1/document", params: { image: upload(golden_scan.to_s, "retry.png", "image/png") }, headers: headers_for }
        .not_to change(ActiveStorage::Blob, :count)
    end

    it "keeps one document record per session" do
      post "/api/v1/document", params: { image: valid_image }, headers: headers_for

      expect { post "/api/v1/document", params: { image: upload(golden_scan.to_s, "retry.png", "image/png") }, headers: headers_for }
        .not_to change(Document, :count)
    end
  end

  describe "GET /api/v1/document" do
    it "reports no document before anything is uploaded" do
      get "/api/v1/document", headers: headers_for

      expect(response.parsed_body["status"]).to eq("none")
    end

    # The filename a phone assigns can itself be identifying, and the interface has no
    # use for it.
    it "never returns the original filename" do
      consent!
      post "/api/v1/document", params: { image: valid_image }, headers: headers_for

      get "/api/v1/document", headers: headers_for

      expect(response.body).not_to include("id.png")
    end

    it "does not leak another user's document" do
      consent!
      post "/api/v1/document", params: { image: valid_image }, headers: headers_for

      get "/api/v1/document", headers: headers_for("user_bob")

      expect(response.parsed_body["status"]).to eq("none")
    end
  end

  it "requires authentication" do
    post "/api/v1/document", params: { image: valid_image }

    expect(response).to have_http_status(:unauthorized)
  end
end
