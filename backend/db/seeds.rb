# Seed data, loaded with `bin/rails db:seed`.
#
# Every seed file must be idempotent: this runs on each deploy, and a seed that
# duplicates rows on a second run turns a routine deploy into a data cleanup.
#
# Split into db/seeds/ rather than kept in one file — the OCR golden set alone would
# outgrow a single script, and a seed failure should name the thing that failed.

Rails.logger.debug "Seeding..."

Dir[Rails.root.join("db/seeds/*.rb")].sort.each { |file| require file }

Seeds::AppointmentSlots.call

Rails.logger.debug "Done."
