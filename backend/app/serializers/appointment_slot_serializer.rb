# Shapes an AppointmentSlot for the booking screen.
#
# Includes `taken` rather than filtering taken slots out of the response entirely: the
# design shows a claimed slot struck through with "Just taken", so a user who was
# looking at it sees why it disappeared instead of watching the grid silently reflow.
class AppointmentSlotSerializer
  def initialize(slot)
    @slot = slot
  end

  def as_json
    {
      id: @slot.id,
      starts_at: @slot.starts_at.iso8601,
      duration_minutes: @slot.duration_minutes,
      clinician_name: @slot.clinician_name,
      modality: @slot.modality,
      taken: @slot.taken?
    }
  end
end
