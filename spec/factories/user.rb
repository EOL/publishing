FactoryGirl.define do
  factory :user do
    sequence(:username) { |n| "username_#{n}" }
    sequence(:email) { |n| "email_#{n}@example.com" }
    password "password"
    admin false
  end

  factory :admin_user, class: User do
    sequence(:username) { |n| "username_#{n}" }
    sequence(:email) {|n| "email_#{n}@example.com" }
    password "password"
    active 1
    confirmed_at Time.now
    admin true
  end
end
