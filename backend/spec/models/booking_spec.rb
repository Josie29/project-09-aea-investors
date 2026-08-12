require "rails_helper"

RSpec.describe Booking do
  let(:session) { OnboardingSession.for(create(:user)) }
  let(:other_session) { OnboardingSession.for(create(:user)) }
  let(:slot) do
    AppointmentSlot.create!(starts_at: 2.days.from_now, clinician_name: "Dr. Osei", modality: "video")
  end

  describe ".claim!" do
    it "books an open slot" do
      expect(described_class.claim!(session: session, slot: slot).appointment_slot).to eq(slot)
    end

    it "refuses a slot in the past" do
      past = AppointmentSlot.create!(starts_at: 1.minute.ago, clinician_name: "Dr. Past", modality: "video")

      expect { described_class.claim!(session: session, slot: past) }
        .to raise_error(described_class::SlotUnavailable, /already passed/)
    end

    # The validation is a courtesy that produces a readable message most of the time.
    # This is the case that matters: two requests both pass validation before either
    # commits, and only the unique index stops the second write. Simulated by writing
    # the competing row after validation has already run.
    it "loses gracefully when another request commits first" do
      allow(described_class).to receive(:create!).and_wrap_original do |original, **args|
        described_class.new(onboarding_session: other_session, appointment_slot: slot).save!(validate: false)
        original.call(**args)
      end

      expect { described_class.claim!(session: session, slot: slot) }
        .to raise_error(described_class::SlotUnavailable)
    end

    it "tells a user who already booked that nothing is wrong" do
      described_class.claim!(session: session, slot: slot)
      another = AppointmentSlot.create!(starts_at: 5.days.from_now, clinician_name: "Dr. Two", modality: "video")

      expect { described_class.claim!(session: session, slot: another) }
        .to raise_error(described_class::SlotUnavailable, /already have an appointment/)
    end
  end

  # Belt and braces: prove the constraint exists at the database level, not only in
  # the model. If someone drops the index during a refactor, this fails.
  it "refuses a duplicate slot even when validations are bypassed" do
    described_class.claim!(session: session, slot: slot)
    duplicate = described_class.new(onboarding_session: other_session, appointment_slot: slot)

    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
