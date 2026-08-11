class User < ApplicationRecord
  validates :clerk_id, presence: true, uniqueness: true

  # Finds or creates the local record for an authenticated Clerk user.
  #
  # The onboarding wizard fires several requests as soon as it mounts, so two of
  # them can reach this at once on a user's very first visit. The unique index
  # makes the loser of that race raise instead of inserting a duplicate; retrying
  # the lookup resolves it. Without this, a first-time user sees a random 500.
  #
  # @param claims [Hash] verified Clerk JWT claims
  # @return [User]
  # @raise [KeyError] if the token carried no `sub` claim
  def self.from_clerk_claims!(claims)
    clerk_id = claims.fetch("sub")

    find_or_create_by!(clerk_id: clerk_id)
  rescue ActiveRecord::RecordNotUnique
    find_by!(clerk_id: clerk_id)
  end
end
