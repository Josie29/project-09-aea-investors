module ClerkAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!

    attr_reader :current_user, :clerk_claims
  end

  private

  def authenticate_user!
    @clerk_claims = Clerk::TokenVerifier.call(bearer_token)
    @current_user = User.from_clerk_claims!(@clerk_claims)
  rescue Clerk::TokenVerifier::InvalidToken => e
    # The reason is safe to return: it describes the token, never the user. It is
    # also logged without the token itself, which is a bearer credential.
    Rails.logger.info("clerk auth rejected: #{e.message}")
    render json: { error: "unauthorized" }, status: :unauthorized
  end

  def bearer_token
    request.authorization.to_s[/\ABearer (.+)\z/, 1]
  end
end
