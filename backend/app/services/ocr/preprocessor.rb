require "vips"
require "tmpdir"

module Ocr
  # Prepares an image before OCR.
  #
  # Every step here is switchable and only ONE is on by default, because that is what
  # the golden-set scorecard actually supports. Measured on 30 documents, PSM 4:
  #
  #   deskew only ................ 97.8%   <- default
  #   deskew + upscale ........... 96.7%
  #   nothing .................... 93.3%
  #   sharpen only ............... 85.6%
  #   global equalisation only ... 52.2%
  #   everything ................. 61.1%
  #
  # The lesson worth keeping: contrast normalisation and sharpening are the steps
  # people reach for first, and both made things markedly worse. Sharpening amplifies
  # JPEG ringing around glyph edges into strokes, and a global histogram cannot serve
  # a card that is both shadowed at one edge and blown out in the middle. Do not
  # re-enable either without re-running `rake ai:ocr`.
  #
  # Upscaling is off on the same evidence, with a caveat: after recalibration the
  # golden set no longer contains genuinely low-resolution documents, so it barely
  # exercises that path. A corpus of small uploads would likely flip that decision.
  #
  # libvips rather than ImageMagick: it is already in the production image (Rails 8
  # installs it for Active Storage), it is markedly faster, and it streams rather than
  # loading whole images into memory, which matters when the OCR latency budget is
  # 8 seconds p95.
  class Preprocessor
    class PreprocessingFailed < StandardError; end

    # Tesseract's accuracy falls off sharply below roughly 300 DPI. Our hard tier is
    # deliberately downscaled to 55-72% of card size, so upscaling to a target height
    # is the single largest win available.
    TARGET_HEIGHT = 1400

    # Never upscale beyond this. Past it, Tesseract gets slower with no accuracy gain,
    # and the p95 latency target is real.
    MAX_SCALE = 4.0

    # Widest skew we attempt to correct. A card held more crookedly than this is a
    # retake, not a preprocessing problem, and widening the search costs time on every
    # document to rescue a handful.
    SKEW_SEARCH_DEGREES = 8.0

    # Below this, rotating costs a resample and its interpolation blur for no gain.
    MIN_CORRECTABLE_SKEW = 0.3

    # Width of the downscaled copy used to measure skew.
    PROBE_WIDTH = 600

    # Fraction trimmed from each edge of the probe before measuring skew.
    PROBE_INSET = 0.10

    # Window for local histogram equalisation, in pixels at the upscaled size.
    LOCAL_CONTRAST_WINDOW = Integer(ENV.fetch("OCR_LOCAL_WINDOW", 96))

    # Steps are individually switchable so the eval harness can measure each one's
    # contribution instead of the pipeline being tuned by intuition. The defaults are
    # the configuration the scorecard actually selected.
    def initialize(target_height: TARGET_HEIGHT, enabled: true,
                   deskew: env_flag("OCR_DESKEW", true),
                   upscale: env_flag("OCR_UPSCALE", false),
                   contrast: ENV.fetch("OCR_CONTRAST", "none"),
                   sharpen: env_flag("OCR_SHARPEN", false))
      @target_height = target_height
      @enabled = enabled
      @deskew = deskew
      @upscale = upscale
      @contrast = contrast
      @sharpen = sharpen
    end

    # Yields a path to the image OCR should read.
    #
    # Takes a block so any derived file has a defined lifetime. A preprocessed copy of
    # someone's ID is the same sensitive data as the original and must not outlive the
    # read that needed it — the temporary directory is removed on block exit, on the
    # success and failure paths alike.
    #
    # @param path [String]
    # @yieldparam prepared [String] path to the prepared image
    def with_prepared(path)
      raise PreprocessingFailed, "no such image: #{path}" unless File.exist?(path)
      return yield path.to_s unless @enabled

      Dir.mktmpdir("ocr-prep") do |dir|
        prepared = File.join(dir, "prepared.png")
        enhance(path.to_s).write_to_file(prepared)
        yield prepared
      end
    rescue Vips::Error => e
      raise PreprocessingFailed, "libvips could not process the image: #{e.message}"
    end

    private

    def enhance(path)
      # Random access, not sequential: histogram equalisation needs more than one pass
      # over the pixels, and libvips raises under sequential access rather than
      # silently degrading. ID photos are small enough that holding one is cheap.
      image = Vips::Image.new_from_file(path, access: :random)

      image = to_greyscale(image)
      image = deskew(image) if @deskew
      image = upscale(image) if @upscale
      image = normalize_contrast(image)
      image = sharpen(image) if @sharpen
      image
    end

    def env_flag(name, default)
      value = ENV.fetch(name, nil)
      return default if value.nil?

      %w[1 true yes on].include?(value.downcase)
    end

    # Rotates the card so its text lines are horizontal.
    #
    # This is the single most important step. Without it the golden set scores 49%
    # and the hard tier scores ZERO — not because characters are misread, but because
    # Tesseract fails to group skewed text into lines at all, so the label anchors the
    # extractor depends on never appear. Every field on those documents came back nil.
    #
    # Method: horizontal projection profile. When text lines are level, summing pixel
    # intensity across each row produces sharp peaks (text) and troughs (gaps), so the
    # variance of that profile peaks at the correct angle. Cheaper and more robust for
    # a document than a Hough transform, which is designed for finding arbitrary lines
    # rather than exploiting the fact that we already know the structure is rows.
    def deskew(image)
      angle = estimate_skew(image)
      return image if angle.abs < MIN_CORRECTABLE_SKEW

      image.similarity(angle: -angle, background: background_level(image))
    end

    # Coarse pass then a fine pass around the winner, rather than one fine sweep over
    # the whole range: same resolution for roughly a quarter of the rotations, which
    # matters against the 8s p95 OCR budget.
    def estimate_skew(image)
      probe = skew_probe(image)

      coarse = best_angle(probe, (-SKEW_SEARCH_DEGREES..SKEW_SEARCH_DEGREES).step(1.0))

      # A winner sitting on the edge of the search range means the profile is being
      # driven by something other than text — the peak is outside the window we
      # looked in. Rotating on that estimate is worse than not rotating: an early
      # version pinned phone photos to -9 degrees when their true skew was under 3,
      # and the hard tier's accuracy went to zero.
      return 0.0 if coarse.abs >= SKEW_SEARCH_DEGREES

      best_angle(probe, ((coarse - 1.0)..(coarse + 1.0)).step(0.25))
    end

    # The angle search runs on a small edge-energy copy. Skew is a global property, so
    # measuring it at full resolution costs time and buys nothing.
    def skew_probe(image)
      scale = (PROBE_WIDTH.to_f / image.width).clamp(0.05, 1.0)
      small = image.resize(scale, kernel: :linear)

      # Edge magnitude, not a light/dark threshold. A threshold classifies the flat
      # grey around a photographed card as "ink", and that region is large enough to
      # dominate the projection — the search then aligns the card's border rather than
      # its text lines. Edge energy is near zero on any flat region, background and
      # card interior alike, so only strokes contribute.
      edges = small.sobel

      # Drop the outer tenth, where rotation and perspective fill leave hard synthetic
      # borders that are pure edge energy and carry no information about text angle.
      inset_x = (edges.width * PROBE_INSET).to_i
      inset_y = (edges.height * PROBE_INSET).to_i
      return edges if edges.width - 2 * inset_x < 32 || edges.height - 2 * inset_y < 32

      edges.crop(inset_x, inset_y, edges.width - 2 * inset_x, edges.height - 2 * inset_y)
    end

    def best_angle(probe, angles)
      angles.max_by { |angle| row_profile_variance(probe, angle) }
    end

    def row_profile_variance(probe, angle)
      rotated = angle.zero? ? probe : probe.similarity(angle: -angle, background: 0)
      _columns, rows = rotated.project
      profile = rows.to_a.flatten

      return 0.0 if profile.empty?

      mean = profile.sum.to_f / profile.size
      profile.sum { |value| (value - mean)**2 } / profile.size
    end

    # Rotation exposes corners; filling them with the image's own median keeps the
    # introduced border from reading as a hard edge Tesseract might treat as content.
    def background_level(image)
      [ image.percent(50) ].flatten.first.to_f
    rescue Vips::Error
      255.0
    end

    # Colour carries no signal for text recognition and triples the work.
    def to_greyscale(image)
      image.bands > 1 ? image.colourspace("b-w") : image
    end

    def upscale(image)
      scale = (@target_height.to_f / image.height).clamp(1.0, MAX_SCALE)
      return image if scale <= 1.0

      # Lanczos preserves glyph edges far better than bilinear when enlarging, and
      # blurred edges are exactly what turns "Fulton" into "Fultcn".
      image.resize(scale, kernel: :lanczos3)
    end

    # Stretches the histogram so faint text on an unevenly lit card separates from the
    # background. Applied after upscaling so it operates on recovered detail.
    #
    # Deliberately NOT a hard binary threshold: glare blows out a region entirely, and
    # a global threshold turns that region into solid white, destroying the characters
    # underneath rather than dimming them.
    # Local equalisation looks like the right tool for unevenly lit photographs, and
    # measured markedly WORSE than global on this set (22% against 47%): equalising a
    # small window around flat card stock amplifies JPEG noise into texture that
    # Tesseract reads as character strokes. Kept as an option because the tradeoff
    # would flip on genuinely large images, but global is the default on the evidence.
    def normalize_contrast(image)
      case @contrast
      when "none" then image
      when "local" then image.hist_local(LOCAL_CONTRAST_WINDOW, LOCAL_CONTRAST_WINDOW)
      else image.hist_equal
      end
    rescue Vips::Error
      # Undefined for a uniform image (a blank or fully blown-out scan). That is a
      # legitimate input — the flow handles it by offering manual entry — so degrade
      # rather than fail the whole extraction.
      image
    end

    def sharpen(image)
      image.sharpen(sigma: 1.0, x1: 2, m2: 20)
    end
  end
end
