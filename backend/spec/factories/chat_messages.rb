FactoryBot.define do
  factory :chat_message do
    onboarding_session { nil }
    role { "MyString" }
    content { "MyText" }
    intent { "MyString" }
  end
end
