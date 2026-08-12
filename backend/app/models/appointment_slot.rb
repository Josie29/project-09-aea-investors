class AppointmentSlot < ApplicationRecord
  has_one :booking, dependent: :restrict_with_error

  validates :starts_at, presence: true
  validates :clinician_name, presence: true
  validates :duration_minutes, numericality: { greater_than: 0 }
  validates :modality, inclusion: { in: %w[video in_person] }

  # Slots with no booking yet. Uses a LEFT JOIN rather than `where.not(id: taken)`
  # so it stays one query as the table grows.
  scope :open, -> { where.missing(:booking) }
  scope :upcoming, -> { where(starts_at: Time.current..) }
  scope :chronological, -> { order(:starts_at) }

  # What the booking screen offers: open, in the future, soonest first.
  scope :bookable, -> { open.upcoming.chronological }

  def taken?
    booking.present?
  end
end
