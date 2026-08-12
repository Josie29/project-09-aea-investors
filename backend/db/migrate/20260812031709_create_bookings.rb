class CreateBookings < ActiveRecord::Migration[8.1]
  def change
    create_table :bookings do |t|
      t.references :onboarding_session, null: false, foreign_key: true, index: { unique: true }

      # THE double-booking guard, declared on the reference itself because
      # `t.references` already builds an index and a second one on the same column
      # collides. Application-level checks lose this race: two requests can both read
      # "slot is free" before either writes. Only the database makes the check and the
      # write atomic, so the constraint lives here and the model rescues the violation
      # rather than trying to prevent it in Ruby.
      t.references :appointment_slot, null: false, foreign_key: true, index: { unique: true }

      t.timestamps
    end
  end
end
