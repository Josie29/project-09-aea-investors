module Api
  module V1
    # Returns the authenticated user's own record. Exists primarily to prove the
    # Clerk -> Rails round trip end to end; the onboarding session endpoints in the
    # next issue build on the same authentication and authorization pattern.
    class MeController < ApplicationController
      def show
        # Fields are listed explicitly rather than serialising the model, so a column
        # added later is omitted by default instead of leaked by accident.
        render json: {
          id: current_user.id,
          clerk_id: current_user.clerk_id,
          created_at: current_user.created_at.iso8601
        }
      end
    end
  end
end
