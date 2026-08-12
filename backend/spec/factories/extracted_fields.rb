FactoryBot.define do
  factory :extracted_field do
    document { nil }
    name { "MyString" }
    value { "MyString" }
    confidence { "9.99" }
  end
end
