require "net/http"
require "json"

module Llm
  # Talks to Groq's OpenAI-compatible chat completions API.
  #
  # Deliberately thin and provider-shaped rather than Groq-shaped: the tech-stack doc
  # keeps Gemini as a failover, and both speak this same request format. Swapping is a
  # base URL and a model name, not a rewrite.
  #
  # No SDK. The surface we use is one POST with a JSON body, and a gem would add a
  # dependency that needs tracking for the sake of code we would still have to
  # configure timeouts and error handling on.
  class Client
    class Error < StandardError; end
    class Timeout < Error; end
    class Unavailable < Error; end

    DEFAULT_BASE_URL = "https://api.groq.com/openai/v1".freeze
    DEFAULT_MODEL = "llama-3.3-70b-versatile".freeze

    # The brief's guardrail is < 3 s p95 for the whole request, and the API round trip
    # measures ~0.4 s. Six seconds is generous enough to absorb a slow response while
    # still failing well inside a user's patience — the chatbot degrades to a short
    # form rather than making someone watch a spinner.
    OPEN_TIMEOUT = 3
    READ_TIMEOUT = 6

    # One retry, on connection-level failures only. A 400 means our request was wrong
    # and will be wrong again; a 429 means backing off is the polite response but the
    # user is waiting, so we fail over to the manual path instead of queueing.
    MAX_ATTEMPTS = 2

    def initialize(
      api_key: ENV.fetch("GROQ_API_KEY", nil),
      model: ENV.fetch("GROQ_MODEL", DEFAULT_MODEL),
      base_url: ENV.fetch("GROQ_BASE_URL", DEFAULT_BASE_URL)
    )
      @api_key = api_key
      @model = model
      @base_url = base_url
    end

    # @return [Boolean] whether a key is configured at all
    def configured?
      @api_key.present?
    end

    # Sends a chat completion request.
    #
    # @param messages [Array<Hash>] role/content pairs
    # @param json [Boolean] request a JSON object response
    # @param max_tokens [Integer]
    # @return [String] the assistant's message content
    # @raise [Unavailable] when no key is configured, or the provider errors
    # @raise [Timeout] when the provider does not answer in time
    def complete(messages:, json: false, max_tokens: 600, temperature: 0.3)
      raise Unavailable, "no LLM api key configured" unless configured?

      body = {
        model: @model,
        messages: messages,
        max_tokens: max_tokens,
        temperature: temperature
      }
      body[:response_format] = { type: "json_object" } if json

      parse(post(body))
    end

    private

    def post(body)
      attempts = 0

      begin
        attempts += 1
        perform_request(body)
      rescue Timeout
        raise
      rescue Unavailable => e
        # Retry only transport failures. A refusal from the provider is deterministic
        # and repeating it just spends the user's patience twice.
        raise e unless e.message.include?("connection") && attempts < MAX_ATTEMPTS

        retry
      end
    end

    def perform_request(body)
      uri = URI.parse("#{@base_url}/chat/completions")
      http = ::Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      request = ::Net::HTTP::Post.new(uri.path)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(body)

      response = http.request(request)
      # Status only. The request body carries the user's own words about their mental
      # health, and an error path that echoes it into a log or an exception message is
      # the easiest way to leak the most sensitive content in the system.
      raise Unavailable, "llm provider returned #{response.code}" unless response.is_a?(::Net::HTTPSuccess)

      response.body
    rescue ::Net::OpenTimeout, ::Net::ReadTimeout
      raise Timeout, "llm provider timed out"
    rescue SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET, EOFError, OpenSSL::SSL::SSLError => e
      raise Unavailable, "llm provider connection failed (#{e.class})"
    end

    def parse(raw)
      payload = JSON.parse(raw)
      content = payload.dig("choices", 0, "message", "content")
      raise Unavailable, "llm provider returned no content" if content.blank?

      content
    rescue JSON::ParserError
      raise Unavailable, "llm provider returned unparseable json"
    end
  end
end
