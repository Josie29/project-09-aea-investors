require "net/http"

# Mints real RS256 tokens against a locally generated keypair and stubs Clerk's JWKS
# endpoint to publish the matching public key.
#
# The point is to exercise the actual signature, issuer, expiry, and azp verification
# rather than stubbing TokenVerifier out — a stubbed verifier would pass even if the
# real one accepted unsigned tokens.
module ClerkTokenHelper
  ISSUER = "https://test-instance.clerk.accounts.dev".freeze
  AUTHORIZED_PARTY = "http://localhost:3000".freeze
  KID = "test-key-id".freeze

  class << self
    def signing_key
      @signing_key ||= OpenSSL::PKey::RSA.generate(2048)
    end

    # A key Clerk never published — used to prove a well-formed token signed by
    # someone else is rejected.
    def foreign_key
      @foreign_key ||= OpenSSL::PKey::RSA.generate(2048)
    end

    def jwks_json
      export = JWT::JWK.new(signing_key, kid: KID).export
      { keys: [ export.merge(use: "sig", alg: "RS256") ] }.to_json
    end
  end

  # @param claims [Hash] overrides merged over a valid default payload
  # @param key [OpenSSL::PKey::RSA] signing key, defaults to the published one
  # @return [String] an encoded JWT
  def clerk_token(claims = {}, key: ClerkTokenHelper.signing_key)
    now = Time.current.to_i
    payload = {
      "iss" => ClerkTokenHelper::ISSUER,
      "sub" => "user_2abcdef",
      "azp" => ClerkTokenHelper::AUTHORIZED_PARTY,
      "iat" => now,
      "nbf" => now - 5,
      "exp" => now + 60
    }.merge(claims.transform_keys(&:to_s))

    JWT.encode(payload, key, "RS256", kid: ClerkTokenHelper::KID)
  end

  def auth_headers(token = clerk_token)
    { "Authorization" => "Bearer #{token}" }
  end

  # Fully qualified: inside this module, a bare `Net` would resolve against
  # ClerkTokenHelper first and fail.
  def stub_clerk_jwks(body = ClerkTokenHelper.jwks_json)
    response = instance_double(::Net::HTTPOK, body: body, value: nil)
    allow(::Net::HTTP).to receive(:get_response).and_return(response)
  end
end

RSpec.configure do |config|
  config.include ClerkTokenHelper

  config.before do
    ENV["CLERK_ISSUER"] = ClerkTokenHelper::ISSUER
    ENV["CLERK_AUTHORIZED_PARTIES"] = ClerkTokenHelper::AUTHORIZED_PARTY
  end
end
