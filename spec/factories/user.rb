FactoryGirl.define do
  factory :user do
    sequence(:username) { |n| "username_#{n}" }
    sequence(:email) { |n| "email_#{n}@example.com" }
    password "password"
    password_confirmation "password"
    role :user
  end

  factory :admin_user, class: User do
    sequence(:username) { |n| "username_#{n}" }
    sequence(:email) {|n| "email_#{n}@example.com" }
    password "password"
    password_confirmation "password"
    active 1
    confirmed_at Time.now
    role :admin
  end
end
