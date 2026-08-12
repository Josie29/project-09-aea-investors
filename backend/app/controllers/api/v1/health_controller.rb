module Api
  module V1
    # Unauthenticated liveness/readiness probe for load balancers and the uptime monitor.
    #
    # Inherits ActionController::API rather than ApplicationController on purpose: once
    # Clerk authentication becomes a before_action on the application base controller,
    # inheriting it would silently start returning 401 to the uptime probe and read as
    # an outage. Keeping this controller off that inheritance chain makes the exemption
    # structural instead of a skip_before_action someone can delete.
    class HealthController < ActionController::API
      def show
        report = Health::Report.call
        healthy = report[:status] == Health::Report::OK

        render json: report, status: healthy ? :ok : :service_unavailable
      end
    end
  end
end
