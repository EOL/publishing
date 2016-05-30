FactoryGirl.define do
  factory :user do
    sequence(:display_name) { |n| "username_#{n}" }
    sequence(:email) {|n| "email_#{n}@example.com" }
    password "password"
  end
end  