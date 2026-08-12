class DocumentExtractionJob < ApplicationJob
  queue_as :default

  # Retried only for transient infrastructure problems — the storage read failing,
  # the network glitching. An image Tesseract cannot make sense of is NOT retried:
  # the result would be identical, and the flow already handles it properly by
  # offering manual entry. Retrying it would just delay that offer.
  retry_on ActiveStorage::FileNotFoundError, wait: :polynomially_longer, attempts: 3

  # Extracts identity fields from a document's uploaded image.
  #
  # Never raises on a bad read. OCR failure is an expected outcome the flow recovers
  # from, so the job records the failure and returns — an exception here would leave
  # the document stuck in `processing` forever with the user watching a spinner.
  #
  # @param document_id [Integer]
  def perform(document_id)
    document = Document.find_by(id: document_id)
    return if document.nil? || !document.image.attached?

    document.update!(status: "processing")

    result = extract(document)

    if result.failed?
      # Only the error class and the document id. The image and anything read from it
      # are the most sensitive data in the system and must never reach a log line.
      Rails.logger.warn("ocr extraction failed for document #{document.id}: #{result.error}")
      document.update!(status: "failed")
      return
    end

    persist_fields(document, result.fields)
    document.update!(status: "extracted")

    Rails.logger.info(
      "ocr extraction complete for document #{document.id} " \
      "in #{result.duration_ms}ms, #{result.fields.count { |_, f| f.value.present? }}/#{result.fields.size} fields read"
    )
  end

  private

  # Tesseract reads a path, not a stream, so the image has to touch local disk.
  # `open` gives it a tempfile with a defined lifetime that is removed on both the
  # success and failure paths — a copy of someone's ID left in /tmp would be exactly
  # the kind of quiet, durable leak the retention policy exists to prevent.
  def extract(document)
    document.image.open(tmpdir: Dir.tmpdir) do |file|
      Ocr::Extraction.new.call(file.path)
    end
  end

  def persist_fields(document, fields)
    ExtractedField.transaction do
      fields.each do |name, field|
        next unless ExtractedField::NAMES.include?(name.to_s)

        record = ExtractedField.find_or_initialize_by(document: document, name: name.to_s)

        # A re-read replaces the machine's reading but must NOT wipe a value the user
        # already confirmed — that would silently discard their correction and ask
        # them to make it again.
        record.value = field.value
        record.confidence = field.confidence
        record.save!
      end
    end
  end
end
