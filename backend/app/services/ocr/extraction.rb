module Ocr
  # Reads identity fields off a document image.
  #
  # The single entry point the rest of the application uses. Callers never touch the
  # engine or the extractor directly, so swapping Tesseract for PaddleOCR later is a
  # change inside this file rather than across the codebase.
  class Extraction
    Result = Struct.new(:fields, :engine_version, :duration_ms, :error, keyword_init: true) do
      def failed? = !error.nil?
    end

    def initialize(engine: Engine.new, preprocessor: Preprocessor.new)
      @engine = engine
      @preprocessor = preprocessor
    end

    # @param path [String] image path
    # @return [Result] fields keyed by symbol; on failure, empty fields and an error
    #   string. Never raises: OCR failure is an expected outcome the flow recovers
    #   from by offering manual entry, not an exception for a controller to rescue.
    def call(path)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      fields = @preprocessor.with_prepared(path) do |prepared|
        FieldExtractor.new(@engine.lines(prepared)).call
      end

      Result.new(fields: fields, engine_version: @engine.version, duration_ms: elapsed_ms(started))
    rescue Engine::OcrFailed, Preprocessor::PreprocessingFailed => e
      Result.new(fields: empty_fields, engine_version: safe_version, duration_ms: elapsed_ms(started), error: e.message)
    end

    private

    def empty_fields
      %i[name dob address id_number].index_with { FieldExtractor::Field.new(value: nil, confidence: 0.0) }
    end

    def safe_version
      @engine.version
    rescue StandardError
      nil
    end

    def elapsed_ms(started)
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1_000).round(1)
    end
  end
end
