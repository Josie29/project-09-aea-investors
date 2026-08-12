module Ocr
  # Maps raw OCR lines onto the identity fields the onboarding flow needs.
  #
  # Label-anchored rather than positional: the card prints NAME, DOB, and ADDRESS
  # captions above their values, and anchoring on those survives the skew and crop
  # variation that would break fixed coordinates.
  #
  # Confidence for a field is the MINIMUM confidence of the words composing it, not
  # the mean. One garbled character is what makes a field wrong, and a mean would let
  # four confident words hide it -- which is precisely the case the confirm screen
  # exists to catch.
  class FieldExtractor
    Field = Struct.new(:value, :confidence, keyword_init: true) do
      def blank_value? = value.nil? || value.strip.empty?
    end

    # Captions as printed on the card. Matched loosely because OCR routinely returns
    # "NAKE" or "AODRESS" on a degraded scan, and demanding an exact caption would
    # discard a field whose value read perfectly well.
    ANCHORS = {
      name: /\A(NAME|NAHE|NAKE|N[A4]ME)\z/i,
      dob: /\A(DOB|D0B|DQB)\z/i,
      address: /\A(ADDRESS|AODRESS|ADDR[E3]SS)\z/i,
      id_number: /\A(DL|OL|D1)\z/i
    }.freeze

    # A date on this card is always ISO. Used to recover a DOB whose caption was
    # mangled beyond matching.
    DATE_PATTERN = /\b(\d{4})[-\/](\d{2})[-\/](\d{2})\b/

    # Words printed on the card's furniture rather than in any field. The portrait
    # placeholder sits to the left of the field column, and every page-segmentation
    # mode we tested joins it onto whichever field line it happens to align with,
    # producing values like "PHOTO Marisol M. Okafor". Stripping them here fixes the
    # cause; the alternative was preprocessing the image to separate the columns,
    # which measured far worse on photographed cards than doing nothing at all.
    CHROME_TOKENS = /\A(PHOTO|PHOT0|PH0TO|CLASS|ISS|EXP)\z/i

    def initialize(lines)
      @lines = lines.map { |words| LineView.new(words) }
    end

    # @return [Hash{Symbol => Field}]
    def call
      {
        name: extract_name,
        dob: extract_dob,
        address: extract_address,
        id_number: single_line_after(:id_number)
      }
    end

    private

    # Groups a line's words so text and confidence stay associated.
    class LineView
      attr_reader :words

      def initialize(words)
        @words = words
      end

      # Card furniture removed before the value is read, but kept in `words` so
      # `raw_text` can still match a caption line that consists only of chrome.
      def text
        content_words.map(&:text).join(" ")
      end

      def raw_text = words.map(&:text).join(" ")

      # Confidence over the words that actually form the value. Including a
      # confidently-read "PHOTO" would raise a field's score for text the user is not
      # being shown.
      def min_confidence
        scored = content_words.map(&:confidence).reject { |c| c == Engine::NO_CONFIDENCE }
        scored.empty? ? 0.0 : scored.min
      end

      private

      def content_words
        @content_words ||= words.reject { |word| CHROME_TOKENS.match?(word.text) }
      end
    end

    # Matched against raw text: a caption line is chrome-free already, and using the
    # filtered text would let a line of pure chrome collapse to empty and shift the
    # index of the value line that follows.
    def anchor_index(field)
      @lines.index { |line| ANCHORS.fetch(field).match?(line.raw_text.strip) }
    end

    def single_line_after(field)
      index = anchor_index(field)
      return Field.new(value: nil, confidence: 0.0) if index.nil?

      line = @lines[index + 1]
      return Field.new(value: nil, confidence: 0.0) if line.nil?

      Field.new(value: line.text.strip, confidence: normalize(line.min_confidence))
    end

    def extract_name = single_line_after(:name)

    def extract_dob
      field = single_line_after(:dob)
      return field if field.value.to_s.match?(DATE_PATTERN)

      # The caption was unreadable but the value may not be. Fall back to the first
      # ISO date on the card -- better than discarding a field the user would
      # otherwise have to retype.
      fallback = @lines.find { |line| line.text.match?(DATE_PATTERN) }
      return field if fallback.nil?

      Field.new(value: fallback.text[DATE_PATTERN], confidence: normalize(fallback.min_confidence))
    end

    # Address spans two printed lines: street, then city/state/postcode.
    def extract_address
      index = anchor_index(:address)
      return Field.new(value: nil, confidence: 0.0) if index.nil?

      parts = [ @lines[index + 1], @lines[index + 2] ].compact
      return Field.new(value: nil, confidence: 0.0) if parts.empty?

      Field.new(
        value: parts.map { |line| line.text.strip }.join(", "),
        confidence: normalize(parts.map(&:min_confidence).min)
      )
    end

    # Tesseract reports 0-100; the rest of the system speaks 0-1 so thresholds read
    # the same in Ruby and in the TypeScript that renders them.
    def normalize(confidence)
      (confidence / 100.0).round(4).clamp(0.0, 1.0)
    end
  end
end
