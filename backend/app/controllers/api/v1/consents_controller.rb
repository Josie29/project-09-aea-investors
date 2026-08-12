module Api
  module V1
    # Consent for processing the user's intake data.
    class ConsentsController < ApplicationController
      def show
        consent = Consent.find_by(onboarding_session: current_session)
        return render json: { granted: false }, status: :ok if consent.nil?

        render json: serialize(consent)
      end

      def create
        render json: serialize(Consent.grant!(current_session)), status: :created
      end

      # Withdrawal always succeeds from the user's point of view, including when no
      # consent was on file. Returning an error for "you never consented" would be
      # pedantic at the exact moment someone is trying to stop processing.
      def destroy
        consent = Consent.find_by(onboarding_session: current_session)
        consent&.withdraw!

        # Purging the data this covered is tracked separately. Withdrawal is recorded
        # first and unconditionally: if deletion later fails, the log must still show
        # that permission was revoked when it was.
        Rails.logger.info("consent withdrawn for session #{current_session.id}")

        render json: consent ? serialize(consent) : { granted: false }
      end

      private

      def current_session
        @current_session ||= OnboardingSession.for(current_user)
      end

      def serialize(consent)
        {
          granted: consent.active?,
          granted_at: consent.granted_at.iso8601,
          withdrawn_at: consent.withdrawn_at&.iso8601,
          policy_version: consent.policy_version
        }
      end
    end
  end
end
