FactoryBot.define do
  factory :assessment do
    onboarding_session { nil }
    presenting_concern { "MyString" }
    frequency { "MyString" }
    referral { "MyString" }
    prior_care { "MyString" }
    modality { "MyString" }
    urgency { "MyString" }
    acknowledged_at { "2026-08-12 12:29:01" }
  end
end
