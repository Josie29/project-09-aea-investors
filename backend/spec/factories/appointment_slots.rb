FactoryBot.define do
  factory :appointment_slot do
    starts_at { "2026-08-11 22:17:08" }
    duration_minutes { 1 }
    clinician_name { "MyString" }
    modality { "MyString" }
  end
end
