FactoryGirl.define do
  factory :bibliographic_citation do
    sequence(:body) { |n| "Body of #{n}" }
  end
  
end