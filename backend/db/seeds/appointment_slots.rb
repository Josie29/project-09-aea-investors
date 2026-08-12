# Clinic availability for the next fortnight.
#
# Idempotent, and generated relative to today rather than at fixed dates: seeds
# committed with hardcoded timestamps are all in the past by the time anyone runs
# them, and a booking screen with no bookable slots looks broken rather than empty.
module Seeds
  module AppointmentSlots
    CLINICIANS = [
      { name: "Dr. Amara Osei, LCSW", modality: "video" },
      { name: "Dr. Idris Bello, PsyD", modality: "video" },
      { name: "Dr. Wren Halloway, LCSW", modality: "in_person" }
    ].freeze

    # Weekday times only. A clinic that offers 2am appointments reads as test data.
    TIMES = [ [ 9, 0 ], [ 11, 30 ], [ 14, 0 ], [ 16, 15 ], [ 17, 30 ] ].freeze

    DAYS_AHEAD = 14

    def self.call
      created = 0

      (1..DAYS_AHEAD).each do |offset|
        date = Date.current + offset
        next if date.saturday? || date.sunday?

        CLINICIANS.each_with_index do |clinician, index|
          # Staggered so the three clinicians do not offer identical times, which
          # would make the booking grid look duplicated.
          TIMES.rotate(index).first(3).each do |hour, minute|
            starts_at = Time.zone.local(date.year, date.month, date.day, hour, minute)

            slot = AppointmentSlot.find_or_initialize_by(
              clinician_name: clinician[:name], starts_at: starts_at
            )
            next if slot.persisted?

            slot.update!(duration_minutes: 50, modality: clinician[:modality])
            created += 1
          end
        end
      end

      puts "  appointment slots: #{created} created, #{AppointmentSlot.count} total"
    end
  end
end
