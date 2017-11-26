FactoryGirl.define do
  factory :collection do
    sequence(:name) { |n| "Collection #{n}" }
    sequence(:description) { |n| "Description ##{n} of a collection" }
    default_sort { "position" }
    collection_type { "normal" }
    created_at {Date.new(2017,3,6)}
    updated_at {Date.new(2017,3,6)}  
    user_ids {create(:user).id}  
  end
end
