FactoryGirl.define do
  factory :medium do
    sequence(:guid) { |n| ((0..9).to_a + ('A'..'F').to_a).shuffle.join + n.to_s }
    sequence(:resource_pk)
    association :resource
    subclass { "image" }
    format { "jpg" }
    license { License.public_domain }
    language { Language.english }
    sequence(:owner) { |n| "Owned by #{n}" }
    sequence(:name) { |n| "Article Title ##{n}" }
    sequence(:description) { |n| "Body of article ##{n}" }
    sequence(:source_url) { |n| "http://some.place.com/#{n}" }
    sequence(:base_url) { |n| "http://some.place.com/#{n}" }

    # Yes, I know these are the same as above, but this allows the above to
    # change, if we wanted it to, and shows the pattern for other types:
    factory :image do
      subclass { "image" }
      format { "jpg" }
    end
  end
  
  factory :api_medium, class: "Medium" do
    sequence(:guid) { |n| ((0..9).to_a + ('A'..'F').to_a).shuffle.join + n.to_s }
    sequence(:resource_pk)
    resource {create(:api_resource)}
    subclass { "image" }
    format { "jpg" }
    license { License.public_domain }
    language { Language.english }
    sequence(:owner) { |n| "Owned by #{n}" }
    sequence(:name) { |n| "Article Title ##{n}" }
    sequence(:description) { |n| "Body of article ##{n}" }
    sequence(:source_url) { |n| "http://some.place.com/#{n}" }
    sequence(:base_url) { |n| "http://some.place.com/#{n}" }
  end
end
