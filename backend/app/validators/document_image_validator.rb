require "marcel"

# Server-side validation of an uploaded document image.
#
# The frontend states the limits before upload, but a client-side check is a courtesy
# to honest users, not a control. Everything here is enforced again on the server,
# because the only thing standing between the OCR pipeline and a hostile file is this
# class.
class DocumentImageValidator
  MAX_BYTES = 10.megabytes

  # Deliberately narrow. Tesseract will attempt far more formats than this, and every
  # additional decoder is additional attack surface reachable by an unauthenticated-
  # adjacent user with an upload box.
  PERMITTED_TYPES = %w[image/jpeg image/png].freeze

  Result = Struct.new(:valid, :error, keyword_init: true) do
    def valid? = valid
  end

  def initialize(upload)
    @upload = upload
  end

  # @return [Result] with a user-facing message on failure
  def call
    return failure("Choose a photo of your ID to upload.") if @upload.blank?
    return failure(size_message) if too_large?
    return failure(type_message) unless permitted_type?

    Result.new(valid: true)
  end

  private

  def too_large?
    @upload.size > MAX_BYTES
  end

  # Sniffs the actual bytes rather than trusting the declared Content-Type or the
  # filename extension. Both are attacker-controlled: renaming payload.exe to id.png
  # and declaring image/png costs nothing, and a validator that believes either is
  # decorative.
  def permitted_type?
    PERMITTED_TYPES.include?(detected_type)
  end

  def detected_type
    @detected_type ||= begin
      @upload.rewind
      Marcel::MimeType.for(@upload, name: @upload.original_filename)
    ensure
      @upload.rewind
    end
  end

  def size_message
    "That file is #{ActiveSupport::NumberHelper.number_to_human_size(@upload.size)}. " \
      "Please upload an image under #{ActiveSupport::NumberHelper.number_to_human_size(MAX_BYTES)}."
  end

  # Names what was actually detected, so a user who uploaded a PDF or a screenshot in
  # an unexpected format learns something actionable instead of "invalid file".
  def type_message
    "That looks like a #{detected_type} file. Please upload a JPG or PNG photo."
  end

  def failure(message)
    Result.new(valid: false, error: message)
  end
end
