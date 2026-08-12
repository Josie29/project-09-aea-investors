class Document < ApplicationRecord
  # Lifecycle of the uploaded image. `purged` is terminal and is the state the flow is
  # designed to end in — the image exists only long enough to be read and confirmed.
  STATUSES = %w[pending processing extracted failed purged].freeze

  belongs_to :onboarding_session
  has_one_attached :image

  validates :status, inclusion: { in: STATUSES }
  validates :onboarding_session_id, uniqueness: true

  # Replaces any previous upload for this session.
  #
  # Re-uploading is common: the first photo is blurry, or OCR failed and the user
  # tries again in better light. Each attempt destroys the previous image rather than
  # accumulating copies of someone's ID in the bucket.
  #
  # @param session [OnboardingSession]
  # @param upload [ActionDispatch::Http::UploadedFile]
  # @return [Document]
  def self.replace_for!(session, upload)
    document = find_or_initialize_by(onboarding_session: session)
    document.image.purge if document.persisted? && document.image.attached?

    document.image.attach(upload)
    document.update!(status: "pending", image_purged_at: nil)
    document
  end

  # Destroys the source image, keeping the record as evidence it existed and was
  # removed.
  #
  # Called after the user confirms the extracted fields, and again on a deletion
  # request. Idempotent, because both paths can reach it and a second call must not
  # fail — "already deleted" is the desired end state, not an error.
  def purge_image!
    image.purge if image.attached?
    update!(status: "purged", image_purged_at: image_purged_at || Time.current)
  end

  def image_available?
    image.attached?
  end
end
