module Api
  module V1
    # The user's appointment booking.
    #
    # Singular, like the onboarding session: a user has at most one, and there is no
    # id in the URL, so another user's booking cannot be named.
    class BookingsController < ApplicationController
      def show
        booking = Booking.existing_for(current_session)
        return render json: { error: "not_found" }, status: :not_found if booking.nil?

        render json: BookingSerializer.new(booking).as_json
      end

      def create
        slot = AppointmentSlot.find_by(id: params.require(:appointment_slot_id))
        return render json: { error: "not_found" }, status: :not_found if slot.nil?

        booking = Booking.claim!(session: current_session, slot: slot)
        render json: BookingSerializer.new(booking).as_json, status: :created
      rescue Booking::SlotUnavailable => e
        # 409 rather than 422: the request was well-formed and would have succeeded a
        # moment earlier. The client redraws the grid so the slot shows as taken
        # instead of leaving the user pressing a button that will never work.
        render json: { error: "slot_unavailable", detail: e.message }, status: :conflict
      end

      private

      def current_session
        @current_session ||= OnboardingSession.for(current_user)
      end
    end
  end
end
