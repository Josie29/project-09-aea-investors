class Booking < ApplicationRecord
  # Raised when the slot was taken between the user seeing it and choosing it.
  class SlotUnavailable < StandardError; end

  belongs_to :onboarding_session
  belongs_to :appointment_slot

  validates :appointment_slot_id, uniqueness: true
  validates :onboarding_session_id, uniqueness: true

  delegate :user, to: :onboarding_session

  # Books a slot for a session.
  #
  # The uniqueness validation above is a courtesy that produces a readable error most
  # of the time; it does NOT prevent double-booking. Two concurrent requests can both
  # pass validation before either commits — the window is small and the failure is
  # silent, which is the worst combination. The unique index is what actually holds,
  # and rescuing its violation is how a loser of that race learns it lost.
  #
  # @param session [OnboardingSession]
  # @param slot [AppointmentSlot]
  # @return [Booking]
  # @raise [SlotUnavailable] if the slot was taken first, or is in the past
  def self.claim!(session:, slot:)
    raise SlotUnavailable, "that time has already passed" if slot.starts_at <= Time.current

    create!(onboarding_session: session, appointment_slot: slot)
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    # Distinguish "someone else took it" from "you already booked", because the two
    # need different words in the UI: one is bad news, the other is reassurance.
    raise SlotUnavailable, existing_for(session) ? "you already have an appointment" : "that slot has just been taken"
  end

  def self.existing_for(session)
    find_by(onboarding_session: session)
  end
end
