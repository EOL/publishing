FactoryGirl.define do
  factory :user_download do
    user
    term_query
    search_url "foo"
    count 10
  end
end
