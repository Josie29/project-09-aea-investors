# Shapes a confirmed booking for the confirmation screen.
class BookingSerializer
  def initialize(booking)
    @booking = booking
  end

  def as_json
    slot = @booking.appointment_slot

    {
      id: @booking.id,
      starts_at: slot.starts_at.iso8601,
      duration_minutes: slot.duration_minutes,
      clinician_name: slot.clinician_name,
      modality: slot.modality,
      booked_at: @booking.created_at.iso8601
    }
  end
end
