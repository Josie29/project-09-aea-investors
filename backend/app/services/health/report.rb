module Health
  # Aggregates reachability of the application and each external dependency.
  #
  # Deliberately cheap: an uptime monitor polls this roughly every minute across the
  # whole review window, so no check may do real work, touch user data, or make a
  # billable call. Dependencies that have not been built yet report NOT_CONFIGURED
  # rather than being omitted, so the shape of the response never changes.
  class Report
    OK = "ok".freeze
    UNAVAILABLE = "unavailable".freeze
    NOT_CONFIGURED = "not_configured".freeze

    # A dependency listed here failing makes the whole report unhealthy. OCR and the
    # LLM are excluded on purpose: the onboarding flow degrades gracefully without
    # either (manual entry, short form), so neither should take the API down or trip
    # an uptime alert.
    CRITICAL_CHECKS = %i[database].freeze

    def self.call
      new.call
    end

    # Builds the full health report.
    #
    # @return [Hash] status, per-dependency checks, and an ISO8601 timestamp
    def call
      checks = {
        app: { status: OK },
        database: database_check,
        ocr: { status: NOT_CONFIGURED },  # wired up by the OCR extraction issue
        llm: { status: NOT_CONFIGURED }   # wired up by the Groq adapter issue
      }

      { status: overall_status(checks), checks: checks, checked_at: Time.current.iso8601 }
    end

    private

    # Round-trips a trivial query so the check exercises a real connection rather
    # than just reading pool state.
    #
    # @return [Hash] status, plus latency on success or an exception class on failure
    def database_check
      started_at = monotonic_now
      ActiveRecord::Base.connection.select_value("SELECT 1")
      { status: OK, latency_ms: elapsed_ms_since(started_at) }
    rescue StandardError => e
      # Only the exception CLASS is reported. Adapter messages routinely embed the
      # full connection string, and this endpoint is unauthenticated — including the
      # message would publish database credentials to anyone who curls it.
      { status: UNAVAILABLE, error: e.class.name }
    end

    def overall_status(checks)
      CRITICAL_CHECKS.all? { |name| checks[name][:status] == OK } ? OK : UNAVAILABLE
    end

    def monotonic_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def elapsed_ms_since(started_at)
      ((monotonic_now - started_at) * 1_000).round(1)
    end
  end
end
