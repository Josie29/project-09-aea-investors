require "open3"

module Ocr
  # Thin wrapper over the Tesseract CLI.
  #
  # Shelling out rather than using a binding gem: we need TSV output with per-word
  # confidences and control over page-segmentation flags, the interface is two
  # commands wide, and it keeps the dependency a system package we already install in
  # the image rather than a gem tracking someone else's build of the same binary.
  class Engine
    class OcrFailed < StandardError; end

    # Tesseract reports -1 for whitespace rows in the TSV; those are structural, not
    # low-confidence readings, and must not drag a field's score down.
    NO_CONFIDENCE = -1

    # 4 = "single column of text of variable sizes". The card is a photo box beside a
    # column of labelled fields; mode 6 ("uniform block") merges the two horizontally
    # and yields lines like "PHOTO Adaeze M. Ashworth".
    DEFAULT_PSM = Integer(ENV.fetch("TESSERACT_PSM", 4))

    Word = Struct.new(:text, :confidence, :line_id, keyword_init: true)

    def initialize(binary: ENV.fetch("TESSERACT_BIN", "tesseract"), psm: DEFAULT_PSM)
      @binary = binary
      @psm = psm
    end

    # @return [Boolean] whether the binary is present and runnable
    def available?
      version.present?
    rescue StandardError
      false
    end

    # @return [String, nil] e.g. "5.5.3". Recorded in the eval scorecard, since an
    #   accuracy number is meaningless without the engine version that produced it.
    def version
      stdout, _stderr, status = Open3.capture3(@binary, "--version")
      return nil unless status.success?

      stdout.lines.first.to_s[/tesseract\s+([\d.]+)/, 1]
    end

    # Runs OCR and returns words with their confidences.
    #
    # @param path [String] image path
    # @return [Array<Word>]
    # @raise [OcrFailed] if the binary is missing or exits non-zero
    def words(path)
      stdout, stderr, status = Open3.capture3(
        @binary, path.to_s, "stdout", "--psm", @psm.to_s, "tsv"
      )
      raise OcrFailed, "tesseract exited #{status.exitstatus}: #{stderr.lines.first}" unless status.success?

      parse_tsv(stdout)
    rescue Errno::ENOENT
      raise OcrFailed, "tesseract binary not found at #{@binary.inspect}"
    end

    # Words grouped into lines, in reading order.
    #
    # @return [Array<Array<Word>>]
    def lines(path)
      words(path).group_by(&:line_id).values
    end

    private

    # Parsed by hand rather than with the csv gem: Tesseract's TSV has no quoting or
    # embedded separators, and csv left Ruby's default gems in 3.4, so avoiding it
    # keeps a dependency out of the Gemfile for a two-line split.
    def parse_tsv(output)
      lines = output.split("\n")
      header = lines.shift.to_s.split("\t")
      return [] if header.empty?

      index = header.each_with_index.to_h

      lines.filter_map do |raw|
        columns = raw.split("\t")
        next if columns.size < header.size

        row = ->(name) { columns[index.fetch(name, -1)] }
        text = row.call("text").to_s.strip
        next if text.empty?

        Word.new(
          text: text,
          confidence: row.call("conf").to_f,
          # block/paragraph/line together identify a visual line; page_num is constant
          # for a single image but included so the key stays correct for PDFs later.
          line_id: %w[page_num block_num par_num line_num].map { |c| row.call(c) }.join("-")
        )
      end
    end
  end
end
