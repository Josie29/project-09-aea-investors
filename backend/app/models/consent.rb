class Consent < ApplicationRecord
  # Bumped whenever the privacy notice changes materially. Consent recorded against
  # an older version is still a real record of what the user agreed to at the time,
  # which is the point of storing it.
  CURRENT_POLICY_VERSION = "2026-08-1".freeze

  belongs_to :onboarding_session

  validates :granted_at, presence: true
  validates :policy_version, presence: true
  validates :onboarding_session_id, uniqueness: true

  scope :active, -> { where(withdrawn_at: nil) }

  # Records consent for a session, or reinstates it if previously withdrawn.
  #
  # A user who withdraws and then changes their mind should be able to continue
  # rather than being permanently locked out of a service they came to use. The new
  # grant timestamp replaces the old, so the record always reflects the consent
  # currently in force.
  #
  # @param session [OnboardingSession]
  # @return [Consent]
  def self.grant!(session)
    consent = find_or_initialize_by(onboarding_session: session)
    consent.update!(
      granted_at: Time.current,
      withdrawn_at: nil,
      policy_version: CURRENT_POLICY_VERSION
    )
    consent
  end

  # Marks consent withdrawn. Purging the data it covered is a separate step, tracked
  # by its own issue — withdrawal must be recorded even if deletion later fails, or
  # the log would claim processing stopped when it had not.
  def withdraw!
    update!(withdrawn_at: Time.current)
  end

  def active?
    withdrawn_at.nil?
  end
end
