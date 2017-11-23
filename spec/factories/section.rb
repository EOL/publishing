FactoryGirl.define do
  factory :section do
    sequence(:name) {|n| "section#{n}"} 
  end
end