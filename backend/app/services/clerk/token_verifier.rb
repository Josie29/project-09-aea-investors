# Required explicitly: Rails does not load net/http for you, and without this the
# JWKS fetch raises NameError at runtime. The test suite will NOT catch a missing
# require here, because stubbing Net::HTTP in a spec loads the constant as a side
# effect — this bug only appears against a real server.
require "net/http"

module Clerk
  # Verifies a Clerk-issued session JWT against Clerk's published JWKS.
  #
  # We verify the token ourselves with the `jwt` gem rather than depending on
  # `clerk-sdk-ruby`. That SDK's own README warns of breaking changes without major
  # version bumps and it shipped four majors in six months; we need exactly one
  # behaviour from it, and owning ~60 lines is cheaper than tracking that churn.
  class TokenVerifier
    class InvalidToken < StandardError; end

    JWKS_CACHE_KEY = "clerk:jwks".freeze
    JWKS_TTL = 1.hour

    # Clerk allows ~5s of clock skew on their side; container clocks drift. Without
    # leeway you get sporadic ExpiredSignature errors that never reproduce locally
    # and only surface under load.
    CLOCK_LEEWAY_SECONDS = 30

    # Clerk session tokens carry no `aud` claim. Enabling audience verification is a
    # known footgun that also breaks Clerk's own Next.js helpers.
    REQUIRED_CLAIMS = %w[exp iat nbf sub iss].freeze

    def self.call(token)
      new.call(token)
    end

    # @param token [String] the raw Bearer token
    # @return [Hash] verified claims
    # @raise [InvalidToken] if the token is absent, malformed, expired, or not ours
    def call(token)
      raise InvalidToken, "missing bearer token" if token.blank?

      payload, _header = JWT.decode(
        token, nil, true,
        algorithms: [ "RS256" ],
        jwks: jwks_loader,
        iss: issuer,
        verify_iss: true,
        verify_aud: false,
        exp_leeway: CLOCK_LEEWAY_SECONDS,
        nbf_leeway: CLOCK_LEEWAY_SECONDS,
        required_claims: REQUIRED_CLAIMS
      )

      verify_authorized_party!(payload)
      payload
    rescue JWT::ExpiredSignature
      raise InvalidToken, "token expired"
    rescue JWT::DecodeError, JWT::VerificationError => e
      raise InvalidToken, e.message
    end

    private

    # `azp` is derived from the Origin of the request that minted the token, so it
    # pins a token to the front end that requested it.
    #
    # Tokens minted server-side (a Next.js Server Component calling `getToken()`)
    # have no Origin and may carry no `azp` at all. We therefore enforce the
    # allowlist only when the claim is present: an `azp` naming a foreign origin is
    # rejected, while an absent one falls back to the signature, issuer, and 60s
    # expiry for its security. Clerk's docs do not specify server-side behaviour, so
    # this is deliberately the permissive-but-explicit reading rather than an
    # accident.
    def verify_authorized_party!(payload)
      azp = payload["azp"]
      return if azp.blank?
      return if authorized_parties.include?(azp)

      raise InvalidToken, "unauthorized party"
    end

    # The `jwt` gem calls this with {kid:, kid_not_found:}. Busting the cache on an
    # unknown kid lets a Clerk key rotation self-heal on the next request; without
    # it, a rotation causes an outage lasting up to the full cache TTL.
    def jwks_loader
      lambda do |options|
        Rails.cache.delete(JWKS_CACHE_KEY) if options[:kid_not_found]

        raw = Rails.cache.fetch(JWKS_CACHE_KEY, expires_in: JWKS_TTL) { fetch_jwks }

        # Keep signing keys only. Assigned and returned separately because `select!`
        # follows Array semantics and returns nil when it removes nothing — chaining
        # off it yields an empty key set and every token fails to verify.
        keys = JWT::JWK::Set.new(JSON.parse(raw))
        keys.select! { |key| key[:use].nil? || key[:use] == "sig" }
        keys
      end
    end

    # Fetched over the network, so it must stay cached — an uncached JWKS puts an
    # outbound HTTPS round trip on every authenticated request, which alone would
    # threaten the <3s p95 target.
    def fetch_jwks
      # Fully qualified: a bare `Net` resolves against the Clerk module first.
      response = ::Net::HTTP.get_response(URI.parse("#{issuer}/.well-known/jwks.json"))
      response.value # raises unless 2xx
      response.body
    end

    def issuer
      @issuer ||= ENV.fetch("CLERK_ISSUER")
    end

    def authorized_parties
      @authorized_parties ||= ENV.fetch("CLERK_AUTHORIZED_PARTIES", "").split(",").map(&:strip)
    end
  end
end
