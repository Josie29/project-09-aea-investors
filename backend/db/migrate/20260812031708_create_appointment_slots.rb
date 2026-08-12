class CreateAppointmentSlots < ActiveRecord::Migration[8.1]
  def change
    create_table :appointment_slots do |t|
      t.datetime :starts_at, null: false
      t.integer :duration_minutes, null: false, default: 50
      t.string :clinician_name, null: false
      t.string :modality, null: false, default: "video"

      t.timestamps
    end

    add_index :appointment_slots, :starts_at

    # A clinician cannot be in two places at once. This is separate from the
    # one-booking-per-slot rule: that stops two patients taking the same slot, this
    # stops the seed data or an admin creating overlapping slots in the first place.
    add_index :appointment_slots, %i[clinician_name starts_at], unique: true
  end
end
