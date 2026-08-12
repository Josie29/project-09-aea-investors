# Refuses to process document data without active consent.
#
# The brief is unambiguous: explicit, logged consent is required BEFORE any document
# image is uploaded or processed. This concern is how that becomes structural rather
# than a checkbox the frontend is trusted to have shown — a client that skips the
# consent screen, or replays an upload after withdrawal, is refused by the server.
#
# Applied per controller rather than globally: most endpoints legitimately work
# without consent (reading your session, browsing slots), and a global gate would
# either block those or be so riddled with exemptions that the exemptions become the
# rule.
module ConsentGate
  extend ActiveSupport::Concern

  private

  def require_active_consent!
    return if consent_on_file&.active?

    render json: {
      error: "consent_required",
      detail: "Consent must be given before a document can be uploaded or processed."
    }, status: :forbidden
  end

  def consent_on_file
    @consent_on_file ||= Consent.find_by(onboarding_session: current_session)
  end
end
