module Api
  module V1
    # The user's onboarding session.
    #
    # Two shapes are exposed on purpose:
    #
    # - The singular routes (`/onboarding_session`) always operate on the authenticated
    #   user's own record. There is no id in the URL, so reaching someone else's is not
    #   merely forbidden, it is unexpressible. This is what the wizard uses.
    # - The id-addressed route (`/onboarding_sessions/:id`) goes through the policy
    #   layer. It exists so ownership is enforced explicitly rather than only as an
    #   emergent property of URL design, and it is the seam that role-scoped staff
    #   access will hook into.
    class OnboardingSessionsController < ApplicationController
      # GET /api/v1/onboarding_session
      def show_current
        render json: serialize(current_session)
      end

      # PATCH /api/v1/onboarding_session
      #
      # The caller states the state it expects to move to, so a double-submitted
      # request fails loudly instead of silently advancing two steps.
      def update_current
        session = current_session.advance_to!(params.require(:state))
        render json: serialize(session)
      rescue Onboarding::StateMachine::InvalidTransition => e
        render json: { error: "invalid_transition", detail: e.message }, status: :unprocessable_content
      end

      # GET /api/v1/onboarding_sessions/:id
      def show
        session = OnboardingSession.find_by(id: params[:id])
        return not_found unless session && policy(session).show?

        render json: serialize(session)
      end

      private

      def current_session
        @current_session ||= OnboardingSession.for(current_user)
      end

      def policy(session)
        OnboardingSessionPolicy.new(current_user, session)
      end

      def serialize(session)
        OnboardingSessionSerializer.new(session).as_json
      end

      # 404 rather than 403 for a record that exists but is not yours. A 403 confirms
      # the id is real, which tells an attacker enumerating ids exactly which ones
      # belong to somebody.
      def not_found
        render json: { error: "not_found" }, status: :not_found
      end
    end
  end
end
