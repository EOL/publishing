FactoryGirl.define do
  factory :collection do
    sequence(:name) { |n| "Collection #{n}" }
    sequence(:description) { |n| "Description ##{n} of a collection" }
    default_sort { "position" }
    collection_type { "normal" }
  end
end
