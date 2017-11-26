FactoryGirl.define do
  factory :location do
    sequence(:location) { |n| "location of #{n}" }
    sequence(:longitude) { |n| n+0.1 }
    sequence(:latitude) { |n| n+0.2 }
    sequence(:altitude) { |n| n+0.3 }
    
  end
end