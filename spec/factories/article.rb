FactoryGirl.define do
  factory :article do
    sequence(:guid) { |n| ((0..9).to_a + ('A'..'F').to_a).shuffle.join + n.to_s }
    sequence(:resource_pk)
    association :resource
    license { License.public_domain }
    language { Language.english }
    sequence(:owner) { |n| "Owned by #{n}" }
    sequence(:name) { |n| "Article Title ##{n}" }
    sequence(:body) { |n| "Body of article ##{n}" }
  end
end
