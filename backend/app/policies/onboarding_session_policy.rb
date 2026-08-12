# Who may see and change an onboarding session.
#
# The brief is explicit: a user can only access their own onboarding record. That
# record accumulates identity fields read off a government ID and a clinical intake
# summary, so a leak here is the worst outcome the product has.
#
# Staff access is deliberately absent rather than stubbed permissively — it is a
# separate issue with its own audit-logging requirement, and a placeholder that
# returned true for some future role would be a hole waiting to be forgotten.
class OnboardingSessionPolicy < ApplicationPolicy
  def show?
    owner?
  end

  def update?
    owner?
  end

  private

  # Compared by id rather than object identity: `record.user == user` would quietly
  # return false for two AR instances loaded separately in the same request.
  def owner?
    user.present? && record.present? && record.user_id == user.id
  end
end
