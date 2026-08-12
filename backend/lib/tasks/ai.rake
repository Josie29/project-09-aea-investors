require "json"

namespace :ai do
  GOLDEN_SET_DIR = Rails.root.join("spec/fixtures/golden_set/ocr")

  desc "Score OCR extraction against the synthetic golden set"
  task ocr: :environment do
    labels = JSON.parse(File.read(GOLDEN_SET_DIR.join("expected/labels.json")))
    documents = labels.fetch("documents")
    scored_fields = labels.fetch("scored_fields").map(&:to_sym)

    extraction = Ocr::Extraction.new
    engine_version = Ocr::Engine.new.version

    abort "tesseract not found on PATH. Install it, or run inside the Docker image." if engine_version.nil?

    results = documents.map do |document|
      image = GOLDEN_SET_DIR.join("images", document.fetch("filename"))
      result = extraction.call(image.to_s)

      comparisons = scored_fields.index_with do |field|
        expected = document.fetch(field.to_s)
        actual = result.fields[field]
        {
          expected: expected,
          actual: actual.value,
          confidence: actual.confidence,
          correct: OcrScoring.matches?(expected, actual.value)
        }
      end

      { document: document, comparisons: comparisons, duration_ms: result.duration_ms, error: result.error }
    end

    OcrScoring.print_scorecard(results, scored_fields, engine_version)
  end

  desc "Run every AI evaluation (OCR and, once it exists, chatbot intent coverage)"
  task eval: %i[ocr]
end

# Scoring and reporting for the OCR eval.
module OcrScoring
  THRESHOLD = 0.90

  class << self
    # Compares an extracted value against ground truth.
    #
    # Normalised before comparison because case, punctuation, and run-together
    # whitespace are not errors a user would have to correct -- "1420 W Fulton St."
    # and "1420 W FULTON ST" are the same address. A wrong character still fails.
    def matches?(expected, actual)
      return false if actual.nil?

      normalize(expected) == normalize(actual)
    end

    def normalize(value)
      value.to_s
           .unicode_normalize(:nfkd)
           .downcase
           .gsub(/[[:punct:]]/, " ")
           .gsub(/\s+/, " ")
           .strip
    end

    def print_scorecard(results, fields, engine_version)
      puts
      puts "OCR golden set scorecard"
      puts "=" * 72
      puts "  Engine          tesseract #{engine_version}"
      puts "  Ruby            #{RUBY_VERSION}"
      puts "  Host            #{RbConfig::CONFIG['host_os']}"
      puts "  Documents       #{results.size}"
      puts "  Threshold       #{(THRESHOLD * 100).to_i}% field-level accuracy"
      puts

      print_per_field(results, fields)
      print_per_tier(results, fields)
      print_failures(results, fields)

      overall = accuracy(results, fields)
      puts
      puts "-" * 72
      status = overall >= THRESHOLD ? "PASS" : "FAIL"
      puts format("  OVERALL  %<pct>.1f%%   %<status>s", pct: overall * 100, status: status)
      puts "-" * 72
      puts

      # Non-zero exit so CI can gate on the threshold rather than a human reading
      # the number and deciding it looks about right.
      exit(1) if overall < THRESHOLD
    end

    private

    def all_comparisons(results, fields)
      results.flat_map { |result| fields.map { |field| result[:comparisons][field] } }
    end

    def accuracy(results, fields)
      comparisons = all_comparisons(results, fields)
      return 0.0 if comparisons.empty?

      comparisons.count { |c| c[:correct] }.to_f / comparisons.size
    end

    def print_per_field(results, fields)
      puts "  Per field"
      fields.each do |field|
        comparisons = results.map { |result| result[:comparisons][field] }
        correct = comparisons.count { |c| c[:correct] }
        puts format("    %-10<field>s %<correct>2d/%<total>2d   %<pct>5.1f%%",
                    field: field, correct: correct, total: comparisons.size,
                    pct: 100.0 * correct / comparisons.size)
      end
      puts
    end

    def print_per_tier(results, fields)
      puts "  Per tier"
      results.group_by { |result| result[:document]["tier"] }.each do |tier, tier_results|
        comparisons = all_comparisons(tier_results, fields)
        correct = comparisons.count { |c| c[:correct] }
        mean_ms = tier_results.sum { |r| r[:duration_ms].to_f } / tier_results.size
        puts format("    %-12<tier>s %<correct>2d/%<total>2d   %<pct>5.1f%%   %<ms>6.0f ms avg",
                    tier: tier, correct: correct, total: comparisons.size,
                    pct: 100.0 * correct / comparisons.size, ms: mean_ms)
      end
      puts
    end

    def print_failures(results, fields)
      failures = results.flat_map do |result|
        fields.filter_map do |field|
          comparison = result[:comparisons][field]
          next if comparison[:correct]

          [ result[:document]["id"], field, comparison ]
        end
      end

      return if failures.empty?

      puts "  Misses (#{failures.size})"
      failures.first(20).each do |id, field, comparison|
        puts format("    %-16<id>s %-8<field>s conf %<conf>.2f", id: id, field: field, conf: comparison[:confidence])
        puts "      expected  #{comparison[:expected].inspect}"
        puts "      got       #{comparison[:actual].inspect}"
      end
      puts "    ... and #{failures.size - 20} more" if failures.size > 20
      puts
    end
  end
end
