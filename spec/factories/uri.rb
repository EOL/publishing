FactoryGirl.define do
  factory :uri do
    sequence(:uri) { |n| "http://uri.for/term#{n}" }
    sequence(:name) { |n| "Term #{n} from URIs" }
  end
end
