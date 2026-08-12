# Base class for every authenticated API controller.
#
# Authentication is opt-OUT rather than opt-in: inheriting from here means a
# controller requires a valid Clerk token unless it deliberately says otherwise.
# A new endpoint that forgets to think about auth therefore fails closed.
# Api::V1::HealthController stays off this chain entirely because it must remain
# publicly pollable.
class ApplicationController < ActionController::API
  include ClerkAuthentication
end
