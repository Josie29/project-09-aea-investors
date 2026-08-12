FactoryBot.define do
  factory :onboarding_session do
    user
    state { Onboarding::StateMachine::INITIAL }
  end
end
