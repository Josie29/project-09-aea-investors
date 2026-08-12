FactoryBot.define do
  factory :user do
    sequence(:clerk_id) { |n| "user_2test#{n}" }
  end
end
