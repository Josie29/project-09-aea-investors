module Api
  module V1
    # Open appointment slots.
    #
    # Authenticated, though the slots themselves are not personal data: onboarding is
    # behind sign-in throughout, and leaving one endpoint open would make the
    # clinic's calendar and staffing levels scrapeable by anyone.
    class AppointmentSlotsController < ApplicationController
      # Bounded so a client cannot ask for the entire calendar. The booking screen
      # shows four days; this leaves room without being unbounded.
      DEFAULT_LIMIT = 40

      def index
        slots = AppointmentSlot.upcoming.chronological.includes(:booking).limit(DEFAULT_LIMIT)

        render json: { slots: slots.map { |slot| AppointmentSlotSerializer.new(slot).as_json } }
      end
    end
  end
end
