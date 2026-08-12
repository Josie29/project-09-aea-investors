FactoryBot.define do
  factory :consent do
    onboarding_session { nil }
    granted_at { "2026-08-12 11:26:54" }
    withdrawn_at { "2026-08-12 11:26:54" }
    policy_version { "MyString" }
  end
end
